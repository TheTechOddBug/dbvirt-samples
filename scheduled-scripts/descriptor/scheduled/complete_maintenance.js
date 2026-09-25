const affectedRows = DBEngine.executeUpdatePrivileged(
    "ScheduledScriptsVDB",
    "UPDATE scheduler.MAINTENANCE_JOB " +
        "SET processed = true, execution_marker = 'privileged bundle scheduler' " +
        "WHERE id = 'maintenance-1'"
);

if (Number(affectedRows) !== 1) {
    throw new Error("Expected to update one maintenance job, updated " + affectedRows);
}
