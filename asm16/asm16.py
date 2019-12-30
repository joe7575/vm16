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
from copy import copy
from array import array

reLABEL = re.compile(r"^([A-Za-z_][A-Za-z_0-9]+):")
reCONST = re.compile(r"#(\$?[0-9A-Fa-fx]+)$")
reADDR = re.compile(r"(\$?[0-9A-Fa-fx]+)$")
reREL  = re.compile(r"([\+\-])(\$?[0-9A-Fa-fx]+)$")
reSTACK = re.compile(r"\[SP\+(\$?[0-9A-Fa-fx]+)\]$")
reINCL =  re.compile(r'^\$include +"(.+?)"')
reEQUALS = re.compile(r"^([A-Za-z_][A-Za-z_0-9]+) *= *(\S+)")

lFileList = []

# Token tuple indexes
FILEREF = 0
LINENUM = 1
LINESTR = 2
LINETYPE = 3
LABELPREFIX = 4
ADDRESS = 5
INSTRSIZE = 6
INSTRWORDS = 7
OPCODES = 8

# Segment types
CODETYPE = 0
WTEXTTYPE = 1
BTEXTTYPE = 2
DATATYPE = 3
COMMENT = 4

def load_file(path, fname):
    """
    Read ASM file with all include files.
    Function is called recursively to handle includes.
    Return a token list with (file-ref, line-no, line-string) 
    """
    global lFileList
    
    if not os.path.exists(fname):
        print("Error: File '%s' does not exist" % fname)
        sys.exit(0)
    if fname not in lFileList:
        file_ref = len(lFileList)
        lFileList.append(fname)
    lToken = []
    lToken.append((file_ref, 0, ""))
    lToken.append((file_ref, 0, ";################ File: %s ################" % fname))
    for idx, line in enumerate(open(fname).readlines()):
        # include files
        m = reINCL.match(line)
        if m:
            inc_file = os.path.join(path, m.group(1))
            print(" - import %s..." % m.group(1))
            lToken.extend(load_file(path, inc_file))
        else:
            lToken.append((file_ref, idx+1, line))
    return lToken

class AsmBase(object):
    def error(self, err):
        fname = lFileList[self.token[FILEREF]]
        lineno = self.token[LINENUM]
        print("Error in file '%s', line %u:\n%s" % (fname, lineno, err))
        sys.exit(-1)
    
    def prepare_opcode_tables(self):
        self.dOpcodes = {}
        self.dOperands = {}
        for idx,s in enumerate(Opcodes):
            opc = s.split(":")[0] 
            self.dOpcodes[opc] = idx
        for idx,s in enumerate(RegOperands):
            self.dOperands[s] = idx

    def string(self, s):
        lOut =[]
        s = s.replace("\\0", "\0")
        s = s.replace("\\n", "\n")
        if s[0] == '"' and s[-1] == '"':
            for c in s[1:-1]:
                lOut.append(ord(c))
        return lOut
    
    def byte_string(self, s):
        list_get = lambda l, idx: l[idx] if len(l) > idx else ' '
        lOut =[]
        s = s.replace("\\0", "\0")
        s = s.replace("\\n", "\n")
        if s[0] == '"' and s[-1] == '"':
            for idx in range(1, len(s) - 1, 2):
                val = ord(list_get(s,idx)) + (ord(list_get(s, idx+1)) << 8) 
                lOut.append(val)
        return lOut
    
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
            if label in self.dSymbols:
                self.error("Label '%s' used twice" % label)
            self.dSymbols[label] = addr
        else:
            label = self.add_label_prefix(label)
            if label in self.dSymbols:
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
            

