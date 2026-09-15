#!/usr/bin/env python3
"""Structural sanity check for Luau sources: block keywords and brackets must balance.

    python3 tools/luau_balance_check.py lemonade-game            # every .luau file below
    python3 tools/luau_balance_check.py path/to/File.luau ...

Not a parser. It strips comments and strings (including [[long]] and `interpolated` forms),
then counts `function`, statement `if`, `do` and `repeat` against `end` / `until`, and
(), {}, []. Luau if-expressions (`x = if a then b else c`) open no block and are recognised
by the token before them. Catches the stray/missing `end` class of mistakes that otherwise
only surfaces when Studio loads the script.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*|\.\.\.|\.\.|==|~=|<=|>=|[-+*/%^#<>=(){}\[\];:,.]|\d[\d.xXa-fA-F_]*")
EXPRESSION_CONTEXT = {"=", "return", "(", ",", "{", "..", "and", "or", "not", "+", "-", "*", "/", "%", "^",
                      "==", "~=", "<", ">", "<=", ">=", "in", "["}
PAIRS = {")": "(", "}": "{", "]": "["}


def strip(source: str) -> str:
    out, i, n = [], 0, len(source)
    while i < n:
        c = source[i]
        if source.startswith("--", i):
            m = re.match(r"--\[(=*)\[", source[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = source.find(close, i + m.end())
                j = n if j < 0 else j + len(close)
                out.append("\n" * source.count("\n", i, j))
                i = j
            else:
                j = source.find("\n", i)
                i = n if j < 0 else j
            continue
        m = re.match(r"\[(=*)\[", source[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = source.find(close, i + m.end())
            j = n if j < 0 else j + len(close)
            out.append(' _str_ ' + "\n" * source.count("\n", i, j))
            i = j
            continue
        if c in "\"'`":
            j = i + 1
            depth = 0
            while j < n:
                if source[j] == "\\":
                    j += 2
                    continue
                if c == "`" and source[j] == "{":
                    depth += 1
                elif c == "`" and source[j] == "}" and depth:
                    depth -= 1
                elif source[j] == c and depth == 0:
                    break
                elif source[j] == "\n" and c != "`":
                    break
                j += 1
            out.append(' _str_ ')
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def check(path: Path) -> list[str]:
    text = strip(path.read_text())
    problems, stack, brackets = [], [], []
    prev = None
    for line_no, line in enumerate(text.split("\n"), 1):
        for tok in TOKEN.findall(line):
            if tok in ("function", "do", "repeat"):
                stack.append((tok, line_no))
            elif tok == "if":
                if prev not in EXPRESSION_CONTEXT:  # an if-expression opens no block
                    stack.append((tok, line_no))
            elif tok in ("end", "until"):
                if not stack:
                    problems.append(f"{path}:{line_no}: unmatched `{tok}`")
                else:
                    opener, _ = stack.pop()
                    if (tok == "until") != (opener == "repeat"):
                        problems.append(f"{path}:{line_no}: `{tok}` closes `{opener}`")
            elif tok in "({[":
                brackets.append((tok, line_no))
            elif tok in ")}]":
                if not brackets or brackets[-1][0] != PAIRS[tok]:
                    problems.append(f"{path}:{line_no}: unbalanced `{tok}`")
                else:
                    brackets.pop()
            prev = tok
    for opener, line_no in stack:
        problems.append(f"{path}:{line_no}: `{opener}` never closed")
    for opener, line_no in brackets:
        problems.append(f"{path}:{line_no}: `{opener}` never closed")
    return problems


def main():
    targets = []
    for arg in sys.argv[1:] or ["lemonade-game"]:
        p = Path(arg)
        targets += sorted(p.rglob("*.luau")) if p.is_dir() else [p]
    problems = [msg for t in targets for msg in check(t)]
    for msg in problems:
        print(msg)
    print(f"[luau_balance_check] {len(targets)} files, {len(problems)} problems")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
