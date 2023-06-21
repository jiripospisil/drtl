#!/usr/bin/bash

set -eu

wget https://github.com/tldr-pages/tldr/archive/main.zip

rm -rf pages
unzip main.zip "tldr-main/pages/*.md"
mv tldr-main/pages .

date -u +%Y-%m-%d > pages/updated_on
echo "These pages are copied from https://github.com/tldr-pages/tldr and are licensed under the Creative Commons Attribution 4.0 International License (CC-BY)." > pages/README

rmdir tldr-main
rm main.zip
