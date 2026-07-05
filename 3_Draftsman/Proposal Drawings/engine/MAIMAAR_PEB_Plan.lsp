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
    ("FLAT ROOF" . "FR") ("ROOF ON RCC COLUMNS" . "RC")
    ("ARCHED CLEAR SPAN" . "ACS") ("ARCHED MULTI-SPAN" . "AMS")
    ("ARCHED MULTI SPAN" . "AMS") ("BUTTERFLY" . "BF")
    ("CANTILEVER CANOPY" . "CC")))

(defun peb-frame-display-to-code (s / up pair)
  (setq up (strcase (vl-string-trim " " s)))
  (cond ((member up '("CS" "SS" "MS" "LT" "MG" "FR" "RC" "ACS" "AMS" "BF" "CC")) up)
        (T (setq pair (assoc up *PEB-FRAME-CODE-MAP*))
           (if pair (cdr pair) "CS"))))

(defun peb-slope-to-denom (slopeStr customStr / s pos)
  (setq s (vl-string-trim " " slopeStr))
  (if (or (= (strcase s) "OTHER (SPECIFY)") (= s ""))
    (setq s (vl-string-trim " " customStr)))
  (setq pos (vl-string-search ":" s))
  (if pos (vl-string-trim " " (substr s (+ pos 2))) s))

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

(defun peb-build-sheeting-string (data prefix / typ outProf outMat pirThk pirDens innerMat)
  (setq typ      (peb-alist-get data (strcat "PN_" prefix "_TYPE")))
  (setq outProf  (peb-alist-get data (strcat "PN_" prefix "_OUTER_PROFILE")))
  (setq outMat   (peb-alist-get data (strcat "PN_" prefix "_OUTER_MAT")))
  (setq pirThk   (peb-alist-get data (strcat "PN_" prefix "_PIR_THK")))
  (setq pirDens  (peb-alist-get data (strcat "PN_" prefix "_PIR_DENS")))
  (setq innerMat (peb-alist-get data (strcat "PN_" prefix "_INNER_MAT")))
  (cond
    ((or (= (strcase typ) "SANDWICH PANEL") (= (strcase typ) "SANDWICH"))
      ;; Clean two-line label "<PREFIX> SHEETING:" / "<thk>MM PIR SANDWICH PANEL".
      ;; NOTE: the spec MUST contain a digit (the thickness) so split-at-first-digit
      ;; produces a non-nil suffix and the section label takes the tested two-line
      ;; branch; a digit-less spec routes to a (command)-based fallback that hangs
      ;; in batch. Default thickness to 50mm when the IF leaves it blank.
      (strcat prefix " SHEETING  "
              (if (= pirThk "") "50" pirThk) "MM PIR SANDWICH PANEL"))
    ((or (= (strcase typ) "SINGLE SKIN") (= typ ""))
      (strcat prefix " SHEETING:  " outMat
              (if (/= outProf "") (strcat " - " outProf) "")))
    (T (strcat prefix " SHEETING:  " outMat))))

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
  (setq brick (peb-alist-get v3 "BP_BRICK_HT"))
  (if (= brick "") (setq brick "0"))
  (setq out (cons (cons "BRICKHEIGHT" brick) out))
  (setq modExpr (peb-alist-get v3 "BP_WIDTH_MOD"))
  (setq modList (peb-parse-mod-expression modExpr))
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

(defun txt-bold (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if str (setq str (strcase str)))
  (setvar "TEXTSTYLE" "PEB-TITLE")
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
)

(defun txt-dim (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if str (setq str (strcase str)))
  (setvar "TEXTSTYLE" "PEB-DIM")
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
)

(defun grid-bubble (x y label / r h prev)
  ;; Clean single circle (GRID layer) with a centred GRID-TEXT label — the
  ;; Mammut grid-bubble look.  Caller places (x,y) clear outside the building so
  ;; the bubble never overlaps a column; the grid line stops at the bubble.
  ;; RULE G2: text AUTO-FITS inside the circle — sized by label length so a
  ;; single digit fills the bubble and 2-3 chars still sit clean inside it.
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setq r (if *PEB-BUBRAD* *PEB-BUBRAD* (* 620 *PEB-TEXT-SCALE*)) prev (getvar "CLAYER"))  ; RULE: flexible bubble radius (clamped so bubbles never touch); text auto-fits to r
  (setq h (* r (cond ((<= (strlen label) 1) 0.95)   ; 1 char  -> fills the circle
                     ((= (strlen label) 2) 0.66)    ; 2 chars -> fit
                     (T 0.48))))                    ; 3+ chars -> fit
  (setvar "CLAYER" "GRID")
  (command "_.CIRCLE" (list x y) r)
  (setvar "CLAYER" "GRID-TEXT")
  (setvar "TEXTSTYLE" "PEB-TITLE")
  (command "_.TEXT" "_J" "_MC" (list x y) h 0 label)
  (setvar "CLAYER" prev))

(defun col-crosshair (x y / arm)
  (setq arm 280)
  (setvar "CLAYER" "COL-CENTER")
  (command "LINE" (list (- x arm) y) (list (+ x arm) y) "")
  (command "LINE" (list x (- y arm)) (list x (+ y arm)) "")
)

;; RIDGE-LINE callout = Roshan curl/hook "ladder" symbol (owner 3-Jul): a small LOOP sitting ON the
;; ridge line + a short leader up to the "RIDGE LINE" text (no arrowhead).  This curl is the SOLE ridge
;; marker; the ridge LINE itself stays a dotted/broken line (RIDGE layer).  Matches the symbol Nasir
;; inserted from MAMMUT_09_Roshan.  tgtX,tgtY = point on the ridge line.
(defun peb-ridge-callout (txtStr tgtX tgtY / s r cx cy prev)
  (setq s (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0) r (* 300.0 s)
        cx tgtX cy tgtY prev (getvar "CLAYER"))
  (setvar "CLAYER" "TEXT")
  (command "_.CIRCLE" (list cx cy) r)                                             ; the curl loop ON the ridge
  (command "_.LINE" (list (+ cx (* 0.7 r)) (+ cy (* 0.7 r)))
                    (list (+ cx (* 5.0 r)) (+ cy (* 5.0 r))) "")                  ; short leader up-right (no arrow)
  (txt "ML" (list (+ cx (* 5.4 r)) (+ cy (* 5.0 r))) (peb-th 'ANNOT) 0 txtStr)   ; "RIDGE LINE" label (engine text)
  (setvar "CLAYER" prev))

;; RIDGE-LINE LADDER — owner rule F5 (3-Jul, from MAMMUT_09_Roshan): the ridge line is marked with a
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

;; RIDGE-LINE SYMBOL — reproduced EXACTLY from the Roshan Packages reference (MAMMUT_09 DXF, owner 4-Jul):
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
  (setvar "CLAYER" "BOLTS")      ; 4 bolts = circle + cross
  (foreach p (list (list (- x bx) (- y by)) (list (+ x bx) (- y by))
                   (list (- x bx) (+ y by)) (list (+ x bx) (+ y by)))
    (command "_.CIRCLE" p br)
    (command "_.LINE" (list (- (car p) br) (cadr p)) (list (+ (car p) br) (cadr p)) "")
    (command "_.LINE" (list (car p) (- (cadr p) br)) (list (car p) (+ (cadr p) br)) ""))
  (setvar "CLAYER" prevLayer)
)

;; Braced-bay selection — port of geometryRules bracingPlan: never brace the END
;; bays; brace the 2nd and 2nd-last bay; add interior braces so no unbraced run
;; exceeds 27 m. Returns 0-based bay indices. bayPts = grid x-stations (len+1 pts).
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
      (txt "MC" (list cx (+ yy (* inward (+ d (* 420 *PEB-TEXT-SCALE*))))) 190.0 0
           (strcat (if m m "") " PORTAL"))
      T)
    ;; PORTAL (full-height goal-post) → plan symbol: cyan half-thick BEAM line on the web centre +
    ;; "PORTAL-FULL" label (owner 4-Jul). The goal-post ELEVATION (2 verticals + haunched beam) → Section.
    ((wcmatch bt "*PORTAL*")
      (setvar "CLAYER" "CROSS")
      (command "_.PLINE" (list xa yy) "_W" (* 60.0 *PEB-DIM-SCALE*) (* 60.0 *PEB-DIM-SCALE*) (list xb yy) "")
      (setvar "PLINEWID" 0.0)
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list cx (+ yy (* inward (+ d (* 420 *PEB-TEXT-SCALE*))))) 190.0 0 "PORTAL-FULL")
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
        (txt-bold "MC" (list cx ymid) 320.0 90 "BRACED BAY")
        (if first
          (progn
            (setq first nil)
            ;; owner 4-Jul: SMALLER "CROSS BRACING (TYP.)" (was 260*scale which txt re-scaled -> huge) +
            ;; a leader ARROW that TOUCHES the NSW bracing bowtie.
            (setvar "CLAYER" "TEXT")
            (txt "MC" (list cx (- oy (* 900.0 *PEB-TEXT-SCALE*))) 340.0 0 "CROSS BRACING (TYP.)")
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
      (txt "MC" (list px (- py (* inSign 600 *PEB-TEXT-SCALE*))) 280.0 0 mark)
      (txt "MC" (list (- px (* inSign 600 *PEB-TEXT-SCALE*)) py) 280.0 0 mark))
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

(defun peb-fmt-value (value / mode)
  ;;  Format a single mm value per *PEB-DIM-DISPLAY* mode.
  ;;    "MM"   → "40000"
  ;;    "MMFT" → "40000 [131'-3\"]"
  ;;    "FT"   → "131'-3\""
  (setq mode (if *PEB-DIM-DISPLAY* *PEB-DIM-DISPLAY* "MM"))
  (cond
    ((= mode "MMFT") (strcat (rtos value 2 0) " [" (peb-mm-to-ft-in value) "]"))
    ((= mode "FT")   (peb-mm-to-ft-in value))
    (T               (rtos value 2 0))))

(defun peb-fmt-labelled (prefix value suffix / mode)
  ;;  Format a labelled dim like "BUILDING LENGTH : 40000 OUT TO OUT OF STEEL"
  ;;  per *PEB-DIM-DISPLAY* mode.  Inserts the value (mm / mm-and-ft / ft)
  ;;  between the prefix and suffix strings.
  (strcat prefix " : " (peb-fmt-value value)
          (if (and suffix (/= suffix ""))
            (strcat " " suffix)
            "")))

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
    ((wcmatch u "*CENTER TO CENTER*,*CENTRE TO CENTRE*,*C/C*")
       (list (- gridVal (* 2.0 hw)) hw (- hw) dc (- dc)))                   ; witness on drawn web centre
    ((wcmatch u "*KNEE*")
       (setq d (peb-haunch-web-depth gridVal))
       (list (- gridVal (* 2.0 d)) d (- d) (* 2.0 dc) (* -2.0 dc)))         ; witness on drawn inner face
    ((wcmatch u "*BASE*")
       (list (- gridVal (* 2.0 fw)) fw (- fw) (* 2.0 dc) (* -2.0 dc)))      ; witness on drawn inner face
    ((wcmatch u "*SHEET*,*BRICK*,*MASON*,*GIRT*")
       (list (+ gridVal (* 2.0 brick)) (- brick) brick 0.0 0.0))           ; witness on drawn outer face
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

;; Inner-chain label = MIRROR the IF spacing expression verbatim (owner 4-Jul: "dimensions must be a
;; mirror of the IF, the way it is presented in the IF"); derive from the grid only when the IF has none.
(defun peb-chain-text (ifExpr pts)
  (if (and ifExpr (/= ifExpr "") (vl-string-search "@" ifExpr))
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
(defun peb-fall-marker (x y dir u / prev a ts hw bh sy ah fh sh)
  ;; house = tall rectangular BODY (base at -dir*bh, shoulders at +dir*sy) capped by a wide TRIANGULAR roof
  ;; (apex at +dir*ah), with the CIRCLE sitting in the body so it never pokes past the narrowing roof.
  (setq prev (getvar "CLAYER") a u ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        hw (* 0.70 a) bh (* 0.74 a) sy (* 0.34 a) ah (* 0.90 a)
        fh (/ (* 0.50 a) ts) sh (/ (* 0.36 a) ts))
  (setvar "CLAYER" "FALL")
  (command "_.PLINE"
    (list (- x hw) (- y (* dir bh))) (list (+ x hw) (- y (* dir bh)))                 ; body base
    (list (+ x hw) (+ y (* dir sy))) (list x (+ y (* dir ah))) (list (- x hw) (+ y (* dir sy)))  ; roof shoulders + apex
    "_C")
  (command "_.CIRCLE" (list x (- y (* dir 0.09 a))) (* 0.50 a))                        ; circle in the body
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list x (- y (* dir (+ bh (* 1.00 a))))) fh 90.0 "FALL")                   ; FALL vertical, clear below the pentagon
  (txt "MC" (list x (- y (* dir (+ bh (* 1.92 a))))) sh  0.0 (peb-slope-text))         ; slope small + horizontal, below FALL
  (setvar "CLAYER" prev))

(defun arrow-up-big   (x y u) (peb-fall-marker x y  1.0 u)) ; fall toward FSW (up)
(defun arrow-down-big (x y u) (peb-fall-marker x y -1.0 u)) ; fall toward NSW (down)

(defun draw-north-arrow (cx cy / s)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setq s *PEB-TEXT-SCALE*)
  (setvar "CLAYER" "STRUCTURE")
  (command "CIRCLE" (list cx cy) (* 600 s))
  (command "PLINE" (list cx (+ cy (* 550 s))) (list (- cx (* 180 s)) (- cy (* 150 s))) (list cx (- cy (* 50 s))) "C")
  (command "HATCH" "SOLID" "L" "")
  (command "PLINE" (list cx (- cy (* 550 s))) (list (+ cx (* 180 s)) (+ cy (* 150 s))) (list cx (- cy (* 50 s))) "C")
  (txt-bold "MC" (list cx (+ cy (* 900 s))) 600 0 "N")
)

(defun draw-border (x1 y1 x2 y2 / margin)
  (setq margin (* 800 *PEB-TEXT-SCALE*))
  (setvar "CLAYER" "BORDER")
  (command "RECTANG" (list (- x1 margin) (- y1 margin)) (list (+ x2 margin) (+ y2 margin)))
  (command "RECTANG" (list (- x1 (* margin 0.6)) (- y1 (* margin 0.6))) (list (+ x2 (* margin 0.6)) (+ y2 (* margin 0.6))))
)

(defun peb-structure-label (stype)
  (cond
    ((= stype "CS") (if *PEB-ARCHED* "ARCHED CLEAR SPAN" "CLEAR SPAN GABLE"))
    ((= stype "SS") "SINGLE SLOPE - COLUMNS BOTH SIDES")
    ((= stype "MS") (if *PEB-ARCHED* "ARCHED MULTI-SPAN" "MULTI-SPAN"))
    ((= stype "LT") "LEAN-TO")
    ((= stype "MG") "MULTI-GABLE")
    ((= stype "FR") "FLAT ROOF")
    ((= stype "RC") "ROOF ON RCC COLUMNS - NO STEEL COLUMNS")
    ((= stype "CC") "CANTILEVER CANOPY")
    ((= stype "BF") "BUTTERFLY STRUCTURE")
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
    ((= stype "CC") "CANTILEVER CANOPY")
    ((= stype "BF") "BUTTERFLY ROOF")
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
(defun tb-mtext (x y h wid attach str col)
  ;; UPPERCASE plain strings (labels + IF values); skip RTF blocks ("{\f...}") so
  ;; MText control words (\fArial, \b1, \P) are not corrupted by strcase.
  (if (and str (not (vl-string-search "{" str))) (setq str (strcase str)))
  (entmake (list (cons 0 "MTEXT") (cons 100 "AcDbEntity") (cons 8 "0")
                 (cons 62 col) (cons 100 "AcDbMText")
                 (list 10 x y 0.0) (cons 40 h) (cons 41 wid)
                 (cons 71 attach) (cons 7 "Standard") (cons 1 str) (cons 50 0.0))))
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
;; ONE line, capped at the desired height mh (Arial char width ~ 0.60 x height).
(defun tb-fith (s mw mh)
  (min mh (/ mw (* (max 1.0 (float (strlen s))) 0.64))))

;; strip an embedded unit suffix ("0 KN/m2" -> "0", "135 km/h" -> "135").
(defun peb-num-only (s / p)
  (setq p (vl-string-search " " s))
  (if p (substr s 1 p) s))

;; title-block value helpers (IF-linked): default when blank; dash "-" when not
;; applicable (zero / none); seismic shown as a ZONE.
(defun peb-tb-or (v d) (if (= v "") d v))
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
  (tb-mtext cx (+ cyBase (* w 0.135)) th (* w 1.04) 5 "{\\fArial|b1;MAIMAAR}" blue)
  (tb-mtext cx cyBase (* w 0.058) (* w 1.30) 5 "{\\fArial|b1;BUILDING SYSTEMS}" blue))

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

;; Mammut-MIRROR vertical title strip:  NOTES + disclaimer + DESIGN-LOAD table
;; anchored at the TOP, PROJECT-INFORMATION block anchored at the BOTTOM (exact
;; mirror of the Mammut proposal-drawing title block).  Every value links to the IF.
(defun peb-titleblock-mammut (X0 Y0 W H data
                              / white grey green cyan midX cw val lbl bv sm
                              yCur bt rh bottomH lx vx ux c1x c2x tb-get tb-hdiv)
  (setq white 7 grey 8 green 3 cyan 4)
  (defun tb-get (k) (cond ((cdr (assoc k data))) (T "")))
  (defun tb-hdiv (y) (tb-line X0 y (+ X0 W) y white))
  (setq midX (+ X0 (* W 0.50)) cw (* W 0.90)
        val (* H 0.0140) lbl (* H 0.0112) bv (* H 0.0160) sm (* H 0.0108))
  (tb-rect X0 Y0 (+ X0 W) (+ Y0 H) white)

  ;; ===================== TOP : GENERAL NOTES =====================
  (setq yCur (+ Y0 H))
  (setq rh (* H 0.026) bt yCur yCur (- yCur rh))
  (tb-mtext midX (+ yCur (* rh 0.28)) (* H 0.0140) cw 5
            "{\\fArial|b1;GENERAL NOTES}" white)
  (tb-hdiv yCur)
  (setq rh (* H 0.122) bt yCur yCur (- yCur rh))
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
  (setq rh (* H 0.058) bt yCur yCur (- yCur rh))
  (tb-mtext midX (+ yCur (* rh 0.5))
    (tb-fith "MAIMAAR STEEL (PVT) LTD - NOT FOR CONSTRUCTION" cw (* H 0.0105)) cw 5
    (strcat "{\\fArial|b1;THIS DOCUMENT IS A PROPOSAL DRAWING OF\\P"
            "MAIMAAR STEEL (PVT) LTD - NOT FOR CONSTRUCTION}") cyan)
  (tb-hdiv yCur)
  ;; ----- DESIGN-LOAD table (Mammut format) -----
  (setq lx (+ X0 (* W 0.05)) vx (+ X0 (* W 0.60)) ux (+ X0 (* W 0.80)))
  (setq rh (* H 0.052) bt yCur yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* H 0.0150))
    (tb-fith "SUPPORT IT'S OWN DEAD LOAD PLUS:" cw (* H 0.0120)) cw 1
    (strcat "{\\fArial|b1;THE BUILDING HAS BEEN DESIGNED TO\\P"
            "SUPPORT IT'S OWN DEAD LOAD PLUS:}") green)
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
    (setq rh (* H 0.0200) yCur (- yCur rh))
    (tb-mtext lx (+ yCur (* rh 0.5)) sm 0 4 (car r) white)
    (tb-mtext vx (+ yCur (* rh 0.5)) (tb-fith (cadr r) (* W 0.19) val) 0 4 (cadr r) green)
    (if (/= (caddr r) "")
      (tb-mtext ux (+ yCur (* rh 0.5)) sm 0 4 (caddr r) grey)))
  ;; code note — taller row + smaller fit so the 2-line text stays INSIDE the box
  ;; (above the divider), never overwriting the rule below.
  (setq rh (* H 0.044) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (+ yCur (* rh 0.74))
    (tb-fith (strcat "AS PER " (tb-get "CODE") " METAL BUILDING SYSTEMS MANUAL")
             (* cw 1.02) (* H 0.0092)) cw 1
    (strcat "{\\fArial|i1;AS PER " (tb-get "CODE")
            " METAL BUILDING SYSTEMS MANUAL}") green)
  (tb-hdiv yCur)

  ;; ============ BOTTOM : PROJECT INFORMATION (anchored to bottom) ============
  (setq bottomH (* H 0.515))
  (setq yCur (+ Y0 bottomH))
  (tb-hdiv yCur)
  ;; rev table : two sub-rows x cols
  (setq rh (* H 0.026))
  (tb-mtext (+ X0 (* W 0.11)) (- yCur (* rh 0.55)) val 0 5 (tb-get "REV")  green)
  (tb-mtext (+ X0 (* W 0.41)) (- yCur (* rh 0.55)) val 0 5 (tb-get "DATE") green)
  (tb-mtext (+ X0 (* W 0.80)) (- yCur (* rh 0.55)) val 0 5 (tb-get "DRN")  green)
  (tb-mtext (+ X0 (* W 0.935))(- yCur (* rh 0.55)) val 0 5 (tb-get "CHK")  green)
  (tb-hdiv (- yCur rh))
  (tb-mtext (+ X0 (* W 0.11)) (- yCur rh (* rh 0.55)) lbl 0 5 "Rev. No." grey)
  (tb-mtext (+ X0 (* W 0.41)) (- yCur rh (* rh 0.55)) lbl 0 5 "Date"    grey)
  (tb-mtext (+ X0 (* W 0.665))(- yCur rh (* rh 0.55)) lbl 0 5 "DSN"     grey)
  (tb-mtext (+ X0 (* W 0.80)) (- yCur rh (* rh 0.55)) lbl 0 5 "DRN"     grey)
  (tb-mtext (+ X0 (* W 0.935))(- yCur rh (* rh 0.55)) lbl 0 5 "CHK"     grey)
  (tb-line (+ X0 (* W 0.22)) (- yCur (* rh 2.0)) (+ X0 (* W 0.22)) yCur white)
  (tb-line (+ X0 (* W 0.60)) (- yCur (* rh 2.0)) (+ X0 (* W 0.60)) yCur white)
  (tb-line (+ X0 (* W 0.735))(- yCur (* rh 2.0)) (+ X0 (* W 0.735)) yCur white)
  (tb-line (+ X0 (* W 0.87)) (- yCur (* rh 2.0)) (+ X0 (* W 0.87)) yCur white)
  (setq yCur (- yCur (* rh 2.0)))
  (tb-hdiv yCur)
  ;; PROJECT NAME — label on its own line, value left-aligned BELOW it (no overlap)
  (setq bt yCur rh (* H 0.090) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "PROJECT NAME :" grey)
  (tb-mtext (+ X0 (* W 0.06)) (- bt (* lbl 3.0))
            (tb-fith (tb-get "PROJECT") (* 3.2 cw) (* bv 0.92)) (* cw 0.92) 1 (tb-get "PROJECT") green)
  (tb-hdiv yCur)
  ;; CUSTOMER
  (setq bt yCur rh (* H 0.048) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "CUSTOMER :" grey)
  (tb-mtext midX (+ yCur (* rh 0.28)) (tb-fith (tb-get "CUSTOMER") (* 1.6 cw) bv) cw 5 (tb-get "CUSTOMER") green)
  (tb-hdiv yCur)
  ;; STEEL CONTRACTOR : real Maimaar logo + address
  (setq bt yCur rh (* H 0.118) yCur (- yCur rh))   ; owner 5-Jul: narrower (tighter gaps around logo/address; frees footer room)
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "STEEL CONTRACTOR :" grey)
  (peb-tb-place-logo (+ X0 (* W 0.10)) (+ yCur (* rh 0.52))
                     (+ X0 (* W 0.90)) (- bt (* lbl 2.4)))
  (tb-mtext (+ X0 (* W 0.06)) (+ yCur (* rh 0.62)) (* sm 0.84) cw 1 (tb-get "ADDR") white)  ; owner 5-Jul: raised + shrunk so the CELL line stays inside the cell (was crossing the divider)
  (tb-hdiv yCur)
  ;; quote / bldg rows
  (foreach pr (list (list "QUOTE NO." (tb-get "QUOTE"))
                    (list "Bldg. No." (tb-get "BLDGNO"))
                    (list "Bldg. Name." (tb-get "BLDGNAME"))
                    (list "No. Of Identical Bldg." (tb-get "IDENTICAL")))
    (setq rh (* H 0.0240) yCur (- yCur rh))
    (tb-mtext (+ X0 (* W 0.05)) (+ yCur (* rh 0.50)) lbl 0 4 (car pr) grey)
    (tb-mtext (+ X0 (* W 0.52)) (+ yCur (* rh 0.50))
              (tb-fith (strcat ": " (cadr pr)) (* W 0.44) val) (* W 0.45) 4
              (strcat ": " (cadr pr)) green)
    (tb-hdiv yCur))
  ;; Drawing Title
  (setq bt yCur rh (* H 0.045) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.2)) lbl cw 1 "Drawing Title :" grey)
  (tb-mtext midX (+ yCur (* rh 0.20)) (tb-fith (tb-get "DRGTITLE") cw (* bv 0.82)) cw 5   ; owner 5-Jul: lower + smaller so it clears the label
            (strcat "{\\fArial|b1;" (tb-get "DRGTITLE") "}") green)
  (tb-hdiv yCur)
  ;; footer : Scale | Sheet Size | Sheet No.  (fills down to Y0)
  (setq rh (- yCur Y0) c1x (+ X0 (* W 0.40)) c2x (+ X0 (* W 0.70)))
  (tb-line c1x Y0 c1x yCur white) (tb-line c2x Y0 c2x yCur white)
  ;; owner 5-Jul: labels pinned to the TOP of the footer, values to the BOTTOM + smaller — no overlap.
  (tb-mtext (+ X0 (* W 0.04)) (- yCur (* lbl 1.0)) lbl 0 1 "Scale" grey)
  (tb-mtext (+ X0 (* W 0.20)) (+ Y0 (* val 0.95)) (* val 0.85) 0 5 (tb-get "SCALE") green)
  (tb-mtext (+ c1x (* W 0.03)) (- yCur (* lbl 1.0)) lbl 0 1 "Sheet Size" grey)
  (tb-mtext (* 0.5 (+ c1x c2x)) (+ Y0 (* val 0.95)) (* val 0.85) 0 5 (tb-get "SHEETSIZE") green)
  (tb-mtext (+ c2x (* W 0.03)) (- yCur (* lbl 1.0)) lbl 0 1 "Sheet No." grey)
  (tb-mtext (* 0.5 (+ c2x (+ X0 W))) (+ Y0 (* val 0.95)) (* val 0.85) 0 5 (tb-get "SHEETNO") green)
  (princ))

