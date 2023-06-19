#!/usr/bin/env bash

set -e
echo BUILD:
time g++ *.cpp -o test -O3 -ffast-math #-ggdb -fsanitize=bounds,undefined,null -Wall 
echo OUTPUT:
time ./test