class AsmPass1(AsmBase):
    """
    Work on the given token list:
    - feed aliases table
    - feed symbol table
    - determine instruction size (num words)
    - return the enriched token list (file-ref, line-no, line-string, line-type, 
                                      address, instr-size, instr-words)
    """
    def __init__(self):
        self.segment_type = CODETYPE
        self.addr = 0
        self.labelprefix = 0
        self.dSymbols = {}
        self.dAliases = {}
        self.prepare_opcode_tables()

    def directive(self, s):
        words = s.split()
        if words[0] == ".data":
            self.segment_type = DATATYPE
            return True
        elif words[0] == ".code":
            self.segment_type =CODETYPE
            return True
        elif words[0] == ".text":
            self.segment_type = WTEXTTYPE
            return True
        elif words[0] == ".btext":
            self.segment_type = BTEXTTYPE
            return True
        elif words[0] == ".org" and len(words) > 1:
            self.addr = self.value(words[1])
            return True
        return False

    def tokenize(self, size, words):
        token = (self.token[FILEREF], self.token[LINENUM], self.token[LINESTR],
                 self.segment_type, self.labelprefix, self.addr, size, words)
        self.addr += size
        return token
       
    def comment(self):
        return (self.token[FILEREF], self.token[LINENUM], self.token[LINESTR],
                COMMENT, 0, 0, 0, [])

    def operand_size(self, s):
        if not s: return 0
        if s in self.dAliases: s = self.dAliases[s]
        if s in ["#0", "#1", "#$0", "#$1"]: return 0
        if s[0] in ["#", "+", "-"]: return 1
        if s in self.dOperands: return 0
        return 1
        
    def operand_correction(self, words):
        # add the "immediate" sign to all jump instructions
        if words[0] in JumpInst:
            if len(words) == 3:
                if words[2][0] not in ["+", "-", "#"]:
                    words[2] = "#" + words[2]
            elif len(words) == 2:
                if words[1][0] not in ["+", "-", "#"]:
                    words[1] = "#" + words[1]
        return words
        
    def decode(self):
        list_get = lambda l, idx: l[idx] if len(l) > idx else None
            
        line = self.token[LINESTR]
        line = line.split(";")[0].rstrip()
        line = line.replace(",", " ")
        line = line.replace("\t", "    ")
        if line.strip() == "": 
            return self.comment()
        words = line.split()
        # assembler directive
        if self.directive(line):
            return False
        # aliases
        m = reEQUALS.match(line)
        if m:
            self.dAliases[m.group(1)] = m.group(2)
            return False
        # address label
        m = reLABEL.match(line)
        if m:
            self.add_sym_addr(m.group(1), self.addr)
            if len(words) == 1:
                return False
            words = words[1:]
            line = line.split(" ", 1)[1]
        # text segment
        if self.segment_type == WTEXTTYPE:
            s = self.string(line.strip())
            return self.tokenize(len(s), s)
        if self.segment_type == BTEXTTYPE:
            s = self.byte_string(line.strip())
            return self.tokenize(len(s), s)
        # data segment
        if self.segment_type == DATATYPE:
            l = []
            for s in words:
                l.append(self.value(s))
            return self.tokenize(len(l), l)
        # code segment
        if words[0] not in self.dOpcodes:
            self.error("Invalid syntax '%s'" % line.strip())
        opcode = self.dOpcodes[words[0]]
        if len(words) == 2 and opcode < 4: # special handling
            size = 1
        else:
            words = self.operand_correction(words)
            size = 1 + self.operand_size(list_get(words, 1)) + self.operand_size(list_get(words, 2))
        return self.tokenize(size, words)    

    def run(self, fname):
        path = os.path.dirname(fname)
        lToken = load_file(path, fname)
        lNewToken = []
        for self.token in lToken:
            token = self.decode()
            if token:
                lNewToken.append(token)
        return lNewToken