;; ===================== MAIN COMMAND =====================

(defun C:PEB-PLAN
  ( / dataFile data
    project client propinput propno fulldate
    len wid btype rooftype stype widthPts windspeed exposure collateral bldgno revno
    bays baysp bayPts x1 x2 baylen ewcols ewsp gridWpts ewStations ewY
    lewBrace rewBrace extType intType
    minSp prevp yBayDim yOvrDim yFsw ySub yTtl yFrmTop dimGap topGap txtGap
    ewExpr ewSpans ewSum ewScale ewAcc
    x y i j colOff botY topY leftX rightX
    xdraw idx ypt prevY currY
    c0 c1 c2 c3 c4 c5 c6
    tbTop tbBot tbW tbScale tbXShift
    maxSize areaM2
    borderL borderR borderB borderT bMarg bGap exmin exmax
    logoX logoY logoScale
    endBayL endBayR roofSlope
    mgGableW mgSpanW mgRidgePts mgValleyPts mgColumnPts mgSpans mgGables mgY loadValX
    numBays numMod sp bayNum modNum
    tblHeaderH tblBodyRowH tblBodyH tblTotalH tblColWs tblHeaders tblBodies
    tblMerges tblObj tblScaleX
    genNotesText accessoriesText loadsText codesText maimaarText projInfoRows
    slopeXs slopeStep rafterStep sx grp clearH
    lewFrameRaw rewFrameRaw lewFrameLabel rewFrameLabel
    mainHalfY endHalfX sheetGap
    gridY1 gridY2 gridX1 gridX2 ovrTxtH bubR nWid
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

  ;; Phase-2A v6: 3-mode dim display.
  ;; Excel BP_DIM_DISPLAY = "mm" / "mm & Ft" / "Only Ft" (default "mm").
  (setq *PEB-DIM-DISPLAY*
    (cond
      ((= (strcase (MSPL-Get-Str data "DIM_DISPLAY")) "MM & FT") "MMFT")
      ((= (strcase (MSPL-Get-Str data "DIM_DISPLAY")) "ONLY FT") "FT")
      (T                                                          "MM")))
  (setq stype     (strcase (MSPL-Get-Str data "STYPE")))
  ;; owner 5-Jul: the ARCH shows only in the SECTION — the column-layout PLAN of an arched building is the
  ;; same as its straight equivalent.  So map ACS->CS and AMS->MS for geometry, but flag it so the label
  ;; reads "ARCHED …".  (Before, both fell through to CS — AMS wrongly lost its interior columns.)
  (setq *PEB-ARCHED* nil)
  (cond ((= stype "ACS") (setq *PEB-ARCHED* T stype "CS"))
        ((= stype "AMS") (setq *PEB-ARCHED* T stype "MS")))
  (if (not (member stype '("CS" "SS" "MS" "LT" "MG" "FR" "RC" "CC" "BF")))
    (setq stype "CS"))

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
    ((= stype "FR") (setq rooftype "F"))
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

  ;; ── Width points ─────────────────────────────────────────────
  (cond
    ((= stype "MG")
      (progn
        (setq mgGables (MSPL-Get-Int data "NUMGABLES"))
        (setq mgSpans  (MSPL-Get-Int data "SPANSPERGABLE"))
        (if (or (null mgGables) (< mgGables 2)) (setq mgGables 2))
        (if (or (null mgSpans)  (< mgSpans  1)) (setq mgSpans  1))
        (if (> mgSpans 4) (setq mgSpans 4))
        (setq mgGableW (/ wid mgGables))
        (setq mgSpanW  (/ mgGableW mgSpans))
        (setq mgRidgePts '())
        (setq mgValleyPts '())
        (setq mgColumnPts (list 0.0 wid))
        (setq i 0)
        (while (< i mgGables)
          (setq base (* i mgGableW))
          (setq mgRidgePts (append mgRidgePts (list (+ base (/ mgGableW 2.0)))))
          (if (< i (1- mgGables))
            (progn
              (setq valley (+ base mgGableW))
              (setq mgValleyPts (append mgValleyPts (list valley)))
              (setq mgColumnPts (append mgColumnPts (list valley)))
            )
          )
          (if (> mgSpans 1)
            (progn
              (setq j 1)
              (while (< j mgSpans)
                (setq colY (+ base (* j mgSpanW)))
                (if (and (> colY 0) (< colY wid))
                  (setq mgColumnPts (append mgColumnPts (list colY))))
                (setq j (1+ j))
              )
            )
          )
          (setq i (1+ i))
        )
        (setq mgColumnPts (vl-sort mgColumnPts '<))
        (setq widthPts mgColumnPts)
      )
    )
    ((= stype "BF")
      (setq widthPts (list 0.0 (/ wid 2.0) wid))
    )
    ((= stype "MS")
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
  (setq ewcols (fix (/ wid 6250.0)))
  (if (< ewcols 1) (setq ewcols 1))
  (setq ewsp (/ wid ewcols))
  (if (< ewsp 6000) (progn (setq ewcols (1- ewcols)) (if (< ewcols 1) (setq ewcols 1)) (setq ewsp (/ wid ewcols))))
  (if (> ewsp 6500) (progn (setq ewcols (1+ ewcols)) (setq ewsp (/ wid ewcols))))

  ;; RULE (owner, deviation from Zealcon): EVERY end-wall column gets a grid line
  ;; + letter.  Build the end-wall column stations (0, ewsp, 2*ewsp, … , wid) and
  ;; merge them with the main-frame width stations (widthPts) into gridWpts, so the
  ;; intermediate end-wall column (e.g. the red one between A & B) is gridded too.
  ;; End-wall stations STRICTLY from the IF (BP_EW_LEFT_SPACING) if provided; else the auto rule.
  (setq ewExpr (MSPL-Get-Str data "EWLEXPR"))
  (setq ewSpans (if (and ewExpr (/= ewExpr "")) (peb-parse-mod-expression ewExpr) nil))
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
    (if (not (vl-some '(lambda (p) (< (abs (- p s)) 1.0)) gridWpts))
      (setq gridWpts (append gridWpts (list s)))))
  (setq gridWpts (vl-sort gridWpts '<))

  (setq areaM2 (/ (* len wid) 1000000.0))
  ;; Phase-2A v23: column placement so OUTER flange sits ON the grid
  ;; line (Mammut convention).  Sidewall columns inset h/2 = 350 from
  ;; NSW/FSW grid; end-wall columns inset w/2 = 230 from LEW/REW grid.
  ;; Maimaar-typical column web depth BY SPAN → drives the symbol + the inset.
  (setq *PEB-COL-WEB* (peb-col-web-depth wid))
  (setq colOff  (/ *PEB-COL-WEB* 2.0)
        botY    (/ *PEB-COL-WEB* 2.0)
        topY    (- wid (/ *PEB-COL-WEB* 2.0))
        leftX   230.0
        rightX  (- len 230.0))

  (command "UNDO" "BEGIN")

  ;; ── Text styles & layers ─────────────────────────────────────
  (make-text-style "PEB-TITLE" "romand.shx")
  (make-text-style "PEB-BODY"  "romans.shx")
  (make-text-style "PEB-DIM"   "romans.shx")

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
  (peb-draw-outline 0.0 0.0 len wid)
  (setvar "CLAYER" "SHEETING")
  (peb-draw-outline (- 0.0 sheetGap) (- 0.0 sheetGap) (+ len sheetGap) (+ wid sheetGap))
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
  (txt-bold "MC" (list aCx aCy) 550 0 aLbl)

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
  (setq minSp len prevp nil)
  (foreach p bayPts   (if prevp (setq minSp (min minSp (- p prevp)))) (setq prevp p))
  (setq prevp nil)
  (foreach p gridWpts (if prevp (setq minSp (min minSp (- p prevp)))) (setq prevp p))
  ;; owner 4-Jul: bubbles must be big enough to READ. Floor 650, grow with the building (620*scale),
  ;; only shrink if bays are tight (0.42*minSp so bubbles still never touch).
  (setq *PEB-BUBRAD* (max 900.0 (min (* 720.0 *PEB-TEXT-SCALE*) (* 0.48 minSp))))
  (setq bubR (+ *PEB-BUBRAD* (* 60.0 *PEB-TEXT-SCALE*)))       ; stem stops just outside the bubble
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
  (setq ovrTxtH (* 490.0 *PEB-DIM-SCALE*))                             ; outer-dim TEXT height (DIMTXT 440*DS) — clear it snugly
  (setq gridY2  (+ yOvrDim ovrTxtH topGap *PEB-BUBRAD*))                ; grid bubble CENTRE — gap ABOVE the dim text (owner 5-Jul)
  (setq yFsw    (+ gridY2 *PEB-BUBRAD* txtGap))                         ; FSW wall label
  (setq ySub    (+ yFsw txtGap))                                        ; area-description banner
  (setq yTtl    (+ ySub txtGap))                                        ; COLUMN LAYOUT PLAN title
  (setq yFrmTop (+ yTtl txtGap))                                        ; frame / border top
  ;; LEFT stack (leftward from the LEW edge x=0): overall-width dim (-3500 DS) then letter bubbles
  ;; letter bubble CENTRE — anchored 0.9*dimGap BEYOND the outermost (-3*dimGap) width dim, + bubble radius,
  ;; so it FOLLOWS dimGap and can never collide with the overall-width chain no matter how wide the spacing.
  (setq gridX1  (- (- 0.0 (* 3.0 dimGap) ovrTxtH topGap) *PEB-BUBRAD*))  ; bubble LEFT of the outer-dim text + a gap (owner 5-Jul)

  (setq i 1)
  ;; owner 5-Jul (multi-area): the top length-grid sits on the FSW side — skip it when FSW is the wall
  ;; SHARED with an attached area (the grid continues from the reference; avoids the overlap at the join).
  (if (not (peb-omit-wall-p "FSW"))
    (foreach x bayPts
      (setvar "CLAYER" "GRID-LINES")
      ;; RULE (owner 4-Jul): grid marking line runs from the OUTER dimension line (overall length dim,
      ;; yOvrDim) up to the inner side of the bubble — not through the building.
      (command "LINE" (list x (+ yOvrDim ovrTxtH)) (list x (- gridY2 bubR)) "")   ; owner 5-Jul: start just ABOVE the outer-dim text
      (setvar "CLAYER" "GRID")
      (grid-bubble x gridY2 (itoa i))
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
  (if (not (peb-hide-wall-label-p "LEW"))
  (foreach y gridWpts
    (setvar "CLAYER" "GRID-LINES")
    ;; RULE (owner 4-Jul): grid marking line from the OUTER width dimension line (-3*dimGap) to the bubble.
    (command "LINE" (list (- (- 0.0 (* 3.0 dimGap)) ovrTxtH) y) (list (+ gridX1 bubR) y) "")   ; owner 5-Jul: start just LEFT of the outer-dim text
    (setvar "CLAYER" "GRID")
    (grid-bubble gridX1 y (chr (+ 65 (- nWid 1 j))))
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
        (peb-ridge-line 0 len (/ wid 2.0))
        (vl-catch-all-apply
          (function (lambda ()
            (peb-ridge-symbol (peb-ridge-bay-x bayPts) (/ wid 2.0)))))
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
              (peb-label-with-leader "VALLEY GUTTER LINE"
                                     (list (* len 0.80) (+ mgY (* 1200 *PEB-TEXT-SCALE*)))
                                     (list (* len 0.75) mgY)
                                     "S" 600.0)))))
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (* len 0.50) (+ wid (* 700 *PEB-TEXT-SCALE*))) 300 0
          (strcat "MULTI-GABLE ROOF | " (itoa mgGables) " GABLES | " (itoa mgSpans) " SPAN(S) EACH GABLE"))
      )
    )
    ((= stype "BF")
      (progn
        (setvar "CLAYER" "RIDGE")
        (command "LINE" (list 0 (/ wid 2.0)) (list len (/ wid 2.0)) "")
      )   ; owner 5-Jul: valley label folded into the centre-line callouts below (was overlapping the AREA tag)
    )
    ((= stype "FR")
      (progn (setvar "CLAYER" "TEXT")
             (txt "MC" (list (* len 0.50) (- (* wid 0.50) (* 1300 *PEB-TEXT-SCALE*))) 400 0 "FLAT ROOF BUILDING"))   ; owner 5-Jul: below the AREA tag
    )
    (T
      (progn (setvar "CLAYER" "TEXT")
             (txt "MC" (list (* len 0.50) (- (* wid 0.50) (* 1300 *PEB-TEXT-SCALE*))) 400 0 (peb-roof-label stype rooftype)))   ; owner 5-Jul: below the AREA tag
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
      (peb-label-with-leader "RAFTER"
                             (list (+ (nth i bayPts) (* 1200 *PEB-DIM-SCALE*))
                                   (- (* 1200 *PEB-DIM-SCALE*)))
                             (list (nth i bayPts) (/ wid 4.0))
                             "S" 600.0))))

  ;; End-frame TYPE — computed HERE (before the columns) so a MAIN-FRAME end wall draws its outer
  ;; columns like the interior (full-size, lengthwise); a BEARING end wall uses the half-size posts.
  (setq lewFrameRaw (strcase (MSPL-Get-Str data "EW_LEFT_FRAME"))
        rewFrameRaw (strcase (MSPL-Get-Str data "EW_RIGHT_FRAME"))
        lewFrameLabel (if (or (= lewFrameRaw "MAIN FRAME") (= lewFrameRaw "RIGID")) "MAIN FRAME" "BEARING FRAME")
        rewFrameLabel (if (or (= rewFrameRaw "MAIN FRAME") (= rewFrameRaw "RIGID")) "MAIN FRAME" "BEARING FRAME"))

  ;; owner 5-Jul (multi-area): in multi-area mode, this area OMITS the column/bracing/sheeting on the wall
  ;; it SHARES with its reference (from AR_POSITION) — one shared row of columns.  nil => single-area, draw all.
  (setq *PEB-OMIT-WALL* (if *PEB-MULTI-MODE* (peb-common-wall (MSPL-Get-Str data "AR_POSITION")) nil))

  ;; ── Columns ───────────────────────────────────────────────────
  (cond
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
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.86)) 600 0 "FRONT / CANTILEVER EDGE - NO COLUMNS")
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.14)) 600 0 "BACK SUPPORT COLUMN LINE")
      )
    )
    ((= stype "LT")
      (progn
        (foreach x bayPts
          (if (= x 0) (setq xdraw leftX) (if (> x (- len 1)) (setq xdraw rightX) (setq xdraw x)))
          (draw-I-column-lengthwise xdraw botY))
        (setvar "CLAYER" "TEXT")
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.86)) 600 0 "ATTACHED SIDE / EXISTING BUILDING OR WALL")
        (txt-bold "MC" (list (/ len 2.0) (* wid 0.14)) 600 0 "OUTER STEEL COLUMN LINE")
      )
    )
    ((= stype "BF")
      (progn
        (foreach x bayPts
          (if (= x 0) (setq xdraw leftX) (if (> x (- len 1)) (setq xdraw rightX) (setq xdraw x)))
          (draw-I-column-lengthwise xdraw (/ wid 2.0)))
        (setvar "CLAYER" "TEXT")   ; owner 5-Jul: cleared of the AREA tag — one callout above, one below, snug to the falls
        (txt-bold "MC" (list (/ len 2.0) (+ (/ wid 2.0) (* 1700 *PEB-TEXT-SCALE*))) 560 0 "CENTER COLUMN LINE / VALLEY GUTTER - BUTTERFLY")
        (txt-bold "MC" (list (/ len 2.0) (- (/ wid 2.0) (* 1700 *PEB-TEXT-SCALE*))) 560 0 "NO SIDE-WALL COLUMNS - ROOF CANTILEVERS BOTH SIDES")
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
            (progn (if (not (peb-omit-wall-p "LEW")) (draw-I-column-widthwise leftX y))
                   (if (not (peb-omit-wall-p "REW")) (draw-I-column-widthwise rightX y))))
        )
        (if (member stype '("MS" "MG"))
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
  (vl-catch-all-apply (function (lambda () (peb-draw-bracing bayPts widthPts wid 0.0 0.0 lewBrace rewBrace extType intType))))
  ;; End-wall column bracing (owner 5-Jul): X-bracing between the end-wall columns in the LEW/REW planes,
  ;; same braced-panel rule as the bays, gated by lewBrace/rewBrace, exterior type.
  (vl-catch-all-apply (function (lambda () (peb-draw-endwall-bracing ewStations leftX rightX lewBrace rewBrace extType))))

  ;; ── Doors / windows at their offsets (+ braced-bay clash flag) ─
  (vl-catch-all-apply (function (lambda () (peb-draw-placements data 0.0 0.0 len wid bayPts))))

  ;; (Anchor-bolt base-plate schedule removed — this is the COLUMN LAYOUT PLAN;
  ;;  columns show the I-section with their typical 4 anchor bolts, no schedule.)

  ;; ── FALL glyphs (owner 4-Jul) ─────────────────────────────────
  ;; MAXIMUM 2-3 fall symbols total (owner: "should be maximum 2 or 3"), evenly spaced, snapped to the
  ;; nearest UNBRACED bay (so the "BRACED BAY" text never overlaps). Autosized (fallU), placed MID-WAY
  ;; between the ridge line and the outer columns.
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

  ;; catch-wrap so a fall-glyph error can never abort the whole plan.
  (vl-catch-all-apply (function (lambda ()
    (cond
      ((member stype '("CS" "MS" "RC"))
        (foreach sx slopeXs
          (arrow-up-big   sx (* wid 0.875) fallU)    ; owner 5-Jul: 3/4 from ridge -> near FSW
          (arrow-down-big sx (* wid 0.125) fallU)))  ; owner 5-Jul: 3/4 from ridge -> near NSW
      ((= stype "MG")
        (foreach mgY mgRidgePts
          (foreach sx slopeXs
            (arrow-up-big   sx (+ mgY (* mgGableW 0.375)) fallU)   ; owner 5-Jul: 3/4 from gable ridge
            (arrow-down-big sx (- mgY (* mgGableW 0.375)) fallU))))
      ((= stype "BF")
        (foreach sx slopeXs
          (arrow-down-big sx (* wid 0.875) fallU)   ; owner 5-Jul: 3/4 from ridge -> near wall
          (arrow-up-big   sx (* wid 0.125) fallU)))
      ((= stype "FR")
        (progn (setvar "CLAYER" "TEXT")
               (txt "MC" (list (* len 0.50) (* wid 0.57)) 600 0 "MINIMUM ROOF SLOPE / DRAINAGE AS PER DESIGN")))
      (T
        (foreach sx slopeXs
          (arrow-down-big sx (* wid 0.5) fallU)))))))

  ;; ── Wall labels ───────────────────────────────────────────────
  ;; Phase-2A v12: pushed FSW/NSW further from building (was 2800,
  ;; now 4500) to clear the bay+overall dim chain underneath.
  (setvar "CLAYER" "TEXT")
  ;; owner 4-Jul: wall labels are SIMPLE — the full name only, no open-wall condition suffix.
  ;; owner 5-Jul (multi-area): drop the wall label on the side SHARED with an attached area (avoids the
  ;; label piling onto the reference area at the join).
  (if (not (peb-hide-wall-label-p "FSW")) (txt-bold "MC" (list (/ len 2.0) yFsw) 560 0 "FSW - FAR SIDE WALL"))
  (if (not (peb-hide-wall-label-p "NSW")) (txt-bold "MC" (list (/ len 2.0) (- (* 3000 *PEB-TEXT-SCALE*))) 560 0 "NSW - NEAR SIDE WALL"))
  ;; owner 4-Jul: LEW label sits OUTSIDE the letter bubbles (was sandwiched between the width dims and
  ;; the bubbles -> overlapped the dim text). REW side has no dims/bubbles, so it stays close.
  (if (not (peb-hide-wall-label-p "LEW")) (txt-bold "MC" (list (- gridX1 (* 2200.0 *PEB-DIM-SCALE*)) (/ wid 2.0)) 560 90 "LEW - LEFT END WALL"))
  (if (not (peb-hide-wall-label-p "REW")) (txt-bold "MC" (list (+ len (* 3000 *PEB-DIM-SCALE*)) (/ wid 2.0)) 560 90 "REW - RIGHT END WALL"))

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
  (setq lewFrameLabel
    (if (or (= lewFrameRaw "MAIN FRAME") (= lewFrameRaw "RIGID"))
      "MAIN FRAME"
      "BEARING FRAME"))
  (setq rewFrameLabel
    (if (or (= rewFrameRaw "MAIN FRAME") (= rewFrameRaw "RIGID"))
      "MAIN FRAME"
      "BEARING FRAME"))
  ;; Clear BEARING/MAIN FRAME word on BOTH end walls (owner requirement) — placed
  ;; beside the LEW/REW wall labels.  (If an end is a Main Frame, its corner
  ;; columns are already drawn lengthwise = interior main-frame size/direction.)
  (setvar "CLAYER" "TEXT")
  (if (not (peb-hide-wall-label-p "LEW")) (txt-bold "MC" (list (- gridX1 (* 4400.0 *PEB-DIM-SCALE*)) (/ wid 2.0)) 430 90 (strcat "(" lewFrameLabel ")")))
  (if (not (peb-hide-wall-label-p "REW")) (txt-bold "MC" (list (+ len (* 4500 *PEB-DIM-SCALE*)) (/ wid 2.0)) 430 90 (strcat "(" rewFrameLabel ")")))
  (cond
    ;; Both ends same → ONE MLEADER, "BEARING FRAME / BOTH ENDS"
    ((= lewFrameLabel rewFrameLabel)
      (vl-catch-all-apply
        (function (lambda ()
          (peb-label-with-leader
            (if (= lewFrameLabel "MAIN FRAME") "MAIN FRAME\\P(HALF BAY LOADING)"
                (strcat lewFrameLabel "\\PBOTH ENDS"))               ; owner 4-Jul: sync w/ IF, 2 rows
            (list (- (* 1500 *PEB-DIM-SCALE*))                        ; owner 5-Jul: moved RIGHT (was -4500*DS)
                  (+ wid (* 2200 *PEB-TEXT-SCALE*)))
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
                                 "S" 600.0))))))

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
                         (peb-fmt-labelled "BLDG. LENGTH" (nth 0 ldim) (peb-basis-suffix lref)))
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
                          (peb-fmt-labelled "BLDG. WIDTH" (nth 0 wdim) (peb-basis-suffix wref)))
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
  (if (not *PEB-MULTI-MODE*)
    (progn
      (txt-bold "MC" (list (/ len 2.0) yTtl) 870 0 "COLUMN LAYOUT PLAN")   ; owner 5-Jul: smaller, more proportional
      (txt "MC" (list (/ len 2.0) ySub) 560 0
        (strcat (rtos (/ len 1000.0) 2 0) "×"
                (rtos (/ wid 1000.0) 2 0) " m"
                "  |  " (peb-comma (rtos areaM2 2 0)) " m\U+00B2"   ; owner 5-Jul: comma-grouped (6,967)
                "  |  " (itoa bays) " BAYS"
                "  |  SLOPE " roofSlope
                (if (and clearH (> clearH 0))
                  (strcat "  |  C.H = " (peb-comma (rtos clearH 2 0)))   ; owner 5-Jul: comma-grouped (10,670)
                  "")
                "  |  " (peb-structure-label stype)
                (if (= stype "MG")
                  (strcat "  |  " (itoa mgGables) " GABLES — " (itoa mgSpans) " SPAN(S) EACH")
                  "")))
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
  (setq bMarg (+ (* 10500.0 *PEB-DIM-SCALE*) *PEB-BUBRAD*))
  (setq borderL (- 0.0 bMarg))
  (setq borderR (max (+ len bMarg) (+ c6 (* 800 *PEB-TEXT-SCALE*))))
  (setq borderT (+ yFrmTop (* 400.0 *PEB-TEXT-SCALE*)))
  (princ (strcat "\n[BORDER-DEBUG R2] borderL=" (rtos borderL 2 0) " borderR=" (rtos borderR 2 0)
                 " DIMSCALE=" (rtos *PEB-DIM-SCALE* 2 2) " BUBRAD=" (rtos *PEB-BUBRAD* 2 0)))

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
      "{\\fArial|b1;MAIMAAR STEEL Pvt. Ltd.}\\P"
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
      "{\\fArial|b1;COLUMN LAYOUT & ANCHOR BOLT PLAN}"
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
  (setq tbStripW (* (- borderT borderB) 0.30))
  (setq tbStripX (+ (car exmax) (* 3500.0 *PEB-DIM-SCALE*))   ; gap right of the building content
        borderR  (+ tbStripX tbStripW))                       ; right border = panel right edge (no gap)
  ;; owner 5-Jul (multi-area): publish this area's drawn size, frame params and attach info so the
  ;; orchestrator (peb-plan-multi-from-files) can place areas by their LOGICAL dimensions and draw ONE
  ;; shared border + title block around the whole set (each area suppresses its own via *PEB-SUPPRESS-TB*).
  (setq *PEB-MA-WID* wid *PEB-MA-LEN* len
        *PEB-MA-TBDATA* tbData *PEB-MA-TBSTRIPW* tbStripW *PEB-MA-BGAP* bGap
        *PEB-MA-SHEETH* (- borderT borderB)   ; this area's own sheet height (for a constant combined title block)
        *PEB-AR-NUM* (MSPL-Get-Int data "AREA_NUM")
        *PEB-AR-POS* (MSPL-Get-Str data "AR_POSITION")
        *PEB-AR-REF* (MSPL-Get-Int data "AR_REF_AREA")
        *PEB-AR-GAP* (MSPL-Get-Num data "AR_GAP"))
  (if (not *PEB-SUPPRESS-TB*)
    (progn
      (peb-titleblock-mammut tbStripX borderB tbStripW (- borderT borderB) tbData)  ; fills full height
      (draw-border borderL borderB borderR borderT)))

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
            (cons 3 "arialbd.ttf")   ; primary font: Arial Bold
            (cons 4 "")              ; big-font name (none)
          ))))))
  ;; Pick the first available style — PEB-Body preferred (Arial Bold),
  ;; then user's reference TNROMAN, then other fallbacks.
  (setq txtStyle
    (cond
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
  (setvar "DIMTXT"   500.0)
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
  (setvar "DIMTXSTY"    txtStyle)
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

(defun peb-dim-v-native (x y1 y2 override / oldLayer dimPt)
  ;;  Native VERTICAL linear dimension via DIMLINEAR.  Picking a dim-line
  ;;  position to the side of the def points causes DIMLINEAR to choose
  ;;  vertical orientation automatically.
  (setq oldLayer (getvar "CLAYER"))
  (setvar "CLAYER" "DIMENSIONS")
  (setq dimPt (list x (/ (+ y1 y2) 2.0)))
  (if override
    (command "_DIMLINEAR"
             (list x y1)
             (list x y2)
             "_T" override
             dimPt)
    (command "_DIMLINEAR"
             (list x y1)
             (list x y2)
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
  ;; should embed MText format codes (e.g. "{\\fArial|b1;…}") in the
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
  (peb-safe-setvar "DIMTXT"   440.0)        ; owner 5-Jul: smaller, more proportional with the sheet
  (peb-safe-setvar "DIMTXSTY" "PEB-TITLE")
  (peb-safe-setvar "DIMTSZ"     0.0)        ; no ticks -> arrowheads
  (peb-safe-setvar "DIMASZ"   320.0)        ; proper small arrowhead
  (vl-catch-all-apply (function (lambda () (setvar "DIMBLK" "_CLOSEDFILLED"))))
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

(defun peb-vla-make-dim-h (x1 x2 y override / acad doc mspace dimObj)
  ;;  VLA path for a horizontal dim.  Returns the dim object on success,
  ;;  errors out otherwise (caller catches via vl-catch-all-apply).
  (vl-load-com)
  (setq acad   (vlax-get-acad-object))
  (setq doc    (vla-get-ActiveDocument acad))
  (setq mspace (vla-get-ModelSpace doc))
  (setq dimObj
    (vla-AddDimRotated
      mspace
      (vlax-3d-point (list x1 0.0 0.0))                       ; def 1
      (vlax-3d-point (list x2 0.0 0.0))                       ; def 2
      (vlax-3d-point (list (/ (+ x1 x2) 2.0) y 0.0))          ; dim line
      0.0))                                                    ; rotation
  (vla-put-Layer dimObj "DIMENSIONS")
  (if override (vla-put-TextOverride dimObj override))
  dimObj
)

(defun peb-vla-make-dim-height (objX dimX y1 y2 override / acad doc mspace dimObj)
  ;;  VLA path for a vertical/height dim.  Def points at objX so
  ;;  extension lines are drawn from the object out to the dim line.
  (vl-load-com)
  (setq acad   (vlax-get-acad-object))
  (setq doc    (vla-get-ActiveDocument acad))
  (setq mspace (vla-get-ModelSpace doc))
  (setq dimObj
    (vla-AddDimRotated
      mspace
      (vlax-3d-point (list objX y1 0.0))
      (vlax-3d-point (list objX y2 0.0))
      (vlax-3d-point (list dimX (/ (+ y1 y2) 2.0) 0.0))
      (/ pi 2.0)))                                             ; rotation = 90°
  (vla-put-Layer dimObj "DIMENSIONS")
  (if override (vla-put-TextOverride dimObj override))
  dimObj
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

(defun peb-dim-height-native (objX dimX y1 y2 override / oldLayer dimPt)
  ;;  Vertical "height" dim — extension lines run horizontally from objX
  ;;  to the dim-line column at dimX.  Def points are at (objX, y1) and
  ;;  (objX, y2); dim-line position is (dimX, midY) which forces
  ;;  vertical orientation.
  (setq oldLayer (getvar "CLAYER"))
  (setvar "CLAYER" "DIMENSIONS")
  (setq dimPt (list dimX (/ (+ y1 y2) 2.0)))
  (if override
    (command "_DIMLINEAR"
             (list objX y1)
             (list objX y2)
             "_T" override
             dimPt)
    (command "_DIMLINEAR"
             (list objX y1)
             (list objX y2)
             dimPt))
  (setvar "CLAYER" oldLayer)
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

(defun peb-plan-from-file (path / prev-last prev-max-x e new-set offset)
  (setq prev-last (entlast))
  (if prev-last
    (progn
      (command "_.REGEN")
      (setq prev-max-x (car (getvar "EXTMAX")))
      (if (or (null prev-max-x) (< prev-max-x -1e10))
        (setq prev-max-x nil)))
    (setq prev-max-x nil))

  (setq *PEB-DATA-FILE* path)
  (princ (strcat "\nPEB-PLAN using data file: " path))
  (C:PEB-PLAN)
  (setq *PEB-DATA-FILE* nil)

  (peb-tile-place prev-last prev-max-x)   ; left→right tile, fixed gap, no box overlap
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
  (or (peb-omit-wall-p w)
      (and *PEB-REF-SHARED* (= (strcase *PEB-REF-SHARED*) (strcase w)))))

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

;; draw a building-outline rectangle EDGE-BY-EDGE, skipping the wall shared with an attached area
;; (*PEB-OMIT-WALL*).  NSW=bottom(y0) FSW=top(y1) LEW=left(x0) REW=right(x1).  nil => all 4 (normal).
(defun peb-draw-outline (x0 y0 x1 y1)
  (if (not (peb-omit-wall-p "NSW")) (command "_.LINE" (list x0 y0) (list x1 y0) ""))
  (if (not (peb-omit-wall-p "FSW")) (command "_.LINE" (list x0 y1) (list x1 y1) ""))
  (if (not (peb-omit-wall-p "LEW")) (command "_.LINE" (list x0 y0) (list x0 y1) ""))
  (if (not (peb-omit-wall-p "REW")) (command "_.LINE" (list x1 y0) (list x1 y1) ""))
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
(defun peb-draw-combined-frame ( / exmin exmax cw ch cds bGap sh tbW bL bB bT bR tbX)
  (vl-catch-all-apply (function (lambda () (command "_.ZOOM" "_E"))))
  (setq exmin (getvar "EXTMIN") exmax (getvar "EXTMAX")
        cw (- (car exmax) (car exmin)) ch (- (cadr exmax) (cadr exmin))
        cds  (max 0.8 (/ (max cw ch) 45000.0))   ; combined "dim scale" (single-sheet formula)
        bGap (* 3000.0 cds))                       ; uniform border margin for the whole sheet
  ;; owner 5-Jul: use the REFERENCE area's own (tested) title-block width + height — a CONSTANT standard
  ;; block that fits its content perfectly — anchored TOP-right, NOT stretched to the full set height
  ;; (which over-stretched the note/load sections and made the text overlap).  Falls back to 0.30 x sheet
  ;; height if the reference size wasn't supplied.
  (setq bL (- (car exmin) bGap) bB (- (cadr exmin) bGap) bT (+ (cadr exmax) bGap) sh (- bT bB)
        tbW (if *PEB-MA-FIRST-TBW*    *PEB-MA-FIRST-TBW*    (* sh 0.30))
        tbH (min (if *PEB-MA-FIRST-SHEETH* *PEB-MA-FIRST-SHEETH* sh) sh)
        tbX (+ (car exmax) (* 3500.0 cds)) bR (+ tbX tbW))
  (if *PEB-MA-TBDATA* (peb-titleblock-mammut tbX (- bT tbH) tbW tbH *PEB-MA-TBDATA*))
  (draw-border bL bB bR bT)
  ;; owner 5-Jul: ONE big title at the TRUE combined top-centre (over the plan, left of the title block) —
  ;; correct for every attach direction since no area draws its own title in multi-area mode.
  (setvar "CLAYER" "TEXT")
  (txt-bold "MC" (list (/ (+ (car exmin) (car exmax)) 2.0) (+ (cadr exmax) (* bGap 0.5)))
            (* sh 0.0072) 0 "COLUMN LAYOUT PLAN")
  (command "_.ZOOM" "_E")
  (princ))

;; ORCHESTRATOR — draw + place every area file, then one shared frame.
;; NB (owner 5-Jul): the CALLER must invoke this AND the DXFOUT/export in ONE top-level form (a progn) —
;; in acad /b, the script reader stalls on the NEXT top-level form after the multi-area draw (an ActiveX/
;; title-block state quirk).  Single-area is unaffected.  e.g.:
;;   (progn (peb-plan-multi-from-files (list ...)) (command "_.ZOOM" "_E") (command "_.DXFOUT" f "16"))
(defun peb-plan-multi-from-files (paths / placed prev-last off aNum pos ref gap w l refbnds i)
  (setq *PEB-SUPPRESS-TB* T *PEB-MULTI-MODE* T placed nil i 0)
  (foreach path paths
    (setq prev-last (entlast) *PEB-DATA-FILE* path)
    ;; C:PEB-PLAN itself sets *PEB-OMIT-WALL* from AR_POSITION (it already reads the data) — no re-open here
    (vl-catch-all-apply (function (lambda () (C:PEB-PLAN))))
    (setq w *PEB-MA-WID* l *PEB-MA-LEN* aNum *PEB-AR-NUM*
          pos *PEB-AR-POS* ref *PEB-AR-REF* gap *PEB-AR-GAP*)
    ;; the reference (first) area fixes the title-block size so it stays CONSTANT (not stretched to the set)
    (if (= i 0) (setq *PEB-MA-FIRST-SHEETH* *PEB-MA-SHEETH* *PEB-MA-FIRST-TBW* *PEB-MA-TBSTRIPW*))
    (setq refbnds (if ref (cdr (assoc ref placed))))
    (if (or (= i 0) (null refbnds) (wcmatch (strcase (if pos pos "STANDALONE")) "*STANDALONE*"))
      (setq off (list 0.0 0.0))
      (setq off (peb-area-offset pos gap w l refbnds)))
    (peb-move-since prev-last off)
    (setq placed (cons (cons aNum (list (car off) (+ (car off) l) (cadr off) (+ (cadr off) w))) placed)
          i (1+ i)))
  (setq *PEB-SUPPRESS-TB* nil *PEB-OMIT-WALL* nil *PEB-MULTI-MODE* nil)
  (peb-draw-combined-frame)
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

(princ "\nMAIMAAR PEB-PLAN (Phase-2 standalone) loaded [BUILD 2026-07-04-R2 border-centre+bubble]. Command: PEB-PLAN")
(princ "\nPDF helper:    type PEB-PDF  then pick window corners.")
(princ "\nIdentify tool: type PEB-WHAT then pick any entity to see its LISP source.\n")
(princ)
