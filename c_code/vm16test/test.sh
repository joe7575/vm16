#!/bin/sh

../../asm16/asm16.py test.asm
./bin/Release/vm16test >result.txt
echo ready.