from flask import Flask, request
import socket
from datetime import datetime, timezone

app = Flask(__name__)

NAME = "Azer Hassine Zaabar"
PROJECT = "net4255-flask-docker"
VERSION = "V1 (no DB)"

def get_client_ip():
    return request.headers.get("X-Forwarded-For", request.remote_addr)

@app.route("/")
def home():
    hostname = socket.gethostname()
    now = datetime.now(timezone.utc).astimezone()
    return f"""
    <!doctype html>
    <html>
      <head><meta charset="utf-8"/><title>{PROJECT}</title></head>
      <body style="font-family: Arial; margin: 40px;">
        <h1>{PROJECT}</h1>
        <p><b>Name:</b> {NAME}</p>
        <p><b>Version:</b> <code>{VERSION}</code></p>
        <p><b>Server hostname:</b> <code>{hostname}</code></p>
        <p><b>Client IP:</b> <code>{get_client_ip()}</code></p>
        <p><b>Current date:</b> <code>{now.strftime("%Y-%m-%d %H:%M:%S %Z")}</code></p>
        <p>This instance does NOT use MongoDB.</p>
      </body>
    </html>
    """
