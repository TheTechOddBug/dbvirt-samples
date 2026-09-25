import { maintenanceJobFixtures } from "../data/maintenance-jobs";

const stateKey = "scheduled_scripts_maintenance_jobs";

function readJobs() {
    if (!global.containsKey(stateKey)) {
        global.put(stateKey, JSON.stringify(maintenanceJobFixtures()));
    }

    return JSON.parse(String(global.get(stateKey)));
}

function writeJobs(jobs) {
    global.put(stateKey, JSON.stringify(jobs));
}

function applyEqualityFilters(jobs, queryFilter) {
    const filters = JSON.parse(String(queryFilter.json)).filters || [];

    return jobs.filter(function (job) {
        return filters.every(function (filter) {
            if (!Object.prototype.hasOwnProperty.call(job, filter.field)) {
                return true;
            }

            const operation = typeof filter.operation === "string"
                ? filter.operation
                : filter.operation.value;

            return operation !== "EQUAL" || String(job[filter.field]) === String(filter.value);
        });
    });
}

export default {
    select(queryFilter, resultSet) {
        resultSet.dataFormat("JSON");

        applyEqualityFilters(readJobs(), queryFilter).forEach(function (job) {
            resultSet.addRow(JSON.stringify(job));
        });
    },

    update(updateOperation, affectedRows) {
        let jobs = readJobs();

        updateOperation.jsonList.forEach(function (document) {
            const updated = JSON.parse(String(document));

            jobs = jobs.map(function (job) {
                return job.id === updated.id ? updated : job;
            });
            affectedRows.increment();
        });

        writeJobs(jobs);
    }
};
