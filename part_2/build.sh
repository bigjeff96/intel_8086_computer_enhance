#!/usr/bin/env bash

set -e
echo BUILD:
time g++ *.cpp -o test.bin -ggdb -fsanitize=bounds,undefined,null,address -Wall 
echo OUTPUT:
time ./test.bin
