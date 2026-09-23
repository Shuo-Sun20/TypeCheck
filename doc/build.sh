#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p build
if [[ ! -f build/acmart.cls || acmart-primary/acmart.dtx -nt build/acmart.cls ]]; then
  (
    cd acmart-primary
    tex -interaction=nonstopmode -output-directory=../build acmart.ins > ../build/class-generation.log
  )
fi
TEXINPUTS="./build:${TEXINPUTS:-}" latexmk -xelatex -outdir=build doc/main.tex
