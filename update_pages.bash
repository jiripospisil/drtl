#!/usr/bin/bash

set -eu

wget https://github.com/tldr-pages/tldr/archive/main.zip

rm -rf pages
unzip main.zip "tldr-main/pages/*.md"
mv tldr-main/pages .
date -u +%Y-%m-%d > pages/updated_on

rmdir tldr-main
rm main.zip
