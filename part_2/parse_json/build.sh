#!/usr/bin/env bash

set -e
echo BUILD:
time g++ *.cpp -o test.bin -O2 #-ggdb -fsanitize=bounds,undefined,null -Wall 
echo OUTPUT:
time ./test.bin
