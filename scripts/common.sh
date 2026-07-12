#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/Resona.xcodeproj}"
SCHEME="${SCHEME:-Resona}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro,OS=latest}"

export ROOT_DIR PROJECT_PATH SCHEME CONFIGURATION DERIVED_DATA_PATH DESTINATION
