#!/usr/bin/env bash
set -euo pipefail

source cloudfront.env

mkdir -p tmp

for f in templates/*.tpl
do
    name=$(basename "$f" .tpl)

    envsubst < "$f" > "tmp/$name"

    echo "Rendered tmp/$name"
done
