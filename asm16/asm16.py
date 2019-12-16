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

reCONST = re.compile(r"#(\$?[0-9a-fx]+)$")
reADDR = re.compile(r"(\$?[0-9a-fx]+)$")
reREL  = re.compile(r"([\+\-])(\$?[0-9a-fx]+)$")
reSTACK = re.compile(r"\[sp\+(\$?[0-9a-fx]+)\]$")

class Assembler(object):
    def __init__(self, fname):
        self.fname = fname
        self.fmt = "%04Xh"  #%06o"
        self.is_data = False
        self.is_text = False
        self.addr = 0
        self.lines = [] 
        self.dSymbols = {}
        for line in file(fname).readlines():
            self.lines.append(line)
        
        self.dOpcodes = {}
        for idx,s in enumerate(Opcodes):
            opc = s.split(":")[0] 
            self.dOpcodes[opc] = idx
            
        self.dOperands = {}
        for idx,s in enumerate(RegOperands):
            self.dOperands[s.lower()] = idx
            
    def value(self, s):
        if s[0] == "$":
            return int(s[1:], base=16)
        elif s[0:2] == "0x":
            return int(s[2:], base=16)
        elif s[0] == "0":
            return int(s, base=8)
        return int(s, base=10)       

    def string(self, s):
        lOut =[]
        s = s.replace("\\0", "\0")
        if s[0] == '"' and s[-1] == '"':
            for c in s[1:-1]:
                lOut.append(ord(c))
        return lOut

    def segment(self, s):
        words = s.split()
        if words[0] == ".data":
            self.is_data = True
            self.is_text = False
            return True
        elif words[0] == ".code":
            self.is_data = False
            self.is_text = False
            return True
        elif words[0] == ".text":
            self.is_data = False
            self.is_text = True
            return True
        return False
    
    def num_operands(self, opcode):
        words = Opcodes[opcode].split(":")
        num = 2
        if words[1] == "-": num -= 1
        if words[2] == "-": num -= 1
        return num

    def check_opcode(self, opcode):
        if(opcode & 0x0210) == 0x0210:
            print("Error in line %u: Invalid combination of operands" % (self.no + 1))
            sys.exit(0)

    def opcode(self, s):
        try:
            self.codes = [self.dOpcodes[s]]
            return self.num_operands(self.dOpcodes[s])
        except:
            print("Error in line %u: Invalid instruction" % (self.no + 1))
            sys.exit(0)
    
    def operand(self, s):
        try:
            opd = self.dOperands[s]
            self.codes[0] = (self.codes[0] << 5) + opd
        except:
            m = reCONST.match(s)
            if m:
                self.codes[0] = (self.codes[0] << 5) + Operands.index("IMM") 
                self.codes.append(self.value(m.group(1)))
                return
            m = reADDR.match(s)
            if m: 
                self.codes[0] = (self.codes[0] << 5) + Operands.index("IND") 
                self.codes.append(self.value(m.group(1)))
                return
            m = reREL.match(s)
            if m: 
                self.codes[0] = (self.codes[0] << 5) + Operands.index("REL") 
                if m.groups(1) == "-": 
                    self.codes.append(-self.value(m.group(2)))
                else:
                    self.codes.append(self.value(m.group(2)))
                return
            m = reSTACK.match(s)
            if m: 
                self.codes[0] = (self.codes[0] << 5) + Operands.index("[sp+n]") 
                self.codes.append(self.value(m.group(1)))
                return
            if s[0] == "#":
                if self.dSymbols.has_key(s[1:]):
                    self.codes[0] = (self.codes[0] << 5) + Operands.index("IMM")
                    self.codes.append(self.dSymbols[s[1:]])
                    return
            elif s[0] in ["+", "-"]:
                if self.dSymbols.has_key(s[1:]):
                    self.codes[0] = (self.codes[0] << 5) + Operands.index("REL") 
                    offset = (0x10000 + self.dSymbols[s[1:]] - self.addr) & 0xFFFF
                    self.codes.append(offset)
                    return
            else:
                if self.dSymbols.has_key(s):
                    self.codes[0] = (self.codes[0] << 5) + Operands.index("IND")  
                    self.codes.append(self.dSymbols[s])
                    return
            if not self.ispass2 and re.match(r"[#\+\-a-z0-9_]+", s):
                self.codes.append(0)
                return
            if self.ispass2:    
                print("Error in line %u" % (self.no + 1))
                sys.exit(0)

    def operand_correction(self, opc, opnd):
        # add the "immediate" sign to all jump instructions
        if opc in JumpInst:
            if opnd[0] not in ["+", "-", "#"]:
                opnd = "#" + opnd
        return opnd
        
    def check_num_operands(self, should, has):
        if should != has:
            print("Error in line %u: Instruction should have %u operand(s), %u given." % (self.no + 1, should, has))
            sys.exit(0)
        
    def decode(self, line):
        line = line.rstrip().lower()
        line = line.split(";")[0]
        line = line.replace(",", " ")
        if line.strip() == "": return False
        self.codes = []
        words = line.split()
        
        # new memory segment
        if self.segment(line):
            return False
        
        # address label
        if words[0][-1] == ":":
            self.dSymbols[words[0][:-1]] = self.addr
            words = words[1:]
            if len(words) == 0:
                return False
            line = line.split(" ", 1)[1]

        # text segment
        if self.is_text:
            self.codes.extend(self.string(line.strip()))
        # data segment
        elif self.is_data:
            for s in words:
                self.codes.append(self.value(s))
        # code segment
        else:
            if len(words) == 1:
                num_opnds = self.opcode(words[0])
                self.check_num_operands(0, num_opnds)
                self.codes[0] = self.codes[0] << 10
            elif len(words) == 2: # one operand
                num_opnds = self.opcode(words[0])
                self.check_num_operands(1, num_opnds)
                opnd = self.operand_correction(words[0], words[1])
                self.operand(opnd)
                self.codes[0] = self.codes[0] << 5
            elif len(words) == 3:
                num_opnds = self.opcode(words[0])
                self.check_num_operands(2, num_opnds)
                opnd1 = words[1]
                opnd2 = self.operand_correction(words[0], words[2])
                self.operand(opnd1)
                self.operand(opnd2)
            self.check_opcode(self.codes[0])
        curr_addr = self.addr
        self.addr += len(self.codes)
        return curr_addr
        
    def hexcodes(self, lData):
        lOut = []
        for idx, c in enumerate(lData):
            lOut.append("0x%04X" % c)
            if idx > 0 and idx % 8 == 0:
                lOut[-1] = "\n" + lOut[-1]
        return ", ".join(lOut)
                  
    def pass1(self):
        self.addr = 0
        self.ispass2 = False
        for self.no, line in enumerate(self.lines):
            self.decode(line)
    
    def pass2(self):
        self.addr = 0
        self.ispass2 = True
        lOut = []
        lOctals = []
        for self.no, line in enumerate(self.lines):
            addr = self.decode(line)
            if type(addr) is int:
                s1 = self.fmt % addr
                s2 = ", ".join([self.fmt % c for c in self.codes])
                s3 = "%s: %-14s" % (s1, s2)
                s4 = "%s" % self.lines[self.no].rstrip()
                lOctals.extend(self.codes)
            else:
                s4 = "%s" % self.lines[self.no].rstrip()[1:]
                s3 = ""
            if s4 != "": 
                lOut.append("%-32s ; %s" % (s3, s4))
            else:
                lOut.append("")
        hex = self.hexcodes(lOctals)
        return "\n".join(lOut), hex, len(lOctals)
            

def assembler(fname):
    print("VM16 ASSEMBLER v%s (c) 2019 by Joe\n" % VERSION)
    print(" - read %s..." % fname)
    a = Assembler(fname)
    a.pass1()
    lst, oct, size = a.pass2()

    dname = os.path.splitext(fname)[0] + ".lst"
    print(" - write %s..." % dname)
    file(dname, "wt").write(lst)

    dname = os.path.splitext(fname)[0] + ".hex"
    print(" - write %s..." % dname)
    file(dname, "wt").write(oct)

    print("\nSymbol table:")
    for key, line in a.dSymbols.items():
        print(" - %s = %u" % (key.upper(), line))

    print("Code size: %u words\n" % size)

if len(sys.argv) != 2:
    print("Syntax: asm13.py <asm-file>")
    sys.exit(0)
        
assembler(sys.argv[1])    
