;; ============================================================================
;;  MAIMAAR_PEB_Standard.lsp  —  PRESENTATION STANDARDS DATABASE
;; ----------------------------------------------------------------------------
;;  The single source of truth for the LOOK of every Maimaar proposal drawing:
;;  layers, colours, lineweights, linetypes, text-height ladder, dimension
;;  style and hatch dispatch.  Distilled from a deep study of 40 competitor
;;  (Mammut / Izhar) proposal DXFs — see reference/03_proposal_drawings/
;;  MAMMUT_PLAN_STUDY.md and the corpus standard.
;;
;;  Two CAD templates were found in the gold-standard set:
;;    Template A "Izhar clean"   — the cleanest layer / colour / lineweight
;;                                 discipline (adopted as the base).
;;    Template B "Mammut/Karren" — heavy RED columns (lw 0.50) + orange RCC
;;                                 poché (ACI 32) — adopted as overrides because
;;                                 they read far better on a plotted sheet.
;;  Plus the Roshan grid sub-scheme (thin 0.09 grid text / column hatch).
;;
;;  LOAD ORDER (see Cover.lsp:11-15):  Standard -> Section -> Plan -> Cover.
;;  Call (peb-std-setup) once at the start of a drawing (done by C:PEB-PLAN /
;;  C:PEB-SECTION).  This module is ADDITIVE — it only defines layers/styles
;;  and helper accessors; it draws nothing.
;;
;;  Lineweights are stored in MILLIMETRES here and written to the LAYER record
;;  as DXF group code 370 = mm x 100 (e.g. 0.50 mm -> 50).  Valid ACAD weights:
;;    0 5 9 13 15 18 20 25 30 35 40 50 53 60 70 80 90 100 ...
;; ============================================================================

;; ---------------------------------------------------------------------------
;; 1) LAYER TABLE  —  (name  ACI-colour  linetype  lineweight-mm)
;;    Engine layer NAMES are preserved (the draw code targets them); only the
;;    visual attributes are upgraded to corpus grade, and the three known
;;    Plan/Section divergences are reconciled here (RIDGE 0.18, ARROWS cyan,
;;    COL-CENTER == CL).  New corpus layers: HATCHR, HATCH, GRID-TEXT, COLUMN-HATCH.
;; ---------------------------------------------------------------------------
;; Lineweights below are the EXACT values extracted from the best competitor
;; exemplars (proposals/10,12,14,18 = Template-A "Izhar clean"; 33,35 = Template-B
;; Mammut/Karren). Key facts from that extraction:
;;   * the pervasive working line is 0.09 (code 9) — most geometry sits here;
;;   * BORDER 0.50; heavy RED COLUMN 0.50 (Template-B, owner-approved);
;;   * RCC HATCHR = ACI 32 @ 0.30; CROSS bracing = 0.13 HIDDEN; dims/text thin.
(setq *PEB-LAYERS*
  '(;; --- sheet / title block ---
    ("BORDER"       7   "Continuous" 0.50)   ; exemplars: 0.50 (cyan in Mammut; kept white for our TB)
    ("TITLEBLOCK"   1   "Continuous" 0.35)
    ("TB-HEADER"    1   "Continuous" 0.50)
    ;; --- grid system (green grid + Roshan thin sub-scheme @ 0.09) ---
    ("GRID"         150 "Continuous" 0.13)   ; grid bubble = CIRCLE, ACI 150 (OWNER RULE — original)
    ("GRID-LINES"   8   "CENTER"     0.09)   ; grid axis lines — grey CENTER dash-dot (OWNER RULE — real Mammut)
    ("GRID-TEXT"    1   "Continuous" 0.09)   ; grid bubble number/letter — RED (ACI 1) on the blue circle (G17); matches PEB_LAYERS.csv
    ("COLUMN-HATCH" 8   "Continuous" 0.09)   ; column poché (thin grey)
    ;; --- primary steel ---
    ("STRUCTURE"    7   "Continuous" 0.25)   ; rafters/members (was 0.50 — exemplars are lighter)
    ("COLUMNS"      1   "Continuous" 0.50)   ; Template-B heavy RED columns
    ("COL-CENTER"   1   "CENTER"     0.09)   ; plan column centre-line
    ("CL"           1   "CENTER"     0.09)   ; section alias of COL-CENTER
    ;; CROSS was "DOT".  A DOT pattern only renders while its dot spacing stays small
    ;; relative to the line, so every brace needed a per-entity 1/LTSCALE correction read
    ;; at draw time — and anything that changed LTSCALE afterwards silently switched the
    ;; whole roof bracing off at plot.  That is exactly what the PDF pipeline does
    ;; (peb-add-layout runs after the sheet is drawn), so the geometry was always present
    ;; -- 30 CROSS lines on B-03 sheet 1, correctly placed -- and the plot was empty.
    ;; Second time this class has bitten, so it is fixed at the layer: CONTINUOUS has no
    ;; pattern, nothing to scale, and nothing downstream can turn it off.  Still cyan and
    ;; 0.18 mm, so it reads as secondary bracing against the 0.35 mm framing, and it
    ;; matches the reference sets (KMFoods draws bracing as plain thin lines).
    ("CROSS"        4   "Continuous" 0.18)   ; cross-bracing — cyan thin X
    ("BOLTS"        7   "Continuous" 0.09)
    ("PLATES"       1   "Continuous" 0.35)   ; connection plates RED (owner 14-Jul)
    ("FRAME"        1   "Continuous" 0.30)   ; section main-frame outline — RED, lighter weight (owner 7-Jul)
    ("FRAME-FILL"   8   "Continuous" 0.09)
    ("RIDGE"        5   "HIDDEN"     0.18)   ; reconciled (was 0.09 plan / 0.18 sec)
    ("RAFTER"       8   "HIDDEN"     0.09)
    ;; --- secondary / envelope (thin) ---
    ("PURLINS"      6   "Continuous" 0.13)
    ("GIRTS"        6   "Continuous" 0.13)
    ("SHEETING"     4   "Continuous" 0.09)   ; building outline — CYAN (OWNER RULE — original)
    ("CLADDING"     5   "Continuous" 0.18)
    ("COL-OUTER"    4   "DASHDOT"    0.09)
    ("GUTTER"       4   "Continuous" 0.18)
    ;; --- annotation (thin, legible) ---
    ("DIMENSIONS"   6   "Continuous" 0.13)   ; dim chain — MAGENTA (OWNER RULE — real Mammut)
    ("ARROWS"       3   "Continuous" 0.13)   ; dim ticks/arrows match dim colour
    ("FALL"         1   "Continuous" 0.35)   ; FALL roof-drainage glyph — RED (OWNER RULE); heavy for contrast (owner 10-Jul)
    ("TEXT"         7   "Continuous" 0.13)
    ("AREA-MARK"    8   "Continuous" 0.18)   ; thick area-identification cross lines
    ("OPEN"         6   "Continuous" 0.18)   ; doors / windows / openings (magenta)
    ;; --- masonry / RCC / fills ---
    ("BRICK-WALL"   30  "Continuous" 0.25)
    ("RCC-COLUMN"   8   "Continuous" 0.35)
    ("GROUND"       7   "Continuous" 0.50)
    ("GROUND-HATCH" 8   "Continuous" 0.09)
    ("HATCHR"       32  "Continuous" 0.30)   ; RCC / concrete poché (orange) — exemplar-exact
    ("HATCH"        8   "Continuous" 0.05)   ; light fill (existing / future)
    ;; --- mezzanine framing "material" = line-thickness standard (owner 12-Jul); COLOURS kept from the CLP ---
    ("COMP-MEZZ-BEAM"      5  "Continuous" 0.50)   ; MAIN BEAM  — heavy (200mm top flange), blue
    ("COMP-MEZZ-JOIST"     8  "Continuous" 0.25)   ; JOIST      — medium (150mm top flange), grey
    ("COMP-MEZZ-JOIST-SEC" 8  "Continuous" 0.13)   ; SEC. JOIST — light (100mm top flange), grey
    ;; --- roof monitor section detail (owner 19-Jul; standalone MAIMAAR_PEB_Monitor.lsp) ---
    ("COMP-MONITOR-SEC"    4  "Continuous" 0.13)   ; monitor sheeting / ridge & eave panels — CYAN (matches roof panel)
   ))

