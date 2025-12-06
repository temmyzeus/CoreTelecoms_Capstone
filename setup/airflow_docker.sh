#!/usr/bin/bash

# Get the full path of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the parent directory
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"

# Move to parent directory
cd "$PARENT_DIR" || exit 1

mkdir -p ./dags ./logs ./plugins ./config
echo -e "AIRFLOW_UID=$(id -u)" > .env
