; ============================================================================
; MAIMAAR STEEL Pvt. Ltd.
; PEB Phase-2  --  Cross-Section Drawing  (standalone)
; Command: PEB-SECTION
;
; Self-contained: reads PEB_Data_B<n>_A<m>.txt (v3 format, written by
; Maimaar_PEB_Input.xlsm Generate Drawings VBA). No Phase-1 dependency.
; Geometry inherited from V40 (frame, haunch, plate, dim, stiffener,
; sheeting, title-block) -- intact.
;
; Two entry points:
;   C:PEB-SECTION                   interactive (Pick-file dialog)
;   (peb-section-from-file <path>)  non-interactive (used by Excel VBA)
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
      ;; spec MUST keep a digit (thickness) — see Plan.lsp note; default 50mm.
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
  (reverse out))

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
      ;; so that LISP edits to layer attributes always take effect.
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

(defun tbY (y)
  ;;  Title-block Y transformer: maps a legacy Y (anchored at -5200,
  ;;  the historical tbTop) to the current scaled, shifted position.
  ;;  Used by every absolute Y inside the title-block layout.
  ;;
  ;;  Y_new = (Y_legacy − (-5200)) × tbScale + tbTop
  ;;        = (Y_legacy + 5200)    × tbScale + tbTop
  ;;
  ;;  where tbScale = tbW / 35000 (1.0 at min title-block width up to
  ;;  about 2.29 for a 80 m capped tbW), and tbTop is the dynamic
  ;;  top edge of the title block.  Both variables live in the
  ;;  C:PEB-SECTION call frame and tbY accesses them via AutoLISP's
  ;;  dynamic scoping.
  (+ (* (+ y 5200.0) tbScale) tbTop))

(defun txt (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setvar "TEXTSTYLE" "PEB-BODY")
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
)

(defun txt-bold (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setvar "TEXTSTYLE" "PEB-TITLE")
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
)

(defun txt-dim (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setvar "TEXTSTYLE" "PEB-DIM")
  (command "TEXT" "J" just pt (* h *PEB-TEXT-SCALE*) rot str)
)

(defun split-on-space (s / out cur i ch)
  ;;  Tokenize a string on space - returns a list of words (no empties).
  (setq out '() cur "" i 1)
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (if (= ch " ")
      (progn
        (if (/= cur "") (setq out (append out (list cur))))
        (setq cur ""))
      (setq cur (strcat cur ch)))
    (setq i (1+ i)))
  (if (/= cur "") (setq out (append out (list cur))))
  out
)

(defun txt-wrap (just pt h rot maxWidth str /
                  words w line lines i cw lineW newW)
  ;;  Word-wrap str into lines of at most maxWidth (drawing units in mm)
  ;;  and emit them as stacked txt() calls below pt.  Estimated character
  ;;  width = 0.65 * h (romans-style).  maxWidth is taken AFTER the text
  ;;  scale is applied, so callers pass real-world cell width.
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setq cw (* 0.85 h *PEB-TEXT-SCALE*))     ; per-char width estimate (conservative)
  (setq words (split-on-space str))
  (setq lines '())  (setq line "")  (setq lineW 0.0)
  (foreach w words
    (setq newW (+ lineW (if (= line "") 0.0 cw) (* (strlen w) cw)))
    (if (and (/= line "") (> newW maxWidth))
      (progn
        (setq lines (append lines (list line)))
        (setq line w)
        (setq lineW (* (strlen w) cw)))
      (progn
        (if (= line "")
          (progn (setq line w) (setq lineW (* (strlen w) cw)))
          (progn (setq line (strcat line " " w)) (setq lineW newW)))
      )))
  (if (/= line "") (setq lines (append lines (list line))))
  ;; Draw each line stacked downward (1.2× line spacing)
  (setq i 0)
  (foreach lne lines
    (txt just (list (car pt)
                    (- (cadr pt) (* i (* 1.2 h *PEB-TEXT-SCALE*))))
         h rot lne)
    (setq i (1+ i)))
  ;; Return the number of lines emitted
  (length lines)
)

(defun dim-mm-ft (mm / ft)
  (setq ft (/ mm 304.8))
  (strcat (rtos mm 2 0) " mm|" (rtos ft 2 2) " ft")
)

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
  ;; ── Phase-2A user spec ───────────────────────────────────────────
  ;; DIMSCALE = 1 (rendered text = DIMTXT directly, no scale multiplier)
  ;; DIMTXT, DIMASZ = 800 (matches user-supplied LIST output reference)
  ;; Primary unit suffix removed (no " mm")
  ;; Alt unit format = Architectural (DIMALTU=4) for "feet'-inches"" style
  ;; DIMALTF 0.03937 = mm → inches conversion (then Arch format formats)
  ;; DIMALTRND 1.0 = round to nearest inch (no fractions)
  ;; DIMAPOST "[ ]" wraps alt in brackets → "8255 [27'-1\"]"
  ;; Phase-2A v4: DIMTXT bumped to 600 base for readable PDF print
  (setvar "DIMSCALE" (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0))
  (setvar "DIMTXT"   600.0)
  (setvar "DIMASZ"   600.0)
  (setvar "DIMEXE"   100.0)
  (setvar "DIMEXO"   100.0)
  (setvar "DIMGAP"    10.0)
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
  (setvar "DIMATFIT"    3)
  (setvar "DIMTMOVE"    0)
  (setvar "DIMALT"      1)
  (setvar "DIMALTF"     0.03937)         ; mm → inches
  (setvar "DIMALTRND"   1.0)              ; round to 1 inch
  (setvar "DIMALTD"     0)                ; integer inches
  (setvar "DIMALTU"     4)                ; Architectural (feet'-inches")
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
                              mlResult mtResult ptList elbow tX tY aX aY)
  ;;  Draw a labelled leader as a SINGLE MLEADER object (text + leader
  ;;  + arrow are one entity — drag any part and the rest follows).
  ;;
  ;;  leaderDir options:
  ;;    "S" : STRAIGHT 2-vertex leader (arrow tip → text). Cleanest look.
  ;;    "V" : 3-vertex L — vertical leg from arrow up/down to text-Y,
  ;;          then horizontal landing across to text.
  ;;    "H" : 3-vertex L — horizontal leg first, then vertical to text.
  (setq tX (car  labelPos))
  (setq tY (cadr labelPos))
  (setq aX (car  arrowPt))
  (setq aY (cadr arrowPt))
  (cond
    ((= leaderDir "S")
      ;; Straight 2-vertex leader — no elbow.
      (setq ptList (list arrowPt labelPos)))
    ((= leaderDir "V")
      (setq elbow (list aX tY))
      (setq ptList (list arrowPt elbow labelPos)))
    (T
      (setq elbow (list tX aY))
      (setq ptList (list arrowPt elbow labelPos)))
  )
  (setq mlResult
    (vl-catch-all-apply 'peb-make-mleader
                        (list ptList text)))
  (if (vl-catch-all-error-p mlResult)
    (progn
      ;; --- Fallback: MTEXT + L-leader (old behaviour) ---
      (setq mtResult
        (vl-catch-all-apply 'peb-make-mtext-line
                            (list labelPos fallbackTextHeight 0 "ML" text)))
      (if (vl-catch-all-error-p mtResult)
        (txt "ML" labelPos fallbackTextHeight 0 text))
      (draw-l-leader (car labelPos) (cadr labelPos)
                     (car arrowPt)  (cadr arrowPt)
                     leaderDir))
  )
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

