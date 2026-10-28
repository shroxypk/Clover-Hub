import io
path = "src/runtime.lua"
lines = io.open(path, encoding="utf-8").read().split("\n")
for i, line in enumerate(lines, 1):
    if any(ord(c) > 127 for c in line) or "icons=" in line:
        print(i, line.encode("unicode_escape").decode()[:220])
