#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

printf 'Validating Provider Aggregates static contract (no containers will be started).\n'

compose_file="provider-aggregates/compose.yaml"
vdb_file="provider-aggregates/descriptor/vdb/ProviderAggregatesVDB.yaml"

required_files=(
  "${compose_file}"
  provider-aggregates/README.md
  provider-aggregates/app-config.yaml
  provider-aggregates/descriptor/bundle-info.yaml
  "${vdb_file}"
  provider-aggregates/scripts/smoke-test.sh
  provider-aggregates/scripts/assert-pushdown.sh
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    printf 'ERROR: required Provider Aggregates file is missing: %s\n' "${required_file}" >&2
    exit 1
  fi
done

docker compose -f "${compose_file}" config --quiet
sh -n provider-aggregates/scripts/smoke-test.sh
bash -n provider-aggregates/scripts/assert-pushdown.sh

mapfile -t images < <(docker compose -f "${compose_file}" config --images | sort -u)
expected_images=(
  docker.io/curlimages/curl:latest
  docker.io/fullstorydev/grpcurl:latest
  docker.io/kubling/kubling-cli:latest
  docker.io/kubling/kubling:latest
  docker.io/kubling/inmemory-provider:latest
)

for expected_image in "${expected_images[@]}"; do
  if ! printf '%s\n' "${images[@]}" | grep -Fqx "${expected_image}"; then
    printf 'ERROR: Provider Aggregates image is missing or changed: %s\n' "${expected_image}" >&2
    exit 1
  fi
done

for image in "${images[@]}"; do
  if ! printf '%s\n' "${expected_images[@]}" | grep -Fqx "${image}"; then
    printf 'ERROR: unexpected Provider Aggregates image: %s\n' "${image}" >&2
    exit 1
  fi
done

grep -Fq 'name: "ProviderAggregatesVDB"' "${vdb_file}"
grep -Fq 'name: "provider"' "${vdb_file}"
grep -Fq 'dataSourceType: "PROVIDER_GRPC"' "${vdb_file}"
grep -Fq -- '-log-queries' "${compose_file}"
grep -Fq 'GROUP BY completed' provider-aggregates/scripts/smoke-test.sh
grep -Fq 'mode=aggregate' provider-aggregates/scripts/assert-pushdown.sh

if grep -Eiq '^[[:space:]]*ddl(FilePaths)?[[:space:]]*:' "${vdb_file}"; then
  printf 'ERROR: Provider Aggregates VDB must import its physical schema from GetSchema.\n' >&2
  exit 1
fi

if find provider-aggregates -type f -name '*.zip' -print -quit | grep -q .; then
  printf 'ERROR: generated bundles must not be committed.\n' >&2
  exit 1
fi

printf 'Provider Aggregates static checks passed.\n'
