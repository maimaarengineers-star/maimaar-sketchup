;; ============================================================================
;;  MAIMAAR_PEB_Roof.lsp  —  ROOF PLAN (top view) drawing engine
;; ----------------------------------------------------------------------------
;;  A TOP VIEW of the roof: outline + eaves + the SAME bay/width GRID as the
;;  Column Layout Plan (so the two sheets register), ridge/valley lines, purlin
;;  lines, roof FALL arrows, eave gutters + downspouts, roof accessories
;;  (skylights / turbo-vents / opening), and the roof-plane footprints of any
;;  ROOF EXTENSIONS (RX_*) and CANOPIES (CN_*).
;;
;;  Reads the SAME v3 data file the plan uses (via MSPL-Read-Data) and derives
;;  its geometry with the SAME algorithms as C:PEB-PLAN — len / wid / bayPts /
;;  widthPts / stype / MG ridge+valley — so grid numbers/letters land in the
;;  identical positions.
;;
;;  LOAD ORDER (STRICT):  Standard -> Section -> Plan -> Roof.
;;  This module assumes MAIMAAR_PEB_Plan.lsp is loaded FIRST; it REUSES the
;;  plan's helpers (MSPL-Read-Data / MSPL-Get-*, grid-bubble, peb-ridge-line,
;;  peb-ridge-symbol, peb-comp-layer / -poly, txt / txt-bold, peb-comma,
;;  peb-draw-roof-accessories, peb-draw-roof-ext, peb-draw-canopy, draw-border,
;;  peb-tile-place, setup-maimaar-dim, peb-std-setup, peb-parse-mod-expression).
;;  It does NOT re-implement the data reader.
;;
;;  Plan axes (shared with the Column Layout Plan):
;;    NSW = bottom (y=0)   FSW = top (y=wid)   LEW = left (x=0)   REW = right (x=len)
;;  For a gable the ridge runs along the LENGTH (x) at y = wid/2; purlins run
;;  PARALLEL to the ridge (x-direction) at width (y) intervals.
;;
;;  ENTRY POINTS:
;;    C:PEB-ROOF                     interactive (pick-file dialog / *PEB-DATA-FILE*)
;;    (peb-roof-from-file <path>)    non-interactive (mirror of peb-plan-from-file)
;; ============================================================================

;; ---------------------------------------------------------------------------
;;  Small local helpers (self-contained; used only by the Roof engine)
;; ---------------------------------------------------------------------------

;; A simple FALL/slope arrow from (x0 y0) -> (x1 y1) with a filled arrowhead at
;; the tip (x1 y1), drawn on the given layer.  hl = head length (mm).
(defun peb-roof-arrow (x0 y0 x1 y1 lay hl / dx dy d ux uy nx ny bx by)
  (setvar "CLAYER" lay)
  (entmake (list (cons 0 "LINE") (cons 8 lay) (list 10 x0 y0 0.0) (list 11 x1 y1 0.0)))
  (setq dx (- x1 x0) dy (- y1 y0) d (sqrt (+ (* dx dx) (* dy dy))))
  (if (> d 1.0)
    (progn
      (setq ux (/ dx d) uy (/ dy d) nx (- 0.0 uy) ny ux
            bx (- x1 (* hl ux)) by (- y1 (* hl uy)))
      (entmake (list (cons 0 "SOLID") (cons 8 lay)
                     (list 10 x1 y1 0.0)
                     (list 11 (+ bx (* hl 0.32 nx)) (+ by (* hl 0.32 ny)) 0.0)
                     (list 12 (- bx (* hl 0.32 nx)) (- by (* hl 0.32 ny)) 0.0)
                     (list 13 x1 y1 0.0)))))
  (princ))

;; The largest boundary strictly below y, from an ascending list bnds (else nil).
(defun peb-roof-below (y bnds / best)
  (foreach b bnds (if (< b (- y 1.0)) (if (or (null best) (> b best)) (setq best b)))) best)
;; The smallest boundary strictly above y (else nil).
(defun peb-roof-above (y bnds / best)
  (foreach b bnds (if (> b (+ y 1.0)) (if (or (null best) (< b best)) (setq best b)))) best)

