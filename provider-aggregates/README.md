# Provider Aggregate Pushdown Sample

This sample shows how Kubling delegates a grouped SQL query to a gRPC provider that explicitly advertises aggregate capabilities.

The official In-memory provider declares support for `COUNT(*)`, `COUNT`, `COUNT_BIG`, `MIN`, `MAX`, `SUM`, and `AVG`, together with `DISTINCT`, `GROUP BY`, and `HAVING`. Kubling uses only the capabilities the provider publishes; unsupported query shapes remain engine work.

This sample verifies two independent outcomes:

- the SQL result is correct
- the provider logs prove that the aggregate shape reached the provider

## Source map

- `descriptor/vdb/ProviderAggregatesVDB.yaml` registers the provider as `PROVIDER_GRPC` and imports its schema through `GetSchema`.
- `compose.yaml` enables the provider's safe structural query logs with `-log-queries`.
- `scripts/smoke-test.sh` verifies the deterministic grouped result.
- `scripts/assert-pushdown.sh` verifies the provider-side aggregate request without relying on engine plans or result inference.

## Prerequisites

- Git
- Docker Engine
- Docker Compose v2

## Start

```bash
cd provider-aggregates
docker compose up --wait
```

Compose generates the descriptor bundle with the official Kubling CLI image. Generated ZIP files live only in a named volume and are not committed.

When the stack is ready:

- Kubling Studio: <http://localhost:8282/console>
- Health endpoint: <http://localhost:8282/observe/health>
- VDB: `ProviderAggregatesVDB`
- schema/data source: `provider`
- table: `TASK`

## Run a grouped query

Open Kubling Studio and run:

```sql
SELECT completed,
       COUNT(*) AS task_count,
       SUM(priority) AS priority_sum,
       AVG(estimate_hours) AS average_estimate
FROM provider.TASK
GROUP BY completed
HAVING COUNT(*) >= 1
ORDER BY completed;
```

Expected rows:

| completed | task_count | priority_sum | average_estimate |
|:--|--:|--:|--:|
| `false` | 2 | 5 | 4.0 |
| `true` | 1 | 1 | 2.5 |

`AVG` ignores the null estimate on the third task.

## Prove that the provider executed the aggregate

After running the query, inspect the provider evidence:

```bash
bash scripts/assert-pushdown.sh
```

The structural log reports:

```text
entity=TASK
mode=aggregate
aggregate_functions="[COUNT_STAR SUM AVG]"
group_by_count=1
having=true
output_rows=2
```

The provider records this shape without logging literal values, predicates, namespaces, or connection identifiers. A correct SQL result alone would not prove pushdown; the `mode=aggregate` provider event does.

Aggregate pushdown is conservative. A provider must advertise each operation it accepts, and Kubling deliberately disables this pushdown while an MVCC overlay is active.

## Automated verification

Run the result assertions and then the provider-side evidence check:

```bash
docker compose --profile test run --rm --no-deps smoke-test
bash scripts/assert-pushdown.sh
```

Static checks are available from the repository root:

```bash
bash scripts/check-provider-aggregates.sh
```

## Cleanup

```bash
docker compose down --volumes --remove-orphans
```