;; TITLE-BLOCK FORMATTING RULES (shared with Plan.lsp): R1 body text height is
;; derived from the tallest merged cell's line count so nothing clips; R2 caps
;; merged cells at nBodyRows lines (MAIMAAR block condensed); R3 truncates long
;; single-line values; R4 header=middle-centre, body=top-left.
(defun peb-nlines (s / n i)
  (if (or (null s) (not (= (type s) 'STR))) 1
    (progn
      (setq n 1 i 0)
      (while (setq i (vl-string-search "\\P" s i))
        (setq n (1+ n) i (+ i 2)))
      n)))
(defun peb-fit-cell (s maxChars)
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
  ;; ── Phase-2A user spec ─────────────────────────────────────────
  ;; DIMSCALE = 1, DIMTXT = DIMASZ = 800 (matches user reference LIST).
  ;; Primary dim shows just the mm value (no " mm" suffix).
  ;; Alt unit format = Architectural ("[ X'-Y\" ]") — DIMALTU=4 + DIMALTF=0.03937.
  (peb-safe-setvar "DIMSCALE" (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0))
  (peb-safe-setvar "DIMTXT"   600.0)        ; Phase-2A v4: 600 base
  (peb-safe-setvar "DIMTXSTY" "PEB-TITLE")
  (peb-safe-setvar "DIMASZ"   600.0)        ; Phase-2A v4: 600 base
  (peb-safe-setvar "DIMEXE"   100.0)
  (peb-safe-setvar "DIMEXO"   100.0)
  (peb-safe-setvar "DIMGAP"    10.0)
  (peb-safe-setvar "DIMTAD"      0)         ; centered on dim line per ref
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
  ;; Alt units ON, Architectural format (mm → "X'-Y\"")
  (peb-safe-setvar "DIMALT"      1)
  (peb-safe-setvar "DIMALTF"     0.03937)   ; mm → inches
  (peb-safe-setvar "DIMALTRND"   1.0)       ; round to 1 inch (no fractions)
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
      (dim-line-h x1 x2 y
                  (if override
                    override
                    (dim-mm-ft (abs (- x2 x1)))))
      (setq newEnts (peb-collect-entities-since lastBefore))
      (peb-group-entities newEnts "PEBDIMH")))
)

(defun peb-dim-height-stretch (objX dimX y1 y2 override / lastBefore oldLayer newEnts result)
  ;;  Height dim — DIMLINEAR primary, grouped hand-rolled fallback.
  (setq lastBefore (entlast))
  (setq oldLayer   (getvar "CLAYER"))
  (peb-dim-set-vars)
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

(defun dim-mm-ft-overall (mm / ft)
  (setq ft (/ mm 304.8))
  (strcat (rtos mm 2 0) " mm (OVERALL)|" (rtos ft 2 2) " ft")
)

(defun split-dim-label (label / pos)
  (setq pos (vl-string-search "|" label))
  (if pos
    (list (substr label 1 pos) (substr label (+ pos 2)))
    (list label "")
  )
)

(defun dim-arrow-h (x y dir / a b)
  (setq a (* 260 *PEB-DIM-SCALE*))
  (setq b (* 120 *PEB-DIM-SCALE*))
  (if (= dir "R")
    (command "PLINE" (list x y) (list (+ x a) (+ y b)) (list (+ x a) (- y b)) "C")
    (command "PLINE" (list x y) (list (- x a) (+ y b)) (list (- x a) (- y b)) "C")
  )
  (command "HATCH" "SOLID" "L" "")
)

(defun dim-arrow-v (x y dir / a b)
  (setq a (* 260 *PEB-DIM-SCALE*))
  (setq b (* 120 *PEB-DIM-SCALE*))
  (if (= dir "U")
    (command "PLINE" (list x y) (list (- x b) (+ y a)) (list (+ x b) (+ y a)) "C")
    (command "PLINE" (list x y) (list (- x b) (- y a)) (list (+ x b) (- y a)) "C")
  )
  (command "HATCH" "SOLID" "L" "")
)

(defun dim-line-h (x1 x2 y label / parts mmTxt ftTxt mid extLen)
  ;;  ACTIVE — hand-rolled horizontal dim with witness/extension lines.
  ;;  Builds the dim from primitives (LINE + LINE + LINE + 2× arrow
  ;;  PLINE-and-HATCH + 2× TEXT).  Not stretchable as a unit, but
  ;;  reliably renders across all AutoCAD versions.  Native-dim helpers
  ;;  peb-dim-h-native etc. exist above but are not currently called.
  (setvar "CLAYER" "DIMENSIONS")
  (setvar "PLINEWID" 0.0)
  (setq parts (split-dim-label label))
  (setq mmTxt (car parts))
  (setq ftTxt (cadr parts))
  (setq mid (/ (+ x1 x2) 2.0))
  (setq extLen (* 100 *PEB-DIM-SCALE*))
  ;; Extension lines from object (y=0 = FFL) to past dim line
  (command "LINE" (list x1 0.0) (list x1 (- y extLen)) "")
  (command "LINE" (list x2 0.0) (list x2 (- y extLen)) "")
  ;; Dimension line + arrows on both ends
  (command "LINE" (list x1 y) (list x2 y) "")
  (dim-arrow-h x1 y "R")
  (dim-arrow-h x2 y "L")
  ;; Text
  (txt-dim "MC" (list mid (+ y (* 360 *PEB-DIM-SCALE*))) 300 0 mmTxt)
  (if (/= ftTxt "") (txt-dim "MC" (list mid (- y (* 360 *PEB-DIM-SCALE*))) 280 0 ftTxt))
)

(defun dim-line-v (x y1 y2 label / parts mmTxt ftTxt midY textX)
  (setvar "CLAYER" "DIMENSIONS")
  (setq parts (split-dim-label label))
  (setq mmTxt (car parts))
  (setq ftTxt (cadr parts))
  (setq midY (/ (+ y1 y2) 2.0))
  (setq textX (- x (* 500 *PEB-DIM-SCALE*)))
  (command "LINE" (list x y1) (list x y2) "")
  (dim-arrow-v x y1 "U")
  (dim-arrow-v x y2 "D")
  (txt-dim "MC" (list textX midY) 300 90 mmTxt)
  (if (/= ftTxt "") (txt-dim "MC" (list (+ textX (* 650 *PEB-DIM-SCALE*)) midY) 280 90 ftTxt))
)

(defun draw-border (x1 y1 x2 y2 / margin)
  (setq margin (* 800 *PEB-TEXT-SCALE*))
  (setvar "CLAYER" "BORDER")
  (command "RECTANG" (list (- x1 margin) (- y1 margin)) (list (+ x2 margin) (+ y2 margin)))
  (command "RECTANG" (list (- x1 (* margin 0.6)) (- y1 (* margin 0.6))) (list (+ x2 (* margin 0.6)) (+ y2 (* margin 0.6))))
)

;; ===================== SECTION DRAWING HELPERS =====================

(defun compute-section-layout (data stype W /
                                cols ridges numMod numGab spanPerGab gW
                                i sp cum modw)
  ;;  Returns a list (cols ridges) where:
  ;;    cols   = sorted list of column X positions (length >= 2)
  ;;    ridges = sorted list of ridge X positions  (length = N gables)
  ;;
  ;;  For CS:        (cols ridges) = ((0 W) (W/2))
  ;;  For MS:        cols from B53..B62 cumulative widths, single ridge at W/2.
  ;;  For MG:        cols at equal-width gable boundaries, ridge at each gable centre.
  (cond
    ((= stype "MS")
      (setq numMod (MSPL-Get-Int data "NUMMODULES"))
      (if (or (null numMod) (< numMod 1)) (setq numMod 2))
      (if (> numMod 10) (setq numMod 10))
      (setq cols (list 0.0)  cum 0.0  i 0)
      (while (< i numMod)
        (setq modw (MSPL-Get-Num data (strcat "MODULE" (itoa (1+ i)))))
        (cond
          ((= i (1- numMod)) (setq sp (- W cum)))
          ((and modw (> modw 0)) (setq sp modw))
          (T (setq sp (/ (- W cum) (- numMod i)))))
        (setq cum (+ cum sp))
        (setq cols (append cols (list cum)))
        (setq i (1+ i)))
      (list cols (list (/ W 2.0))))

    ((= stype "MG")
      (setq numGab (MSPL-Get-Int data "NUMGABLES"))
      (if (or (null numGab) (< numGab 1)) (setq numGab 2))
      (setq spanPerGab (MSPL-Get-Int data "SPANSPERGABLE"))
      (if (or (null spanPerGab) (< spanPerGab 1)) (setq spanPerGab 1))
      (setq gW (/ W numGab))
      ;; Generate columns at every sub-span boundary (matches plan view).
      ;; For numGab=2, spanPerGab=1: cols at 0, W/2, W (3 cols)
      ;; For numGab=2, spanPerGab=2: cols at 0, W/4, W/2, 3W/4, W (5 cols)
      (setq cols '())
      (setq i 0)
      (while (<= i (* numGab spanPerGab))
        (setq cols (append cols (list (* i (/ gW spanPerGab)))))
        (setq i (1+ i)))
      ;; Ridges remain at gable centres (one per gable)
      (setq ridges '())
      (setq i 0)
      (while (< i numGab)
        (setq ridges (append ridges (list (+ (* i gW) (/ gW 2.0)))))
        (setq i (1+ i)))
      (list cols ridges))

    ((= stype "SS")
      ;; Single slope: 2 columns at LOW and HIGH ends, no ridge in middle.
      ;; Empty ridges list signals SS to the polygon builder.
      (list (list 0.0 W) '()))

    ((= stype "RC")
      ;; Roof system on Reinforced Concrete columns.
      ;; Same gable layout as CS but columns drawn separately as
      ;; concrete rectangles (handled in main draw flow).
      (list (list 0.0 W) (list (/ W 2.0))))

    ((= stype "ACS")
      ;; Arched Clear Span — 2 columns, "ridge" at apex (W/2)
      (list (list 0.0 W) (list (/ W 2.0))))

    ((= stype "AMS")
      ;; Arched Multi-Span 1 — 3 columns at 0, W/2, W; two arches
      ;; with apexes at the quarter-points. Ridges = peak X (= W/2)
      ;; for grid bubble + dim purposes.
      (list (list 0.0 (/ W 2.0) W) (list (/ W 2.0))))

    (T   ; CS (clear span gable) and any unrecognized stype
      (list (list 0.0 W) (list (/ W 2.0))))
  )
)

(defun cigar-taper-lengths (gableSpan / kneeL ridgeL)
  ;;  Returns (list kneeL ridgeL) for a gable rafter of given span (xR-xL).
  ;;  Single source of truth — called from BOTH build-frame-polygon (the
  ;;  rafter outline) AND draw-rafter-stiffeners (the splice plates).  By
  ;;  routing both through this helper, the cigar transition X positions
  ;;  the polygon shows and the plate X positions are guaranteed identical
  ;;  for any building W and H.
  ;;
  ;;  Formula: kneeL = ridgeL = linear ramp 3000mm at 15m span up to 6500mm
  ;;  at 50m span, clamped to [3000, 6500].
  (setq kneeL  (max 3000.0 (min 6500.0 (+ 3000.0 (* (/ (- gableSpan 15000.0) 35000.0) 3500.0)))))
  (setq ridgeL kneeL)
  (list kneeL ridgeL)
)

(defun rafter-underside-points (xL xR ridgeX H rise ht rd midD kneeL ridgeL /
                                 sl slLen sa ca kneeXp kneeYp ridgeXp ridgeYp pts)
  ;;  Returns the 4 inner-edge points along ONE rafter going from
  ;;  the LEFT haunch (xL+ht, H) up over the ridge (ridgeX) and back
  ;;  down to the RIGHT haunch (xR-ht, H).
  ;;
  ;;  The rafter has three zones, matching MAIMAAR PEB practice:
  ;;    knee taper  (kneeL mm along slope) - depth drops ht -> midD
  ;;    middle      (constant depth midD)
  ;;    ridge taper (ridgeL mm along slope) - depth rises midD -> rd
  ;;
  ;;  Returns (going LEFT-to-RIGHT-to-LEFT under the rafter):
  ;;    (left-knee-end  ridge-left-taper-start  ridge-bottom
  ;;     ridge-right-taper-start  right-knee-end)
  (setq sl    (- ridgeX xL))                    ; horizontal half-span
  (setq slLen (sqrt (+ (* sl sl) (* rise rise)))) ; full slope length
  (setq sa    (/ rise slLen))                    ; sin(slope angle)
  (setq ca    (/ sl   slLen))                    ; cos(slope angle)
  ;; If half-rafter is too short for both tapers, shrink them.
  (if (> (+ kneeL ridgeL) (* slLen 0.85))
    (progn
      (setq kneeL  (* slLen 0.40))
      (setq ridgeL (* slLen 0.40))
    )
  )
  ;; LEFT knee-taper END point
  (setq kneeXp (* kneeL ca))
  (setq kneeYp (* kneeL sa))
  ;; LEFT ridge-taper START point
  (setq ridgeXp (* ridgeL ca))
  (setq ridgeYp (* ridgeL sa))
  (list
    ;; left side knee-end (depth = midD), measured down from rafter top
    (list (+ xL kneeXp)              (- (+ H kneeYp)            midD))
    ;; left side ridge-start (depth = midD)
    (list (- ridgeX ridgeXp)         (- (+ H rise (- 0 ridgeYp)) midD))
    ;; ridge bottom (depth = rd)
    (list ridgeX                     (+ H rise (- 0 rd)))                ; ridge bottom (depth = rd)
    (list (+ ridgeX ridgeXp)         (- (+ H rise (- 0 ridgeYp)) midD))
    ;; right side knee-end (depth = midD), mirror of left knee-end
    (list (- xR kneeXp)              (- (+ H kneeYp)            midD))
  )
)

(defun cigar-rafter-underside-y (x xL xR ridgeX H rise ht rd midD kneeL ridgeL /
                                   sl slLen sa ca kneeXp kneeYp ridgeXp ridgeYp
                                   xa xb ya yb f)
  ;;  Returns the Y coordinate of the rafter UNDERSIDE at horizontal x for
  ;;  a gable spanning xL..xR with apex at ridgeX.  The rafter has three
  ;;  zones per half (matching the polygon built by build-frame-polygon
  ;;  via rafter-underside-points):
  ;;
  ;;    haunch corner -> knee-end : straight line  (knee taper zone)
  ;;    knee-end      -> ridge-start : straight line on slope - midD  (constant middle)
  ;;    ridge-start   -> ridge-bottom : straight line  (ridge taper zone)
  ;;
  ;;  If x falls inside the column body (i.e. between xL and xL+ht on the
  ;;  left, or xR-ht and xR on the right) the helper returns the haunch
  ;;  corner Y (= H-ht) since that is the column-top reference there.
  ;;
  ;;  Used by draw-ms-frame so that interior column rectangles land
  ;;  exactly on the polygon rafter underside even when they fall in the
  ;;  knee or ridge taper zones - no punch-through, no gaps.
  (setq sl    (- ridgeX xL))
  (setq slLen (sqrt (+ (* sl sl) (* rise rise))))
  (setq sa    (/ rise slLen))
  (setq ca    (/ sl   slLen))
  ;; Mirror the auto-shrink rule from rafter-underside-points so the
  ;; helper's segments line up with the polygon for narrow gables.
  (if (> (+ kneeL ridgeL) (* slLen 0.85))
    (progn
      (setq kneeL  (* slLen 0.40))
      (setq ridgeL (* slLen 0.40))))
  (setq kneeXp  (* kneeL  ca))
  (setq kneeYp  (* kneeL  sa))
  (setq ridgeXp (* ridgeL ca))
  (setq ridgeYp (* ridgeL sa))
  (cond
    ;; ── LEFT half: x ∈ [xL, ridgeX] ──────────────────────────────────
    ((<= x ridgeX)
      (cond
        ;; Column body region: return the haunch-corner Y (rafter "begins"
        ;; at xL+ht on the inside).
        ((<= x (+ xL ht))
          (- H ht))
        ;; Knee taper zone: straight line from haunch corner to knee-end.
        ((<= x (+ xL kneeXp))
          (setq xa (+ xL ht))
          (setq xb (+ xL kneeXp))
          (setq ya (- H ht))
          (setq yb (- (+ H kneeYp) midD))
          (setq f  (/ (- x xa) (- xb xa)))
          (+ ya (* f (- yb ya))))
        ;; Constant-middle zone: rafter top follows slope, depth = midD.
        ((<= x (- ridgeX ridgeXp))
          (- (+ H (* rise (/ (- x xL) sl))) midD))
        ;; Left ridge-taper zone: straight line up to ridge bottom.
        (T
          (setq xa (- ridgeX ridgeXp))
          (setq xb ridgeX)
          (setq ya (- (+ H rise (- 0 ridgeYp)) midD))
          (setq yb (+ H rise (- 0 rd)))
          (setq f  (/ (- x xa) (- xb xa)))
          (+ ya (* f (- yb ya))))))
    ;; ── RIGHT half: x ∈ (ridgeX, xR] ─────────────────────────────────
    (T
      (cond
        ;; Column body region (right end column): haunch-corner Y.
        ((>= x (- xR ht))
          (- H ht))
        ;; Right knee taper zone (mirror of left).
        ((>= x (- xR kneeXp))
          (setq xa (- xR kneeXp))
          (setq xb (- xR ht))
          (setq ya (- (+ H kneeYp) midD))
          (setq yb (- H ht))
          (setq f  (/ (- x xa) (- xb xa)))
          (+ ya (* f (- yb ya))))
        ;; Right constant-middle zone.
        ((>= x (+ ridgeX ridgeXp))
          (- (+ H (* rise (/ (- xR x) sl))) midD))
        ;; Right ridge-taper zone (mirror of left).
        (T
          (setq xa ridgeX)
          (setq xb (+ ridgeX ridgeXp))
          (setq ya (+ H rise (- 0 rd)))
          (setq yb (- (+ H rise (- 0 ridgeYp)) midD))
          (setq f  (/ (- x xa) (- xb xa)))
          (+ ya (* f (- yb ya)))))))
)

(defun ms-col-web (modW)
  ;;  Returns interior column web depth based on the module width feeding
  ;;  the column.  Linear ramp 300 mm at 15 m module up to 600 mm at 35 m
  ;;  module, clamped to [300, 600].
  ;;
  ;;  | module | web |
  ;;  |--------|-----|
  ;;  | ≤15 m  | 300 |
  ;;  | 25 m   | 450 |
  ;;  | ≥35 m  | 600 |
  (max 300.0 (min 600.0 (+ 300.0 (* (/ (- modW 15000.0) 20000.0) 300.0))))
)

(defun ms-col-web-at (cols i / leftMod rightMod)
  ;;  Returns the web depth for cols[i] in an MS layout, sized from the
  ;;  LARGER of the two flanking module widths (conservative — the wider
  ;;  module's tributary load drives the column).  For end columns
  ;;  (i = 0 or i = n-1) returns nil because end columns are tapered
  ;;  (cb at base, ht at top) and don't use intColW.
  (cond
    ((or (= i 0) (= i (1- (length cols)))) nil)
    (T
      (setq leftMod  (- (nth i cols) (nth (1- i) cols)))
      (setq rightMod (- (nth (1+ i) cols) (nth i cols)))
      (ms-col-web (max leftMod rightMod))))
)

(defun draw-ms-interior-plates (cols W H rise ht rd ep msApexX /
                                 ridgeX midD kneeL ridgeL boltR
                                 i n x colWeb halfW colTopY
                                 upTopY upBotY loTopY loBotY
                                 outerX innerX ext stiffH)
  ;;  Connection plates at the TOP of every MS interior column, where the
  ;;  rafter underside sits on the column flange.  Two horizontal plates
  ;;  (upper = rafter end-plate, lower = column end-plate), bolts at the
  ;;  interface, and stiffener triangles at each plate end.  Skips the
  ;;  column at msApexX (ridge column — handled by draw-mg-ridge-col-plates).
  ;;
  ;;  Differs from draw-haunch-plates' interior branch in two ways
  ;;  required by MS:
  ;;    1. Plate Y is the actual cigar-rafter underside at the column's x,
  ;;       not the fixed haunch elevation H-ht.
  ;;    2. Plate width tracks the column web (300-600 mm based on module
  ;;       width via ms-col-web-at) plus 100 mm extension each side.
  (setvar "CLAYER" "PLATES")
  (setq ridgeX (/ W 2.0))
  (setq midD   (max 300.0 (min 500.0 (- (* ht 0.5) 50.0))))
  (setq kneeL  (car  (cigar-taper-lengths W)))
  (setq ridgeL (cadr (cigar-taper-lengths W)))
  (setq boltR  (* 25 *PEB-TEXT-SCALE*))
  (setq ext    100.0)              ; plate extension beyond column flange
  (setq stiffH 100.0)
  (setq n (length cols))
  (setq i 1)
  (while (< i (1- n))
    (setq x (nth i cols))
    (cond
      ;; Skip the ridge column — draw-mg-ridge-col-plates handles it.
      ((and msApexX (< (abs (- x msApexX)) 1.0)) nil)
      (T
        (setq colWeb (ms-col-web-at cols i))
        (setq halfW  (/ colWeb 2.0))
        ;; Cigar-aware rafter underside Y = column top elevation here.
        (setq colTopY (cigar-rafter-underside-y
                        x 0.0 W ridgeX H rise ht rd midD kneeL ridgeL))
        (setq upTopY colTopY)                 ; upper plate top edge
        (setq upBotY (- colTopY ep))          ; upper plate bottom = bolt line
        (setq loTopY upBotY)                  ; lower plate top = bolt line
        (setq loBotY (- upBotY ep))           ; lower plate bottom edge
        (setq outerX (- x halfW ext))         ; plate left  = col flange − ext
        (setq innerX (+ x halfW ext))         ; plate right = col flange + ext
        ;; Upper (rafter) plate
        (command "RECTANG" (list outerX upBotY) (list innerX upTopY))
        ;; Lower (column) plate
        (command "RECTANG" (list outerX loBotY) (list innerX loTopY))
        ;; Six bolts at the interface, three each side of column centre
        (command "DONUT" 0 (* boltR 2) (list (- x (* halfW 0.85)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (- x (* halfW 0.50)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (- x (* halfW 0.15)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (+ x (* halfW 0.15)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (+ x (* halfW 0.50)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (+ x (* halfW 0.85)) upBotY) "")
        ;; Outer-end stiffeners — vertical at column flange (x±halfW),
        ;; hypotenuse extends OUT to the plate end.
        (draw-stiff-top (- x halfW) upTopY ext stiffH -1)
        (draw-stiff-bot (- x halfW) loBotY ext stiffH -1)
        (draw-stiff-top (+ x halfW) upTopY ext stiffH  1)
        (draw-stiff-bot (+ x halfW) loBotY ext stiffH  1)))
    (setq i (1+ i)))
)

(defun build-frame-polygon (cols ridges H rise ht rd cb /
                             pts colN ridgeN i lastCol curCol intColW
                             midD kneeL ridgeL rPts xL xR rxC
                             topProfile c r p isAtRidge isAtCol)
  ;;  Build a list of (x y) point lists describing the closed
  ;;  multi-span frame outline.  Outer boundary goes left->right,
  ;;  inner boundary right->left, with multi-segment rafter underside
  ;;  (knee taper + constant middle + ridge taper) per gable.
  ;;
  ;;  END columns:      outside face vertical, inside face tapered (cb at base, ht at top).
  ;;  INTERIOR columns: rectangular intColW wide, no taper.
  ;;  RAFTER cigar:     deep at knee (ht), tapers to midD constant in middle, taper to rd at ridge.
  (setq intColW 400.0)
  (setq midD    (max 300.0 (min 500.0 (- (* ht 0.5) 50.0))))   ; mid depth: 300-500mm linear with ht
  ;; kneeL and ridgeL now computed PER GABLE inside the foreach loop based on gable span
  (setq colN (length cols))
  (setq ridgeN (length ridges))
  (setq pts '())

  ;; --- Outer boundary, left to right ---
  ;; Build a sorted "rafter top profile" from cols + ridges.
  ;; If a col coincides with a ridge, that col extends UP to ridge top
  ;; (H + rise) instead of eave (H), avoiding degenerate edges.
  (setq pts (append pts (list (list (car cols) 0.0))))   ; bottom-left
  (setq topProfile '())
  ;; First, add each col with its top y (H or H+rise if at a ridge)
  (foreach c cols
    (setq isAtRidge nil)
    (foreach r ridges
      (if (equal c r 0.001) (setq isAtRidge T)))
    (setq topProfile
          (append topProfile
                  (list (list c (if isAtRidge (+ H rise) H))))))
  ;; Then add ridges not at any col
  (foreach r ridges
    (setq isAtCol nil)
    (foreach c cols
      (if (equal r c 0.001) (setq isAtCol T)))
    (if (not isAtCol)
      (setq topProfile (append topProfile (list (list r (+ H rise)))))))
  ;; Sort the combined profile by x
  (setq topProfile
        (vl-sort topProfile
                 (function (lambda (a b) (< (car a) (car b))))))
  ;; Append every profile point to outer polygon
  (foreach p topProfile
    (setq pts (append pts (list p))))
  ;; bottom-right corner
  (setq lastCol (nth (1- colN) cols))
  (setq pts (append pts (list (list lastCol 0.0))))

  ;; --- Inner boundary, right to left ---
  ;; right column inside-base
  (setq pts (append pts (list (list (- lastCol cb) 0.0))))
  ;; right column inside-top, dropped by ht so the haunch shows real
  ;; vertical depth (deep at the eave, narrowing into the rafter).
  (setq pts (append pts (list (list (- lastCol ht) (- H ht)))))

  ;; Walk through gables in reverse (from right to left).
  ;; For each gable: emit the multi-segment rafter underside
  ;; (right-knee-end, right-ridge-start, ridge-bottom, left-ridge-start, left-knee-end).
  ;; Between gables: zigzag down/up around the interior column.
  (setq i (1- ridgeN))
  (while (>= i 0)
    (setq rxC (nth i ridges))
    ;; bounding columns of this gable
    (setq xL (nth i cols))
    (setq xR (nth (1+ i) cols))
    ;; --- Variable knee/ridge taper lengths based on gable span ---
    ;; Both polygon and plates use the SAME helper for taper lengths so
    ;; they can never diverge.
    (setq kneeL  (car  (cigar-taper-lengths (- xR xL))))
    (setq ridgeL (cadr (cigar-taper-lengths (- xR xL))))
    ;; Get rafter underside points for THIS gable.
    ;; The function returns points oriented LEFT-to-RIGHT under the rafter
    ;; (left-knee-end, left-ridge-start, ridge-bottom, right-ridge-start, right-knee-end).
    ;; Since we're traversing the inner boundary RIGHT to LEFT, we reverse them.
    (setq rPts (rafter-underside-points xL xR rxC H rise ht rd midD kneeL ridgeL))
    ;; Append in reverse: right-knee-end, right-ridge-start, ridge-bottom, left-ridge-start, left-knee-end
    (setq pts (append pts (list (nth 4 rPts))))
    (setq pts (append pts (list (nth 3 rPts))))
    (setq pts (append pts (list (nth 2 rPts))))
    (setq pts (append pts (list (nth 1 rPts))))
    (setq pts (append pts (list (nth 0 rPts))))

    ;; If this isn't the leftmost gable, there's an interior column to walk around.
    (if (> i 0)
      (progn
        (setq curCol (nth i cols))
        ;; right haunch corner of this column (DEEP, at H-ht)
        (setq pts (append pts (list (list (+ curCol (/ ht 2.0)) (- H ht)))))
        ;; step inward to rectangular column outer edge at top of column body
        (setq pts (append pts (list (list (+ curCol (/ intColW 2.0)) (- H ht)))))
        ;; rectangular column: vertical right face down to base
        (setq pts (append pts (list (list (+ curCol (/ intColW 2.0)) 0.0))))
        ;; across base
        (setq pts (append pts (list (list (- curCol (/ intColW 2.0)) 0.0))))
        ;; rectangular column: vertical left face up to top of column body
        (setq pts (append pts (list (list (- curCol (/ intColW 2.0)) (- H ht)))))
        ;; left haunch corner of this column (DEEP, at H-ht)
        (setq pts (append pts (list (list (- curCol (/ ht 2.0)) (- H ht)))))
      )
    )
    (setq i (1- i)))

  ;; left column inside-top, dropped by ht so the haunch shows real
  ;; vertical depth (deep at the eave, narrowing into the rafter).
  (setq pts (append pts (list (list ht (- H ht)))))
  ;; left column inside-base
  (setq pts (append pts (list (list cb 0.0))))

  pts
)

(defun draw-frame-outline (cols ridges H rise ht rd cb / pts)
  ;;  Draw the multi-span frame outline as a single closed PLINE,
  ;;  feeding the variable-length point list one vertex at a time.
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (setq pts (build-frame-polygon cols ridges H rise ht rd cb))
  (command "PLINE")
  (foreach p pts (command p))
  (command "C")
)

(defun build-ss-polygon (W H slopeRise ht cb)
  ;;  Single Slope (mono-slope) frame outline.
  ;;  LOW column on left (eave at H), HIGH column on right (eave at H+slopeRise).
  ;;  One continuous rafter sloping from low to high.
  (list
    (list 0.0          0.0)                          ; 1 bottom-left outside
    (list 0.0          H)                             ; 2 low eave outside
    (list W            (+ H slopeRise))               ; 3 high eave outside
    (list W            0.0)                           ; 4 bottom-right outside
    (list (- W cb)     0.0)                           ; 5 right column inside-base
    (list (- W ht)     (- (+ H slopeRise) ht))        ; 6 right haunch (high side)
    (list ht           (- H ht))                      ; 7 left haunch (low side)
    (list cb           0.0)                           ; 8 left column inside-base
  )
)

(defun draw-ss-frame (W H slopeRise ht cb / pts)
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (setq pts (build-ss-polygon W H slopeRise ht cb))
  (command "PLINE")
  (foreach p pts (command p))
  (command "C")
)

(defun draw-rcc-columns (cols H rccW)
  ;;  RCC (Reinforced Concrete) columns drawn as filled rectangles
  ;;  with concrete hatch pattern (AR-CONC).
  ;;  Used for stype = RC.
  (setvar "CLAYER" "RCC-COLUMN")
  (foreach x cols
    (cond
      ;; LEFT end column: outside flush at x=0
      ((equal x (car cols) 0.001)
        (command "RECTANG" (list x 0.0) (list (+ x rccW) H))
        (command "HATCH" "AR-CONC" 25 0 "L" "")
      )
      ;; RIGHT end column: outside flush at x=W
      ((equal x (last cols) 0.001)
        (command "RECTANG" (list (- x rccW) 0.0) (list x H))
        (command "HATCH" "AR-CONC" 25 0 "L" "")
      )
      ;; Interior column (centred)
      (T
        (command "RECTANG"
          (list (- x (/ rccW 2.0)) 0.0)
          (list (+ x (/ rccW 2.0)) H))
        (command "HATCH" "AR-CONC" 25 0 "L" "")
      )
    )
  )
)

(defun build-rc-rafter-polygon (W H rise ht rd)
  ;;  Just the steel rafter (gable shape) for buildings on RCC columns.
  ;;  Rafter sits ON TOP of concrete columns at eave height H.
  (list
    (list 0.0       H)                       ; left eave outside (rafter top)
    (list (/ W 2.0) (+ H rise))              ; ridge top
    (list W         H)                       ; right eave outside
    (list (- W ht)  (- H ht))                ; right haunch corner
    (list (/ W 2.0) (+ H rise (- 0 rd)))     ; ridge bottom
    (list ht        (- H ht))                ; left haunch corner
  )
)

(defun draw-rc-frame (W H rise ht rd / pts rccW)
  ;;  Draw RCC columns + steel rafter (separate entities).
  (setq rccW 500.0)        ; typical RCC column width (mm)
  (draw-rcc-columns (list 0.0 W) (- H ht) rccW)   ; columns end at haunch knee
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (setq pts (build-rc-rafter-polygon W H rise ht rd))
  (command "PLINE")
  (foreach p pts (command p))
  (command "C")
)

(defun draw-mg-frame (W H rise ht rd cb numGab spanPerGab /
                       gW gap i j gxL gxR midX rxC subSpanW intColW
                       midD kneeL ridgeL rPts vXL vXR k subX subColH)
  ;;  Multi-Gable: each gable is drawn as an independent CS-like polygon.
  ;;  Adjacent gables have a small gap (300 mm) with a valley gutter.
  ;;  Within each gable, if spanPerGab > 1 there are intermediate columns
  ;;  at sub-span boundaries (same convention as plan code).
  (setq gap 300.0)
  (setq gW (/ (- W (* (1- numGab) gap)) numGab))
  (setq subSpanW (/ gW spanPerGab))
  (setq midD (max 300.0 (min 500.0 (- (* ht 0.5) 50.0))))
  (setq kneeL  (car  (cigar-taper-lengths gW)))   ; per-gable, via shared helper
  (setq ridgeL (cadr (cigar-taper-lengths gW)))
  (setq intColW 400.0)

  (setq i 0)
  (while (< i numGab)
    (setq gxL (* i (+ gW gap)))           ; this gable's LEFT outer x
    (setq gxR (+ gxL gW))                 ; this gable's RIGHT outer x
    (setq midX (/ (+ gxL gxR) 2.0))       ; gable centre = ridge x

    ;; Cigar rafter underside points within this gable
    (setq rPts (rafter-underside-points gxL gxR midX H rise ht rd midD kneeL ridgeL))

    ;; Closed polygon for this gable (CS-style with cigar rafter)
    (setvar "CLAYER" "FRAME")
    (command "PLINE"
      (list gxL 0.0)                              ; bottom-left outside
      (list gxL H)                                 ; eave-left outside
      (list midX (+ H rise))                       ; ridge top
      (list gxR H)                                 ; eave-right outside
      (list gxR 0.0)                               ; bottom-right outside
      (list (- gxR cb) 0.0)                        ; right column inside-base
      (list (- gxR ht) (- H ht))                   ; right haunch corner
      (nth 4 rPts)                                  ; right knee end
      (nth 3 rPts)                                  ; right ridge start
      (nth 2 rPts)                                  ; ridge bottom
      (nth 1 rPts)                                  ; left ridge start
      (nth 0 rPts)                                  ; left knee end
      (list (+ gxL ht) (- H ht))                   ; left haunch corner
      (list (+ gxL cb) 0.0)                        ; left column inside-base
      "C")

    ;; Intermediate columns within gable (for spanPerGab > 1)
    (if (> spanPerGab 1)
      (progn
        (setq j 1)
        (while (< j spanPerGab)
          (setq subX (+ gxL (* j subSpanW)))
          ;; Compute rafter underside Y at subX
          (cond
            ((< subX midX)
              (setq subColH (- (+ H (* rise (/ (- subX gxL) (- midX gxL)))) midD)))
            ((> subX midX)
              (setq subColH (- (+ H (* rise (/ (- gxR subX) (- gxR midX)))) midD)))
            (T
              (setq subColH (+ H rise (- 0 rd)))))
          (command "RECTANG"
            (list (- subX (/ intColW 2.0)) 0.0)
            (list (+ subX (/ intColW 2.0)) subColH))
          (setq j (1+ j)))))

    ;; Valley gutter between this gable and the NEXT (if not last)
    (if (< i (1- numGab))
      (progn
        (setq vXL gxR)                               ; right edge of this gable
        (setq vXR (+ gxR gap))                       ; left edge of next gable
        (setvar "CLAYER" "GUTTER")
        ;; V-shape valley gutter at the eave level (water collects here)
        (command "PLINE"
          (list vXL H)                               ; top-left
          (list (/ (+ vXL vXR) 2.0) (- H 250))       ; bottom of V (centre)
          (list vXR H)                               ; top-right
          "")
        ;; "VALLEY GUTTER" leader label
        (setvar "CLAYER" "TEXT")
        (txt "MC"
          (list (/ (+ vXL vXR) 2.0) (+ H (* 1500 *PEB-TEXT-SCALE*)))
          200 0 "VALLEY GUTTER")))

    (setq i (1+ i)))
)

(defun draw-mg-multi-frame (W H rise ht rd cb numGab spanPerGab /
                            gW i j subX subColH midD intColW
                            mainCols mainRidges ridgeX gxL gxR)
  ;;  Multi-Gable with sub-spans.  Strategy: draw the BASE multi-gable
  ;;  outline using the proven draw-frame-outline (with gable-boundary
  ;;  cols and per-gable ridges).  Then add intermediate sub-span
  ;;  columns as plain rectangles rising up to the rafter underside.
  (setq gW      (/ W numGab))
  (setq midD    (max 300.0 (min 500.0 (- (* ht 0.5) 50.0))))
  (setq intColW 400.0)

  ;; Build base column list: 0, gW, 2gW, ..., W  (one col per gable boundary)
  (setq mainCols '())
  (setq i 0)
  (while (<= i numGab)
    (setq mainCols (append mainCols (list (* i gW))))
    (setq i (1+ i)))

  ;; Build ridge list: gW/2, 3gW/2, 5gW/2, ...  (one ridge per gable)
  (setq mainRidges '())
  (setq i 0)
  (while (< i numGab)
    (setq mainRidges (append mainRidges (list (+ (* i gW) (/ gW 2.0)))))
    (setq i (1+ i)))

  ;; Draw the proven multi-span outline (handles cigar rafter, haunches, columns)
  (draw-frame-outline mainCols mainRidges H rise ht rd cb)

  ;; Intermediate sub-span columns (only when spanPerGab > 1)
  (if (> spanPerGab 1)
    (progn
      (setvar "CLAYER" "FRAME")
      (setq i 0)
      (while (< i numGab)
        (setq gxL    (* i gW))
        (setq gxR    (+ gxL gW))
        (setq ridgeX (+ gxL (/ gW 2.0)))
        (setq j 1)
        (while (< j spanPerGab)
          (setq subX (+ gxL (* j (/ gW spanPerGab))))
          ;; Rafter underside Y at subX
          (cond
            ((equal subX ridgeX 0.001)
              (setq subColH (+ H rise (- 0 rd))))
            ((< subX ridgeX)
              (setq subColH (- (+ H (* rise (/ (- subX gxL) (- ridgeX gxL)))) midD)))
            (T
              (setq subColH (- (+ H (* rise (/ (- gxR subX) (- gxR ridgeX)))) midD))))
          (command "RECTANG"
            (list (- subX (/ intColW 2.0)) 0.0)
            (list (+ subX (/ intColW 2.0)) subColH))
          (setq j (1+ j)))
        (setq i (1+ i)))))
)

(defun draw-ms-frame (cols W H rise ht rd cb /
                       midD i x rafterY ridgeX numCols
                       kneeL ridgeL thisColW halfW)
  ;;  Multi-Span: single big rafter spanning full width with one ridge
  ;;  at centre, end columns at left/right, INTERMEDIATE columns at
  ;;  module boundaries rising up to the rafter underside.
  ;;
  ;;  Draws:
  ;;    1. Outer gable polygon (just end columns + cigar rafter)
  ;;    2. Each intermediate column as a separate rectangle from
  ;;       FFL up to the rafter underside at that x.  Each column's web
  ;;       is sized from its flanking module widths (300 mm at 15 m
  ;;       module → 600 mm at 35 m module, via ms-col-web-at).
  ;;
  ;;  Column-top elevations come from cigar-rafter-underside-y so they
  ;;  land EXACTLY on the polygon's rafter underside in any of the three
  ;;  zones (knee taper, constant middle, ridge taper).  Without this,
  ;;  columns near the haunches punch through the rafter and columns in
  ;;  the ridge-taper zone leave a gap.
  (setq ridgeX  (/ W 2.0))
  (setq midD    (max 300.0 (min 500.0 (- (* ht 0.5) 50.0))))
  (setq numCols (length cols))
  ;; SHARED cigar taper lengths for the full-width rafter — same helper
  ;; the polygon uses, so taper transitions match.
  (setq kneeL  (car  (cigar-taper-lengths W)))
  (setq ridgeL (cadr (cigar-taper-lengths W)))

  ;; --- Outer frame: simple gable shape with cigar rafter ---
  ;; Use the existing build-frame-polygon with just 2 end cols + 1 ridge
  (draw-frame-outline (list 0.0 W) (list ridgeX) H rise ht rd cb)

  ;; --- Intermediate columns (web sized from larger flanking module) ---
  (setvar "CLAYER" "FRAME")
  (setq i 1)
  (while (< i (1- numCols))
    (setq x        (nth i cols))
    (setq thisColW (ms-col-web-at cols i))
    (setq halfW    (/ thisColW 2.0))
    ;; Cigar-aware rafter underside Y at this x.  Returns the correct Y
    ;; whether x is in the knee taper zone, constant-middle zone, or
    ;; ridge taper zone.  At the ridge it returns H+rise-rd.
    (setq rafterY (cigar-rafter-underside-y
                    x 0.0 W ridgeX H rise ht rd midD kneeL ridgeL))
    (command "RECTANG"
      (list (- x halfW) 0.0)
      (list (+ x halfW) rafterY))
    (setq i (1+ i)))
)

(defun draw-fr-frame (W H ht cb / pts)
  ;;  Flat Roof: horizontal rafter at eave height, two side columns.
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (command "PLINE"
    (list 0.0       0.0)                   ; bottom-left outside
    (list 0.0       H)                      ; eave-left outside (rafter top left)
    (list W         H)                      ; eave-right outside (rafter top right)
    (list W         0.0)                    ; bottom-right outside
    (list (- W cb)  0.0)                    ; right column inside-base
    (list (- W ht)  (- H ht))               ; right haunch corner
    (list ht        (- H ht))               ; left haunch corner
    (list cb        0.0)                    ; left column inside-base
    "C")
)

(defun draw-cc-frame (W H slopeRise ht cb / )
  ;;  Cantilever Canopy: ONE column on the LEFT (back), rafter
  ;;  cantilevers out to the right (open front).  No right column.
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (command "PLINE"
    (list 0.0       0.0)                   ; bottom-left outside
    (list 0.0       (+ H slopeRise))       ; eave-left outside (HIGH back)
    (list W         H)                     ; eave-right outside (LOW front, open)
    (list W         (- H ht))              ; rafter end inside-bottom (cantilever tip)
    (list ht        (- H ht))              ; left haunch corner
    (list cb        0.0)                   ; left column inside-base
    "C")
)

(defun draw-acs-frame (W H rise ht cb /
                        midX peakY innerH innerW)
  ;;  Arched Clear Span (ACS): two R.F. columns with a CURVED ROOF
  ;;  RAFTER spanning between them.  No ridge — single arc from
  ;;  left column top, peaking at building centerline, down to
  ;;  right column top.  Geometry uses AutoCAD ARC through 3 points.
  ;;
  ;;     ┌────────────╮         ╭────────────┐
  ;;     │           ╭─╯  curve ╰─╮          │
  ;;     │ R.F.    ╭─╯             ╰─╮     R.F.│
  ;;     │ COL    ╱                   ╲    COL │
  ;;     │       ╱                     ╲       │
  ;;     ├──────╯                       ╰──────┤
  ;;     │ ht                          ht      │
  ;;     │                                     │
  ;;     0 ────────── building width W ──────── W
  (setvar "CLAYER" "FRAME")
  (setq midX (/ W 2.0))
  (setq peakY (+ H rise))
  (setq innerH 200.0)        ; rafter web depth (approx)
  ;; LEFT column (rectangular pier)
  (command "RECTANG"
    (list (- 0.0 (/ cb 2.0)) 0.0)
    (list (/ cb 2.0)         H))
  ;; RIGHT column (rectangular pier)
  (command "RECTANG"
    (list (- W (/ cb 2.0))   0.0)
    (list (+ W (/ cb 2.0))   H))
  ;; OUTER (top) curved rafter — ARC through 3 points
  ;;   (0, H) → (midX, peakY) → (W, H)
  (command "ARC"
    (list 0.0  H)
    (list midX peakY)
    (list W    H))
  ;; INNER (bottom) curved rafter — offset inward by web depth
  (command "ARC"
    (list 0.0  (- H innerH))
    (list midX (- peakY innerH))
    (list W    (- H innerH)))
  ;; Cap pieces at the column-rafter junctions (small horizontal lines
  ;; closing the rafter section against the column top).
  (command "LINE"
    (list 0.0 H)
    (list 0.0 (- H innerH))
    "")
  (command "LINE"
    (list W   H)
    (list W   (- H innerH))
    "")
)

(defun draw-ams-frame (W H rise ht cb /
                        halfW peakY innerH q1 q3 peakInnerY)
  ;;  Arched Multi-Span (AMS-01): three R.F. columns with TWO
  ;;  CURVED arches.  Center column rises to the peak; left and
  ;;  right columns at clear height H.
  ;;
  ;;     ╭─╮   ╭───╮   ╭─╮
  ;;     │ │ ╱─╯   ╰─╲ │ │
  ;;     │ │╱         ╲│ │
  ;;     ├─┤           ├─┤
  ;;     │ │           │ │
  ;;     │ │  centre   │ │
  ;;     │ │  column   │ │
  ;;     │ │  rises to │ │
  ;;     │ │  peak     │ │
  ;;     0 ── halfW ── W
  ;;
  ;;  The center column (at midX = W/2) extends from FFL up to the
  ;;  peak Y where the two arches meet.
  (setvar "CLAYER" "FRAME")
  (setq halfW (/ W 2.0))
  (setq peakY (+ H rise))
  (setq innerH 200.0)
  ;; Each arch's mid-quarter Y (control point for ARC) = approximately
  ;; halfway up the rise.
  (setq q1 (/ halfW 2.0))                    ; quarter-X of LEFT arch
  (setq q3 (+ halfW (/ halfW 2.0)))          ; quarter-X of RIGHT arch
  (setq peakInnerY (+ H rise (- 0 (* 0.15 rise))))  ; intermediate Y
  ;; LEFT column (at x=0)
  (command "RECTANG"
    (list (- 0.0 (/ cb 2.0)) 0.0)
    (list (/ cb 2.0)         H))
  ;; CENTER column rises to peak
  (command "RECTANG"
    (list (- halfW (/ cb 2.0)) 0.0)
    (list (+ halfW (/ cb 2.0)) peakY))
  ;; RIGHT column
  (command "RECTANG"
    (list (- W (/ cb 2.0)) 0.0)
    (list (+ W (/ cb 2.0)) H))
  ;; LEFT arch outer: (0, H) → (q1, peakInnerY) → (halfW, peakY)
  (command "ARC"
    (list 0.0   H)
    (list q1    peakInnerY)
    (list halfW peakY))
  ;; LEFT arch inner: offset by web depth
  (command "ARC"
    (list 0.0   (- H innerH))
    (list q1    (- peakInnerY innerH))
    (list halfW (- peakY innerH)))
  ;; RIGHT arch outer: (halfW, peakY) → (q3, peakInnerY) → (W, H)
  (command "ARC"
    (list halfW peakY)
    (list q3    peakInnerY)
    (list W     H))
  ;; RIGHT arch inner
  (command "ARC"
    (list halfW (- peakY innerH))
    (list q3    (- peakInnerY innerH))
    (list W     (- H innerH)))
  ;; Section caps at column-arch junctions
  (command "LINE" (list 0.0 H) (list 0.0 (- H innerH)) "")
  (command "LINE" (list W   H) (list W   (- H innerH)) "")
  (command "LINE" (list halfW peakY) (list halfW (- peakY innerH)) "")
)

(defun draw-bf-frame (W H rise ht cb intColW / cx)
  ;;  Butterfly: CENTER column only, NO side columns.
  ;;  Two rafters slope UP-OUTWARD from center valley to high side eaves.
  (setq cx (/ W 2.0))
  (setq intColW (max intColW 400.0))

  ;; Center column (rectangular)
  (setvar "CLAYER" "FRAME")
  (command "RECTANG"
    (list (- cx (/ intColW 2.0)) 0.0)
    (list (+ cx (/ intColW 2.0)) (- H ht)))

  ;; Frame outline: butterfly shape (V at top, valley at centre)
  (command "PLINE"
    (list 0.0       (+ H rise))            ; LEFT high eave outside
    (list cx        H)                     ; VALLEY (centre, lowest point of roof)
    (list W         (+ H rise))            ; RIGHT high eave outside
    (list (- W ht)  (+ H rise (- 0 ht)))   ; right rafter inside-bottom near eave
    (list (+ cx (/ intColW 2.0)) (- H ht)) ; valley right haunch (column right top)
    (list (- cx (/ intColW 2.0)) (- H ht)) ; valley left haunch (column left top)
    (list ht        (+ H rise (- 0 ht)))   ; left rafter inside-bottom near eave
    "C")
)

(defun draw-lt-frame (W H slopeRise ht cb / wallW)
  ;;  Lean-To frame: one PEB column at LEFT (low side),
  ;;  existing masonry/concrete wall at RIGHT (high side).
  ;;  Sloped rafter goes from low column up to the existing wall.
  (setq wallW 230.0)       ; existing wall thickness (mm)

  ;; Existing wall on RIGHT (drawn as hatched concrete/masonry block)
  (setvar "CLAYER" "RCC-COLUMN")
  (command "RECTANG"
    (list W 0.0)
    (list (+ W wallW) (+ H slopeRise (* 500 *PEB-TEXT-SCALE*))))
  (command "HATCH" "AR-CONC" 25 0 "L" "")

  ;; PEB frame: ONE column on LEFT + sloped rafter to wall
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (command "PLINE"
    (list 0.0      0.0)                         ; bottom-left outside
    (list 0.0      H)                           ; low eave outside
    (list W        (+ H slopeRise))             ; rafter ends at wall
    (list (- W ht) (- (+ H slopeRise) ht))      ; rafter inside-bottom at wall
    (list ht       (- H ht))                    ; left haunch corner
    (list cb       0.0)                         ; left column inside-base
    "C")
)

(defun draw-frame-fill (W H rise ht rd cb)
  ;;  Single ANSI31 hatch over the just-drawn frame outline polyline.
  ;;  The polyline is one closed connected region, so a single
  ;;  HATCH...L call fills the entire frame (both columns + rafter).
  (setvar "CLAYER" "FRAME-FILL")
  (command "HATCH" "ANSI31" (* 60 *PEB-TEXT-SCALE*) 0 "L" "")
)

(defun draw-base-plate-at (xLeft xRight ep boltR /
                            plateBot plateTop boltY bolt1X bolt2X)
  ;;  Helper: draws ONE base plate assembly at a column whose body
  ;;  occupies x = xLeft to x = xRight at the FFL.
  ;;
  ;;  Layout (per user — base plate BOTTOM at FFL):
  ;;     Base plate :  y = 0   -> y = ep         (steel, bottom on FFL)
  ;;     Anchor bolts:  2 donuts through the plate
  ;;  Pedestal/concrete pier removed — plate now sits directly on FFL.
  (setq plateBot 0.0)
  (setq plateTop ep)
  (setq boltY    (+ plateBot (/ ep 2.0)))
  ;; Steel base plate
  (setvar "CLAYER" "PLATES")
  (command "RECTANG"
    (list (- xLeft 100.0) plateBot)
    (list (+ xRight 100.0) plateTop))
  (command "HATCH" "SOLID" "L" "")
  ;; Anchor bolts: 2 donuts through plate, ~25% and ~75% across column
  (setq bolt1X (+ xLeft (* (- xRight xLeft) 0.25)))
  (setq bolt2X (+ xLeft (* (- xRight xLeft) 0.75)))
  (command "DONUT" 0 (* 2 boltR) (list bolt1X boltY) "")
  (command "DONUT" 0 (* 2 boltR) (list bolt2X boltY) "")
)

(defun draw-base-plates (W cb ep / boltR)
  ;;  Base plates for the LEFT and RIGHT outer columns (CS / SS / etc.).
  ;;  Each plate is RAISED above FFL on a small concrete pedestal,
  ;;  with anchor bolts visible through the plate.
  (setq boltR (* 25 *PEB-TEXT-SCALE*))
  (draw-base-plate-at 0.0     cb        ep boltR)   ; LEFT
  (draw-base-plate-at (- W cb) W        ep boltR)   ; RIGHT
)

(defun draw-base-plates-multi (cols cb ep intColW / boltR x i n thisW)
  ;;  Base plates for MS / MG with intermediate columns.
  ;;  - End columns (first and last in cols): tapered, body width = cb
  ;;  - Interior columns: rectangular thisW wide, centred on x
  ;;
  ;;  intColW may be either:
  ;;    - a NUMBER: same width for every interior column (legacy MG path)
  ;;    - a LIST  : parallel to cols, one width per column.  Used by MS
  ;;                so each interior base plate matches its column's web,
  ;;                which itself varies 300-600 mm with the larger flanking
  ;;                module width (via ms-col-web-at).  Indices for end
  ;;                columns may hold nil — they're never read because the
  ;;                end-col cond branches use cb instead.
  (setq boltR (* 25 *PEB-TEXT-SCALE*))
  (setq n (length cols))
  (setq i 0)
  (foreach x cols
    (cond
      ((= i 0)              ; LEFT end column
        (draw-base-plate-at x (+ x cb) ep boltR))
      ((= i (1- n))         ; RIGHT end column
        (draw-base-plate-at (- x cb) x ep boltR))
      (T                    ; interior column (rectangular)
        (setq thisW (if (listp intColW) (nth i intColW) intColW))
        (draw-base-plate-at (- x (/ thisW 2.0))
                            (+ x (/ thisW 2.0)) ep boltR)))
    (setq i (1+ i)))
)

(defun draw-stiff-top (xOuter yEdge w h dx)
  ;;  Triangular stiffener ABOVE the upper plate, outline only.
  ;;  yEdge = top edge Y of the upper plate.
  (command "PLINE"
    (list xOuter             yEdge)
    (list xOuter             (+ yEdge h))
    (list (+ xOuter (* dx w)) yEdge)
    "C"))

(defun draw-stiff-bot (xOuter yEdge w h dx)
  ;;  Triangular stiffener BELOW the lower plate, outline only.
  ;;  yEdge = bottom edge Y of the lower plate.
  (command "PLINE"
    (list xOuter             yEdge)
    (list xOuter             (- yEdge h))
    (list (+ xOuter (* dx w)) yEdge)
    "C"))

;; ── Plate-pair de-duplication tracker ─────────────────────────────────
;;  draw-rafter-stiffeners pushes (kxL kyBot) onto *PEB-DRAWN-PLATES* every
;;  time it draws a transition site (plate pair + bolts + 4 stiffener
;;  triangles).  Subsequent draws within tolerance (±300 mm in X AND ±400
;;  mm in Y) are SKIPPED.  This prevents duplicate plate sets from appearing
;;  near the same cigar-transition X regardless of code path.  The
;;  X-tolerance (300 mm) is safely below the minimum legitimate spacing
;;  between adjacent transitions (kneeL_min + ridgeL_min = 3000 + 3000 =
;;  6000 mm), so no real transition will ever be wrongly dropped.
;;  Cleared at the start of every draw-rafter-stiffeners invocation.
(setq *PEB-DRAWN-PLATES* '())

(defun peb-plate-already-drawn (kxL kyBot / p tolX tolY found)
  ;;  Returns T if a plate pair has already been drawn within tolerance
  ;;  of (kxL, kyBot).
  (setq tolX 300.0)
  (setq tolY 400.0)
  (setq found nil)
  (foreach p *PEB-DRAWN-PLATES*
    (if (and (< (abs (- kxL  (car  p))) tolX)
             (< (abs (- kyBot (cadr p))) tolY))
      (setq found T)))
  found
)

(defun peb-record-plate-drawn (kxL kyBot)
  (setq *PEB-DRAWN-PLATES* (cons (list kxL kyBot) *PEB-DRAWN-PLATES*))
  T
)

(defun draw-rafter-plate-pair (kxL kyBot kyTop plateThk plateExt slopeL slopeR vShift /)
  ;;  Draw a pair of splice plates centered on the seam at (kxL).
  ;;  Plates are axis-aligned rectangles, optionally shifted by vShift (+ = UP).
  ;;  slopeL/slopeR retained for callers but currently unused.
  ;;  No stiffeners drawn here — those are drawn separately by each call site.
  (command "RECTANG"
    (list (- kxL plateThk) (+ (- kyBot plateExt) vShift))
    (list kxL              (+ (+ kyTop plateExt) vShift)))
  (command "RECTANG"
    (list kxL                  (+ (- kyBot plateExt) vShift))
    (list (+ kxL plateThk)     (+ (+ kyTop plateExt) vShift)))
)

(defun draw-rafter-stiffeners (cols ridges H rise ht rd apexHasCol /
                                 midD kneeL ridgeL stiffSize plateExt plateThk boltR
                                 slL slLnL tanA slopeL slopeR
                                 midSecLen splDist splCa splSa nSpl spcLen splI
                                 i nR rxC xL xR rPts kxL kyTop kyBot)
  ;;  apexHasCol = T to SKIP the ridge-apex plate-pair (used for MG when a
  ;;  sub-span column lands directly under the ridge — the column
  ;;  brings its own connection at column-top, so the apex web stays
  ;;  continuous with no vertical splice plate).
  ;;  Draw small stiffener triangles at every rafter web-transition
  ;;  point (knee_end + ridge_start of the cigar profile).  At each
  ;;  transition: ONE triangle on the OUTER (top) flange, ONE on the
  ;;  INNER (bottom) flange.  Same triangular shape as haunch stiffeners.
  (setvar "CLAYER" "PLATES")
  (setvar "PLINEWID" 0.0)
  (setq midD     (max 300.0 (min 500.0 (- (* ht 0.5) 50.0))))
  ;; kneeL and ridgeL now computed per-gable inside the foreach loop
  (setq stiffSize 75.0)
  (setq plateExt  100.0)   ; plates extend 100 mm BEYOND the rafter top flange AND below bottom flange
  (setq plateThk   20.0)   ; vertical connection plate thickness
  (setq boltR     (* 25 *PEB-TEXT-SCALE*))   ; bolt radius for donut

  ;; ── Reset the per-frame plate-pair de-dup tracker ──
  ;; Each invocation starts fresh.  Any transition site whose (kxL, kyBot)
  ;; falls within ±100 mm of an already-drawn site is silently skipped
  ;; (plate pair + bolts + 4 stiffeners all together).
  (setq *PEB-DRAWN-PLATES* '())

  ;; Iterate over ridges with explicit while-loop indexing.  rxC, xL, xR
  ;; are all driven from the same `i` so they cannot get out of sync.
  (setq nR (length ridges))
  (setq i 0)
  (while (< i nR)
    (setq rxC (nth i ridges))
    (setq xL  (nth i cols))
    (setq xR  (nth (1+ i) cols))
    ;; Variable knee/ridge taper lengths — use the SHARED cigar-taper-lengths
    ;; helper that build-frame-polygon also calls.  This guarantees the plate
    ;; X positions land on the SAME cigar transitions the rafter polygon shows,
    ;; for any building W and H, and any number of gables.
    (setq kneeL  (car  (cigar-taper-lengths (- xR xL))))
    (setq ridgeL (cadr (cigar-taper-lengths (- xR xL))))
    (setq rPts (rafter-underside-points xL xR rxC H rise ht rd midD kneeL ridgeL))
    ;; rPts = ( left-knee-end  left-ridge-start  ridge-bottom  right-ridge-start  right-knee-end )
    ;; Compute rafter slope info (for sloping the lower stiffener top legs)
    (setq slL    (- rxC xL))
    (setq slLnL  (sqrt (+ (* slL slL) (* rise rise))))
    (setq tanA   (/ rise slL))                     ; tan(alpha) for LEFT half (positive slope going +x)
    (setq slopeL  tanA)                              ; LEFT half slope (going +x toward ridge increases y)
    (setq slopeR  (- 0 tanA))                        ; RIGHT half slope (going +x toward eave decreases y)

    ;; Helper: draw connection plate + 2 stiffener triangles at one transition
    ;; (kxL, kyBot) = rafter inner-flange position; kyTop = outer-flange y (= kyBot + midD)
    ;; dirIn = +1 if stiffener extends to the RIGHT (e.g. left knee end),
    ;;         -1 if stiffener extends to the LEFT (e.g. right knee end)

    ;; LEFT KNEE END: TWO plates (LEFT + RIGHT) bolted, 2 stiffeners per plate
    (setq kxL (car (nth 0 rPts)))
    (setq kyBot (cadr (nth 0 rPts)))
    (setq kyTop (+ kyBot midD))
    ;; Skip the WHOLE transition site (plates + bolts + stiffeners) if we
    ;; already drew a plate pair within tolerance at this (kxL, kyBot).
    (if (not (peb-plate-already-drawn kxL kyBot))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    ;; LEFT KNEE END: standard plate detail (2 plates + 3 bolts + 2 stiffeners)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeL slopeL 0.0)
    ;; Bolts at joint line (3 donuts spread along web)
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot 50.0)) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot (/ midD 2.0))) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (- kyTop 50.0)) "")
    ;; LEFT plate stiffeners (LEFT half rafter, slopeL = +tanA)
    ;; TOP stiffeners stay horizontal (along straight top flange)
    (command "PLINE"
      (list (- kxL plateThk) kyTop) (list (- kxL plateThk) (+ kyTop stiffSize))
      (list (- kxL plateThk stiffSize) kyTop) "C")
    ;; BOTTOM stiffener TOP leg slopes along bottom flange (going LEFT = -x = down on LEFT half)
    (command "PLINE"
      (list (- kxL plateThk) kyBot)
      (list (- kxL plateThk) (- kyBot stiffSize))
      (list (- kxL plateThk stiffSize) (- kyBot (* stiffSize slopeL))) "C")
    ;; RIGHT plate stiffeners (LEFT half rafter, going +x = up)
    (command "PLINE"
      (list (+ kxL plateThk) kyTop) (list (+ kxL plateThk) (+ kyTop stiffSize))
      (list (+ kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (+ kxL plateThk) kyBot)
      (list (+ kxL plateThk) (- kyBot stiffSize))
      (list (+ kxL plateThk stiffSize) (+ kyBot (* stiffSize slopeL))) "C")
      ))   ; end (if (not peb-plate-already-drawn) … LEFT KNEE END)

    ;; LEFT RIDGE START: web changes from midD → rd here.  Both plates
    ;; are in the LEFT half rafter (slope = +tanA).
    (setq kxL (car (nth 1 rPts)))
    (setq kyBot (cadr (nth 1 rPts)))
    (setq kyTop (+ kyBot midD))
    (if (not (peb-plate-already-drawn kxL kyBot))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeL slopeL 0.0)
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot 50.0)) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot (/ midD 2.0))) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (- kyTop 50.0)) "")
    ;; LEFT plate stiffeners (going LEFT = -x = down on LEFT half)
    (command "PLINE"
      (list (- kxL plateThk) kyTop) (list (- kxL plateThk) (+ kyTop stiffSize))
      (list (- kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (- kxL plateThk) kyBot)
      (list (- kxL plateThk) (- kyBot stiffSize))
      (list (- kxL plateThk stiffSize) (- kyBot (* stiffSize slopeL))) "C")
    ;; RIGHT plate stiffeners (going +x = up on LEFT half)
    (command "PLINE"
      (list (+ kxL plateThk) kyTop) (list (+ kxL plateThk) (+ kyTop stiffSize))
      (list (+ kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (+ kxL plateThk) kyBot)
      (list (+ kxL plateThk) (- kyBot stiffSize))
      (list (+ kxL plateThk stiffSize) (+ kyBot (* stiffSize slopeL))) "C")
      ))   ; end (if (not peb-plate-already-drawn) … LEFT RIDGE START)

    ;; RIDGE APEX: TWO plates AT the ridge centerline + 4 stiffeners + bolts
    ;; Web depth here is rd (deeper than midD), so kyTop = H + rise (apex)
    ;; Skipped entirely when apexHasCol = T (MG with column at ridge):
    ;; the column-top connection plates take over and the rafter web
    ;; stays continuous over the apex.
    (if (not apexHasCol)
      (progn
    (setq kxL (car (nth 2 rPts)))
    (setq kyBot (cadr (nth 2 rPts)))
    (setq kyTop (+ H rise))
    (if (not (peb-plate-already-drawn kxL kyBot))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    ;; Apex: LEFT plate is in LEFT half (slope=+tanA), RIGHT plate in RIGHT half (slope=-tanA)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeL slopeR 0.0)
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot 50.0)) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot (/ (- kyTop kyBot) 2.0))) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (- kyTop 50.0)) "")
    ;; LEFT plate stiffeners at ridge (LEFT-half top flange goes DOWN going -x)
    (command "PLINE"
      (list (- kxL plateThk) kyTop) (list (- kxL plateThk) (+ kyTop stiffSize))
      (list (- kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (- kxL plateThk) kyBot)
      (list (- kxL plateThk) (- kyBot stiffSize))
      (list (- kxL plateThk stiffSize) kyBot) "C")
    ;; RIGHT plate stiffeners at ridge (RIGHT-half top flange goes DOWN going +x)
    (command "PLINE"
      (list (+ kxL plateThk) kyTop) (list (+ kxL plateThk) (+ kyTop stiffSize))
      (list (+ kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (+ kxL plateThk) kyBot)
      (list (+ kxL plateThk) (- kyBot stiffSize))
      (list (+ kxL plateThk stiffSize) kyBot) "C")
      ))   ; end (if (not peb-plate-already-drawn) … RIDGE APEX)
      ))   ; end (if (not apexHasCol))

    ;; RIGHT RIDGE START: web changes from rd → midD here.  Both plates
    ;; are in the RIGHT half rafter (slope = -tanA = slopeR).
    (setq kxL (car (nth 3 rPts)))
    (setq kyBot (cadr (nth 3 rPts)))
    (setq kyTop (+ kyBot midD))
    (if (not (peb-plate-already-drawn kxL kyBot))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeR slopeR 0.0)
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot 50.0)) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot (/ midD 2.0))) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (- kyTop 50.0)) "")
    ;; LEFT plate stiffeners (going -x = up on RIGHT half = toward ridge)
    (command "PLINE"
      (list (- kxL plateThk) kyTop) (list (- kxL plateThk) (+ kyTop stiffSize))
      (list (- kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (- kxL plateThk) kyBot)
      (list (- kxL plateThk) (- kyBot stiffSize))
      (list (- kxL plateThk stiffSize) (- kyBot (* stiffSize slopeR))) "C")
    ;; RIGHT plate stiffeners (going +x = down on RIGHT half = toward eave)
    (command "PLINE"
      (list (+ kxL plateThk) kyTop) (list (+ kxL plateThk) (+ kyTop stiffSize))
      (list (+ kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (+ kxL plateThk) kyBot)
      (list (+ kxL plateThk) (- kyBot stiffSize))
      (list (+ kxL plateThk stiffSize) (+ kyBot (* stiffSize slopeR))) "C")
      ))   ; end (if (not peb-plate-already-drawn) … RIGHT RIDGE START)

    ;; RIGHT KNEE END: both plates are in the RIGHT half rafter (slope = -tanA = slopeR)
    (setq kxL (car (nth 4 rPts)))
    (setq kyBot (cadr (nth 4 rPts)))
    (setq kyTop (+ kyBot midD))
    (if (not (peb-plate-already-drawn kxL kyBot))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeR slopeR 0.0)
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot 50.0)) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot (/ midD 2.0))) "")
    (command "DONUT" 0 (* 2 boltR) (list kxL (- kyTop 50.0)) "")
    ;; LEFT plate stiffeners (going -x = up on RIGHT half = toward ridge)
    (command "PLINE"
      (list (- kxL plateThk) kyTop) (list (- kxL plateThk) (+ kyTop stiffSize))
      (list (- kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (- kxL plateThk) kyBot)
      (list (- kxL plateThk) (- kyBot stiffSize))
      (list (- kxL plateThk stiffSize) (- kyBot (* stiffSize slopeR))) "C")
    ;; RIGHT plate stiffeners (going +x = down on RIGHT half = toward eave)
    (command "PLINE"
      (list (+ kxL plateThk) kyTop) (list (+ kxL plateThk) (+ kyTop stiffSize))
      (list (+ kxL plateThk stiffSize) kyTop) "C")
    (command "PLINE"
      (list (+ kxL plateThk) kyBot)
      (list (+ kxL plateThk) (- kyBot stiffSize))
      (list (+ kxL plateThk stiffSize) (+ kyBot (* stiffSize slopeR))) "C")
      ))   ; end (if (not peb-plate-already-drawn) … RIGHT KNEE END)

    ;; ===== MID-SPAN SPLICE PLATES (12 m max piece rule) =====
    ;; The constant-middle section runs along the slope from knee-end
    ;; (kneeL) to ridge-start (slLnL - ridgeL).  Any rafter piece must
    ;; not exceed 12 m for shipping/splice reasons - so we divide the
    ;; middle section into N+1 equal pieces (each <= 12 m) by inserting
    ;; N splice plates at evenly spaced points.
    (setq midSecLen (- slLnL ridgeL kneeL))
    (setq nSpl (fix (/ (- midSecLen 0.001) 12000.0)))
    (if (> nSpl 0)
      (progn
        (setq splCa (/ slL slLnL))
        (setq splSa (/ rise slLnL))
        (setq spcLen (/ midSecLen (+ nSpl 1.0)))
        (setq splI 1)
        (while (<= splI nSpl)
          (setq splDist (+ kneeL (* splI spcLen)))

          ;; --- LEFT half splice ---
          (setq kxL   (+ xL (* splDist splCa)))
          (setq kyBot (- (+ H (* splDist splSa)) midD))
          (setq kyTop (+ kyBot midD))
          (if (not (peb-plate-already-drawn kxL kyBot))
            (progn
              (peb-record-plate-drawn kxL kyBot)
          (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeL slopeL 0.0)
          (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot 50.0)) "")
          (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot (/ midD 2.0))) "")
          (command "DONUT" 0 (* 2 boltR) (list kxL (- kyTop 50.0)) "")
          (command "PLINE"
            (list (- kxL plateThk) kyTop) (list (- kxL plateThk) (+ kyTop stiffSize))
            (list (- kxL plateThk stiffSize) kyTop) "C")
          (command "PLINE"
            (list (- kxL plateThk) kyBot)
            (list (- kxL plateThk) (- kyBot stiffSize))
            (list (- kxL plateThk stiffSize) (- kyBot (* stiffSize slopeL))) "C")
          (command "PLINE"
            (list (+ kxL plateThk) kyTop) (list (+ kxL plateThk) (+ kyTop stiffSize))
            (list (+ kxL plateThk stiffSize) kyTop) "C")
          (command "PLINE"
            (list (+ kxL plateThk) kyBot)
            (list (+ kxL plateThk) (- kyBot stiffSize))
            (list (+ kxL plateThk stiffSize) (+ kyBot (* stiffSize slopeL))) "C")
            ))   ; end (if (not peb-plate-already-drawn) … LEFT mid-splice)

          ;; --- RIGHT half splice (RIGHT half rafter slope = -tanA = slopeR) ---
          (setq kxL   (- xR (* splDist splCa)))
          (setq kyBot (- (+ H (* splDist splSa)) midD))
          (setq kyTop (+ kyBot midD))
          (if (not (peb-plate-already-drawn kxL kyBot))
            (progn
              (peb-record-plate-drawn kxL kyBot)
          (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeR slopeR 0.0)
          (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot 50.0)) "")
          (command "DONUT" 0 (* 2 boltR) (list kxL (+ kyBot (/ midD 2.0))) "")
          (command "DONUT" 0 (* 2 boltR) (list kxL (- kyTop 50.0)) "")
          (command "PLINE"
            (list (- kxL plateThk) kyTop) (list (- kxL plateThk) (+ kyTop stiffSize))
            (list (- kxL plateThk stiffSize) kyTop) "C")
          (command "PLINE"
            (list (- kxL plateThk) kyBot)
            (list (- kxL plateThk) (- kyBot stiffSize))
            (list (- kxL plateThk stiffSize) (- kyBot (* stiffSize slopeR))) "C")
          (command "PLINE"
            (list (+ kxL plateThk) kyTop) (list (+ kxL plateThk) (+ kyTop stiffSize))
            (list (+ kxL plateThk stiffSize) kyTop) "C")
          (command "PLINE"
            (list (+ kxL plateThk) kyBot)
            (list (+ kxL plateThk) (- kyBot stiffSize))
            (list (+ kxL plateThk stiffSize) (+ kyBot (* stiffSize slopeR))) "C")
            ))   ; end (if (not peb-plate-already-drawn) … RIGHT mid-splice)

          (setq splI (1+ splI))
        )
      )
    )

    (setq i (1+ i))
  )
)

