#!/usr/bin/bash

set -e

odin build . -debug -o:minimal -use-separate-modules -show-timings -out:intel_8086.bin
echo OUTPUT:
nasm data/listing_0041_add_sub_cmp_jnz.asm 
./intel_8086.bin data/listing_0041_add_sub_cmp_jnz > test.asm
nasm test.asm
diff test data/listing_0041_add_sub_cmp_jnz 
