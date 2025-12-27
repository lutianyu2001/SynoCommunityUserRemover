# SynoCommunityUserRemover

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A utility script to safely remove orphaned `sc-*` users left behind by SynoCommunity packages on Synology NAS.

## Overview

When SynoCommunity packages are uninstalled, they sometimes leave behind service users (prefixed with `sc-`) in the system. This script helps identify and safely remove these orphaned users while providing tools to audit file ownership before deletion.

## Features

- List all `sc-*` users on the system
- Scan filesystem for files owned by a specific user
- Detects running processes and installed packages before deletion

## Usage

Run directly from any directory:

```bash
chmod +x SynoCommunityUserRemover.sh
sudo ./SynoCommunityUserRemover.sh <command>
```

| Command | Description |
|---------|-------------|
| `list` | List all `sc-*` users on the system |
| `scan <user> <path>` | Find all files owned by user under path |
| `del <user>` | Dry-run: show what would be deleted |
| `del <user> --apply` | Actually delete the user and group |
| `help`, `-h`, `--help` | Show help message |

## Workflow

Recommended steps for safely removing an orphaned user:

1. **List** all `sc-*` users to identify candidates:
   ```bash
   ./SynoCommunityUserRemover.sh list
   ```

2. **Scan** for files owned by the user:
   ```bash
   sudo ./SynoCommunityUserRemover.sh scan sc-example /
   ```

3. **Review** the generated file list and decide whether to:
   - Change ownership: `tr '\n' '\0' < sc-example_owned.txt | xargs -0 chown <NEW_USER>:<NEW_GROUP>`
   - Delete files: `tr '\n' '\0' < sc-example_owned.txt | xargs -0 rm -rf`

4. **Delete** the user (dry-run first, then with `--apply`):
   ```bash
   sudo ./SynoCommunityUserRemover.sh del sc-example
   sudo ./SynoCommunityUserRemover.sh del sc-example --apply
   ```

## Compatibility

Tested on:
- Synology DSM 7.3.2-86009
- [Syncthing v1.30.0-32 from SynoCommunity](https://synocommunity.com/package/syncthing) (service user: sc-syncthing)

## License

Copyright 2025 Tianyu (Sky) Lu

The entire repository is licensed under the Apache License, Version 2.0 
(the "License"); you may not use any file in this repository except in 
compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Author

Tianyu (Sky) Lu
