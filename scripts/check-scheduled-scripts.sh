#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

printf 'Validating Scheduled Scripts static contract (no containers will be started).\n'

sample_directory="scheduled-scripts"
compose_file="${sample_directory}/compose.yaml"
bundle_file="${sample_directory}/descriptor/bundle-info.yaml"
scheduled_script="${sample_directory}/descriptor/scheduled/complete_maintenance.js"
module_file="${sample_directory}/module/bundle-script-info.yaml"
vdb_file="${sample_directory}/descriptor/vdb/ScheduledScriptsVDB.yaml"

required_files=(
  "${compose_file}"
  "${sample_directory}/README.md"
  "${sample_directory}/app-config.yaml"
  "${bundle_file}"
  "${scheduled_script}"
  "${vdb_file}"
  "${module_file}"
  "${sample_directory}/module/schema.sql"
  "${sample_directory}/module/translator-config.yaml"
  "${sample_directory}/module/data/maintenance-jobs.js"
  "${sample_directory}/module/handler/MAINTENANCE_JOB.js"
  "${sample_directory}/scripts/smoke-test.sh"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    printf 'ERROR: required Scheduled Scripts file is missing: %s\n' "${required_file}" >&2
    exit 1
  fi
done

docker compose -f "${compose_file}" config --quiet
sh -n "${sample_directory}/scripts/smoke-test.sh"

mapfile -t images < <(docker compose -f "${compose_file}" config --images | sort -u)
expected_images=(
  docker.io/curlimages/curl:latest
  docker.io/kubling/kubling-cli:latest
  docker.io/kubling/kubling:latest
)

for expected_image in "${expected_images[@]}"; do
  if ! printf '%s\n' "${images[@]}" | grep -Fqx "${expected_image}"; then
    printf 'ERROR: Scheduled Scripts image is missing or changed: %s\n' "${expected_image}" >&2
    exit 1
  fi
done

for image in "${images[@]}"; do
  if ! printf '%s\n' "${expected_images[@]}" | grep -Fqx "${image}"; then
    printf 'ERROR: unexpected Scheduled Scripts image: %s\n' "${image}" >&2
    exit 1
  fi
done

grep -Fq 'scheduledScripts:' "${bundle_file}"
grep -Fq 'scheduled/complete_maintenance.js' "${bundle_file}"
grep -Fq 'DBEngine.executeUpdatePrivileged' "${scheduled_script}"
grep -Fq 'name: "ScheduledScriptsVDB"' "${vdb_file}"
grep -Fq 'name: "scheduler"' "${vdb_file}"
grep -Fq 'dataSourceType: "SCRIPT_DOCUMENT_JS"' "${vdb_file}"

if grep -Fq 'scheduledScripts:' "${module_file}"; then
  printf 'ERROR: schedule must belong to the descriptor bundle, not the state module.\n' >&2
  exit 1
fi

if find "${sample_directory}" -type f -name '*.zip' -print -quit | grep -q .; then
  printf 'ERROR: generated bundles must not be committed.\n' >&2
  exit 1
fi

printf 'Scheduled Scripts static checks passed.\n'
