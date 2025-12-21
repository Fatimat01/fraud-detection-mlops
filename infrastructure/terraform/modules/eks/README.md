## EKS Module Decisions Explained

| Component | Decision | Why |
|-----------|----------|-----|
| **Private subnets** | Nodes in private subnets | Security — no public IPs on nodes |
| **OIDC Provider** | Enabled for IRSA | Pods can assume IAM roles securely |
| **EBS CSI Driver** | Installed as addon | Required for persistent volumes |
| **SPOT instances** | Used in dev | Cost savings (~70% cheaper) |
| **Cluster logging** | All types enabled | Debugging, audit trail |
| **Public endpoint** | Enabled with CIDR restriction | Can restrict to personal IP later |


## Cost Optimization (Dev)

| Setting | Value | Savings |
|---------|-------|---------|
| `capacity_type` | SPOT | ~70% on compute |
| `node_desired_size` | 2 | Minimal footprint |
| `instance_type` | t3.medium | Balanced cost/performance |

- after tf apply, run output of ***configure_kubectl*** to update kubeconfig so that  `kubectl` can connect to your EKS cluster.
```bash
$ aws eks update-kubeconfig --region us-east-1 --name fraud-detection-dev

# Verify connection
$ kubectl get nodes
$ kubectl get pods -A
```
