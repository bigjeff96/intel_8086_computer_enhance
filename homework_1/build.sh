#!/usr/bin/bash

set -e

odin build . -debug -o:minimal -use-separate-modules -show-timings -out:test.bin
echo OUTPUT:
./test.bin
