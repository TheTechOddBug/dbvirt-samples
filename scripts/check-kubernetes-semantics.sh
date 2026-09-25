#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

printf 'Validating Kubernetes Semantics static contract (no containers will be started).\n'

sample_directory="kubernetes-semantics"
compose_file="${sample_directory}/compose.yaml"
vdb_file="${sample_directory}/descriptor/vdb/KubernetesSemanticVDB.yaml"
composition_file="${sample_directory}/descriptor/vdb/semantic/kubernetes-platform.composition.yaml"
alignment_file="${sample_directory}/descriptor/vdb/semantic/kubernetes-platform.alignment.yaml"

required_files=(
  "${compose_file}"
  "${sample_directory}/README.md"
  "${sample_directory}/app-config.yaml"
  "${sample_directory}/provider-config.yaml"
  "${sample_directory}/fixture.yaml"
  "${sample_directory}/descriptor/bundle-info.yaml"
  "${vdb_file}"
  "${composition_file}"
  "${alignment_file}"
  "${sample_directory}/scripts/smoke-test.sh"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    printf 'ERROR: required Kubernetes semantics file is missing: %s\n' "${required_file}" >&2
    exit 1
  fi
done

docker compose -f "${compose_file}" config --quiet
sh -n "${sample_directory}/scripts/smoke-test.sh"

mapfile -t images < <(docker compose -f "${compose_file}" config --images | sort -u)
expected_images=(
  docker.io/curlimages/curl:latest
  docker.io/fullstorydev/grpcurl:latest
  docker.io/kubling/kubling-cli:latest
  docker.io/kubling/kubling:latest
  docker.io/kubling/kubernetes-provider:latest
  docker.io/rancher/k3s:latest
)

for expected_image in "${expected_images[@]}"; do
  if ! printf '%s\n' "${images[@]}" | grep -Fqx "${expected_image}"; then
    printf 'ERROR: Kubernetes semantics image is missing or changed: %s\n' "${expected_image}" >&2
    exit 1
  fi
done

for image in "${images[@]}"; do
  if ! printf '%s\n' "${expected_images[@]}" | grep -Fqx "${image}"; then
    printf 'ERROR: unexpected Kubernetes semantics image: %s\n' "${image}" >&2
    exit 1
  fi
done

grep -Fq 'name: "KubernetesSemanticVDB"' "${vdb_file}"
grep -Fq 'name: "kube"' "${vdb_file}"
grep -Fq 'dataSourceType: "PROVIDER_GRPC"' "${vdb_file}"
grep -Fq 'composition: "semantic/kubernetes-platform.composition.yaml"' "${vdb_file}"
grep -Fq 'activationFailurePolicy: failStartup' "${vdb_file}"
grep -Fq 'imports: []' "${composition_file}"
grep -Fq 'platform:Workload' "${composition_file}"
grep -Fq 'id: Workload' "${alignment_file}"
grep -Fq 'kube:Deployment' "${alignment_file}"

if find "${sample_directory}" -type f -name '*.zip' -print -quit | grep -q .; then
  printf 'ERROR: generated bundles must not be committed.\n' >&2
  exit 1
fi

printf 'Kubernetes semantics static checks passed.\n'