class AsmPass2(AsmBase):
    """
    Work on the given token list:
    - determine opcodes
    - return the enriched token list (file-ref, line-no, line-string, line-type, 
                                      address, instr-size, instr-words, opcodes)
    """
    def __init__(self, dSymbols, dAliases):
        self.labelprefix = 0
        self.ispass2 = True
        self.dSymbols = dSymbols
        self.dAliases = dAliases
        self.prepare_opcode_tables()

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
    
    def aliases(self, s):    
        if s[0] == "#":
            if s[1:] in self.dAliases:
                s = "#" + self.dAliases[s[1:]]
        else:
            if s in self.dAliases:
                s = self.dAliases[s]
        return s

    def operand(self, s):
        if not s: return 0, None
        s = self.aliases(s)
        if s in self.dOperands:
            return self.dOperands[s], None
        if s == "#$0": return Operands.index("#0"), None
        if s == "#$1": return Operands.index("#1"), None
        m = reCONST.match(s)
        if m: return Operands.index("IMM"), self.value(m.group(1))
        m = reADDR.match(s)
        if m: return Operands.index("IND"), self.value(m.group(1))
        m = reREL.match(s)
        if m: 
            if m.group(1) == "-": 
                offset = (0x10000 - self.value(m.group(2))) & 0xFFFF
            else:
                offset = self.value(m.group(2))
            return Operands.index("REL"), offset
        m = reSTACK.match(s)
        if m: return Operands.index("[SP+n]"), self.value(m.group(1))
        if s[0] == "#": return Operands.index("IMM"), self.get_sym_addr(s[1:]) 
        if s[0] in ["+", "-"]:
            dst_addr = self.get_sym_addr(s[1:])
            src_addr = self.token[ADDRESS]  
            offset = (0x10000 + dst_addr - src_addr - 2) & 0xFFFF
            return Operands.index("REL"), offset
        return Operands.index("IND"), self.get_sym_addr(s) 
        
    def get_opcode(self, instr):
        if instr not in self.dOpcodes:
            self.error("Invalid instruction '%s'" % instr)
        opc1 = self.dOpcodes[instr]
        num_opnds = 2 - Opcodes[opc1].count("-") 
        num_has = len(self.token[INSTRWORDS]) - 1
        if num_opnds != num_has:
            self.error("Instruction should have %u operand(s), %u given" % (num_opnds, num_has))
        return opc1 
    
    def tokenize(self, code):
        token = (self.token[FILEREF], self.token[LINENUM], self.token[LINESTR],
                 self.token[LINETYPE], self.token[LABELPREFIX], self.token[ADDRESS], 
                 self.token[INSTRSIZE], self.token[INSTRWORDS], code)
        return token

    def decode(self):
        list_get = lambda l, idx: l[idx] if len(l) > idx else None
        instr = list_get(self.token[INSTRWORDS], 0)
        oprnd1 = list_get(self.token[INSTRWORDS], 1)
        oprnd2 = list_get(self.token[INSTRWORDS], 2)
        self.labelprefix = self.token[LABELPREFIX]

        if instr not in self.dOpcodes:
             self.error("Invalid instruction '%s'" % instr)
        opc1 = self.get_opcode(instr)
        if oprnd1 and opc1 < 4:
            num = self.value(oprnd1) % 1024
            opc2, val1 = int(num / 32), None
            opc3, val2 = int(num % 32), None
        else:
            opc2, val1 = self.operand(oprnd1)
            opc3, val2 = self.operand(oprnd2)
        code = [(opc1 * 1024) + (opc2 * 32) + opc3]
        if val1 or val1 == 0: code.append(val1)
        if val2 or val2 == 0: code.append(val2)
        if len(code) != self.token[INSTRSIZE]:
             self.error("Internal error '%s'" % repr(self.token))
        return self.tokenize(code)
    
    def run(self, lToken):
        lNewToken = []
        for self.token in lToken:
            if self.token[LINETYPE] == CODETYPE:
                token = self.decode()
            else:
                token = self.tokenize(self.token[INSTRWORDS])
            lNewToken.append(token)
        return lNewToken

def locater(lToken):
    """
    Memory allocation of the token list code.
    Returns start-address and the array with the opcodes
    (unused memory cells are set to -1) 
    """
    l = copy(lToken)
    l.sort(key=lambda item: item[ADDRESS])
    start = list(filter(lambda t: t[LINETYPE] < COMMENT, l))[0][ADDRESS]
    end   = l[-1][ADDRESS] + l[-1][INSTRSIZE]
    size = end - start
    mem = array('l', [-1] * size)

    for token in lToken:
        if token[LINETYPE] == CODETYPE:
            addr = token[ADDRESS] - start
            for idx, val in enumerate(token[OPCODES]):
                if mem[addr + idx] != -1: print("Warning: Memory location conflict at $%04X" % (addr + idx))
                mem[addr + idx] = val
        elif token[LINETYPE] in [BTEXTTYPE, WTEXTTYPE]:
            addr = token[ADDRESS] - start
            for idx, val in enumerate(token[OPCODES]):
                if mem[addr + idx] != -1: print("Warning: Memory location conflict at $%04X" % (addr + idx))
                mem[addr + idx] = val
    return start, mem
    
