from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)

# APP_VERSION gets baked in at Docker build time by CI — makes it obvious
# in the response which pipeline run / image tag is actually running,
# which is genuinely useful when demoing rolling deployments.
APP_VERSION = os.environ.get("APP_VERSION", "dev")


@app.route("/")
def index():
    return jsonify(
        message="Hello from the DevSecOps platform",
        version=APP_VERSION,
        hostname=socket.gethostname(),  # changes per pod — proves load balancing/rollout works
    )


@app.route("/healthz")
def healthz():
    # Used by the Kubernetes liveness/readiness probes in k8s/deployment.yaml
    return jsonify(status="ok"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
