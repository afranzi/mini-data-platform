#!/bin/bash

docs=($(find terraform -type f -path '*/readme.md' | sort -r))

for doc in "${docs[@]}"; do
  folder=$(dirname "${doc}")
  doc_folder=$(dirname "${folder}")
  mkdir -p "docs/${doc_folder}"
  cp "${doc}" "docs/${folder}.md"
done
