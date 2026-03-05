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

---

## Challenge 22 – Helm Chart Prometheus Integration (ServiceMonitor)

**Objective:** Update the Helm chart so Prometheus can auto-discover and scrape the Flask app.

### What was done:

1. **Created `servicemonitor-webdb.yaml` template**
   - A `ServiceMonitor` (CRD from `monitoring.coreos.com/v1`) that tells Prometheus to scrape the webdb Service
   - Targets the `http` port on `/metrics` path
   - Configurable interval (default `15s`) and scrapeTimeout (`10s`)
   - Conditionally rendered: only when `prometheus.enabled` and `prometheus.serviceMonitor.enabled` are true
   - Supports optional `additionalLabels` and `namespace` overrides

2. **Updated `webdb.yaml`**
   - Liveness probe changed from `/` to `/health`
   - Added readiness probe on `/health`
   - Added Prometheus annotations on the Service (`prometheus.io/scrape`, `prometheus.io/port`, `prometheus.io/path`)
   - Named the Service port `http` (required for ServiceMonitor port reference)

3. **Updated `webnodb.yaml`**
   - Named the Service port `http` for consistency

4. **Updated `values.yaml`**
   - Added `prometheus` section with `enabled`, `serviceMonitor` sub-config

5. **Bumped Chart version** from `0.1.0` to `0.2.0`, appVersion to `7.0`

### New file:
- `net4255-chart/templates/servicemonitor-webdb.yaml`

### Modified files:
- `net4255-chart/templates/webdb.yaml`
- `net4255-chart/templates/webnodb.yaml`
- `net4255-chart/values.yaml`
- `net4255-chart/Chart.yaml`

### How it works:
```
Prometheus ──scrapes──> ServiceMonitor ──selects──> webdb Service ──port: http──> /metrics
```

### Validated:
```bash
helm template test-release net4255-chart/
# Confirmed: ServiceMonitor renders, annotations present, probes use /health
```

---

## Challenge 23 – Prometheus Alert Rules (PrometheusRule)

**Objective:** Define production-relevant alert rules that Prometheus will evaluate automatically.

### What was done:

Created `net4255-chart/templates/prometheusrule.yaml` with 3 alert groups (6 rules total):

#### Group 1: Pod Health
| Alert | Condition | Severity |
|-------|-----------|----------|
| `PodRestarting` | >3 restarts in 15 minutes | warning |
| `PodCrashLooping` | CrashLoopBackOff state for 5 min | critical |

#### Group 2: Resource Usage
| Alert | Condition | Severity |
|-------|-----------|----------|
| `HighCPUUsage` | CPU >85% of limit for 10 min | warning |
| `HighMemoryUsage` | Memory >90% of limit for 10 min | warning |

#### Group 3: Deployment Health
| Alert | Condition | Severity |
|-------|-----------|----------|
| `ReplicaMismatch` | Desired != Available replicas for 10 min | critical |
| `WebdbEndpointDown` | Prometheus cannot scrape webdb for 3 min | critical |

### How it works:
- Uses the `monitoring.coreos.com/v1` `PrometheusRule` CRD
- All PromQL expressions are namespace-scoped using `{{ .Release.Namespace }}`
- Conditionally rendered: `prometheus.enabled` and `prometheus.alertRules.enabled`
- Supports `additionalLabels` for Prometheus rule selectors

### Files:
- **New:** `net4255-chart/templates/prometheusrule.yaml`
- **Modified:** `net4255-chart/values.yaml` (added `alertRules` section)

### Validated:
```bash
helm template test-release net4255-chart/
# Confirmed: All 6 alerts render with correct PromQL and namespace scoping
```

---

## Challenge 24 – Ansible Project Structure

**Objective:** Create a clean, production-grade Ansible project structure for Kubernetes lifecycle automation.

### What was done:

Created `ansible/` directory with standard Ansible best practices:

```
ansible/
├── ansible.cfg                      # Project-level config (local connection, YAML output)
├── requirements.yml                 # Galaxy collections: kubernetes.core, community.general
├── inventories/
│   ├── dev/                         # Development environment
│   │   ├── hosts.yml                # localhost with local connection
│   │   └── group_vars/all.yml       # Dev vars (namespace, images, ingress, prometheus)
│   └── prod/                        # Production environment
│       ├── hosts.yml
│       └── group_vars/all.yml       # Prod vars (larger storage, more retries)
├── roles/
│   ├── namespace/                   # Ensure K8s namespace exists
│   ├── helm_deploy/                 # Helm install/upgrade net4255-chart
│   ├── helm_upgrade/                # Image tag upgrade (obsolescence management)
│   ├── verify_rollout/              # kubectl rollout status checks
│   ├── health_check/                # Web, MongoDB, Redis post-deploy checks
│   ├── helm_rollback/               # Helm rollback on verification failure
│   └── prometheus_stack/            # Deploy kube-prometheus-stack
└── playbooks/
    ├── deploy.yml                   # Full deployment pipeline
    ├── upgrade.yml                  # Image upgrade pipeline
    └── monitoring.yml               # Prometheus stack deployment
```

