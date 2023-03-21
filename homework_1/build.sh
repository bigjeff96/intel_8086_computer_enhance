#!/usr/bin/bash

set -e
CHALLENGE=data/listing_0041_add_sub_cmp_jnz 
odin build . -debug -o:minimal -use-separate-modules -show-timings -out:intel_8086.bin
echo OUTPUT:
# nasm $CHALLENGE
./intel_8086.bin $CHALLENGE > test.asm 
cat test.asm 
nasm test.asm
diff test $CHALLENGE
$CHALLENGE
