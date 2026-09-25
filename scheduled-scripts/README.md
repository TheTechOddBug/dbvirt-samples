# Bundle-level Scheduled Scripts Sample

This sample shows how a descriptor bundle schedules trusted JavaScript automation that executes SQL through Kubling's `DBEngine` binding.

The schedule belongs to the main descriptor bundle, next to the VDB declarations:

```yaml
scheduledScripts:
  - scriptFilePath: "scheduled/complete_maintenance.js"
    cron: "0/2 * * * * *"
```

Every two seconds, the script calls `DBEngine.executeUpdatePrivileged` to update one deterministic maintenance row. The JavaScript data source in this sample only makes that SQL effect observable; it does not own or execute the schedule.

This differs from the [module initialization and scheduling sample](../initializer/README.md), where lifecycle scripts belong to a loaded module and work directly with that module's shared state.

## Source map

- `descriptor/bundle-info.yaml` declares the bundle-level schedule.
- `descriptor/scheduled/complete_maintenance.js` performs the explicit privileged SQL update.
- `descriptor/vdb/ScheduledScriptsVDB.yaml` loads the small state module as the `scheduler` data source.
- `module/handler/MAINTENANCE_JOB.js` persists the updated row in module-owned state.
- `scripts/smoke-test.sh` waits for the scheduled effect and verifies it.

## Prerequisites

- Git
- Docker Engine
- Docker Compose v2

## Start

```bash
cd scheduled-scripts
docker compose up --wait
```

Compose generates both bundles with the official Kubling CLI image. Generated ZIP files live only in a named volume and are not committed.

When the stack is ready:

- Kubling Studio: <http://localhost:8282/console>
- Health endpoint: <http://localhost:8282/observe/health>
- VDB: `ScheduledScriptsVDB`
- schema/data source: `scheduler`
- table: `MAINTENANCE_JOB`

## Observe the scheduled update

Open Kubling Studio and run:

```sql
SELECT id, processed, execution_marker
FROM scheduler.MAINTENANCE_JOB
WHERE id = 'maintenance-1';
```

Within two seconds of startup, the row becomes:

| id | processed | execution_marker |
|:--|:--|:--|
| `maintenance-1` | `true` | `privileged bundle scheduler` |

The module fixture starts with `processed = false` and `execution_marker = 'not executed'`. The descriptor-level script is the only code that changes it.

## Security boundary

`executeUpdatePrivileged` uses Kubling's internal engine session and does not depend on a request-scoped user. Descriptor bundles containing privileged scripts are trusted deployment artifacts and should be reviewed like application code.

Normal methods such as `DBEngine.executeUpdate` remain on the authenticated execution path; Kubling does not silently promote them to privileged operations.

## Automated verification

Run the same polling assertion used by CI:

```bash
docker compose --profile test run --rm --no-deps smoke-test
```

Static checks are available from the repository root:

```bash
bash scripts/check-scheduled-scripts.sh
```

## Cleanup

```bash
docker compose down --volumes --remove-orphans
```
