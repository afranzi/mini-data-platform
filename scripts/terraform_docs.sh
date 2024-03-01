#!/bin/bash

docs=($(find terraform -type f -path '*/readme.md' | sort -r))

for doc in "${docs[@]}"; do
  folder=$(dirname "${doc}")
  mkdir -p "docs/${folder}"
  cp "${doc}" "docs/${folder}.md"
done