;; Roof FALL arrows, dispatched by structure type.  Arrows point ridge->eave
;; (gable), high->low (single slope / lean-to), or inward (flat / butterfly).
;; ridgeYs / valleyYs supplied for MG; ignored otherwise.
(defun peb-roof-falls (stype len wid ridgeYs valleyYs / hl xf x bnds r lo hi mid)
  (setq hl (max 350.0 (* (min len wid) 0.010)))
  (cond
    ;; central-ridge gable family: fall to BOTH eaves
    ((member stype '("CS" "MS" "RC"))
      (foreach xf '(0.22 0.5 0.78)
        (setq x (* len xf))
        (peb-roof-arrow x (* wid 0.44) x (* wid 0.14) "FALL" hl)     ; lower slope -> NSW eave
        (peb-roof-arrow x (* wid 0.56) x (* wid 0.86) "FALL" hl))    ; upper slope -> FSW eave
      (setvar "CLAYER" "FALL")
      (txt "MC" (list (* len 0.5) (* wid 0.30)) 300 0 "FALL")
      (txt "MC" (list (* len 0.5) (* wid 0.70)) 300 0 "FALL"))
    ;; multi-gable: each ridge falls to the boundaries (valleys / outer eaves) either side
    ((= stype "MG")
      (setq bnds (append (list 0.0 wid) valleyYs))
      (foreach r ridgeYs
        (setq lo (peb-roof-below r bnds) hi (peb-roof-above r bnds))
        (foreach xf '(0.3 0.7)
          (setq x (* len xf))
          (if lo (peb-roof-arrow x (- r (* (- r lo) 0.20)) x (+ lo (* (- r lo) 0.25)) "FALL" hl))
          (if hi (peb-roof-arrow x (+ r (* (- hi r) 0.20)) x (- hi (* (- hi r) 0.25)) "FALL" hl)))))
    ;; single slope / lean-to: one direction across the width (FSW high -> NSW low)
    ((member stype '("SS" "LT"))
      (foreach xf '(0.22 0.5 0.78)
        (setq x (* len xf))
        (peb-roof-arrow x (* wid 0.85) x (* wid 0.15) "FALL" hl))
      (setvar "CLAYER" "FALL")
      (txt "MC" (list (* len 0.5) (* wid 0.5)) 320 0 "FALL"))
    ;; flat roof / butterfly: drainage INWARD to the centre
    ((member stype '("FR" "BF"))
      (setq mid (list (* len 0.5) (* wid 0.5)))
      (peb-roof-arrow (* len 0.5) (* wid 0.12) (* len 0.5) (* wid 0.40) "FALL" hl)
      (peb-roof-arrow (* len 0.5) (* wid 0.88) (* len 0.5) (* wid 0.60) "FALL" hl)
      (peb-roof-arrow (* len 0.12) (* wid 0.5) (* len 0.40) (* wid 0.5) "FALL" hl)
      (peb-roof-arrow (* len 0.88) (* wid 0.5) (* len 0.60) (* wid 0.5) "FALL" hl)
      (setvar "CLAYER" "FALL")
      (txt "MC" (list (* len 0.5) (* wid 0.5)) 300 0 "FALL TO DRAINS"))
    (T
      (foreach xf '(0.22 0.5 0.78)
        (setq x (* len xf))
        (peb-roof-arrow x (* wid 0.44) x (* wid 0.14) "FALL" hl)
        (peb-roof-arrow x (* wid 0.56) x (* wid 0.86) "FALL" hl))))
  (setvar "CLAYER" "0")
  (princ))

;; Eave GUTTER lines just outside the eave walls + DOWNSPOUT squares at bay
;; intervals.  Gutters on the two eave walls (NSW y=0, FSW y=wid) for gable /
;; mono roofs; full perimeter for flat/butterfly.  bayPts drives the spouts.
(defun peb-roof-gutters (stype len wid bayPts / gof ds hw walls yl per)
  (setq gof (max 250.0 (* wid 0.006))
        ds  (max 300.0 (* (min len wid) 0.006))
        hw  (/ ds 2.0)
        per (member stype '("FR" "BF")))
  (peb-comp-layer "ROOF-DOWNSPOUT" 4)
  ;; --- horizontal eave gutters (NSW & FSW) ---
  (setvar "CLAYER" "GUTTER")
  (entmake (list (cons 0 "LINE") (cons 8 "GUTTER") (list 10 0.0 (- 0.0 gof) 0.0) (list 11 len (- 0.0 gof) 0.0)))
  (entmake (list (cons 0 "LINE") (cons 8 "GUTTER") (list 10 0.0 (+ wid gof) 0.0) (list 11 len (+ wid gof) 0.0)))
  ;; downspout squares at each bay station on both eaves
  (foreach x bayPts
    (peb-comp-poly (list (list (- x hw) (- (- 0.0 gof) hw)) (list (+ x hw) (- (- 0.0 gof) hw))
                         (list (+ x hw) (+ (- 0.0 gof) hw)) (list (- x hw) (+ (- 0.0 gof) hw))))
    (peb-comp-poly (list (list (- x hw) (- (+ wid gof) hw)) (list (+ x hw) (- (+ wid gof) hw))
                         (list (+ x hw) (+ (+ wid gof) hw)) (list (- x hw) (+ (+ wid gof) hw)))))
  ;; --- flat/butterfly: also run gutters on the two end walls (full perimeter) ---
  (if per
    (progn
      (setvar "CLAYER" "GUTTER")
      (entmake (list (cons 0 "LINE") (cons 8 "GUTTER") (list 10 (- 0.0 gof) 0.0 0.0) (list 11 (- 0.0 gof) wid 0.0)))
      (entmake (list (cons 0 "LINE") (cons 8 "GUTTER") (list 10 (+ len gof) 0.0 0.0) (list 11 (+ len gof) wid 0.0)))))
  (setvar "CLAYER" "GUTTER")
  (txt "ML" (list (* len 0.02) (- 0.0 gof (* ds 1.6))) 300 0 "EAVE GUTTER")
  (setvar "CLAYER" "0")
  (princ))

;; Build the roof-panel note string from PN_ROOF_* keys (blank parts dropped).
(defun peb-roof-panel-note (data / parts out)
  (setq parts (list (MSPL-Get-Str data "PN_ROOF_TYPE")
                    (MSPL-Get-Str data "PN_ROOF_OUTER_PROFILE")
                    (MSPL-Get-Str data "PN_ROOF_OUTER_MAT")
                    (MSPL-Get-Str data "PN_ROOF_OUTER_FINISH"))
        out "")
  (foreach p parts
    (if (and p (/= p ""))
      (setq out (if (= out "") p (strcat out " | " p)))))
  (if (= out "") "ROOF PANEL: AS PER PROJECT REQUIREMENT" (strcat "ROOF PANEL: " out)))

;; ===========================================================================
;;  MAIN COMMAND
;; ===========================================================================
(defun C:PEB-ROOF
  ( / dataFile data project client propinput bldgno revno propno fulldate
    len wid stype rooftype roofSlope
    numBays bays baysp bayPts cum i j sp rem
    mgGables mgSpans mgGableW mgSpanW mgRidgePts mgValleyPts mgColumnPts base valley colY
    numMod widthPts gridWpts ewExpr ewSpans ewSum ewScale ewAcc ewStations ewcols ewsp ewY
    ts ds maxSize minSp prevp
    bubR dimGap topGap txtGap yBayDim yOvrDim ovrTxtH gridY2 gridX1 nWid
    psp npur y mgY x
    aNo aLbl yTtl border-margin
    borderL borderR borderT borderB bMarg
  )

  ;; ── Presentation standard (layers / styles / dim) — RUN ONCE PER SESSION ─
  ;; Guard on the MAIMAAR-DIM dimstyle: re-running setup-maimaar-dim after another sheet (Cover/Plan) already
  ;; created it re-issues (-DIMSTYLE _Save), which PROMPTS "redefine?" and HANGS in /b batch (EXPERT=5 does
  ;; not fully suppress it on re-run). Skipping when the style exists makes the full multi-sheet drawing
  ;; (Cover+Plan+Roof+Elevation+Framing+Section in one session) safe; a standalone roof still sets itself up.
  (if (not (tblsearch "DIMSTYLE" "MAIMAAR-DIM"))
    (progn
      (vl-catch-all-apply (function (lambda () (setup-maimaar-dim))))
      (if (boundp 'peb-std-setup)
        (vl-catch-all-apply (function (lambda () (peb-std-setup))))
        (princ "\n** MAIMAAR_PEB_Standard.lsp NOT loaded — load it FIRST (single source of every layer). **"))))
  (vl-load-com)
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  (setvar "GRIDMODE" 0)
  (setvar "SNAPMODE" 0)
  (princ "\nMAIMAAR PEB-ROOF starting...")

  ;; ── Data file (mirror C:PEB-PLAN) ────────────────────────────────
  (setq dataFile
    (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
      *PEB-DATA-FILE*
      (getfiled "Pick the v3 area data file"
                (strcat (if (= (getvar "DWGPREFIX") "") "" (getvar "DWGPREFIX"))
                        "PEB_Data_B1_A1.txt")
                "txt" 4)))
  (if (or (null dataFile) (= dataFile ""))
    (progn (princ "\nNo data file selected -- aborting.") (setvar "CMDECHO" 1) (princ) (exit)))
  (princ (strcat "\nReading: " dataFile))
  (setq data (MSPL-Read-Data dataFile))
  (if (null data)
    (progn (setvar "CMDECHO" 1) (princ "\nERROR: Data file not found or empty.") (princ) (exit)))
  ;; ── Core geometry (identical derivation to C:PEB-PLAN) ───────────
  (setq project   (MSPL-Get-Str data "PROJECT"))
  (setq client    (MSPL-Get-Str data "CLIENT"))
  (setq propinput (MSPL-Get-Str data "PROPOSAL"))
  (setq bldgno    (MSPL-Get-Str data "BLDGNO"))
  (setq revno     (MSPL-Get-Str data "REVNO"))
  (if (= propinput "") (setq propinput "000"))
  (setq propno (strcat "MSPL-26-" propinput))

  (setq len (MSPL-Get-Num data "LENGTH"))
  (setq wid (MSPL-Get-Num data "WIDTH"))
  (if (or (null len) (<= len 0) (null wid) (<= wid 0))
    (progn
      (alert "LENGTH or WIDTH is missing in the data file.\nClick Generate in Excel to regenerate the data file.")
      (setvar "CMDECHO" 1) (princ) (exit)))

  (setq roofSlope (format-slope (MSPL-Get-Str data "SLOPE")))
  (setq *PEB-ROOF-SLOPE* roofSlope)

  ;; structure type (map ARCHED -> straight equivalent, same as the plan)
  (setq stype (strcase (MSPL-Get-Str data "STYPE")))
  (setq *PEB-ARCHED* nil)
  (cond ((= stype "ACS") (setq *PEB-ARCHED* T stype "CS"))
        ((= stype "AMS") (setq *PEB-ARCHED* T stype "MS")))
  (if (not (member stype '("CS" "SS" "MS" "LT" "MG" "FR" "RC" "CC" "BF")))
    (setq stype "CS"))

  (cond
    ((member stype '("SS" "LT" "CC")) (setq rooftype "M"))
    ((member stype '("CS" "MS" "MG" "RC")) (setq rooftype "G"))
    ((= stype "FR") (setq rooftype "F"))
    ((= stype "BF") (setq rooftype "B"))
    (T (setq rooftype "G")))

  ;; bay points
  (setq numBays (MSPL-Get-Int data "NUMBAYS"))
  (if (or (null numBays) (< numBays 1)) (setq numBays 1))
  (if (> numBays 60) (setq numBays 60))
  (setq bayPts (list 0.0) cum 0.0 i 0)
  (while (< i numBays)
    (setq sp (MSPL-Get-Num data (strcat "BAY" (itoa (1+ i)))))
    (setq rem (- len cum))
    (cond
      ((= i (1- numBays)) (setq sp rem))
      ((and sp (> sp 0) (< sp rem)) T)
      (T (setq sp (/ rem (float (- numBays i))))))
    (setq cum (+ cum sp) bayPts (append bayPts (list cum)) i (1+ i)))
  (setq bays (1- (length bayPts)) baysp (/ len bays))

  ;; width points (+ MG ridge / valley) — same as the plan
  (setq mgRidgePts '() mgValleyPts '())
  (cond
    ((= stype "MG")
      (setq mgGables (MSPL-Get-Int data "NUMGABLES"))
      (setq mgSpans  (MSPL-Get-Int data "SPANSPERGABLE"))
      (if (or (null mgGables) (< mgGables 2)) (setq mgGables 2))
      (if (or (null mgSpans) (< mgSpans 1)) (setq mgSpans 1))
      (if (> mgSpans 4) (setq mgSpans 4))
      (setq mgGableW (/ wid mgGables) mgSpanW (/ mgGableW mgSpans)
            mgColumnPts (list 0.0 wid) i 0)
      (while (< i mgGables)
        (setq base (* i mgGableW))
        (setq mgRidgePts (append mgRidgePts (list (+ base (/ mgGableW 2.0)))))
        (if (< i (1- mgGables))
          (setq valley (+ base mgGableW)
                mgValleyPts (append mgValleyPts (list valley))
                mgColumnPts (append mgColumnPts (list valley))))
        (if (> mgSpans 1)
          (progn
            (setq j 1)
            (while (< j mgSpans)
              (setq colY (+ base (* j mgSpanW)))
              (if (and (> colY 0) (< colY wid)) (setq mgColumnPts (append mgColumnPts (list colY))))
              (setq j (1+ j)))))
        (setq i (1+ i)))
      (setq widthPts (vl-sort mgColumnPts '<)))
    ((= stype "BF") (setq widthPts (list 0.0 (/ wid 2.0) wid)))
    ((= stype "MS")
      (setq numMod (MSPL-Get-Int data "NUMMODULES"))
      (if (or (null numMod) (< numMod 1)) (setq numMod 1))
      (if (> numMod 10) (setq numMod 10))
      (setq widthPts (list 0.0) cum 0.0 i 0)
      (while (< i numMod)
        (setq sp (MSPL-Get-Num data (strcat "MODULE" (itoa (1+ i)))))
        (setq rem (- wid cum))
        (cond
          ((= i (1- numMod)) (setq sp rem))
          ((and sp (> sp 0) (< sp rem)) T)
          (T (setq sp (/ rem (float (- numMod i))))))
        (setq cum (+ cum sp) widthPts (append widthPts (list cum)) i (1+ i))))
    (T (setq widthPts (list 0.0 wid))))

  ;; end-wall stations merged into the width grid (so letters match the plan)
  (setq ewcols (fix (/ wid 6250.0)))
  (if (< ewcols 1) (setq ewcols 1))
  (setq ewsp (/ wid ewcols))
  (if (< ewsp 6000) (progn (setq ewcols (1- ewcols)) (if (< ewcols 1) (setq ewcols 1)) (setq ewsp (/ wid ewcols))))
  (if (> ewsp 6500) (progn (setq ewcols (1+ ewcols)) (setq ewsp (/ wid ewcols))))
  (setq ewExpr (MSPL-Get-Str data "EWLEXPR"))
  (setq ewSpans (if (and ewExpr (/= ewExpr "") (boundp 'peb-parse-mod-expression))
                  (peb-parse-mod-expression ewExpr) nil))
  (if ewSpans
    (progn
      (setq ewSum 0.0) (foreach s ewSpans (setq ewSum (+ ewSum s)))
      (setq ewScale (if (> ewSum 0.0) (/ wid ewSum) 1.0) ewAcc 0.0 ewStations (list 0.0))
      (foreach s ewSpans (setq ewAcc (+ ewAcc (* s ewScale)) ewStations (append ewStations (list ewAcc)))))
    (progn
      (setq ewStations (list 0.0) ewY ewsp)
      (repeat ewcols (setq ewStations (append ewStations (list ewY)) ewY (+ ewY ewsp)))))
  (setq gridWpts widthPts)
  (foreach s ewStations
    (if (not (vl-some '(lambda (p) (< (abs (- p s)) 1.0)) gridWpts))
      (setq gridWpts (append gridWpts (list s)))))
  (setq gridWpts (vl-sort gridWpts '<))

  ;; ── Scales (same continuous formula as the plan) ─────────────────
  (setq maxSize (max len wid))
  (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ maxSize 45000.0))))
  (setq *PEB-DIM-SCALE* *PEB-TEXT-SCALE* ts *PEB-TEXT-SCALE* ds *PEB-DIM-SCALE*)

  ;; text styles + linetypes + linetype scale
  (make-text-style "PEB-TITLE" "romand.shx")
  (make-text-style "PEB-BODY"  "romans.shx")
  (make-text-style "PEB-DIM"   "romans.shx")
  (safe-load-ltype "CENTER") (safe-load-ltype "HIDDEN") (safe-load-ltype "DASHDOT")
  (setvar "LTSCALE" (max 60.0 (/ (max len wid) 400.0)))
  (setvar "CELTSCALE" 1.0)

  ;; new ROOF-only layers (everything else reuses the Standard layer set)
  (peb-comp-layer "ROOF-PURLIN" 8)      ; light grey purlin lines
  (peb-comp-layer "ROOF-DOWNSPOUT" 4)   ; cyan downspout squares
  (setvar "CLAYER" "0")

  (command "UNDO" "BEGIN")

  ;; ── ROOF OUTLINE (building rectangle) + eave edges ───────────────
  (setvar "CLAYER" "SHEETING")
  (command "RECTANG" (list 0.0 0.0) (list len wid))

  ;; ── PURLIN lines — parallel to the ridge, along the length ───────
  (setq npur (max 1 (fix (+ 0.5 (/ wid 1800.0)))))   ; ~1800 mm target spacing
  (setq psp (/ wid (float npur)))
  (setvar "CLAYER" "ROOF-PURLIN")
  (setq i 1)
  (while (< i npur)
    (setq y (* i psp))
    (entmake (list (cons 0 "LINE") (cons 8 "ROOF-PURLIN") (list 10 0.0 y 0.0) (list 11 len y 0.0)))
    (setq i (1+ i)))
  (setvar "CLAYER" "ROOF-PURLIN")
  (txt "ML" (list (* len 0.02) (+ wid (* 300.0 ts))) 300 0
       (strcat "PURLINS @ " (peb-comma (rtos psp 2 0)) " C/C"))

  ;; ── RIDGE / VALLEY lines (dash-dot) by structure type ────────────
  (cond
    ((member stype '("CS" "MS" "RC"))
      (peb-ridge-line 0 len (/ wid 2.0))
      (if (boundp 'peb-ridge-symbol)
        (vl-catch-all-apply (function (lambda () (peb-ridge-symbol (peb-ridge-bay-x bayPts) (/ wid 2.0)))))))
    ((= stype "MG")
      (foreach mgY mgRidgePts (peb-ridge-line 0 len mgY))
      (setvar "CLAYER" "GRID-LINES")
      (foreach mgY mgValleyPts
        (entmake (list (cons 0 "LINE") (cons 8 "GRID-LINES") (list 10 0.0 mgY 0.0) (list 11 len mgY 0.0))))
      (setvar "CLAYER" "TEXT")
      (foreach mgY mgValleyPts
        (txt "ML" (list (* len 0.72) (+ mgY (* 300.0 ts))) 280 0 "VALLEY GUTTER"))
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (* len 0.5) (+ wid (* 900.0 ts))) 320 0
           (strcat "MULTI-GABLE ROOF | " (itoa mgGables) " GABLES | " (itoa mgSpans) " SPAN(S) EACH")))
    ((= stype "BF")
      (setvar "CLAYER" "RIDGE")
      (entmake (list (cons 0 "LINE") (cons 8 "RIDGE") (list 10 0.0 (/ wid 2.0) 0.0) (list 11 len (/ wid 2.0) 0.0)))
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (* len 0.5) (+ (/ wid 2.0) (* 500.0 ts))) 300 0 "CENTRAL VALLEY"))
    ((= stype "FR")
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (* len 0.5) (* wid 0.5)) 400 0 "FLAT ROOF"))
    ((member stype '("SS" "LT"))
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (* len 0.5) (* wid 0.5)) 380 0 (if (= stype "LT") "LEAN-TO ROOF" "SINGLE SLOPE ROOF")))
    (T
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (* len 0.5) (* wid 0.5)) 380 0 (peb-roof-label stype rooftype))))

  ;; ── FALL glyphs (owner 7-Jul: IDENTICAL to the Column Layout Plan) ──
  ;; Use the SHARED pentagon-glyph set (the better symbol) so the Roof Plan and CLP match exactly.
  ;; (Superseded the local peb-roof-falls line-arrows, which are kept defined but no longer called.)
  (vl-catch-all-apply (function (lambda () (peb-fall-glyph-set data stype len wid bayPts mgRidgePts mgGableW))))

  ;; ── EAVE gutters + downspouts ────────────────────────────────────
  (vl-catch-all-apply (function (lambda () (peb-roof-gutters stype len wid bayPts))))

  ;; ── GRID  (numbers along x = top / FSW ; letters along y = left / LEW) ──
  ;; positions mirror the plan's grid stack so the two sheets register.
  (setq minSp len prevp nil)
  (foreach p bayPts   (if prevp (setq minSp (min minSp (- p prevp)))) (setq prevp p))
  (setq prevp nil)
  (foreach p gridWpts (if prevp (setq minSp (min minSp (- p prevp)))) (setq prevp p))
  (setq *PEB-BUBRAD* (max 900.0 (min (* 720.0 ts) (* 0.48 minSp))))
  (setq bubR (+ *PEB-BUBRAD* (* 60.0 ts)))
  (setq dimGap (* 1050.0 ds) topGap (* 1050.0 ds) txtGap (* 2000.0 ts))
  (setq yBayDim (+ wid topGap) yOvrDim (+ yBayDim topGap) ovrTxtH (* 490.0 ds))
  (setq gridY2 (+ yOvrDim ovrTxtH topGap *PEB-BUBRAD*))
  (setq gridX1 (- (- 0.0 (* 3.0 dimGap) ovrTxtH topGap) *PEB-BUBRAD*))

  ;; length numbers (bottom of stem near FSW edge -> up to bubble)
  (setq i 1)
  (foreach x bayPts
    (setvar "CLAYER" "GRID-LINES")
    (command "LINE" (list x (+ wid (* 300.0 ds))) (list x (- gridY2 bubR)) "")
    (setvar "CLAYER" "GRID")
    (grid-bubble x gridY2 (itoa i) "D")
    (setq i (1+ i)))

  ;; width letters (A at the TOP = FSW; counts down toward NSW)
  (setq j 0 nWid (length gridWpts))
  (foreach y gridWpts
    (setvar "CLAYER" "GRID-LINES")
    (command "LINE" (list (- 0.0 (* 300.0 ds)) y) (list (+ gridX1 bubR) y) "")
    (setvar "CLAYER" "GRID")
    (grid-bubble gridX1 y (chr (+ 65 (- nWid 1 j))) "R")
    (setq j (1+ j)))

  ;; ── ROOF ACCESSORIES (skylights / vents / opening) ───────────────
  (vl-catch-all-apply (function (lambda () (peb-draw-roof-accessories data len wid))))

  ;; ── ROOF EXTENSIONS + CANOPIES (footprints beyond the walls) ─────
  (vl-catch-all-apply (function (lambda () (peb-draw-roof-ext data len wid))))
  (vl-catch-all-apply (function (lambda () (peb-draw-canopy data len wid))))
  (setvar "CLAYER" "0")

  ;; ── TITLE + panel note + border ──────────────────────────────────
  (setq aNo (MSPL-Get-Int data "AREA_NUM"))
  (if (or (null aNo) (< aNo 1)) (setq aNo 1))
  (setq aLbl (strcat "AREA No. " (if (< aNo 10) (strcat "0" (itoa aNo)) (itoa aNo))))

  ;; title sits above the top grid stack (like the plan's title band)
  (setq yTtl (+ gridY2 *PEB-BUBRAD* txtGap txtGap))
  (setvar "CLAYER" "TEXT")
  ;; owner 7-Jul: the sheet title now lives in the shared title block; keep only the AREA + panel-note band.
  (txt "MC" (list (* len 0.5) yTtl) 380 0 (strcat aLbl "  |  " (peb-roof-panel-note data)))

  ;; owner 7-Jul: shared title block + border — IDENTICAL to the Column Layout Plan (see peb-frame-and-titleblock).
  (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data "ROOF PLAN"))))

  (command "UNDO" "END")
  (vl-catch-all-apply (function (lambda () (command "_.ZOOM" "_E"))))
  (setvar "CMDECHO" 1)
  (princ "\nMAIMAAR PEB-ROOF complete.")
  (princ))

;; ===========================================================================
;;  NON-INTERACTIVE ENTRY (mirror of peb-plan-from-file): read, draw, tile
;; ===========================================================================
(defun peb-roof-from-file (path / prev-last prev-max-x)
  (setq prev-last (entlast))
  (if prev-last
    (progn
      (command "_.REGEN")
      (setq prev-max-x (car (getvar "EXTMAX")))
      (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (princ (strcat "\nPEB-ROOF using data file: " path))
  (C:PEB-ROOF)
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place) (peb-tile-place prev-last prev-max-x))
  (princ))

(princ "\nMAIMAAR_PEB_Roof.lsp loaded — Roof Plan engine. Run C:PEB-ROOF or (peb-roof-from-file <path>).")
(princ)
