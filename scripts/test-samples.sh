#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

all_samples=(
  quickstart
  endpoints
  rbac
  javascript
  functions
  initializer
  synthetic-entities
  provider-values
  provider-aggregates
  scheduled-scripts
  kubernetes-semantics
)

if (( $# > 0 )); then
  samples=("$@")
else
  samples=("${all_samples[@]}")
fi

is_known_sample() {
  local requested="$1"
  local candidate

  for candidate in "${all_samples[@]}"; do
    if [[ "${candidate}" == "${requested}" ]]; then
      return 0
    fi
  done

  return 1
}

for sample in "${samples[@]}"; do
  if ! is_known_sample "${sample}"; then
    printf 'ERROR: unknown sample: %s\n' "${sample}" >&2
    printf 'Available samples: %s\n' "${all_samples[*]}" >&2
    exit 2
  fi
done

active_sample=""

cleanup_active_sample() {
  if [[ -z "${active_sample}" ]]; then
    return
  fi

  printf '\n[%s] Cleaning containers, networks, and volumes\n' "${active_sample}"
  (
    cd "${repository_root}/${active_sample}"
    docker compose down --volumes --remove-orphans
  )
  active_sample=""
}

on_exit() {
  local status=$?
  trap - EXIT INT TERM

  if (( status != 0 )) && [[ -n "${active_sample}" ]]; then
    printf '\n[%s] E2E failed; printing Compose logs\n' "${active_sample}" >&2
    (
      cd "${repository_root}/${active_sample}"
      docker compose logs --no-color
    ) || true
  fi

  cleanup_active_sample || true
  exit "${status}"
}

trap on_exit EXIT
trap 'exit 130' INT TERM

printf '[repository] Validating static repository contract\n'
bash scripts/check-repository.sh

total="${#samples[@]}"
position=0

for sample in "${samples[@]}"; do
  position=$((position + 1))
  wait_timeout=180
  if [[ "${sample}" == "kubernetes-semantics" ]]; then
    wait_timeout=300
  fi

  printf '\n[%d/%d] %s: validating static sample contract\n' \
    "${position}" "${total}" "${sample}"
  bash "scripts/check-${sample}.sh"

  active_sample="${sample}"
  printf '\n[%d/%d] %s: starting stack and waiting for healthchecks\n' \
    "${position}" "${total}" "${sample}"
  (
    cd "${repository_root}/${sample}"
    docker compose up --wait --wait-timeout "${wait_timeout}"
  )

  printf '\n[%d/%d] %s: running smoke test\n' \
    "${position}" "${total}" "${sample}"
  smoke_command=(docker compose --profile test run --rm)
  case "${sample}" in
    quickstart|endpoints|rbac)
      ;;
    *)
      smoke_command+=(--no-deps)
      ;;
  esac
  smoke_command+=(smoke-test)
  (
    cd "${repository_root}/${sample}"
    "${smoke_command[@]}"
  )

  if [[ "${sample}" == "provider-aggregates" ]]; then
    printf '\n[%d/%d] %s: verifying provider-side pushdown evidence\n' \
      "${position}" "${total}" "${sample}"
    (
      cd "${repository_root}/${sample}"
      bash scripts/assert-pushdown.sh
    )
  fi

  cleanup_active_sample
  printf '\n[%d/%d] %s: E2E passed\n' \
    "${position}" "${total}" "${sample}"
done

printf '\nAll %d sample E2E tests passed.\n' "${total}"
