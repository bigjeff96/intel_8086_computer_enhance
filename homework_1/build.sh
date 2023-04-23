#!/usr/bin/bash

set -e
nasm data/listing_0049_conditional_jumps.asm 
CHALLENGE=/home/joseph/Dropbox/Projects/Performance_aware/homeworks/homework_1/data/listing_0049_conditional_jumps
echo BUILD:
time odin build . -debug -o:minimal -use-separate-modules -out:intel_8086.bin
echo OUTPUT:
# nasm $CHALLENGE
./intel_8086.bin $CHALLENGE
echo TEST_ASM:
cat test.asm 
nasm test.asm
diff test $CHALLENGE
rm test.asm test
