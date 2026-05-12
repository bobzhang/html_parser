#!/usr/bin/env bash
set -euo pipefail

moon info

interface_files=()
while IFS= read -r path; do
  interface_files+=("$path")
done < <(git ls-files -- "pkg.generated.mbti" "*/pkg.generated.mbti")

if [[ "${#interface_files[@]}" -eq 0 ]]; then
  echo "No tracked pkg.generated.mbti files found." >&2
  exit 1
fi

git diff --exit-code -- "${interface_files[@]}"
