# Challenge 5 – Accès à Kubernetes

- Installation de `kubectl`
- Configuration du fichier kubeconfig depuis Rancher (cluster **net4255**)
- Connexion au cluster vérifiée avec la commande `kubectl cluster-info`
- Problème TLS résolu à l’aide de la configuration fournie par Rancher

Commandes utilisées :
- `kubectl cluster-info`

## Challenge 6 – First Kubernetes Pod (CLI)

- Deployment `webnodb` created via kubectl
- 1 replica only
- No Service created
- Pod running in namespace `azaabar`
- Access tested using port-forwarding

Commands used:
- kubectl create deployment
- kubectl get deployments -o wide
- kubectl get pods -o wide
- kubectl port-forward

---

# Personal Formation — Extended Challenges

> Chapters 21+ are personal extensions beyond the school curriculum.
> Goal: simulate a production-ready telecom platform with observability and lifecycle automation.

---

## Challenge 21 – Prometheus Flask Instrumentation (V7)

**Objective:** Instrument the Flask application with Prometheus metrics to enable observability.

### What was done:
- Added `prometheus_client==0.21.0` to `requirements.txt`
- Bumped app version from **V6** to **V7**
- Defined custom Prometheus metrics in `app.py`:
  - `flask_http_requests_total` — Counter with labels: method, endpoint, http_status
  - `flask_http_request_duration_seconds` — Histogram with labels: method, endpoint
  - `flask_http_requests_in_progress` — Gauge with labels: method, endpoint
  - `flask_app_info` — Info metric with version, name, author
- Added `@app.before_request` / `@app.after_request` hooks for automatic instrumentation
- The `/metrics` endpoint itself is excluded from instrumentation to avoid recursion
- Added **`/metrics`** endpoint — exposes all Prometheus metrics in OpenMetrics format
- Added **`/health`** endpoint — returns JSON with:
  - App version and hostname
  - MongoDB connectivity status
  - Redis connectivity status

### New endpoints:
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/metrics` | GET | Prometheus scrape target |
| `/health` | GET | Kubernetes liveness/readiness probe |

### Files modified:
- `app.py` — metrics + health instrumentation
- `requirements.txt` — added `prometheus_client`

### Example `/metrics` output:
```
flask_http_requests_total{endpoint="/",http_status="200",method="GET"} 1.0
flask_http_request_duration_seconds_bucket{endpoint="/",le="0.005",method="GET"} 1.0
flask_app_info{author="Azer Hassine Zaabar",name="net4255-flask-docker",version="V7"} 1.0
```

### Example `/health` output:
```json
{
  "status": "healthy",
  "version": "V7",
  "hostname": "webdb-abc123",
  "mongodb": "connected",
  "redis": "connected"
}
```

### Tested locally:
```bash
python3 -m flask --app app run --host=0.0.0.0 --port=5001
curl http://localhost:5001/metrics
curl http://localhost:5001/health
```