(defun draw-haunch-plates (cols H ht ep valleyStyle ridgeX /
                                          boltR plateY upTopY upBotY loTopY loBotY
                                          i nCols x ext stiffW stiffH outerX innerX
                                          vIntColW vHalfCol vPThk vPlateBot vPlateTop
                                          vBoltY1 vBoltY2 vBoltY3
                                          vL1xL vL1xR vL2xL vL2xR
                                          vR1xL vR1xR vR2xL vR2xR
                                          vMidY)
  ;;  valleyStyle = T  → interior columns get the 4-vertical-plate VALLEY
  ;;                     detail (MG gable-boundary columns).
  ;;  valleyStyle = nil → interior columns get a simpler symmetric horizontal
  ;;                     plate stack (MS intermediate supports under a
  ;;                     continuous rafter — NOT valleys).
  ;;  ridgeX        = nil OR an X coordinate.  When non-nil, any interior
  ;;                     column whose X equals ridgeX (within 1 mm) is
  ;;                     SKIPPED here — that column is at the rafter apex
  ;;                     and is handled externally by draw-mg-ridge-col-plates
  ;;                     so the rafter web stays continuous over the peak.
  ;;  TWO stacked end plates at the column-rafter junction, drawn as
  ;;  outline rectangles (4 horizontal lines total in section):
  ;;    Upper (rafter) plate: bolted to the rafter underside
  ;;    Lower (column) plate: bolted to the top of the column
  ;;  Bolts (donuts) go through both plates at the interface line.
  ;;  Plate extends 100 mm past the rafter on each side.
  ;;  Stiffeners (outline triangles, 75 x 75 mm):
  ;;    OUTER end - both above upper plate AND below lower plate
  ;;    INNER end - only below lower plate (column side only)
  (setvar "CLAYER" "PLATES")
  (setq boltR  (* 25 *PEB-TEXT-SCALE*))
  ;; Plate stack sits BELOW the haunch corner so the TOP of the upper
  ;; (rafter) plate aligns with the rafter underside / column top.
  ;;   Upper plate (rafter):  H-ht-ep   to  H-ht
  ;;   Lower plate (column):  H-ht-2*ep to  H-ht-ep    <- interface = bolt line
  (setq plateY (- H ht (* 0.5 ep)))     ; bolt-line Y for stiffener-anchor reference
  (setq upTopY (- H ht))                ; upper plate top edge = rafter underside
  (setq upBotY (- (- H ht) ep))         ; upper plate bottom edge (= interface = bolt level)
  (setq loTopY upBotY)                  ; lower plate top edge   (= interface)
  (setq loBotY (- upBotY ep))           ; lower plate bottom edge
  (setq nCols  (length cols))
  (setq ext    100.0)                   ; plate extension beyond rafter (mm)
  (setq stiffW ext)                     ; stiffener reaches flange line (= plate extension)
  (setq stiffH 100.0)                   ; stiffener height perpendicular (mm)
  (setq i 0)

  (foreach x cols
    (cond
      ;; --- LEFT END column: outer = (x-ext), inner = (x+ht+ext) ---
      ((= i 0)
        (setq outerX (- x ext))
        (setq innerX (+ x ht ext))
        ;; Upper (rafter) plate
        (command "RECTANG" (list outerX upBotY) (list innerX upTopY))
        ;; Lower (column) plate
        (command "RECTANG" (list outerX loBotY) (list innerX loTopY))
        ;; Bolts at the interface
        (command "DONUT" 0 (* boltR 2) (list (+ x (* ht 0.15)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (+ x (* ht 0.40)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (+ x (* ht 0.65)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (+ x (* ht 0.90)) upBotY) "")
        ;; OUTER end stiffeners: vertical at column flange (x), hypotenuse OUT to outerX
        (draw-stiff-top x        upTopY ext stiffH -1)
        (draw-stiff-bot x        loBotY ext stiffH -1)
        ;; INNER end stiffener: vertical at rafter end plate (x+ht), hypotenuse IN to innerX
        (draw-stiff-bot (+ x ht) loBotY ext stiffH  1)
      )
      ;; --- RIGHT END column: outer = (x+ext), inner = (x-ht-ext) ---
      ((= i (1- nCols))
        (setq outerX (+ x ext))
        (setq innerX (- x ht ext))
        (command "RECTANG" (list innerX upBotY) (list outerX upTopY))
        (command "RECTANG" (list innerX loBotY) (list outerX loTopY))
        (command "DONUT" 0 (* boltR 2) (list (- x (* ht 0.15)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (- x (* ht 0.40)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (- x (* ht 0.65)) upBotY) "")
        (command "DONUT" 0 (* boltR 2) (list (- x (* ht 0.90)) upBotY) "")
        ;; OUTER end stiffeners: vertical at column flange (x), hypotenuse OUT to outerX
        (draw-stiff-top x        upTopY ext stiffH  1)
        (draw-stiff-bot x        loBotY ext stiffH  1)
        ;; INNER end stiffener: vertical at rafter end plate (x-ht), hypotenuse IN to innerX
        (draw-stiff-bot (- x ht) loBotY ext stiffH -1)
      )
      ;; --- INTERIOR column ----------------------------------------------
      ;; If this column lands AT the ridge (within 1 mm of ridgeX), SKIP
      ;;     entirely — draw-mg-ridge-col-plates is invoked separately for
      ;;     that column and the rafter web stays continuous over the apex.
      ;; If valleyStyle = T  → MG gable-boundary column (TRUE valley).
      ;;     Draw 4 vertical plates flanking the column + web stiffener.
      ;; If valleyStyle = nil → MS intermediate support under continuous rafter.
      ;;     Use the simpler symmetric horizontal plate stack.
      (T
        (cond
          ((and ridgeX (< (abs (- x ridgeX)) 1.0))
            nil)         ; column at ridge — handled by draw-mg-ridge-col-plates
          (valleyStyle
            (setq vIntColW  400.0)                       ; column body width
            (setq vHalfCol  (/ vIntColW 2.0))            ; = 200
            (setq vPThk     20.0)                        ; end-plate thickness
            (setq vPlateBot (- (- H ht) 50.0))           ; 50 mm below haunch corner
            (setq vPlateTop (+ H 50.0))                  ; 50 mm above rafter top flange
            (setq vL1xR (- x vHalfCol))                  ; column LEFT flange face
            (setq vL1xL (- vL1xR vPThk))
            (setq vL2xR vL1xL)
            (setq vL2xL (- vL2xR vPThk))
            (setq vR1xL (+ x vHalfCol))                  ; column RIGHT flange face
            (setq vR1xR (+ vR1xL vPThk))
            (setq vR2xL vR1xR)
            (setq vR2xR (+ vR2xL vPThk))
            (setq vMidY  (/ (+ vPlateBot vPlateTop) 2.0))
            (setq vBoltY1 (+ vPlateBot 100.0))
            (setq vBoltY2 vMidY)
            (setq vBoltY3 (- vPlateTop 100.0))
            ;; LEFT pair (Plates 3 + 4)
            (command "RECTANG" (list vL1xL vPlateBot) (list vL1xR vPlateTop))
            (command "RECTANG" (list vL2xL vPlateBot) (list vL2xR vPlateTop))
            (command "DONUT" 0 (* boltR 2) (list vL1xL vBoltY1) "")
            (command "DONUT" 0 (* boltR 2) (list vL1xL vBoltY2) "")
            (command "DONUT" 0 (* boltR 2) (list vL1xL vBoltY3) "")
            ;; RIGHT pair (Plates 1 + 2)
            (command "RECTANG" (list vR1xL vPlateBot) (list vR1xR vPlateTop))
            (command "RECTANG" (list vR2xL vPlateBot) (list vR2xR vPlateTop))
            (command "DONUT" 0 (* boltR 2) (list vR1xR vBoltY1) "")
            (command "DONUT" 0 (* boltR 2) (list vR1xR vBoltY2) "")
            (command "DONUT" 0 (* boltR 2) (list vR1xR vBoltY3) "")
            ;; Column-web stiffener at plate bottom
            (command "RECTANG"
              (list (- x vHalfCol) (- vPlateBot 20.0))
              (list (+ x vHalfCol)    vPlateBot)))
          (T
            ;; --- Non-valley interior column (MS): single horizontal plate
            ;;     stack centered on the column, similar to end-column style ---
            (setq outerX (- x ht ext))
            (setq innerX (+ x ht ext))
            (command "RECTANG" (list outerX upBotY) (list innerX upTopY))
            (command "RECTANG" (list outerX loBotY) (list innerX loTopY))
            (command "DONUT" 0 (* boltR 2) (list (- x (* ht 0.85)) upBotY) "")
            (command "DONUT" 0 (* boltR 2) (list (- x (* ht 0.50)) upBotY) "")
            (command "DONUT" 0 (* boltR 2) (list (- x (* ht 0.15)) upBotY) "")
            (command "DONUT" 0 (* boltR 2) (list (+ x (* ht 0.15)) upBotY) "")
            (command "DONUT" 0 (* boltR 2) (list (+ x (* ht 0.50)) upBotY) "")
            (command "DONUT" 0 (* boltR 2) (list (+ x (* ht 0.85)) upBotY) "")
            (draw-stiff-top (- x ht) upTopY ext stiffH -1)
            (draw-stiff-bot (- x ht) loBotY ext stiffH -1)
            (draw-stiff-top (+ x ht) upTopY ext stiffH  1)
            (draw-stiff-bot (+ x ht) loBotY ext stiffH  1))))
    )
    (setq i (1+ i))
  )
)

(defun draw-ridge-plate (W H rise rd ep)
  ;;  Ridge connection plate (vertical, at the ridge centerline)
  (setvar "CLAYER" "PLATES")
  (command "RECTANG"
    (list (- (/ W 2.0) (/ ep 2.0)) (+ H rise (- 0 rd) (* 100.0)))
    (list (+ (/ W 2.0) (/ ep 2.0)) (+ H rise        )))
  (command "HATCH" "SOLID" "L" "")
)

(defun draw-mg-ridge-col-plates (x H rise rd ep /
                                  boltR upTopY upBotY loTopY loBotY
                                  intColW halfCol ext stiffH outerX innerX)
  ;;  Ridge-column connection detail (MG, picture 4):
  ;;  Sub-span column lands directly under a ridge peak (e.g., spanPerGab=2).
  ;;  Column top is at H+rise-rd (rafter underside at ridge).
  ;;  PLATE SIZE auto-adjusts to the column web (intColW = 400 mm) plus
  ;;  exactly 100 mm extension on each end — the plate is just wide
  ;;  enough to bolt the column flange to the rafter underside.
  ;;  The vertical apex plates (RIDGE APEX in draw-rafter-stiffeners) are
  ;;  suppressed for this case so the rafter web runs continuous over the peak.
  (setvar "CLAYER" "PLATES")
  (setq boltR   (* 25 *PEB-TEXT-SCALE*))
  (setq upTopY  (- (+ H rise) rd))           ; rafter underside at ridge / column top
  (setq upBotY  (- upTopY ep))               ; upper plate bottom edge
  (setq loTopY  upBotY)                      ; lower plate top  edge (= bolt interface)
  (setq loBotY  (- upBotY ep))               ; lower plate bottom edge
  (setq intColW 400.0)                       ; matches draw-mg-multi-frame
  (setq halfCol (/ intColW 2.0))             ; = 200
  (setq ext     100.0)                       ; 100 mm extension each end
  (setq stiffH  100.0)
  (setq outerX  (- x halfCol ext))           ; = x - 300
  (setq innerX  (+ x halfCol ext))           ; = x + 300
  ;; LEFT half plates (welded to left-rafter end)
  (command "RECTANG" (list outerX upBotY) (list x upTopY))
  (command "RECTANG" (list outerX loBotY) (list x loTopY))
  ;; RIGHT half plates (welded to right-rafter end)
  (command "RECTANG" (list x upBotY) (list innerX upTopY))
  (command "RECTANG" (list x loBotY) (list innerX loTopY))
  ;; Bolt rows at column-rafter interface — 2 per side, centered between
  ;; column flange (x ± halfCol) and outer plate end (x ± halfCol+ext).
  (command "DONUT" 0 (* boltR 2) (list (- x halfCol (* ext 0.5)) upBotY) "")
  (command "DONUT" 0 (* boltR 2) (list (- x (* halfCol 0.5))     upBotY) "")
  (command "DONUT" 0 (* boltR 2) (list (+ x (* halfCol 0.5))     upBotY) "")
  (command "DONUT" 0 (* boltR 2) (list (+ x halfCol (* ext 0.5)) upBotY) "")
  ;; Vertical seam highlight at column centerline
  (command "LINE"
    (list x (- loBotY (* 0.5 ep)))
    (list x (+ upTopY (* 0.5 ep))) "")
  ;; Outer-end stiffeners (top + bottom) at column flange line
  (draw-stiff-top (- x halfCol) upTopY ext stiffH -1)
  (draw-stiff-bot (- x halfCol) loBotY ext stiffH -1)
  (draw-stiff-top (+ x halfCol) upTopY ext stiffH  1)
  (draw-stiff-bot (+ x halfCol) loBotY ext stiffH  1)
)

(defun draw-z-purlin-flat (xWeb yBase dir /
                            depth wtop wbot lip lipDx lipDy
                            v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  ;;  Flat (non-sloped) Z-purlin section, drawn as a 6-vertex polyline
  ;;  matching the 200×60×20 Z profile used elsewhere (draw-purlins).
  ;;  xWeb  = world x of the vertical web
  ;;  yBase = world y of bottom-of-web
  ;;  dir   = +1 ⇒ top flange extends to the RIGHT, bottom flange to the LEFT
  ;;          -1 ⇒ mirror (top flange LEFT, bottom flange RIGHT)
  (setvar "CLAYER" "PURLINS")
  (setvar "PLINEWID" 0.0)
  (setq depth 200.0  wtop 60.0  wbot 60.0  lip 20.0)
  (setq lipDx (* lip 0.5))         ; cos 60° (lip leans 60° from flange)
  (setq lipDy (* lip 0.866))       ; sin 60°
  ;; Z profile in local frame:
  ;;   v6 (bottom-lip-end)        = (-wbot+lipDx, lipDy)
  ;;   v5 (bottom-flange-corner)  = (-wbot,        0)
  ;;   v4 (bottom-of-web)         = (0,            0)
  ;;   v3 (top-of-web)            = (0,            depth)
  ;;   v2 (top-flange-corner)     = (+wtop,        depth)
  ;;   v1 (top-lip-end)           = (+wtop-lipDx,  depth-lipDy)
  (setq v6x (+ xWeb (* dir (- lipDx wbot))))
  (setq v6y (+ yBase lipDy))
  (setq v5x (+ xWeb (* dir (- 0 wbot))))
  (setq v5y yBase)
  (setq v4x xWeb)
  (setq v4y yBase)
  (setq v3x xWeb)
  (setq v3y (+ yBase depth))
  (setq v2x (+ xWeb (* dir wtop)))
  (setq v2y (+ yBase depth))
  (setq v1x (+ xWeb (* dir (- wtop lipDx))))
  (setq v1y (+ yBase depth (- 0 lipDy)))
  (command "PLINE"
    (list v6x v6y) "W" 1.5 1.5
    (list v5x v5y) (list v4x v4y)
    (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
  (setvar "FILLETRAD" 4.0)
  (command "FILLET" "P" (entlast))
  (setvar "PLINEWID" 0.0)
)

(defun draw-detail-a-inset (cx cyBase /
                             colW colH plateThk plateH stiffThk
                             rafLen rafRise rafD rafSlope
                             gutH gutBotW gutSideRun gutFlangeW
                             rafTopY rafBotY
                             colTopY colLF colRF
                             plateBotY plateTopY
                             pLxL pLxR pLxL2 pLxR2 pRxL pRxR pRxL2 pRxR2
                             rafLU_x rafLU_y rafLB_x rafLB_y
                             rafRU_x rafRU_y rafRB_x rafRB_y
                             gBL gBR gFLi gFLo gFRi gFRo gTopY gBotY insetVY0
                             sheetSlope shTopY shBotY shLeftEnd shRightEnd
                             shLeftEndY shRightEndY
                             shLeftStartX shLeftStartY shRightStartX shRightStartY
                             tH tx ty)
  ;;  DETAIL-A: TYPICAL VALLEY DETAILS  (schematic inset).
  ;;  cx, cyBase = horizontal centre and bottom (FFL) of the column for
  ;;               this inset — caller positions it where it fits.
  ;;  Drawn at section-drawing scale (mm) — geometry is FORESHORTENED so
  ;;  the schematic fits in roughly 6 m wide × 3 m tall.
  (setvar "PLINEWID" 0.0)
  ;; --- Tunable schematic sizes ---
  (setq colW       400.0)             ; column body width
  (setq colH       1400.0)            ; column body height (schematic)
  (setq plateThk   30.0)              ; connection plate thickness (visible in section)
  (setq plateH     700.0)             ; plate height
  (setq stiffThk   25.0)              ; column-web stiffener thickness
  (setq rafLen     2200.0)            ; rafter horizontal extent (each side)
  (setq rafRise     280.0)            ; rafter rise over rafLen
  (setq rafD        450.0)            ; rafter web depth
  (setq gutH        190.0)            ; gutter depth (real)
  (setq gutBotW     400.0)            ; gutter bottom flat
  (setq gutSideRun  200.0)            ; gutter side horizontal run (matches purlin pos)
  (setq gutFlangeW  114.0)            ; top flange width (each)
  ;; --- Derived ---
  (setq colTopY  (+ cyBase colH))      ; column body top
  (setq colLF    (- cx (/ colW 2.0)))  ; column LEFT flange face
  (setq colRF    (+ cx (/ colW 2.0)))  ; column RIGHT flange face
  (setq rafTopY  colTopY)              ; rafter top flange at column = column top
  (setq rafBotY  (- rafTopY rafD))
  (setq plateBotY (- rafBotY 50.0))
  (setq plateTopY (+ rafTopY 50.0))

  ;; ===== Column body =====
  (setvar "CLAYER" "FRAME")
  (command "RECTANG"
    (list colLF cyBase) (list colRF colTopY))

  ;; ===== Two rafters (sloped rectangles) =====
  ;; LEFT rafter: low end at column flange, high end out at -rafLen
  (setq rafLU_x (- colLF rafLen))                   ; left-rafter outer top corner (x)
  (setq rafLU_y (+ rafTopY rafRise))                ; outer top y (rises away from column)
  (setq rafLB_x rafLU_x)                            ; outer bottom corner same x
  (setq rafLB_y (- rafLU_y rafD))                   ; outer bottom y
  (command "PLINE"
    (list rafLU_x rafLU_y)                          ; outer top
    (list colLF   rafTopY)                          ; inner top (at col flange)
    (list colLF   rafBotY)                          ; inner bottom (at col flange)
    (list rafLB_x rafLB_y)                          ; outer bottom
    "C")
  ;; RIGHT rafter (mirror)
  (setq rafRU_x (+ colRF rafLen))
  (setq rafRU_y (+ rafTopY rafRise))
  (setq rafRB_x rafRU_x)
  (setq rafRB_y (- rafRU_y rafD))
  (command "PLINE"
    (list colRF   rafTopY)
    (list rafRU_x rafRU_y)
    (list rafRB_x rafRB_y)
    (list colRF   rafBotY)
    "C")

  ;; ===== Four vertical connection plates =====
  (setvar "CLAYER" "PLATES")
  ;; LEFT pair (col left + left-rafter end)
  (setq pLxR  colLF)
  (setq pLxL  (- pLxR plateThk))
  (setq pLxR2 pLxL)
  (setq pLxL2 (- pLxR2 plateThk))
  (command "RECTANG" (list pLxL  plateBotY) (list pLxR  plateTopY))
  (command "RECTANG" (list pLxL2 plateBotY) (list pLxR2 plateTopY))
  ;; RIGHT pair
  (setq pRxL  colRF)
  (setq pRxR  (+ pRxL plateThk))
  (setq pRxL2 pRxR)
  (setq pRxR2 (+ pRxL2 plateThk))
  (command "RECTANG" (list pRxL  plateBotY) (list pRxR  plateTopY))
  (command "RECTANG" (list pRxL2 plateBotY) (list pRxR2 plateTopY))
  ;; Bolt donuts (3 per pair-seam)
  (command "DONUT" 0 50.0 (list pLxL  (+ plateBotY 100.0)) "")
  (command "DONUT" 0 50.0 (list pLxL  (/ (+ plateBotY plateTopY) 2.0)) "")
  (command "DONUT" 0 50.0 (list pLxL  (- plateTopY 100.0)) "")
  (command "DONUT" 0 50.0 (list pRxR  (+ plateBotY 100.0)) "")
  (command "DONUT" 0 50.0 (list pRxR  (/ (+ plateBotY plateTopY) 2.0)) "")
  (command "DONUT" 0 50.0 (list pRxR  (- plateTopY 100.0)) "")
  ;; Column web stiffener at plate-bottom level
  (command "RECTANG"
    (list colLF (- plateBotY stiffThk)) (list colRF plateBotY))

  ;; ===== Two Z-shape valley purlins, UNDER the gutter lips =====
  ;; LOWER flange rests on the SLOPED rafter top.  Rafter top y at purlin
  ;; position (cx ± 460) = rafTopY + rafRise × (260/rafLen), where 260 mm
  ;; is the horizontal distance from column flange (colLF=cx−200) outward
  ;; to the purlin web (cx−460).
  (setq insetVY0 (+ rafTopY (* rafRise (/ 260.0 rafLen))))
  (draw-z-purlin-flat (- cx 460.0) insetVY0  1)
  (draw-z-purlin-flat (+ cx 460.0) insetVY0 -1)

  ;; ===== Valley gutter — LIPS rest on purlin UPPER FLANGE =====
  ;; LIPS at y = insetVY0 + 200; trough bottom at y = insetVY0 + 10.
  (setvar "CLAYER" "GUTTER")
  (setq gTopY (+ insetVY0 200.0))      ; gutter lip Y (= purlin upper flange)
  (setq gBotY (+ insetVY0  10.0))      ; gutter bottom Y
  (setq gBL   (- cx (/ gutBotW 2.0)))
  (setq gBR   (+ cx (/ gutBotW 2.0)))
  (setq gFLi  (- gBL gutSideRun))
  (setq gFLo  (- gFLi gutFlangeW))
  (setq gFRi  (+ gBR gutSideRun))
  (setq gFRo  (+ gFRi gutFlangeW))
  (command "PLINE"
    (list gFLo gTopY) "W" 1.5 1.5
    (list gFLi gTopY)
    (list gBL  gBotY)
    (list gBR  gBotY)
    (list gFRi gTopY)
    (list gFRo gTopY)
    "")
  (setvar "PLINEWID" 0.0)

  ;; ===== Roof sheeting — REST ON PURLINS at rafter_top + 200 =====
  ;; Sheet bottom follows rafter slope at +200 mm offset.
  ;; Sheet extends TOWARD the valley with 75 mm overlap INTO the gutter,
  ;; ending 75 mm inboard of the LIP INNER edge.
  ;; Sheet's Y at the break = (rafter slope y at break x) + 200.
  (setvar "CLAYER" "CLADDING")
  (setq sheetSlope (/ rafRise rafLen))
  ;; LEFT roof sheet (75 mm INWARD from LIP INNER edge → into the trough)
  (setq shLeftEnd     (+ gFLi 75.0))
  (setq shLeftEndY    (+ (+ rafLU_y (* (- rafTopY rafLU_y)
                                       (/ (- shLeftEnd rafLU_x) rafLen)))
                         200.0))
  (setq shLeftStartX  (- rafLU_x 100.0))
  (setq shLeftStartY  (+ rafLU_y 200.0))
  (command "LINE"
    (list shLeftStartX shLeftStartY)
    (list shLeftEnd    shLeftEndY) "")
  (command "LINE"
    (list shLeftStartX (+ shLeftStartY 35.0))
    (list shLeftEnd    (+ shLeftEndY  35.0)) "")
  ;; End-cap closing the LEFT sheet's 2 lines at the break
  (command "LINE"
    (list shLeftEnd shLeftEndY)
    (list shLeftEnd (+ shLeftEndY 35.0)) "")
  ;; RIGHT roof sheet (mirror)
  (setq shRightEnd    (- gFRi 75.0))
  (setq shRightEndY   (+ (+ rafRU_y (* (- rafTopY rafRU_y)
                                       (/ (- rafRU_x shRightEnd) rafLen)))
                         200.0))
  (setq shRightStartX (+ rafRU_x 100.0))
  (setq shRightStartY (+ rafRU_y 200.0))
  (command "LINE"
    (list shRightEnd    shRightEndY)
    (list shRightStartX shRightStartY) "")
  (command "LINE"
    (list shRightEnd    (+ shRightEndY 35.0))
    (list shRightStartX (+ shRightStartY 35.0)) "")
  ;; End-cap closing the RIGHT sheet's 2 lines at the break
  (command "LINE"
    (list shRightEnd shRightEndY)
    (list shRightEnd (+ shRightEndY 35.0)) "")

  ;; ===== Labels with leaders =====
  (setvar "CLAYER" "TEXT")
  (setq tH 180.0)
  ;; VALLEY GUTTER (top centre, leader pointing down to gutter trough)
  (setq tx (- cx 2500.0))
  (setq ty (+ gTopY 1200.0))
  (txt "ML" (list tx ty) tH 0 "VALLEY GUTTER")
  (draw-l-leader (+ tx 50.0) (- ty 80.0) cx (+ gBotY 60.0) "V")
  ;; ROOF PANEL (left top)
  (setq tx (- shLeftStartX 1800.0))
  (setq ty (+ shLeftStartY 600.0))
  (txt "ML" (list tx ty) tH 0 "ROOF PANEL")
  (draw-l-leader (+ tx 50.0) (- ty 80.0)
                 (/ (+ shLeftStartX shLeftEnd) 2.0)
                 (+ (/ (+ shLeftStartY gTopY) 2.0) 35.0) "V")
  ;; INSIDE FOAM CLOSURE (left, leader pointing to corner near sheet end on flange)
  (setq tx (- shLeftStartX 1800.0))
  (setq ty (- shLeftStartY 200.0))
  (txt "ML" (list tx ty) tH 0 "INSIDE FOAM CLOSURE")
  (draw-l-leader (+ tx 50.0) (- ty 80.0) (- shLeftEnd 80.0) (+ gTopY 50.0) "V")
  ;; SDS SCREW (right top)
  (setq tx (+ shRightStartX 200.0))
  (setq ty (+ shRightStartY 600.0))
  (txt "ML" (list tx ty) tH 0 "SDS 5.5x40 SELF DRILLING SCREW")
  (draw-l-leader (+ tx 50.0) (- ty 80.0)
                 (/ (+ shRightStartX shRightEnd) 2.0)
                 (+ (/ (+ shRightStartY gTopY) 2.0) 35.0) "V")
  ;; C-SECTION OR Z-SECTION PURLIN (right)
  (setq tx (+ shRightStartX 200.0))
  (setq ty (- shRightStartY 200.0))
  (txt "ML" (list tx ty) tH 0 "C-SECTION OR 'Z' SECTION PURLIN")
  (draw-l-leader (+ tx 50.0) (- ty 80.0)
                 (- shRightStartX 80.0)
                 (+ shRightStartY 80.0) "V")
  ;; MAIN FRAME RAFTER (right side)
  (setq tx (+ rafRU_x 200.0))
  (setq ty (- (/ (+ rafRU_y rafRB_y) 2.0) 100.0))
  (txt "ML" (list tx ty) tH 0 "MAIN FRAME RAFTER")
  (draw-l-leader (+ tx 50.0) ty (- rafRU_x 800.0) ty "H")
  ;; MAIN FRAME COLUMN (left of column, leader pointing right)
  (setq tx (- colLF 2400.0))
  (setq ty (+ cyBase (/ colH 2.0)))
  (txt "ML" (list tx ty) tH 0 "MAIN FRAME COLUMN")
  (draw-l-leader (+ tx (* tH 11) 50.0) ty colLF ty "H")

  ;; ===== Title under the detail =====
  (setq tx cx)
  (setq ty (- cyBase 600.0))
  (txt-bold "MC" (list tx ty) 280 0 "DETAIL-A: TYPICAL VALLEY DETAILS")
  ;; Underline
  (command "LINE"
    (list (- cx 3500.0) (- ty 220.0))
    (list (+ cx 3500.0) (- ty 220.0)) "")
  (setvar "PLINEWID" 0.0)
)

(defun draw-floor-line (W ext / y0 i xt step)
  ;;  Ground / FFL line, slightly extended beyond columns
  (setvar "CLAYER" "GROUND")
  (setq y0 0.0)
  (command "LINE" (list (- 0.0 ext) y0) (list (+ W ext) y0) "")
  ;; Hatching beneath ground line - short tick marks
  (setvar "CLAYER" "GROUND-HATCH")
  (setq step (* 800 *PEB-TEXT-SCALE*))
  (setq i 0)
  (while (<= (* i step) (+ W (* 2 ext)))
    (setq xt (+ (- 0.0 ext) (* i step)))
    (command "LINE"
      (list xt y0)
      (list (- xt (* 250 *PEB-TEXT-SCALE*)) (- y0 (* 350 *PEB-TEXT-SCALE*)))
      "")
    (setq i (1+ i))
  )
)

(defun draw-ffl-marker (x y / s halfW topY tipY tickLen)
  ;;  "FFL ±0.00" elevation marker:
  ;;    - downward-pointing FILLED triangle, tip touching the FFL line
  ;;    - short horizontal tick at the line under the triangle
  ;;    - "FFL ±0.00" text label to the right of the triangle
  ;;
  ;;  Standard architectural elevation reference symbol.
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setq s       *PEB-TEXT-SCALE*)
  (setq halfW   (* 200 s))                ; half-width of triangle base
  (setq topY    (+ y (* 400 s)))          ; triangle top edge above FFL
  (setq tipY    y)                        ; triangle tip on FFL line
  (setq tickLen (* 500 s))                ; horizontal tick under triangle
  (setvar "CLAYER" "DIMENSIONS")
  ;; FILLED triangle — SOLID command takes 4 points (last two same for tri)
  (command "SOLID"
    (list (- x halfW) topY)
    (list (+ x halfW) topY)
    (list x tipY)
    (list x tipY)
    "")
  ;; Short horizontal tick line at FFL under the triangle apex
  (setvar "CLAYER" "DIMENSIONS")
  (command "LINE"
    (list (- x tickLen) y)
    (list (+ x tickLen) y) "")
  ;; "FFL ±0.00" text label, baseline left-anchored just right of triangle
  (txt "ML"
       (list (+ x halfW (* 250 s)) (+ y (* 200 s)))
       (* 220 s) 0
       "FFL \\U+00B100.00")
)

(defun draw-slope-symbol (cx cy slopeStr slopeD / s rise run aL ax ay bx by)
  ;;  Triangle slope symbol with "1 / N" label  (legacy, larger format)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setq s *PEB-TEXT-SCALE*)
  (setvar "CLAYER" "ARROWS")
  (setq aL  (* 1200 s))             ; horizontal length of triangle
  (setq run aL)
  (setq rise (/ run slopeD))
  (setq ax cx ay cy)
  (setq bx (+ cx run) by (+ cy rise))
  ;; hypotenuse
  (command "LINE" (list ax ay) (list bx by) "")
  ;; horizontal
  (command "LINE" (list ax ay) (list bx ay) "")
  ;; vertical
  (command "LINE" (list bx ay) (list bx by) "")
  ;; Labels
  (txt "MC" (list (+ cx (/ run 2.0)) (- ay (* 240 s))) 200 0 (rtos slopeD 2 0))
  (txt "MC" (list (+ bx (* 240 s)) (+ ay (/ rise 2.0))) 200 0 "1")
  (txt-bold "MC" (list (+ cx (/ run 2.0)) (+ by (* 350 s))) 240 0 (strcat "SLOPE " slopeStr))
)

(defun draw-slope-tag (cx cy slopeD upRight / s run rise ax ay bx by labX labY labOne)
  ;;  Compact MAIMAAR-style slope tag: small right triangle showing the
  ;;  rise/run ratio.  Labels read "1" next to the vertical leg and the
  ;;  denominator (e.g. "10") below the horizontal leg.
  ;;  upRight = +1 → triangle extends RIGHT from cx (vertical leg on RIGHT,
  ;;                  apex at upper-RIGHT, hypotenuse goes UP-RIGHT)
  ;;  upRight = -1 → triangle extends LEFT  from cx (vertical leg on LEFT,
  ;;                  apex at upper-LEFT, hypotenuse goes UP-LEFT)
  ;;
  ;;  Triangle rises UP from (cx, cy):
  ;;     - horizontal leg sits at the BOTTOM (= y=cy)
  ;;     - vertical leg rises UP by `rise` from one end of the horizontal
  ;;     - apex (right angle vertex) is at (bx, cy)
  ;;     - hypotenuse runs from (cx, cy) UP to (bx, cy+rise)
  ;;
  ;;  Per MAIMAAR convention the hypotenuse FOLLOWS the rafter slope
  ;;  direction — the caller positions cx/cy so the hypotenuse is
  ;;  parallel to the rafter top flange, offset above the sheeting.
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setq s *PEB-TEXT-SCALE*)
  (setvar "CLAYER" "ARROWS")
  (setq run  (* 900 s))                  ; slightly larger run for visibility
  (setq rise (/ run slopeD))
  (setq ax cx ay cy)
  ;; Triangle rises UP from cy by `rise`.
  (setq bx (+ cx (* upRight run)) by (+ cy rise))
  ;; Triangle: hypotenuse + horizontal leg + vertical leg
  (command "LINE" (list ax ay) (list bx by) "")        ; hypotenuse
  (command "LINE" (list ax ay) (list bx ay) "")        ; horizontal leg (BOTTOM)
  (command "LINE" (list bx ay) (list bx by) "")        ; vertical leg (UP)
  ;; "denominator" label BELOW horizontal leg, centred on the leg's midpoint.
  ;; Y math: cy is positioned 300·s above sheeting top (set by caller),
  ;; so sheeting top is at cy - 300·s.  We want the text bottom 50 mm
  ;; above sheeting top to guarantee no overlap at any scale.
  ;;   text bottom = labY - 110·s ≥ sheetingTop + 50
  ;;   labY ≥ sheetingTop + 50 + 110·s = cy - 300·s + 50 + 110·s
  ;;   labY ≥ cy - 190·s + 50
  ;; Use exactly that — places "10" JUST above sheeting.
  (setq labX (+ cx (/ (* upRight run) 2.0)))
  (setq labY (+ (- ay (* 190 s)) 50.0))
  (txt "MC" (list labX labY) 220 0 (rtos slopeD 2 0))
  ;; "1" label outside the vertical leg, vertically centred on its midpoint
  (setq labOne (+ bx (* upRight 220 s)))
  (txt "MC" (list labOne (+ ay (/ rise 2.0))) 220 0 "1")
)

(defun draw-brick-wall (W brickH / bw y nextY row brickLen)
  ;;  Brick walls on the outside of LEFT and RIGHT side columns.
  ;;  Each brick drawn as an INDIVIDUAL RECTANGLE outline, alternating
  ;;  full-stretcher and offset half-bricks for a running bond look.
  (if (and brickH (> brickH 0))
    (progn
      (setvar "CLAYER" "BRICK-WALL")
      (setq bw       200.0)    ; 200mm exact, aligns with girt outer face
      (setq brickLen 80.0)     ; brick course height (mm)

      ;; --- LEFT brick wall ---
      (command "RECTANG" (list (- 0.0 bw) 0.0) (list 0.0 brickH))
      ;; Try real BRICK hatch first (gives proper running bond pattern)
      (command "HATCH" "BRICK" 150 0 "L" "")

      ;; --- RIGHT brick wall ---
      (command "RECTANG" (list W 0.0) (list (+ W bw) brickH))
      (command "HATCH" "BRICK" 150 0 "L" "")

      ;; "BRICK WALL" side labels removed per user request — the brick
      ;; masonry is already called out via the dim override
      ;; "<>\\PBRICK MASONRY", so the duplicate vertical text on each
      ;; side of the hatch was redundant.
      (setvar "CLAYER" "TEXT")
    )
  )
)

(defun draw-cladding (data W H rise brickH /
                       cladThk purlinH girtDepth slopeLen sa ca y d xT yT slpDrop ribStep roofLbl wallLbl
                       labRX labRY labWX labWY leadX leadYStart leadYEnd
                       rParts rLine1 rLine2 rBarY rBarLen rTargetY rDx rTextW rWrapW
                       nRSpec rRectPad rRectTop rRectBot
                       wParts wLine1 wLine2 wBarY wBarLen wTargetX wTextW wTargetY wWrapW
                       nWSpec wRectPad wRectTop wRectBot wBotY wExtX wArrowBase
                       wLine2_2L wCombined wHeadY wSpecY
                       rLine2_2L rCombined rHeadY rSpecY
                       lastBefore mlText mlResult mtResult)
  ;;  Wall sheeting (above brick, on side walls) and roof cladding
  ;;  (above rafters, along the slope).  Drawn as a single line with
  ;;  small rib ticks every 750 mm representing the sheet ribs.
  (setvar "CLAYER" "CLADDING")
  (setq cladThk   35.0)
  (setq purlinH   200.0)
  (setq girtDepth 200.0)  ; girt depth = wall sheeting sits this far outside column
  (setq ribStep  750.0)   ; (legacy) rib tick spacing
  (setq slopeLen (sqrt (+ (expt (/ W 2.0) 2) (expt rise 2))))
  (setq sa (/ rise slopeLen))
  (setq ca (/ (/ W 2.0) slopeLen))

  ;; --- LEFT wall sheeting (2 vertical lines OUTSIDE girts, 50mm overlap on brick) ---
  (if (< brickH H)
    (progn
      ;; sheeting extends 50mm BELOW brickH to overlap the brick wall
      (command "LINE"
        (list (- 0.0 girtDepth) (- brickH 50.0))
        (list (- 0.0 girtDepth) H) "")
      (command "LINE"
        (list (- 0.0 girtDepth cladThk) (- brickH 50.0))
        (list (- 0.0 girtDepth cladThk) H) "")
      ;; Top cap at eave
      (command "LINE"
        (list (- 0.0 girtDepth)         H)
        (list (- 0.0 girtDepth cladThk) H) "")
      ;; Bottom cap at brick overlap point (50mm below brick top)
      (command "LINE"
        (list (- 0.0 girtDepth)         (- brickH 50.0))
        (list (- 0.0 girtDepth cladThk) (- brickH 50.0)) "")
    )
  )

  ;; --- RIGHT wall sheeting (2 vertical lines OUTSIDE girts, 50mm overlap on brick) ---
  (if (< brickH H)
    (progn
      (command "LINE"
        (list (+ W girtDepth) (- brickH 50.0))
        (list (+ W girtDepth) H) "")
      (command "LINE"
        (list (+ W girtDepth cladThk) (- brickH 50.0))
        (list (+ W girtDepth cladThk) H) "")
      (command "LINE"
        (list (+ W girtDepth)         H)
        (list (+ W girtDepth cladThk) H) "")
      (command "LINE"
        (list (+ W girtDepth)         (- brickH 50.0))
        (list (+ W girtDepth cladThk) (- brickH 50.0)) "")
    )
  )

  ;; --- ROOF SHEETING: 2 parallel sloped lines, extended 70mm into the
  ;; gutter at each eave (= 270 mm beyond column outer flange line). ---
  ;; Slope drop over 270mm = 270 * sa / ca.
  (setq slpDrop (* 270.0 (/ sa ca)))
  ;; LEFT half: extend to x = -270, y drops by slpDrop from eave value
  (command "LINE"
    (list -270.0    (+ H purlinH (- 0 slpDrop)))
    (list (/ W 2.0) (+ H rise purlinH))
    "")
  (command "LINE"
    (list -270.0    (+ H purlinH cladThk (- 0 slpDrop)))
    (list (/ W 2.0) (+ H rise purlinH cladThk))
    "")
  ;; RIGHT half: extend to x = W+270
  (command "LINE"
    (list (/ W 2.0)   (+ H rise purlinH))
    (list (+ W 270.0) (+ H purlinH (- 0 slpDrop)))
    "")
  (command "LINE"
    (list (/ W 2.0)   (+ H rise purlinH cladThk))
    (list (+ W 270.0) (+ H purlinH cladThk (- 0 slpDrop)))
    "")
  ;; Eave caps (vertical) at the new extended ends
  (command "LINE"
    (list -270.0 (+ H purlinH (- 0 slpDrop)))
    (list -270.0 (+ H purlinH cladThk (- 0 slpDrop)))
    "")
  (command "LINE"
    (list (+ W 270.0) (+ H purlinH (- 0 slpDrop)))
    (list (+ W 270.0) (+ H purlinH cladThk (- 0 slpDrop)))
    "")

  ;; --- Labels with L-shaped (90-deg) leader arrows ----
  (setvar "CLAYER" "TEXT")
  (setq roofLbl (MSPL-Get-Str data "ROOFSHEETING"))
  (if (= roofLbl "") (setq roofLbl "ROOF CLADDING 50mm PIR SANDWICH PANEL"))
  (setq wallLbl (MSPL-Get-Str data "WALLSHEETING"))
  (if (= wallLbl "") (setq wallLbl "WALL SHEETING 50mm PIR SANDWICH PANEL"))
  ;; ROOF CLADDING label - 2 lines with horizontal line BETWEEN them.
  ;;   Line 1 (above bar): "ROOF CLADDING:" prefix
  ;;   Line 2 (below bar): the spec (e.g. "50mm PIR SANDWICH PANEL")
  ;; Vertical leader drops from LEFT end of horizontal bar straight down to sheeting.
  (setq rParts (split-at-first-digit roofLbl))
  (setq rLine1 (strcat (car rParts) ":"))
  (setq rLine2 (cadr rParts))
  ;; ROOF CLADDING label X: locked at 1/3 of the half-rafter span IN
  ;; FROM the right eave (per user clarification: "1/3 from right side
  ;; eave").  rWrapW sized to fit the remaining halfR/3 of available
  ;; space to the right edge minus a small margin.
  (setq labRX  (- W (/ (/ W 2.0) 3.0)))             ; W - halfR/3
  (setq rWrapW (max 1500.0
                    (min 8000.0
                         (- (- W labRX) (* 300 *PEB-TEXT-SCALE*)))))
  (setq rTextW rWrapW)                              ; back-compat
  ;; Anchor labRY to the SAME Y as the wall sheeting labWY so both
  ;; sheeting MLEADERs sit on the same horizontal level (per user
  ;; spec).  Wall sheeting uses H + 1800·TS, so roof sheeting matches.
  (setq labRY (+ H (* 2700 *PEB-TEXT-SCALE*)))
  ;; Hand-rolled bar+drop+arrow leader, wrapped in a GROUP after.
  ;; (MLEADER attempt was here but disabled — see peb-make-mleader
  ;; comment for the reason.)
  (setq rDx (abs (- labRX (/ W 2.0))))
  (setq rTargetY (- (+ H rise purlinH cladThk)
                    (* rise (/ rDx (/ W 2.0)))))
  (setq lastBefore (entlast))
  (cond
    (rLine2
      ;; --- ONE 3-vertex MLEADER carrying heading + spec ---
      ;;
      ;; LAYOUT (same rules as wall sheeting, just 3 vertices):
      ;;     ROOF CLADDING:                  ← line 1 (BOLD), ABOVE bar
      ;;   ═══●─── 0.50MM AZ 150 ...         ← bar (v1-v2)
      ;;     50MM PIR ...                     ← line 2-3, BELOW bar
      ;;     │
      ;;     │   ← vertical leg (v0-v1)
      ;;     │
      ;;     ▼   ← arrow tip on roof sheeting line (v0)
      ;;
      ;; Vertices:
      ;;   v0 = arrow tip on roof sheeting (lower)
      ;;   v1 = top of vertical leg (= bar's LEFT end)
      ;;   v2 = bar's RIGHT end (= text landing point)
      ;;
      ;; TextLeftAttachmentType = 5 (BottomOfTopLine) anchors v2 at
      ;; the bottom of the heading line — heading floats above bar Y,
      ;; spec lines drop below bar Y.  Heading bold via inline MText
      ;; format code "{\\fArial|b1; … }".
      (setvar "CLAYER" "TEXT")
      ;; Pre-split spec into max 2 lines (same as wall sheeting).
      (setq rLine2_2L (peb-split-2-lines rLine2))
      (setq rBarY     (+ labRY (* 175 *PEB-TEXT-SCALE*)))
      (setq rBarLen   300.0)                  ; 300 mm bar (Option B)
      (setq rCombined
        (strcat "{\\fArial|b1;" rLine1 "}\\P" rLine2_2L))
      ;; --- Try 3-vertex MLEADER with combined text -----------------
      (setq mlResult
        (vl-catch-all-apply 'peb-make-mleader
          (list
            ;; vertex list, arrow tip first → text landing last
            (list (list labRX rTargetY)         ; v0 arrow tip on sheeting
                  (list labRX rBarY)            ; v1 top of vertical leg
                  (list (+ labRX rBarLen) rBarY)) ; v2 text landing (bar end)
            rCombined)))
      (cond
        ((vl-catch-all-error-p mlResult)
          ;; --- Fallback: hand-rolled heading + bar + drop + arrow --
          (setq rHeadY (+ rBarY (* 220 *PEB-TEXT-SCALE*)))
          (setq rSpecY (- rBarY (* 60  *PEB-TEXT-SCALE*)))
          ;; Heading bold above bar
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labRX rHeadY)
                    (* 220.0 *PEB-TEXT-SCALE*) 0 "ML"
                    (strcat "{\\fArial|b1;" rLine1 "}"))))
          (if (vl-catch-all-error-p mtResult)
            (txt "ML" (list labRX rHeadY) 220 0 rLine1))
          ;; Spec regular below bar
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labRX rSpecY)
                    (* 220.0 *PEB-TEXT-SCALE*) 0 "TL" rLine2_2L)))
          (if (vl-catch-all-error-p mtResult)
            (setq nRSpec (txt-wrap "TL" (list labRX rSpecY) 220 0 rBarLen rLine2_2L)))
          (setvar "CLAYER" "ARROWS")
          (setvar "PLINEWID" 0.0)
          ;; Bar
          (command "LINE"
            (list labRX rBarY)
            (list (+ labRX rBarLen) rBarY) "")
          ;; Vertical leader DOWN from LEFT end of bar to sheeting target
          (command "LINE"
            (list labRX rBarY)
            (list labRX (+ rTargetY (* 1200 *PEB-TEXT-SCALE*))) "")
          ;; Arrow tip on the roof sheeting line — 4× wider
          (command "PLINE"
            (list labRX (+ rTargetY (* 1200 *PEB-TEXT-SCALE*)))
            "W" (* 320 *PEB-TEXT-SCALE*) 0
            (list labRX rTargetY) "")
          (setvar "PLINEWID" 0.0))
        (T
          ;; MLEADER succeeded — set attachment so heading sits above
          ;; bar and spec drops below.
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextAttachmentDirection mlResult 0))))
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextLeftAttachmentType  mlResult 5))))
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextRightAttachmentType mlResult 5))))
        )
      )
    )
    (T
      ;; --- Single-line fallback ---
      (txt "ML" (list labRX labRY) 220 0 roofLbl)
      (draw-l-leader (+ labRX (* 5000 *PEB-TEXT-SCALE*))
                     (- labRY (* 250 *PEB-TEXT-SCALE*))
                     (+ (/ W 2.0) (* 1500 *PEB-TEXT-SCALE*))
                     (+ H rise purlinH cladThk)
                     "V")))
  ;; Group the hand-rolled drawing so click-once-select-all works.
  (peb-group-entities (peb-collect-entities-since lastBefore) "PEBLBL")
  ;; WALL SHEETING label with Γ-shape leader on the LEFT.
  ;; Layout (per user spec):
  ;;   Line 1 ("WALL SHEETING:")               ← above the bar
  ;;   ════════════ bar (apex) ════════         ← extends 400mm LEFT past sheeting
  ;;   spec line 1..N (wrapped)
  ;;   |
  ;;   |   ← vertical line dropping from APEX EXTENSION end
  ;;   |
  ;;   ────────► (arrow) at wall sheet
  (setq wParts (split-at-first-digit wallLbl))
  (setq wLine1 (strcat (car wParts) ":"))
  (setq wLine2 (cadr wParts))
  (setq labWX (- 0 girtDepth cladThk))           ; -235 (sheet outer face)
  ;; Anchor labWY clear of the EAVE GUTTER label below it.  Eave gutter
  ;; sits at gyTopOut + 450·TS ≈ H + 681 + 450·TS.  Three wrapped lines
  ;; of wall spec eat ~3·220·TS = 660·TS of space below labWY, so
  ;; labWY must clear that band by at least one text height.  Using
  ;; H + 1800·TS ensures the wall text bottom stays well above the
  ;; gutter label across all reasonable scales.
  (setq labWY (+ H (* 2700 *PEB-TEXT-SCALE*)))
  ;; wWrapW: tighter cap so wall MTEXT doesn't sprawl past mid-rafter
  ;; into the PURLIN label area on narrow buildings.  Was halfL/2 minus
  ;; margin (still 3–4 m wide on a 15 m building); now halfL × 0.3
  ;; which leaves more rafter space for other labels.  Floor 1200 mm
  ;; so very narrow sections still produce a useable wrap.
  (setq wWrapW (max 1200.0
                    (min 8000.0
                         (* (/ W 2.0) 0.3))))
  ;; Hand-rolled Γ-shape leader (apex bar + drop + arrow), grouped after.
  ;; MLEADER attempt was here but disabled.
  ;; Arrow tip Y: raised to 300 mm BELOW the clear-height (eave H) line
  ;; per user spec.  Was previously mid-wall between brick top and eave.
  (setq wTargetY (- H 300.0))
  (setq lastBefore (entlast))
  (cond
    (wLine2
      ;; --- ONE 4-vertex MLEADER carrying heading + spec ---
      ;;
      ;; LAYOUT:
      ;;     WALL SHEETING:                                       ← line 1 (BOLD), ABOVE bar
      ;;   ════════════════════════════════ ●v3                   ← bar (MLEADER v2-v3)
      ;;     0.50MM AZ 150 + 50MM FIBERGLASS                      ← line 2, BELOW bar
      ;;     INSULATION + 0.50MM AZ 150 LINER                     ← line 3, BELOW bar
      ;;   │
      ;;   │   ← vertical leg (v1-v2)
      ;;   │
      ;;   ───►   ← arrow leg (v0-v1) into wall sheeting line
      ;;
      ;; Trick: TextLeftAttachmentType = 5 (BottomOfTopLine) anchors
      ;; v3 at the BOTTOM of the FIRST line of text.  Since the first
      ;; line is the heading, that bottom edge sits at the bar Y, so
      ;; the heading floats ABOVE bar and all subsequent lines (after
      ;; \\P) drop BELOW the bar.
      ;;
      ;; Heading is rendered bold via inline MText format code
      ;; "{\\fArial|b1; … }" so the surrounding spec text stays in
      ;; regular weight at the same 220·TS body size.
      (setvar "CLAYER" "TEXT")
      ;; Force the spec text to AT MOST 2 lines via explicit paragraph
      ;; break.  Heading + spec then becomes a 3-line block
      ;; (heading\\Pspec1\\Pspec2) that splits cleanly across the bar.
      (setq wLine2_2L (peb-split-2-lines wLine2))
      (setq wBarY      (+ labWY (* 175 *PEB-TEXT-SCALE*)))
      ;; Bar length — Option B per user: 300 mm horizontal v2-v3
      ;; segment so the text lands right next to the bar.
      (setq wBarLen    300.0)
      ;; Extension distance — was 400 mm; bumped to 1500 mm because
      ;; AutoCAD's MLEADER suppresses the arrowhead when the v0-v1
      ;; segment is shorter than the arrow size.  GIRT MLEADER works
      ;; (its arrow segment is ~1900 mm), so we match that length here.
      (setq wExtX      (- labWX 1500.0))           ; -1735 (extension end)
      ;; Combined MLEADER text:
      ;;   line 1 = bold "WALL SHEETING:"   (above bar)
      ;;   line 2-3 = spec, 2 lines split   (below bar)
      ;; \\P is MText paragraph break.
      (setq wCombined
        (strcat "{\\fArial|b1;" wLine1 "}\\P" wLine2_2L))
      ;; --- Try 4-vertex MLEADER with combined text -----------------
      ;; Bar (v2-v3) is exactly 300 mm long: v2 at wExtX, v3 at
      ;; wExtX + 300.  Text starts at v3 going RIGHT, landing right
      ;; next to the bar instead of far off-screen.
      (setq mlResult
        (vl-catch-all-apply 'peb-make-mleader
          (list
            ;; vertex list, arrow tip first → text landing last
            (list (list labWX wTargetY)              ; v0 arrow tip on wall
                  (list wExtX wTargetY)              ; v1 elbow near arrow
                  (list wExtX wBarY)                 ; v2 elbow at bar (LEFT)
                  (list (+ wExtX 300.0) wBarY))      ; v3 text landing (300 mm right)
            wCombined)))                             ; heading + spec
      (cond
        ((vl-catch-all-error-p mlResult)
          ;; --- Fallback: hand-rolled heading + Γ leader + spec -----
          (setq wHeadY (+ wBarY (* 220 *PEB-TEXT-SCALE*)))
          (setq wSpecY (- wBarY (* 60  *PEB-TEXT-SCALE*)))
          ;; Heading bold above bar
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labWX wHeadY)
                    (* 220.0 *PEB-TEXT-SCALE*) 0 "ML"
                    (strcat "{\\fArial|b1;" wLine1 "}"))))
          (if (vl-catch-all-error-p mtResult)
            (txt "ML" (list labWX wHeadY) 220 0 wLine1))
          ;; Spec regular below bar
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labWX wSpecY)
                    (* 220.0 *PEB-TEXT-SCALE*) 0 "TL" wLine2_2L)))
          (if (vl-catch-all-error-p mtResult)
            (txt-wrap "TL" (list labWX wSpecY) 220 0 wBarLen wLine2_2L))
          (setvar "CLAYER" "ARROWS")
          (setvar "PLINEWID" 0.0)
          ;; Apex bar - 300 mm long (Option B per user)
          (command "LINE"
            (list wExtX wBarY)
            (list (+ wExtX 300.0) wBarY) "")
          ;; Vertical drop from extension end down to wall mid-height
          (command "LINE"
            (list wExtX wBarY)
            (list wExtX wTargetY) "")
          ;; Horizontal line going RIGHT from extension end to wall sheet
          (command "LINE"
            (list wExtX wTargetY)
            (list (- labWX (* 1200 *PEB-TEXT-SCALE*)) wTargetY) "")
          ;; Arrow tip on the wall sheeting line — 4× wider than before
          (command "PLINE"
            (list (- labWX (* 1200 *PEB-TEXT-SCALE*)) wTargetY)
            "W" (* 320 *PEB-TEXT-SCALE*) 0
            (list labWX wTargetY) "")
          (setvar "PLINEWID" 0.0))
        (T
          ;; MLEADER succeeded.  Set TextLeftAttachmentType = 5
          ;; (BottomOfTopLine) so v3 anchors at the bottom of the
          ;; HEADING line — heading sits above bar, spec sits below.
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextAttachmentDirection mlResult 0))))    ; horizontal
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextLeftAttachmentType  mlResult 5))))    ; BottomOfTopLine
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextRightAttachmentType mlResult 5))))    ; BottomOfTopLine
        )
      )
    )
    (T
      ;; --- Single-line fallback ---
      (txt "ML" (list labWX labWY) 220 0 wallLbl)))
  ;; Group the hand-rolled drawing for click-once-select-all.
  (peb-group-entities (peb-collect-entities-since lastBefore) "PEBLBL")
  (setvar "PLINEWID" 0.0)
)

