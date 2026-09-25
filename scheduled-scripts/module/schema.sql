CREATE FOREIGN TABLE MAINTENANCE_JOB
(
    id string NOT NULL,
    processed boolean NOT NULL,
    execution_marker string NOT NULL,

    PRIMARY KEY(id)
)
OPTIONS(
    updatable true,
    supports_idempotency false,
    ANNOTATION 'Maintenance state updated by the descriptor bundle scheduler'
);
