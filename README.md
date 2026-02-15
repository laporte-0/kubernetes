# High Availability Flask Web Application on Kubernetes

> A production-ready Flask web application demonstrating cloud-native deployment patterns, container orchestration, and distributed systems architecture on Kubernetes.

## 📋 Project Overview

This project showcases the complete journey of building, containerizing, and deploying a high-availability web application using modern DevOps practices. Starting from a simple Flask application, it evolves into a fully distributed, auto-scaling system with MongoDB replication, Redis caching, and REST API architecture.

**Key Features:**
- 🚀 Auto-scaling Flask web application with HPA (Horizontal Pod Autoscaler)
- 🗄️ MongoDB 3-member replica set for high availability
- ⚡ Redis cache for distributed session management
- 🔄 RESTful API with client-side rendering
- 🐳 Docker containerization with multi-service orchestration
- ☸️ Kubernetes deployment with Helm charts
- 📊 Load balancing with NGINX
- 🔒 Network policies for security
- 📈 Resource management and monitoring

## 🛠️ Technology Stack

**Frontend & Backend:**
- Python 3.12 (Alpine-based)
- Flask 3.0.3
- jQuery 3.5.1
- HTML5/CSS3

**Databases & Caching:**
- MongoDB 7.0 (Replica Set)
- Redis 7 (Alpine)

**Container Orchestration:**
- Docker & Docker Compose
- Kubernetes 1.28+
- Helm 3
- Rancher (Cluster Management)

**Infrastructure:**
- NGINX (Load Balancer & Ingress)
- MetalLB (Bare Metal Load Balancer)
- Longhorn (Persistent Storage)

**Monitoring & Scaling:**
- Kubernetes HPA (Horizontal Pod Autoscaler)
- Liveness/Readiness Probes
- Resource Quotas & Limits

## 🏗️ Architecture

### Final Architecture (Challenge 20)

```
                                    Internet
                                       |
                                   [Ingress]
                                    (NGINX)
                                       |
                    +------------------+------------------+
                    |                                     |
              [webdb Service]                    [webnodb Service]
              (ClusterIP)                        (ClusterIP)
                    |                                     |
            +-------+-------+                            |||
            |       |       |                            |||
        [webdb] [webdb] [webdb]                     [webnodb Pods]
         (HPA: 1-10 replicas)                       (Auto-scaled)
            |       |       |
            +-------+-------+
                    |
        +-----------+-----------+
        |                       |
   [MongoDB ReplicaSet]    [Redis Cache]
   (3 members: PRIMARY      (Visit Counter)
    + 2 SECONDARY)
        |
   [PersistentVolume]
    (Longhorn Storage)
```

### Component Breakdown

**Web Application Tier:**
- **webdb**: Flask app with MongoDB connection (auto-scales 1-10 pods)
- **webnodb**: Flask app without database (static content)
- **Resource Limits**: 50m-100m CPU, 64Mi-128Mi RAM per pod

**Data Tier:**
- **MongoDB StatefulSet**: 3-member replica set (1 PRIMARY + 2 SECONDARY)
- **Redis Deployment**: Single-instance cache for visit counter
- **Storage**: Longhorn-backed PersistentVolumeClaim (100Mi)

**Networking:**
- **Ingress**: HTTP routing to services via custom domains
- **Network Policies**: Restrict MongoDB access to webdb pods only
- **Services**: ClusterIP for internal communication, Headless for StatefulSet

## 🚀 Quick Start

### Prerequisites

- Docker Desktop
- kubectl CLI
- Helm 3
- Access to a Kubernetes cluster
- (Optional) Rancher for cluster management

### Local Development

1. **Clone the repository:**
   ```bash
   git clone https://github.com/laporte-0/kubernetes.git
   cd kubernetes
   ```

2. **Build Docker images:**
   ```bash
   # Build webdb (with database)
   docker build -t <your-registry>/flask-net4255:webdb-v6 .
   
   # Push to registry
   docker push <your-registry>/flask-net4255:webdb-v6
   ```

3. **Run with Docker Compose (local testing):**
   ```bash
   docker-compose up -d
   ```
   Access: http://localhost:80

### Kubernetes Deployment

1. **Configure kubectl:**
   ```bash
   export KUBECONFIG=/path/to/your/kubeconfig.yaml
   kubectl cluster-info
   ```

2. **Create namespace:**
   ```bash
   kubectl create namespace <your-namespace>
   ```

