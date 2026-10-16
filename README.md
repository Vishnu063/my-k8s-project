# Kubernetes and GitOps Lab

Application, Terraform, Kubernetes, Argo CD, and monitoring material lives under [devsecops-platform](devsecops-platform).

[Reviewer walkthrough](INTERVIEW.md)

## Review the implementation

| Source | Purpose |
| --- | --- |
| [Application](devsecops-platform/app) | Python app and container build |
| [Tests](devsecops-platform/tests) | Application checks |
| [Terraform](devsecops-platform/terraform) | AWS resource definitions |
| [Kubernetes](devsecops-platform/k8s) | Workload and Service configuration |
| [Argo CD](devsecops-platform/argocd/application.yaml) | GitOps application definition |
| [Monitoring](devsecops-platform/monitoring) | Prometheus/Grafana manifests |

## Important layout limitation

The workflow is at [devsecops-platform/.github/workflows/ci-cd.yml](devsecops-platform/.github/workflows/ci-cd.yml). GitHub Actions discovers workflows in the repository-root `.github/workflows` directory, so the nested file does not activate CI in this repository. Its relative app/test/manifest paths also assume a different root layout. Moving it alone is insufficient; paths, registry names, GitOps writes, and credentials need review together.

Start by inspecting the application and tests from the nested directory:

```bash
git clone https://github.com/Vishnu063/my-k8s-project.git
cd my-k8s-project/devsecops-platform
python3 -m venv .venv
. .venv/bin/activate
python3 -m pip install -r app/requirements.txt pytest
python3 -m pytest tests/ -v
```

These are suggested commands, not newly executed results. Terraform and cluster operations require a separately authorized environment. The previous README's working-pipeline and fixed-cost claims were not established by this source review.
