from flask import Flask, request
import requests
import os

app = Flask(__name__)

OLLAMA_MODEL=os.getenv("OLLAMA_MODEL")

@app.route("/api/chat", methods=["POST"])
def chat():
    message = request.form.get("message")
    reply = requests.post("http://ollama:11434/api/generate", json={"model": OLLAMA_MODEL, "prompt": message, "stream": False, "think": False}, timeout=120)
    return reply.json()["response"]

@app.route("/api/ping", methods=["GET", "POST"])
def ping():
    return "PONG\n"