"""Undo a Windows-1252 round trip that mangled UTF-8 glyphs.

A Get-Content/Set-Content pass decodes UTF-8 bytes as cp1252 and re-encodes
them, so '✓' (E2 9C 93) becomes 'âœ“'. This maps every character back to its
byte (cp1252 table, C1 controls pass through as latin-1) and decodes UTF-8.
"""
import io
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else "src/runtime.lua"


def to_byte(ch):
    try:
        return ch.encode("cp1252")
    except UnicodeEncodeError:
        return ch.encode("latin-1")


def repair(line):
    if all(ord(c) < 128 for c in line):
        return line
    data = b"".join(to_byte(c) for c in line)
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return line


text = io.open(PATH, encoding="utf-8-sig", newline="").read()
lines = text.split("\n")
fixed = 0
for i, line in enumerate(lines):
    new = repair(line)
    if new != line:
        lines[i] = new
        fixed += 1

io.open(PATH, "w", encoding="utf-8", newline="").write("\n".join(lines))
print("repaired lines:", fixed)
for i, line in enumerate(lines, 1):
    if any(ord(c) > 127 for c in line):
        print(i, line.encode("unicode_escape").decode()[:180])
