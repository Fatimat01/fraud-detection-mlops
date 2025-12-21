# Install Kyverno first (if not already installed)
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --wait

# Install policies for staging
helm upgrade --install kyverno-policies ./helm/kyverno-policies \
  --namespace kyverno \
  --values ./helm/kyverno-policies/values-staging.yaml \
  --wait

# Install policies for prod
helm upgrade --install kyverno-policies ./helm/kyverno-policies \
  --namespace kyverno \
  --values ./helm/kyverno-policies/values-prod.yaml \
  --wait
