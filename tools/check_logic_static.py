"""Static checks on the pack's logic.lua, for when there is no `lua` binary to run it with.

Catches the breakage that a rename or a bad edit causes without executing anything: unbalanced
blocks, calls to functions that do not exist, constants that were never assigned, and pack JSON
referencing a `$function` that logic.lua no longer defines. Run from anywhere:

    python tools/check_logic_static.py

For the stronger check that the rules actually behave like the apworld's, see
check_logic_parity.py, which needs lua installed.
"""
import os
import re
import sys

PACK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA = os.path.join(PACK, "scripts", "logic.lua")

BUILTINS = {"ipairs", "pairs", "tonumber", "tostring", "type", "print", "require", "table",
            "string", "math", "os", "io", "pcall", "select", "next", "error", "setmetatable"}
KEYWORDS = {"not", "or", "and", "return", "if", "elseif", "while", "until", "then", "function"}


def main():
    src = open(LUA, encoding="utf-8").read()
    code = "\n".join("" if line.strip().startswith("--") else line.split("--")[0]
                     for line in src.splitlines())

    defined = set(re.findall(r"^function\s+([A-Za-z_][\w]*)\s*\(", code, re.M))
    # A local declaration can name several at once, so take every name before the "=".
    names = set()
    for decl in re.findall(r"\blocal\s+([A-Za-z_][\w,\s]*?)\s*(?:=|$)", code, re.M):
        names |= {n.strip() for n in decl.split(",") if n.strip()}
    names |= set(re.findall(r"\bfor\s+[\w,\s]*?([A-Za-z_][\w]*)\s+in\b", code))
    constants = set()
    for line in code.splitlines():
        m = re.match(r"^([A-Z][A-Z0-9_,\s]*)=", line)
        if m:
            constants |= {n.strip() for n in m.group(1).split(",") if n.strip()}

    problems = []

    # `\bif\b` does not match inside "elseif", so elseif needs no correction here.
    opens = len(re.findall(r"\b(?:function|if|for|while)\b", code))
    closes = len(re.findall(r"\bend\b", code))
    print(f"block openers {opens}, ends {closes}: {'balanced' if opens == closes else 'MISMATCH'}")
    if opens != closes:
        problems.append("logic.lua blocks are unbalanced")

    called = set(re.findall(r"(?<![\w.:])([A-Za-z_][\w]*)\s*\(", code))
    unknown = sorted(called - defined - BUILTINS - names - KEYWORDS - {"Tracker"})
    print(f"undefined calls: {unknown if unknown else 'none'}")
    problems += [f"logic.lua calls undefined {n}" for n in unknown]

    used = set(re.findall(r"(?<![\w.])([A-Z][A-Z0-9_]{2,})(?![\w(])", code))
    missing = sorted(used - constants)
    print(f"undefined constants: {missing if missing else 'none'}")
    problems += [f"logic.lua uses unassigned constant {n}" for n in missing]

    refs = set()
    for root, _, files in os.walk(PACK):
        if ".git" in root:
            continue
        for name in files:
            if name.endswith(".json"):
                text = open(os.path.join(root, name), encoding="utf-8", errors="ignore").read()
                refs |= {r.split("|")[0] for r in re.findall(r"\$([A-Za-z_][\w|]*)", text)}
    dangling = sorted(r for r in refs if r not in defined)
    print(f"{len(refs)} functions referenced by pack JSON; missing: {dangling or 'none'}")
    problems += [f"pack JSON references undefined ${n}" for n in dangling]

    print("FAILED" if problems else "consistent")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
