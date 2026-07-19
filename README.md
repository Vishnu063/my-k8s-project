# DevSecOps CI/CD Platform (AWS Free Tier)

A complete, working DevSecOps pipeline that costs under $2/month to run — built
to survive a technical interview, not just look good on a resume.

**Flow:** GitHub push → unit tests → SonarCloud (SAST) → OWASP Dependency-Check
(SCA) → Docker build → Trivy scan (container) → push to ECR → commit new tag
to Git → ArgoCD (GitOps) auto-deploys to a self-hosted K3s cluster →
Prometheus + Grafana monitor it.

---

## 1. Why these specific choices

| Decision | Reason |
|---|---|
| K3s on EC2, not managed EKS | EKS control plane is $0.10/hr (~$72/mo) with no free tier. K3s is the same Kubernetes API, $0 extra cost. |
| Default VPC, no NAT Gateway | NAT Gateway is ~$32/mo flat. The default VPC's Internet Gateway gives the node internet access for free. |
| No ALB | ~$16/mo. NodePort on the instance's public IP does the same job for a single-node demo. |
| ArgoCD (GitOps), not `kubectl apply` in CI | The pipeline never touches the cluster directly. It only updates Git. ArgoCD reconciles. This is the actual definition of GitOps, and the detail interviewers specifically probe for. |
| 2GB swap file on the node | 1GB RAM is tight for K3s + app + Prometheus + Grafana together. Swap prevents OOM kills. A real, defensible tradeoff to explain in an interview. |

## 2. Prerequisites

