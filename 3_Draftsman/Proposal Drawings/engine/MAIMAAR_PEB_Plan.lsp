; ============================================================================
; MAIMAAR STEEL Pvt. Ltd.
; PEB Phase-2  --  Column Layout Plan  (standalone)
; Command: PEB-PLAN
;
; Self-contained: reads PEB_Data_B<n>_A<m>.txt (v3 format, written by
; Maimaar_PEB_Input.xlsm Generate Drawings VBA). No Phase-1 dependency.
; Geometry inherited from V40 Draw. Section-parity helpers (native dim
; entities, AcDbTable title block, MText / MLeader builders) are appended
; below the original code -- available for use, but the working hand-rolled
; dim-line-h / dim-line-v are kept intact.
;
; Two entry points:
;   C:PEB-PLAN                   interactive (Pick-file dialog)
;   (peb-plan-from-file <path>)  non-interactive (used by Excel VBA)
; ============================================================================

;; ===================== FILE READER =====================


;; ============================================================================
;; v3 FILE READER + TRANSLATOR  (Phase-2 native)
;; ============================================================================

(defun peb-v3-read-file (path / f line trimmed alist key val pos)
  (setq alist '())
  (setq f (open path "r"))
  (if (null f) (progn (princ (strcat "\nERROR: cannot open " path)) nil)
    (progn
      (while (setq line (read-line f))
        (setq trimmed (vl-string-trim " \t\r" line))
        (cond
          ((= trimmed "") nil)
          ((= (substr trimmed 1 1) ";") nil)
          ((and (= (substr trimmed 1 1) "[")
                (= (substr trimmed (strlen trimmed) 1) "]")) nil)
          (T (setq pos (vl-string-search "=" trimmed))
             (if pos (progn
               (setq key (vl-string-trim " " (substr trimmed 1 pos)))
               (setq val (vl-string-trim " " (substr trimmed (+ pos 2))))
               (setq alist (cons (cons key val) alist)))))))
      (close f) (reverse alist))))

(defun peb-v3-is-v3-format (path / f line ten first)
  (setq f (open path "r"))
  (if (null f) nil
    (progn (setq ten 0) (setq first nil)
      (while (and (< ten 12) (setq line (read-line f)) (not first))
        (setq line (vl-string-trim " \t\r" line))
        (cond ((= line "") nil) ((= (substr line 1 1) ";") nil)
              ((and (= (substr line 1 1) "[")
                    (= (substr line (strlen line) 1) "]")) (setq first T))
              (T (setq ten (1+ ten)))))
      (close f) first)))

(defun peb-alist-get (alist key / pair)
  (setq pair (assoc key alist)) (if pair (cdr pair) ""))

(defun peb-digits-only (s / out i ch)
  (setq out "" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (if (and (>= (ascii ch) 48) (<= (ascii ch) 57))
      (setq out (strcat out ch)))
    (setq i (1+ i))) out)

(defun peb-strip-non-numeric (s / out i ch keep)
  (setq out "" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (setq keep (or (and (>= (ascii ch) 48) (<= (ascii ch) 57))
                   (= ch ".") (= ch "-")))
    (if keep (setq out (strcat out ch)))
    (setq i (1+ i))) out)

(defun peb-split-on-char (s ch / out cur i c)
  (setq out '() cur "" i 1)
  (while (<= i (strlen s))
    (setq c (substr s i 1))
    (if (= c ch) (progn (setq out (cons cur out)) (setq cur ""))
                 (setq cur (strcat cur c)))
    (setq i (1+ i)))
  (setq out (cons cur out)) (reverse out))

(setq *PEB-FRAME-CODE-MAP*
  '(("CLEAR SPAN GABLE" . "CS") ("SINGLE SLOPE" . "SS")
    ("MULTI-SPAN" . "MS") ("MULTI SPAN" . "MS")
    ("LEAN-TO" . "LT") ("LEAN TO" . "LT")
    ("MULTI-GABLE" . "MG") ("MULTI GABLE" . "MG")
    ("FLAT ROOF" . "FR") ("ROOF ON RCC COLUMNS" . "RC") ("ROOF SYSTEM" . "RC")
    ("FLAT ROOF G+1" . "F2") ("DOUBLE STOREY FLAT ROOF" . "F2") ("FLAT ROOF DOUBLE STOREY" . "F2")
    ("ARCHED CLEAR SPAN" . "ACS") ("ARCHED MULTI-SPAN" . "AMS")
    ("ARCHED MULTI SPAN" . "AMS") ("BUTTERFLY" . "BF")
    ("CANTILEVER CANOPY" . "CC") ("PETROL CANOPY" . "PP") ("PETROL PUMP" . "PP")))

(defun peb-frame-display-to-code (s / up pair)
  (setq up (strcase (vl-string-trim " " s)))
  (cond ((member up '("CS" "SS" "MS" "LT" "MG" "FR" "F2" "RC" "ACS" "AMS" "BF" "CC" "PP")) up)
        ((setq pair (assoc up *PEB-FRAME-CODE-MAP*)) (cdr pair))
        ;; G+1 / double-storey flat roof — MUST be tested BEFORE the "*FLAT*" fallback below.
        ((wcmatch up "*G+1*,*G + 1*,*DOUBLE*STOREY*,*DOUBLE*STORY*,*TWO*STOREY*,*TWO*STORY*") "F2")
        ;; fuzzy fallbacks (owner 8-Jul) — the IF sends VERBOSE option strings that don't match the
        ;; exact alist keys (e.g. "Roof System without steel columns (rafter is fixed on RCC columns)",
        ;; "Multi-Gable (CS & MS)", "Arch Clear Span (ACS)"), which previously all defaulted to CS.
        ;; Order: most specific first (ARCH-MULTI before ARCH; MULTI-GABLE before MULTI-SPAN).
        ((wcmatch up "*ROOF*SYSTEM*,*RCC*,*ON RCC*,*OVER RCC*,*RC COLUMN*") "RC")
        ((wcmatch up "*PETROL*,*CNG*,*FUEL*")                 "PP")
        ((wcmatch up "*FLAT*")                                "FR")
        ;; FALCON is a 2-wing canopy like the butterfly (centre PEAK vs valley) — it carries no
        ;; "butterfly" in its label, so without this it fell through to the CS default.
        ((wcmatch up "*BUTTERFLY*,*FALCON*")                  "BF")
        ((wcmatch up "*ARCH*MULTI*")                          "AMS")
        ((wcmatch up "*ARCH*")                                "ACS")
        ((wcmatch up "*MULTI*GABLE*")                         "MG")
        ;; CANTILEVER MUST BE TESTED BEFORE SINGLE-SLOPE.  The canopy label
        ;; "Single-Sided Cantilever - Slope Towards Columns" contains SINGLE ... SLOPE in order, so
        ;; "*SINGLE*SLOPE*" swallowed it and drew a mono-slope box building instead of a canopy.
        ;; drawingData.ts normalises canopies to "Cantilever Canopy" before writing BP_FRAME_TYPE, so
        ;; this is latent on the live path — but a hand-edited PEB_Data would hit it silently.
        ((wcmatch up "*CANTILEVER*,*SINGLE*SIDED*,*ONE*SIDED*") "CC")
        ((wcmatch up "*SINGLE*SLOPE*,*MONO*")                 "SS")
        ((wcmatch up "*LEAN*")                                "LT")
        ((wcmatch up "*MULTI*SPAN*")                          "MS")
        ((wcmatch up "*CLEAR*SPAN*")                          "CS")   ; explicit, not by fall-through
        (T                                                    "CS")))

(defun peb-slope-to-denom (slopeStr customStr / s pos)
  (setq s (vl-string-trim " " slopeStr))
  (if (or (= (strcase s) "OTHER (SPECIFY)") (= s ""))
    (setq s (vl-string-trim " " customStr)))
  (setq pos (vl-string-search ":" s))
  (if pos (vl-string-trim " " (substr s (+ pos 2))) s))

;; ── RULE 4B.34 — A WIDTH CHAIN IS WRITTEN FROM GRID A DOWNWARD ──────────────────
;; The house convention, on every layout and tender: a width chain is measured from grid A
;; downward, and A is the FAR side wall — the TOP of the plan. Owner 29-Aug: "we always
;; measure the modules from A to downward."
;;
;; The engine lays width stations out from y = 0, which is the NEAR side wall. So the FIRST
;; term of a written width chain belongs at the TOP, i.e. it is the LAST station the engine
;; accumulates. A width chain must therefore be REVERSED before it is accumulated, or the
;; whole building is drawn MIRRORED across its width.
;;
;; LENGTH chains are untouched — grid 1 is the left end in both conventions.
;;
;; WHY THIS SURVIVED SO LONG: a symmetric chain reversed is itself. 2@15240 mirrors to
;; 2@15240 and looks perfect. MSPL-26-271 (Rainbow) is the first job with UNEQUAL width
;; modules — 2@16662.40 + 16395.70 + 13874.12 — so it is the first time the mirror shows.
;; Anything that builds stations across the WIDTH must go through here.
(defun peb-width-order (lst) (reverse lst))

;; Width-chain stations: parse, REVERSE (above), scale to close exactly on `total`, then
;; accumulate from 0. The width counterpart of peb-fr-scaled-stations / peb-elev-stations,
;; which stay as they are because they also serve LENGTH chains.
(defun peb-width-stations (expr total / lst sum sc acc out)
  (setq lst (peb-width-order (peb-parse-mod-expression expr)))
  (if (or (null lst) (= (length lst) 0))
    (list 0.0 total)
    (progn
      (setq sum 0.0) (foreach s lst (setq sum (+ sum s)))
      (setq sc (if (> sum 0.0) (/ total sum) 1.0) acc 0.0 out (list 0.0))
      (foreach s lst (setq acc (+ acc (* s sc))) (setq out (append out (list acc))))
      out)))

(defun peb-parse-mod-expression (expr / parts seg out atPos cnt sp i)
  (setq expr (vl-string-trim " " expr) out '())
  (if (= expr "") nil
    (progn (setq parts (peb-split-on-char expr "+"))
      (foreach seg parts
        (setq seg (vl-string-trim " " seg))
        (setq atPos (vl-string-search "@" seg))
        (cond (atPos
                (setq cnt (atoi (substr seg 1 atPos)))
                (setq sp  (atof (substr seg (+ atPos 2))))
                (setq i 0)
                (while (< i cnt) (setq out (cons sp out)) (setq i (1+ i))))
              (T (setq out (cons (atof seg) out)))))
      (reverse out))))

;; peb-parse-frame-grid (Tier 0) — parse the canonical FRAME-GRID string
;;   "1@25000 | 2@25000 | 3@25000"   ( | = valley between gables ; = per-gable overrides )
;; into a LIST OF GABLES, each a list of its sub-module span widths (mm), e.g.
;;   -> ((25000.0) (25000.0 25000.0) (25000.0 25000.0 25000.0)).
;; Returns nil for a blank string or one with no "|" — the caller then falls back to the plain
;; MODEXPR / equal-gable path (so legacy multi-gables are unchanged).  Reuses peb-split-on-char +
;; peb-parse-mod-expression; per-gable overrides after ";" are ignored here (they shape the roof,
;; not the plan column grid).
(defun peb-parse-frame-grid (gridStr / segs out semi spansPart)
  (setq gridStr (vl-string-trim " " (if gridStr gridStr "")))
  (if (or (= gridStr "") (not (vl-string-search "|" gridStr)))
    nil
    (progn
      (setq segs (peb-split-on-char gridStr "|") out '())
      (foreach seg segs
        (setq semi (vl-string-search ";" seg))
        (setq spansPart (if semi (substr seg 1 semi) seg))
        (setq out (cons (peb-parse-mod-expression (vl-string-trim " " spansPart)) out)))
      (reverse out))))

(defun peb-build-sheeting-string (data prefix / typ outProf outMat pirThk lbl)
  ;; owner 6-Jul: FULL sheeting+insulation build-up label (shared with the Section). Plan's copy WINS in the
  ;; CRM per-building session (Plan loads after Section), so it must emit the SAME complete label the Section
  ;; owns via peb-panel-label. peb-panel-label lives in the Section engine (loaded first in every render set);
  ;; call it ONLY when it is a real function AND returns a non-empty string, else fall back to a digit-bearing
  ;; label (the section's split-at-first-digit needs a digit). Wrapped so a bad label can NEVER abort the
  ;; data load / plan drawing.
  (setq typ    (peb-alist-get data (strcat "PN_" prefix "_TYPE")))
  (setq outMat (peb-alist-get data (strcat "PN_" prefix "_OUTER_MAT")))
  (setq outProf (peb-alist-get data (strcat "PN_" prefix "_OUTER_PROFILE")))
  (setq pirThk (peb-alist-get data (strcat "PN_" prefix "_PIR_THK")))
  (setq lbl (vl-catch-all-apply
              (function (lambda () (if (boundp 'peb-panel-label) (peb-panel-label data prefix) nil)))))
  (if (and lbl (not (vl-catch-all-error-p lbl)) (= (type lbl) 'STR) (/= lbl ""))
    (strcat prefix " SHEETING  " lbl)
    ;; fallback = the original simple label (always has a digit)
    (cond
      ((or (= (strcase typ) "SANDWICH PANEL") (= (strcase typ) "SANDWICH"))
        (strcat prefix " SHEETING  " (if (= pirThk "") "50" pirThk) "MM PIR SANDWICH PANEL"))
      ((or (= (strcase typ) "SINGLE SKIN") (= typ ""))
        (strcat prefix " SHEETING:  " (if (= outMat "") "0.50mm AZ 150" outMat)
                (if (/= outProf "") (strcat " - " outProf) "")))
      (T (strcat prefix " SHEETING:  " (if (= outMat "") "0.50mm AZ 150" outMat))))))

(defun peb-v3-to-legacy (v3 / out project client proposal bldgno revno
                              len wid heightVal brick slope slopeRaw slopeCustom
                              stype stypeRaw modExpr modList numMod i m
                              bayExpr bayList numBay b numIntCols numGab spanPerGab
                              wind exposure coll collNum roofSheet wallSheet)
  (setq out '())
  (setq project   (peb-alist-get v3 "HD_PROJECT"))
  (setq client    (peb-alist-get v3 "HD_CUSTOMER"))
  (setq proposal  (peb-alist-get v3 "HD_PROPOSAL_NO"))
  (setq bldgno    (peb-alist-get v3 "BUILDING_NUM"))
  (setq revno     (peb-alist-get v3 "HD_REVISION"))
  (setq proposal (peb-digits-only proposal))
  (if (= proposal "") (setq proposal "000"))
  (if (= bldgno   "") (setq bldgno   "01"))
  (if (= revno    "") (setq revno    "0"))
  (setq out (cons (cons "PROJECT"  project ) out))
  (setq out (cons (cons "CLIENT"   client  ) out))
  (setq out (cons (cons "PROPOSAL" proposal) out))
  (setq out (cons (cons "BLDGNO"   bldgno  ) out))
  (setq out (cons (cons "REVNO"    revno   ) out))
  ;; carry the IF title-block fields through to the legacy data so the
  ;; Mammut title block can link them dynamically (blank -> sensible default).
  (setq out (cons (cons "PROPOSAL_FULL" (peb-alist-get v3 "HD_PROPOSAL_NO")) out))
  (setq out (cons (cons "TBDATE"   (peb-alist-get v3 "HD_DATE"))      out))
  (setq out (cons (cons "TBDRN"    (peb-alist-get v3 "HD_DRN_BY"))    out))
  (setq out (cons (cons "TBCHK"    (peb-alist-get v3 "HD_CHK_BY"))    out))
  (setq out (cons (cons "TBBLDGNAME" (peb-alist-get v3 "HD_BLDG_NAME")) out))
  (setq out (cons (cons "LOCATION"   (peb-alist-get v3 "HD_LOCATION"))  out))
  (setq out (cons (cons "IDENTICAL"  (peb-alist-get v3 "HD_IDENTICAL"))  out))
  (setq out (cons (cons "BLDGCOUNT"  (peb-alist-get v3 "BUILDING_COUNT")) out))
  (setq len (peb-alist-get v3 "BP_LENGTH"))
  (setq wid (peb-alist-get v3 "BP_WIDTH"))
  (setq out (cons (cons "LENGTH" len) out))
  (setq out (cons (cons "WIDTH"  wid) out))
  (setq slopeRaw    (peb-alist-get v3 "BP_ROOF_SLOPE"))
  (setq slopeCustom (peb-alist-get v3 "BP_ROOF_SLOPE_CUSTOM"))
  (setq slope (peb-slope-to-denom slopeRaw slopeCustom))
  (setq out (cons (cons "SLOPE" slope) out))
  (setq stypeRaw (peb-alist-get v3 "BP_FRAME_TYPE"))
  (setq stype (peb-frame-display-to-code stypeRaw))
  (setq out (cons (cons "STYPE" stype) out))
  (setq heightVal (peb-alist-get v3 "BP_EAVE_HEIGHT"))
  (setq out (cons (cons "CLEARHEIGHT" heightVal) out))
  ;; G+1 (F2) double-storey: SEPARATE ground- & first-floor clear heights (owner 15-Jul).  Optional; when
  ;; absent the F2 branch falls back to an equal split of the eave height.
  (setq out (cons (cons "GROUNDCH" (peb-alist-get v3 "BP_GROUND_CH")) out))
  (setq out (cons (cons "FIRSTCH"  (peb-alist-get v3 "BP_FIRST_CH")) out))
  (setq brick (peb-alist-get v3 "BP_BRICK_HT"))
  (if (= brick "") (setq brick "0"))
  (setq out (cons (cons "BRICKHEIGHT" brick) out))
  (setq modExpr (peb-alist-get v3 "BP_WIDTH_MOD"))
  ;; Rule 4B.34: reverse here, once, so MODULE1..N are in GEOMETRY order (NSW -> FSW).
  ;; Everything that reads the MODULE keys — widthPts, peb-comp-width-pts — then
  ;; accumulates them from y=0 correctly. MODEXPR below stays VERBATIM: it is printed on
  ;; the plan and must read the way the owner wrote it, A downward.
  (setq modList (peb-width-order (peb-parse-mod-expression modExpr)))
  (setq numMod (length modList))
  (setq out (cons (cons "NUMMODULES" (itoa numMod)) out))
  (setq i 1)
  (foreach m modList
    (setq out (cons (cons (strcat "MODULE" (itoa i)) (rtos m 2 0)) out))
    (setq i (1+ i)))
  (setq bayExpr (peb-alist-get v3 "BP_BAY_SPACING"))
  (setq bayList (peb-parse-mod-expression bayExpr))
  (setq numBay  (length bayList))
  (setq out (cons (cons "NUMBAYS" (itoa numBay)) out))
  (setq i 1)
  (foreach b bayList
    (setq out (cons (cons (strcat "BAY" (itoa i)) (rtos b 2 0)) out))
    (setq i (1+ i)))
  (setq numIntCols (peb-alist-get v3 "BP_NUM_INT_COLS"))
  (cond ((= stype "MG")
          (setq numGab (max 2 (atoi numIntCols)))
          (setq spanPerGab 1)
          (if (= numGab 0) (setq numGab 2)))
        (T (setq numGab 1) (setq spanPerGab 1)))
  (setq out (cons (cons "NUMGABLES"     (itoa numGab)) out))
  (setq out (cons (cons "SPANSPERGABLE" (itoa spanPerGab)) out))
  (setq wind     (peb-alist-get v3 "DL_WIND_SPEED"))
  (setq exposure (peb-alist-get v3 "DL_EXPOSURE"))
  (setq coll     (peb-alist-get v3 "DL_COLLATERAL"))
  (setq collNum  (peb-strip-non-numeric coll))
  (if (= collNum "") (setq collNum "0.00"))
  (setq out (cons (cons "WINDSPEED"  wind) out))
  (setq out (cons (cons "EXPOSURE"   (if (= exposure "") "B" exposure)) out))
  (setq out (cons (cons "COLLATERAL" (strcat collNum " KN/m2")) out))
  ;; design loads + design code carried straight from the IF so the
  ;; Mammut title block links them dynamically (no hardcoded defaults).
  (setq out (cons (cons "LIVEROOF"   (peb-alist-get v3 "DL_LIVE_ROOF"))   out))
  (setq out (cons (cons "LIVEFRAME"  (peb-alist-get v3 "DL_LIVE_FRAME"))  out))
  (setq out (cons (cons "SEISMIC"    (peb-alist-get v3 "DL_SEISMIC"))     out))
  (setq out (cons (cons "SNOW"       (peb-alist-get v3 "DL_SNOW"))        out))
  (setq out (cons (cons "DESIGNCODE" (peb-alist-get v3 "DL_DESIGN_CODE")) out))
  (setq out (cons (cons "TEMP"       (peb-alist-get v3 "DL_TEMP"))        out))
  (setq out (cons (cons "RAIN"       (peb-alist-get v3 "DL_RAINFALL"))    out))
  (setq roofSheet (peb-build-sheeting-string v3 "ROOF"))
  (setq wallSheet (peb-build-sheeting-string v3 "WALL"))
  (setq out (cons (cons "ROOFSHEETING" roofSheet) out))
  (setq out (cons (cons "WALLSHEETING" wallSheet) out))
  ;; Phase-2A v6: dim display mode (mm / mm & Ft / Only Ft)
  (setq out (cons (cons "DIM_DISPLAY"
                        (peb-alist-get v3 "BP_DIM_DISPLAY")) out))
  ;; Phase-2A v12: end-wall frame type for Plan MLEADER labels
  (setq out (cons (cons "EW_LEFT_FRAME"
                        (peb-alist-get v3 "BP_EW_LEFT_FRAME")) out))
  (setq out (cons (cons "EW_RIGHT_FRAME"
                        (peb-alist-get v3 "BP_EW_RIGHT_FRAME")) out))
  ;; per-dimension measurement BASIS (IF) for basis-aware plan dimensions
  (setq out (cons (cons "LENGTH_REF"    (peb-alist-get v3 "BP_LENGTH_REF"))    out))
  (setq out (cons (cons "WIDTH_REF"     (peb-alist-get v3 "BP_WIDTH_REF"))     out))
  (setq out (cons (cons "WIDTH_MOD_REF" (peb-alist-get v3 "BP_WIDTH_MOD_REF")) out))
  (setq out (cons (cons "BAY_REF"       (peb-alist-get v3 "BP_BAY_REF"))       out))
  (setq out (cons (cons "EW_LEFT_REF"   (peb-alist-get v3 "BP_EW_LEFT_REF"))   out))
  (setq out (cons (cons "EW_RIGHT_REF"  (peb-alist-get v3 "BP_EW_RIGHT_REF"))  out))
  (setq out (cons (cons "HEIGHT_REF"    (peb-alist-get v3 "BP_HEIGHT_REF"))    out))
  ;; raw grouped spacing expressions (mm) — printed verbatim on the plan
  (setq out (cons (cons "BAYEXPR" (peb-alist-get v3 "BP_BAY_SPACING"))      out))
  (setq out (cons (cons "MODEXPR" (peb-alist-get v3 "BP_WIDTH_MOD"))        out))
  (setq out (cons (cons "EWLEXPR" (peb-alist-get v3 "BP_EW_LEFT_SPACING"))  out))
  (setq out (cons (cons "EWREXPR" (peb-alist-get v3 "BP_EW_RIGHT_SPACING")) out))
  ;; end-wall girts (gate end-wall posts) + wall conditions (for sections/elevations)
  (setq out (cons (cons "EW_LEFT_GIRTS"  (peb-alist-get v3 "BP_EW_LEFT_GIRTS"))  out))
  (setq out (cons (cons "EW_RIGHT_GIRTS" (peb-alist-get v3 "BP_EW_RIGHT_GIRTS")) out))
  (setq out (cons (cons "OW_NSW" (peb-alist-get v3 "OW_NSW")) out))
  (setq out (cons (cons "OW_FSW" (peb-alist-get v3 "OW_FSW")) out))
  (setq out (cons (cons "OW_LEW" (peb-alist-get v3 "OW_LEW")) out))
  (setq out (cons (cons "OW_REW" (peb-alist-get v3 "OW_REW")) out))
  ;; Pass every placement (PL*) and bracing (BR*) key through verbatim so the
  ;; plan can draw doors/windows + the braced-bay clash flag. (wcmatch "PL*" is
  ;; safe — letters are literal; no '@'/'#' specials in these key names.)
  (foreach kv v3
    (if (and (car kv)
             (or (wcmatch (strcase (car kv)) "PL*")
                 (wcmatch (strcase (car kv)) "BR*")))
      (setq out (cons kv out))))
  ;; AR0 enabler: append EVERY raw IF key AFTER the mapped legacy keys (assoc finds the mapped
  ;; ones first, so nothing changes for them) — makes AREA_NUM, AR_*, and future component blocks
  ;; (MZ_/CR_/PT_/ST_/RX_/CN_/FA_/RM_/LN_) readable by the plan via MSPL-Get-*.
  (append (reverse out) v3))

;; ============================================================================
;; FILE READER (v3-aware)
;; ============================================================================

(defun MSPL-Read-Data (dataFile / v3data)
  (cond
    ((peb-v3-is-v3-format dataFile)
      (princ (strcat "\n  v3 format detected: " dataFile))
      (setq v3data (peb-v3-read-file dataFile))
      (if v3data (peb-v3-to-legacy v3data) nil))
    (T
      (alert (strcat "Phase-2 expects v3-format data files.\n\n"
                     "File:  " dataFile "\n\n"
                     "Generate via Maimaar_PEB_Input.xlsm Generate Drawings."))
      nil)))

(defun MSPL-Get-Str (data key / pair)
  (setq pair (assoc key data))
  (if pair (cdr pair) "")
)

(defun MSPL-Get-Num (data key / v s)
  (setq s (MSPL-Get-Str data key))
  (if (= s "") nil
    (progn
      (setq v (distof s 2))
      (if v v nil)
    )
  )
)

(defun MSPL-Get-Int (data key / v)
  (setq v (MSPL-Get-Num data key))
  (if v (fix (+ v 0.5)) nil)
)

;; ===================== UTILITY FUNCTIONS =====================

(defun format-date (cdate / ds y m d months)
  (setq ds (rtos cdate 2 6))
  (setq y (substr ds 1 4))
  (setq m (atoi (substr ds 5 2)))
  (setq d (atoi (substr ds 7 2)))
  (setq months '("Jan" "Feb" "Mar" "Apr" "May" "Jun"
                  "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))
  (strcat (itoa d) "-" (nth (1- m) months) "-" y)
)

(defun format-slope (s / pos)
  (if (or (null s) (= s "")) (setq s "10"))
  (setq pos (vl-string-search ":" s))
  (if pos s (strcat "1:" s))
)

(defun slope-denom (slopeStr / pos d)
  ;; Returns the slope denominator as a number (e.g. "1:10" -> 10)
  ;; Parity helper with PEB_Section.lsp.
  (setq pos (vl-string-search ":" slopeStr))
  (if pos
    (progn
      (setq d (distof (substr slopeStr (+ pos 2)) 2))
      (if (and d (> d 0)) d 10.0)
    )
    (progn
      (setq d (distof slopeStr 2))
      (if (and d (> d 0)) d 10.0)
    )
  )
)

(defun format-wind-speed (s / us)
  (if (or (null s) (= s "")) (setq s "AS PER DESIGN"))
  (setq us (strcase s))
  (cond
    ((or (vl-string-search "KM" us) (vl-string-search "KPH" us)
         (vl-string-search "MPH" us))
      (strcat s " (3-SECOND GUST)"))
    (T (strcat s " KM/H (3-SECOND GUST)"))
  )
)

(defun make-layer (lname color ltype lw)
  (if (not (tblsearch "LAYER" lname))
    (progn
      (command "LAYER" "M" lname "C" color lname "LT" ltype lname "")
      (if lw (command "LAYER" "LW" lw lname ""))
    )
    (progn
      ;; Layer already exists - REFRESH its colour, linetype, and lineweight
      ;; so that LISP edits to layer attributes always take effect (parity
      ;; with PEB_Section.lsp's make-layer behaviour).
      (command "LAYER" "C" color lname "LT" ltype lname "S" lname "")
      (if lw (command "LAYER" "LW" lw lname ""))
    )
  )
)

(defun safe-load-ltype (lt)
  (if (not (tblsearch "LTYPE" lt))
    (command "-LINETYPE" "LOAD" lt "acad.lin" "")
  )
)

(defun make-text-style (sname font)
  (if (not (tblsearch "STYLE" sname))
    (command "-STYLE" sname font "" "" "" "" "" "")
  )
)

;; ALL drawing-body text is UPPERCASE (owner rule + Mammut master). These helpers
;; emit single-line TEXT (no MText/RTF), so a blanket strcase is safe here.
(defun txt (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if str (setq str (strcase str)))
  (setvar "TEXTSTYLE" "PEB-BODY")
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
)

;; BOLD IS A HEAVIER PEN, AND IT HAS TO ACTUALLY BE SET (owner 28-Aug: "wall and roof
;; sheeting headings in sections must be BOLD ... for more professional look").
;;
;; MAIMAAR_PEB_Standard.lsp already states the rule - "Bold headings = heavier PEN on
;; romand, not Arial-bold" - because the UNIVERSAL standing rule is that ALL drawing text is
;; romand.shx, and an SHX font has no bold cut. But this helper only switched TEXTSTYLE to
;; PEB-TITLE, and PEB-TITLE is romand.shx exactly like PEB-BODY. So it changed nothing:
;; every "bold" heading on every sheet has been plotting at the same 0.13 mm as body text,
;; and the headings never stood out from the notes under them.
;;
;; CELWEIGHT is the pen. 0.30 mm against the TEXT layer's 0.13 gives a heading that reads as
;; a heading at A4 without changing the letterforms. Restored to ByLayer straight after, so
;; nothing else inherits it.
(defun txt-bold (just pt h rot str / prevLw)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if str (setq str (strcase str)))
  (setvar "TEXTSTYLE" "PEB-TITLE")
  (setq prevLw (getvar "CELWEIGHT"))
  (vl-catch-all-apply (function (lambda () (setvar "CELWEIGHT" 30))))
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
  (vl-catch-all-apply (function (lambda () (setvar "CELWEIGHT" (if prevLw prevLw -1)))))
)

;; ROMAND label (owner STANDING RULE: ALL drawing text = ROMAND / romand.shx, not Arial).
(defun txt-rom (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if str (setq str (strcase str)))
  (setvar "TEXTSTYLE" "ROMAND")
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
)

(defun txt-dim (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if str (setq str (strcase str)))
  (setvar "TEXTSTYLE" "PEB-DIM")
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
)

;; Grid bubble — Mammut MIRROR (owner 7-Jul): a GREEN shield/pennant = circle + a triangular pointer
;; Width grid LETTER for a 0-based index, SKIPPING "I" (standard structural grid convention; matches the
;; IF letter list A..H, J, K, … — owner 11-Jul "skip I").  idx 0-7 -> A-H; idx 8 -> J; 9 -> K; …  Only I
;; is skipped (not O): the IF list runs A..N with no O, so the engine agrees for every real building.
(defun peb-grid-letter (idx)
  (chr (+ 65 idx (if (>= idx 8) 1 0))))

;; Inverse: a grid-letter char -> its 0-based index, accounting for the skipped I.  'A'->0 … 'H'->7,
;; 'J'->8, 'K'->9 …  (An 'I', which should never be offered, maps to 8 like 'J' — harmless.)
;; ── THE WIDTH-GRID LETTER RULE — ONE ANSWER FOR EVERY SHEET (owner 26-Aug) ───
;; "Sync all the sheeting, especially the grid lines, with each other."
;;
;; The Column Layout Plan is the reference: it letters the width REVERSED, so A is
;; at the FAR side wall (y = width) and the last letter is at the NEAR side wall
;; (y = 0).  Any sheet that letters the width must give the SAME answer, so they all
;; ask this one function instead of each doing its own (chr (+ 65 i)).
;;
;; Audited on B-03 (width 30480) before this existed — letter at y=0 / y=30480:
;;    Column Layout Plan   F / A      <- the reference
;;    End Wall Framing     F / A      ok
;;    End Wall Sheeting    F / A      ok
;;    Cross Section        A / F      INVERTED
;;    Roof Framing Plan    A / F      INVERTED
;;    Roof Sheeting Plan   A / F      INVERTED
;; Three sheets in the same set lettered the same building back to front.
;;
;;   i    = width-station index, 0 = y=0 = the NEAR side wall
;;   nSt  = how many width stations the merged grid has
;; Skips I via peb-grid-letter and carries the cross-area offset, like the plan.
(defun peb-width-letter (i nSt)
  (peb-grid-letter (+ (- nSt 1 i) (if *PEB-GRID-LET-OFS* *PEB-GRID-LET-OFS* 0))))

(defun peb-grid-letter-index (ch / a)
  (setq a (ascii (strcase ch)))
  (- a 65 (if (> a 73) 1 0)))

;; aimed at the grid line (toward the building), with the number/letter centred in the circle.  dir tells
;; which way the pointer aims (toward the building): "D" down (top number row), "U" up (elevation bubbles
;; below the wall), "L" left, "R" right (left letter column).  Omitted dir defaults to "R" (never crashes).
;; -- OVERALL DIMS: MILLIMETRES, WITH FEET ALONGSIDE (owner 26-Aug) ------------
;; "ALL DIMENSIONS in all drawings must be in mm not in Meter, along with Ft."
;; This first shipped as metres ("121.92 M (400'-0\")"), which contradicted General
;; Note 1 on the very same sheet.  It now uses the house format the plan already
;; uses for BUILDING LENGTH - millimetres, comma-grouped like the bay chain right
;; above it, with feet-and-inches in square brackets:  121,920 [400'-0\"]
;; peb-mm-to-ft-in already carries the whole-foot rollover, so nothing ever prints
;; as 399'-12\".
(defun peb-dim-mft (mm)
  (strcat (peb-comma (rtos mm 2 0)) " [" (peb-mm-to-ft-in mm) "]"))

;; -- A BUBBLE MUST FIT THE DRAWING IT LABELS (owner 26-Aug) -------------------
;; Sizing a grid bubble from *PEB-TEXT-SCALE* alone makes it track the drawing's
;; WIDTH.  That is fine on a plan, which is about as tall as it is wide, and wrong
;; on a wall elevation: the 122 m x 7 m side wall gives TEXT-SCALE 2.71, so the
;; bubble came out 4.9 m across - two thirds of a 7.25 m bay (sixteen of them
;; nearly touching) and taller than the wall band it labels.
;;
;; The size itself is NOT the thing to change.  Every sheet is auto-fitted to A4,
;; so a radius of 720 * TEXT-SCALE plots at the same ~8.5 mm whatever the building
;; -- that invariant is the entire reason TEXT-SCALE exists, and an earlier pass
;; that capped the bubble against the WALL HEIGHT destroyed it and plotted a 2.6 mm
;; bubble nobody could read (owner: "it should not be too small or too big").
;;
;; What was actually wrong on the 122 m wall is CROWDING: sixteen bays at 15.8 mm
;; of paper each, with a 10.6 mm bubble sitting in every one.  So the only cap is a
;; bay FRACTION -- scale-invariant, so it reads the same on paper as in the model:
;; diameter <= 44% of the tightest bay, leaving clear white between neighbours.
(defun peb-bub-radius (minSp / r)
  (setq r (* 1100.0 *PEB-TEXT-SCALE*))                 ; ~8 mm dia on the plotted A4
  (if (> minSp 1.0) (setq r (min r (* 0.30 minSp))))   ; ...but never over 60% of a bay
  (max (* 300.0 *PEB-TEXT-SCALE*) r))                  ; floor stays paper-constant too

;; Smallest gap in a station list (0.0 if there are fewer than two stations).
;; The list is normally ascending, but abs() keeps this honest either way.
(defun peb-min-spacing (stations / m i d)
  (setq m 0.0 i 0)
  (while (< (1+ i) (length stations))
    (setq d (abs (- (nth (1+ i) stations) (nth i stations))))
    (if (and (> d 1.0) (or (<= m 0.0) (< d m))) (setq m d))
    (setq i (1+ i)))
  m)

;; Smallest real gap between consecutive grid stations (nil if there is only one).
;; Duplicates and hair-splitting coincidences are ignored — two stations 0.5 mm apart are
;; one line, not a gap the bubbles have to fit into.
(defun peb-grid-min-gap (pts / prev m g)
  (setq m nil prev nil)
  (foreach p pts
    (if prev (progn (setq g (- p prev))
                    (if (and (> g 1.0) (or (null m) (< g m))) (setq m g))))
    (setq prev p))
  m)

;; How many staggered rows the bubbles need so neighbours never touch.
;; 1 = side by side, which is the normal case and the only one before B-03.
;; Capped at 3: past that the row stack would cost more sheet than the crowding does, and
;; the caller shrinks the bubble instead.
(defun peb-bub-rows (pitch gap)
  (if (or (null gap) (<= gap 0.0) (<= pitch gap))
    1
    (min 3 (fix (+ 0.9999 (/ pitch gap))))))

;; Which stagger row an index falls in — our own modulo, deliberately NOT the built-in `rem`.
;;
;; peb-plan-from-file declares `rem` as a LOCAL (the length still to be divided among the
;; bays, line ~4681), which shadows the function inside the whole defun. Calling (rem a b)
;; there evaluates a NUMBER as a function: "; error: bad function: 15240.0", the plan unwinds
;; silently, and the sheet comes out as a bare building outline with no dimensions, no
;; bubbles and no title block. Measured, not theorised — that is exactly what B-03 produced.
;; Never call a built-in this file also uses as a variable name.
(defun peb-bub-row (idx rows)
  (if (or (null rows) (< rows 2)) 0 (- idx (* rows (fix (/ idx rows))))))

(defun grid-bubble (x y label dir / r h prev pc d tail apex p1 p2 L phi alpha)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setq r (if *PEB-BUBRAD* *PEB-BUBRAD* (* 620 *PEB-TEXT-SCALE*)) prev (getvar "CLAYER") pc (getvar "CECOLOR"))
  (setq h (* r (cond ((<= (strlen label) 1) 0.95)   ; 1 char  -> fills the circle
                     ((= (strlen label) 2) 0.66)    ; 2 chars -> fit
                     (T 0.48))))                    ; 3+ chars -> fit
  (setq d (cond ((= dir "D") (list 0.0 -1.0)) ((= dir "U") (list 0.0 1.0))
                ((= dir "L") (list -1.0 0.0)) (T (list 1.0 0.0)))
        tail (* r 1.15)
        apex (list (+ x (* (car d) (+ r tail)))      (+ y (* (cadr d) (+ r tail)))))
  ;; POINTER (owner 9-Jul: "the V lines are crossing the bubble circle lines").  The two legs used to
  ;; start at 0.688*r from the centre -- INSIDE the circle -- so each leg cut across the circumference.
  ;; Start them exactly ON the circle, at the TANGENT points from the apex: the legs then touch the
  ;; circle and never cross it.  For an apex at distance L from the centre, the tangent points lie at
  ;; +/- alpha from the pointing direction, where cos(alpha) = r / L  (so alpha = atan(sqrt(L^2-r^2), r)).
  (setq L     (+ r tail)
        phi   (atan (cadr d) (car d))                 ; direction angle of the pointer
        alpha (atan (sqrt (- (* L L) (* r r))) r)     ; half-angle to the tangent points
        p1    (list (+ x (* r (cos (+ phi alpha)))) (+ y (* r (sin (+ phi alpha)))))
        p2    (list (+ x (* r (cos (- phi alpha)))) (+ y (* r (sin (- phi alpha))))))
  (setvar "CLAYER" "GRID")
  (setvar "CECOLOR" "3")                              ; Mammut GREEN bubble
  ;; Draw the MAJOR ARC only, from one tangent point round to the other the LONG way, so the circle
  ;; stops where the pointer begins.  Drawing a full circle left its bottom arc running straight
  ;; through the V -- which is the line the owner saw crossing.
  ;;
  ;; GOTCHA: entmake takes angle group codes 50/51 in RADIANS, even though the DXF file stores them
  ;; in degrees.  Passing degrees here made 62.3 be read as 62.3 RADIANS, which wraps to 329 deg --
  ;; the arc came out as the small 63-deg sliver instead of the 235-deg major arc.
  ;; CCW from (phi + alpha) round the back to (phi - alpha) leaves the 2*alpha gap for the pointer.
  (entmake (list '(0 . "ARC") (cons 8 "GRID") '(62 . 3)
                 (list 10 x y 0.0) (cons 40 r)
                 (cons 50 (+ phi alpha))      ; start at tangent point 1 (RADIANS)
                 (cons 51 (- phi alpha))))    ; CCW round the back to tangent point 2 (RADIANS)
  (command "_.PLINE" p1 apex p2 "")                   ; tangent pointer toward the grid line
  (setvar "CECOLOR" pc)
  (setvar "CLAYER" "GRID-TEXT")
  (setvar "TEXTSTYLE" "PEB-TITLE")
  (command "_.TEXT" "_J" "_MC" (list x y) h 0 label)
  (setvar "CLAYER" prev))


;; RIDGE-LINE callout = Roshan curl/hook "ladder" symbol (owner 3-Jul): a small LOOP sitting ON the
;; ridge line + a short leader up to the "RIDGE LINE" text (no arrowhead).  This curl is the SOLE ridge
;; marker; the ridge LINE itself stays a dotted/broken line (RIDGE layer).  Matches the symbol Nasir
;; inserted from REF_09_Roshan.  tgtX,tgtY = point on the ridge line.
(defun peb-ridge-callout (txtStr tgtX tgtY / s r cx cy prev)
  (setq s (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0) r (* 300.0 s)
        cx tgtX cy tgtY prev (getvar "CLAYER"))
  (setvar "CLAYER" "TEXT")
  (command "_.CIRCLE" (list cx cy) r)                                             ; the curl loop ON the ridge
  (command "_.LINE" (list (+ cx (* 0.7 r)) (+ cy (* 0.7 r)))
                    (list (+ cx (* 5.0 r)) (+ cy (* 5.0 r))) "")                  ; short leader up-right (no arrow)
  (txt "ML" (list (+ cx (* 5.4 r)) (+ cy (* 5.0 r))) (peb-th 'ANNOT) 0 txtStr)   ; "RIDGE LINE" label (engine text)
  (setvar "CLAYER" prev))

;; RIDGE-LINE LADDER — owner rule F5 (3-Jul, from REF_09_Roshan): the ridge line is marked with a
;; LADDER — two thin rails a small offset either side of the ridge line + regular rungs between them,
;; running the FULL ridge length and centred EXACTLY on the ridge line ("must exactly mark the ridge
;; line").  The central ridge LINE stays (the spine); this ladder rides on top of it and the curl
;; callout (peb-ridge-callout) still labels it.  widMm scales the rail gap.
;;   rail half-gap off = widMm * 0.010 (clamp 120..350) ; rung pitch = off * 5   (F5 numbers)
(defun peb-ridge-ladder (x0 x1 ridgeY widMm / off pitch xx prev)
  (setq off (* widMm 0.010))                                  ; half the rail spacing (rails at ridgeY +/- off)
  (cond ((< off 120.0) (setq off 120.0)) ((> off 350.0) (setq off 350.0)))
  (setq pitch (* off 5.0) prev (getvar "CLAYER"))             ; rung pitch = ladder look
  (setvar "CLAYER" "RIDGE")
  (command "_.LINE" (list x0 (+ ridgeY off)) (list x1 (+ ridgeY off)) "")   ; upper rail
  (command "_.LINE" (list x0 (- ridgeY off)) (list x1 (- ridgeY off)) "")   ; lower rail
  (setq xx x0)
  (while (< xx (+ x1 (* pitch 0.5)))
    (command "_.LINE" (list xx (- ridgeY off)) (list xx (+ ridgeY off)) "") ; rung
    (setq xx (+ xx pitch)))
  (setvar "CLAYER" prev))

;; RIDGE Y (owner 9-Jul).  The IF's `ridgeOffset` is the ridge distance FROM NSW (y=0) in metres --
;; NOT a delta from the centre -- serialized as BP_RIDGE_OFFSET (mm).  Blank / non-numeric / degenerate
;; => CENTRAL ridge (wid/2).  This is the SAME convention proposalData.ts uses for the Word proposal
;; (rise = max(off, W-off) x slope), so the drawing and the proposal can no longer disagree.
;; Gable sheets only (CS / MS / RC); MG has its own per-gable ridges and SS/FR/CC/PP/BF have no ridge.
;; Clamped off the eaves so a silly value can't put the ridge on top of a sidewall.
(defun peb-ridge-y (data wid / v)
  (setq v (MSPL-Get-Num data "BP_RIDGE_OFFSET"))
  (if (and v (> v (* wid 0.02)) (< v (* wid 0.98))) v (/ wid 2.0)))

;; BF VALLEY/PEAK Y (owner 18-Jul).  Plan mirror of the Section's peb-bf-valley-x so the 2-wing canopy's
;; centre line (Butterfly VALLEY / Falcon PEAK) lands at the SAME station on the plan as on the section.
;; Falcon peak stays CENTRAL (matches the Section's bfPk=W/2 branch); the Butterfly valley honours
;; BP_CANT_SPAN (the cantilever wing span = distance of the valley from the near/NSW eave); blank or a
;; degenerate value => central.  Clamped off the eaves.  Previously the Plan hardcoded wid/2 everywhere,
;; so an off-centre butterfly disagreed with its own section by |BP_CANT_SPAN - W/2|.
(defun peb-bf-valley-y (data wid / v)
  (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES")
    (/ wid 2.0)
    (progn
      (setq v (MSPL-Get-Num data "BP_CANT_SPAN"))
      (if (and v (> v (* wid 0.02)) (< v (* wid 0.98))) v (/ wid 2.0)))))

;; RIDGE LINE = dash-dot centre line (owner 4-Jul, Rule Book: "it just shows the line of the ridge").
;; FIX (ridge showed SOLID): the stock CENTERX2 pattern is only ~a few drawing units long, so the huge
;; global LTSCALE (~380 on big buildings) stretches each dash past the whole line and it renders solid.
;; Define a mm-based dash-dot linetype PEBRIDGE (dash 1400, gap 500, DOT, gap 500 = 2400 mm) and draw the
;; LINE with a PER-ENTITY linetype scale of 1/LTSCALE (DXF 48) so the pattern renders at TRUE mm size
;; regardless of the drawing's global LTSCALE. No global state is touched. widMm unused.
(defun peb-ridge-line (x0 x1 y / lts es)
  (if (not (tblsearch "LTYPE" "PEBRIDGE"))
    (vl-catch-all-apply (function (lambda ()
      (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbLinetypeTableRecord") '(2 . "PEBRIDGE") '(70 . 0)
                     '(3 . "Ridge ____ . ____ . ____") '(72 . 65) '(73 . 4) '(40 . 2400.0)
                     '(49 . 1400.0) '(74 . 0) '(49 . -500.0) '(74 . 0)
                     '(49 . 0.0)    '(74 . 0) '(49 . -500.0) '(74 . 0)))))))
  (setvar "CLAYER" "RIDGE")
  (setq lts (getvar "LTSCALE") es (if (> lts 0.0) (/ 1.0 lts) 1.0))
  (if (tblsearch "LTYPE" "PEBRIDGE")
    (entmake (list '(0 . "LINE") (cons 8 "RIDGE") '(6 . "PEBRIDGE") (cons 48 es)
                   (cons 10 (list x0 y 0.0)) (cons 11 (list x1 y 0.0))))
    (command "_.LINE" (list x0 y) (list x1 y) "")))

;; RIDGE-LINE SYMBOL — reproduced EXACTLY from the Roshan Packages reference (REF_09 DXF, owner 4-Jul):
;; a horizontal shelf that turns down into a small CURL / PIGTAIL landing on the ridge line, with the
;; "RIDGE LINE" label above the shelf.  Same 5 vertices as before (they already matched Roshan to the mm,
;; relative to the tip (0,0) = the point on the ridge line) BUT drawn as a BULGED LWPOLYLINE — the arc
;; bulges (1.066, 1.0, 1.0) on the bottom segments are what form the curl; the old version drew straight
;; segments and so had no curl.  Built via entmake so the bulges are exact.  Scaled by *PEB-TEXT-SCALE*.
(defun peb-ridge-symbol (x y / s prev)
  (setq s (min 1.0 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) prev (getvar "CLAYER"))
  (setvar "CLAYER" "TEXT")
  (entmake
    (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 "TEXT")
          '(100 . "AcDbPolyline") (cons 90 5) (cons 70 0)
          (cons 10 (list (+ x (* 4929.4 s)) (+ y (* 1513.4 s)))) (cons 42 0.0)    ; shelf right end
          (cons 10 (list (- x (* 6.5 s))    (+ y (* 1513.4 s)))) (cons 42 1.066)  ; shelf left corner -> curl
          (cons 10 (list (- x (* 0.7 s))    (+ y (* 221.7 s))))  (cons 42 1.0)    ; curl arc
          (cons 10 (list (- x (* 1.7 s))    (+ y (* 504.3 s))))  (cons 42 1.0)    ; curl arc
          (cons 10 (list x y))                                   (cons 42 0.0)))  ; tip on the ridge line
  ;; owner 5-Jul: text sits ABOVE the shelf line (bottom-aligned above y+1513*s) — no overlap with the line.
  (txt-bold "BL" (list (+ x (* 414.0 s)) (+ y (* 1720.0 s))) (peb-th 'ANNOT) 0 "RIDGE LINE")
  (setvar "CLAYER" prev))

;; Ridge-symbol anchor x (owner 5-Jul): the RIDGE-LINE shelf/text extends to the RIGHT, so anchor it at the
;; LEFT of an UNBRACED interior bay near the RIGHT-CENTRE (~0.75 of the length) — that keeps the whole label
;; inside one bay, clear of the vertical "BRACED BAY" text (at each braced bay's midpoint) AND clear of the
;; centred "AREA No." tag.  Skips the two end bays (shelf must stay inside).  Anchor = bay-left + 10% width.
(defun peb-ridge-bay-x (bayPts / braced n tgt best bestd i)
  (setq braced (peb-braced-bays bayPts) n (1- (length bayPts)) tgt (* 0.75 (float n)) bestd 1e9 i 1)
  (while (< i (1- n))
    (if (and (not (member i braced)) (< (abs (- i tgt)) bestd))
      (setq bestd (abs (- i tgt)) best i))
    (setq i (1+ i)))
  (if (null best) (setq best (max 0 (- n 3))))
  (+ (nth best bayPts) (* 0.10 (- (nth (1+ best) bayPts) (nth best bayPts)))))

;; ── COMPILER BRIDGE (owner 3-Jul) ───────────────────────────────────────────
;; Numbers measured from the Rule Book by compile_rulebook.py live in _peb_rules.lsp
;; (an assoc list bound to *PEB-RULES*).  `peb-rule` looks a number up by key; if the
;; file is missing OR the key absent, it returns the built-in DEFAULT — so the engine
;; behaves EXACTLY as before when the rules file is not present (zero-risk fallback).
(defun peb-load-rules ( / f)
  (foreach c (list "_peb_rules.lsp"
                   "D:/maimaar-os/3_Draftsman/Proposal Drawings/engine/_peb_rules.lsp"
                   "D:/maimaar-os/3_Draftsman/AutoCAD_Drawings/Multi_Area_Development/Compiler/_peb_rules.lsp")
    (if (and (null *PEB-RULES*) (setq f (findfile c)))
      (vl-catch-all-apply (function (lambda () (load f))))))
  ;; also load the compiled SYMBOLS (loose Rule-Book geometry -> *PEB-SYMBOLS*, owner 4-Jul)
  (foreach c (list "_peb_symbols.lsp"
                   "D:/maimaar-os/3_Draftsman/Proposal Drawings/engine/_peb_symbols.lsp"
                   "D:/maimaar-os/3_Draftsman/AutoCAD_Drawings/Multi_Area_Development/Compiler/_peb_symbols.lsp")
    (if (and (null *PEB-SYMBOLS*) (setq f (findfile c)))
      (vl-catch-all-apply (function (lambda () (load f))))))
  *PEB-RULES*)
(defun peb-rule (key dflt / v)
  (if (and (null *PEB-RULES*) (null *PEB-RULES-TRIED*))
    (progn (setq *PEB-RULES-TRIED* T) (peb-load-rules)))
  (if (setq v (assoc key *PEB-RULES*)) (cdr v) dflt))

;; Draw a COMPILED Rule-Book symbol (from *PEB-SYMBOLS*, written by compile_rulebook.py) at (x,y) —
;; primitives are relative to the base = the point that lands on the drawing.  Returns T if drawn,
;; nil if the symbol isn't available (caller falls back to its built-in shape).  (owner 4-Jul)
(defun peb-draw-symbol (name x y / sym prev pl f)
  ;; load the compiled symbols file directly (retry-able each call until *PEB-SYMBOLS* is set) — so it
  ;; picks up _peb_symbols.lsp even if the engine was loaded before the compiler wrote it.
  (if (null *PEB-SYMBOLS*)
    (foreach c (list "_peb_symbols.lsp"
                     "D:/maimaar-os/3_Draftsman/Proposal Drawings/engine/_peb_symbols.lsp"
                     "D:/maimaar-os/3_Draftsman/AutoCAD_Drawings/Multi_Area_Development/Compiler/_peb_symbols.lsp")
      (if (and (null *PEB-SYMBOLS*) (setq f (findfile c)))
        (vl-catch-all-apply (function (lambda () (load f)))))))
  (setq sym (cdr (assoc name *PEB-SYMBOLS*)) prev (getvar "CLAYER"))
  (if sym
    (progn
      (setvar "CLAYER" "TEXT")
      (foreach p sym
        (cond
          ((= (car p) "PLINE")
             (command "_.PLINE")
             (foreach pt (cadr p) (command (list (+ x (car pt)) (+ y (cadr pt)))))
             (command ""))
          ((= (car p) "LINE")
             (setq pl (cadr p))
             (command "_.LINE" (list (+ x (car (car pl)))  (+ y (cadr (car pl))))
                               (list (+ x (car (cadr pl))) (+ y (cadr (cadr pl)))) ""))
          ((= (car p) "TEXT")
             (txt "ML" (list (+ x (nth 1 p)) (+ y (nth 2 p))) (nth 3 p) 0 (nth 4 p)))
          ((= (car p) "CIRCLE")
             (command "_.CIRCLE" (list (+ x (nth 1 p)) (+ y (nth 2 p))) (nth 3 p)))))
      (setvar "CLAYER" prev)
      T)
    nil))

;; Maimaar-typical built-up MAIN column web depth, sized BY SPAN (owner rule).
;; Rule of thumb ~ span/30, rounded to 50 mm, clamped 400..1000.  Drives both the
;; drawn column symbol and the sidewall inset colOff = web/2 (flange flush on grid).
;; ── HAUNCH (RAFTER) DEPTH AT THE EAVE ────────────────────────────────────────
;; 700 mm at a 15 m span rising to 1100 mm at 50 m, clamped at both ends.
;; Lifted out of the section (it computed this inline) so the title block can add
;; the same depth the section actually draws — the two must not drift.
(defun peb-haunch-depth (effSpan)
  (max 700.0 (min 1100.0 (+ 700.0 (* (/ (- effSpan 15000.0) 35000.0) 400.0)))))

;; Purlin depth — the engine draws a 200-deep Z everywhere (draw-purlins, cladding).
(defun peb-purlin-depth () 200.0)

;; ── RULE 4B.7 — ONE HEIGHT NUMBER, AND WHAT IT MEANS ─────────────────────────
;; The BSF carries ONE height, CLEARHEIGHT, whose MEANING is declared by HEIGHT_REF. These two
;; helpers are the single place that turns it into the two numbers a drawing actually needs:
;; the CLEAR height (what a height dimension measures, FFL to the underside of the haunch) and
;; the ADD between it and the drawn eave.
;;
;; They exist because the elevations had neither. Framing.lsp read the number into a variable
;; called `eaveH` and used that ONE variable as BOTH the frame top and the dimension text — so
;; the wall was drawn 1,300 mm short and the dimension was labelled with the clear height while
;; spanning the whole (short) wall. Meanwhile the title block ON THE SAME SHEET printed
;; EAVE HEIGHT = clear + haunch + purlin. The sheet contradicted itself: rule 4B.7.
(defun peb-eave-add (data / wid ng)
  (setq wid (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        ng  (atoi (peb-tb-or (MSPL-Get-Str data "NUMGABLES") "1")))
  (if (< ng 1) (setq ng 1))
  (+ (peb-haunch-depth (if (> wid 0.0) (/ wid ng) 0.0)) (peb-purlin-depth)))

;; The CLEAR height, whatever basis the number was entered on. An EAVE-basis figure has the
;; haunch + purlin backed out of it, exactly as the section does (peb-section basis block).
(defun peb-clear-height (data / h ref ht)
  (setq h (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT")
                  (peb-tb-or (MSPL-Get-Str data "EAVE_HEIGHT")
                    (peb-tb-or (MSPL-Get-Str data "BP_EAVE_HEIGHT") "6000")))))
  (if (<= h 0.0) (setq h 6000.0))
  (setq ref (strcase (peb-tb-or (MSPL-Get-Str data "HEIGHT_REF") "")) ht (peb-eave-add data))
  (if (and (not (wcmatch ref "*CLEAR*")) (wcmatch ref "*EAVE*") (> h (+ ht 1.0)))
    (- h ht)
    h))

;; TRUE EAVE HEIGHT for the title block (owner 26-Aug).
;;   clear height (underside of the haunch, what the section dimensions)
;; + haunch depth  (the rafter at the eave)
;; + purlin depth  (the Z the sheeting sits on)
;; MG: the haunch follows the PER-GABLE span, the same effective span the section
;; sizes the frame from, so divide the width by the gable count.
(defun peb-tb-eave-height (data / clr wid ng eff)
  (setq clr (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT") "0"))
        wid (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        ng  (atoi (peb-tb-or (MSPL-Get-Str data "NUMGABLES") "1")))
  (if (< ng 1) (setq ng 1))
  (setq eff (if (> wid 0.0) (/ wid ng) 0.0))
  (if (<= clr 0.0)
    "-"
    (rtos (+ clr (peb-haunch-depth eff) (peb-purlin-depth)) 2 0)))

(defun peb-col-web-depth (widthMm / d)
  (if (or (null widthMm) (<= widthMm 0.0)) (setq widthMm 18000.0))
  (setq d (* 50.0 (fix (+ 0.5 (/ (/ widthMm (peb-rule "col_depth_div" 27.0)) 50.0)))))   ; ROSHAN ratio: D = span/27 (compiler)
  (cond ((< d 400.0) 400.0) ((> d 1400.0) 1400.0) (T d)))      ; capped 400..1400 (Rule Book / Roshan column)

;; Concise open-wall condition suffix for a wall label (from the IF OW_* field).
;; Returns " \U+00B7 <TAG>" (mid-dot + short tag) so it appends cleanly to the wall
;; direction label, or "" when blank/plain-sheeted. Keeps the plan readable.
(defun peb-ow-suffix (s / u)
  (setq u (strcase (if s s "")))
  (cond
    ((= u "")                                    "")
    ((wcmatch u "*OPEN*")                        "  -  OPEN FOR ACCESS")
    ((wcmatch u "*LOUVER*")                      "  -  LOUVERED")
    ((wcmatch u "*ROLL*")                        "  -  ROLL-UP DOOR(S)")
    ((wcmatch u "*MASONRY*,*BLOCK*,*BRICK*")     "  -  MASONRY DADO")
    ((wcmatch u "*SHEET*")                       "")   ; fully sheeted = the default; no clutter
    (T (strcat "  -  " (strcase s)))))

;; owner 5-Jul: TRUE when a wall's IF condition means NO sheeting line in plan — i.e. FULLY open for
;; access.  The partial "Open up to X M ... Rest Height Sheeted" conditions still have sheeting above the
;; opening, so they stay sheeted in plan (only 'Full Height Open for Access' drops the line).
(defun peb-wall-open-p (s / u)
  (setq u (strcase (if s s "")))
  (and (wcmatch u "*OPEN*") (not (wcmatch u "*SHEET*"))))

;; Base-plate + 4 anchor-bolt holes at a column (top view) — the anchor-bolt
;; content of the combined COLUMN LAYOUT & ANCHOR BOLT PLAN.  Plate on PLATES,
;; bolts as clear circles on BOLTS at gauge ±g.  Drawn BEHIND the column section.
(defun peb-draw-baseplate (x y / ph g prev)
  ;; enlarged so the TYPICAL 4 anchor bolts per plate read clearly at sheet scale.
  (setq ph 360.0 g 230.0 prev (getvar "CLAYER"))
  (setvar "CLAYER" "PLATES")
  (command "_.RECTANG" (list (- x ph) (- y ph)) (list (+ x ph) (+ y ph)))
  (setvar "CLAYER" "BOLTS")
  (foreach pt (list (list (- x g) (- y g)) (list (+ x g) (- y g))
                    (list (- x g) (+ y g)) (list (+ x g) (+ y g)))
    (command "_.CIRCLE" pt 42.0))
  (setvar "CLAYER" prev))

(defun draw-I-column-lengthwise (x y / D w tf tw br bx by hw ytop ybot prevLayer)
  ;; MAIN-FRAME column BODY — the Rule Book sample (owner 2-Jul). One flexible body: the section
  ;; DEPTH D = span/30 (*PEB-COL-WEB*) and everything follows its ratios, so the column scales with
  ;; the building. Web runs along the frame (y); flanges across (x). Outline (no poche), like the sample.
  ;;   flange width = 0.40 D · flange thickness = 0.04 D · web thickness = 0.026 D
  ;;   4 bolts (circle + cross) at (+-0.105 D, +-0.18 D), dia 0.077 D
  (setq D (if *PEB-COL-WEB* *PEB-COL-WEB* 700.0))
  (setq w (* (peb-rule "flange_width_xD" 0.40) D) tf (* (peb-rule "flange_thick_xD" 0.04) D) tw (* (peb-rule "web_thick_xD" 0.026) D)
        br (* (/ (peb-rule "bolt_dia_xD" 0.077) 2.0) D) bx (* (peb-rule "bolt_x_xD" 0.105) D) by (* (peb-rule "bolt_y_xD" 0.18) D)
        hw (/ w 2.0) ytop (+ y (/ D 2.0)) ybot (- y (/ D 2.0)))
  (setq prevLayer (getvar "CLAYER"))
  (setvar "CLAYER" "COLUMNS")    ; red outline
  (command "_.RECTANG" (list (- x hw) ybot) (list (+ x hw) (+ ybot tf)))          ; bottom flange
  (command "_.RECTANG" (list (- x hw) (- ytop tf)) (list (+ x hw) ytop))          ; top flange
  (command "_.RECTANG" (list (- x (/ tw 2.0)) (+ ybot tf)) (list (+ x (/ tw 2.0)) (- ytop tf)))  ; web (between flanges)
  (setvar "CLAYER" "BOLTS")      ; 4 bolts = circle + cross
  (foreach p (list (list (- x bx) (- y by)) (list (+ x bx) (- y by))
                   (list (- x bx) (+ y by)) (list (+ x bx) (+ y by)))
    (command "_.CIRCLE" p br)
    (command "_.LINE" (list (- (car p) br) (cadr p)) (list (+ (car p) br) (cadr p)) "")
    (command "_.LINE" (list (car p) (- (cadr p) br)) (list (car p) (+ (cadr p) br)) ""))
  (setvar "CLAYER" prevLayer)
)

(defun draw-I-column-widthwise (x y / D fw tf tw br bx by hf xl xr prevLayer)
  ;; END-WALL / BEARING column — the SAME Rule Book body, rotated 90° (deep D along X for the end wall).
  ;; HALF depth of the main column (owner 2-Jul: end-wall/bearing columns are the lighter posts).
  ;;   flange width = 0.40 D (along Y) · flange thick = 0.04 D · web thick = 0.026 D · 4 circle-cross bolts.
  (setq D (* (peb-rule "endwall_depth_x_main" 0.5) (if *PEB-COL-WEB* *PEB-COL-WEB* 700.0)))
  (setq fw (* (peb-rule "flange_width_xD" 0.40) D) tf (* (peb-rule "flange_thick_xD" 0.04) D) tw (* (peb-rule "web_thick_xD" 0.026) D)
        br (* (/ (peb-rule "bolt_dia_xD" 0.077) 2.0) D) bx (* (peb-rule "bolt_y_xD" 0.18) D) by (* (peb-rule "bolt_x_xD" 0.105) D)
        hf (/ fw 2.0) xl (- x (/ D 2.0)) xr (+ x (/ D 2.0)))
  (setq prevLayer (getvar "CLAYER"))
  (setvar "CLAYER" "COLUMNS")    ; red outline
  (command "_.RECTANG" (list xl (- y hf)) (list (+ xl tf) (+ y hf)))              ; left flange
  (command "_.RECTANG" (list (- xr tf) (- y hf)) (list xr (+ y hf)))              ; right flange
  (command "_.RECTANG" (list (+ xl tf) (- y (/ tw 2.0))) (list (- xr tf) (+ y (/ tw 2.0))))  ; web (between flanges)
  ;; HANGING COLUMN (owner 28-Jul): a hanging endwall column has NO foundation, so it carries NO base plate /
  ;; anchor bolts in the Column Layout & Anchor Bolt Plan. *PEB-COL-NO-BOLT* (set by the endwall-post loop for
  ;; a "Main Frame with Hanging Columns" endwall) suppresses the bolts; the column outline still shows.
  ;; A circular BUBBLE around the I-section flags it as a hanging column ("show the I symbol with a circular
  ;; bubble"). Radius ~0.72·D bubbles the section with margin. Only drawn for the hanging (no-bolt) columns.
  (if *PEB-COL-NO-BOLT*
    (progn (setvar "CLAYER" "COLUMNS") (command "_.CIRCLE" (list x y) (* D 0.72))))
  (if (not *PEB-COL-NO-BOLT*)
    (progn
      (setvar "CLAYER" "BOLTS")      ; 4 bolts = circle + cross
      (foreach p (list (list (- x bx) (- y by)) (list (+ x bx) (- y by))
                       (list (- x bx) (+ y by)) (list (+ x bx) (+ y by)))
        (command "_.CIRCLE" p br)
        (command "_.LINE" (list (- (car p) br) (cadr p)) (list (+ (car p) br) (cadr p)) "")
        (command "_.LINE" (list (car p) (- (cadr p) br)) (list (car p) (+ (cadr p) br)) ""))))
  (setvar "CLAYER" prevLayer)
)

;; Braced-bay selection — port of geometryRules bracingPlan: never brace the END
;; bays; brace the 2nd and 2nd-last bay; add interior braces so no unbraced run
;; exceeds 27 m. Returns 0-based bay indices. bayPts = grid x-stations (len+1 pts).
;; ── AUTO END-WALL COLUMN RULE ────────────────────────────────────────────────
;; How many bays the end wall is divided into when the IF gives no explicit
;; BP_EW_LEFT/RIGHT_SPACING: aim for ~6.25 m and keep every resulting bay inside
;; 6.0-6.5 m.  13716 -> 3 @ 4572;  30480 -> 5 @ 6096.
;;
;; This lives in ONE place because TWO sheets have to agree about it: the plan
;; grids and letters every end-wall column (A, B, C, D ...), and the END WALL
;; FRAMING elevation has to draw a column under each of those letters.  The
;; elevation used to fall back to the width module instead, so a clear span drew
;; only its two corner columns while the plan lettered A..D — the girt then
;; appeared to span the full width unsupported (owner 25-Aug audit).
(defun peb-ew-auto-cols (wid / n sp)
  (setq n (fix (/ wid 6250.0)))
  (if (< n 1) (setq n 1))
  (setq sp (/ wid n))
  (if (< sp 6000) (progn (setq n (1- n)) (if (< n 1) (setq n 1)) (setq sp (/ wid n))))
  (if (> sp 6500) (setq n (1+ n)))
  n)

;; The stations themselves: (0, sp, 2sp, ... wid).
(defun peb-ew-auto-stations (wid / n sp out i)
  (setq n (peb-ew-auto-cols wid) sp (/ wid n) out (list 0.0) i 1)
  (while (<= i n) (setq out (append out (list (* sp i))) i (1+ i)))
  out)

(defun peb-braced-bays (bayPts / n cum braced unbraced nSeg s target best bd bb mid)
  ;; EXACT port of geometryRules.bracingPlan (the IF's rule — STRICT, owner 2-Jul). bayPts = grid
  ;; x-stations (n+1 cumulative points, mm). Returns 0-based braced-bay indices.
  ;;   • brace the 2nd bay + the 2nd-last bay (near-end); the very end bays are NEVER braced;
  ;;   • interior braces so each unbraced sub-run <= 27 m, distributed EVENLY across bays 3..n-2
  ;;     (nSeg = ceil(unbraced / 27 m); targets at even fractions; snap to the nearest interior bay).
  (setq n (1- (length bayPts)) cum bayPts braced nil)
  (cond
    ((<= n 0) nil)
    ((= n 1) (list 0))
    (T
      (setq braced (list 1))                                       ; 2nd bay  (1-based 2 -> 0-based 1)
      (if (not (member (- n 2) braced)) (setq braced (cons (- n 2) braced)))  ; 2nd-last (1-based n-1)
      (if (> (- n 1) 2)
        (progn
          (setq unbraced (- (nth (- n 2) cum) (nth 2 cum)))        ; mm run between the two near-end braces
          (if (> unbraced 27000.0)
            (progn
              (setq nSeg (fix (+ (/ unbraced 27000.0) 0.999999)))  ; ceil
              (setq s 1)
              (while (< s nSeg)
                (setq target (+ (nth 2 cum) (/ (* unbraced (float s)) nSeg)))
                (setq best -1 bd 1e18 bb 3)
                (while (<= bb (- n 2))
                  (setq mid (/ (+ (nth (1- bb) cum) (nth bb cum)) 2.0))
                  (if (< (abs (- mid target)) bd) (progn (setq bd (abs (- mid target)) best bb)))
                  (setq bb (1+ bb)))
                (if (and (> best 0) (not (member (1- best) braced)))
                  (setq braced (cons (1- best) braced)))
                (setq s (1+ s)))))))
      braced)))

;; Draw roof X cross-bracing in each braced bay — the X spans BETWEEN THE COLUMNS
;; (inset top/bottom by web/2 = colOff, not the full sheeting width) + a clearly
;; visible "BRACED BAY" tag.  ox/oy = area origin (0,0 single).
;; A small asterisk "star" (3 crossing lines) centred at (cx,cy), radius r — the Portal-height marker.
(defun peb-star (cx cy r)
  (command "_.LINE" (list (- cx r) cy) (list (+ cx r) cy) "")
  (command "_.LINE" (list cx (- cy r)) (list cx (+ cy r)) "")
  (command "_.LINE" (list (- cx (* r 0.7)) (- cy (* r 0.7))) (list (+ cx (* r 0.7)) (+ cy (* r 0.7))) "")
  (command "_.LINE" (list (- cx (* r 0.7)) (+ cy (* r 0.7))) (list (+ cx (* r 0.7)) (- cy (* r 0.7))) ""))

;; digits/decimal pulled from a bracing string → "<n>m", else nil (the "Portal up to X m" height).
(defun peb-brace-num (s / i c out)
  (setq i 1 out "")
  (repeat (strlen s)
    (setq c (substr s i 1))
    (if (or (and (>= c "0") (<= c "9")) (= c ".")) (setq out (strcat out c)))
    (setq i (1+ i)))
  (if (> (strlen out) 0) (strcat out "m") nil))

;; Draw the bracing symbol for ONE column line (adjacent bay columns x0..x1, on the line y=yy),
;; per the IF bracing TYPE string (owner spec 2-Jul).  d = bowtie half-height.  Returns T if drawn.
;;   • Diagonal / X-Bracing  → BOWTIE = 2 cross lines (full-height cross brace, web to web).
;;   • Portal up to X m, Cross above → bowtie + 2 stars in the middle + "<X>m PORTAL" above.
;;   • Portal (full height)  → thick beam top-plan line + "PORTAL BRACING" / "FULL HEIGHT".
;;   • Not Applicable / Minor-axis / blank → nothing.
(defun peb-brace-line (x0 x1 yy d inward btype / bt cx sr so m wt xa xb)
  ;; Endpoints attach to the bay-facing WEB FACE (owner 3-Jul, Rule Book brace sample = "web to web"),
  ;; NOT the web centreline: shift the left endpoints +half-web toward the bay and the right endpoints
  ;; -half-web, so each cross line springs from the near web-flange junction (measured RB sample = 0.013 D).
  (setq bt (strcase btype) cx (/ (+ x0 x1) 2.0)
        wt (* (peb-rule "brace_web_offset_xD" 0.013) (if *PEB-COL-WEB* *PEB-COL-WEB* 700.0))
        xa (+ x0 wt) xb (- x1 wt))
  ;; 5 IF bracing configs (estimation-terminal spec 4-Jul), plan symbols; portal/hybrid ELEVATION → Section.
  (cond
    ((or (= btype "") (wcmatch bt "*NOT*APPLICABLE*") (wcmatch bt "*MINOR*AXIS*")) nil)
    ;; DIAGONAL (Cable / Rods / Angles) → full-height X (web-to-web). Angle = heavier line; Cable/Rod = thin.
    ((wcmatch bt "*DIAGONAL*")
      (setvar "CLAYER" "CROSS")
      (if (wcmatch bt "*ANGLE*")
        (progn                                              ; heavier line for angle bracing
          (command "_.PLINE" (list xa (- yy d)) "_W" (* 40.0 *PEB-DIM-SCALE*) (* 40.0 *PEB-DIM-SCALE*) (list xb (+ yy d)) "")
          (command "_.PLINE" (list xa (+ yy d)) (list xb (- yy d)) "")
          (setvar "PLINEWID" 0.0))
        (progn                                              ; thin single line for cable / rod
          (command "_.LINE" (list xa (- yy d)) (list xb (+ yy d)) "")
          (command "_.LINE" (list xa (+ yy d)) (list xb (- yy d)) "")))
      T)
    ;; HYBRID (Portal up to X m + Cross above) → bowtie X + 2 stars + "Xm PORTAL"
    ((and (wcmatch bt "*PORTAL*") (wcmatch bt "*CROSS*"))
      (setvar "CLAYER" "CROSS")
      (command "_.LINE" (list xa (- yy d)) (list xb (+ yy d)) "")
      (command "_.LINE" (list xa (+ yy d)) (list xb (- yy d)) "")
      (setq sr (* 150 *PEB-TEXT-SCALE*) so (+ sr (* 120 *PEB-TEXT-SCALE*)))
      (peb-star cx (+ yy so) sr) (peb-star cx (- yy so) sr)
      (setq m (peb-brace-num btype))
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list cx (+ yy (* inward (+ d (* 420 *PEB-TEXT-SCALE*))))) (peb-th 'SMALL) 0
           (strcat (if m m "") " PORTAL"))
      T)
    ;; PORTAL (full-height goal-post) → plan symbol: cyan half-thick BEAM line on the web centre +
    ;; "PORTAL-FULL" label (owner 4-Jul). The goal-post ELEVATION (2 verticals + haunched beam) → Section.
    ((wcmatch bt "*PORTAL*")
      (setvar "CLAYER" "CROSS")
      (command "_.PLINE" (list xa yy) "_W" (* 60.0 *PEB-DIM-SCALE*) (* 60.0 *PEB-DIM-SCALE*) (list xb yy) "")
      (setvar "PLINEWID" 0.0)
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list cx (+ yy (* inward (+ d (* 420 *PEB-TEXT-SCALE*))))) (peb-th 'SMALL) 0 "PORTAL-FULL")
      T)
    (T nil)))

(defun peb-draw-bracing (bayPts widthPts wid ox oy lewBrace rewBrace extType intType
                         / braced prevLayer x0 x1 cx ymid first nB drewX yp d colOff)
  ;; Cross-bracing on the COLUMN LAYOUT PLAN. Each braced column LINE carries the symbol for its
  ;; bracing TYPE (owner spec 2-Jul): sidewalls (NSW+FSW) use BP_BRACING_EXT; interior column lines
  ;; use BP_BRACING_INT (so when interior is N/A the middle columns get NOTHING). Symbols per line
  ;; drawn by peb-brace-line: Diagonal→bowtie, Portal-up-cross→bowtie+stars+"Xm PORTAL", Portal→thick
  ;; beam line + labels. PLACEMENT (strict = geometryRules.bracingPlan): 2nd + 2nd-last + even interior
  ;; ≤27 m; end bays only when the end wall is By-Framed.
  ;; owner 4-Jul: bracing cross lines = HIDDEN linetype — set it on the CROSS layer once (all brace
  ;; lines are drawn BYLAYER on CROSS, so they inherit it). Loads HIDDEN if absent; caught if it can't.
  (if (not (tblsearch "LTYPE" "HIDDEN"))
    (vl-catch-all-apply (function (lambda () (command "_.-LINETYPE" "_Load" "HIDDEN" "acad.lin" "")))))
  (vl-catch-all-apply (function (lambda () (command "_.-LAYER" "_LType" "HIDDEN" "CROSS" ""))))
  (if (or (null widthPts) (< (length widthPts) 2)) (setq widthPts (list 0.0 wid)))
  (setq braced (peb-braced-bays bayPts))
  (setq nB (1- (length bayPts)))
  ;; END BAYS ARE NEVER BRACED (owner 3-Jul) — the By-Framed end-bay bracing was against the rule; removed.
  ;; (lewBrace / rewBrace kept in the signature but no longer force the end bays.)
  (setq prevLayer (getvar "CLAYER") ymid (+ oy (/ wid 2.0)) first T
        d (* (- 0.5 (peb-rule "flange_thick_xD" 0.04)) (if *PEB-COL-WEB* *PEB-COL-WEB* 700.0))  ; reach = inner flange = D/2 - flange_thick (always meets the flange)
        colOff (/ (if *PEB-COL-WEB* *PEB-COL-WEB* 700.0) 2.0))   ; sidewall column-web inset (= botY / topY)
  (foreach b braced
    (setq x0 (+ ox (nth b bayPts)) x1 (+ ox (nth (1+ b) bayPts)) cx (/ (+ x0 x1) 2.0) drewX nil)
    ;; sidewalls NSW + FSW — bracing ON THE COLUMN-WEB line (inset by colOff) → EXTERIOR.  owner 5-Jul:
    ;; skip the side shared with an attached area (*PEB-OMIT-WALL*) so the common wall has no bracing.
    (if (and (not (peb-omit-wall-p "NSW")) (peb-brace-line x0 x1 (+ oy colOff) d 1.0 extType))          (setq drewX T))   ; NSW web
    (if (and (not (peb-omit-wall-p "FSW")) (peb-brace-line x0 x1 (+ oy (- wid colOff)) d -1.0 extType)) (setq drewX T))   ; FSW web
    ;; interior column lines → INTERIOR bracing type
    (foreach yp widthPts
      (if (and (> yp 1.0) (< yp (- wid 1.0)))
        (if (peb-brace-line x0 x1 (+ oy yp) d 1.0 intType) (setq drewX T))))
    (if drewX
      (progn
        (setvar "CLAYER" "DIMENSIONS")   ; magenta (exists)
        (txt-bold "MC" (list cx ymid) (peb-th 'SMALL) 90 "BRACED BAY")
        (if first
          (progn
            (setq first nil)
            ;; owner 4-Jul: SMALLER "CROSS BRACING (TYP.)" (was 260*scale which txt re-scaled -> huge) +
            ;; a leader ARROW that TOUCHES the NSW bracing bowtie.
            (setvar "CLAYER" "TEXT")
            (txt "MC" (list cx (- oy (* 900.0 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "CROSS BRACING (TYP.)")
            (setvar "CLAYER" "CROSS")
            (command "_.PLINE"
                     (list cx (- oy (* 500.0 *PEB-TEXT-SCALE*)))              ; start above the text
                     (list cx (- (+ oy colOff) (* 300.0 *PEB-TEXT-SCALE*)))   ; shaft up to just below the bowtie
                     "_W" (* 150.0 *PEB-TEXT-SCALE*) 0.0                       ; arrowhead taper
                     (list cx (+ oy colOff))                                  ; tip TOUCHES the bracing
                     "")
            (setvar "PLINEWID" 0.0))))))
  (setvar "CLAYER" prevLayer))

;; Rotated (WIDTH-axis) bracing symbol — the bowtie X spans y0..y1 on the vertical line x=xx (for END-WALL
;; bracing between adjacent end-wall columns).  Mirror of peb-brace-line with the axes swapped; d = half-width.
(defun peb-brace-line-v (y0 y1 xx d btype / bt wt ya yb)
  (setq bt (strcase btype)
        wt (* (peb-rule "brace_web_offset_xD" 0.013) (if *PEB-COL-WEB* *PEB-COL-WEB* 700.0))
        ya (+ y0 wt) yb (- y1 wt))
  (cond
    ((or (= btype "") (wcmatch bt "*NOT*APPLICABLE*") (wcmatch bt "*MINOR*AXIS*")) nil)
    ((wcmatch bt "*DIAGONAL*")                                ; full X (web-to-web); Angle = heavier, else thin
      (setvar "CLAYER" "CROSS")
      (if (wcmatch bt "*ANGLE*")
        (progn
          (command "_.PLINE" (list (- xx d) ya) "_W" (* 40.0 *PEB-DIM-SCALE*) (* 40.0 *PEB-DIM-SCALE*) (list (+ xx d) yb) "")
          (command "_.PLINE" (list (+ xx d) ya) (list (- xx d) yb) "")
          (setvar "PLINEWID" 0.0))
        (progn
          (command "_.LINE" (list (- xx d) ya) (list (+ xx d) yb) "")
          (command "_.LINE" (list (+ xx d) ya) (list (- xx d) yb) "")))
      T)
    ((wcmatch bt "*PORTAL*")                                  ; portal → thick beam line on the web centre
      (setvar "CLAYER" "CROSS")
      (command "_.PLINE" (list xx ya) "_W" (* 60.0 *PEB-DIM-SCALE*) (* 60.0 *PEB-DIM-SCALE*) (list xx yb) "")
      (setvar "PLINEWID" 0.0)
      T)
    (T                                                        ; hybrid / other → basic rotated bowtie
      (setvar "CLAYER" "CROSS")
      (command "_.LINE" (list (- xx d) ya) (list (+ xx d) yb) "")
      (command "_.LINE" (list (+ xx d) ya) (list (- xx d) yb) "")
      T)))

;; END-WALL column bracing (owner 5-Jul): X-bracing BETWEEN adjacent end-wall columns, in the LEW and REW
;; planes, following the SAME braced-panel rule as the bays (peb-braced-bays applied to ewStations: end
;; panels never, 2nd + 2nd-last, interior ≤27 m).  Drawn only when that end's girts are By-Framed (lew/
;; rewBrace).  owner 5-Jul FIX: the X is CENTRED on the end-wall column line (leftX/rightX) and its half-
;; width d = 0.46 × the end-wall column depth (0.5·D) so it sits WITHIN the column webs (was centred at
;; colOff, ~350 into the building, and twice too wide).  Uses the exterior bracing type.
(defun peb-draw-endwall-bracing (ewStations leftX rightX lewBrace rewBrace extType / braced d prevLayer y0 y1)
  (if (and ewStations (> (length ewStations) 2)
           (or lewBrace rewBrace)
           (/= extType "")
           (not (wcmatch (strcase extType) "*NOT*APPLICABLE*")))
    (progn
      (setq prevLayer (getvar "CLAYER")
            braced (peb-braced-bays ewStations)
            d      (* (- 0.5 (peb-rule "flange_thick_xD" 0.04))
                      (* (peb-rule "endwall_depth_x_main" 0.5) (if *PEB-COL-WEB* *PEB-COL-WEB* 700.0))))
      (foreach b braced
        (setq y0 (nth b ewStations) y1 (nth (1+ b) ewStations))
        (if lewBrace (peb-brace-line-v y0 y1 leftX  d extType))   ; LEW plane — on the end-wall column line
        (if rewBrace (peb-brace-line-v y0 y1 rightX d extType)))  ; REW plane
      (setvar "CLAYER" prevLayer))))

;; 0-based bay index containing position `at` (mm along length).
(defun peb-bay-of (at bayPts / i)
  (setq i 0)
  (while (and (< (+ i 2) (length bayPts)) (>= at (nth (1+ i) bayPts)))
    (setq i (1+ i)))
  i)

;; nearest grid station (mm) to x along a station list.
(defun peb-nearest-grid (x stations / best bd d)
  (setq best (car stations) bd 1e12)
  (foreach g stations (setq d (abs (- x g))) (if (< d bd) (progn (setq bd d best g))))
  best)

;; Draw ONE wall opening (door/window) in plan: jambs + panel across the gap,
;; a swing arc for doors, the MARK, an OFFSET dim to the nearest grid, and a RED
;; "(!) OPENING IN BRACED BAY" flag when a sidewall opening sits in a braced bay.
(defun peb-draw-one-opening (surf at w mark isDoor braced len wid ox oy bayPts
                             / px py horiz hw dep prev inSign ng off)
  (setq hw (/ w 2.0) dep 400.0 prev (getvar "CLAYER"))
  (cond
    ((= surf "NSW") (setq px (+ ox at) py oy        horiz T inSign 1.0))
    ((= surf "FSW") (setq px (+ ox at) py (+ oy wid) horiz T inSign -1.0))
    ((= surf "LEW") (setq px ox        py (+ oy at) horiz nil inSign 1.0))
    ((= surf "REW") (setq px (+ ox len) py (+ oy at) horiz nil inSign -1.0))
    (T (setq px nil)))
  (if px (progn
    (setvar "CLAYER" "OPEN")
    (if horiz
      (progn
        (command "_.LINE" (list (- px hw) py) (list (- px hw) (+ py (* inSign dep))) "")
        (command "_.LINE" (list (+ px hw) py) (list (+ px hw) (+ py (* inSign dep))) "")
        (command "_.LINE" (list (- px hw) (+ py (* inSign dep))) (list (+ px hw) (+ py (* inSign dep))) "")
        ;; swing arc ONLY for narrow personnel doors (<=1.5m); wide industrial
        ;; doors (roll-up/sliding) just show the clean opening gap.
        (if (and isDoor (<= w 1500.0)) (command "_.ARC" "_C" (list (- px hw) py) (list (+ px hw) py) (list (- px hw) (+ py (* inSign w))))))
      (progn
        (command "_.LINE" (list px (- py hw)) (list (+ px (* inSign dep)) (- py hw)) "")
        (command "_.LINE" (list px (+ py hw)) (list (+ px (* inSign dep)) (+ py hw)) "")
        (command "_.LINE" (list (+ px (* inSign dep)) (- py hw)) (list (+ px (* inSign dep)) (+ py hw)) "")
        (if (and isDoor (<= w 1500.0)) (command "_.ARC" "_C" (list px (- py hw)) (list px (+ py hw)) (list (+ px (* inSign w)) (- py hw))))))
    ;; MARK label just outside the wall
    (setvar "CLAYER" "TEXT")
    (if horiz
      (txt "MC" (list px (- py (* inSign 600 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 mark)
      (txt "MC" (list (- px (* inSign 600 *PEB-TEXT-SCALE*)) py) (peb-th 'SMALL) 0 mark))
    ;; OFFSET dim from the nearest grid (so the draughtsman sees the location;
    ;; no cross-bracing may sit at an opening) — horizontal walls only (length axis).
    (if horiz
      (progn
        (setq ng (peb-nearest-grid (- px ox) bayPts) off (abs (- (- px ox) ng)))
        (if (> off 1.0)
          (progn
            (peb-dim-h-stretch (+ ox ng) px
                               (+ py (* inSign 1900 *PEB-DIM-SCALE*))
                               (rtos off 2 0))
            (peb-recolor-last-dim 0)))))
    ;; clash flag
    (if braced
      (progn
        (setvar "CLAYER" "COLUMNS")             ; red
        (txt "MC" (list px (- py (* inSign 1250 *PEB-TEXT-SCALE*)))
             (* 230 *PEB-TEXT-SCALE*) 0 "(!) OPENING IN BRACED BAY")))
    (setvar "CLAYER" prev))))

;; Loop [PLACEMENTS]: draw every wall door/window (skip ROOF — that's the roof plan).
(defun peb-draw-placements (data ox oy len wid bayPts / cnt i pre surf at w mark typ isDoor braced bayIdx)
  (setq cnt (atoi (peb-tb-or (MSPL-Get-Str data "PL_COUNT") "0")))
  (setq braced (peb-braced-bays bayPts))
  (setq i 1)
  (while (<= i cnt)
    (setq pre  (strcat "PL" (itoa i) "_"))
    (setq surf (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "SURFACE")) "")))
    (setq at   (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "AT")) "0")))
    (setq w    (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "WIDTH")) "0")))
    (setq mark (peb-tb-or (MSPL-Get-Str data (strcat pre "MARK")) ""))
    (setq typ  (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "TYPE")) "")))
    (setq isDoor (or (vl-string-search "DOOR" typ) (= typ "")))
    (if (and (> w 0.0) (member surf '("NSW" "FSW" "LEW" "REW")))
      (progn
        (setq bayIdx (if (member surf '("NSW" "FSW")) (peb-bay-of at bayPts) -1))
        (peb-draw-one-opening surf at w mark isDoor
                              (if (member bayIdx braced) T nil)
                              len wid ox oy bayPts)))
    (setq i (1+ i))))

;; Base-plate note — at PROPOSAL stage the bolt size & count are NOT yet known,
;; so we only state the typical arrangement (4 bolts per plate), no schedule.
(defun peb-draw-ab-schedule (x0 y0 abgrade / prev s)
  (setq prev (getvar "CLAYER") s (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (setvar "CLAYER" "TEXT")
  (txt-bold "ML" (list x0 y0) (* 340 s) 0 "BASE PLATE & ANCHOR BOLTS")
  (txt "ML" (list x0 (- y0 (* 520 s))) (* 260 s) 0 "TYPICAL 4 ANCHOR BOLTS PER BASE PLATE")
  (txt "ML" (list x0 (- y0 (* 980 s))) (* 220 s) 0 "(SIZE & NUMBER FINALISED AT DESIGN STAGE)")
  (setvar "CLAYER" prev))

;; RCC column (owner 3-Jul): steel columns ALWAYS rest ON existing RCC columns, so the symbol is the
;; RCC concrete column (square outline) with the RED steel I-column drawn WITHIN it (the I-column may be
;; a MAIN or an END-WALL column).  Frame type = Roof on RCC Columns.
(defun draw-RCC-column (x y / D s prevLayer)
  (setq D (if *PEB-COL-WEB* *PEB-COL-WEB* 700.0)
        s (* D 1.40)                       ; RCC concrete column side (bigger than the steel column)
        prevLayer (getvar "CLAYER"))
  (setvar "CLAYER" "COLUMNS")
  (command "_.RECTANG" (list (- x (/ s 2.0)) (- y (/ s 2.0))) (list (+ x (/ s 2.0)) (+ y (/ s 2.0))))  ; RCC square
  (setvar "CLAYER" prevLayer)
  (draw-I-column-lengthwise x y)           ; the steel I-column resting WITHIN the RCC
)

(defun peb-group-equal-spans (pts / lengths groups currLen currCount currStart i sp tol)
  ;;  Walk a list of grid points and group runs of equal-length spans.
  ;;  Returns a list of (startX endX count spacing) tuples — one per group.
  ;;  Tolerance = 1 mm for "equal".
  (setq tol 1.0)
  (setq groups '())
  (if (< (length pts) 2)
    nil
    (progn
      ;; Build per-span lengths
      (setq lengths '())
      (setq i 0)
      (while (< i (1- (length pts)))
        (setq lengths (cons (- (nth (1+ i) pts) (nth i pts)) lengths))
        (setq i (1+ i)))
      (setq lengths (reverse lengths))

      ;; Group consecutive equal lengths
      (setq currLen   (nth 0 lengths))
      (setq currCount 1)
      (setq currStart 0)
      (setq i 1)
      (while (< i (length lengths))
        (setq sp (nth i lengths))
        (if (< (abs (- sp currLen)) tol)
          (setq currCount (1+ currCount))
          (progn
            (setq groups
              (cons (list (nth currStart pts)
                          (nth (+ currStart currCount) pts)
                          currCount currLen) groups))
            (setq currStart (+ currStart currCount))
            (setq currLen   sp)
            (setq currCount 1)))
        (setq i (1+ i)))
      ;; Final group
      (setq groups
        (cons (list (nth currStart pts)
                    (nth (+ currStart currCount) pts)
                    currCount currLen) groups))
      (reverse groups))))

(defun peb-mm-to-ft-in (mm / total-inches feet inches)
  ;;  Convert mm to Architectural feet-inches string ("25'-3\"").
  ;;  Inches rounded to nearest integer (no fractional).
  (setq total-inches (/ mm 25.4))
  (setq feet (fix (/ total-inches 12.0)))
  (setq inches (fix (+ 0.5 (- total-inches (* feet 12.0)))))
  (if (>= inches 12) (progn (setq feet (1+ feet)) (setq inches 0)))
  (strcat (itoa feet) "'-" (itoa inches) "\""))

;; Thousands separators for a digit string: "6967"->"6,967", "10670"->"10,670" (owner 5-Jul).
;; NB: must NOT call the built-in `rem` — the drawing routine has a LOCAL variable named `rem`
;; (setq rem ...) and AutoLISP dynamic scope would rebind it to a number, so we count-and-reset instead.
(defun peb-comma (s / n i out cnt)
  (setq n (strlen s) i n out "" cnt 0)
  (while (> i 0)
    (setq out (strcat (substr s i 1) out) cnt (1+ cnt) i (1- i))
    (if (and (= cnt 3) (> i 0)) (setq out (strcat "," out) cnt 0)))
  out)


;; Comma-group a numeric title-block value; anything non-numeric (or missing) falls
;; through untouched so a "-" stays a "-".
(defun peb-tb-comma (v / t0)
  (setq t0 (peb-tb-or v "-"))
  (if (and t0 (/= t0 "-") (/= t0 "") (numberp (read t0)))
    (peb-comma (rtos (atof t0) 2 0))
    t0))

(defun peb-fmt-value (value / mode)
  ;;  Format a single mm value per *PEB-DIM-DISPLAY* mode.
  ;;    "MM"   → "40000"
  ;;    "MMFT" → "40000 [131'-3\"]"
  ;;    "FT"   → "131'-3\""
  (setq mode (if *PEB-DIM-DISPLAY* *PEB-DIM-DISPLAY* "MM"))
  ;; comma-grouped, like every other number on the sheet (owner's number-presentation
  ;; standard).  Without this "BUILDING LENGTH : 121920" sat on the same plan as the
  ;; subtitle's "121,920 x 30,480" and the bay chain's "8,263".
  (cond
    ((= mode "MMFT") (strcat (peb-comma (rtos value 2 0)) " [" (peb-mm-to-ft-in value) "]"))
    ((= mode "FT")   (peb-mm-to-ft-in value))
    (T               (peb-comma (rtos value 2 0)))))

(defun peb-fmt-labelled (prefix value suffix / mode)
  ;;  Format a labelled dim like "BUILDING LENGTH : 40000 OUT TO OUT OF STEEL"
  ;;  per *PEB-DIM-DISPLAY* mode.  Inserts the value (mm / mm-and-ft / ft)
  ;;  between the prefix and suffix strings.
  (strcat prefix " : " (peb-fmt-value value)
          (if (and suffix (/= suffix ""))
            (strcat " " suffix)
            "")))

;; The per-area height tag's LABEL, from the IF's height basis (BP_HEIGHT_REF -> HEIGHT_REF).
;; The IF stores ONE height number; the basis says what it means. Options are
;;   "Clear Height at Eave" | "Clear Height at Low Eave" | "Eave Height"
;; TRAP: "Clear Height at Eave" contains BOTH "CLEAR" and "EAVE" — CLEAR must be tested FIRST, or every
;; clear height gets labelled as an eave height (which is what the hardcoded tag used to do).
;; Blank basis -> "CLEAR HT.": the IF's heightBasis list defaults to "Clear Height at Eave".
(defun peb-height-tag-label (ref / u)
  (setq u (strcase (if ref ref "")))
  (cond ((wcmatch u "*CLEAR*") "CLEAR HT.")
        ((wcmatch u "*EAVE*")  "EAVE HT.")
        (T                     "CLEAR HT.")))

;; map an IF "Measured At" basis string -> the Mammut-style dim-label suffix.
(defun peb-basis-suffix (b / u)
  ;; Abbreviated to save space (owner 4-Jul): O/O = out to out, C/C = centre to centre, I/I = in to in.
  (setq u (strcase b))
  (cond
    ;; owner 4-Jul: the two "steel"/"steel line" planes renamed to the clearer, distinct
    ;; O/O STEEL COLUMN (steel outer face) and O/O SHEETING LINE (cladding outer face).
    ((wcmatch u "*SHEET*")                              "O/O SH. LINE")
    ((wcmatch u "*CENTER TO CENTER*,*CENTRE TO CENTRE*,*C/C*") "C/C STEEL")
    ((wcmatch u "*BRICK*,*MASON*")                      "O/O BRICKWORK")
    ((wcmatch u "*KNEE*")                               "I/I STEEL @ KNEE")
    ((wcmatch u "*BASE*")                               "I/I STEEL @ BASE")
    ((wcmatch u "*STEEL*,*OUT TO OUT OF STEEL*")        "O/O STEEL COLUMN")
    ((= u "")                                           "O/O STEEL COLUMN")
    (T u)))

;; Basis -> witness-line offsets (lo hi) in mm, so the dim/marking lines sit at
;; the chosen reference plane (owner: "dim/marking lines must match the basis").
;;   Steel line      -> ( 0       0 )      (default; grid = steel line)
;;   Sheeting line   -> (-230   +230)      (out to out of sheeting)
;;   C/C of column   -> (+half  -half)     (witness lines drop to column centres)
;;   Brickwork       -> (-230   +230)
;;   In-to-in @ K/B  -> (+2half -2half)    (inner faces)
;; `half` = half the relevant column depth (web/2 for width, end-col w/2 for length).
(defun peb-basis-offsets (b half / u sg)
  (setq u (strcase (if b b "")) sg 230.0)
  (cond
    ((wcmatch u "*SHEET*")                                     (list (- sg) sg))
    ((wcmatch u "*CENTER TO CENTER*,*CENTRE TO CENTRE*,*C/C*") (list half (- half)))
    ((wcmatch u "*BRICK*")                                     (list (- sg) sg))
    ((wcmatch u "*KNEE*,*BASE*")                               (list (* 2.0 half) (* -2.0 half)))
    (T                                                         (list 0.0 0.0))))

;; Haunch (knee) web depth for the WIDTH In/In basis: Span/20, clamped 300..1200 (owner 4-Jul).
(defun peb-haunch-web-depth (spanMm / d)
  (setq d (/ (if (and spanMm (> spanMm 0.0)) spanMm 18000.0) 20.0))
  (cond ((< d 300.0) 300.0) ((> d 1200.0) 1200.0) (T d)))

;; BASIS-DRIVEN overall dimension (owner 4-Jul). Model grid = O/O STEEL (column outer faces on the
;; building edge). Returns (VALUE loOff hiOff): the number to show + the witness/arrow offsets added
;; to the two endpoints, so the ARROWS MOVE to whichever plane the IF basis (BP_*_REF) selects.
;;   dir 'W (width, main cols) / 'L (length, end-wall cols).  Fixed per-side offsets:
;;     half-web  W 200 / L 100 ; full-web@base W 400 / L 200 ; brick/girt 200 (0 if By-Flush).
;;   WIDTH always By-Framed (side-wall girts, default).  LENGTH By-Flush when *PEB-EW-BYFLUSH*.
;;   C/C = centres (−half-web) · In/In@base = inner faces (−full-web) · In/In@knee = −haunch web
;;   · O/O sheeting/brick = cladding (+brick) · else O/O steel = grid.
;; Returns (VALUE valLo valHi witLo witHi):
;;   VALUE  = the real dimension (fixed offsets)             -> the number shown
;;   valLo/valHi = fixed value offsets                        -> inner-chain end shift (keeps values exact)
;;   witLo/witHi = DRAWN-column offsets (drawnHalf-based)      -> witness/arrow lines, so they sit on the
;;                 drawn WEB CENTRE / faces (owner 4-Jul: columns are drawn oversized for presentation,
;;                 so the C/C line must cross the drawn web centre, not the real 200 plane / the bolts).
(defun peb-basis-dim (basis dir gridVal drawnHalf / u hw fw brick d dc)
  (setq u (strcase (if basis basis ""))
        hw (if (eq dir 'W) 200.0 100.0)
        fw (if (eq dir 'W) 400.0 200.0)
        brick (if (eq dir 'W) 200.0 (if *PEB-EW-BYFLUSH* 0.0 200.0))
        dc (if (and drawnHalf (> drawnHalf 0.0)) drawnHalf hw))     ; drawn web-centre offset
  (cond
    ;; owner 29-Jul FIX: the IF value (BP_WIDTH/LENGTH) is ALREADY stored in the *_REF basis, so when that
    ;; basis is C/C the number IS the C/C distance — show it VERBATIM (the old code subtracted 2×half-web,
    ;; double-converting 19150 C/C -> 18750 while the module chain printed 19150 -> the 18750-vs-19150 clash).
    ((wcmatch u "*CENTER TO CENTER*,*CENTRE TO CENTRE*,*C/C*")
       (list gridVal 0.0 0.0 0.0 0.0))                                      ; grid span = the entered C/C value
    ((wcmatch u "*KNEE*")
       (setq d (peb-haunch-web-depth gridVal))
       (list (- gridVal (* 2.0 d)) d (- d) (* 2.0 dc) (* -2.0 dc)))         ; witness on drawn inner face
    ((wcmatch u "*BASE*")
       (list (- gridVal (* 2.0 fw)) fw (- fw) (* 2.0 dc) (* -2.0 dc)))      ; witness on drawn inner face
    ((wcmatch u "*SHEET*,*BRICK*,*MASON*,*GIRT*")
       (list (+ gridVal (* 2.0 brick)) (- brick) brick (- brick) brick))   ; owner 23-Jul: EXTEND the drawn witness/arrows OUT to the sheeting/brick face (was 0,0 = steel-column plane, so the arrows contradicted the "O/O SH. LINE" label + the +2·brick value)
    (T (list gridVal 0.0 0.0 0.0 0.0))))                                    ; O/O steel = grid / outer face

;; Shift a chain's END grid points to the IF basis plane (owner 4-Jul): first point += loOff,
;; last point += hiOff, interior points unchanged — so a chain's outer edges land on the same
;; plane as its overall dim and the end segments absorb the offset (chain sum = overall value).
(defun peb-shift-ends (pts lo hi / n i out)
  (setq n (length pts) i 0 out '())
  (foreach p pts
    (setq out (cons (cond ((= i 0) (+ p lo)) ((= i (1- n)) (+ p hi)) (T p)) out)
          i   (1+ i)))
  (reverse out))

;; Derived grouped expression "1@7150 + 5@8500 + 1@7150" from (startX endX count spacing) groups —
;; NO total (the total is the overall dim above). Fallback when the IF gives no expression. Owner 4-Jul.
(defun peb-fmt-chain (groups / s first)
  (setq s "" first T)
  (foreach g groups
    (setq s (strcat s (if first "" " + ") (itoa (nth 2 g)) "@" (rtos (nth 3 g) 2 0)) first nil))
  s)

;; T when the IF expression's total equals the span actually drawn by pts (1 mm / 0.1 % tolerance).
;; The end-wall stations are RESCALED to close on the real width (ewScale, ~line 3096), so an IF
;; expression whose total disagrees with the width is drawn at one spacing and would be LABELLED at
;; another. Guard the mirror with this check so a stale IF value can never print a false dimension.
(defun peb-chain-expr-fits (ifExpr pts / spans exprSum ptsSum tol s)
  (setq spans (peb-parse-mod-expression ifExpr))
  (if (or (null spans) (null pts) (< (length pts) 2))
    T                                             ; nothing to check against -> keep mirroring
    (progn
      (setq exprSum 0.0)
      (foreach s spans (setq exprSum (+ exprSum s)))
      (setq ptsSum (abs (- (last pts) (car pts))))
      (setq tol (max 1.0 (* 0.001 ptsSum)))
      (<= (abs (- exprSum ptsSum)) tol))))

;; Inner-chain label = MIRROR the IF spacing expression verbatim (owner 4-Jul: "dimensions must be a
;; mirror of the IF, the way it is presented in the IF"); derive from the grid when the IF has none —
;; or when the IF expression does not close on the drawn span (then the mirror would be a lie).
(defun peb-chain-text (ifExpr pts)
  (if (and ifExpr (/= ifExpr "") (vl-string-search "@" ifExpr)
           (peb-chain-expr-fits ifExpr pts))
    (peb-fmt-expr ifExpr)
    (peb-fmt-chain (peb-group-equal-spans pts))))

;; render a raw IF grouped spacing expression verbatim (mm): "1@7620+5@8200" ->
;; "1@7620 + 5@8200" (just spaces the + separators; values untouched = exact IF).
(defun peb-fmt-expr (s / r ch i)
  (setq r "" i 1)
  (repeat (strlen s)
    (setq ch (substr s i 1))
    (setq r (if (= ch "+") (strcat r " + ") (strcat r ch)))
    (setq i (1+ i)))
  r)

(defun peb-fmt-group (count spacing / total mmStr ftStr ftTotal mode)
  ;;  Format a (count, spacing) group per *PEB-DIM-DISPLAY* mode.
  ;;  v6 — single-line MMFT (compact, no vertical stacking).
  ;;    "MM"   → "12 @ 7692 = 92304"                    (default)
  ;;    "MMFT" → "12 @ 7692 = 92304 [302'-7\"]"          (mm + ft total)
  ;;    "FT"   → "12 @ 25'-3\" = 302'-7\""               (ft only)
  ;;  Singletons drop the "count @" prefix.
  (setq mode (if *PEB-DIM-DISPLAY* *PEB-DIM-DISPLAY* "MM"))
  (setq total   (* count spacing))
  (setq ftTotal (peb-mm-to-ft-in total))
  (cond
    ;; ── Singleton ─────────────────────────────────────────────
    ((<= count 1)
      (setq mmStr (rtos spacing 2 0))
      (setq ftStr (peb-mm-to-ft-in spacing))
      (cond
        ((= mode "MMFT") (strcat mmStr " [" ftStr "]"))
        ((= mode "FT")   ftStr)
        (T               mmStr)))
    ;; ── Group ─────────────────────────────────────────────────
    (T
      (setq mmStr (strcat (itoa count) " @ "
                          (rtos spacing 2 0) " = "
                          (rtos total 2 0)))
      (setq ftStr (strcat (itoa count) " @ "
                          (peb-mm-to-ft-in spacing) " = "
                          ftTotal))
      (cond
        ;; mm primary + ft TOTAL in brackets (compact — no full ft expr)
        ((= mode "MMFT") (strcat mmStr " [" ftTotal "]"))
        ((= mode "FT")   ftStr)
        (T               mmStr)))))

(defun peb-slope-text ()
  ;; Phase-2A v5: keep ratio as-is — "1:10", "1:20", "0.5:10" etc.
  (if *PEB-ROOF-SLOPE* *PEB-ROOF-SLOPE* "1:10")
)

;; FALL marker — "Match the Sample of Fall" (owner 5-Jul): a HOUSE-PENTAGON (rectangle body + triangular
;; apex pointing in the FALL direction) with a CIRCLE inside, "FALL" text VERTICAL BELOW the pentagon, and
;; the slope ratio SMALL + HORIZONTAL below that.  a = scale (u, autosizes with the building); dir (+/-1)
;; points the apex in the fall direction.  Text sized PROPORTIONAL to a (txt re-scales by TS -> pass a/TS).
;; owner 10-Jul: "polish the FALL arrow — more beautiful and contrast … refine per typical PEB".
;; Reference-first (REF_07_Zealcon, glyph beside each REW 'FALL' text): the real symbol is an APEX with
;; two mirrored legs wrapping a small CIRCLE.  Mammut faked boldness by stacking several zero-width offset
;; outlines; we have real lineweights + fills, so we draw it properly:
;;   * a SOLID filled arrowhead (the apex) — the contrast that was missing when everything was hollow
;;   * a bold body outline, slightly narrower than the head so the head reads as a true arrow
;;   * a crisp ring in the body carrying the SLOPE RATIO inside it (typical PEB roof-plan practice:
;;     the ratio travels with the arrow instead of floating on a separate line)
;;   * "FALL" vertical below, unchanged.
;; Drawn with peb-* entmake primitives (project rule: sheet engines never draw raw), BYLAYER on FALL.
;; owner 10-Jul: "render the FALL symbol 100% the same as Mammut Roshan Packages."
;; MEASURED from reference/03_proposal_drawings/DXF/REF_09_Roshan_MultiSpan_JackBeams.dxf
;; (glyph beside each CLP "FALL" text).  The real symbol is a HOUSE/ARROW OUTLINE — apex, two barbs,
;; a straight body — with a CIRCLE centred on the shoulder line so it pokes up into the head.  Mammut
;; drew four near-identical offset copies to fake a bold stroke; we have real lineweights (FALL lw 0.35).
;;
;;   Reference numbers (mm), outermost closed polyline, centred on its own axis:
;;     apex          (0, 4221.9)          total height H = 1848.4   (apex 4221.9 -> tail 2373.5)
;;     barb          (+/-1024.05, 3093.1) barb  half-width = 0.5540 H
;;     body          (+/- 736.25, 3093.1) body  half-width = 0.3983 H
;;     tail          (+/- 736.25, 2373.5) shoulder = 0.3893 H above the tail
;;     CIRCLE        centre (0, 3067.6) r 645.9  ->  centre 0.3756 H above tail, r = 0.3494 H
;;   "FALL" is TEXT colour 7 (WHITE) in Roshan — and also in REF_07_Zealcon.  The 7-Jul note that
;;   it should be red was mistaken; both references say white.  Ratio text sits below "FALL"
;;   (Roshan prints "ONE:15"); we keep the IF's own ratio format.
;;
;; NOTE: this REPLACES the 10-Jul filled arrowhead+shaft+ring. That was a departure from Mammut, not a
;; match to it — the owner asked for the Roshan symbol exactly.
(defun peb-fall-marker (x y dir u / prev a ts hh bodyH barbH shY tailY apexY ccy cr fh fyy syy)
  (setq prev (getvar "CLAYER") a u ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        hh    (* 1.70 a)               ; H — total glyph height (keeps the old footprint)
        bodyH (* 0.3983 hh)            ; body  half-width   (Roshan ratio)
        barbH (* 0.5540 hh)            ; barb  half-width   (Roshan ratio)
        tailY (- y (* dir 0.55 hh))    ; tail, so the glyph straddles y like the old one did
        shY   (+ tailY (* dir 0.3893 hh))
        apexY (+ tailY (* dir 1.0    hh))
        ccy   (+ tailY (* dir 0.3756 hh))
        cr    (* 0.3494 hh)
        fh    (/ (* 0.55 a) ts))
  (setvar "CLAYER" "FALL")
  ;; house/arrow outline: apex -> left barb -> left body -> tail -> right body -> right barb (closed)
  (peb-poly (list (list x apexY)
                  (list (- x barbH) shY)
                  (list (- x bodyH) shY)
                  (list (- x bodyH) tailY)
                  (list (+ x bodyH) tailY)
                  (list (+ x bodyH) shY)
                  (list (+ x barbH) shY))
            "FALL" T)
  ;; circle on the shoulder line — it deliberately overlaps the head, exactly as Roshan draws it.
  ;; owner 10-Jul: FILLED solid red (peb-disc) so the symbol reads instantly at sheet scale; Roshan's
  ;; own circle is hollow, but this is the one polish the owner asked for on top of the exact geometry.
  ;; Falls back to a hollow circle if an older Standard.lsp (no peb-disc) is loaded.
  (if (boundp 'peb-disc) (peb-disc x ccy cr "FALL") (peb-circle x ccy cr "FALL"))
  ;; "FALL" vertical below the glyph, WHITE (TEXT layer).  Rotated text extends along Y by its LENGTH
  ;; (4 chars * ~0.74 * fh), not its height — centre it a half-length + gap below the tail.
  (setq fyy (- tailY (* dir (+ (* 0.5 4.0 0.74 (* fh ts)) (* 0.34 a)))))
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list x fyy) fh 90.0 "FALL")
  ;; slope ratio, small + horizontal, below "FALL"
  ;; gap must clear BOTH the FALL half-length (rotated text) and the ratio's own half-height (~0.19*a)
  (setq syy (- fyy (* dir (+ (* 0.5 4.0 0.74 (* fh ts)) (* 0.62 a)))))
  (txt "MC" (list x syy) (/ (* 0.38 a) ts) 0.0 (peb-slope-text))
  (setvar "CLAYER" prev))

(defun arrow-up-big   (x y u) (peb-fall-marker x y  1.0 u)) ; fall toward FSW (up)
(defun arrow-down-big (x y u) (peb-fall-marker x y -1.0 u)) ; fall toward NSW (down)

;; ── Shared FALL-glyph set (owner 7-Jul: IDENTICAL on the Column Layout Plan AND the Roof Plan) ──
;; Single source of truth for the roof-fall glyphs.  Both sheets build bayPts + mgRidgePts + mgGableW
;; with the same algorithm and share the same *PEB-TEXT-SCALE* / *PEB-ROOF-SLOPE*, so the pentagon
;; glyphs land at IDENTICAL positions and size.  Placement: MAX 2-3 stations (owner), each snapped to
;; the nearest UNBRACED bay so the CLP's "BRACED BAY" text never overlaps; the Roof Plan reuses the
;; SAME stations for an exact match.  Direction/eave-tags per structure type.
(defun peb-fall-glyph-set (data stype len wid bayPts mgRidgePts mgGableW /
                           bays fallBraced fallUsed slopeXs nFall k tgt off found fallU sx mgY rY)
  (setq bays (max 1 (1- (length bayPts))))
  (setq fallBraced (peb-braced-bays bayPts) fallUsed '() slopeXs '())
  (setq nFall (if (<= bays 2) 1 2))   ; owner 4-Jul: FALL in 2 places only (1 on a tiny 1-2 bay building)
  (setq k 1)
  (while (<= k nFall)
    (setq tgt (fix (+ 0.5 (* bays (/ k (+ nFall 1.0))))) off 0 found nil)   ; target bay at k/(nFall+1)
    (while (and (not found) (<= off bays))
      (cond
        ((and (>= (- tgt off) 0) (< (- tgt off) bays)
              (not (member (- tgt off) fallBraced)) (not (member (- tgt off) fallUsed)))
         (setq found (- tgt off)))
        ((and (< (+ tgt off) bays)
              (not (member (+ tgt off) fallBraced)) (not (member (+ tgt off) fallUsed)))
         (setq found (+ tgt off))))
      (setq off (1+ off)))
    (if found
      (setq slopeXs  (cons (/ (+ (nth found bayPts) (nth (1+ found) bayPts)) 2.0) slopeXs)
            fallUsed (cons found fallUsed)))
    (setq k (1+ k)))
  (setq slopeXs (reverse slopeXs))
  (setq fallU (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
  ;; catch-wrap so a fall-glyph error can never abort the sheet.
  (vl-catch-all-apply (function (lambda ()
    (cond
      ((member stype '("CS" "MS" "RC"))
        ;; owner 5-Jul: each arrow sits 3/4 of the way from the RIDGE out to its eave.  With a central
        ;; ridge that is 0.875 / 0.125 of the width -- the old hardcoded numbers.  owner 9-Jul: the
        ;; ridge can be off-centre (BP_RIDGE_OFFSET), so derive both stations from it instead.  A
        ;; central ridge reproduces 0.875 / 0.125 exactly, so nothing moves on the common case.
        (setq rY (peb-ridge-y data wid))
        (foreach sx slopeXs
          (arrow-up-big   sx (+ rY (* 0.75 (- wid rY))) fallU)   ; ridge -> FSW eave
          (arrow-down-big sx (* 0.25 rY)                fallU))) ; ridge -> NSW eave
      ((= stype "MG")
        (foreach mgY mgRidgePts
          (foreach sx slopeXs
            (arrow-up-big   sx (+ mgY (* mgGableW 0.375)) fallU)   ; owner 5-Jul: 3/4 from gable ridge
            (arrow-down-big sx (- mgY (* mgGableW 0.375)) fallU))))
      ((= stype "BF")
        ;; BF covers BOTH 2-wing canopies (centre column at wid/2), mirroring the Section dispatch:
        ;;   CC_FALCON_PEAK=Yes -> FALCON (2-wing, centre peak): wings slope outward, drains at the outer eaves.
        ;;   default            -> BUTTERFLY (2-wing, valley):   wings slope inward, drains at the centre.
        (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES")
          (foreach sx slopeXs
            (arrow-up-big   sx (* wid 0.875) fallU)   ; upper wing falls out toward FSW
            (arrow-down-big sx (* wid 0.125) fallU))  ; lower wing falls out toward NSW
          (progn
            (setq bfVy (peb-bf-valley-y data wid))   ; owner 18-Jul: valley may be off-centre (BP_CANT_SPAN)
            (foreach sx slopeXs
              (arrow-down-big sx (+ bfVy (* 0.75 (- wid bfVy))) fallU)   ; upper wing falls in toward the valley
              (arrow-up-big   sx (* 0.25 bfVy)                  fallU))))) ; lower wing falls in toward the valley
      ((= stype "CC")
        ;; SINGLE-SIDED CANTILEVER (the 1-wing pair -- NOT "Butterfly/Falcon 1-wing", owner 9-Jul).
        ;; Back support column line on NSW (y=0), free edge on FSW (y=wid) -- see the CC column branch
        ;; below.  ONE continuous fall across the width (no ridge), so a single mid-width arrow like SS.
        ;; Direction mirrors the Section's draw-cc-frame lowAtCol:
        ;;   CC_LOW_AT_COLUMN=Yes -> SLOPE TOWARDS COLUMNS:   low at the column, drains AT it (NSW).
        ;;   default              -> SLOPE AWAY FROM COLUMNS: high at the column, drains at the free end (FSW).
        (foreach sx slopeXs
          (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_LOW_AT_COLUMN") "")) "YES")
            (arrow-down-big sx (* wid 0.5) fallU)
            (arrow-up-big   sx (* wid 0.5) fallU))))
      ((= stype "PP")
        ;; PETROL PUMP / CNG CANOPY (owner 9-Jul): near-flat slab on two inset column lines
        ;; (0.22 / 0.78 of the width) with a cantilever overhang each side.  It drains INWARD from
        ;; both free edges to the column lines, through concealed downpipes inside the columns -- so
        ;; no water is shed over the forecourt.  One arrow per overhang, pointing at its column line.
        (foreach sx slopeXs
          (arrow-down-big sx (* wid 0.89) fallU)   ; upper overhang falls in toward the 0.78 column line
          (arrow-up-big   sx (* wid 0.11) fallU))) ; lower overhang falls in toward the 0.22 column line
      ((= stype "FR")
        ;; flat roof drains INWARD to a central drain line (owner/Mammut §4.5): arrows from both
        ;; sidewalls toward the centreline, + a dashed centre drain line along the length.
        (foreach sx slopeXs
          (arrow-down-big sx (* wid 0.72) fallU)    ; upper half falls down toward centre
          (arrow-up-big   sx (* wid 0.28) fallU))   ; lower half falls up toward centre
        (vl-catch-all-apply (function (lambda ()
          (peb-ridge-line (* len 0.04) (* len 0.96) (* wid 0.5)))))   ; central drain line (dash-dot)
        (setvar "CLAYER" "TEXT")
        ;; note lifted to wid*0.70: at 0.55 it sat on the mid-width row where the per-area CLEAR HT tag
        ;; (now drawn above the area box, ~16.5 k on a 30 m frame) and the vertical BRACED BAY text
        ;; (~12.8-17.2 k) both live.  0.70 clears the top of the braced-bay text and the tag.
        (txt "MC" (list (* len 0.50) (* wid 0.70)) (peb-th 'DIM) 0 "ROOF SLOPES TO CENTRE DRAIN"))
      ((= stype "SS")
        ;; single slope: ONE continuous fall high->low across the full width (no ridge). High side =
        ;; RA_MONO_HIGH (FSW default until the IF captures msHighSide). Full-width arrows + HIGH/LOW EAVE tags.
        (foreach sx slopeXs
          (if (wcmatch (strcase (MSPL-Get-Str data "RA_MONO_HIGH")) "*NSW*")
            (arrow-up-big   sx (* wid 0.5) fallU)     ; NSW high -> fall toward FSW
            (arrow-down-big sx (* wid 0.5) fallU)))   ; FSW high (default) -> fall toward NSW
        (setvar "CLAYER" "TEXT")
        (if (wcmatch (strcase (MSPL-Get-Str data "RA_MONO_HIGH")) "*NSW*")
          (progn (txt "MC" (list (* len 0.5) (* wid 0.055)) (peb-th 'SMALL) 0 "HIGH EAVE")
                 (txt "MC" (list (* len 0.5) (* wid 0.945)) (peb-th 'SMALL) 0 "LOW EAVE"))
          (progn (txt "MC" (list (* len 0.5) (* wid 0.945)) (peb-th 'SMALL) 0 "HIGH EAVE")
                 (txt "MC" (list (* len 0.5) (* wid 0.055)) (peb-th 'SMALL) 0 "LOW EAVE"))))
      (T
        (foreach sx slopeXs
          (arrow-down-big sx (* wid 0.5) fallU)))))))
  (setvar "CLAYER" "0")
  (princ))

(defun draw-north-arrow (cx cy / s)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setq s *PEB-TEXT-SCALE*)
  (setvar "CLAYER" "STRUCTURE")
  (command "CIRCLE" (list cx cy) (* 600 s))
  (command "PLINE" (list cx (+ cy (* 550 s))) (list (- cx (* 180 s)) (- cy (* 150 s))) (list cx (- cy (* 50 s))) "C")
  (command "HATCH" "SOLID" "L" "")
  (command "PLINE" (list cx (- cy (* 550 s))) (list (+ cx (* 180 s)) (+ cy (* 150 s))) (list cx (- cy (* 50 s))) "C")
  (txt-bold "MC" (list cx (+ cy (* 900 s))) (peb-th 'DIM) 0 "N")
)

(defun draw-border (x1 y1 x2 y2 / margin)
  (setq margin (* 800 *PEB-TEXT-SCALE*))
  (setvar "CLAYER" "BORDER")
  (command "RECTANG" (list (- x1 margin) (- y1 margin)) (list (+ x2 margin) (+ y2 margin)))
  (command "RECTANG" (list (- x1 (* margin 0.6)) (- y1 (* margin 0.6))) (list (+ x2 (* margin 0.6)) (+ y2 (* margin 0.6))))
)

;; ---- CANTILEVER-SHADE NAMING (owner 9-Jul) ------------------------------------------------------
;; The 4 cantilever shades carry the IF's own names.  "Butterfly" and "Falcon" name ONLY the 2-wing
;; pair (they describe where the roof drains: centre valley vs centre peak).  The 1-wing pair is NOT
;; "Butterfly/Falcon 1-wing" -- it is "Single-Sided Cantilever", qualified by which way it slopes
;; relative to its single column line.  Matches spec.js/specFields.js `canopyType`:
;;   BF + CC_FALCON_PEAK=Yes   -> Falcon (2-wing, centre peak)
;;   BF + (default)            -> Butterfly (2-wing, valley)
;;   CC + CC_LOW_AT_COLUMN=Yes -> Single-Sided Cantilever - Slope Towards Columns
;;   CC + (default)            -> Single-Sided Cantilever - Slope Away From Columns
;; Returns the proper name for a canopy stype, else nil.  Cached per sheet in *PEB-CANOPY-NAME* so
;; the label fns stay single-argument (4 call sites across Plan + Section).
(defun peb-canopy-name (stype data)
  (cond
    ((= stype "BF")
      (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES")
        "FALCON CANOPY (CENTRE PEAK)"
        "BUTTERFLY CANOPY (VALLEY)"))
    ((= stype "CC")
      ;; shortened 9-Jul (owner: "you may say upward, downward").  Slope is read FROM THE COLUMN
      ;; OUTWARD TO THE FREE EDGE, which is the only direction the single column line allows:
      ;;   CC_LOW_AT_COLUMN=Yes -> low at the column, rises to the free end  -> SLOPES UPWARD
      ;;   default              -> high at the column, falls to the free end -> SLOPES DOWNWARD
      ;; The IF's full proper names stay "Single-Sided Cantilever - Slope Towards / Away From
      ;; Columns"; these are the sheet's short forms (was 41/43 chars vs the 38-char longest peer).
      (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_LOW_AT_COLUMN") "")) "YES")
        "CANTILEVER - SLOPES UPWARD"
        "CANTILEVER - SLOPES DOWNWARD"))
    (T nil)
  )
)

(defun peb-structure-label (stype)
  (cond
    ((= stype "CS") (if *PEB-ARCHED* "ARCHED CLEAR SPAN" "CLEAR SPAN GABLE"))
    ((= stype "SS") "SINGLE SLOPE - COLUMNS BOTH SIDES")
    ((= stype "MS") (if *PEB-ARCHED* "ARCHED MULTI-SPAN" "MULTI-SPAN"))
    ((= stype "LT") "LEAN-TO")
    ((= stype "MG") "MULTI-GABLE")
    ((= stype "FR") "FLAT ROOF")
    ((= stype "F2") "FLAT ROOF (G+1)")
    ((= stype "RC") "ROOF ON RCC COLUMNS - NO STEEL COLUMNS")
    ((member stype '("CC" "BF")) (if *PEB-CANOPY-NAME* *PEB-CANOPY-NAME* "CANTILEVER CANOPY"))
    ((= stype "PP") "PETROL PUMP CANOPY")
    ((= stype "ACS") "ARCHED CLEAR SPAN")     ; was missing -> fell through to "CLEAR SPAN GABLE"
    ((= stype "AMS") "ARCHED MULTI-SPAN")
    (T "CLEAR SPAN GABLE")
  )
)

(defun peb-roof-label (stype rooftype)
  (cond
    ((= stype "SS") "SINGLE SLOPE")
    ((= stype "LT") "LEAN-TO")
    ((= stype "MG") "MULTI-GABLE")
    ((= stype "FR") "FLAT ROOF")
    ((= stype "RC") "ROOF SYSTEM ON RCC COLUMNS")
    ((= stype "PP") "PETROL PUMP CANOPY")
    ((= stype "CC") "SINGLE-SIDED CANTILEVER ROOF")   ; fall arrows carry the towards/away distinction
    ((= stype "BF")
      (if (and *PEB-CANOPY-NAME* (wcmatch *PEB-CANOPY-NAME* "FALCON*")) "FALCON ROOF (CENTRE PEAK)"
                                                                        "BUTTERFLY ROOF (VALLEY)"))
    ((= rooftype "M") "MONO-SLOPE")
    (T "GABLE")
  )
)

;; ============================================================================
;;  MAMMUT-STYLE VERTICAL TITLE BLOCK  (Column Layout Plan)
;;  Self-contained: all sizes derived from the strip height H (DYNAMIC autofit).
;;  Native entmake geometry -> every line / text is grip-editable.
;;  peb-tb-logo draws a Mammut-style Maimaar mark (red roof swoosh + wordmark).
;; ============================================================================
(defun tb-line (x1 y1 x2 y2 col)
  (entmake (list (cons 0 "LINE") (cons 100 "AcDbEntity") (cons 8 "0")
                 (cons 62 col) (cons 100 "AcDbLine")
                 (list 10 x1 y1 0.0) (list 11 x2 y2 0.0))))
(defun tb-rect (x1 y1 x2 y2 col)
  (tb-line x1 y1 x2 y1 col) (tb-line x2 y1 x2 y2 col)
  (tb-line x2 y2 x1 y2 col) (tb-line x1 y2 x1 y1 col))
(defun tb-mtext (x y h wid attach str col / lwl)
  ;; UPPERCASE plain strings (labels + IF values); skip RTF blocks ("{\f...}") so
  ;; MText control words (\fArial, \b1, \P) are not corrupted by strcase.
  (if (and str (not (vl-string-search "{" str))) (setq str (strcase str)))
  ;; owner UNIVERSAL RULE 22-Jul: ALL title-block/body text = ROMAND.  Style = ROMAND; wrap fontless strings in
  ;; \Fromand.shx (CAPITAL \F = SHX font code; lowercase \f is TrueType and mis-parses an SHX name).  No Arial.
  (if (and str (not (vl-string-search "\\F" str))) (setq str (strcat "{\\Fromand.shx;" str "}")))
  ;; owner 22-Jul STANDING RULE (weight hierarchy, ALL sheets): fixed field LABELS are drawn GREY (col 8) ->
  ;; give them a light-medium 0.25mm pen (370=25) so they read as structure above the thin dynamic values
  ;; (monochrome plot: only lineweight differentiates).  Non-grey text stays BYLAYER thin.
  (setq lwl (if (= col 8) (list (cons 370 25)) '()))
  (entmake (append
    (list (cons 0 "MTEXT") (cons 100 "AcDbEntity") (cons 8 "0") (cons 62 col))
    lwl
    (list (cons 100 "AcDbMText")
          (list 10 x y 0.0) (cons 40 h) (cons 41 wid)
          (cons 71 attach) (cons 7 "ROMAND") (cons 1 str) (cons 50 0.0)))))
;; owner UNIVERSAL RULE: MAIN HEADINGS bold but STILL ROMAND = heavier PEN (0.50mm) on romand strokes; strip
;; any incoming {\F..;TEXT} font wrapper, uppercase a plain heading, re-wrap in \Fromand.shx.
(defun tb-mtext-bold (x y h wid attach str col / raw lw)
  (setq raw str)
  (if (and raw (vl-string-search "\\F" raw))
    (progn
      (setq raw (vl-string-subst "" "{\\Fromand.shx;" raw))
      (if (and (> (strlen raw) 0) (= (substr raw (strlen raw) 1) "}"))
        (setq raw (substr raw 1 (1- (strlen raw)))))))
  (if (and raw (not (vl-string-search "{" raw)) (not (vl-string-search "\\" raw)))
    (setq raw (strcase raw)))
  ;; owner 22-Jul: BOLD PEN SCALES WITH TEXT HEIGHT (romand.shx has no TTF bold, so bold = heavier pen).  A
  ;; fixed 0.50mm looked bold on small text but thin on the big hero.  pen(0.01mm) = h*0.12 snapped to a valid
  ;; AutoCAD lineweight enum via peb-lw370 (mm=h*0.0012), floored at 50 (never thinner than the old fixed bold),
  ;; capped at 211 by the enum.  hero h~1161 -> 200 (2.0mm, fills the duplex), company h~1010 -> 158, small
  ;; heading h~416 -> 70.  (0.0016 rather than 0.0012 so the giant hero fills solid instead of looking outlined.)
  (setq lw (if (member 'peb-lw370 (atoms-family 1)) (peb-lw370 (* h 0.0016)) 50))
  (if (< lw 50) (setq lw 50))
  (entmake (list (cons 0 "MTEXT") (cons 100 "AcDbEntity") (cons 8 "0")
                 (cons 62 col) (cons 370 lw) (cons 100 "AcDbMText")   ; bold pen ∝ text height (valid LW enum)
                 (list 10 x y 0.0) (cons 40 h) (cons 41 wid)
                 (cons 71 attach) (cons 7 "ROMAND")
                 (cons 1 (strcat "{\\Fromand.shx;" raw "}")) (cons 50 0.0))))
(defun tb-pline (pts wid col / l)
  (setq l (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 "0")
                (cons 62 col) (cons 100 "AcDbPolyline")
                (cons 90 (/ (length pts) 2)) (cons 70 0) (cons 43 wid)))
  (while pts
    (setq l (append l (list (list 10 (car pts) (cadr pts)))) pts (cddr pts)))
  (entmake l))
(defun tb-solid-tri (x1 y1 x2 y2 x3 y3 col)
  (entmake (list (cons 0 "SOLID") (cons 100 "AcDbEntity") (cons 8 "0")
                 (cons 62 col) (cons 100 "AcDbTrace")
                 (list 10 x1 y1 0.0) (list 11 x2 y2 0.0)
                 (list 12 x3 y3 0.0) (list 13 x3 y3 0.0))))
;; AUTOFIT: return a text height so a string of N chars fits within width mw on
;; ONE line, capped at the desired height mh.  owner 7-Jul: the real romans.shx advance is
;; ~0.72 x height (0.64 was optimistic -> long labels/values overflowed their column into the
;; next); use 0.74 so autofit actually shrinks overflowing strings.
(defun tb-fith (s mw mh)
  ;; AUTOFIT (owner STANDING RULE 22-Jul: dynamic text FILLS its field).  Char-width ratio = romand ALL-CAPS
  ;; true advance ~0.86; the "too small" was the \f-vs-\F font bug (narrow Arial fallback), fixed separately.
  ;; 28-Jul (A4 paperspace title block): at the narrow A4 strip 0.86 UNDER-estimated the real ROMAND advance,
  ;; so long fitted strings (GENERAL NOTES, DRAWING TITLE, CUSTOMER) wrapped an extra line and overflowed into
  ;; the box below.  0.94 sizes them to their real width so each stays on the intended line count.
  (min mh (/ mw (* (max 1.0 (float (strlen s))) 0.94))))

;; strip an embedded unit suffix ("0 KN/m2" -> "0", "135 km/h" -> "135").
(defun peb-num-only (s / p)
  (setq p (vl-string-search " " s))
  (if p (substr s 1 p) s))

;; title-block value helpers (IF-linked): default when blank; dash "-" when not
;; applicable (zero / none); seismic shown as a ZONE.
(defun peb-tb-or (v d) (if (= v "") d v))
;; roof slope for the title block: normalized SLOPE is often just the ratio denominator ("10") -> "1:10".
(defun peb-tb-slope (v) (cond ((= v "") "-") ((= v "0") "FLAT") ((vl-string-search ":" v) v) (T (strcat "1:" v))))
(defun peb-tb-snow (v) (if (member (strcase v) '("" "0" "0.0" "0.00" "NONE" "-")) "-" v))
(defun peb-tb-zone (v) (cond ((= v "") "AS PER SITE") ((wcmatch (strcase v) "*ZONE*") v) (T (strcat "ZONE " v))))

;; "DD/MM/YYYY" -> "DD-Mon-YYYY" (clean date for the title block); pass-through otherwise.
(defun peb-pretty-date (s / p1 p2 dd mm yy months)
  (setq months '("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))
  (setq p1 (vl-string-search "/" s))
  (if (not p1) s
    (progn
      (setq dd (substr s 1 p1) p2 (vl-string-search "/" s (1+ p1)))
      (if (not p2) s
        (progn
          (setq mm (atoi (substr s (+ p1 2) (- p2 p1 1))) yy (substr s (+ p2 2)))
          (if (and (>= mm 1) (<= mm 12))
            (strcat dd "-" (nth (1- mm) months) "-" yy) s))))))

(defun peb-tb-logo (cx cyBase w / red blue lft rgt ax baseY apexY th)
  (setq red 1 blue 5)
  (setq lft   (- cx (* w 0.47)) rgt (+ cx (* w 0.47))
        ax    (+ cx (* w 0.06))
        baseY (+ cyBase (* w 0.30)) apexY (+ baseY (* w 0.14)))
  (tb-solid-tri lft baseY ax apexY ax (- apexY (* w 0.045)) red)
  (tb-solid-tri ax apexY rgt (+ baseY (* w 0.015)) ax (- apexY (* w 0.045)) red)
  (tb-pline (list lft baseY ax apexY rgt (+ baseY (* w 0.015))) (* w 0.016) red)
  (setq th (* w 0.150))
  (tb-mtext cx (+ cyBase (* w 0.135)) th (* w 1.04) 5 "{\\Fromand.shx;MAIMAAR}" blue)
  (tb-mtext cx cyBase (* w 0.058) (* w 1.30) 5 "{\\Fromand.shx;BUILDING SYSTEMS}" blue))

;; Path to the real Maimaar logo DWG (normalised: geometry min-corner at 0,0,
;; native size 237 x 72.1).  -INSERTed natively by the LISP so the saved .dwg
;; is complete (no external post-processing).  Override before drawing if needed.
(if (not *PEB-LOGO-DWG*)
  (setq *PEB-LOGO-DWG*
        "D:/maimaar-os/3_Draftsman/Proposal Drawings/assets/MAIMAAR_LOGO_REAL.dwg"))

;; Insert the real Maimaar logo, scaled+centred to fit the cell (x0 y0)-(x1 y1).
(defun peb-tb-place-logo (x0 y0 x1 y1 / lw lh cw ch s px py pad)
  (setq lw 237.0 lh 72.1 pad 0.86
        cw (- x1 x0) ch (- y1 y0))
  (setq s (min (/ (* cw pad) lw) (/ (* ch pad) lh)))
  (setq px (- (/ (+ x0 x1) 2.0) (/ (* lw s) 2.0))
        py (- (/ (+ y0 y1) 2.0) (/ (* lh s) 2.0)))
  (if (findfile *PEB-LOGO-DWG*)
    (vl-catch-all-apply
      (function (lambda ()
        (setvar "ATTREQ" 0) (setvar "FILEDIA" 0)
        (setvar "INSUNITS" 0)        ; unitless target -> no auto unit-scaling on insert
        (command "_.-INSERT" *PEB-LOGO-DWG* (list px py 0.0) s s 0))))
    (princ "\n[title block] logo DWG not found — box left empty.")))

;; ── SHARED title-block data + framing (owner 7-Jul: EVERY sheet gets the SAME title block) ──
;; peb-build-tbdata builds the full Mammut title-block field alist straight from the NORMALIZED
;; data (the same legacy alist every sheet parses), so the title block is identical on the Column
;; Layout Plan, Roof Plan, Wall Elevations and Framing Elevations — only DRGTITLE differs.
(defun peb-build-tbdata (data drgTitle / propinput propno tbQuote tbBno tbDrn tbChk tbBname tbDate
                                          revno windspeed exposure collateral fulldate)
  (setq propinput (MSPL-Get-Str data "PROPOSAL"))
  (if (= propinput "") (setq propinput "000"))
  (setq propno (strcat "MSPL-26-" propinput))
  (setq revno (MSPL-Get-Str data "REVNO")) (if (= revno "") (setq revno "0"))
  (setq windspeed  (MSPL-Get-Str data "WINDSPEED"))
  (setq exposure   (MSPL-Get-Str data "EXPOSURE"))
  (setq collateral (MSPL-Get-Str data "COLLATERAL"))
  (setq fulldate (format-date (getvar "CDATE")))
  ;; QUOTE: prefer the IF's full proposal no.; else re-form the digits-only code.
  (setq tbQuote (MSPL-Get-Str data "PROPOSAL_FULL"))
  (if (= tbQuote "")
    (cond
      ((and (= (strlen propinput) 5) (wcmatch propinput "#####"))
       (setq tbQuote (strcat "MSPL-" (substr propinput 1 2) "-" (substr propinput 3))))
      (T (setq tbQuote propno))))
  (setq tbBno (MSPL-Get-Str data "BLDGNO")) (if (= tbBno "") (setq tbBno "00"))
  (if (= (strlen tbBno) 1) (setq tbBno (strcat "0" tbBno)))
  (setq tbDrn (MSPL-Get-Str data "TBDRN")) (if (= tbDrn "") (setq tbDrn "M.H"))
  (setq tbChk (MSPL-Get-Str data "TBCHK")) (if (= tbChk "") (setq tbChk "YEA"))
  (setq tbBname (MSPL-Get-Str data "TBBLDGNAME"))
  (setq tbDate (MSPL-Get-Str data "TBDATE"))
  (if (= tbDate "") (setq tbDate fulldate) (setq tbDate (peb-pretty-date tbDate)))
  (list
    (cons "REV"  (if (= revno "0") "00" revno))
    (cons "DATE" tbDate)
    (cons "DRN"  tbDrn) (cons "CHK" tbChk)
    (cons "LL_ROOF"  (peb-tb-or (MSPL-Get-Str data "LIVEROOF")  "0.57"))
    (cons "LL_FRAME" (peb-tb-or (MSPL-Get-Str data "LIVEFRAME") "0.57"))
    (cons "WIND"     (if (= windspeed "") "AS PER CODE" (peb-num-only windspeed)))
    (cons "EXPOSURE" (peb-tb-or exposure "B"))
    (cons "COLL"     (if (= collateral "") "0.0" (peb-num-only collateral)))
    (cons "SNOW"     (peb-tb-snow (MSPL-Get-Str data "SNOW")))
    (cons "SEISMIC"  (peb-tb-zone (MSPL-Get-Str data "SEISMIC")))
    (cons "TEMP"     (peb-tb-snow (MSPL-Get-Str data "TEMP")))
    (cons "RAIN"     (peb-tb-or   (MSPL-Get-Str data "RAIN") "-"))
    (cons "CODE"     (peb-tb-or (MSPL-Get-Str data "DESIGNCODE") "MBMA 2006"))
    ;; building data — for the CROSS SECTION sheet's title block (owner 29-Jul: each sheet's title bar
    ;; carries details about ITS drawing; the Section shows BUILDING data, never member sections/thk).
    ;; comma-grouped, like every other number in the set (owner's number-presentation
    ;; standard).  KEY BUILDING DATA read "13716 / 33528 / 6996" on the Cross Section
    ;; while the plan beside it read "121,920".
    (cons "BWIDTH"   (peb-tb-comma (MSPL-Get-Str data "WIDTH")))
    (cons "BLENGTH"  (peb-tb-comma (MSPL-Get-Str data "LENGTH")))
    ;; a real EAVE height, not the clear height wearing an eave label (owner 26-Aug)
    (cons "BEAVE"    (peb-comma (peb-tb-eave-height data)))
    (cons "BCLEAR"   (peb-tb-comma (MSPL-Get-Str data "CLEARHEIGHT")))
    (cons "BSLOPE"   (peb-tb-slope (MSPL-Get-Str data "SLOPE")))
    (cons "BBAYS"    (peb-tb-or (MSPL-Get-Str data "NUMBAYS")     "-"))
    (cons "ROOFPANEL" (peb-tb-or (MSPL-Get-Str data "ROOFSHEETING") ""))
    (cons "PROJECT"  (peb-tb-or (MSPL-Get-Str data "PROJECT") "UNNAMED PROJECT"))
    (cons "CUSTOMER" (peb-tb-or (MSPL-Get-Str data "CLIENT") "UNNAMED CLIENT"))
    (cons "ADDR"
      (strcat "Lahore Office\\P" "238, First Floor, Lalazar Commercial Area,\\P"
              "Raiwind Road, Lahore, Pakistan\\P" "Web: www.maimaargroup.com\\P"
              "Cell : +(92-300) 807 4007"))
    (cons "QUOTE"     tbQuote)
    (cons "BLDGNO"    tbBno)
    (cons "BLDGNAME"  tbBname)
    (cons "IDENTICAL" (peb-tb-or (MSPL-Get-Str data "IDENTICAL") "1"))
    (cons "DRGTITLE"  drgTitle)
    (cons "SCALE"     "N.T.S.")
    (cons "SHEETSIZE" "A1")
    (cons "SHEETNO"   (strcat "PRO-" tbBno))))

;; Draw the title-block strip + border around whatever is currently in model space (call LAST, after all
;; content is drawn).  ADAPTIVE: a landscape sheet (Plan/Roof) gets the full-height flush-right strip (the
;; owner 5-Jul look); a tall PORTRAIT stack (Wall/Framing elevations) gets a bottom-right CORNER block sized
;; to the content width, so the title block never balloons to the stack height.  drgTitle = the sheet title.
(defun peb-frame-and-titleblock (data drgTitle / tbData ds bGap exmin exmax cW cH shBB
                                                 borderL borderB borderT tbStripW tbStripH tbStripX tbY0 borderR)
  ;; owner 7-Jul (multi-area cover): when a combining orchestrator suppresses per-area title blocks
  ;; (*PEB-SUPPRESS-TB*), skip — the finalize pass draws ONE frame around the whole set (mirrors the CLP).
  (if (not *PEB-SUPPRESS-TB*)
    (progn
      (setq tbData (peb-build-tbdata data drgTitle))
      (setq ds (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0))
      ;; SHEET MARGIN.  A margin is a PAPER quantity - it must look the same on every
      ;; sheet - but this is multiplied by DIM-SCALE, which tracks the building, so the
      ;; bigger the shed the wider the empty band.  On B-03 it came out 8127 model units,
      ;; about 10.8 mm of blank paper on all four sides.  Trimmed to a normal drafting
      ;; margin; it still clears a grid bubble, which is what the bubR term is for.
      (setq bGap (max (* 1700.0 ds) (if *PEB-BUBRAD* (* 1.15 *PEB-BUBRAD*) 600.0)))
      ;; ── FRAME THIS SHEET, NOT THE WHOLE DRAWING (owner 26-Aug) ───────────────
      ;; EXTMIN/EXTMAX are the extents of EVERY entity in the drawing.  Each sheet is
      ;; drawn at the origin and only tiled into place afterwards, so by the time the
      ;; third sheet is framed the extents already span the first two — the frame
      ;; stretched to cover them and the title block was pushed out past them, leaving
      ;; the drawing stranded in the left fifth of a sheet that was mostly void.
      ;;
      ;; Measured on B-01: frame widths grew 68,690 -> 37,156 -> 235,385 -> 477,366,
      ;; i.e. each frame was about as wide as everything drawn before it.  On the
      ;; framing-elevations sheet the drawings held 0-19% of the width and the title
      ;; block 90-100%: 71% of the sheet was empty.  The FIRST sheet in a file has no
      ;; predecessors, which is why the cover and plan always looked right.
      ;;
      ;; *PEB-SHEET-MARK* is the entlast the from-file wrapper captured BEFORE drawing,
      ;; so peb-ents-after returns exactly this sheet's entities.  Falls back to the old
      ;; extents when no mark was set (a bare C:PEB-* command on an empty drawing).
      (vl-catch-all-apply (function (lambda () (command "_.ZOOM" "_E"))))
      (setq exmin (getvar "EXTMIN") exmax (getvar "EXTMAX"))
      (setq shBB (if (boundp '*PEB-SHEET-MARK*)
                   (vl-catch-all-apply
                     (function (lambda () (peb-ss-bbox (peb-ents-after *PEB-SHEET-MARK*)))))
                   nil))
      (if (and shBB (not (vl-catch-all-error-p shBB)) (listp shBB) (= (length shBB) 2))
        (setq exmin (car shBB) exmax (cadr shBB)))
      (setq cW (- (car exmax) (car exmin)) cH (- (cadr exmax) (cadr exmin)))
      (setq borderL (- (car  exmin) bGap)
            borderB (- (cadr exmin) bGap)
            borderT (+ (cadr exmax) bGap))
      (cond
        ((<= cH (* cW 1.25))                 ; landscape → full-height flush-right strip (CLP/Roof look)
          (setq tbStripH (- borderT borderB)
                tbStripW (* tbStripH 0.30)
                tbY0     borderB))
        (T                                   ; portrait stack → bottom-right corner block sized to content WIDTH
          (setq tbStripW (* cW 0.20)
                tbStripH (/ tbStripW 0.30)   ; keep the ~0.30 aspect
                tbY0     borderB)))
      ;; GAP between the drawing and the title table (owner 26-Aug: "the Title Table
      ;; Lines and Drawings there is lot of empty space in b/w").  3500 * DIM-SCALE was
      ;; 9482 model units on B-03 - roughly 12.6 mm of dead paper down the middle of the
      ;; sheet, and it grew with every bigger building.  A gutter, not a void.
      (setq tbStripX (+ (car exmax) (* 1100.0 ds))
            borderR  (+ tbStripX tbStripW))
      (vl-catch-all-apply (function (lambda () (peb-titleblock-mammut tbStripX tbY0 tbStripW tbStripH tbData))))
      (draw-border borderL borderB borderR borderT)))
  (princ))

;; Mammut-MIRROR vertical title strip:  NOTES + disclaimer + DESIGN-LOAD table
;; anchored at the TOP, PROJECT-INFORMATION block anchored at the BOTTOM (exact
;; mirror of the Mammut proposal-drawing title block).  Every value links to the IF.
(defun peb-titleblock-mammut (X0 Y0 W H data
                              / white grey green cyan midX cw val lbl bv sm tbBlind
                              yCur bt rh bottomH lx vx ux c1x c2x tb-get tb-hdiv s dt tbKind bandTop)
  (setq white 7 grey 8 green 3 cyan 4)
  (setq s (if (and *PEB-TB-SIZEH* (> *PEB-TB-SIZEH* 0.0)) *PEB-TB-SIZEH* H))   ; F2 flush-strip content cap (owner 16-Jul)
  (defun tb-get (k) (cond ((cdr (assoc k data))) (T "")))
  (defun tb-hdiv (y) (tb-line X0 y (+ X0 W) y white))
  (setq midX (+ X0 (* W 0.50)) cw (* W 0.90)
        val (* s 0.0140) lbl (* s 0.0112) bv (* s 0.0160) sm (* s 0.0108))
  (tb-rect X0 Y0 (+ X0 W) (+ Y0 H) white)

  ;; ===================== TOP : GENERAL NOTES =====================
  (setq yCur (+ Y0 H))
  (setq rh (* s 0.026) bt yCur yCur (- yCur rh))
  (tb-mtext-bold midX (+ yCur (* rh 0.28)) (* s 0.0140) cw 5
            "GENERAL NOTES" white)
  (tb-hdiv yCur)
  (setq rh (* s 0.122) bt yCur yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* sm 1.3))
    (tb-fith "    DIMENSIONS & LEVELS WILL BE SHOWN IN THE" cw (* sm 0.75)) cw 1  ; owner 5-Jul: smaller so the 8-line note fits its box (was overflowing into the disclaimer)
    (strcat "1. ALL DIMENSIONS ARE IN MM.\\P"
            "2. PROPOSAL DRAWING - NOT FOR CONSTRUCTION.\\P"
            "3. PROPOSAL DRAWING IS INDICATIVE ONLY; FINAL\\P"
            "    DIMENSIONS & LEVELS WILL BE SHOWN IN THE\\P"
            "    APPROVAL DRAWING AT THE DESIGN STAGE.\\P"
            "4. FOR DETAILED DESCRIPTION, REFER TO THE\\P"
            "    TECHNICAL & FINANCIAL PROPOSAL.") white)
  (tb-hdiv yCur)
  ;; ----- disclaimer -----
  (setq rh (* s 0.058) bt yCur yCur (- yCur rh))
  (tb-mtext midX (+ yCur (* rh 0.5))
    (tb-fith "MAIMAAR STEEL (PVT) LTD - NOT FOR CONSTRUCTION" cw (* s 0.0105)) cw 5
    (strcat "THIS DOCUMENT IS A PROPOSAL DRAWING OF\\P"
            "MAIMAAR STEEL (PVT) LTD - NOT FOR CONSTRUCTION") cyan)
  (tb-hdiv yCur)
  ;; ----- SHEET-SPECIFIC DATA / NOTES (owner 29-Jul) -----
  ;; Mammut puts the design CRITERIA (loads) on the general Column-Layout-Plan sheet ONLY; every OTHER sheet
  ;; carries notes/data about ITS OWN drawing.  Kind is inferred from the drawing title (no extra field to
  ;; thread); an unrecognised title keeps the DESIGN-LOAD table (back-compat for Roof/other landscape sheets).
  ;; PROPOSAL level — never member sections / web-flange thicknesses (owner).  All four kinds fill the SAME
  ;; vertical band (bandTop -> bandTop-0.276s) so the bottom PROJECT block still lines up on every sheet.
  (setq lx (+ X0 (* W 0.05)) vx (+ X0 (* W 0.70)) ux (+ X0 (* W 0.865)))   ; owner 7-Jul: value+unit cols
  (setq dt (strcase (tb-get "DRGTITLE"))
        tbKind (cond ((wcmatch dt "*SECTION*")             "SECTION")
                     ((wcmatch dt "*FRAMING*")             "FRAMING")
                     ((wcmatch dt "*SHEETING*,*CLADDING*") "SHEETING")
                     (T                                    "PLAN"))
        bandTop yCur)
  (cond
    ;; ==== PLAN / default : DESIGN-LOAD table (the design-criteria home) ====
    ((= tbKind "PLAN")
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.035)) (- bt (* s 0.0110))
        (tb-fith "THE BUILDING HAS BEEN DESIGNED TO" (* cw 0.80) (* s 0.0086)) (* W 0.93) 1
        (strcat "THE BUILDING HAS BEEN DESIGNED TO\\P"
                "SUPPORT IT'S OWN DEAD LOAD PLUS:") green)
      (foreach r (list
           (list "LIVE LOAD ON ROOF"      (tb-get "LL_ROOF")  "KN/SQ.M.")
           (list "LIVE LOAD ON FRAME"     (tb-get "LL_FRAME") "KN/SQ.M.")
           (list "WIND SPEED (3-SEC GUST)" (tb-get "WIND")    "KPH")
           (list "EXPOSURE CATEGORY"      (tb-get "EXPOSURE") "")
           (list "ADD'L. COLLATERAL LOAD" (tb-get "COLL")     "")
           (list "ROOF SNOW LOAD"         (tb-get "SNOW")     "KN/SQ.M.")
           (list "SEISMIC LOAD"           (tb-get "SEISMIC")  "")
           (list "TEMPERATURE LOAD"       (tb-get "TEMP")     "")
           (list "RAINFALL INTENSITY"     (tb-get "RAIN")     "MM/HR"))
        (setq rh (* s 0.0200) yCur (- yCur rh))
        ;; label left-aligned; VALUE right-aligned at 0.80W; UNIT right-aligned ending 0.975W (small pen)
        ;; so neither the value nor the unit can touch the strip border (owner 29-Jul: values were spilling).
        (tb-mtext lx (+ yCur (* rh 0.5)) (tb-fith (car r) (* W 0.60) sm) 0 4 (car r) white)
        (tb-mtext (+ X0 (* W 0.80)) (+ yCur (* rh 0.5)) (tb-fith (cadr r) (* W 0.14) val) 0 6 (cadr r) green)
        (if (/= (caddr r) "")
          (tb-mtext (+ X0 (* W 0.82)) (+ yCur (* rh 0.5)) (tb-fith (caddr r) (* W 0.155) (* sm 0.90)) 0 4 (caddr r) grey)))
      (setq rh (* s 0.044) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (+ yCur (* rh 0.74))
        (tb-fith (strcat "AS PER " (tb-get "CODE") " METAL BUILDING SYSTEMS MANUAL")
                 (* cw 1.02) (* s 0.0092)) cw 1
        (strcat "{\\Fromand.shx;AS PER " (tb-get "CODE")
                " METAL BUILDING SYSTEMS MANUAL}") green))
    ;; ==== SECTION : KEY BUILDING DATA (dimensions in MM — NEVER member sections/thk) ====
    ((= tbKind "SECTION")
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext-bold (+ X0 (* W 0.035)) (- bt (* s 0.0130))
        (tb-fith "KEY BUILDING DATA" (* cw 0.85) (* s 0.0120)) (* W 0.93) 1 "KEY BUILDING DATA" green)
      (foreach r (list
           (list "BUILDING WIDTH"  (tb-get "BWIDTH")  "MM")
           (list "BUILDING LENGTH" (tb-get "BLENGTH") "MM")
           (list "EAVE HEIGHT"     (tb-get "BEAVE")   "MM")
           (list "ROOF SLOPE"      (tb-get "BSLOPE")  "")
           (list "No. OF BAYS"     (tb-get "BBAYS")   ""))
        (setq rh (* s 0.0280) yCur (- yCur rh))
        (tb-mtext lx (+ yCur (* rh 0.5)) (tb-fith (car r) (* W 0.52) sm) 0 4 (car r) white)
        (tb-mtext (+ X0 (* W 0.80)) (+ yCur (* rh 0.5)) (tb-fith (cadr r) (* W 0.16) val) 0 6 (cadr r) green)
        (if (/= (caddr r) "")
          (tb-mtext (+ X0 (* W 0.82)) (+ yCur (* rh 0.5)) (tb-fith (caddr r) (* W 0.155) (* sm 0.90)) 0 4 (caddr r) grey)))
      (setq rh (* s 0.050) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (+ yCur (* rh 0.72))
        (tb-fith "HEIGHTS, SLOPE & GRIDS AS SHOWN ON THE SECTION." (* cw 1.02) (* s 0.0090)) cw 1
        "HEIGHTS, SLOPE & GRIDS AS SHOWN ON THE SECTION." green))
    ;; ==== FRAMING : proposal-level framing notes (NO member sizes/sections) ====
    ((= tbKind "FRAMING")
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext-bold (+ X0 (* W 0.035)) (- bt (* s 0.0130))
        (tb-fith "FRAMING NOTES" (* cw 0.85) (* s 0.0120)) (* W 0.93) 1 "FRAMING NOTES" green)
      ;; The band is sized for the DATA sheets, whose row list fills it.  These note
      ;; sheets carried four short lines and left the other two thirds empty (owner
      ;; 26-Aug).  It cannot be fixed by bigger text - tb-fith already caps these lines
      ;; on the COLUMN WIDTH, so they are as large as the strip allows - and it cannot be
      ;; fixed by a shorter band without the bottom PROJECT block sitting at a different
      ;; height on notes sheets than on data sheets.  So the band is filled with content:
      ;; two more proposal-level notes, same register as the existing four, each deferring
      ;; to the proposal or the approved design rather than asserting anything new.
      (setq rh (* s 0.224) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (- (+ yCur rh) (* sm 1.3))
        (tb-fith "3. BRACING & ANCHORS PER APPROVED DESIGN." cw (* sm 1.05)) cw 1
        (strcat "1. FRAMING SHOWN IS INDICATIVE ONLY.\\P"
                "2. MEMBER SIZES PER APPROVED DESIGN.\\P"
                "3. BRACING & ANCHORS PER APPROVED DESIGN.\\P"
                "4. WALL INFILL BY OTHERS AS SHOWN.\\P"
                ;; kept under ~40 characters so each note stays on ONE line — note 3 is
                ;; the longest that fits the strip, and a wrapped note reads as a mistake
                "5. CONNECTIONS BOLTED UNLESS NOTED.\\P"
                "6. FRAME GEOMETRY PER CROSS SECTION.") white))
    ;; ==== SHEETING / CLADDING : proposal-level cladding notes ====
    (T
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext-bold (+ X0 (* W 0.035)) (- bt (* s 0.0130))
        (tb-fith "CLADDING NOTES" (* cw 0.85) (* s 0.0120)) (* W 0.93) 1 "CLADDING NOTES" green)
      ;; The band is sized for the DATA sheets, whose row list fills it.  These note
      ;; sheets carried four short lines and left the other two thirds empty (owner
      ;; 26-Aug).  It cannot be fixed by bigger text - tb-fith already caps these lines
      ;; on the COLUMN WIDTH, so they are as large as the strip allows - and it cannot be
      ;; fixed by a shorter band without the bottom PROJECT block sitting at a different
      ;; height on notes sheets than on data sheets.  So the band is filled with content:
      ;; two more proposal-level notes, same register as the existing four, each deferring
      ;; to the proposal or the approved design rather than asserting anything new.
      (setq rh (* s 0.224) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (- (+ yCur rh) (* sm 1.3))
        (tb-fith "3. FLASHINGS & TRIMS PER APPROVED DESIGN." cw (* sm 1.05)) cw 1
        (strcat "1. ROOF & WALL PANELS AS SPECIFIED.\\P"
                "2. PROFILE & COLOUR TO CLIENT SELECTION.\\P"
                "3. FLASHINGS & TRIMS PER APPROVED DESIGN.\\P"
                "4. OPENINGS & INFILL BY OTHERS AS SHOWN.\\P"
                "5. SHEET THICKNESS PER THE PROPOSAL.\\P"
                "6. FASTENERS & SEALANTS PER DESIGN.") white)))
  (setq yCur (- bandTop (* s 0.276)))
  (tb-hdiv yCur)

  ;; ============ BOTTOM : PROJECT INFORMATION (anchored to bottom) ============
  (setq bottomH (* s 0.515))
  (setq yCur (+ Y0 bottomH))
  (tb-hdiv yCur)
  ;; rev table : two sub-rows x cols
  (setq rh (* s 0.026))
  ;; owner 29-Jul: FIT every rev-table value + label to its column so none can spill past a cell edge
  ;; (REV.NO. was crossing the left border; the DATE was touching the DSN divider).
  (tb-mtext (+ X0 (* W 0.11)) (- yCur (* rh 0.55)) (tb-fith (tb-get "REV")  (* W 0.20) val) 0 5 (tb-get "REV")  green)
  (tb-mtext (+ X0 (* W 0.41)) (- yCur (* rh 0.55)) (tb-fith (tb-get "DATE") (* W 0.36) val) 0 5 (tb-get "DATE") green)
  (tb-mtext (+ X0 (* W 0.80)) (- yCur (* rh 0.55)) (tb-fith (tb-get "DRN") (* W 0.12) val) 0 5 (tb-get "DRN")  green)   ; owner 5-Jul: fit initials to the cell
  (tb-mtext (+ X0 (* W 0.935))(- yCur (* rh 0.55)) (tb-fith (tb-get "CHK") (* W 0.12) val) 0 5 (tb-get "CHK")  green)
  (tb-hdiv (- yCur rh))
  (tb-mtext (+ X0 (* W 0.11)) (- yCur rh (* rh 0.55)) (tb-fith "Rev. No." (* W 0.20) lbl) 0 5 "Rev. No." grey)
  (tb-mtext (+ X0 (* W 0.41)) (- yCur rh (* rh 0.55)) (tb-fith "Date"     (* W 0.34) lbl) 0 5 "Date"    grey)
  (tb-mtext (+ X0 (* W 0.665))(- yCur rh (* rh 0.55)) (tb-fith "DSN"      (* W 0.12) lbl) 0 5 "DSN"     grey)
  (tb-mtext (+ X0 (* W 0.80)) (- yCur rh (* rh 0.55)) (tb-fith "DRN"      (* W 0.12) lbl) 0 5 "DRN"     grey)
  (tb-mtext (+ X0 (* W 0.935))(- yCur rh (* rh 0.55)) (tb-fith "CHK"      (* W 0.12) lbl) 0 5 "CHK"     grey)
  (tb-line (+ X0 (* W 0.22)) (- yCur (* rh 2.0)) (+ X0 (* W 0.22)) yCur white)
  (tb-line (+ X0 (* W 0.60)) (- yCur (* rh 2.0)) (+ X0 (* W 0.60)) yCur white)
  (tb-line (+ X0 (* W 0.735))(- yCur (* rh 2.0)) (+ X0 (* W 0.735)) yCur white)
  (tb-line (+ X0 (* W 0.87)) (- yCur (* rh 2.0)) (+ X0 (* W 0.87)) yCur white)
  (setq yCur (- yCur (* rh 2.0)))
  (tb-hdiv yCur)
  ;; PROJECT NAME — label on its own line, value left-aligned BELOW it (no overlap)
  (setq bt yCur rh (* s 0.090) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "PROJECT NAME :" grey)
  ;; owner 23-Jul: BLIND (for-estimate) version leaves PROJECT + CUSTOMER blank so the client isn't revealed.
  (setq tbBlind (peb-blind-p data))
  (tb-mtext (+ X0 (* W 0.06)) (- bt (* lbl 3.0))
            (tb-fith (if tbBlind "" (tb-get "PROJECT")) (* cw 0.92) (* bv 0.92)) (* cw 0.92) 1 (if tbBlind "" (tb-get "PROJECT")) green)
  (tb-hdiv yCur)
  ;; CUSTOMER
  (setq bt yCur rh (* s 0.048) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "CUSTOMER :" grey)
  (tb-mtext midX (+ yCur (* rh 0.28)) (tb-fith (if tbBlind "" (tb-get "CUSTOMER")) cw bv) cw 5 (if tbBlind "" (tb-get "CUSTOMER")) green)
  (tb-hdiv yCur)
  ;; STEEL CONTRACTOR : enlarged logo + MAIMAAR wordmark + address (owner 10-Jul: "make Maimaar Steel
  ;; Pvt Ltd prominent in the right side table").  Hierarchy is LOGO > NAME > ADDRESS:
  ;;   * the old cell had NO company name at all — the name lived only in the red disclaimer
  ;;   * the address (white) was placed at 0.66*rh, INSIDE the logo box that started at 0.52*rh,
  ;;     so the logo and "LAHORE OFFICE" overlapped.  Address now sits BELOW the wordmark, in grey.
  ;;   * wordmark is capped at bv — the same height as the CUSTOMER value — so a proposal drawing
  ;;     still reads as addressed to the client rather than as an advertisement.
  ;; Cell grown 0.118H -> 0.140H; the bottom block had 0.066H of footer slack, now 0.044H (still ~4*lbl).
  (setq bt yCur rh (* s 0.140) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "STEEL CONTRACTOR :" grey)
  (peb-tb-place-logo (+ X0 (* W 0.14)) (+ yCur (* rh 0.56))
                     (+ X0 (* W 0.86)) (- bt (* lbl 2.4)))
  ;; wordmark — ONE line: MTEXT width 0 = no wrap.  tb-fith assumes a 0.74 advance while bold caps run
  ;; ~0.82, so fit to 0.80*cw to keep the bold string inside the strip.
  ;; NOTE for anyone reviewing a PNG preview: ezdxf's matplotlib backend WRAPS an RTF-wrapped MTEXT
  ;; ("{\Fromand.shx;...}") even when width=0 — a plain MTEXT with the same width renders on one line.
  ;; That two-line "…(PVT)" / "LTD" you may see in a preview is a RENDERER artifact, not the drawing.
  (tb-mtext-bold midX (+ yCur (* rh 0.44))
            (tb-fith "MAIMAAR STEEL (PVT) LTD" cw bv) 0 5
            "MAIMAAR STEEL (PVT) LTD" white)
  (tb-mtext (+ X0 (* W 0.06)) (+ yCur (* rh 0.355)) (* sm 0.52) cw 1 (tb-get "ADDR") grey)
  (tb-hdiv yCur)
  ;; quote / bldg rows
  (foreach pr (list (list "QUOTE NO." (tb-get "QUOTE"))
                    (list "Bldg. No." (tb-get "BLDGNO"))
                    (list "Bldg. Name." (tb-get "BLDGNAME"))
                    (list "No. Of Identical Bldg." (tb-get "IDENTICAL")))
    (setq rh (* s 0.0240) yCur (- yCur rh))
    ;; owner 23-Jul: PROPOSAL (QUOTE) NO. row is PROMINENT — bold LABEL + bold value (heavier pen, same height
    ;; so it can't overrun the row); the tracking ref for ALL communication, never blanked (even blind).
    (if (= (car pr) "QUOTE NO.")
      (progn
        (tb-mtext-bold (+ X0 (* W 0.05)) (+ yCur (* rh 0.50)) (tb-fith (car pr) (* W 0.44) lbl) 0 4 (car pr) grey)
        (tb-mtext-bold (+ X0 (* W 0.55)) (+ yCur (* rh 0.50))
              (tb-fith (strcat ": " (cadr pr)) (* W 0.42) (* s 0.009)) (* W 0.43) 4
              (strcat ": " (cadr pr)) green))
      (progn
        (tb-mtext (+ X0 (* W 0.05)) (+ yCur (* rh 0.50)) (tb-fith (car pr) (* W 0.44) lbl) 0 4 (car pr) grey)   ; owner 5-Jul: fit long labels so the value doesn't overlap
        (tb-mtext (+ X0 (* W 0.55)) (+ yCur (* rh 0.50))
              (tb-fith (strcat ": " (cadr pr)) (* W 0.42) val) (* W 0.43) 4
              (strcat ": " (cadr pr)) green)))
    (tb-hdiv yCur))
  ;; Drawing Title
  (setq bt yCur rh (* s 0.045) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.2)) lbl cw 1 "Drawing Title :" grey)
  (tb-mtext-bold midX (+ yCur (* rh 0.20)) (tb-fith (tb-get "DRGTITLE") cw (* bv 0.82)) cw 5   ; owner 5-Jul: lower + smaller so it clears the label
            (tb-get "DRGTITLE") green)
  (tb-hdiv yCur)
  ;; footer : Scale | Sheet Size | Sheet No.  (fills down to Y0)
  (setq rh (- yCur Y0) c1x (+ X0 (* W 0.40)) c2x (+ X0 (* W 0.70)))
  (tb-line c1x Y0 c1x yCur white) (tb-line c2x Y0 c2x yCur white)
  ;; owner 5-Jul: labels pinned to the TOP of the footer, values to the BOTTOM + smaller — no overlap.
  (tb-mtext (+ X0 (* W 0.04)) (- yCur (* lbl 1.0)) (tb-fith "Scale" (* W 0.34) lbl) 0 1 "Scale" grey)
  (tb-mtext (+ X0 (* W 0.20)) (+ Y0 (* val 0.95)) (* val 0.85) 0 5 (tb-get "SCALE") green)
  (tb-mtext (+ c1x (* W 0.03)) (- yCur (* lbl 1.0)) (tb-fith "Sheet Size" (* W 0.26) lbl) 0 1 "Sheet Size" grey)
  (tb-mtext (* 0.5 (+ c1x c2x)) (+ Y0 (* val 0.95)) (* val 0.85) 0 5 (tb-get "SHEETSIZE") green)
  (tb-mtext (+ c2x (* W 0.03)) (- yCur (* lbl 1.0)) (tb-fith "Sheet No." (* W 0.26) lbl) 0 1 "Sheet No." grey)
  (tb-mtext (* 0.5 (+ c2x (+ X0 W))) (+ Y0 (* val 0.95)) (* val 0.85) 0 5 (tb-get "SHEETNO") green)
  (princ))

;; ============================================================================
;; A4 PAPERSPACE LAYOUT (owner 28-Jul) — the professional "draftsman draws in the Model, frames each
;; drawing in a printable Layout" workflow.  The Model holds the geometry (title block SUPPRESSED via
;; *PEB-SUPPRESS-TB*); each sheet is wrapped in an A4 landscape LAYOUT: a right-hand Mammut title strip
;; (paperspace, fixed) + a border + ONE viewport showing the model at a REAL standard scale (1:S).  Plots
;; one-to-one to A4 and merges into the proposal PDF.  Reuses peb-titleblock-mammut at fixed paper coords.
;; ============================================================================

;; round a model-per-paper ratio UP to a standard architectural scale denominator (1:S)
;; ── MATCH-LINE SHEET PARTS (owner 26-Aug) ────────────────────────────────────
;; The drawing area beside the title block is about 218 x 198 mm — roughly 1.1:1.
;; A plan whose drawn block is far wider than that cannot use the sheet height AT
;; ALL: the fit is bound by width and the leftover height is simply unreachable.
;; Measured on B-03 (121920 x 30480 = 4:1): 118 mm of the 198 mm drawing height was
;; blank — 60% of the sheet — with 51 mm above the drawing and 51 mm below.
;;
;; The drafting answer for a building that long is not a smaller scale, it is to cut
;; it into parts joined by a MATCH LINE, each part drawn at roughly twice the scale.
;;
;; *PEB-PART-N* = how many parts this sheet is cut into (nil / 1 = not cut)
;; *PEB-PART-P* = which part is being drawn, 1-based
;;
;; peb-part-range returns (i0 i1), the STATION INDEX range this part covers, sharing
;; the boundary station with its neighbour so the match line falls on a real grid and
;; the two halves visibly join. Returns nil when there is no split to make.
(defun peb-part-range (nSt / p n per i0 i1)
  (if (and *PEB-PART-N* (> *PEB-PART-N* 1) (> nSt 2))
    (progn
      (setq p   (if *PEB-PART-P* *PEB-PART-P* 1)
            n   *PEB-PART-N*
            per (max 1 (fix (+ 0.5 (/ (float (1- nSt)) n)))))
      (setq i0 (* (1- p) per)
            i1 (if (>= p n) (1- nSt) (min (1- nSt) (* p per))))
      (if (>= i0 i1) nil (list i0 i1)))
    nil))

;; "ROOF FRAMING PLAN" -> "ROOF FRAMING PLAN  (SHEET 1 OF 2)" while a split is active.
;; Untouched when there is no split, so a normal building's heading never changes.
;; ── A HEADING MUST FIT THE DRAWING IT TITLES (owner 27-Aug) ──────────────────
;; "Proportionally size is too much."  peb-th 'HEADING is paper-constant (5.0 mm),
;; which is right for a short title but says nothing about a LONG one: on the side
;; wall sheets "FSW - FAR SIDE WALL SHEETING" is 28 characters and ran to about 54%
;; of the wall's own width, so the title competed with the drawing.
;;
;; Same principle as the bubble rule (4B.10): keep the paper size, then cap it
;; against the thing it has to sit over — here, 40% of the drawn width.  Short
;; headings ("ROOF FRAMING PLAN" is 33%) are untouched; only the long ones shrink.
;; txt-bold multiplies by TEXT-SCALE, so this returns the RAW height to hand it.
(defun peb-head-h (s faceLen / n hmax ts)
  (setq ts (if (and *PEB-TEXT-SCALE* (> *PEB-TEXT-SCALE* 0.01)) *PEB-TEXT-SCALE* 1.0)
        n  (max 1 (strlen s)))
  (if (> faceLen 1.0)
    (progn (setq hmax (/ (* 0.34 faceLen) (* n 0.62 ts)))
           (max (* 0.45 (peb-th 'HEADING)) (min (peb-th 'HEADING) hmax)))
    (peb-th 'HEADING)))

(defun peb-part-title (t0)
  (if (and *PEB-PART-N* (> *PEB-PART-N* 1))
    (strcat t0 "  (SHEET " (itoa (if *PEB-PART-P* *PEB-PART-P* 1))
            " OF " (itoa *PEB-PART-N*) ")")
    t0))

;; elements a..b of a list, inclusive
(defun peb-sub-list (l a b / i r)
  (setq i 0 r '())
  (foreach x l
    (if (and (>= i a) (<= i b)) (setq r (cons x r)))
    (setq i (1+ i)))
  (reverse r))

;; The MATCH LINE itself: a heavy dashed line down the cut edge, running clear of the
;; drawing top and bottom, with the sheet it continues onto named beside it.
(defun peb-match-line (x y0 y1 otherSheet / prev ov n hMx hLb)
  (setq prev (getvar "CLAYER"))
  (setvar "CLAYER" "GRID")
  (setq ov (getvar "CELTYPE"))
  (vl-catch-all-apply (function (lambda () (setvar "CELTYPE" "DASHED"))))
  (command "_.LINE" (list x y0) (list x y1) "")
  (vl-catch-all-apply (function (lambda () (setvar "CELTYPE" ov))))
  ;; The label reads ALONG the line.  Above the line it landed on the bay chain and the
  ;; bubbles (26-Aug); at mid-height on a WALL elevation it ran down through the grid
  ;; bubbles instead (27-Aug); moving it to the upper third was still not enough, because
  ;; the rotated string is sized for PAPER and a 6 m wall is only ~14 mm tall on the sheet,
  ;; so a 20-character label is longer than the line it labels.
  ;;
  ;; So the label is now CLIPPED to the line: its height is capped so the whole string fits
  ;; inside 80% of the span, and it is centred on that span.  On a tall drawing (a roof
  ;; plan) nothing changes — the cap is not reached.  On a short one it shrinks to fit
  ;; rather than running out into the bubbles.
  (setq n   (strlen (strcat "MATCH LINE - SHEET " otherSheet))
        hMx (/ (* 0.80 (- y1 y0)) (* n 0.62 (if (> *PEB-TEXT-SCALE* 0.01) *PEB-TEXT-SCALE* 1.0)))
        hLb (max (* 0.40 (peb-th 'ANNOT)) (min (peb-th 'ANNOT) hMx)))
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (+ x (* 700.0 *PEB-TEXT-SCALE*)) (/ (+ y0 y1) 2.0)) hLb 90
       (strcat "MATCH LINE - SHEET " otherSheet))
  (setvar "CLAYER" prev))

;; ── STANDARD PLOT SCALES ─────────────────────────────────────────────────────
;; The sheet is drawn at the next standard scale ABOVE the one that would exactly
;; fit, so the ladder's step size IS wasted paper: a coarse step leaves the drawing
;; floating in white.
;;
;; The old ladder jumped 500 -> 750 -> 1000.  The B-03 roof plan needs 1:595, which
;; rounded to 1:750 and drew the building at 79% of the width it could have used --
;; about 22 mm of blank down EACH side, and the right-hand one sits against the title
;; table, which is what reads as a gap (owner 26-Aug: "still there is gap").
;;
;; Steps are now no coarser than ~1.15x, so the rounding can never waste more than
;; about 13% of the sheet.  Every value is still a round number a draftsman would
;; write in the title block; the ladder already carried non-ISO-preferred steps
;; (75, 125, 150, 250, 300, 400, 750), so this is the same convention, finer.
;; EXACT FIT, ROUNDED UP TO A WHOLE NUMBER (owner 27-Aug).
;; `r` is model-units-per-paper-mm for the binding dimension. Rounding UP guarantees the
;; drawing still fits (never overfit); rounding to 1 keeps the printed scale an integer while
;; giving away at most one unit — versus up to 13% on the standard ladder below, which is
;; kept for anything that genuinely wants conventional rungs.
;; Detail sheets legitimately land under 1:10, so the floor is 1, not 10.
;; Rounding UP by a whole unit is cheap at 1:200 (0.5%) and expensive at 1:6 (14%), because
;; the step is a fixed size against a shrinking number. Measured: the SHEETING PROFILE
;; DETAILS sheet needed 1:6.11, was given 1:7, and filled 86% instead of 98%. So the step
;; follows the scale — tenths below 1:20, whole units above, which keeps a normal drawing's
;; scale an integer and only lets a detail sheet read 1:6.2.
(defun peb-fit-scale (r / v)
  (setq v (if (and r (> r 0.0)) r 1.0))
  (if (< v 20.0)
    (max 1.0 (/ (fix (+ 0.9999 (* v 10.0))) 10.0))
    (float (fix (+ 0.9999 v)))))

(defun peb-std-scale (r / scales)
  ;; 1..10 are for DETAIL sheets (the sheeting profile section is ~1000 mm wide and
  ;; would otherwise round to 1:20 and sit as a stamp in the corner of an A4).
  (setq scales '(1 2 5 10 20 25 30 40 50 60 75 100 125 150 175 200 225 250 275 300 350 400
                 450 500 550 600 650 700 750 800 900 1000 1100 1250 1500 1750 2000
                 2500 3000 4000 5000))
  (while (and (cdr scales) (< (car scales) r)) (setq scales (cdr scales)))
  (car scales))

;; patch (or add) a key in the title-block alist
(defun peb-tb-set (al key val / p)
  (if (setq p (assoc key al)) (subst (cons key val) p al) (cons (cons key val) al)))

;; Create an A4 layout `lname` viewing the model region bmin..bmax at a real standard scale.
;; `tbData` = peb-build-tbdata alist; `sheetNo` overrides the SHEET NO. cell (nil = keep).  Returns 1:S.
;; Apply ONE viewport property, announcing failure instead of swallowing it.  These calls
;; are individually fragile (a fresh paperspace viewport rejects some puts until it is on
;; and regenerated), and grouping them under one catch meant the first failure silently
;; skipped every later one.
(defun peb-vp-put (vp what fn / r)
  (setq r (vl-catch-all-apply fn))
  (if (vl-catch-all-error-p r)
    (princ (strcat "
PEB-VP: " what " FAILED - " (vl-catch-all-error-message r))))
  r)

;; Step INSIDE floating viewport `vp` (ename `vpe`) so a ZOOM will move ITS view and not
;; paper space.  Returns T only if we really are inside it.
;;
;; Getting in is unreliable in headless acad and the failure is silent, so this verifies
;; instead of assuming: CVPORT must end up equal to the viewport's own number (group 69).
;; Measured on B-01, MSPACE succeeded on some layouts and refused on others in the SAME run
;; ("variable setting rejected: CVPORT"), alternating rather than failing outright -- state
;; left over from the previous layout, not anything about the sheet being framed.  A plain
;; retry clears it, so retry, but never assume: a ZOOM fired while still in paper space
;; zooms the A4 sheet out to model coordinates and the tab then opens apparently empty.
;; REGENALL between attempts is what brings a fresh floating viewport on screen at all
;; (group 68 goes -1 "fully off screen" -> 2); MSPACE will not enter one that is off screen.
(defun peb-vp-enter (vp vpe / vpn tries)
  (setq vpn (cdr (assoc 69 (entget vpe))) tries 0)
  (while (and vpn (< tries 4) (/= (getvar "CVPORT") vpn))
    (setq tries (1+ tries))
    (vl-catch-all-apply (function (lambda () (vla-put-ViewportOn vp :vlax-true))))
    (vl-catch-all-apply (function (lambda () (command "_.PSPACE"))))
    (vl-catch-all-apply (function (lambda () (command "_.REGENALL"))))
    (vl-catch-all-apply (function (lambda () (command "_.MSPACE"))))
    (if (/= (getvar "CVPORT") vpn)
      (vl-catch-all-apply (function (lambda () (setvar "CVPORT" vpn))))))
  (if (and vpn (= (getvar "CVPORT") vpn))
    T
    (progn
      (princ (strcat "
PEB-VP: could not enter viewport " (vl-princ-to-string vpn)
                     " after " (itoa tries) " tries"
                     " (CTAB=" (getvar "CTAB")
                     " TILEMODE=" (itoa (getvar "TILEMODE"))
                     " CVPORT=" (itoa (getvar "CVPORT"))
                     " status68=" (vl-princ-to-string (cdr (assoc 68 (entget vpe)))) ")"))
      nil)))

(defun peb-add-layout (lname bmin bmax tbData sheetNo / paperW paperH margin tbW gap
                       dawX0 dawX1 dawY0 dawY1 mw mh sc lay vp vpe vpn cx cy pdw pdh cxp cyp)
  (setq paperW 297.0 paperH 210.0 margin 6.0 gap 3.0)   ; A4 landscape (owner: proposals always print on A4)
  (setq tbW    (* (- paperH (* 2.0 margin)) 0.32)
        dawX0  margin
        dawX1  (- paperW margin tbW gap)
        dawY0  margin
        dawY1  (- paperH margin))
  ;; real scale (compute BEFORE the title block so SCALE can read it)
  (setq mw (- (car bmax) (car bmin)) mh (- (cadr bmax) (cadr bmin)))
  (if (<= mw 0.0) (setq mw 1.0)) (if (<= mh 0.0) (setq mh 1.0))
  ;; BREATHING ROOM INSIDE THE FRAME (owner 27-Aug: "the drawings are fitting in the frames
  ;; of out boundary lines, partially hidden in pdf").
  ;;
  ;; The captured bbox is TIGHT — vla-GetBoundingBox returns each entity's own extent, and
  ;; the outermost things on a sheet are dimension text, grid bubbles and edge labels whose
  ;; drawn ink reaches slightly past the box the API reports (a rotated MTEXT in particular).
  ;; Framing the viewport on that exact box therefore shaves the outermost annotation
  ;; against the viewport edge, and the drawing reads as running into the border.
  ;;
  ;; This never showed before because the viewport was silently left at zoom-extents (see
  ;; peb-vp-put): everything was visible because everything was far too small. Fixing the
  ;; scale exposed the missing margin underneath it.
  ;;
  ;; 3% all round, applied to the SIZE only — cx/cy stay the true bbox centre, so the sheet
  ;; is still centred, just inset. Measured: 3% clears the annotation overhang that was being
  ;; shaved, while 6% (the first guess) cost real space on a sheet that is supposed to be
  ;; packed. The scale printed in the title block is the scale actually plotted, because sc
  ;; is computed from the padded size.
  (setq mw (* mw 1.03) mh (* mh 1.03))
  ;; ── FILL THE BOX (owner 27-Aug: "all drawings must be centrally placed in the box with
  ;; utilization of maximum space ... not overfit & not underfit") ─────────────────────
  ;; peb-std-scale rounds UP to the next rung of a standard ladder (…150, 175, 200, 225…).
  ;; Every rung skipped is paper thrown away: measured on B-01 the CROSS SECTION filled 77%
  ;; of the box in BOTH directions — under by the same amount each way, which is the
  ;; signature of scale rounding rather than of the drawing's shape. Worst rungs cost ~13%.
  ;;
  ;; A draughtsman wants a round scale, but 1:187 is every bit as round as 1:200 to read off
  ;; a title block, and it wastes 0.5% instead of 13%. So the scale is the exact fit rounded
  ;; UP to the next whole number — still an integer in the title block, never overfit,
  ;; and never more than 1 unit of slack.
  (setq sc (peb-fit-scale (max (/ mw (- dawX1 dawX0)) (/ mh (- dawY1 dawY0)))))
  ;; patch title-block fields for a paperspace A4 sheet
  (setq tbData (peb-tb-set tbData "SCALE"     (strcat "1:" (rtos sc 2 (if (< sc 20.0) 1 0)))))
  (setq tbData (peb-tb-set tbData "SHEETSIZE" "A4"))
  (if sheetNo (setq tbData (peb-tb-set tbData "SHEETNO" sheetNo)))
  ;; new layout + make current
  (command "_.-LAYOUT" "_N" lname)
  (command "_.-LAYOUT" "_S" lname)
  (setvar "CTAB" lname)
  (setq lay (vla-get-ActiveLayout (vla-get-ActiveDocument (vlax-get-acad-object))))
  (vl-catch-all-apply (function (lambda () (vla-put-ConfigName lay "DWG To PDF.pc3"))))
  (vl-catch-all-apply (function (lambda () (vla-put-CanonicalMediaName lay "ISO_full_bleed_A4_(297.00_x_210.00_MM)"))))
  (vl-catch-all-apply (function (lambda () (vla-put-StyleSheet lay "monochrome.ctb"))))
  (vl-catch-all-apply (function (lambda () (vla-put-PlotWithPlotStyles lay :vlax-true))))
  (vl-catch-all-apply (function (lambda () (vla-put-PlotRotation lay 0))))
  ;; work in paperspace; clear the auto-created viewport
  (setvar "TILEMODE" 0)
  (command "_.PSPACE")
  (command "_.ERASE" "_ALL" "")
  ;; title block (fixed A4 coords)
  (vl-catch-all-apply (function (lambda ()
    (peb-titleblock-mammut (+ dawX1 gap) margin tbW (- paperH (* 2.0 margin)) tbData))))
  ;; plain paperspace A4 border (NOT draw-border — that insets by 800*PEB-TEXT-SCALE, the MODEL text
  ;; scale ~15000 mm, which would blow up the plot extents and shrink the sheet to a dot).
  (vl-catch-all-apply (function (lambda ()
    (setvar "CLAYER" "0")
    (command "_.RECTANG" (list 3.0 3.0) (list (- paperW 3.0) (- paperH 3.0)))
    (command "_.RECTANG" (list margin margin) (list (- paperW margin) (- paperH margin))))))
  ;; drawing viewport + real scale inside it. TWO fixes over the old MSPACE+ZOOM-Window (owner 29-Jul):
  ;;  1. The viewport is sized to the DRAWING's own aspect (mw/sc x mh/sc), centred in the drawing-area box,
  ;;     so it shows ONLY this sheet — a fixed A4-aspect viewport shows extra model area in the non-binding
  ;;     dimension, which in the COMBINED DWG bleeds in the neighbouring tiled sheet.
  ;;  2. The view is set via ActiveX (ViewCenter + CustomScale) so it frames the sheet wherever it sits in the
  ;;     model — ZOOM-Window only worked when the sheet was at the origin (the PDF path erases between sheets).
  (setvar "CLAYER" "0")
  (setq cx  (/ (+ (car bmin) (car bmax)) 2.0)   cy  (/ (+ (cadr bmin) (cadr bmax)) 2.0)
        pdw (/ mw (float sc))                    pdh (/ mh (float sc))
        cxp (/ (+ dawX0 dawX1) 2.0)              cyp (/ (+ dawY0 dawY1) 2.0))
  ;; VIEWPORT BORDER MUST NOT PLOT (owner 26-Aug: "Crossed Box must be deleted, it is
  ;; not required — there is already a Box which is also part of the Title Block").
  ;; MVIEW's own outline was printing as a SECOND rectangle around the drawing, inside
  ;; the sheet border the title block already draws.  Put the viewport on its own
  ;; no-plot layer: it still frames and scales the view, its outline just never
  ;; reaches the paper.  CLAYER is restored to 0 straight after.
  ;; SHOW THE WHOLE A4 IN PAPER SPACE BEFORE THE VIEWPORT IS MADE.  This one line is the
  ;; difference between a layout that frames its sheet and one that comes out blank.
  ;; A viewport that falls outside the current paper-space view is flagged "on but FULLY OFF
  ;; SCREEN" (group 68 = -1), and MSPACE will not step into an off-screen viewport -- so the
  ;; ZOOM meant for the sheet lands on paper space instead and blows the A4 up to model
  ;; coordinates, leaving a tab that opens empty.  Measured: with the paper view left wherever
  ;; the previous layout happened to leave it, group 68 stayed -1 through four REGENALLs and
  ;; the sheets alternated between framed and blank for no reason to do with their contents.
  ;; Zoom the page into view first and group 68 becomes 2 on every sheet.
  (vl-catch-all-apply (function (lambda ()
    (command "_.ZOOM" "_W" (list 0.0 0.0) (list paperW paperH)))))
  (vl-catch-all-apply (function (lambda ()
    (command "_.-LAYER" "_Make" "PEB-VPORT" "_Plot" "_No" "PEB-VPORT" ""))))
  (command "_.MVIEW" (list (- cxp (/ pdw 2.0)) (- cyp (/ pdh 2.0)))
                     (list (+ cxp (/ pdw 2.0)) (+ cyp (/ pdh 2.0))))
  (setq vp (vlax-ename->vla-object (entlast)))
  ;; SET THE VIEW ONCE, DETERMINISTICALLY (owner 27-Aug: "each Layout must have one page
  ;; drawing").  This used to set ViewCenter + CustomScale by ActiveX and then follow it
  ;; with a "belt-and-suspenders" MSPACE / ZOOM _C / PSPACE for builds where the ActiveX put
  ;; might be a no-op.  Measured on B-01: the belt was breaking the suspenders.  Every
  ;; viewport came out at CustomScale 0.00113 (1:883) when its own sheet needed 1:200 — and
  ;; a 192 mm viewport at 1:883 shows 170 m of model, so each layout displayed its
  ;; NEIGHBOURS: PRO-01 COLUMN LAYOUT PLAN framed the whole tiled row, section and every
  ;; elevation, while its title block still printed the computed 1:225.
  ;;
  ;; MSPACE activates whichever viewport AutoCAD considers current, which in a freshly
  ;; created layout is not reliably the one just made, so the ZOOM landed elsewhere and left
  ;; this one at its default zoom-extents view.  ViewHeight IS the canonical property — set
  ;; it and the scale follows — so set height, then centre, then assert the scale, and do
  ;; not touch model space at all.  Nothing here depends on which viewport is "current".
  ;; ONE GUARD PER CALL.  All four used to share a single vl-catch-all-apply, so the first
  ;; one to throw silently skipped the rest — and vla-put-ViewCenter throws readily on a
  ;; viewport that has not been turned on and regenerated yet.  That is how every sheet
  ;; ended up at its default zoom-extents view while the cover, which goes through
  ;; peb-add-plain-layout, came out correct.  Each result is announced so a failure shows in
  ;; the AutoCAD log instead of vanishing.
  ;; ── RULE 4B.28 — EACH LAYOUT SHOWS ITS OWN SHEET, CENTRED (owner 28-Aug: "only few
  ;; pages are placed in the layout ... the drawings are not centrally placed in the middle
  ;; of layout box") ────────────────────────────────────────────────────────────
  ;;
  ;; THE ONE LINE THAT MATTERS IS THE REGENALL.  Everything else here is ordinary.
  ;;
  ;; Measured, not guessed.  Group 12 (view centre) read back from every viewport of a
  ;; finished B-01 DWG was the SAME point on all ten tabs -- 229401,11763, the extents centre
  ;; of the whole left-to-right tiled model -- while group 45 (view height) was correct and
  ;; different on each.  So the height was landing and the centre never was, and every tab
  ;; looked at one spot: the two or three sheets sitting near it showed something, the rest
  ;; came out blank or half off the box.  Both of the owner's symptoms, one cause.
  ;; IDENTICAL VIEW CENTRES ACROSS LAYOUTS IS THE SIGNATURE -- check it by number, because on
  ;; screen it reads as missing pages, not as a bad view.
  ;;
  ;; A viewport's view can only be moved from INSIDE it, so the viewport has to be made
  ;; current, and headless acad kept refusing: "There is no active modelspace viewport",
  ;; "Error setting current viewport", "variable setting rejected: CVPORT".  Probing the
  ;; entity said why -- group 68 was -1, "on but FULLY OFF SCREEN".  A fresh floating
  ;; viewport is not drawn until something forces a display update, and MSPACE will not
  ;; activate a viewport that is not on screen.  REGEN alone does not do it; REGENALL does:
  ;; measured, group 68 goes -1 -> 2 and CVPORT then reports this viewport's own number.
  ;;
  ;; Worse, the failure was silent AND destructive: when MSPACE quietly does not switch, the
  ;; ZOOM behind it lands on PAPER space and zooms the A4 sheet out to model coordinates, so
  ;; the tab opens apparently empty.  That is the other half of "only a few pages are placed
  ;; in the layout" -- the pages were there, the paper view was 80 m wide.
  ;;
  ;; Routes that CANNOT work here, so they are not worth trying again:
  ;;   * vla-put-ViewCenter  -- throws even once the viewport is current.
  ;;   * entmod of groups 12/45 -- returns nil; both are read-only on a viewport.
  ;;   * vla-put-ActivePViewport / setvar CVPORT before the REGENALL -- both rejected.
  ;; CustomScale IS writable without any of this, which is exactly why the height looked
  ;; right while the centre stayed wrong, and why the fault was so easy to misread.
  (setq vpe (vlax-vla-object->ename vp))
  ;; Only zoom if we really are inside our own viewport -- a zoom fired from paper space
  ;; wrecks the sheet, which is the failure this rule exists to stop.
  (if (peb-vp-enter vp vpe)
    (peb-vp-put vp "Zoom Centre" (function (lambda () (command "_.ZOOM" "_C" (list cx cy) mh))))
    (princ (strcat "
PEB-VP: view left unset for " lname)))
  (peb-vp-put vp "PSpace" (function (lambda () (command "_.PSPACE"))))
  ;; CustomScale after the centring: scaling about a centre keeps the centre, so the title
  ;; block's 1:S is the scale actually plotted (ZOOM height alone drifts by the rounding
  ;; peb-fit-scale applies).  DisplayLocked last -- the DWG goes to a customer who will
  ;; scroll it, and a locked viewport cannot be knocked off its scale by a stray wheel-zoom.
  (peb-vp-put vp "CustomScale"   (function (lambda () (vla-put-CustomScale vp (/ 1.0 (float sc))))))
  (peb-vp-put vp "DisplayLocked" (function (lambda () (vla-put-DisplayLocked vp :vlax-true))))
  ;; Leave PAPER space showing the A4 page, so opening the tab shows the sheet.
  (vl-catch-all-apply (function (lambda ()
    (command "_.ZOOM" "_W" (list 0.0 0.0) (list paperW paperH)))))
  (setvar "CLAYER" "0")
  sc)

;; ============================================================================
;; COMBINED-DWG helpers (owner 29-Jul): lay EVERY sheet into ONE shared model space, each
;; framed by its OWN named A4 layout tab, WITHOUT erasing between sheets — so the saved DWG
;; opens as a proper tabbed drawing set (all geometry visible in the single model, each tab
;; auto-fitted to its drawing). Used by the combined-DWG script; the PDF path is untouched.

;; Selection set of every MODEL entity created AFTER `marker` (nil = from the very first
;; entity). entnext walks the whole db in creation order, so calling this immediately after a
;; draw command captures exactly what that command just drew.
(defun peb-ents-after (marker / e ss)
  (setq ss (ssadd) e (if marker (entnext marker) (entnext)))
  (while e (setq ss (ssadd e ss) e (entnext e)))
  ss)

;; Bounding box (list min max) of a selection set via vla-GetBoundingBox; degenerate/failed
;; entities are skipped. Returns nil for an empty set.
(defun peb-ss-bbox (ss / i n o p1 p2 mn mx)
  (setq i 0 n (if ss (sslength ss) 0))
  (while (< i n)
    (setq o (vlax-ename->vla-object (ssname ss i)))
    (vl-catch-all-apply
      (function (lambda ()
        (vla-GetBoundingBox o 'p1 'p2)
        (setq p1 (vlax-safearray->list p1) p2 (vlax-safearray->list p2))
        (if mn (setq mn (mapcar 'min mn p1) mx (mapcar 'max mx p2))
                (setq mn p1 mx p2)))))
    (setq i (1+ i)))
  (if mn (list mn mx)))

;; Move a selection set by (dx dy).
(defun peb-ss-move (ss dx dy)
  (if (and ss (> (sslength ss) 0))
    (command "_.MOVE" ss "" (list 0.0 0.0) (list dx dy))))

;; Frame the sheet drawn since `mk` on its OWN named, auto-fitted A4 layout tab, then return to
;; the shared model. The from-file drawers already tiled the geometry left→right (peb-tile-place),
;; so here we only measure the just-drawn region and wrap it. Draw the sheet BETWEEN
;; (setq MK (entlast)) and this call, so any draw command composes.
;;   mk      : entlast marker captured just BEFORE the draw
;;   tabName : layout TAB text on AutoCAD's bottom bar (e.g. "PRO-01 COLUMN LAYOUT PLAN")
;;   tbData  : title-block alist (peb-build-tbdata ...)   sheetNo : SHEET NO. cell (e.g. "PRO-01")
(defun peb-frame-sheet (mk tabName tbData sheetNo / ss bb)
  (setq ss (peb-ents-after mk) bb (peb-ss-bbox ss))
  (if bb
    (progn
      (peb-add-layout tabName (car bb) (cadr bb) tbData sheetNo)
      (setvar "TILEMODE" 1) (setvar "CTAB" "Model")))    ; back to the shared model for the next sheet
  (princ))

;; A BARE A4 layout (no Mammut strip / border of its own) whose single full-page viewport frames
;; bmin..bmax — for the COVER sheet, which already carries its own complete A4 presentation frame.
(defun peb-add-plain-layout (lname bmin bmax / paperW paperH lay vp vpe vpn)
  (setq paperW 297.0 paperH 210.0)
  (command "_.-LAYOUT" "_N" lname)
  (command "_.-LAYOUT" "_S" lname)
  (setvar "CTAB" lname)
  (setq lay (vla-get-ActiveLayout (vla-get-ActiveDocument (vlax-get-acad-object))))
  (vl-catch-all-apply (function (lambda () (vla-put-ConfigName lay "DWG To PDF.pc3"))))
  (vl-catch-all-apply (function (lambda () (vla-put-CanonicalMediaName lay "ISO_full_bleed_A4_(297.00_x_210.00_MM)"))))
  (vl-catch-all-apply (function (lambda () (vla-put-StyleSheet lay "monochrome.ctb"))))
  (vl-catch-all-apply (function (lambda () (vla-put-PlotWithPlotStyles lay :vlax-true))))
  (vl-catch-all-apply (function (lambda () (vla-put-PlotRotation lay 0))))
  (setvar "TILEMODE" 0) (command "_.PSPACE") (command "_.ERASE" "_ALL" "")
  ;; SHOW THE WHOLE A4 IN PAPER SPACE BEFORE THE VIEWPORT IS MADE.  This one line is the
  ;; difference between a layout that frames its sheet and one that comes out blank.
  ;; A viewport that falls outside the current paper-space view is flagged "on but FULLY OFF
  ;; SCREEN" (group 68 = -1), and MSPACE will not step into an off-screen viewport -- so the
  ;; ZOOM meant for the sheet lands on paper space instead and blows the A4 up to model
  ;; coordinates, leaving a tab that opens empty.  Measured: with the paper view left wherever
  ;; the previous layout happened to leave it, group 68 stayed -1 through four REGENALLs and
  ;; the sheets alternated between framed and blank for no reason to do with their contents.
  ;; Zoom the page into view first and group 68 becomes 2 on every sheet.
  (vl-catch-all-apply (function (lambda ()
    (command "_.ZOOM" "_W" (list 0.0 0.0) (list paperW paperH)))))
  (vl-catch-all-apply (function (lambda ()
    (command "_.-LAYER" "_Make" "PEB-VPORT" "_Plot" "_No" "PEB-VPORT" ""))))
  (command "_.MVIEW" (list 0.0 0.0) (list paperW paperH))
  ;; Rule 4B.28 applies here too, and for the same reason: the viewport has to be on screen
  ;; before MSPACE will step into it.  The cover survived the old MSPACE+ZOOM only because it
  ;; is drawn first, when its viewport happens to be the current one -- luck, not design.
  (setq vp  (vlax-ename->vla-object (entlast))
        vpe (vlax-vla-object->ename vp))
  (if (peb-vp-enter vp vpe)
    (peb-vp-put vp "Zoom Window" (function (lambda () (command "_.ZOOM" "_W" bmin bmax))))
    (princ (strcat "
PEB-VP: view left unset for " lname)))
  (peb-vp-put vp "PSpace"        (function (lambda () (command "_.PSPACE"))))
  (peb-vp-put vp "DisplayLocked" (function (lambda () (vla-put-DisplayLocked vp :vlax-true))))
  (vl-catch-all-apply (function (lambda ()
    (command "_.ZOOM" "_W" (list 0.0 0.0) (list paperW paperH)))))
  (setvar "TILEMODE" 1) (setvar "CTAB" "Model")
  (princ))

;; ── RULE 4B.28, GUARD: NO SECOND VIEWPORT ON A SHEET ─────────────────────────────
;; A layout is entitled to a default viewport of its own, created when the layout is first
;; initialised -- which is not always before the ERASE in peb-add-layout runs.  If one ever
;; survives, the tab holds two real viewports: ours framing the sheet, and a leftover at
;; zoom-extents on the whole tiled model, drawn over it.
;;
;; This is a GUARD, not the fix for the 28-Aug fault: measured on B-01, no stray was
;; actually present -- the second viewport in each layout was the paperspace pseudo-viewport
;; (group 69 = 1), which is not a real viewport and must stay.  It costs nothing to run and
;; it forecloses a failure that would look exactly like the one just fixed.
;;
;; Ours is the only viewport on layer PEB-VPORT (both layout builders create it there so its
;; border never plots), which makes "not ours" a fact read off the entity rather than a guess
;; from size or position.  Runs at the END, once every layout exists.
;; Collect first, delete after: deleting inside a vlax-for skips entries.
(defun peb-purge-stray-viewports ( / doc dead n)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) n 0)
  (vlax-for lay (vla-get-Layouts doc)
    (if (/= (strcase (vla-get-Name lay)) "MODEL")
      (progn
        (setq dead nil)
        (vl-catch-all-apply (function (lambda ()
          (vlax-for o (vla-get-Block lay)
            (if (and (= (vla-get-ObjectName o) "AcDbViewport")
                     (/= 1 (cdr (assoc 69 (entget (vlax-vla-object->ename o)))))
                     (/= (strcase (vla-get-Layer o)) "PEB-VPORT"))
              (setq dead (cons o dead)))))))
        (foreach o dead
          (if (not (vl-catch-all-error-p (vl-catch-all-apply (function (lambda () (vla-Delete o))))))
            (setq n (1+ n)))))))
  (princ (strcat "
PEB-VP: swept " (itoa n) " stray viewport(s)"))
  (princ))

;; Frame the COVER (drawn since `mk`) on a bare full-page A4 tab.
(defun peb-frame-cover (mk tabName / ss bb)
  (setq ss (peb-ents-after mk) bb (peb-ss-bbox ss))
  (if bb (peb-add-plain-layout tabName (car bb) (cadr bb)))
  (princ))

;; ============================================================================
;; COMPONENT OVERLAY PASS (owner 6-Jul) — draws the IF components onto the Column
;; Layout Plan AFTER the frame/columns/placements.  Each drawer is self-contained
;; (add a component = one new defun + one line in peb-draw-components).  Owner
;; rule: minimal footprint (outer steel outline + FALL arrow + coverage dims +
;; label); columns ONLY where the component really has columns.
;; Building axes in plan: NSW=bottom(y=0) FSW=top(y=wid) LEW=left(x=0) REW=right(x=len).
;; ============================================================================

;; ensure a component layer exists (batch-safe entmake — no command-line prompts)
(defun peb-comp-layer (name col)
  (if (not (tblsearch "LAYER" name))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 name) (cons 70 0) (cons 62 col))))
  (setvar "CLAYER" name)
  (princ))

;; Light diagonal HATCH for the mezzanine deck (owner 12-Jul: hatch it like Mammut 33 Option-2, but
;; "very attractive, light, beautiful").  Real HATCH entities fail under acad /b, so this fills the
;; rectangle with thin 45-degree LINES on a light-grey layer, drawn BEHIND the framing.  `spacing` is
;; the perpendicular gap between lines; larger = lighter.  A 45-deg line is y = x + c; c = y-x runs from
;; the bottom-right corner (y0-x1) to the top-left (y1-x0), stepped by spacing*sqrt(2).
(defun peb-mezz-hatch (x0 y0 x1 y1 spacing / c cmax step xa xb)
  (if (or (null spacing) (<= spacing 0.0)) (setq spacing 1600.0))
  (peb-comp-layer "COMP-MEZZ-HATCH" 9)                 ; LIGHT grey — a soft background, lighter than
                                                       ; the joists (8) so the framing stays clearest
  (setq step (* spacing 1.41421356)
        c    (+ (- y0 x1) step)
        cmax (- y1 x0))
  (while (< c cmax)
    (setq xa (max x0 (- y0 c)) xb (min x1 (- y1 c)))
    (if (< (+ xa 1.0) xb)
      (entmake (list (cons 0 "LINE") (cons 8 "COMP-MEZZ-HATCH") (cons 370 5)   ; 0.05 mm — fine
                     (list 10 xa (+ xa c) 0.0) (list 11 xb (+ xb c) 0.0))))
    (setq c (+ c step)))
  (princ))

;; A framing member in plan drawn as a STEEL I-SECTION in top view (owner 12-Jul: "draw as real steel
;; profiles"): the two FLANGE edges offset +/- half from the centre-line PLUS a WEB centre-line, so it
;; reads as an I (flange | web | flange) rather than a plain double line.  Drawn on the CURRENT layer,
;; so COLOUR + LINEWEIGHT come BYLAYER (beam 0.50/blue, joist 0.25/grey, sec-joist 0.13/grey — set the
;; layer before calling).  Horizontal member when y0==y1, else vertical.
(defun peb-mezz-mainbeam (x0 y0 x1 y1 half / lay)
  (setq lay (getvar "CLAYER"))
  (if (< (abs (- y0 y1)) 1.0)
    (progn
      (entmake (list (cons 0 "LINE") (cons 8 lay) (list 10 x0 (- y0 half) 0.0) (list 11 x1 (- y0 half) 0.0)))   ; flange
      (entmake (list (cons 0 "LINE") (cons 8 lay) (list 10 x0 (+ y0 half) 0.0) (list 11 x1 (+ y0 half) 0.0)))   ; flange
      (entmake (list (cons 0 "LINE") (cons 8 lay) (list 10 x0 y0 0.0) (list 11 x1 y0 0.0))))                    ; web c/l
    (progn
      (entmake (list (cons 0 "LINE") (cons 8 lay) (list 10 (- x0 half) y0 0.0) (list 11 (- x0 half) y1 0.0)))   ; flange
      (entmake (list (cons 0 "LINE") (cons 8 lay) (list 10 (+ x0 half) y0 0.0) (list 11 (+ x0 half) y1 0.0)))   ; flange
      (entmake (list (cons 0 "LINE") (cons 8 lay) (list 10 x0 y0 0.0) (list 11 x0 y1 0.0)))))                   ; web c/l
  (princ))

;; closed polyline outline on the current layer (pts = list of (x y))
(defun peb-comp-poly (pts / e)
  (setq e (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 (getvar "CLAYER"))
                (cons 100 "AcDbPolyline") (cons 90 (length pts)) (cons 70 1)))
  (foreach p pts (setq e (append e (list (list 10 (car p) (cadr p))))))
  (entmake e))

;; closed polyline with an explicit linetype + entity linetype scale.  Used for the mezzanine boundary:
;; owner 11-Jul confirmed a DASHED demarcation line (NOT a hatch — hatch is unsafe under acad /b and
;; would bury the columns the CLP exists to show).  lts scales the dashes against the global LTSCALE.
(defun peb-comp-poly-lt (pts lt lts / e)
  (setq e (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 (getvar "CLAYER"))
                (cons 6 lt) (cons 48 lts) (cons 100 "AcDbPolyline") (cons 90 (length pts)) (cons 70 1)))
  (foreach p pts (setq e (append e (list (list 10 (car p) (cadr p))))))
  (entmake e))

;; a FALL/slope arrow CENTRED at (cx cy) along unit normal (nx ny), with "FALL"
;; text set to the perpendicular SIDE so both stay inside the component strip.
;; u = strip-scaled size unit (NOT the building unit) so it never protrudes.
(defun peb-comp-fall (cx cy nx ny u / x0 y0 x1 y1 ang hl a1 a2 px py)
  (setvar "CLAYER" "TEXT")
  (setq x0 (- cx (* nx u 0.9)) y0 (- cy (* ny u 0.9))
        x1 (+ cx (* nx u 0.9)) y1 (+ cy (* ny u 0.9))
        ang (atan ny nx) hl (* u 0.5) px (- ny) py nx)   ; (px py) = perpendicular to the arrow
  (entmake (list (cons 0 "LINE") (cons 8 "TEXT") (list 10 x0 y0 0.0) (list 11 x1 y1 0.0)))
  (setq a1 (list (- x1 (* hl (cos (- ang 0.35)))) (- y1 (* hl (sin (- ang 0.35)))))
        a2 (list (- x1 (* hl (cos (+ ang 0.35)))) (- y1 (* hl (sin (+ ang 0.35))))))
  (entmake (list (cons 0 "SOLID") (cons 8 "TEXT") (list 10 (car a1) (cadr a1) 0.0)
                 (list 11 (car a2) (cadr a2) 0.0) (list 12 x1 y1 0.0) (list 13 x1 y1 0.0)))
  (txt-bold "MC" (list (+ cx (* px u 1.15)) (+ cy (* py u 1.15)))
            (/ (* u 0.5) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))   ; txt-bold re-applies the scale; divide it out
            (if (equal nx 0.0 0.001) 0.0 90.0) "FALL")   ; text reads along the strip
  (princ))

;; dispatch — called from C:PEB-PLAN after the frame is drawn (len/wid = drawn plan size)
(defun peb-draw-components (data len wid)
  (setq *PEB-MEZZ-FOOTS* nil)                 ; reset; peb-draw-mezzanine republishes it per plan
  (vl-catch-all-apply (function (lambda () (peb-draw-canopy data len wid))))
  ;; NOTE (owner 6-Jul): roof ACCESSORIES (skylights/vents/openings) belong on the ROOF PLAN, NOT the
  ;; Column Layout Plan — peb-draw-roof-accessories is called by the Roof Plan engine, not here.
  ;; MEZZANINE before STAIRS (owner 14-Jul): a stair's ST_IN_MEZZ can only anchor to its mezzanine once
  ;; the mezzanine footprint exists.  peb-draw-mezzanine publishes *PEB-MEZZ-FOOTS*; peb-draw-stairs reads it.
  (vl-catch-all-apply (function (lambda () (peb-draw-mezzanine data len wid))))
  (vl-catch-all-apply (function (lambda () (peb-draw-stairs data len wid))))
  (vl-catch-all-apply (function (lambda () (peb-draw-roof-ext data len wid))))
  (vl-catch-all-apply (function (lambda () (peb-draw-fascia data len wid))))
  ;; owner 21-Jul: the ROOF MONITOR is NOT shown on the Column Layout Plan — it belongs on the ROOF PLAN
  ;; (to be built later), like the other roof accessories.  Disabled here (drawer kept for the Roof Plan).
  ;; (vl-catch-all-apply (function (lambda () (peb-draw-monitor data len wid))))
  (vl-catch-all-apply (function (lambda () (peb-draw-partition data len wid))))
  (vl-catch-all-apply (function (lambda () (peb-draw-crane data len wid))))
  ;; future drawers appended here: mezzanine / crane / roof-ext / fascia / monitor / platform / catwalk / partition ...
  (setvar "CLAYER" "0")
  (princ))

;; ---- CANOPY (attached, per wall CN_<W>_*) — owner: outer steel outline + slope/
;;      FALL sign + coverage dims; NO columns at the free (cantilever) edge. ----
;; Width grid stations from the width modules (mirror of peb-mzfp-bays for the WIDTH axis) — used to place
;; an endwall component between width grid letters. Clear span (no modules) → (0 wid) = grids A..B.
(defun peb-comp-width-pts (data wid / nm pts cum i sp rem)
  (setq nm (MSPL-Get-Int data "NUMMODULES")) (if (or (null nm) (< nm 1)) (setq nm 1))
  (setq pts (list 0.0) cum 0.0 i 0)
  (while (< i nm)
    (setq sp (MSPL-Get-Num data (strcat "MODULE" (itoa (1+ i)))) rem (- wid cum))
    (cond ((= i (1- nm)) (setq sp rem)) ((and sp (> sp 0.0) (< sp rem)) T) (T (setq sp (/ rem (float (- nm i))))))
    (setq cum (+ cum sp) pts (append pts (list cum)) i (1+ i)))
  pts)

(defun peb-draw-canopy (data len wid / u proj alen bayPts wPts horiz stn gf gt ga0 ga1)
  (if (= (strcase (MSPL-Get-Str data "CN_TOGGLE")) "YES")
    (progn
      (setq u (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
      (setq bayPts (peb-mzfp-bays data len) wPts (peb-comp-width-pts data wid))
      (foreach w (list "NSW" "FSW" "LEW" "REW")
        (if (= (strcase (MSPL-Get-Str data (strcat "CN_" w "_TOGGLE"))) "YES")
          (progn
            (setq proj (MSPL-Get-Num data (strcat "CN_" w "_WIDTH")))   ; projection from wall
            (setq alen (MSPL-Get-Num data (strcat "CN_" w "_LEN")))     ; length along wall (0 = full)
            (if (or (null proj) (<= proj 0.0)) (setq proj 1500.0))      ; std 1500 mm
            ;; Grid-line placement (owner 11-Jul): position along the wall from CN_<w>_GRID_FROM/TO into the
            ;; grid stations — bay points on a sidewall, width points on an endwall. nil -> full/centered.
            (setq horiz (or (= w "NSW") (= w "FSW")) stn (if horiz bayPts wPts)
                  gf (MSPL-Get-Int data (strcat "CN_" w "_GRID_FROM"))
                  gt (MSPL-Get-Int data (strcat "CN_" w "_GRID_TO")))
            (if (and gf gt (> gf 0) (> gt gf) stn (<= gt (length stn)))
              (setq ga0 (nth (1- gf) stn) ga1 (nth (1- gt) stn))
              (setq ga0 nil ga1 nil))
            (vl-catch-all-apply (function (lambda () (peb-comp-canopy-one w proj alen len wid u ga0 ga1)))))))))
  (princ))

;; one canopy on wall w: outline extruded from the wall by proj, along the wall by
;; alen (default full), + outward FALL arrow + projection & coverage-length dims + label.
(defun peb-comp-canopy-one (w proj alen len wid u ga0 ga1 / wl a0 a1 bx by ex ey nx ny mcx mcy lx ly horiz su full)
  (setq horiz (member w '("NSW" "FSW")) wl (if horiz len wid))
  ;; Placement along the wall: grid range (owner 11-Jul) if given, else a partial coverage is centred, else full.
  (cond
    ((and ga0 ga1 (> ga1 ga0)) (setq a0 ga0 a1 ga1))
    ((or (null alen) (<= alen 0.0) (>= alen wl)) (setq a0 0.0 a1 wl))
    (T (setq a0 (/ (- wl alen) 2.0) a1 (+ a0 alen))))
  (setq full (and (< a0 1.0) (> a1 (- wl 1.0))))
  (cond
    ((= w "NSW") (setq bx a0 by 0.0 ex a1 ey 0.0  nx 0.0 ny -1.0))
    ((= w "FSW") (setq bx a0 by wid ex a1 ey wid  nx 0.0 ny 1.0))
    ((= w "LEW") (setq bx 0.0 by a0 ex 0.0 ey a1  nx -1.0 ny 0.0))
    ((= w "REW") (setq bx len by a0 ex len ey a1  nx 1.0 ny 0.0)))
  (setq mcx (+ (/ (+ bx ex) 2.0) (* nx proj 0.5)) mcy (+ (/ (+ by ey) 2.0) (* ny proj 0.5))
        su (max 300.0 (min u (* (abs proj) 0.30))))        ; annotation size scaled to the STRIP depth
  (peb-comp-layer "COMP-CANOPY" 3)                        ; green
  ;; owner 11-Jul: on the CLP a canopy is shown LIGHT — just the outer DOTTED outline + the name.
  ;; No FALL arrow, no projection/coverage dims (those belong on the canopy's own detail, not the
  ;; column layout plan, which is about columns).
  (peb-comp-poly-lt (list (list bx by) (list ex ey)
                          (list (+ ex (* nx proj)) (+ ey (* ny proj)))
                          (list (+ bx (* nx proj)) (+ by (* ny proj)))) "DOT" 1.0)
  (setvar "CLAYER" "COMP-CANOPY")
  ;; label centred along the wall, held at 0.72 (measured 513 mm overlap at 0.50 on 10-Jul against the
  ;; CLP's own "CROSS BRACING (TYP.)" / "RAFTER" / "<wall> - ... WALL" text).
  (setq lx (if horiz (+ bx (* (- ex bx) 0.72)) mcx)
        ly (if horiz mcy (+ by (* (- ey by) 0.72))))
  (txt-bold "MC" (list lx ly) (/ su (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) (if horiz 0.0 90.0) "CANOPY")
  (princ))


;; ---- component drawer: peb-draw-roof-ext (merged from comp_roofext.lsp) ----
;; ============================================================================
;; ROOF EXTENSION / OVERHANG drawer (per wall RX_<W>_*)  — Column Layout Plan
;; ----------------------------------------------------------------------------
;; A roof extension is a roof-plane cantilever beyond a wall: same slope/plane as
;; the main roof (unlike a canopy which falls to its own free edge), so the plan
;; footprint is the outline projected past the wall by WIDTH, along the wall by
;; LEN (0 = full wall).  Owner rule: outer steel outline + projection dim
;; (+ coverage dim if partial) + label; NO fall arrow (same roof plane) — the
;; eave condition is annotated instead.
;; Building axes in plan: NSW=bottom(y=0) FSW=top(y=wid) LEW=left(x=0) REW=right(x=len).
;; Reuses shared helpers: peb-comp-layer, peb-comp-poly, txt-bold,
;; peb-dim-h-stretch, peb-dim-height-stretch, peb-comma, MSPL-Get-Str/Num.
;; Self-contained + catch-wrapped; safe defaults; draws only on RX_TOGGLE = Yes.
;; ============================================================================

;; dispatch — mirror of peb-draw-canopy: iterate the four walls, draw each
;; toggled-on roof extension.  proj = RX_<W>_WIDTH (projection from the wall);
;; alen = RX_<W>_LEN (coverage along the wall, 0/blank = full).
(defun peb-draw-roof-ext (data len wid / u proj alen eave bayPts wPts horiz stn gf gt ga0 ga1)
  (if (= (strcase (MSPL-Get-Str data "RX_TOGGLE")) "YES")
    (progn
      (setq u (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
      (setq bayPts (peb-mzfp-bays data len) wPts (peb-comp-width-pts data wid))
      (foreach w (list "NSW" "FSW" "LEW" "REW")
        (if (= (strcase (MSPL-Get-Str data (strcat "RX_" w "_TOGGLE"))) "YES")
          (progn
            (setq proj (MSPL-Get-Num data (strcat "RX_" w "_WIDTH")))   ; projection from wall
            (setq alen (MSPL-Get-Num data (strcat "RX_" w "_LEN")))     ; length along wall (0 = full)
            (setq eave (MSPL-Get-Str data (strcat "RX_" w "_EAVE")))    ; eave-edge condition
            (if (or (null proj) (<= proj 0.0)) (setq proj 1000.0))      ; std overhang 1000 mm
            ;; Grid-line placement (owner 11-Jul): RX_<w>_GRID_FROM/TO → grid stations (bays / width pts).
            (setq horiz (or (= w "NSW") (= w "FSW")) stn (if horiz bayPts wPts)
                  gf (MSPL-Get-Int data (strcat "RX_" w "_GRID_FROM"))
                  gt (MSPL-Get-Int data (strcat "RX_" w "_GRID_TO")))
            (if (and gf gt (> gf 0) (> gt gf) stn (<= gt (length stn)))
              (setq ga0 (nth (1- gf) stn) ga1 (nth (1- gt) stn))
              (setq ga0 nil ga1 nil))
            (vl-catch-all-apply
              (function (lambda () (peb-comp-roof-ext-one w proj alen eave len wid u ga0 ga1)))))))))
  (princ))

;; one roof extension on wall w: outline extruded from the wall by proj, along the
;; wall by alen (default full), + projection & coverage-length dims + label +
;; eave-condition note.  Same NSW/FSW/LEW/REW geometry + horiz/dims logic as
;; peb-comp-canopy-one, minus the FALL arrow (roof extension shares the roof plane).
(defun peb-comp-roof-ext-one (w proj alen eave len wid u ga0 ga1 / wl a0 a1 bx by ex ey nx ny mcx mcy horiz su full)
  (setq horiz (member w '("NSW" "FSW")) wl (if horiz len wid))
  ;; Placement along the wall: grid range (owner 11-Jul) if given, else centred partial, else full.
  (cond
    ((and ga0 ga1 (> ga1 ga0)) (setq a0 ga0 a1 ga1))
    ((or (null alen) (<= alen 0.0) (>= alen wl)) (setq a0 0.0 a1 wl))
    (T (setq a0 (/ (- wl alen) 2.0) a1 (+ a0 alen))))
  (setq full (and (< a0 1.0) (> a1 (- wl 1.0))))
  (cond
    ((= w "NSW") (setq bx a0 by 0.0 ex a1 ey 0.0  nx 0.0 ny -1.0))
    ((= w "FSW") (setq bx a0 by wid ex a1 ey wid  nx 0.0 ny 1.0))
    ((= w "LEW") (setq bx 0.0 by a0 ex 0.0 ey a1  nx -1.0 ny 0.0))
    ((= w "REW") (setq bx len by a0 ex len ey a1  nx 1.0 ny 0.0)))
  (setq mcx (+ (/ (+ bx ex) 2.0) (* nx proj 0.5)) mcy (+ (/ (+ by ey) 2.0) (* ny proj 0.5))
        su (max 300.0 (min u (* (abs proj) 0.30))))        ; annotation size scaled to the STRIP depth
  (peb-comp-layer "COMP-ROOF-EXT" 5)                       ; blue
  ;; owner 11-Jul: on the CLP a roof extension is shown LIGHT — just the outer DOTTED outline + the
  ;; name.  No EAVE note, no projection/coverage dims (they belong on the roof plan / detail).
  (peb-comp-poly-lt (list (list bx by) (list ex ey)
                          (list (+ ex (* nx proj)) (+ ey (* ny proj)))
                          (list (+ bx (* nx proj)) (+ by (* ny proj)))) "DOT" 1.0)
  (setvar "CLAYER" "COMP-ROOF-EXT")
  ;; centre label (reads along the strip)
  (txt-bold "MC" (list mcx mcy) (/ su (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) (if horiz 0.0 90.0) "ROOF EXTENSION")
  (princ))

;; ---- component drawer: peb-draw-fascia (merged from comp_fascia.lsp) ----
;; ============================================================================
;; FASCIA / PARAPET component drawer (per wall FA_<W>_*)  — own file, self-contained.
;; Mirrors the CANOPY drawer pattern (peb-draw-canopy / peb-comp-canopy-one).
;; Plan axes: NSW=bottom(y=0) FSW=top(y=wid) LEW=left(x=0) REW=right(x=len).
;; Raw mm everywhere; only txt-bold divides its height by *PEB-TEXT-SCALE*.
;; Draws a THIN perimeter BAND just OUTBOARD of each toggled wall (full length or
;; FA_<W>_LEN), projecting OUT by FA_<W>_PROJ (default 600 mm). No columns.
;; Layer "COMP-FASCIA" colour 2 (yellow).
;; ============================================================================

(defun peb-draw-fascia (data len wid / u proj alen)
  (if (= (strcase (MSPL-Get-Str data "FA_TOGGLE")) "YES")
    (progn
      ;; annotation base unit (same clamp as canopy); su clamps this down per strip
      (setq u (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
      (foreach w (list "NSW" "FSW" "LEW" "REW")
        (if (= (strcase (MSPL-Get-Str data (strcat "FA_" w "_TOGGLE"))) "YES")
          (progn
            (setq proj (MSPL-Get-Num data (strcat "FA_" w "_PROJ")))   ; projection out from wall
            (setq alen (MSPL-Get-Num data (strcat "FA_" w "_LEN")))    ; length along wall (0/blank = full)
            (if (or (null proj) (<= proj 0.0)) (setq proj 600.0))      ; fascia/parapet std ~600 mm
            (vl-catch-all-apply
              (function (lambda ()
                (peb-comp-fascia-one w proj alen len wid u
                  (MSPL-Get-Str data (strcat "FA_" w "_TYPE")))))))))))
  (setvar "CLAYER" "0")
  (princ))

;; one fascia/parapet band on wall w: outboard strip extruded from the wall by proj,
;; along the wall by alen (default full) + centred TYPE label + projection dim.
(defun peb-comp-fascia-one (w proj alen len wid u typ / wl a0 a1 bx by ex ey nx ny mcx mcy horiz su full lbl)
  (setq horiz (member w '("NSW" "FSW")) wl (if horiz len wid)
        full (or (null alen) (<= alen 0.0) (>= alen wl)))
  (if full (setq a0 0.0 a1 wl) (setq a0 (/ (- wl alen) 2.0) a1 (+ a0 alen)))
  (cond
    ((= w "NSW") (setq bx a0 by 0.0 ex a1 ey 0.0  nx 0.0 ny -1.0))
    ((= w "FSW") (setq bx a0 by wid ex a1 ey wid  nx 0.0 ny 1.0))
    ((= w "LEW") (setq bx 0.0 by a0 ex 0.0 ey a1  nx -1.0 ny 0.0))
    ((= w "REW") (setq bx len by a0 ex len ey a1  nx 1.0 ny 0.0)))
  (setq mcx (+ (/ (+ bx ex) 2.0) (* nx proj 0.5)) mcy (+ (/ (+ by ey) 2.0) (* ny proj 0.5))
        ;; PROJ is small (~600): keep text legible but never protruding past the band
        su (max 150.0 (min u (* (abs proj) 0.5))))
  ;; label: "PARAPET" when the type reads as a parapet, else "FASCIA - <TYPE>"
  (if (or (null typ) (= typ "")) (setq typ "PARAPET"))
  (setq lbl (if (wcmatch (strcase typ) "*PARAPET*")
              (strcase typ)
              (strcat "FASCIA - " (strcase typ))))
  (peb-comp-layer "COMP-FASCIA" 2)                       ; yellow
  ;; thin outboard band running ALONG the wall, projecting OUT by proj
  (peb-comp-poly (list (list bx by) (list ex ey)
                       (list (+ ex (* nx proj)) (+ ey (* ny proj)))
                       (list (+ bx (* nx proj)) (+ by (* ny proj)))))
  (setvar "CLAYER" "COMP-FASCIA")
  ;; centred TYPE label — reads along the wall (horizontal walls) or up it (end walls)
  (txt-bold "MC" (list mcx mcy)
            (/ su (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
            (if horiz 0.0 90.0) lbl)
  ;; projection dim ALWAYS; coverage dim only when PARTIAL (full-length is already the
  ;; building length/width dim, so re-drawing it just collides with the wall labels).
  (if horiz
    (progn   ; wall along X: projection dim = vertical, coverage dim = horizontal
      (vl-catch-all-apply (function (lambda () (peb-dim-height-stretch bx (- bx (* su 1.6)) by (+ by (* ny proj)) (peb-comma (rtos proj 2 0))))))
      (if (not full) (vl-catch-all-apply (function (lambda () (peb-dim-h-stretch bx ex (+ by (* ny (+ proj (* su 1.6)))) (peb-comma (rtos (abs (- ex bx)) 2 0))))))))
    (progn   ; wall along Y: projection dim = horizontal, coverage dim = vertical
      (vl-catch-all-apply (function (lambda () (peb-dim-h-stretch bx (+ bx (* nx proj)) (- by (* su 1.6)) (peb-comma (rtos proj 2 0))))))
      (if (not full) (vl-catch-all-apply (function (lambda () (peb-dim-height-stretch bx (+ bx (* nx (+ proj (* su 1.6)))) by ey (peb-comma (rtos (abs (- ey by)) 2 0)))))))))
  (princ))

;; ---- component drawer: peb-draw-monitor (merged from comp_monitor.lsp) ----
;; ============================================================================
;; ROOF MONITOR — Column Layout Plan component drawer (single, along the ridge)
;; Building axes in plan: NSW=bottom(y=0) FSW=top(y=wid) LEW=left(x=0) REW=right(x=len).
;; Ridge runs along the LENGTH at mid-width (y = wid/2).  All coords RAW mm; only
;; txt-bold divides by *PEB-TEXT-SCALE*.  Layer "COMP-MONITOR" colour 4 (cyan).
;; Draws: raised strip outline (rectangle centred on ridge, total width
;; RM_OVERALL_WIDTH, running RM_LENGTH along the length, default full & centred),
;; a centre ridge line, a "ROOF MONITOR" label, a width dim, and a length dim if
;; the monitor is partial.  NO columns.
;; ============================================================================
(defun peb-draw-monitor (data len wid
                         / u ridge ow throat rmlen half x0 x1 yTop yBot mcx su lay lyr bayPts gf gt)
  (if (= (strcase (MSPL-Get-Str data "RM_TOGGLE")) "YES")
    (progn
      ;; ---- size unit (same formula the other drawers use) ----------------
      (setq u (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
      ;; ---- read IF keys with safe defaults (all raw mm) ------------------
      (setq ow    (MSPL-Get-Num data "RM_OVERALL_WIDTH"))   ; total strip width across the ridge
      (setq rmlen (MSPL-Get-Num data "RM_LENGTH"))          ; length along the ridge (0/blank = full)
      (if (or (null ow) (<= ow 0.0)) (setq ow 3000.0))      ; Mammut-ish default 3.0 m
      (setq throat (MSPL-Get-Num data "RM_THROAT_WIDTH"))   ; vent opening (SAME O.W. the section reads)
      (if (or (null throat) (<= throat 0.0)) (setq throat (* ow 0.5)))
      ;; ---- geometry ------------------------------------------------------
      ;; ridge station via peb-ridge-y (honours BP_RIDGE_OFFSET) so the plan monitor lands on the
      ;; SAME ridge the SECTION uses (peb-ridge-x) — no section/plan disagreement (owner 19-Jul).
      (setq ridge (peb-ridge-y data wid)                   ; single ridge (offset-aware)
            half  (/ ow 2.0)
            yTop  (+ ridge half)
            yBot  (- ridge half))
      ;; length span — grid range (owner 11-Jul: RM_GRID_FROM/TO into the bay grid) if set, else centred
      ;; if partial, else full LEW->REW.
      (setq bayPts (peb-mzfp-bays data len)
            gf (MSPL-Get-Int data "RM_GRID_FROM") gt (MSPL-Get-Int data "RM_GRID_TO"))
      (cond
        ((and gf gt (> gf 0) (> gt gf) bayPts (<= gt (length bayPts)))
         (setq x0 (nth (1- gf) bayPts) x1 (nth (1- gt) bayPts)))
        ((or (null rmlen) (<= rmlen 0.0) (>= rmlen len)) (setq x0 0.0 x1 len))
        (T (setq x0 (/ (- len rmlen) 2.0) x1 (+ x0 rmlen))))
      (setq mcx (/ (+ x0 x1) 2.0)
            su  (max 300.0 (min u (* ow 0.30))))            ; annotation size scaled to the strip depth
      ;; ---- layer ---------------------------------------------------------
      (setq lay "COMP-MONITOR")
      (if (not (tblsearch "LAYER" lay))
        (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                       (cons 100 "AcDbLayerTableRecord") (cons 2 lay)
                       (cons 70 0) (cons 62 4))))           ; colour 4 = cyan
      (setvar "CLAYER" lay)
      (setq lyr (getvar "CLAYER"))
      ;; ---- strip outline (rectangle = two ridge-parallel lines + end caps) ----
      (entmake (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 lyr)
                     (cons 100 "AcDbPolyline") (cons 90 4) (cons 70 1)
                     (list 10 x0 yBot) (list 10 x1 yBot)
                     (list 10 x1 yTop) (list 10 x0 yTop)))
      ;; ---- centre ridge line ---------------------------------------------
      (entmake (list (cons 0 "LINE") (cons 8 lyr)
                     (list 10 x0 ridge 0.0) (list 11 x1 ridge 0.0)))
      ;; ---- THROAT opening (vent slot) — two lines at ridge ± throat/2, so the PLAN reads the SAME
      ;;      O.W. opening the SECTION shows between the legs (plan/section agreement, owner 19-Jul).
      (entmake (list (cons 0 "LINE") (cons 8 lyr)
                     (list 10 x0 (- ridge (/ throat 2.0)) 0.0) (list 11 x1 (- ridge (/ throat 2.0)) 0.0)))
      (entmake (list (cons 0 "LINE") (cons 8 lyr)
                     (list 10 x0 (+ ridge (/ throat 2.0)) 0.0) (list 11 x1 (+ ridge (/ throat 2.0)) 0.0)))
      ;; ---- label suppressed (owner 8-Jul) --------------------------------
      ;; Real Maimaar/Mammut approval drawings show the monitor GEOMETRICALLY only —
      ;; no "ROOF MONITOR" text on either the CLP or the Roof Plan (reference-verified).
      ;; The opening band + dims below identify it; no text label is drawn.
      ;; ---- width dim (RM_OVERALL_WIDTH) — vertical, at the left end -------
      (vl-catch-all-apply
        (function (lambda ()
          (peb-dim-height-stretch x0 (- x0 (* su 1.6)) yBot yTop
                                  (peb-comma (rtos ow 2 0))))))
      ;; ---- length dim — horizontal, only if PARTIAL ----------------------
      (if (and rmlen (> rmlen 0.0) (< rmlen len))
        (vl-catch-all-apply
          (function (lambda ()
            (peb-dim-h-stretch x0 x1 (+ yTop (* su 1.6))
                               (peb-comma (rtos (- x1 x0) 2 0)))))))))
  (princ))

;; ---- component drawer: peb-draw-partition (merged from comp_partition.lsp) ----
;; ============================================================================
;; PARTITION (interior wall) drawer  -- PT_TOGGLE + PT<n>_* (n = 1..4)
;; Self-contained; reuses shared helpers only. Owner rule: minimal footprint
;; interior wall LINE, NO columns.  Building axes in plan:
;;   NSW = bottom (y=0)  FSW = top (y=wid)  LEW = left (x=0)  REW = right (x=len)
;;   Longitudinal = along the LENGTH (x), positioned at a WIDTH  (from-NSW) y.
;;   Transverse   = across the WIDTH  (y), positioned at a LENGTH (from-LEW) x.
;;   PT<n>_LENGTH  0/blank => full span; else the wall is that long, centred.
;;   PT<n>_LOCATION (mm) => the offset position; blank => mid-span.
;;   PT<n>_OPEN /= "Fully Sheeted" => label gets " (OPEN)".
;; Dispatch (add to peb-draw-components):
;;   (vl-catch-all-apply (function (lambda () (peb-draw-partition data len wid))))
;; ============================================================================
(defun peb-draw-partition
       (data len wid / u th tw i tag typ plen pos opn lng x0 x1 y0 y1 cx cy)
  (if (= (strcase (MSPL-Get-Str data "PT_TOGGLE")) "YES")
    (progn
      (setq u  (max 400.0 (min 3000.0 (/ (max len wid) 70.0)))   ; annotation unit
            th (max 300.0 (* u 0.45))                            ; desired raw text height
            tw 150.0)                                            ; wall thickness on plan (mm)
      (peb-comp-layer "COMP-PARTITION" 6)                        ; magenta
      (setq i 1)
      (while (<= i 4)
        (setq tag (strcat "PT" (itoa i) "_"))
        (if (= (strcase (MSPL-Get-Str data (strcat tag "TOGGLE"))) "YES")
          (vl-catch-all-apply
            (function
              (lambda ()
                (setq typ  (strcase (MSPL-Get-Str data (strcat tag "TYPE")))
                      plen (MSPL-Get-Num data (strcat tag "LENGTH"))
                      pos  (MSPL-Get-Num data (strcat tag "LOCATION"))
                      opn  (strcase (MSPL-Get-Str data (strcat tag "OPEN"))))
                (peb-comp-layer "COMP-PARTITION" 6)
                (if (wcmatch typ "*TRANSVERSE*")
                  ;; ---- TRANSVERSE : vertical band across the width at x = cx ----
                  (progn
                    (setq lng (if (and plen (> plen 0.0)) (min plen wid) wid)
                          y0  (/ (- wid lng) 2.0)
                          y1  (+ y0 lng)
                          cx  (if (and pos (> pos 0.0) (< pos len)) pos (/ len 2.0)))
                    (peb-comp-poly (list (list (- cx (/ tw 2.0)) y0)
                                         (list (+ cx (/ tw 2.0)) y0)
                                         (list (+ cx (/ tw 2.0)) y1)
                                         (list (- cx (/ tw 2.0)) y1)))
                    (setvar "CLAYER" "COMP-PARTITION")
                    (txt-bold "MC"
                              (list (+ cx (* u 0.8)) (/ (+ y0 y1) 2.0))
                              (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
                              90.0
                              (strcat "PARTITION PT" (itoa i) " (TRANSVERSE)"
                                      (if (and opn (/= opn "FULLY SHEETED") (/= opn "")) " (OPEN)" "")))
                    (vl-catch-all-apply
                      (function (lambda ()
                        (peb-dim-height-stretch cx (- cx (* u 1.6)) y0 y1
                                                (peb-comma (rtos lng 2 0)))))))
                  ;; ---- LONGITUDINAL (default) : horizontal band along len at y = cy ----
                  (progn
                    (setq lng (if (and plen (> plen 0.0)) (min plen len) len)
                          x0  (/ (- len lng) 2.0)
                          x1  (+ x0 lng)
                          cy  (if (and pos (> pos 0.0) (< pos wid)) pos (/ wid 2.0)))
                    (peb-comp-poly (list (list x0 (- cy (/ tw 2.0)))
                                         (list x1 (- cy (/ tw 2.0)))
                                         (list x1 (+ cy (/ tw 2.0)))
                                         (list x0 (+ cy (/ tw 2.0)))))
                    (setvar "CLAYER" "COMP-PARTITION")
                    (txt-bold "MC"
                              (list (/ (+ x0 x1) 2.0) (+ cy (* u 0.8)))
                              (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
                              0.0
                              (strcat "PARTITION PT" (itoa i) " (LONGITUDINAL)"
                                      (if (and opn (/= opn "FULLY SHEETED") (/= opn "")) " (OPEN)" "")))
                    (vl-catch-all-apply
                      (function (lambda ()
                        (peb-dim-h-stretch x0 x1 (- cy (* u 1.6))
                                           (peb-comma (rtos lng 2 0))))))))
                (princ)))))
        (setq i (1+ i)))))
  (setvar "CLAYER" "0")
  (princ))

;; Grid stations across [a,b] from a "N@S+..." spacing expression (mm) — used to place the
;; EXISTING RCC pillars of a client's building under a dropped-in mezzanine.  Blank => the two ends.
(defun peb-mezz-stations (expr a b / lst acc out)
  (setq lst (if (and expr (/= expr "") (boundp 'peb-parse-mod-expression))
              (peb-parse-mod-expression expr) nil))
  (setq out (list a) acc a)
  (if lst
    (progn
      (foreach s lst
        (if (> s 0.0)
          (progn (setq acc (+ acc s)) (if (< acc (- b 1.0)) (setq out (append out (list acc)))))))
      (setq out (append out (list b))))
    (setq out (list a b)))
  out)

;; Existing RCC concrete pillar (top view) — a square outline with an X, visually distinct from the
;; steel I-column, so a mezzanine dropped inside a client's existing RCC building shows BOTH the
;; existing concrete pillars and the new steel mezzanine columns.
(defun peb-draw-rcc-pillar (x y s / h prev)
  (setq h (/ s 2.0) prev (getvar "CLAYER"))
  (setvar "CLAYER" "COMP-RCC")
  (command "_.RECTANG" (list (- x h) (- y h)) (list (+ x h) (+ y h)))
  (command "_.LINE" (list (- x h) (- y h)) (list (+ x h) (+ y h)) "")
  (command "_.LINE" (list (- x h) (+ y h)) (list (+ x h) (- y h)) "")
  (setvar "CLAYER" prev))

;; TRUE when the mezzanine host is an EXISTING RCC building — the plan then draws the existing RCC
;; pillars (via peb-draw-mezzanine) and NO steel building columns.  The two hosts are mutually exclusive.
(defun peb-mz-rcc-p (data)
  (and (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_TOGGLE") "")) "YES")
       (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_RCC")    "")) "YES")))

;; The MEZZANINE FLOOR's placement ACROSS THE WIDTH (owner 10-Jul: "there must be a field in the IF
;; for placement of the mezzanine floor, and it must show on the CLP at the defined location").
;; Length placement already exists (MZ_GRID_BAY_FROM/TO).  Width placement did not: the footprint was
;; ALWAYS the full interior width.  MZ_WIDTH_ANCHOR names the wall it grows from; MZ_WIDTH_EXTENT is
;; how deep it runs (mm).  Blank / "FULL" / no extent => full interior width, i.e. the old behaviour.
;; Returns (b0 b1) clamped inside the wall clearance.
;;
;; owner 11-Jul: the PRIMARY placement is now by GRID LETTER — MZ_WIDTH_GRID_FROM/TO (A,B,C…).  The
;; letters map to *PEB-WGRID-YS* (the width-letter stations the plan stashes at ~3384) with the SAME
;; rule the letter bubbles use (~3609): ascending station index j carries letter chr(65 + (nW-1-j) +
;; *PEB-GRID-LET-OFS*).  So a letter char c inverts to station index j = nW-1-((c-65)-letOfs); A is the
;; top (FSW), letters increase toward the NSW.  Grid letters WIN when both are given; otherwise the
;; MZ_WIDTH_ANCHOR + MZ_WIDTH_EXTENT offset fallback (below) applies, exactly as before.
;; NOTE: the IF letter list skips I (standard grid convention); the engine's bubbles at ~3609 use raw
;; chr and DO include I.  They agree for <9 width lines (I never appears) — the common case.  A building
;; with >=9 width grid lines would drift by one past I; fixing the bubble labelling to skip I is a
;; separate, drawing-wide change (it renumbers existing sheets), tracked for later.
(defun peb-mz-width-band (data wid inset / anc ext b0 b1 gf gt ys nW vf vt y0 y1 letOfs)
  ;; --- PRIMARY: width grid letters ---
  (setq gf (strcase (peb-tb-or (MSPL-Get-Str data "MZ_WIDTH_GRID_FROM") ""))
        gt (strcase (peb-tb-or (MSPL-Get-Str data "MZ_WIDTH_GRID_TO")   ""))
        ys (if (and (boundp '*PEB-WGRID-YS*) *PEB-WGRID-YS*) *PEB-WGRID-YS* nil)
        letOfs (if *PEB-GRID-LET-OFS* *PEB-GRID-LET-OFS* 0))
  (if (and ys (> (length ys) 1)
           (= (strlen gf) 1) (= (strlen gt) 1) (>= (ascii gf) 65) (>= (ascii gt) 65))
    (progn
      (setq nW (length ys)
            vf (- (peb-grid-letter-index gf) letOfs)   ; skip-I aware (matches the bubble letters)
            vt (- (peb-grid-letter-index gt) letOfs)
            y0 (nth (max 0 (min (1- nW) (- nW 1 vf))) ys)
            y1 (nth (max 0 (min (1- nW) (- nW 1 vt))) ys))
      (if (> (abs (- y1 y0)) 1.0)
        (setq b0 (min y0 y1) b1 (max y0 y1)))))     ; grid placement succeeded
  (if b0 (list b0 b1)                               ; PRIMARY won -> done
  (progn
  ;; --- FALLBACK: MZ_WIDTH_ANCHOR + MZ_WIDTH_EXTENT (Advanced offset) ---
  (setq anc (strcase (peb-tb-or (MSPL-Get-Str data "MZ_WIDTH_ANCHOR") ""))
        ext (MSPL-Get-Num data "MZ_WIDTH_EXTENT")
        b0  inset
        b1  (- wid inset))
  ;; The extent is measured FROM THE WALL (y=0 for NSW, y=wid for FSW).  A mezzanine slab ABUTS the
  ;; wall, so the anchored deck runs wall-to-extent and its depth dim then prints the IF's own number.
  ;; (Insetting the wall side drew 11 000 for a 12 m mezzanine — a label that disagrees with the
  ;; geometry, the same class of error as the O/O dim.)  FULL WIDTH keeps the old inset-both-sides
  ;; footprint, and never prints a width dim anyway (dims are drawn only when partial).
  (if (and ext (> ext 0.0) (< ext wid))
    (cond
      ((wcmatch anc "*NSW*,*NEAR*")  (setq b0 0.0 b1 ext))                  ; grows up from NSW (y=0)
      ((wcmatch anc "*FSW*,*FAR*")   (setq b0 (- wid ext) b1 wid))          ; grows down from FSW (y=wid)
      ((wcmatch anc "*CENTR*,*MID*") (setq b0 (- (/ wid 2.0) (/ ext 2.0))   ; centred on the width
                                           b1 (+ b0 ext)))))
  ;; clamp to the building, and never invert
  (setq b0 (max 0.0 b0) b1 (min wid b1))
  (if (>= b0 b1) (setq b0 inset b1 (- wid inset)))     ; nonsense extent -> fall back to full width
  (list b0 b1))))

;; EVERY width station where a MAIN-FRAME column already stands: the two SIDE-WALL column centres
;; (colOff = D/2 and wid-D/2, exactly where botY/topY put them) plus the INTERIOR module lines.
;;
;; owner 10-Jul: "existing columns as-is; NEW columns (up to the mezzanine beam bottom) encircled."
;; A mezzanine stub must NOT be drawn where a building column already stands, or the drawer stacks a
;; second I-section on the existing one AND encircles it, calling an existing column new.
;;   * INTERIOR lines matter on a multi-span, where the mezzanine module can land on one.
;;   * The SIDE-WALL lines matter ALWAYS: the stub grid starts at the wall clearance (inset, 1000),
;;     which is inside half a column depth of the side-wall column centre (550) — measured, 7 stubs
;;     landed on them.  The drawer's own comment already said "the existing PEB frame columns carry
;;     the beam at the walls"; it just never acted on it.
;; Interior lines derive from BP_WIDTH_MOD (MODEXPR), the same expression the plan uses for widthPts.
(defun peb-main-column-ys (data wid / expr spans acc out s colOff)
  (setq colOff (/ (peb-col-web-depth wid) 2.0))
  (setq out (list colOff (- wid colOff)))          ; the two side-wall column lines
  (setq expr (MSPL-Get-Str data "MODEXPR"))
  (if (and expr (/= expr ""))
    (progn
      ;; Rule 4B.34 — MODEXPR is stored verbatim (A downward); reverse it to lay the
      ;; interior column lines out from the NSW.
      (setq spans (peb-width-order (peb-parse-mod-expression expr)) acc 0.0)
      (foreach s spans
        (setq acc (+ acc s))
        (if (and (> acc 1.0) (< acc (- wid 1.0))) (setq out (append out (list acc)))))))
  out)

;; Mezzanine column WIDTH stations — the mezzanine columns are distributed WITHIN each MAIN width
;; module, EQUALLY subdivided BETWEEN the main PEB columns (owner 11-Jul: "the distribution of mezzanine
;; columns is WITHIN, between the columns of the main PEB building"; a 3@10 m module gets 2@5 m mezz
;; columns per module, NOT one spacing walked across the whole width).
;;   1. Main width-module boundaries come from MODEXPR (0, m1, m1+m2, …, wid); a clear span is one
;;      module (0, wid).
;;   2. Each module is split into N EQUAL sub-bays, N chosen so the sub-bay is closest to targetSp (the
;;      representative mezz spacing from MZ_COL_SPACING / the IF load band).  The split points are the
;;      mezzanine column lines.
;;   3. Clip to the footprint [fy0, fy1] and dedupe.
;; The caller's existing-column skip (peb-main-column-ys ± mainTol) then drops the stubs that land on a
;; main column line, leaving the interior subdivisions as the NEW encircled mezzanine columns.
(defun peb-mezz-col-ys (data wid fy0 fy1 targetSp / expr bnds acc out prev b0 b1 n k g y s sp2 sumSp sc2 span)
  (if (or (null targetSp) (<= targetSp 0.0)) (setq targetSp 6000.0))
  (setq span (- fy1 fy0))
  ;; USER-PLACED width module (owner 12-Jul: "the user will place the width module in the IF if they do
  ;; NOT want the width module by auto-division").  If MZ_COL_SPACING is a multi-bay expression summing
  ;; to ~ the mezzanine width (or the building width), WALK it directly across the footprint (scaled to
  ;; close exactly) — the estimator's own grid, no auto-subdivision.
  (setq sp2 (peb-width-order (peb-parse-mod-expression (peb-tb-or (MSPL-Get-Str data "MZ_COL_SPACING") ""))))   ; rule 4B.34 — width chain, written A downward
  (setq sumSp 0.0) (foreach s sp2 (setq sumSp (+ sumSp s)))
  (if (and sp2 (> (length sp2) 1) (> sumSp 0.0)
           (or (< (abs (- sumSp span)) (* 0.12 span))
               (< (abs (- sumSp wid))  (* 0.12 wid))))
    (progn
      (setq sc2 (/ span sumSp) out (list fy0) acc fy0)
      (foreach s sp2 (setq acc (+ acc (* s sc2))) (if (< acc (- fy1 1.0)) (setq out (append out (list acc)))))
      (append out (list fy1)))
    ;; else AUTO-DIVIDE each MAIN width module (the default) — columns between the main PEB columns
    (progn
      (setq expr (MSPL-Get-Str data "MODEXPR") bnds (list 0.0) acc 0.0)
      (if (and expr (/= expr ""))
        (foreach s (peb-width-order (peb-parse-mod-expression expr))   ; rule 4B.34
          (setq acc (+ acc s)) (if (< acc (- wid 1.0)) (setq bnds (append bnds (list acc))))))
      (setq bnds (append bnds (list wid)))
      (setq out '() b0 (car bnds))
      (foreach b1 (cdr bnds)
        (setq g (- b1 b0) n (max 1 (fix (+ 0.5 (/ g targetSp)))) k 0)
        (while (< k n) (setq out (append out (list (+ b0 (* g (/ (float k) (float n))))))) (setq k (1+ k)))
        (setq b0 b1))
      (setq out (append out (list wid)) out (vl-sort out '<) bnds '() prev nil)
      (foreach y out
        (if (and (>= y (- fy0 1.0)) (<= y (+ fy1 1.0)) (or (null prev) (> (- y prev) 1.0)))
          (progn (setq bnds (append bnds (list y))) (setq prev y))))
      bnds)))

;; ---- component drawer: peb-draw-mezzanine (merged from comp_mezzanine.lsp) ----
;; ============================================================================
;; MEZZANINE component drawer  —  Column Layout Plan (TOP VIEW)
;; Owner rule (Ch.11 §11.1-11.2, catalogue §11): a CLEAN FOOTPRINT, not a framing
;; plan.  Draw only: (1) decking OUTLINE rectangle over the footprint, (2) its OWN
;; interior stub-column grid — I-section + 4 anchor bolts, capped with a CIRCLE that
;; marks it a STUB rising only to the mezzanine-beam underside (owner 8-Jul; the
;; older "small filled squares" note was superseded), (3) "MEZZANINE" label +
;; "F.F.L" tag, (4) footprint dims only when PARTIAL.
;;
;; Self-contained: reuses engine helpers (MSPL-Get-*, peb-comp-layer, peb-comp-poly,
;; txt-bold, peb-comma, peb-dim-h-stretch, peb-dim-height-stretch) but every risky
;; call is wrapped in vl-catch-all-apply and every field defaults if missing/zero.
;; Plan axes: NSW=bottom(y=0) FSW=top(y=wid) LEW=left(x=0) REW=right(x=len).  Raw mm.
;; Layer: "COMP-MEZZ" colour 6 (magenta).
;; ============================================================================
(defun peb-draw-mezzanine
  ( data len wid /
    u post inset scale
    spStr spList tmp plus seg atP cnt val k s2 spx
    specs foots n ml mw ff sp cx0 a0 a1 b0 b1
    ft fx0 fx1 fy0 fy1 partial cx cy lcy hlab fflStr fflv
    ys xs acc h hh x y
    numBays bayPts2 sp2 rem2 bx colD savedWeb circR host rcc mzRcc rccXs rccYs
    module rr gap nsub yi yy0 yy1 glF glT glX0 glX1 offF offT
    mzBand mzB0 mzB1 mzPart mainYs mainTol sy0 sy1 dimX yprev yy
    mzNums mzk )

  (if (/= (strcase (MSPL-Get-Str data "MZ_TOGGLE")) "YES")
    (princ)                                    ; not requested — do nothing
    (progn
      (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
      (setq scale *PEB-TEXT-SCALE*)
      (if (or (null len) (<= len 0.0)) (setq len 30000.0))
      (if (or (null wid) (<= wid 0.0)) (setq wid 20000.0))

      ;; strip / feature units (same law as the canopy drawer)
      (setq u    (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
      (setq post (max 200.0 (min 450.0 (/ (max len wid) 150.0))))   ; stub-post square side
      (setq inset (max 300.0 (min 1000.0 (* (min len wid) 0.10))))   ; wall clearance

      ;; --- parse MZ_COL_SPACING ("4@6000" / "1@7150+5@8500") into a spacing list ---
      (setq spStr (MSPL-Get-Str data "MZ_COL_SPACING") spList '())
      (vl-catch-all-apply
        (function (lambda ()
          (setq tmp spStr)
          (while (and tmp (> (strlen tmp) 0))
            (setq plus (vl-string-search "+" tmp))
            (if plus (setq seg (substr tmp 1 plus) tmp (substr tmp (+ plus 2)))
                     (setq seg tmp tmp ""))
            (setq seg (vl-string-trim " " seg) atP (vl-string-search "@" seg))
            (if atP
              (progn (setq cnt (atoi (substr seg 1 atP)) val (atof (substr seg (+ atP 2))) k 0)
                     (while (< k cnt) (setq spList (cons val spList) k (1+ k))))
              (if (> (atof seg) 0.0) (setq spList (cons (atof seg) spList)))))
          (setq spList (reverse spList)))))
      (if (null spList) (setq spList (list 6000.0)))          ; sane default grid
      (setq spx (car spList))
      (if (or (null spx) (<= spx 0.0)) (setq spx 6000.0))     ; length-wise pitch

      ;; --- collect footprints ---------------------------------------------------
      ;; PARTIAL: any MZn_TOGGLE=Yes with a real LEN & WID -> tiled from the LEW/NSW
      ;;          corner (inset), dimensioned.  DEFAULT: one full building-interior
      ;;          rectangle inset ~inset mm from all walls (LEN/WID currently 0).
      (setq specs '() mzNums '())
      (foreach n (list "1" "2" "3")
        (if (= (strcase (MSPL-Get-Str data (strcat "MZ" n "_TOGGLE"))) "YES")
          (progn
            (setq ml (MSPL-Get-Num data (strcat "MZ" n "_LEN"))
                  mw (MSPL-Get-Num data (strcat "MZ" n "_WID"))
                  ff (MSPL-Get-Num data (strcat "MZ" n "_CH_FFL_BEAM")))
            (if (and ml mw (> ml 0.0) (> mw 0.0))
              (setq specs   (append specs (list (list ml mw ff)))
                    mzNums  (append mzNums (list (atoi n))))))))

      ;; grid-line LENGTH extent (owner 8-Jul): a partial mezzanine can be defined by the grid it
      ;; covers — bays Grid <from>..<to>.  Map those grid numbers to the building bay stations.
      ;;
      ;; owner 10-Jul: "if the mezzanine is ENDING between grid lines, we must have some option of
      ;; giving the offset reference in the IF."  Grid numbers alone snap each edge onto a bay line; a
      ;; deck that stops mid-bay could not be drawn.  MZ_OFFSET_FROM / MZ_OFFSET_TO (mm, signed, +toward
      ;; the far end) shift each edge off its grid line.  Both blank/0 => bit-for-bit the old behaviour.
      ;; The stub COLUMNS still land on the building bay lines that fall inside the deck (xs, ~2543); an
      ;; offset only moves the deck EDGE, which is correct — a mezzanine ending mid-bay has no column at
      ;; the edge, its edge beam spans back to the last grid-line column.
      (setq glF (MSPL-Get-Int data "MZ_GRID_BAY_FROM") glT (MSPL-Get-Int data "MZ_GRID_BAY_TO")
            offF (MSPL-Get-Num data "MZ_OFFSET_FROM") offT (MSPL-Get-Num data "MZ_OFFSET_TO")
            glX0 nil glX1 nil)
      (if (null offF) (setq offF 0.0))
      (if (null offT) (setq offT 0.0))
      (if (and glF glT (> glF 0) (> glT glF))
        (progn
          (setq numBays (MSPL-Get-Int data "NUMBAYS"))
          (if (or (null numBays) (< numBays 1)) (setq numBays 1))
          (setq bayPts2 (list 0.0) acc 0.0 k 0)
          (while (< k numBays)
            (setq sp2 (MSPL-Get-Num data (strcat "BAY" (itoa (1+ k)))) rem2 (- len acc))
            (cond ((= k (1- numBays))             (setq sp2 rem2))
                  ((and sp2 (> sp2 0.0) (< sp2 rem2)) T)
                  (T                               (setq sp2 (/ rem2 (float (- numBays k))))))
            (setq acc (+ acc sp2) bayPts2 (append bayPts2 (list acc)) k (1+ k)))
          (if (<= glT (length bayPts2))
            (progn
              (setq glX0 (+ (nth (1- glF) bayPts2) offF)
                    glX1 (+ (nth (1- glT) bayPts2) offT))
              ;; clamp inside the building and keep from < to; a bad offset falls back to the grid lines.
              (setq glX0 (max 0.0 (min glX0 len))
                    glX1 (max 0.0 (min glX1 len)))
              (if (>= glX0 glX1)
                (setq glX0 (nth (1- glF) bayPts2) glX1 (nth (1- glT) bayPts2)))))))

      ;; WIDTH placement (owner 10-Jul) — MZ_WIDTH_ANCHOR + MZ_WIDTH_EXTENT.  Blank => full width,
      ;; so every existing drawing is bit-for-bit unchanged.
      (setq mzBand (peb-mz-width-band data wid inset)
            mzB0   (nth 0 mzBand)
            mzB1   (nth 1 mzBand)
            mzPart (or (> mzB0 (+ inset 1.0)) (< mzB1 (- (- wid inset) 1.0))))  ; narrowed => partial
      (setq foots '())
      (cond
        ;; grid-line extent → one footprint spanning those bays, over the placed width band
        ((and glX0 glX1 (> glX1 glX0))
         (setq foots (list (list glX0 glX1 mzB0 mzB1 T (MSPL-Get-Num data "MZ1_CH_FFL_BEAM")))))
        (specs
          (setq cx0 inset)                       ; one or more dimensioned footprints
          (foreach sp specs
            (setq ml (nth 0 sp) mw (nth 1 sp) ff (nth 2 sp)
                  a0 cx0 a1 (min (- len inset) (+ cx0 ml))
                  b0 inset b1 (min (- wid inset) (+ inset mw)))
            (if (and (> a1 a0) (> b1 b0))
              (setq foots (append foots (list (list a0 a1 b0 b1 T ff)))))
            (setq cx0 (+ a1 (max u 2000.0)))))    ; gap before next tiled mezz
        (T
          (setq foots (list (list inset (- len inset) mzB0 mzB1
                                  mzPart (MSPL-Get-Num data "MZ1_CH_FFL_BEAM"))))))

      ;; --- PUBLISH footprints for the stair drawer (owner 14-Jul) -----------------
      ;; *PEB-MEZZ-FOOTS* = list of (mezzNum fx0 fx1 fy0 fy1).  A stair's ST_IN_MEZZ ("Mezz N") looks
      ;; up its mezzanine here to anchor against the correct footprint instead of blind-tiling the LEW.
      ;; grid/default paths are a single Mezz 1; the specs path maps each footprint to its toggled MZn.
      (setq *PEB-MEZZ-FOOTS* '())
      (cond
        ((and glX0 glX1 (> glX1 glX0))
         (setq *PEB-MEZZ-FOOTS* (list (list 1 glX0 glX1 mzB0 mzB1))))
        (specs
         (setq mzk 0)
         (foreach ft foots
           (setq *PEB-MEZZ-FOOTS*
                 (append *PEB-MEZZ-FOOTS*
                         (list (list (if (nth mzk mzNums) (nth mzk mzNums) (1+ mzk))
                                     (nth 0 ft) (nth 1 ft) (nth 2 ft) (nth 3 ft)))))
           (setq mzk (1+ mzk))))
        (T
         (setq *PEB-MEZZ-FOOTS* (list (list 1 inset (- len inset) mzB0 mzB1)))))

      ;; --- draw each footprint --------------------------------------------------
      (peb-comp-layer "COMP-MEZZ" 6)             ; magenta
      (foreach ft foots
        (vl-catch-all-apply
          (function (lambda ()
            (setq fx0 (nth 0 ft) fx1 (nth 1 ft) fy0 (nth 2 ft) fy1 (nth 3 ft)
                  partial (nth 4 ft) fflv (nth 5 ft))
            (if (and (> fx1 fx0) (> fy1 fy0))
              (progn
                ;; (0) LIGHT diagonal hatch FIRST so it sits behind the boundary + framing (owner 12-Jul:
                ;;     hatch the mezzanine area so it is easy to recognise; keep it very light).
                (vl-catch-all-apply (function (lambda () (peb-mezz-hatch fx0 fy0 fx1 fy1 1600.0))))
                (peb-comp-layer "COMP-MEZZ" 6)

                ;; (1) mezzanine BOUNDARY — a DASHED demarcation over the footprint.
                (peb-comp-poly-lt (list (list fx0 fy0) (list fx1 fy0)
                                        (list fx1 fy1) (list fx0 fy1)) "DASHED" 1.5)

                ;; (2) OWN column grid — MEZZANINE STUB COLUMNS (owner 8-Jul):
                ;;     each drawn as an I-section + anchor bolts, EXACTLY like the PEB
                ;;     columns, but capped with a CIRCLE that marks it a STUB rising only
                ;;     to the underside of the mezzanine beam.  Length-wise the columns sit
                ;;     on the BUILDING BAY grid lines (the main-beam lines); width-wise at
                ;;     the mezzanine column module (MZ_COL_SPACING).  The existing PEB frame
                ;;     columns already carry the beam at the walls, so the footprint-interior
                ;;     stubs drawn here are the NEW mezzanine columns.
                ;; length (x) stations = building bay grid lines that fall inside the footprint
                (setq numBays (MSPL-Get-Int data "NUMBAYS"))
                (if (or (null numBays) (< numBays 1)) (setq numBays 1))
                (if (> numBays 60) (setq numBays 60))
                (setq bayPts2 (list 0.0) acc 0.0 k 0)
                (while (< k numBays)
                  (setq sp2 (MSPL-Get-Num data (strcat "BAY" (itoa (1+ k)))) rem2 (- len acc))
                  (cond ((= k (1- numBays))             (setq sp2 rem2))
                        ((and sp2 (> sp2 0.0) (< sp2 rem2)) T)
                        (T                               (setq sp2 (/ rem2 (float (- numBays k))))))
                  (setq acc (+ acc sp2) bayPts2 (append bayPts2 (list acc)) k (1+ k)))
                (setq xs '())
                (foreach bx bayPts2
                  (if (and (>= bx (- fx0 1.0)) (<= bx (+ fx1 1.0))) (setq xs (append xs (list bx)))))
                (if (null xs) (setq xs (list fx0 fx1)))
                ;; width (y) stations — the mezzanine columns subdivide EACH main width module equally,
                ;; between the main PEB columns (owner 11-Jul), NOT one spacing walked across the width.
                ;; peb-mezz-col-ys builds them from the module boundaries; the existing-column skip below
                ;; drops the stubs on a main line, leaving the interior subdivisions as the new columns.
                (setq ys (peb-mezz-col-ys data wid fy0 fy1 (if spList (car spList) 6000.0)))
                ;; mezzanine stub-column section depth — sized off the width module (lighter
                ;; than the main frame); override the global col depth for the stub, then restore.
                (setq colD     (peb-col-web-depth (apply 'max (cons 6000.0 spList)))
                      savedWeb  *PEB-COL-WEB*
                      *PEB-COL-WEB* colD
                      circR     (* colD 0.72))
                ;; column depiction (owner 8-Jul):
                ;;  - MZ_RCC = Yes → mezzanine dropped inside a client's EXISTING RCC building:
                ;;      draw the EXISTING RCC concrete pillars on their own grid (MZ_RCC_BAY along the
                ;;      length x MZ_RCC_COL across the width) PLUS the NEW steel mezzanine columns that
                ;;      fill in the width module between them.  The drawing shows BOTH column types.
                ;;      (Estimate stays the Mammut self-contained grid — SAP + the detail sheet reconcile
                ;;      the real columns; the drawing is not driven off the estimate.)
                ;;  - else derive from FRAME TYPE: STYPE RC (roof-on-RCC) → RCC pier symbol; else steel I-stub.
                ;; The two hosts are MUTUALLY EXCLUSIVE (owner 8-Jul):
                (setq mzRcc (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_RCC") "")) "YES"))
                (if mzRcc
                  (progn
                    ;; ── EXISTING RCC BUILDING ──────────────────────────────────────────────
                    ;; The building columns ARE the existing RCC pillars (X-square) — no steel
                    ;; building columns (suppressed in the main plan when MZ_RCC=Yes).  Mezzanine
                    ;; beams are CHEMICALLY ANCHORED to them; steel columns are added between the
                    ;; RCC pillars ONLY where an RCC bay is wider than the mezzanine module.
                    (peb-comp-layer "COMP-RCC" 8)          ; grey = existing concrete
                    (setq rccXs   (peb-mezz-stations (MSPL-Get-Str data "MZ_RCC_BAY") fx0 fx1)
                          rccYs   (peb-mezz-stations (MSPL-Get-Str data "MZ_RCC_COL") fy0 fy1)
                          module  (apply 'max (cons 6000.0 spList)))
                    ;; existing RCC concrete pillars at their grid
                    (foreach x rccXs
                      (foreach y rccYs
                        (vl-catch-all-apply (function (lambda () (peb-draw-rcc-pillar x y (* colD 1.40)))))))
                    ;; steel INFILL columns — subdivide only an RCC bay whose width gap exceeds the
                    ;; mezz module (long span); none where the RCC spacing already fits the module.
                    (setq rr (cdr rccYs) yy0 (car rccYs))
                    (foreach yy1 rr
                      (setq gap (- yy1 yy0) nsub (fix (/ (- gap 1.0) module)) k 1)
                      (while (<= k nsub)
                        (setq yi (+ yy0 (* (/ gap (float (1+ nsub))) k)))
                        (foreach x rccXs
                          (vl-catch-all-apply (function (lambda ()
                            (draw-I-column-lengthwise x yi)
                            (setvar "CLAYER" "COMP-MEZZ")
                            (command "_.CIRCLE" (list x yi) circR)))))
                        (setq k (1+ k)))
                      (setq yy0 yy1))
                    ;; one representative chemical-anchor callout
                    (vl-catch-all-apply (function (lambda ()
                      (setvar "CLAYER" "COMP-RCC")
                      (txt-bold "ML" (list (+ (car rccXs) (* colD 1.2)) (+ (cadr rccYs) (* colD 1.2)))
                                (/ 520.0 scale) 0.0 "BEAM CHEM. ANCHORED TO RCC COL (TYP.)")))))
                  ;; ── PEB (STEEL) BUILDING ───────────────────────────────────────────────
                  ;; NEW steel mezzanine columns only (I + 4 bolts + circle stub).  NO RCC columns
                  ;; appear on a steel-building plan (owner 8-Jul).
                  ;;
                  ;; owner 10-Jul: "EXISTING columns as-is; NEW columns (up to the mezzanine beam
                  ;; bottom) will be ENCIRCLED."  Skip every station where a building column already
                  ;; stands — both the SIDE-WALL lines and a MULTI-SPAN's interior lines.  The
                  ;; building column carries the beam there and is left exactly as the frame drew it.
                  (progn
                    (setq mainYs (peb-main-column-ys data wid)
                          mainTol (* 0.5 (peb-col-web-depth wid)))   ; within half a column depth = the same column
                    (foreach x xs
                      (foreach y ys
                        (if (not (vl-some '(lambda (my) (< (abs (- my y)) mainTol)) mainYs))
                          (vl-catch-all-apply (function (lambda ()
                            (draw-I-column-lengthwise x y)
                            (setvar "CLAYER" "COMP-MEZZ")
                            (command "_.CIRCLE" (list x y) circR)))))))))
                (setq *PEB-COL-WEB* savedWeb)

                ;; (3) label + F.F.L tag (centred on the decking)
                (setq cx (/ (+ fx0 fx1) 2.0) cy (/ (+ fy0 fy1) 2.0)
                      lcy (+ fy0 (* (- fy1 fy0) 0.80))   ; label block in the UPPER part, clear of the centre AREA marker
                      hlab (max 250.0 (min 900.0 (* u 0.6))))
                ;; owner 11-Jul: the label carries a description of the HEIGHT — "CLEAR HT. n,nnn"
                ;; (the FFL-to-beam-bottom clear height, MZ1_CH_FFL_BEAM), under the "MEZZANINE FLOOR" name.
                (setq fflStr (if (and fflv (> fflv 0.0))
                               (strcat "CLEAR HT. " (peb-comma (rtos fflv 2 0)))
                               ""))
                (setvar "CLAYER" "COMP-MEZZ")
                (vl-catch-all-apply (function (lambda ()
                  (txt-bold "MC" (list cx lcy) (/ hlab scale) 0.0 "MEZZANINE FLOOR"))))
                (if (/= fflStr "")
                  (vl-catch-all-apply (function (lambda ()
                    (txt-bold "MC" (list cx (- lcy (* hlab 1.7))) (/ (* hlab 0.65) scale) 0.0 fflStr)))))
                ;; mezzanine column SECTION size intentionally NOT shown (owner 12-Jul: "no need to show
                ;; the size of mezzanine columns" — reverses the 11-Jul request; the section is finalised
                ;; at design/SAP, not on the proposal CLP).  The encircled stub columns are still drawn.

                ;; (3b) SHOW THE MEZZANINE COLUMN SPACING (owner 11-Jul) — a vertical dim chain of the
                ;; mezz column lines, run just INSIDE the deck's left edge (the building's own width dims
                ;; already occupy the space outside the LEW wall).
                (if (> (length ys) 1)
                  (progn
                    (setq dimX (+ fx0 (* u 1.3)) yprev (car ys))
                    (foreach yy (cdr ys)
                      (vl-catch-all-apply (function (lambda ()
                        (peb-dim-height-stretch fx0 dimX yprev yy (peb-comma (rtos (- yy yprev) 2 0))))))
                      (setq yprev yy))))

                ;; (4) footprint dims — only when PARTIAL (a full-interior default
                ;;     rectangle is implied by the building outline, so dims would collide).
                (if partial
                  (progn
                    (vl-catch-all-apply (function (lambda ()
                      (peb-dim-h-stretch fx0 fx1 (- fy0 (* post 2.5))
                                         (peb-comma (rtos (- fx1 fx0) 2 0))))))
                    (vl-catch-all-apply (function (lambda ()
                      (peb-dim-height-stretch fx0 (- fx0 (* post 2.5)) fy0 fy1
                                              (peb-comma (rtos (- fy1 fy0) 2 0))))))))))))))
      (setvar "CLAYER" "0")
      (princ))))

;; ---- component drawer: peb-draw-crane (merged from comp_crane.lsp) ----
;; ============================================================================
;;  peb-draw-crane  —  PEB Column Layout Plan overlay for the CRANE component.
;;  Owner: crane runway beams + bridge + hook + capacity/class label, and (only
;;  where the load actually warrants it) a SEPARATE crane-column row.
;;
;;  Self-contained drawer.  Reuses only stable engine helpers that are always in
;;  scope when the Plan engine is loaded:  MSPL-Get-Str / MSPL-Get-Num /
;;  MSPL-Get-Int, peb-comp-layer, peb-comp-poly, txt-bold, peb-comma,
;;  peb-dim-h-stretch, peb-dim-height-stretch.  Everything else is inline.
;;
;;  Plan axes (raw mm):  NSW = bottom (y=0) · FSW = top (y=wid) ·
;;                       LEW = left (x=0)  · REW = right (x=len).
;;  Only txt-bold divides by *PEB-TEXT-SCALE*.
;;
;;  IF keys (from drawingData.js, per crane CR1_/CR2_/CR3_):
;;    CR_TOGGLE            master on/off ("Yes"/"No")
;;    CRn_TOGGLE           this crane on/off
;;    CRn_SPAN             crane span  = c/c of the two runways, mm
;;    CRn_RUN_LENGTH       runway length, mm
;;    CRn_GRID_LOC         "Between Grids" location text (e.g. "Grid 2 to 5")
;;    CRn_CAP              capacity, metric TONNES (t)
;;    CRn_TYPE             e.g. "Top Running (TR)"
;;    CRn_CMAA_CLASS       service class A..F
;;    CRn_QTY_PER_RUNWAY   cranes per runway (informational)
;;
;;  UNITS:  span & runway length are in MILLIMETRES (drawingData pushes them via
;;          mm0()).  Capacity is in TONNES (num0()).  Column-trigger thresholds
;;          therefore compare cap>20 (t) and span>15000 (mm).
;; ============================================================================
;; small HIDDEN-linetype helpers for the crane footprint (open line + closed box) on COMP-CRANE-FP.
(defun peb-crane-fp-line (xa ya xb yb lts)
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-FP") (cons 6 "HIDDEN") (cons 48 lts)
                 (list 10 xa ya 0.0) (list 11 xb yb 0.0))))
(defun peb-crane-fp-box (xa ya xb yb lts)
  (peb-crane-fp-line xa ya xb ya lts) (peb-crane-fp-line xb ya xb yb lts)
  (peb-crane-fp-line xb yb xa yb lts) (peb-crane-fp-line xa yb xa ya lts))
;; CRANE-BEAM runway line — a distinctive LONG-DASH linetype (900 dash / 300 gap, TRUE mm via
;; per-entity scale 1/LTSCALE) so the crane runway reads clearly apart from the short-dash sheeting /
;; grid / other HIDDEN lines on the plan (owner 19-Jul).  Falls back to HIDDEN if the LT can't be made.
(defun peb-crane-beam-line (xa ya xb yb / es)
  (if (not (tblsearch "LTYPE" "CRANEBEAM"))
    (vl-catch-all-apply (function (lambda ()
      (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbLinetypeTableRecord") '(2 . "CRANEBEAM") '(70 . 0)
                     '(3 . "Crane beam ____ ____") '(72 . 65) '(73 . 2) '(40 . 1200.0)
                     '(49 . 900.0) '(74 . 0) '(49 . -300.0) '(74 . 0)))))))
  (setq es (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
  (if (tblsearch "LTYPE" "CRANEBEAM")
    (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-FP") (cons 6 "CRANEBEAM") (cons 48 es)
                   (list 10 xa ya 0.0) (list 11 xb yb 0.0)))
    (peb-crane-fp-line xa ya xb yb (max 0.7 (/ (getvar "LTSCALE") 130.0)))))
;; end-carriage WHEEL — a small solid (continuous) circle so the 2 wheels read as wheels, not dashes.
(defun peb-crane-wheel (cx cy r)
  (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-CRANE-FP") (cons 6 "Continuous")
                 (list 10 cx cy 0.0) (cons 40 r))))
;; CRANEDOT — a true DOTTED linetype (dot / 130 gap, TRUE mm via per-entity scale 1/LTSCALE) for the
;; hoist / trolley symbol, so it reads DOTTED even on its short segments (a plain HIDDEN dash covers a
;; short segment whole and prints solid).  Owner 19-Jul.  Ensures the linetype once, then draws.
(defun peb-crane-dot-ensure ( )
  (if (not (tblsearch "LTYPE" "CRANEDOT"))
    (vl-catch-all-apply (function (lambda ()
      (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbLinetypeTableRecord") '(2 . "CRANEDOT") '(70 . 0)
                     '(3 . "Crane bridge __ __ __") '(72 . 65) '(73 . 2) '(40 . 270.0)
                     '(49 . 150.0) '(74 . 0) '(49 . -120.0) '(74 . 0))))))))  ; owner: SHORT DASH
;; THICK dotted line/circle for the bridge girder + hoist symbol (owner 19-Jul: show them as THICK
;; dotted).  Lineweight 0.15mm (cons 370 15) is honoured by the DWG-To-PDF monochrome plot.
(defun peb-crane-dot-line (xa ya xb yb / es)
  (peb-crane-dot-ensure)
  (setq es (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
  (if (tblsearch "LTYPE" "CRANEDOT")
    (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-FP") (cons 6 "CRANEDOT") (cons 48 es)
                   (cons 370 15)
                   (list 10 xa ya 0.0) (list 11 xb yb 0.0)))
    (peb-crane-fp-line xa ya xb yb (max 0.7 (/ (getvar "LTSCALE") 130.0)))))
(defun peb-crane-dot-circle (cx cy r / es)
  (peb-crane-dot-ensure)
  (setq es (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
  (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-CRANE-FP")
                 (cons 6 (if (tblsearch "LTYPE" "CRANEDOT") "CRANEDOT" "HIDDEN")) (cons 48 es)
                 (cons 370 15)
                 (list 10 cx cy 0.0) (cons 40 r))))

(defun peb-draw-crane (data len wid /
                        u sc n pre span cap typ cls loc runlen
                        numBays cum i sp rem bayPts
                        nums cur k ch g1 g2 tmp
                        x0 x1 yLo yHi bcx hcx hcy hr dg s bx capLbl capY clsY
                        gw etL etW yr
                        midx runTxt capInt byoth craneIdx runY ah a ax dir capX clX clY
                        bracedXs usedCapX b bestX bestD cand dmin bxc px fr
                        yN yF flts txc tyc thw thh yy pt
                        wgys nW letOfs gfW gtW vf vt yy0 yy1 rbw off xb colOff off0 off1 cbIn)
  (if (= (strcase (MSPL-Get-Str data "CR_TOGGLE")) "YES")
    (progn
      (setq u  (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
      (setq sc (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))

      ;; ── grid stations (same parse as the engine: NUMBAYS + BAYn) ──────────
      (setq numBays (MSPL-Get-Int data "NUMBAYS"))
      (if (or (null numBays) (< numBays 1)) (setq numBays 1))
      (if (> numBays 60) (setq numBays 60))
      (setq bayPts (list 0.0) cum 0.0 i 0)
      (while (< i numBays)
        (setq sp  (MSPL-Get-Num data (strcat "BAY" (itoa (1+ i))))
              rem (- len cum))
        (cond ((= i (1- numBays))            (setq sp rem))
              ((and sp (> sp 0.0) (< sp rem)) T)
              (T                              (setq sp (/ rem (float (- numBays i))))))
        (setq cum (+ cum sp) bayPts (append bayPts (list cum)) i (1+ i)))

      ;; ── braced-bay centre x's, so a capacity label never lands on the vertical
      ;;    "BRACED BAY" text (which the CLP prints at each braced bay's midpoint) ──
      (setq bracedXs '())
      (if (boundp 'peb-braced-bays)
        (vl-catch-all-apply (function (lambda ()
          (foreach b (peb-braced-bays bayPts)
            (if (and (>= b 0) (< (1+ b) (length bayPts)))
              (setq bracedXs (cons (/ (+ (nth b bayPts) (nth (1+ b) bayPts)) 2.0)
                                   bracedXs))))))))

      ;; ── one strip per crane (catch-wrapped so one bad crane can't kill the rest) ──
      (setq n 1 craneIdx 0 usedCapX '())
      (while (<= n 3)
        (setq pre (strcat "CR" (itoa n) "_"))
        (if (= (strcase (MSPL-Get-Str data (strcat pre "TOGGLE"))) "YES")
          (progn                       ; UNIVERSAL: show only ONE crane per plan (the first enabled)
          (vl-catch-all-apply
            (function
              (lambda ( / )
                ;; --- read this crane, with defaults ---
                (setq span   (MSPL-Get-Num data (strcat pre "SPAN")))
                (setq cap    (MSPL-Get-Num data (strcat pre "CAP")))
                (setq typ    (MSPL-Get-Str data (strcat pre "TYPE")))
                (setq cls    (MSPL-Get-Str data (strcat pre "CMAA_CLASS")))
                (setq loc    (MSPL-Get-Str data (strcat pre "GRID_LOC")))
                (setq runlen (MSPL-Get-Num data (strcat pre "RUN_LENGTH")))
                (if (or (null span) (<= span 0.0)) (setq span (* wid 0.7)))
                (if (or (null cap)  (<= cap  0.0)) (setq cap  5.0))
                (if (= typ "") (setq typ "Top Running (TR)"))
                (if (= cls "") (setq cls "C"))

                ;; --- runway x-range: prefer "Between Grids", else RUN_LENGTH, else full ---
                (setq x0 0.0 x1 len)
                (setq nums '() cur "" k 1)
                (while (<= k (strlen loc))
                  (setq ch (substr loc k 1))
                  (if (and (>= ch "0") (<= ch "9"))
                    (setq cur (strcat cur ch))
                    (if (> (strlen cur) 0) (setq nums (append nums (list (atoi cur))) cur "")))
                  (setq k (1+ k)))
                (if (> (strlen cur) 0) (setq nums (append nums (list (atoi cur)))))
                (cond
                  ((>= (length nums) 2)
                   (setq g1 (nth 0 nums) g2 (nth 1 nums))
                   (if (> g1 g2) (setq tmp g1 g1 g2 g2 tmp))
                   (if (and (>= g1 1) (<= g2 (length bayPts)))
                     (setq x0 (nth (1- g1) bayPts) x1 (nth (1- g2) bayPts))))
                  ((and runlen (> runlen 0.0) (< runlen len))
                   (setq x0 (/ (- len runlen) 2.0) x1 (+ x0 runlen))))

                (setq midx    (/ (+ x0 x1) 2.0)
                      runTxt  (peb-comma (rtos (- x1 x0) 2 0))
                      capInt  (rtos cap 2 0)
                      byoth   (= (strcase (MSPL-Get-Str data (strcat pre "BY_OTHERS"))) "YES")
                      craneIdx (1+ craneIdx))

                (peb-comp-layer "COMP-CRANE" 1)                 ; red
                (setvar "CLAYER" "COMP-CRANE")

                ;; Maimaar house style (Thal 125-23, HBA 034-23 crane-shed CLPs): on the Column
                ;; Layout Plan the crane is NOT an EOT bridge symbol — it is a RUNNING-LENGTH arrow
                ;; along the length near the eave + a centred "OVER HEAD CRANE / nn TONES" label +
                ;; a "C/L OF RAFTER" bridge centreline.  The runway rides on BRACKETS off the main
                ;; columns, so no separate crane columns are drawn (true even for the 50 t crane).

                ;; (1) RUNNING-LENGTH double-headed arrow along the length, just inside the near
                ;;     eave; a 2nd/3rd crane in series stacks downward.  Capacity + run ride on it.
                (setq runY (- wid (* u 1.35 craneIdx))
                      ah   (* u 0.40))
                (if (< runY (* wid 0.55)) (setq runY (* wid 0.55)))
                (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE")
                               (list 10 x0 runY 0.0) (list 11 x1 runY 0.0)))
                (foreach a (list (list x0 1.0) (list x1 -1.0))
                  (setq ax (car a) dir (cadr a))
                  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE")
                                 (list 10 ax runY 0.0)
                                 (list 11 (+ ax (* dir ah)) (+ runY (* ah 0.30)) 0.0)))
                  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE")
                                 (list 10 ax runY 0.0)
                                 (list 11 (+ ax (* dir ah)) (- runY (* ah 0.30)) 0.0))))
                (txt-rom "MC" (list midx (+ runY (* u 0.32))) (/ (* u 0.42) sc) 0.0
                          (strcat capInt " TONES CRANE RUNNING LENGTH : " runTxt))

                ;; (2) capacity label — placed on the run at the interior point with the MOST
                ;;     clearance from any braced-bay "BRACED BAY" text AND from any capacity label
                ;;     already placed (so 2-3 cranes never stack on a braced bay or on each other).
                (setq bestX nil bestD -1.0)
                (foreach fr (list 0.30 0.40 0.50 0.60 0.70)
                  (setq cand (+ x0 (* (- x1 x0) fr)) dmin 1.0e12)
                  (foreach bxc bracedXs (setq dmin (min dmin (abs (- cand bxc)))))
                  (foreach px  usedCapX (setq dmin (min dmin (abs (- cand px)))))
                  (if (> dmin bestD) (setq bestD dmin bestX cand)))
                (setq capX    (if bestX bestX (/ (+ x0 x1) 2.0))
                      usedCapX (cons capX usedCapX)
                      capY     (* wid 0.50))
                (txt-rom "MC" (list capX (+ capY (* u 0.35))) (/ (* u 0.50) sc) 0.0
                          "OVER HEAD CRANE")
                (txt-rom "MC" (list capX (- capY (* u 0.35))) (/ (* u 0.50) sc) 0.0
                          (strcat capInt " TONES"))
                (if (and cls (/= cls ""))
                  (txt-rom "MC" (list capX (- capY (* u 1.00))) (/ (* u 0.38) sc) 0.0
                            (strcat "CMAA CLASS " cls)))
                (if byoth
                  (txt-rom "MC" (list capX (- capY (* u 1.60))) (/ (* u 0.42) sc) 0.0
                            "(BY OTHERS)"))

                ;; ── (3) DASHED CRANE FOOTPRINT — imported from the old reference CLPs ──
                ;;   2 runway beams (along the length) + bridge girder (across the span)
                ;;   + trolley/hook, all HIDDEN linetype, in this crane's grid module.
                ;;
                ;;   RUNWAY Y-PLACEMENT — a crane runs BETWEEN THE COLUMNS OF ITS MODULE.
                ;;   On a multi-span / multi-gable building the width is divided into modules
                ;;   by interior column lines (*PEB-WGRID-YS*); the crane's width grid range
                ;;   CRn_GRID_FROM_W..TO_W names the two column lines bounding its module, so
                ;;   the runways ride ON those columns.  Each crane can sit in its own module.
                ;;   Single-span (or no width grid given) -> span centred on the building.
                ;; width stations = MAIN column lines only (module boundaries), NOT the merged
                ;; grid lines (*PEB-WGRID-YS* also carries endwall column subdivisions).  This
                ;; matches the CRM's width-grid-letter derivation (nM+1 letters for nM modules).
                (setq flts (max 1.0 (/ u 400.0))         ; per-entity dash scale vs global LTSCALE
                      wgys (peb-comp-width-pts data wid)
                      gfW  (strcase (MSPL-Get-Str data (strcat pre "GRID_FROM_W")))
                      gtW  (strcase (MSPL-Get-Str data (strcat pre "GRID_TO_W")))
                      yN nil yF nil)
                (if (and wgys (> (length wgys) 1)
                         (= (strlen gfW) 1) (= (strlen gtW) 1) (>= (ascii gfW) 65) (>= (ascii gtW) 65))
                  (progn
                    (setq nW     (length wgys)
                          letOfs (if *PEB-GRID-LET-OFS* *PEB-GRID-LET-OFS* 0)
                          vf     (- (peb-grid-letter-index gfW) letOfs)   ; letter A = top (FSW)
                          vt     (- (peb-grid-letter-index gtW) letOfs))
                    ;; UNIVERSAL RULE (owner): a crane runs COLUMN TO COLUMN — one module.  The bridge can
                    ;; NOT cross an interior column line, so clamp a multi-module width range to ADJACENT.
                    (if (> (abs (- vt vf)) 1) (setq vt (+ vf (if (> vt vf) 1 -1))))
                    (setq yy0    (nth (max 0 (min (1- nW) (- nW 1 vf))) wgys)
                          yy1    (nth (max 0 (min (1- nW) (- nW 1 vt))) wgys))
                    (if (> (abs (- yy1 yy0)) 1.0)
                      (progn
                        (setq yN (min yy0 yy1) yF (max yy0 yy1)
                              colOff (/ (if (and (boundp '*PEB-COL-WEB*) *PEB-COL-WEB*) *PEB-COL-WEB* 700.0) 2.0))
                        ;; UNIVERSAL RULE: the crane beam sits just INSIDE each column's INNER FLANGE and
                        ;; the bridge spans beam-to-beam.  A SIDE column (sheeting line at y=0 / y=wid) has
                        ;; its FULL web INSIDE the grid line -> offset the whole web; an INTERIOR column
                        ;; is centred on the line -> offset HALF the web.  (guard: never invert.)
                        ;; The offset lands at the inner-flange FACE; add `cbIn` so the WHOLE 200mm beam band
                        ;; (drawn later as yN±100) sits INBOARD of the flange with a clear gap — its lines
                        ;; never fall flush with the column web/flange.  cbIn = half the 200mm beam + 100 gap.
                        (setq cbIn (+ 100.0 100.0)
                              off0 (+ (if (< yN 1.0)         (* colOff 2.0) colOff) cbIn)
                              off1 (+ (if (> yF (- wid 1.0)) (* colOff 2.0) colOff) cbIn))
                        (if (> (- yF yN) (* (+ off0 off1) 1.3)) (setq yN (+ yN off0) yF (- yF off1)))))))
                (if (null yN)                            ; no width-grid range given
                  (if (and wgys (> (length wgys) 2))
                    ;; MULTI-SPAN / MULTI-GABLE (owner UNIVERSAL RULE): the crane bridge must sit BETWEEN
                    ;; ADJACENT columns (one module) — it can NOT cross an interior column.  Default to the
                    ;; FIRST module (matches the section); width grid keys pick a specific module.  Beams on
                    ;; the inner flanges (cbIn offset), same as the grid-keys path.
                    (progn
                      (setq yN (nth 0 wgys) yF (nth 1 wgys)
                            colOff (/ (if (and (boundp '*PEB-COL-WEB*) *PEB-COL-WEB*) *PEB-COL-WEB* 700.0) 2.0)
                            cbIn (+ 100.0 100.0)
                            off0 (+ (if (< yN 1.0)         (* colOff 2.0) colOff) cbIn)
                            off1 (+ (if (> yF (- wid 1.0)) (* colOff 2.0) colOff) cbIn))
                      (if (> (- yF yN) (* (+ off0 off1) 1.3)) (setq yN (+ yN off0) yF (- yF off1))))
                    ;; SINGLE / CLEAR SPAN (no interior columns): span centred across the width
                    (progn
                      (setq yN (/ (- wid span) 2.0) yF (/ (+ wid span) 2.0))
                      (if (< yN (* u 0.4))         (setq yN (* u 0.4)))
                      (if (> yF (- wid (* u 0.4))) (setq yF (- wid (* u 0.4)))))))
                (if (boundp 'safe-load-ltype) (vl-catch-all-apply (function (lambda () (safe-load-ltype "HIDDEN")))))
                (peb-comp-layer "COMP-CRANE-FP" 8)       ; grey dashed footprint layer
                (setvar "CLAYER" "COMP-CRANE-FP")
                (setq bx  (+ x0 (* (- x1 x0) 0.62))      ; bridge station along the run
                      gw  (max 450.0 (min 1000.0 (* (- yF yN) 0.05))) ; girder/detail scale ~5% of drawn span
                      rbw 200.0                           ; crane-beam top-flange width = STANDARD 200mm (true)
                      txc (+ bx (/ gw 2.0))              ; girder centre-x
                      tyc (/ (+ yN yF) 2.0)              ; bridge mid-span
                      flts (max 0.7 (/ (getvar "LTSCALE") 130.0))) ; finer, LTSCALE-aware dash density
                ;; (1) RUNWAY BEAMS — each drawn as a DOUBLE LONG-DASH line (beam width rbw), sitting
                ;;     just INSIDE the module column's inner flange (yN / yF).  Long-dash linetype
                ;;     differentiates the crane beam from the sheeting / grid lines.
                (foreach yy (list yN yF)
                  (peb-crane-beam-line x0 (- yy (/ rbw 2.0)) x1 (- yy (/ rbw 2.0)))
                  (peb-crane-beam-line x0 (+ yy (/ rbw 2.0)) x1 (+ yy (/ rbw 2.0))))
                ;; (3) BRACKETS — the runway rides on a bracket off each main column; draw a small
                ;;     support pad where a runway crosses a column (bay grid line) inside the run.
                (foreach xb bayPts
                  (if (and (>= xb (- x0 1.0)) (<= xb (+ x1 1.0)))
                    (foreach yy (list yN yF)
                      (peb-crane-fp-box (- xb (* gw 0.45)) (- yy (/ rbw 2.0))
                                        (+ xb (* gw 0.45)) (+ yy (/ rbw 2.0)) flts))))
                ;; BRIDGE GIRDER — two THICK DOTTED lines across the span between the two runways.
                (peb-crane-dot-line bx yN bx yF)
                (peb-crane-dot-line (+ bx gw) yN (+ bx gw) yF)
                ;; (2) END CARRIAGES — the end-truck box where the bridge lands on BOTH runways,
                ;;     each carrying 2 WHEELS (small solid circles) riding on the runway beam.
                (foreach yy (list yN yF)
                  (peb-crane-fp-box (- txc (* gw 0.85)) (- yy (* gw 0.32))
                                    (+ txc (* gw 0.85)) (+ yy (* gw 0.32)) flts)
                  (peb-crane-wheel (- txc (* gw 0.52)) yy (* gw 0.20))
                  (peb-crane-wheel (+ txc (* gw 0.52)) yy (* gw 0.20)))
                ;; TROLLEY + HOOK — accurate hoist symbol (mid-run), proportioned in girder-widths:
                ;; connector cap, main trolley box (with internal division), hook block, hook eye.
                (foreach s (list
                     (list (- txc (* gw 1.14)) (- tyc (* gw 1.40)) (+ txc (* gw 1.14)) (- tyc (* gw 1.40)))
                     (list (+ txc (* gw 1.14)) (- tyc (* gw 1.40)) (+ txc (* gw 1.14)) (+ tyc (* gw 1.40)))
                     (list (+ txc (* gw 1.14)) (+ tyc (* gw 1.40)) (- txc (* gw 1.14)) (+ tyc (* gw 1.40)))
                     (list (- txc (* gw 1.14)) (+ tyc (* gw 1.40)) (- txc (* gw 1.14)) (- tyc (* gw 1.40)))
                     (list (- txc (* gw 1.14)) (- tyc (* gw 0.40)) (+ txc (* gw 1.14)) (- tyc (* gw 0.40)))
                     (list (- txc (* gw 0.67)) (+ tyc (* gw 1.40)) (- txc (* gw 0.67)) (+ tyc (* gw 2.10)))
                     (list (- txc (* gw 0.67)) (+ tyc (* gw 2.10)) (+ txc (* gw 0.67)) (+ tyc (* gw 2.10)))
                     (list (+ txc (* gw 0.67)) (+ tyc (* gw 2.10)) (+ txc (* gw 0.67)) (+ tyc (* gw 1.40)))
                     (list (- txc (* gw 0.90)) (- tyc (* gw 1.40)) (- txc (* gw 0.90)) (- tyc (* gw 2.68)))
                     (list (- txc (* gw 0.90)) (- tyc (* gw 2.68)) (+ txc (* gw 0.90)) (- tyc (* gw 2.68)))
                     (list (+ txc (* gw 0.90)) (- tyc (* gw 2.68)) (+ txc (* gw 0.90)) (- tyc (* gw 1.40))))
                  (peb-crane-dot-line (nth 0 s) (nth 1 s) (nth 2 s) (nth 3 s)))   ; DOTTED hoist symbol
                (peb-crane-dot-circle (- txc (* gw 0.37)) (- tyc (* gw 2.00)) (* gw 0.37))  ; hook eye
                ;; ── LABEL THE CRANE at the footprint (owner 19-Jul): capacity + CMAA + hoist note,
                ;;    centred just below the hoist so the crane is identified AT its bridge (kept clear
                ;;    of the FALL roof tag by stacking DOWN-span, not out to the side). ──
                (setvar "CLAYER" "COMP-CRANE")
                (txt-rom "MC" (list txc (+ tyc (* gw 4.05))) (/ (* u 0.42) sc) 0.0
                          (strcat capInt " TONES CRANE"))
                (txt-rom "MC" (list txc (+ tyc (* gw 5.00))) (/ (* u 0.30) sc) 0.0
                          (if (and cls (/= cls ""))
                            (strcat "CMAA CLASS " cls "   HOIST (BY OTHERS)")
                            "HOIST (BY OTHERS)"))
                ;; bridge girder named alongside it (reads up the span)
                (txt-rom "MC" (list (- bx (* gw 1.05)) (/ (+ yN tyc) 2.0)) (/ (* u 0.30) sc) 90.0
                          "CRANE BRIDGE (BY OTHERS)")
                ;; STOPS / BUMPERS — bar across the beam width at each of the 4 runway ends.
                (foreach pt (list (list x0 yN) (list x1 yN) (list x0 yF) (list x1 yF))
                  (peb-crane-fp-line (car pt) (- (cadr pt) (* rbw 0.9))
                                     (car pt) (+ (cadr pt) (* rbw 0.9)) flts))
                (txt-rom "MC" (list (/ (+ x0 x1) 2.0) (- yN (* u 0.30) (/ rbw 2.0))) (/ (* u 0.34) sc) 0.0
                          (strcat "CRANE RUN : " (peb-comma (rtos (- x1 x0) 2 0))))
                (setvar "CLAYER" "COMP-CRANE")
                (princ)))) ; end lambda / catch
          (setq n 3)))                 ; drew one crane -> break the loop (one per plan)
        (setq n (1+ n)))))
      ;; C/L OF RAFTER — the crane bridge runs symmetric about the rafter centreline
      ;; (drawn once, only when at least one crane was placed).  The label is lifted ABOVE
      ;; the vertical "BRACED BAY" text band (which tops out around wid*0.55) with a short
      ;; leader down to the true centreline at wid/2, so it never overlaps a braced-bay tag.
      (if (and craneIdx (> craneIdx 0))
        (progn
          (peb-comp-layer "COMP-CRANE" 1)
          (setvar "CLAYER" "COMP-CRANE")
          (setq clX (min (* len 0.92) (+ x0 (* (- x1 x0) 0.85)))
                clY (* wid 0.66))
          (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE")
                         (list 10 clX (/ wid 2.0) 0.0)
                         (list 11 clX (- clY (* u 0.30)) 0.0)))
          (txt-rom "MC" (list clX clY) (/ (* u 0.42) sc) 0.0 "C/L OF RAFTER")))
  (setvar "CLAYER" "0")
  (princ))


;; ---- component drawer: peb-draw-stairs (merged from comp_stairs.lsp) ----
;; ---- component drawer: peb-draw-stairs (comp_stairs.lsp) --------------------
;; ============================================================================
;; STAIRS / STAIRCASE drawer  --  ST_TOGGLE + ST<n>_* (n = 1..4)  -- Column Layout Plan
;; ----------------------------------------------------------------------------
;; A staircase in plan = a straight-flight FOOTPRINT (clean footprint, NOT a
;; detailed stair section): an outline WIDTH (across, x) x run-length (along, y),
;; a set of evenly-spaced TREAD lines, an UP arrow showing the climb direction,
;; and a "STAIR ST<n>" label.  Optional TOP-landing rectangle at the head.
;;
;; PLACEMENT (there is no x/y key for a staircase): stack the staircases along
;; the LEW (left, x=0) wall just inside the building, starting near the NSW
;; corner (y=0), tiling upward in +y so multiple stairs never overlap.  A stair
;; normally sits against a wall / in a mezzanine, so this is a sensible default;
;; ST<n>_IN_MEZZ = Yes is still drawn the same way.
;;
;; ST<n> keys used:  TOGGLE, TYPE, WIDTH (mm, dflt 1200), HEIGHT (mm, dflt nil),
;;                   TOP_LANDING ('1'/'0'), MID_LANDING ('1'/'0').
;; Building axes in plan:  NSW=bottom(y=0) FSW=top(y=wid) LEW=left(x=0) REW=right(x=len).
;; Raw mm everywhere; only txt-bold divides its height by *PEB-TEXT-SCALE*.
;; Layer: "COMP-STAIRS" colour 6 (magenta).
;; Self-contained: reuses engine helpers (MSPL-Get-Str/Num, peb-comp-layer,
;; peb-comp-poly, txt-bold, peb-comma) but every risky stair is wrapped in
;; vl-catch-all-apply so one bad stair can't kill the rest; fields default if
;; missing/zero.
;; Dispatch (add to peb-draw-components):
;;   (vl-catch-all-apply (function (lambda () (peb-draw-stairs data len wid))))
;; ============================================================================
;; "Mezz 1" / "Mezz 2" / "MEZZ 3" -> integer N (nil if none).  Tolerates spacing/case.
(defun peb-mezz-num (s / u p ch d)
  (if (or (null s) (= s "")) nil
    (progn
      (setq u (strcase s) p 1 d "")
      (while (<= p (strlen u))
        (setq ch (substr u p 1))
        (if (and (>= ch "0") (<= ch "9")) (setq d (strcat d ch)))
        (setq p (1+ p)))
      (if (> (strlen d) 0) (atoi d) nil))))

(defun peb-draw-stairs
       (data len wid /
        u inset gap ycur i tag wdt hgt typ topl runlen
        x0 x1 y0 y1 midx midy th nt spc j ty
        ax0 ay0 ay1 hl a1 a2 lan
        midl mzStr mezzNum foot xbase yc newy mlanm ymid0 ymid1 mzcur ytop)
  (if (= (strcase (MSPL-Get-Str data "ST_TOGGLE")) "YES")
    (progn
      (setq u     (max 400.0 (min 3000.0 (/ (max len wid) 70.0)))  ; annotation unit
            inset (max 300.0 (min 1500.0 (* u 0.5)))               ; clearance from LEW wall / NSW corner
            gap   (max 400.0 (* u 0.9))                            ; vertical gap between stacked stairs
            th    (max 300.0 (* u 0.40))                           ; desired raw text height
            ycur  inset                                            ; running y-cursor, starts near NSW corner
            mzcur nil)                                             ; per-mezzanine y-cursors (alist mezzNum . y)
      (peb-comp-layer "COMP-STAIRS" 6)                             ; magenta
      (setq i 1)
      (while (<= i 4)
        (setq tag (strcat "ST" (itoa i) "_"))
        (if (= (strcase (MSPL-Get-Str data (strcat tag "TOGGLE"))) "YES")
          (vl-catch-all-apply
            (function
              (lambda ()
                ;; --- read + default this stair's fields ---
                (setq wdt  (MSPL-Get-Num data (strcat tag "WIDTH"))
                      hgt  (MSPL-Get-Num data (strcat tag "HEIGHT"))
                      typ  (MSPL-Get-Str data (strcat tag "TYPE"))
                      topl (MSPL-Get-Str data (strcat tag "TOP_LANDING"))
                      midl (MSPL-Get-Str data (strcat tag "MID_LANDING")))
                (if (or (null wdt) (<= wdt 0.0)) (setq wdt 1200.0)) ; ST width already mm, dflt 1200
                ;; straight-flight run: derived from climb height, else 4000 mm
                (setq runlen (if (and hgt (> hgt 0.0)) (max 3000.0 (* hgt 1.2)) 4000.0))
                ;; --- PLACEMENT: anchor to the stair's mezzanine when ST_IN_MEZZ resolves to a known
                ;;     footprint (owner 14-Jul); else fall back to the old LEW-corner tiling, unchanged. ---
                (setq mzStr   (MSPL-Get-Str data (strcat tag "IN_MEZZ"))
                      mezzNum (peb-mezz-num mzStr)
                      foot    (if (and mezzNum *PEB-MEZZ-FOOTS*) (assoc mezzNum *PEB-MEZZ-FOOTS*) nil))
                (if foot
                  (progn
                    ;; against the mezzanine's LEW edge, climbing up within its y-band; per-mezz cursor
                    (setq xbase (nth 1 foot)
                          yc    (cdr (assoc mezzNum mzcur)))
                    (if (null yc) (setq yc (+ (nth 3 foot) inset)))
                    (setq x0 xbase y0 yc))
                  (setq x0 inset y0 ycur))          ; fallback: LEW corner, global cursor
                ;; MID_LANDING splits the run into two flights with a landing band between (owner 14-Jul).
                (setq mlanm (if (= midl "1") (max 900.0 (* wdt 0.9)) 0.0))
                (setq x1   (+ x0 wdt)
                      y1   (+ y0 runlen mlanm)
                      midx (/ (+ x0 x1) 2.0)
                      midy (/ (+ y0 y1) 2.0)
                      ymid0 (+ y0 (/ runlen 2.0))                  ; landing band start (mid-run)
                      ymid1 (+ ymid0 mlanm))                       ; landing band end
                (peb-comp-layer "COMP-STAIRS" 6)
                (peb-comp-poly (list (list x0 y0) (list x1 y0)
                                     (list x1 y1) (list x0 y1)))
                ;; --- TREAD lines: ~6-10 across the width, over each flight (skip the mid-landing band) ---
                (setq nt  (max 6 (min 10 (fix (/ runlen 400.0))))
                      spc (/ runlen (+ nt 1.0))
                      j   1)
                (while (<= j nt)
                  (setq ty (+ y0 (* j spc)))
                  (if (> ty ymid0) (setq ty (+ ty mlanm)))         ; shift upper-flight treads past the band
                  (if (or (<= mlanm 0.0) (< ty ymid0) (> ty ymid1))
                    (entmake (list (cons 0 "LINE") (cons 8 "COMP-STAIRS")
                                   (list 10 x0 ty 0.0) (list 11 x1 ty 0.0))))
                  (setq j (1+ j)))
                ;; --- MID landing band: cross line + "LANDING" ---
                (if (> mlanm 0.0)
                  (progn
                    (entmake (list (cons 0 "LINE") (cons 8 "COMP-STAIRS")
                                   (list 10 x0 ymid0 0.0) (list 11 x1 ymid0 0.0)))
                    (entmake (list (cons 0 "LINE") (cons 8 "COMP-STAIRS")
                                   (list 10 x0 ymid1 0.0) (list 11 x1 ymid1 0.0)))
                    (setvar "CLAYER" "COMP-STAIRS")
                    (txt-bold "MC" (list midx (/ (+ ymid0 ymid1) 2.0))
                              (/ (* th 0.55) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
                              0.0 "LANDING")))
                ;; --- UP arrow: LINE along the run (+y = climb) + arrowhead + "UP" ---
                (setq ax0 midx
                      ay0 (+ y0 (* spc 0.5))
                      ay1 (- y1 (* spc 0.5))
                      hl  (max 300.0 (* u 0.5)))
                (entmake (list (cons 0 "LINE") (cons 8 "COMP-STAIRS")
                               (list 10 ax0 ay0 0.0) (list 11 ax0 ay1 0.0)))
                (setq a1 (list (- ax0 (* hl 0.4)) (- ay1 hl))
                      a2 (list (+ ax0 (* hl 0.4)) (- ay1 hl)))
                (entmake (list (cons 0 "SOLID") (cons 8 "COMP-STAIRS")
                               (list 10 (car a1) (cadr a1) 0.0)
                               (list 11 (car a2) (cadr a2) 0.0)
                               (list 12 ax0 ay1 0.0) (list 13 ax0 ay1 0.0)))
                (setvar "CLAYER" "COMP-STAIRS")
                (txt-bold "ML"
                          (list (+ ax0 (* u 0.35)) (+ ay0 (* runlen 0.10)))
                          (/ (* th 0.75) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
                          90.0 "UP")
                ;; --- optional TOP landing rectangle at the head (y1..y1+landing) ---
                (if (= topl "1")
                  (progn
                    (setq lan (max 900.0 (* wdt 0.9)))
                    (peb-comp-poly (list (list x0 y1) (list x1 y1)
                                         (list x1 (+ y1 lan)) (list x0 (+ y1 lan))))
                    (setvar "CLAYER" "COMP-STAIRS")
                    (txt-bold "MC" (list midx (+ y1 (/ lan 2.0)))
                              (/ (* th 0.6) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
                              0.0 "LANDING")
                    (setq y1 (+ y1 lan)))
                  (setq lan 0.0))
                ;; --- label to the right of the footprint, reading up the run ---
                (setvar "CLAYER" "COMP-STAIRS")
                (txt-bold "MC"
                          (list (+ x1 (* u 0.7)) (/ (+ y0 y1) 2.0))
                          (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
                          90.0
                          (strcat "STAIR ST" (itoa i)
                                  (if (and typ (/= typ ""))
                                    (strcat " (" (strcase typ) ")") "")
                                  (if foot (strcat " @ MEZZ " (itoa mezzNum)) "")))
                ;; --- advance the cursor past this stair (incl. landing) + gap ---
                (setq newy (+ y1 gap))
                (if foot
                  (setq mzcur (cons (cons mezzNum newy) mzcur))   ; per-mezz cursor (front shadows old)
                  (setq ycur newy))                                ; global fallback cursor
                (princ)))))
        (setq i (1+ i)))))
  (setvar "CLAYER" "0")
  (princ))

;; ---- ROOF ACCESSORIES (RA_*) : skylights + turbo-vents as COUNTS → typical distributed roof marks
;;      (no per-unit grid location in the IF; grid-located ones flow through PL_ placements), + a roof-
;;      opening area note. Owner 6-Jul "100% IF": closes the count-based accessory fields. ----
(defun peb-draw-roof-accessories (data len wid / nsky nvent opening u ts sq cols rows i j k px py r ridge cap)
  (setq nsky    (MSPL-Get-Num data "RA_SKYLIGHTS")
        nvent   (MSPL-Get-Num data "RA_TURBOVENTS")
        opening (MSPL-Get-Num data "RA_ROOF_OPENING")
        u  (max 400.0 (min 3000.0 (/ (max len wid) 70.0)))
        ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (if (or (and nsky (> nsky 0)) (and nvent (> nvent 0)) (and opening (> opening 0)))
    (peb-comp-layer "COMP-ROOF-ACC" 4))                      ; cyan
  ;; --- skylights: even grid over the roof (draw up to 15 typical marks; true count in the label) ---
  (if (and nsky (> nsky 0))
    (progn
      (setq nsky (fix nsky) cap (min nsky 15)
            sq (max 700.0 (min 2200.0 (/ (min len wid) 32.0)))
            cols (fix (+ 0.999 (sqrt cap))) rows (fix (+ 0.999 (/ (float cap) (max 1 cols))))
            k 0 i 1)
      (while (and (<= i rows) (< k cap))
        (setq j 1)
        (while (and (<= j cols) (< k cap))
          (setq px (* len (/ (float j) (+ cols 1))) py (* wid (/ (float i) (+ rows 1))))
          (peb-comp-poly (list (list (- px sq) (- py sq)) (list (+ px sq) (- py sq))
                               (list (+ px sq) (+ py sq)) (list (- px sq) (+ py sq))))
          (entmake (list (cons 0 "LINE") (cons 8 "COMP-ROOF-ACC") (list 10 (- px sq) (- py sq) 0.0) (list 11 (+ px sq) (+ py sq) 0.0)))
          (entmake (list (cons 0 "LINE") (cons 8 "COMP-ROOF-ACC") (list 10 (- px sq) (+ py sq) 0.0) (list 11 (+ px sq) (- py sq) 0.0)))
          (setq k (1+ k) j (1+ j)))
        (setq i (1+ i)))
      (setvar "CLAYER" "COMP-ROOF-ACC")
      (txt-bold "MC" (list (* len 0.5) (* wid 0.035)) (/ (* u 0.45) ts) 0.0
                (strcat (itoa nsky) " SKYLIGHTS (TYP. DISTRIBUTED)"))))
  ;; --- turbo/roof vents: circles evenly along the ridge line ---
  (if (and nvent (> nvent 0))
    (progn
      (setq nvent (fix nvent) ridge (/ wid 2.0) r (max 300.0 (min 850.0 (/ (min len wid) 60.0))) k 1)
      (while (<= k (min nvent 20))
        (setq px (* len (/ (float k) (+ (min nvent 20) 1))))
        (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-ROOF-ACC") (list 10 px ridge 0.0) (cons 40 r)))
        (setq k (1+ k)))
      (setvar "CLAYER" "COMP-ROOF-ACC")
      (txt-bold "MC" (list (* len 0.5) (+ ridge (* r 3.0))) (/ (* u 0.4) ts) 0.0
                (strcat (itoa nvent) " TURBO/ROOF VENTS (ON RIDGE)"))))
  ;; --- roof opening (area only, no location) : a note ---
  (if (and opening (> opening 0))
    (progn
      (setvar "CLAYER" "COMP-ROOF-ACC")
      (txt-bold "MC" (list (* len 0.5) (* wid 0.965)) (/ (* u 0.4) ts) 0.0
                (strcat "ROOF OPENING(S): " (peb-comma (rtos opening 2 1)) " SQM (SEE ROOF PLAN)"))))
  (setvar "CLAYER" "0")
  (princ))

;; ===================== MAIN COMMAND =====================

;; Mark the raised-base zone on the Column Layout Plan (owner 29-Jul): the bay between length-grids
;; rbFrom..rbTo rests on the existing RCC building — a light hatch + boundary + note across the full width.
(defun peb-plan-raised-zone (data bayPts wid / rgf rgt rff x0 x1)
  (if (and (= (peb-tb-or (MSPL-Get-Str data "BP_RAISED_ON") "0") "1") bayPts (> (length bayPts) 1))
    (progn
      (setq rgf (atoi (peb-tb-or (MSPL-Get-Str data "BP_RAISED_GRID_FROM") "0"))
            rgt (atoi (peb-tb-or (MSPL-Get-Str data "BP_RAISED_GRID_TO") "0"))
            rff (atof (peb-tb-or (MSPL-Get-Str data "BP_RAISED_FLOOR") "0")))
      (if (and (>= rgf 1) (<= rgt (length bayPts)) (<= rgf rgt))
        (progn
          (setq x0 (nth (1- rgf) bayPts) x1 (nth (1- rgt) bayPts))
          (vl-catch-all-apply (function (lambda () (peb-mezz-hatch x0 0.0 x1 wid 1400.0))))
          (setvar "CLAYER" "DIMENSIONS")
          (command "_.RECTANG" (list x0 0.0) (list x1 wid))
          (setvar "CLAYER" "TEXT")
          (txt "MC" (list (* 0.5 (+ x0 x1)) (* wid 0.60)) (* 450.0 *PEB-TEXT-SCALE*) 0
               (strcat "ON EXISTING RCC FLOOR +" (peb-comma (rtos rff 2 0))))
          (txt "MC" (list (* 0.5 (+ x0 x1)) (* wid 0.47)) (* 360.0 *PEB-TEXT-SCALE*) 0
               (strcat "(EXISTING RCC BUILDING - BY OTHERS, GRID " (itoa rgf) "-" (itoa rgt) ")"))))))
  (princ))

(defun C:PEB-PLAN
  ( / dataFile data
    project client propinput propno fulldate
    len wid btype rooftype stype widthPts windspeed exposure collateral bldgno revno
    ppY1 ppY2 ridgeY bfVy
    bays baysp bayPts x1 x2 baylen ewcols ewsp gridWpts ewStations ewY
    lewBrace rewBrace extType intType
    minSp prevp yBayDim yOvrDim yFsw ySub yTtl yFrmTop dimGap topGap txtGap
    ewExpr ewSpans ewSum ewScale ewAcc
    x y i j colOff botY topY leftX rightX endHalf
    xdraw idx ypt prevY currY
    c0 c1 c2 c3 c4 c5 c6
    tbTop tbBot tbW tbScale tbXShift
    maxSize areaM2
    borderL borderR borderB borderT bMarg bGap exmin exmax
    prng pi0 pi1 px0 pOfs pnTot pFullLen pFullBays
    logoX logoY logoScale
    endBayL endBayR roofSlope
    mgGableW mgSpanW mgRidgePts mgValleyPts mgColumnPts mgSpans mgGables mgY loadValX
    mgWs sc2 gw base valley colY acc s
    numBays numMod sp bayNum modNum
    tblHeaderH tblBodyRowH tblBodyH tblTotalH tblColWs tblHeaders tblBodies
    tblMerges tblObj tblScaleX
    genNotesText accessoriesText loadsText codesText maimaarText projInfoRows
    slopeXs slopeStep rafterStep sx grp clearH
    lewFrameRaw rewFrameRaw lewFrameLabel rewFrameLabel
    mainHalfY endHalfX sheetGap
    gridY1 gridY2 gridX1 gridX2 ovrTxtH bubR bubStand nWid
    minSpX minSpY bubPitch bubRowsX bubRowsY bubStep bubFit bubOfs
  )

  ;; Initialize MAIMAAR-DIM dimstyle (Section-spec native dims).
  (vl-catch-all-apply (function (lambda () (setup-maimaar-dim))))
  ;; Lay the shared Presentation Standards DB (layers/colours/lineweights/
  ;; styles) when MAIMAAR_PEB_Standard.lsp is loaded.  When it is NOT loaded
  ;; the inline make-layer block further down stays as the fallback.
  (if (boundp 'peb-std-setup)
    (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  ;; Fix the Standard multileader style so MLEADERs get a visible
  ;; "Closed Filled" arrowhead (parity with PEB_Section.lsp).
  (vl-catch-all-apply (function (lambda () (peb-setup-mleader-style))))
  (vl-load-com)
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  (setvar "GRIDMODE" 0)
  (setvar "SNAPMODE" 0)

  ;; ── Visible confirmation that LISP is running ────────────────
  (princ "\nMAIMAAR PEB-PLAN starting...")

  ;; ── Read data file written by VBA macro ──────────────────────
  (setq dataFile
    (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
      *PEB-DATA-FILE*
      (getfiled "Pick the v3 area data file"
                (strcat (if (= (getvar "DWGPREFIX") "") ""
                          (getvar "DWGPREFIX"))
                        "PEB_Data_B1_A1.txt")
                "txt" 4)))
  (if (or (null dataFile) (= dataFile ""))
    (progn (princ "\nNo data file selected -- aborting.")
           (setvar "CMDECHO" 1) (princ) (exit)))
  (princ (strcat "\nReading: " dataFile))
  (setq data (MSPL-Read-Data dataFile))
  ;; owner 5-Jul (multi-area): decide the shared/omitted wall from AR_POSITION UP-FRONT — the building
  ;; outline, width grid and dims are all drawn early, so this must be set before ANY of them (not just
  ;; before the columns).  nil => single-area, draw everything.
  (setq *PEB-OMIT-WALL* (if (and *PEB-MULTI-MODE* data) (peb-common-wall (MSPL-Get-Str data "AR_POSITION")) nil))
  ;; single-area: never inherit a shared-wall marking left over from a previous multi-area run in the
  ;; same acad session (the orchestrator sets it per area and clears it at both ends).
  (if (not *PEB-MULTI-MODE*) (setq *PEB-REF-SHARED* nil))
  ;; owner 5-Jul: per-wall open-for-access state (IF Wall Conditions: OW_NSW/FSW/LEW/REW) — drives whether
  ;; the SHEETING line is drawn on that wall.  Area 01 draws as usual (its own conditions); an associated
  ;; area omits its common wall entirely, so the shared wall follows Area 01's condition.
  (setq *PEB-WOPEN-NSW* (and data (peb-wall-open-p (MSPL-Get-Str data "OW_NSW")))
        *PEB-WOPEN-FSW* (and data (peb-wall-open-p (MSPL-Get-Str data "OW_FSW")))
        *PEB-WOPEN-LEW* (and data (peb-wall-open-p (MSPL-Get-Str data "OW_LEW")))
        *PEB-WOPEN-REW* (and data (peb-wall-open-p (MSPL-Get-Str data "OW_REW"))))
  (if (null data)
    (progn
      (setvar "CMDECHO" 1)
      (princ "\nERROR: Data file not found or empty.")
      (princ)
      (exit)
    )
  )
  (princ (strcat "\nData loaded. " (itoa (length data)) " parameters found."))

  ;; ── Read all inputs from data ────────────────────────────────
  (setq project   (MSPL-Get-Str data "PROJECT"))
  (setq client    (MSPL-Get-Str data "CLIENT"))
  (setq propinput (MSPL-Get-Str data "PROPOSAL"))
  (setq bldgno    (MSPL-Get-Str data "BLDGNO"))
  (setq revno     (MSPL-Get-Str data "REVNO"))

  (if (= project   "") (setq project   "UNNAMED PROJECT"))
  (if (= client    "") (setq client    "UNNAMED CLIENT"))
  (if (= propinput "") (setq propinput "000"))
  (if (= bldgno    "") (setq bldgno    "00"))
  (if (= revno     "") (setq revno     "00"))
  (setq propno (strcat "MSPL-26-" propinput))

  (setq len (MSPL-Get-Num data "LENGTH"))
  (setq wid (MSPL-Get-Num data "WIDTH"))

  (if (or (null len) (<= len 0) (null wid) (<= wid 0))
    (progn
      (alert "LENGTH or WIDTH is missing in the data file.\nClick the Generate button in Excel to regenerate the data file.")
      (setvar "CMDECHO" 1) (princ) (exit)
    )
  )

  (setq roofSlope (format-slope (MSPL-Get-Str data "SLOPE")))
  (setq *PEB-ROOF-SLOPE* roofSlope)

  ;; UNIVERSAL RULE (owner 21-Jul): the Column Layout Plan shows BOTH mm & ft-inches on EVERY
  ;; dimension, exactly as the Section does (Section is always dual via dim-mm-ft / DIMALT).
  ;; So MMFT is the DEFAULT here. Both labelled dims (peb-fmt-value) and bay/module chains
  ;; (peb-fmt-group) read *PEB-DIM-DISPLAY*, so this one global drives every plan dimension.
  ;; Explicit BP_DIM_DISPLAY = "Only Ft" still forces ft-only; "mm"/"mm & Ft"/blank all = BOTH
  ;; (the mm-only mode is retired on the plan per the universal rule).
  (setq *PEB-DIM-DISPLAY*
    (cond
      ((= (strcase (MSPL-Get-Str data "DIM_DISPLAY")) "ONLY FT") "FT")
      (T                                                          "MMFT")))
  (setq stype     (strcase (MSPL-Get-Str data "STYPE")))
  ;; owner 5-Jul: the ARCH shows only in the SECTION — the column-layout PLAN of an arched building is the
  ;; same as its straight equivalent.  So map ACS->CS and AMS->MS for geometry, but flag it so the label
  ;; reads "ARCHED …".  (Before, both fell through to CS — AMS wrongly lost its interior columns.)
  (setq *PEB-ARCHED* nil)
  (cond ((= stype "ACS") (setq *PEB-ARCHED* T stype "CS"))
        ((= stype "AMS") (setq *PEB-ARCHED* T stype "MS")))
  ;; owner 9-Jul: "PP" (Petrol Pump / CNG canopy) MUST be in this whitelist -- it was omitted, so a
  ;; Petrol Pump silently fell through to "CS" and drew as a clear-span gable, leaving the
  ;; "PETROL PUMP CANOPY" label unreachable.  The Section always handled it (draw-petrol-frame).
  (if (not (member stype '("CS" "SS" "MS" "LT" "MG" "FR" "RC" "CC" "BF" "PP")))
    (setq stype "CS"))
  ;; proper canopy name for this sheet (nil for non-canopy stypes -- must be set every sheet so a
  ;; later Clear Span in the same drawing can't inherit a stale Falcon/Butterfly name).
  (setq *PEB-CANOPY-NAME* (peb-canopy-name stype data))
  ;; OPEN CANOPY (owner 9-Jul, from the rendered review set).  BF / CC / PP are open shades: they have
  ;; NO side walls, NO end walls and NO end frames -- the plan even prints "NO SIDE-WALL COLUMNS" while
  ;; the old code went on to draw sidewall cross-bracing, four wall labels and a "BEARING FRAME BOTH
  ;; ENDS" leader across them.  Reset every sheet.
  (setq *PEB-OPEN-CANOPY* (if (member stype '("BF" "CC" "PP")) T nil))

  (setq windspeed  (MSPL-Get-Str data "WINDSPEED"))
  (setq exposure   (MSPL-Get-Str data "EXPOSURE"))
  (setq collateral (MSPL-Get-Str data "COLLATERAL"))
  (if (= windspeed  "") (setq windspeed  "AS PER DESIGN"))
  (if (= exposure   "") (setq exposure   "B"))
  (if (= collateral "") (setq collateral "AS PER DESIGN"))

  ;; ── Roof type ────────────────────────────────────────────────
  (cond
    ((member stype '("SS" "LT" "CC")) (setq rooftype "M"))
    ((member stype '("CS" "MS" "MG" "RC")) (setq rooftype "G"))
    ((member stype '("FR" "PP")) (setq rooftype "F"))   ; PP = near-flat slab (owner 9-Jul)
    ((= stype "BF") (setq rooftype "B"))
    (T (setq rooftype "G"))
  )

  ;; ── Bay points ───────────────────────────────────────────────
  (setq numBays (MSPL-Get-Int data "NUMBAYS"))
  (if (or (null numBays) (< numBays 1)) (setq numBays 1))
  (if (> numBays 60) (setq numBays 60))   ; RULE(STRICT): honour ALL bays (was capped at 20 → broke equal auto-division on long buildings)

  (setq bayPts (list 0.0))
  (setq cum 0.0)
  (setq i 0)
  (while (< i numBays)
    (setq sp (MSPL-Get-Num data (strcat "BAY" (itoa (1+ i)))))
    (setq rem (- len cum))
    (cond
      ((= i (1- numBays)) (setq sp rem))
      ((and sp (> sp 0) (< sp rem)) T)
      (T (setq sp (/ rem (float (- numBays i)))))
    )
    (setq cum (+ cum sp))
    (setq bayPts (append bayPts (list cum)))
    (setq i (1+ i))
  )
  (setq bays (1- (length bayPts)))
  (setq baysp (/ len bays))

  ;; ── MATCH-LINE PART SLICE (owner 27-Aug) ─────────────────────────────────
  ;; A 4:1 building cannot use the height of a 1.1:1 drawing area: B-03's plan was 57%
  ;; blank at 1:800, the worst sheet in the set.  Same cut the roof plans and side walls
  ;; already take (4B.18).  It happens HERE — after the bays are built and BEFORE
  ;; *PEB-TEXT-SCALE* is derived from `len` further down — so the scale, the bubbles and
  ;; every dimension follow the PART automatically.
  ;;
  ;; ONLY THE LENGTH IS SLICED.  The width grid is untouched, so peb-width-letter still
  ;; sees the whole width list and the letters read A..F identically on both parts
  ;; (a 4B.15 regression if it ever changed between sheets).
  ;;
  ;; pFullLen / pFullBays keep the WHOLE building's figures for the subtitle and the
  ;; area: a part sheet must still say the building is 122 x 30 m with 15 bays, not
  ;; report its own half as though that were the building.
  (setq pFullLen len pFullBays bays pOfs 0 pnTot (length bayPts))
  (setq prng (peb-part-range (length bayPts)))
  (if prng
    (progn
      (setq pi0 (car prng) pi1 (cadr prng) pOfs pi0)
      (setq bayPts (peb-sub-list bayPts pi0 pi1))
      (setq px0 (car bayPts))
      (setq bayPts (mapcar (function (lambda (ss) (- ss px0))) bayPts))
      (setq len   (last bayPts)
            bays  (1- (length bayPts)))
      (setq baysp (/ len (max 1 bays)))))

  ;; ── Width points ─────────────────────────────────────────────
  (cond
    ((= stype "MG")
      ;; owner 10-Jul: "two adjacent areas of the SAME height and the SAME length are one MULTI-GABLE
      ;; building WITH MODULES — e.g. width module 1@30 + 1@12."  A multi-gable's gables are therefore
      ;; NOT necessarily equal: each WIDTH MODULE is one gable, with its own ridge at its mid-width and
      ;; a VALLEY at every internal module boundary.  The old code split the width EQUALLY
      ;; (mgGableW = wid / mgGables), so a 30 + 12 building drew two 21 m gables and put the valley in
      ;; the wrong place.  Fall back to equal division only when the IF gives no modules.
      (progn
        ;; Gable structure: PREFER the canonical FRAME GRID (Tier 0 — each gable its OWN sub-modules,
        ;; so a gable can itself be multi-span / clear-span independently).  Fall back to the legacy
        ;; MODEXPR (each width module = a clear-span gable, uniform SPANSPERGABLE interior columns) or
        ;; equal division when the IF gives no grid — so existing multi-gables are UNCHANGED.
        (setq mgGrid (peb-parse-frame-grid (MSPL-Get-Str data "BP_FRAME_GRID")))
        (setq mgSpans (MSPL-Get-Int data "SPANSPERGABLE"))
        (if (or (null mgSpans) (< mgSpans 1)) (setq mgSpans 1))
        (if (> mgSpans 4) (setq mgSpans 4))
        (if (null mgGrid)
          (progn                                    ; legacy → synthesise a grid from MODEXPR + uniform mgSpans
            (setq mgWs (peb-width-order (peb-parse-mod-expression (MSPL-Get-Str data "MODEXPR"))))   ; rule 4B.34 — width chain, written A downward
            (if (not (and mgWs (> (length mgWs) 1)))
              (progn
                (setq mgGables (MSPL-Get-Int data "NUMGABLES"))
                (if (or (null mgGables) (< mgGables 2)) (setq mgGables 2))
                (setq mgWs '() i 0)
                (while (< i mgGables) (setq mgWs (append mgWs (list (/ wid mgGables))) i (1+ i)))))
            (setq mgGrid '())
            (foreach gw mgWs
              (setq mgSub '() j 0)
              (while (< j mgSpans) (setq mgSub (append mgSub (list (/ gw (float mgSpans)))) j (1+ j)))
              (setq mgGrid (append mgGrid (list mgSub))))))
        ;; ── unified: everything below reads mgGrid (list of gables, each a list of sub-span widths) ──
        (setq mgWs (mapcar '(lambda (mgG) (apply '+ mgG)) mgGrid))
        (setq acc 0.0) (foreach s mgWs (setq acc (+ acc s)))
        (setq sc2 (if (> acc 0.0) (/ wid acc) 1.0))         ; scale so the grid closes EXACTLY on wid
        (setq mgGables (length mgGrid))
        (setq mgSpans (apply 'max (mapcar 'length mgGrid))) ; for the fall-arrow offset
        ;; per-gable span descriptor for the labels: "3 SPAN(S) EACH" when uniform, else "1,2,3 SPANS/GABLE"
        (setq mgSpanList (mapcar 'length mgGrid) mgSpanDesc "")
        (foreach n mgSpanList (setq mgSpanDesc (strcat mgSpanDesc (if (= mgSpanDesc "") "" ",") (itoa n))))
        (setq mgSpanDesc
          (if (apply '= mgSpanList)
            (strcat (itoa (car mgSpanList)) " SPAN(S) EACH")
            (strcat mgSpanDesc " SPANS/GABLE")))
        (setq mgWs (mapcar '(lambda (w) (* w sc2)) mgWs))
        ;; the NARROWEST gable drives the FALL-arrow offset (peb-fall-glyph-set uses +/- 0.375*mgGableW).
        (setq mgGableW (apply 'min mgWs))
        (setq mgRidgePts '() mgValleyPts '() mgColumnPts (list 0.0 wid))
        (setq base 0.0 mgGi 0)
        (foreach mgG mgGrid
          (setq gw (* (apply '+ mgG) sc2))
          (setq mgRidgePts (append mgRidgePts (list (+ base (/ gw 2.0)))))   ; ridge at the gable centre
          (setq mgGi (1+ mgGi))
          (if (< mgGi mgGables)                             ; valley (+ valley column) at the gable boundary
            (progn
              (setq valley (+ base gw))
              (setq mgValleyPts (append mgValleyPts (list valley)))
              (setq mgColumnPts (append mgColumnPts (list valley)))))
          (setq mgSubAcc 0.0 mgK 0 mgNsub (length mgG))     ; interior columns at THIS gable's sub-boundaries
          (foreach mgSp mgG
            (setq mgK (1+ mgK))
            (if (< mgK mgNsub)
              (progn
                (setq mgSubAcc (+ mgSubAcc (* mgSp sc2)))
                (setq colY (+ base mgSubAcc))
                (if (and (> colY 0) (< colY wid)) (setq mgColumnPts (append mgColumnPts (list colY)))))))
          (setq base (+ base gw)))
        (setq mgColumnPts (vl-sort mgColumnPts '<))
        (setq widthPts mgColumnPts)
      )
    )
    ((= stype "BF")
      (setq widthPts (list 0.0 (/ wid 2.0) wid))
    )
    ;; owner 10-Jul (frameInvariants.js, RULES/05): SINGLE SLOPE is class 'either' — "built as Clear
    ;; Span Single Slope OR Multi-Span Single Slope (2/3/4 spans)", interior columns "none or 1+".
    ;; FLAT ROOF likewise ("per grid"). Both used to fall to the (T …) branch below, so widthPts
    ;; collapsed to (0 wid): no interior column lines, no width-module dim chain, no interior bracing —
    ;; a multi-span single slope drew as a clear span. Take the module branch whenever the IF actually
    ;; supplies modules (NUMMODULES > 1); with none, nothing changes.
    ;; (AMS already reaches here: line ~3003 rewrites stype "AMS" -> "MS" behind *PEB-ARCHED*.)
    ((or (= stype "MS")
         (and (member stype '("SS" "FR"))
              (setq numMod (MSPL-Get-Int data "NUMMODULES"))
              (> numMod 1)))
      (progn
        (setq numMod (MSPL-Get-Int data "NUMMODULES"))
        (if (or (null numMod) (< numMod 1)) (setq numMod 1))
        (if (> numMod 10) (setq numMod 10))
        (setq widthPts (list 0.0))
        (setq cum 0.0)
        (setq i 0)
        (while (< i numMod)
          (setq sp (MSPL-Get-Num data (strcat "MODULE" (itoa (1+ i)))))
          (setq rem (- wid cum))
          (cond
            ((= i (1- numMod)) (setq sp rem))
            ((and sp (> sp 0) (< sp rem)) T)
            (T (setq sp (/ rem (float (- numMod i)))))
          )
          (setq cum (+ cum sp))
          (setq widthPts (append widthPts (list cum)))
          (setq i (1+ i))
        )
      )
    )
    (T (setq widthPts (list 0.0 wid)))
  )

  (if (member stype '("MS" "MG")) (setq btype "M") (setq btype "C"))

  (setq fulldate (format-date (getvar "CDATE")))

  ;; ── Auto scaling (Phase-2A v7: continuous gradual formula) ──
  ;; Replaces 5-step ladder with smooth linear scaling clamped to a
  ;; sensible range.  Formula:  scale = max(0.60, min(2.50, max_dim / 60000))
  ;;
  ;;   20 m → 0.60 (floor)        100 m → 1.67
  ;;   30 m → 0.60                120 m → 2.00
  ;;   40 m → 0.67                140 m → 2.33
  ;;   60 m → 1.00                150 m → 2.50 (cap)
  ;;   80 m → 1.33                ≥150 m → 2.50
  ;;
  ;; This gives every 10 m of building span a noticeable but small
  ;; bump in text/dim/leader size — finer-grained than the old 5-step
  ;; ladder, no sudden jumps.
  (setq maxSize (max len wid))
  ;; owner 4-Jul: on large buildings text/bubbles were too small to read once plotted. Raised the cap
  ;; 2.5 -> 4.0 and lowered the divisor 60000 -> 45000 so big buildings get larger, readable elements.
  ;;   46 m -> 1.02   100 m -> 2.22   150 m -> 3.39   200 m -> 4.0 (cap)
  (setq *PEB-TEXT-SCALE*
        (max 0.80 (min 4.00 (/ maxSize 45000.0))))
  (setq *PEB-DIM-SCALE* *PEB-TEXT-SCALE*)

  ;; ── End wall columns ─────────────────────────────────────────
  ;; the rule now lives in peb-ew-auto-cols so the END WALL FRAMING elevation
  ;; can grid the identical columns (see the helper's note).
  (setq ewcols (peb-ew-auto-cols wid) ewsp (/ wid ewcols))

  ;; RULE (owner, deviation from Zealcon): EVERY end-wall column gets a grid line
  ;; + letter.  Build the end-wall column stations (0, ewsp, 2*ewsp, … , wid) and
  ;; merge them with the main-frame width stations (widthPts) into gridWpts, so the
  ;; intermediate end-wall column (e.g. the red one between A & B) is gridded too.
  ;; End-wall stations STRICTLY from the IF (BP_EW_LEFT_SPACING) if provided; else the auto rule.
  (setq ewExpr (MSPL-Get-Str data "EWLEXPR"))
  ;; Rule 4B.34 — the end-wall chain runs ACROSS THE WIDTH, so it is written from grid A
  ;; downward and must be reversed, exactly like the width module above. Missing it here
  ;; leaves the two width chains running in OPPOSITE directions, so their shared lines
  ;; stop coinciding and every one of them doubles into two grid letters.
  (setq ewSpans (if (and ewExpr (/= ewExpr "")) (peb-width-order (peb-parse-mod-expression ewExpr)) nil))
  (if ewSpans
    (progn                                             ; positions from the IF spans, scaled to close exactly on wid
      (setq ewSum 0.0) (foreach s ewSpans (setq ewSum (+ ewSum s)))
      (setq ewScale (if (> ewSum 0.0) (/ wid ewSum) 1.0) ewAcc 0.0 ewStations (list 0.0))
      (foreach s ewSpans
        (setq ewAcc (+ ewAcc (* s ewScale)) ewStations (append ewStations (list ewAcc)))))
    (progn                                             ; fallback: engine auto ewsp rule
      (setq ewStations (list 0.0) ewY ewsp)
      (repeat ewcols (setq ewStations (append ewStations (list ewY)) ewY (+ ewY ewsp)))))
  (setq ewcols (1- (length ewStations)))               ; keep ewcols in step with the IF stations
  (setq gridWpts widthPts)
  (foreach s ewStations
  ;; Rule 4B.34 / grid merge tolerance: 5 mm, not 1 mm. Two chains across the SAME width
  ;; (the width module and the end-wall columns) are entered independently and each is
  ;; rounded to whole millimetres on export, so the same physical line can arrive from the
  ;; two chains up to a couple of mm apart. At 1.0 mm — and the test is "<", so exactly
  ;; 1 mm FAILED — those survived as separate stations and the sheet grew duplicate grid
  ;; letters printed on top of each other (MSPL-26-271 came out A..M for a 9-line grid).
  ;; No two real columns are 5 mm apart, so this cannot merge lines that differ.
    (if (not (vl-some '(lambda (p) (< (abs (- p s)) 5.0)) gridWpts))
      (setq gridWpts (append gridWpts (list s)))))
  (setq gridWpts (vl-sort gridWpts '<))
  ;; owner 11-Jul: stash the width-letter stations so the mezzanine WIDTH-GRID placement
  ;; (peb-mz-width-band) maps its A/B/C letters to the SAME lines the plan letters here (~3609).
  ;; Set AFTER the merge, BEFORE peb-draw-components (~3866), so the drawer reads the final list.
  (setq *PEB-WGRID-YS* gridWpts)

  ;; the WHOLE building's area — a match-line part is not a smaller building
  (setq areaM2 (/ (* pFullLen wid) 1000000.0))
  ;; Phase-2A v23: column placement so the OUTER FLANGE sits ON the grid line (Mammut convention).
  ;; Every inset is HALF THE DRAWN COLUMN DEPTH, so it tracks the section at any building size.
  ;;   side-wall  (draw-I-column-lengthwise, ~684): depth D  = *PEB-COL-WEB*        -> inset D/2
  ;;   end-wall   (draw-I-column-widthwise,  ~708): depth De = 0.5*D (peb-rule)     -> inset De/2
  ;;
  ;; owner 10-Jul: "the dim shows O/O of steel column but the arrow is not coming on the outer side of
  ;; the flanges."  leftX/rightX were the HARDCODED 230 while botY/topY were derived — 230 only equals
  ;; De/2 when *PEB-COL-WEB* = 920.  On a 30 m building (D=1100, De=550) the end column was inset 230
  ;; instead of 275, so its outer flange face sat at x = -45 while the bay chain's arrow sat at x = 0.
  ;; Derive it from the SAME peb-rule the drawer uses, so the Rule Book still governs the section.
  ;; NOTE: sheetGap (~3274) and peb-draw-baseplate's bolt gauge (~673) are DIFFERENT 230s — leave them.
  (setq *PEB-COL-WEB* (peb-col-web-depth wid))
  (setq endHalf (/ (* (peb-rule "endwall_depth_x_main" 0.5) *PEB-COL-WEB*) 2.0))   ; De/2
  (setq colOff  (/ *PEB-COL-WEB* 2.0)
        botY    (/ *PEB-COL-WEB* 2.0)
        topY    (- wid (/ *PEB-COL-WEB* 2.0))
        leftX   endHalf
        rightX  (- len endHalf))

  (command "UNDO" "BEGIN")

  ;; ── Text styles & layers ─────────────────────────────────────
  ;; owner 19-Jul UNIVERSAL RULE: ALL TEXT = ROMAND (romand.shx) everywhere on the Plan too.
  (make-text-style "PEB-TITLE" "romand.shx")
  (make-text-style "PEB-BODY"  "romand.shx")
  (make-text-style "PEB-DIM"   "romand.shx")   ; owner 19-Jul STANDING: dimension text = ROMAND (match Section)
  (make-text-style "ROMAND"    "romand.shx")   ; dedicated dim style so AutoCAD Properties Text style reads ROMAND
  ;; owner 19-Jul UNIVERSAL: title-block MTEXT (tb-mtext) uses the "Standard" style — repoint it to ROMAND
  ;; (romand.shx) + oblique 0 so ALL title-block body text is ROMAND upright (bold \fArial|b1 headers stay bold).
  (vl-catch-all-apply
    (function (lambda (/ so sd)
      (setq so (tblobjname "STYLE" "Standard"))
      (if so (progn (setq sd (entget so))
                    (if (assoc 3  sd) (setq sd (subst (cons 3 "romand.shx") (assoc 3 sd) sd)))
                    (if (assoc 50 sd) (setq sd (subst (cons 50 0.0) (assoc 50 sd) sd)))
                    (entmod sd))))))

  (safe-load-ltype "CENTER")
  (safe-load-ltype "HIDDEN")
  (safe-load-ltype "DASHDOT")

  ;; Phase-2A: bump LTSCALE so HIDDEN dashes (ridge / rafter / grid lines)
  ;; render with visible gaps — proportional to building size so a 100 m
  ;; building gets bigger dashes than a 10 m one but neither looks
  ;; effectively continuous.  Floor 50, ceiling 500.
  (setvar "LTSCALE"
    (max 50.0 (min 500.0 (/ (max len wid) 200.0))))

  ;; Layers: prefer the shared Presentation Standards DB (already laid by
  ;; peb-std-setup above when MAIMAAR_PEB_Standard.lsp is loaded).  Fall back
  ;; to this inline block only when the standard module is NOT present.
  ;; SINGLE SOURCE (29-Jun): every brick/layer now comes ONLY from
  ;; MAIMAAR_PEB_Standard.lsp (peb-ensure-layers, run by peb-std-setup above).
  ;; The old inline Phase-2 layer definitions were DROPPED so stale brick values
  ;; can never mix with the owner-locked standard.  Standard must be loaded first.
  (if (not (boundp 'peb-ensure-layers))
    (princ "\n** MAIMAAR_PEB_Standard.lsp NOT loaded — load it FIRST; it is the single source of every line brick. **"))

  ;; ── Building outline (Phase-2A v23: column-flange flush) ─────────
  ;; Now that columns are placed with outer flange ON the grid line
  ;; (botY=350, topY=wid-350 etc.), COL-OUTER coincides with the
  ;; grid rectangle (0,0)→(len,wid).  SHEETING sits 230 mm further out.
  (setq mainHalfY 0.0)                ; column outer flange = grid line
  (setq endHalfX  0.0)
  (setq sheetGap  230.0)              ; column flange → sheeting gap
  ;; Global linetype scale tied to building size so DASHED/CENTER linetypes
  ;; (grid lines, cross-bracing) actually render as dashes at this scale.
  (setvar "LTSCALE" (max 60.0 (/ (max len wid) 400.0)))
  (setvar "CELTSCALE" 2.0)            ; per-entity linetype scale = 2.0
  ;; owner 5-Jul: draw the outline edge-by-edge (peb-draw-outline) so multi-area can OMIT the shared-wall
  ;; sheeting/col-outer line (Area 02's common side).  Single-area draws all 4 (identical to the RECTANGs).
  (setvar "CLAYER" "COL-OUTER")
  (peb-draw-outline 0.0 0.0 len wid nil)                 ; column line: always drawn (columns are there)
  (setvar "CLAYER" "SHEETING")
  (peb-draw-outline (- 0.0 sheetGap) (- 0.0 sheetGap) (+ len sheetGap) (+ wid sheetGap) T)   ; sheeting: skip fully-open walls
  (setvar "CELTSCALE" 1.0)            ; reset for everything else

  ;; ── AREA marking (Zealcon convention) ─────────────────────────────
  ;; A boxed "AREA No. 01" tag at the centre.  NO full-building diagonal X — the
  ;; area is identified by the box; the only X on the plan is the cross-bracing
  ;; in the braced bays (Zealcon master).
  (setq aCx (/ len 2.0) aCy (/ wid 2.0))
  ;; Real area number from the IF (META AREA_NUM); defaults to 1 → "01" if absent (unchanged).
  (setq aNo (MSPL-Get-Int data "AREA_NUM"))
  (if (or (null aNo) (< aNo 1)) (setq aNo 1))
  (setq aLbl (strcat "AREA No. " (if (< aNo 10) (strcat "0" (itoa aNo)) (itoa aNo))))
  (setq aTxH (if *PEB-TEXT-SCALE* (* 620.0 *PEB-TEXT-SCALE*) 620.0))  ; owner 5-Jul: bigger, bolder tag
  (setq aBw  (+ (* (strlen aLbl) aTxH 0.34) aTxH))            ; box half-width to fit text
  (setq aBh  (* aTxH 0.95))                                   ; box half-height
  ;; Geometry via ENTMAKE (no command-line prompts → batch-safe).
  (defun aLn (x1 y1 x2 y2)
    (entmake (list (cons 0 "LINE") (cons 8 "AREA-MARK")
                   (list 10 x1 y1 0.0) (list 11 x2 y2 0.0))))
  (defun aSol (x1 y1 x2 y2 x3 y3 x4 y4)                       ; FILLED grey quad (SOLID) for the drop-shadow
    (entmake (list (cons 0 "SOLID") (cons 8 "AREA-MARK") (cons 62 8)
                   (list 10 x1 y1 0.0) (list 11 x2 y2 0.0)   ; SOLID wants the 3rd/4th corner swapped
                   (list 12 x4 y4 0.0) (list 13 x3 y3 0.0))))
  (setq aFL (- aCx aBw) aFR (+ aCx aBw) aFB (- aCy aBh) aFT (+ aCy aBh))  ; front box corners
  ;; DROP SHADOW (owner 5-Jul: match the BUILDING-01 sample) — a FILLED grey L behind the tag, offset
  ;; DOWN-LEFT (left strip + bottom strip only, so it never bleeds through the box interior). Plot-safe.
  (setq aSo (* aBh 0.55))
  (aSol (- aFL aSo) (- aFB aSo) aFL (- aFB aSo) aFL (- aFT aSo) (- aFL aSo) (- aFT aSo))  ; left strip
  (aSol (- aFL aSo) (- aFB aSo) (- aFR aSo) (- aFB aSo) (- aFR aSo) aFB (- aFL aSo) aFB)  ; bottom strip
  ;; centre box (4 lines) — front face, on top of the shadow
  (aLn aFL aFB aFR aFB) (aLn aFR aFB aFR aFT) (aLn aFR aFT aFL aFT) (aLn aFL aFT aFL aFB)
  ;; AREA CROSS LINES (Roshan, owner): each building corner leadered to the NEAREST corner of the AREA
  ;; tag box — the diagonals CONNECT to the tag box corners (owner 4-Jul: must touch the tag corners).
  (aLn 0.0  0.0  (- aCx aBw) (- aCy aBh))   ; SW corner -> SW box corner
  (aLn len  0.0  (+ aCx aBw) (- aCy aBh))   ; SE corner -> SE box corner
  (aLn len  wid  (+ aCx aBw) (+ aCy aBh))   ; NE corner -> NE box corner
  (aLn 0.0  wid  (- aCx aBw) (+ aCy aBh))   ; NW corner -> NW box corner
  ;; centred area label inside the box (real number)
  (setvar "CLAYER" "TEXT")
  (txt-bold "MC" (list aCx aCy) (peb-th 'SMALL) 0 aLbl)
  ;; HEIGHT tag just below the box so, at a glance, you see which area is high / low.
  ;; owner 10-Jul: "show the CLEAR height on each plan (not eave) ... on each area."
  ;; The IF carries ONE height number (BP_EAVE_HEIGHT) whose MEANING is declared by BP_HEIGHT_REF
  ;; ("Clear Height at Eave" | "Clear Height at Low Eave" | "Eave Height").  peb-v3-to-legacy maps that
  ;; same number to CLEARHEIGHT.  The tag used to be hardcoded "EAVE HT.", which MISLABELS a clear
  ;; height as an eave height — the exact class of error the IF's own Clear-vs-Eave fix guarded against.
  ;; Label it from the basis: never call an eave height "clear", and never call a clear height "eave".
  ;; Now drawn on EVERY plan (was multi-area only, because of the vertical "BRACED BAY" text).  A centre
  ;; bay CAN be braced (the rule is 2nd + 2nd-last + even interior <= 27 m), so they really can be
  ;; neighbours — but measured on 01_clear_span the tag clears the nearest BRACED BAY by 577 mm, since
  ;; the label sits BELOW the area box and the bay text runs vertically beside it.  audit_tagclash.py.
  ;;
  ;; It goes ABOVE the area box, because everything else claims the space BELOW it.  Measured lanes in
  ;; the 8 m-deep lean-to of 30_open_common_wall (area centre y = -4000, box half-height 785):
  ;;     -4000  AREA NO. 02 (in the box)
  ;;     -5447  <- old position, off the box bottom : buried 'LEAN-TO'            2763 x 247 mm
  ;;     -6000  LEAN-TO        (the roof label, ~3608)
  ;;     -6667  <- one line under the roof label    : buried 'OUTER STEEL COLUMN LINE' 5920 x 453 mm
  ;;     -7280  OUTER STEEL COLUMN LINE
  ;; A shallow area simply has no room under the box: ~583 mm of gap for a 533 mm tag.  Above the box
  ;; there is clear air in every fixture.  Do NOT raise it a second line — that lands on 'RAFTER'
  ;; (3136 x 375 mm).  Verified with try_tagpos.py, which reproduces audit_textclash's verdicts exactly.
  (setq aEave (MSPL-Get-Num data "BP_EAVE_HEIGHT"))
  (if (and aEave (> aEave 0.0))
    ;; owner 27-Aug audit: at 0.80 the gap from the box top edge to the glyph tops was
    ;; ~0.9 mm on the plotted A4 — a hairline that READS as a collision with the filled
    ;; AREA band even though it never actually touches.  1.35 opens it to ~2.5 mm and is
    ;; still well under the one-full-line rise that the note above warns lands on RAFTER.
    (txt-bold "MC" (list aCx (+ aCy aBh (* aTxH 1.35))) (peb-th 'SMALL) 0
              (strcat (peb-height-tag-label (MSPL-Get-Str data "HEIGHT_REF")) " "
                      (peb-comma (rtos aEave 2 0)))))

  ;; ── Grid lines (Phase-2A v19 — extend to sheeting outer lines) ──
  ;; Bay lines run from NSW sheeting outer to FSW sheeting outer.
  ;; Width lines run from LEW sheeting outer to REW sheeting outer.
  ;; Grid bubbles sit just outside the sheeting line for clean look.
  ;; Master (Mammut): grid bubbles sit WELL CLEAR of the building — OUTSIDE the
  ;; dimension chains — and the green axis line runs from the building out to the
  ;; bubble, stopping at the bubble edge.  Bay bubbles go above the overall-length
  ;; dim (wid + 2400 DS); width bubbles go left of the overall-width dim (-3500 DS).
  (setq gridY1 (- 0.0 mainHalfY sheetGap))            ; near (NSW) end of axis
  (setq gridX2 (+ len endHalfX sheetGap))             ; near (REW) end of axis
  ;; ── FLEXIBLE GRID STACK (running cursor) — auto-adjusts, NEVER mingles 20x15..150x100 m.
  ;;    Each band is placed from the one below it + its height + a gap (all x scale), so
  ;;    overlap is impossible at any size.  Bubble radius is clamped so bubbles never touch
  ;;    sideways on narrow-bay buildings (the number keeps auto-fitting inside — G2).
  ;; ── RULE 4B.31 — GRID BUBBLES: SIZE TO READ, THEN STAGGER TO FIT ───────────────
  ;; Owner 28-Aug: "Grid No.'s and Bubbles in B-03 are not coming in front of post columns
  ;; and are more than columns."
  ;;
  ;; MEASURED on B-03. Its width grid is the frame lines MERGED with the end-wall posts:
  ;; {0, 6096, 12192, 15240, 18288, 24384, 30480}. Every gap is 6096 except two of 3048,
  ;; where the interior frame line at 15240 falls between two posts. The old rule shrank
  ;; EVERY bubble to 0.48 of that tightest gap — radius 1463 where the building's own text
  ;; scale asks for 1950 — and even then left 122 units between neighbours, which at 1:779
  ;; is 0.16 mm of paper. C, D and E printed as one merged blob: unreadable, and impossible
  ;; to count against the columns they belong to.
  ;;
  ;; Shrinking is the wrong lever twice over. It makes the letters smallest on exactly the
  ;; big buildings whose sheets are already at 1:779, and it never actually buys clearance,
  ;; because the bubble and the gap shrink together — 0.48 of a tight gap is still touching.
  ;;
  ;; So size the bubble for READING and, when the grid is too tight to hold them side by
  ;; side, STAGGER alternate bubbles outward onto a second (or third) row. The stem still
  ;; lands on the true grid line, so every bubble stays in front of its own column — which
  ;; is what was asked for — while neighbours are a whole row apart.
  ;;
  ;; THE TWO DIRECTIONS ARE MEASURED SEPARATELY. They shared one minSp before, so a tight
  ;; WIDTH grid shrank the bay numbers along the top as well, for no reason of their own.
  (setq minSpX (peb-grid-min-gap bayPts)
        minSpY (peb-grid-min-gap gridWpts))
  ;; owner 4-Jul: bubbles must be big enough to READ — floor 900, growing with the building.
  ;; No spacing term here any more; spacing is answered by the row count below.
  (setq *PEB-BUBRAD* (max 900.0 (* 720.0 *PEB-TEXT-SCALE*)))
  (setq bubPitch (+ (* 2.0 *PEB-BUBRAD*) (* 220.0 *PEB-TEXT-SCALE*)))   ; centre-to-centre needed
  (setq bubRowsX (peb-bub-rows bubPitch minSpX)
        bubRowsY (peb-bub-rows bubPitch minSpY))
  ;; Row-to-row offset, measured from the pointer APEX (2.15r) so a staggered bubble's V
  ;; cannot reach into the row in front of it.
  (setq bubStep (+ (* 2.15 *PEB-BUBRAD*) (* 250.0 *PEB-TEXT-SCALE*)))
  ;; Safety net for a pathological grid that even 3 rows cannot hold: fall back to the old
  ;; behaviour and shrink, rather than print bubbles on top of each other.
  (setq bubFit (/ (- (min (* bubRowsX (if minSpX minSpX bubPitch))
                          (* bubRowsY (if minSpY minSpY bubPitch)))
                     (* 220.0 *PEB-TEXT-SCALE*)) 2.0))
  (if (< bubFit *PEB-BUBRAD*) (setq *PEB-BUBRAD* (max 700.0 bubFit)))
  (setq bubR (+ *PEB-BUBRAD* (* 60.0 *PEB-TEXT-SCALE*)))       ; circle edge (kept for reference)
  ;; owner 10-Jul: "the vertical dotted lines go INSIDE the bubble".  bubR only cleared the CIRCLE, but
  ;; grid-bubble also draws a tangent POINTER whose apex sits at (r + tail) = 2.15*r from the centre —
  ;; so a stem ending at the circle ran straight through the V.  Stop the stem clear of the APEX instead,
  ;; leaving a small gap; the pointer itself is then the "small line" below/right of the bubble.
  (setq bubStand (+ (* 2.15 *PEB-BUBRAD*) (* 140.0 *PEB-TEXT-SCALE*)))
  ;; TOP stack (upward from the FSW edge y=wid). owner 4-Jul: FIXED, UNIFORM gap between dimension rows
  ;; (dimGap) so dim spacing is consistent everywhere; generous, equal spacing (txtGap) between the FSW
  ;; label, the area-description banner, the "COLUMN LAYOUT PLAN" title, and the border.
  ;; owner 5-Jul (Gap Fix): step = ~1.6x the dim TEXT height (DIMTXT 500 * DIMSCALE) so the gap between
  ;; the building line and the innermost dim, and between the nested chains, AUTO-FITS the text size
  ;; (was 2000/1300 -> ~4x the text, far too wide). Same value drives the width (dimGap) & top (topGap) chains.
  (setq dimGap (* 1050.0 *PEB-DIM-SCALE*))                               ; gap between the NESTED LEFT width chains (owner 5-Jul: 800 was too tight, small space added)
  (setq topGap (* 1050.0 *PEB-DIM-SCALE*))                               ; TOP length-dim / bubble stack gap
  (setq txtGap (* 2000.0 *PEB-TEXT-SCALE*))                              ; FIXED gap between text rows
  (setq yBayDim (+ wid topGap))                                         ; per-bay dim chain
  (setq yOvrDim (+ yBayDim topGap))                                     ; overall-length dim (same gap)
  (setq ovrTxtH (* (peb-th 'DIM) *PEB-DIM-SCALE*))                     ; outer-dim TEXT height — track the ladder, not a copy of it
  ;; owner 10-Jul: push the number bubbles LIGHTLY upward (0.55*r) so the stem/pointer reads as a short
  ;; connector below the bubble instead of the dotted line crowding it.
  (setq gridY2  (+ yOvrDim ovrTxtH topGap *PEB-BUBRAD* (* 0.55 *PEB-BUBRAD*)))   ; grid bubble CENTRE
  ;; 4B.31: clear the OUTERMOST staggered row, not just row 0, or the FSW label lands on it.
  (setq yFsw    (+ gridY2 (* (- bubRowsX 1) bubStep) *PEB-BUBRAD* txtGap))   ; FSW wall label
  (setq ySub    (+ yFsw txtGap))                                        ; area-description banner
  (setq yTtl    (+ ySub txtGap))                                        ; COLUMN LAYOUT PLAN title
  (setq yFrmTop (+ yTtl txtGap))                                        ; frame / border top
  ;; LEFT stack (leftward from the LEW edge x=0): overall-width dim (-3500 DS) then letter bubbles
  ;; letter bubble CENTRE — anchored 0.9*dimGap BEYOND the outermost (-3*dimGap) width dim, + bubble radius,
  ;; so it FOLLOWS dimGap and can never collide with the overall-width chain no matter how wide the spacing.
  ;; owner 10-Jul: and LIGHTLY leftward (0.55*r) for the letter column, same reason.
  (setq gridX1  (- (- 0.0 (* 3.0 dimGap) ovrTxtH topGap) *PEB-BUBRAD* (* 0.55 *PEB-BUBRAD*)))  ; bubble CENTRE, left of the outer-dim text

  (setq i 1)
  ;; owner 5-Jul (multi-area): the top length-grid sits on the FSW side — skip it when FSW is the wall
  ;; SHARED with an attached area (the grid continues from the reference; avoids the overlap at the join).
  ;; owner 10-Jul: also skip it when THIS area is the reference and an area is attached ABOVE — that FSW
  ;; is now an interior wall, and both areas were drawing a top number row (numbers came out 1 1 2 2 ...).
  (if (not (peb-hide-wall-label-p "FSW"))
    (foreach x bayPts
      ;; owner 5-Jul (multi-area): at a SHARED end wall (Left/Right) the length-grid bubble MERGES — the
      ;; attached area skips its endpoint on the common LEW/REW so it isn't drawn twice at the join.
      (if (not (or (and (peb-omit-wall-p "LEW") (< (abs x) 1.0))
                   (and (peb-omit-wall-p "REW") (< (abs (- x len)) 1.0))))
        (progn
          (setvar "CLAYER" "GRID-LINES")
          ;; RULE (owner 4-Jul): grid marking line runs from the OUTER dimension line (overall length dim,
          ;; yOvrDim) up to the inner side of the bubble — not through the building.
          ;; 4B.31: this bubble's own row. The stem still runs to the TRUE grid line, so a
          ;; staggered bubble is still in front of its own column — only further out.
          (setq bubOfs (* (peb-bub-row (1- i) bubRowsX) bubStep))
          (command "LINE" (list x (+ yOvrDim ovrTxtH)) (list x (- (+ gridY2 bubOfs) bubStand)) "")   ; stop clear of the pointer apex (owner 10-Jul)
          (setvar "CLAYER" "GRID")
          ;; + pOfs keeps the numbers TRUE on a match-line part: part 2 starts at grid 9.
          (grid-bubble x (+ gridY2 bubOfs)
            (itoa (+ i pOfs (if *PEB-GRID-NUM-OFS* *PEB-GRID-NUM-OFS* 0))) "D")))   ; owner 5-Jul: number offset -> grid CONTINUES across side-by-side areas
      (setq i (1+ i))
    )
  )

  ;; Phase-2A v21: skip width grid LINES at NSW (y=0) and FSW (y=wid)
  ;; — they're redundant with the COL-OUTER / SHEETING rectangle
  ;; horizontals right above/below.  Bubbles still drawn so letters
  ;; A (NSW) and last (FSW) remain visible.
  ;; RULE: grid letter A at the TOP (FSW), then B, C… downward.  widthPts is
  ;; ascending (y=0 NSW bottom → y=wid FSW top), so letter index counts DOWN.
  ;; owner 5-Jul (multi-area): the LEFT width grid sits on the LEW side — skip it when LEW is the shared
  ;; end wall (Left/Right side-by-side); the outer area carries the one width grid.
  (setq j 0 nWid (length gridWpts))
  ;; ... and skip the letter column when an area is attached to THIS area's LEW (mirror of the FSW case)
  (if (not (peb-hide-wall-label-p "LEW"))
  (foreach y gridWpts
    ;; owner 5-Jul (multi-area): at a SHARED side wall (Below/Above) the grid bubble MERGES — the attached
    ;; area skips its endpoint bubble/line on the common wall so it isn't drawn twice at the join.
    (if (not (or (and (peb-omit-wall-p "NSW") (< (abs y) 1.0))
                 (and (peb-omit-wall-p "FSW") (< (abs (- y wid)) 1.0))))
      (progn
        (setvar "CLAYER" "GRID-LINES")
        ;; RULE (owner 4-Jul): grid marking line from the OUTER width dimension line (-3*dimGap) to the bubble.
        ;; 4B.31: this bubble's own row — B-03's frame line at 15240 sits 3048 from the posts
        ;; either side of it, too close to hold three readable bubbles in one column.
        (setq bubOfs (* (peb-bub-row j bubRowsY) bubStep))
        (command "LINE" (list (- (- 0.0 (* 3.0 dimGap)) ovrTxtH) y) (list (+ (- gridX1 bubOfs) bubStand) y) "")   ; stop clear of the pointer apex (owner 10-Jul)
        (setvar "CLAYER" "GRID")
        (grid-bubble (- gridX1 bubOfs) y (peb-grid-letter (+ (- nWid 1 j) (if *PEB-GRID-LET-OFS* *PEB-GRID-LET-OFS* 0))) "R")))   ; owner 5-Jul: letter offset -> grid CONTINUES across stacked areas; skip-I via peb-grid-letter
    (setq j (1+ j))
  ))

  ;; ── COLUMN CENTRE LINES (owner 4-Jul) ────────────────────────────────────────────
  ;; At each frame (bay grid), a dash-dot CENTRE line crosses the building ALONG THE WIDTH,
  ;; connecting the columns (NSW..FSW) through their centres. Drawn together with the grid lines.
  (if (not (tblsearch "LTYPE" "CENTER"))
    (vl-catch-all-apply (function (lambda () (command "_.-LINETYPE" "_Load" "CENTER" "acad.lin" "")))))
  ;; owner 5-Jul (multi-area): on the wall SHARED with an attached area, extend the frame/rafter centre
  ;; line all the way to the grid line (0 or wid) so it TOUCHES the reference area's column outer flange
  ;; (which sits ON that grid line); the non-common walls stay inset by colOff as normal.
  (foreach x bayPts
    (setvar "CLAYER" "GRID-LINES")
    (vl-catch-all-apply (function (lambda () (setvar "CELTYPE" "CENTER"))))
    (command "_.LINE" (list x (if (peb-omit-wall-p "NSW") 0.0 colOff))
                      (list x (if (peb-omit-wall-p "FSW") wid (- wid colOff))) "")
    (vl-catch-all-apply (function (lambda () (setvar "CELTYPE" "BYLAYER")))))

  ;; ── Ridge / roof type ─────────────────────────────────────────
  ;; Phase-2A: ridge lines kept on RIDGE layer (HIDDEN linetype, slim),
  ;; labels converted from plain TEXT to native MLEADER pointing at the
  ;; ridge line itself (grip-editable, draftsman can drag arrow tip).
  (cond
    ((member stype '("CS" "MS" "RC"))
      (progn
        ;; owner 4-Jul: ridge = dash-dot CENTERX2 line; L-leader symbol in the 3rd bay from the right.
        ;; owner 9-Jul: ridge Y honours BP_RIDGE_OFFSET (distance from NSW); blank => central.
        (setq ridgeY (peb-ridge-y data wid))
        (peb-ridge-line 0 len ridgeY)
        (vl-catch-all-apply
          (function (lambda ()
            (peb-ridge-symbol (peb-ridge-bay-x bayPts) ridgeY))))
      )
    )
    ((= stype "MG")
      (progn
        ;; owner 4-Jul: each gable ridge = dash-dot CENTERX2 line; L-leader symbol in the 3rd bay from right.
        (foreach mgY mgRidgePts (peb-ridge-line 0 len mgY))
        (setvar "CLAYER" "GRID-LINES")
        (foreach mgY mgValleyPts (command "LINE" (list 0 mgY) (list len mgY) ""))
        (foreach mgY mgRidgePts
          (vl-catch-all-apply
            (function (lambda ()
              (peb-ridge-symbol (peb-ridge-bay-x bayPts) mgY)))))
        (foreach mgY mgValleyPts
          (vl-catch-all-apply
            (function (lambda ()
              ;; owner defect: at 0.80*len the label sat on the last braced bay's vertical "BRACED BAY"
              ;; text (~48750 on a 60 m frame); at 0.60*len it hit the centre AREA/CLEAR-HT tag.  When the
              ;; gables are equal the valley runs down the MID-WIDTH — the same crowded row as the area tag
              ;; and every BRACED BAY.  0.32*len drops it into the clear gap between the two close interior
              ;; braces (the 2nd + 2nd-last brace rule leaves ~15 m open there), left of the centre tag.
              (peb-label-with-leader "VALLEY GUTTER LINE"
                                     (list (* len 0.32) (+ mgY (* 1200 *PEB-TEXT-SCALE*)))
                                     (list (* len 0.30) mgY)
                                     "S" 600.0)))))
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (* len 0.50) (+ wid (* 700 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0
          (strcat "MULTI-GABLE ROOF | " (itoa mgGables) " GABLES | " mgSpanDesc))
      )
    )
    ((= stype "BF")
      (progn
        (setvar "CLAYER" "RIDGE")
        (setq bfVy (peb-bf-valley-y data wid))   ; T1.1: BF centre line at the TRUE valley/peak (BP_CANT_SPAN), not wid/2
        (command "LINE" (list 0 bfVy) (list len bfVy) "")
      )   ; owner 5-Jul: valley label folded into the centre-line callouts below (was overlapping the AREA tag)
    )
    ((= stype "FR")
      (progn (setvar "CLAYER" "TEXT")
             (txt "MC" (list (* len 0.50) (- (* wid 0.50) (* 1300 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "FLAT ROOF BUILDING"))   ; owner 5-Jul: below the AREA tag
    )
    (T
      (progn (setvar "CLAYER" "TEXT")
             (txt "MC" (list (* len 0.50) (- (* wid 0.50) (* 1300 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 (peb-roof-label stype rooftype)))   ; owner 5-Jul: below the AREA tag
    )
  )

  ;; ── RAFTER lines + periodic MLEADER labels ───────────────────────
  ;; Phase-2A: each bay-grid position carries a slim dotted "RAFTER"
  ;; line on the new RAFTER layer (already drawn as the GRID-LINES per
  ;; column position above — so we only ADD the MLEADER labels here).
  ;;
  ;; Spacing rule (per user): denser labels on small buildings,
  ;; sparser on big ones to keep the plan uncluttered.
  ;;   ≤ 3 bays  → 1 label (middle)
  ;;   4–7 bays  → every 4th rafter
  ;;   8–11 bays → every 5th rafter
  ;;   ≥ 12 bays → every 6th rafter
  ;; owner 4-Jul: ONE RAFTER leader label only, at the middle bay-line (was one per rafterStep bays).
  (setq i (fix (/ (length bayPts) 2)))
  (vl-catch-all-apply
    (function (lambda ()
      ;; owner 29-Jul: drop the label well below the NSW line so it clears the centred "CROSS BRACING (TYP.)"
      ;; text (which sits ~900 below the line) — the two were overlapping at the bottom centre.
      (peb-label-with-leader "RAFTER"
                             (list (+ (nth i bayPts) (* 1200 *PEB-DIM-SCALE*))
                                   (- (* 2200 *PEB-DIM-SCALE*)))
                             (list (nth i bayPts) (/ wid 4.0))
                             "S" 600.0))))

  ;; End-frame TYPE — computed HERE (before the columns) so a MAIN-FRAME end wall draws its outer
  ;; columns like the interior (full-size, lengthwise); a BEARING end wall uses the half-size posts.
  (setq lewFrameRaw (strcase (MSPL-Get-Str data "EW_LEFT_FRAME"))
        rewFrameRaw (strcase (MSPL-Get-Str data "EW_RIGHT_FRAME"))
        ;; "MAIN FRAME", "MAIN FRAME WITH HANGING COLUMNS" (owner 28-Jul) and legacy "RIGID" are MAIN frames
        ;; (their corners draw as full-size lengthwise legs). MF 1/2 stays as it was.
        lewFrameLabel (if (or (= lewFrameRaw "MAIN FRAME") (wcmatch lewFrameRaw "MAIN FRAME WITH HANGING*") (= lewFrameRaw "RIGID")) "MAIN FRAME" "BEARING FRAME")
        rewFrameLabel (if (or (= rewFrameRaw "MAIN FRAME") (wcmatch rewFrameRaw "MAIN FRAME WITH HANGING*") (= rewFrameRaw "RIGID")) "MAIN FRAME" "BEARING FRAME")
        ;; HANGING COLUMNS (owner 28-Jul, NLC Workshop): the endwall's INTERMEDIATE columns hang from the
        ;; rafter and have NO foundation → NO base plate / anchor bolts in the Column Layout & Anchor Bolt Plan.
        lewHang (wcmatch lewFrameRaw "*HANGING*")
        rewHang (wcmatch rewFrameRaw "*HANGING*"))

  ;; (*PEB-OMIT-WALL* is now set up-front, right after the data read — see the top of C:PEB-PLAN.)

  ;; ── Columns ───────────────────────────────────────────────────
  (cond
    ;; existing-RCC-building mezzanine: the building columns ARE the existing RCC pillars
    ;; (drawn by peb-draw-mezzanine) — draw NO steel building columns here (owner 8-Jul).
    ((peb-mz-rcc-p data) nil)
    ((= stype "RC")
      (progn
        (foreach x bayPts
          (if (= x 0) (setq xdraw leftX) (if (> x (- len 1)) (setq xdraw rightX) (setq xdraw x)))
          (draw-RCC-column xdraw botY) (draw-RCC-column xdraw topY))
        ;; owner 5-Jul: centre "ROOF RAFTERS FIXED ON RCC COLUMNS" label removed — it overlapped the AREA
        ;; tag and duplicated the "ROOF SYSTEM ON RCC COLUMNS" note already placed below the tag.
      )
    )
    ((= stype "CC")
      (progn
        (foreach x bayPts
          (if (= x 0) (setq xdraw leftX) (if (> x (- len 1)) (setq xdraw rightX) (setq xdraw x)))
          (draw-I-column-lengthwise xdraw botY))
        (setvar "CLAYER" "TEXT")
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.86)) (peb-th 'DIM) 0 "FRONT / CANTILEVER EDGE - NO COLUMNS")
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.14)) (peb-th 'DIM) 0 "BACK SUPPORT COLUMN LINE")
      )
    )
    ((= stype "PP")
      ;; Petrol Pump / CNG canopy (owner 9-Jul).  TWO column lines, INSET from the roof edges, with a
      ;; cantilever overhang on each side -- the same 0.22 / 0.78 of the width the Section uses
      ;; (draw-petrol-frame: cx1 = 0.22W, cx2 = 0.78W).  Open underneath: no walls, no end columns.
      (progn
        (setq ppY1 (* wid 0.22) ppY2 (* wid 0.78))
        (foreach x bayPts
          (if (= x 0) (setq xdraw leftX) (if (> x (- len 1)) (setq xdraw rightX) (setq xdraw x)))
          (draw-I-column-lengthwise xdraw ppY1)
          (draw-I-column-lengthwise xdraw ppY2))
        (setvar "CLAYER" "TEXT")
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.95)) (peb-th 'DIM) 0 "CANTILEVER OVERHANG - NO COLUMNS")
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.05)) (peb-th 'DIM) 0 "CANTILEVER OVERHANG - NO COLUMNS")
      )
    )
    ((= stype "LT")
      (progn
        (foreach x bayPts
          (if (= x 0) (setq xdraw leftX) (if (> x (- len 1)) (setq xdraw rightX) (setq xdraw x)))
          (draw-I-column-lengthwise xdraw botY))
        (setvar "CLAYER" "TEXT")
        ;; owner 10-Jul: "no need to write the word of existing PEB building etc. — automatically define
        ;; that the lean-to area is connected with the adjacent building."  When the lean-to is an ATTACHED
        ;; area of a multi-area plan the adjacent building is DRAWN right next to it, so the attachment is
        ;; self-evident and the label only crowds an 8 m strip.  A STANDALONE lean-to still needs to say
        ;; what it leans on, because that building is not on the sheet.
        (if (not *PEB-MULTI-MODE*)
          (txt-bold "MC" (list (/ len 2.0) (* wid 0.86)) (peb-th 'DIM) 0 "ATTACHED SIDE / EXISTING BUILDING OR WALL"))
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.14)) (peb-th 'DIM) 0 "OUTER STEEL COLUMN LINE")
      )
    )
    ((= stype "BF")
      (progn
        (setq bfVy (peb-bf-valley-y data wid))   ; T1.1: centre column at the TRUE valley (BP_CANT_SPAN for butterfly; wid/2 for falcon), matching the Section
        (foreach x bayPts
          (if (= x 0) (setq xdraw leftX) (if (> x (- len 1)) (setq xdraw rightX) (setq xdraw x)))
          (draw-I-column-lengthwise xdraw bfVy))
        (setvar "CLAYER" "TEXT")   ; owner 5-Jul: cleared of the AREA tag — one callout above, one below, snug to the falls
        ;; The centre line means the OPPOSITE thing for the two 2-wing canopies (owner 9-Jul):
        ;;   Butterfly -> wings fall INWARD, so the centre is a VALLEY and carries the gutter.
        ;;   Falcon    -> wings fall OUTWARD, so the centre is a RIDGE PEAK and drains at the
        ;;                outer free edges; calling it a valley gutter is simply wrong.
        ;; *PEB-CANOPY-NAME* is set from CC_FALCON_PEAK when the sheet's data is read.
        (txt-bold "MC" (list (/ len 2.0) (+ bfVy (* 1700 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0
          (if (and *PEB-CANOPY-NAME* (wcmatch *PEB-CANOPY-NAME* "FALCON*"))
            "CENTER COLUMN LINE / RIDGE PEAK - FALCON"
            "CENTER COLUMN LINE / VALLEY GUTTER - BUTTERFLY"))
        (txt-bold "MC" (list (/ len 2.0) (- bfVy (* 1700 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "NO SIDE-WALL COLUMNS - ROOF CANTILEVERS BOTH SIDES")
      )
    )
    (T
      (progn
        (foreach x bayPts
          (if (= x 0) (setq xdraw leftX) (if (> x (- len 1)) (setq xdraw rightX) (setq xdraw x)))
          ;; Phase-2A v22: corner column matches end-frame TYPE.
          ;;   MAIN FRAME corner → lengthwise (700 deep) — flush with COL-OUTER
          ;;   BEARING FRAME corner → widthwise (smaller — bearing post)
          ;; owner 5-Jul (multi-area): omit the SIDE-WALL column row that is COMMON with the attached area
          ;; (*PEB-OMIT-WALL* = "NSW"|"FSW"), so the shared wall has ONE row of columns.  nil => draw both.
          (cond
            ;; owner 5-Jul (multi-area): END wall shared with a side-by-side area (Left/Right) → drop that
            ;; whole end-column line (the neighbour's end-wall columns serve the join).
            ((and (= x 0)          (peb-omit-wall-p "LEW")) nil)
            ((and (> x (- len 1))  (peb-omit-wall-p "REW")) nil)
            ;; LEW corner (x=0)
            ((= x 0)
              (if (= lewFrameLabel "MAIN FRAME")
                (progn (if (not (peb-omit-wall-p "NSW")) (draw-I-column-lengthwise xdraw botY)) (if (not (peb-omit-wall-p "FSW")) (draw-I-column-lengthwise xdraw topY)))
                (progn (if (not (peb-omit-wall-p "NSW")) (draw-I-column-widthwise xdraw botY)) (if (not (peb-omit-wall-p "FSW")) (draw-I-column-widthwise xdraw topY)))))
            ;; REW corner (x=len)
            ((> x (- len 1))
              (if (= rewFrameLabel "MAIN FRAME")
                (progn (if (not (peb-omit-wall-p "NSW")) (draw-I-column-lengthwise xdraw botY)) (if (not (peb-omit-wall-p "FSW")) (draw-I-column-lengthwise xdraw topY)))
                (progn (if (not (peb-omit-wall-p "NSW")) (draw-I-column-widthwise xdraw botY)) (if (not (peb-omit-wall-p "FSW")) (draw-I-column-widthwise xdraw topY)))))
            ;; Interior bay → main frame lengthwise
            (T
              (progn (if (not (peb-omit-wall-p "NSW")) (draw-I-column-lengthwise xdraw botY)) (if (not (peb-omit-wall-p "FSW")) (draw-I-column-lengthwise xdraw topY)))))
        )
        ;; intermediate end-wall columns at the IF stations (exclude the two corners)
        ;; owner 5-Jul (multi-area): drop the posts on an end wall shared with a side-by-side area.
        (foreach y ewStations
          (if (and (> y 0.5) (< y (- wid 0.5)))
            ;; owner 28-Jul: a "Main Frame with Hanging Columns" endwall → its INTERMEDIATE columns hang, so
            ;; suppress their base plate / bolts (lewHang/rewHang drive *PEB-COL-NO-BOLT* per side).
            (progn (if (not (peb-omit-wall-p "LEW")) (progn (setq *PEB-COL-NO-BOLT* lewHang) (draw-I-column-widthwise leftX y)))
                   (if (not (peb-omit-wall-p "REW")) (progn (setq *PEB-COL-NO-BOLT* rewHang) (draw-I-column-widthwise rightX y)))))
        )
        (setq *PEB-COL-NO-BOLT* nil)   ; reset — corner + interior module-line columns keep their base plates
        ;; Interior columns on every interior width-module line.  MS/MG always; SS (single slope) and FR
        ;; (flat roof) too now (owner 10-Jul: a multi-span single slope / modular flat roof has interior
        ;; columns and must not draw as a clear span).  Safe to add: their widthPts is only modularized
        ;; when NUMMODULES>1 (~3334); a CLEAR-SPAN SS/FR keeps widthPts=(0 wid), so the loop finds no
        ;; interior ypt and draws nothing — identical to before.
        (if (member stype '("MS" "MG" "SS" "FR"))
          (progn
            (foreach ypt widthPts
              (if (and (> ypt 0) (< ypt wid))
                (progn
                  (setq idx 1)
                  (while (< idx (1- (length bayPts)))
                    (setq x (nth idx bayPts))
                    (draw-I-column-lengthwise x ypt)
                    (setq idx (1+ idx))
                  )
                )
              )
            )
          )
        )
      )
    )
  )

  ;; ── Roof cross-bracing (X) in the braced bays ────────────────
  ;; Mammut convention: brace the 2nd & 2nd-last bay (never end bays) + interior
  ;; braces so no unbraced run > 27 m.  Drawn on the CROSS layer (hidden, 0.13).
  ;; End-wall bracing (owner rule): an end wall carries bracing (its end bay is braced) when its
  ;; girts are "By Framed" AND it has end-wall columns — matches geometryRules.endwallBracePlan.
  (setq lewBrace (and (wcmatch (strcase (MSPL-Get-Str data "BP_EW_LEFT_GIRTS"))  "*BY*FRAMED*")
                      (/= "" (MSPL-Get-Str data "BP_EW_LEFT_SPACING")))
        rewBrace (and (wcmatch (strcase (MSPL-Get-Str data "BP_EW_RIGHT_GIRTS")) "*BY*FRAMED*")
                      (/= "" (MSPL-Get-Str data "BP_EW_RIGHT_SPACING"))))
  ;; Bracing TYPE strings (IF): the sidewalls use BP_BRACING_EXT, the interior columns BP_BRACING_INT.
  ;; peb-brace-line maps each to its plan symbol (Diagonal→bowtie, Portal-up-cross→bowtie+stars, Portal
  ;; →thick beam line, N/A→nothing).
  (setq extType (MSPL-Get-Str data "BP_BRACING_EXT")
        intType (MSPL-Get-Str data "BP_BRACING_INT"))
  ;; An OPEN CANOPY (BF/CC/PP) has no side walls and no end walls, so there is nothing to brace.
  (if (not *PEB-OPEN-CANOPY*)
    (progn
      (vl-catch-all-apply (function (lambda () (peb-draw-bracing bayPts widthPts wid 0.0 0.0 lewBrace rewBrace extType intType))))
      ;; End-wall column bracing (owner 5-Jul): X-bracing between the end-wall columns in the LEW/REW planes,
      ;; same braced-panel rule as the bays, gated by lewBrace/rewBrace, exterior type.
      (vl-catch-all-apply (function (lambda () (peb-draw-endwall-bracing ewStations leftX rightX lewBrace rewBrace extType))))))

  ;; ── Doors / windows at their offsets (+ braced-bay clash flag) ─
  (vl-catch-all-apply (function (lambda () (peb-draw-placements data 0.0 0.0 len wid bayPts))))

  ;; ── Overlaid IF components (canopy, mezzanine, crane, roof-ext, …) — owner 6-Jul ──
  (vl-catch-all-apply (function (lambda () (peb-draw-components data len wid))))

  ;; (Anchor-bolt base-plate schedule removed — this is the COLUMN LAYOUT PLAN;
  ;;  columns show the I-section with their typical 4 anchor bolts, no schedule.)

  ;; ── FALL glyphs (owner 4-Jul; unified 7-Jul) ──────────────────
  ;; MAX 2-3 fall symbols, snapped to unbraced bays, autosized — now via the SHARED routine so the
  ;; Column Layout Plan and the Roof Plan draw the SAME glyph set. (See peb-fall-glyph-set.)
  (peb-fall-glyph-set data stype len wid bayPts mgRidgePts mgGableW)

  ;; ── Wall labels ───────────────────────────────────────────────
  ;; Phase-2A v12: pushed FSW/NSW further from building (was 2800,
  ;; now 4500) to clear the bay+overall dim chain underneath.
  (setvar "CLAYER" "TEXT")
  ;; owner 4-Jul: wall labels are SIMPLE — the full name only, no open-wall condition suffix.
  ;; owner 5-Jul (multi-area): drop the wall label on the side SHARED with an attached area (avoids the
  ;; label piling onto the reference area at the join).
  ;; owner 5-Jul (multi-area): in multi-area mode NO area draws the outer wall labels — the FINALIZE draws
  ;; the four labels ONCE around the whole combined building, so they never repeat per stacked/side area.
  ;; owner 9-Jul: an OPEN CANOPY has no walls at all, so it gets none of the four wall labels.
  (if (and (not *PEB-MULTI-MODE*) (not *PEB-OPEN-CANOPY*) (not (peb-hide-wall-label-p "FSW"))) (txt-bold "MC" (list (/ len 2.0) yFsw) (peb-th 'SMALL) 0 "FSW - FAR SIDE WALL"))
  (if (and (not *PEB-MULTI-MODE*) (not *PEB-OPEN-CANOPY*) (not (peb-hide-wall-label-p "NSW"))) (txt-bold "MC" (list (/ len 2.0) (- (* 3000 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "NSW - NEAR SIDE WALL"))
  ;; owner 4-Jul: LEW label sits OUTSIDE the letter bubbles (was sandwiched between the width dims and
  ;; the bubbles -> overlapped the dim text). REW side has no dims/bubbles, so it stays close.
  (if (and (not *PEB-MULTI-MODE*) (not *PEB-OPEN-CANOPY*) (not (peb-hide-wall-label-p "LEW"))) (txt-bold "MC" (list (- gridX1 (* (- bubRowsY 1) bubStep) (* 2200.0 *PEB-DIM-SCALE*)) (/ wid 2.0)) (peb-th 'SMALL) 90 "LEW - LEFT END WALL"))
  (if (and (not *PEB-MULTI-MODE*) (not *PEB-OPEN-CANOPY*) (not (peb-hide-wall-label-p "REW"))) (txt-bold "MC" (list (+ len (* 3000 *PEB-DIM-SCALE*)) (/ wid 2.0)) (peb-th 'SMALL) 90 "REW - RIGHT END WALL"))

  ;; ── End-frame type MLEADERs (Phase-2A v12) ─────────────────────
  ;; Replaces the old "END FRAME" / "BEARING FRAME (TYP.)" txt labels.
  ;; Reads BP_EW_LEFT_FRAME and BP_EW_RIGHT_FRAME from Excel.
  ;; If both ends are the SAME type → single MLEADER pointing at the
  ;; left end frame with "<TYPE> / BOTH ENDS" two-line text.
  ;; If different → two separate MLEADERs, one per end.
  (setq lewFrameRaw (strcase (MSPL-Get-Str data "EW_LEFT_FRAME")))
  (setq rewFrameRaw (strcase (MSPL-Get-Str data "EW_RIGHT_FRAME")))
  ;; Normalise — accept "MAIN FRAME" or "RIGID" as MAIN; everything
  ;; else (incl. blank, "BEARING", "BEARING FRAME") = BEARING FRAME.
  ;; "Main Frame with Hanging Columns" is labelled "MAIN FRAME - HANGING COLUMNS" (owner 28-Jul: NO "MLADDER"
  ;; word — show the plain HANGING COLUMNS text). "Main Frame"/"Rigid" stay MAIN FRAME; else BEARING FRAME.
  (setq lewFrameLabel
    (cond ((wcmatch lewFrameRaw "*HANGING*") "MAIN FRAME - HANGING COLUMNS")
          ((or (= lewFrameRaw "MAIN FRAME") (= lewFrameRaw "RIGID")) "MAIN FRAME")
          (T "BEARING FRAME")))
  (setq rewFrameLabel
    (cond ((wcmatch rewFrameRaw "*HANGING*") "MAIN FRAME - HANGING COLUMNS")
          ((or (= rewFrameRaw "MAIN FRAME") (= rewFrameRaw "RIGID")) "MAIN FRAME")
          (T "BEARING FRAME")))
  ;; Clear BEARING/MAIN FRAME word on BOTH end walls (owner requirement) — placed
  ;; beside the LEW/REW wall labels.  (If an end is a Main Frame, its corner
  ;; columns are already drawn lengthwise = interior main-frame size/direction.)
  (setvar "CLAYER" "TEXT")
  ;; owner 5-Jul (multi-area): drop the per-end frame-type words + the BOTH-ENDS leader in multi-area — they
  ;; repeat per stacked area and overprint the width dims.  (Single-area draws them normally.)
  ;; owner 9-Jul: an OPEN CANOPY has no end WALLS, so it has no end FRAMES to name either -- the
  ;; "(BEARING FRAME)" words and the "BEARING FRAME / BOTH ENDS" leader are suppressed for BF/CC/PP.
  (if (and (not *PEB-MULTI-MODE*) (not *PEB-OPEN-CANOPY*) (not (peb-hide-wall-label-p "LEW"))) (txt-bold "MC" (list (- gridX1 (* (- bubRowsY 1) bubStep) (* 4400.0 *PEB-DIM-SCALE*)) (/ wid 2.0)) (peb-th 'SMALL) 90 (if (wcmatch lewFrameLabel "*(*") lewFrameLabel (strcat "(" lewFrameLabel ")"))))
  (if (and (not *PEB-MULTI-MODE*) (not *PEB-OPEN-CANOPY*) (not (peb-hide-wall-label-p "REW"))) (txt-bold "MC" (list (+ len (* 4500 *PEB-DIM-SCALE*)) (/ wid 2.0)) (peb-th 'SMALL) 90 (if (wcmatch rewFrameLabel "*(*") rewFrameLabel (strcat "(" rewFrameLabel ")"))))
  (if (and (not *PEB-MULTI-MODE*) (not *PEB-OPEN-CANOPY*))
  (cond
    ;; Both ends same → ONE MLEADER, "BEARING FRAME / BOTH ENDS"
    ((= lewFrameLabel rewFrameLabel)
      (vl-catch-all-apply
        (function (lambda ()
          (peb-label-with-leader
            (if (= lewFrameLabel "MAIN FRAME") "MAIN FRAME\\P(HALF BAY LOADING)"
                (strcat lewFrameLabel "\\PBOTH ENDS"))               ; owner 4-Jul: sync w/ IF, 2 rows
            ;; owner 5-Jul moved this RIGHT from -4500*DS to -1500*DS; at -1500 it still sat
            ;; over the vertical BUILDING WIDTH dim text, which runs up the left margin.
            ;; Moving it INSIDE (2600*DS, wid + 2200*TS) then put it straight on the TOP dim
            ;; stack instead: yBayDim = wid + 1050*DS and yOvrDim = wid + 2100*DS, so
            ;; wid + 2200*TS lands on the BUILDING LENGTH chain (owner 27-Aug audit, B-03
            ;; sheet 1 of 2 — the label printed through "BUILDING LENGTH : 65,091").
            ;;
            ;; The dim chains are CENTRED on the building length, so their text never reaches
            ;; the far LEFT; and the width chains live at y in [0,wid], so nothing but a
            ;; witness line crosses y > wid out there.  That corner — outside-left, above the
            ;; FSW line — is the one lane clear at every building size.  The leader still
            ;; points at (0,wid), so it reads as belonging to the LEW frame.
            (list (- (* 6000 *PEB-DIM-SCALE*))
                  (+ wid (* 2600 *PEB-TEXT-SCALE*)))
            (list 0 wid)                                              ; arrow points AT the LEW frame
            "S" 430.0)))))                                            ; owner 5-Jul: smaller (was 600)
    ;; Different → TWO MLEADERs
    (T
      (vl-catch-all-apply
        (function (lambda ()
          (peb-label-with-leader lewFrameLabel
                                 (list (- (* 4500 *PEB-DIM-SCALE*))
                                       (+ wid (* 2800 *PEB-TEXT-SCALE*)))
                                 (list 0 wid)
                                 "S" 600.0))))
      (vl-catch-all-apply
        (function (lambda ()
          (peb-label-with-leader rewFrameLabel
                                 (list (+ len (* 4500 *PEB-DIM-SCALE*))
                                       (+ wid (* 2800 *PEB-TEXT-SCALE*)))
                                 (list len wid)
                                 "S" 600.0)))))))   ; extra ) closes the (if (not *PEB-MULTI-MODE*) around the cond

  ;; ── Dimensions (Phase-2A v3 — Mammut-style group format) ─────
  ;; Bays + widths now grouped by runs of equal spacing.  A group of N
  ;; identical bays at spacing S renders as "<N×S> = N @ S" inside the
  ;; dim text, instead of N separate dims.  Singleton bays render their
  ;; raw length only.  Overall dim still spans full length / width.
  ;;
  ;; Implementation: peb-group-equal-spans walks bayPts / widthPts and
  ;; returns (startX endX count spacing) tuples; we draw one
  ;; peb-dim-h-stretch per group with override text via peb-fmt-group.

  ;; Length By-Flush only when BOTH end walls' girts are Flush; else By-Framed (owner 4-Jul).
  (setq *PEB-EW-BYFLUSH*
        (and (wcmatch (strcase (MSPL-Get-Str data "BP_EW_LEFT_GIRTS"))  "*FLUSH*")
             (wcmatch (strcase (MSPL-Get-Str data "BP_EW_RIGHT_GIRTS")) "*FLUSH*")))
  (setq lref (peb-tb-or (MSPL-Get-Str data "LENGTH_REF") (MSPL-Get-Str data "BAY_REF")))
  (setq ldim (peb-basis-dim lref 'L len leftX))     ; drawnHalf = leftX (drawn end-column centre)
  ;; HORIZONTAL (bay) chain — ONE dim MIRRORING the IF bay expression + basis; NO total (the total is
  ;; the overall length dim). Arrows on the drawn web centre (nth 3/4). Owner 4-Jul.
  ;; owner 5-Jul (multi-area): the top LENGTH dims sit on the FSW side — skip them when FSW is the shared
  ;; wall (attached area's omit OR the reference's shared side), so they don't land at the internal join.
  (if (not (peb-hide-wall-label-p "FSW"))
    (progn
      (peb-dim-h-stretch (nth 3 ldim) (+ len (nth 4 ldim)) yBayDim
                         (strcat (peb-chain-text (MSPL-Get-Str data "BAYEXPR") bayPts) " " (peb-basis-suffix lref)))
      (peb-recolor-last-dim 0)              ; ByBlock
      ;; Overall length dim — real VALUE (nth 0); witness/arrows on the DRAWN plane (nth 3/4).
      (peb-dim-h-stretch (nth 3 ldim) (+ len (nth 4 ldim)) yOvrDim
                         (peb-fmt-labelled "BUILDING LENGTH" (nth 0 ldim) (peb-basis-suffix lref)))
      (peb-recolor-last-dim 0)))                   ; ByBlock for overall length

  ;; ── WIDTH DIMENSIONS: 3 NESTED CHAINS (owner 4-Jul) ─────────────────────────────
  ;;   most RIGHT (REW)  : END-WALL COLUMN SPACING  (finest — every end-wall post)
  ;;   next LEFT (LEW in): WIDTH MODULE             (main-frame interior modules)
  ;;   most LEFT (LEW out): OVERALL WIDTH           (total)
  ;; All GROUPED "N @ S = total" + the O/O / C/C basis on EVERY chain (owner 4-Jul).
  (setq wmSuffix (peb-basis-suffix (peb-tb-or (MSPL-Get-Str data "WIDTH_MOD_REF")
                                              (MSPL-Get-Str data "WIDTH_REF"))))
  (setq wref (peb-tb-or (MSPL-Get-Str data "WIDTH_REF") (MSPL-Get-Str data "WIDTH_MOD_REF")))
  (setq wdim (peb-basis-dim wref 'W wid colOff))    ; drawnHalf = colOff (drawn side-wall web centre)
  ;; ALL width dims on the LEFT (LEW), nested; NO dimension on the Right End Wall (owner 4-Jul).
  ;; owner 5-Jul (multi-area): skip the whole LEW width-dim stack when LEW is the shared end wall
  ;; (Left/Right side-by-side) — the outer area carries the one width dimension.
  (if (not (peb-hide-wall-label-p "LEW"))
   (progn
  ;; (1) END-WALL COLUMN SPACING — LEW innermost (-1200); ONE dim MIRRORING the IF EW expression +
  ;; basis, no total. Arrows on the drawn web centre (nth 3/4).
  (peb-dim-height-stretch 0.0 (- dimGap) (nth 3 wdim) (+ wid (nth 4 wdim))
                          (strcat (peb-chain-text (MSPL-Get-Str data "EWLEXPR") ewStations) " " wmSuffix))
  (peb-recolor-last-dim 0)                 ; LEW end-wall column spacing (innermost)
  ;; (2) WIDTH MODULE — LEW middle (-3000). ONE dim MIRRORING the IF module expression + basis, no total.
  (if (> (length widthPts) 2)
    (progn
      (peb-dim-height-stretch 0.0 (- (* 2.0 dimGap)) (nth 3 wdim) (+ wid (nth 4 wdim))
                              (strcat (peb-chain-text (MSPL-Get-Str data "MODEXPR") widthPts) " " wmSuffix))
      (peb-recolor-last-dim 0)))              ; LEW width module (middle)
  ;; (3) OVERALL WIDTH — LEW outermost (-4800). Real VALUE (nth 0); witness on the DRAWN plane (nth 3/4).
  (peb-dim-height-stretch 0.0 (- (* 3.0 dimGap)) (nth 3 wdim) (+ wid (nth 4 wdim))
                          (peb-fmt-labelled "BUILDING WIDTH" (nth 0 wdim) (peb-basis-suffix wref)))
  (peb-recolor-last-dim 0)))                    ; LEW overall width (outermost)

  ;; ── Title (Phase-2A: compact dim × dim with area) ────────────
  ;;   Line 1: COLUMN LAYOUT PLAN
  ;;   Line 2: 20×40 m  |  800 m²  |  5 BAYS  |  SLOPE 1:10  |  CLEAR SPAN GABLE
  (setvar "CLAYER" "TEXT")
  ;; Read clear height once for the subtitle banner
  (setq clearH (MSPL-Get-Num data "CLEARHEIGHT"))
  (if (or (null clearH) (<= clearH 0))
    (setq clearH (MSPL-Get-Num data "EAVE_HEIGHT")))

  ;; Phase-2A v13: title + subtitle pushed higher so FSW label
  ;; (at wid + 4500*TS) sits cleanly between subtitle and overall dim.
  ;; Vertical stack from building top:
  ;;   Bay dim chain      → wid + 900 * DS
  ;;   Overall length dim → wid + 2400 * DS
  ;;   FSW label          → wid + 4500 * TS
  ;;   Subtitle           → wid + 6000 * TS
  ;; BIG "COLUMN LAYOUT PLAN" heading at the very top centre (owner: restore it),
  ;; with the compact dim/area/bays/slope info banner below it.
  ;; owner 5-Jul (multi-area): in multi-area NO area draws the big title/spec-banner/north-arrow — the
  ;; FINALIZE pass (peb-draw-combined-frame) draws ONE title at the true combined top, so it's correct for
  ;; ANY direction (Below/Above/Left/Right), not only when the reference sits on top.  Each area still draws
  ;; its own AREA No. tag + dims.  (Single-area: *PEB-MULTI-MODE* nil, draws normally.)
  ;; MATCH LINE on whichever edge of this part is a cut (owner 27-Aug).  The plan is not
  ;; mirrored — grid 1 is always drawn on the left — so the low-grid end is the left edge
  ;; and the high-grid end the right, with no view-direction swap to handle.
  (if prng
    (progn
      (if (> pi0 0)
        (peb-match-line 0.0 (- (* 900.0 *PEB-DIM-SCALE*)) (+ wid (* 900.0 *PEB-DIM-SCALE*))
                        (itoa (1- *PEB-PART-P*))))
      (if (< pi1 (1- pnTot))
        (peb-match-line len (- (* 900.0 *PEB-DIM-SCALE*)) (+ wid (* 900.0 *PEB-DIM-SCALE*))
                        (itoa (1+ *PEB-PART-P*))))))

  (if (not *PEB-MULTI-MODE*)
    (progn
      (setvar "CECOLOR" "5")   ; owner 7-Jul (Mammut mirror): the main title is BLUE
      (txt-bold "MC" (list (/ len 2.0) yTtl) (peb-th 'ANNOT) 0 (peb-part-title "COLUMN LAY-OUT PLAN"))
      (setvar "CECOLOR" "BYLAYER")
      ;; Subtitle drawn directly (not via txt) so the multiplication stays a SMALL "x": uppercase the whole
      ;; line per the owner rule, then restore the spaced "×" to a lowercase x. romand.shx has no × or ²
      ;; glyph (they render "?"), so we use "x" and "m2". (owner 23-Jul)
      (progn
        (setvar "TEXTSTYLE" "PEB-BODY")
        (command "TEXT" "J" "MC" (list (/ len 2.0) ySub) (* 560 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0
          (vl-string-subst " x " " X "
            (strcase
              ;; SUBTITLE STAYS IN METRES (owner 26-Aug): the mm-only rule 4B.14 governs
              ;; DIMENSIONS.  This line is a descriptive summary of the building — size,
              ;; area, bays, slope — not a dimension on the drawing, so "122 x 30 m"
              ;; beside "3,716 m2" is the right register and reads far better than
              ;; "121,920 x 30,480".  Briefly converted to mm; reverted on the owner's call.
              (strcat (rtos (/ pFullLen 1000.0) 2 0) " x "
                      (rtos (/ wid 1000.0) 2 0) " m"
                      "  |  " (peb-comma (rtos areaM2 2 0)) " m2"
                      "  |  " (itoa pFullBays) " BAYS"
                      "  |  SLOPE " roofSlope
                      (if (and clearH (> clearH 0))
                        (strcat "  |  C.H = " (peb-comma (rtos clearH 2 0)))   ; owner 5-Jul: comma-grouped (10,670)
                        "")
                      "  |  " (peb-structure-label stype)
                      (if (= stype "MG")
                        (strcat "  |  " (itoa mgGables) " GABLES — " mgSpanDesc)
                        ""))))))
      (draw-north-arrow (+ len (* 3000 *PEB-DIM-SCALE*)) (+ wid (* 4200 *PEB-DIM-SCALE*)))))

  ;; CLEAR HEIGHT moved to the subtitle banner above (Phase-2A v7).
  ;; For multi-area plans, per-area C.H. callouts will be re-introduced
  ;; inside each AREA box via the AR_POSITION dispatcher.

  ;; PROPOSAL DRAWING corner stamp removed per user (Phase-2A v13).

  ;; ── Title block as ONE AcDbTable entity (Section-parity) ───────
  ;; Replaces the legacy hand-rolled lines/text title block with a
  ;; single AcDbTable.  Six columns, header row + 7 body rows, with
  ;; the non-project columns merged through rows 1-7 so each holds
  ;; ONE tall cell of multi-line text via "\\P" breaks.
  ;;
  ;; tbW auto-widens for narrow plans (min 35 m) and caps at 80 m so
  ;; cells stay readable on big plans.  tbScale uniformly scales row
  ;; heights and text inside the block.  Plan's title block sits
  ;; BELOW the building (negative Y), unlike Section which sits below
  ;; the section AT negative Y as well — same coordinate scheme.
  (setq tbW     (max 35000.0 (min len 80000.0)))
  (setq tbScale (/ tbW 35000.0))
  (setq tbXShift (/ (- tbW len) 2.0))
  (setq c0 (- 0.0 tbXShift)
        c1 (+ c0 (* tbW 0.14))
        c2 (+ c0 (* tbW 0.30))
        c3 (+ c0 (* tbW 0.45))
        c4 (+ c0 (* tbW 0.62))
        c5 (+ c0 (* tbW 0.85))
        c6 (+ c0 tbW))
  ;; Title-block top sits below the LEW overall width-dim text column
  ;; (which extends down from y=0 in width-dim text rotation).  Keep
  ;; clear of the bottom-of-building edge.
  (setq tbTop (min -5200.0
                   (- 0.0 (* 5500.0 *PEB-DIM-SCALE*))))
  (setq tbBot   (- tbTop (* 4800.0 tbScale)))

  ;; Save and override scales so all text inside the title block uses
  ;; tbScale (matches Section).  Restored after the table is built.
  (setq *PEB-OLD-TEXT-SCALE* *PEB-TEXT-SCALE*)
  (setq *PEB-OLD-DIM-SCALE*  *PEB-DIM-SCALE*)
  ;; (scale override removed — the Mammut title block is self-contained &
  ;;  DYNAMIC: every size derives from the strip height H, not *PEB-*-SCALE*.)

  ;; Border edges first — table is sized to span borderL..borderR so
  ;; bottom of table coincides with borderB (flush against border).
  ;; owner 4-Jul STRICT RULE: ALL drawings + labels MUST fit inside the border, and the plan is CENTRED
  ;; (equal side margins). bMarg = symmetric side margin, past the far LEW frame label (gridX1-3000*DS =
  ;; -(9000*DS + BUBRAD)); use 10500*DS + BUBRAD so there is a clear margin beyond it on BOTH sides.
  ;; 4B.31: the letter bubbles may be staggered outward, and the LEW labels move out with
  ;; them, so the margin has to clear the WHOLE row stack — not just row 0.
  (setq bMarg (+ (* 10500.0 *PEB-DIM-SCALE*) *PEB-BUBRAD* (* (- bubRowsY 1) bubStep)))
  (setq borderL (- 0.0 bMarg))
  (setq borderR (max (+ len bMarg) (+ c6 (* 800 *PEB-TEXT-SCALE*))))
  (setq borderT (+ yFrmTop (* 400.0 *PEB-TEXT-SCALE*)))

  ;; Heights — same as Section (175 / 225, halved from earlier).
  (setq tblHeaderH  (* 175 tbScale))
  (setq tblBodyRowH (* 225 tbScale))
  (setq tblBodyH    (* tblBodyRowH 7))
  (setq tblTotalH   (+ tblHeaderH tblBodyH))
  (setq borderB     (- tbTop tblTotalH))
  ;; Stretch column widths so they sum to (borderR - borderL) instead
  ;; of (c6 - c0) — table edge-to-edge with the border.
  (setq tblScaleX (/ (- borderR borderL) (- c6 c0)))
  (setq tblColWs (list (* tblScaleX (- c1 c0))
                       (* tblScaleX (- c2 c1))
                       (* tblScaleX (- c3 c2))
                       (* tblScaleX (- c4 c3))
                       (* tblScaleX (- c5 c4))
                       (* tblScaleX (- c6 c5))))
  ;; --- Header row text (column titles) ---------------------------
  (setq tblHeaders
    (list "GENERAL NOTES"
          "BUILDING ACCESSORIES"
          "BUILDING DESIGN LOADS"
          "BUILDING DESIGN CODES"
          "PROJECT INFORMATION"
          "MAIMAAR STEEL Pvt. Ltd."))
  ;; --- Multi-line content for the merged columns ---
  (setq genNotesText
    (strcat
      "1. ALL DIMENSIONS ARE IN MM.\\P"
      "2. THIS IS PROPOSAL DRAWING ONLY.\\P"
      "3. NOT FOR CONSTRUCTION.\\P"
      "4. THIS DRAWING IS NOT TO SCALE.\\P"
      "5. ALL STEELWORK SHALL BE AS PER\\P"
      "    APPROVED FABRICATION DRAWINGS."))
  (setq accessoriesText
    (strcat
      "ROOF CLADDING:\\P"
      "    AS PER PROJECT REQUIREMENT\\P"
      "WALL CLADDING:\\P"
      "    AS PER PROJECT REQUIREMENT\\P"
      "RIDGE / TRIM / FLASHING:\\P"
      "    AS PER PROPOSAL SCOPE"))
  (setq loadsText
    (strcat
      "LIVE LOAD = AS PER DESIGN CODE\\P"
      "WIND SPEED = " (format-wind-speed windspeed) "\\P"
      "EXPOSURE = " exposure "\\P"
      "COLLATERAL LOAD = " collateral "\\P"
      "ROOF SLOPE = " roofSlope "\\P"
      "SEISMIC ZONE = AS PER SITE"))
  (setq codesText
    (strcat
      "DESIGN CODE: AISC / ASD\\P"
      "LOAD APPLICATION: MBMA\\P"
      "COLD FORMED: AISI\\P"
      "WELD CODE: AWS D1.1\\P"
      "BOLT GRADE: ASTM A325\\P"
      "DESIGN BASIS TO BE CONFIRMED."))
  (setq maimaarText
    (strcat
      "{\\Fromand.shx;MAIMAAR STEEL Pvt. Ltd.}\\P"
      "238, First Floor, Lalazar Commercial\\P"
      "Area, Raiwind Road, Lahore, Pakistan\\P"
      "Web: www.maimaargroup.com\\P"
      "nasir.abbas@maimaargroup.com\\P"
      "maimaar.steel@gmail.com\\P"
      "Cell: +(92-300) 807 4007, +(92-333) 807 1115"))   ; R2: condensed to 7 lines
  ;; PROJECT INFORMATION — 7 separate cells (one per body row).
  ;; Row 6 carries the drawing title; row 7 the sheet number.
  (setq projInfoRows
    (list
      (strcat "QUOTE NO.: " propno)
      (strcat "BLDG. NAME: " project)
      (strcat "CLIENT: " client)
      (strcat "REV: " revno "    DRN: M.H    CHK: YEA")
      (strcat "DATE: " fulldate "    BLDG NO.: " bldgno)
      "{\\Fromand.shx;COLUMN LAYOUT & ANCHOR BOLT PLAN}"
      "SHEET NO.  PRO-01"))
  ;; Body matrix: 7 rows × 6 cols.  Row 1 (the first body row) has
  ;; the merged-column content; subsequent rows for non-project cols
  ;; are empty (those cells get merged into row 1 below).
  (setq tblBodies
    (list
      (list genNotesText accessoriesText loadsText codesText
            (nth 0 projInfoRows) maimaarText)
      (list "" "" "" "" (nth 1 projInfoRows) "")
      (list "" "" "" "" (nth 2 projInfoRows) "")
      (list "" "" "" "" (nth 3 projInfoRows) "")
      (list "" "" "" "" (nth 4 projInfoRows) "")
      (list "" "" "" "" (nth 5 projInfoRows) "")
      (list "" "" "" "" (nth 6 projInfoRows) "")))
  ;; Merge cols 0,1,2,3,5 across rows 1-7.  PROJECT INFORMATION (col 4)
  ;; intentionally NOT merged — keeps its 7 separate cells.
  (setq tblMerges
    (list
      (list 1 7 0 0)
      (list 1 7 1 1)
      (list 1 7 2 2)
      (list 1 7 3 3)
      (list 1 7 5 5)))
  ;; R1: derive the BODY text height from the tallest merged cell so nothing
  ;; clips.  maxLines = largest line-count across the multi-line body cells
  ;; (and the 7 PROJECT-INFO rows).  LSF 1.4 = AcDbTable cell line spacing.
  (setq maxBodyLines (max (peb-nlines genNotesText) (peb-nlines accessoriesText)
                          (peb-nlines loadsText)     (peb-nlines codesText)
                          (peb-nlines maimaarText)   (length projInfoRows)))
  (setq bodyTxtH (/ tblBodyH (* maxBodyLines 1.4)))
  ;; ── Mammut-style vertical title block on the RIGHT (replaces the old
  ;;    bottom AcDbTable).  Building stays on the left; the strip is a tall
  ;;    panel on the right edge, full frame height.  DYNAMIC: strip width is
  ;;    derived from the frame height, and every internal size from H. ────
  (setvar "CLAYER" "TEXT")
  ;; building-area extents (margins for dims + LEW/REW labels)
  (setq tbBldgL (- (* 6500.0 *PEB-DIM-SCALE*)))               ; left margin
  (setq tbBldgR (+ len (* 6800.0 *PEB-DIM-SCALE*)))           ; right of REW label
  (setq tbFrmT  yFrmTop)          ; RULE: frame top from the flexible stack (title always inside the border)
  (setq tbFrmB  (min -5200.0 (- 0.0 (* 6000.0 *PEB-DIM-SCALE*)))) ; below NSW label
  ;; strip geometry
  (setq tbStripH (- tbFrmT tbFrmB))
  (setq tbStripW (max (* len 0.24)                            ; not too thin
                      (min (* tbStripH 0.46)                  ; Mammut-ish aspect
                           (* len 0.46))))                    ; not too dominant
  (setq tbStripX (+ tbBldgR (* 1800.0 *PEB-DIM-SCALE*)))      ; gap right of building
  ;; --- clean field values (fix the doubled-year quote no.; pad bldg no.) ---
  ;; propinput may arrive as "YYNNN" (e.g. "26172"); propno then doubles the
  ;; year ("MSPL-26-26172").  Detect a 5-digit YY-prefixed code and re-form it
  ;; as MSPL-YY-NNN; otherwise the normal propno (MSPL-26-NNN) is already right.
  ;; QUOTE: prefer the IF's full proposal no.; else re-form the digits-only code.
  (setq tbQuote (MSPL-Get-Str data "PROPOSAL_FULL"))
  (if (= tbQuote "")
    (cond
      ((and (= (strlen propinput) 5) (wcmatch propinput "#####"))
       (setq tbQuote (strcat "MSPL-" (substr propinput 1 2) "-" (substr propinput 3))))
      (T (setq tbQuote propno))))
  (setq tbBno bldgno)
  (if (= (strlen tbBno) 1) (setq tbBno (strcat "0" tbBno)))
  (setq tbDrn (MSPL-Get-Str data "TBDRN"))
  (if (= tbDrn "") (setq tbDrn "M.H"))
  (setq tbChk (MSPL-Get-Str data "TBCHK"))
  (if (= tbChk "") (setq tbChk "YEA"))
  (setq tbBname (MSPL-Get-Str data "TBBLDGNAME"))
  ;; DATE linked to the IF (HD_DATE, dd/mm/yyyy) — prettified; else system date
  (setq tbDate (MSPL-Get-Str data "TBDATE"))
  (if (= tbDate "") (setq tbDate fulldate) (setq tbDate (peb-pretty-date tbDate)))
  ;; field data from the IF
  (setq tbData
    (list
      (cons "REV"  (if (= revno "0") "00" revno))
      (cons "DATE" tbDate)
      (cons "DRN"  tbDrn) (cons "CHK" tbChk)
      ;; --- design loads + code: linked DIRECTLY to the IF (blank -> default) ---
      (cons "LL_ROOF"  (peb-tb-or (MSPL-Get-Str data "LIVEROOF")  "0.57"))
      (cons "LL_FRAME" (peb-tb-or (MSPL-Get-Str data "LIVEFRAME") "0.57"))
      (cons "WIND"     (if (= windspeed "") "AS PER CODE" (peb-num-only windspeed)))
      (cons "EXPOSURE" (peb-tb-or exposure "B"))
      (cons "COLL"     (if (= collateral "") "0.0" (peb-num-only collateral)))
      (cons "SNOW"     (peb-tb-snow (MSPL-Get-Str data "SNOW")))
      (cons "SEISMIC"  (peb-tb-zone (MSPL-Get-Str data "SEISMIC")))
      (cons "TEMP"     (peb-tb-snow (MSPL-Get-Str data "TEMP")))
      (cons "RAIN"     (peb-tb-or   (MSPL-Get-Str data "RAIN") "-"))
      (cons "CODE"     (peb-tb-or (MSPL-Get-Str data "DESIGNCODE") "MBMA 2006"))
      (cons "PROJECT"  project)
      (cons "CUSTOMER" client)
      (cons "ADDR"
        (strcat "Lahore Office\\P"
                "238, First Floor, Lalazar Commercial Area,\\P"
                "Raiwind Road, Lahore, Pakistan\\P"
                "Web: www.maimaargroup.com\\P"
                "Cell : +(92-300) 807 4007"))
      (cons "QUOTE"     tbQuote)
      (cons "BLDGNO"    tbBno)
      (cons "BLDGNAME"  tbBname)
      (cons "IDENTICAL" (peb-tb-or (MSPL-Get-Str data "IDENTICAL") "1"))
      (cons "DRGTITLE"  "COLUMN LAYOUT PLAN")
      (cons "SCALE"     "N.T.S.")
      (cons "SHEETSIZE" "A1")
      (cons "SHEETNO"   (strcat "PRO-" tbBno))))
  ;; (The title block is drawn in the BORDER block below — sized to FILL the right side flush to the
  ;;  border, no gap on 3 sides.  owner 5-Jul.  *PEB-SUPPRESS-TB* still governs multi-area suppression.)

  ;; Restore drawing scales (title block done)
  (setq *PEB-TEXT-SCALE* *PEB-OLD-TEXT-SCALE*)
  (setq *PEB-DIM-SCALE*  *PEB-OLD-DIM-SCALE*)

  ;; ── Border + AUTO-FILL title block (owner 5-Jul: the title panel FILLS the right side with NO gap on
  ;; 3 sides, like the Cover table).  Order matters: grab the BUILDING-zone extents FIRST (title block not
  ;; yet drawn) so the border top/left/bottom come from the plan + one uniform margin; then draw the title
  ;; panel as a FULL-BORDER-HEIGHT strip on the right whose right edge IS the right border (flush).
  ;; peb-titleblock-mammut is fully proportional to (W,H) so it auto-scales to fill — no separate resize.
  (setq bGap (max (* 3000.0 *PEB-DIM-SCALE*) *PEB-BUBRAD*))
  (vl-catch-all-apply (function (lambda () (command "_.ZOOM" "_E"))))
  (setq exmin (getvar "EXTMIN") exmax (getvar "EXTMAX"))
  (setq borderL (- (car  exmin) bGap)
        borderB (- (cadr exmin) bGap)
        borderT (+ (cadr exmax) bGap))
  ;; owner 5-Jul: AUTO-FIT the title-block strip to the SHEET HEIGHT at a constant aspect (0.30) so it fits
  ;; ANY building size without distortion (was 0.24*length — absurdly wide for long buildings).  Matches the
  ;; approved 195 look (its 36573 strip = 0.305 * 119818 sheet height).
  ;; owner 22-Jul: FLOOR the strip width (like the Section, Section.lsp:9068) so the title-block notes/values
  ;; never wrap/overlap on a short-but-wide plan (this 40x20 gave 0.30*height ~ 7800 -> notes wrapped into the
  ;; disclaimer, date overran the rev cell).  max(10000, 0.26*width, 0.30*height) keeps tall buildings unchanged.
  (setq tbStripW (max 10000.0 (* wid 0.26) (* (- borderT borderB) 0.30)))
  (setq tbStripX (+ (car exmax) (* 3500.0 *PEB-DIM-SCALE*))   ; gap right of the building content
        borderR  (+ tbStripX tbStripW))                       ; right border = panel right edge (no gap)
  ;; owner 5-Jul (multi-area): publish this area's drawn size, frame params and attach info so the
  ;; orchestrator (peb-plan-multi-from-files) can place areas by their LOGICAL dimensions and draw ONE
  ;; shared border + title block around the whole set (each area suppresses its own via *PEB-SUPPRESS-TB*).
  (setq *PEB-MA-WID* wid *PEB-MA-LEN* len
        *PEB-MA-TBDATA* tbData *PEB-MA-TBSTRIPW* tbStripW *PEB-MA-BGAP* bGap
        *PEB-MA-SHEETH* (- borderT borderB)   ; this area's own sheet height (for a constant combined title block)
        *PEB-MA-WGRID-N* nWid *PEB-MA-LGRID-N* (length bayPts)   ; owner 5-Jul: grid counts for cross-area letter/number continuity
        *PEB-AR-NUM* (MSPL-Get-Int data "AREA_NUM")
        *PEB-AR-POS* (MSPL-Get-Str data "AR_POSITION")
        *PEB-AR-REF* (MSPL-Get-Int data "AR_REF_AREA")
        *PEB-AR-GAP* (MSPL-Get-Num data "AR_GAP"))
  ;; RAISED BASE (owner 29-Jul): mark the grids [from..to] bay that rests on the existing RCC building.
  (vl-catch-all-apply (function (lambda () (peb-plan-raised-zone data bayPts wid))))
  (if (not *PEB-SUPPRESS-TB*)
    (progn
      ;; owner 22-Jul: CAP the title-block CONTENT height (like the Section) so the text is sized to the strip
      ;; WIDTH, not the full (tall) sheet height — otherwise on a short-wide plan the text grows too big and the
      ;; notes wrap / date & sheet values overrun their cells.  Content fills ~2x the width; the rest is the
      ;; Mammut middle gap.  Reset to nil after so other sheets are unaffected.
      (setq *PEB-TB-SIZEH* (min (- borderT borderB) (* tbStripW 2.0)))
      (peb-titleblock-mammut tbStripX borderB tbStripW (- borderT borderB) tbData)  ; fills full height
      (setq *PEB-TB-SIZEH* nil)
      (draw-border borderL borderB borderR borderT)))

  ;; ── THE AREA TAG IS RE-ASSERTED LAST, MASKED (owner 27-Aug audit) ─────────────────
  ;; The tag is drawn early (with its drop shadow and the corner diagonals), but the GRID
  ;; and RIDGE lines are drawn AFTER it — and the tag sits at the exact centre of the plan,
  ;; which is where the ridge line and a column line run.  "AREA No. 01" therefore printed
  ;; with a line struck through it and column symbols sitting on the lettering.
  ;;
  ;; Masking it in place does nothing, because a WIPEOUT only hides what was drawn BEFORE
  ;; it.  So the box is re-drawn here, at the very end: mask first (now covering the grid
  ;; and ridge lines), then the box outline and the label on top.  The early copy stays
  ;; where it is so the diagonals still terminate on real box corners; this pass only puts
  ;; the same geometry back on top of what was laid over it.
  ;; Same technique and same catch-guard as peb-fr-masked-label (owner 29-Jul).
  (if (and aFL aFR aFB aFT aLbl)
    (vl-catch-all-apply (function (lambda ()
      (setvar "WIPEOUTFRAME" 0)
      (command "_.WIPEOUT" (list aFL aFB) (list aFR aFB) (list aFR aFT) (list aFL aFT) "")
      (aLn aFL aFB aFR aFB) (aLn aFR aFB aFR aFT)
      (aLn aFR aFT aFL aFT) (aLn aFL aFT aFL aFB)
      (setvar "CLAYER" "TEXT")
      (txt-bold "MC" (list aCx aCy) (peb-th 'SMALL) 0 aLbl)))))

  (command "UNDO" "END")
  (setvar "GRIDMODE" 0)
  (setvar "SNAPMODE" 0)
  (setvar "CMDECHO" 1)
  (command "ZOOM" "E")

  (princ (strcat "\nMAIMAAR PEB V40 COMPLETE  |  "
                 (itoa bays) " bays  |  "
                 (rtos areaM2 2 0) " m2  |  "
                 (peb-structure-label stype)))
  (princ)
)

;; ============================================================================
;; SECTION-PARITY HELPERS  (ported from PEB_Section.lsp)
;; The block below brings Plan up to parity with Section's modern helpers:
;;   * setup-maimaar-dim  -- registers the MAIMAAR-DIM dimstyle with DIMALT
;;   * peb-dim-h-native / peb-dim-v-native / peb-dim-height-native --
;;     AcDbRotatedDimension entities (grip-editable, copy/stretch-safe)
;;   * peb-build-title-table + helpers -- a real AcDbTable for title blocks
;;   * peb-make-mtext / peb-make-mleader / peb-label-* -- clean text+leader
;; The original hand-rolled dim-line-h / dim-line-v are kept intact above
;; (they ARE working for Plan). New helpers are available for selective use.
;; ============================================================================

(defun setup-maimaar-dim ( / dscale oldExpert oldLayer txtStyle saveResult)
  ;;  Register the "MAIMAAR-DIM" dimstyle.  Every native dim created via
  ;;  peb-dim-h-native / peb-dim-v-native / peb-dim-height-native uses
  ;;  this style (it's set as the active DIMSTYLE before each call).
  ;;
  ;;  Visual matches the old hand-rolled look:
  ;;    - large text (300 × DIMSCALE), large arrows (250 × DIMSCALE)
  ;;    - BYLAYER colours (DIMENSIONS layer is green)
  ;;    - mm primary + ft alternate units, dual display, stretch-safe
  ;;
  ;;  Defensive:  the DIMSTYLE _Save command is wrapped in
  ;;  vl-catch-all-apply so a stray prompt or AutoCAD quirk can't take
  ;;  down the rest of the drawing.  EXPERT and DIMSTYLE are
  ;;  saved/restored.
  (setq dscale    (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0))
  (setq oldExpert (getvar "EXPERT"))
  (setvar "EXPERT" 5)                       ; suppress all interactive prompts

  ;; Set DIM* sysvars first — these populate any newly-saved dimstyle.
  ;; Prefer Romans (clean architectural single-stroke) over default.
  ;; Create the PEB-Body text style if it doesn't already exist.
  ;; PEB-Body uses arialbd.ttf — Arial Bold TrueType — which ships
  ;; with every Windows install.  Bold gives dim numbers more visual
  ;; weight, easier to read at any zoom.  entmake writes directly into
  ;; the STYLE symbol table; failure (e.g., font not present) is caught
  ;; silently and we fall through to the next available style below.
  (vl-catch-all-apply
    (function (lambda ()
      (if (not (tblsearch "STYLE" "PEB-Body"))
        (entmake
          (list
            '(0 . "STYLE")
            '(100 . "AcDbSymbolTableRecord")
            '(100 . "AcDbTextStyleTableRecord")
            (cons 2 "PEB-Body")
            '(70 . 0)               ; standard flag
            '(40 . 0.0)              ; fixed text height (0 = not fixed)
            '(41 . 1.0)              ; width factor
            '(50 . 0.0)              ; oblique angle
            '(71 . 0)                ; generation flags
            '(42 . 2.5)              ; last height used
            (cons 3 "romand.shx")    ; primary font: ROMAND (universal rule — dims must be romand)
            (cons 4 "")              ; big-font name (none)
          ))))))
  ;; Dimension text style: forced to ROMAND below; PEB-Body is now also romand (universal rule).
  (setq txtStyle
    (cond
      ((tblsearch "STYLE" "PEB-DIM")   "PEB-DIM")
      ((tblsearch "STYLE" "PEB-Body")  "PEB-Body")
      ((tblsearch "STYLE" "TNROMAN")   "TNROMAN")
      ((tblsearch "STYLE" "tnroman")   "tnroman")
      ((tblsearch "STYLE" "Romans")    "Romans")
      ((tblsearch "STYLE" "ROMANS")    "ROMANS")
      ((tblsearch "STYLE" "PEB-DIM")   "PEB-DIM")
      (T                                "Standard")))
  ;; ── Phase-2A v4: bigger base for readable PDF print ────────────
  ;; Bumped DIMTXT 300 → 600 (Mammut-parity legibility).
  ;; Final rendered = 600 × DIMSCALE.
  ;;   50  m bldg → 600 mm at 1:120 = 5.0 mm on paper ✓
  ;;   100 m bldg → 900 mm at 1:240 = 3.8 mm on paper ✓
  ;;   200 m bldg → 1260 mm at 1:480 = 2.6 mm on paper ✓
  (setvar "DIMSCALE" (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0))
  ;; Dimension TEXT + ARROWS (owner: proper beautiful arrowheads, not ticks):
  ;;   DIMTXT 500 (clean); proper small CLOSED-FILLED arrowhead at each end,
  ;;   sitting on the dimension line (DIMTSZ 0 disables ticks; DIMBLK both ends).
  (setvar "DIMTXT"   (peb-th 'DIM))     ; ladder: 2.5 mm of paper (x DIMSCALE)
  (setvar "DIMTSZ"     0.0)        ; no ticks -> use arrowheads
  (setvar "DIMASZ"   320.0)        ; proper small arrowhead (~0.6 x text)
  (vl-catch-all-apply (function (lambda () (setvar "DIMBLK" "_CLOSEDFILLED"))))
  (vl-catch-all-apply (function (lambda () (setvar "DIMSAH" 0))))
  (setvar "DIMEXE"   120.0)        ; extension beyond dim line
  (setvar "DIMEXO"   120.0)        ; extension offset from object
  (setvar "DIMGAP"    60.0)
  (setvar "DIMTAD"      1)
  (setvar "DIMTOH"      0)
  (setvar "DIMTIH"      0)
  (setvar "DIMTOFL"     1)
  (setvar "DIMCLRD"     0)
  (setvar "DIMCLRE"     0)
  (setvar "DIMCLRT"     0)
  (setvar "DIMTXSTY"    "ROMAND")  ; owner UNIVERSAL RULE: dimension text = ROMAND (was txtStyle=Arial-bold — Plan dim drift)
  (setvar "DIMDEC"      0)
  (setvar "DIMLUNIT"    2)
  (setvar "DIMATFIT"    0)        ; keep BOTH text+arrows together (don't split them out)
  (setvar "DIMTIX"      1)        ; owner 4-Jul: force the label INSIDE the arrows (never outside)
  (setvar "DIMTMOVE"    0)
  (setvar "DIMALT"      1)
  (setvar "DIMALTF"     0.03937)         ; mm → inches
  (setvar "DIMALTRND"   1.0)              ; round to 1 inch
  (setvar "DIMALTD"     0)                ; integer inches
  (setvar "DIMALTU"     4)                ; Architectural format
  (setvar "DIMPOST"  "")                  ; no primary suffix
  (setvar "DIMAPOST" "")                  ; no extra suffix (DIMALT auto-wraps in [ ])
  ;; DIMDSEP 46 rejected on some AutoCAD builds -- catch + ignore.
  (vl-catch-all-apply (function (lambda () (setvar "DIMDSEP" 46))))

  ;; Save the style — wrapped in error catch.  Two arg-counts to handle
  ;; first-run (no existing) vs re-run (overwrite needs explicit Yes).
  (setq saveResult
    (vl-catch-all-apply
      (function (lambda ()
        (if (tblsearch "DIMSTYLE" "MAIMAAR-DIM")
          (command "_-DIMSTYLE" "_Save" "MAIMAAR-DIM" "_Yes")
          (command "_-DIMSTYLE" "_Save" "MAIMAAR-DIM"))))))

  ;; Activate it if save succeeded; otherwise keep going with whatever
  ;; dimstyle is current — the dim helpers will use that as fallback.
  (if (and (not (vl-catch-all-error-p saveResult))
           (tblsearch "DIMSTYLE" "MAIMAAR-DIM"))
    (setvar "DIMSTYLE" "MAIMAAR-DIM"))

  (setvar "EXPERT" oldExpert)
  (princ)
)

(defun peb-dim-h-native (x1 x2 y override / oldLayer dimPt)
  ;;  Native HORIZONTAL linear dimension via the DIMLINEAR command.
  ;;  AutoCAD does all the geometry-block management, so this works
  ;;  reliably across versions (entmake DIMENSION is finickier).
  ;;
  ;;  x1, x2 = X coords of the two ends being dimensioned (FFL = y=0).
  ;;  y      = Y coord of the dim line.
  ;;  override = nil → auto-measure, string → "<>" placeholder is
  ;;              substituted with the measured value at render time.
  (setq oldLayer (getvar "CLAYER"))
  (setvar "CLAYER" "DIMENSIONS")
  (setq dimPt (list (/ (+ x1 x2) 2.0) y))
  (if override
    (command "_DIMLINEAR"
             (list x1 0.0)
             (list x2 0.0)
             "_T" override
             dimPt)
    (command "_DIMLINEAR"
             (list x1 0.0)
             (list x2 0.0)
             dimPt))
  (setvar "CLAYER" oldLayer)
)


;; Counter for unique group names — incremented each time we make a group.
(setq *PEB-DIM-GROUP-COUNTER* 0)

(defun peb-fix-mleader-style-codes (stdData stdEnt arrHandle / newData)
  ;;  Try multiple DXF group code combinations for arrow handle + size
  ;;  on the AcDbMLeaderStyle.  AutoCAD versions disagree on which
  ;;  codes carry these values:
  ;;     code 342 OR 343 → arrow block handle
  ;;     code 41  OR 44  → arrow size
  ;;  We replace whichever ones already exist; for any missing ones we
  ;;  append them.  This shotgun approach hits the right code on every
  ;;  version we've seen.
  (setq newData stdData)
  ;; Arrow block handle — try both 342 and 343 group codes.
  (foreach code '(342 343)
    (setq existing (assoc code newData))
    (if existing
      (setq newData (subst (cons code arrHandle) existing newData))
      (setq newData (append newData (list (cons code arrHandle))))))
  ;; Arrow size — try both 41 and 44.
  (foreach code '(41 44)
    (setq existing (assoc code newData))
    (if existing
      (setq newData (subst (cons code 500.0) existing newData))
      (setq newData (append newData (list (cons code 500.0))))))
  (entmod newData)
  (entupd stdEnt)
)

(defun peb-setup-mleader-style (/ ndict mldictEnt mldictData stdEnt stdData
                                 arrEnt arrHandle existing)
  ;;  Fix the "Standard" multileader style so every MLEADER created
  ;;  afterwards has a visible "Closed Filled" arrowhead.
  ;;
  ;;  Three layers of fix, applied in order:
  ;;    1. Set DIMBLK sysvar to _ClosedFilled (some MLEADER builds
  ;;       inherit the dim arrow when their own block is _None).
  ;;    2. Modify the AcDbMLeaderStyle's DXF data via entmod, hitting
  ;;       multiple group code variants.
  ;;    3. Force regen so the style change propagates to any future
  ;;       MLEADER creations.
  ;;
  ;;  All wrapped in vl-catch-all-apply so missing dicts / blocks
  ;;  / unsupported sysvars never break the main script.
  ;; --- Layer 1: DIMBLK ---
  (vl-catch-all-apply
    (function (lambda () (setvar "DIMBLK" "_ClosedFilled"))))
  ;; --- Layer 2: DXF entmod on Standard MLEADERSTYLE ---
  (vl-catch-all-apply
    (function
      (lambda ()
        (setq ndict      (namedobjdict))
        (setq mldictData (dictsearch ndict "ACAD_MLEADERSTYLE"))
        (setq mldictEnt  (cdr (assoc -1 mldictData)))
        (setq stdData    (dictsearch mldictEnt "Standard"))
        (setq stdEnt     (cdr (assoc -1 stdData)))
        (setq arrEnt     (tblobjname "BLOCK_RECORD" "_ClosedFilled"))
        (setq arrHandle  (cdr (assoc 5 (entget arrEnt))))
        (peb-fix-mleader-style-codes stdData stdEnt arrHandle)
      )
    )
  )
  ;; --- Layer 3: regen ---
  (vl-catch-all-apply
    (function (lambda () (command "_.REGEN"))))
  (princ)
)

(defun peb-make-mleader (ptList text /
                          acad doc mspace pts mleader scl flat n upper i p)
  ;;  Create a native AutoCAD MLEADER (multileader) — single entity that
  ;;  contains BOTH the leader line/arrow AND the text.  Drag the arrow
  ;;  tip, the text, or the corner — they all stay connected because
  ;;  they're one object.
  ;;
  ;;  ptList = list of (x y) point pairs.  ORDER MATTERS:
  ;;            ptList[0] = arrow tip (where the arrow points to)
  ;;            ptList[n] = text landing (where the text attaches)
  ;;            intermediate points = leader vertices (for L-shapes etc)
  ;;
  ;;  Example for an L-shaped leader from text at (1000,5000) with
  ;;  corner at (3000,5000) and arrow tip at (3000,2000):
  ;;     '((3000 2000) (3000 5000) (1000 5000))
  ;;
  ;;  Returns the MLeader object on success; errors out otherwise so
  ;;  caller's vl-catch-all-apply can fall back.
  (vl-load-com)
  (setq scl    (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (setq acad   (vlax-get-acad-object))
  (setq doc    (vla-get-ActiveDocument acad))
  (setq mspace (vla-get-ModelSpace doc))
  ;; Flatten ptList into [x1 y1 0  x2 y2 0  …] for the SafeArray.
  ;; (* 1.0 x) forces int→double promotion since vlax-safearray-fill
  ;; rejects mixed-type lists in some AutoCAD builds.
  (setq flat '())
  (foreach p ptList
    (setq flat (append flat
                       (list (* 1.0 (car p))
                             (* 1.0 (cadr p))
                             0.0))))
  (setq n     (length flat))
  (setq upper (1- n))
  (setq pts   (vlax-make-safearray vlax-vbDouble (cons 0 upper)))
  (vlax-safearray-fill pts flat)
  ;; AddMLeader: 2nd arg = SafeArray of vertex coords; 3rd arg = leader
  ;; index (0 = first leader cluster).
  (setq mleader (vla-AddMLeader mspace pts 0))
  (vla-put-TextString  mleader text)
  ;; Layer ARROWS so the leader line + arrow are guaranteed visible
  ;; (TEXT layer was masking the arrow on some setups).  MText content
  ;; on the MLEADER also goes on this layer — the layer is BYLAYER
  ;; for color so it inherits whatever colour ARROWS is mapped to.
  (vla-put-Layer       mleader "ARROWS")
  (vla-put-ScaleFactor mleader scl)
  ;; Disable auto-landing — we already provide the elbow + text-landing
  ;; vertices explicitly in ptList, so an extra landing stub from
  ;; AutoCAD would double-draw or visually offset the text from where
  ;; we positioned it.
  (vl-catch-all-apply
    (function (lambda () (vla-put-Landing       mleader :vlax-false))))
  (vl-catch-all-apply
    (function (lambda () (vla-put-DoglegEnabled mleader :vlax-false))))
  ;; Arrow size — sensible value (500 mm).  The actual visibility fix
  ;; is at the MULTILEADER STYLE level (peb-setup-mleader-style sets
  ;; the Standard style's arrow block to "Closed Filled" once per run),
  ;; so any new MLEADER inherits a visible arrow regardless of what we
  ;; set at the entity level.
  (vl-catch-all-apply
    (function (lambda () (vla-put-ArrowSize mleader 500.0))))
  ;; Force text height = body text height (220 × scale).  Caller can
  ;; override later if it wants something bigger (e.g. heading).
  (vl-catch-all-apply
    (function (lambda () (vla-put-TextHeight mleader (* 600.0 scl)))))   ; Phase-2A v4: 600 base
  ;; Use Standard text style by default.  Callers wanting bold/Arial
  ;; should embed MText format codes (e.g. "{\\Fromand.shx;…}") in the
  ;; text string — this leaves regular weight as the surrounding default.
  (vl-catch-all-apply
    (function (lambda () (vla-put-TextStyleName mleader "Standard"))))
  mleader
)

(defun peb-make-mtext (insertPt width text /
                        acad doc mspace mtext scl)
  ;;  Create a native MTEXT object via VLA.  Single editable multi-line
  ;;  text box that the draftsman can stretch (drag the corner to widen
  ;;  / narrow the wrap), edit (double-click), or move as a unit.
  ;;
  ;;  insertPt = (x y) — top-left corner of the MText box
  ;;             (AttachmentPoint = TopLeft = 1, set after creation)
  ;;  width    = wrap width in drawing units
  ;;  text     = content; use "\\P" for explicit line breaks
  ;;
  ;;  Returns the AcadMText object on success; errors out otherwise so
  ;;  the caller's vl-catch-all-apply can fall back to hand-rolled.
  (vl-load-com)
  (setq scl    (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (setq acad   (vlax-get-acad-object))
  (setq doc    (vla-get-ActiveDocument acad))
  (setq mspace (vla-get-ModelSpace doc))
  (setq mtext
    (vla-AddMText
      mspace
      (vlax-3d-point (list (* 1.0 (car insertPt))
                            (* 1.0 (cadr insertPt))
                            0.0))
      (* 1.0 width)
      text))
  (vla-put-Layer  mtext "TEXT")
  (vla-put-Height mtext (* 600.0 scl))   ; Phase-2A v4: 600 base
  ;; AttachmentPoint 1 = Top-Left so the insertion point is the top-left
  ;; corner of the wrap box (matches the txt "ML" insertion point).
  (vla-put-AttachmentPoint mtext 1)
  ;; LineSpacingFactor 0.85 makes lines tighter — reduces vertical
  ;; sprawl on narrow buildings where the spec wraps to many short
  ;; lines, helping avoid overlap with PURLIN/EAVE GUTTER labels below.
  (vla-put-LineSpacingFactor mtext 0.85)
  mtext
)

(defun peb-just-to-attachment (just)
  ;;  Map AutoLISP txt justification strings to MText AttachmentPoint
  ;;  numeric codes (1=TopLeft .. 9=BottomRight).
  (cond
    ((= just "TL") 1)  ((= just "TC") 2)  ((= just "TR") 3)
    ((= just "ML") 4)  ((= just "MC") 5)  ((= just "MR") 6)
    ((= just "BL") 7)  ((= just "BC") 8)  ((= just "BR") 9)
    (T 4))   ; default ML
)

(defun peb-make-mtext-line (insertPt textHeight rotationDeg justify text /
                             acad doc mspace mtext)
  ;;  Single-line MTEXT helper.  width=0 means "no auto-wrap" — text
  ;;  stays on one line.  rotation in degrees (converted to radians).
  ;;  justify is "ML" / "MC" / etc — mapped to AttachmentPoint via
  ;;  peb-just-to-attachment.
  (vl-load-com)
  (setq acad   (vlax-get-acad-object))
  (setq doc    (vla-get-ActiveDocument acad))
  (setq mspace (vla-get-ModelSpace doc))
  (setq mtext
    (vla-AddMText
      mspace
      (vlax-3d-point (list (* 1.0 (car insertPt))
                            (* 1.0 (cadr insertPt))
                            0.0))
      0.0
      text))
  (vla-put-Layer  mtext "TEXT")
  (vla-put-Height mtext (* 1.0 textHeight))
  (vla-put-Rotation mtext (* (/ pi 180.0) (* 1.0 rotationDeg)))
  (vla-put-AttachmentPoint mtext (peb-just-to-attachment justify))
  mtext
)

(defun peb-label-with-leader (text labelPos arrowPt leaderDir
                              fallbackTextHeight /
                              tX tY aX aY sgn baseY ah w s p prev lines ln L)
  ;;  Draw a labelled leader as a SINGLE MLEADER object (text + leader
  ;;  + arrow are one entity — drag any part and the rest follows).
  ;;
  ;;  leaderDir options:
  ;;    "S" : STRAIGHT 2-vertex leader (arrow tip → text landing).
  ;;          Cleanest look, matches Section's RAFTER / RIDGE style.
  ;;    "V" : 3-vertex L — vertical leg from arrow up/down to text-Y,
  ;;          then horizontal landing across to text.
  ;;    "H" : 3-vertex L — horizontal leg first, then vertical to text.
  ;;
  ;;  Vertex order (MLEADER convention):
  ;;    [0] = arrow tip
  ;;    [last] = text landing point
  ;;    intermediate = elbow corners
  ;;
  ;;  If MLEADER fails, falls back to MTEXT label + hand-rolled L-arrow.
  (setq tX (car labelPos) tY (cadr labelPos) aX (car arrowPt) aY (cadr arrowPt))
  (setq s (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0) ah (* 260.0 s) w (* 100.0 s))
  (if (or (null fallbackTextHeight) (<= fallbackTextHeight 0)) (setq fallbackTextHeight (* 500.0 s)))
  ;; owner 4-Jul: split on \P into 2+ ROWS (was flattened to one line) — stacked downward.
  (setq lines '())
  (while (setq p (vl-string-search "\\P" text))
    (setq lines (cons (substr text 1 p) lines) text (substr text (+ p 3))))
  (setq lines (reverse (cons text lines)))
  (setq prev (getvar "CLAYER"))
  (setvar "CLAYER" "TEXT")
  ;; RULE (Nasir): CLEAN 90-degree leader — vertical leg from the arrow tip to the text
  ;; level, then a horizontal shoulder to the text; FILLED arrowhead at the tip.  No
  ;; native MLEADER (rendered garbled) — hand-rolled LINE + SOLID + TEXT, same points.
  (command "_.LINE" arrowPt (list aX tY) (list tX tY) "")
  (setq sgn (if (>= tY aY) 1.0 -1.0) baseY (+ aY (* sgn ah)))
  ;; filled arrowhead (entmake SOLID — no command prompts): base behind the tip, apex at the tip
  (entmake (list (cons 0 "SOLID") (cons 8 "TEXT")
                 (list 10 (- aX w) baseY 0.0) (list 11 (+ aX w) baseY 0.0)
                 (list 12 aX aY 0.0) (list 13 aX aY 0.0)))
  (setq ln 0)
  (foreach L lines
    (txt (if (>= tX aX) "ML" "MR")
         (list tX (- tY (* ln fallbackTextHeight s 1.35)))     ; stack rows downward (s = *PEB-TEXT-SCALE*)
         fallbackTextHeight 0 L)
    (setq ln (1+ ln)))
  (setvar "CLAYER" prev)
)

(defun peb-label-no-leader (text labelPos textHeight rotation justify /
                             mtResult)
  ;;  For labels that don't have a leader (RAFTER, BRICK WALL — text
  ;;  only).  Tries native MTEXT first; falls back to plain (txt …).
  (setq mtResult
    (vl-catch-all-apply 'peb-make-mtext-line
                        (list labelPos textHeight rotation justify text)))
  (if (vl-catch-all-error-p mtResult)
    (txt justify labelPos textHeight rotation text))
)

(defun peb-collect-entities-since (lastEnt / e result)
  ;;  Walks the entity chain from lastEnt (or the very beginning if nil)
  ;;  forward, returning a list of all entity names created after.  Used
  ;;  by the dim helpers to grab their just-drawn primitives for grouping.
  (setq result '())
  (setq e (if lastEnt (entnext lastEnt) (entnext)))
  (while e
    (setq result (cons e result))
    (setq e (entnext e)))
  (reverse result)
)

(defun peb-group-entities (entList prefix / groupName)
  ;;  GROUP creation TEMPORARILY DISABLED — when the named group already
  ;;  existed from a previous LISP run, (command "_-GROUP" "_Create" …)
  ;;  hung waiting for the "redefine?" prompt and every subsequent
  ;;  (command …) call in the script broke as a result.  That left the
  ;;  drawing missing labels, dim chains, title block, etc.
  ;;
  ;;  Returning the would-be group name keeps callers happy.  Click-
  ;;  once-select-all is sacrificed for now.  Future fix path: switch
  ;;  to anonymous groups (name = "*") which AutoCAD auto-numbers and
  ;;  never collide; or check (tblsearch "GROUP" name) and skip if it
  ;;  already exists.
  (setq *PEB-DIM-GROUP-COUNTER* (1+ *PEB-DIM-GROUP-COUNTER*))
  (setq groupName (strcat prefix "_" (itoa *PEB-DIM-GROUP-COUNTER*)))
  groupName
)

(defun peb-safe-setvar (varName value /)
  ;;  setvar wrapped in vl-catch-all-apply so a rejected value doesn't
  ;;  abort the LISP run.  AutoCAD silently ignores invalid values.
  (vl-catch-all-apply 'setvar (list varName value))
)

(defun peb-dim-text-spacing (orientation / dimtxt dimscale)
  ;;  Auto-compute spacing between two parallel dim lines.  ONE
  ;;  unified formula for both vertical and horizontal dims (per user
  ;;  "same formula for all balance dimensions").
  ;;
  ;;    spacing = max(1200, 4 × DIMTXT × DIMSCALE)
  ;;
  ;;  This gives:
  ;;    - clean visible gap between rotated 2-line text blocks
  ;;    - tighter overall layout than the previous 8× formula
  ;;    - 1200 mm floor so small-scale drawings still look readable
  ;;
  ;;  orientation parameter kept for API back-compat but no longer
  ;;  changes the result.
  (setq dimtxt   (if (getvar "DIMTXT") (getvar "DIMTXT") 250.0))
  (setq dimscale (if (getvar "DIMSCALE") (getvar "DIMSCALE") 1.0))
  (max 1200.0 (* 4.0 dimtxt dimscale))
)

(defun peb-set-cell-text (tbl row col text height /)
  ;;  Helper: set a cell's text + alignment + height + style on an
  ;;  AcDbTable.  Body cells use MiddleLeft (4) alignment.  Text style
  ;;  PEB-BODY (per user spec, matches pic-1 Cell Properties pane).
  ;;  Color stays at ByBlock (default for Standard table style).
  (vl-catch-all-apply
    (function (lambda () (vla-SetText tbl row col text))))
  (vl-catch-all-apply
    (function (lambda () (vla-SetCellTextHeight tbl row col (* 1.0 height)))))
  (vl-catch-all-apply
    (function (lambda () (vla-SetCellAlignment tbl row col 4)))) ; 4 = MiddleLeft
  ;; Cell text style — PEB-BODY for body cells.  Header style overridden
  ;; at call site if needed.  Wrapped in catch so missing style doesn't
  ;; break the call (falls back to Standard).
  (vl-catch-all-apply
    (function (lambda () (vla-SetCellTextStyle tbl row col "PEB-BODY"))))
)

;; ============================================================================
;;  TITLE-BLOCK FORMATTING RULES  (Phase-2A v24 — rule-based, not hardcoded)
;; ----------------------------------------------------------------------------
;;  R1 (vertical fit): the BODY text height is DERIVED from content, never fixed.
;;      bodyTextH = bodyTotalH / (maxLines * LSF)
;;      where maxLines = the largest line-count among the merged multi-line
;;      cells (incl. the MAIMAAR address block) and LSF = AcDbTable line-spacing
;;      factor (~1.15).  Guarantees the tallest cell fits its merged height, so
;;      no line is clipped by a row divider or spills past the bottom border.
;;  R2 (line cap): no merged body cell exceeds nBodyRows (7) lines — the MAIMAAR
;;      block is condensed to <=7 lines at the call site.
;;  R3 (horizontal fit): single-line PROJECT-INFO values are truncated to
;;      maxChars = floor(colW / (0.62 * bodyTextH)) so they never spill into the
;;      next column (peb-fit-cell).
;;  R4 (alignment): headers = middle-centre (5); merged multi-line body = top-
;;      left (handled by the cell MText); PROJECT-INFO single rows = middle-left.
;; ============================================================================
(defun peb-nlines (s / n i)
  ;;  Count text lines in a title-cell string (lines split by the MText
  ;;  paragraph break "\\P").  Empty/atomic string = 1 line.
  (if (or (null s) (not (= (type s) 'STR))) 1
    (progn
      (setq n 1 i 0)
      (while (setq i (vl-string-search "\\P" s i))
        (setq n (1+ n) i (+ i 2)))
      n)))

(defun peb-fit-cell (s maxChars)
  ;;  R3 — truncate a single-line cell value to maxChars (keeps it inside the
  ;;  column).  Appends nothing; just clips so it never overruns the divider.
  (if (and (= (type s) 'STR) (> (strlen s) maxChars) (> maxChars 1))
    (substr s 1 maxChars)
    s))

(defun peb-build-title-table (insertPt colWidths headerH bodyTotalH
                              headerTexts bodyMatrix mergeSpecs
                              headerH_pt bodyH_pt /
                              acad doc mspace tbl nCols nRows nBodyRows
                              bodyRowH r i totW spec)
  ;;  Build the title-block as a real AcDbTable entity, supporting:
  ;;    - one header row (column titles, NOT title-merged)
  ;;    - any number of body rows (e.g. 7 for the PROJECT INFORMATION
  ;;      sub-rows: QUOTE NO., BLDG. NAME, CLIENT, REV/DRN/CHK,
  ;;      DATE/BLDG, CROSS SECTION title, SHEET NO.)
  ;;    - cell-merge specs so non-project columns can fold their body
  ;;      rows into ONE tall cell containing the multi-line content
  ;;
  ;;  insertPt    = (x y) — TOP-LEFT corner
  ;;  colWidths   = list of N column widths
  ;;  headerH     = height of the header row
  ;;  bodyTotalH  = TOTAL height of all body rows combined
  ;;  headerTexts = list of N strings for the header
  ;;  bodyMatrix  = list of body rows; each row = list of N strings
  ;;  mergeSpecs  = list of (minR maxR minC maxC) tuples; each one
  ;;                merges the rectangular block of cells.  After
  ;;                merge, the merged cell shows the content of (minR,minC).
  ;;  headerH_pt  = header text height
  ;;  bodyH_pt    = body text height
  (vl-load-com)
  (setq acad      (vlax-get-acad-object))
  (setq doc       (vla-get-ActiveDocument acad))
  (setq mspace    (vla-get-ModelSpace doc))
  (setq nCols     (length colWidths))
  (setq nBodyRows (length bodyMatrix))
  (setq nRows     (1+ nBodyRows))               ; 1 header + body rows
  (setq totW      (apply '+ colWidths))
  (setq bodyRowH  (/ bodyTotalH (max 1 nBodyRows)))
  (vl-catch-all-apply
    (function
      (lambda ()
        (setq tbl
          (vla-AddTable
            mspace
            (vlax-3d-point (list (* 1.0 (car insertPt))
                                  (* 1.0 (cadr insertPt))
                                  0.0))
            nRows nCols
            (* 1.0 headerH)
            (* 1.0 (/ totW nCols))))
        ;; Suppress the auto-title row so row 0 isn't merged.
        (vl-catch-all-apply
          (function (lambda () (vla-put-TitleSuppressed tbl :vlax-true))))
        ;; Defensive: unmerge row 0 in case the style still merges it.
        (vl-catch-all-apply
          (function (lambda () (vla-UnmergeCells tbl 0 0 0 (1- nCols)))))
        ;; Column widths
        (setq i 0)
        (foreach w colWidths
          (vl-catch-all-apply
            (function (lambda () (vla-SetColumnWidth tbl i (* 1.0 w)))))
          (setq i (1+ i)))
        ;; Tighten cell margins — minimal padding inside cells so row
        ;; heights aren't auto-expanded by AcDbTable's internal margin
        ;; calculation.  Set BEFORE adding content so initial heights
        ;; are computed against the smaller margins.
        (vl-catch-all-apply
          (function (lambda () (vla-put-VertCellMargin tbl 5.0))))
        (vl-catch-all-apply
          (function (lambda () (vla-put-HorzCellMargin tbl 30.0))))
        ;; Header row: text + height + alignment.
        (setq i 0)
        (foreach hdr headerTexts
          (peb-set-cell-text tbl 0 i hdr headerH_pt)
          (vl-catch-all-apply
            (function (lambda () (vla-SetCellAlignment tbl 0 i 5))))
          (setq i (1+ i)))
        ;; Body row content (set BEFORE merging; merged cell takes
        ;; content from its top-left source cell)
        (setq r 1)
        (foreach rowData bodyMatrix
          (setq i 0)
          (foreach content rowData
            (peb-set-cell-text tbl r i content bodyH_pt)
            (setq i (1+ i)))
          (setq r (1+ r)))
        ;; Apply merges
        (foreach spec mergeSpecs
          (vl-catch-all-apply
            (function (lambda ()
              (vla-MergeCells tbl
                (nth 0 spec) (nth 1 spec)
                (nth 2 spec) (nth 3 spec))))))
        ;; Force per-row heights AFTER content + merging.  This is the
        ;; key fix for "first body row too tall": AutoCAD auto-expands
        ;; rows that hold multi-line content (the merged top cell
        ;; carries 6+ lines of \\P-broken text) — without this last
        ;; pass, that first body row ends up taller than bodyRowH.
        ;; Setting AFTER merge locks rows to 1-line height.
        (setq r 1)
        (while (<= r nBodyRows)
          (vl-catch-all-apply
            (function (lambda () (vla-SetRowHeight tbl r (* 1.0 bodyRowH)))))
          (setq r (1+ r)))
      )
    )
  )
  tbl
)

(defun peb-tb-mtext (insertPt width height text /
                      acad doc mspace mtext)
  ;;  Title-block MText helper.  Creates ONE multi-line MText entity
  ;;  with the given absolute text height (NOT scaled by *PEB-TEXT-SCALE*
  ;;  — title block has its own fixed sizing).  Insertion point is the
  ;;  TOP-LEFT corner; lines are stacked downward via "\\P" breaks in
  ;;  the text string.
  ;;
  ;;  insertPt = (x y) — top-left of the text block
  ;;  width    = wrap width in drawing units
  ;;  height   = text height in drawing units
  ;;  text     = MText content with "\\P" between lines
  (vl-load-com)
  (setq acad   (vlax-get-acad-object))
  (setq doc    (vla-get-ActiveDocument acad))
  (setq mspace (vla-get-ModelSpace doc))
  (setq mtext
    (vla-AddMText
      mspace
      (vlax-3d-point (list (* 1.0 (car insertPt))
                            (* 1.0 (cadr insertPt))
                            0.0))
      (* 1.0 width)
      text))
  (vla-put-Layer  mtext "TEXT")
  (vla-put-Height mtext (* 1.0 height))
  (vla-put-AttachmentPoint    mtext 1)         ; TopLeft
  (vla-put-LineSpacingFactor  mtext 1.0)
  mtext
)

(defun peb-recolor-last-dim (color / lastEnt obj)
  ;;  Override the COLOR of the most recently created dim entity.
  ;;  Used when DIMCLR* sysvar overrides don't take effect (because
  ;;  peb-dim-set-vars resets them inside peb-dim-height-stretch).
  ;;  Setting color via vla-put-Color directly on the entity bypasses
  ;;  the dim-style chain and always wins.
  ;;
  ;;  color = AutoCAD color index:
  ;;     0   = ByBlock (displays as white in default modelspace)
  ;;     1-255 = ACI colors (4 = cyan, 7 = white)
  ;;     256 = ByLayer
  (vl-load-com)
  (setq lastEnt (entlast))
  (if lastEnt
    (vl-catch-all-apply
      (function (lambda ()
        (setq obj (vlax-ename->vla-object lastEnt))
        (vla-put-Color obj color))))
  )
)

(defun peb-dim-set-vars ()
  ;;  Apply MAIMAAR dim look as sysvar overrides.  Each setvar is wrapped
  ;;  in peb-safe-setvar so any one rejected value (e.g. DIMDSEP 46
  ;;  rejected on this AutoCAD build) doesn't break the rest.
  ;;  AutoCAD applies these as overrides on the active dimstyle —
  ;;  matches the "Dimension style overrides" block visible when LIST
  ;;  is run on the resulting AcDbRotatedDimension.
  ;; Settings matched to user's LIST output from a reference dim:
  ;;   DIMASZ=250, DIMTXT=250, DIMGAP=10, DIMEXE=100, DIMEXO=100,
  ;;   DIMSCALE=1.1783, DIMTIH/DIMTOH=Off, DIMTOFL=On, DIMDEC=0,
  ;;   DIMALT=On with DIMALTF=0.0033, DIMALTRND=0.01, DIMAPOST=" ft",
  ;;   DIMPOST=" mm".
  ;; Per-dim labels are applied via override "<>\\PLABEL" format
  ;; (\\P = MText paragraph break — value on line 1, label on line 2).
  ;; ── Phase-2A v3: DIMSCALE auto-scales with building size ──────
  (peb-safe-setvar "DIMSCALE" (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0))
  ;; Proper small CLOSED-FILLED arrowheads at each end (owner), value above line.
  (peb-safe-setvar "DIMTXT"   (peb-th 'DIM))   ; ladder: 2.5 mm of paper (x DIMSCALE)
  (peb-safe-setvar "DIMTXSTY" "ROMAND")     ; owner 19-Jul STANDING: dimension Text style = ROMAND (romand.shx)
  (peb-safe-setvar "DIMTSZ"     0.0)        ; no ticks -> arrowheads
  (peb-safe-setvar "DIMASZ"   320.0)        ; proper small arrowhead
  ;; owner 19-Jul STANDING RULE: dimension arrowheads = "OPEN" type (open V, NOT filled solid).
  (vl-catch-all-apply (function (lambda () (setvar "DIMBLK" "_OPEN"))))
  (vl-catch-all-apply (function (lambda () (setvar "DIMSAH" 0))))
  (peb-safe-setvar "DIMEXE"   120.0)
  (peb-safe-setvar "DIMEXO"   120.0)
  (peb-safe-setvar "DIMGAP"    60.0)
  (peb-safe-setvar "DIMTAD"      1)         ; value above the dim/tick line
  (peb-safe-setvar "DIMTOFL"     1)         ; force line inside (On)
  (peb-safe-setvar "DIMTIH"      0)         ; text aligned with dim line
  (peb-safe-setvar "DIMTOH"      0)
  (peb-safe-setvar "DIMJUST"     0)
  (peb-safe-setvar "DIMCLRD"     0)         ; BYLAYER
  (peb-safe-setvar "DIMCLRE"     0)
  (peb-safe-setvar "DIMCLRT"     0)
  (peb-safe-setvar "DIMDEC"      0)         ; integer mm
  (peb-safe-setvar "DIMLUNIT"    2)         ; decimal
  (peb-safe-setvar "DIMATFIT"    3)
  ;; Alt units ON, Architectural format
  (peb-safe-setvar "DIMALT"      1)
  (peb-safe-setvar "DIMALTF"     0.03937)   ; mm → inches
  (peb-safe-setvar "DIMALTRND"   1.0)       ; round to 1 inch
  (peb-safe-setvar "DIMALTD"     0)         ; integer inches
  (peb-safe-setvar "DIMALTU"     4)         ; Architectural format
  (peb-safe-setvar "DIMALTZ"     0)
  (peb-safe-setvar "DIMAPOST" "")           ; no extra suffix (auto-wraps in [ ])
  (peb-safe-setvar "DIMPOST"  "")           ; no primary suffix
  ;; DIMDSEP intentionally NOT set — some AutoCAD builds reject
  ;; integer-46-as-character-code.  The default decimal separator is
  ;; fine for our drawings.
  (princ)
)



(defun peb-dim-h-stretch (x1 x2 y override / lastBefore oldLayer newEnts result)
  ;;  Horizontal dim with TWO-TIER strategy:
  ;;    1. Try (command "_DIMLINEAR" …) — creates a native, associative,
  ;;       stretchable AcDbRotatedDimension that auto-updates on stretch
  ;;       (matches the user's reference dims from other drawings).
  ;;    2. If DIMLINEAR errors, fall back to hand-rolled dim-line-h
  ;;       primitives wrapped in a GROUP so the drawing always renders
  ;;       and the draftsman gets at least click-once-select-all.
  ;;
  ;;  Sysvars are set per-call via peb-dim-set-vars so the resulting
  ;;  dim has the right scale/text/arrow look as overrides on whatever
  ;;  dimstyle is currently active.
  (setq lastBefore (entlast))
  (setq oldLayer   (getvar "CLAYER"))
  (peb-dim-set-vars)
  ;; owner 14-Jul: honour the global *PEB-DIM-TXT* here too (same hook as peb-dim-height-stretch) so the
  ;; overall WIDTH dim text can be forced to the SAME size as the height dims ("both dims same size").
  (if (and *PEB-DIM-TXT* (> *PEB-DIM-TXT* 0)) (peb-safe-setvar "DIMTXT" *PEB-DIM-TXT*))
  (setvar "CLAYER" "DIMENSIONS")
  (setq result
    (vl-catch-all-apply
      (function (lambda ()
        (if override
          (command "_DIMLINEAR"
                   (list x1 0.0)
                   (list x2 0.0)
                   "_T" override
                   (list (/ (+ x1 x2) 2.0) y))
          (command "_DIMLINEAR"
                   (list x1 0.0)
                   (list x2 0.0)
                   (list (/ (+ x1 x2) 2.0) y)))))))
  (setvar "CLAYER" oldLayer)
  ;; If DIMLINEAR threw an error (and didn't create a dim), fall back.
  (if (vl-catch-all-error-p result)
    (progn
      (peb-dim-h-native x1 x2 y "<>")
      (setq newEnts (peb-collect-entities-since lastBefore))
      (peb-group-entities newEnts "PEBDIMH")))
)

;; Longest line (char count) in an MText override, treating "\P" as a paragraph break (owner 5-Jul).
(defun peb-longest-line-len (s / n best seg i c)
  (setq best 0 seg 0 i 1 n (strlen s))
  (while (<= i n)
    (setq c (substr s i 1))
    (if (and (= c "\\") (= (substr s (1+ i) 1) "P"))
      (progn (if (> seg best) (setq best seg)) (setq seg 0 i (+ i 2)))
      (setq seg (1+ seg) i (1+ i))))
  (if (> seg best) (setq best seg))
  (max best 1))

(defun peb-dim-height-stretch (objX dimX y1 y2 override / lastBefore oldLayer newEnts result)
  ;;  Height dim — DIMLINEAR primary, grouped hand-rolled fallback.
  (setq lastBefore (entlast))
  (setq oldLayer   (getvar "CLAYER"))
  (peb-dim-set-vars)
  ;; AUTOSIZE (owner 5-Jul, STRICT RULE: the label must NEVER go beyond the arrows).  Shrink DIMTXT so the
  ;; longest override line fits within the dim span with margin (conservative 0.82 span / 0.66 char-width),
  ;; capped at the default 500, floored at 150.  (Very long labels are also abbreviated at the source.)
  (if override
    (peb-safe-setvar "DIMTXT"
      (max 150.0 (min 440.0
        (/ (* (abs (- y2 y1)) 0.82)
           (* (peb-longest-line-len override) 0.66
              (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0)))))))
  ;; owner 14-Jul: an explicit *PEB-DIM-TXT* (mm, global) OVERRIDES the autosize — used to force a tall
  ;; two-line override (e.g. "3048\PBRICK MASONRY") small enough to sit between the arrows.  It ALSO forces
  ;; the text INSIDE the extension lines (DIMTIX=1) and keeps text+arrows together (DIMATFIT=0) so a label
  ;; whose rotated width still exceeds the span is centred BETWEEN the arrows instead of floating above the
  ;; top arrow (owner 14-Jul "shift the dim text between the arrows").  Reset to the house default otherwise.
  (if (and *PEB-DIM-TXT* (> *PEB-DIM-TXT* 0))
    (progn
      (peb-safe-setvar "DIMTXT" *PEB-DIM-TXT*)
      (peb-safe-setvar "DIMTIX" 1)
      (peb-safe-setvar "DIMATFIT" 0))
    (progn
      (peb-safe-setvar "DIMTIX" 0)
      (peb-safe-setvar "DIMATFIT" 3)))
  (setvar "CLAYER" "DIMENSIONS")
  (setq result
    (vl-catch-all-apply
      (function (lambda ()
        (if override
          (command "_DIMLINEAR"
                   (list objX y1)
                   (list objX y2)
                   "_T" override
                   (list dimX (/ (+ y1 y2) 2.0)))
          (command "_DIMLINEAR"
                   (list objX y1)
                   (list objX y2)
                   (list dimX (/ (+ y1 y2) 2.0))))))))
  (setvar "CLAYER" oldLayer)
  (if (vl-catch-all-error-p result)
    (progn
      (draw-height-dim objX dimX y1 y2
                       (if override
                         override
                         (rtos (abs (- y2 y1)) 2 0)))
      (setq newEnts (peb-collect-entities-since lastBefore))
      (peb-group-entities newEnts "PEBDIMV")))
)


;; ============================================================================
;; NON-INTERACTIVE ENTRY  (used by Excel VBA Generate-Drawings auto-launch)
;; Tiling: each new drawing places to the right of existing entities.
;; ============================================================================



;; ============================================================================

;; ============================================================================


(setq *PEB-MAIMAAR-DIM-READY* nil)

(defun peb-ensure-maimaar-dim ()
  (if (not *PEB-MAIMAAR-DIM-READY*)
    (progn
      (vl-catch-all-apply (function (lambda () (setup-maimaar-dim))))
      (setq *PEB-MAIMAAR-DIM-READY* T))))

(defun peb-sync-dimscale ()
  (if (and (boundp '*PEB-DIM-SCALE*) *PEB-DIM-SCALE* (> *PEB-DIM-SCALE* 0))
    (vl-catch-all-apply
      (function (lambda () (setvar "DIMSCALE" *PEB-DIM-SCALE*))))))

(defun peb-tile-gap () 5000.0)   ;; 5 m gap between tiled drawings

;; PART-AWARE plan entry point — one A4 per match-line part.  Part 1 of 1 is exactly the
;; old behaviour, so a building under the split threshold is unchanged.
(defun peb-plan-part-from-file (path p n)
  (setq *PEB-PART-P* p *PEB-PART-N* n)
  (peb-plan-from-file path)
  (setq *PEB-PART-P* nil *PEB-PART-N* nil)
  (princ))

(defun peb-plan-from-file (path / prev-last prev-max-x e new-set offset msSel)
  ;; Enter in a KNOWN command state, exactly as peb-elev-from-file does.  C:PEB-PLAN exits
  ;; with (setvar "CMDECHO" 1) and leaves OSMODE alone, so a SECOND plan sheet in the same
  ;; acad session starts in a different state from the first — and the elevations, which do
  ;; reset both, are the sheets that survive being drawn twice.  (owner 27-Aug)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (setq prev-last (entlast))
  ;; the frame must wrap THIS sheet, not every sheet drawn so far (see
  ;; peb-frame-and-titleblock).  Same marker the tiler already uses.
  (setq *PEB-SHEET-MARK* prev-last)
  ;; ── TILE ONLY IF MODEL SPACE REALLY HOLDS A PREVIOUS SHEET (owner 27-Aug) ──────────
  ;; (entlast) sees the WHOLE database, PAPER SPACE INCLUDED.  The PDF pipeline plots one
  ;; sheet at a time: ERASE _ALL -> draw -> (peb-add-layout "PLn") -> plot -> -LAYOUT
  ;; _Delete PLn.  The deleted layout can leave an entity behind, so (entlast) comes back
  ;; NON-NIL on a model space that is in fact EMPTY.  EXTMAX is then still the PREVIOUS
  ;; sheet's, and peb-tile-place shifts this sheet ~98 m to the right of nothing; the next
  ;; peb-add-layout gets an impossible extent box and the whole acad session wedges with no
  ;; error — the run dies on the 600 s timeout having plotted only the sheets before it.
  ;;
  ;; This stayed hidden until the COLUMN LAYOUT PLAN was split in two: part 2 is the first
  ;; sheet ever to follow another sheet drawn by THIS function.  Test the space we actually
  ;; tile in, not the database.
  (setq msSel (ssget "_X" '((410 . "Model"))))
  (if (and prev-last msSel)
    (progn
      (command "_.REGEN")
      (setq prev-max-x (car (getvar "EXTMAX")))
      (if (or (null prev-max-x) (< prev-max-x -1e10))
        (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (if (not msSel) (setq prev-last nil))     ; nothing to tile past -> draw at the origin

  (setq *PEB-DATA-FILE* path)
  (princ (strcat "\nPEB-PLAN using data file: " path))
  (C:PEB-PLAN)
  (setq *PEB-DATA-FILE* nil)

  ;; guarded like every other *-from-file entry point: a tiling failure must not take the
  ;; finished drawing down with it.
  (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x))))
  (princ))

;; ============================================================================
;;  MULTI-AREA — ONE combined plan (owner 5-Jul)
;; ============================================================================
;; Draw several AREAS on ONE plan, each placed ADJACENT to its reference area per the IF fields
;; AR_POSITION / AR_REF_AREA / AR_GAP, then wrap the whole set in ONE border + title block.  Areas are
;; placed by their LOGICAL drawn dimensions (wid/len published by C:PEB-PLAN) — no fragile extent scan.
;; Convention (owner 5-Jul): LEFT-ALIGNED; GAP 0 = shared wall.  Position is relative to the reference:
;;   Attached — Below -> under ref (shares ref NSW)     Attached — Above -> over ref (shares ref FSW)
;;   Attached — Right of -> right of ref (share ref REW) Attached — Left of -> left of ref (share ref LEW)

;; TRUE when the given wall's column row is the one COMMON with an attached area (set by the orchestrator
;; via *PEB-OMIT-WALL*); C:PEB-PLAN skips that row so the shared wall carries ONE row of columns.
(defun peb-omit-wall-p (w) (and *PEB-OMIT-WALL* (= (strcase *PEB-OMIT-WALL*) (strcase w))))

;; owner 5-Jul (multi-area): hide a wall LABEL when that wall is (a) the attached area's omitted common
;; wall, OR (b) the REFERENCE area's wall that another area attaches to (*PEB-REF-SHARED*, set per direction
;; for the reference — it KEEPS its columns there, only drops the now-internal wall label).
(defun peb-hide-wall-label-p (w)
  (or (peb-omit-wall-p w) (peb-ref-shared-p w)))

;; read AR_POSITION from a data file without drawing (to decide the omitted wall BEFORE C:PEB-PLAN runs)
(defun peb-read-ar-position (path / f line pos)
  (setq pos "")
  (if (setq f (open path "r"))
    (progn
      (while (setq line (read-line f))
        (if (and (>= (strlen line) 12) (= (substr line 1 12) "AR_POSITION="))
          (setq pos (substr line 13))))
      (close f)))
  pos)

;; ---- STATIC grid-station counts, from the DATA alone (no drawing) --------------------------------
;; Needed because an area attached ABOVE / LEFT must make the REFERENCE carry the grid offset, and the
;; reference is drawn FIRST — we cannot wait for the attached area's own *PEB-MA-*GRID-N*.  Mirrors the
;; drawer: width stations = {0, wid} U module stations U end-wall stations (the EW spans are RESCALED to
;; close on wid, exactly as the drawer does at ~3096); bay stations = bay spans + 1.
(defun peb-count-wgrid (d / wid ewE mdE spans sts acc sum sc s)
  (setq wid (MSPL-Get-Num d "WIDTH"))
  (if (or (null wid) (<= wid 0.0)) (setq wid 30000.0))
  (setq sts (list 0.0 wid))
  ;; module (interior-column) stations
  (setq mdE (MSPL-Get-Str d "MODEXPR") spans (if (/= mdE "") (peb-width-order (peb-parse-mod-expression mdE)) nil))   ; rule 4B.34 — width chain, written A downward
  (if spans
    (progn (setq acc 0.0)
      (foreach s spans (setq acc (+ acc s)) (if (< acc (- wid 1.0)) (setq sts (cons acc sts))))))
  ;; end-wall stations, scaled to close on wid
  (setq ewE (MSPL-Get-Str d "EWLEXPR") spans (if (/= ewE "") (peb-width-order (peb-parse-mod-expression ewE)) nil))   ; rule 4B.34 — width chain, written A downward
  (if spans
    (progn (setq sum 0.0) (foreach s spans (setq sum (+ sum s)))
      (if (> sum 0.0)
        (progn (setq sc (/ wid sum) acc 0.0)
          (foreach s spans (setq acc (+ acc (* s sc)))
            (if (< acc (- wid 1.0)) (setq sts (cons acc sts))))))))
  ;; unique within 1 mm
  (setq acc nil)
  (foreach s (vl-sort sts '<)
    (if (not (vl-some '(lambda (p) (< (abs (- p s)) 5.0)) acc)) (setq acc (cons s acc))))   ; 5 mm — see the grid-merge note above
  (length acc))

(defun peb-count-lgrid (d / spans)
  (setq spans (peb-parse-mod-expression (MSPL-Get-Str d "BAYEXPR")))
  (if spans (1+ (length spans)) 2))

;; The REFERENCE area's wall that an attached area sits against — the mirror of peb-common-wall, which
;; returns the ATTACHED area's own common wall.  Below => the attached area hangs off the reference's NSW.
(defun peb-ref-shared-wall (pos / p)
  (setq p (strcase (if pos pos "")))
  (cond ((wcmatch p "*BELOW*") "NSW") ((wcmatch p "*ABOVE*") "FSW")
        ((wcmatch p "*RIGHT*") "REW") ((wcmatch p "*LEFT*")  "LEW") (T nil)))

;; TRUE when w is a wall of THIS area that an attached area sits against — i.e. this area is the
;; REFERENCE and that wall is now interior.  *PEB-REF-SHARED* was already consulted by
;; peb-hide-wall-label-p but NOTHING ever set it (scaffolded, never wired); the orchestrator now does.
;; It gates, in one place: the wall LABEL, the length/width DIM stack, and the grid bubbles — all of
;; which are genuinely interior once an area attaches.  It does NOT gate the sheeting: a common wall is
;; always clad above the lower area's roof (see peb-wall-clad-p).  It instead FORCES that cladding on,
;; overriding a 'Full Height Open for Access' condition, which on a common wall means open only up to
;; the low roof.  The ATTACHED area omits the wall entirely via *PEB-OMIT-WALL*, so exactly one line.
(defun peb-ref-shared-p (w)
  (and *PEB-REF-SHARED*
       (member (strcase w)
               (mapcar 'strcase (if (listp *PEB-REF-SHARED*) *PEB-REF-SHARED* (list *PEB-REF-SHARED*))))))

;; T when a wall must carry a line on THIS pass.  `sheeting` nil = the COL-OUTER pass (the columns are
;; real, so it always draws); T = the SHEETING outline, which asks whether the wall is clad.
;;
;; A COMMON wall is always clad.  Owner 10-Jul, giving the reason: "why are we giving the sheeting line?
;; the reason is that when there is a difference in height.  Sheeting will be either full height, or the
;; common area open and above sheeting.  Both cases the sheeting line will come."  The two areas differ
;; in height (that is what makes them two areas), so above the LOWER area's roof the taller area's wall
;; is exterior and must be clad.  Hence a common wall set 'Full Height Open for Access' is open only up
;; to the low roof — there is still a sheeted strip above it, and in PLAN that strip is the sheeting
;; line.  The IF's own list says the same: 'Open up to .. M for Access, Rest Height Sheeted' keeps its
;; line already (peb-wall-open-p is nil for it — it matches *SHEET*).
;;
;; Exactly ONE line results at the join: the ATTACHED area omits the wall entirely (*PEB-OMIT-WALL*),
;; the REFERENCE clads it.  *PEB-REF-SHARED* governs that wall's LABEL, DIM stack and GRID row (all
;; genuinely interior), but never its sheeting.  Only a fully-open EXTERNAL wall loses the line.
(defun peb-wall-clad-p (w open sheeting)
  (or (not sheeting)                ; COL-OUTER pass — the column line is always drawn
      (peb-ref-shared-p w)          ; common wall — clad above the lower area's roof, always
      (not open)))                  ; external wall — clad unless fully open for access

;; draw a building-outline rectangle EDGE-BY-EDGE, skipping the wall shared with an attached area
;; (*PEB-OMIT-WALL*).  NSW=bottom(y0) FSW=top(y1) LEW=left(x0) REW=right(x1).  nil => all 4 (normal).
(defun peb-draw-outline (x0 y0 x1 y1 sheeting)
  (if (and (not (peb-omit-wall-p "NSW")) (peb-wall-clad-p "NSW" *PEB-WOPEN-NSW* sheeting))
    (command "_.LINE" (list x0 y0) (list x1 y0) ""))
  (if (and (not (peb-omit-wall-p "FSW")) (peb-wall-clad-p "FSW" *PEB-WOPEN-FSW* sheeting))
    (command "_.LINE" (list x0 y1) (list x1 y1) ""))
  (if (and (not (peb-omit-wall-p "LEW")) (peb-wall-clad-p "LEW" *PEB-WOPEN-LEW* sheeting))
    (command "_.LINE" (list x0 y0) (list x0 y1) ""))
  (if (and (not (peb-omit-wall-p "REW")) (peb-wall-clad-p "REW" *PEB-WOPEN-REW* sheeting))
    (command "_.LINE" (list x1 y0) (list x1 y1) ""))
  (princ))

;; wall of THIS area that is common with its reference, given its attach position (for *PEB-OMIT-WALL*)
(defun peb-common-wall (pos / p)
  (setq p (strcase (if pos pos "")))
  (cond ((wcmatch p "*BELOW*") "FSW") ((wcmatch p "*ABOVE*") "NSW")
        ((wcmatch p "*RIGHT*") "LEW") ((wcmatch p "*LEFT*") "REW") (T nil)))

;; (dx dy) to move a freshly-drawn area (box [0,l]x[0,w]) into place vs refbnds=(lew rew nsw fsw)
(defun peb-area-offset (pos gap w l refbnds / rlew rrew rnsw rfsw p)
  (setq rlew (nth 0 refbnds) rrew (nth 1 refbnds) rnsw (nth 2 refbnds) rfsw (nth 3 refbnds)
        p (strcase (if pos pos "")) gap (if gap gap 0.0))
  (cond
    ((wcmatch p "*BELOW*") (list rlew (- rnsw gap w)))   ; under ref, share ref NSW
    ((wcmatch p "*ABOVE*") (list rlew (+ rfsw gap)))     ; over ref, share ref FSW
    ((wcmatch p "*RIGHT*") (list (+ rrew gap) rnsw))     ; right of ref, share ref REW
    ((wcmatch p "*LEFT*")  (list (- rlew gap l) rnsw))   ; left of ref, share ref LEW
    (T (list (+ rrew gap) rnsw))))

;; MOVE every entity drawn AFTER prev-last by (dx dy) — collect via entnext (no getboundingbox)
(defun peb-move-since (prev-last off / e ss)
  (if (and prev-last off (or (/= (car off) 0.0) (/= (cadr off) 0.0)))
    (progn
      (setq ss (ssadd) e prev-last)
      (while (setq e (entnext e)) (ssadd e ss))
      (if (> (sslength ss) 0)
        (command "_.MOVE" ss "" "0,0,0" (list (car off) (cadr off) 0.0)))))
  (princ))

;; one border + title block around the whole placed set.  owner 5-Jul: size the margin + title-block strip
;; from the COMBINED extents (not the last/smallest area's params — that made the strip too narrow and the
;; title-block text squish).  Same proportions a single sheet would use for a building this size.
;; bbmin/bbmax (each (x y)) = the PLAN-SET extents, supplied by the orchestrator so the frame wraps the
;; plan ONLY (a cover / sections may share this DXF).  nil nil => fall back to the whole-modelspace EXTMIN/
;; EXTMAX (keeps any interactive/standalone caller working).
(defun peb-draw-combined-frame (bbmin bbmax / exmin exmax cw ch cds bGap sh tbW bL bB bT bR tbX g0x g0y g1x g1y gcx gcy gof lh)
  (vl-catch-all-apply (function (lambda () (command "_.ZOOM" "_E"))))
  (setq exmin (if bbmin bbmin (getvar "EXTMIN")) exmax (if bbmax bbmax (getvar "EXTMAX"))
        cw (- (car exmax) (car exmin)) ch (- (cadr exmax) (cadr exmin))
        cds  (max 0.8 (/ (max cw ch) 45000.0))   ; combined "dim scale" (single-sheet formula)
        bGap (* 3000.0 cds))                       ; uniform border margin for the whole sheet
  ;; owner 5-Jul: the title block VERTICALLY FILLS the sheet, flush between the top & bottom border lines
  ;; (owner: 'side block must vertically fit b/w the lines').  Width = 0.30 x that height keeps the tested
  ;; aspect so the note/load sections stay proportioned (heading sizing already fixed the earlier overlap).
  (setq bL (- (car exmin) bGap) bB (- (cadr exmin) bGap) bT (+ (cadr exmax) bGap) sh (- bT bB)
        tbW (* sh 0.30)
        tbX (+ (car exmax) (* 3500.0 cds)) bR (+ tbX tbW))
  (if *PEB-MA-TBDATA* (peb-titleblock-mammut tbX bB tbW sh *PEB-MA-TBDATA*))
  (draw-border bL bB bR bT)
  ;; owner 5-Jul: ONE big title at the TRUE combined top-centre (over the plan, left of the title block) —
  ;; correct for every attach direction since no area draws its own title in multi-area mode.
  (setvar "CLAYER" "TEXT")
  (txt-bold "MC" (list (/ (+ (car exmin) (car exmax)) 2.0) (+ (cadr exmax) (* bGap 0.5)))
            (* sh 0.0072) 0 "COLUMN LAYOUT PLAN")
  ;; owner 5-Jul (multi-area): the FOUR outer wall labels drawn ONCE around the whole combined building
  ;; (bbox supplied by the driver as *PEB-MA-BLDG-BBOX* = (x0 y0 x1 y1)) — never repeated per stacked area.
  (if *PEB-MA-BLDG-BBOX*
    (progn
      (setq g0x (nth 0 *PEB-MA-BLDG-BBOX*) g0y (nth 1 *PEB-MA-BLDG-BBOX*)
            g1x (nth 2 *PEB-MA-BLDG-BBOX*) g1y (nth 3 *PEB-MA-BLDG-BBOX*)
            gcx (/ (+ g0x g1x) 2.0) gcy (/ (+ g0y g1y) 2.0) gof (* 3200.0 cds) lh (* sh 0.0052))
      (txt-bold "MC" (list gcx (+ g1y gof)) lh 0  "FSW - FAR SIDE WALL")
      (txt-bold "MC" (list gcx (- g0y gof)) lh 0  "NSW - NEAR SIDE WALL")
      (txt-bold "MC" (list (- g0x gof) gcy) lh 90 "LEW - LEFT END WALL")
      (txt-bold "MC" (list (+ g1x gof) gcy) lh 90 "REW - RIGHT END WALL")))
  (command "_.ZOOM" "_E")
  (princ))

;; ORCHESTRATOR — draw + place every area file, then one shared frame.
;; NB (owner 5-Jul): the CALLER must invoke this AND the DXFOUT/export in ONE top-level form (a progn) —
;; in acad /b, the script reader stalls on the NEXT top-level form after the multi-area draw (an ActiveX/
;; title-block state quirk).  Single-area is unaffected.  e.g.:
;;   (progn (peb-plan-multi-from-files (list ...)) (command "_.ZOOM" "_E") (command "_.DXFOUT" f "16"))
(defun peb-plan-multi-from-files (paths / placed prev-last off aNum pos ref gap w l refbnds i
                                        wgrids lgrids adata apos aref rw rl shared refLet refNum
                                        d2 p2 r2 w2 aNo
                                        first-ent pmin pmax minx miny maxx maxy bbe bbobj bblo bbhi
                                        pr pb bx0 by0 bx1 by1)
  (setq *PEB-SUPPRESS-TB* T *PEB-MULTI-MODE* T placed nil wgrids nil lgrids nil i 0
        *PEB-GRID-LET-OFS* nil *PEB-GRID-NUM-OFS* nil *PEB-REF-SHARED* nil)
  (setq first-ent (entlast))   ; everything drawn AFTER this = the plan set (bounds the combined frame)
  ;; PRE-PASS (owner 10-Jul): the reference area is drawn FIRST and never learns that something attached
  ;; to it, so it kept cladding its own shared wall (two lines at the join).  Scan every file up front and
  ;; record, per REFERENCE area number, which of ITS walls an area sits against.
  ;; ALSO: an area attached ABOVE / LEFT grows AGAINST the letter/number direction (letters run A at the
  ;; top downward, numbers 1 at the left rightward).  There the OUTER area is the attached one, so the
  ;; REFERENCE must carry the offset — and the reference draws first.  Compute the attached area's station
  ;; count statically (peb-count-wgrid / peb-count-lgrid) and hand the offset to the reference.
  (setq shared nil refLet nil refNum nil)
  (foreach path paths
    (setq d2 (MSPL-Read-Data path)
          p2 (MSPL-Get-Str d2 "AR_POSITION")
          r2 (MSPL-Get-Int d2 "AR_REF_AREA")
          w2 (peb-ref-shared-wall p2))
    (if (and r2 (> r2 0) w2)
      (progn
        (setq shared (cons (cons r2 w2) shared))
        (cond
          ((wcmatch (strcase p2) "*ABOVE*")
            (setq refLet (cons (cons r2 (1- (peb-count-wgrid d2))) refLet)))
          ((wcmatch (strcase p2) "*LEFT*")
            (setq refNum (cons (cons r2 (1- (peb-count-lgrid d2))) refNum)))))))
  (foreach path paths
    (setq prev-last (entlast) *PEB-DATA-FILE* path)
    ;; CROSS-AREA GRID CONTINUITY (owner 10-Jul).  *PEB-GRID-LET-OFS* / *PEB-GRID-NUM-OFS* are READ by
    ;; the bubble loops (~3363 / ~3388) but were never SET by anyone, so every attached area restarted
    ;; its letters at A — a lean-to under a 6-letter main building came out B,C instead of G,H.
    ;; Letters run A at the TOP (FSW) downward, so an area attached BELOW continues at refLetters-1
    ;; (the shared wall's letter is counted once, by the reference).  Must be set BEFORE C:PEB-PLAN,
    ;; which draws the bubbles — so read AR_POSITION/AR_REF_AREA from the file here rather than relying
    ;; on the *PEB-AR-* globals, which C:PEB-PLAN only fills in as it draws.
    ;; ABOVE / LEFT / RIGHT are deliberately left at nil (unchanged): they grow against the letter/number
    ;; direction and need their own rule — wiring them blind would renumber existing multi-area sheets.
    (setq adata (MSPL-Read-Data path)
          aNo   (MSPL-Get-Int adata "AREA_NUM"))
    ;; if THIS area is a reference that something attaches to, mark that wall SHARED (hides its wall
    ;; label, its dim stack, its grid bubbles and its sheeting line), and take any offset an ABOVE/LEFT
    ;; attachment pushed onto it
    (setq *PEB-REF-SHARED* (if aNo (cdr (assoc aNo shared))))
    (setq *PEB-GRID-LET-OFS* (if aNo (cdr (assoc aNo refLet)))
          *PEB-GRID-NUM-OFS* (if aNo (cdr (assoc aNo refNum))))
    (if (> i 0)
      (progn
        (setq apos (strcase (MSPL-Get-Str adata "AR_POSITION"))
              aref (MSPL-Get-Int adata "AR_REF_AREA"))
        (setq rw (if aref (cdr (assoc aref wgrids)))    ; reference's letter count (width stations)
              rl (if aref (cdr (assoc aref lgrids))))   ; reference's number count (bay stations)
        ;; BELOW: letters run A at the top downward, so the attached area continues at refLetters-1
        ;; (the shared wall's letter belongs to the reference and is counted once).
        (if (and rw (> rw 1) (wcmatch apos "*BELOW*"))
          (setq *PEB-GRID-LET-OFS* (1- rw)))
        ;; RIGHT: numbers run 1..n left to right — exactly symmetric. The attached area omits its shared
        ;; LEW station, so its first DRAWN station (i=2) must read refBays+1 => offset = refBays-1.
        (if (and rl (> rl 1) (wcmatch apos "*RIGHT*"))
          (setq *PEB-GRID-NUM-OFS* (1- rl)))))
    ;; C:PEB-PLAN itself sets *PEB-OMIT-WALL* from AR_POSITION (it already reads the data) — no re-open here
    (vl-catch-all-apply (function (lambda () (C:PEB-PLAN))))
    (setq w *PEB-MA-WID* l *PEB-MA-LEN* aNum *PEB-AR-NUM*
          pos *PEB-AR-POS* ref *PEB-AR-REF* gap *PEB-AR-GAP*)
    (setq wgrids (cons (cons aNum *PEB-MA-WGRID-N*) wgrids)    ; letters this area used, for the next one
          lgrids (cons (cons aNum *PEB-MA-LGRID-N*) lgrids))   ; numbers this area used
    ;; the reference (first) area fixes the title-block size so it stays CONSTANT (not stretched to the set)
    (if (= i 0) (setq *PEB-MA-FIRST-SHEETH* *PEB-MA-SHEETH* *PEB-MA-FIRST-TBW* *PEB-MA-TBSTRIPW*))
    (setq refbnds (if ref (cdr (assoc ref placed))))
    (if (or (= i 0) (null refbnds) (wcmatch (strcase (if pos pos "STANDALONE")) "*STANDALONE*"))
      (setq off (list 0.0 0.0))
      (setq off (peb-area-offset pos gap w l refbnds)))
    (peb-move-since prev-last off)
    (setq placed (cons (cons aNum (list (car off) (+ (car off) l) (cadr off) (+ (cadr off) w))) placed)
          i (1+ i)))
  (setq *PEB-SUPPRESS-TB* nil *PEB-OMIT-WALL* nil *PEB-MULTI-MODE* nil
        *PEB-GRID-LET-OFS* nil *PEB-GRID-NUM-OFS* nil *PEB-REF-SHARED* nil)   ; globals: never leak into the next drawing
  ;; PLAN-SET EXTENTS — the combined frame must wrap the plan ONLY (a cover / sections may share this DXF).
  ;; Walk every entity drawn since first-ent and union its bounding box (mirrors peb-tile-place).
  (vl-load-com)
  (setq minx nil miny nil maxx nil maxy nil
        bbe (if first-ent (entnext first-ent) (entnext)))
  (while bbe
    (setq bbobj (vlax-ename->vla-object bbe))
    (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-getboundingbox (list bbobj 'bblo 'bbhi))))
      (progn
        (setq bblo (vlax-safearray->list bblo) bbhi (vlax-safearray->list bbhi))
        (if (or (null minx) (< (car bblo) minx)) (setq minx (car bblo)))
        (if (or (null miny) (< (cadr bblo) miny)) (setq miny (cadr bblo)))
        (if (or (null maxx) (> (car bbhi) maxx)) (setq maxx (car bbhi)))
        (if (or (null maxy) (> (cadr bbhi) maxy)) (setq maxy (cadr bbhi)))))
    (setq bbe (entnext bbe)))
  (if minx (setq pmin (list minx miny) pmax (list maxx maxy)))
  ;; RAW building rectangle (no dims/margins) from the placed areas — positions the 4 outer wall labels.
  ;; placed entry = (aNum lew rew nsw fsw).
  (setq bx0 nil by0 nil bx1 nil by1 nil)
  (foreach pr placed
    (setq pb (cdr pr))
    (if (or (null bx0) (< (nth 0 pb) bx0)) (setq bx0 (nth 0 pb)))
    (if (or (null bx1) (> (nth 1 pb) bx1)) (setq bx1 (nth 1 pb)))
    (if (or (null by0) (< (nth 2 pb) by0)) (setq by0 (nth 2 pb)))
    (if (or (null by1) (> (nth 3 pb) by1)) (setq by1 (nth 3 pb))))
  (setq *PEB-MA-BLDG-BBOX* (if bx0 (list bx0 by0 bx1 by1)))
  (peb-draw-combined-frame pmin pmax)
  (setq *PEB-MA-BLDG-BBOX* nil)   ; consumed — clear so it never leaks into the next drawing
  (princ))

;; ============================================================================
;; PEB-PDF — one-click window plot to PDF
;; ============================================================================
;; Asks the user to pick a rectangular window around the drawing.  Everything
;; else is preset:
;;   plotter = "DWG To PDF.pc3"  (Autodesk's built-in PDF driver)
;;   paper   = ISO A3 (420 × 297 mm)
;;   units   = mm,  orientation = Landscape
;;   scale   = Fit to paper
;;   offset  = Centered on paper
;;   pen     = monochrome.ctb (b&w with line weights)
;;   output  = <dwg-folder>/<dwg-name>_<timestamp>.pdf
;;
;; If the AutoCAD prompt order on the user's build differs from below, edit
;; the (command "_-PLOT" …) call to match.  Defaults shown below match
;; AutoCAD 2020+ english/metric.
;; ============================================================================
(defun C:PEB-PDF ( / p1 p2 dwgPath dwgBase pdfPath ts)
  (princ "\n──────────────────────────────────────────────────")
  (princ "\n  MAIMAAR PEB → PDF (window plot)")
  (princ "\n──────────────────────────────────────────────────")
  (princ "\n  Pick the rectangular window around your drawing.")
  (princ "\n  PDF will save next to the .dwg file.\n")

  (setq p1 (getpoint "\nPick FIRST corner of plot window: "))
  (if (null p1) (progn (princ "\nCancelled.") (princ) (exit)))
  (setq p2 (getcorner p1 "\nPick OPPOSITE corner: "))
  (if (null p2) (progn (princ "\nCancelled.") (princ) (exit)))

  ;; Build PDF filename = <dwg name>_<YYYYMMDD-HHMM>.pdf
  (setq ts (rtos (getvar "CDATE") 2 0))
  (setq dwgPath (getvar "DWGPREFIX"))
  (setq dwgBase
    (if (= (getvar "DWGNAME") "Drawing1.dwg")
      "Maimaar_PEB"
      (vl-filename-base (getvar "DWGNAME"))))
  (setq pdfPath (strcat dwgPath dwgBase "_" ts ".pdf"))
  (princ (strcat "\n  → " pdfPath "\n"))

  (setvar "CMDECHO" 0)
  (setvar "BACKGROUNDPLOT" 0)   ; foreground plot — wait until done
  (vl-catch-all-apply
    (function (lambda ()
      (command "_-PLOT"
        "_Yes"                                        ; detailed plot config
        ""                                            ; current layout (Model)
        "DWG To PDF.pc3"                              ; plotter
        "ISO A3 (420.00 x 297.00 MM)"                 ; paper size
        "_Millimeters"                                ; units
        "_Landscape"                                  ; orientation
        "_No"                                         ; plot upside down?
        "_Window"                                     ; plot area
        p1                                            ; window corner 1
        p2                                            ; window corner 2
        "_Fit"                                        ; scale to fit
        "_Center"                                     ; offset = centered
        "_Yes"                                        ; plot styles ON
        "monochrome.ctb"                              ; pen table
        "_Yes"                                        ; plot lineweights
        ""                                            ; shaded plot (default)
        pdfPath                                       ; output file
        "_No"                                         ; save changes to layout?
        "_Yes"                                        ; proceed with plot?
      ))))
  (setvar "CMDECHO" 1)
  (princ (strcat "\nPDF saved → " pdfPath "\n"))
  (princ))

;; ============================================================================
;; PEB-WHAT  —  identify any entity by its LISP source
;; ============================================================================
;; Pick an entity in AutoCAD and the command-line reports:
;;   • Its layer name (e.g. COL-OUTER, COLUMNS, ARROWS, etc.)
;;   • Its entity type (LINE, LWPOLYLINE, MTEXT, MULTILEADER, etc.)
;;   • The most-likely LISP function that drew it
;;   • The friendly name to use in conversation
;;
;; Usage:  type PEB-WHAT, pick an entity, read the report.
;; ============================================================================
(defun C:PEB-WHAT ( / ent edata layer etype handle source friendly tip)
  (princ "\n────────────────────────────────────────────────────")
  (princ "\n  PEB-WHAT  —  identify entity by LISP source")
  (princ "\n────────────────────────────────────────────────────")
  (setq ent (entsel "\n  Pick any entity (or ESC to quit): "))
  (if (null ent) (progn (princ "\n  Cancelled.") (princ) (exit)))
  (setq edata  (entget (car ent)))
  (setq layer  (cdr (assoc 8 edata)))
  (setq etype  (cdr (assoc 0 edata)))
  (setq handle (cdr (assoc 5 edata)))

  ;; Layer + entity-type → source function / friendly name
  (cond
    ;; Building outlines
    ((= layer "COL-OUTER")
      (setq friendly "COL-OUTER")
      (setq source   "make-layer setup + RECTANG in C:PEB-PLAN building outline section")
      (setq tip      "Cyan dashed reference rectangle at column outer face."))

    ((= layer "SHEETING")
      (setq friendly "SHEETING")
      (setq source   "make-layer setup + RECTANG in C:PEB-PLAN building outline section")
      (setq tip      "Cyan continuous rectangle at sheeting outer face (230 mm outside grid)."))

    ((= layer "BORDER")
      (setq friendly "BORDER")
      (setq source   "draw-border function")
      (setq tip      "Drawing sheet border — outermost rectangle on the plot."))

    ;; Grid system
    ((= layer "GRID-LINES")
      (setq friendly "GRID-LINES")
      (setq source   "C:PEB-PLAN — bay/width grid loop")
      (setq tip      "DASHDOT bay or width grid line. Bay = vertical, width = horizontal interior only."))

    ((= layer "GRID")
      (setq friendly "GRID bubble")
      (setq source   "grid-bubble function")
      (setq tip      "Numbered (bay) or lettered (width) circle. Drawn at every grid position."))

    ;; Columns
    ((= layer "COLUMNS")
      (setq friendly "COLUMNS layer")
      (setq source
        (cond
          ((= etype "LWPOLYLINE")
            "RECTANG inside draw-I-column-lengthwise / draw-I-column-widthwise / draw-RCC-column")
          ((= etype "HATCH")
            "HATCH SOLID inside the column draw functions")
          (T (strcat "type=" etype " — unknown"))))
      (setq tip      "Red column flange/web rectangle. Shape depends on column type."))

    ((= layer "BOLTS")
      (setq friendly "BOLTS")
      (setq source   "(command DONUT …) inside draw-I-column-lengthwise / -widthwise")
      (setq tip      "White anchor-bolt donut. 4 per column, ~25 mm radius."))

    ((= layer "COL-CENTER")
      (setq friendly "COL-CENTER")
      (setq source   "(legacy — col-crosshair function, currently unused)")
      (setq tip      "Reserved CENTER linetype layer."))

    ;; Roof indicators
    ((= layer "RIDGE")
      (setq friendly "RIDGE LINE")
      (setq source   "(command LINE …) in C:PEB-PLAN ridge cond block")
      (setq tip      "Blue HIDDEN-linetype ridge line. CS, MS, RC, MG, BF frame types."))

    ((= layer "RAFTER")
      (setq friendly "RAFTER")
      (setq source   "(command LINE …) in C:PEB-PLAN rafter loop")
      (setq tip      "Grey HIDDEN-linetype rafter centerline."))

    ((= layer "ARROWS")
      (setq friendly "ARROWS layer")
      (setq source
        (cond
          ((= etype "LWPOLYLINE")
            "arrow-up-big or arrow-down-big function (slope arrow shape)")
          ((or (= etype "MULTILEADER") (= etype "MLEADER"))
            "peb-make-mleader / peb-label-with-leader (RIDGE LINE / RAFTER / END FRAME)")
          ((= etype "HATCH")
            "HATCH SOLID inside arrow-up-big / arrow-down-big")
          (T (strcat "type=" etype " — check ARROWS layer"))))
      (setq tip      "Cyan slope-arrow polygon OR MLEADER text+leader."))

    ;; Text
    ((= layer "TEXT")
      (setq friendly "TEXT label")
      (setq source
        (cond
          ((= etype "TEXT")  "txt() or txt-bold() helper — body label")
          ((= etype "MTEXT") "peb-make-mtext / peb-make-mtext-line — multi-line label")
          (T (strcat "type=" etype))))
      (setq tip      "Body text — title, subtitle, FSW/NSW/LEW/REW labels, slope ratio, etc."))

    ;; Dimensions
    ((= layer "DIMENSIONS")
      (setq friendly "DIM (group / overall)")
      (setq source   "peb-dim-h-stretch / peb-dim-height-stretch — native AcDbRotatedDimension")
      (setq tip      "Bay group dim, overall length dim, width dim chain, or building width dim."))

    ;; Title block
    ((= layer "TITLEBLOCK")
      (setq friendly "title block cell")
      (setq source   "peb-build-title-table — AcDbTable cell separator"))

    ((= layer "TB-HEADER")
      (setq friendly "title block header")
      (setq source   "peb-build-title-table — table header row outline"))

    ;; Structure (legacy / north arrow)
    ((= layer "STRUCTURE")
      (setq friendly "STRUCTURE")
      (setq source   "draw-north-arrow function")
      (setq tip      "North arrow shape — circle + 2 chevrons."))

    (T
      (setq friendly "UNKNOWN")
      (setq source   (strcat "Layer '" layer "' not in known PEB layers."))
      (setq tip      "Either a user-drawn entity or a layer not registered by PEB-PLAN.")))

  (princ (strcat "\n  Layer       : " layer))
  (princ (strcat "\n  Entity type : " etype))
  (princ (strcat "\n  Handle      : " handle))
  (princ "\n  ────────")
  (princ (strcat "\n  Friendly    : " friendly))
  (princ (strcat "\n  Source      : " source))
  (if tip (princ (strcat "\n  Note        : " tip)))
  (princ "\n────────────────────────────────────────────────────\n")
  (princ))

;; ============================================================================
;;  MEZZANINE FLOOR LAYOUT PLAN (per floor) — for multi-storey mezzanines (owner 8-Jul).
;;  One sheet per floor: mezzanine footprint + columns (I-section) + main beams (along the
;;  length) + joists (across the width) + grid bubbles + a "MEZZANINE FLOOR-n LAYOUT PLAN"
;;  title.  Extent full-interior or partial by grid lines (MZ_GRID_BAY_FROM/TO).
;;  Entry: (peb-mezz-floor-from-file <path> <floorNum>).  Reuses the CLP helpers.
;; ============================================================================
(defun peb-mzfp-bays (data len / nb pts cum i sp rem)
  (setq nb (MSPL-Get-Int data "NUMBAYS")) (if (or (null nb) (< nb 1)) (setq nb 1))
  (setq pts (list 0.0) cum 0.0 i 0)
  (while (< i nb)
    (setq sp (MSPL-Get-Num data (strcat "BAY" (itoa (1+ i)))) rem (- len cum))
    (cond ((= i (1- nb)) (setq sp rem)) ((and sp (> sp 0.0) (< sp rem)) T) (T (setq sp (/ rem (float (- nb i))))))
    (setq cum (+ cum sp) pts (append pts (list cum)) i (1+ i)))
  pts)

(defun peb-mzfp-splist (data / spList tmp plus seg atP cnt val k)
  (setq spList '())
  (vl-catch-all-apply (function (lambda ()
    (setq tmp (MSPL-Get-Str data "MZ_COL_SPACING"))
    (while (and tmp (> (strlen tmp) 0))
      (setq plus (vl-string-search "+" tmp))
      (if plus (setq seg (substr tmp 1 plus) tmp (substr tmp (+ plus 2))) (setq seg tmp tmp ""))
      (setq seg (vl-string-trim " " seg) atP (vl-string-search "@" seg))
      (if atP (progn (setq cnt (atoi (substr seg 1 atP)) val (atof (substr seg (+ atP 2))) k 0)
                     (while (< k cnt) (setq spList (cons val spList) k (1+ k))))
        (if (> (atof seg) 0.0) (setq spList (cons (atof seg) spList)))))
    (setq spList (reverse spList)))))
  (if (null spList) (setq spList (list 10000.0)))
  spList)

(defun peb-draw-mezz-floor-plan (data len wid floorNum / spList bayPts glF glT offF offT fx0 fx1 fy0 fy1
                                 ys xs acc s2 x y colD savedWeb jx i gbr letterIdx sc band inset
                                 mzRcc rccXs rccYs floorSys jspSys lvl lvlStr specStr mzJoist
                                 dimX yprev yy jy beamHalf joistHalf secHalf secSp sx isGrating
                                 bayA bayB legX legY rowH sampleLen L colR)
  (setq sc (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (setq inset (max 300.0 (min 1000.0 (* (min len wid) 0.10))))
  (setq spList (peb-mzfp-splist data) bayPts (peb-mzfp-bays data len))

  ;; WIDTH footprint — the SAME peb-mz-width-band as the CLP so the two sheets agree.  This runs
  ;; STANDALONE (no plan drawn), so seed *PEB-WGRID-YS* from the width module lines to make the
  ;; grid-LETTER placement work here too; if the plan already set it, keep that.
  (if (not (and (boundp '*PEB-WGRID-YS*) *PEB-WGRID-YS*))
    (setq *PEB-WGRID-YS* (vl-sort (peb-main-column-ys data wid) '<)))
  (setq band (peb-mz-width-band data wid inset) fy0 (car band) fy1 (cadr band))

  ;; LENGTH footprint — grid bays + offsets (mirror the CLP), else a 6% inset.
  (setq glF (MSPL-Get-Int data "MZ_GRID_BAY_FROM") glT (MSPL-Get-Int data "MZ_GRID_BAY_TO")
        offF (MSPL-Get-Num data "MZ_OFFSET_FROM") offT (MSPL-Get-Num data "MZ_OFFSET_TO"))
  (if (null offF) (setq offF 0.0))
  (if (null offT) (setq offT 0.0))
  (if (and glF glT (> glF 0) (> glT glF) (<= glT (length bayPts)))
    (progn
      (setq fx0 (+ (nth (1- glF) bayPts) offF) fx1 (+ (nth (1- glT) bayPts) offT))
      (setq fx0 (max 0.0 (min fx0 len)) fx1 (max 0.0 (min fx1 len)))
      (if (>= fx0 fx1) (setq fx0 (nth (1- glF) bayPts) fx1 (nth (1- glT) bayPts))))
    (setq fx0 (* len 0.06) fx1 (- len (* len 0.06))))

  ;; width column lines (ys) — mezzanine columns subdivide EACH main width module between the main PEB
  ;; columns (owner 11-Jul), the same rule as the CLP overlay, so the two sheets agree.  Beams + columns
  ;; are drawn at every station (this is the mezzanine's own framing plan — the main-line columns show
  ;; too, unlike the CLP overlay which encircles only the NEW ones).
  (setq ys (peb-mezz-col-ys data wid fy0 fy1 (if spList (car spList) 6000.0)))
  (setq xs '())
  (foreach x bayPts (if (and (>= x (- fx0 1.0)) (<= x (+ fx1 1.0))) (setq xs (append xs (list x)))))
  (if (null xs) (setq xs (list fx0 fx1)))

  ;; light diagonal hatch first (owner 12-Jul), then the deck outline over it
  (vl-catch-all-apply (function (lambda () (peb-mezz-hatch fx0 fy0 fx1 fy1 1600.0))))
  ;; deck outline
  (peb-comp-layer "COMP-MEZZ" 6)
  (peb-comp-poly (list (list fx0 fy0) (list fx1 fy0) (list fx1 fy1) (list fx0 fy1)))

  ;; floor system -> joist rule (owner 11-Jul): PRECAST / HOLLOW-CORE = beams only (no joists);
  ;; GRATING / CHEQUERED PLATE = closer joists at 1220 mm (4 ft); DECK + SLAB = joists at MZ_JOIST.
  (setq floorSys (strcase (peb-tb-or (MSPL-Get-Str data (strcat "MZ" (itoa floorNum) "_FLOOR"))
                                     (MSPL-Get-Str data "MZ1_FLOOR"))))
  (setq mzJoist (MSPL-Get-Num data "MZ_JOIST"))
  (if (or (null mzJoist) (<= mzJoist 0.0)) (setq mzJoist 1500.0))
  (cond ((wcmatch floorSys "*PRECAST*,*HOLLOW*")        (setq jspSys nil))
        ((wcmatch floorSys "*GRAT*,*PLATE*,*CHEQ*")     (setq jspSys 1220.0))
        (T                                              (setq jspSys mzJoist)))

  ;; ---- FRAMING MEMBERS drawn as their TOP FLANGE to scale (owner 12-Jul): main beam 200mm, joist
  ;; 150mm, secondary joist 100mm top flange.  Each on its own layer so COLOUR + LINE-THICKNESS come
  ;; BYLAYER (beam blue/0.50, joist grey/0.25, sec-joist grey/0.13 — the "material" line-weight standard).
  ;; Floor-system content: decking sheet -> beams + joists; hollow-core/precast -> beams only;
  ;; grating/chequered plate -> beams + joists + SECONDARY joists. ----
  ;; flange HALF-widths, exaggerated ~2.5x from the true 200/150/100mm so the I-profiles READ at plan
  ;; scale (owner 12-Jul: "draw as real steel profiles ... visibly exaggerated") — proportions kept.
  (setq beamHalf 250.0 joistHalf 180.0 secHalf 120.0)
  (setq isGrating (wcmatch floorSys "*GRAT*,*CHEQ*,*PLATE*"))

  ;; JOISTS — 150mm double-line flange ALONG THE LENGTH, spaced across the width at jspSys.  None for
  ;; precast / hollow-core (jspSys nil).
  (if jspSys
    (progn
      (peb-comp-layer "COMP-MEZZ-JOIST" 8)
      (setvar "CLAYER" "COMP-MEZZ-JOIST")
      (setq jy (+ fy0 jspSys))
      (while (< jy (- fy1 100.0))
        (vl-catch-all-apply (function (lambda () (peb-mezz-mainbeam fx0 jy fx1 jy joistHalf))))
        (setq jy (+ jy jspSys)))
      (vl-catch-all-apply (function (lambda ()
        (txt "MC" (list (/ (+ fx0 fx1) 2.0) (+ fy1 (/ 900.0 sc))) (/ 300.0 sc) 0.0
             (strcat "JOISTS ALONG LENGTH @ " (peb-comma (rtos jspSys 2 0)) " C/C")))))))

  ;; SECONDARY JOISTS — grating / chequered plate only: 100mm double-line flange PERPENDICULAR to the
  ;; joists (WIDTH direction), spaced along the length at HALF the joist spacing.  Shown in ONE
  ;; representative bay as TYPICAL (a full grid of them across the floor buries the plan) — owner 12-Jul.
  (if (and jspSys isGrating (> (length xs) 1))
    (progn
      (peb-comp-layer "COMP-MEZZ-JOIST-SEC" 8)
      (setvar "CLAYER" "COMP-MEZZ-JOIST-SEC")
      (setq secSp (/ jspSys 2.0) bayA (nth 0 xs) bayB (nth 1 xs) sx (+ bayA secSp))
      (while (< sx (- bayB 1.0))
        (vl-catch-all-apply (function (lambda () (peb-mezz-mainbeam sx fy0 sx fy1 secHalf))))
        (setq sx (+ sx secSp)))
      (vl-catch-all-apply (function (lambda ()
        (txt "MC" (list (/ (+ bayA bayB) 2.0) (- fy0 (/ 900.0 sc))) (/ 280.0 sc) 0.0
             (strcat "SECONDARY JOISTS @ " (peb-comma (rtos secSp 2 0)) " C/C (TYP.)")))))))

  ;; MAIN BEAMS — 200mm double-line flange (heaviest), in the WIDTH direction, column to column, one at
  ;; each length column line (xs).  Drawn LAST so the heavy beams read on top of the joists + secondaries.
  (peb-comp-layer "COMP-MEZZ-BEAM" 5)
  (setvar "CLAYER" "COMP-MEZZ-BEAM")
  (foreach x xs (vl-catch-all-apply (function (lambda () (peb-mezz-mainbeam x fy0 x fy1 beamHalf)))))
  (if (> (length xs) 1)
    (vl-catch-all-apply (function (lambda ()
      (txt-bold "MC" (list (+ (nth 1 xs) (+ beamHalf (/ 260.0 sc))) (/ (+ fy0 fy1) 2.0)) (/ 300.0 sc) 90.0 "MAIN BEAM (TYP.)")))))

  ;; ---- LEGEND / KEY (owner 12-Jul "beautiful") — the framing members, each sample drawn on its own
  ;; layer so it shows the real colour + line-thickness + top-flange width, with its NAME.  Lower-left,
  ;; below the plan (secondary joist row only when this floor system has secondaries). ----
  (setq legX fx0
        legY (- fy0 (/ 1300.0 sc))
        rowH (/ 640.0 sc)
        sampleLen (max 2000.0 (* (- fx1 fx0) 0.05)))
  (foreach L (list (list "COMP-MEZZ-BEAM"      5 beamHalf  "MAIN BEAM"       T)
                   (list "COMP-MEZZ-JOIST"     8 joistHalf "JOIST"           (if jspSys T nil))
                   (list "COMP-MEZZ-JOIST-SEC" 8 secHalf   "SECONDARY JOIST" (if (and jspSys isGrating) T nil)))
    (if (nth 4 L)
      (progn
        (peb-comp-layer (nth 0 L) (nth 1 L))
        (setvar "CLAYER" (nth 0 L))
        (vl-catch-all-apply (function (lambda () (peb-mezz-mainbeam legX legY (+ legX sampleLen) legY (nth 2 L)))))
        (setvar "CLAYER" "TEXT")
        (vl-catch-all-apply (function (lambda ()
          (txt "ML" (list (+ legX sampleLen (/ 500.0 sc)) legY) (/ 300.0 sc) 0.0 (nth 3 L)))))
        (setq legY (- legY rowH)))))

  ;; columns — RCC host draws the existing concrete pillars; else steel mezzanine columns
  (setq mzRcc (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_RCC") "")) "YES"))
  (setq colD (peb-col-web-depth (apply 'max (cons 6000.0 spList))) savedWeb *PEB-COL-WEB* *PEB-COL-WEB* colD)
  (if mzRcc
    (progn
      (peb-comp-layer "COMP-RCC" 8)
      (setq rccXs (peb-mezz-stations (MSPL-Get-Str data "MZ_RCC_BAY") fx0 fx1)
            rccYs (peb-mezz-stations (MSPL-Get-Str data "MZ_RCC_COL") fy0 fy1))
      (foreach x rccXs
        (foreach y rccYs
          (vl-catch-all-apply (function (lambda () (peb-draw-rcc-pillar x y (* colD 1.40))))))))
    ;; steel mezzanine columns drawn as TUBE (round) columns — a CIRCLE — to match the Mammut mezzanine
    ;; plan (033: "MEZZ COLUMN" = circles), the design manual (mezz columns preferably tube), and the
    ;; CLP overlay's encircled columns.  On COLUMNS (red), like the reference.
    (progn
      (peb-comp-layer "COLUMNS" 1)
      (setvar "CLAYER" "COLUMNS")
      (setq colR (max 150.0 (* colD 0.45)))
      (foreach x xs
        (foreach y ys
          (vl-catch-all-apply (function (lambda ()
            (entmake (list (cons 0 "CIRCLE") (cons 8 "COLUMNS") (list 10 x y 0.0) (cons 40 colR))))))))))
  (setq *PEB-COL-WEB* savedWeb)

  ;; SHOW THE MEZZANINE COLUMN SPACING (owner 11-Jul) — a vertical dim chain of the column lines, just
  ;; inside the deck's left edge.
  (if (> (length ys) 1)
    (progn
      (setq dimX (+ fx0 (* (min len wid) 0.03)) yprev (car ys))
      (foreach yy (cdr ys)
        (vl-catch-all-apply (function (lambda ()
          (peb-dim-height-stretch fx0 dimX yprev yy (peb-comma (rtos (- yy yprev) 2 0))))))
        (setq yprev yy))))

  ;; grid bubbles — building bay NUMBERS along the top, width LETTERS down the left (A at the top)
  (setq gbr (max 900.0 (* 620.0 sc)) i 0)
  (foreach x bayPts
    (if (and (>= x (- fx0 1.0)) (<= x (+ fx1 1.0)))
      (progn (setvar "CLAYER" "GRID-LINES")
             (entmake (list (cons 0 "LINE") (cons 8 "GRID-LINES") (list 10 x fy1 0.0) (list 11 x (+ fy1 (* 2.0 gbr)) 0.0)))
             (setvar "CLAYER" "GRID")
             (grid-bubble x (+ fy1 (* 2.0 gbr) gbr) (itoa (1+ i)) "D")))
    (setq i (1+ i)))
  (setq letterIdx 0)
  (foreach y (reverse ys)
    (setvar "CLAYER" "GRID-LINES")
    (entmake (list (cons 0 "LINE") (cons 8 "GRID-LINES") (list 10 fx0 y 0.0) (list 11 (- fx0 (* 2.0 gbr)) y 0.0)))
    (setvar "CLAYER" "GRID")
    (grid-bubble (- fx0 (* 2.0 gbr) gbr) y (peb-grid-letter letterIdx) "R")
    (setq letterIdx (1+ letterIdx)))

  ;; deck spec note (what the floor IS).  The members are distinguished by their flange width + BYLAYER
  ;; line-weight ("material" = line thickness, owner 12-Jul) and are NAMED on the plan (MAIN BEAM / JOISTS
  ;; / SECONDARY JOISTS); no steel-section text and no mezzanine column SIZE are shown here.
  (setq specStr (cond ((wcmatch floorSys "*PRECAST*,*HOLLOW*")    "PRECAST / HOLLOW-CORE SLAB (BY OTHERS)")
                      ((wcmatch floorSys "*GRAT*,*CHEQ*,*PLATE*") "STEEL GRATING / CHEQUERED PLATE ON JOISTS")
                      (T                                          "0.7mm DECKING PANEL + 100mm CONCRETE SLAB")))
  (setvar "CLAYER" "TEXT")
  (vl-catch-all-apply (function (lambda ()
    (txt "MC" (list (/ (+ fx0 fx1) 2.0) (- fy0 (/ 1600.0 sc))) (/ 320.0 sc) 0.0 specStr))))

  ;; blue floor TITLE + LEVEL tag below the plan.
  ;; BUGFIX (owner note): txt-bold already multiplies by *PEB-TEXT-SCALE*, so pass (/ H sc) — the old
  ;; (* 450 sc) rendered the title at H*sc^2, which blew up on large buildings.
  (setq lvl (MSPL-Get-Num data "MZ_FLOOR_HT"))
  (if (null lvl) (setq lvl 0.0))
  (setq lvlStr (if (> lvl 0.0)
                 (strcat "  (LEVEL approx. +" (peb-comma (rtos (* lvl floorNum) 2 0)) " MM, BOTTOM OF BEAM)")
                 ""))
  (setvar "CLAYER" "TEXT") (setvar "CECOLOR" "5")
  (txt-bold "MC" (list (/ (+ fx0 fx1) 2.0) (- fy0 (/ 3200.0 sc))) (/ 700.0 sc) 0
            (strcat "MEZZANINE FLOOR-" (itoa floorNum) " LAYOUT PLAN" lvlStr))
  (setvar "CECOLOR" "BYLAYER")
  (princ))

(defun C:PEB-MEZZ-FLOOR (/ dataFile data len wid floorNum)
  (setq dataFile (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*) *PEB-DATA-FILE* nil))
  (if (null dataFile) (progn (princ "\nPEB-MEZZ-FLOOR: no data file.") (exit)))
  ;; Create the standard layers (COLUMNS / BOLTS / GRID / GRID-LINES / TEXT …) the drawer needs.  C:PEB-PLAN
  ;; runs this at start; the standalone floor-plan path must too, or a bare (setvar "CLAYER" "COLUMNS")
  ;; errors under acad /b and aborts the sheet (only COMP-* layers, created on demand, survive).
  (if (boundp 'peb-std-setup)
    (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (setq data (MSPL-Read-Data dataFile))
  ;; Skip CLEANLY when this area carries no mezzanine, so the render pipeline may call this for EVERY
  ;; area and only areas WITH a mezzanine produce a sheet (no spurious/blank mezzanine plans).
  (if (/= (strcase (MSPL-Get-Str data "MZ_TOGGLE")) "YES")
    (progn (princ "\nPEB-MEZZ-FLOOR: no mezzanine on this area — skipped.") (setvar "CLAYER" "0"))
    (progn
      (setq len (MSPL-Get-Num data "LENGTH") wid (MSPL-Get-Num data "WIDTH"))
      (if (or (null len) (<= len 0)) (setq len 30000.0))
      (if (or (null wid) (<= wid 0)) (setq wid 20000.0))
      (setq floorNum (if (and (boundp '*PEB-MEZZ-FLOOR-NUM*) *PEB-MEZZ-FLOOR-NUM*) *PEB-MEZZ-FLOOR-NUM* 1))
      (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ (max len wid 1.0) 45000.0))) *PEB-DIM-SCALE* *PEB-TEXT-SCALE*)
      (vl-catch-all-apply (function (lambda () (peb-draw-mezz-floor-plan data len wid floorNum))))
      (setvar "CLAYER" "0")
      (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data (strcat "MEZZANINE FLOOR-" (itoa floorNum) " LAYOUT PLAN")))))
      (vl-catch-all-apply (function (lambda () (command "_.ZOOM" "_E"))))))
  (princ))

(defun peb-mezz-floor-from-file (path floorNum / prev-last prev-max-x)
  (setq prev-last (entlast))
  ;; the frame must wrap THIS sheet, not every sheet drawn so far (see
  ;; peb-frame-and-titleblock).  Same marker the tiler already uses.
  (setq *PEB-SHEET-MARK* prev-last)
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path *PEB-MEZZ-FLOOR-NUM* floorNum)
  (C:PEB-MEZZ-FLOOR)
  (setq *PEB-DATA-FILE* nil *PEB-MEZZ-FLOOR-NUM* nil)
  (if (boundp 'peb-tile-place) (peb-tile-place prev-last prev-max-x))
  (princ))

(princ "\nMAIMAAR PEB-PLAN (Phase-2 standalone) loaded [BUILD 2026-07-04-R2 border-centre+bubble]. Command: PEB-PLAN")
(princ "\nPDF helper:    type PEB-PDF  then pick window corners.")
(princ "\nIdentify tool: type PEB-WHAT then pick any entity to see its LISP source.\n")
(princ)
