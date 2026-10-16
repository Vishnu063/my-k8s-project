# Kubernetes and GitOps lab: reviewer guide

A nested devsecops-platform project containing application, Terraform, Kubernetes, Argo CD, monitoring, and workflow material.

## Start the review

Explain desired state and reconciliation. The workflow is nested below the repository root, so GitHub does not discover it as a repository workflow in its current location.

| Source | Review focus |\n| --- | --- |\n| [devsecops-platform/.github/workflows/ci-cd.yml](devsecops-platform/.github/workflows/ci-cd.yml) | Triggers, credentials, failure handling, and deploy conditions |\n| [devsecops-platform/.gitignore](devsecops-platform/.gitignore) | Implementation, assumptions, and operational boundaries |\n| [devsecops-platform/app/.dockerignore](devsecops-platform/app/.dockerignore) | Implementation, assumptions, and operational boundaries |\n| [devsecops-platform/app/Dockerfile](devsecops-platform/app/Dockerfile) | Build context, runtime configuration, ports, and persistence |\n| [devsecops-platform/app/app.py](devsecops-platform/app/app.py) | Implementation, assumptions, and operational boundaries |\n| [devsecops-platform/app/requirements.txt](devsecops-platform/app/requirements.txt) | Implementation, assumptions, and operational boundaries |

## A useful interview walkthrough

1. State the problem and the specific part you implemented or changed.
2. Open the source above and follow one request, release, or failure from start to finish.
3. Show a reproducible result, including an actual failure and the observation that confirms recovery.
4. Explain one tradeoff and one limitation. Distinguish a local test from a live deployment.

## Evidence and limits

This guide is based on the default-branch source inspected on 16 October 2026. It is a source review, not a fresh deployment or a certification of every feature. Existing CI runs and tests should be checked at the commit being demonstrated. Do not present screenshots, inherited code, planned features, or old README statements as proof of a current deployment.