;; ---- SINGLE-SOURCE OVERRIDE  (Rule Book -> engine) -------------------------
;;  The table above is now a FALLBACK.  The single source of truth for the
;;  STYLE (colour / linetype / lineweight) is:
;;      Rule_Book/PEB_LAYERS.csv  ->  _PEB_LAYERS_generated.lsp
;;  (regenerated by Rule_Book/build_engine_standard.py).  When that generated
;;  file is reachable it OVERRIDES the fallback, so editing the Rule Book drives
;;  the engine's look directly -- no hand-editing this list, no drift.
(if (findfile "_PEB_LAYERS_generated.lsp")
  (load (findfile "_PEB_LAYERS_generated.lsp")))

;; ---------------------------------------------------------------------------
;; 2) SYMBOLIC COLOUR MAP  —  kill bare ACI literals; unify the Cover set.
;; ---------------------------------------------------------------------------
(setq *PEB-COLORS*
  '((STEEL . 7)  (COLUMN . 1)   (DIM . 3)     (GRID . 150) (CL . 1)
    (ACCENT . 4) (HATCH-RCC . 32) (TEXT . 7)  (SHEET . 4)  (SECONDARY . 6)
    (RIDGE . 5)  (BRICK . 30)
    ;; raw names (for the Cover's old (setq white 7 ...) set)
    (WHITE . 7)  (RED . 1)  (YELLOW . 2)  (GREEN . 3)  (CYAN . 4)
    (BLUE . 5)   (MAGENTA . 6) (GREY . 8) (LTGREY . 9) (BROWN . 30) (ORANGE . 32)))

;; ── THE CRANE'S LINETYPE ───────────────────────────────────────────────────────────────────
;; Owner 5-Sep-2026: "LINE TYPE IS HIDDEN - - - -, Scale - 1, Colour - White, line Weight .050",
;; then, twice over: "All Crane Bridge Items Must be Shown in Dashed Line in PDF like Mammut".
;;
;; WHY IT KEPT PRINTING SOLID, AND IT WAS NEVER THE LINETYPE.
;;
;; This engine plots from LAYOUTS (GOLDEN RULE 31), and it never sets PSLTSCALE, so PSLTSCALE is
;; at AutoCAD's default of 1 -- "scale linetypes in paper space".  Under PSLTSCALE 1 a pattern
;; length is read in PAPER millimetres, not model millimetres.  The pattern here was written as
;; 300 / 150, meaning to say "300 mm on the building".  AutoCAD read it as 300 mm ON THE SHEET --
;; one dash longer than the A1 page -- and drew the crane as a single unbroken stroke.
;;
;; That is why every attempt to fix this by changing the LINETYPE failed.  HIDDEN, CRANEHID,
;; entity scale 300, entity scale 1, entity scale 1/LTSCALE: under PSLTSCALE 1 they all resolve to
;; a dash measured in paper mm, and every value tried was far bigger than the sheet.  Measured on
;; the plotted DXF the crane region held four unbroken runs over 10 mm and not one dash.
;;
;; PSLTSCALE is NOT changed here.  Setting it to 0 would fix the crane and silently re-scale every
;; other dashed linetype on all nine sheets -- bracing, hidden framing, sheeting -- none of which
;; has been looked at.  A one-component defect does not get a drawing-wide switch.
;;
;; Instead the pattern is stated in the unit AutoCAD is actually reading: PAPER MILLIMETRES.
;;
;;      1.5 mm dash / 0.75 mm gap, on paper, on every sheet, at every viewport scale
;;
;; which is what Mammut's sheet measures: their $LTSCALE 1200 on the imperial acad.lin HIDDEN
;; (0.25 / -0.125) gives a 300 mm dash on a building plotted at 1:209 -- 1.44 mm in the customer's
;; hand.  We now print 1.5.  The entity scale stays 1/LTSCALE, which cancels the drawing's own
;; LTSCALE so the figure above is absolute and cannot drift when a bigger building raises LTSCALE.
(defun peb-crane-ltype ( )
  (if (not (tblsearch "LTYPE" "CRANEHID"))
    (vl-catch-all-apply (function (lambda ()
      (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbLinetypeTableRecord") '(2 . "CRANEHID") '(70 . 0)
                     '(3 . "Crane hidden  1.5 / 0.75 PAPER mm") '(72 . 65) '(73 . 2) '(40 . 2.25)
                     '(49 . 1.5) '(74 . 0) '(49 . -0.75) '(74 . 0)))))))
  (if (tblsearch "LTYPE" "CRANEHID") "CRANEHID" "HIDDEN"))

;; Cancel the drawing's LTSCALE so the pattern above is an absolute paper measurement.
(defun peb-crane-lts ( / L)
  (setq L (getvar "LTSCALE"))
  (if (or (null L) (<= L 0.0)) (setq L 1.0))
  (/ 1.0 L))

