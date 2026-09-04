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

;; ---- A MAIN LINE TAKES A LETTER, AN INFILL POST TAKES A PRIME  (owner 3-Sep-2026) --------
;; "Bubble of dimension should be based on post columns & in case the main columns are not
;;  aligned, then use A', B' like this."
;;
;; The width grid every sheet letters is the MERGED one: the width-module lines (the multi-span
;; frame columns) plus the end-wall / mezzanine posts between them.  Lettering it straight through
;; gives every station equal billing, so a reader cannot tell a primary frame line from a wind
;; post - and they carry different connections.  The prime says which is which without adding a
;; second bubble shape, which would only re-open "the bubbles are not the same".
;;
;;   A  A'  B  B'  C  C'  D  D'  E  E'  F        <- 5@15,240 split at 7,620
;;
;; A is at the FAR side wall and the letters run downward (rule 4B.34), so a station's letter is
;; the number of MAIN lines strictly above it, and a post carries the letter of the main line
;; above it with a prime.  Skip-I comes free from peb-grid-letter, and the cross-area offset is
;; applied exactly as the plain lettering applies it.
(defun peb-is-main-station (y mods / hit)
  (setq hit nil)
  (foreach m mods (if (< (abs (- y m)) 5.0) (setq hit T)))
  hit)

(defun peb-width-mark (y stations mods / n ofs)
  (if (null mods)
    ;; no module chain to judge against - every station is a main line, as before
    (peb-width-letter (peb-station-index y stations) (length stations))
    (progn
      (setq n 0 ofs (if *PEB-GRID-LET-OFS* *PEB-GRID-LET-OFS* 0))
      (foreach st stations
        (if (and (> st (+ y 5.0)) (peb-is-main-station st mods)) (setq n (1+ n))))
      (if (peb-is-main-station y mods)
        (peb-grid-letter (+ n ofs))
        (strcat (peb-grid-letter (+ (max 0 (1- n)) ofs)) "'")))))

;; The whole merged grid's marks, in PLAN ORDER (index 0 = y=0 = the near side wall), so a
;; caller that already works in station indices can look one up instead of re-deriving it.
;; The one bubble radius lives in MAIMAAR_PEB_Standard.lsp (peb-bub-r), because Roof, Elevation
;; and Section ask for it and none of them is guaranteed to have Plan.lsp loaded beside it.

(defun peb-width-marks (stations mods / out)
  (setq out nil)
  (foreach st stations (setq out (append out (list (peb-width-mark st stations mods)))))
  out)

