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
    ("GRID"         3   "Continuous" 0.13)   ; grid bubbles + chain frame (Mammut grid = green)
    ("GRID-LINES"   3   "DASHED"     0.09)   ; grid axis lines — green dashed (Zealcon)
    ("GRID-TEXT"    1   "Continuous" 0.09)   ; grid bubble numbers (red)
    ("COLUMN-HATCH" 8   "Continuous" 0.09)   ; column poché (thin grey)
    ;; --- primary steel ---
    ("STRUCTURE"    7   "Continuous" 0.25)   ; rafters/members (was 0.50 — exemplars are lighter)
    ("COLUMNS"      1   "Continuous" 0.50)   ; Template-B heavy RED columns
    ("COL-CENTER"   1   "CENTER"     0.09)   ; plan column centre-line
    ("CL"           1   "CENTER"     0.09)   ; section alias of COL-CENTER
    ("CROSS"        4   "DASHED"     0.18)   ; cross-bracing — cyan dotted X (Zealcon)
    ("BOLTS"        7   "Continuous" 0.09)
    ("PLATES"       7   "Continuous" 0.35)
    ("FRAME"        7   "Continuous" 0.50)   ; section main-frame outline (heavy)
    ("FRAME-FILL"   8   "Continuous" 0.09)
    ("RIDGE"        5   "HIDDEN"     0.18)   ; reconciled (was 0.09 plan / 0.18 sec)
    ("RAFTER"       8   "HIDDEN"     0.09)
    ;; --- secondary / envelope (thin) ---
    ("PURLINS"      6   "Continuous" 0.13)
    ("GIRTS"        6   "Continuous" 0.13)
    ("SHEETING"     5   "Continuous" 0.09)   ; sheeting-face line (Mammut SHEETING = blue)
    ("CLADDING"     5   "Continuous" 0.18)
    ("COL-OUTER"    4   "DASHDOT"    0.09)
    ("GUTTER"       4   "Continuous" 0.18)
    ;; --- annotation (thin, legible) ---
    ("DIMENSIONS"   3   "Continuous" 0.13)   ; dim lines green @ 0.13
    ("ARROWS"       3   "Continuous" 0.13)   ; dim ticks/arrows match dim colour
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
   ))

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

(defun peb-color (sym / p)
  (if (setq p (assoc sym *PEB-COLORS*)) (cdr p) 7))

;; ---------------------------------------------------------------------------
;; 3) TEXT-HEIGHT LADDER (model-space mm; multiply by the drawing scale at use).
;;    Fonts: romans.shx (dims/general), Arial (headings/title block),
;;    ravi.shx reserved for Urdu.
;; ---------------------------------------------------------------------------
(setq *PEB-TEXT-HEIGHTS*
  '((SMALL . 50) (DIM . 56) (ANNOT . 300) (HEADING . 320) (LABEL . 400) (TITLE . 450)))

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
(setq *PEB-DIM-PARAMS*
  '((DIMTXT . 600.0) (DIMASZ . 600.0) (DIMEXE . 100.0) (DIMEXO . 100.0)
    (DIMGAP . 10.0)  (DIMDEC . 0)     (DIMFONT . "romans.shx")))

(defun peb-dimp (sym / p)
  (if (setq p (assoc sym *PEB-DIM-PARAMS*)) (cdr p) nil))

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
(defun peb-std-textstyle (name font)
  (if (not (tblsearch "STYLE" name))
    (vl-catch-all-apply
      '(lambda () (command "_.-STYLE" name font "" "" "" "" "" "")))))

;; One call to lay the full presentation standard into the current drawing.
(defun peb-std-setup ( / )
  (vl-catch-all-apply '(lambda () (setvar "LWDISPLAY" 1)))  ; show lineweights
  ;; preload the linetypes the standard uses
  (foreach lt '("DASHDOT" "HIDDEN" "CENTER" "DASHED") (peb-std-ltype lt))
  (peb-ensure-layers)
  (peb-std-textstyle "PEB-TITLE" "romand.shx")
  (peb-std-textstyle "PEB-BODY"  "romans.shx")
  (peb-std-textstyle "PEB-DIM"   "romans.shx")
  (peb-std-textstyle "ROMAND"    "romand.shx")
  (peb-std-textstyle "OPEN"      "romand.shx")
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

;; GRID BUBBLE = pentagon on GRID (green) + label on GRID-TEXT (red).
;;   dir "D" = top row (numbers), "R" = left column (letters).
(defun peb-bubble (cx cy r lab dir)
  (peb-pent cx cy r dir "GRID")
  (peb-text cx cy (* r 0.85) 0.0 lab "GRID-TEXT"))

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

(princ "\nMAIMAAR_PEB_Standard.lsp loaded — Standards DB + primitive library. Run (peb-std-setup).")
(princ)
