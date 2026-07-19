# --- Build stage: install deps into a clean layer -------------------------
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# --- Runtime stage: minimal image, no build tools left behind -------------
FROM python:3.12-slim
WORKDIR /app

# Security: run as a non-root user. This is one of the first things Trivy
# and any DevSecOps interviewer will check for — root containers are a
# classic finding.
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

COPY --from=builder /root/.local /home/appuser/.local
COPY app.py .

ENV PATH=/home/appuser/.local/bin:$PATH
ENV APP_VERSION=unset

USER appuser

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/healthz')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
