from flask import Flask
import socket
from datetime import datetime, timezone

app = Flask(__name__)

NAME = "Azer Hassine Zaabar"
PROJECT = "NET4255-Kubernetes"
VERSION = "V1"

@app.route("/")
def home():
    hostname = socket.gethostname()
    now = datetime.now(timezone.utc).astimezone()  # local time with tz
    return f"""
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>{PROJECT}</title>
        <style>
          body {{ font-family: Arial, sans-serif; margin: 40px; }}
          .card {{ max-width: 700px; padding: 20px; border: 1px solid #ddd; border-radius: 12px; }}
          h1 {{ margin-top: 0; }}
          code {{ background: #f5f5f5; padding: 2px 6px; border-radius: 6px; }}
        </style>
      </head>
      <body>
        <div class="card">
          <h1>{PROJECT}</h1>
          <p><b>Name:</b> {NAME}</p>
          <p><b>Version:</b> <code>{VERSION}</code></p>
          <p><b>Server hostname:</b> <code>{hostname}</code></p>
          <p><b>Current date:</b> <code>{now.strftime("%Y-%m-%d %H:%M:%S %Z")}</code></p>
        </div>
      </body>
    </html>
    """
