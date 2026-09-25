#!/bin/sh

set -eu

kubling_base_url="${KUBLING_BASE_URL:-http://kubling:8282}"
kubling_vdb="${KUBLING_VDB:-ScheduledScriptsVDB}"

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

attempt=0
while [ "${attempt}" -lt 20 ]; do
  state="$(execute_sql "SELECT id, processed, execution_marker FROM scheduler.MAINTENANCE_JOB WHERE id = 'maintenance-1'")"

  case "${state}" in
    *'"processed":"true"'*'"execution_marker":"privileged bundle scheduler"'*)
      assert_contains "${state}" '"id":"maintenance-1"' "maintenance job is missing"
      printf 'Bundle-level scheduled script smoke test passed.\n'
      exit 0
      ;;
  esac

  attempt=$((attempt + 1))
  sleep 1
done

fail "bundle-level scheduled script did not update the maintenance job; last response: ${state}"