(defun peb-color (sym / p)
  (if (setq p (assoc sym *PEB-COLORS*)) (cdr p) 7))

;; ---------------------------------------------------------------------------
;; 3) TEXT-HEIGHT LADDER  --  THE DRAWING STANDARD, IN MILLIMETRES OF PAPER.
;;    Fonts: romans.shx (dims/general), Arial (headings/title block),
;;    ravi.shx reserved for Urdu.
;;
;;    Hand one of these to txt / txt-bold / txt-rom RAW.  Those helpers multiply
;;    by *PEB-TEXT-SCALE* themselves, and that is what makes the ladder a
;;    standard rather than a suggestion:
;;
;;      TEXT-SCALE = faceMax / 45000, and each view is fitted to ~163 mm of paper
;;      width, so the plotted height is
;;          h * (faceMax/45000) / (faceMax/163)  =  h * 163/45000  =  h * 0.0036 mm
;;      -- independent of the building.  A 14 m shed and a 122 m shed print the
;;      same heading at the same size.  (Pre-multiplying by TEXT-SCALE first is
;;      the classic bug here: it squares the scale and the label grows with the
;;      building.  See rulebook 4B.2.)
;;
;;    Owner 26-Aug: "headings and bubbles and other supporting nomenclature must
;;    match with other drawings.  Currently these are too small."  The old ladder
;;    was 300-450, i.e. 1.1-1.6 mm on paper - too small to read, and ignored by
;;    almost every sheet anyway.  These are the sizes an approval drawing uses:
;; ---------------------------------------------------------------------------
(setq *PEB-TEXT-HEIGHTS*
  '((MARK    .  400)      ; 1.45 mm - the smallest DEFINED size: slope tags and similar
                          ;   marks that sit against a small symbol rather than stand alone.
                          ;   Added 28-Aug: the text audit moved every hard-coded height onto
                          ;   this ladder, and the slope tag landed on SMALL - "1:10 size is
                          ;   more than it should be" (owner). It needed something below
                          ;   SMALL, and a DEFINED rung is the answer, not a loose number:
                          ;   the whole point of the audit was that no text picks its own size.
                          ;   Use it sparingly - anything a customer must READ belongs at
                          ;   SMALL or above.
    (SMALL   .  550)      ; 2.0 mm - marks, leader tails, minor notes
    (DIM     .  700)      ; 2.5 mm - dimension text (ISO)
    (ANNOT   .  830)      ; 3.0 mm - nomenclature: RIDGE LINE, slope tags, member marks
    (LABEL   .  970)      ; 3.5 mm - sub-headings
    (HEADING . 1400)      ; 5.0 mm - the view heading under each drawing
    (TITLE   . 1650)))    ; 6.0 mm - sheet title

;; -- RULE 4B.27 - A LABEL MUST FIT THE THING IT LABELS ------------------------------
;; peb-th returns a rung off the text ladder, and `txt` multiplies that AGAIN by
;; *PEB-TEXT-SCALE* so the label plots at a constant size on paper whatever the building.
;; That is right for a note standing in open space and wrong for a note that has to sit
;; INSIDE a drawn feature: on a 93 m building 'SMALL plots ~1,140 mm a character, so a
;; 44-character slab note drew ~30 m wide - straight through the columns either side of
;; the mezzanine it was labelling (owner 29-Aug, cross section).
;;
;; The rung is a CAP, not a promise. Return the largest height at or below `cap` whose
;; PLOTTED string fits `avail`, remembering the TEXT-SCALE multiply that txt applies.
;; 0.62 is the ROMAND advance width as a fraction of cap height, measured off the SHX.
;; Callers decide what to do when the answer is too small to read - usually drop the long
;; note and keep the short one; a 200 mm caption is not a caption, it is a smudge.
(defun peb-fit-txt-h (str avail cap / ts wPerCh h)
  (setq ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (if (or (null str) (= str "") (null avail) (<= avail 0.0))
    cap
    (progn
      (setq wPerCh (* 0.62 ts (strlen str)))       ; plotted width per unit of PASSED height
      (setq h (if (> wPerCh 0.0) (/ avail wPerCh) cap))
      (min cap (max 0.0 h)))))

(defun peb-th (sym / p)
  (if (setq p (assoc sym *PEB-TEXT-HEIGHTS*)) (cdr p) 300))

;; ---------------------------------------------------------------------------
;; 4) HATCH DISPATCH  —  keyed off an IF area structure-type zone.
;;    Returns (pattern scale ACI layer) or nil for "no hatch" (clear steel).
;; ---------------------------------------------------------------------------
(setq *PEB-HATCH*
  '((STEEL    . nil)
    (RCC      . ("AR-CONC" 25.0 32 "HATCHR"))
    (CONCRETE . ("AR-CONC" 25.0 32 "HATCHR"))
    (MASONRY  . ("AR-B816" 20.0 7  "BRICK-WALL"))
    (BRICK    . ("AR-B816" 20.0 7  "BRICK-WALL"))
    (EXISTING . ("ANSI31"  60.0 8  "HATCH"))
    (FUTURE   . ("ANSI31"  60.0 8  "HATCH"))
    (SOLID    . ("SOLID"    1.0 nil nil))))

(defun peb-hatch-spec (zone / p)
  (setq p (assoc zone *PEB-HATCH*))
  (if p (cdr p) nil))

;; ---------------------------------------------------------------------------
;; 5) DIMENSION STYLE parameters (modelled on the corpus "Standard Dimensions"
;;    / "ALAM" dimstyles).  Consumed by setup-maimaar-dim in the Plan engine.
;;    DIMTXT x DIMSCALE should plot ~300-1100 mm.
;; ---------------------------------------------------------------------------
;; *PEB-DIM-PARAMS* and peb-dimp were DELETED (3-Sep-2026).  A table of DIMTXT/DIMASZ/DIMEXE/
;; DIMGAP values that nothing read - `peb-dimp` had no callers anywhere in the engine - sitting in
;; the file that calls itself the single source of truth for how a drawing LOOKS.  It also named
;; romans.shx, contradicting the universal ROMAND rule twelve lines below it.  A stale standard
;; that nothing enforces is worse than none: the next person to read this file would have taken
;; it for the answer.  The numbers that ARE used live with the drawers that use them.

;; ---------------------------------------------------------------------------
;; 6) HELPERS  —  linetype loader, layer materialiser, text styles, one-shot setup
;; ---------------------------------------------------------------------------