(defun draw-cladding-mg (data W H rise brickH numGab /
                         cladThk purlinH girtDepth gW i gxL gxR ridgeX y ribStep
                         slopeLen sa ca slpDrop d xT yT roofLbl wallLbl
                         rParts rLine1 rLine2 rBarY rBarLen rTargetY rDx rTextW rWrapW nRSpec
                         rLine2_2L rCombined mlResult mtResult
                         labRX labRY gxL_last ridgeX_last
                         wParts wLine1 wLine2 wBarY wBarLen wTargetY wWrapW
                         wLine2_2L wCombined wHeadY wSpecY
                         labWX labWY wExtX wArrowBase
                         breakX breakY)
  ;;  MG-specific cladding: roof cladding follows each gable's
  ;;  ridge/valley profile, side wall sheeting only on the OUTER walls.
  (setvar "CLAYER" "CLADDING")
  (setq cladThk   35.0)
  (setq purlinH   200.0)
  (setq girtDepth 200.0)  ; girt depth = wall sheeting sits this far outside column face
  (setq ribStep   750.0)
  (setq gW (/ W numGab))
  ;; Slope geometry per gable (used for outer eave extension of roof sheeting below)
  (setq slopeLen (sqrt (+ (* (/ gW 2.0) (/ gW 2.0)) (* rise rise))))
  (setq sa (/ rise slopeLen))
  (setq ca (/ (/ gW 2.0) slopeLen))
  (setq slpDrop (* 270.0 (/ sa ca)))     ; Y-drop over 270mm horizontal eave overhang
  ;; --- LEFT outer wall sheeting (2 lines OUTSIDE girts, 50 mm overlap on brick) ---
  (if (< brickH H)
    (progn
      (command "LINE"
        (list (- 0.0 girtDepth)         (- brickH 50.0))
        (list (- 0.0 girtDepth)         H) "")
      (command "LINE"
        (list (- 0.0 girtDepth cladThk) (- brickH 50.0))
        (list (- 0.0 girtDepth cladThk) H) "")
      (command "LINE"
        (list (- 0.0 girtDepth)         H)
        (list (- 0.0 girtDepth cladThk) H) "")
      (command "LINE"
        (list (- 0.0 girtDepth)         (- brickH 50.0))
        (list (- 0.0 girtDepth cladThk) (- brickH 50.0)) "")
    )
  )
  ;; --- RIGHT outer wall sheeting ---
  (if (< brickH H)
    (progn
      (command "LINE"
        (list (+ W girtDepth)           (- brickH 50.0))
        (list (+ W girtDepth)           H) "")
      (command "LINE"
        (list (+ W girtDepth cladThk)   (- brickH 50.0))
        (list (+ W girtDepth cladThk)   H) "")
      (command "LINE"
        (list (+ W girtDepth)           H)
        (list (+ W girtDepth cladThk)   H) "")
      (command "LINE"
        (list (+ W girtDepth)           (- brickH 50.0))
        (list (+ W girtDepth cladThk)   (- brickH 50.0)) "")
    )
  )
  ;; --- Roof sheeting per gable: 2 parallel lines on top of purlins ---
  ;; Outer eaves (i=0 left, i=numGab-1 right) extend 270mm past the column face,
  ;; matching the CS eave gutter overhang.  Inner gable junctions end at column CL.
  (setq i 0)
  (while (< i numGab)
    (setq gxL    (* i gW))
    (setq gxR    (+ gxL gW))
    (setq ridgeX (/ (+ gxL gxR) 2.0))
    ;; LEFT half of this gable
    (if (= i 0)
      (progn
        ;; Outer left eave: extend sheeting 270mm past column to match gutter
        (command "LINE"
          (list -270.0  (+ H purlinH (- 0 slpDrop)))
          (list ridgeX  (+ H rise purlinH)) "")
        (command "LINE"
          (list -270.0  (+ H purlinH cladThk (- 0 slpDrop)))
          (list ridgeX  (+ H rise purlinH cladThk)) "")
        ;; Eave cap at extension end
        (command "LINE"
          (list -270.0  (+ H purlinH (- 0 slpDrop)))
          (list -270.0  (+ H purlinH cladThk (- 0 slpDrop))) "")
      )
      (progn
        ;; Inner valley boundary: sheeting STAYS at +200 above rafter top
        ;; (rests on regular roof purlins).  Sheet extends TOWARD the
        ;; valley with 75 mm overlap INTO the gutter trough.
        ;; Break point = 75 mm INWARD from the gutter LIP INNER edge
        ;; (gxL+340 → gxL+265).
        ;; Y at break point = H + purlinH + slope rise at that x.
        (setq breakX (+ gxL 265.0))
        (setq breakY (+ H purlinH
                        (/ (* rise 265.0) (- ridgeX gxL))))
        (command "LINE"
          (list breakX breakY)
          (list ridgeX (+ H rise purlinH)) "")
        (command "LINE"
          (list breakX (+ breakY cladThk))
          (list ridgeX (+ H rise purlinH cladThk)) "")
        ;; End-cap: close sheet's 2 lines with a vertical face at the break
        (command "LINE"
          (list breakX  breakY)
          (list breakX (+ breakY cladThk)) "")
      )
    )
    ;; RIGHT half of this gable
    (if (= i (1- numGab))
      (progn
        ;; Outer right eave: extend 270mm
        (command "LINE"
          (list ridgeX     (+ H rise purlinH))
          (list (+ W 270.0) (+ H purlinH (- 0 slpDrop))) "")
        (command "LINE"
          (list ridgeX     (+ H rise purlinH cladThk))
          (list (+ W 270.0) (+ H purlinH cladThk (- 0 slpDrop))) "")
        ;; Eave cap at extension end
        (command "LINE"
          (list (+ W 270.0) (+ H purlinH (- 0 slpDrop)))
          (list (+ W 270.0) (+ H purlinH cladThk (- 0 slpDrop))) "")
      )
      (progn
        ;; Inner valley boundary: sheet STAYS at +200 above rafter top
        ;; and extends 75 mm INTO the gutter from LIP INNER edge
        ;; (gxR-340 → gxR-265).
        (setq breakX (- gxR 265.0))
        (setq breakY (+ H purlinH
                        (/ (* rise 265.0) (- gxR ridgeX))))
        (command "LINE"
          (list ridgeX (+ H rise purlinH))
          (list breakX breakY) "")
        (command "LINE"
          (list ridgeX (+ H rise purlinH cladThk))
          (list breakX (+ breakY cladThk)) "")
        ;; End-cap: close sheet's 2 lines with a vertical face at the break
        (command "LINE"
          (list breakX  breakY)
          (list breakX (+ breakY cladThk)) "")
      )
    )
    (setq i (1+ i)))
  ;; --- Labels with CS-style bracket leaders ----------------------------
  (setvar "CLAYER" "TEXT")
  (setq roofLbl (MSPL-Get-Str data "ROOFSHEETING"))
  (if (= roofLbl "") (setq roofLbl "ROOF CLADDING 50mm PIR SANDWICH PANEL"))
  (setq wallLbl (MSPL-Get-Str data "WALLSHEETING"))
  (if (= wallLbl "") (setq wallLbl "WALL SHEETING 50mm PIR SANDWICH PANEL"))

  ;; === ROOF CLADDING label: bracket-leader anchored to the LAST gable's right slope ===
  ;; gxL_last / ridgeX_last give the per-gable geometry for the leader Y target.
  (setq gxL_last  (* (1- numGab) gW))
  (setq ridgeX_last (+ gxL_last (/ gW 2.0)))   ; = W - gW/2
  (setq rParts (split-at-first-digit roofLbl))
  (setq rLine1 (strcat (car rParts) ":"))
  (setq rLine2 (cadr rParts))
  ;; ROOF CLADDING label X: 1/3 of the LAST gable's half-span IN FROM
  ;; the right eave.
  (setq labRX  (- W (/ (/ gW 2.0) 3.0)))            ; W - (gW/2)/3 = W - gW/6
  ;; Anchor labRY to the SAME Y as the wall sheeting label so both
  ;; sheeting MLEADERs sit on the same horizontal level (same rule as CS).
  (setq labRY  (+ H (* 2700 *PEB-TEXT-SCALE*)))
  ;; Y at labRX on last gable (sheeting surface) — used as arrow tip
  (setq rDx (abs (- labRX ridgeX_last)))
  (setq rTargetY
    (max (+ H purlinH cladThk)
         (- (+ H rise purlinH cladThk)
            (* rise (/ rDx (/ gW 2.0))))))
  (cond
    (rLine2
      ;; --- ONE 3-vertex MLEADER carrying heading + spec (matches CS) ---
      ;; v0 = arrow tip on roof sheeting (lower)
      ;; v1 = top of vertical leg (= bar's LEFT end)
      ;; v2 = bar's RIGHT end (= text landing point)
      (setvar "CLAYER" "TEXT")
      (setq rLine2_2L (peb-split-2-lines rLine2))
      (setq rBarY  (+ labRY (* 175 *PEB-TEXT-SCALE*)))
      (setq rBarLen 300.0)
      (setq rCombined
        (strcat "{\\fArial|b1;" rLine1 "}\\P" rLine2_2L))
      (setq mlResult
        (vl-catch-all-apply 'peb-make-mleader
          (list
            (list (list labRX rTargetY)         ; v0 arrow tip on sheeting
                  (list labRX rBarY)            ; v1 top of vertical leg
                  (list (+ labRX rBarLen) rBarY)) ; v2 text landing
            rCombined)))
      (cond
        ((vl-catch-all-error-p mlResult)
          ;; Fallback: hand-rolled
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labRX (+ rBarY (* 220 *PEB-TEXT-SCALE*)))
                    (* 220.0 *PEB-TEXT-SCALE*) 0 "ML"
                    (strcat "{\\fArial|b1;" rLine1 "}"))))
          (if (vl-catch-all-error-p mtResult)
            (txt "ML" (list labRX (+ rBarY (* 220 *PEB-TEXT-SCALE*))) 220 0 rLine1))
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labRX (- rBarY (* 60 *PEB-TEXT-SCALE*)))
                    (* 220.0 *PEB-TEXT-SCALE*) 0 "TL" rLine2_2L)))
          (if (vl-catch-all-error-p mtResult)
            (setq nRSpec (txt-wrap "TL" (list labRX (- rBarY (* 60 *PEB-TEXT-SCALE*))) 220 0 rBarLen rLine2_2L)))
          (setvar "CLAYER" "ARROWS")
          (setvar "PLINEWID" 0.0)
          (command "LINE"
            (list labRX rBarY)
            (list (+ labRX rBarLen) rBarY) "")
          (command "LINE"
            (list labRX rBarY)
            (list labRX (+ rTargetY (* 1200 *PEB-TEXT-SCALE*))) "")
          (command "PLINE"
            (list labRX (+ rTargetY (* 1200 *PEB-TEXT-SCALE*)))
            "W" (* 320 *PEB-TEXT-SCALE*) 0
            (list labRX rTargetY) "")
          (setvar "PLINEWID" 0.0))
        (T
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextAttachmentDirection mlResult 0))))
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextLeftAttachmentType  mlResult 5))))
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextRightAttachmentType mlResult 5))))
        )
      )
    )
    (T
      ;; --- Single-line fallback -----------------------------------------
      (txt "ML" (list labRX labRY) 220 0 roofLbl)
      (draw-l-leader (+ labRX (* 5000 *PEB-TEXT-SCALE*))
                     (- labRY (* 250 *PEB-TEXT-SCALE*))
                     ridgeX_last
                     (+ H rise purlinH cladThk)
                     "V")))

  ;; === WALL SHEETING label: ONE 4-vertex MLEADER (matches CS) ===
  (setq wParts (split-at-first-digit wallLbl))
  (setq wLine1 (strcat (car wParts) ":"))
  (setq wLine2 (cadr wParts))
  (setq labWX  (- 0.0 girtDepth cladThk))      ; -235 : outer face of wall sheet
  (setq labWY  (+ H (* 2700 *PEB-TEXT-SCALE*)))
  ;; Arrow tip Y: 300 mm BELOW the clear-height line (same rule as CS).
  (setq wTargetY (- H 300.0))
  (cond
    (wLine2
      (setvar "CLAYER" "TEXT")
      (setq wLine2_2L (peb-split-2-lines wLine2))
      (setq wBarY      (+ labWY (* 175 *PEB-TEXT-SCALE*)))
      (setq wBarLen    300.0)
      ;; v0-v1 segment 1500 mm so the arrow renders (matches CS rule)
      (setq wExtX      (- labWX 1500.0))
      (setq wCombined
        (strcat "{\\fArial|b1;" wLine1 "}\\P" wLine2_2L))
      (setq mlResult
        (vl-catch-all-apply 'peb-make-mleader
          (list
            (list (list labWX wTargetY)            ; v0 arrow on wall
                  (list wExtX wTargetY)            ; v1 elbow near arrow
                  (list wExtX wBarY)               ; v2 elbow at bar
                  (list (+ wExtX 300.0) wBarY))    ; v3 text landing
            wCombined)))
      (cond
        ((vl-catch-all-error-p mlResult)
          ;; Hand-rolled fallback
          (setq wHeadY (+ wBarY (* 220 *PEB-TEXT-SCALE*)))
          (setq wSpecY (- wBarY (* 60  *PEB-TEXT-SCALE*)))
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labWX wHeadY)
                    (* 220.0 *PEB-TEXT-SCALE*) 0 "ML"
                    (strcat "{\\fArial|b1;" wLine1 "}"))))
          (if (vl-catch-all-error-p mtResult)
            (txt "ML" (list labWX wHeadY) 220 0 wLine1))
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labWX wSpecY)
                    (* 220.0 *PEB-TEXT-SCALE*) 0 "TL" wLine2_2L)))
          (if (vl-catch-all-error-p mtResult)
            (txt-wrap "TL" (list labWX wSpecY) 220 0 wBarLen wLine2_2L))
          (setvar "CLAYER" "ARROWS")
          (setvar "PLINEWID" 0.0)
          (command "LINE"
            (list wExtX wBarY)
            (list (+ wExtX 300.0) wBarY) "")
          (command "LINE"
            (list wExtX wBarY)
            (list wExtX wTargetY) "")
          (command "LINE"
            (list wExtX wTargetY)
            (list (- labWX (* 1200 *PEB-TEXT-SCALE*)) wTargetY) "")
          (command "PLINE"
            (list (- labWX (* 1200 *PEB-TEXT-SCALE*)) wTargetY)
            "W" (* 320 *PEB-TEXT-SCALE*) 0
            (list labWX wTargetY) "")
          (setvar "PLINEWID" 0.0))
        (T
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextAttachmentDirection mlResult 0))))
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextLeftAttachmentType  mlResult 5))))
          (vl-catch-all-apply
            (function (lambda ()
              (vla-put-TextRightAttachmentType mlResult 5))))
        )
      )
    )
    (T
      (txt "ML" (list labWX labWY) 220 0 wallLbl)))
  (setvar "PLINEWID" 0.0)
)

