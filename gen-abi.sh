#!/bin/bash

for file in out/**/*.json
do
  filename=$(basename "$file" .json)
  jq .abi "$file" > "abis/${filename}.abi.json"
done