#!/bin/sh

../../asm16/asm16.py test.asm
./bin/Release/vm16test >result.txt
meld result.txt result.ref
echo ready.