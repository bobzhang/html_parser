#!/usr/bin/env bash
set -euo pipefail

moon info
git diff --exit-code -- pkg.generated.mbti cmd/main/pkg.generated.mbti
