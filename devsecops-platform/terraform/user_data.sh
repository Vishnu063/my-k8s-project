#!/bin/bash
# This script runs automatically once, the first time the EC2 instance boots.
# Everything here is what turns a blank Ubuntu box into a working K3s node.
set -euxo pipefail

# ---------------------------------------------------------------------------
# 1. SWAP FILE — t2.micro/t3.micro only has 1GB RAM. K3s + the app pod +
#    Prometheus + Grafana will get OOM-killed without swap as a buffer.
#    This is a genuine production technique for memory-constrained nodes,
#    not just a workaround — worth mentioning in an interview.
# ---------------------------------------------------------------------------
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# ---------------------------------------------------------------------------
# 2. INSTALL K3S — Rancher's lightweight Kubernetes distribution. A single
#    binary that runs both control plane and kubelet, ideal for a one-node
#    cluster. This replaces the $72/month managed EKS control plane cost
#    with $0, while keeping the same kubectl/YAML workflow.
# ---------------------------------------------------------------------------
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Wait for k3s to be fully up before continuing
until kubectl get nodes 2>/dev/null | grep -q Ready; do
  sleep 5
done

# ---------------------------------------------------------------------------
# 3. MAKE KUBECONFIG READABLE BY THE ubuntu USER — so you don't need sudo
#    for every kubectl command after SSHing in.
# ---------------------------------------------------------------------------
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# ---------------------------------------------------------------------------
# 4. CLOUDWATCH AGENT — ships basic OS-level metrics (CPU, memory, disk) to
#    CloudWatch so there's a real monitoring signal outside the cluster too.
# ---------------------------------------------------------------------------
curl -sSL https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -o /tmp/cw-agent.deb
dpkg -i -E /tmp/cw-agent.deb || true
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c default || true

echo "K3s node bootstrap complete." > /var/log/bootstrap-complete.log
