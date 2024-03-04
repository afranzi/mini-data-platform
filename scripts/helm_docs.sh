#!/bin/bash

docs=($(find helms -type f -path '*/README.md' | sort -r))

for doc in "${docs[@]}"; do
  folder=$(dirname "${doc}")
  doc_folder=$(dirname "${folder}")
  mkdir -p "docs/${doc_folder}"
  cp "${doc}" "docs/${folder}.md"
done
