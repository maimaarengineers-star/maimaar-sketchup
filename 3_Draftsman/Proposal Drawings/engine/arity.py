# -*- coding: utf-8 -*-
"""Arity linter for the PEB LISP engine.

AutoLISP does not raise a catchable error when a defun is called with too few
arguments -- it silently unwinds the whole evaluation. Everything after the bad
call is simply never drawn, with no error anywhere. That is invisible in review
and invisible at runtime, so it needs a linter.

Collects every (defun name (a b c / locals) ...) in the given files, then checks
every call site against the declared argument count.
"""
import io, os, re, sys, glob

FILES = sorted(glob.glob(os.path.join(
    r"D:\maimaar-os\3_Draftsman\Proposal Drawings\engine", "*.lsp")))

DEFUN = re.compile(r"^\(defun\s+([^\s()]+)\s*\(([^)]*)\)", re.M)


def strip_code(text):
    """Blank out ; comments and "strings" so they cannot look like code."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == ";":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif c == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                j += 1
            j = min(j + 1, n)
            # keep the string as an opaque TOKEN of the same length: blanking it
            # made every string argument vanish and the counts came out short.
            out.append("S" * (j - i))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


# ---- 1. collect declarations ------------------------------------------------
decl = {}
for path in FILES:
    raw = io.open(path, encoding="utf-8", errors="replace").read()
    for m in DEFUN.finditer(strip_code(raw)):
        name, params = m.group(1), m.group(2)
        required = params.split("/")[0].split()
        decl[name] = len(required)

# ---- 2. check call sites ----------------------------------------------------
def top_level_args(src, start):
    """Count the top-level arguments of the call whose ( is at `start`.

    Walks element by element rather than splitting on whitespace: (a)(b) is TWO
    arguments even with no space between them, which the whitespace version
    counted as one -- that turned every title-block helper into a false positive.
    """
    n = len(src)
    i = start + 1
    count = -1                     # the first element is the function name
    while i < n:
        c = src[i]
        if c.isspace():
            i += 1
        elif c == ")":
            break
        elif c == "(":
            depth = 0
            while i < n:
                if src[i] == "(":
                    depth += 1
                elif src[i] == ")":
                    depth -= 1
                    if depth == 0:
                        i += 1
                        break
                i += 1
            count += 1
        else:
            while i < n and (not src[i].isspace()) and src[i] not in "()":
                i += 1
            count += 1
    return max(count, 0)

problems = []
for path in FILES:
    raw = io.open(path, encoding="utf-8", errors="replace").read()
    code = strip_code(raw)
    for name, want in decl.items():
        for m in re.finditer(r"\(" + re.escape(name) + r"[\s)]", code):
            s = m.start()
            # skip the declaration itself
            if code[:s].rstrip().endswith("(defun"):
                continue
            got = top_level_args(code, s)
            if got != want:
                line = raw[:s].count("\n") + 1
                snippet = raw[s:raw.find("\n", s)][:96]
                problems.append((os.path.basename(path), line, name, want, got, snippet))

problems.sort(key=lambda p: (p[0], p[1]))
short = [p for p in problems if p[4] < p[3]]
extra = [p for p in problems if p[4] > p[3]]

print("=== TOO FEW ARGUMENTS (silently aborts the whole render) ===")
for f, ln, nm, want, got, sn in short:
    print("  %-26s:%-5d %-24s wants %d, got %d   %s" % (f, ln, nm, want, got, sn))
print("  (none)" if not short else "")
print("=== too many arguments (ignored by AutoLISP, but a smell) ===")
for f, ln, nm, want, got, sn in extra:
    print("  %-26s:%-5d %-24s wants %d, got %d   %s" % (f, ln, nm, want, got, sn))
print("  (none)" if not extra else "")
print("checked %d defuns across %d files" % (len(decl), len(FILES)))
