#!/usr/bin/env bash

set -e
echo BUILD:
time g++ *.cpp -o test.bin -O3 -march=native #-ggdb -fsanitize=bounds,undefined,null,address -Wall 
echo OUTPUT:
time ./test.bin
