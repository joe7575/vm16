#!/usr/bin/env python3
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

reLABEL = re.compile(r"^([A-Za-z_][A-Za-z_0-9]+):")
reCONST = re.compile(r"#(\$?[0-9A-Fa-fx]+)$")
reADDR = re.compile(r"(\$?[0-9A-Fa-fx]+)$")
reREL  = re.compile(r"([\+\-])(\$?[0-9A-Fa-fx]+)$")
reSTACK = re.compile(r"\[SP\+(\$?[0-9A-Fa-fx]+)\]$")
reINCL =  re.compile(r'^\$include +"(.+?)"')
reFILEINFO = re.compile(r'^#### include "(.+?)" ([0-9]+)')
reEQUALS = re.compile(r"^([A-Za-z_][A-Za-z_0-9]+) *= *(\S+)")

def import_file(fname):
    """
    Is called recursive to handle includes
    """
    def handle_includes(idx, fname, line):
        m = reINCL.match(line)
        if m:
            path = os.path.dirname(fname)
            inc_file = os.path.join(path, m.group(1))
            print(" - import %s..." % inc_file)
            lines = ['#### include "%s" %u START ################################' % (inc_file, 0)]
            lines.extend(import_file(inc_file))
            lines.append('#### include "%s" %u END ################################' % (fname, idx+1))
            return lines
        return [line]
        
    if not os.path.exists(fname):
        print("Error: File '%s' does not exist" % fname)
        sys.exit(0)
    lines = []
    for idx, line in enumerate(open(fname).readlines()):
        lines.extend(handle_includes(idx, fname, line))
    return lines
  

