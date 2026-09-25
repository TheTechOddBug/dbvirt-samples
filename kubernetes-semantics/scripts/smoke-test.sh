#!/bin/sh

set -eu

kubling_base_url="${KUBLING_BASE_URL:-http://kubling:8282}"
kubling_vdb="${KUBLING_VDB:-KubernetesSemanticVDB}"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  value="$1"
  expected="$2"
  description="$3"

  case "${value}" in
    *"${expected}"*) ;;
    *) fail "${description}; expected ${expected} in ${value}" ;;
  esac
}

encode_query() {
  printf '%s' "$1" |
    base64 |
    tr -d '\n' |
    sed -e 's/+/%2B/g' -e 's#/#%2F#g' -e 's/=/%3D/g'
}

execute_sql() {
  query="$1"
  encoded_query="$(encode_query "${query}")"
  curl --fail --silent --show-error \
    "${kubling_base_url}/api/v1/admin/query/${kubling_vdb}/${encoded_query}"
}

semantic_detail="$(
  curl --fail --silent --show-error \
    "${kubling_base_url}/api/v1/admin/semantic/vdbs/${kubling_vdb}/versions/1"
)"
assert_contains "${semantic_detail}" '"state":"active"' "semantic model is not active"
assert_contains "${semantic_detail}" '"activationFailurePolicy":"failStartup"' "activation policy is incorrect"
assert_contains "${semantic_detail}" '"packageAvailable":true' "compiled semantic package is unavailable"
assert_contains "${semantic_detail}" '"errorCount":0' "semantic activation reported errors"

semantic_package="$(
  curl --fail --silent --show-error \
    "${kubling_base_url}/api/v1/admin/semantic/vdbs/${kubling_vdb}/versions/1/package"
)"
semantic_package_compact="$(printf '%s' "${semantic_package}" | tr -d '[:space:]')"
assert_contains "${semantic_package}" 'kubernetes-workloads' "provider semantic document is missing"
assert_contains "${semantic_package}" 'k8s:Deployment' "Deployment semantic entity is missing"
assert_contains "${semantic_package}" 'k8s:DeploymentOwnsReplicaSet' "provider relationship is missing"
assert_contains "${semantic_package}" 'platform:Workload' "federation concept is missing"
assert_contains "${semantic_package_compact}" '"representations":["k8s:Deployment"]' "Workload does not preserve its provider representation"
assert_contains "${semantic_package_compact}" '"authority":"k8s:Deployment"' "Workload authority is incorrect"

deployment="$(execute_sql "SELECT metadata__namespace, metadata__name FROM kube.DEPLOYMENT WHERE metadata__namespace = 'kubling-sample' AND metadata__name = 'provider-sample'")"
assert_contains "${deployment}" '"containsRows":true' "Kubernetes query returned no rows"
assert_contains "${deployment}" '"metadata__namespace":"kubling-sample"' "fixture namespace is missing"
assert_contains "${deployment}" '"metadata__name":"provider-sample"' "fixture deployment is missing"

printf 'Kubernetes provider and federation semantics smoke test passed.\n'
