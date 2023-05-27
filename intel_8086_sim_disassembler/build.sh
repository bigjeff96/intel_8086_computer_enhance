#!/usr/bin/bash

set -e
nasm data/listing_0054_draw_rectangle.asm 
CHALLENGE=/home/joseph/Dropbox/Projects/Performance_aware/homeworks/homework_1/data/listing_0054_draw_rectangle
echo BUILD:
time odin build . -o:speed -debug -use-separate-modules -out:intel_8086.bin
echo OUTPUT:
# nasm $CHALLENGE
./intel_8086.bin $CHALLENGE > bob.txt
echo TEST_ASM:
cat test.asm 
nasm test.asm
diff test $CHALLENGE
rm test.asm test
