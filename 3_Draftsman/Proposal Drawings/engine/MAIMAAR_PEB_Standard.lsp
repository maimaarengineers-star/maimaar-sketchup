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
    ("GRID-LINES"   8   "DASHDOT"    0.09)   ; grid centre-lines
    ("GRID-TEXT"    1   "Continuous" 0.09)   ; grid bubble numbers (red)
    ("COLUMN-HATCH" 8   "Continuous" 0.09)   ; column poché (thin grey)
    ;; --- primary steel ---
    ("STRUCTURE"    7   "Continuous" 0.25)   ; rafters/members (was 0.50 — exemplars are lighter)
    ("COLUMNS"      1   "Continuous" 0.50)   ; Template-B heavy RED columns
    ("COL-CENTER"   1   "CENTER"     0.09)   ; plan column centre-line
    ("CL"           1   "CENTER"     0.09)   ; section alias of COL-CENTER
    ("CROSS"        82  "HIDDEN"     0.13)   ; X cross-bracing (exemplar-exact)
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
    ("AREA-MARK"    8   "Continuous" 0.09)
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
  (foreach lt '("DASHDOT" "HIDDEN" "CENTER") (peb-std-ltype lt))
  (peb-ensure-layers)
  (peb-std-textstyle "PEB-TITLE" "romand.shx")
  (peb-std-textstyle "PEB-BODY"  "romans.shx")
  (peb-std-textstyle "PEB-DIM"   "romans.shx")
  (peb-std-textstyle "ROMAND"    "romand.shx")
  (peb-std-textstyle "OPEN"      "romand.shx")
  (princ "\nMAIMAAR PEB presentation standard ready (layers + colours + styles).")
  (princ))

(princ "\nMAIMAAR_PEB_Standard.lsp loaded — Presentation Standards DB. Run (peb-std-setup).")
(princ)
