"""Per-side offered/ok/err/p95/throttling every 30 s for each "name start end" window in a file (needs Prometheus on localhost:9090).
Usage: knee.py windows.txt"""
import json, sys, time, urllib.parse, urllib.request

Q = {
    "offered": 'sum by (scenario) (rate(k6_http_reqs_total{scenario=~"bad|good"}[30s])) + sum by (scenario) (rate(k6_dropped_iterations_total{scenario=~"bad|good"}[30s]))',
    "ok": 'sum by (scenario) (rate(k6_http_reqs_total{scenario=~"bad|good", expected_response="true"}[30s]))',
    "err": 'sum by (scenario) (rate(k6_http_reqs_total{scenario=~"bad|good", expected_response="false"}[30s]))',
    "p95": 'max by (scenario) (k6_http_req_duration_p95{scenario=~"bad|good"}) * 1000',
    "thr": 'label_replace(sum by (container) (rate(container_cpu_cfs_throttled_periods_total{namespace="demo", container=~"bad|good"}[1m])) / sum by (container) (rate(container_cpu_cfs_periods_total{namespace="demo", container=~"bad|good"}[1m])), "scenario", "$1", "container", "(.*)")',
}
for line in open(sys.argv[1]):
    name, start, end = line.split()
    rows = {}
    for key, q in Q.items():
        url = "http://localhost:9090/api/v1/query_range?" + urllib.parse.urlencode({"query": q, "start": int(start) + 30, "end": end, "step": 30})
        for s in json.load(urllib.request.urlopen(url))["data"]["result"]:
            for t, v in s["values"]:
                rows.setdefault(int(t), {}).setdefault(key, {})[s["metric"]["scenario"]] = float(v)
    print(f"== {name}   (variante = bad | referencia = good)")
    print("hora   ofrecido     ok/s         err/s       p95 ms        throttling")
    for t in sorted(rows):
        r = rows[t]
        cell = lambda k, f="{:.0f}": f"{f.format(r.get(k, {}).get('bad', 0)):>5}|{f.format(r.get(k, {}).get('good', 0)):<5}"
        print(time.strftime("%H:%M:%S", time.localtime(t)), cell("offered"), " ", cell("ok"), " ", cell("err"), " ", cell("p95"), " ", cell("thr", "{:.2f}"))
