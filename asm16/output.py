#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# VM16 Assembler v1.0
# Copyright (C) 2019 Joe <iauit@gmx.de>
#
# This file is part of VM16.

# VM16 is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# VM16 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with VM16.  If not, see <https://www.gnu.org/licenses/>.

import re
import sys
import os
import pprint
from instructions import *

def table1():
    lOut = []
    for idx, item in enumerate(Opcodes):
        opc, addr_mode1, addr_mode2 = item.split(":")
        if addr_mode1 == "-" and addr_mode2 == "-":
            lOut.append([" %-4s   " % opc, " --     ", " --     ", " %04X                  " % (idx << 10)])
        elif addr_mode1 == "NUM" and addr_mode2 == "-":
            lOut.append([" %-4s   " % opc, " %-6s " % addr_mode1, " --     ", " %04X + number (10bit) " % (idx << 10)])
        elif addr_mode1 != "-" and addr_mode2 == "-":
            lOut.append([" %-4s   " % opc, " %-6s " % addr_mode1, " --     ", " %04X + Opnd1          " % (idx << 10)])
        elif addr_mode1 == "-" and addr_mode2 != "-":
            lOut.append([" %-4s   " % opc, " --     ", " %-6s " % addr_mode2, " %04X + Opnd2          " % (idx << 10)])
        elif addr_mode1 != "-" and addr_mode2 != "-":
            lOut.append([" %-4s   " % opc, " %-6s " % addr_mode1, " %-6s " % addr_mode2, " %04X + Opnd1 + Opnd2  " % (idx << 10)])

    print("# VM16 V1.0")
    print("")
    print("### Instruction Set")
    print("")
    print("| Instr. | Opnd 1 | Opnd 2 | Opcode                |")
    print("|--------|--------|--------|-----------------------|")
    for item in lOut:
        print("|" + "|".join(item) + "|")
    print("")
    

def table2():
    print("")
    print("### Addressing Modes")
    print("")
    print("- REG = %s" % (", ".join(REG)))
    print("- MEM = %s" % (", ".join(MEM)))
    print("- ADR = %s" % (", ".join(ADR)))
    print("- CNST = %s" % (", ".join(CNST)))
    print("- DST = %s" % (", ".join(DST)))
    print("- SRC = %s" % (", ".join(SRC)))
    print("")
    

def table3():
    print("")
    print("### Opcodes")
    print("")
    
    def output(tbl1, tbl3):
        tbl2 = ["------"] * len(tbl1) 
        print("|" + "|".join(tbl1) + "|")
        print("|" + "|".join(tbl2) + "|")
        print("|" + "|".join(tbl3) + "|")
        print

    lOut1 = []
    lOut2 = []
    for idx, item in enumerate(Opcodes):
        opc, addr_mode1, addr_mode2 = item.split(":")
        lOut1.append(" %-4s " % opc)
        lOut2.append(" %04X " % (idx << 10))

    print("#### Instructions")
    print("")
    output(lOut1[0:8], lOut2[0:8])
    output(lOut1[8:16], lOut2[8:16])
    output(lOut1[16:24], lOut2[16:24])
    output(lOut1[24:32], lOut2[24:32])
         
    lOut1 = []
    lOut2 = []
    for idx, item in enumerate(Operands):
        if item == "[SP+n]":
            lOut1.append("%-4s" % item)
        else:
            lOut1.append(" %-4s " % item)
        lOut2.append(" %04X " % (idx << 5))

    print("#### Operand 1 (Opnd1)")
    print("")
    output(lOut1[0:8], lOut2[0:8])
    output(lOut1[8:16], lOut2[8:16])
    output(lOut1[16:24], lOut2[16:24])
          
    lOut1 = []
    lOut2 = []
    for idx, item in enumerate(Operands):
        if item == "[SP+n]":
            lOut1.append("%-4s" % item)
        else:
            lOut1.append(" %-4s " % item)
        lOut2.append(" %04X " % (idx))

    print("#### Operand 2 (Opnd2)")
    print("")
    output(lOut1[0:8], lOut2[0:8])
    output(lOut1[8:16], lOut2[8:16])
    output(lOut1[16:24], lOut2[16:24])
    print("")


table1()
table2()
table3()


