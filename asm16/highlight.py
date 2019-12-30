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

import sys

if len(sys.argv) != 2:
    print("Syntax: highlight.py <h16-file>")
    sys.exit(0)

print("H16-FILE HIGHLIGHTER v1.0 (c) 2019 by Joe\n")
print("\33[91m" + ':n ' + "\33[92m" + "addr " + "\33[94m" + "ty " + "\33[0m" + "words")
print("-- ---- -- --------------------------------")
for s in open(sys.argv[1]).readlines():
	print("\33[91m" + s[0:2] + " \33[92m" + s[2:6] + " \33[94m" + s[6:8], end=" ")
	for i in range(8, len(s.strip()), 4):
		if i % 8 == 0:
			print("\33[0m" + s[i:i+4], end="")
		else:
			print("\33[93m" + s[i:i+4], end="")
	print("")


