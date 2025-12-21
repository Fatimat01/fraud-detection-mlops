# Helm Addons

This directory contains Terraform-managed Helm releases that install and configure **core Kubernetes platform add-ons** for the cluster. These add-ons provide ingress, security, observability, logging, certificate management, and AWS load balancer integration.

All files in this directory are intended to be applied **after the base cluster is created** and are typically wired behind feature flags (e.g. `enable_*` variables) to allow selective installation per environment (dev/staging/prod).

---

## General Design Principles

- **Terraform + Helm (**``**)** is used for repeatable, declarative addon management
- Each addon:
  - Uses a pinned Helm chart version (reproducibility)
  - Creates its own namespace where applicable
  - Waits for readiness (`wait = true`) to ensure ordering
- Addons are **loosely coupled** but some depend on cluster readiness or other addons
- Designed to work well with **GitOps / Argo CD** downstream

---

## cert-manager.tf

**Purpose:** Manages TLS certificates inside the cluster using cert-manager.

**What it installs:**

- `cert-manager` Helm chart from Jetstack
- CRDs for Certificate, Issuer, ClusterIssuer

**Key Details:**

- Namespace: `cert-manager`
- Chart version is pinned (e.g. `v1.13.0`)
- `create_namespace = true`
- Controlled by a feature flag (e.g. `var.enable_cert_manager`)

**Why it matters:**

- Required for automatic TLS (Let’s Encrypt / ACM / internal PKI)
- Common dependency for Ingress, Gateways, and secure services

---

## ingress-nginx.tf

**Purpose:** Provides a production-grade Kubernetes Ingress Controller.

**What it installs:**

- `ingress-nginx` Helm chart

**Key Details:**

- Creates the ingress controller in its own namespace
- Configured to work with cloud load balancers
- Often integrates with:
  - cert-manager (TLS)
  - AWS Load Balancer Controller (ELB/NLB/ALB)

**Why it matters:**

- Primary entry point for HTTP/HTTPS traffic into the cluster
- Enables path-based and host-based routing

---

## lb-controller.tf (AWS Load Balancer Controller)

**Purpose:** Manages AWS ALB/NLB resources from Kubernetes Ingress and Service objects.

**What it installs:**

- AWS Load Balancer Controller Helm chart

**Key Details:**

- Requires:
  - EKS cluster
  - IAM OIDC provider
  - IAM role for service account (IRSA)
- Integrates tightly with AWS networking

**Why it matters:**

- Enables native AWS load balancers
- Required for production-grade EKS ingress patterns

---

## prometheus.tf

**Purpose:** Installs full Kubernetes monitoring and alerting stack.

**What it installs:**

- `kube-prometheus-stack` Helm chart
  - Prometheus
  - Alertmanager
  - Node Exporter
  - kube-state-metrics

**Key Details:**

- Namespace: `monitoring`
- Chart version pinned (e.g. `55.x`)
- Often depends on cluster readiness (`time_sleep` or similar)

**Why it matters:**

- Core observability for cluster health
- Enables SLOs, alerts, and capacity planning

---

## grafana.tf

**Purpose:** Provides visualization for metrics and logs.

**What it installs:**

- Grafana (often bundled via kube-prometheus-stack or standalone)

**Key Details:**

- Namespace: `monitoring`
- Preconfigured dashboards (Prometheus / Kubernetes)
- Typically integrates with:
  - Prometheus (metrics)
  - Loki (logs)

**Why it matters:**

- Single pane of glass for platform and application insights
- Used by SREs, DevOps, and developers

---

## loki.tf

**Purpose:** Centralized logging for Kubernetes workloads.

**What it installs:**

- Loki Helm chart (log aggregation)
- Often paired with Promtail or Fluent Bit

**Key Details:**

- Stores logs indexed by labels, not full-text
- Designed to scale efficiently
- Integrates natively with Grafana

**Why it matters:**

- Enables debugging and incident response
- Complements metrics-based monitoring

---

## kyverno.tf

**Purpose:** Policy-as-code engine for Kubernetes.

**What it installs:**

- Kyverno Helm chart

**Key Details:**

- Enforces policies at admission time
- Common policies include:
  - Required labels
  - Image registry restrictions
  - Security context enforcement

**Why it matters:**

- Shifts security and compliance left
- Reduces risk from misconfigured workloads

---

## Dependencies & Ordering

Typical installation order:

1. Cluster provisioning (EKS / Kubernetes)
2. AWS Load Balancer Controller
3. Ingress NGINX
4. cert-manager
5. Prometheus stack
6. Grafana
7. Loki
8. Kyverno

Terraform handles most ordering via:

- `depends_on`
- `wait = true`
- Explicit sleep or readiness checks

---

## Environment Strategy

These addons are usually:

- **Enabled in dev/staging** for early feedback
- **Hardened in prod** with stricter values and policies

Feature flags allow selective enablement:

```hcl
enable_cert_manager = true
enable_kyverno     = true
enable_loki        = false
```

---

## Notes for Operators

- Always pin Helm chart versions
- Review values overrides carefully before production
- Monitor CRD upgrades (cert-manager, Prometheus)
- Treat this directory as **platform-critical code**

---

**Owner:** Platform / DevOps Team **Scope:** Cluster-level infrastructure only
