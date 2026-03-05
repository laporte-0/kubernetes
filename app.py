from flask import Flask, request, jsonify
import socket
import time
from datetime import datetime, timezone
from pymongo import MongoClient
import redis
import os
from prometheus_client import (
    Counter, Histogram, Gauge, Info,
    generate_latest, CONTENT_TYPE_LATEST, REGISTRY
)

app = Flask(__name__)

NAME = "Azer Hassine Zaabar"
PROJECT = "net4255-flask-docker"
VERSION = "V7"

# ──────────────────────────────────────────────
# Prometheus Metrics
# ──────────────────────────────────────────────
REQUEST_COUNT = Counter(
    "flask_http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "http_status"]
)
REQUEST_LATENCY = Histogram(
    "flask_http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"]
)
REQUESTS_IN_PROGRESS = Gauge(
    "flask_http_requests_in_progress",
    "Number of HTTP requests currently being processed",
    ["method", "endpoint"]
)
APP_INFO = Info(
    "flask_app",
    "Application metadata"
)
APP_INFO.info({
    "version": VERSION,
    "name": PROJECT,
    "author": NAME
})

MONGO_HOST = os.getenv("MONGO_HOST", "localhost")
MONGO_PORT = int(os.getenv("MONGO_PORT", "27017"))
MONGO_DB = os.getenv("MONGO_DB", "net4255")
MONGO_COLLECTION = os.getenv("MONGO_COLLECTION", "visits")

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

def get_client_ip():
    return request.headers.get("X-Forwarded-For", request.remote_addr)

def get_redis_client():
    try:
        return redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
    except:
        return None

# ──────────────────────────────────────────────
# Prometheus: Automatic request instrumentation
# ──────────────────────────────────────────────
@app.before_request
def _start_timer():
    """Record request start time and increment in-progress gauge."""
    if request.path == "/metrics":
        return  # Don't instrument the metrics endpoint itself
    request._prom_start_time = time.time()
    REQUESTS_IN_PROGRESS.labels(method=request.method, endpoint=request.path).inc()

@app.after_request
def _record_metrics(response):
    """Record request duration and count after each request."""
    if request.path == "/metrics":
        return response
    latency = time.time() - getattr(request, "_prom_start_time", time.time())
    REQUEST_LATENCY.labels(method=request.method, endpoint=request.path).observe(latency)
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.path,
        http_status=response.status_code
    ).inc()
    REQUESTS_IN_PROGRESS.labels(method=request.method, endpoint=request.path).dec()
    return response

# ──────────────────────────────────────────────
# Prometheus /metrics endpoint
# ──────────────────────────────────────────────
@app.route("/metrics")
def metrics():
    """Expose Prometheus metrics."""
    return generate_latest(REGISTRY), 200, {"Content-Type": CONTENT_TYPE_LATEST}

# ──────────────────────────────────────────────
# Health check endpoint
# ──────────────────────────────────────────────
@app.route("/health")
def health():
    """Simple health check for Kubernetes probes."""
    health_status = {"status": "healthy", "version": VERSION, "hostname": socket.gethostname()}
    # Check MongoDB connectivity
    try:
        client = MongoClient(host=MONGO_HOST, port=MONGO_PORT, serverSelectionTimeoutMS=2000)
        client.admin.command("ping")
        health_status["mongodb"] = "connected"
    except Exception:
        health_status["mongodb"] = "disconnected"
    # Check Redis connectivity
    try:
        r = get_redis_client()
        if r and r.ping():
            health_status["redis"] = "connected"
        else:
            health_status["redis"] = "disconnected"
    except Exception:
        health_status["redis"] = "disconnected"
    return jsonify(health_status)

@app.route("/")
def home():
    hostname = socket.gethostname()
    now = datetime.now(timezone.utc).astimezone()

    # Still save the visit to database
    try:
        client = MongoClient(host=MONGO_HOST, port=MONGO_PORT, serverSelectionTimeoutMS=2000)
        col = client[MONGO_DB][MONGO_COLLECTION]
        col.insert_one({
            "client_ip": get_client_ip(),
            "date": now.isoformat()
        })
    except Exception as e:
        pass  # Silent fail for demo

    return f"""
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>{PROJECT}</title>
        <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
        <style>
          body {{ font-family: Arial, sans-serif; margin: 40px; }}
          .card {{ max-width: 900px; padding: 20px; border: 1px solid #ddd; border-radius: 12px; }}
          code {{ background: #f5f5f5; padding: 2px 6px; border-radius: 6px; }}
          table {{ border-collapse: collapse; width: 100%; margin-top: 12px; }}
          th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
          th {{ background: #fafafa; }}
          .err {{ color: #b00020; }}
        </style>
        <script>
          $(document).ready(async function() {{
            // Increment visit count
            try {{
              const visitResponse = await fetch('/api/v1/visit', {{method: 'POST'}});
              const visitData = await visitResponse.json();
              document.getElementById('visit-count').textContent = visitData.visits || '?';
            }} catch (error) {{
              document.getElementById('visit-count').textContent = 'Error';
            }}
            
            // Load database records
            try {{
              const response = await fetch('/api/db?limit=10');
              const data = await response.json();
              
              const tbody = document.getElementById('records-body');
              tbody.innerHTML = '';
              
              data.forEach(record => {{
                const row = document.createElement('tr');
                row.innerHTML = `<td><code>${{record.client_ip || ''}}</code></td><td><code>${{record.date || ''}}</code></td>`;
                tbody.appendChild(row);
              }});
            }} catch (error) {{
              document.getElementById('error-msg').textContent = 'Error loading data: ' + error.message;
            }}
          }});
        </script>
      </head>
      <body>
        <div class="card">
          <h1>{PROJECT}</h1>
          <p><b>Name:</b> {NAME}</p>
          <p><b>Version:</b> <code>{VERSION}</code></p>
          <p><b>Server hostname:</b> <code>{hostname}</code></p>
          <p><b>Current date:</b> <code>{now.strftime("%Y-%m-%d %H:%M:%S %Z")}</code></p>
          <p><b>Total visits (Redis):</b> <code id="visit-count">Loading...</code></p>

          <h2>Last 10 records (MongoDB) - Loaded via JavaScript</h2>
          <p id="error-msg" class="err"></p>

          <table>
            <thead>
              <tr><th>client_ip</th><th>date</th></tr>
            </thead>
            <tbody id="records-body">
              <tr><td colspan="2">Loading...</td></tr>
            </tbody>
          </table>
        </div>
      </body>
    </html>
    """

@app.route("/api/db")
def api_db():
    limit = request.args.get('limit', default=10, type=int)
    
    try:
        client = MongoClient(host=MONGO_HOST, port=MONGO_PORT, serverSelectionTimeoutMS=2000)
        col = client[MONGO_DB][MONGO_COLLECTION]
        
        cursor = col.find({}, {"_id": 0}).sort("date", -1).limit(limit)
        records = list(cursor)
        
        return jsonify(records)
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/v1/visit", methods=["GET"])
def get_visits():
    """Get total visit count from Redis"""
    try:
        r = get_redis_client()
        if r:
            count = r.get("visit_count")
            return jsonify({"visits": int(count) if count else 0})
        else:
            return jsonify({"error": "Redis not available"}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/v1/visit", methods=["POST"])
def increment_visit():
    """Increment and return visit count"""
    try:
        r = get_redis_client()
        if r:
            count = r.incr("visit_count")
            return jsonify({"visits": count})
        else:
            return jsonify({"error": "Redis not available"}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500