(defun draw-ridge-cap (W H rise / cx cTop yTop tipY plateBaseY plateTipY)
  ;;  Two pieces at the ridge:
  ;;    1. RIDGE CAP / PANEL above the sheeting (small triangle on top)
  ;;    2. RIDGE CONNECTION PLATE below the rafter top at the apex
  ;;       (a triangular gusset where the two rafters meet)
  (setvar "CLAYER" "PLATES")
  (setq cx   (/ W 2.0))
  (setq yTop (+ H rise 200.0 35.0))   ; top of sheeting at ridge
  (setq tipY (+ yTop 250.0))           ; cap apex 250 mm above sheeting top
  ;; Ridge cap (triangle resting on top of sheeting, apex above)
  (command "PLINE"
    (list (- cx 300.0) yTop)
    "W" 1.5 1.5
    (list (+ cx 300.0) yTop)
    (list cx           tipY)
    "C")
  ;; Ridge connection plate (triangle hanging below rafter at apex)
  ;; The rafter underside at ridge sits at (H + rise - rd) approximately;
  ;; we place a 600 wide x ~250 deep triangular gusset just below it.
  (setq plateBaseY (+ H rise))         ; rafter top at apex
  (setq plateTipY  (- plateBaseY 800.0))
  (command "PLINE"
    (list (- cx 300.0) plateBaseY)
    "W" 1.5 1.5
    (list (+ cx 300.0) plateBaseY)
    (list cx           plateTipY)
    "C")
  (setvar "PLINEWID" 0.0)
)

