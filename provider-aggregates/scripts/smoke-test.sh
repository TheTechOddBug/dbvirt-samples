#!/bin/sh

set -eu

kubling_base_url="${KUBLING_BASE_URL:-http://kubling:8282}"
kubling_vdb="${KUBLING_VDB:-ProviderAggregatesVDB}"

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

aggregates="$(execute_sql "SELECT completed, COUNT(*) AS task_count, SUM(priority) AS priority_sum, AVG(estimate_hours) AS average_estimate FROM provider.TASK GROUP BY completed HAVING COUNT(*) >= 1 ORDER BY completed")"
assert_contains "${aggregates}" '"containsRows":true' "aggregate query returned no rows"
assert_contains "${aggregates}" '"completed":"false"' "incomplete task group is missing"
assert_contains "${aggregates}" '"task_count":"2"' "incomplete task count is incorrect"
assert_contains "${aggregates}" '"priority_sum":"5"' "incomplete priority sum is incorrect"
assert_contains "${aggregates}" '"average_estimate":"4.0"' "incomplete average estimate is incorrect"
assert_contains "${aggregates}" '"completed":"true"' "completed task group is missing"
assert_contains "${aggregates}" '"task_count":"1"' "completed task count is incorrect"
assert_contains "${aggregates}" '"priority_sum":"1"' "completed priority sum is incorrect"
assert_contains "${aggregates}" '"average_estimate":"2.5"' "completed average estimate is incorrect"

printf 'Provider aggregate result smoke test passed.\n'