3. **Deploy with Helm:**
   ```bash
   helm install ch18 ./net4255-chart -n <your-namespace>
   ```

4. **Verify deployment:**
   ```bash
   kubectl get pods -n <your-namespace>
   kubectl get svc -n <your-namespace>
   kubectl get ingress -n <your-namespace>
   ```

5. **Check replica set status:**
   ```bash
   kubectl exec -n <your-namespace> net4255-mongodb-0 -- \
     mongosh --eval "rs.status()"
   ```

### Access the Application

- **With Ingress**: http://webdb.<your-namespace>.<cluster-domain>/
- **With Port-Forward**:
  ```bash
  kubectl port-forward -n <your-namespace> svc/webdb 5000:5000
  ```
  Access: http://localhost:5000

## 📦 Project Structure

```
.
├── app.py                          # Main Flask app (with MongoDB & Redis)
├── app_nodb.py                     # Flask app without database
├── Dockerfile                      # Multi-purpose Dockerfile (Alpine-based)
├── requirements.txt                # Python dependencies
├── docker-compose.yml              # Local Docker Compose setup
│
├── net4255-chart/                  # Helm Chart for Kubernetes
│   ├── Chart.yaml
│   ├── values.yaml                 # Configuration values
│   └── templates/
│       ├── mongodb-statefulset.yaml
│       ├── mongodb-headless-service.yaml
│       ├── redis-deployment.yaml
│       ├── redis-service.yaml
│       ├── webdb.yaml              # Deployment & Service
│       ├── webnodb.yaml
│       ├── ingress.yaml
│       ├── configmap-mongo.yaml
│       └── _helpers.tpl
│
├── challenge16/                    # Pure kubectl YAML files
│   ├── mongodb-deployment.yml
│   ├── mongodb-service.yml
│   ├── webdb-deployment.yml
│   └── webdb-service.yml
│
├── nginx/
│   └── nginx.conf                  # NGINX load balancer config
│
└── schemas/                        # Architecture diagrams
    ├── schema_ch1.png
    ├── schema_ch2.png
    └── ...
```

## 🎯 Implementation Milestones (Challenges)

Each challenge represents a learning milestone in building production-ready cloud-native applications:

### Phase 1: Containerization (Challenges 1-4)
- ✅ **Ch1**: Flask application + Dockerfile
- ✅ **Ch2**: MongoDB deployment with Docker Compose
- ✅ **Ch3**: Full-stack app (Flask + MongoDB)
- ✅ **Ch4**: NGINX load balancer

### Phase 2: Kubernetes Basics (Challenges 5-10)
- ✅ **Ch5**: Kubernetes cluster access & kubectl
- ✅ **Ch6**: First pod deployment (CLI)
- ✅ **Ch7**: Deployment YAML + ClusterIP service
- ✅ **Ch8**: Multi-pod deployment with KubeDNS
- ✅ **Ch9**: Liveness probes
- ✅ **Ch10**: Ingress controller

### Phase 3: Advanced Kubernetes (Challenges 11-15)
- ✅ **Ch11**: Helm chart automation
- ✅ **Ch12**: StatefulSet + PersistentVolume
- ✅ **Ch13**: Rolling updates
- ✅ **Ch14**: Horizontal Pod Autoscaler (HPA)
- ✅ **Ch15**: Network policies

### Phase 4: Distributed Systems (Challenges 16-20)
- ✅ **Ch16**: MongoDB replica set (kubectl)
- ✅ **Ch17**: MongoDB replica set (Helm)
- ✅ **Ch18**: REST API implementation
- ✅ **Ch19**: JavaScript client-side data fetching
- ✅ **Ch20**: Redis cache for distributed state

## 🔧 Configuration

### Environment Variables

**Flask Application (webdb):**
```bash
APP_MODULE=app                    # Module to run
MONGO_HOST=net4255-mongodb-0      # MongoDB hostname
MONGO_PORT=27017                  # MongoDB port
MONGO_DB=net4255                  # Database name
MONGO_COLLECTION=visits           # Collection name
REDIS_HOST=net4255-redis          # Redis hostname
REDIS_PORT=6379                   # Redis port
```

### Helm Chart Values

Key configurations in `net4255-chart/values.yaml`:

```yaml
webdb:
  replicas: 1
  tag: webdb-v6
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 10
    targetCPUUtilizationPercentage: 60

mongodb:
  enabled: true
  replicas: 3
  storage: 100Mi
  storageClassName: longhorn

resources:
  requests:
    cpu: "50m"
    memory: "64Mi"
  limits:
    cpu: "100m"
    memory: "128Mi"
```

## 📊 Monitoring & Scaling

### Auto-Scaling Configuration

The webdb deployment automatically scales based on CPU utilization:

```bash
# Check HPA status
kubectl get hpa -n <your-namespace>

# Manually scale (if needed)
kubectl scale deployment webdb -n <your-namespace> --replicas=3
```

### MongoDB Replica Set Health

```bash
# Check replica set status
kubectl exec -n <your-namespace> net4255-mongodb-0 -- \
  mongosh --eval "rs.status()"

# View PRIMARY/SECONDARY members
kubectl exec -n <your-namespace> net4255-mongodb-0 -- \
  mongosh --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"
```

### Redis Cache Status

```bash
# Check visit counter
kubectl exec -n <your-namespace> deploy/webdb -- \
  python -c "import redis; r=redis.Redis(host='net4255-redis', port=6379); print(r.get('visit_count'))"
```

### Logs & Debugging

```bash
# View webdb logs
kubectl logs -n <your-namespace> deploy/webdb --tail=50

# View MongoDB logs
kubectl logs -n <your-namespace> net4255-mongodb-0 --tail=50

# View Redis logs
kubectl logs -n <your-namespace> deploy/net4255-redis --tail=50
```

## 🔐 Security Features

### Network Policies

- MongoDB access restricted to webdb pods only
- Default deny ingress traffic
- Explicit allow rules for required communication

### Resource Limits

- CPU and memory limits prevent resource exhaustion
- Pod quotas enforce namespace limits
- Storage quotas prevent disk overflow

### Best Practices

- Non-root containers (Alpine base images)
- Liveness/readiness probes for self-healing
- ConfigMaps for sensitive configuration
- Network segmentation with ClusterIP services

## 🧪 Testing

### Functionality Tests

```bash
# Test webdb endpoint
curl http://webdb.<namespace>.<domain>/

# Test REST API
curl http://webdb.<namespace>.<domain>/api/db?limit=10

# Test visit counter
curl -X POST http://webdb.<namespace>.<domain>/api/v1/visit
curl http://webdb.<namespace>.<domain>/api/v1/visit
```

### Load Testing

```bash
# Install Apache Bench
apt-get install apache2-utils

# Generate load
ab -n 1000 -c 50 http://webdb.<namespace>.<domain>/

# Watch HPA scale
watch kubectl get hpa -n <namespace>
```

## 📚 API Documentation

### REST Endpoints

#### GET /
Returns the main HTML page with:
- Server hostname
- Visit counter (from Redis)
- Last 10 database records (loaded via JavaScript)

#### GET /api/db?limit=N
Returns the last N records from MongoDB.

**Parameters:**
- `limit` (optional): Number of records (default: 10)

**Response:**
```json
[
  {
    "client_ip": "192.168.1.100",
    "date": "2026-01-26T15:30:00+00:00"
  }
]
```

#### GET /api/v1/visit
Returns the current visit count.

**Response:**
```json
{
  "visits": 42
}
```

#### POST /api/v1/visit
Increments and returns the visit count.

**Response:**
```json
{
  "visits": 43
}
```

## 🎓 Key Learnings

### Cloud-Native Patterns
- **12-Factor App**: Configuration via environment, stateless processes
- **Microservices**: Separation of concerns (web, data, cache tiers)
- **Distributed Systems**: Replica sets, eventual consistency
- **Auto-Scaling**: Horizontal scaling based on metrics

### Kubernetes Concepts
- **Controllers**: Deployments, StatefulSets, ReplicaSets
- **Services**: ClusterIP, Headless, Ingress
- **Storage**: PersistentVolumes, StatefulSet storage
- **Configuration**: ConfigMaps, environment variables
- **Networking**: KubeDNS, Network Policies
- **Observability**: Probes, logging, monitoring

### DevOps Practices
- **IaC**: Infrastructure as Code with Helm
- **GitOps**: Version-controlled deployments
- **CI/CD**: Docker builds, image tagging, rolling updates
- **Monitoring**: Resource usage, application health

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

This project was developed as part of the NET4255 course at Télécom SudParis, demonstrating practical implementation of high-availability web services and Kubernetes orchestration.

---

**Built with ❤️ using Flask, Docker, and Kubernetes**
