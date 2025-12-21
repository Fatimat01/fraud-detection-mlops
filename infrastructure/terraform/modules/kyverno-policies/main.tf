# Deploy Kyverno policies using Helm
resource "helm_release" "kyverno_policies" {
  name      = "kyverno-policies"
  chart     = "../../../../../helm/kyverno-policies"
  namespace = "kyverno"

  wait    = true
  timeout = 300

  values = [
    file("../../../../helm/kyverno-policies/values.yaml")
  ]

  set {
    name  = "imageVerification.cosign.certificateIdentityRegexp"
    value = "https://github.com/${var.github_org}/${var.github_repo}/.*"
  }
}