(defun draw-purlins (W H rise / depth wtop wbot lip lipDx lipDy
                     slopeLen sa ca d xL yL xR yR nP purlinSpacing
                     d_ridge_offset d_ridge_purlin
                     uX uY vX vY purlinH fw
                     pLabD pLabPX pLabPY pLabX pLabY
                     v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  ;;  Z-section purlin profile (200Z15 typical: depth 200, flange 60,
  ;;  lip 20, lip-angle 60 deg from flange).  Each purlin is drawn as
  ;;  a 6-vertex polyline and tilted perpendicular to the rafter so
  ;;  the top flange sits flush against the bottom of the sheeting.
  ;;
  ;;  Z profile in local (u, v) frame [u = top-flange direction,
  ;;                                   v = web direction perpendicular up]:
  ;;     v6 (bottom-lip-end)       = ( -wbot+lipDx,  lipDy )
  ;;     v5 (bottom-flange-corner) = ( -wbot,        0     )
  ;;     v4 (bottom-of-web)        = (  0,           0     )  <-- on rafter top
  ;;     v3 (top-of-web)           = (  0,           depth )
  ;;     v2 (top-flange-corner)    = ( +wtop,        depth )
  ;;     v1 (top-lip-end)          = ( +wtop-lipDx,  depth-lipDy )
  ;;
  ;;  Conversion to world: WX = cx + u*uX + v*vX
  ;;                       WY = cy + u*uY + v*vY
  (setvar "CLAYER" "PURLINS")
  (setq depth 200.0  wtop 60.0  wbot 60.0  lip 20.0)   ; 200Z15: top of Z touches sheeting
  (setq lipDx (* lip 0.5))      ; cos 60 deg
  (setq lipDy (* lip 0.866))    ; sin 60 deg
  (setq slopeLen (sqrt (+ (* (/ W 2.0) (/ W 2.0)) (* rise rise))))
  (setq sa (/ rise slopeLen))
  (setq ca (/ (/ W 2.0) slopeLen))
  ;; Adjusted spacing: last purlin sits 300mm down-slope from ridge so the
  ;; centre 600mm gap stays clear for the ridge panel.
  (setq d_ridge_offset 300.0)
  (setq d_ridge_purlin (- slopeLen d_ridge_offset))
  (setq nP (max 1 (fix (+ 0.5 (/ d_ridge_purlin 1500.0)))))
  (setq purlinSpacing (/ d_ridge_purlin nP))

  ;; LEFT half: u along rafter toward ridge = (ca, sa); v perp up = (-sa, ca)
  (setq uX ca   uY sa)
  (setq vX (- 0 sa)   vY ca)
  (setq d purlinSpacing)
  (while (<= d (+ d_ridge_purlin 0.5))
    (setq xL (* d ca))
    (setq yL (+ H (* d sa)))
    (setq v6x (+ xL (* (- lipDx wbot) uX) (* lipDy vX)))
    (setq v6y (+ yL (* (- lipDx wbot) uY) (* lipDy vY)))
    (setq v5x (+ xL (* (- 0 wbot) uX)))
    (setq v5y (+ yL (* (- 0 wbot) uY)))
    (setq v4x xL)
    (setq v4y yL)
    (setq v3x (+ xL (* depth vX)))
    (setq v3y (+ yL (* depth vY)))
    (setq v2x (+ xL (* wtop uX) (* depth vX)))
    (setq v2y (+ yL (* wtop uY) (* depth vY)))
    (setq v1x (+ xL (* (- wtop lipDx) uX) (* (- depth lipDy) vX)))
    (setq v1y (+ yL (* (- wtop lipDx) uY) (* (- depth lipDy) vY)))
    (command "PLINE"
      (list v6x v6y)
      "W" 1.5 1.5
      (list v5x v5y) (list v4x v4y)
      (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
    (setvar "FILLETRAD" 4.0)   ; smaller radius to keep lip visible
    (command "FILLET" "P" (entlast))
    (setq d (+ d purlinSpacing)))

  ;; (No purlin AT the ridge centreline - 600mm gap left for the ridge panel)

  ;; RIGHT half: u along rafter toward ridge = (-ca, sa); v perp up = (sa, ca)
  (setq uX (- 0 ca)   uY sa)
  (setq vX sa   vY ca)
  (setq d purlinSpacing)
  (while (<= d (+ d_ridge_purlin 0.5))
    (setq xR (- W (* d ca)))
    (setq yR (+ H (* d sa)))
    (setq v6x (+ xR (* (- lipDx wbot) uX) (* lipDy vX)))
    (setq v6y (+ yR (* (- lipDx wbot) uY) (* lipDy vY)))
    (setq v5x (+ xR (* (- 0 wbot) uX)))
    (setq v5y (+ yR (* (- 0 wbot) uY)))
    (setq v4x xR)
    (setq v4y yR)
    (setq v3x (+ xR (* depth vX)))
    (setq v3y (+ yR (* depth vY)))
    (setq v2x (+ xR (* wtop uX) (* depth vX)))
    (setq v2y (+ yR (* wtop uY) (* depth vY)))
    (setq v1x (+ xR (* (- wtop lipDx) uX) (* (- depth lipDy) vX)))
    (setq v1y (+ yR (* (- wtop lipDx) uY) (* (- depth lipDy) vY)))
    (command "PLINE"
      (list v6x v6y)
      "W" 1.5 1.5
      (list v5x v5y) (list v4x v4y)
      (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
    (setvar "FILLETRAD" 4.0)   ; smaller radius to keep lip visible
    (command "FILLET" "P" (entlast))
    (setq d (+ d purlinSpacing)))

  ;; "PURLIN" leader label - L-shaped arrow pointing EXACTLY to an actual
  ;; left-half purlin (snap arrow target to nearest real purlin distance).
  (setvar "CLAYER" "TEXT")
  (setq purlinH depth)         ; depth = 200 (Z-purlin web height)
  ;; Pick the purlin nearest 55% of the rafter length, NOT 40% — at 40%
  ;; the label X falls inside the wall-sheeting text wrap on the LEFT
  ;; eave for typical building widths.  At 55% it's safely clear.
  (setq pLabD (* purlinSpacing
                 (max 1 (fix (+ 0.5 (/ (* slopeLen 0.65) purlinSpacing))))))
  ;; Arrow target = web mid-height of that purlin (web base = (xL,yL),
  ;; web top = (xL+depth*vX, yL+depth*vY)).  vX = -sa, vY = ca for LEFT.
  (setq pLabPX (+ (* pLabD ca) (* (/ purlinH 2.0) (- 0 sa))))
  (setq pLabPY (+ H (* pLabD sa) (* (/ purlinH 2.0) ca)))
  ;; X offset = 300 mm (bar length per wall/roof sheeting rule).
  ;; Text lands 300 mm right of the arrow X so the v1-v2 horizontal
  ;; "bar" segment is exactly 300 mm long, matching the wall and
  ;; roof sheeting MLEADERs.  Text extends rightward from the bar end.
  (setq pLabX (+ pLabPX 300.0))
  (setq pLabY (+ pLabPY (* 1200 *PEB-TEXT-SCALE*)))
  (peb-label-with-leader "PURLIN"
                         (list pLabX pLabY)
                         (list pLabPX pLabPY)
                         "V"
                         220)
  (setvar "PLINEWID" 0.0)
)

(defun draw-purlins-OLD (W H rise / purlinSpacing s xL xR yTop slopeAngle)
  ;;  Small inverted-T tick marks along rafter top representing purlins.
  ;;  Spacing typically 1500 mm along the slope.
  (setvar "CLAYER" "PURLINS")
  (setq purlinSpacing 1500.0)
  (setq s 100.0)   ; tick height in mm
  (setq slopeAngle (atan rise (/ W 2.0)))
  ;; LEFT rafter purlins
  (setq d 0.0)
  (while (< d (sqrt (+ (* (/ W 2.0) (/ W 2.0)) (* rise rise))))
    (setq xL (* d (cos slopeAngle)))
    (setq yTop (+ H (* d (sin slopeAngle))))
    ;; Vertical tick going DOWN from rafter top
    (command "LINE"
      (list xL yTop)
      (list xL (- yTop s))
      "")
    (setq d (+ d purlinSpacing))
  )
  ;; RIGHT rafter purlins
  (setq d 0.0)
  (while (< d (sqrt (+ (* (/ W 2.0) (/ W 2.0)) (* rise rise))))
    (setq xR (- W (* d (cos slopeAngle))))
    (setq yTop (+ H (* d (sin slopeAngle))))
    (command "LINE"
      (list xR yTop)
      (list xR (- yTop s))
      "")
    (setq d (+ d purlinSpacing))
  )
  ;; "PURLIN" leader label
  (setvar "CLAYER" "TEXT")
  (txt "ML"
       (list (* W 0.62) (+ H (* rise 0.5) (* 600 *PEB-TEXT-SCALE*)))
       200 0 "PURLIN")
)

(defun draw-purlins-mg (W H rise numGab gW /
                         depth wtop wbot lip lipDx lipDy
                         slopeLen sa ca
                         d_ridge_offset d_ridge_purlin nP purlinSpacing purlinH
                         uX uY vX vY
                         i gxL gxR
                         d xL yL xR yR
                         v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y
                         pLabD pLabPX pLabPY pLabX pLabY)
  ;;  Z-section purlins for every gable in an MG frame.
  ;;  Same 200Z15 Z-profile as draw-purlins.
  ;;  PURLIN leader label is emitted on gable 0 only (avoids clutter on wide MG).
  (setvar "CLAYER" "PURLINS")
  (setq depth 200.0  wtop 60.0  wbot 60.0  lip 20.0)
  (setq lipDx (* lip 0.5))
  (setq lipDy (* lip 0.866))
  ;; Per-gable slope (constant across all gables since spans are equal)
  (setq slopeLen (sqrt (+ (* (/ gW 2.0) (/ gW 2.0)) (* rise rise))))
  (setq sa (/ rise slopeLen))
  (setq ca (/ (/ gW 2.0) slopeLen))
  (setq d_ridge_offset 300.0)
  (setq d_ridge_purlin (- slopeLen d_ridge_offset))
  (setq nP (max 1 (fix (+ 0.5 (/ d_ridge_purlin 1500.0)))))
  (setq purlinSpacing (/ d_ridge_purlin nP))
  (setq purlinH depth)

  (setq i 0)
  (while (< i numGab)
    (setq gxL (* i gW))
    (setq gxR (+ gxL gW))

    ;; --- LEFT half of gable i ---
    (setq uX ca  uY sa)
    (setq vX (- 0 sa)  vY ca)
    (setq d purlinSpacing)
    (while (<= d (+ d_ridge_purlin 0.5))
      (setq xL (+ gxL (* d ca)))
      (setq yL (+ H   (* d sa)))
      (setq v6x (+ xL (* (- lipDx wbot) uX) (* lipDy vX)))
      (setq v6y (+ yL (* (- lipDx wbot) uY) (* lipDy vY)))
      (setq v5x (+ xL (* (- 0 wbot) uX)))
      (setq v5y (+ yL (* (- 0 wbot) uY)))
      (setq v4x xL)  (setq v4y yL)
      (setq v3x (+ xL (* depth vX)))
      (setq v3y (+ yL (* depth vY)))
      (setq v2x (+ xL (* wtop uX) (* depth vX)))
      (setq v2y (+ yL (* wtop uY) (* depth vY)))
      (setq v1x (+ xL (* (- wtop lipDx) uX) (* (- depth lipDy) vX)))
      (setq v1y (+ yL (* (- wtop lipDx) uY) (* (- depth lipDy) vY)))
      (command "PLINE"
        (list v6x v6y) "W" 1.5 1.5
        (list v5x v5y) (list v4x v4y)
        (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
      (setvar "FILLETRAD" 4.0)
      (command "FILLET" "P" (entlast))
      (setq d (+ d purlinSpacing)))

    ;; --- RIGHT half of gable i ---
    (setq uX (- 0 ca)  uY sa)
    (setq vX sa  vY ca)
    (setq d purlinSpacing)
    (while (<= d (+ d_ridge_purlin 0.5))
      (setq xR (- gxR (* d ca)))
      (setq yR (+ H   (* d sa)))
      (setq v6x (+ xR (* (- lipDx wbot) uX) (* lipDy vX)))
      (setq v6y (+ yR (* (- lipDx wbot) uY) (* lipDy vY)))
      (setq v5x (+ xR (* (- 0 wbot) uX)))
      (setq v5y (+ yR (* (- 0 wbot) uY)))
      (setq v4x xR)  (setq v4y yR)
      (setq v3x (+ xR (* depth vX)))
      (setq v3y (+ yR (* depth vY)))
      (setq v2x (+ xR (* wtop uX) (* depth vX)))
      (setq v2y (+ yR (* wtop uY) (* depth vY)))
      (setq v1x (+ xR (* (- wtop lipDx) uX) (* (- depth lipDy) vX)))
      (setq v1y (+ yR (* (- wtop lipDx) uY) (* (- depth lipDy) vY)))
      (command "PLINE"
        (list v6x v6y) "W" 1.5 1.5
        (list v5x v5y) (list v4x v4y)
        (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
      (setvar "FILLETRAD" 4.0)
      (command "FILLET" "P" (entlast))
      (setq d (+ d purlinSpacing)))

    ;; PURLIN label + L-leader on gable 0 only
    (if (= i 0)
      (progn
        (setvar "CLAYER" "TEXT")
        ;; Pick the purlin nearest 55% of slope length (was 40%) so the
        ;; PURLIN label sits clear of the wall-sheeting text wrap on
        ;; the LEFT eave.  Same anti-overlap fix as the CS path.
        (setq pLabD (* purlinSpacing
                       (max 1 (fix (+ 0.5 (/ (* slopeLen 0.65) purlinSpacing))))))
        ;; Arrow target = mid-height of that purlin's web (left half, gable 0)
        (setq pLabPX (+ gxL (* pLabD ca) (* (/ purlinH 2.0) (- 0 sa))))
        (setq pLabPY (+     H (* pLabD sa) (* (/ purlinH 2.0) ca)))
        ;; 300 mm bar (wall/roof sheeting rule).
        (setq pLabX (+ pLabPX 300.0))
        (setq pLabY (+ pLabPY (* 1200 *PEB-TEXT-SCALE*)))
        (peb-label-with-leader "PURLIN"
                               (list pLabX pLabY)
                               (list pLabPX pLabPY)
                               "V"
                               220)))

    (setq i (1+ i)))
  (setvar "PLINEWID" 0.0)
)

(defun draw-girts (W H brickH / depth wtop wbot lip lipDx lipDy
                   girtSpacing nG y topY botY desSpacing labGX labGY
                   v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  ;;  Z-section girt profile (200Z15 typical) attached to the OUTSIDE
  ;;  face of the side wall column.  Web runs HORIZONTALLY perpendicular
  ;;  to the wall; flanges are vertical (up/down).  Drawn as 6-vertex
  ;;  Z polyline.
  ;;
  ;;  Local Z, then rotated so that:
  ;;     u-axis = vertical UP
  ;;     v-axis = horizontal OUT from wall
  ;;
  ;;  For LEFT wall: world_x = 0 + u*0 + v*(-1) = -v
  ;;                 world_y = y + u*1 + v*0  = y + u
  ;;  For RIGHT wall: world_x = W + v*(+1) = W + v
  ;;                  world_y = y + u
  (setvar "CLAYER" "GIRTS")
  (setq depth 200.0  wtop 60.0  wbot 60.0  lip 20.0)   ; 200Z15: top of Z touches sheeting
  (setq lipDx (* lip 0.5))
  (setq lipDy (* lip 0.866))
  ;; Top girt sits at H-160 so its top flange (at H-100) touches the
  ;; bottom of the eave strut stiffener.
  ;; Bottom girt (added below) sits at brickH+60 (inner flange on brick top).
  ;; Total girts evenly distributed between bottom (botY) and top (topY).
  ;; Desired spacing varies with eave height H: 1200mm at H=5m up to 1500mm at H=10m+.
  (setq topY  (- H 160.0))
  (setq botY  (+ brickH 60.0))
  (setq desSpacing (max 1200.0 (min 1500.0 (+ 1200.0 (* (/ (- H 5000.0) 5000.0) 300.0)))))
  (setq nG (max 1 (fix (+ 0.5 (/ (- topY botY) desSpacing)))))
  (setq girtSpacing (/ (- topY botY) nG))

  ;; LEFT wall girts: from botY (bottom, on brick) to topY (under stiffener)
  (setq y botY)
  (while (<= y (+ topY 0.5))
    ;; Apply transform: WX = -v_local; WY = y + u_local
    ;; v6 local (-wbot+lipDx, lipDy)
    (setq v6x (- 0 lipDy))
    (setq v6y (+ y (- lipDx wbot)))
    (setq v5x 0.0)
    (setq v5y (+ y (- 0 wbot)))
    (setq v4x 0.0)
    (setq v4y y)
    (setq v3x (- 0 depth))
    (setq v3y y)
    (setq v2x (- 0 depth))
    (setq v2y (+ y wtop))
    (setq v1x (- 0 (- depth lipDy)))
    (setq v1y (+ y (- wtop lipDx)))
    (command "PLINE"
      (list v6x v6y)
      "W" 1.5 1.5
      (list v5x v5y) (list v4x v4y)
      (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
    (setvar "FILLETRAD" 4.0)   ; smaller radius to keep lip visible
    (command "FILLET" "P" (entlast))
    (setq y (+ y girtSpacing)))

  ;; RIGHT wall girts: from botY to topY
  (setq y botY)
  (while (<= y (+ topY 0.5))
    ;; Mirror transform: WX = W + v_local; WY = y + u_local
    (setq v6x (+ W lipDy))
    (setq v6y (+ y (- lipDx wbot)))
    (setq v5x W)
    (setq v5y (+ y (- 0 wbot)))
    (setq v4x W)
    (setq v4y y)
    (setq v3x (+ W depth))
    (setq v3y y)
    (setq v2x (+ W depth))
    (setq v2y (+ y wtop))
    (setq v1x (+ W (- depth lipDy)))
    (setq v1y (+ y (- wtop lipDx)))
    (command "PLINE"
      (list v6x v6y)
      "W" 1.5 1.5
      (list v5x v5y) (list v4x v4y)
      (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
    (setvar "FILLETRAD" 4.0)   ; smaller radius to keep lip visible
    (command "FILLET" "P" (entlast))
    (setq y (+ y girtSpacing)))

  ;; "GIRT" leader label — native MLEADER with grouped fallback.
  ;; Arrow tip snapped to an actual girt position (2nd girt from bottom).
  (setvar "CLAYER" "TEXT")
  (setq labGX (max 1800.0 (+ ht 800.0)))
  (setq labGY (+ botY girtSpacing))
  (peb-label-with-leader "GIRT"
                         (list labGX labGY)
                         (list -100.0 labGY)
                         "H"
                         220)
  (setvar "PLINEWID" 0.0)
)

(defun draw-eave-strut (W H rise / depth wtop wbot lip lipDx lipDy
                              slopeLen sa ca xL yL xR yR
                              v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  ;;  Eave detail combo:
  ;;  (a) Rafter top flange EXTENSION 200mm outside the eave + triangular
  ;;      stiffener below.  Drawn as a closed triangle on the FRAME layer.
  ;;  (b) Eave Strut = Z-purlin tilted PERPENDICULAR to rafter (same as
  ;;      regular roof purlins).  Positioned so:
  ;;        - bottom-of-web rests on rafter extension at y = H
  ;;        - bottom-flange-end (outer face) lands at x = -200 / W+200
  ;;          (= girt outer face line, supports wall sheeting at top)
  (setq depth 200.0  wtop 60.0  wbot 60.0  lip 20.0)
  (setq lipDx (* lip 0.5))
  (setq lipDy (* lip 0.866))
  (setq slopeLen (sqrt (+ (* (/ W 2.0) (/ W 2.0)) (* rise rise))))
  (setq sa (/ rise slopeLen))
  (setq ca (/ (/ W 2.0) slopeLen))

  ;; ===== LEFT EAVE =====
  ;; (a) Rafter top flange extension 200mm outside + stiffener triangle
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  ;; Triangle: outer-top -> inner-top -> inner-bottom (vertical edge at column,
  ;; hypotenuse from bottom-of-column UP-OUT to outer extension end)
  (command "PLINE"
    (list -200.0  H)             ; outer-top (extension end)
    (list 0.0     H)             ; inner-top (at column outer flange)
    (list 0.0     (- H 100.0))   ; inner-bottom (smaller stiffener: 100mm drop)
    "C")                          ; close via hypotenuse

  ;; (b) Eave Strut Z-purlin tilted perpendicular to rafter (LEFT half)
  (setvar "CLAYER" "PURLINS")
  (setq xL -140.0)
  (setq yL (- H 8.0))   ; lower 8mm so top-of-web touches sheeting bottom
  (setq v6x (+ xL (* (- lipDx wbot) ca) (* lipDy (- 0 sa))))
  (setq v6y (+ yL (* (- lipDx wbot) sa) (* lipDy ca)))
  (setq v5x (+ xL (* (- 0 wbot) ca)))
  (setq v5y (+ yL (* (- 0 wbot) sa)))
  (setq v4x xL)
  (setq v4y yL)
  (setq v3x (+ xL (* depth (- 0 sa))))
  (setq v3y (+ yL (* depth ca)))
  (setq v2x (+ xL (* wtop ca) (* depth (- 0 sa))))
  (setq v2y (+ yL (* wtop sa) (* depth ca)))
  (setq v1x (+ xL (* (- wtop lipDx) ca) (* (- depth lipDy) (- 0 sa))))
  (setq v1y (+ yL (* (- wtop lipDx) sa) (* (- depth lipDy) ca)))
  (command "PLINE"
    (list v6x v6y)
    "W" 1.5 1.5
    (list v5x v5y) (list v4x v4y)
    (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
  (setvar "FILLETRAD" 4.0)
  (command "FILLET" "P" (entlast))

  ;; (EAVE STRUT label removed - the strut is visually obvious in section
  ;; and the label was crowding the eave area on narrow buildings.)

  ;; ===== RIGHT EAVE (mirror) =====
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  ;; RIGHT stiffener: vertical edge at column (x=W), hypotenuse to outer top
  (command "PLINE"
    (list (+ W 200.0) H)
    (list W           H)
    (list W           (- H 100.0))
    "C")

  (setvar "CLAYER" "PURLINS")
  (setvar "PLINEWID" 0.0)
  (setq xR (+ W 140.0))
  (setq yR (- H 8.0))   ; lower 8mm so top-of-web touches sheeting bottom
  (setq v6x (+ xR (* (- lipDx wbot) (- 0 ca)) (* lipDy sa)))
  (setq v6y (+ yR (* (- lipDx wbot) sa) (* lipDy ca)))
  (setq v5x (+ xR (* (- 0 wbot) (- 0 ca))))
  (setq v5y (+ yR (* (- 0 wbot) sa)))
  (setq v4x xR)
  (setq v4y yR)
  (setq v3x (+ xR (* depth sa)))
  (setq v3y (+ yR (* depth ca)))
  (setq v2x (+ xR (* wtop (- 0 ca)) (* depth sa)))
  (setq v2y (+ yR (* wtop sa) (* depth ca)))
  (setq v1x (+ xR (* (- wtop lipDx) (- 0 ca)) (* (- depth lipDy) sa)))
  (setq v1y (+ yR (* (- wtop lipDx) sa) (* (- depth lipDy) ca)))
  (command "PLINE"
    (list v6x v6y)
    "W" 1.5 1.5
    (list v5x v5y) (list v4x v4y)
    (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
  (setvar "FILLETRAD" 4.0)
  (command "FILLET" "P" (entlast))

  ;; (RIGHT EAVE STRUT label also removed.)
  (setvar "PLINEWID" 0.0)
)

(defun draw-eave-strut-mg (W gW H rise /
                            depth wtop wbot lip lipDx lipDy
                            slopeLen sa ca
                            xL yL xR yR
                            v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  ;;  MG outer eave struts only (left at x=0, right at x=W).
  ;;  Stiffener triangle + Z-purlin use the PER-GABLE slope angle (from gW),
  ;;  so the strut sits flush against the gable rafter — not the false CS angle.
  (setq depth 200.0  wtop 60.0  wbot 60.0  lip 20.0)
  (setq lipDx (* lip 0.5))
  (setq lipDy (* lip 0.866))
  (setq slopeLen (sqrt (+ (* (/ gW 2.0) (/ gW 2.0)) (* rise rise))))
  (setq sa (/ rise slopeLen))
  (setq ca (/ (/ gW 2.0) slopeLen))

  ;; ===== LEFT OUTER EAVE (x = 0) =====
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (command "PLINE"
    (list -200.0  H)
    (list 0.0     H)
    (list 0.0     (- H 100.0))
    "C")
  (setvar "CLAYER" "PURLINS")
  (setq xL -140.0)
  (setq yL (- H 8.0))
  (setq v6x (+ xL (* (- lipDx wbot) ca) (* lipDy (- 0 sa))))
  (setq v6y (+ yL (* (- lipDx wbot) sa) (* lipDy ca)))
  (setq v5x (+ xL (* (- 0 wbot) ca)))
  (setq v5y (+ yL (* (- 0 wbot) sa)))
  (setq v4x xL)  (setq v4y yL)
  (setq v3x (+ xL (* depth (- 0 sa))))
  (setq v3y (+ yL (* depth ca)))
  (setq v2x (+ xL (* wtop ca) (* depth (- 0 sa))))
  (setq v2y (+ yL (* wtop sa) (* depth ca)))
  (setq v1x (+ xL (* (- wtop lipDx) ca) (* (- depth lipDy) (- 0 sa))))
  (setq v1y (+ yL (* (- wtop lipDx) sa) (* (- depth lipDy) ca)))
  (command "PLINE"
    (list v6x v6y) "W" 1.5 1.5
    (list v5x v5y) (list v4x v4y)
    (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
  (setvar "FILLETRAD" 4.0)
  (command "FILLET" "P" (entlast))

  ;; ===== RIGHT OUTER EAVE (x = W) =====
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (command "PLINE"
    (list (+ W 200.0) H)
    (list W           H)
    (list W           (- H 100.0))
    "C")
  (setvar "CLAYER" "PURLINS")
  (setq xR (+ W 140.0))
  (setq yR (- H 8.0))
  (setq v6x (+ xR (* (- lipDx wbot) (- 0 ca)) (* lipDy sa)))
  (setq v6y (+ yR (* (- lipDx wbot) sa)        (* lipDy ca)))
  (setq v5x (+ xR (* (- 0 wbot) (- 0 ca))))
  (setq v5y (+ yR (* (- 0 wbot) sa)))
  (setq v4x xR)  (setq v4y yR)
  (setq v3x (+ xR (* depth sa)))
  (setq v3y (+ yR (* depth ca)))
  (setq v2x (+ xR (* wtop (- 0 ca)) (* depth sa)))
  (setq v2y (+ yR (* wtop sa)        (* depth ca)))
  (setq v1x (+ xR (* (- wtop lipDx) (- 0 ca)) (* (- depth lipDy) sa)))
  (setq v1y (+ yR (* (- wtop lipDx) sa)        (* (- depth lipDy) ca)))
  (command "PLINE"
    (list v6x v6y) "W" 1.5 1.5
    (list v5x v5y) (list v4x v4y)
    (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
  (setvar "FILLETRAD" 4.0)
  (command "FILLET" "P" (entlast))
  (setvar "PLINEWID" 0.0)
)

(defun draw-downpipes (W H brickH / dpW dpOff dpX1L dpX2L dpX1R dpX2R dpTop
                                    labDX labDY labCX labCY mlResult)
  ;;  Vertical down-pipes on the OUTSIDE of the wall sheeting (one per side).
  ;;  Pipe runs from FFL up to just below the eave gutter.
  ;;  Single "DOWN PIPE" label drawn on the LEFT side only, with an L-leader
  ;;  (H mode) - same style as the GIRT label.
  (setvar "CLAYER" "GUTTER")
  (setq dpW   100.0)              ; pipe outer width
  (setq dpOff (+ 200.0 35.0 30.0)); girtDepth + cladThk + 30mm clearance
  (setq dpTop (+ H 35.0))    ; top exactly at gutter bottom (gyBot) - no gap
  ;; LEFT side pipe
  (setq dpX2L (- 0.0 dpOff))
  (setq dpX1L (- dpX2L dpW))
  (command "LINE" (list dpX1L 0.0)   (list dpX1L dpTop) "")
  (command "LINE" (list dpX2L 0.0)   (list dpX2L dpTop) "")
  (command "LINE" (list dpX1L dpTop) (list dpX2L dpTop) "")
  (command "LINE" (list dpX1L 0.0)   (list dpX2L 0.0)   "")
  ;; RIGHT side pipe (no label)
  (setq dpX1R (+ W dpOff))
  (setq dpX2R (+ dpX1R dpW))
  (command "LINE" (list dpX1R 0.0)   (list dpX1R dpTop) "")
  (command "LINE" (list dpX2R 0.0)   (list dpX2R dpTop) "")
  (command "LINE" (list dpX1R dpTop) (list dpX2R dpTop) "")
  (command "LINE" (list dpX1R 0.0)   (list dpX2R 0.0)   "")
  ;; "DOWN PIPE" leader label — native MLEADER with grouped fallback.
  ;; LEFT side only, INSIDE the building, mid-height of brick wall.
  (setvar "CLAYER" "TEXT")
  (setq labDX (max 1800.0 (+ ht 800.0)))
  (setq labDY (* brickH 0.5))
  (peb-label-with-leader "DOWN PIPE"
                         (list labDX labDY)
                         (list (/ (+ dpX1L dpX2L) 2.0) labDY)
                         "H"
                         220)
  ;; "COLUMN" leader label — LEFT side, 700 mm below KNEE.
  ;; Knee = bottom of haunch = (H - ht), where ht is the haunch depth.
  ;; Same single-MLEADER style as GIRT and DOWN PIPE:
  ;;   - arrow on inner flange of LEFT column (X = 250)
  ;;   - text inside building at the same Y (one-vertex H-leader)
  ;;   - Y = (H - ht - 700) — 700 mm below the haunch underside, so
  ;;     the label sits clear of the knee geometry
  ;;   - arrow auto-points AT the column from inside the building
  (setq labCY (- H ht 700.0))               ; 700 mm below knee/haunch underside
  (setq labCX (max 1800.0 (+ ht 800.0)))    ; same offset as DOWN PIPE / GIRT
  (peb-label-with-leader "COLUMN"
                         (list labCX labCY)        ; labelPos (inside bldg)
                         (list 250.0 labCY)        ; arrowPt on inner flange
                         "H"
                         220)
  (setvar "PLINEWID" 0.0)
)

(defun draw-eave-features (W H /
                          inH outH botW innerX outerX
                          gyTopIn gyBot gyTopOut
                          tx ty ax arrowX arrowY)
  ;;  MAIMAAR-standard eave gutter (open-top trough):
  ;;     INNER (toward building) vertical = 165 mm  with drip-lip on top
  ;;                                          (roof sheeting drops water here)
  ;;     OUTER (away from building) vert  = 196 mm  with hem fold
  ;;                                          (taller wall retains water)
  ;;     BOTTOM flat                       = 190 mm  (= 20 + 170)
  ;;  Inner top sits at H + 200 = roof-sheeting bottom level at the eave.
  (setvar "CLAYER" "GUTTER")
  (setq inH    165.0)               ; INNER vertical height (was 196 - corrected)
  (setq outH   196.0)               ; OUTER vertical height (was 165 - corrected)
  (setq botW   190.0)
  (setq gyTopIn  (+ H 200.0))       ; inner top (where roof sheet drops in)
  (setq gyBot    (- gyTopIn inH))   ; bottom y = inner top - 165 = H + 35
  (setq gyTopOut (+ gyBot outH))    ; outer top = bottom + 196 = H + 231

  ;; ----- LEFT side eave gutter (per picture 2 reference) -----
  ;; Inner side (toward building) at innerX=-200, height=165 with 100mm lip
  ;;   bent INWARD into the gutter trough (= away from building, -x direction).
  ;;   Roof sheet rests on top of this lip.
  ;; Outer side (away from building) at outerX=-390, height=196 with hem fold.
  (setq innerX -200.0)
  (setq outerX (- innerX botW))
  (command "PLINE"
    (list (- innerX 25.0) gyTopIn)                ; inner lip end (25mm into gutter)
    "W" 1.5 1.5
    (list innerX gyTopIn)                          ; inner top
    (list innerX gyBot)                            ; down inner vertical 165 mm
    (list outerX gyBot)                            ; across bottom 190 mm
    ;; Up outer vertical with hem fold zigzag (toward gutter interior = +x)
    (list outerX        (- gyTopOut 105.0))
    (list (+ outerX 15) (- gyTopOut 95.0))
    (list (+ outerX 15) (- gyTopOut 80.0))
    (list outerX        (- gyTopOut 70.0))
    (list outerX gyTopOut)                         ; outer top
    (list (+ outerX 25.0) gyTopOut)                ; outer lip end (25mm into gutter)
    "")

  ;; ----- RIGHT side eave gutter (mirrored: lip extends +x into gutter) -----
  (setq innerX (+ W 200.0))
  (setq outerX (+ innerX botW))
  (command "PLINE"
    (list (+ innerX 25.0) gyTopIn)                ; inner lip end (25mm into gutter)
    "W" 1.5 1.5
    (list innerX gyTopIn)
    (list innerX gyBot)
    (list outerX gyBot)
    (list outerX        (- gyTopOut 105.0))
    (list (- outerX 15) (- gyTopOut 95.0))
    (list (- outerX 15) (- gyTopOut 80.0))
    (list outerX        (- gyTopOut 70.0))
    (list outerX gyTopOut)
    (list (- outerX 25.0) gyTopOut)               ; outer lip end (25mm into gutter)
    "")

  ;; ----- "EAVE GUTTER" labels — same rule as PURLIN/wall sheeting --
  ;; Arrow segment vertical 1200·TS (so MLEADER renders arrowhead),
  ;; horizontal "bar" segment exactly 300 mm with text starting at the
  ;; bar's right end.  Text X = arrow X + 300.
  (setvar "CLAYER" "TEXT")
  ;; LEFT label  (arrow at left of building)
  (setq ax (- 0.0 botW (* 100 *PEB-TEXT-SCALE*)))    ; arrow X
  (setq tx (+ ax 300.0))                             ; text 300 right of arrow
  (setq ty (+ gyTopOut (* 1200.0 *PEB-TEXT-SCALE*)))
  (peb-label-with-leader "EAVE GUTTER"
                         (list tx ty)                ; labelPos
                         (list ax gyTopOut)          ; arrowPt
                         "V"
                         220)
  ;; RIGHT label  (arrow at right of building)
  (setq ax (+ W botW (* 100 *PEB-TEXT-SCALE*)))      ; arrow X
  (setq tx (+ ax 300.0))                             ; text 300 right of arrow
  (setq ty (+ gyTopOut (* 1200.0 *PEB-TEXT-SCALE*)))
  (peb-label-with-leader "EAVE GUTTER"
                         (list tx ty)
                         (list ax gyTopOut)
                         "V"
                         220)
  (setvar "PLINEWID" 0.0)
)

(defun draw-rafter-label (W H rise ht / slopeLen sa ca dMid topX topY
                                       midD innerX innerY rLabX rLabY)
  ;;  "RAFTER" MLEADER label — single MLEADER like PURLIN but reversed
  ;;  (text within building, below rafter).  Per user spec:
  ;;    - Arrow tip on the INNER FLANGE of the rafter (not the top
  ;;      cladding line)
  ;;    - Anchored to the RIGHT side of the ridge line (mirror of LEFT)
  ;;    - "V" direction, 300 mm bar, text 1200·TS below arrow
  (setq slopeLen (sqrt (+ (* (/ W 2.0) (/ W 2.0)) (* rise rise))))
  (setq sa (/ rise slopeLen))
  (setq ca (/ (/ W 2.0) slopeLen))
  ;; Mid-rafter depth (matches rafter-underside calc):
  (setq midD (max 300.0 (min 500.0 (- (* 0.5 ht) 50.0))))
  ;; RIGHT half rafter — 55% along slope from RIGHT eave (mirror of LEFT).
  (setq dMid (* slopeLen 0.55))
  (setq topX (- W (* dMid ca)))             ; mirror of LEFT: W - dMid*ca
  (setq topY (+ H (* dMid sa)))             ; same Y as LEFT mirror
  ;; Inner flange = top point shifted perpendicular into section.
  ;; For RIGHT rafter, perpendicular-into-section is (-sa, -ca).
  (setq innerX (- topX (* midD sa)))
  (setq innerY (- topY (* midD ca)))
  ;; Text position: 300 mm to the RIGHT of arrow (per user — bar goes
  ;; RIGHT and text sits at right end of the bar) and 1200·TS BELOW
  ;; arrow (mirror of PURLIN's above-arrow offset).
  (setq rLabX (+ innerX 300.0))
  (setq rLabY (- innerY (* 1200 *PEB-TEXT-SCALE*)))
  (setvar "CLAYER" "TEXT")
  (peb-label-with-leader "RAFTER"
                         (list rLabX rLabY)        ; labelPos (below-left arrow)
                         (list innerX innerY)      ; arrowPt on inner flange
                         "V"
                         220)
)

(defun draw-grid-bubble (cx cy r label)
  ;;  Single circle grid bubble (bottom of column), with grid letter inside.
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setvar "CLAYER" "GRID")
  (command "CIRCLE" (list cx cy) r)
  (setvar "TEXTSTYLE" "PEB-TITLE")
  (command "TEXT" "J" "MC" (list cx cy) (* r 0.7) 0 label)
)

(defun peb-structure-label (stype)
  (cond
    ((= stype "CS") "CLEAR SPAN GABLE")
    ((= stype "SS") "SINGLE SLOPE")
    ((= stype "MS") "MULTI-SPAN")
    ((= stype "LT") "LEAN-TO")
    ((= stype "MG") "MULTI-GABLE")
    ((= stype "FR") "FLAT ROOF")
    ((= stype "RC") "ROOF ON RCC COLUMNS")
    ((= stype "CC") "CANTILEVER CANOPY")
    ((= stype "BF") "BUTTERFLY STRUCTURE")
    ((= stype "ACS") "ARCHED CLEAR SPAN")
    ((= stype "AMS") "ARCHED MULTI-SPAN")
    (T "CLEAR SPAN GABLE")
  )
)

;; ===================== MAIN COMMAND =====================

(defun split-at-first-digit (s / i ch result)
  ;;  Split string at first digit position. Returns (prefix suffix-or-nil).
  (setq i 1)
  (setq result nil)
  (while (and (<= i (strlen s)) (not result))
    (setq ch (substr s i 1))
    (if (and (>= (ascii ch) 48) (<= (ascii ch) 57))
      (setq result i))
    (setq i (1+ i)))
  (if result
    (list (vl-string-trim " " (substr s 1 (1- result)))
          (substr s result))
    (list s nil)))

(defun peb-split-2-lines (txt / words idx total halfTotal acc line1 line2 w)
  ;;  Split a string into AT MOST 2 lines, joined by MText paragraph
  ;;  break "\\P".  Splits at a word boundary (space) so words don't
  ;;  get cut.  Aim is roughly half the total character count on each
  ;;  line so the visual block looks balanced.
  ;;
  ;;  Used to force the WALL SHEETING / ROOF SHEETING spec text into a
  ;;  clean two-line layout regardless of wrap-width quirks in MLEADER
  ;;  text content.
  ;;
  ;;  txt = input string (single line, words separated by spaces)
  ;;  Returns: "<line1>\\P<line2>"  (or just txt if only 1 word)
  (if (or (null txt) (= txt "")) (setq txt ""))
  ;; Tokenize on spaces.
  (setq words '())
  (while (setq idx (vl-string-search " " txt))
    (if (> idx 0) (setq words (cons (substr txt 1 idx) words)))
    (setq txt (substr txt (+ idx 2))))
  (if (> (strlen txt) 0) (setq words (cons txt words)))
  (setq words (reverse words))
  (cond
    ((<= (length words) 1) (or (car words) ""))
    (T
      (setq total (apply '+ (mapcar 'strlen words)))
      ;; +1 per gap to roughly account for spaces; not exact but good
      ;; enough for visual balance.
      (setq halfTotal (/ (+ total (length words)) 2))
      (setq acc 0)
      (setq line1 "")
      (setq line2 "")
      (foreach w words
        (cond
          ((and (= line2 "") (< acc halfTotal))
            (setq line1 (if (= line1 "") w (strcat line1 " " w)))
            (setq acc (+ acc (strlen w) 1)))
          (T
            (setq line2 (if (= line2 "") w (strcat line2 " " w))))))
      (if (= line2 "")
        line1
        (strcat line1 "\\P" line2))
    )
  )
)

(defun draw-l-leader (textX textY targetX targetY arrowDir / arrowSize aw)
  ;;  L-shaped (90-deg) arrow leader from text to target.
  ;;  arrowDir = "V" : horizontal first leg then vertical leg with vertical arrow
  ;;                   (use when target is BELOW or ABOVE text - e.g. roof sheeting)
  ;;  arrowDir = "H" : vertical first leg then horizontal leg with horizontal arrow
  ;;                   (use when target is to the SIDE - e.g. wall sheeting, girt)
  ;;  Arrow tip lands AT the target point, tapered tip.
  (setvar "CLAYER" "ARROWS")
  (setvar "PLINEWID" 0.0)
  (setq arrowSize (* 250 *PEB-TEXT-SCALE*))
  (setq aw (* 80 *PEB-TEXT-SCALE*))
  (cond
    ((= arrowDir "V")
      ;; First leg horizontal from text TO targetX at textY
      (command "LINE" (list textX textY) (list targetX textY) "")
      ;; Second leg vertical TO target with arrow tip at target
      (if (< targetY textY)
        ;; Target below
        (progn
          (command "LINE" (list targetX textY)
                          (list targetX (+ targetY arrowSize)) "")
          (command "PLINE"
            (list targetX (+ targetY arrowSize))
            "W" aw 0
            (list targetX targetY) ""))
        ;; Target above
        (progn
          (command "LINE" (list targetX textY)
                          (list targetX (- targetY arrowSize)) "")
          (command "PLINE"
            (list targetX (- targetY arrowSize))
            "W" aw 0
            (list targetX targetY) ""))))
    (T   ; "H" or default
      ;; First leg vertical from text TO targetY at textX
      (command "LINE" (list textX textY) (list textX targetY) "")
      ;; Second leg horizontal TO target with arrow tip at target
      (if (< targetX textX)
        ;; Target left
        (progn
          (command "LINE" (list textX targetY)
                          (list (+ targetX arrowSize) targetY) "")
          (command "PLINE"
            (list (+ targetX arrowSize) targetY)
            "W" aw 0
            (list targetX targetY) ""))
        ;; Target right
        (progn
          (command "LINE" (list textX targetY)
                          (list (- targetX arrowSize) targetY) "")
          (command "PLINE"
            (list (- targetX arrowSize) targetY)
            "W" aw 0
            (list targetX targetY) "")))))
  (setvar "PLINEWID" 0.0)
  ;; (Block-wrap removed - it left the AutoCAD command engine in a state
  ;; that silently broke every subsequent draw-* call.  Leader entities
  ;; are kept as plain LINE + PLINE primitives.)
)

(defun draw-height-dim (objX dimX y1 y2 label / midY extLen txtX sideSign)
  ;;  ACTIVE — hand-rolled vertical/height dim.  Native peb-dim-height-
  ;;  native is defined above for future use but not currently called.
  ;;  objX  = x-coord of the object being dimensioned (where extension lines start)
  ;;  dimX  = x-coord of the dimension line itself
  ;;  y1, y2 = top and bottom y coords being dimensioned
  ;;  label = text label
  (setvar "CLAYER" "DIMENSIONS")
  (setvar "PLINEWID" 0.0)
  (setq midY (/ (+ y1 y2) 2.0))
  (setq extLen 100.0)
  (setq sideSign (if (< dimX objX) -1 1))
  ;; Extension lines (horizontal from object to past dim line)
  (command "LINE" (list objX y1) (list (+ dimX (* sideSign extLen)) y1) "")
  (command "LINE" (list objX y2) (list (+ dimX (* sideSign extLen)) y2) "")
  ;; Dimension line (vertical)
  (command "LINE" (list dimX y1) (list dimX y2) "")
  ;; Arrowheads at ends of dim line
  (dim-arrow-v dimX y1 "U")
  (dim-arrow-v dimX y2 "D")
  ;; Text - rotated 90, on the OUTSIDE of dim line, with extra clearance
  ;; so it sits clearly outside the dim arrows and witness lines.
  (setvar "CLAYER" "TEXT")
  (setq txtX (+ dimX (* sideSign (* 450 *PEB-TEXT-SCALE*))))
  (txt "MC" (list txtX midY) 220 90 label)
)

;; ============================================================================
;; MAMMUT RIGHT-EDGE TITLE PANEL  (ported from MAIMAAR_PEB_Plan.lsp so the
;; cross-section carries the SAME vertical title block as the column plan).
;; These defuns are intentionally identical to the Plan's; when both files are
;; loaded (the _run.scr does Section then Plan) the Plan's copies override these
;; harmlessly.  Kept here so Section.lsp renders a full title block standalone.
;; ============================================================================
(defun tb-line (x1 y1 x2 y2 col)
  (entmake (list (cons 0 "LINE") (cons 100 "AcDbEntity") (cons 8 "0")
                 (cons 62 col) (cons 100 "AcDbLine")
                 (list 10 x1 y1 0.0) (list 11 x2 y2 0.0))))
(defun tb-rect (x1 y1 x2 y2 col)
  (tb-line x1 y1 x2 y1 col) (tb-line x2 y1 x2 y2 col)
  (tb-line x2 y2 x1 y2 col) (tb-line x1 y2 x1 y1 col))
(defun tb-mtext (x y h wid attach str col)
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

;; strip an embedded unit suffix ("0 KN/m2" -> "0", "135 km/h" -> "135")
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
    (tb-fith "    DIMENSIONS & LEVELS WILL BE SHOWN IN THE" cw (* sm 0.92)) cw 1
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
       (list "WIND SPEED"             (tb-get "WIND")     "KPH")
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
  (setq rh (* H 0.024) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (+ yCur (* rh 0.4))
    (tb-fith (strcat "AS PER " (tb-get "CODE") " METAL BUILDING SYSTEMS MANUAL")
             cw (* H 0.0100)) cw 1
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
  ;; PROJECT
  (setq bt yCur rh (* H 0.058) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "PROJECT :" grey)
  (tb-mtext midX (+ yCur (* rh 0.30)) (tb-fith (tb-get "PROJECT") (* 1.9 cw) bv) cw 5 (tb-get "PROJECT") green)
  (tb-hdiv yCur)
  ;; CUSTOMER
  (setq bt yCur rh (* H 0.048) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "CUSTOMER :" grey)
  (tb-mtext midX (+ yCur (* rh 0.28)) (tb-fith (tb-get "CUSTOMER") (* 1.6 cw) bv) cw 5 (tb-get "CUSTOMER") green)
  (tb-hdiv yCur)
  ;; STEEL CONTRACTOR : real Maimaar logo + address
  (setq bt yCur rh (* H 0.175) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "STEEL CONTRACTOR :" grey)
  (peb-tb-place-logo (+ X0 (* W 0.10)) (+ yCur (* rh 0.52))
                     (+ X0 (* W 0.90)) (- bt (* lbl 2.4)))
  (tb-mtext (+ X0 (* W 0.06)) (+ yCur (* rh 0.48)) sm cw 1 (tb-get "ADDR") white)
  (tb-hdiv yCur)
  ;; quote / bldg rows
  (foreach pr (list (list "QUOTE NO." (tb-get "QUOTE"))
                    (list "Bldg. No." (tb-get "BLDGNO"))
                    (list "Bldg. Name." (tb-get "BLDGNAME"))
                    (list "No. Of Identical Bldg." (tb-get "IDENTICAL")))
    (setq rh (* H 0.024) yCur (- yCur rh))
    (tb-mtext (+ X0 (* W 0.05)) (+ yCur (* rh 0.50)) lbl 0 4 (car pr) grey)
    (tb-mtext (+ X0 (* W 0.52)) (+ yCur (* rh 0.50))
              (tb-fith (strcat ": " (cadr pr)) (* W 0.44) val) (* W 0.45) 4
              (strcat ": " (cadr pr)) green)
    (tb-hdiv yCur))
  ;; Drawing Title
  (setq bt yCur rh (* H 0.045) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.2)) lbl cw 1 "Drawing Title :" grey)
  (tb-mtext midX (+ yCur (* rh 0.26)) (tb-fith (tb-get "DRGTITLE") cw bv) cw 5
            (strcat "{\\fArial|b1;" (tb-get "DRGTITLE") "}") green)
  (tb-hdiv yCur)
  ;; footer : Scale | Sheet Size | Sheet No.  (fills down to Y0)
  (setq rh (- yCur Y0) c1x (+ X0 (* W 0.40)) c2x (+ X0 (* W 0.70)))
  (tb-line c1x Y0 c1x yCur white) (tb-line c2x Y0 c2x yCur white)
  (tb-mtext (+ X0 (* W 0.04)) (- yCur (* lbl 1.2)) lbl 0 1 "Scale" grey)
  (tb-mtext (+ X0 (* W 0.20)) (+ Y0 (* rh 0.32)) val 0 5 (tb-get "SCALE") green)
  (tb-mtext (+ c1x (* W 0.03)) (- yCur (* lbl 1.2)) lbl 0 1 "Sheet Size" grey)
  (tb-mtext (* 0.5 (+ c1x c2x)) (+ Y0 (* rh 0.32)) val 0 5 (tb-get "SHEETSIZE") green)
  (tb-mtext (+ c2x (* W 0.03)) (- yCur (* lbl 1.2)) lbl 0 1 "Sheet No." grey)
  (tb-mtext (* 0.5 (+ c2x (+ X0 W))) (+ Y0 (* rh 0.32)) val 0 5 (tb-get "SHEETNO") green)
  (princ))

(defun C:PEB-SECTION
  ( / dataFile data
    project client propinput propno fulldate
    bldgno revno
    len wid widInput stype slopeStr slopeD rise
    H clearHt ht rd cb fw ep purlinD brickH
    windspeed exposure collateral
    maxSize areaM2
    c0 c1 c2 c3 c4 c5 c6
    tbTop tbBot tbW tbXShift
    borderL borderR borderB borderT
    logoX logoY logoScale
    ext extY
    dimX1 dimX2 d y
    loadValX bubR
    layout cols ridges i rx cx prevCol curCol modw
    numGab effSpan slopeRise spanPerGab gWmg haunchCols msApexX msWidths
    bubY tbShift tbScale cxL cyL cxR cyR tagRun
    dimX1 dimX2 dimX3 dimX4
    leftCol rightCol halfL halfR midLX midRX midLY midRY
    nCols bubX
    loadValW rowY lineH rowGap nL pjValX pjValW rowPad rTops yy
    oldEnts shiftAmt
    vY0
    tblTotalH tblHeaderH tblBodyH tblBodyRowH tblColWs tblHeaders tblBodies tblMerges tblObj
    tblScaleX
    genNotesText accessoriesText loadsText codesText projInfoText maimaarText
    genNotesCol accessoriesCol loadsCol codesCol projInfoCol maimaarCol
    projInfoRows
  )

  (vl-load-com)
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  (setvar "GRIDMODE" 0)
  (setvar "SNAPMODE" 0)
  (setvar "PLINEWID" 0.0)   ; ensure thin lines for frame/rafter

  ;; Reset L-leader block counter so block names start fresh each run.
  (setq *PEB-LEADER-CNT* 0)

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
  (setq data (MSPL-Read-Data dataFile))
  (if (null data)
    (progn
      (setvar "CMDECHO" 1)
      (princ "\nERROR: Data file not found or empty.")
      (princ)
      (exit)
    )
  )

  ;; ── Project info ─────────────────────────────────────────────
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

  ;; ── Geometry ─────────────────────────────────────────────────
  ;; The Excel WIDTH input is OUT-TO-OUT of the wall sheeting.  Internally
  ;; the section is laid out with the LEFT column outer face at x=0 and
  ;; RIGHT column outer face at x=wid, with the sheeting an extra 235mm
  ;; outside on each side (girtDepth 200 + cladThk 35).  So convert:
  ;;   widInput = user input  (sheeting → sheeting, used for display + area)
  ;;   wid      = widInput - 470  (column-outer → column-outer, used for geometry)
  (setq len      (MSPL-Get-Num data "LENGTH"))
  (setq widInput (MSPL-Get-Num data "WIDTH"))

  (if (or (null widInput) (<= widInput 0))
    (progn
      (alert "WIDTH is missing in the data file.\nClick Generate in Excel to refresh.")
      (setvar "CMDECHO" 1) (princ) (exit)
    )
  )
  (setq wid (- widInput 470.0))

  ;; ── Slope ────────────────────────────────────────────────────
  (setq slopeStr (format-slope (MSPL-Get-Str data "SLOPE")))
  (setq slopeD   (slope-denom slopeStr))

  (setq stype (strcase (MSPL-Get-Str data "STYPE")))
  (if (not (member stype '("CS" "SS" "MS" "LT" "MG" "FR" "RC" "CC" "BF" "ACS" "AMS")))
    (setq stype "CS"))

  ;; ── Effective span for rise/haunch calc (per-gable for MG) ──
  ;; For MG: each gable has its own ridge, so rise is computed
  ;; on the gable-width, not the full building width.
  ;; Min NumGables for MG = 2 (per user spec), so default to 2 if blank.
  (cond
    ((= stype "MG")
      (setq numGab (MSPL-Get-Int data "NUMGABLES"))
      (if (or (null numGab) (< numGab 2)) (setq numGab 2))
      (setq effSpan (/ wid numGab)))
    (T
      (setq effSpan wid)))
  (setq rise (/ (/ effSpan 2.0) slopeD))

  ;; ── User-facing section inputs ───────────────────────────────
  ;; Customer enters only the BUILDING ENVELOPE.  Structural member
  ;; sizes are auto-computed using PEB engineering judgment, since
  ;; at proposal stage the draftsman doesn't yet have detailed sizes.
  (setq clearHt (MSPL-Get-Num data "CLEARHEIGHT"))
  (if (or (null clearHt) (<= clearHt 0))
    (progn
      (alert "CLEAR HEIGHT is missing.\nFill Excel cell B65 (clear height in mm), click Generate, and try again.")
      (setvar "CMDECHO" 1) (princ) (exit)
    )
  )

  (setq brickH (MSPL-Get-Num data "BRICKHEIGHT"))
  (if (or (null brickH) (< brickH 0))   ; 0 disables brick wall
    (setq brickH 3048.0)
  )

  ;; ── Auto-computed member sizes (engineering judgment) ───────
  ;; effSpan was computed above (per-gable for MG, full width otherwise).
  (setq ht      (max 700.0 (min 1100.0 (+ 700.0 (* (/ (- effSpan 15000.0) 35000.0) 400.0)))))   ; haunch depth: 700-1100mm for span 15-50m
  ;; Ridge depth ~70% of haunch (visible vertical depth), per Chapter 3 / user guidance.
  (setq rd      (max 600.0 (min 1000.0 (- ht 100.0))))         ; ridge depth: ht-100mm (600-1000mm for span 15-50m)
  (setq cb      (max 250.0 (min 400.0 (+ 250.0 (* (/ (- effSpan 15000.0) 35000.0) 150.0)))))   ; column base: 250-400mm for span 15-50m
  (setq fw      200.0)                                        ; flange width
  (setq ep      20.0)                                         ; end plate thickness (typical 20-24mm)
  (setq purlinD 200.0)                                        ; Z-purlin standard

  ;; Eave height = top of rafter at the haunch.
  ;; Rafter UNDERSIDE at the haunch sits exactly at clearHt (user input).
  ;; Purlins and sheeting sit ABOVE H (H + purlinD, H + purlinD + cladThk).
  (setq H (+ clearHt ht))

  ;; ── Other info for title block ───────────────────────────────
  (setq windspeed  (MSPL-Get-Str data "WINDSPEED"))
  (setq exposure   (MSPL-Get-Str data "EXPOSURE"))
  (setq collateral (MSPL-Get-Str data "COLLATERAL"))
  (if (= windspeed  "") (setq windspeed  "AS PER DESIGN"))
  (if (= exposure   "") (setq exposure   "B"))
  (if (= collateral "") (setq collateral "AS PER DESIGN"))

  (setq fulldate (format-date (getvar "CDATE")))
  ;; Floor area uses the user's input width (out-to-out of sheeting).
  (if (and len widInput (> len 0) (> widInput 0))
    (setq areaM2 (/ (* len widInput) 1000000.0))
    (setq areaM2 0.0)
  )

  ;; ── Auto scaling: text/dim/leader scale fits BOTH building dimensions.
  ;; Use the SMALLER of width-derived and height-derived scales, so the
  ;; binding dimension always governs.  This keeps text proportional for:
  ;;   - Tall narrow buildings   (15 x 50)  -> width binds  -> small text
  ;;   - Wide short buildings    (150 x 5)  -> height binds -> small text
  ;;   - Balanced typical bldgs  (25 x 6)   -> width binds  -> normal text
  ;; Continuous formula, clamped to [0.55, 1.70] so small buildings stay
  ;; readable and huge ones don't get cartoon-sized.  Final 1.25 bump
  ;; for print legibility.
  ;; Use the LARGER of the two scale factors so wide low-slope buildings
  ;; (where H+rise is small but widInput is huge) still get a readable
  ;; text scale.  Was `min` of the two, which floored TS at the smaller
  ;; factor and produced unreadable labels at e.g. W=150 m / slopeD=10
  ;; (height factor 1.55 vs width factor 4.29 → min=1.55, but a 150 m
  ;; section can use the bigger scale).  Outer min(1.7, …) still caps it.
  (setq *PEB-TEXT-SCALE*
        (* 1.25 (max 0.55
                     (min 1.7
                          (max (/ widInput      35000.0)
                               (/ (+ H rise)    10000.0))))))
  (setq *PEB-DIM-SCALE*  *PEB-TEXT-SCALE*)
  ;; (setup-maimaar-dim is defined above and was used by the
  ;;  peb-dim-*-native helpers, but the current code path uses the
  ;;  hand-rolled dim-line-h / draw-height-dim functions which don't
  ;;  need a registered dimstyle — they emit primitives directly.)
  ;; Fix the Standard multileader style so MLEADERs get a visible
  ;; "Closed Filled" arrowhead.  Without this, the style ships with
  ;; arrow set to "_None" and ArrowSize is irrelevant.
  (peb-setup-mleader-style)

  ;; ── Default DIMTXSTY = PEB-TITLE for every dim in the run ──
  ;; Set globally now so even dims that bypass peb-dim-set-vars (e.g.,
  ;; legacy callers) still pick up the right text style.  Also save
  ;; it onto the active dimstyle via _-DIMSTYLE _Save so it persists
  ;; as the default on the dimstyle itself, not just as an override.
  (vl-catch-all-apply
    (function (lambda () (setvar "DIMTXSTY" "PEB-TITLE"))))

  ;; ── Working extents ──────────────────────────────────────────
  (setq ext  (* 2500 *PEB-TEXT-SCALE*))   ; horizontal bleed beyond columns
  (setq extY (* 1500 *PEB-TEXT-SCALE*))   ; vertical bleed below floor

  (command "UNDO" "BEGIN")

  ;; ── Multi-section: shift previous drawings right on each new run ──
  ;; Each call to PEB-SECTION shifts whatever entities are already in the
  ;; drawing (from previous runs) rightward by widInput + 30000mm, then
  ;; draws the new section fresh at origin.  Newest is always at origin;
  ;; older drawings cascade further right with a clear gap.
  ;;
  ;; ssget filter EXCLUDES OLE2FRAME / IMAGE entities (Excel-embedded
  ;; objects) so the MOVE doesn't trigger the OLE handshake / Excel hang.
  (setq oldEnts (ssget "_X"
                       '((-4 . "<NOT")
                         (0 . "OLE2FRAME,IMAGE")
                         (-4 . "NOT>"))))
  (if (and oldEnts (> (sslength oldEnts) 0))
    (progn
      (setq shiftAmt (+ widInput 30000.0))
      (command "_MOVE" oldEnts "" (list 0.0 0.0) (list shiftAmt 0.0))
    )
  )

  ;; ── Text styles ──────────────────────────────────────────────
  (make-text-style "PEB-TITLE" "romand.shx")
  (make-text-style "PEB-BODY"  "romans.shx")
  (make-text-style "PEB-DIM"   "romans.shx")

  ;; ── Linetypes ────────────────────────────────────────────────
  (safe-load-ltype "CENTER")
  (safe-load-ltype "HIDDEN")
  (safe-load-ltype "DASHDOT")

  ;; ── Layers ───────────────────────────────────────────────────
  (make-layer "BORDER"       "7"   "Continuous" "0.70")
  (make-layer "FRAME"        "7"   "Continuous" "0.50")
  (make-layer "FRAME-FILL"   "8"   "Continuous" "0.09")
  (make-layer "PLATES"       "7"   "Continuous" "0.35")  ; white = MS material colour
  (make-layer "GROUND"       "7"   "Continuous" "0.50")
  (make-layer "GROUND-HATCH" "8"   "Continuous" "0.09")
  (make-layer "RIDGE"        "5"   "HIDDEN"     "0.18")
  (make-layer "TEXT"         "7"   "Continuous" "0.25")
  (make-layer "DIMENSIONS"   "3"   "Continuous" "0.18")
  (make-layer "ARROWS"       "7"   "Continuous" "0.25")
  (make-layer "CL"           "1"   "CENTER"     "0.09")
  (make-layer "TITLEBLOCK"   "1"   "Continuous" "0.35")
  (make-layer "TB-HEADER"    "1"   "Continuous" "0.50")
  (make-layer "BRICK-WALL"   "30"  "Continuous" "0.25")  ; brown
  (make-layer "RCC-COLUMN"   "8"   "Continuous" "0.35")  ; grey - RCC concrete
  (make-layer "CLADDING"     "5"   "Continuous" "0.25")  ; blue
  (make-layer "PURLINS"      "6"   "Continuous" "0.18")  ; magenta
  (make-layer "GIRTS"        "6"   "Continuous" "0.18")  ; magenta
  (make-layer "GUTTER"       "4"   "Continuous" "0.25")  ; cyan
  (make-layer "GRID"         "150" "Continuous" "0.25")

  ;; ── Compute section layout (cols + ridges) based on stype ───
  (setq layout (compute-section-layout data stype wid))
  (setq cols   (car  layout))
  (setq ridges (cadr layout))

  ;; ── Floor / ground line ──────────────────────────────────────
  (draw-floor-line wid ext)
  ;; "FFL ±0.00" elevation marker — always centered horizontally
  ;; under the building (X = wid / 2) so it stays in the middle
  ;; of the section regardless of building width.
  (draw-ffl-marker (/ wid 2.0) 0.0)

  ;; ── Frame outline (stype-aware dispatcher) ───────────────────
  (cond
    ((= stype "SS")
      (setq slopeRise (/ wid slopeD))
      (draw-ss-frame wid H slopeRise ht cb))
    ((= stype "RC")
      (draw-rc-frame wid H rise ht rd))
    ((= stype "LT")
      (setq slopeRise (/ wid slopeD))
      (draw-lt-frame wid H slopeRise ht cb))
    ((= stype "FR")
      (draw-fr-frame wid H ht cb))
    ((= stype "CC")
      (setq slopeRise (/ wid slopeD))
      (draw-cc-frame wid H slopeRise ht cb))
    ((= stype "BF")
      (draw-bf-frame wid H rise ht cb 400.0))
    ((= stype "ACS")
      ;; Arched Clear Span — single curved roof arc, 2 R.F. columns
      (draw-acs-frame wid H rise ht cb))
    ((= stype "AMS")
      ;; Arched Multi-Span 1 — two arches with center column rising to peak
      (draw-ams-frame wid H rise ht cb))
    ((= stype "MS")
      ;; Multi-Span: end-frame gable + separate intermediate columns
      (draw-ms-frame cols wid H rise ht rd cb))
    ((= stype "MG")
      ;; Multi-Gable: route to draw-mg-multi-frame (handles both
      ;; spanPerGab=1 and spanPerGab>1 via base outline + sub-span cols).
      ;; NOTE: AutoLISP's `or` returns T/nil (not first non-nil value),
      ;; so we use a simple if-let pattern to default missing values.
      (setq spanPerGab (MSPL-Get-Int data "SPANSPERGABLE"))
      (if (or (null spanPerGab) (< spanPerGab 1)) (setq spanPerGab 1))
      (draw-mg-multi-frame wid H rise ht rd cb numGab spanPerGab))
    (T
      ;; CS, MG (spanPerGab=1) and other standard gable-type frames
      (draw-frame-outline cols ridges H rise ht rd cb)))

  ;; ── Connection plates ────────────────────────────────────────
  ;; For MG: plates only at HAUNCH columns (left/right outer + valley
  ;; columns between gables).  Sub-span intermediate columns are not
  ;; haunch points - they sit under the rafter and do not need plates.
  (cond
    ((= stype "MG")
      (progn
        ;; Base plates at every gable-boundary column (0, gW, 2gW, ..., W)
        (setq haunchCols '())
        (setq i 0)
        (setq gWmg (/ wid numGab))
        (while (<= i numGab)
          (setq haunchCols (append haunchCols (list (* i gWmg))))
          (setq i (1+ i)))
        (draw-base-plates-multi haunchCols cb ep 400.0)
        ;; Standard knee-haunch + valley-seam plates at gable boundaries.
        ;; (draw-haunch-plates' interior branch now draws TWO half-plates
        ;;  with a vertical seam at the column flange — matches picture 5.)
        (draw-haunch-plates haunchCols H ht ep T nil)   ; T = MG valleys → 4-vertical-plate detail; ridgeX nil (MG ridges aren't in haunchCols)
        ;; Ridge-apex plates are SKIPPED when a sub-span column lands at the
        ;; ridge (spanPerGab even).  In that case the ridge column carries
        ;; the connection at column-top and the rafter web stays continuous
        ;; through the apex.
        (draw-rafter-stiffeners haunchCols ridges H rise ht rd
          (and spanPerGab (> spanPerGab 1) (zerop (rem spanPerGab 2))))
        ;; --- Ridge-column connection plates (picture 4) ----------------
        ;; A sub-span column lands at a ridge ONLY when spanPerGab is EVEN
        ;; (then j = spanPerGab/2 places subX at gable midpoint = ridge).
        ;; For each such column, add the ridge-column plate detail at column
        ;; top elevation (H + rise - rd).  Sub-span cols off-ridge stay plain.
        (if (and spanPerGab (> spanPerGab 1)
                 (zerop (rem spanPerGab 2)))
          (progn
            (setq i 0)
            (while (< i numGab)
              ;; Each gable's ridge column lies at i*gWmg + gWmg/2
              (draw-mg-ridge-col-plates
                (+ (* i gWmg) (/ gWmg 2.0))
                H rise rd ep)
              (setq i (1+ i)))))))
    ((= stype "MS")
      (progn
        ;; MS: base plates at every column (end + interior).  Build a
        ;; parallel list of per-column webs so each interior base plate
        ;; matches its column's web (300-600 mm scaled with module width).
        (setq msWidths '())
        (setq i 0)
        (while (< i (length cols))
          (setq msWidths (append msWidths (list (ms-col-web-at cols i))))
          (setq i (1+ i)))
        (draw-base-plates-multi cols cb ep msWidths)
        ;; Detect whether any interior MS column lands AT the ridge (W/2).
        ;; If so, treat that column the same way MG treats a ridge sub-span
        ;; column: SUPPRESS the apex plate-pair AND draw the ridge-column
        ;; plate detail (4 horizontal plates + 4 bolts + outer-end stiffeners).
        ;; The simple horizontal haunch-stack at column-top elevation H-ht
        ;; would be wrong here because the actual column top is H+rise-rd.
        (setq msApexX nil)
        (setq i 1)
        (while (< i (1- (length cols)))
          (if (< (abs (- (nth i cols) (/ wid 2.0))) 1.0)
            (setq msApexX (nth i cols)))
          (setq i (1+ i)))
        ;; END-column haunch plates ONLY — pass (0, wid) so draw-haunch-plates
        ;; renders the LEFT-end and RIGHT-end haunch details and nothing else.
        ;; Interior MS columns use the new draw-ms-interior-plates helper
        ;; below, which positions plates at the actual cigar-rafter underside
        ;; and sizes them to the per-column web (300-600 mm based on module).
        (draw-haunch-plates (list 0.0 wid) H ht ep nil nil)
        ;; Rafter web transition plates + 12 m mid-span splices.
        ;; CRITICAL: pass (0, wid) NOT cols — draw-rafter-stiffeners uses
        ;; cols[i] / cols[i+1] as the gable boundaries flanking ridges[i],
        ;; and for MS the gable spans the FULL building width, not the
        ;; first module.  Without this, transition X positions and the
        ;; 12 m piece-rule are computed against a tiny sub-segment.
        (draw-rafter-stiffeners (list 0.0 wid) ridges H rise ht rd
          (if msApexX T nil))                            ; suppress apex if ridge col
        ;; Interior MS column connection plates — cigar-aware Y, web-sized.
        (draw-ms-interior-plates cols wid H rise ht rd ep msApexX)
        (if msApexX
          (draw-mg-ridge-col-plates msApexX H rise rd ep))))
    ((member stype '("ACS" "AMS"))
      ;; Arched frames — base plates only.  No haunch plates or
      ;; rafter stiffeners (arches don't have classic haunches; the
      ;; arch acts as a continuous member).
      (cond
        ((= stype "ACS") (draw-base-plates wid cb ep))
        ((= stype "AMS") (draw-base-plates-multi cols cb ep 400.0))))
    (T
      (progn
        (draw-base-plates   wid cb ep)
        (draw-haunch-plates cols H ht ep nil nil)        ; nil = CS/RC end columns only
        (if (member stype '("CS" "RC"))
          (draw-rafter-stiffeners cols ridges H rise ht rd nil)))))

  ;; ── Valley gutter (between adjacent gables in MG) ───────────
  ;; Valley positions: i * (W / numGab) for i = 1 .. numGab-1
  ;; True trapezoidal gutter cross-section per the MAIMAAR std detail:
  ;;   Bottom flat      = 400 mm  (= column intColW, sits on column flanges)
  ;;   Side slope       = 140 mm horizontal × 190 mm vertical
  ;;   Top flanges      = 174 mm each (horizontal)
  ;;   Total depth      = 190 mm
  ;;   Top flange Y     = H (eave level)
  ;;   Bottom flat Y    = H − 190
  (if (and (= stype "MG") (>= numGab 2))
    (progn
      (setq gWmg (/ wid numGab))
      (setq i 1)
      (while (< i numGab)
        (setq cx (* i gWmg))             ; valley X (gable boundary)
        ;; Rafter top at the purlin x position (cx ± 460), accounting for slope.
        ;; Purlin lower flange sits on this elevation (rests on rafter top).
        (setq vY0 (+ H (/ (* rise 920.0) gWmg)))   ; = H + rise·460/(gWmg/2)

        ;; --- Two Z-shape valley purlins, OUTSIDE under the gutter lips ---
        ;; Each purlin is centred under the corresponding gutter top flange.
        ;; LOWER flange rests on the rafter top (at vY0); UPPER flange supports
        ;; the gutter LIP from below at vY0 + 200.
        (draw-z-purlin-flat (- cx 460.0) vY0  1)
        (draw-z-purlin-flat (+ cx 460.0) vY0 -1)

        ;; --- 6-vertex trapezoidal valley gutter ---
        ;; LIPS rest on purlin UPPER FLANGE at y = vY0 + 200.
        ;; Lip INNER edge bends DOWN at cx ± 400 (= purlin top flange inner
        ;; end), so the FULL lip width is fully supported by the purlin
        ;; top flange below.  Side slope is now 200 H × 190 V (was 140×190).
        ;; Trough hangs BELOW: bottom at y = vY0 + 10.
        (setvar "CLAYER" "GUTTER")
        (setvar "PLINEWID" 0.0)
        (command "PLINE"
          (list (- cx 514.0) (+ vY0 200.0))   ; left flange OUTER end
          "W" 1.5 1.5
          (list (- cx 400.0) (+ vY0 200.0))   ; left flange INNER (slope start, on purlin)
          (list (- cx 200.0) (+ vY0  10.0))   ; bottom-left corner
          (list (+ cx 200.0) (+ vY0  10.0))   ; bottom-right corner
          (list (+ cx 400.0) (+ vY0 200.0))   ; right flange INNER (slope end, on purlin)
          (list (+ cx 514.0) (+ vY0 200.0))   ; right flange OUTER end
          "")
        (setvar "PLINEWID" 0.0)
        ;; Label — placed above the gutter top flanges
        (setvar "CLAYER" "TEXT")
        (txt "MC"
          (list cx (+ vY0 200.0 (* 1500 *PEB-TEXT-SCALE*)))
          200 0 "VALLEY GUTTER")
        (setq i (1+ i))))
  )
  ;; Haunch plates only meaningful for gable-type and SS/LT frames.
  ;; Skip for FR (no haunch), BF (centre column only), CC (back column only).


  ;; ── Side elements (brick, cladding, purlins, girts, gutter) ──
  ;; Skip elements that don't apply to certain frame types:
  ;;   BF: NO side walls (centre column only)
  ;;   CC: open front (cantilever) - simplified, skip side elements
  ;;   LT: existing wall on one side (drawn separately in draw-lt-frame)
  ;;   SS: asymmetric heights - elements still drawn at H, high-side
  ;;       follow-up tuning will be done next turn
  (cond
    ;; ── BF (Butterfly): center column only, no walls ──
    ;; Add COLUMN label pointing at center column inner flange.
    ((= stype "BF")
      (peb-label-with-leader "COLUMN"
                             (list (max 1800.0 (+ ht 800.0))
                                   (- H ht 700.0))            ; text Y, 700 below knee
                             (list (+ (/ wid 2.0) 200.0)      ; arrow at center col R-flange
                                   (- H ht 700.0))
                             "H"
                             220))
    ;; ── CC (Cantilever Canopy): one back column, open front ──
    ;; Add COLUMN label pointing at the back (left) column inner flange.
    ((= stype "CC")
      (peb-label-with-leader "COLUMN"
                             (list (max 1800.0 (+ ht 800.0))
                                   (- H ht 700.0))
                             (list 250.0 (- H ht 700.0))      ; arrow at left col inner flange
                             "H"
                             220))
    ;; ── LT (Lean-To): one PEB column on left, masonry wall on right ──
    ;; LT has a sloped roof (single slope from low eave to wall top), so
    ;; it gets the full set of labels: COLUMN (left), GIRTS, DOWN PIPE
    ;; on the wall side, ROOF SHEETING along the slope, and slope tag.
    ((= stype "LT")
      (peb-label-with-leader "COLUMN"
                             (list (max 1800.0 (+ ht 800.0))
                                   (- H ht 700.0))
                             (list 250.0 (- H ht 700.0))
                             "H"
                             220)
      ;; Existing wall label on the right (RCC/MASONRY)
      (peb-label-with-leader "EXISTING WALL"
                             (list (- wid (max 1800.0 (+ ht 800.0)))
                                   (- H ht 700.0))
                             (list (- wid 230.0)              ; arrow on wall inner face
                                   (- H ht 700.0))
                             "H"
                             220)
      ;; Brick wall + girts only on the LEFT (PEB column) side; the
      ;; right side has the existing masonry wall already.
      (if (and brickH (> brickH 0))
        (progn
          (setvar "CLAYER" "BRICK-WALL")
          (command "RECTANG"
            (list (- 0.0 200.0) 0.0)
            (list 0.0 brickH))
          (command "HATCH" "BRICK" 150 0 "L" ""))))
    ((member stype '("ACS" "AMS"))
      ;; Arched frames — brick walls + girts + downpipes + eave features
      ;; apply normally (they're at column locations).  Cladding/purlins
      ;; follow the CURVED roof so they need a future arched-cladding
      ;; routine; for now skip those, which is acceptable at proposal stage
      ;; (the curved rafter outline already shows the roof geometry).
      (draw-brick-wall    wid brickH)
      (draw-girts         wid H brickH)
      (draw-downpipes     wid H brickH)
      (draw-eave-features wid H)
      ;; "CURVED ROOF RAFTER" label — single MLEADER pointing at the
      ;; arch's apex (or quarter-arch).  Same style as the standard
      ;; RAFTER MLEADER (reversed PURLIN with text below arrow), but
      ;; with descriptive label text matching the user's reference pic.
      (peb-label-with-leader "CURVED ROOF RAFTER"
                             (list (+ (/ wid 2.0) 1500.0)        ; text right of apex
                                   (- (+ H rise)
                                      (* 1200 *PEB-TEXT-SCALE*))) ; text below arrow
                             (list (/ wid 2.0)                   ; arrow at apex inner
                                   (- (+ H rise) 200.0))         ; 200mm below outer
                             "V"
                             220))
    ((= stype "MG")
      ;; MG: same element sequence as CS, but MG-specific variants for
      ;; purlins (per gable) and eave struts (outer eaves only, correct slope).
      ;; GIRT + DOWN PIPE labels use the same CS functions (they target x=0/W).
      (draw-brick-wall    wid brickH)
      (draw-cladding-mg   data wid H rise brickH numGab)
      (draw-purlins-mg    wid H rise numGab (/ wid numGab))
      (draw-eave-strut-mg wid (/ wid numGab) H rise)
      (draw-girts         wid H brickH)
      (draw-downpipes     wid H brickH)
      (draw-eave-features wid H)
      (draw-rafter-label  (/ wid numGab) H rise ht))
    (T
      (draw-brick-wall    wid brickH)
      (draw-cladding      data wid H rise brickH)
      (draw-purlins       wid H rise)
      (draw-eave-strut    wid H rise)
      (draw-girts         wid H brickH)
      (draw-downpipes     wid H brickH)
      (draw-eave-features wid H)
      (draw-rafter-label  wid H rise ht)))

  ;; ── Slope tags placed 25% in from the RIDGE on each rafter half ──
  ;; sheeting top sits at H + rise + purlinH(200) + cladThk(35) above rafter.
  ;; Tag X at 75% of half-span from each eave (= 25% from ridge) so it sits
  ;; well clear of the EAVE STRUT/GUTTER labels at the eave AND clear of
  ;; the PURLIN label at ~30-40% of the slope.  Triangle ramps toward
  ;; the ridge on each side.
  ;;
  ;; SKIPPED for arched frames (ACS, AMS) — no straight slope.  The
  ;; curved rafter geometry self-documents its roof shape; a straight
  ;; rise/run triangle would misrepresent the arch.
  (if (not (member stype '("ACS" "AMS")))
  (foreach rx ridges
    ;; figure out which columns flank this ridge
    (setq leftCol  0.0)
    (setq rightCol wid)
    (foreach cx cols
      (if (and (< cx rx) (> cx leftCol))  (setq leftCol  cx))
      (if (and (> cx rx) (< cx rightCol)) (setq rightCol cx)))
    (setq halfL (- rx leftCol))
    (setq halfR (- rightCol rx))
    ;; X position: middle of each half-rafter span (50% from eave column,
    ;; 50% from ridge).  Per user request — was 75% from eave previously.
    (setq midLX (+ leftCol  (* halfL 0.5)))
    (setq midRX (- rightCol (* halfR 0.5)))
    ;; The tag is a right triangle that RISES from cy by `rise`.  Place
    ;; cx so that the tag is visually centred at midLX/midRX, and place
    ;; cy at sheeting_top_at_cx + clearance so the BOTTOM of the tag
    ;; (the horizontal leg, at y=cy) sits clearly above the sheeting.
    ;;
    ;; Hypotenuse direction follows the rafter slope (per user request):
    ;;   LEFT  half-rafter slopes UP-RIGHT → upRight = +1
    ;;       (cx at LEFT of tag, hypotenuse from (cx,cy) UP-RIGHT to
    ;;        (cx+run, cy+rise) — both on a line parallel to the rafter)
    ;;       cx = midLX − run/2 to centre the tag at midLX
    ;;   RIGHT half-rafter slopes UP-LEFT  → upRight = -1
    ;;       (cx at RIGHT of tag, hypotenuse from (cx,cy) UP-LEFT to
    ;;        (cx-run, cy+rise))
    ;;       cx = midRX + run/2 to centre the tag at midRX
    ;; Clearance ABOVE the sheeting line (235 mm above rafter top).
    ;; Per user: "keep the slope notation just above sheeting always" —
    ;; 200·TS keeps the tag tucked right above the sheeting, well clear
    ;; of the roof-sheeting spec which lives 1500·TS above its target.
    (setq tagRun (* 900 *PEB-TEXT-SCALE*))
    (setq cxL (- midLX (/ tagRun 2.0)))
    (setq cyL (+ H (* rise (/ (- cxL leftCol)  halfL))
                  235.0
                  (* 300 *PEB-TEXT-SCALE*)))
    (setq cxR (+ midRX (/ tagRun 2.0)))
    (setq cyR (+ H (* rise (/ (- rightCol cxR) halfR))
                  235.0
                  (* 300 *PEB-TEXT-SCALE*)))
    (draw-slope-tag cxL cyL slopeD  1)
    (draw-slope-tag cxR cyR slopeD -1)
  ))                                  ; close (if not arched ...) wrapping

  ;; ── Member labels (proposal-level only) ──────────────────────
  ;; (RAFTER text now drawn between rafter lines via draw-rafter-label)
  (setvar "CLAYER" "TEXT")

  ;; ── Grid bubbles at every column base (sequential A, B, C…) ──
  ;; Grid bubble shares the SAME vertical line as the dim extension line,
  ;; so the dim arrow + grid tick + bubble form one continuous column.
  ;;   - Leftmost / rightmost: x = cx ∓ 235 (outer sheeting face).
  ;;   - Interior: x = cx (column centreline).
  ;;
  ;; Bubble Y must clear the overall-dim ft text.  Now that overall
  ;; dim is at -2200·DS (was -3500·DS), the ft text sits at ~-2560·DS.
  ;; Bubble centre = -3300·TS gives ~740·TS clearance below ft text +
  ;; ~380 bubble radius — fits cleanly without floating.
  (setq bubR (* 380 *PEB-TEXT-SCALE*))
  (setq bubY (- 0.0 (* 3300 *PEB-TEXT-SCALE*)))
  (setq i 0)
  (setq nCols (length cols))
  (foreach cx cols
    (cond
      ((= i 0)            (setq bubX (- cx 235.0)))   ; leftmost outer
      ((= i (1- nCols))   (setq bubX (+ cx 235.0)))   ; rightmost outer
      (T                  (setq bubX cx)))            ; interior
    (draw-grid-bubble bubX bubY bubR (chr (+ 65 i)))   ; A, B, C, ...
    ;; Connector tick - a single continuous vertical line from FFL all
    ;; the way down to the top of the bubble, passing through the dim
    ;; lines so the chain visually merges into one column.
    (setvar "CLAYER" "GRID")
    (command "LINE"
      (list bubX (- 0.0 (* 100 *PEB-TEXT-SCALE*)))
      (list bubX (+ bubY bubR)) "")
    (setq i (1+ i)))

  ;; ── Dimensions ───────────────────────────────────────────────
  ;; Vertical: short C.H. callout on right side.
  ;; Horizontal: half-spans + total at the bottom (matches MAIMAAR style).

  ;; ===== Vertical height dimensions on BOTH SIDES =====
  ;; Stacked progressively further out:
  ;;   1. Brick masonry height (closest)
  ;;   2. Clear height (under rafter at haunch)
  ;; (Eave height & Ridge height removed - clear height is sufficient)
  ;; Set DIM* sysvars to MAIMAAR look (no DIMSTYLE _Save — that was
  ;; what broke the drawing in earlier attempts).
  (peb-dim-set-vars)
  ;; ── RIGHT side height dims only (per user) ──
  ;; Inner dim (BRICK MASONRY) at dimX1.  Outer dim (CLEAR HEIGHT)
  ;; offset by peb-dim-text-spacing — auto-adjusts to 3 × scaled
  ;; DIMTXT so the two ROTATED 2-line dim texts always clear each
  ;; other regardless of drawing scale.
  (setq dimX1 (max (+ wid 800.0)  (+ wid (* 1000 *PEB-DIM-SCALE*))))
  (setq dimX2 (+ dimX1 (peb-dim-text-spacing "vertical")))
  ;; Drawn dims, then overridden to colour 0 (ByBlock = displays as
  ;; white in modelspace) via direct entity property since DIMCLR*
  ;; sysvars get reset inside peb-dim-height-stretch.
  (if (and brickH (> brickH 0))
    (progn
      (peb-dim-height-stretch wid dimX1 0.0 brickH "<>\\PBRICK MASONRY")
      (peb-recolor-last-dim 0)))                  ; ByBlock
  (peb-dim-height-stretch wid dimX2 0.0 (- H ht) "<>\\PCLEAR HEIGHT")
  (peb-recolor-last-dim 0)                        ; ByBlock

  ;; Width dimensions at the bottom — VLA path via peb-dim-h-stretch
  ;; (single grip-editable AcDbRotatedDimension; falls back to hand-
  ;; rolled dim-line-h if VLA unavailable so the drawing always renders).
  ;; Module chain dimensions:
  ;;   - INTERIOR modules: C/C (column centerline to column centerline)
  ;;   - END modules:      C/O (interior-col centerline → OUTER FACE of
  ;;                       wall sheeting, i.e., -235 on LEFT, wid+235 on RIGHT)
  ;; This keeps the sum of modules equal to widInput (Excel input value,
  ;; out-to-out of sheeting line).
  (if (> (length cols) 2)
    (progn
      (setq nCols (length cols))
      (setq i 1)
      (while (< i nCols)
        (setq prevCol (if (= i 1) -235.0          (nth (1- i) cols)))
        (setq curCol  (if (= i (1- nCols)) (+ wid 235.0) (nth i cols)))
        (setq modw    (- curCol prevCol))
        ;; VLA path — no override means measured value with DIMALT.
        ;; Falls back to dim-line-h with mm|ft format if VLA fails.
        (peb-dim-h-stretch prevCol curCol
                           (- 0.0 (* 1500 *PEB-DIM-SCALE*))
                           nil)
        (peb-recolor-last-dim 0)              ; ByBlock for module dims
        (setq i (1+ i)))))
  ;; Overall width dimension OUT-TO-OUT OF SHEETING LINE.
  ;; "<>" substitutes measured value at render — stretch updates the
  ;; "75000" while keeping the "0/0 OF SHEETING LINE" suffix as-is.
  ;; Y position auto-adjusted: module dim at -1500·DS, overall dim
  ;; offset BELOW that by peb-dim-text-spacing (auto-scales with
  ;; DIMTXT × DIMSCALE so dim texts always have a visible gap).
  (peb-dim-h-stretch -235.0 (+ wid 235.0)
                     (- 0.0
                        (if (> (length cols) 2)
                          (+ (* 1500 *PEB-DIM-SCALE*) (peb-dim-text-spacing "horizontal"))
                          (* 1500 *PEB-DIM-SCALE*)))
                     "<>\\P0/0 OF SHEETING LINE")
  (peb-recolor-last-dim 0)                    ; ByBlock for overall width dim

  ;; ── Title (frame type prominently displayed for review) ─────
  (setvar "CLAYER" "TEXT")
  ;; Top line: frame type (e.g. CLEAR SPAN GABLE / MULTI-GABLE / SINGLE SLOPE)
  (txt-bold "MC"
            (list (/ wid 2.0) (+ H rise (* 6300 *PEB-TEXT-SCALE*)))
            500 0
            (peb-structure-label stype))
  ;; Second line: generic "BUILDING CROSS-SECTION"
  (txt-bold "MC"
            (list (/ wid 2.0) (+ H rise (* 5500 *PEB-TEXT-SCALE*)))
            350 0
            "BUILDING CROSS-SECTION")
  ;; Underline beneath title
  (setvar "CLAYER" "TEXT")
  (command "LINE"
    (list (- (/ wid 2.0) (* 6000 *PEB-TEXT-SCALE*))
          (+ H rise (* 5100 *PEB-TEXT-SCALE*)))
    (list (+ (/ wid 2.0) (* 6000 *PEB-TEXT-SCALE*))
          (+ H rise (* 5100 *PEB-TEXT-SCALE*))) "")
  ;; Subtitle: short summary line - use widInput (out-to-out of sheeting,
  ;; matches the dimension shown at the bottom of the section).
  (txt "MC"
       (list (/ wid 2.0) (+ H rise (* 4400 *PEB-TEXT-SCALE*)))
       200 0
       (strcat (rtos (/ widInput 1000.0) 2 1) "m SPAN  |  "
               "C.H " (rtos (/ (- H ht) 1000.0) 2 1) "m  |  "
               "RIDGE " (rtos (/ (+ H rise) 1000.0) 2 1) "m  |  "
               "SLOPE " slopeStr))

  ;; ── Title block (auto-widens for narrow buildings, scales uniformly for big) ──
  ;; Min: 35 m so small buildings still get readable cells.
  ;; Max: 80 m so a 150 m section doesn't push tbScale past ~2.3, which
  ;;      keeps the title block height (4800·tbScale) under ~11 m.
  ;; The title block is centred under the section.  Inside the block we
  ;; SCALE all internal Y offsets and text heights by tbScale (= tbW /
  ;; 35 000) so the block stretches BOTH horizontally and vertically
  ;; with width — text grows in proportion, cells grow in proportion.
  (setq tbW     (max 35000.0 (min wid 80000.0)))
  (setq tbScale (/ tbW 35000.0))
  (setq tbXShift (/ (- tbW wid) 2.0))     ; how far the TB extends past the building
  (setq c0 (- 0.0 tbXShift)
        c1 (+ c0 (* tbW 0.14))
        c2 (+ c0 (* tbW 0.30))
        c3 (+ c0 (* tbW 0.45))
        c4 (+ c0 (* tbW 0.62))
        c5 (+ c0 (* tbW 0.85))
        c6 (+ c0 tbW))
  ;; Title-block Y must clear EVERYTHING above it:
  ;;   - Module dims at  Y = -1500 * DIM_SCALE
  ;;   - Overall dim at  Y = -3500 * DIM_SCALE  (when interior cols)
  ;;   - Overall ft text at Y = -3860 * DIM_SCALE
  ;;   - Grid bubbles at Y = -5000 * TEXT_SCALE  (bottom = -5380 * TS)
  ;; Compute tbTop from the deepest element + margin.  tbBot scales
  ;; with tbScale so the title block height grows in proportion to its
  ;; width.  tbShift kept as a back-compat alias (= tbTop − -5200) but
  ;; the canonical transformer is now (tbY Y_legacy).
  (setq tbTop (min -5200.0
                   (- 0.0 (* 6500.0 *PEB-TEXT-SCALE*))
                   (- 0.0 (* 4500.0 *PEB-DIM-SCALE*))))
  (setq tbBot   (- tbTop (* 4800.0 tbScale)))
  (setq tbShift (- tbTop -5200.0))

  ;; Force the global text scale to a FIXED 1.0 inside the title block.
  ;; Title block has fixed cell widths (% of tbW) and fixed row Y positions,
  ;; so its text size needs to be consistent regardless of how big the
  ;; section drawing scaled.  Saved scale is restored AFTER the title block.
  (setq *PEB-OLD-TEXT-SCALE* *PEB-TEXT-SCALE*)
  (setq *PEB-OLD-DIM-SCALE*  *PEB-DIM-SCALE*)
  ;; Inside the title block, text + dim scale = tbScale, so all the
  ;; fixed text heights (140, 180, 200, 300) grow proportionally with
  ;; the title-block width.  Combined with row offsets being scaled
  ;; by tbY(), this gives a uniformly scaled title block.
  (setq *PEB-TEXT-SCALE* tbScale)
  (setq *PEB-DIM-SCALE*  tbScale)

  ;; ── Title block as ONE AcDbTable entity ─────────────────────────
  ;; Per user: AcDbTable must STRETCH end-to-end with the drawing
  ;; border, and its BOTTOM line must overlap the border bottom.
  ;; Compute border edges FIRST, then size the table to fit
  ;; borderL..borderR horizontally and tbTop..borderB vertically.
  (setq borderL (min (- (* 6000 *PEB-DIM-SCALE*))
                     (- c0 (* 800 *PEB-TEXT-SCALE*))))
  (setq borderR (max (+ wid (* 6000 *PEB-DIM-SCALE*))
                     (+ c6 (* 800 *PEB-TEXT-SCALE*))))
  (setq borderB (- tbBot (* 1200 *PEB-TEXT-SCALE*)))
  (setq borderT (+ H rise (* 6500 *PEB-TEXT-SCALE*)))
  ;; Table dimensions:
  ;;   horizontal: borderL → borderR (full drawing width)
  ;;   vertical:   header height + 7 × body row height (autofit)
  ;;
  ;;  AUTOFIT: each body row sized to fit ONE line of project-info
  ;;  text (text height + small padding).  This keeps the project-info
  ;;  cells tight vertically per user request.  Merged cells (in non-
  ;;  project columns) get all 7 rows' worth of total height — plenty
  ;;  for their 6-8 lines of multi-line content.
  ;;
  ;;  After table size is fixed, snap borderB up to coincide with the
  ;;  computed table bottom so the table sits flush against the border.
  ;; Heights HALVED per user — total table now ~half its previous
  ;; vertical span.  Text height halved to match so it still fits.
  ;; (The old AcDbTable string-building / column-width / merge machinery
  ;;  was removed here — the Mammut vertical right-strip below now renders
  ;;  the title block, IF-linked, matching the Column Layout Plan.)
  ;; ============================================================
  ;; MAMMUT-STYLE VERTICAL TITLE PANEL ON THE RIGHT
  ;; (replaces the old bottom AcDbTable, for parity with the Column
  ;;  Layout Plan).  The section stays on the left; the strip is a tall
  ;;  panel on the right edge running the full drawing height.  Every
  ;;  field value links DIRECTLY to the IF; the REAL Maimaar logo is
  ;;  -INSERTed by peb-tb-place-logo inside the contractor cell.
  ;; ============================================================
  ;; Use the NATURAL drawing scales (not the title-table override) so the
  ;; strip geometry sits correctly relative to the frame.
  (setq *PEB-TEXT-SCALE* *PEB-OLD-TEXT-SCALE*)
  (setq *PEB-DIM-SCALE*  *PEB-OLD-DIM-SCALE*)
  (setvar "CLAYER" "TEXT")
  (setq tbFrmB tbTop)                                   ; deepest point below the frame
  (setq tbFrmT (+ H rise (* 6800.0 *PEB-TEXT-SCALE*)))  ; above the section heading
  (setq tbBldgR (+ wid (* 6000.0 *PEB-DIM-SCALE*)))     ; right of the frame + dims
  (setq tbStripH (- tbFrmT tbFrmB))
  (setq tbStripW (max (* wid 0.26)                      ; not too thin
                      (min (* tbStripH 0.46)            ; Mammut-ish aspect
                           (* wid 0.55))))              ; not too dominant
  (setq tbStripX (+ tbBldgR (* 1800.0 *PEB-DIM-SCALE*)))
  ;; --- field values, linked DIRECTLY to the IF -----------------------
  (setq tbQuote (MSPL-Get-Str data "PROPOSAL_FULL"))
  (if (= tbQuote "")
    (cond
      ((and (= (strlen propinput) 5) (wcmatch propinput "#####"))
       (setq tbQuote (strcat "MSPL-" (substr propinput 1 2) "-" (substr propinput 3))))
      (T (setq tbQuote propno))))
  (setq tbBno bldgno)
  (if (= (strlen tbBno) 1) (setq tbBno (strcat "0" tbBno)))
  (setq tbDrn (MSPL-Get-Str data "TBDRN"))  (if (= tbDrn "") (setq tbDrn "M.H"))
  (setq tbChk (MSPL-Get-Str data "TBCHK"))  (if (= tbChk "") (setq tbChk "YEA"))
  (setq tbBname (MSPL-Get-Str data "TBBLDGNAME"))
  (setq tbDate (MSPL-Get-Str data "TBDATE"))
  (if (= tbDate "") (setq tbDate fulldate) (setq tbDate (peb-pretty-date tbDate)))
  (setq tbData
    (list
      (cons "REV"  (if (= revno "0") "00" revno))
      (cons "DATE" tbDate)
      (cons "DRN"  tbDrn) (cons "CHK" tbChk)
      ;; design loads + code linked DIRECTLY to the IF (blank -> default)
      (cons "LL_ROOF"  (peb-tb-or (MSPL-Get-Str data "LIVEROOF")  "0.57"))
      (cons "LL_FRAME" (peb-tb-or (MSPL-Get-Str data "LIVEFRAME") "0.57"))
      (cons "WIND"     (if (= windspeed "") "AS PER CODE" (peb-num-only windspeed)))
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
      (cons "IDENTICAL" "ONE")
      (cons "DRGTITLE"  "CROSS SECTION")
      (cons "SCALE"     "N.T.S.")
      (cons "SHEETSIZE" "A1")
      (cons "SHEETNO"   (strcat "PRO-" tbBno))))
  (peb-titleblock-mammut tbStripX tbFrmB tbStripW tbStripH tbData)
  ;; Drawing border wraps the section + the title strip.
  (setq borderL (- (* 6000.0 *PEB-DIM-SCALE*))
        borderB tbFrmB
        borderR (+ tbStripX tbStripW (* 1000.0 *PEB-DIM-SCALE*))
        borderT tbFrmT)

  ;; Restore drawing scales (title block done)
  (setq *PEB-TEXT-SCALE* *PEB-OLD-TEXT-SCALE*)
  (setq *PEB-DIM-SCALE*  *PEB-OLD-DIM-SCALE*)

  ;; Drawing border — borderL/B/R/T already computed above (before
  ;; the table) so the table sits flush against them.  Just draw
  ;; the rectangle here.
  (draw-border borderL borderB borderR borderT)

  ;; (Y-axis right-shift removed for the same hang reason as above.
  ;;  Drawing stays at its native coordinates with borderL slightly
  ;;  negative for the dim grid extension.)

  (command "UNDO" "END")
  (setvar "GRIDMODE" 0)
  (setvar "SNAPMODE" 0)
  (setvar "CMDECHO" 1)
  ;; Force regen so all entities show, then zoom to extents.
  (command "_REGEN")
  (command "_ZOOM" "_E")

  (princ
    (strcat "\nMAIMAAR PEB SECTION V40 COMPLETE  |  "
            (rtos (/ widInput 1000.0) 2 1) "m span  |  "
            (rtos (/ H        1000.0) 2 1) "m eave  |  "
            "SLOPE " slopeStr "  |  "
            (peb-structure-label stype)))
  (princ)
)

;; ============================================================================
;; NON-INTERACTIVE ENTRY (used by Excel VBA Generate-Drawings auto-launch)
;; ============================================================================
;; -- Tiling helper: shift newly drawn entities to the right of any
;; existing drawing with a gap, so successive Generate-Drawings calls
;; place each drawing side-by-side instead of on top of each other.
(defun peb-tile-gap () 5000.0)   ;; 5 m gap between tiled drawings

(defun peb-section-from-file (path / prev-last prev-max-x e new-set offset)
  ;; ── Pre-draw: capture state of the drawing before our entities ──
  (setq prev-last (entlast))           ;; nil if drawing is empty
  (if prev-last
    (progn
      (command "_.REGEN")              ;; ensure EXTMAX reflects reality
      (setq prev-max-x (car (getvar "EXTMAX")))
      ;; AutoCAD uses -1e20 as the "no extents" sentinel
      (if (or (null prev-max-x) (< prev-max-x -1e10))
        (setq prev-max-x nil)))
    (setq prev-max-x nil))

  ;; ── Draw the section in V40's coordinate system ──
  (setq *PEB-DATA-FILE* path)
  (princ (strcat "\nPEB-SECTION using data file: " path))
  (C:PEB-SECTION)
  (setq *PEB-DATA-FILE* nil)

  ;; ── Post-draw: if there was previous content, tile the new entities
  ;; to the right of the rightmost existing X ──
  (if prev-max-x
    (progn
      (setq new-set (ssadd))
      (setq e prev-last)
      (while (setq e (entnext e))
        (ssadd e new-set))
      (if (> (sslength new-set) 0)
        (progn
          (setq offset (+ prev-max-x (peb-tile-gap)))
          (command "_.MOVE" new-set "" "0,0,0"
                   (list offset 0.0 0.0))
          (princ (strcat "\nTiled new drawing at X = "
                         (rtos offset 2 0) " mm"))
          (command "_.ZOOM" "_E")))))

  (princ))

;; ============================================================================
;; PEB-PDF — one-click window plot to PDF
;; (mirrors the helper in MAIMAAR_PEB_Plan.lsp so user can run it from
;; either Section or Plan context)
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

  (setq ts (rtos (getvar "CDATE") 2 0))
  (setq dwgPath (getvar "DWGPREFIX"))
  (setq dwgBase
    (if (= (getvar "DWGNAME") "Drawing1.dwg")
      "Maimaar_PEB"
      (vl-filename-base (getvar "DWGNAME"))))
  (setq pdfPath (strcat dwgPath dwgBase "_" ts ".pdf"))
  (princ (strcat "\n  → " pdfPath "\n"))

  (setvar "CMDECHO" 0)
  (setvar "BACKGROUNDPLOT" 0)
  (vl-catch-all-apply
    (function (lambda ()
      (command "_-PLOT"
        "_Yes"
        ""
        "DWG To PDF.pc3"
        "ISO A3 (420.00 x 297.00 MM)"
        "_Millimeters"
        "_Landscape"
        "_No"
        "_Window"
        p1
        p2
        "_Fit"
        "_Center"
        "_Yes"
        "monochrome.ctb"
        "_Yes"
        ""
        pdfPath
        "_No"
        "_Yes"))))
  (setvar "CMDECHO" 1)
  (princ (strcat "\nPDF saved → " pdfPath "\n"))
  (princ))

(princ "\nMAIMAAR PEB-SECTION (Phase-2 standalone) loaded. Command: PEB-SECTION")
(princ "\nPDF helper: type PEB-PDF then pick window corners.\n")
(princ)
