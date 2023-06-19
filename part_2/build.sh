#!/usr/bin/env bash

set -e
echo BUILD:
time g++ *.cpp -ggdb -fsanitize=address,bounds,undefined,null -Wall -o test
echo OUTPUT:
./test
