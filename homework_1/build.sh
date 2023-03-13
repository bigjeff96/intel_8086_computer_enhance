#!/usr/bin/bash

set -e

odin run . -debug -o:minimal -use-separate-modules -show-timings