def list_file(fname, lToken):
    """
    Generate a list file
    """
    from time import localtime, strftime
    t = strftime("%d-%b-%Y %H:%M:%S", localtime())
    lOut = []
    lOut.append("VM16 ASSEMBLER v%s       File: %-18s    Date: %s" % (VERSION, fname, t))
    lOut.append("")
    for token in lToken:
        if token[LINETYPE] == COMMENT:
            cmnt = "%s" % token[LINESTR].rstrip()
            lOut.append("%s" % cmnt)
        elif token[LINETYPE] == CODETYPE:
            addr = "%04X" % token[ADDRESS]
            code = ", ".join(["%04X" % c for c in token[OPCODES]])
            cmnt = "%s" % token[LINESTR].rstrip()
            lOut.append("%s: %-18s %s" % (addr, code, cmnt))
        elif token[LINETYPE] in [BTEXTTYPE, WTEXTTYPE]:
            addr = "%04X" % token[ADDRESS]
            code = ", ".join(["%04X" % c for c in token[OPCODES]])
            cmnt = "%s" % token[LINESTR].rstrip()
            lOut.append("%s" % cmnt)
            lOut.append("%s: %s" % (addr, code))
    dname = os.path.splitext(fname)[0] + ".lst"
    print(" - write %s..." % dname)
    open(dname, "wt").write("\n".join(lOut))
    
def txt_file(fname, mem, fillword=0):
    """
    Generate a TXT file 
    """
    dname = os.path.splitext(fname)[0] + ".txt"
    print(" - write %s..." % dname)
    open(dname, "wt").write(" ".join(["%04X" % (v if v != -1 else 0) for v in mem]))
    
def h16_file(fname, start_addr, mem):
    """
    Generate a H16 file 
    """
    def first_valid(arr, start):
        for idx, val in enumerate(arr[start:]):
            if val != -1: return start + idx
        return ROWSIZE
     
    def first_invalid(arr, start):       
        for idx, val in enumerate(arr[start:]):
            if val == -1: return start + idx
        return ROWSIZE

    def add(lOut, row, addr):
        s = "".join(["%04X" % v for v in row])
        lOut.append(":%X%04X00%s" % (len(row), addr, s))
        return len(row)
             
    dname = os.path.splitext(fname)[0] + ".h16"
    print(" - write %s..." % dname)

    idx = 0
    ROWSIZE = 8
    lOut = []
    while idx < len(mem):
        row = mem[idx:idx+ROWSIZE]
        i1 = 0
        offs = 0
        while i1 < ROWSIZE and idx < len(mem):
            i1 = first_valid(row, i1)
            i2  = first_invalid(row, i1)
            if i1 != i2 and i1 < ROWSIZE:
                add(lOut, row[i1:i2], start_addr + idx + i1)
                i1 = i2
        idx += ROWSIZE
    lOut.append(":0000001")
    #print("\n".join(lOut))    
    open(dname, "wt").write("\n".join(lOut))
    
def assembler(fname):
    print("VM16 ASSEMBLER v%s (c) 2019 by Joe\n" % VERSION)
    print(" - read %s..." % fname)
    a = AsmPass1()
    lToken = a.run(fname)
    a = AsmPass2(a.dSymbols, a.dAliases)
    lToken = a.run(lToken)
    list_file(fname, lToken)
    start_addr, mem = locater(lToken)
    txt_file(fname, mem)
    h16_file(fname, start_addr, mem)
    
    print("\nSymbol table:")
    items = []
    for key, addr in a.dSymbols.items():
        if not key.islower():
            items.append((key, addr))
    items.sort(key=lambda item: item[1])
    for item in items:
        print(" - %-16s = %04X" % (item[0], item[1]))
    print("")
 
    size = len(mem)
    print("Code start address: $%04X" % start_addr)
    print("Code size: $%04X/%u words\n" % (size, size))
    return lToken

if len(sys.argv) != 2:
    print("Syntax: asm13.py <asm-file>")
    sys.exit(0)
        
l = assembler(sys.argv[1])

# mem = array('l', [-1,1,1,-1,-1,1,1,1])
# h16_file("t1.asm", 0, mem)

# mem = array('l', [1,1,-1,-1,1,1,-1,-1])
# h16_file("t2.asm", 0, mem)