;; Quietly load a linetype from acad.lin if it isn't already present.
(defun peb-std-ltype (lt)
  (if (and lt (/= (strcase lt) "CONTINUOUS") (not (tblsearch "LTYPE" lt)))
    (vl-catch-all-apply
      '(lambda () (command "_.-LINETYPE" "_Load" lt "acad.lin" "")))))

;; mm lineweight -> nearest valid ACAD code-370 integer (mm x 100).
(defun peb-lw370 (mm / v valid best bd d)
  (setq v (fix (+ 0.5 (* mm 100.0))))
  (setq valid '(0 5 9 13 15 18 20 25 30 35 40 50 53 60 70 80 90 100 106 120 140 158 200 211))
  (setq best 25 bd 100000)
  (foreach c valid
    (setq d (abs (- c v)))
    (if (< d bd) (progn (setq bd d) (setq best c))))
  best)

;; owner 23-Jul: BLIND toggle for the DRAWINGS ONLY (Cover/Plan/Section).  TRUE => the "for estimate" version
;; sent to outside fabricators/estimators — CUSTOMER + PROJECT (subject) are left blank so the client is not
;; revealed; MAIMAAR's proposal branding stays prominent.  Default nil => the full customer version.  Set via
;; the *PEB-BLIND* global (the "generate for estimate" path) OR a per-drawing data flag BLIND=1/YES.
(defun peb-blind-p (data / v)
  (or (and (boundp '*PEB-BLIND*) *PEB-BLIND*)
      (and data (setq v (cdr (assoc "BLIND" data))) (member (strcase v) '("1" "YES" "TRUE" "Y")))))

;; Create/refresh ONE layer with colour + linetype + lineweight (code 370).
(defun peb-ensure-layer (name color ltype lwmm / lw)
  (peb-std-ltype ltype)
  (setq lw (peb-lw370 lwmm))
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord") (cons 2 name) (cons 70 0)
                   (cons 62 color)
                   (cons 6 (if ltype ltype "Continuous"))
                   (cons 370 lw)))
    ;; already exists -> refresh colour / linetype / lineweight
    (vl-catch-all-apply
      '(lambda ()
         (command "_.-LAYER" "_Color" (itoa color) name
                  "_Ltype" (if ltype ltype "Continuous") name
                  "_LWeight" (rtos (/ lw 100.0) 2 2) name ""))))
  name)

;; Materialise the whole standard layer set.
(defun peb-ensure-layers ( / )
  (foreach L *PEB-LAYERS*
    (peb-ensure-layer (nth 0 L) (nth 1 L) (nth 2 L) (nth 3 L)))
  (princ))

;; Create a text style (idempotent).  Uses the SAME prompt sequence as the
;; engine's proven make-text-style: name, font, then 6 Enters
;; (height, width, oblique, backwards, upside-down, vertical) — the trailing
;; vertical answer is REQUIRED for .shx fonts or acad /b hangs at that prompt.
;; owner 22-Jul: if the style ALREADY exists this now FORCES its font (entmod), instead of skipping.  The old
;; "create only if absent" let whichever setup ran FIRST win the font — so an early Arial creator could pin
;; PEB-* to Arial and these romand calls became dead no-ops (the load-order drift).  Forcing romand every time
;; means romand always wins no matter who created the style first.
(defun peb-std-textstyle (name font / so sd)
  (if (tblsearch "STYLE" name)
    (vl-catch-all-apply
      (function (lambda ()
        (setq so (tblobjname "STYLE" name) sd (entget so))
        (if (assoc 3 sd) (setq sd (subst (cons 3 font) (assoc 3 sd) sd)))
        (if (assoc 4 sd) (setq sd (subst (cons 4 "")   (assoc 4 sd) sd)))
        (entmod sd) (entupd so))))
    (vl-catch-all-apply
      '(lambda () (command "_.-STYLE" name font "" "" "" "" "" "")))))

;; TTF text style via entmake (group 3 = font file) — no -STYLE prompt-count issues that a .ttf
;; font would otherwise cause (TTF has no "Vertical?" prompt, unlike .shx).
(defun peb-std-ttf-style (name font)
  (if (not (tblsearch "STYLE" name))
    (vl-catch-all-apply
      (function (lambda ()
        (entmake (list '(0 . "STYLE") '(100 . "AcDbSymbolTableRecord")
                       '(100 . "AcDbTextStyleTableRecord") (cons 2 name)
                       '(70 . 0) '(40 . 0.0) '(41 . 1.0) '(50 . 0.0) '(71 . 0) '(42 . 2.5)
                       (cons 3 font) (cons 4 ""))))))))

;; One call to lay the full presentation standard into the current drawing.
(defun peb-std-setup ( / )
  (vl-catch-all-apply '(lambda () (setvar "LWDISPLAY" 1)))  ; show lineweights
  ;; preload the linetypes the standard uses
  (foreach lt '("DASHDOT" "HIDDEN" "CENTER" "DASHED" "DOT") (peb-std-ltype lt))
  (peb-ensure-layers)
  ;; owner UNIVERSAL STANDING RULE 22-Jul: ALL drawing text = ROMAND (romand.shx) — dims, titles, body,
  ;; M-Ladder, cover, everything.  These base styles MUST be romand so the drift can't recur no matter which
  ;; engine (Section / Plan / Cover) creates the style first (the old Arial here won the load-order race on
  ;; the Plan sheet and put every PEB-* text in Arial).  Bold headings = heavier PEN on romand, not Arial-bold.
  (peb-std-textstyle "PEB-TITLE" "romand.shx")
  (peb-std-textstyle "PEB-BODY"  "romand.shx")
  (peb-std-textstyle "PEB-DIM"   "romand.shx")
  (peb-std-textstyle "ROMAND"    "romand.shx")
  (peb-std-textstyle "OPEN"      "romand.shx")
  ;; the default "Standard" style is what stray TEXT/MTEXT (and \F fallbacks) land on — force it romand too,
  ;; and point FONTALT at romand so even a missing-font substitution renders romand.  Belt-and-suspenders.
  (peb-std-textstyle "Standard"  "romand.shx")
  (vl-catch-all-apply '(lambda () (setvar "FONTALT" "romand.shx")))
  (princ "\nMAIMAAR PEB presentation standard ready (layers + colours + styles).")
  (princ))

;; ===========================================================================
;; 7) PRIMITIVE DRAW LIBRARY  —  the UNIVERSAL toolkit (the foundation).
;; ---------------------------------------------------------------------------
;;  Every sheet engine (Plan/Section/Elevation/Framing/Cover) must draw ONLY
;;  through these helpers — never raw entmake.  Each primitive places its entity
;;  on the given STANDARD layer and draws BYLAYER (no colour/linetype override),
;;  so *PEB-LAYERS* fully governs the look: fix a layer once, every sheet follows.
;;  These are the proven batch-safe entmake patterns (entity props after
;;  AcDbEntity, BYLAYER colour) promoted into one shared library.
;;
;;  Native AutoCAD object behind each primitive:
;;    peb-line  -> LINE        peb-poly/-rect -> LWPOLYLINE   peb-circle -> CIRCLE
;;    peb-arc   -> ARC         peb-solid      -> SOLID        peb-text   -> TEXT
;;    peb-mtext -> MTEXT       peb-insert     -> INSERT       peb-pent/-bubble (poly+text)
;;    peb-leader (LINE+SOLID+TEXT, an MLEADER stand-in)
;; ===========================================================================

(defun peb-d2r (d) (* d (/ pi 180.0)))            ; degrees -> radians

;; LINE — straight line, BYLAYER.
(defun peb-line (x1 y1 x2 y2 lay)
  (entmake (list (cons 0 "LINE") (cons 8 lay)
                 (list 10 x1 y1 0.0) (list 11 x2 y2 0.0))))

;; LWPOLYLINE — pts = list of (x y); closed = T / nil.
(defun peb-poly (pts lay closed)
  (entmake (append
    (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 lay)
          (cons 100 "AcDbPolyline") (cons 90 (length pts)) (cons 70 (if closed 1 0)))
    (mapcar '(lambda (p) (list 10 (car p) (cadr p))) pts))))

;; RECTANG — closed rectangle polyline.
(defun peb-rect (x1 y1 x2 y2 lay)
  (peb-poly (list (list x1 y1) (list x2 y1) (list x2 y2) (list x1 y2)) lay T))

;; CIRCLE.
(defun peb-circle (cx cy r lay)
  (entmake (list (cons 0 "CIRCLE") (cons 8 lay) (list 10 cx cy 0.0) (cons 40 r))))

;; FILLED DISC of radius r — the AutoCAD DONUT with inner diameter 0: a CLOSED 2-vertex LWPOLYLINE of
;; two 180-degree arcs (bulge 1) whose centreline radius is r/2, carrying a CONSTANT WIDTH of r.  The
;; stroke then runs from radius 0 to r, i.e. a solid disc.
;; entmake, NOT (command "_.DONUT"): the donut/hatch commands pull in the "_ClosedFilled" block, which
;; this engine has already seen fail under acad /b (see the multi-call TILING note).  Needs FILLMODE 1
;; (AutoCAD default) for the fill to show.
(defun peb-disc (cx cy r lay)
  (entmake (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 lay)
                 (cons 100 "AcDbPolyline") (cons 90 2) (cons 70 1) (cons 43 r)
                 (list 10 (- cx (/ r 2.0)) cy) (cons 42 1.0)
                 (list 10 (+ cx (/ r 2.0)) cy) (cons 42 1.0))))

;; ARC — a1,a2 in DEGREES (CCW).
(defun peb-arc (cx cy r a1 a2 lay)
  (entmake (list (cons 0 "ARC") (cons 8 lay) (list 10 cx cy 0.0) (cons 40 r)
                 (cons 50 (peb-d2r a1)) (cons 51 (peb-d2r a2)))))

;; SOLID — filled quad; pN = (x y). For a triangle pass p3 = p4.
(defun peb-solid (p1 p2 p3 p4 lay)
  (entmake (list (cons 0 "SOLID") (cons 8 lay)
                 (list 10 (car p1)(cadr p1) 0.0) (list 11 (car p2)(cadr p2) 0.0)
                 (list 12 (car p3)(cadr p3) 0.0) (list 13 (car p4)(cadr p4) 0.0))))

;; TEXT — full control. jh = group-72 (0 L,1 C,2 R,4 M), jv = group-73 (0 base,2 mid,3 top).
(defun peb-text-j (x y h rotdeg str lay sty jh jv)
  (entmake (list (cons 0 "TEXT") (cons 8 lay)
                 (list 10 x y 0.0) (list 11 x y 0.0) (cons 40 h) (cons 1 str)
                 (cons 50 (peb-d2r rotdeg)) (cons 7 (if sty sty "PEB-BODY"))
                 (cons 72 jh) (cons 73 jv))))

;; TEXT — middle-centre, PEB-BODY style (the common case).
(defun peb-text (x y h rotdeg str lay)
  (peb-text-j x y h rotdeg str lay "PEB-BODY" 1 2))

;; MTEXT — width wid (0 = auto), attach top-left.
(defun peb-mtext (x y h wid rotdeg str lay sty)
  (entmake (list (cons 0 "MTEXT") (cons 100 "AcDbEntity") (cons 8 lay)
                 (cons 100 "AcDbMText") (list 10 x y 0.0) (cons 40 h)
                 (cons 41 wid) (cons 71 1) (cons 7 (if sty sty "PEB-BODY"))
                 (cons 50 (peb-d2r rotdeg)) (cons 1 str))))

;; INSERT — block reference, uniform scale.
(defun peb-insert (blk x y scl rotdeg lay)
  (entmake (list (cons 0 "INSERT") (cons 8 lay) (cons 2 blk)
                 (list 10 x y 0.0) (cons 41 scl) (cons 42 scl) (cons 43 scl)
                 (cons 50 (peb-d2r rotdeg)))))

;; PENTAGON grid-bubble OUTLINE, apex toward the building.
;;   dir "D" apex down (top row) · "U" up · "L" left · "R" right (left column).
(defun peb-pent (cx cy r dir lay / p)
  (cond
    ((= dir "D")
     (setq p (list (list (- cx r)(+ cy (* r 0.45))) (list (+ cx r)(+ cy (* r 0.45)))
                   (list (+ cx r)(- cy (* r 0.15))) (list cx (- cy r))
                   (list (- cx r)(- cy (* r 0.15))))))
    ((= dir "U")
     (setq p (list (list (- cx r)(- cy (* r 0.45))) (list (+ cx r)(- cy (* r 0.45)))
                   (list (+ cx r)(+ cy (* r 0.15))) (list cx (+ cy r))
                   (list (- cx r)(+ cy (* r 0.15))))))
    ((= dir "L")
     (setq p (list (list (- cx (* r 0.45))(- cy r)) (list (- cx (* r 0.45))(+ cy r))
                   (list (+ cx (* r 0.15))(+ cy r)) (list (+ cx r) cy)
                   (list (+ cx (* r 0.15))(- cy r)))))
    (T  ;; "R" apex right (default for left column)
     (setq p (list (list (+ cx (* r 0.45))(- cy r)) (list (+ cx (* r 0.45))(+ cy r))
                   (list (- cx (* r 0.15))(+ cy r)) (list (- cx r) cy)
                   (list (- cx (* r 0.15))(- cy r))))))
  (peb-poly p lay T))

;; GRID BUBBLE = CIRCLE on GRID (ACI 150) + label on GRID-TEXT (ACI 150).
;;   OWNER RULE: circle bubble (not pentagon).  `dir` kept for call compatibility.
;;   (peb-pent remains available for any sheet that wants the pentagon variant.)
;; ---- ONE BUBBLE RADIUS, FOR EVERY SHEET IN THE SET  (owner 3-Sep-2026) -------------------
;; "Sync all the bubbles."  Rule 4B.31 has said since 28-Aug that a grid bubble is sized to be
;; READ - 720 x TEXT-SCALE, staggered when the grid is tight, never shrunk - and an audit found
;; SIX different radii in the engine:
;;
;;   Column Layout Plan   max(900, 720xTS)        <- the rule
;;   Mezzanine Floor Plan max(900, 620xsc)
;;   Roof Plan            max(900, min(720xts, 0.48xminSp))   <- the shrink 4B.31 repealed
;;   Framing / Sheeting   1100xTS capped at 0.30xminSp
;;   Cross Section        380xTS
;;   Wall Elevations      whatever *PEB-BUBRAD* the PREVIOUS SHEET happened to leave behind
;;
;; That last one is the sharpest: the elevations set nothing and read the global, so the same
;; job could plot different bubbles depending on which sheet rendered before them.
;;
;; Shrinking was the wrong lever twice over - it makes the letters smallest on exactly the big
;; buildings whose sheets are already at 1:800, and it never buys clearance anyway, because the
;; bubble and the gap shrink together.  Stagger instead; peb-bub-rows already does.
;; ---- A BUBBLE IS THE SAME SIZE ON EVERY SHEET  (owner 3-Sep-2026) -----------------------
;; "Fix the bubbles issue."  Four passes in, the radius was already ONE rule everywhere
;; (4B.31, 720 x TEXT-SCALE) and the bubbles still did not match, because a model radius plots
;; at 1440 x TS / sc and the two sheets only agree when TS and sc agree.  TS is ESTIMATED from
;; the building's face; sc is MEASURED from the drawn extents - the face plus every paper-sized
;; dim chain, bubble stack, legend and heading hung off it.  A sheet carrying three nested
;; chains and a legend is fitted smaller than a bare elevation of the same building, and its
;; bubble plots smaller with it.  Measured on MSPL-26-279, in true plotted millimetres:
;;
;;   Cross Section          6.01      Column Layout Plan     4.58
;;   End Wall Framing       6.04      Mezzanine Floor Plan   4.74
;;   Side Wall Framing      5.91      Roof Framing / Sheeting 4.84
;;   Sheeting Elevations    5.21
;;
;; A third bigger on one sheet than another, and perfectly consistent WITHIN each sheet type -
;; which is the tell: it is not noise, it is the annotation profile of the sheet.
;;
;; So each sheet declares its own profile and the bubble is corrected for it.  The factor is
;; MEASURED, not guessed (peb-log-sheet above is what measured it), and it is deliberately the
;; BUBBLE that is corrected and not TEXT-SCALE: scaling all the lettering to close the same gap
;; costs the Column Layout Plan 13% of its drawing scale, because bigger text means bigger
;; extents means a smaller fit.  Correcting the bubble alone costs about 2%.
;;
;; The reference (1.00) is the framing elevation and the cross section - the two that already
;; land near 6 mm, so nothing on the set gets smaller.
(defun peb-bub-fit (kind)
  (cond ((= kind "PLAN")       1.31)     ; Column Layout Plan     4.58 -> 6.0
        ((= kind "MEZZ-PLAN")  1.31)     ; Mezzanine Floor Plan   4.74 -> 6.0
        ((= kind "ROOF")       1.24)     ; Roof framing / sheeting 4.84 -> 6.0
        ((= kind "SHEET-ELEV") 1.15)     ; Sheeting elevations    5.21 -> 6.0
        (T                     1.00)))   ; framing elevations, cross section - the reference

;; EVERY sheet-level drawer sets *PEB-BUB-FIT* beside its *PEB-TEXT-SCALE*, and none inherits.
;; That is the whole lesson of the old *PEB-BUBRAD*, which the wall elevations read without ever
;; setting, so their bubble size depended on which sheet rendered before them.
(defun peb-bub-r ( / f)
  (setq f (if (and (boundp '*PEB-BUB-FIT*) *PEB-BUB-FIT*) *PEB-BUB-FIT* 1.0))
  (* f (max 900.0 (* 720.0 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)))))

(defun peb-bubble (cx cy r lab dir)
  (peb-circle cx cy r "GRID")
  (peb-text cx cy (* r 0.85) 0.0 lab "GRID-TEXT"))

;; UNIVERSAL dual-dimension string (owner 21-Jul): a mm value -> "5300 [17'-5\"]".
;; Shared in Standard.lsp (loaded before Section+Plan) so ANY sheet's dimension can read
;; in BOTH mm and architectural feet-inches, matching the Section's DIMALT dual display and
;; the Plan's *PEB-DIM-DISPLAY* = MMFT default.  ft-inches rounded to the nearest inch.
;; ---- SHEET SCALE LOG  (owner 3-Sep-2026) ------------------------------------------------
;; "Fix the bubbles issue" — and after four passes the honest answer was that the bubble RADIUS
;; is already one rule on every sheet (4B.31), and what differs is the SCALE each sheet is
;; fitted to.  A bubble drawn at 720 x TEXT-SCALE plots at 1440 x TS / sc, so two sheets agree
;; only when TS and sc move together, and TS is estimated from the building's face while sc is
;; measured from the drawn extents - face PLUS every paper-sized dim chain, bubble and note
;; hung off it.  A sheet that carries three dim chains and a legend is fitted smaller than a
;; bare elevation of the same building, and its bubble plots smaller with it.
;;
;; That is a calibration, and a calibration wants MEASUREMENTS, not a fourth guess.  This writes
;; one CSV line per sheet - sheet number, TEXT-SCALE, fitted scale - so the ratio can be read off
;; the real set instead of derived from an assumption about how much annotation each sheet hangs.
;;
;; OFF unless *PEB-SCALE-LOG* names a file.  open/write-line/close only: no `command`, so it
;; cannot leave a prompt open and eat the render script (the 2-Sep failure class).
(if (not (boundp '*PEB-SCALE-LOG*)) (setq *PEB-SCALE-LOG* nil))   ; set to a path to re-measure

(defun peb-log-sheet (sheetNo sc / f)
  (if *PEB-SCALE-LOG*
    (vl-catch-all-apply (function (lambda ()
      (setq f (open *PEB-SCALE-LOG* "a"))
      (if f
        (progn
          (write-line (strcat (if sheetNo sheetNo "?") ","
                              (rtos (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0) 2 4) ","
                              (rtos sc 2 2))
                      f)
          (close f)))))))
  (princ))

(defun peb-dim-mmft (mm / ti ft in)
  (setq ti (/ (abs mm) 25.4)
        ft (fix (/ ti 12.0))
        in (fix (+ 0.5 (- ti (* ft 12.0)))))
  (if (>= in 12) (setq ft (1+ ft) in 0))
  ;; COMMA-GROUPED, like every other number on the set (the owner's number-presentation
  ;; standard).  This printed "76200 [250'-0\"]" on the mezzanine floor plan while the framing
  ;; elevation printed "76,200 [250'-0\"]" for the SAME extent, two sheets apart - one number,
  ;; two presentations, which is the small end of exactly what 4B.8 is about.
  (strcat (if (boundp 'peb-comma) (peb-comma (rtos mm 2 0)) (rtos mm 2 0))
          " [" (itoa ft) "'-" (itoa in) "\"]"))

;; LEADER = line tip->elbow + filled arrowhead at the tip + text at the elbow.
;; Batch-safe MLEADER stand-in, drawn entirely on the given layer.
(defun peb-leader (tipx tipy elbx elby str lay / dx dy d ux uy bx by nx ny hl w)
  (peb-line tipx tipy elbx elby lay)
  (setq dx (- tipx elbx) dy (- tipy elby) d (sqrt (+ (* dx dx) (* dy dy))))
  (if (> d 1.0)
    (progn
      (setq ux (/ dx d) uy (/ dy d) hl 400.0 w 130.0
            bx (- tipx (* hl ux)) by (- tipy (* hl uy)) nx (- 0.0 uy) ny ux)
      (peb-solid (list tipx tipy)
                 (list (+ bx (* w nx)) (+ by (* w ny)))
                 (list (- bx (* w nx)) (- by (* w ny)))
                 (list tipx tipy) lay)))
  (peb-text-j elbx (+ elby 250.0) (peb-th 'ANNOT) 0.0 str lay "PEB-BODY" 1 2))

;; ── Tile a just-drawn drawing to the RIGHT of existing content, with a FIXED clear gap ──
;; RULE (owner): drawings are laid out LEFT→RIGHT and must never overlap.  The new drawing
;; is shifted so its actual LEFT EDGE (min-X — which sits far left of the drawing origin:
;; grid letters + width dims) lands at prevMaxX + gap.  (The old code placed the ORIGIN
;; there, so the negative overhang overran the previous sheet.)
;;   prev-last  = (entlast) captured BEFORE drawing the new sheet (nil if drawing was empty)
;;   prev-max-x = fallback only; the TRUE right edge is measured here from bounding boxes.
;; Fix (owner 3-Jul): EXTMAX under-reports the Mammut titleblock (AcDbTable / wide MTEXT) on a
;; sheet's right edge, so the next sheet was placed too far left and OVERLAPPED. We now scan the
;; actual bounding boxes of every existing entity for the true prevMaxX — a guaranteed clear gap.
(defun peb-tile-place (prev-last prev-max-x / e new-set nmin pmax lo hi obj gap off)
  (vl-load-com)
  (if prev-last
    (progn
      ;; TRUE max-X of ALL existing sheets (entities up to and including prev-last)
      (setq pmax nil e (entnext))
      (while e
        (setq obj (vlax-ename->vla-object e))
        (if (not (vl-catch-all-error-p
                   (vl-catch-all-apply 'vla-getboundingbox (list obj 'lo 'hi))))
          (progn
            (setq hi (vlax-safearray->list hi))
            (if (or (null pmax) (> (car hi) pmax)) (setq pmax (car hi)))))
        (if (equal e prev-last) (setq e nil) (setq e (entnext e))))
      (if (null pmax) (setq pmax (cond (prev-max-x prev-max-x) (t 0.0))))
      ;; the newly drawn sheet = entities AFTER prev-last: collect + find its true min-X
      (setq nmin nil new-set (ssadd) e prev-last)
      (while (setq e (entnext e))
        (ssadd e new-set)
        (setq obj (vlax-ename->vla-object e))
        (if (not (vl-catch-all-error-p
                   (vl-catch-all-apply 'vla-getboundingbox (list obj 'lo 'hi))))
          (progn
            (setq lo (vlax-safearray->list lo))
            (if (or (null nmin) (< (car lo) nmin)) (setq nmin (car lo))))))
      (if (and nmin (> (sslength new-set) 0))
        (progn
          (setq gap (if (boundp 'peb-tile-gap) (peb-tile-gap) 5000.0))
          (setq off (- (+ pmax gap) nmin))   ; new drawing's LEFT edge → true prevMaxX + gap
          (command "_.MOVE" new-set "" "0,0,0" (list off 0.0 0.0))
          (princ (strcat "\nTiled new drawing: left edge at X = " (rtos (+ pmax gap) 2 0) " mm (gap " (rtos gap 2 0) ")"))
          (command "_.ZOOM" "_E")))))
  (princ))

;; ── Generate the STRICT proposal drawing SET for one PEB_Data, left→right ──
;; STRICT (owner 3-Jul): exactly THREE sheets — Cover · Column Layout Plan · Section.
;; NO framing plans, NO elevations — those are REMOVED from the proposal drawing set.
;; Each sheet tiles to the right of the previous via peb-tile-place (fixed gap, no overlap).
;; ---------------------------------------------------------------------------
;; peb-plan-stype - THE one answer to "what structure type is this PLAN?"
;;
;; PD_RULEBOOK S61 / 4B.13: ONE fall glyph on every plan-type sheet, drawn by one
;; routine.  peb-fall-glyph-set already WAS that routine - but it branches on stype,
;; and the sheets were resolving stype differently, so the shared glyph still landed
;; in different places:
;;
;;   Column Layout Plan (Plan.lsp)      ACS->CS, AMS->MS, unknown->CS   <- normalised
;;   Roof Plan          (Roof.lsp)      ACS->CS, AMS->MS                <- normalised
;;   PRO-05a/05b        (Framing.lsp)   raw STYPE                       <- NOT normalised
;;
;; The two roof sheets that actually ship are the Framing.lsp pair; the Roof.lsp
;; drawer that carried the normalisation is dead code behind PEB_DRAFT_SHEETS (S14).
;; So on an ARCHED building the CLP asked for "CS" and got its two rows of fall
;; arrows, while PRO-05a/05b asked for "ACS", matched no branch in the cond, and drew
;; NONE - the deviation the owner saw.  Same for any type outside the whitelist
;; (F2 among them), which the CLP folds to CS and the roof sheets did not.
;;
;; Reading the same rule is not the same as drawing the same stair (S38).  So the
;; resolution lives HERE, in the file every sheet loads first, and every plan-type
;; sheet asks this function instead of reading STYPE for itself.
;;
;; Also sets *PEB-ARCHED*, because the arch shows only in the SECTION - the PLAN of an
;; arched building is its straight equivalent, and the flag is what lets the title
;; still read "ARCHED ...". (owner 5-Jul)
(defun peb-plan-stype (data / s)
  (setq s (strcase (peb-tb-or (MSPL-Get-Str data "STYPE") "CS")))
  (setq *PEB-ARCHED* nil)
  (cond ((= s "ACS") (setq *PEB-ARCHED* T s "CS"))
        ((= s "AMS") (setq *PEB-ARCHED* T s "MS")))
  ;; PP must stay in this whitelist - it was once omitted and a Petrol Pump silently
  ;; drew as a clear-span gable (owner 9-Jul).
  (if (not (member s '("CS" "SS" "MS" "LT" "MG" "FR" "RC" "CC" "BF" "PP")))
    (setq s "CS"))
  s)

;; ---------------------------------------------------------------------------
;; peb-panel-cover / peb-panel-lines - THE panel layout for every sheeting surface.
;;
;; RULE (owner 4-Sep-2026): "if we have 22m length of end wall, there must be 22 or 23
;; lines to show 2 side lines of each panel, for all roofs and all walls", and
;; "place exactly same sheeting profile of sheeting developed M35-250".
;;
;; So a sheeting sheet shows ONE LINE PER PANEL JOINT at the COVER width, plus the two end
;; edges: n = L/cover panels -> n+1 lines.  22 m at 1000 cover = 22 panels, 23 lines.
;; That is 4B.50 applied to the FACE instead of the detail - the proposal states the COVER
;; and nothing finer; ribs and folds are roll-forming dimensions and belong to the DETAILS
;; sheet, which draws the true developed profile.
;;
;; THE COVER IS THE DEVELOPED PROFILE'S OWN.  M35-250 is a 35 mm rib on a 250 pitch and
;; FOUR pitches make the 1000 cover, so the number is taken from peb-sheet-cover (the
;; DETAILS-sheet accessor, Framing.lsp) and never retyped here.  Its own comment already
;; said "these accessors make the sheet the SOURCE, and every other drawer reads the
;; profile from it" - the sheeting drawers were the ones that did not.  S83: a 100% match
;; means ONE SOURCE, not two literals that agree today.
;;
;; WHAT WAS WRONG.  Three drawers hardcoded 1000 and a fourth - the WALL FACE on the
;; sheeting elevations - stepped 333, which is not a pitch of anything: the real rib is
;; 250.  A 22 m wall came out with ~66 identical lines and no readable joint while the roof
;; beside it drew 23.  And because the number was a constant, a LOCK SEAM job drew
;; 1000-wide panels on PRO-04/05 while its own DETAILS sheet printed "470 COVER" from
;; peb-sd-lockseam: one set contradicting itself, which is 4B.7.
;;
;; key is "ROOF" or "WALL" (the PN_ family the surface belongs to).
(defun peb-panel-cover (data key / v c)
  (setq v (MSPL-Get-Str data (strcat "PN_" key "_COVER")))
  (setq c (if (= v "") 0.0 (atof v)))
  ;; Blank or nonsense = a legacy row with no profile captured, which means the standard
  ;; developed profile.  Never 0: it would divide by zero or draw a line per millimetre.
  (if (< c 100.0)
    (setq c (if (boundp 'peb-sheet-cover) (peb-sheet-cover) 1000.0)))
  c)

;; The joint stations across a face of length len, EXCLUDING the two end edges (every drawer
;; already closes its own outline; drawing them again doubles the edge pen).
;;
;; THE PART PANEL IS REAL.  22.3 m of wall is 22 full panels and a 300 mm closer, so the
;; remainder gets its own station - flooring the count left a short band at the end that
;; read as a full panel.
;;
;; AND THE LINES MUST STILL READ.  Every sheet is framed on the same A4 drawing area, so the
;; paper spacing of the joints is (areaW x cover / len) mm and the drawer can work it out
;; for itself - no plot scale needed.  Below ~1.5 mm the lines stop being information and
;; plot as a grey band (the frequency clash GOLDEN_RULES M2 warns about; the proposal PDF is
;; monochrome, so tone carries nothing).  Thin to every 2nd joint, then every 3rd, rather
;; than going grey.  The old guard was "more than 400 runs" - a model-space count, which is
;; the wrong unit: it never fires on the sheets that actually go grey.
(defun peb-panel-lines (len cover / out x step areaW minMm)
  (setq areaW 219.0      ; A4 landscape less margins and the title-block strip (peb-add-layout)
        minMm   1.5
        step  cover)
  (if (and (> len 0.0) (> cover 0.0))
    (while (and (< (/ (* areaW step) len) minMm) (< step len))
      (setq step (+ step cover))))
  (setq out '() x step)
  (while (< x (- len 1.0))          ; 1 mm: never sit a joint on top of the end edge
    (setq out (cons x out))
    (setq x (+ x step)))
  ;; The closer needs no station of its own: the last full joint plus the face's own end edge
  ;; already bound it.  22.3 m gives joints at 1000..22000 and the edge at 22300 - 23 panels,
  ;; the last one 300 wide.  22.0 m gives 1000..21000 and the two edges: 22 panels, 23 lines.
  (reverse out))

(defun peb-all-sheets (path)
  (if (boundp 'peb-cover-from-file)        (peb-cover-from-file path))
  (if (boundp 'peb-plan-from-file)         (peb-plan-from-file path))
  (if (boundp 'peb-section-from-file)      (peb-section-from-file path))
  (command "_.ZOOM" "_E")
  (princ))

(princ "\nMAIMAAR_PEB_Standard.lsp loaded — Standards DB + primitive library. Run (peb-std-setup).")
(princ)
