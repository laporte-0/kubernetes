from flask import Flask, request, jsonify
import socket
from datetime import datetime, timezone
from pymongo import MongoClient
import os

app = Flask(__name__)

NAME = "Azer Hassine Zaabar"
PROJECT = "net4255-flask-docker"
VERSION = "V5"

MONGO_HOST = os.getenv("MONGO_HOST", "localhost")
MONGO_PORT = int(os.getenv("MONGO_PORT", "27017"))
MONGO_DB = os.getenv("MONGO_DB", "net4255")
MONGO_COLLECTION = os.getenv("MONGO_COLLECTION", "visits")

def get_client_ip():
    return request.headers.get("X-Forwarded-For", request.remote_addr)

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
