const fs = require("fs");
const path = require("path");

const dir = ".";

let serviceResults = {};
let modelResults = {};
let endpointResults = {};

let files = {};

function countChangeFailures(changes, results) {
    for (const change of changes) {
        if (!change.result) {
            console.error("Entry doesn't have a failure type: " + change.id);
            continue;
        }

        let number = results[change.result] ?? 0;
        results[change.result] = number + 1;
    }
}

for (const file of fs.readdirSync(dir)) {
    if (!file.endsWith(".json")) {
        continue;
    }

    const fileBuffer = fs.readFileSync(path.join(dir, file));
    const json = JSON.parse(fileBuffer.toString("utf8"));

    if (json.serviceChanges) {
        countChangeFailures(json.serviceChanges, serviceResults);
    }
    if (json.modelChanges) {
        countChangeFailures(json.modelChanges, modelResults);
    }
    if (json.endpointChanges) {
        countChangeFailures(json.endpointChanges, endpointResults);
    }

    files[file] = {
        serviceResults,
        modelResults,
        endpointResults,
    };
    serviceResults = {};
    modelResults = {};
    endpointResults = {};
}


for (const [file, results] of Object.entries(files)) {
    console.log("--------------- " + file + " ---------------");
    console.log("Service Change Results: " + JSON.stringify(results.serviceResults, null, 4));
    console.log("Model Change Results: " + JSON.stringify(results.modelResults, null, 4));
    console.log("Endpoint Change Results: " + JSON.stringify(results.endpointResults, null, 4));
}
