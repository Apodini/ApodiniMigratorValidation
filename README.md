<!--

This source file is part of the Apodini open source project

SPDX-FileCopyrightText: 2022 Paul Schmiedmayer and the project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>

SPDX-License-Identifier: MIT

-->

# ApodiniMigratorValidation

[![Build](https://github.com/Apodini/ApodiniMigratorValidation/actions/workflows/build.yml/badge.svg)](https://github.com/Apodini/ApodiniMigratorValidation/actions/workflows/build.yml)
[![codecov](https://codecov.io/gh/Apodini/ApodiniMigratorValidation/branch/develop/graph/badge.svg?token=5MMKMPO5NR)](https://codecov.io/gh/Apodini/ApodiniMigratorValidation)

This project contains some utilities used within the validation of [ApodiniMigrator](https://github.com/Apodini/ApodiniMigrator).
While the tool can be applied to any set of OAS or Migration Guide documents, the [Documents](./Documents) folder of the repository
contains those documents used within our validation of the Apodini Migrator.
The [Migration Guide Results Assessments](./Documents/migration-guides-output/result-assessments/README.md) guide
provides detailed information about our approach of assessing the quality of the those Migration Guides.

It contains a command line utility to:
* Convert an OpenAPI Specification (3.x) document to an ApodiniMigrator APIDocument.
* Calculate statistics of a ApodiniMigrator MigrationGuide document.
* Generate a MigrationGuide from two OAS documents and print stats in latex table format.
  This may be done for individual pairs of documents or in bulk for all documents collected in the
  [Documents](./Documents) folder.

## Installation

To run the util clone the repository and have a swift toolchain ready.

Then you can execute the util as follows:
```commandline
swift run ApodiniMigratorValidationUtil [arguments...] 
```

## Usage

When not supplying any arguments you will be presented the following help page:

```commandline
OVERVIEW: Utilities used for the validation of ApodiniMigrator.

USAGE: validation-util <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  convert                 Convert OpenAPI Specification documents to ApodiniMigrator APIDocuments.
  stats                   Print stats about a ApodiniMigrator MigrationGuide.
  e2e                     Convert two OAS documents, generate the MigrationGuide and output the latex table contents for the paper.
  e2e-bulk                Convert multiple OAS documents, generate the MigrationGuide and output the latex table contents for the paper.

  See 'validation-util help <subcommand>' for detailed help.
```

### OAS to APIDocument Conversion

The `convert` subcommand can be used to convert OpenAPI Specification (3.x) documents to
ApodiniMigrator APIDocuments.
You need to specify an OAS input file (`yaml` or `json` format) and a location to write the resulting APIDocument.

The help page of the subcommand looks as follows:

```commandline
OVERVIEW: Convert OpenAPI Specification documents to ApodiniMigrator APIDocuments.

USAGE: validation-util convert --input <input> --output <output>

OPTIONS:
  -i, --input <input>     The OpenAPI Specification document used as the input. 
  -o, --output <output>   The destination to write the resulting API Document. 
  -h, --help              Show help information.
```

### MigrationGuide Stats

The `stats` subcommand can be used to gather statistics of a MigrationGuide document.

Below is the help page of the subcommand:

```commandline
OVERVIEW: Print stats about a ApodiniMigrator MigrationGuide.

USAGE: validation-util stats --input <input> [--latex-table]

OPTIONS:
  -i, --input <input>     The MigrationGuide you want to analyze. 
  -l, --latex-table       Print the stats in the latex table format. 
  -h, --help              Show help information.
```

Below is an example output how the resulting statistics are presented:
```commandline
--------------------------- SUMMARY ---------------------------
-- SERVICE
  - ADDITION:  0        (breaking: 0, unsolvable: 0)
  - REMOVAL:   0        (breaking: 0, unsolvable: 0)
  - UPDATE:    3        (breaking: 2, unsolvable: 0)
  - IDCHANGE:  0        (breaking: 0, unsolvable: 0)
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  TOTAL:       3        (breaking: 2 unsolvable: 0)
-- ENDPOINTS
  - ADDITION:  3        (breaking: 0, unsolvable: 0)
  - REMOVAL:   1        (breaking: 1, unsolvable: 1)
  - UPDATE:    37       (breaking: 35, unsolvable: 0)
  - IDCHANGE:  0        (breaking: 0, unsolvable: 0)
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  TOTAL:       41       (breaking: 36 unsolvable: 1)
-- MODELS
  - ADDITION:  4        (breaking: 0, unsolvable: 0)
  - REMOVAL:   1        (breaking: 0, unsolvable: 1)
  - UPDATE:    51       (breaking: 49, unsolvable: 0)
  - IDCHANGE:  0        (breaking: 0, unsolvable: 0)
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  TOTAL:       56       (breaking: 49 unsolvable: 1)
-- SCRIPTS
  - scripts:     30     (type conversions)
  - jsonValues:  8      (default/fallback values)
  - objectJSONS: 11     (input for decoding tests)
---------------------------------------------------------------
```

### E2E

The `e2e` type of subcommands are used to generate the data used within the paper
in latex format such that it can be easy copied and pasted into the paper source code.

There exists two different kinds of `e2e` subcommands:
* `e2e` used for oneshot operations on a single pair of OAS documents.
* `e2e-bulk` used to generate data for multiple OAS documents (located in the
  [Documents](https://github.com/Apodini/ApodiniMigratorValidation/tree/develop/Documents) folder by default).

#### E2E OneShot

The help page for the subcommand looks like the following:

```commandline
OVERVIEW: Convert two OAS documents, generate the MigrationGuide and output the latex table contents for the paper.

USAGE: validation-util e2e --previous <previous> --current <current>

OPTIONS:
  --previous <previous>   The OpenAPI Specification document used as the input. 
  --current <current>     The OpenAPI Specification document used as the input. 
  -h, --help              Show help information.
```

#### E2E Bulk

The help page for the subcommand looks like the following:

```commandline
OVERVIEW: Convert multiple OAS documents, generate the MigrationGuide and output the latex table contents for the paper.

USAGE: validation-util e2e-bulk [--documents <documents>] [--output-migration-guides]

OPTIONS:
  -d, --documents <documents>
                          Folder containing bulk of OAS documents and a `document.json` index file. (default: ./Documents)
  -o, --output-migration-guides
                          When specified, MigrationGuides will be written to the `migration-guides-output` directory. 
  -h, --help              Show help information.

```

## Contributing
Contributions to this project are welcome. Please make sure to read the [contribution guidelines](https://github.com/Apodini/.github/blob/main/CONTRIBUTING.md) and the [contributor covenant code of conduct](https://github.com/Apodini/.github/blob/main/CODE_OF_CONDUCT.md) first.

## License
This project is licensed under the MIT License. See [Licenses](https://github.com/Apodini/ApodiniMigratorValidation/tree/develop/LICENSES) for more information.