class Assembler(object):
    def __init__(self, fname):
        self.fname = fname
        self.fmt = "%04Xh"  #%06o"
        self.is_data = False
        self.is_text = False
        self.addr = 0
        self.labelprefix = 0
        self.dSymbols = {}
        self.dAliases = {}
        self.lines = import_file(fname)
        self.dOpcodes = {}
        for idx,s in enumerate(Opcodes):
            opc = s.split(":")[0] 
            self.dOpcodes[opc] = idx
            
        self.dOperands = {}
        for idx,s in enumerate(RegOperands):
            self.dOperands[s] = idx

    def error(self, err):
        print("Error in file '%s', line %u:\n%s" % (self.fname, self.lineno, err))
        sys.exit(-1)
        
    def value(self, s):
        try:
            if s[0] == "$":
                return int(s[1:], base=16)
            elif s[0:2] == "0x":
                return int(s[2:], base=16)
            elif s[0] == "0":
                return int(s, base=8)
            return int(s, base=10)
        except:
            self.error("Invalid operand '%s'" % s)
            
    def string(self, s):
        lOut =[]
        s = s.replace("\\0", "\0")
        s = s.replace("\\n", "\n")
        if s[0] == '"' and s[-1] == '"':
            for c in s[1:-1]:
                lOut.append(ord(c))
        return lOut
    
    def add_label_prefix(self, label):
        if label.islower(): # local label
            return "%u_%s" % (self.labelprefix, label)
        return label
    
    def rmv_label_prefix(self, label):
        if label.islower(): # local label
            return label.split("_", 1)[1]
        return label
    
    def add_sym_addr(self, label, addr):
        if not label.islower(): # global label
            self.labelprefix += 1
            if label in self.dSymbols and not self.ispass2:
                self.error("Label '%s' used twice" % label)
            self.dSymbols[label] = addr
        else:
            label = self.add_label_prefix(label)
            if label in self.dSymbols and not self.ispass2:
                self.error("Label '%s' used twice" % label)
            self.dSymbols[label] = addr
            
    def get_sym_addr(self, label):
        if not label.islower(): # global label
            self.labelprefix += 1
            if label in self.dSymbols:
                return self.dSymbols[label]
        else:
            label2 = self.add_label_prefix(label)
            if label2 in self.dSymbols:
                return self.dSymbols[label2]
        if self.ispass2:
            self.error("Invalid/unknown operand '%s'" % label)
        return 0
            
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
        elif words[0] == ".org" and len(words) > 1:
            if self.codes != []:
                self.error("Keyword '.org' is on wrong position")
                
            self.addr = self.value(words[1])
            self.start_addr = self.addr
            return True
        return False
    
    def num_operands(self, opcode):
        words = Opcodes[opcode].split(":")
        num = 2
        if words[1] == "-": num -= 1
        if words[2] == "-": num -= 1
        return num

    def check_opcode(self, opcode):
        #if(opcode & 0x0210) == 0x0210:
        #    self.error("Invalid combination of operands")
        pass

    def opcode(self, s):
        try:
            self.codes = [self.dOpcodes[s]]
            return self.num_operands(self.dOpcodes[s])
        except:
            self.error("Invalid instruction")
    
    def operand(self, s):
        if s[0] == "#":
            if s[1:] in self.dAliases:
                s = "#" + self.dAliases[s[1:]]
        else:
            if s in self.dAliases:
                s = self.dAliases[s]
        try:
            opd = self.dOperands[s]
            self.codes[0] = (self.codes[0] << 5) + opd
            return opd
        except:
            m = reCONST.match(s)
            if m:
                self.codes[0] = (self.codes[0] << 5) + Operands.index("IMM") 
                self.codes.append(self.value(m.group(1)))
                return Operands.index("IMM")
            m = reADDR.match(s)
            if m: 
                self.codes[0] = (self.codes[0] << 5) + Operands.index("IND") 
                self.codes.append(self.value(m.group(1)))
                return Operands.index("IND")
            m = reREL.match(s)
            if m: 
                self.codes[0] = (self.codes[0] << 5) + Operands.index("REL") 
                if m.group(1) == "-": 
                    offset = (0x10000 - self.value(m.group(2))) & 0xFFFF
                    self.codes.append(offset)
                else:
                    self.codes.append(self.value(m.group(2)))
                return Operands.index("REL")
            m = reSTACK.match(s)
            if m: 
                self.codes[0] = (self.codes[0] << 5) + Operands.index("[SP+n]") 
                self.codes.append(self.value(m.group(1)))
                return Operands.index("[SP+n]")
            if s[0] == "#":
                self.codes[0] = (self.codes[0] << 5) + Operands.index("IMM")
                addr = self.get_sym_addr(s[1:])
                self.codes.append(addr)
                return
            elif s[0] in ["+", "-"]:
                self.codes[0] = (self.codes[0] << 5) + Operands.index("REL")
                addr = self.get_sym_addr(s[1:]) 
                offset = (0x10000 + addr - self.addr - 2) & 0xFFFF
                self.codes.append(offset)
                return Operands.index("REL")
            else:
                self.codes[0] = (self.codes[0] << 5) + Operands.index("IND")
                addr = self.get_sym_addr(s)  
                self.codes.append(addr)
                return Operands.index("IND")
            if not self.ispass2 and re.match(r"[#\+\-A-Fa-z0-9_]+", s):
                self.codes.append(0)
                return Operands.index("IMM")
            if self.ispass2:    
                self.error("Invalid/unknown operand '%s'" % s)

    def operand_correction(self, opc, opnd):
        # add the "immediate" sign to all jump instructions
        if opc in JumpInst:
            if opnd[0] not in ["+", "-", "#"]:
                opnd = "#" + opnd
        return opnd
        
    def check_operand_type(self, instr, opnd1, opnd2):
        opcode = self.dOpcodes[instr]
        words = Opcodes[opcode].split(":")
        if words[1] != "-":
            validOpnds = globals()[words[1]]
            if opnd1 != None and Operands[opnd1] not in validOpnds:
                self.error("Invalid operand1 type")
        if words[2] != "-":
            validOpnds = globals()[words[2]]
            if opnd2 != None and Operands[opnd2] not in validOpnds:
                self.error("Invalid operand2 type")
        
    def check_num_operands(self, should, has):
        if should != has:
            self.error("Instruction should have %u operand(s), %u given" % (should, has))
        
    def decode(self, line):
        line = line.rstrip()
        line = line.split(";")[0]
        line = line.replace(",", " ")
        if line.strip() == "": return False
        self.codes = []
        words = line.split()
        
        # new memory segment
        if self.segment(line):
            return False

        # file re-synchronization
        m = reFILEINFO.match(line)
        if m:
            self.fname = m.group(1)
            self.lineno = int(m.group(2))
            return False
        
        # address label
        m = reLABEL.match(line)
        if m:
            self.add_sym_addr(m.group(1), self.addr)
            if len(words) == 1:
                return False
            words = words[1:]
            line = line.split(" ", 1)[1]
            
        # aliases
        m = reEQUALS.match(line)
        if m:
            self.dAliases[m.group(1)] = m.group(2)
        # text segment
        elif self.is_text:
            self.codes.extend(self.string(line.strip()))
        # data segment
        elif self.is_data:
            for s in words:
                self.codes.append(self.value(s))
        # code segment
        else:
            if len(words) == 1:
                num_opnds = self.opcode(words[0])
                self.check_num_operands(num_opnds, 0)
                self.codes[0] = self.codes[0] << 10
            elif len(words) == 2: # one operand
                if words[0] in self.dOpcodes and self.dOpcodes[words[0]] < 4: # special opcode handling
                    self.opcode(words[0])
                    num_opnds = 1
                    num = self.value(words[1]) % 1024
                    self.codes[0] = (self.codes[0] << 10) | num
                else:
                    num_opnds = self.opcode(words[0])
                    opnd = self.operand_correction(words[0], words[1])
                    type1 = self.operand(opnd)
                    self.check_operand_type(words[0], type1, None)
                    self.codes[0] = self.codes[0] << 5
            elif len(words) == 3:
                num_opnds = self.opcode(words[0])
                self.check_num_operands(num_opnds, 2)
                opnd1 = words[1]
                opnd2 = self.operand_correction(words[0], words[2])
                type1 = self.operand(opnd1)
                type2 = self.operand(opnd2)
                self.check_operand_type(words[0], type1, type2)
            else:
                self.error("Invalid syntax '%s'" % line.strip())
            if self.codes != []:
                self.check_opcode(self.codes[0])
        curr_addr = self.addr
        self.addr += len(self.codes)
        return curr_addr
        
    def hexcodes(self, lData):
        lOut = []
        for idx, c in enumerate(lData):
            lOut.append("%04X" % c)
            #if idx > 0 and idx % 8 == 0:
            #    lOut[-1] = "\n" + lOut[-1]
        return " ".join(lOut)
                  
    def hexcodes2(self, lData):
        lOut = []
        for idx, c in enumerate(lData):
            lOut.append("0x%04X" % c)
            if idx > 0 and idx % 8 == 0:
                lOut[-1] = "\n" + lOut[-1]
        return ", ".join(lOut)
                  
    def pass1(self):
        self.addr = 0
        self.start_addr = 0
        self.ispass2 = False
        self.lineno = 1
        self.labelprefix = 0
        for line in self.lines:
            self.decode(line)
            self.lineno += 1
    
    def pass2(self):
        self.addr = 0
        self.ispass2 = True
        self.lineno = 1
        self.labelprefix = 0
        lOut = []
        lOctals = []
        for line in self.lines:
            addr = self.decode(line)
            if type(addr) is int:
                s1 = self.fmt % addr
                s2 = ", ".join([self.fmt % c for c in self.codes])
                s3 = "%s: %-14s" % (s1, s2)
                s4 = "%s" % line.rstrip()
                lOctals.extend(self.codes)
            else:
                s4 = "%s" % line.rstrip()[1:]
                s3 = ""
            if s4 != "": 
                lOut.append("%-32s %s" % (s3, s4))
            else:
                lOut.append("")
            self.lineno += 1
        hex1 = self.hexcodes(lOctals)
        hex2 = self.hexcodes2(lOctals)
        return "\n".join(lOut), hex1, hex2, len(lOctals)
            

def assembler(fname):
    print("VM16 ASSEMBLER v%s (c) 2019 by Joe\n" % VERSION)
    print(" - read %s..." % fname)
    a = Assembler(fname)
    a.pass1()
    lst, hex1, hex2, size = a.pass2()

    dname = os.path.splitext(fname)[0] + ".lst"
    print(" - write %s..." % dname)
    open(dname, "wt").write(lst)

    dname = os.path.splitext(fname)[0] + ".hex"
    print(" - write %s..." % dname)
    open(dname, "wt").write(hex1)

    dname = os.path.splitext(fname)[0] + ".txt"
    print(" - write %s..." % dname)
    open(dname, "wt").write(hex2)

    print("\nSymbol table:")
    items = []
    for key, addr in a.dSymbols.items():
        if not key.islower():
            items.append((key, addr))
    items.sort(key=lambda item: item[1])
    for item in items:
        print(" - %-16s = %04X" % (item[0], item[1]))

    print("")
    print("Code start address: $%04X" % a.start_addr)
    print("Code size: $%04X/%u words\n" % (size, size))

if len(sys.argv) != 2:
    print("Syntax: asm13.py <asm-file>")
    sys.exit(0)
        
assembler(sys.argv[1])    
