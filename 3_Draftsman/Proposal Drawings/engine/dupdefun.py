# dupdefun.py - which defuns exist in MORE THAN ONE engine file, and have the copies drifted?
#
#   python dupdefun.py            # report
#   python dupdefun.py --strict   # exit 1 if any copies have DRIFTED
#
# Owner, 5-Sep-2026: "find what deviations we have made in the coding while adding new components."
# This is the biggest one, and it is structural rather than a bug in any single place.
#
# WHY IT MATTERS MORE THAN IT LOOKS. Plan.lsp and Section.lsp both load into the same drawing, so a
# defun in both means the LAST ONE LOADED WINS. On a full set that is Plan.lsp and everything is
# consistent. But drawingRender loads each module only when a selected sheet needs it, and PRO-08 /
# PRO-09 are Section-only - so asking for those pages alone skipped Plan.lsp and ran Section's
# copies instead. txt-bold differed between the two: one set a 0.30 pen for headings, the other set
# nothing. The same drawing printed differently depending on which pages were requested.
#
# A fix applied to one copy is therefore not applied to the drawing - it is applied to some of the
# drawing, some of the time, depending on an argument nobody connects to text weight.
#
# DRIFTED copies are reported first because they are live: the two behave differently TODAY.
# IDENTICAL copies are reported second and are not wrong yet - they are simply where the next
# divergence will happen, because only one of them will get the next fix.
import io, re, sys, glob, os, hashlib

DEF = re.compile(r'^\(defun\s+([A-Za-z0-9\-:*/+?!<>=_]+)', re.M)

bodies = {}   # name -> {file: normalised body}
for path in sorted(glob.glob('MAIMAAR_PEB_*.lsp') + glob.glob('_peb_*.lsp')):
    if path.endswith('.bak'):
        continue
    src = io.open(path, encoding='latin-1').read()
    lines = src.split('\n')
    starts = [(m.start(), m.group(1)) for m in DEF.finditer(src)]
    for i, (pos, name) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(src)
        body = src[pos:end]
        # normalise: drop comments and whitespace so formatting differences are not "drift"
        norm = '\n'.join(l.split(';')[0].rstrip() for l in body.split('\n'))
        norm = re.sub(r'\s+', ' ', norm).strip()
        bodies.setdefault(name, {})[os.path.basename(path)] = norm

dups = {n: f for n, f in bodies.items() if len(f) > 1}
same, drifted = [], []
for name, files in sorted(dups.items()):
    hashes = {hashlib.md5(b.encode()).hexdigest(): f for f, b in files.items()}
    (drifted if len(hashes) > 1 else same).append((name, list(files), len(next(iter(files.values())))))

STRICT = '--strict' in sys.argv
print('defuns defined in more than one engine file: %d' % len(dups))
print()
print('=== THE COPIES HAVE ALREADY DRIFTED (%d) - these are live bugs waiting ===' % len(drifted))
for name, files, _ in sorted(drifted, key=lambda r: -r[2]):
    print('  %-34s %s' % (name, ', '.join(files)))
print()
print('=== identical copies (%d) - not wrong yet, but only one of them will get the next fix ===' % len(same))
for name, files, size in sorted(same, key=lambda r: -r[2])[:20]:
    print('  %-34s %-5d chars   %s' % (name, size, ', '.join(files)))

if STRICT and drifted:
    print()
    print('FAIL: %d defun(s) have drifted between their copies.' % len(drifted))
    sys.exit(1)
