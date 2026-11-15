#!/bin/sh
# Installs the bad version on the demo VM with no container: pip, the same start.sh and gunicorn_conf.py, under systemd.
# The VM reaches the cluster's PostgreSQL and payments through NodePorts. SSH goes through IAP with the key in infra (vm_ssh_public_key_file).
set -eu
cd "$(dirname "$0")/.."
out() { tofu -chdir=infra output -raw "$1"; }
VM=$(out vm_name)
ZONE=$(out zone)
PROJECT=$(out project_id)
KEY=${VM_SSH_KEY:-$HOME/.ssh/pycon-vm}

remote() {
  ssh -F /dev/null -i "$KEY" -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$HOME/.ssh/known_hosts_pycon" \
    -o "ProxyCommand=gcloud compute start-iap-tunnel %h 22 --listen-on-stdin --zone $ZONE --project $PROJECT" \
    "demo@$VM" "$@"
}

kubectl apply -f k8s/vm.yaml
node=$(kubectl get nodes -l cloud.google.com/gke-nodepool=tools -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
secret() { kubectl -n demo get secret postgres-app -o jsonpath="{.data.$1}" | base64 -d; }

bundle=$(mktemp -d)
trap 'rm -r "$bundle"' EXIT
cp app/app.py deploy/bad/gunicorn_conf.py deploy/bad/start.sh deploy/bad/requirements.txt scripts/shop.service "$bundle"
cat > "$bundle/env" <<ENV
DATABASE_URL=postgresql://$(secret username):$(secret password)@$node:30432/$(secret dbname)
PAYMENTS_URL=http://$node:30080/charge
CATALOG_URI=$(out catalog_uri)
SHOP_NAME=vm
LOG_LEVEL=INFO
ENV

tar -C "$bundle" -cf - . | remote 'rm -rf shop && mkdir shop && tar -C shop -xf -'
remote '
  set -eu
  sudo apt-get update -qq && sudo apt-get install -y -qq python3-venv >/dev/null
  sudo systemctl stop shop 2>/dev/null || true
  sudo rm -rf /opt/shop && sudo mv shop /opt/shop && sudo chown -R root:root /opt/shop && sudo chmod 755 /opt/shop && sudo chmod 600 /opt/shop/env
  sudo python3 -m venv /opt/shop/venv && sudo /opt/shop/venv/bin/pip install -q -r /opt/shop/requirements.txt
  sudo mv /opt/shop/shop.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable -q --now shop
  for _ in $(seq 120); do curl -sf localhost:8000/health >/dev/null && break; sleep 0.5; done; systemctl is-active shop
  echo "nproc=$(nproc) workers=$(($(pgrep -c -f gunicorn) - 1))"
'
echo "VM: http://$(out vm_address):8000"
