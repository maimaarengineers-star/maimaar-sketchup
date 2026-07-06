import re, collections
DD='D:/maimaar-os/2_Sales CRM/dist/services/drawingData.js'
ENG='D:/maimaar-os/3_Draftsman/Proposal Drawings/engine/MAIMAAR_PEB_Plan.lsp'
dd=open(DD,encoding='utf-8').read()
eng=open(ENG,encoding='utf-8').read()

# keys the CRM writes to the v3 data file
written=set(re.findall(r"push\('([A-Z0-9_]+)'", dd))
# handle dynamic per-wall keys: push('CN_' + w + '_WIDTH') -> expand to the 4 walls
WALLS=['NSW','FSW','LEW','REW']
for pre,suf in re.findall(r"push\('([A-Z0-9_]+)'\s*\+\s*w\s*\+\s*'([A-Z0-9_]+)'", dd):
    for w in WALLS: written.add(pre+w+suf)
# per-index keys: push('PT'+n+'_TYPE') / push('MZ'+n...) / push('CR'+n...) / 'ST'+n / 'RX'... handled above
for pre,suf in re.findall(r"push\('([A-Z0-9_]+)'\s*\+\s*n\s*\+\s*'([A-Z0-9_]+)'", dd):
    for i in '1234': written.add(pre+i+suf)

# keys the engine reads
read=set(re.findall(r'MSPL-Get-(?:Str|Num)\s+\w+\s+"([A-Z0-9_]+)"', eng))
read |= set(re.findall(r'peb-alist-get\s+\w+\s+"([A-Z0-9_]+)"', eng))
# engine reads per-wall/per-index via (strcat "CN_" w "_WIDTH") etc — expand those patterns
for pre,suf in re.findall(r'\(strcat\s+"([A-Z0-9_]+)"\s+w\s+"([A-Z0-9_]+)"\)', eng):
    for w in WALLS: read.add(pre+w+suf)
for m in re.findall(r'strcat\s+"?(?:tag|pre)"?', eng): pass
# engine builds tag=(strcat "PT" (itoa i) "_") then (strcat tag "TYPE") — approximate: any (strcat tag "X")
tagsuf=set(re.findall(r'\(strcat\s+(?:tag|pre)\s+"([A-Z0-9_]+)"\)', eng))
# also (strcat "MZ" n "_LEN") style
for pre,suf in re.findall(r'\(strcat\s+"([A-Z0-9_]+)"\s+n\s+"([A-Z0-9_]+)"\)', eng):
    for i in '1234': read.add(pre+i+suf)
for pre,suf in re.findall(r'\(strcat\s+"([A-Z0-9_]+)"\s+\(itoa\s+\w+\)\s+"([A-Z0-9_]+)"\)', eng):
    for i in '1234': read.add(pre+i+suf)
# dynamic pre/tag prefixes: (setq pre (strcat "CR" (itoa n) "_")) ... (strcat pre "SPAN") -> CR<i>_SPAN
prefixes={}
for var,pfx in re.findall(r'\(setq\s+(pre|tag)\s+\(strcat\s+"([A-Z]+)"', eng):
    prefixes.setdefault(var,set()).add(pfx)
for var,suf in re.findall(r'\(strcat\s+(pre|tag)\s+"([A-Z0-9_]+)"\)', eng):
    for pfx in prefixes.get(var,()):
        for i in '1234': read.add(pfx+i+'_'+suf.lstrip('_'))
# PL* placements consumed by peb-draw-placements via (wcmatch "PL*") — whole family is plan-consumed
if 'PL*' in eng or 'wcmatch (strcase (car kv)) "PL*"' in eng:
    read |= {k for k in written if k.startswith('PL')}

# families that are NOT plan geometry (estimation / section / proposal header / skins) -> exclude from the gate
NONPLAN_FAM={'HD','PN','LN','B'}
NONPLAN_SUF={'DL','LL','CL','OTHER','AREA','FLOOR','FLOOR_THK','TOS','CH_FFL_SLAB','CH_SLAB_RAFTER',
    'MANUFACTURER','WHEEL_BASE','HOOK_HEIGHT','LIFT','MAX_HORIZ_LOAD','MAX_VERT_LOAD','OP','BRIDGE',
    'CMAA_CAT','SOFFIT','INSULATION','BACKUP','GUTTER','HT','SHEETING','OPEN_HT','QTY','QTY_PER_RUNWAY',
    'BIRD_MESH','EAVE_TYPE','EAVE_HT','PROJ','ROOF_AREA','WALL_AREA','ROOF_COVERAGE','WALL_COVERAGE',
    'FLANGE_BRACES','WALL_FLANGE_BRACES','SURFACE','SCOPE','MARK','REPEAT_BAY','ROOFLINE','LINTEL','SILL'}
def nonplan(k):
    f=re.match(r'([A-Z]+)',k).group(1)
    if f in NONPLAN_FAM: return True
    for s in NONPLAN_SUF:
        if k.endswith('_'+s): return True
    return False

# group the gap by prefix family for readability
plan_written={k for k in written if not nonplan(k) and not k.endswith('_') and k not in ('CN','CR','MZ','PT','FA','RX','PN','PL','ST','B','MZ4_TOGGLE','MZ4_LEN','MZ4_WID','MZ4_CH_FFL_BEAM')}
gap=sorted(plan_written-read)
print('PLAN-RELEVANT written:',len(plan_written),' covered:',len(plan_written&read),
      '(%.0f%%)'%(100*len(plan_written&read)/max(1,len(plan_written))))
def fam(k):
    m=re.match(r'([A-Z]+)',k); return m.group(1) if m else k
byfam=collections.defaultdict(list)
for k in gap: byfam[fam(k)].append(k)
print('WRITTEN keys:',len(written),' READ keys:',len(read))
print('COVERED:',len(written&read),'/',len(written), '(%.0f%%)'%(100*len(written&read)/max(1,len(written))))
print('\n--- GAP (written but not detected as read), by family ---')
for f in sorted(byfam):
    print('  %-6s (%2d): %s'%(f,len(byfam[f]),', '.join(byfam[f])))
