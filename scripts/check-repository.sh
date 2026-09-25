#!/usr/bin/env bash

set -euo pipefail

repository_root="$(git rev-parse --show-toplevel)"
cd "${repository_root}"

printf 'Validating repository static contract (no containers will be started).\n'

errors=0

report_error() {
  printf 'ERROR: %s\n' "$1" >&2
  errors=$((errors + 1))
}

required_files=(
  .editorconfig
  .gitattributes
  .gitignore
  CONTRIBUTING.md
  LICENSE
  README.md
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    report_error "required repository file is missing: ${required_file}"
  fi
done

printf '  - required OSS files\n'

while IFS= read -r generated_file; do
  if [[ -e "${generated_file}" ]]; then
    report_error "generated artifact is tracked: ${generated_file}"
  fi
done < <(git ls-files '*.zip' '*.jar' '*.class')

printf '  - no tracked generated archives or binaries\n'

while IFS= read -r -d '' shell_script; do
  if [[ -e "${shell_script}" ]] && ! bash -n "${shell_script}"; then
    report_error "invalid shell syntax: ${shell_script}"
  fi
done < <(find . -type f -name '*.sh' -not -path './.git/*' -print0 | sort -z)

printf '  - shell syntax, including untracked scripts\n'

private_registry="europe-southwest1-docker.pkg"".dev/bluelone""-repos"
while IFS= read -r private_reference; do
  report_error "private registry reference must not be committed: ${private_reference}"
done < <(
  {
    grep -RInF --exclude-dir=.git --exclude='*.zip' --exclude='*.jar' --exclude='*.class' \
      "${private_registry}" . || true
    git grep --cached -n -F "${private_registry}" -- . || true
  } | sort -u
)
printf '  - no private registry references, including untracked files\n'

internal_runtime_flag="RUNNING_IN_KUBLING_""ENV"
while IFS= read -r internal_reference; do
  report_error "internal runtime configuration must not be committed: ${internal_reference}"
done < <(
  {
    grep -RInF --exclude-dir=.git --exclude='*.zip' --exclude='*.jar' --exclude='*.class' \
      "${internal_runtime_flag}" . || true
    git grep --cached -n -F "${internal_runtime_flag}" -- . || true
  } | sort -u
)
printf '  - no internal runtime flag references, including untracked files\n'

if (( errors > 0 )); then
  printf 'Repository checks failed with %d error(s).\n' "${errors}" >&2
  exit 1
fi

printf 'Repository static checks passed; no containers were started.\n'