### Architecture decisions:
- **Local connection** — Ansible runs on the same machine as `kubectl`/`helm` (no SSH)
- **Role-based** — Each concern is a separate, reusable role
- **Environment separation** — dev/prod inventories with different `group_vars`
- **Each role has:** `tasks/main.yml`, `defaults/main.yml`, `meta/main.yml`

### Files created: 30 files across ansible/ directory

---

## Challenge 25 – Ansible Helm Deploy Playbook

**Objective:** Automate full platform deployment with Helm via Ansible.

### Playbook: `deploy.yml`

A 5-phase deployment pipeline:
1. **Namespace Provisioning** — creates K8s namespace if it doesn't exist
2. **Helm Deploy** — `helm upgrade --install` with all chart values
3. **Rollout Verification** — `kubectl rollout status` for webdb, webnodb, MongoDB
4. **Health Checks** — HTTP /health endpoint, MongoDB rs.status, Redis ping
5. **Auto-Rollback** — triggers `helm rollback` if phases 3 or 4 fail

### Usage:
```bash
# Deploy to dev
cd ansible/
ansible-playbook playbooks/deploy.yml

# Deploy to prod
ansible-playbook playbooks/deploy.yml -i inventories/prod/hosts.yml
```

### Key roles used:
- `namespace` — uses `kubernetes.core.k8s` to ensure namespace + asserts Active state
- `helm_deploy` — full `helm upgrade --install` with `--atomic` (auto-rollback on Helm failure)
- `verify_rollout` — checks all Deployments and StatefulSets, sets `rollout_ok` fact
- `health_check` — 3-point check (web + MongoDB RS + Redis), sets `health_ok` fact
- `helm_rollback` — conditionally triggered when `rollout_ok` or `health_ok` is false

---

## Challenge 26 – Ansible Upgrade & Rollback

**Objective:** Automate image tag upgrades with verification and automatic rollback.

### Playbook: `upgrade.yml`

Simulates **obsolescence management** in a telecom context:
1. Validates that new image tag is provided
2. Upgrades via `helm upgrade --reuse-values --set webdb.tag=...`
3. Verifies rollout
4. Runs health checks
5. Rolls back if any check fails

### Usage:
```bash
# Upgrade webdb to v8
ansible-playbook playbooks/upgrade.yml -e "upgrade_image_tag_webdb=webdb-v8"

# Upgrade both components
ansible-playbook playbooks/upgrade.yml \
  -e "upgrade_image_tag_webdb=webdb-v8" \
  -e "upgrade_image_tag_webnodb=webnodb-v3"
```

### Key role: `helm_upgrade`
- Uses `--reuse-values` to preserve existing configuration
- Only overrides the image tags being upgraded
- Clean separation from full deploy

---

## Challenge 27 – Ansible Health Checks

**Objective:** Post-deployment verification of all platform components.

### Role: `health_check`

Three verification points:
| Check | Method | Success Criteria |
|-------|--------|------------------|
| **Web** | HTTP GET `/health` | HTTP 200 + JSON response |
| **MongoDB** | `kubectl exec` → `mongosh rs.status()` | All members reporting state |
| **Redis** | `kubectl exec` → `redis-cli ping` | Response is `PONG` |

Features:
- Configurable retries and delay for web endpoint checks
- Sets `health_ok` fact used by rollback role
- Pretty-printed summary table in console output

### Role: `helm_rollback`
- Shows `helm history` before rollback
- Conditional execution based on `rollback_trigger` variable
- Runs `helm rollback` + `helm status` to confirm

---

## Challenge 28 – Prometheus Stack Deployment Playbook

**Objective:** Automate deployment of the `kube-prometheus-stack` monitoring platform.

### Playbook: `monitoring.yml`

1. Deploys `kube-prometheus-stack` via Helm (Prometheus + Grafana + Alertmanager)
2. Verifies ServiceMonitor discovery in the app namespace
3. Verifies PrometheusRule discovery
4. Reports summary

### Key configuration:
```yaml
# Critical Helm values for cross-namespace monitoring:
--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
--set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false
```
This ensures Prometheus discovers ServiceMonitors and PrometheusRules in **all namespaces**, not just the monitoring namespace.

### Usage:
```bash
ansible-playbook playbooks/monitoring.yml
```

### Note:
All Ansible playbooks will be tested when cluster access is available. The syntax and structure follow Ansible best practices and are ready for execution.
