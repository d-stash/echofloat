#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/ci.yml"

if /usr/bin/grep -n '\<rtk\>' "$WORKFLOW"; then
    echo "GitHub Actions workflow must not depend on rtk." >&2
    exit 1
fi

echo "Workflow checks passed"
