#!/usr/bin/bash

set -e
nasm data/listing_0040_challenge_movs.asm 
CHALLENGE=/home/joseph/Dropbox/Projects/Performance_aware/homeworks/homework_1/data/listing_0040_challenge_movs
odin build . -debug -o:minimal -use-separate-modules -show-timings -out:intel_8086.bin
echo OUTPUT:
# nasm $CHALLENGE
./intel_8086.bin $CHALLENGE > test.asm 
cat test.asm 
nasm test.asm
diff test $CHALLENGE
