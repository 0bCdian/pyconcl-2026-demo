# Bootstrap (personal project)

Creates what `../` assumes already exists: the project with billing, its APIs, a versioned bucket for the state of `../`, and a budget alert. Local state; run once.

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in project_id and billing_account
gcloud auth application-default login
tofu init && tofu plan && tofu apply
```

Then in `../`: copy `backend.tf.example` to `backend.tf` with `bucket = "<project_id>-tofu-state"`, and `terraform.tfvars.example` to `terraform.tfvars` with your `project_id` and a region such as `southamerica-west1` / `southamerica-west1-b`.
