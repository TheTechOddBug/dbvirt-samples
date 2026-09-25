#!/usr/bin/env bash

set -euo pipefail

logs="$(docker compose logs --no-color provider)"

assert_log() {
  expected="$1"
  description="$2"

  if ! grep -Fq "${expected}" <<<"${logs}"; then
    printf 'ERROR: %s; expected %s in provider logs\n' "${description}" "${expected}" >&2
    printf '%s\n' "${logs}" >&2
    exit 1
  fi
}

assert_log 'INFO provider query received' "provider did not receive the query"
assert_log 'entity=TASK' "provider did not aggregate TASK"
assert_log 'mode=aggregate' "query was not encoded as an aggregate request"
assert_log 'aggregate_functions="[COUNT_STAR SUM AVG]"' "aggregate functions were not pushed down"
assert_log 'group_by_count=1' "GROUP BY was not pushed down"
assert_log 'having=true' "HAVING was not pushed down"
assert_log 'INFO provider query executed' "provider did not execute the aggregate"
assert_log 'output_rows=2' "provider returned an unexpected number of aggregate groups"

printf 'Provider aggregate pushdown evidence passed.\n'