;; ---- MERGING TWO CHAINS ACROSS ONE WIDTH  (owner 3-Sep-2026) -----------------------------
;; The grid every sheet letters is the MERGED one - the width-module lines together with the
;; end-wall / mezzanine posts between them (4B.61).  The Column Layout Plan has always merged
;; them inline; these are the same three steps, named, so the mezzanine floor plan can ask for
;; the identical list instead of building a second one that agrees only by luck.
;;
;; The tolerance is 5 mm, not 1 mm, and deliberately: two chains written across the SAME width
;; from two different expressions land a millimetre or two apart on the lines they share, and at
;; 1 mm those stop coinciding - every shared line doubles into two bubbles a hair's breadth apart.
(defun peb-merge-ys (lst tol / srt out)
  (if (null tol) (setq tol 5.0))
  (setq srt (vl-sort lst '<) out '())
  (foreach v srt
    (if (or (null out) (> (abs (- v (last out))) tol))
      (setq out (append out (list v)))))
  out)

;; Do two station lists describe the same lines?  Used to decide whether a chain is worth its own
;; dimension rung, or is already being stated by the one beside it.
(defun peb-ys-same (a b tol / ok i)
  (if (null tol) (setq tol 5.0))
  (if (or (null a) (null b) (/= (length a) (length b)))
    nil
    (progn
      (setq ok T i 0)
      (while (< i (length a))
        (if (> (abs (- (nth i a) (nth i b))) tol) (setq ok nil))
        (setq i (1+ i)))
      ok)))

;; A chain's stations, or NIL when the BSF states no chain - peb-width-stations answers a blank
;; expression with the two end lines, which reads as a real chain and would print "76,200" as if
;; the estimator had entered it.
(defun peb-mzfp-stations (expr total)
  (if (and expr (/= expr "") (vl-string-search "@" expr))
    (peb-width-stations expr total)
    nil))

;; index of the station nearest y, for the no-module fallback above
(defun peb-station-index (y stations / i best bd d)
  (setq i 0 best 0 bd 1e12)
  (foreach st stations
    (setq d (abs (- st y)))
    (if (< d bd) (setq bd d best i))
    (setq i (1+ i)))
  best)

;; The MAIN width-module stations for this area, in the same coordinates the grid is drawn in.
(defun peb-width-mods (data wid)
  (if (boundp 'peb-width-stations)
    (peb-width-stations (peb-tb-or (MSPL-Get-Str data "MODEXPR") "") wid)
    nil))

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
(defun peb-bub-radius (minSp)
  ;; `minSp` is accepted and IGNORED. 4B.31 repealed sizing a bubble against its neighbours, and
  ;; this was the last place still doing it: 1100 x TS - a different size from the plan's 720 -
  ;; capped at 0.30 x the tightest bay. Both halves were wrong, and the four framing/sheeting
  ;; views are the ones that used it. Crowding is answered by the STAGGER (peb-bub-rows), never
  ;; by shrinking: the bubble and the gap shrink together, so shrinking buys no clearance and
  ;; makes the letters smallest on exactly the big buildings that are already at 1:800.
  ;; The parameter stays so the four call sites need no change.
  (peb-bub-r))

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
  ;; ONE radius, asked for - never inherited.  *PEB-BUBRAD* used to be read here and set by only
  ;; some of the sheets, so a sheet that set nothing drew whatever size the PREVIOUS sheet had
  ;; left in the global.  peb-bub-r (Standard.lsp) is 4B.31's 720 x TEXT-SCALE for every sheet.
  (setq r (peb-bub-r) prev (getvar "CLAYER") pc (getvar "CECOLOR"))
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
;;
;; THE BSF IS THE SINGLE SOURCE OF TRUTH (owner, 3-Sep-2026). CLEARHEIGHT is the ONE number the
;; BSF carries and HEIGHT_REF says what it means, so this must read it through peb-clear-height —
;; the same helper the section and the elevations use. Reading the RAW field added the haunch and
;; the purlin to a figure that ALREADY included them whenever the basis was "Eave Height", and the
;; title block printed an eave ~800 mm taller than the one the BSF stated and the section drew.
;; On a clear-height basis peb-clear-height returns the field unchanged, so that path is untouched.
(defun peb-tb-eave-height (data / raw clr wid ng eff)
  (setq raw (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT") "0"))
        clr (peb-clear-height data)
        wid (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        ng  (atoi (peb-tb-or (MSPL-Get-Str data "NUMGABLES") "1")))
  (if (< ng 1) (setq ng 1))
  (setq eff (if (> wid 0.0) (/ wid ng) 0.0))
  (if (<= raw 0.0)
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

;; -- RULE 4B.45 - A COLUMN SYMBOL AND ITS BUBBLE MUST BOTH READ (owner 29-Aug) --------
;; "It is shown in the column layout plan but these are too small", and
;; "appareantly we must see the I and there should be small gap and then bubble must come."
;;
;; The mezzanine stub column is sized off the MEZZANINE spacing (~8.3 m / 35 = ~240 mm deep),
;; because that is its real section - lighter than the main frame, correctly.  But a 240 mm
;; section on a 93 m building auto-fitted to A4 plots at about four tenths of a millimetre, and
;; the bubble at 0.72 D lands INSIDE the linework: neither the I nor the gap survives.
;;
;; A member is drawn at its real size (rule 4B.42).  A SYMBOL - which is what this is, a mark
;; saying "this column is new" - is drawn to READ, like a grid bubble (rule 4B.31).  So the stub
;; gets a legibility FLOOR expressed in *PEB-TEXT-SCALE*, the engine's constant-on-paper unit,
;; and is CAPPED at three quarters of the main column so the hierarchy never inverts: the stub
;; must still look lighter than the frame column beside it.
;;
;; The bubble is then sized off the I it encircles, not off a constant: the I-section's half
;; diagonal is 0.539 D (D deep x 0.40 D wide), so 0.78 D leaves a clear gap all the way round.
(defun peb-mz-stub-depth (rawD wid)
  (min (max rawD (* 650.0 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)))
       (max rawD (* 0.75 (peb-col-web-depth wid)))))
(defun peb-mz-bubble-r (colD) (* colD 0.78))   ; I half-diagonal 0.539 D + a visible gap

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
;; ---- THE FALLBACK DIVISION, ON THE SAME RULE AS EVERYONE ELSE  (owner 3-Sep-2026) --------
;; Used only when the data carries no end-wall spacing string at all.  It used to divide at
;; 6250 mm with `fix` (truncate) - a THIRD rule, matching neither geometryRules.js in the browser
;; nor geometryDivision.ts on the server, so a building with a blank spacing drew one chain and
;; was priced on another.
;;
;; The rule is now the owner's: every WIDTH-MODULE line carries a column, and a module wider than
;; the cap is split equally into the fewest parts that fit under it.  A blank spacing therefore
;; falls back to the same chain the forms would have filled in.
(defun peb-post-split-max () 8000.0)             ; mm - the ONE cap, mirroring POST_SPLIT_MAX

;; The fewest equal parts of `m` that each come in at or under the cap.
(defun peb-post-split-count (m / n)
  (setq n 1)
  (while (and (> (/ m (float n)) (peb-post-split-max)) (< n 200)) (setq n (1+ n)))
  n)

;; How many end-wall bays across a plain width, when there is no module chain to follow.
(defun peb-ew-auto-cols (wid) (peb-post-split-count wid))

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

(defun peb-draw-bracing (bayPts widthPts wid ox oy lewBrace rewBrace extType intType data
                         / braced prevLayer x0 x1 cx ymid first nB drewX yp d colOff
                           mzOn mzB0 mzB1 mzX0 mzX1 glF glT bType bnd)
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
  ;; -- RULE 4B.41 - INSIDE A MEZZANINE, INTERIOR BRACING IS FULL-HEIGHT PORTAL --------
  ;; Owner 29-Aug: "in the Mezzanine Area, all internal bracings will be Full height Portal",
  ;; and on seeing the sheet: "internal bracing is still showing cross ... should be full
  ;; height portal."
  ;;
  ;; This is PHYSICS, not preference, which is why it overrides the entered type rather than
  ;; asking for a second field: a cross brace on an interior column line runs its diagonals
  ;; through the plane of the mezzanine floor.  The floor is there; the diagonal cannot be.
  ;; A portal frame carries the same load in the plane of the columns and leaves the floor clear.
  ;;
  ;; DERIVED FROM THE BSF, NEVER STORED (standing rule: consumers derive).  The footprint is
  ;; already stated - MZ_WIDTH_GRID_FROM/TO through peb-mz-width-band, the same function the
  ;; plan, the section and the mezzanine sheet place the deck with, plus MZ_GRID_BAY_FROM/TO
  ;; along the length.  An "interior bracing = portal" field would be a second place to say what
  ;; MZ_TOGGLE already says, and the two would drift.
  ;;
  ;; IT IS PER COLUMN LINE, NOT PER BUILDING.  On MSPL-26-271 the mezzanine is the full length
  ;; but only A->G of a nine-line width grid, so lines out in the void bay keep the entered type.
  ;; A blanket override would portal bracing that has no floor anywhere near it.
  (setq mzOn (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_TOGGLE") "")) "YES"))
  (if mzOn
    (progn
      (setq bnd (vl-catch-all-apply (function (lambda () (peb-mz-width-band data wid 1000.0)))))
      (if (or (vl-catch-all-error-p bnd) (not (listp bnd)))
        (setq mzOn nil)
        (setq mzB0 (car bnd) mzB1 (cadr bnd)))
      (setq glF (MSPL-Get-Int data "MZ_GRID_BAY_FROM") glT (MSPL-Get-Int data "MZ_GRID_BAY_TO"))
      (if (and glF glT (> glF 0) (> glT glF) (<= glT (length bayPts)))
        (setq mzX0 (nth (1- glF) bayPts) mzX1 (nth (1- glT) bayPts))
        (setq mzX0 0.0 mzX1 (last bayPts)))))
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
    ;; -- RULE 4B.48 - MEZZANINE STUB COLUMNS ARE NOT BRACED, ON PURPOSE ---------------
    ;; This loop runs over widthPts - the MAIN FRAME column lines.  The mezzanine's own stub
    ;; stations are deliberately NOT in it (owner 29-Aug: "better not to provide the bracing for
    ;; those columns which are coming till mezzanine as it may not even required").
    ;;
    ;; A stub stops at the beam soffit and carries only floor load: a GRAVITY (leaning) column,
    ;; no part of the lateral system.  The slab is a rigid diaphragm and delivers the floor's
    ;; inertia to the MAIN columns, so the load path is already complete - slab, main columns,
    ;; the interior portals of 4B.41 across the width, wall bracing along the length.  Bracing a
    ;; stub line would stiffen it, and what is stiffened attracts load away from the frames that
    ;; were sized for it.
    ;;
    ;; The comment is here because this is an ABSENCE.  Without it the next reader sees an
    ;; unbraced mezzanine column line and takes it for something the engine forgot.
    ;; interior column lines → INTERIOR bracing type
    (foreach yp widthPts
      (if (and (> yp 1.0) (< yp (- wid 1.0)))
        (progn
          ;; rule 4B.41 - a line under the mezzanine deck is portalled whatever was entered
          (setq bType intType)
          (if (and mzOn
                   (>= yp (- mzB0 1.0)) (<= yp (+ mzB1 1.0))
                   (>= (- x0 ox) (- mzX0 1.0)) (<= (- x1 ox) (+ mzX1 1.0)))
            (setq bType "Portal (full height)"))
          (if (peb-brace-line x0 x1 (+ oy yp) d 1.0 bType) (setq drewX T)))))
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
    ;; ── NO LOUVERS ON THE COLUMN LAYOUT PLAN (owner 4-Sep-2026: "Do not show the lV on CLP") ──
    ;; This first dropped only their offset dimensions; the owner then took the whole accessory
    ;; off the sheet. Right, and for the reason the sheet has a name: a COLUMN layout plan is
    ;; about columns, grids and bracing. Twelve louvers put twelve symbols and twelve marks
    ;; across it that answer a question nobody asks here - where a louver sits along a wall is
    ;; elevation business, and it is drawn there. Rule 32: show what the reader of THIS sheet
    ;; needs, not everything that is true.
    (if (and (> w 0.0) (member surf '("NSW" "FSW" "LEW" "REW"))
             (not (wcmatch typ "*LOUVER*")))
      (progn
        (setq bayIdx (if (member surf '("NSW" "FSW")) (peb-bay-of at bayPts) -1))
        (peb-draw-one-opening surf at w mark isDoor
                              (if (member bayIdx braced) T nil)
                              len wid ox oy bayPts)))
    (setq i (1+ i)))
  ;; ── THE TICKED DOORS, WHICH ARE NOT PLACEMENTS ────────────────────────────────────────
  ;; PL*_ is the manual Area Placement panel. The doors the BSF TICKS arrive as DR_*, and those
  ;; reached the wall elevations only - so a job with two ticked sliding doors showed them on the
  ;; elevations and nothing at all on the plan, while the customer's own layout plan for that
  ;; same job draws both. The sliding door speaks for itself here; every other door type is still
  ;; the opening drawer above.
  ;; Through vl-catch-all-apply so a component that is not loaded, or that throws, costs this
  ;; sheet nothing.
  (vl-catch-all-apply 'peb-sld-plan-doors (list data ox oy len wid bayPts)))

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

;; An OVERALL extent always carries its feet, whatever *PEB-DIM-DISPLAY* says (4B.11 / 4B.14):
;; mm is the sheet's language - General Note 1 states it - and feet are what the reader checks the
;; size against, so the two overalls get both and nothing else does.  This is the same string the
;; framing elevations' overall prints, comma-grouped like every other number on the set.
(defun peb-fmt-overall (value)
  (strcat (peb-comma (rtos value 2 0)) " [" (peb-mm-to-ft-in value) "]"))

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

;; The SAME basis, abbreviated, for the WALL ELEVATIONS (owner 31-Aug: "you may make the
;; abbreviation of Clear Height to C.H, Eave Height to E.H ... for framing elevations and sheeting
;; elevations").  A sibling rather than a flag on the one above, because the three sheets want three
;; lengths of the same fact and each has its own room for it:
;;    plan      -> CLEAR HT.     (a tag inside an area box)
;;    section   -> CLEAR HEIGHT  (rotated, spans the whole wall)
;;    elevation -> C.H           (appended to a dim string that already carries mm and feet)
;; They must not disagree about WHICH basis it is, which is why both read HEIGHT_REF through the
;; same cond - including the trap: "Clear Height at Eave" contains BOTH "CLEAR" and "EAVE", so CLEAR
;; is tested FIRST or every clear height prints as an eave height.
(defun peb-height-tag-abbr (ref / u)
  (setq u (strcase (if ref ref "")))
  (cond ((wcmatch u "*CLEAR*") "C.H")
        ((wcmatch u "*EAVE*")  "E.H")
        (T                     "C.H")))

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
    ;; -- RULE 4B.39 - THE MEZZANINE SHEET CARRIES THE MEZZANINE'S OWN DATA (owner 29-Aug) --
    ;; "on Mezzanine Floor plan, title block have all the information related to Mezzanine like
    ;;  live load, & other load and details ... as overall buildings are already at have the
    ;;  information and column layout plan."
    ;; Every one of these is a stated BSF field, so the panel quotes the estimate rather than
    ;; restating the roof loads the Column Layout Plan already carries.
    (cons "MZ_AREA"   (peb-tb-comma (MSPL-Get-Str data "MZ1_AREA")))
    (cons "MZ_DL"     (peb-tb-or (MSPL-Get-Str data "MZ1_DL")   "-"))
    (cons "MZ_LL"     (peb-tb-or (MSPL-Get-Str data "MZ1_LL")   "-"))
    (cons "MZ_CL"     (peb-tb-or (MSPL-Get-Str data "MZ1_CL")   "-"))
    (cons "MZ_FLOOR"  (peb-tb-or (MSPL-Get-Str data "MZ1_FLOOR_MAT")
                                 (peb-tb-or (MSPL-Get-Str data "MZ1_FLOOR") "-")))
    (cons "MZ_THK"    (peb-tb-or (MSPL-Get-Str data "MZ1_FLOOR_THK") "-"))
    (cons "MZ_FFL"    (peb-tb-comma (MSPL-Get-Str data "MZ1_CH_FFL_SLAB")))
    (cons "MZ_CHB"    (peb-tb-comma (MSPL-Get-Str data "MZ1_CH_FFL_BEAM")))
    (cons "MZ_CHR"    (peb-tb-comma (MSPL-Get-Str data "MZ1_CH_SLAB_RAFTER")))
    (cons "MZ_JOISTSP" (peb-tb-comma (MSPL-Get-Str data "MZ_JOIST")))
;; -- RULE 1.6.3 - THE SHEET'S OWN DATA, for the bands that had none (owner 30-Aug) --
    ;; "Right Side Title Block must have the Information about that Page Drawings."
    ;; The DETAILS sheet draws PANEL SECTIONS and the EAVE GUTTER, so these are what it has to
    ;; talk about; the ROOF sheets are about the roof, not the walls. All stated BSF fields -
    ;; the panel is quoted, never inferred - and still PROPOSAL level: no member sections, no
    ;; web/flange thicknesses (owner's standing rule for the title block).
    (cons "PN_R_TYPE" (peb-tb-or (MSPL-Get-Str data "PN_ROOF_TYPE") "-"))
    (cons "PN_R_PROF" (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_PROFILE") "-"))
    (cons "PN_R_MAT"  (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_MAT") "-"))
    (cons "PN_W_TYPE" (peb-tb-or (MSPL-Get-Str data "PN_WALL_TYPE") "-"))
    (cons "PN_W_PROF" (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_PROFILE") "-"))
    (cons "PN_W_MAT"  (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_MAT") "-"))
    (cons "EAVETYPE"  (peb-tb-or (MSPL-Get-Str data "BP_EAVE_TYPE") "-"))
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
  ;; RULE 1.6.3 (owner 30-Aug): the band must be about THIS sheet. Two kinds were missing and
  ;; the sheets fell through to bands about something else:
  ;;   * DETAILS matched nothing, so the sheeting-profile page printed the BUILDING's roof live
  ;;     load, wind speed, seismic zone and rainfall intensity - the same complaint 4B.39 fixed
  ;;     for the mezzanine, on a different sheet.
  ;;   * ROOF FRAMING PLAN matched *FRAMING* and ROOF SHEETING PLAN matched *SHEETING*, so both
  ;;     roof sheets printed the WALL framing / cladding notes.
  ;; ORDER MATTERS: the specific patterns are tested before the substring ones, and the ROOF
  ;; tests anchor on the FIRST word ("ROOF*") so "SIDE WALL SHEETING" cannot be caught by them.
  (setq dt (strcase (tb-get "DRGTITLE"))
        tbKind (cond ((wcmatch dt "*STAIRCASE*")          "STAIRCASE")  ; staircase design loads (2-Sep-2026)
                     ;; MEZZANINE BEFORE DETAIL/SECTION (3-Sep-2026).  "MEZZANINE SECTION
                     ;; DETAILS" hit *DETAIL* first and printed the PANEL & TRIM table - the
                     ;; cladding spec on a sheet about a floor slab.  A sheet that says
                     ;; MEZZANINE is about the mezzanine whatever else its title says, so the
                     ;; test that names the subject is asked before the ones that name the view.
                     ((wcmatch dt "*MEZZANINE*")           "MEZZ")      ; rule 4B.39
                     ((wcmatch dt "*DETAIL*")              "DETAILS")   ; rule 1.6.3
                     ((wcmatch dt "*SECTION*")             "SECTION")
                     ((and (wcmatch dt "ROOF*") (wcmatch dt "*FRAMING*"))  "ROOFFRM")
                     ((and (wcmatch dt "ROOF*") (wcmatch dt "*SHEETING*")) "ROOFSHT")
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
        ;; A UNIT BELONGS TO A NUMBER (owner 3-Sep-2026).  MZ1_CH_FFL_SLAB on MSPL-26-279 is the
        ;; text "As per Design", and the panel appended MM to it regardless, so the sheet read
        ;; "F.F.L (FROM G.F.)   AS PER DESIGN  MM".  A row whose value is a sentence carries no
        ;; unit - and these panels exist precisely so a blank BSF field can say so out loud.
        (if (and (/= (caddr r) "") (wcmatch (cadr r) "#*"))
          (tb-mtext (+ X0 (* W 0.82)) (+ yCur (* rh 0.5)) (tb-fith (caddr r) (* W 0.155) (* sm 0.90)) 0 4 (caddr r) grey)))
      (setq rh (* s 0.044) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (+ yCur (* rh 0.74))
        (tb-fith (strcat "AS PER " (tb-get "CODE") " METAL BUILDING SYSTEMS MANUAL")
                 (* cw 1.02) (* s 0.0092)) cw 1
        (strcat "{\\Fromand.shx;AS PER " (tb-get "CODE")
                " METAL BUILDING SYSTEMS MANUAL}") green))
    ;; ==== STAIRCASE DETAILS : the STAIRCASE's own design loads (2-Sep-2026) ====
    ((= tbKind "STAIRCASE")
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext-bold (+ X0 (* W 0.035)) (- bt (* s 0.0130))
        (tb-fith "DESIGN LOADS" (* cw 0.85) (* s 0.0120)) (* W 0.93) 1 "DESIGN LOADS" green)
      (setq rh (* s 0.224) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (- (+ yCur rh) (* sm 1.3))
        (tb-fith "OCCUPANCY: PRODUCTION / INDUSTRIAL" cw (* sm 1.05)) cw 1
        (strcat "OCCUPANCY : PRODUCTION / INDUSTRIAL\\P"
                "LIVE LOAD : 3.0 kN/m²\\P"
                "HANDRAIL : 0.36 kN/m LINE LOAD AT TOP\\P"
                "MEZZANINE LIVE LOAD : AS STATED IN BSF\\P"
                "REFERENCE : BS 6399 TABLE 4.10") white))
    ;; ==== MEZZANINE FLOOR PLAN : the MEZZANINE's own design data (owner 29-Aug) ====
    ;; Rule 4B.39.  The roof/frame live loads, wind, exposure, snow and seismic belong to the
    ;; BUILDING and are already printed on the Column Layout Plan and the Cross Section; repeating
    ;; them here told the reader nothing about the floor the sheet is actually about.  A mezzanine
    ;; is bought on its own numbers: what it costs to hold up (dead + live + collateral), what it
    ;; is made of, and the two clear heights it creates.  Every row is a stated BSF field.
    ((= tbKind "MEZZ")
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext-bold (+ X0 (* W 0.035)) (- bt (* s 0.0130))
        (tb-fith "MEZZANINE DESIGN DATA" (* cw 0.85) (* s 0.0120)) (* W 0.93) 1
        "MEZZANINE DESIGN DATA" green)
      (foreach r (list
           (list "FLOOR AREA"             (tb-get "MZ_AREA")    "SQ.M.")
           (list "DEAD LOAD"              (tb-get "MZ_DL")      "KN/SQ.M.")
           (list "LIVE LOAD"              (tb-get "MZ_LL")      "KN/SQ.M.")
           (list "COLLATERAL LOAD"        (tb-get "MZ_CL")      "KN/SQ.M.")
           (list "SLAB THICKNESS"         (tb-get "MZ_THK")     "MM")
           (list "F.F.L (FROM G.F.)"      (tb-get "MZ_FFL")     "MM")
           (list "C.H UNDER MEZZ. BEAM"   (tb-get "MZ_CHB")     "MM")
           (list "C.H OVER MEZZANINE"     (tb-get "MZ_CHR")     "MM")
           ;; rule 4B.49 — JOIST SPACING deliberately absent: design sets it, so the sheet
           ;; must not state it. The row was here; removing it is the point, not an omission.
           (list "FLOOR SYSTEM"            ""                    ""))
        (setq rh (* s 0.0200) yCur (- yCur rh))
        (tb-mtext lx (+ yCur (* rh 0.5)) (tb-fith (car r) (* W 0.60) sm) 0 4 (car r) white)
        (tb-mtext (+ X0 (* W 0.80)) (+ yCur (* rh 0.5)) (tb-fith (cadr r) (* W 0.14) val) 0 6 (cadr r) green)
        ;; A UNIT BELONGS TO A NUMBER (owner 3-Sep-2026).  MZ1_CH_FFL_SLAB on MSPL-26-279 is the
        ;; text "As per Design", and the panel appended MM to it regardless, so the sheet read
        ;; "F.F.L (FROM G.F.)   AS PER DESIGN  MM".  A row whose value is a sentence carries no
        ;; unit - and these panels exist precisely so a blank BSF field can say so out loud.
        (if (and (/= (caddr r) "") (wcmatch (cadr r) "#*"))
          (tb-mtext (+ X0 (* W 0.82)) (+ yCur (* rh 0.5)) (tb-fith (caddr r) (* W 0.155) (* sm 0.90)) 0 4 (caddr r) grey)))
      ;; the floor system spelled out, on its own line - it is a sentence, not a number
      (setq rh (* s 0.044) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (+ yCur (* rh 0.74))
        (tb-fith (strcat "FLOOR SYSTEM: " (tb-get "MZ_FLOOR")) (* cw 1.02) (* s 0.0092)) cw 1
        (strcat "{\\Fromand.shx;FLOOR SYSTEM: " (tb-get "MZ_FLOOR") "}") green))
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
        ;; A UNIT BELONGS TO A NUMBER (owner 3-Sep-2026).  MZ1_CH_FFL_SLAB on MSPL-26-279 is the
        ;; text "As per Design", and the panel appended MM to it regardless, so the sheet read
        ;; "F.F.L (FROM G.F.)   AS PER DESIGN  MM".  A row whose value is a sentence carries no
        ;; unit - and these panels exist precisely so a blank BSF field can say so out loud.
        (if (and (/= (caddr r) "") (wcmatch (cadr r) "#*"))
          (tb-mtext (+ X0 (* W 0.82)) (+ yCur (* rh 0.5)) (tb-fith (caddr r) (* W 0.155) (* sm 0.90)) 0 4 (caddr r) grey)))
      (setq rh (* s 0.050) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (+ yCur (* rh 0.72))
        (tb-fith "HEIGHTS, SLOPE & GRIDS AS SHOWN ON THE SECTION." (* cw 1.02) (* s 0.0090)) cw 1
        "HEIGHTS, SLOPE & GRIDS AS SHOWN ON THE SECTION." green))
    ;; ==== DETAILS : the PANELS and the EAVE this sheet actually draws (rule 1.6.3) ====
    ;; Written as paragraphs rather than the label/value rows the SECTION band uses, because a
    ;; profile name is "Standard S Profile 35-250" - in the narrow value column tb-fith would
    ;; shrink it to unreadable. The gutter gauge is stated here because the sheet draws the
    ;; gutter section (rule 4B.51: 0.50 mm, and NOT the 1.2 on the traced approval drawing).
    ((= tbKind "DETAILS")
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext-bold (+ X0 (* W 0.035)) (- bt (* s 0.0130))
        (tb-fith "PANEL & TRIM DATA" (* cw 0.85) (* s 0.0120)) (* W 0.93) 1 "PANEL & TRIM DATA" green)
      (setq rh (* s 0.224) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (- (+ yCur rh) (* sm 1.3))
        (tb-fith (strcat "ROOF  " (tb-get "PN_R_PROF")) cw (* sm 1.05)) cw 1
        (strcat "ROOF PANEL\\P"
                "  " (tb-get "PN_R_TYPE") "  |  " (tb-get "PN_R_PROF") "\\P"
                "  " (tb-get "PN_R_MAT") "\\P"
                "WALL PANEL\\P"
                "  " (tb-get "PN_W_TYPE") "  |  " (tb-get "PN_W_PROF") "\\P"
                "  " (tb-get "PN_W_MAT") "\\P"
                "EAVE\\P"
                "  " (tb-get "EAVETYPE") "  |  0.50 mm PPG.L") white))
    ;; ==== ROOF FRAMING PLAN : about the ROOF, not the walls (rule 1.6.3) ====
    ((= tbKind "ROOFFRM")
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext-bold (+ X0 (* W 0.035)) (- bt (* s 0.0130))
        (tb-fith "ROOF FRAMING DATA" (* cw 0.85) (* s 0.0120)) (* W 0.93) 1 "ROOF FRAMING DATA" green)
      (foreach r (list
           (list "ROOF SLOPE"      (tb-get "BSLOPE")  "")
           (list "No. OF BAYS"     (tb-get "BBAYS")   "")
           (list "BUILDING LENGTH" (tb-get "BLENGTH") "MM")
           (list "BUILDING WIDTH"  (tb-get "BWIDTH")  "MM"))
        (setq rh (* s 0.0280) yCur (- yCur rh))
        (tb-mtext lx (+ yCur (* rh 0.5)) (tb-fith (car r) (* W 0.52) sm) 0 4 (car r) white)
        (tb-mtext (+ X0 (* W 0.80)) (+ yCur (* rh 0.5)) (tb-fith (cadr r) (* W 0.16) val) 0 6 (cadr r) green)
        ;; A UNIT BELONGS TO A NUMBER (owner 3-Sep-2026).  MZ1_CH_FFL_SLAB on MSPL-26-279 is the
        ;; text "As per Design", and the panel appended MM to it regardless, so the sheet read
        ;; "F.F.L (FROM G.F.)   AS PER DESIGN  MM".  A row whose value is a sentence carries no
        ;; unit - and these panels exist precisely so a blank BSF field can say so out loud.
        (if (and (/= (caddr r) "") (wcmatch (cadr r) "#*"))
          (tb-mtext (+ X0 (* W 0.82)) (+ yCur (* rh 0.5)) (tb-fith (caddr r) (* W 0.155) (* sm 0.90)) 0 4 (caddr r) grey)))
      (setq rh (* s 0.090) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (- (+ yCur rh) (* sm 1.1))
        (tb-fith "PURLIN SIZE & SPACING PER APPROVED DESIGN." cw (* sm 1.05)) cw 1
        (strcat "PURLIN SIZE & SPACING PER APPROVED DESIGN.\\P"
                "BRACED BAYS & FALL AS SHOWN ON THIS PLAN.") green))
    ;; ==== ROOF SHEETING PLAN : the ROOF panel, not the wall cladding (rule 1.6.3) ====
    ((= tbKind "ROOFSHT")
      (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
      (tb-mtext-bold (+ X0 (* W 0.035)) (- bt (* s 0.0130))
        (tb-fith "ROOF SHEETING DATA" (* cw 0.85) (* s 0.0120)) (* W 0.93) 1 "ROOF SHEETING DATA" green)
      (setq rh (* s 0.224) yCur (- yCur rh))
      (tb-mtext (+ X0 (* W 0.04)) (- (+ yCur rh) (* sm 1.3))
        (tb-fith (strcat "  " (tb-get "PN_R_PROF")) cw (* sm 1.05)) cw 1
        (strcat "ROOF PANEL\\P"
                "  " (tb-get "PN_R_TYPE") "  |  " (tb-get "PN_R_PROF") "\\P"
                "  " (tb-get "PN_R_MAT") "\\P"
                "ROOF SLOPE  " (tb-get "BSLOPE") "\\P"
                "EAVE\\P"
                "  " (tb-get "EAVETYPE") "\\P"
                "FALL DIRECTION AS SHOWN ON THIS PLAN.") white))
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
                "6. FRAME GEOMETRY PER CROSS SECTION.\\P"
                ;; ABBREVIATION LEGEND (owner 31-Aug: abbreviate to C.H / E.H, then "But there must
                ;; be clarity").  An abbreviation on a customer drawing has to be defined ON that
                ;; drawing: the height dim is the only place C.H/E.H appears and a reader who does
                ;; not already know the convention has nothing to resolve it against.  BOTH are
                ;; defined, not only the one in use, so the note does not change between an
                ;; eave-basis job and a clear-basis one.
                ;; tbKind FRAMING/SHEETING reaches ONLY the four wall elevations - the roof sheets
                ;; match ROOFFRM/ROOFSHT earlier in the same cond - so this lands exactly where the
                ;; abbreviation is used and nowhere else.  Kept under 40 chars like its neighbours,
                ;; because a wrapped note in this strip reads as a mistake.
                "7. C.H = CLEAR HT.   E.H = EAVE HT.") white))
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
                "6. FASTENERS & SEALANTS PER DESIGN.\\P"
                ;; ABBREVIATION LEGEND - see the identical note in the FRAMING block above.  Both
                ;; elevation kinds carry the C.H/E.H height dim, so both have to define it.
                "7. C.H = CLEAR HT.   E.H = EAVE HT.") white)))
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
  (peb-log-sheet sheetNo sc)          ; diagnostic, off unless *PEB-SCALE-LOG* names a file
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
  ;; (vl-catch-all-apply (function (lambda () (peb-draw-monitor data len wid bayPts))))
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

(defun peb-draw-canopy (data len wid / u proj alen bayPts wPts horiz stn gf gt ga0 ga1 nOn k pfx off)
  (if (= (strcase (MSPL-Get-Str data "CN_TOGGLE")) "YES")
    (progn
      (setq u (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
      (setq bayPts (peb-mzfp-bays data len) wPts (peb-comp-width-pts data wid))
      (foreach w (list "NSW" "FSW" "LEW" "REW")
        (if (= (strcase (MSPL-Get-Str data (strcat "CN_" w "_TOGGLE"))) "YES")
          (progn
            ;; EVERY canopy on this wall, not just one. The data now carries CN_<W>_N and
            ;; CN_<W>_<n>_*; a file written before that has neither, so fall back to the single
            ;; unindexed set and draw one, exactly as before (owner 29-Aug: two entrance canopies
            ;; on the same wall, only one drawn).
            (setq nOn (MSPL-Get-Int data (strcat "CN_" w "_N")))
            (if (or (null nOn) (< nOn 1)) (setq nOn 1))
            (setq k 1)
            (while (<= k nOn)
              (setq pfx (if (MSPL-Get-Int data (strcat "CN_" w "_N"))
                          (strcat "CN_" w "_" (itoa k) "_")
                          (strcat "CN_" w "_")))
              (setq proj (MSPL-Get-Num data (strcat pfx "WIDTH")))      ; projection from wall
              (setq alen (MSPL-Get-Num data (strcat pfx "LEN")))        ; length along wall (0 = full)
              (setq off  (MSPL-Get-Num data (strcat pfx "OFF")))        ; mid-bay start, mm from GRID_FROM
              (if (or (null proj) (<= proj 0.0)) (setq proj 1500.0))    ; std 1500 mm
              ;; Grid-line placement (owner 11-Jul): position along the wall from GRID_FROM/TO into the
              ;; grid stations — bay points on a sidewall, width points on an endwall. nil -> full/centered.
              (setq horiz (or (= w "NSW") (= w "FSW")) stn (if horiz bayPts wPts)
                    gf (MSPL-Get-Int data (strcat pfx "GRID_FROM"))
                    gt (MSPL-Get-Int data (strcat pfx "GRID_TO")))
              (if (and gf gt (> gf 0) (> gt gf) stn (<= gt (length stn)))
                (setq ga0 (nth (1- gf) stn) ga1 (nth (1- gt) stn))
                (setq ga0 nil ga1 nil))
              ;; MID-BAY PLACEMENT (owner 29-Aug). An offset shifts the start off the grid line, and
              ;; once a start is anchored the entered LENGTH governs the far end — it is no longer
              ;; stretched to the grid range. That stretching is why a 62'-1" canopy at grids 1->4
              ;; drew as the full three bays, 76'-10".
              (if (and ga0 off (> off 0.0)) (setq ga0 (+ ga0 off)))
              (if (and ga0 alen (> alen 0.0)) (setq ga1 (+ ga0 alen)))
              ;; rule 4B.46 — what the canopy is FOR, and how high it sits, both come off the BSF
              (vl-catch-all-apply (function (lambda ()
                (peb-comp-canopy-one w proj alen len wid u ga0 ga1
                                     (MSPL-Get-Str data (strcat pfx "PURPOSE"))
                                     (MSPL-Get-Num data (strcat pfx "EAVE_HT"))))))
              (setq k (1+ k))))))))
  (princ))

;; one canopy on wall w: outline extruded from the wall by proj, along the wall by
;; alen (default full), + outward FALL arrow + projection & coverage-length dims + label.
(defun peb-comp-canopy-one (w proj alen len wid u ga0 ga1 purpose cnHt
                            / wl a0 a1 bx by ex ey nx ny mcx mcy lx ly horiz su full lab)
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
  ;; -- RULE 4B.46 - ON THE PLAN A CANOPY IS A BOX WITH ITS NAME IN IT (owner 29-Aug) ----
  ;; "Just show the rectangular box and write canopy ... that's all", and "you may write
  ;;  height also of canopy in plan."
  ;;
  ;; It was a DOTTED outline with the word parked at 0.72 along the wall - dodging the CLP's other
  ;; annotation rather than sitting in the thing it names.  A dotted line reads as "not built yet"
  ;; next to the solid steel around it, and a label outside its own box belongs to nothing.  A
  ;; SOLID rectangle with the name centred in it is unambiguous at any scale, and is all the
  ;; column layout plan owes a canopy: no fall arrow, no projection or coverage dims - those are
  ;; the canopy's own detail, and this sheet is about columns.
  (peb-comp-poly (list (list bx by) (list ex ey)
                       (list (+ ex (* nx proj)) (+ ey (* ny proj)))
                       (list (+ bx (* nx proj)) (+ by (* ny proj)))))
  (setvar "CLAYER" "COMP-CANOPY")
  ;; PURPOSE comes from the BSF, never from the position.  A building can carry several canopies
  ;; on one wall and they are not interchangeable to the reader - the entrance is the one the
  ;; customer walks in through.  The engine cannot know which end is the front door, and a house
  ;; rule like "grid 1 is always the entrance" would be wrong on the next job.
  (setq lab (strcat "CANOPY"
                    (if (and purpose (/= purpose "")) (strcat " (" (strcase purpose) ")") "")
                    (if (and cnHt (> cnHt 0.0)) (strcat "  H=" (peb-comma (rtos cnHt 2 0))) "")))
  ;; centred IN the box, along its length, so the label and its outline are one object to the eye
  (setq lx (if horiz (/ (+ bx ex) 2.0) mcx)
        ly (if horiz mcy (/ (+ by ey) 2.0)))
  (txt-bold "MC" (list lx ly) (/ su (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) (if horiz 0.0 90.0) lab)
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


;; The monitor's FOOTPRINT on the roof plane -> (x0 x1 yBot yTop throat ridge), or nil when the job
;; has no monitor.  Factored out because TWO sheets need it and they must not disagree: the monitor
;; drawer draws the band, and the ROOF SHEETING PLAN has to STOP the sheeting runs at it.  Cladding
;; does not run through an upstand - and drawn through, 59 run lines turned the monitor into a smear
;; you could not identify on the sheet (owner 31-Aug: "simple But Excellent Outlook").
(defun peb-monitor-band (data len wid bayPtsIn / ow throat rmlen ridge half bp gf gt x0 x1)
  (if (/= (strcase (MSPL-Get-Str data "RM_TOGGLE")) "YES")
    nil
    (progn
      ;; OVERALL WIDTH = THROAT x 2 (owner 31-Aug).  The monitor sheeting extends half a throat past
      ;; the opening on EACH side, so a 1.50 m throat gives a 3.00 m band with 750 either side.
      ;; ONE derivation, stated once: the section used throat + 1800 and the plan a flat 3000, so a
      ;; job that left the field blank got a section and a plan that disagreed by 200 mm about the
      ;; same monitor - and neither said so.
      (setq throat (MSPL-Get-Num data "RM_THROAT_WIDTH")
            ow     (MSPL-Get-Num data "RM_OVERALL_WIDTH"))
      (if (or (null throat) (<= throat 0.0))
        (setq throat (if (and ow (> ow 0.0)) (/ ow 2.0) 1000.0)))
      (if (or (null ow) (<= ow 0.0)) (setq ow (* throat 2.0)))
      (setq rmlen (MSPL-Get-Num data "RM_LENGTH")
            ridge (peb-ridge-y data wid)
            half  (/ ow 2.0)
            bp    (if (and bayPtsIn (> (length bayPtsIn) 1)) bayPtsIn (peb-mzfp-bays data len))
            gf    (MSPL-Get-Int data "RM_GRID_FROM")
            gt    (MSPL-Get-Int data "RM_GRID_TO"))
      (cond
        ((and gf gt (> gf 0) (> gt gf) bp (<= gt (length bp)))
         (setq x0 (nth (1- gf) bp) x1 (nth (1- gt) bp)))
        ((or (null rmlen) (<= rmlen 0.0) (>= rmlen len)) (setq x0 0.0 x1 len))
        (T (setq x0 (/ (- len rmlen) 2.0) x1 (+ x0 rmlen))))
      (list x0 x1 (- ridge half) (+ ridge half) throat ridge))))

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
(defun peb-draw-monitor (data len wid bayPtsIn
                         / u ridge ow throat rmlen half x0 x1 yTop yBot mcx su lay lyr bayPts gf gt bnd sx lts yy mlbl mlh mlw mlx0 mlx1)
  (if (= (strcase (MSPL-Get-Str data "RM_TOGGLE")) "YES")
    (progn
      ;; ---- size unit (same formula the other drawers use) ----------------
      (setq u (max 400.0 (min 3000.0 (/ (max len wid) 70.0))))
      ;; ---- read IF keys with safe defaults (all raw mm) ------------------
      ;; ONE source for the footprint (peb-monitor-band) - the sheeting plan reads the same band to
      ;; break its runs, so the opening the sheeting stops at IS the opening drawn here.
      (setq bnd   (peb-monitor-band data len wid bayPtsIn)
            x0    (nth 0 bnd) x1 (nth 1 bnd) yBot (nth 2 bnd) yTop (nth 3 bnd)
            throat (nth 4 bnd) ridge (nth 5 bnd)
            ow    (- yTop yBot)
            rmlen (- x1 x0)
            mcx   (/ (+ x0 x1) 2.0)
            su    (max 300.0 (min u (* ow 0.30))))            ; annotation size scaled to the strip depth
      ;; ---- layer ---------------------------------------------------------
      (setq lay "COMP-MONITOR")
      (if (not (tblsearch "LAYER" lay))
        (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                       (cons 100 "AcDbLayerTableRecord") (cons 2 lay)
                       (cons 70 0) (cons 62 4))))           ; colour 4 = cyan
      (setvar "CLAYER" lay)
      (setq lyr (getvar "CLAYER"))
      ;; ---- strip outline (rectangle = two ridge-parallel lines + end caps) ----
      ;; The band EDGE is the only line on this sheet that says "different surface, different level",
      ;; so it carries weight.  At the sheeting runs' own 0.09 it disappeared among them: the monitor
      ;; drew correctly - 3000 deep, own ridge, own 1000-pitch runs - and still read as unbroken roof,
      ;; because everything inside it looks like everything outside it.  Two eaves at 0.50 separate
      ;; the two surfaces at a glance; the callout then says which is which.
      (entmake (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 lyr)
                     (cons 100 "AcDbPolyline") (cons 90 4) (cons 70 1) (cons 370 50)
                     (list 10 x0 yBot) (list 10 x1 yBot)
                     (list 10 x1 yTop) (list 10 x0 yTop)))
      ;; ---- what you actually SEE from above: the monitor's own ROOF ---------------------------
      ;; This is a ROOF PLAN, so it shows the roof.  A monitor seen from above is a little building
      ;; with its own ridge and its own sheeting; the throat is in its VERTICAL SIDES and is hidden
      ;; underneath that roof, not visible as a hole (owner 31-Aug: "since it is roof plan, show the
      ;; roof monitor sheeting").  So the sheeting is what reads, and the opening is drawn HIDDEN.
      ;;
      ;; This replaced a hatched throat.  The hatch was an improvement on five near-parallel lines,
      ;; but it said the wrong thing: it drew the monitor as a hole in the roof, which is what you
      ;; would see if the monitor were not there.
      ;; --- the monitor's OWN ridge, down the centre of its band.  (The MAIN roof ridge is
      ;;     suppressed under the monitor - 4B.56 - so this is the only ridge here, and it is real.)
      (entmake (list (cons 0 "LINE") (cons 8 lyr)
                     (list 10 x0 ridge 0.0) (list 11 x1 ridge 0.0)))
      ;; --- THE NAME, marked in the plan (owner 31-Aug: "mark the name of Roof Monitor in plan").
      ;;     Inside the band and with no leader - exactly where KM Foods puts `ROOF MONITOR OPENING`
      ;;     on its own roof sheeting plan.  Sized off the ladder and capped to a third of the band
      ;;     so it can never outgrow the thing it names.  Sits in the UPPER half, clear of the
      ;;     monitor's own ridge line running down the centre.
      (setq mlbl "ROOF MONITOR"
            mlh  (peb-fit-txt-h mlbl (* (- x1 x0) 0.30) (peb-th 'ANNOT))
            mlw  (* 0.62 mlh (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0) (strlen mlbl))
            mlx0 (- mcx (/ mlw 2.0))
            mlx1 (+ mcx (/ mlw 2.0)))
      ;; --- its sheeting runs, at the SAME 1000 cover the main roof uses: one material, two levels.
      ;;     The runs SKIP the label's span.  KM Foods does the same thing by islanding its hatch
      ;;     around the text; with line-fill the equivalent is simply not drawing the lines that
      ;;     would strike through it.  A name with sheeting ruled across it is not a name.
      (setq sx (+ x0 1000.0))
      (while (< sx (- x1 1.0))
        (if (or (< sx (- mlx0 (* mlh 0.7))) (> sx (+ mlx1 (* mlh 0.7))))
          (entmake (list (cons 0 "LINE") (cons 8 lyr) (cons 370 9)   ; 0.09 - as light as the roof runs
                         (list 10 sx yBot 0.0) (list 11 sx yTop 0.0))))
        (setq sx (+ sx 1000.0)))
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list mcx (+ ridge (* (- yTop ridge) 0.5))) mlh 0.0 mlbl)
      (setvar "CLAYER" lyr)
      ;; The OPENING is deliberately NOT drawn.  It is directly under the monitor sheeting, so from
      ;; above you cannot see it (owner 31-Aug: "opening will not be visible in the Roof Plan as it
      ;; will come underneath of roof monitor Sheeting").  A dashed throat was drawn here for one
      ;; iteration; it showed a hole that the view does not contain.  The reference sweep says the
      ;; same from the other direction: no MSPL drawing uses a dashed monitor boundary in plan.
      ;; --- name it.  From above there are TWO sheeted surfaces and they look alike - same 1000
      ;;     cover, same direction - so the sheet has to say which is which (owner: "we have to just
      ;;     identity that this is roof monitor sheeting and this is main sheeting").
      ;;     It sits in the NOTE BLOCK BELOW the drawing, not on a leader over it (owner 31-Aug:
      ;;     "all text below the drawings").  A leader from below the eave up to the ridge band
      ;;     would cross the whole lower roof and every skylight on the way - and the band already
      ;;     reads on its own, being the only thing on the sheet drawn at 0.50.
      ;;     Height off the 4B.27 LADDER (peb-th), never a fraction of `u`: no text picks its own size.
      (setq lts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
      (setvar "CLAYER" "TEXT")
      (txt "ML" (list 0.0 (- 0.0 (* (peb-th 'ANNOT) lts 6.2))) (peb-th 'ANNOT) 0.0
           "ROOF MONITOR SHEETING - SAME PROFILE AS MAIN ROOF, OVER THE RIDGE")
      (setvar "CLAYER" lyr)
      ;; NO DIMENSIONS on the roof sheeting plan.  The overall sat at the far LEFT of the sheet and
      ;; the throat at the far RIGHT - two numbers for one object, 63 m apart, and the overall wedged
      ;; into a gap smaller than its own text between the roof outline and the 30,480 width chain
      ;; (owner 31-Aug: "the dimensions of roof monitor these are mingled").  Deleting them fixes
      ;; that at the root rather than moving the clutter somewhere else, and it is what the reference
      ;; does: KM Foods does not dimension the monitor on the plan at all, and MSPL-032 dimensions it
      ;; only on its own dedicated ROOF MONITOR SHEETING PLAN.  The numbers still live on the BSF and
      ;; on the cross section.
      ))
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
  ;; -- A FULL-WIDTH MEZZANINE IS FULL WIDTH (owner 3-Sep-2026) ---------------------------
  ;; This used to start at `inset` / `wid - inset` - a 1,000 mm cosmetic margin at both side
  ;; walls - and for a FULL WIDTH deck nothing ever overrode it.  Three things went wrong at
  ;; once, and only the third was visible:
  ;;   * the deck stopped 1,000 short of each wall it actually abuts, and the strips left over
  ;;     were labelled "VOID - NO MEZZANINE" on a mezzanine that has no void;
  ;;   * grid A..F landed on 1,000..75,200 while the COLUMN LAYOUT PLAN letters the same six
  ;;     lines at 0..76,200 - two sheets lettering one grid differently, against rule 4B.8;
  ;;   * and the column chain, which sums to the full 76,200, no longer fitted the band it was
  ;;     walked across.  peb-mezz-col-ys only walks a chain RAW when it agrees to within 2%;
  ;;     2,000 / 74,200 is 2.7%, so it missed the guard, rescaled every station by 0.9738, and
  ;;     printed the estimator's 15,240 module as 14,840 - the exact fault 4B.8 exists to stop,
  ;;     warned about in the comment directly above the code that did it.
  ;; The margin was only ever a drawing convenience.  A deck that reaches both side walls is
  ;; drawn reaching both side walls.
  (setq anc (strcase (peb-tb-or (MSPL-Get-Str data "MZ_WIDTH_ANCHOR") ""))
        ext (MSPL-Get-Num data "MZ_WIDTH_EXTENT")
        b0  0.0
        b1  wid)
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
  (if (>= b0 b1) (setq b0 0.0 b1 wid))                 ; nonsense extent -> fall back to full width
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
;; ---- A COLUMN STANDS ON ITS OWN CENTRELINE, NOT ON THE OUT-TO-OUT LINE  (owner 3-Sep-2026)
;;
;; "Still arrows are passing from middle of columns, it must be from outer line of sheeting."
;;
;; The BSF states the width OUT TO OUT OF STEEL COLUMN - 76,200 on MSPL-26-279 - and the chain
;; that divides it, 5@15240, is written against that same out-to-out line.  Walking that chain
;; from y=0 therefore puts the first and last station ON the out-to-out line, and a column drawn
;; centred there straddles it: half the section outside the building, and the dimension arrow
;; landing in the middle of the steel instead of on its face.
;;
;; The Column Layout Plan has always known this - peb-main-column-ys starts at colOff and ends at
;; wid-colOff, and only the INTERIOR module lines sit on the raw sums.  This is that same
;; correction, applied where the mezzanine builds its own stations, so the two sheets put the
;; same column in the same place:
;;
;;      out-to-out  0 |<--------------- 76,200 --------------->| 76,200
;;      centrelines   |  700                            75,500 |
;;                    +--+------------------------------+------+
;;                    |==|                              |==|          <- 1,400 deep column
;;
;; The chain still PRINTS 15,240 - that is the estimator's out-to-out module and what was
;; quoted (4B.8).  Only where the steel is drawn changes; the arrows then reach the outer face,
;; which is where a reader measures an out-to-out dimension from.
(defun peb-mezz-snap-ends (lst wid / co)
  (setq co (/ (peb-col-web-depth wid) 2.0))
  (if (or (null lst) (< (length lst) 2))
    lst
    (progn
      (if (< (abs (car lst)) 1.0)
        (setq lst (cons co (cdr lst))))
      (if (< (abs (- (last lst) wid)) 1.0)
        (setq lst (append (reverse (cdr (reverse lst))) (list (- wid co)))))
      lst)))

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
      ;; -- RULE 4B.8 - BOTH SHEETS PRINT THE ESTIMATOR'S OWN SPACING ------------------
      ;; This always rescaled the chain to close exactly on the band it was handed.  The band
      ;; is the DECK, whose edges sit at the column faces, so it runs ~365 mm short of the grid
      ;; the chain was written against - and every station moved with it.  On MSPL-26-271 the
      ;; Column Layout Plan printed the entered "5@8331 + 1@8065" while the Mezzanine Floor
      ;; Plan printed "5@8270 + 1@8006": the same six columns, two sets of numbers, in one set
      ;; of drawings.  The reader has no way to know which is the quote.
      ;;
      ;; When the chain already agrees with the span to within 2%, WALK IT RAW.  The estimator's
      ;; figures print verbatim on every sheet and the columns stand at the spacing that was
      ;; priced; the sub-1% residual is absorbed at the deck edge, which is a drawn edge nobody
      ;; dimensions, rather than smeared across six dimensions that everybody reads.
      ;; A chain that genuinely does not fit (>2% out) is still scaled to close - that is a data
      ;; problem, and silently leaving the deck short would hide it.
      (setq sc2 (if (< (abs (- sumSp span)) (* 0.02 span)) 1.0 (/ span sumSp)))
      (setq out (list fy0) acc fy0)
      (foreach s sp2 (setq acc (+ acc (* s sc2))) (if (< acc (- fy1 1.0)) (setq out (append out (list acc)))))
      (peb-mezz-snap-ends (append out (list fy1)) wid))
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
      (peb-mezz-snap-ends bnds wid))))

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
    module rr gap nsub yi yy0 yy1 glF glT glX0 glX1 offF offT mzOO modSnp ewSnp
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
                ;; rule 4B.45 — the stub is a SYMBOL here: floor it so the I reads, cap it so it
                ;; still looks lighter than the main frame column, then size the bubble off the I.
                (setq colD     (peb-mz-stub-depth (peb-col-web-depth (apply 'max (cons 6000.0 spList))) wid)
                      savedWeb  *PEB-COL-WEB*
                      *PEB-COL-WEB* colD
                      circR     (peb-mz-bubble-r colD))
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
                ;; -- ...AND ONLY WHEN IT IS NOT ALREADY ON THE SHEET  (owner 3-Sep-2026) -----
                ;; Two faults, one cause.  This measured the DRAWN gaps, so once the mezzanine's
                ;; end stations were pulled back onto the column centrelines it printed
                ;; "14,540 | 15,240 | 15,240 | 15,240 | 14,540" - the centre-to-centre chain -
                ;; a hand's breadth from this sheet's own "5@15240 O/O STEEL COLUMN".  One grid,
                ;; two answers, and the wrong one is the in-to-in number the owner rejected.
                ;;
                ;; And on this job it was a DUPLICATE as well: MZ_COL_SPACING is 5@15240 on the
                ;; 50 ft option and 10@7620 on the 25 ft one, and the sheet already prints both
                ;; outside the LEW wall.  So the chain is drawn only when the mezzanine really
                ;; does divide the width its own way - and then it prints the estimator's
                ;; expression with its basis, like every other chain in the set (4B.8).
                (if (> (length ys) 1)
                  (progn
                    (setq mzOO   (peb-width-stations
                                   (peb-tb-or (MSPL-Get-Str data "MZ_COL_SPACING") "") wid)
                          modSnp (peb-mezz-snap-ends (peb-width-mods data wid) wid)
                          ewSnp  (peb-mezz-snap-ends
                                   (peb-mzfp-stations (MSPL-Get-Str data "EWLEXPR") wid) wid))
                    (if (and (not (peb-ys-same ys modSnp 5.0))
                             (not (peb-ys-same ys ewSnp  5.0)))
                      (vl-catch-all-apply (function (lambda ()
                        (peb-dim-height-stretch fx0 (+ fx0 (* u 1.3)) (car ys) (last ys)
                          (strcat (peb-chain-text
                                    (peb-tb-or (MSPL-Get-Str data "MZ_COL_SPACING") "") mzOO)
                                  " " (peb-basis-suffix
                                        (peb-tb-or (MSPL-Get-Str data "WIDTH_MOD_REF")
                                                   (MSPL-Get-Str data "WIDTH_REF")))))))))))

                ;; (4) footprint dims — only when PARTIAL (a full-interior default
                ;;     rectangle is implied by the building outline, so dims would collide).
                ;; PARTIAL IN EACH DIRECTION SEPARATELY (owner 3-Sep-2026).  `partial` is forced
                ;; to T for a grid-bay-placed mezzanine, so a FULL-WIDTH deck still drew a width
                ;; dim - a bare "76,200" printed across this sheet's own "10@7620 O/O STEEL
                ;; COLUMN", stating the building's width a second time in a second voice.  A
                ;; footprint dimension earns its place only where the footprint differs from the
                ;; building; where it does not, the building outline already says it.
                (if partial
                  (progn
                    (if (> (abs (- (- fx1 fx0) len)) 1.0)
                      (vl-catch-all-apply (function (lambda ()
                        (peb-dim-h-stretch fx0 fx1 (- fy0 (* post 2.5))
                                           (peb-comma (rtos (- fx1 fx0) 2 0)))))))
                    (if (> (abs (- (- fy1 fy0) wid)) 1.0)
                      (vl-catch-all-apply (function (lambda ()
                        (peb-dim-height-stretch fx0 (- fx0 (* post 2.5)) fy0 fy1
                                                (peb-comma (rtos (- fy1 fy0) 2 0)))))))))))))))
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
                     '(3 . "Crane bridge . . . .") '(72 . 65) '(73 . 2) '(40 . 300.0)
                     '(49 . 0.0) '(74 . 0) '(49 . -300.0) '(74 . 0)))))))) ; TRUE DOTS (owner 5-Sep-2026)
                     ;; "Beam will be in Dotted to differentiate, as Bridge is normally not in
                     ;; Maimaar Scope" - and on a crane the MAIN BEAM *is* the bridge girder (the
                     ;; 210-25 gantry drawing labels it exactly that). This pattern read 150 dash /
                     ;; 120 gap - a short DASH, not dots - even though it is called CRANEDOT and its
                     ;; own comment says the owner asked for dotted on 19-Jul. A dash also says the
                     ;; same thing as every other hidden line on the sheet, so it could not carry
                     ;; "not our scope". A dot is a dash of length ZERO.
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
                (txt-rom "MC" (list midx (+ runY (* u 0.32))) (/ (max (* u 0.42) (peb-th 'SMALL)) sc) 0.0
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
                (txt-rom "MC" (list capX (+ capY (* u 0.35))) (/ (max (* u 0.50) (peb-th 'SMALL)) sc) 0.0
                          "OVER HEAD CRANE")
                (txt-rom "MC" (list capX (- capY (* u 0.35))) (/ (max (* u 0.50) (peb-th 'SMALL)) sc) 0.0
                          (strcat capInt " TONES"))
                (if (and cls (/= cls ""))
                  (txt-rom "MC" (list capX (- capY (* u 1.00))) (/ (max (* u 0.38) (peb-th 'MARK)) sc) 0.0
                            (strcat "CMAA CLASS " cls)))
                (if byoth
                  (txt-rom "MC" (list capX (- capY (* u 1.60))) (/ (max (* u 0.42) (peb-th 'SMALL)) sc) 0.0
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
                (txt-rom "MC" (list txc (+ tyc (* gw 4.05))) (/ (max (* u 0.42) (peb-th 'SMALL)) sc) 0.0
                          (strcat capInt " TONES CRANE"))
                (txt-rom "MC" (list txc (+ tyc (* gw 5.00))) (/ (max (* u 0.30) (peb-th 'MARK)) sc) 0.0
                          (if (and cls (/= cls ""))
                            (strcat "CMAA CLASS " cls "   HOIST (BY OTHERS)")
                            "HOIST (BY OTHERS)"))
                ;; bridge girder named alongside it (reads up the span)
                (txt-rom "MC" (list (- bx (* gw 1.05)) (/ (+ yN tyc) 2.0)) (/ (max (* u 0.30) (peb-th 'MARK)) sc) 90.0
                          "CRANE BRIDGE (BY OTHERS)")
                ;; STOPS / BUMPERS — bar across the beam width at each of the 4 runway ends.
                (foreach pt (list (list x0 yN) (list x1 yN) (list x0 yF) (list x1 yF))
                  (peb-crane-fp-line (car pt) (- (cadr pt) (* rbw 0.9))
                                     (car pt) (+ (cadr pt) (* rbw 0.9)) flts))
                (txt-rom "MC" (list (/ (+ x0 x1) 2.0) (- yN (* u 0.30) (/ rbw 2.0))) (/ (max (* u 0.34) (peb-th 'MARK)) sc) 0.0
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
          (txt-rom "MC" (list clX clY) (/ (max (* u 0.42) (peb-th 'SMALL)) sc) 0.0 "C/L OF RAFTER")))
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
        u inset i tag wdt hgt typ midl th mzStr mezzNum foot
        nOnMezz onREW xcol yb0 yt1 r lab any offX offY orient dep org)
  ;; ============================================================================
  ;; COLUMN LAYOUT PLAN: THE STAIRCASE COLUMNS, AND NOTHING ELSE  (owner 1-Sep-2026)
  ;; ----------------------------------------------------------------------------
  ;; "on columns layout plan only staircase column will come. you may mark them and label ...
  ;;  However, the Full Plan of Staircase Must come in the Mezzanine Floor Plan"
  ;;
  ;; This sheet is about COLUMNS.  A staircase footprint with treads, landings and an UP arrow
  ;; on it is noise here - it answers a question the sheet is not asking, and it competes with
  ;; the thing the sheet exists to show.  The full stair now lives on the mezzanine floor plan
  ;; (peb-draw-mezz-floor-plan) and on its own PRO-10 detail sheet; what belongs HERE is where
  ;; the staircase puts columns into the building's column grid.
  ;;
  ;; EACH ONE IS RINGED.  On a sheet carrying hundreds of identical column marks, an unringed
  ;; staircase column is invisible - a reader cannot tell which four of them are not the
  ;; building's.  The circle is the whole point of drawing them here.
  ;;
  ;; Placement follows the same rule as the detail sheet: two columns per stair, under the ends
  ;; of the landing beam, on the two outer stringer lines; ST1 takes the mezzanine's LEW end and
  ;; ST2 its REW end.  The *PEB-MEZZ-FOOTS* contract is unchanged - mezzanine is drawn first and
  ;; publishes the footprint, and a stair whose mezzanine cannot be resolved simply draws nothing
  ;; here rather than guessing a position ([[maimaar-stairs-mezz-anchor]]).
  ;; ============================================================================
  (if (= (strcase (MSPL-Get-Str data "ST_TOGGLE")) "YES")
    (progn
      (setq u     (max 400.0 (min 3000.0 (/ (max len wid) 70.0)))
            inset (max 300.0 (min 1500.0 (* u 0.5)))
            th    (max 300.0 (* u 0.40))
            i     1
            nOnMezz 0
            any   nil)
      (peb-comp-layer "COMP-STAIRS" 6)
      (while (<= i 4)
        (setq tag (strcat "ST" (itoa i) "_"))
        (if (= (strcase (MSPL-Get-Str data (strcat tag "TOGGLE"))) "YES")
          (vl-catch-all-apply
            (function
              (lambda ()
                (setq wdt  (MSPL-Get-Num data (strcat tag "WIDTH"))
                      hgt  (MSPL-Get-Num data (strcat tag "HEIGHT"))
                      typ  (MSPL-Get-Str data (strcat tag "TYPE"))
                      midl (MSPL-Get-Str data (strcat tag "MID_LANDING")))
                (if (or (null wdt) (<= wdt 0.0)) (setq wdt 1200.0))
                ;; READ STAIRCASE OFFSETS FROM BSF (owner 2-Sep-2026)
                ;; OFFSET_X = distance from LEW (Left End Wall) — along building width
                ;; OFFSET_Y = distance from NSW (Near Side Wall) — along building length
                ;; ORIENTATION = Longitudinal (runs length-wise NSW→FSW) or Transverse (runs width-wise LEW→REW)
                (setq offX (MSPL-Get-Num data (strcat tag "OFFSET_X"))
                      offY (MSPL-Get-Num data (strcat tag "OFFSET_Y"))
                      orient (MSPL-Get-Str data (strcat tag "ORIENTATION")))
                (if (null offX) (setq offX 0.0))
                (if (null offY) (setq offY 6000.0))
                (if (null orient) (setq orient "Longitudinal"))
                (setq mzStr   (MSPL-Get-Str data (strcat tag "IN_MEZZ"))
                      mezzNum (peb-mezz-num mzStr)
                      foot    (if (and mezzNum *PEB-MEZZ-FOOTS*) (assoc mezzNum *PEB-MEZZ-FOOTS*) nil))
                ;; ALWAYS DRAW SOMETHING.  The old drawer fell back to the LEW corner when the
                ;; mezzanine footprint could not be resolved, and that fallback is why it drew at
                ;; all; my first cut simply skipped the stair, so the columns silently vanished
                ;; from the sheet.  A stair whose mezzanine cannot be found still HAS columns -
                ;; place them against the building instead and let the drawing show them.
                (progn
                    ;; ---- THE SAME STAIR, IN THE SAME PLACE, ON EVERY SHEET  (owner 3-Sep-2026) ----
                    ;; "Sync all the details of stair and its sync with mezzanine plan and CLP."
                    ;;
                    ;; This sheet read ST<n>_OFFSET_Y as the stair's LOWER edge and put its two columns
                    ;; `wdt` (1,200) apart on the flight lines.  The mezzanine floor plan - which draws
                    ;; the whole staircase, through peb-mzfp-stair-org - reads the SAME number as the
                    ;; stairwell's CENTRE line and spans it `dep` (1,200 + 200 well + 1,200 = 2,600).
                    ;; So one offset put the stair in two places, 1,300 apart, and the staircase sheet's
                    ;; own base plate plan called the column spacing 2,600 while this one drew 1,200.
                    ;;
                    ;; So this sheet no longer does the arithmetic at all: where the mezzanine
                    ;; footprint is known it ASKS peb-mzfp-stair-org - the one function the mezzanine
                    ;; floor plan itself uses - and stands its columns on what comes back.  That is
                    ;; 4B.8 at sheet level: one producer, so the two plans cannot drift apart, and the
                    ;; clamp that keeps a stair on the deck it serves now applies to both of them
                    ;; rather than to one.  offY is the CENTRE of the stairwell, and the columns stand
                    ;; on the tower's outer lines - where the base plates are, and what the staircase
                    ;; sheet's own "2600 O/O OF STEEL COLUMN" measures.
                    (setq dep (+ wdt wdt (peb-stair-well wdt))
                          org (if foot
                                (peb-mzfp-stair-org data tag (nth 1 foot) (nth 2 foot)
                                                              (nth 3 foot) (nth 4 foot))
                                nil))
                    (if org
                      (setq xcol (car org)
                            yb0  (- (cadr org) (/ dep 2.0))
                            yt1  (+ (cadr org) (/ dep 2.0)))
                    (if (and offX (> offX 0.0))
                      ;; no mezzanine footprint to clamp against - the stated offsets, unchanged
                      (progn
                        (setq xcol offX)
                        (setq yb0 (- offY (/ dep 2.0)) yt1 (+ offY (/ dep 2.0))))
                      ;; Fall back to mezzanine-based placement if offsets not provided
                      (progn
                        (setq onREW (= (rem nOnMezz 2) 1))
                        (setq xcol (if foot
                                     (if onREW (- (nth 2 foot) inset) (+ (nth 1 foot) inset))
                                     (if onREW (- len inset) inset)))
                        ;; the two columns straddle the STAIRWELL, on the tower's outer lines
                        (setq yb0 (if foot (+ (nth 3 foot) inset) inset)
                              yt1 (+ yb0 dep)))))
                    (setq r (max 250.0 (* u 0.55)))
                    (foreach cy (list yb0 yt1)
                      ;; the column itself, drawn as the I-section this sheet uses everywhere
                      (vl-catch-all-apply
                        (function (lambda () (peb-stair-col-plan xcol cy))))
                      ;; and the ring that says "this one is the staircase's"
                      (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-STAIRS")
                                     (list 10 xcol cy 0.0) (cons 40 r))))
                    ;; ---- AND THE LABEL NAMES THE END THE STAIR IS ACTUALLY AT ------------------
                    ;; onREW was only ever set on the fallback path, so a stair placed from its BSF
                    ;; offsets was labelled "(LEW)" whichever end it stood at - ST2 at 42,260 of a
                    ;; 54,860 building, hard against the RIGHT end wall, printed "(LEW)" beside it.
                    ;; The end is not an input, it is a consequence of where the stair is: read it
                    ;; off the column that has just been placed.
                    (setq onREW (> xcol (/ len 2.0)))
                    ;; one label per stair, on a leader out from the upper column
                    (setq lab (strcat "STAIR COLUMNS - ST" (itoa i)
                                      (if onREW " (REW)" " (LEW)")))
                    (entmake (list (cons 0 "LINE") (cons 8 "COMP-STAIRS")
                                   (list 10 xcol (+ yt1 r) 0.0)
                                   (list 11 xcol (+ yt1 (* u 2.2)) 0.0)))
                    (setvar "CLAYER" "COMP-STAIRS")
                    (txt-bold "BC" (list xcol (+ yt1 (* u 2.4)))
                              (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 lab)
                    (setq nOnMezz (1+ nOnMezz) any T))
                (princ)))))
        (setq i (1+ i)))))
  (setvar "CLAYER" "0")
  (princ))
;; ===== SKYLIGHTS, PLACED (rule 4B.55) =====================================================
;; The count-only path below spreads skylights on an even grid.  That is honest for "N somewhere on
;; the roof" but it is not a LOCATION, and it can drop a skylight straight onto the ridge.  When the
;; BSF says how many PER BAY (RA_SKY_PER_BAY) the sheet can place them properly: the MIDDLE OF EACH
;; ROOF SIDE and the MIDDLE OF EACH BAY (owner 31-Aug-2026).
;;
;; Traced from MSPL 2025/203 (DHL Warehouse, Islamabad) approval drawing sheet 19 - a 49,370 x 66,845
;; gable at 1:10 over 8 bays carrying 16 skylights on a 2 x 8 grid, one per slope per bay.
;;
;; Drawn at the NET LIGHT OPENING (RA_SKY_L_NET, 3000), NOT the overall sheet (RA_SKY_L, 3250): the
;; balance laps under the roof sheeting and lets no light through, so drawing the overall would show
;; an opening 250 bigger than the building actually gets.  The BOQ still buys the overall.
;;
;; Layer "SKY LIGHT" cyan - the house layer, read out of MSPL-051's own DXF, not invented.  The fill
;; is 45-degree LINES and never a HATCH entity: real hatches do not survive acad /b.

;; n evenly spaced centres between y0 and y1.  n=1 lands on the MIDDLE of that side, which is the rule.
(defun peb-sky-half (y0 y1 n / out i)
  (setq out nil i 0)
  (while (< i n)
    (setq out (cons (+ y0 (* (- y1 y0) (/ (+ (* 2.0 i) 1.0) (* 2.0 n)))) out) i (1+ i)))
  (reverse out))

;; The y-stations of ONE bay's skylights.  Default splits them symmetrically about the ridge, so
;; 2 per bay = one per slope; an explicit Position forces them all onto one slope or onto the ridge.
;; rY comes from peb-ridge-y, so an off-centre ridge gives two DIFFERENT half widths and the
;; skylights still sit mid-slope on each - never (/ wid 2.0).
(defun peb-sky-rows (rY wid n pos / nearN farN)
  (cond
    ((and pos (vl-string-search "RIDGE" pos)) (list rY))
    ((and pos (vl-string-search "NSW" pos))   (peb-sky-half 0.0 rY n))
    ((and pos (vl-string-search "FSW" pos))   (peb-sky-half rY wid n))
    (T (setq nearN (fix (/ (+ n 1) 2)) farN (- n nearN))
       (append (peb-sky-half 0.0 rY nearN)
               (if (> farN 0) (peb-sky-half rY wid farN) nil)))))

;; 45-degree line fill on the CURRENT layer - the peb-mezz-hatch algorithm, not hard-wired to the
;; mezzanine layer.
(defun peb-sky-hatch (x0 y0 x1 y1 spacing / c cmax step xa xb lay)
  (if (or (null spacing) (<= spacing 0.0)) (setq spacing 250.0))
  (setq lay (getvar "CLAYER") step (* spacing 1.41421356)
        c (+ (- y0 x1) step) cmax (- y1 x0))
  (while (< c cmax)
    (setq xa (max x0 (- y0 c)) xb (min x1 (- y1 c)))
    (if (< (+ xa 1.0) xb)
      (entmake (list (cons 0 "LINE") (cons 8 lay) (cons 370 5)
                     (list 10 xa (+ xa c) 0.0) (list 11 xb (+ xb c) 0.0))))
    (setq c (+ c step)))
  (princ))

;; NO PART MARKS.  A proposal sheet is not a cutting list - SKL-01 / RS-01 and the parts table belong
;; to the APPROVAL drawing (owner 31-Aug: "at this stage no need to give the sheeting and skylight any
;; number").  One SKY LIGHT / W X L callout, the count, and the note.  Returns how many it drew.
(defun peb-draw-skylights-per-bay (data len wid bayPts n perBay / skyW skyL pos rY nb ys bi cx yc
                                   gf gt i0 i1 u ts drawn x0 x1 y0 y1 first nt)
  (setq skyW (MSPL-Get-Num data "RA_SKY_W")
        skyL (MSPL-Get-Num data "RA_SKY_L_NET"))
  (if (or (null skyW) (<= skyW 0.0)) (setq skyW 1000.0))
  (if (or (null skyL) (<= skyL 0.0)) (setq skyL 3000.0))
  (setq pos (strcase (MSPL-Get-Str data "RA_SKY_POS"))
        rY  (peb-ridge-y data wid)
        nb  (max 1 (1- (length bayPts)))
        ys  (peb-sky-rows rY wid (max 1 (fix perBay)) pos))
  ;; optional grid range; 0 / blank = every bay
  (setq gf (MSPL-Get-Num data "RA_SKY_GRID_FROM") gt (MSPL-Get-Num data "RA_SKY_GRID_TO"))
  (setq i0 (if (and gf (> gf 0)) (max 0 (1- (fix gf))) 0)
        i1 (if (and gt (> gt 1)) (min nb (1- (fix gt))) nb))
  (if (<= i1 i0) (setq i0 0 i1 nb))
  (setq u (max 400.0 (min 3000.0 (/ (max len wid) 70.0)))
        ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        drawn 0 bi i0 first T)
  (peb-comp-layer "SKY LIGHT" 4)
  (while (and (< bi i1) (< drawn n))
    (setq cx (/ (+ (nth bi bayPts) (nth (1+ bi) bayPts)) 2.0))
    (foreach yc ys
      (if (< drawn n)
        (progn
          (setq x0 (- cx (/ skyW 2.0)) x1 (+ cx (/ skyW 2.0))
                y0 (- yc (/ skyL 2.0)) y1 (+ yc (/ skyL 2.0)))
          ;; ONE PRODUCT, ONE DRAWER (rule 1, engine/Library/GOLDEN_RULES.md). This used to be
          ;; its own poly + hatch, so the identical fiberglass panel read as four fat stripes
          ;; here and as a glossy sheet on the wall. It now calls the component library, with
          ;; the sheen opened out to /4 because a roof plan shows the panel small - the density
          ;; is a scale choice, the geometry is shared.
          ;; Guarded: the library loads AFTER this file, which is fine at draw time, but Plan.lsp
          ;; must still work if it is ever loaded alone.
          (if (boundp 'peb-acc-light-elev)
            (progn
              (setq *PEB-ACC-SHEEN-DIV* 4.0)
              (peb-acc-light-elev x0 y0 (- x1 x0) (- y1 y0) "ROOF")
              (setq *PEB-ACC-SHEEN-DIV* nil))
            (progn
              (setvar "CLAYER" "SKY LIGHT")
              (peb-comp-poly (list (list x0 y0) (list x1 y0) (list x1 y1) (list x0 y1)))
              (peb-sky-hatch x0 y0 x1 y1 (/ skyW 4.0))))
          ;; No leader.  The size now rides in the note block below the drawing with everything
          ;; else (owner 31-Aug: "all text below the drawings"), and a hatched 1000 x 3000 panel
          ;; repeated 16 times on a bay grid does not need to be pointed at.
          (setq drawn (1+ drawn)))))
    (setq bi (1+ bi)))
  ;; the count, in the house wording, and the standing note.  Owner 31-Aug: the window to move a
  ;; skylight is the APPROVAL stage, not erection - the sheets ship CUT TO SIZE, so the location is
  ;; fixed the moment the drawing is approved.  (PAECO 169's "BEFORE ERECTION" is superseded.)
  ;; ---- the note block: ALL of it BELOW the drawing, and below the view heading --------------
  ;; These two lines used to sit just under the eave, where the sheet's own view heading
  ;; ("ROOF SHEETING PLAN", ~1,900 tall) already lives - the note printed straight through it.
  ;; Measured: note at y -3422 against a heading spanning -5283..-3387.  There is no room above the
  ;; heading for four lines, so the block goes BELOW it, left-aligned, one ladder rung, even pitch.
  ;; Heights come from peb-th (4B.27); the long note is additionally capped by peb-fit-txt-h so it
  ;; can never grow wider than the building it belongs to.
  (setvar "CLAYER" "TEXT")
  (txt "ML" (list 0.0 (- 0.0 (* (peb-th 'ANNOT) ts 7.5))) (peb-th 'ANNOT) 0.0
       (strcat (if (< drawn 10) (strcat "0" (itoa drawn)) (itoa drawn))
               " No. ROOF SKY LIGHT (EACH " (rtos skyL 2 0) "mm) - "
               (rtos skyW 2 0) " X " (rtos skyL 2 0) " TYPICAL"))
  ;; NO skylight-location note on a PROPOSAL sheet (owner 31-Aug: "it do not seems good at the time
  ;; of proposal stage").  It was traced from PAECO 169 - an APPROVAL drawing, where the location is
  ;; being fixed and saying so is the point.  Here it is premature and, worse, redundant: this sheet's
  ;; own General Note 3 already reads "PROPOSAL DRAWING IS INDICATIVE ONLY; FINAL DIMENSIONS & LEVELS
  ;; WILL BE SHOWN IN THE APPROVAL DRAWING AT THE DESIGN STAGE."  The note belongs on the approval
  ;; drawing, with the rest of what approval fixes.
  (setvar "CLAYER" "0")
  drawn)

;; ---- ROOF ACCESSORIES (RA_*) : skylights + turbo-vents as COUNTS → typical distributed roof marks
;;      (no per-unit grid location in the IF; grid-located ones flow through PL_ placements), + a roof-
;;      opening area note. Owner 6-Jul "100% IF": closes the count-based accessory fields. ----
(defun peb-draw-roof-accessories (data len wid bayPts / nsky nvent opening u ts sq cols rows i j k px py r ridge cap perBay)

  ;; --- GRAVITY RIDGE VENTILATORS (RA_RV_*) ----------------------------------------------
  ;;
  ;;  The roof plan is the sheet that shows HOW MANY and WHERE, and it drew none of them:
  ;;  the section and the end elevation each show one typical unit, so without this a job
  ;;  with six ventilators looked like a job with one.
  ;;
  ;;  Maimaar's own roof sheeting plan (MSPL-203 drawing 18) draws each unit as a heavy
  ;;  3000-long bar sitting on the ridge line, with ONE "(TYP.) RIDGE VENTILATOR" callout
  ;;  and the count in the legend (RV-01, 3,000, 8 No.). This reproduces that.
  ;;
  ;;  SINGLE vs CONTINUOUS is the BSF's own ventType and they are genuinely different
  ;;  products on the roof: discrete units centred in each bay, or one unbroken run along
  ;;  the ridge. Drawing a continuous run as six separate bars would misstate what is being
  ;;  bought, so the two are drawn differently.
  ;;
  ;;  The QUANTITY caps the loop: a job with fewer ventilators than bays gets the number it
  ;;  is paying for, starting at the first bay, rather than one per bay regardless.
  (if (and (boundp 'peb-rv-plan)
           (= (strcase (peb-tb-or (MSPL-Get-Str data "RA_RV_ON") "No")) "YES"))
    (vl-catch-all-apply (function (lambda ( / rvY rvQ rvLen rvPer rvTw rvCont nb bi bj cx bw pit drawn ax)
      ;; EVERY NUMBER THROUGH atoi/atof ON A STRING. MSPL-Get-Num returns nil for a key the
      ;; data file does not carry, and (max 0.0 nil) throws — inside a vl-catch-all-apply that
      ;; the CALLER has already wrapped in a second one, so the ventilators simply did not
      ;; appear and nothing anywhere said why. Both roof plans drew zero.
      (setq rvY    (peb-ridge-y data wid)
            rvQ    (atoi (peb-tb-or (MSPL-Get-Str data "RA_RV_QTY") "0"))
            rvLen  (atof (peb-tb-or (MSPL-Get-Str data "RA_RV_LEN") "3000"))
            rvPer  (max 1 (atoi (peb-tb-or (MSPL-Get-Str data "RA_RV_PER_BAY") "1")))
            rvTw   (atof (peb-tb-or (MSPL-Get-Str data "RA_RV_THROAT") "300"))
            rvCont (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data "RA_RV_TYPE") "Single")) "*CONTIN*")
            drawn  0 ax nil)
      (if (<= rvLen 0.0) (setq rvLen 3000.0))
      ;; NO USABLE BAY GRID -> fall back to spreading the stated quantity evenly along the
      ;; ridge, rather than drawing nothing. A roof plan that omits six ventilators the
      ;; customer is paying for is worse than one that spaces them approximately.
      (if (or (null bayPts) (< (length bayPts) 2))
        (progn
          (setq bayPts nil nb (max 1 rvQ) bi 0)
          (while (and (< bi nb) (< drawn (max rvQ 1)))
            (setq cx (* len (/ (+ bi 0.5) (float nb))))
            (peb-rv-plan cx rvY rvLen rvTw 1.0)
            (if (null ax) (setq ax cx))
            (setq drawn (1+ drawn) bi (1+ bi)))))
      (if (and (null bayPts) (> drawn 0))
        nil                                      ; already drawn by the no-grid fallback above
      (if rvCont
        (progn                                   ; CONTINUOUS — one unbroken run on the ridge
          (peb-rv-plan (* len 0.5) rvY (* len 0.94) rvTw 1.0)
          (setq ax (* len 0.30) drawn (max rvQ 1)))
        (progn                                   ; SINGLE — units centred in each bay
          (setq nb (max 1 (1- (length bayPts))) bi 0)
          (while (and (< bi nb) (or (<= rvQ 0) (< drawn rvQ)))
            (setq bw  (- (nth (1+ bi) bayPts) (nth bi bayPts))
                  pit (/ bw (float (1+ rvPer))) bj 1)
            (while (and (<= bj rvPer) (or (<= rvQ 0) (< drawn rvQ)))
              (setq cx (+ (nth bi bayPts) (* bj pit)))
              (peb-rv-plan cx rvY rvLen rvTw 1.0)
              ;; anchor the ONE callout on a MIDDLE unit, not the first: at the left-hand end
              ;; it lands on the "RIDGE LINE" note that shares this line.
              (if (or (null ax) (< (abs (- cx (* len 0.5))) (abs (- ax (* len 0.5))))) (setq ax cx))
              (setq drawn (1+ drawn) bj (1+ bj)))
            (setq bi (1+ bi))))))
      ;; ONE typical callout for the whole run (golden rule 17), carrying the count.
      (if ax (peb-rv-label ax rvY
                           (+ ax (* 1.2 (peb-th 'ANNOT)))
                           (+ rvY (* 3.0 (peb-th 'ANNOT)))
                           drawn (peb-th 'ANNOT)))))))

  (setq nsky    (MSPL-Get-Num data "RA_SKYLIGHTS")
        nvent   (MSPL-Get-Num data "RA_TURBOVENTS")
        opening (MSPL-Get-Num data "RA_ROOF_OPENING")
        u  (max 400.0 (min 3000.0 (/ (max len wid) 70.0)))
        ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (if (or (and nsky (> nsky 0)) (and nvent (> nvent 0)) (and opening (> opening 0)))
    (peb-comp-layer "COMP-ROOF-ACC" 4))                      ; cyan
  ;; --- skylights ---------------------------------------------------------------------------
  ;; PLACED when the BSF states a per-bay count AND the caller handed us the real bay grid: middle of
  ;; each roof side, middle of each bay (rule 4B.55).  Otherwise the original even grid, UNCHANGED -
  ;; so every drawing that does not use the new key renders exactly as it did before.
  (setq perBay (MSPL-Get-Num data "RA_SKY_PER_BAY"))
  (if (or (null perBay) (<= perBay 0.0)) (setq perBay 0.0))
  (if (and nsky (> nsky 0) (> perBay 0.0) bayPts (> (length bayPts) 1))
    (peb-draw-skylights-per-bay data len wid bayPts (fix nsky) perBay)
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
                (strcat (itoa nsky) " SKYLIGHTS (TYP. DISTRIBUTED)")))))
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
  ( / dataFile data wMods
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
  ;; THE SHARED PLAN STYPE (peb-plan-stype, Standard.lsp).  The body moved there VERBATIM:
  ;; ACS->CS / AMS->MS behind *PEB-ARCHED* (the arch shows only in the SECTION, owner 5-Jul),
  ;; then the whitelist fold with PP kept in it (owner 9-Jul: omitted once, and a Petrol Pump
  ;; silently drew as a clear-span gable).  It lived ONLY here, which is why the roof sheets
  ;; drew a different fall-arrow set for the same building.  The fallback keeps a Plan-only
  ;; load resolving the type identically.
  (setq stype
    (if (boundp 'peb-plan-stype)
      (peb-plan-stype data)
      (progn
        (setq stype (strcase (MSPL-Get-Str data "STYPE")))
        (setq *PEB-ARCHED* nil)
        (cond ((= stype "ACS") (setq *PEB-ARCHED* T stype "CS"))
              ((= stype "AMS") (setq *PEB-ARCHED* T stype "MS")))
        (if (not (member stype '("CS" "SS" "MS" "LT" "MG" "FR" "RC" "CC" "BF" "PP")))
          (setq stype "CS"))
        stype)))
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
  (setq *PEB-BUB-FIT* (peb-bub-fit "PLAN"))     ; see peb-bub-fit - never inherited

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
    ;; ── BELOW THE BOX, NOT ABOVE IT (owner 4-Sep-2026) ──────────────────────────────
    ;; Above the AREA tag is where the RIDGE LINE callout lives, and the two grazed:
    ;; measured on B-01, "RIDGE LINE" occupies y 13,150-14,050 and this tag 12,677-13,273,
    ;; so the ridge label clipped its top by 123 over a 2,975 overlap - about 0.4 mm at
    ;; 1:312, which is exactly enough to read as crowded lettering rather than two labels.
    ;; Below the box is empty: the ridge is drawn on the centre line and its callout always
    ;; goes UP and to the RIGHT (peb-ridge-symbol), so the two can no longer meet whatever
    ;; bay the ridge anchor lands in.
    (txt-bold "MC" (list aCx (- aCy aBh (* aTxH 1.35))) (peb-th 'SMALL) 0
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
  (setq j 0 nWid (length gridWpts) wMods (peb-width-mods data wid))
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
        ;; peb-width-mark, not a straight count: a station that is a width-MODULE line takes a
        ;; plain letter and an infill post takes the primed letter of the main above it (4B.61).
        (grid-bubble (- gridX1 bubOfs) y (peb-width-mark y gridWpts wMods) "R")))   ; owner 5-Jul: letter offset -> grid CONTINUES across stacked areas; skip-I via peb-grid-letter
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
      (vl-catch-all-apply (function (lambda () (peb-draw-bracing bayPts widthPts wid 0.0 0.0 lewBrace rewBrace extType intType data))))
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
      ;; -- THE LABEL THAT WAS COSTING THE SHEET HALF ITS SCALE (owner 3-Sep-2026) ------
      ;; "Fix the bubbles issue as well."  The bubbles were the symptom.  This dim used to read
      ;; "BUILDING LENGTH : 54,860 [180'-0\"] O/O STEEL COLUMN" - fifty characters, which at this
      ;; sheet's lettering is WIDER than the 54,860 it measures.  A stretched dim whose text will
      ;; not fit between its own extension lines puts the text OUTSIDE, so the whole string hung
      ;; off the right of grid 8 and became the sheet's rightmost ink.  The auto-fit frames the
      ;; extents, so ONE label doubled the sheet's width and took the plan from about 1:400 to
      ;; 1:608 - and a bubble drawn at 4B.31's model radius then plots two-thirds the size it
      ;; does on the framing elevations of the same building.  That is the "bubbles are not the
      ;; same" the eye actually sees: not a different radius, a different SHEET SCALE.
      ;;
      ;; The overall carries its value and its feet (4B.11) and nothing else - exactly as the
      ;; framing elevations' overall does, which is the point of 4B.8.  The BASIS is not lost:
      ;; the bay chain immediately below states "... O/O STEEL COLUMN" on the same stack, and
      ;; the subtitle above states the size.  Each fact once.
      (peb-dim-h-stretch (nth 3 ldim) (+ len (nth 4 ldim)) yOvrDim
                         (peb-fmt-overall (nth 0 ldim)))
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
  ;; Same treatment as the overall LENGTH above: value + feet, no prefix and no basis - the two
  ;; nested chains inboard of it already carry "O/O STEEL COLUMN", and rotated up the margin this
  ;; string was the tallest thing on the sheet as well as a second voice for the same fact.
  (peb-dim-height-stretch 0.0 (- (* 3.0 dimGap)) (nth 3 wdim) (+ wid (nth 4 wdim))
                          (peb-fmt-overall (nth 0 wdim)))
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
  ;; Dimension TEXT + ARROWS.  STANDING RULE (owner 19-Jul-2026, PD_RULEBOOK 3.7 / 4B.62 /
  ;; S55): every DIMENSION arrowhead in the set is the OPEN V.  Leader and callout heads stay
  ;; FILLED - that is the other half of the rule, and it is set on the MLEADER style, not here.
  ;; Ticks are retired (DIMTSZ 0).  Height comes from the peb-th ladder, never a literal.
  ;;   Corrected 4-Sep-2026: this defun used to set DIMBLK "_CLOSEDFILLED", which contradicted
  ;;   the rule.  It was latent only because every native dim goes through peb-dim-set-vars
  ;;   (which sets _OPEN) first - the next one added without that wrapper would have been wrong.
  (setvar "DIMTXT"   (peb-th 'DIM))     ; ladder: 2.5 mm of paper (x DIMSCALE)
  (setvar "DIMTSZ"     0.0)        ; no ticks -> use arrowheads
  (setvar "DIMASZ"   700.0)        ; 2.5 mm on the printed sheet - the ISO / AutoCAD standard.
                                 ; 320 plotted at ~1.0 mm at 1:300, about 40% of standard, and
                                 ; disagreed with the cross-section's own 800 in the same set.
  (vl-catch-all-apply (function (lambda () (setvar "DIMBLK" "_OPEN"))))
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
  (setq s (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0) ah (* 560.0 s) w (* 100.0 s))
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
  (peb-safe-setvar "DIMASZ"   700.0)        ; 2.5 mm on paper - see the note at the other setter
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

;; ── THE MEZZANINE FLOOR PLAN MUST SHOW THE WHOLE FLOOR PLATE ────────────────────
;; Owner 29-Aug: "where there is no mezzanine show the void with crosslines & text".
;;
;; The sheet used to draw ONLY the deck, so a partial mezzanine came out as a rectangle
;; floating on an empty page — nothing said how much of the building it covered, or which end
;; it sat at. On MSPL-26-271 the deck is 49.7 m of a 63.6 m width, and the missing 13.9 m
;; simply was not on the drawing.
;;
;; One void band: the building outline round it, a crossed pair of diagonals through it, and a
;; label. Drawn BEFORE the deck so the deck reads on top.
(defun peb-mzfp-void (x0 y0 x1 y1 lbl / cx cy th)
  ;; 1500 mm, not 1 mm. The deck stops at the COLUMN FACE, so the gap between it and the wall
  ;; line is half a column web — ~350 mm — on the sides the mezzanine actually reaches. At a
  ;; 1 mm threshold that sliver was crossed and labelled "VOID" hard against grid A, which reads
  ;; as a missing strip of floor that does not exist. A real void is a bay, not a flange.
  (if (and (> (- x1 x0) 1500.0) (> (- y1 y0) 1500.0))
    (progn
      (peb-comp-layer "COMP-MEZZ-VOID" 8)
      (vl-catch-all-apply (function (lambda ()
        (command "_.LINE" (list x0 y0) (list x1 y1) "")
        (command "_.LINE" (list x0 y1) (list x1 y0) ""))))
      ;; The label goes near the BOTTOM of the band. The two diagonals meet at the centre, so a
      ;; centred label is struck through by both; near an edge the legs are still out by the
      ;; corners and the middle is clear. Bottom rather than top because the sheet's own caption
      ;; ("MEZZANINE FLOOR-n LAYOUT PLAN (LEVEL ...)") sits just under the deck, i.e. across the
      ;; TOP of the void band — putting the label there simply swapped one collision for another.
      (setq th (* (peb-th 'SMALL) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)))
      (setq cx (/ (+ x0 x1) 2.0) cy (+ y0 (* th 1.2)))
      (if (> cy (- y1 (* th 0.6))) (setq cy (/ (+ y0 y1) 2.0)))   ; a shallow band: centre it
      (setvar "CLAYER" "TEXT")
      (vl-catch-all-apply (function (lambda ()
        (txt-bold "MC" (list cx cy) (peb-th 'SMALL) 0 lbl))))))
  (princ))

(defun peb-draw-mezz-floor-plan (data len wid floorNum / spList bayPts glF glT offF offT fx0 fx1 fy0 fy1
                                 ys xs acc s2 x y colD savedWeb jx i gbr wMods sc band inset
                                 mzRcc rccXs rccYs floorSys jspSys lvl lvlStr specStr mzJoist
                                 dimX yprev yy jy beamHalf joistHalf secHalf secSp sx isGrating
                                 bayA bayB legX legY rowH sampleLen L colR
                                 jbi jxa jxb thS mzThk fflLvl mainYs mzOnly bubR2 stVoids
                                 gYs ewSt sufW sufL chainMod chainEW rungX rungY
                                 wModsOO ewStOO)
  (setq sc (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  ;; -- RULE 4B.26 - EVERY NOTE ON THIS SHEET IS SIZED FROM THE LADDER (owner 29-Aug) --
  ;; "Floors Details are Also Missing ... We had already developed it."  They were not missing.
  ;; The legend, the member names and the deck spec note were all drawn at (/ NNN sc), and `txt`
  ;; multiplies by *PEB-TEXT-SCALE* again - so they plotted at a FIXED ~300 mm whatever the
  ;; building, against a ladder whose smallest rung ('SMALL) plots at 550*scale = ~1,140 mm here.
  ;; Nearly four times under the ladder floor, they came out as an unreadable smudge in the corner
  ;; of the A4 sheet: developed, drawn, and invisible.
  ;; thS is that plotted height in MODEL units, so every offset below is expressed in text-heights
  ;; and the block stays proportioned at any building size.
  (setq thS (* (peb-th 'SMALL) sc))
  (setq inset (max 300.0 (min 1000.0 (* (min len wid) 0.10))))
  (setq spList (peb-mzfp-splist data) bayPts (peb-mzfp-bays data len))

  ;; WIDTH footprint — the SAME peb-mz-width-band as the CLP so the two sheets agree.  This runs
  ;; STANDALONE (no plan drawn), so seed *PEB-WGRID-YS* from the width module lines to make the
  ;; grid-LETTER placement work here too; if the plan already set it, keep that.
  (if (not (and (boundp '*PEB-WGRID-YS*) *PEB-WGRID-YS*))
    (setq *PEB-WGRID-YS* (vl-sort (peb-main-column-ys data wid) '<)))
  (setq band (peb-mz-width-band data wid inset) fy0 (car band) fy1 (cadr band))
  (princ (strcat "
PEB-MZFP-DIAG band=" (rtos fy0 2 1) ".." (rtos fy1 2 1)
                 " span=" (rtos (- fy1 fy0) 2 1)
                 " wgridN=" (itoa (length *PEB-WGRID-YS*))
                 " wgrid=" (vl-princ-to-string (mapcar (function (lambda (v) (fix v))) *PEB-WGRID-YS*))))

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
  ;; A MAIN BEAM ON BOTH END WALLS (owner 1-Sep-2026: "On Both Endwalls as well, there will be main
  ;; beam b/w the post columns and joists will rest on it").
  ;;
  ;; xs is the bay lines CLIPPED to the deck band, and the band is inset from the building ends - so
  ;; the first and last bay lines fell outside it and no beam was drawn at either end wall. The joists
  ;; are drawn bay by bay BETWEEN consecutive xs, so the end bay had nothing to frame into: a floor
  ;; running to the end wall with no member carrying it there.
  ;;
  ;; Force the two deck edges into the beam line list. Each spans post to post across the width like
  ;; every other main beam, and because the joist loop reads this same list, the end-bay joists now
  ;; land on it automatically. Added only when a bay line is not already there, so a mezzanine that
  ;; genuinely stops mid-bay is unchanged.
  (if (not (vl-some (function (lambda (v) (< (abs (- v fx0)) 1.0))) xs)) (setq xs (cons fx0 xs)))
  (if (not (vl-some (function (lambda (v) (< (abs (- v fx1)) 1.0))) xs)) (setq xs (append xs (list fx1))))
  (setq xs (vl-sort xs '<))
  ;; ...and the two END bay lines carry columns as well, so they get the same centreline
  ;; correction the width stations get (see peb-mezz-snap-ends).  Without it the end-wall
  ;; column straddles the out-to-out line and the length arrow lands inside the steel.
  (if (and (< (abs (car xs)) 1.0) (< (abs (- (last xs) len)) 1.0))
    (setq xs (peb-mezz-snap-ends xs len)))

  ;; THE WHOLE FLOOR PLATE FIRST (owner 29-Aug): the building outline, then every part of it the
  ;; mezzanine does NOT cover, crossed and labelled. Up to four bands — below / above the deck
  ;; across the width, and before / after it along the length. Each is skipped when empty, so a
  ;; full-footprint mezzanine draws exactly as it always did.
  (peb-comp-layer "COMP-MEZZ-VOID" 8)
  (vl-catch-all-apply (function (lambda ()
    (command "_.RECTANG" (list 0.0 0.0) (list len wid)))))
  (peb-mzfp-void 0.0 0.0  len  fy0 "VOID - NO MEZZANINE")           ; below the deck (NSW side)
  (peb-mzfp-void 0.0 fy1  len  wid "VOID - NO MEZZANINE")           ; above the deck (FSW side)
  (peb-mzfp-void 0.0 fy0  fx0  fy1 "VOID")                         ; before it along the length
  (peb-mzfp-void fx1 fy0  len  fy1 "VOID")                         ; after it along the length
  ;; floor system -> joist rule (owner 11-Jul): PRECAST / HOLLOW-CORE = beams only (no joists);
  ;; GRATING / CHEQUERED PLATE = closer joists at 1220 mm (4 ft); DECK + SLAB = joists at MZ_JOIST.
  ;; DECIDED BEFORE THE HATCH, because the hatch now depends on it (see below).
  (setq floorSys (strcase (peb-tb-or (MSPL-Get-Str data (strcat "MZ" (itoa floorNum) "_FLOOR"))
                                     (MSPL-Get-Str data "MZ1_FLOOR"))))
  (setq mzJoist (MSPL-Get-Num data "MZ_JOIST"))
  (if (or (null mzJoist) (<= mzJoist 0.0)) (setq mzJoist 1500.0))
  (cond ((wcmatch floorSys "*PRECAST*,*HOLLOW*")        (setq jspSys nil))
        ((wcmatch floorSys "*GRAT*,*PLATE*,*CHEQ*")     (setq jspSys 1220.0))
        (T                                              (setq jspSys mzJoist)))

  ;; -- THE DECK HATCH IS A LAST RESORT, NOT A BACKGROUND (owner 29-Aug) ----------------
  ;; "Joists are not Shown Properly."  A diagonal hatch at 1600 c/c UNDER 39 joist rows at
  ;; 1,250 c/c is two overlapping line fields at almost the same pitch; on the A4 sheet they
  ;; read as one grey mat with the beams lost inside it.  The hatch exists to say "there is a
  ;; floor here" - which is exactly what the joists say, better.  So hatch ONLY when there are
  ;; no joists to draw (precast / hollow-core), where it is the only thing marking the deck.
  (if (null jspSys)
    (vl-catch-all-apply (function (lambda () (peb-mezz-hatch fx0 fy0 fx1 fy1 1600.0)))))
  ;; deck outline
  (peb-comp-layer "COMP-MEZZ" 6)
  (peb-comp-poly (list (list fx0 fy0) (list fx1 fy0) (list fx1 fy1) (list fx0 fy1)))

  ;; ---- FRAMING MEMBERS drawn as their TOP FLANGE to scale (owner 12-Jul): main beam 200mm, joist
  ;; 150mm, secondary joist 100mm top flange.  Each on its own layer so COLOUR + LINE-THICKNESS come
  ;; BYLAYER (beam blue/0.50, joist grey/0.25, sec-joist grey/0.13 — the "material" line-weight standard).
  ;; Floor-system content: decking sheet -> beams + joists; hollow-core/precast -> beams only;
  ;; grating/chequered plate -> beams + joists + SECONDARY joists. ----
  ;; flange HALF-widths, exaggerated ~2.5x from the true 200/150/100mm so the I-profiles READ at plan
  ;; scale (owner 12-Jul: "draw as real steel profiles ... visibly exaggerated") — proportions kept.
  ;; -- RULE 4B.42 - MEMBERS ARE DRAWN AT THEIR REAL FLANGE WIDTH (owner 29-Aug) -------
  ;; "Main Beams top flanges are shown very thick and Joist are shown very very thin ...
  ;;  But actually there small difference - For Example if the Main Flange is 300mm-350mm,
  ;;  joists are 150-200mm normally."
  ;;
  ;; The old half-widths (250 / 180 / 120) were an invented ~2.5x exaggeration of an invented
  ;; 200 / 150 / 100.  That made the drawn ratio 1.39 : 1 where the real one is close to 2 : 1,
  ;; so the beam read as a solid bar and the joist as a hairline beside it - the difference in
  ;; the wrong place and the wrong size.  These are the owner's own numbers, mid-range:
  ;; main beam 325, joist 175, secondary 125 - so the sheet shows the steel that is quoted.
  ;;
  ;; REVISED 29-Aug: "also make the size of main beams as 200 and joist 150 Typically."  The
  ;; first pass used 325 / 175, read off the owner's earlier "300-350 ... 150-200"; he has since
  ;; settled the typical section at MAIN BEAM 200 / JOIST 150 / SECONDARY 100 top flange.  Those
  ;; are the numbers drawn - halved here because these are half-widths.
  ;;
  ;; At 200 vs 150 the two members are only 0.42 and 0.32 mm apart on the plotted sheet, so the
  ;; WIDTH can no longer carry the distinction on its own: the LINE WEIGHT does, which is the
  ;; house rule anyway ("material = line thickness") and is set per layer in PEB_LAYERS.csv -
  ;; beam 0.40, joist 0.30, secondary 0.18.
  ;;
  ;; The `max` is a LEGIBILITY FLOOR, not a fudge.  Every sheet is auto-fitted to A4, so a fixed
  ;; model width plots smaller the bigger the building, and past a point a 150 mm joist flange
  ;; closes to a single line and stops reading as a member at all.  The floor is expressed in
  ;; *PEB-TEXT-SCALE* - the engine's "constant on paper" unit - and TUNED SO THE TRUE SIZE WINS
  ;; at this building (93 m, scale 2.07: floor 87 / 66 / 46 against true 100 / 75 / 50).  It only
  ;; takes over on buildings big enough that the true width would vanish.
  (setq beamHalf  (max 100.0 (* 42.0 sc))
        joistHalf (max  75.0 (* 32.0 sc))
        secHalf   (max  50.0 (* 22.0 sc)))
  (setq isGrating (wcmatch floorSys "*GRAT*,*CHEQ*,*PLATE*"))

  ;; CALCULATE STAIRCASE VOIDS EARLY (for joist/beam exclusion)
  ;; Standing Rule: Remove joists & beams in staircase void area
  (setq stVoids (peb-stair-voids data fx0 fx1 fy0 fy1))

  ;; JOISTS — 150mm double-line flange ALONG THE LENGTH, spaced across the width at jspSys.  None for
  ;; precast / hollow-core (jspSys nil).
  (if jspSys
    (progn
      ;; ---- THE JOIST COLOUR  (owner 3-Sep-2026) ----------------------------------------------
      ;; "Change the colour of joist to a bit more visible while working."
      ;;
      ;; COMP-MEZZ-JOIST was ACI 8 - dark grey.  On paper it plots black like everything else, so the
      ;; PDF never showed the problem; in the model, which is where the drawing is actually worked on,
      ;; a mezzanine floor is mostly joists and every one of them was the dimmest colour in the index.
      ;; ACI 3 (green) reads on either background and stays clearly apart from the beam's ACI 5 (blue),
      ;; which matters more here than on any other sheet: beam and joist are drawn as the same kind of
      ;; line and are told apart by weight and colour alone.
      (peb-comp-layer "COMP-MEZZ-JOIST" 3)
      (setvar "CLAYER" "COMP-MEZZ-JOIST")
      ;; -- A JOIST SPANS ONE BAY, BETWEEN TWO BEAMS (owner 29-Aug) ---------------------
      ;; "Joists are not Shown Properly."  Each joist was ONE line the full 93 m length of the
      ;; building, running straight over all thirteen main beams.  A joist does not do that - the
      ;; main beams run across the width at every bay line, and the joists span BETWEEN them, one
      ;; bay (7.7 m) at a time.  Drawn continuous they read as ribs of the deck rather than as
      ;; members, and they bury the very beams they land on.
      ;;
      ;; Draw each joist bay by bay, stopping a beam half-flange short at both ends so it visibly
      ;; frames INTO the beam.  The bays come from xs - the same beam lines drawn below - so a
      ;; joist can never cross a beam.  A bay too short to hold a readable segment is skipped
      ;; rather than drawn as a stub.
      (setq jy (+ fy0 jspSys))
      (while (< jy (- fy1 100.0))
        (setq jbi 0)
        (while (< jbi (1- (length xs)))
          (setq jxa (+ (nth jbi xs) beamHalf) jxb (- (nth (1+ jbi) xs) beamHalf))
          (if (> (- jxb jxa) beamHalf)
            (peb-mezz-member-broken jxa jy jxb jy joistHalf stVoids))
          (setq jbi (1+ jbi)))
        (setq jy (+ jy jspSys)))
      (vl-catch-all-apply (function (lambda ()
        ;; -- RULE 4B.49 - DO NOT PUBLISH A SPACING DESIGN WILL SET (owner 29-Aug) --------
        ;; "do not show the joist spacing, spacing remains as per design."
        ;; The joists are still DRAWN on a spacing - they have to be drawn somewhere, and the
        ;; estimate still prices that spacing - but the sheet must not PRINT the number. A
        ;; proposal drawing that states 1,250 c/c is read as a commitment, and the spacing is
        ;; settled at design/SAP against the real floor loading. Same reason the mezzanine
        ;; column SECTION size is not shown (owner 12-Jul). What the drawing states, it owes.
        ;; ...ABOVE the bubble row, not through it (owner 3-Sep-2026).  This sat at 1.2 text
        ;; heights over the deck edge, which was clear white paper until the bay NUMBERS were
        ;; synced onto this sheet; the bubbles are centred at fy1 + 3r and the note printed
        ;; straight across them.  4B.27 again: a gap that has to clear something is measured
        ;; from that thing - here the bubble radius, so the two move together for ever after.
        (txt "MC" (list (/ (+ fx0 fx1) 2.0) (+ (max fy1 wid) (* (peb-bub-r) 10.6))) (peb-th 'SMALL) 0.0
             "JOISTS ALONG LENGTH, SPANNING BAY TO BAY - SPACING AS PER DESIGN"))))))

  ;; SECONDARY JOISTS — grating / chequered plate only: 100mm double-line flange PERPENDICULAR to the
  ;; joists (WIDTH direction), spaced along the length at HALF the joist spacing.  Shown in ONE
  ;; representative bay as TYPICAL (a full grid of them across the floor buries the plan) — owner 12-Jul.
  (if (and jspSys isGrating (> (length xs) 1))
    (progn
      (peb-comp-layer "COMP-MEZZ-JOIST-SEC" 4)
      (setvar "CLAYER" "COMP-MEZZ-JOIST-SEC")
      (setq secSp (/ jspSys 2.0) bayA (nth 0 xs) bayB (nth 1 xs) sx (+ bayA secSp))
      (while (< sx (- bayB 1.0))
        (peb-mezz-member-broken sx fy0 sx fy1 secHalf stVoids)
        (setq sx (+ sx secSp)))
      (vl-catch-all-apply (function (lambda ()
        ;; rule 4B.49 — the secondary spacing is a design number too
        (txt "MC" (list (/ (+ bayA bayB) 2.0) (- 0.0 (* thS 1.2))) (peb-th 'SMALL) 0.0
             "SECONDARY JOISTS (TYP.) - SPACING AS PER DESIGN"))))))

  ;; MAIN BEAMS — 200mm double-line flange (heaviest), in the WIDTH direction, column to column, one at
  ;; each length column line (xs).  Drawn LAST so the heavy beams read on top of the joists + secondaries.
  ;; The beam RUNS THE WHOLE GRID LINE and BREAKS over the stairwell - see
  ;; peb-mezz-member-broken.  Deleting it wholesale is what took grids 2 and 7 off 279-26.
  (peb-comp-layer "COMP-MEZZ-BEAM" 5)
  (setvar "CLAYER" "COMP-MEZZ-BEAM")
  (foreach x xs
    (peb-mezz-member-broken x fy0 x fy1 beamHalf stVoids))
  ;; The rotated "MAIN BEAM (TYP.)" tag that used to stand here is GONE (owner 29-Aug,
  ;; "austhetic is not good").  It named a member the legend below already names, and it stood
  ;; ON the second beam, crossing every joist in that bay - a label obscuring the thing it
  ;; labels.  One naming of each member, in the legend, off the drawing.

  ;; ---- LEGEND / KEY (owner 12-Jul "beautiful") — the framing members, each sample drawn on its own
  ;; layer so it shows the real colour + line-thickness + top-flange width, with its NAME.  Lower-left,
  ;; below the plan (secondary joist row only when this floor system has secondaries). ----
  ;; -- THE CAPTION BLOCK HANGS OFF THE BUILDING, NOT OFF THE DECK (owner 29-Aug) ------
  ;; fy0 is the DECK's lower edge; the void band runs from the building edge up to it.  Hanging
  ;; the legend, the spec note and the sheet title off fy0 dropped all three INSIDE that void
  ;; band - straight across its crossed diagonals and its "VOID - NO MEZZANINE" label, four
  ;; pieces of text in one strip (measured on MSPL-26-271, where the void is a 13.9 m band).
  ;; The whole floor plate starts at y = 0, so that is what the block hangs from.  A mezzanine
  ;; covering the full width has fy0 = 0 and is unaffected.
  (setq legX fx0
        legY (- 0.0 (* thS 1.7))
        rowH (* thS 1.5)
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
          (txt "ML" (list (+ legX sampleLen (* thS 0.5)) legY) (peb-th 'SMALL) 0.0 (nth 3 L)))))
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
    ;; -- RULE 4B.40/4B.45 - AN I-SECTION, A GAP, THEN THE BUBBLE (owner 29-Aug) ---------
    ;; "Circle bubble will come on mezzanine columns on Ground Floor Plan & Mezzanine Floor Plan.
    ;;  I symbol will be shown in the circle", "we must see the I and there should be small gap
    ;;  and then bubble must come."
    ;;
    ;; This sheet drew every column as a plain tube CIRCLE, so it showed neither the section nor
    ;; the distinction: a full-height main frame column and a stub that stops at the beam soffit
    ;; were the same dot.  It now uses the SAME symbol as the Column Layout Plan overlay - the
    ;; I-section body, encircled when the column exists only for the mezzanine - so a reader
    ;; moving between the two sheets sees one convention, not two.
    (progn
      (peb-comp-layer "COLUMNS" 1)
      (setvar "CLAYER" "COLUMNS")
      ;; rule 4B.45 — floor the stub so the I reads at sheet scale, cap it under the main frame
      (setq colD (peb-mz-stub-depth colD wid) *PEB-COL-WEB* colD)
      ;; -- RULE 4B.40 - AN ENCIRCLED COLUMN IS A MEZZANINE-ONLY COLUMN (owner 29-Aug) -----
      ;; "the internal columns of mezzanine which are coming till only mezzanine bottom will have
      ;;  a circle bubble around the columns ... It will differentiate b/w the columns of main
      ;;  building and additional columns which are only required for mezzanine."
      ;;
      ;; This sheet drew EVERY column as the same tube circle, so a full-height main frame column
      ;; and a stub that stops at the beam soffit were indistinguishable - and the count of NEW
      ;; steel is the whole point of the sheet.  Same convention the Column Layout Plan overlay
      ;; already uses (owner 10-Jul: "existing columns as-is; NEW columns encircled"), so the two
      ;; sheets now read the same way.
      ;;
      ;; A column is MAIN when its width station is one the main frame already stands on - x is
      ;; always a bay line here, so the width station is what decides.  peb-main-column-ys is the
      ;; same list the mezzanine stub placer uses to avoid doubling a column, so the two cannot
      ;; disagree about which columns are new.  With no main list we encircle nothing rather than
      ;; encircle everything: an unmarked sheet is recoverable, a wrongly marked one is not.
      (setq mainYs (vl-catch-all-apply (function (lambda () (peb-main-column-ys data wid)))))
      (if (vl-catch-all-error-p mainYs) (setq mainYs nil))
      (setq bubR2 (peb-mz-bubble-r colD) mzOnly nil)
      ;; OWNER 1-Sep-2026: "you have to only show the Additional Columns which are coming till the
      ;; Mezzanine, and those columns are to be circled with circle bubble to identify", and
      ;; "existing columns of main building columns will support Mezzanine Beams and Joists".
      ;;
      ;; So a station that lands on a PEB column IS that column: drawn once, at the COLUMN'S OWN
      ;; centre, and never bubbled.  Only a genuine extra stub is drawn at its own station and circled.
      ;;
      ;; WHY THIS USED TO FAIL - 250 mm could never recognise "same column".  The stub chain is walked
      ;; across the DECK BAND (inset 1000 mm from each wall) and rescaled to close on it, so its
      ;; stations drift off the frame grid: on MSPL-26-279 they sat 199-600 mm out, every one was
      ;; judged NEW, and a second column was drawn beside a full-height one and labelled MEZZANINE
      ;; ONLY - on the plan AND, with its own 5 mm test, in the section.
      ;;
      ;; The test is now PHYSICAL, not a constant: within half a column depth the stub stands INSIDE
      ;; the existing column, so it is the same column. Derived from the column the frame actually
      ;; carries, so it scales with the building instead of being a number that fits one span.
      (setq mzColTol (/ (peb-col-web-depth wid) 2.0) mzStations '())
      (foreach y ys
        (setq mzHit (if mainYs
                      (car (vl-remove-if-not
                             (function (lambda (m) (< (abs (- m y)) mzColTol))) mainYs))
                      nil))
        (setq mzRy (if mzHit mzHit y))
        ;; Two stub stations inside ONE column collapse to that column - never two I-sections in
        ;; the same place, which is the whole complaint this rule exists to answer.
        (if (not (vl-some (function (lambda (q) (< (abs (- (car q) mzRy)) 1.0))) mzStations))
          (setq mzStations (append mzStations (list (cons mzRy (if mzHit nil T)))))))
      (foreach x xs
        (foreach mzp mzStations
          (vl-catch-all-apply (function (lambda ()
            (draw-I-column-lengthwise x (car mzp))
            (if (cdr mzp)
              (progn
                (setq mzOnly T)
                (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-MEZZ")
                               (list 10 x (car mzp) 0.0) (cons 40 bubR2))))))))))
      ;; say what the circle MEANS, or it is just a decoration
      (if mzOnly
        (progn
          (peb-comp-layer "COMP-MEZZ" 6)
          (setvar "CLAYER" "COMP-MEZZ")
          (vl-catch-all-apply (function (lambda ()
            (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-MEZZ")
                           (list 10 (+ fx0 (* thS 0.7)) (- 0.0 (* thS 5.2)) 0.0) (cons 40 bubR2))))))
          (setvar "CLAYER" "TEXT")
          (vl-catch-all-apply (function (lambda ()
            (txt "ML" (list (+ fx0 (* thS 0.7) bubR2 (* thS 0.5)) (- 0.0 (* thS 5.2))) (peb-th 'SMALL) 0.0
                 "COLUMN REQUIRED FOR MEZZANINE ONLY (STOPS AT BEAM SOFFIT)"))))))))
  (setq *PEB-COL-WEB* savedWeb)

  ;; ======================================================================================
  ;;  THE SAME GRID, AND THE SAME CHAINS, AS THE COLUMN LAYOUT PLAN  (owner 3-Sep-2026)
  ;;
  ;;  "BSF showing out to out dimensions but mezzanine floor plan showing in to in of the
  ;;   columns - sync all the dim and bubbles grids."
  ;;
  ;;  Held side by side, the two sheets described ONE grid in two languages.
  ;;
  ;;    Column Layout Plan     A A' B B' C C' D D' E E' F        (eleven bubbles)
  ;;                           10@7620 O/O STEEL COLUMN
  ;;                           5@15240 O/O STEEL COLUMN
  ;;                           76,200 [250'-0"]
  ;;
  ;;    Mezzanine Floor Plan   A B C D E F                       (six bubbles)
  ;;                           15,240  15,240  15,240  15,240  15,240
  ;;                           76200 [250'-0"]
  ;;
  ;;  Every number on the mezzanine sheet was measured off ITS OWN drawn stations and printed
  ;;  bare.  Nowhere on it did the word O/O appear - so a reader holding the BSF, which states
  ;;  76,200 OUT TO OUT OF STEEL COLUMN, has no way to know whether the 15,240 in front of them
  ;;  is that same out-to-out module or a centre-to-centre or in-to-in distance the drawing
  ;;  happened to measure.  On a drawn grid whose end lines sit on the column CENTRES that
  ;;  difference is a real 700 mm a side, and it is the estimator's module that is quoted.
  ;;
  ;;  So this sheet stops speaking for itself and repeats what the BSF says:
  ;;    * the BUBBLES come off the MERGED building grid - width modules, end-wall posts and the
  ;;      mezzanine's own column lines, merged at 5 mm exactly as the CLP merges them.  A grid
  ;;      line is a grid line: 4B.8 is that the same line carries the same mark on every sheet,
  ;;      whether or not THIS sheet happens to draw a member on it.
  ;;    * the CHAINS are the estimator's own expressions with their BASIS spelled out - the
  ;;      same three strings the CLP prints, in the same order, so the two can be read against
  ;;      each other word for word.
  ;;    * the mezzanine's OWN column chain is drawn as a fourth, innermost rung ONLY when it
  ;;      differs from both of them.  On the 50 ft option it IS the module chain and on the
  ;;      25 ft option it IS the post chain, so it is not repeated in either.
  ;;    * and the LENGTH is dimensioned at all, which it never was: the sheet carried bay
  ;;      bubbles 1..8 over a building whose length it never stated.
  ;; ======================================================================================
  (setq gbr (peb-bub-r))          ; 4B.31 - one radius for every sheet; the chains measure off it
  ;; Both chains are written OUT TO OUT, so both start at 0 and end at wid - the same
  ;; straddle peb-mezz-snap-ends corrects on the mezzanine's own stations.  They are snapped
  ;; here too, BEFORE the merge: leave one list on 0 and another on 700 and the 5 mm merge
  ;; keeps them apart, which prints two bubbles a hair's breadth apart both lettered A.
  ;; TWO lists of the same chain, and they are not interchangeable.
  ;;   *OO  - as the BSF writes it, 0 .. wid, out to out.  This is what the chain TEXT is
  ;;          checked against: peb-chain-text prints the estimator's expression verbatim only
  ;;          while that expression still FITS the stations it is handed.  Hand it the snapped
  ;;          list and "5@15240" stops fitting, so it silently falls back to measuring the gaps
  ;;          and prints "1@14540 + 3@15240 + 1@14540" - the centre-to-centre chain, which is
  ;;          precisely the in-to-in number the owner rejected.
  ;;   snapped - where the STEEL is, ends pulled back to the column centrelines.  This is what
  ;;          the bubbles and the members are placed on.
  (setq wModsOO (peb-width-mods data wid))
  (setq ewStOO  (peb-mzfp-stations (MSPL-Get-Str data "EWLEXPR") wid))
  (setq wMods (peb-mezz-snap-ends wModsOO wid))
  (setq ewSt  (peb-mezz-snap-ends ewStOO  wid))
  ;; the merged grid, clipped to the deck - a bubble on a line the deck never reaches labels nothing
  (setq gYs (peb-merge-ys (append (if wMods wMods '()) (if ewSt ewSt '()) ys) 5.0))
  (setq gYs (vl-remove-if (function (lambda (v) (or (< v (- fy0 1.0)) (> v (+ fy1 1.0))))) gYs))
  (if (< (length gYs) 2) (setq gYs ys))

  ;; ---- the chain STRINGS, straight from the BSF ----------------------------------------
  (setq sufW (peb-basis-suffix (peb-tb-or (MSPL-Get-Str data "WIDTH_MOD_REF")
                                          (MSPL-Get-Str data "WIDTH_REF"))))
  (setq chainMod (if wModsOO
                   (strcat (peb-chain-text (MSPL-Get-Str data "MODEXPR") wModsOO) " " sufW)))
  (setq chainEW  (if (and ewStOO (> (length ewStOO) 2))
                   (strcat (peb-chain-text (MSPL-Get-Str data "EWLEXPR") ewStOO) " " sufW)))

  ;; ---- the width stack, outside the deck's left edge, innermost first -------------------
  ;; PLACEMENT (owner 3-Sep-2026: "dimensions placement should be as per the established rules").
  ;; The order was already right - finest chain nearest the drawing, the OVERALL furthest out, per
  ;; the 4-Jul three-nested-chains rule - but the whole stack sat OUTSIDE the grid bubbles, which
  ;; is the opposite of the Column Layout Plan.  On the CLP a reader goes: drawing, chains, bubbles.
  ;; Here they went: drawing, bubbles, chains, so the bubbles were buried mid-annotation and the
  ;; two sheets read outward in different orders.
  ;;
  ;; So the rungs march out from the deck edge and the BUBBLE COLUMN is placed from wherever the
  ;; outermost rung finished - not from a constant (4B.27).  Add a rung and the bubbles move with
  ;; it; that is the whole point of measuring the gap from the thing it has to clear.
  (setq rungX (- fx0 (* gbr 1.6)))
  (if (and (> (length gYs) 1) (boundp 'peb-fr-overall-v))
    (progn
      ;; (a) the mezzanine's OWN chain - and only when it is not already one of the two below.
      ;; It prints MZ_COL_SPACING verbatim with its basis, like every other chain on the sheet.
      ;; Measuring the DRAWN gaps instead would print 14,540 at each end - the centre-to-centre
      ;; distance - against a BSF that says 15,240 out to out.  That is the in-to-in / out-to-out
      ;; split the owner caught, and it is why no chain on this sheet is measured any more.
      (if (and (> (length ys) 1)
               (not (peb-ys-same ys wMods 5.0)) (not (peb-ys-same ys ewSt 5.0)))
        (progn
          (vl-catch-all-apply (function (lambda ()
            (peb-fr-overall-v rungX 0.0 wid
              (strcat (peb-chain-text (peb-tb-or (MSPL-Get-Str data "MZ_COL_SPACING") "")
                                      (peb-width-stations
                                        (peb-tb-or (MSPL-Get-Str data "MZ_COL_SPACING") "") wid))
                      " " sufW)))))
          (setq rungX (- rungX (* gbr 2.6)))))
      ;; (b) the end-wall / post chain, verbatim
      (if chainEW
        (progn
          (vl-catch-all-apply (function (lambda ()
            (peb-fr-overall-v rungX 0.0 wid chainEW))))
          (setq rungX (- rungX (* gbr 2.6)))))
      ;; (c) the width MODULE chain, verbatim
      (if chainMod
        (progn
          (vl-catch-all-apply (function (lambda ()
            (peb-fr-overall-v rungX 0.0 wid chainMod))))
          (setq rungX (- rungX (* gbr 2.6)))))
      ;; (d) the OVERALL - the BSF's width, with its feet (4B.11)
      (vl-catch-all-apply (function (lambda ()
        (peb-fr-overall-v rungX 0.0 wid (peb-fmt-overall wid)))))
      (setq rungX (- rungX (* gbr 2.6)))))       ; clear of the overall's own rotated label

  ;; ---- the LENGTH chains, in the same order the CLP reads outward in -------------------
  ;; drawing -> bay chain -> overall -> bubbles.  The bay expression carries its basis and the
  ;; overall carries its feet; this sheet used to bubble 1..8 over a building whose length it
  ;; never stated at all.
  (setq rungY (+ fy1 (* gbr 1.6)))
  (if (boundp 'peb-fr-overall-h)
    (progn
      (setq sufL (peb-basis-suffix (peb-tb-or (MSPL-Get-Str data "LENGTH_REF")
                                              (MSPL-Get-Str data "BAY_REF"))))
      (vl-catch-all-apply (function (lambda ()
        (peb-fr-overall-h (if (< (abs fx0) 1.0) 0.0 fx0) (if (< (abs (- fx1 len)) 1.0) len fx1) rungY
                          (strcat (peb-chain-text (MSPL-Get-Str data "BAYEXPR") bayPts) " " sufL)))))
      (setq rungY (+ rungY (* gbr 2.6)))
      (vl-catch-all-apply (function (lambda ()
        (peb-fr-overall-h 0.0 len rungY (peb-fmt-overall len)))))
      (setq rungY (+ rungY (* gbr 2.6)))))       ; clear of the overall's own label

  ;; grid bubbles - bay NUMBERS along the top, width LETTERS down the left (A at the top),
  ;; both OUTSIDE their dimension stack, which is where the Column Layout Plan puts them.
  (setq i 0)
  (foreach x bayPts
    (if (and (>= x (- fx0 1.0)) (<= x (+ fx1 1.0)))
      (progn (setvar "CLAYER" "GRID-LINES")
             ;; A TICK, NOT A LINE BACK TO THE DRAWING.  With the chains now between the plan
             ;; and the bubbles, a stalk drawn all the way to the deck edge rules straight
             ;; through every chain bar and every chain label on its way.  The bubble points
             ;; at its line; the line is already drawn on the plan.
             (entmake (list (cons 0 "LINE") (cons 8 "GRID-LINES")
                            (list 10 x rungY 0.0) (list 11 x (- rungY (* gbr 0.9)) 0.0)))
             (setvar "CLAYER" "GRID")
             (grid-bubble x (+ rungY (* gbr 1.5)) (itoa (1+ i)) "D")))
    (setq i (1+ i)))

  ;; the LETTERS, on the merged grid
  (foreach y (reverse gYs)
    (setvar "CLAYER" "GRID-LINES")
    (entmake (list (cons 0 "LINE") (cons 8 "GRID-LINES")
                   (list 10 rungX y 0.0) (list 11 (+ rungX (* gbr 0.9)) y 0.0)))
    (setvar "CLAYER" "GRID")
    (grid-bubble (- rungX (* gbr 1.5)) y (peb-width-mark y gYs wMods) "R"))

  ;; deck spec note (what the floor IS).  The members are distinguished by their flange width + BYLAYER
  ;; line-weight ("material" = line thickness, owner 12-Jul) and are NAMED on the plan (MAIN BEAM / JOISTS
  ;; / SECONDARY JOISTS); no steel-section text and no mezzanine column SIZE are shown here.
  ;; -- RULE 4B.7 - THE NOTE QUOTES THE BSF, NOT A CONSTANT (owner 29-Aug) -------------
  ;; This note read "100mm CONCRETE SLAB" on every drawing ever produced, hard-coded, while
  ;; MZ<n>_FLOOR_THK on this job says 125 and the CROSS SECTION - built from the same field -
  ;; correctly printed "125MM R.C. SLAB".  Two sheets in one set, contradicting each other on
  ;; the thickness of the same slab.  Read the field.
  (setq mzThk (MSPL-Get-Num data (strcat "MZ" (itoa floorNum) "_FLOOR_THK")))
  (if (or (null mzThk) (<= mzThk 0.0)) (setq mzThk (MSPL-Get-Num data "MZ1_FLOOR_THK")))
  (if (or (null mzThk) (<= mzThk 0.0)) (setq mzThk 150.0))
  (setq specStr (cond ((wcmatch floorSys "*PRECAST*,*HOLLOW*")    "PRECAST / HOLLOW-CORE SLAB (BY OTHERS)")
                      ((wcmatch floorSys "*GRAT*,*CHEQ*,*PLATE*") "STEEL GRATING / CHEQUERED PLATE ON JOISTS")
                      (T  (strcat "0.7mm DECKING PANEL + " (rtos mzThk 2 0) "mm CONCRETE SLAB"))))
  (setvar "CLAYER" "TEXT")
  (vl-catch-all-apply (function (lambda ()
    (txt "MC" (list (/ (+ fx0 fx1) 2.0) (- 0.0 (* thS 7.0))) (peb-th 'SMALL) 0.0 specStr))))

  ;; blue floor TITLE + LEVEL tag below the plan.
  ;; BUGFIX (owner note): txt-bold already multiplies by *PEB-TEXT-SCALE*, so pass (/ H sc) — the old
  ;; (* 450 sc) rendered the title at H*sc^2, which blew up on large buildings.
  ;; -- RULE 4B.7 - THE TAG NAMES THE LEVEL IT IS QUOTING (owner 29-Aug) ---------------
  ;; This printed "(LEVEL approx. +5,791 MM, BOTTOM OF BEAM)".  5,791 is MZ_FLOOR_HT, the
  ;; floor-to-floor height, which the BSF also states as MZ1_CH_FFL_SLAB - the mezzanine
  ;; F.F.L.  The bottom of the beam is MZ1_CH_FFL_BEAM = 4,877.  So the sheet put the right
  ;; number under the wrong name, 914 mm out, and disagreed with the cross section's own
  ;; F.F.L MEZZANINE mark.  Quote the stated F.F.L and call it the F.F.L.
  (setq fflLvl (MSPL-Get-Num data (strcat "MZ" (itoa floorNum) "_CH_FFL_SLAB")))
  (if (or (null fflLvl) (<= fflLvl 0.0))
    (progn (setq lvl (MSPL-Get-Num data "MZ_FLOOR_HT"))
           (if (null lvl) (setq lvl 0.0))
           (setq fflLvl (* lvl floorNum))))
  (setq lvlStr (if (> fflLvl 0.0)
                 (strcat "  (F.F.L approx. +" (peb-comma (rtos fflLvl 2 0)) " MM)")
                 ""))
  (setvar "CLAYER" "TEXT") (setvar "CECOLOR" "5")
  (txt-bold "MC" (list (/ (+ fx0 fx1) 2.0) (- 0.0 (* thS 8.7))) (peb-th 'ANNOT) 0
            (strcat "MEZZANINE FLOOR-" (itoa floorNum) " LAYOUT PLAN" lvlStr))
  (setvar "CECOLOR" "BYLAYER")

  ;; ---- THE STAIRCASES AND THEIR OPENINGS  (owner 1-Sep-2026) -----------------------------
  ;; "Mark the opening in the Mezzanine Floor Plan and Show the Staircase there" ... "make the
  ;;  opening as per the length and width of staircase and show the staircase".
  ;;
  ;; Drawn LAST, deliberately: the deck, voids, joists, columns, grid and caption above are the
  ;; existing sheet and the owner was explicit that none of it changes.  Everything below only
  ;; ADDS on top, so a failure here cannot damage the floor plan - and the whole block is
  ;; wrapped so it cannot take the sheet down either.
  (vl-catch-all-apply
    (function (lambda () (peb-mzfp-stairs data fx0 fx1 fy0 fy1))))
  (princ))

;; ---- A MEMBER STOPS AT THE OPENING - IT IS NOT DELETED, AND IT DOES NOT CROSS -----------
;; Owner, 3-Sep-2026, in two passes on the same sheet:
;;   "main beam should not be removed along GR. 2 & 7"   then   "Beams Must break at the point
;;   of staircase".
;; Both at once, and they are one rule: the member RUNS THE WHOLE GRID LINE and is BROKEN over
;; the stairwell.  The first cut of this asked a yes/no question - does this member touch a void
;; - and threw the whole member away on a yes.  So a main beam that clipped the corner of a stair
;; vanished from column to column, and grids 2 and 7 on 279-26 lost their beam over 76 m because
;; a 6.6 m stair stood on them.  A floor plan that deletes a primary member is not a drawing of a
;; floor that can stand.
;;
;; This is now measured instead of judged: the blocked runs are subtracted from the member's
;; span and what is left is drawn.  Every member on the sheet goes through it - main beams,
;; joists, secondaries - so the whole deck reads one way: nothing crosses the hole, and nothing
;; disappears because of it.

;; The runs of `voids` that block an axis-aligned member, as (lo hi) pairs along its own axis.
(defun peb-mezz-void-blocks (x0 y0 x1 y1 voids / blocks vx0 vx1 vy0 vy1 horiz)
  (setq horiz (equal y0 y1 0.1) blocks nil)
  (foreach v voids
    (setq vx0 (min (nth 0 v) (nth 1 v)) vx1 (max (nth 0 v) (nth 1 v))
          vy0 (min (nth 2 v) (nth 3 v)) vy1 (max (nth 2 v) (nth 3 v)))
    (if horiz
      (if (and (> y0 vy0) (< y0 vy1))
        (setq blocks (append blocks (list (list vx0 vx1)))))
      (if (and (> x0 vx0) (< x0 vx1))
        (setq blocks (append blocks (list (list vy0 vy1)))))))
  blocks)

;; [lo hi] minus the blocked runs -> the clear runs.  Overlapping blocks are merged by the walk,
;; and a leftover shorter than a millimetre is dropped rather than drawn as a stub.
(defun peb-span-subtract (lo hi blocks / sorted cur out b)
  (setq sorted (vl-sort blocks (function (lambda (p q) (< (car p) (car q)))))
        cur lo out nil)
  (foreach b sorted
    (if (> (car b) cur) (setq out (append out (list (list cur (min hi (car b)))))))
    (if (> (cadr b) cur) (setq cur (cadr b))))
  (if (< cur hi) (setq out (append out (list (list cur hi)))))
  (vl-remove-if (function (lambda (r) (<= (- (cadr r) (car r)) 1.0))) out))

;; Draw one member, broken over every void it runs through.
(defun peb-mezz-member-broken (x0 y0 x1 y1 half voids / horiz lo hi blocks)
  (setq horiz  (equal y0 y1 0.1)
        lo     (if horiz (min x0 x1) (min y0 y1))
        hi     (if horiz (max x0 x1) (max y0 y1))
        blocks (peb-mezz-void-blocks x0 y0 x1 y1 voids))
  (if (null blocks)
    (vl-catch-all-apply (function (lambda () (peb-mezz-mainbeam x0 y0 x1 y1 half))))
    (foreach r (peb-span-subtract lo hi blocks)
      (vl-catch-all-apply
        (function (lambda ()
          (if horiz
            (peb-mezz-mainbeam (car r) y0 (cadr r) y0 half)
            (peb-mezz-mainbeam x0 (car r) x0 (cadr r) half)))))))
  (princ))

;; (The predecessor of these three, peb-line-intersects-void, is gone.  It answered only
;; "does this member touch a void" - which is why a member that clipped a stair was deleted
;; whole - and it was written in Common Lisp: `catch`, `throw` and `let`, none of which exist
;; in AutoLISP.  The first joist that asked it raised "no function definition: CATCH" and took
;; the rest of peb-draw-mezz-floor-plan with it, so the sheet plotted its deck outline and
;; nothing else.  Both faults are answered above: the question is now "which part is blocked",
;; and the answer is written in the AutoLISP the rest of this file is written in.)

;; ---- ONE PLACE DECIDES WHERE A STAIRCASE STANDS ------------------------------------------
;; Both passes below - the void pass that clears the joists and the draw pass that puts the
;; stair on the sheet - MUST agree to the millimetre, or the deck opens a hole in one place
;; and the stair rises through another.  So neither of them works the position out: they both
;; ask this, and it answers once.
;;
;; Returns (ox oy wdt hgt topl midl trd pfl shp) for ST<n>, or nil when that stair is not on.
;;
;; -- THE OFFSET IS MEASURED FROM THE BUILDING CORNER, NOT FROM THE DECK --------------------
;; The BSF asks for "Position X - Distance from LEW" and "Position Y - Distance from NSW", and
;; this sheet already draws in exactly those coordinates: its own voids start at 0,0, and 0,0
;; IS the LEW/NSW junction.  Both passes used to add fx0/fy0 and so measured the stair from the
;; corner of the mezzanine DECK instead - the form and the drawing disagreeing in silence,
;; which is the one thing the single-truth rule forbids.  On 279-26 the deck is inset 1,000
;; from the NSW, so every stair drew 1,000 off its stated position; on a mezzanine that starts
;; at grid 3 it would be a whole bay out.
(defun peb-mzfp-stair-org (data tag fx0 fx1 fy0 fy1 /
                           wdt hgt typ topl midl trd pfl shp offX offY ox oy dep runX)
  (if (/= (strcase (MSPL-Get-Str data (strcat tag "TOGGLE"))) "YES")
    nil
    (progn
      (setq wdt  (MSPL-Get-Num data (strcat tag "WIDTH"))
            hgt  (MSPL-Get-Num data (strcat tag "HEIGHT"))
            typ  (MSPL-Get-Str data (strcat tag "TYPE"))
            topl (/= nil (wcmatch (strcase (MSPL-Get-Str data (strcat tag "TOP_LANDING"))) "Y*,1"))
            midl (/= nil (wcmatch (strcase (MSPL-Get-Str data (strcat tag "MID_LANDING"))) "Y*,1"))
            trd  (MSPL-Get-Str data (strcat tag "TREAD"))
            pfl  (MSPL-Get-Str data (strcat tag "PLAT_FLOOR"))
            offX (MSPL-Get-Num data (strcat tag "OFFSET_X"))
            offY (MSPL-Get-Num data (strcat tag "OFFSET_Y")))
      (if (or (null wdt)  (<= wdt 0.0))  (setq wdt 1200.0))
      (if (or (null hgt)  (<= hgt 0.0))  (setq hgt 3000.0))
      (if (or (null offX) (< offX 0.0))  (setq offX 0.0))
      (if (or (null offY) (<= offY 0.0)) (setq offY 6000.0))
      (setq shp (peb-stair-shape typ midl)
            ox  offX
            oy  offY)
      ;; -- AND IT STAYS ON THE DECK IT SERVES ----------------------------------------------
      ;; dep is the stairwell out-to-out ACROSS the flights (two bands + the stringer well) and
      ;; oy is its CENTRE line; runX is what the stair needs ALONG the deck - flight 1 plus the
      ;; landing at its head.  Both come from the same functions the stair drawer itself uses,
      ;; so the clamp can never disagree with what gets drawn.  A stair hanging off the slab is
      ;; not a placement, it is a mistake nobody can build - so a stated position that will not
      ;; fit is pulled back onto the deck rather than drawn into thin air.
      (setq dep  (+ wdt wdt (peb-stair-well wdt))
            runX (+ (* (peb-stair-going) (car (peb-stair-flights hgt)))
                    (peb-stair-landing-w wdt)))
      (if (> (- fy1 fy0) dep)
        (setq oy (max (+ fy0 (/ dep 2.0)) (min oy (- fy1 (/ dep 2.0))))))
      (if (> (- fx1 fx0) runX)
        (setq ox (max fx0 (min ox (- fx1 runX)))))
      (list ox oy wdt hgt topl midl trd pfl shp))))

;; Draw ST<n> from an org list and hand back the footprint the drawer itself reports.
;;
;; *PEB-STAIR-PLAIN* stands the stair's OWN dimensions, leaders and "PLAN" caption down for the
;; duration - see peb-stair-plain-p in MAIMAAR_PEB_Stair.lsp.  They are sized off the stair
;; (100 mm on a 1,200 wide one) and this sheet is a 55 m building on an A4 page, so they plotted
;; at about a sixth of the ladder's smallest rung: an unreadable smudge lying across the deck.
;; The stairwell, treads, landing and climb arrow stay - they are what this sheet is showing -
;; and the numbers stay on the staircase sheet, which is drawn at a scale that can hold them.
(defun peb-mzfp-stair-draw (org / ox oy wdt hgt topl midl trd pfl shp ext prev)
  (setq ox (nth 0 org) oy (nth 1 org) wdt (nth 2 org) hgt (nth 3 org)
        topl (nth 4 org) midl (nth 5 org) trd (nth 6 org) pfl (nth 7 org) shp (nth 8 org))
  (setq prev (if (boundp '*PEB-STAIR-PLAIN*) *PEB-STAIR-PLAIN* nil)
        *PEB-STAIR-PLAIN* T)
  ;; Caught HERE, not by the caller: the flag is global and the whole page set runs in ONE
  ;; acad, so a drawer that threw on its way out would leave every later staircase sheet
  ;; silenced - a sheet losing its dimensions because a different sheet failed.
  (setq ext (vl-catch-all-apply
              (function (lambda ()
                (cond ((= shp "U") (peb-stair-plan-u ox oy wdt hgt topl midl nil trd pfl))
                      ((= shp "L") (peb-stair-plan-l ox oy wdt hgt topl midl nil trd pfl))
                      (T           (peb-stair-plan   ox oy wdt hgt topl midl nil trd pfl)))))))
  (setq *PEB-STAIR-PLAIN* prev)
  (if (vl-catch-all-error-p ext) (setq ext nil))
  ext)

;; Erase every entity made after `mark` (nil = since the drawing was empty).
(defun peb-erase-after (mark / e nx)
  (setq e (if mark (entnext mark) (entnext)))
  (while e
    (setq nx (entnext e))
    (vl-catch-all-apply (function (lambda () (entdel e))))
    (setq e nx))
  (princ))

;; ---- the staircase VOIDS, measured before a single joist is drawn ------------------------
;; The joists, the secondaries and the main beams must stop at the stairwell (owner: remove
;; joists & beams in the staircase void), and they are drawn long before the stair is - so the
;; hole has to be known first.
;;
;; It is MEASURED, not calculated.  The shape drawers report their own footprint, so this pass
;; draws each stair, keeps what it reports, and ERASES it again - leaving the sheet exactly as
;; it found it.  Calculating the footprint a second time here would be a second opinion about
;; the same geometry, and the two would drift apart the first time a drawer changed.
;;
;; (The first version skipped the erase, which is why the crashed sheet still had staircases on
;;  it: those were this pass's throwaway copies, left behind.)
(defun peb-stair-voids (data fx0 fx1 fy0 fy1 / i tag org ext voids mark)
  (setq voids nil i 1)
  (if (= (strcase (MSPL-Get-Str data "ST_TOGGLE")) "YES")
    (while (<= i 4)
      (setq tag (strcat "ST" (itoa i) "_")
            org (peb-mzfp-stair-org data tag fx0 fx1 fy0 fy1))
      (if org
        (progn
          (setq mark (entlast) ext nil)
          (vl-catch-all-apply (function (lambda () (setq ext (peb-mzfp-stair-draw org)))))
          (vl-catch-all-apply (function (lambda () (peb-erase-after mark))))
          (if ext (setq voids (append voids (list ext))))))
      (setq i (1+ i))))
  voids)

;; ---- the staircases on the mezzanine floor plan ------------------------------------------
;; THE OPENING IS SIZED TO THE STAIR, not to a nominal hole.  The shape drawers on the stair
;; sheet return their own footprint as (x0 x1 y0 y1), so the opening is cut from the same
;; numbers that draw the stair - a U's run plus landing by the depth of both flights and the
;; well.  Anything else would show a staircase rising through a deck it would actually hit.
;;
;; The stair itself is drawn by those SAME drawers, so this sheet and the detail sheet cannot
;; disagree about what the staircase looks like.
;;
;; COORDINATE SYSTEM: origin at the LEW / NSW junction = 0,0, per peb-mzfp-stair-org above.
(defun peb-mzfp-stairs (data fx0 fx1 fy0 fy1 / i tag org ext th)
  (if (= (strcase (MSPL-Get-Str data "ST_TOGGLE")) "YES")
    (progn
      (setq th (peb-th 'SMALL) i 1)
      (while (<= i 4)
        (setq tag (strcat "ST" (itoa i) "_")
              org (peb-mzfp-stair-org data tag fx0 fx1 fy0 fy1))
        (if org
          (vl-catch-all-apply
            (function
              (lambda ()
                (setq ext (peb-mzfp-stair-draw org))
                ;; THE OPENING, cut to exactly the footprint the stair just reported.
                (if ext
                  (progn
                    (peb-comp-layer "COMP-MEZZ-OPENING" 8)
                    (peb-comp-poly (list (list (nth 0 ext) (nth 2 ext))
                                         (list (nth 1 ext) (nth 2 ext))
                                         (list (nth 1 ext) (nth 3 ext))
                                         (list (nth 0 ext) (nth 3 ext))))
                    (setvar "CLAYER" "COMP-MEZZ-OPENING")
                    (txt-bold "MC" (list (/ (+ (nth 0 ext) (nth 1 ext)) 2.0)
                                         (- (nth 2 ext) (* th 1.6)))
                              th 0.0 (strcat "OPENING - ST" (itoa i)))))
                (princ)))))
        (setq i (1+ i)))))
  (setvar "CLAYER" "0")
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
      (setq *PEB-BUB-FIT* (peb-bub-fit "MEZZ-PLAN"))
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
