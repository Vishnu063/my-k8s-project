#!/bin/bash
echo "Stopping existing tunnels..."
killall kubectl 2>/dev/null
echo "Starting tunnels..."
nohup kubectl port-forward svc/kube-stack-kube-prometheus-prometheus -n monitoring 9090:9090 --address 0.0.0.0 > ../monitoring/prometheus.log 2>&1 &
nohup kubectl port-forward svc/kube-stack-grafana -n monitoring 3000:80 --address 0.0.0.0 > ../monitoring/grafana.log 2>&1 &
echo "Tunnels running in background."
