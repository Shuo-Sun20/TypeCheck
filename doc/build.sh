#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$project_root"
mkdir -p build
if [[ ! -f build/acmart.cls || acmart-primary/acmart.dtx -nt build/acmart.cls ]]; then
  (
    cd acmart-primary
    tex -interaction=nonstopmode -output-directory=../build acmart.ins > ../build/class-generation.log
  )
fi
cd doc
TEXINPUTS="$project_root/build:${TEXINPUTS:-}" \
  latexmk -xelatex -outdir="$project_root/build" main.tex