- AWS account (free tier, new-ish so the 12-month clock isn't expired)
- [Terraform](https://developer.hashicorp.com/terraform/install) installed locally
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws configure`) with an IAM user that has EC2/IAM/ECR permissions
- `kubectl` installed locally
- An EC2 key pair created in your AWS account (EC2 Console → Key Pairs → Create)
- A GitHub account, and this project pushed to your own repo
- A free [SonarCloud](https://sonarcloud.io) account, linked to that GitHub repo

## 3. Provision the infrastructure

```bash
cd terraform

# Find your public IP for the security group
curl ifconfig.me
# -> e.g. 49.36.12.87

terraform init
terraform apply \
  -var="key_pair_name=YOUR_KEY_PAIR_NAME" \
  -var="my_ip=49.36.12.87/32"
```

Type `yes` to confirm. This takes ~2 minutes and creates: the EC2 instance,
security group, IAM role + instance profile, and the ECR repository.

When it finishes, note the outputs:
```
instance_public_ip = "13.234.x.x"
ecr_repository_url = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/devsecops-platform-app"
app_url             = "http://13.234.x.x:30080"
grafana_url         = "http://13.234.x.x:30030"
```

## 4. Connect to the cluster

The bootstrap script needs ~60–90 seconds after the instance is running to
finish installing K3s.

```bash
ssh -i /path/to/your-key.pem ubuntu@<instance_public_ip>

# Once connected, confirm K3s is up:
kubectl get nodes
# Should show one node in "Ready" state
```

To run kubectl from your **local machine** instead of over SSH:
```bash
scp -i your-key.pem ubuntu@<instance_public_ip>:~/.kube/config ./kubeconfig
sed -i '' "s/127.0.0.1/<instance_public_ip>/" ./kubeconfig   # macOS
# sed -i "s/127.0.0.1/<instance_public_ip>/" ./kubeconfig    # Linux
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

**Fix the image placeholder** in `k8s/deployment.yaml` — replace
`<ACCOUNT_ID>` with your real AWS account ID (visible in the ECR URL from
the Terraform output), then commit and push.

## 5. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl get pods -n argocd -w

# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Expose the UI on a NodePort so you can log in from your browser
kubectl -n argocd patch svc argocd-server -p '{"spec": {"type": "NodePort", "ports": [{"port":443,"nodePort":30090,"targetPort":8080}]}}'
```

Open `https://<instance_public_ip>:30090` (accept the self-signed cert
warning), log in with `admin` / the password above.

Edit `argocd/application.yaml`, replace `<your-username>` with your GitHub
username, then apply it:
```bash
kubectl apply -f argocd/application.yaml
```

ArgoCD will now watch your repo's `k8s/` folder and deploy automatically.

## 6. Deploy monitoring

```bash
kubectl apply -f monitoring/prometheus.yaml
kubectl apply -f monitoring/grafana.yaml
```

Visit `http://<instance_public_ip>:30030`, log in with `admin` /
`changeme123` — **change this password immediately** (Grafana will prompt
you). Prometheus is already wired as the default datasource.

## 7. Configure GitHub Actions secrets

In your repo: **Settings → Secrets and variables → Actions**, add:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | From an IAM user with ECR push permissions |
| `AWS_SECRET_ACCESS_KEY` | Same IAM user |
| `AWS_REGION` | e.g. `ap-south-1` |
| `ECR_REPOSITORY` | The `ecr_repository_url` from Terraform output |
| `SONAR_TOKEN` | Generate at sonarcloud.io → My Account → Security |

Also update `sonar-project.properties` with your real SonarCloud org/project
key.

## 8. Trigger the pipeline

```bash
git add .
git commit -m "trigger pipeline"
git push origin main
```

Watch it run under the **Actions** tab. It will: test → SonarCloud scan →
dependency scan → build → Trivy scan → push to ECR → commit the new image
tag to `k8s/deployment.yaml`. Within ~30 seconds of that commit, ArgoCD's UI
will show the app syncing to the new version.

Confirm:
```bash
curl http://<instance_public_ip>:30080/
# {"message": "Hello from the DevSecOps platform", "version": "a1b2c3d", "hostname": "devsecops-app-..."}
```

## 9. Cost control — do this or you'll get charged

- **Set a AWS Budget alert**: Billing Console → Budgets → Create budget →
  $5 threshold, email alert. Takes 2 minutes, catches mistakes early.
- ECR storage is billed per GB after the free 500MB — old image tags pile
  up. Periodically run `aws ecr list-images` and delete old tags, or set a
  lifecycle policy.
- When you're done experimenting for the day: `terraform destroy` tears
  down the EC2 instance (stops all compute billing) and ECR repo. Re-run
  `terraform apply` next time you want to demo it — takes 2 minutes.

## 10. Talking points for the interview

Be ready to explain, in your own words:
- **Why K3s instead of EKS** — cost tradeoff, same K8s API surface, what
  you'd change if this were a real multi-node production cluster.
- **What GitOps actually means** — the pipeline never runs `kubectl apply`;
  it only updates Git, and ArgoCD reconciles. Contrast this with a
  push-based deploy.
- **Where security is enforced** — SAST (SonarCloud) → SCA (OWASP
  Dependency-Check) → container scan (Trivy) → runtime hardening
  (non-root user, dropped capabilities, read-only root filesystem in
  `deployment.yaml`).
- **What happens on a failed scan** — Trivy's `exit-code: 1` fails the
  build; nothing vulnerable ever reaches ECR, let alone the cluster.
- **What's missing for real production** — multi-node HA, a proper
  private VPC with NAT for a private subnet, Vault/Secrets Manager for
  app secrets (none needed here since there are none), and an admission
  controller like Kyverno for policy-as-code at deploy time. Naming the
  gaps yourself is a strong signal — it shows you know the difference
  between a demo and production.

## Project structure

```
devsecops-platform/
├── terraform/           # Infrastructure: EC2, IAM, security group, ECR
├── app/                  # Flask app + Dockerfile
├── tests/                # Unit tests run in CI
├── .github/workflows/    # The CI/CD pipeline
├── k8s/                  # Deployment + Service manifests (what ArgoCD watches)
├── argocd/               # ArgoCD Application definition
├── monitoring/           # Prometheus + Grafana manifests
└── sonar-project.properties
```
