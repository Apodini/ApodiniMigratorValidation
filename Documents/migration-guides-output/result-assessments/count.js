const fs = require("fs");
const path = require("path");
const assert = require("assert");

const dir = ".";

let serviceResults = {};
let modelResults = {};
let endpointResults = {};

let files = {};

const nameLookup = {
    "migration-guide_1password_local.json": "1Password Local",
    "migration-guide_appstore_connect.json": "AppStore Connect",
    "migration-guide_aws_app_mesh.json": "AWS App Mesh",
    "migration-guide_github_enterprise_v2.json": "GH Enterprise v2",
    "migration-guide_github_enterprise_v3.json": "GH Enterprise v3",
    "migration-guide_google_adsense.json": "Google AdSense",
    "migration-guide_google_content.json": "Google Content",
    "migration-guide_google_drive.json": "Google Drive",
    "migration-guide_google_oauth2.json": "Google OAuth2",
    "migration-guide_google_translate.json": "Google Translate",
    "migration-guide_kubernetes.json": "Kubernetes",
    "migration-guide_mercedes_car_configurator.json": "MCC",
    "migration-guide_zoom.json": "Zoom"
}

function countChangeFailures(file, changes, results) {
    for (const change of changes) {
        if (!change.result) {
            console.error("[" + file + "] Entry doesn't have a failure type: " + change.id);
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
        countChangeFailures(file, json.serviceChanges, serviceResults);
    }
    if (json.modelChanges) {
        countChangeFailures(file, json.modelChanges, modelResults);
    }
    if (json.endpointChanges) {
        countChangeFailures(file, json.endpointChanges, endpointResults);
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


function countTotals(resultObject, destination) {
    let totals = 0;

    for (const [key, entry] of Object.entries(resultObject)) {
        let number = destination[key] ?? 0;
        destination[key] = number + entry;

        totals += entry;
    }

    return totals;
}


console.log("NAME & SUCCESS & CLASS. INACCURACIES & MANUAL REVIEW & ILL-CLASSIFIED RENAME & INDUCED CHANGES & TOTAL \\\\\n" +
    "\\hline\\hline")
for (const [file, results] of Object.entries(files)) {
    let totalChanges = 0;
    let totals = {};
    let name = nameLookup[file];
    assert(name != null);

    totalChanges += countTotals(results.serviceResults, totals);
    totalChanges += countTotals(results.modelResults, totals);
    totalChanges += countTotals(results.endpointResults, totals);

    function formatC() {
        let sum = 0;

        for (let i = 0; i < arguments.length; ++i) {
            sum += totals[arguments[i]] ?? 0;
        }

        return ((sum / totalChanges) * 100).toFixed(1) + " \\%";
    }

    console.log(`${name} & ${
        formatC("success", "success-duplicate")
    } & ${
        formatC("property-breaking-classification-inaccuracy")
    } & ${
        formatC("conversion-manual-adjustments")
    } & ${
        formatC("ill-classified-idchange")
    } & ${
        formatC("ill-classified-idchange-caused")
    } & ${totalChanges} \\\\`);
    console.log("\\hline");
}
