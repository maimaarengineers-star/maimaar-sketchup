; ============================================================================
; MAIMAAR STEEL Pvt. Ltd.
; PEB Phase-2  --  Cross-Section Drawing  (standalone)
; Command: PEB-SECTION
;
; ****************************************************************************
; ***  UNIVERSAL / STANDING RULES (owner) — ALL SECTIONS MUST FOLLOW  *******
; ****************************************************************************
;  0. PURLINS & SHEETING always follow the FRAME's exact rafter roofline
;     (up each ridge / down each valley / per-gable slope) — never a flat line.
;  1. CP (Connection Plates) — every bolted connection = TWO filled-SOLID plates,
;     *PEB-CP-THK*=30 mm thick, *PEB-CP-GAP*=1.5 mm seam, NO bolt donuts, each
;     extended *PEB-CP-EXT*=100 mm past BOTH flanges (plate len >= web + 200).
;  2. GP (Gusset Plates) — SMALL solid stiffener triangle tying the CP to the
;     flange (column & rafter), at BOTH flanges, its flange leg on the flange
;     SLOPE. Purpose: strengthen the CP<->flange joint.  (draw-rc-gusset / inline)
;  3. Canopy/Valley connections are SIDE-mounted (rafter to column SIDE, not top).
;  4. DIMENSIONS: text style = ROMAND (romand.shx); arrowheads = OPEN type.
;  5. ALL TEXT = ROMAND everywhere (labels/M-ladders/notes/titles); title-block
;     company name stays bold.
;  6. G1 — NO gutter and NO "GUTTER" text on the OPEN/FREE cantilever edge.
;  7. G2 — DOWNPIPES at valley & cantilever = DOTTED (PEBPIPE linetype).
;  8. G3 — every GUTTER lip sits just BELOW the roof sheeting line.
;  9. P1 — a PURLIN at each eave + directly under every gutter (eave & valley);
;     interior purlins BALANCE-spaced at 1.25-1.50 m.
;  (Keep adding new owner standing rules to THIS block as they are established.)
; ****************************************************************************
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
;
; ============================================================================
; STANDING DRAWING RULES (owner — apply to ALL section drawings, always)
;   1. TITLE BLOCK must be FLUSH with the sheet double-lines on TOP, BOTTOM and
;      RIGHT for every drawing, whatever the size; General Notes top-aligned.
;   2. CONNECTION-PLATE GUSSETS (stiffeners) must be FILLED SOLID and must NOT
;      extend BEYOND the 100 mm extension of the connection plates (they stay
;      within the plate end lines).  See draw-rc-gusset.
;   3. CONNECTION PLATES on a rafter always EXTEND 100 mm BEYOND the TOP flange
;      AND 100 mm BEYOND the BOTTOM flange (ext = 100 in draw-rc-ridge/splice).
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
;;   "1@25000 | 2@25000 | 3@25000"  ( | = valley between gables ; = per-gable overrides )
;; into a LIST OF GABLES, each a list of its sub-module span widths (mm).  Returns nil for a
;; blank string or one with no "|" (caller then uses the legacy NUMGABLES/SPANSPERGABLE path).
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

;; peb-mg-grid — the multi-gable gable structure as a list of gables (each a list of sub-span
;; widths): PREFER the canonical BP_FRAME_GRID (Tier 0 — unequal gables, per-gable sub-modules);
;; else synthesise the legacy equal-gable grid from NUMGABLES x SPANSPERGABLE so existing MGs are
;; unchanged.  Shared by compute-section-layout (positions/dims) and draw-mg-multi-frame (frame).
(defun peb-mg-grid (data W / g gw numGab spanPerGab mws i j mgSub)
  (setq g (peb-parse-frame-grid (MSPL-Get-Str data "BP_FRAME_GRID")))
  (if g g
    (progn
      (setq spanPerGab (MSPL-Get-Int data "SPANSPERGABLE"))
      (if (or (null spanPerGab) (< spanPerGab 1)) (setq spanPerGab 1))
      ;; Legacy gable WIDTHS from the width modules (each module = a gable, UNEQUAL) — matches the
      ;; plan (owner decision T1.2: Section MG follows the modules, not an equal split).  Fall back
      ;; to an equal NUMGABLES split only when the IF gives no usable module string.
      (setq mws (peb-width-order (peb-parse-mod-expression (MSPL-Get-Str data "MODEXPR"))))   ; rule 4B.34 — width chain, written A downward
      (if (not (and mws (> (length mws) 1)))
        (progn
          (setq numGab (MSPL-Get-Int data "NUMGABLES"))
          (if (or (null numGab) (< numGab 1)) (setq numGab 2))
          (setq mws '() i 0)
          (while (< i numGab) (setq mws (append mws (list (/ W (float numGab)))) i (1+ i)))))
      ;; each gable width -> spanPerGab equal sub-modules (interior columns per gable)
      (setq g '())
      (foreach gw mws
        (setq mgSub '() j 0)
        (while (< j spanPerGab) (setq mgSub (append mgSub (list (/ gw (float spanPerGab)))) j (1+ j)))
        (setq g (append g (list mgSub))))
      g)))

;; ----------------------------------------------------------------------------
;;  SHEETING / INSULATION build-up composer
;; ----------------------------------------------------------------------------
;;  peb-panel-digits — pull the leading numeric run (int or decimal) out of a
;;  free-form field, dropping any unit suffix.  "50mm" -> "50" , "38 kg/m3" ->
;;  "38" , "0.50 mm" -> "0.50".  Leading spaces are skipped; scanning stops at
;;  the first non-numeric char AFTER a digit has been seen.
(defun peb-panel-digits (s / i n ch out started stop)
  (setq s (if s s "") out "" i 1 n (strlen s) started nil stop nil)
  (while (and (<= i n) (not stop))
    (setq ch (substr s i 1))
    (cond
      ((or (and (>= (ascii ch) 48) (<= (ascii ch) 57)) (= ch "."))
        (setq out (strcat out ch) started T))
      (started (setq stop T)))
    (setq i (1+ i)))
  out)

;;  peb-panel-clean-mat — a skin material/thickness string as authored in the
;;  IF (e.g. "0.50 mm AZ150").  Blank -> the standard default "0.50mm AZ 150"
;;  so a callout never prints an empty skin.  (Exact spacing of a NON-blank
;;  value is whatever the estimator typed in the CRM Panel field — one truth
;;  from the IF; we only trim it.)
(defun peb-panel-clean-mat (s)
  (setq s (vl-string-trim " " (if s s "")))
  (if (= s "") "0.50mm AZ 150" s))

;;  peb-panel-label — compose the FULL sheeting sandwich for KEY = "ROOF" or
;;  "WALL":   outer  [+ " + " core]  [+ " + " inner ("(Liner)" if a liner skin)]
;;
;;    "0.50mm AZ 150 + 50 PIR Core Density 38kg/m3 + 0.50mm AZ 150"  (PIR sandwich)
;;    "0.50mm AZ 150 + 50mm Fiberglass Insulation"                   (fibre, no liner)
;;    "0.50mm AZ 150 + 50mm Fiberglass + 0.50mm AZ 150 (Liner)"      (fibre + liner)
;;
;;  Reads the v3 PN_<KEY>_* keys (same fields the CRM's pushPanel emits); the
;;  sheet THICKNESS is embedded in PN_<KEY>_OUTER_MAT ("0.50 mm AZ150").  Empty
;;  parts are omitted gracefully; blank skin -> standard 0.50mm AZ 150.
;;  peb-finish-code — the pre-paint/coating code shown after a skin material,
;;  derived from the coating in the material string + the finish field:
;;    Galvalume (AZ) painted -> "(PPGL)"   unpainted -> "(GL)"
;;    Galvanized (GI / Z)     -> "(PPGI)"  unpainted -> "(GI)"
;;  Owner 13-Jul: sheeting skins read e.g. "0.50mm AZ 150 (PPGL)".
(defun peb-finish-code (mat finish / m f painted)
  (setq m (strcase (if mat mat "")) f (strcase (if finish finish "")))
  ;; owner 29-Jul: if the material string ALREADY carries a coating code (e.g. "0.50 mm AZ150 PPGL"), don't
  ;; append another → was rendering "...PPGL (PPGL)".
  (if (or (wcmatch m "*PPGL*") (wcmatch m "*PPGI*") (wcmatch m "*(GL)*") (wcmatch m "*(GI)*")
          (wcmatch m "* GL") (wcmatch m "* GI"))
    ""
    (progn
      (setq painted (or (wcmatch f "*PAINT*") (wcmatch f "*PPG*")
                        (wcmatch f "*POLYESTER*") (wcmatch f "*PVDF*")))
      (cond
        ((wcmatch m "*AZ*")               (if painted " (PPGL)" " (GL)"))   ; Aluzinc / galvalume
        ((wcmatch m "*GALVALUME*")        (if painted " (PPGL)" " (GL)"))
        ((or (wcmatch m "*GI*") (wcmatch m "*GALVANI*")) (if painted " (PPGI)" " (GI)"))
        (T "")))))

;;  peb-profile-name — the sheeting PROFILE suffix shown after the outer skin, from
;;  PN_<KEY>_OUTER_PROFILE (BS).  Owner 14-Jul: ALWAYS show the profile (they run BOTH S-Type and
;;  Seam-Lock, so the label must say which).  The house-standard trapezoidal profile IS the S-Type, so
;;  Standard/Trapezoidal/blank map to ", S-Type"; the standing-seam maps to ", Seam-Lock".  Label reads
;;  e.g. "0.50mm AZ 150 (PPGL), S-Type" or "..., Seam-Lock".
(defun peb-profile-name (prof / p)
  (setq p (strcase (vl-string-trim " " (if prof prof ""))))
  (cond
    ((or (wcmatch p "*LOCK*SEAM*") (wcmatch p "*LOCKSEAM*")
         (wcmatch p "*SEAM*LOCK*") (wcmatch p "*STANDING*SEAM*")) " (Seam-Lock)")
    ((or (wcmatch p "*MICRO*") (wcmatch p "*M-RIB*") (= p "MR")) " (Micro-Ribbed)")
    ((or (= p "") (wcmatch p "*STANDARD*") (wcmatch p "*TRAPEZ*")
         (wcmatch p "*S-TYPE*") (wcmatch p "*S TYPE*") (wcmatch p "*STYPE*")) " (S-Type)")
    (T (strcat " (" (vl-string-trim " " prof) ")")))) ; any other named profile carried verbatim, in parens

;;  peb-panel-label — compose the FULL sheeting sandwich for KEY = "ROOF"/"WALL".
;;  Owner 13-Jul spec, sourced from the BS:
;;    single skin           : "0.50mm AZ 150 (PPGL)"
;;    + insulation          : "... + 50mm Fiberglass Insulation (12kg/m3)"
;;    + insulation + liner  : "... + ... + 0.50mm AZ 150 (PPGL) Liner"
;;    SANDWICH PANEL        : "0.50mm AZ 150 + 50mm PIR Core (38kg/m3 Density) + 0.50mm AZ 150 (PPGL)"
;;  IMPORTANT: for a SINGLE-SKIN panel the insulation is read from the roof/wall
;;  ACCESSORIES (PN_<KEY>_INSUL_*), NOT the panel description; the PIR core is read
;;  from the panel only for a SANDWICH.  Density is always shown when present.
(defun peb-panel-label (data key / typ outMat outFin outProf innerProf insThk insType insDens
                                    pirThk pirDens pirType innerMat linerMat
                                    outer core inner coreU isSandwich isLiner finOut profOut lbl addOn)
  (setq typ      (peb-alist-get data (strcat "PN_" key "_TYPE")))
  (setq outMat   (peb-alist-get data (strcat "PN_" key "_OUTER_MAT")))
  (setq outFin   (peb-alist-get data (strcat "PN_" key "_OUTER_FINISH")))
  (setq outProf  (peb-alist-get data (strcat "PN_" key "_OUTER_PROFILE")))
  (setq pirThk   (peb-alist-get data (strcat "PN_" key "_PIR_THK")))
  (setq pirDens  (peb-alist-get data (strcat "PN_" key "_PIR_DENS")))
  (setq pirType  (peb-alist-get data (strcat "PN_" key "_PIR_TYPE")))
  (setq innerMat (peb-alist-get data (strcat "PN_" key "_INNER_MAT")))
  (setq innerProf (peb-alist-get data (strcat "PN_" key "_INNER_PROFILE")))
  (setq linerMat (peb-alist-get data "PN_LINER_OUTER_MAT"))
  ;; INSULATION from the ACCESSORIES (single-skin case), not the panel description.
  (setq insThk  (peb-panel-digits (peb-alist-get data (strcat "PN_" key "_INSUL_THK"))))
  (setq insType (peb-alist-get data (strcat "PN_" key "_INSUL_TYPE")))
  (setq insDens (peb-panel-digits (peb-alist-get data (strcat "PN_" key "_INSUL_DENS"))))
  (setq isSandwich (or (= (strcase typ) "SANDWICH PANEL") (= (strcase typ) "SANDWICH")))
  (setq finOut (peb-finish-code outMat outFin))
  (setq profOut (peb-profile-name outProf))
  ;; --- OUTER skin: material + finish code (PPGL) + profile (S-Type) in parens (owner 14-Jul: the outer
  ;;     skin always shows its finish AND profile, e.g. "0.50mm AZ150 (PPGL) (S-Type)") ---
  (setq outer (strcat (peb-panel-clean-mat outMat) finOut profOut))
  ;; --- CORE / INSULATION ---
  (cond
    ;; SANDWICH: core from the PANEL (PIR / EPS / named), with density
    (isSandwich
      (setq coreU (strcase (if pirType pirType "")))
      (setq core
        (strcat (if (= (peb-panel-digits pirThk) "") "50" (peb-panel-digits pirThk)) "mm "
                (cond ((or (= coreU "") (wcmatch coreU "*PIR*")) "PIR")
                      ((wcmatch coreU "*EPS*") "EPS")
                      ((or (wcmatch coreU "*ROCK*") (wcmatch coreU "*MINERAL*")) "Rock Wool")
                      (T (vl-string-trim " " pirType)))
                " Core"
                ;; owner 14-Jul: kg/m3 IS the density — plain " NN kg/m3", no "Density" word / parens
                (if (/= (peb-panel-digits pirDens) "")
                  (strcat " " (peb-panel-digits pirDens) " kg/m3") ""))))
    ;; SINGLE SKIN + accessory insulation
    ((/= insThk "")
      (setq coreU (strcase (if insType insType "")))
      (setq core
        (strcat insThk "mm "
                (cond ((or (wcmatch coreU "*FIBER*") (wcmatch coreU "*FIBRE*")
                           (wcmatch coreU "*GLASS*")) "Fiberglass")
                      ((or (wcmatch coreU "*ROCK*") (wcmatch coreU "*MINERAL*")) "Rock Wool")
                      ((= coreU "") "Fiberglass")
                      (T (vl-string-trim " " insType)))
                " Insulation"
                (if (/= insDens "") (strcat " (" insDens "kg/m3)") ""))))
    (T (setq core "")))
  ;; --- INNER skin / LINER ---
  (setq isLiner nil)
  (cond
    ;; sandwich: inner skin = material + its PROFILE (owner 14-Jul: the liner is Micro-Ribbed / MR by
    ;; default), e.g. "0.50mm AZ150 (Micro-Ribbed)".  Profile from PN_<key>_INNER_PROFILE; blank -> Micro-Ribbed.
    (isSandwich
      (setq inner (strcat (peb-panel-clean-mat innerMat)
                          (peb-profile-name
                            (if (= (vl-string-trim " " (if innerProf innerProf "")) "")
                              "Micro-Ribbed" innerProf)))))
    ;; single skin + an authored inner sheet => liner.  Show the liner's OWN profile too when it is
    ;; explicitly set (owner 14-Jul: "both sides S-Profile") — e.g. "0.50mm AZ150 (PPGL) (S-Type) Liner";
    ;; a blank inner profile keeps the plain liner (no default suffix) so flat liners stay clean.
    ((/= (vl-string-trim " " innerMat) "")
      (setq inner (strcat (peb-panel-clean-mat innerMat) finOut
                          (if (/= (vl-string-trim " " (if innerProf innerProf "")) "")
                            (peb-profile-name innerProf) ""))
            isLiner T))
    ;; single skin + a standalone liner panel (PN_LINER_*), gated on coverage.  PN_LINER_OUTER_MAT
    ;; carries a DEFAULT even when no liner is wanted, so a liner is present only if
    ;; LN_<key>_COVERAGE is set and not "Not Required".
    ((and (/= (vl-string-trim " " linerMat) "")
          (/= (strcase (vl-string-trim " " (peb-alist-get data (strcat "LN_" key "_COVERAGE")))) "")
          (/= (strcase (vl-string-trim " " (peb-alist-get data (strcat "LN_" key "_COVERAGE")))) "NOT REQUIRED"))
      (setq inner (strcat (peb-panel-clean-mat linerMat) finOut) isLiner T))
    (T (setq inner "")))
  ;; --- COMPOSE: outer [+ core] [+ inner (Liner? Add-on?)] ---
  ;; A liner on an OP1-OP10 sales code is quoted SEPARATELY from the base price (LN_<key>_ADDON),
  ;; so the drawing says so: without it the customer reads a lined roof on the sheet and a base
  ;; price that does not include it.  Tagged on the ITEM, never on the sheet - a bare "(OPTIONAL)"
  ;; floating on a drawing reads as though the BUILDING were optional (owner 31-Aug).
  ;; This is the one place both the SECTION and the PLAN compose a panel label, so the tag reaches
  ;; both sheets from here.  Blank/"No" on every existing job, so those drawings do not move.
  (setq lbl outer)
  (if (/= core "")  (setq lbl (strcat lbl " + " core)))
  (setq addOn (= (strcase (vl-string-trim " " (peb-alist-get data (strcat "LN_" key "_ADDON")))) "YES"))
  (if (/= inner "")
    (setq lbl (strcat lbl " + " inner
                      (if isLiner " Liner" "")
                      (if (and isLiner addOn) " (ADD-ON)" ""))))
  lbl)

;;  Legacy entry point kept for the drawing code: heading + full build-up.
;;  Two spaces (no colon) before the spec so split-at-first-digit yields a
;;  clean "ROOF SHEETING" / "WALL SHEETING" heading (the label routine adds
;;  the ":") and a spec that begins with the outer-skin thickness digit.
(defun peb-build-sheeting-string (data prefix / typ outProf outMat pirThk lbl)
  ;; owner 6-Jul: FULL sheeting+insulation build-up label (shared with the Plan). Single-source canonical
  ;; (Plan == Section, enforced by check_pd_sync C5): peb-panel-label lives in the Section engine; call it
  ;; ONLY when it is a real function AND returns a non-empty string, else fall back to a digit-bearing
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

;;  peb-arch-sheeting-labels — ROOF + WALL SHEETING callouts for sections that draw their own
;;  cladding and so bypass draw-cladding's built-in labels (currently the ARCHED types ACS/AMS).
;;  Same MLEADER format as the gable path: bold heading + (<=2-line) build-up spec, white text so it
;;  plots black.  Placed top-right (roof) and top-left (wall) with L-leaders, like the gable labels.
(defun peb-arch-sheeting-labels (data W H rise / rspec wspec rc wc rx ry topY wTgtY wExtX)
  ;; owner 14-Jul: LT/arch sheeting labels must READ THE SAME AS CLEAR SPAN — both ROOF & WALL labels on a
  ;; common TOP band, each on a CS-style M-Ladder (4-leg: arrow → leg → bar → text) with a SMALL arrowhead.
  (setvar "CLAYER" "TEXT")
  (setq rspec (peb-split-2-lines (peb-panel-label data "ROOF")))
  (setq wspec (peb-split-2-lines (peb-panel-label data "WALL")))
  (setq rc (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;ROOFING SYSTEM:}\\P" rspec "}"))
  (setq wc (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;WALL SHEETING:}\\P" wspec "}"))
  (setq topY (+ H rise (* 3800 *PEB-TEXT-SCALE*)))      ; common top band (same level for both), like CS
  ;; ROOF: arrow tip on the roof at ~68% span, leg up to the top band, then a 300 bar to the text.
  (setq rx (* W 0.68) ry (+ H (* rise 0.82) 235.0))
  (vl-catch-all-apply 'peb-make-mleader
    (list (list (list rx ry) (list rx topY) (list (+ rx 300.0) topY)) rc))
  (setvar "CLAYER" "ARROWS") (setvar "PLINEWID" 0.0)
  (command "LINE" (list rx topY) (list rx (+ ry (* 160 *PEB-TEXT-SCALE*))) "")
  (command "PLINE" (list rx (+ ry (* 160 *PEB-TEXT-SCALE*))) "W" (* 55 *PEB-TEXT-SCALE*) 0 (list rx ry) "")
  (setvar "PLINEWID" 0.0)
  ;; WALL: arrow tip on the LEFT wall, 4-leg L-leader out & up to the SAME top band (identical to CS).
  (setq wTgtY (- H 300.0) wExtX -1735.0)
  (setvar "CLAYER" "TEXT")
  (vl-catch-all-apply 'peb-make-mleader
    (list (list (list -235.0 wTgtY) (list wExtX wTgtY) (list wExtX topY) (list (+ wExtX 300.0) topY)) wc))
  (setvar "CLAYER" "ARROWS") (setvar "PLINEWID" 0.0)
  (command "PLINE" (list (- -235.0 (* 160 *PEB-TEXT-SCALE*)) wTgtY) "W" (* 55 *PEB-TEXT-SCALE*) 0 (list -235.0 wTgtY) "")
  (setvar "PLINEWID" 0.0))

;;  peb-arch-wall-sheeting — the WALL SHEETING line for arched frames (owner 16-Jul): arches bypass
;;  draw-cladding, so its side-wall sheeting was missing.  Draw the SAME 2 vertical lines OUTSIDE the girts
;;  (at -girtDepth and -girtDepth-cladThk / mirror on the right), overlapping 50 mm onto the brick at the
;;  bottom and running UP to the eave/gutter (H) at the top — identical to the Clear Span wall sheeting.
(defun peb-arch-wall-sheeting (W H brickH / girtDepth cladThk yBot)
  (setvar "CLAYER" "CLADDING")
  (setq girtDepth 200.0 cladThk 35.0 yBot (- brickH 50.0))
  (if (< brickH H)
    (progn
      ;; LEFT wall sheeting (2 lines + top/bottom caps)
      (command "LINE" (list (- 0.0 girtDepth)         yBot) (list (- 0.0 girtDepth)         H) "")
      (command "LINE" (list (- 0.0 girtDepth cladThk) yBot) (list (- 0.0 girtDepth cladThk) H) "")
      (command "LINE" (list (- 0.0 girtDepth) H)    (list (- 0.0 girtDepth cladThk) H)    "")
      (command "LINE" (list (- 0.0 girtDepth) yBot) (list (- 0.0 girtDepth cladThk) yBot) "")
      ;; RIGHT wall sheeting
      (command "LINE" (list (+ W girtDepth)         yBot) (list (+ W girtDepth)         H) "")
      (command "LINE" (list (+ W girtDepth cladThk) yBot) (list (+ W girtDepth cladThk) H) "")
      (command "LINE" (list (+ W girtDepth) H)    (list (+ W girtDepth cladThk) H)    "")
      (command "LINE" (list (+ W girtDepth) yBot) (list (+ W girtDepth cladThk) yBot) "")))
  (princ))

;;  peb-deck-purlins — FULL Z-purlin SECTIONS hanging BELOW a canopy sheeting deck (x0,y0)->(x1,y1),
;;  ~1500 mm apart, tilted to the deck slope (owner 16-Jul markup 3: "show the purlin below the sheeting
;;  line", like Clear Span / the arched frames).  The passed segment is the SHEETING line; each Z-purlin's
;;  TOP flange sits under it and the 200 mm web drops toward the rafter.
;;  peb-z-purlin-at — draw ONE 200Z15 Z-purlin section with its TOP flange at deck point (px,py) and the
;;  web dropping 200 mm along the DOWN normal.  (ux,uy) = unit vector ALONG the deck.  Extracted so the
;;  valley purlins (owner 18-Jul markup 16) are drawn by the SAME code as the spaced deck purlins.
(defun peb-z-purlin-at (px py ux uy / nx ny depth wtop wbot lip lipDx lipDy
                          v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  (setvar "CLAYER" "PURLINS") (setvar "PLINEWID" 0.0)
  (setq depth 200.0 wtop 60.0 wbot 60.0 lip 20.0 lipDx (* lip 0.5) lipDy (* lip 0.866))
  (setq nx uy ny (- 0 ux))                        ; n = normal pointing DOWN (below the sheeting)
  (setq v3x px v3y py)
  (setq v4x (+ px (* depth nx)) v4y (+ py (* depth ny)))
  (setq v2x (+ px (* wtop ux)) v2y (+ py (* wtop uy)))
  (setq v1x (+ px (* (- wtop lipDx) ux) (* lipDy nx)) v1y (+ py (* (- wtop lipDx) uy) (* lipDy ny)))
  (setq v5x (+ v4x (* (- 0 wbot) ux)) v5y (+ v4y (* (- 0 wbot) uy)))
  (setq v6x (+ v4x (* (- lipDx wbot) ux) (* (- 0 lipDy) nx)) v6y (+ v4y (* (- lipDx wbot) uy) (* (- 0 lipDy) ny)))
  (command "PLINE" (list v6x v6y) "W" 12.0 12.0
    (list v5x v5y) (list v4x v4y) (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
  (setvar "FILLETRAD" 4.0)
  (command "FILLET" "P" (entlast))
  (setvar "PLINEWID" 0.0))

(defun peb-deck-purlins (x0 y0 x1 y1 / dx dy len ux uy n i tt px py sp)
  (setq dx (- x1 x0) dy (- y1 y0) len (sqrt (+ (* dx dx) (* dy dy))))
  (if (> len 1.0)
    (progn
      (setq ux (/ dx len) uy (/ dy len))          ; u = along the deck
      ;; P1 (owner 19-Jul): BALANCE-SPACE the interior deck bays to 1.25-1.5 m (n = ceil(len/1500), step to n-1
      ;; if that would drop the bay below 1250).  The deck ENDS (eave/tip/valley) carry their own edge/gutter
      ;; purlins added by the caller, so this drops the interior purlins at even 1.25-1.5 m spacing.
      (setq n (max 1 (fix (+ 0.9999 (/ len 1500.0)))))
      (if (and (> n 1) (< (/ len n) 1250.0)) (setq n (1- n)))
      (setq sp (/ len n) i 1)
      (while (< i n)
        (setq tt (* i sp) px (+ x0 (* ux tt)) py (+ y0 (* uy tt)))
        (peb-z-purlin-at px py ux uy)
        (setq i (1+ i))))))

;;  draw-purlins-arc — FULL Z-purlin SECTIONS that FOLLOW an arched roof (owner 16-Jul: ACS/AMS purlins must
;;  read like Clear Span's — a real 200Z15 section sitting ON the rafter top flange, BELOW the sheeting line,
;;  tilted to the LOCAL slope, not a bare tick).  Pass the RAFTER OUTER arc's 3 points (end, peak, end): the
;;  web base sits on that arc and the 200 mm web rises (normal to the tangent) into the 200 mm gap up to the
;;  sheeting.  Fits a parabola y=c0+c1x+c2x^2, steps ~1500 mm along the ARC, on the PURLINS layer.
(defun draw-purlins-arc (x1 y1 x2 y2 x3 y3 / d12 d23 c0 c1 c2 step x y dyx ln ux uy nx ny prevx prevy acc dseg
                          depth wtop wbot lip lipDx lipDy
                          v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  (setvar "CLAYER" "PURLINS")
  (setvar "PLINEWID" 0.0)
  (setq depth 200.0 wtop 60.0 wbot 60.0 lip 20.0 lipDx (* lip 0.5) lipDy (* lip 0.866))
  (setq d12 (/ (- y1 y2) (- x1 x2))
        d23 (/ (- y2 y3) (- x2 x3))
        c2  (/ (- d12 d23) (- x1 x3))
        c1  (- d12 (* c2 (+ x1 x2)))
        c0  (- y1 (* c1 x1) (* c2 x1 x1)))
  (setq step (/ (- x3 x1) 240.0) x x1 prevx x1 prevy y1 acc 0.0)
  (while (<= x x3)
    (setq y    (+ c0 (* c1 x) (* c2 x x)))
    (setq dseg (sqrt (+ (* (- x prevx) (- x prevx)) (* (- y prevy) (- y prevy)))))
    (setq acc  (+ acc dseg))
    (if (>= acc 1500.0)
      (progn
        (setq acc 0.0
              dyx (+ c1 (* 2.0 c2 x))                 ; dy/dx (local slope)
              ln  (sqrt (+ 1.0 (* dyx dyx)))
              ux  (/ 1.0 ln) uy (/ dyx ln)            ; u = tangent (increasing x)
              nx  (- 0 uy) ny ux)                     ; n = normal, points UP (ny=ux>0)
        ;; Z-purlin: v4 (web base) ON the rafter arc; web up +depth*n; flanges along u (200Z15 profile).
        (setq v4x x v4y y)
        (setq v3x (+ x (* depth nx)) v3y (+ y (* depth ny)))
        (setq v5x (+ x (* (- 0 wbot) ux)) v5y (+ y (* (- 0 wbot) uy)))
        (setq v6x (+ x (* (- lipDx wbot) ux) (* lipDy nx))
              v6y (+ y (* (- lipDx wbot) uy) (* lipDy ny)))
        (setq v2x (+ x (* wtop ux) (* depth nx)) v2y (+ y (* wtop uy) (* depth ny)))
        (setq v1x (+ x (* (- wtop lipDx) ux) (* (- depth lipDy) nx))
              v1y (+ y (* (- wtop lipDx) uy) (* (- depth lipDy) ny)))
        (command "PLINE" (list v6x v6y) "W" 12.0 12.0
          (list v5x v5y) (list v4x v4y) (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
        (setvar "FILLETRAD" 4.0)
        (command "FILLET" "P" (entlast))))
    (setq prevx x prevy y x (+ x step)))
  (setvar "PLINEWID" 0.0)
  (princ))

;;  peb-canopy-roof-label — one ROOF SHEETING callout for a canopy deck (no walls).
(defun peb-canopy-roof-label (data ax ay topY / spec rc)
  (setvar "CLAYER" "TEXT")
  (setq spec (peb-split-2-lines (peb-panel-label data "ROOF")))
  (setq rc (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;ROOFING SYSTEM:}\\P" spec "}"))
  ;; the M-Ladder arrow is drawn by peb-make-mleader itself now (explicit solid arrowhead, owner 18-Jul).
  (vl-catch-all-apply 'peb-make-mleader
    (list (list (list ax ay) (list ax topY) (list (+ ax 300.0) topY)) rc)))

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
  ;; (MZ_/CR_/PT_/ST_/RX_/CN_/FA_/RM_/LN_) readable by EVERY sheet via MSPL-Get-*.  This single
  ;; append subsumes the section's old explicit RM*/CR* passthrough (they arrive in the raw tail).
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

;; ROMAND label (owner STANDING RULE: ALL drawing text = ROMAND / romand.shx, not Arial).
(defun txt-rom (just pt h rot str)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setvar "TEXTSTYLE" "ROMAND")
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
            (cons 3 "romand.shx")    ; primary font: ROMAND (universal rule — dims must be romand)
            (cons 4 "")              ; big-font name (none)
          ))))))
  ;; Dimension text style: ROMAND is forced by DIMTXSTY below; PEB-Body is now also romand (universal rule).
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
  ;; owner 19-Jul STANDING RULE: dimension arrowheads = "OPEN" type (open V, NOT filled solid).
  (vl-catch-all-apply (function (lambda () (setvar "DIMSAH" 0) (setvar "DIMBLK" "_OPEN"))))
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
  (setvar "DIMTXSTY"    "ROMAND")    ; owner 19-Jul STANDING: dimension Text style = ROMAND (romand.shx)
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
  ;; Arrow size — try both 41 and 44.  Owner 14-Jul: the 500 mm arrowheads on the COLUMN/GIRT/DOWN PIPE
  ;; leaders read oversized; 250 mm gives a clean small arrow that points at the element.
  (foreach code '(41 44)
    (setq existing (assoc code newData))
    (if existing
      (setq newData (subst (cons code 200.0) existing newData))
      (setq newData (append newData (list (cons code 200.0))))))
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
                          acad doc mspace pts mleader scl flat n upper i p
                          ap0 ap1 adx ady adl aux auy abx aby aaw)
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
  ;; owner 14-Jul: the new MLEADER inherits DIMASZ for its arrowhead — force a SMALL value here so the
  ;; COLUMN/GIRT/DOWN PIPE arrows aren't oversized (dims set their own DIMASZ via peb-dim-set-vars).
  (vl-catch-all-apply (function (lambda () (setvar "DIMASZ" 180.0))))
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
  ;; owner 18-Jul: the native MLEADER arrowhead does NOT render reliably (missing on vertical-leg M-Ladders
  ;; like ROOF/WALL SHEETING & ROOFING SYSTEM).  Shrink it to invisible and draw our OWN solid arrowhead
  ;; below, so EVERY leader gets a guaranteed arrow, uniform across all frames.
  (vl-catch-all-apply
    (function (lambda () (vla-put-ArrowSize mleader 1.0))))
  ;; Force text height = body text height (220 × scale).  Caller can
  ;; override later if it wants something bigger (e.g. heading).
  (vl-catch-all-apply
    (function (lambda () (vla-put-TextHeight mleader (* 600.0 scl)))))   ; Phase-2A v4: 600 base
  ;; Use Standard text style by default.  Callers wanting bold/Arial
  ;; should embed MText format codes (e.g. "{\\Fromand.shx;…}") in the
  ;; text string — this leaves regular weight as the surrounding default.
  (vl-catch-all-apply
    (function (lambda () (vla-put-TextStyleName mleader "Standard"))))
  ;; owner 18-Jul: explicit SOLID arrowhead at the tip (ptList[0]), pointing along the last leader segment
  ;; (ptList[1] -> ptList[0]).  Replaces the unreliable native arrow (shrunk above) so every M-Ladder is wired.
  (setq ap0 (car ptList) ap1 (cadr ptList))
  (setq adx (- (car ap0) (car ap1)) ady (- (cadr ap0) (cadr ap1)))
  (setq adl (sqrt (+ (* adx adx) (* ady ady))))
  (if (> adl 1.0)
    (progn
      (setq aux (/ adx adl) auy (/ ady adl) aaw 90.0)
      (setq abx (- (car ap0) (* aux 260.0)) aby (- (cadr ap0) (* auy 260.0)))   ; arrow base centre
      (setvar "CLAYER" "ARROWS") (setvar "PLINEWID" 0.0)
      (peb-solid-quad (list (- abx (* auy aaw)) (+ aby (* aux aaw)))
                      (list (+ abx (* auy aaw)) (- aby (* aux aaw)))
                      ap0 ap0)))
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

(defun peb-label-pline-leader (text labelPos arrowPt leaderDir textH / )
  ;;  owner 14-Jul: COLUMN / GIRT / DOWN PIPE leaders must show a CLEAN arrowhead pointing STRAIGHT AT the
  ;;  element (horizontal ◄ / ► for a side target) — the native MLEADER arrow renders as a stray downward
  ;;  triangle.  Bypass the mleader entirely: plain MTEXT/text label + a hand-rolled PLINE L-leader
  ;;  (draw-l-leader lays a correctly-oriented tapered tip exactly at the target).
  (if (vl-catch-all-error-p
        (vl-catch-all-apply 'peb-make-mtext-line (list labelPos textH 0 "ML" text)))
    (txt "ML" labelPos textH 0 text))
  (draw-l-leader (car labelPos) (cadr labelPos) (car arrowPt) (cadr arrowPt) leaderDir)
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
  ;; 4.0 -> 2.8 (owner 28-Aug: "in Section the gap b/w the dim of BW and Clear height is
  ;; more"). The gap exists to clear two ROTATED 2-LINE dim texts - "3,048 [10'-0\"]" over
  ;; "BRICK MASONRY", and "6,100 [20'-0\"]" over "CLEAR HEIGHT" - from each other. Rotated,
  ;; a 2-line block occupies 2 x DIMTXT across, so the requirement is 2 lines plus a gap,
  ;; about 2.8. At 4.0 it was 2,400 mm on a 13,720 building - 17% of the section's width
  ;; spent on white space between two dimension columns.
  ;;
  ;; Same rule as the slope tag: the clearance is computed FROM the text it has to clear.
  ;; 2.0 would touch, so the 0.8 is the visible gap and nothing more.
  (max 1200.0 (* 2.8 dimtxt dimscale))
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
  (peb-safe-setvar "DIMTXSTY" "ROMAND")     ; owner 19-Jul STANDING: dimension Text style = ROMAND (romand.shx)
  (peb-safe-setvar "DIMASZ"   600.0)        ; Phase-2A v4: 600 base
  ;; owner 19-Jul STANDING RULE: dimension arrowheads = "OPEN" type (open V, NOT filled solid).
  (peb-safe-setvar "DIMSAH" 0)
  (peb-safe-setvar "DIMBLK" "_OPEN")
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
  ;; owner 14-Jul: global *PEB-DIM-TXT* (mm) shrinks a tall override label (e.g. "3048\PBRICK MASONRY")
  ;; to fit BETWEEN the arrows.  nil/unbound => normal DIMTXT.  (Shared arity — do NOT add a param.)
  (if (and *PEB-DIM-TXT* (> *PEB-DIM-TXT* 0)) (peb-safe-setvar "DIMTXT" *PEB-DIM-TXT*))
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

;; ---- DIMENSION ARROWHEADS ARE OPEN  (owner 19-Jul, enforced 3-Sep-2026) ------------------
;; These drew a closed PLINE triangle and then HATCHed it SOLID - a filled head, against the
;; standing rule stated in this file's own header ("DIMENSIONS: text style = ROMAND; arrowheads
;; = OPEN type") and repeated at three more places in it.  The same file's rm-arrow-h drew them
;; open, so ONE SHEET carried both kinds: the cross-section's own dims filled, the roof
;; monitor's open, eight inches apart.
;;
;; Now two barbs meeting at the tip and no fill - the DIMBLK "_OPEN" look every other sheet
;; plots - at the 240/85 the open heads already used, so the whole set matches.
;; (Leader and callout heads stay FILLED; that is the other half of the rule, and is why this
;;  is fixed here in the DIM arrows rather than by changing every arrow in the engine.)
(defun dim-arrow-h (x y dir / a b)
  (setvar "PLINEWID" 0.0)
  (setq a (* 240 *PEB-DIM-SCALE*) b (* 85 *PEB-DIM-SCALE*))
  (if (= dir "R")
    (command "_.PLINE" (list (+ x a) (+ y b)) (list x y) (list (+ x a) (- y b)) "")
    (command "_.PLINE" (list (- x a) (+ y b)) (list x y) (list (- x a) (- y b)) "")))

(defun dim-arrow-v (x y dir / a b)
  (setvar "PLINEWID" 0.0)
  (setq a (* 240 *PEB-DIM-SCALE*) b (* 85 *PEB-DIM-SCALE*))
  (if (= dir "U")
    (command "_.PLINE" (list (- x b) (+ y a)) (list x y) (list (+ x b) (+ y a)) "")
    (command "_.PLINE" (list (- x b) (- y a)) (list x y) (list (+ x b) (- y a)) "")))

;; OPEN dimension arrowheads (standing rule: dim arrows = OPEN type, NOT filled) for the monitor's
;; custom dims (rm-dim-*).  Two barbs meeting at the tip, no fill — the DIMBLK _OPEN look, on DIMENSIONS.
(defun rm-arrow-h (x y dir / a b)
  (setvar "PLINEWID" 0.0)
  (setq a (* 240 *PEB-DIM-SCALE*) b (* 85 *PEB-DIM-SCALE*))
  (if (= dir "R")
    (command "_.PLINE" (list (+ x a) (+ y b)) (list x y) (list (+ x a) (- y b)) "")
    (command "_.PLINE" (list (- x a) (+ y b)) (list x y) (list (- x a) (- y b)) "")))
(defun rm-arrow-v (x y dir / a b)
  (setvar "PLINEWID" 0.0)
  (setq a (* 240 *PEB-DIM-SCALE*) b (* 85 *PEB-DIM-SCALE*))
  (if (= dir "U")
    (command "_.PLINE" (list (- x b) (+ y a)) (list x y) (list (+ x b) (+ y a)) "")
    (command "_.PLINE" (list (- x b) (- y a)) (list x y) (list (+ x b) (- y a)) "")))

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


(defun draw-border (x1 y1 x2 y2 / margin)
  (setq margin (* 800 *PEB-TEXT-SCALE*))
  (setvar "CLAYER" "BORDER")
  (command "RECTANG" (list (- x1 margin) (- y1 margin)) (list (+ x2 margin) (+ y2 margin)))
  (command "RECTANG" (list (- x1 (* margin 0.6)) (- y1 (* margin 0.6))) (list (+ x2 (* margin 0.6)) (+ y2 (* margin 0.6))))
)

;; ===================== SECTION DRAWING HELPERS =====================

;; RIDGE X (owner 9-Jul).  Duplicate of the Plan engine's peb-ridge-y (Plan loads last and wins; kept
;; here so Section stands alone).  The IF's `ridgeOffset` is the ridge distance FROM NSW in metres --
;; NOT a delta from the centre -- serialized as BP_RIDGE_OFFSET (mm).  Blank / non-numeric /
;; degenerate => CENTRAL ridge.  In the section, NSW is x=0, so the plan's Y is the section's X.
(defun peb-ridge-x (data W / v)
  (setq v (MSPL-Get-Num data "BP_RIDGE_OFFSET"))
  (if (and v (> v (* W 0.02)) (< v (* W 0.98))) v (/ W 2.0)))

(defun compute-section-layout (data stype W /
                                cols ridges numMod numGab spanPerGab gW
                                i sp cum modw bfVx)
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
      (list cols (list (peb-ridge-x data W))))   ; owner 9-Jul: ridge honours BP_RIDGE_OFFSET

    ((= stype "MG")
      ;; Gable structure from the canonical FRAME GRID (Tier 0) — unequal gables + per-gable
      ;; sub-modules; legacy NUMGABLES x SPANSPERGABLE when no grid.  cols = every column line
      ;; (exterior + interior + valley); ridges = each gable's centre.  Matches the plan.
      (setq mgGrid (peb-mg-grid data W))
      (setq mgAcc 0.0) (foreach mgG mgGrid (setq mgAcc (+ mgAcc (apply '+ mgG))))
      (setq mgSc (if (> mgAcc 0.0) (/ W mgAcc) 1.0))
      (setq cols (list 0.0) ridges '() cum 0.0)
      (foreach mgG mgGrid
        (setq gW (* (apply '+ mgG) mgSc))
        (setq ridges (append ridges (list (+ cum (/ gW 2.0)))))
        (setq modw 0.0)
        (foreach sp mgG
          (setq modw (+ modw (* sp mgSc)))
          (setq cols (append cols (list (+ cum modw)))))
        (setq cum (+ cum gW)))
      (list cols ridges))

    ((= stype "SS")
      ;; Single slope: LOW→HIGH columns, NO ridge (empty ridges signals SS to the polygon builder).
      ;; Multi-span single slope (SSMS) adds interior columns from NUMMODULES/MODULEn, mirroring MS;
      ;; clear-span single slope (SSCS, NUMMODULES blank/1) collapses to just (0 W) — no regression.
      (setq numMod (MSPL-Get-Int data "NUMMODULES"))
      (if (or (null numMod) (< numMod 1)) (setq numMod 1))
      (if (> numMod 10) (setq numMod 10))
      (setq cols (list 0.0) cum 0.0 i 0)
      (while (< i numMod)
        (setq modw (MSPL-Get-Num data (strcat "MODULE" (itoa (1+ i)))))
        (cond
          ((= i (1- numMod))     (setq sp (- W cum)))
          ((and modw (> modw 0)) (setq sp modw))
          (T                     (setq sp (/ (- W cum) (- numMod i)))))
        (setq cum (+ cum sp))
        (setq cols (append cols (list cum)))
        (setq i (1+ i)))
      (list cols '()))

    ((= stype "RC")
      ;; Roof system on Reinforced Concrete columns.
      ;; Same gable layout as CS but columns drawn separately as
      ;; concrete rectangles (handled in main draw flow).
      (list (list 0.0 W) (list (peb-ridge-x data W))))   ; owner 9-Jul: ridge honours BP_RIDGE_OFFSET

    ((= stype "ACS")
      ;; Arched Clear Span — 2 columns, "ridge" at apex (W/2)
      (list (list 0.0 W) (list (/ W 2.0))))

    ((= stype "AMS")
      ;; Arched Multi-Span 1 — 3 columns at 0, W/2, W; two arches
      ;; with apexes at the quarter-points. Ridges = peak X (= W/2)
      ;; for grid bubble + dim purposes.
      (list (list 0.0 (/ W 2.0) W) (list (/ W 2.0))))

    ((= stype "BF")
      ;; Butterfly/Falcon 2-wing canopy — a MIDDLE pillar at the valley/peak (owner 18-Jul): give it a grid
      ;; bubble (B) and split the width into TWO modules, so UNEQUAL legs read as a width module ("N@L+M@R").
      ;; Falcon peak stays central; the Butterfly valley honours the ridge-offset (peb-ridge-x).
      (setq bfVx (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES")
                   (/ W 2.0) (peb-bf-valley-x data W)))   ; SAME valley source as the frame/plates/roofing
      (list (list 0.0 bfVx W) (list bfVx)))

    ((= stype "PP")
      ;; Petrol Pump canopy — TWO inset column lines (roof cantilevers beyond each), no ridge.
      (list (list (* W 0.22) (- W (* W 0.22))) '()))

    (T   ; CS (clear span gable) and any unrecognized stype
      ;; owner 9-Jul: ridge honours BP_RIDGE_OFFSET (blank => central).  ACS/AMS keep a central apex
      ;; above -- an arch crown is not a ridge and must stay at W/2.
      (list (list 0.0 W) (list (peb-ridge-x data W))))
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
                                 slL slLenL saL caL slR slLenR saR caR
                                 kLL rLL kLR rLR kXpL kYpL rXpL rYpL kXpR kYpR rXpR rYpR)
  ;;  Returns the inner-edge points along ONE rafter going from the LEFT haunch up over the ridge and back
  ;;  down to the RIGHT haunch.  Three zones each side: knee taper (ht->midD), middle (midD), ridge taper
  ;;  (midD->rd).  Returns (left-knee-end  left-ridge-start  ridge-bottom  right-ridge-start  right-knee-end).
  ;;
  ;;  owner 22-Jul: PER-HALF slopes so an OFF-CENTRE ridge (ridgeX != W/2) doesn't deshape the rafter.  The
  ;;  LEFT half run is (ridgeX-xL) and the RIGHT half run is (xR-ridgeX); each half projects the taper lengths
  ;;  with its OWN slope angle (was: the LEFT slope reused/mirrored for BOTH halves, so the right underside no
  ;;  longer tracked the right top flange).  Mirrors the per-side-slope pattern in peb-draw-roof-monitor.
  ;;  Taper shrink (short half) is also decided per half.
  (setq slL (- ridgeX xL) slLenL (sqrt (+ (* slL slL) (* rise rise)))
        saL (/ rise slLenL) caL (/ slL slLenL) kLL kneeL rLL ridgeL)
  (if (> (+ kLL rLL) (* slLenL 0.85)) (setq kLL (* slLenL 0.40) rLL (* slLenL 0.40)))
  (setq kXpL (* kLL caL) kYpL (* kLL saL) rXpL (* rLL caL) rYpL (* rLL saL))
  (setq slR (- xR ridgeX) slLenR (sqrt (+ (* slR slR) (* rise rise)))
        saR (/ rise slLenR) caR (/ slR slLenR) kLR kneeL rLR ridgeL)
  (if (> (+ kLR rLR) (* slLenR 0.85)) (setq kLR (* slLenR 0.40) rLR (* slLenR 0.40)))
  (setq kXpR (* kLR caR) kYpR (* kLR saR) rXpR (* rLR caR) rYpR (* rLR saR))
  (list
    ;; left knee-end (depth midD) — LEFT projections
    (list (+ xL kXpL)         (- (+ H kYpL)              midD))
    ;; left ridge-start (depth midD) — LEFT projections
    (list (- ridgeX rXpL)     (- (+ H rise (- 0 rYpL))   midD))
    ;; ridge bottom (depth rd)
    (list ridgeX              (+ H rise (- 0 rd)))
    ;; right ridge-start (depth midD) — RIGHT projections
    (list (+ ridgeX rXpR)     (- (+ H rise (- 0 rYpR))   midD))
    ;; right knee-end (depth midD) — RIGHT projections
    (list (- xR kXpR)         (- (+ H kYpR)              midD))
  )
)

(defun cigar-rafter-underside-y (x xL xR ridgeX H rise ht rd midD kneeL ridgeL /
                                   slL slLenL saL caL kLL rLL kXpL kYpL rXpL rYpL
                                   slR slLenR saR caR kLR rLR kXpR kYpR rXpR rYpR
                                   xa xb ya yb f)
  ;;  Returns the Y of the rafter UNDERSIDE at horizontal x for a gable xL..xR, apex ridgeX.  Three zones per
  ;;  half (matching the polygon from rafter-underside-points): knee taper, constant middle, ridge taper.
  ;;  Inside a column body returns the haunch-corner Y (= H-ht).  Used by draw-ms-frame to land interior columns
  ;;  exactly on the rafter underside.
  ;;  owner 22-Jul: PER-HALF slopes (like rafter-underside-points) so an OFF-CENTRE ridge doesn't distort the
  ;;  right-half sampling — each half uses its OWN run/slope/projection and its own taper-shrink.
  (setq slL (- ridgeX xL) slLenL (sqrt (+ (* slL slL) (* rise rise)))
        saL (/ rise slLenL) caL (/ slL slLenL) kLL kneeL rLL ridgeL)
  (if (> (+ kLL rLL) (* slLenL 0.85)) (setq kLL (* slLenL 0.40) rLL (* slLenL 0.40)))
  (setq kXpL (* kLL caL) kYpL (* kLL saL) rXpL (* rLL caL) rYpL (* rLL saL))
  (setq slR (- xR ridgeX) slLenR (sqrt (+ (* slR slR) (* rise rise)))
        saR (/ rise slLenR) caR (/ slR slLenR) kLR kneeL rLR ridgeL)
  (if (> (+ kLR rLR) (* slLenR 0.85)) (setq kLR (* slLenR 0.40) rLR (* slLenR 0.40)))
  (setq kXpR (* kLR caR) kYpR (* kLR saR) rXpR (* rLR caR) rYpR (* rLR saR))
  (cond
    ;; ── LEFT half: x ∈ [xL, ridgeX] ── LEFT slope/projections
    ((<= x ridgeX)
      (cond
        ((<= x (+ xL ht))
          (- H ht))
        ((<= x (+ xL kXpL))
          (setq xa (+ xL ht))
          (setq xb (+ xL kXpL))
          (setq ya (- H ht))
          (setq yb (- (+ H kYpL) midD))
          (setq f  (/ (- x xa) (- xb xa)))
          (+ ya (* f (- yb ya))))
        ((<= x (- ridgeX rXpL))
          (- (+ H (* rise (/ (- x xL) slL))) midD))
        (T
          (setq xa (- ridgeX rXpL))
          (setq xb ridgeX)
          (setq ya (- (+ H rise (- 0 rYpL)) midD))
          (setq yb (+ H rise (- 0 rd)))
          (setq f  (/ (- x xa) (- xb xa)))
          (+ ya (* f (- yb ya))))))
    ;; ── RIGHT half: x ∈ (ridgeX, xR] ── RIGHT slope/projections
    (T
      (cond
        ((>= x (- xR ht))
          (- H ht))
        ((>= x (- xR kXpR))
          (setq xa (- xR kXpR))
          (setq xb (- xR ht))
          (setq ya (- (+ H kYpR) midD))
          (setq yb (- H ht))
          (setq f  (/ (- x xa) (- xb xa)))
          (+ ya (* f (- yb ya))))
        ((>= x (+ ridgeX rXpR))
          (- (+ H (* rise (/ (- xR x) slR))) midD))
        (T
          (setq xa ridgeX)
          (setq xb (+ ridgeX rXpR))
          (setq ya (+ H rise (- 0 rd)))
          (setq yb (- (+ H rise (- 0 rYpR)) midD))
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
                                 outerX innerX ext stiffH
                                 yOut yIn mSlp bx f g)
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
  (setq ep     *PEB-CP-THK*)   ; CP rule: 20mm plates
  (setq ext    *PEB-CP-EXT*)              ; plate extension beyond column flange
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
        (setq outerX (- x halfW ext))         ; plate left  = col flange − ext
        (setq innerX (+ x halfW ext))         ; plate right = col flange + ext
        ;; owner 14-Jul: BOTH plates follow the SLOPE of the rafter BOTTOM FLANGE (not horizontal).  Take
        ;; the cigar-rafter underside at each plate END so the plate strip lies parallel to the flange.
        (setq yOut (cigar-rafter-underside-y outerX 0.0 W ridgeX H rise ht rd midD kneeL ridgeL))
        (setq yIn  (cigar-rafter-underside-y innerX 0.0 W ridgeX H rise ht rd midD kneeL ridgeL))
        (setq mSlp (/ (- yIn yOut) (- innerX outerX)))   ; bottom-flange slope across the plate
        (setq g    *PEB-CP-GAP*)                           ; CP rule: hairline seam gap between the two plates
        ;; owner 14-Jul: TWO SOLID 20mm plates, sloped parallel to the rafter BOTTOM FLANGE, 1mm hairline, NO
        ;; bolts.  The UPPER plate's top edge lies ON the bottom flange line (it REPLACES the flange at the
        ;; connection) and carries NO stiffeners.
        (peb-solid-quad (list outerX (- yOut ep)) (list innerX (- yIn ep))
                        (list outerX yOut) (list innerX yIn))                       ; rafter plate (SOLID)
        (peb-solid-quad (list outerX (- yOut (+ ep g ep))) (list innerX (- yIn (+ ep g ep)))
                        (list outerX (- yOut (+ ep g)))    (list innerX (- yIn (+ ep g))))   ; column plate (SOLID)
        ;; LOWER (column) plate stiffeners only, at the sloped plate-bottom outer corners — stiffener JUST
        ;; till the plate extension (owner 14-Jul): width 100 = the plate extension, no beyond.
        (draw-stiff-bot (- x halfW) (+ (- yOut (+ ep g ep)) (* mSlp ext)) ext stiffH -1)
        (draw-stiff-bot (+ x halfW) (- (- yIn (+ ep g ep)) (* mSlp ext)) ext stiffH  1)))
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

;; ssTopY — rafter TOP Y at horizontal x on a mono slope.
(defun ss-topY (x H slopeRise W) (+ H (* slopeRise (/ x W))))

;; ss-taper-params — SINGLE source of truth for the SS haunch/splice geometry (owner 14-Jul), so the
;; polygon outline (draw-ss-frame) and the splice plates (plate branch) land on the SAME x.  Returns
;; (list midD hLx): midD = thin web depth; hLx = HORIZONTAL taper run ≈ 3-4 m off each column, clamped
;; so adjacent haunch tapers never cross.
(defun ss-taper-params (cols W slopeRise ht / midD hL slLen hLx i gap minGap)
  (setq midD  (max 300.0 (* ht 0.45)))
  (setq hL    (max 3000.0 (min 4000.0 (car (cigar-taper-lengths W)))))   ; splice 3-4 m from column
  (setq slLen (sqrt (+ (* W W) (* slopeRise slopeRise))))
  (setq hLx   (* hL (/ W slLen)))                                        ; horizontal run of the taper
  (setq minGap W i 1)
  (while (< i (length cols))
    (setq gap (- (nth i cols) (nth (1- i) cols)))
    (if (< gap minGap) (setq minGap gap))
    (setq i (1+ i)))
  (setq hLx (min hLx (- (/ minGap 2.0) 200.0)))                          ; keep tapers apart
  (if (< hLx 500.0) (setq hLx 500.0))
  (list midD hLx))

(defun build-ss-polygon (cols W H slopeRise ht cb hLx midD / n i xi under)
  ;;  Single Slope (mono-slope) frame outline — HAUNCHED at EVERY column (owner 14-Jul, ref sample).
  ;;  LOW column on left (eave at H), HIGH column on right (eave at H+slopeRise); one continuous slope.
  ;;  Rafter is DEEP (ht) at every column knee and taper down to THIN (midD) over hLx (~3-4m), then runs
  ;;  STRAIGHT at depth midD between haunch ends.  End knees keep an `ht` horizontal haunch; interior
  ;;  columns are point-haunches at their station.  `cols` = column x-list (0..W); interior columns are
  ;;  drawn separately by draw-ss-interior-cols and land on these knees.
  (setq n (length cols))
  ;; underside vertices LEFT->RIGHT: left knee (deep) -> left taper (thin) ...
  (setq under (list
    (list ht (- H ht))
    (list (+ ht hLx) (- (ss-topY (+ ht hLx) H slopeRise W) midD))))
  ;; ... interior columns: thin-before -> deep-knee -> thin-after ...
  (setq i 1)
  (while (< i (1- n))
    (setq xi (nth i cols))
    (setq under (append under (list
      (list (- xi hLx) (- (ss-topY (- xi hLx) H slopeRise W) midD))
      (list xi         (- (ss-topY xi H slopeRise W) ht))
      (list (+ xi hLx) (- (ss-topY (+ xi hLx) H slopeRise W) midD)))))
    (setq i (1+ i)))
  ;; ... right taper (thin) -> right knee (deep).
  (setq under (append under (list
    (list (- (- W ht) hLx) (- (ss-topY (- (- W ht) hLx) H slopeRise W) midD))
    (list (- W ht) (- (+ H slopeRise) ht)))))
  ;; polygon walks the underside RIGHT->LEFT, so reverse the left->right list.
  (setq under (reverse under))
  (append
    (list
      (list 0.0      0.0)               ; bottom-left outside
      (list 0.0      H)                 ; low eave top
      (list W        (+ H slopeRise))   ; high eave top
      (list W        0.0)               ; bottom-right outside
      (list (- W cb) 0.0))              ; right column inside-base
    under                              ; underside right->left (right knee ... left knee)
    (list (list cb 0.0))))             ; left column inside-base

(defun draw-ss-frame (cols W H slopeRise ht cb hLx midD / pts)
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (setq pts (build-ss-polygon cols W H slopeRise ht cb hLx midD))
  (command "PLINE")
  (foreach p pts (command p))
  (command "C")
)

;; SSMS interior columns: for a MULTI-SPAN single slope, each interior station rises to the STRAIGHT
;; rafter underside (NOT the cigar/ridge formula — single slope has no ridge).  The underside runs
;; linearly from the low haunch (H−ht) to the high haunch (H+slopeRise−ht), so at station x:
;;   yTop(x) = (H − ht) + slopeRise·(x/W).  Web width reuses ms-col-web-at (module-sized).  SSCS (2 cols)
;; skips this entirely.  (Called AFTER draw-ss-frame from the dispatcher.)
(defun draw-ss-interior-cols (cols W H slopeRise ht / i x rafterY thisColW halfW numCols)
  (setvar "CLAYER" "FRAME")
  (setq numCols (length cols) i 1)
  (while (< i (1- numCols))
    (setq x        (nth i cols)
          thisColW (ms-col-web-at cols i)
          halfW    (/ thisColW 2.0)
          rafterY  (+ (- H ht) (* slopeRise (/ x W))))
    (command "_.RECTANG" (list (- x halfW) 0.0) (list (+ x halfW) rafterY))
    (setq i (1+ i)))
  (princ))

(defun draw-rcc-columns (cols H rccW brickExt / x x0 x1 sx0 sx1 bx)
  ;;  RCC (Reinforced Concrete) columns — presentable concrete section (owner 16-Jul "very presentable"):
  ;;  a clean rectangle outline + AR-CONC concrete hatch + 2 vertical REINFORCEMENT bars (hidden/dashed) inset
  ;;  from the faces.  Used for stype = RC.  `brickExt` WIDENS the OUTER face of the end columns out to the
  ;;  flush brick-masonry face (owner 16-Jul, flush case); 0 = column edge only.  sx0/sx1 = STRUCTURAL faces
  ;;  (rebar insets from these, never into the brick zone).
  (if (null brickExt) (setq brickExt 0.0))
  (setvar "CLAYER" "RCC-COLUMN")
  (foreach x cols
    (cond
      ((equal x (car cols)  0.001) (setq x0 (- x brickExt) x1 (+ x rccW)         sx0 x            sx1 (+ x rccW)))  ; LEFT (widen OUT)
      ((equal x (last cols) 0.001) (setq x0 (- x rccW)     x1 (+ x brickExt)     sx0 (- x rccW)   sx1 x))           ; RIGHT (widen OUT)
      (T                           (setq x0 (- x (/ rccW 2.0)) x1 (+ x (/ rccW 2.0)) sx0 x0 sx1 x1)))               ; interior
    (command "RECTANG" (list x0 0.0) (list x1 H))
    (command "HATCH" "AR-CONC" 100 0 "L" "")   ; sparser aggregate — cleaner concrete look (owner markup 17)
    ;; two vertical reinforcement bars, dashed, inset 90mm from the STRUCTURAL faces (not into the brick zone)
    (setvar "CELTYPE" "HIDDEN") (setvar "CELTSCALE" 300.0)
    (foreach bx (list (+ sx0 90.0) (- sx1 90.0))
      (command "LINE" (list bx 90.0) (list bx (- H 90.0)) ""))
    (setvar "CELTYPE" "BYLAYER") (setvar "CELTSCALE" 1.0)))

(defun build-rc-rafter-polygon (W H rise de dp inset)
  ;;  Roof System on RCC columns: the steel rafter is PINNED on the concrete
  ;;  columns at both eaves (no moment haunch), so its web is CONTINUOUSLY
  ;;  TAPERED -- SHALLOW at the eaves (min moment at the pinned ends) and
  ;;  DEEPEST at the peak (max moment at mid-span / ridge).  Owner 13-Jul,
  ;;  matching the design-manual shape.  de = eave depth, dp = peak depth.
  ;;  `inset` pulls the eaves IN (fascia case) so the roof sits BEHIND the
  ;;  parapets, draining to the valley gutters; 0 for the plain arrangement.
  (list
    (list inset       H)                     ; left eave TOP (bears on column)
    (list (/ W 2.0)   (+ H rise))            ; ridge TOP
    (list (- W inset) H)                     ; right eave TOP (bears on column)
    (list (- W inset) (- H de))              ; right eave UNDERSIDE (shallow)
    (list (/ W 2.0)   (+ H rise (- 0 dp)))   ; ridge UNDERSIDE (deep)
    (list inset       (- H de))              ; left eave UNDERSIDE (shallow)
  )
)

(defun draw-rc-frame (W H rise ht rd fascia parapetH / pts rccW de dp colTop)
  ;;  Draw RCC columns + a continuously-tapered steel rafter (separate entities).  Two arrangements (owner
  ;;  15-Jul markups 4/9): `fascia`=nil → plain roof-on-RCC with eave gutters (columns bear the rafter at the
  ;;  eave underside); `fascia`=T → the RCC columns extend ABOVE the roof as a PARAPET/FASCIA (height parapetH
  ;;  above the eave) and the roof drains into a VALLEY GUTTER at each parapet base (drawn by draw-rc-fascia).
  (setq rccW 500.0)                       ; typical RCC column width (mm)
  (setq de (max 200.0 (* ht 0.35)))       ; shallow eave rafter depth
  (setq dp (max 600.0 (* ht 1.10)))       ; deep peak rafter depth
  (setq colTop (- H de))                  ; RCC column bears the rafter at the eave underside
  ;; fascia → only the OUTER PORTION of the column (owner 16-Jul) rises past the roof; the rafter tucks BEHIND
  ;; it (inset by that outer-portion width) and drains to a valley gutter.  plain → eaves flush at 0/W.
  (setq *PEB-RC-PARAW* (* rccW 0.45))     ; outer portion of the column that extends up as the fascia parapet
  ;; owner markup 18: EXTEND the rafter (and its trimmed roof sheeting) right up to the FASCIA inner face; the
  ;; valley gutter then rests ON TOP of the rafter end, tucked against the fascia.
  (setq *PEB-RC-INSET* (if fascia *PEB-RC-PARAW* 0.0))
  ;; FLUSH brick case (owner 16-Jul): the plain roof-system wall has brick masonry FLUSH with the columns, so
  ;; widen the column OUT to the brick face and show the brick as dotted lines WITHIN it (draw-rc-brick-hidden).
  ;; No brick on the fascia option.
  (setq *PEB-RC-BRICKEXT* (if fascia 0.0 200.0))
  (draw-rcc-columns (list 0.0 W) colTop rccW *PEB-RC-BRICKEXT*)
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (setq pts (build-rc-rafter-polygon W H rise de dp *PEB-RC-INSET*))
  (command "PLINE")
  (foreach p pts (command p))
  (command "C")
  ;; fascia: the OUTER portion of each RCC column extends up (concrete) to HIDE the peak line (owner 16-Jul).
  (if fascia (draw-rc-fascia W H rise *PEB-RC-PARAW* colTop))
)

(defun draw-rc-fascia (W H rise paraW baseY / pTop ivL ivR g gxOut gxIn gIn)
  ;;  RCC FASCIA (owner 16-Jul clarification): the SECTION is cut through the RCC column, so the fascia is the
  ;;  OUTER PORTION of the column (width paraW) CONTINUING UPWARD as concrete — from the column top (baseY) past
  ;;  the roof up to just ABOVE the peak line (pTop) so it HIDES the roof peak behind it.  Drawn as the same
  ;;  concrete section as the column (AR-CONC hatch + reinforcement bar), NOT block masonry.  The steel rafter
  ;;  is inset behind the parapet and drains into a VALLEY GUTTER at each parapet inner face.
  (setq pTop (+ H rise 650.0)              ; rise well ABOVE the roof sheeting peak so the parapet HIDES the peak
        ivL paraW ivR (- W paraW))         ; inner faces of the L / R parapet extensions (= rafter eaves)
  ;; CONCRETE parapet extensions — the outer slice of each column carried up.
  (setvar "CLAYER" "RCC-COLUMN")
  (foreach g (list (list 0.0 paraW) (list (- W paraW) W))
    (command "RECTANG" (list (car g) baseY) (list (cadr g) pTop))
    (command "HATCH" "AR-CONC" 100 0 "L" "")   ; sparser aggregate — cleaner concrete look (owner markup 17)
    (setvar "CELTYPE" "HIDDEN") (setvar "CELTSCALE" 300.0)
    (command "LINE" (list (+ (car g) 90.0) baseY) (list (+ (car g) 90.0) (- pTop 90.0)) "")   ; outer-face bar
    (setvar "CELTYPE" "BYLAYER") (setvar "CELTSCALE" 1.0))
  ;; VALLEY GUTTER (owner markup 18): a SMALL box gutter RESTING ON TOP of the rafter end, tucked against the
  ;; fascia inner face (ivL/ivR) — outer wall up the fascia, bottom on the rafter top (~H), a low inner upstand
  ;; the roof sheeting laps over.
  (setq gIn 240.0)                                  ; small gutter width (inboard from the fascia)
  (setvar "CLAYER" "GUTTER") (setvar "PLINEWID" 0.0)
  (foreach g (list (list ivL 1.0) (list ivR -1.0))
    (setq gxOut (car g) gxIn (+ (car g) (* (cadr g) gIn)))
    (command "PLINE"
      (list gxOut (+ H 260.0))      ; top of the OUTER wall, up the fascia
      (list gxOut (+ H 20.0))       ; down onto the rafter top at the fascia
      (list gxIn  (+ H 20.0))       ; bottom along the rafter top
      (list gxIn  (+ H 150.0)) "")) ; low INNER upstand — the sheeting laps over this into the channel
  ;; labels — only VALLEY GUTTER kept (owner markup 21 removed the RCC PARAPET/FASCIA + CLOSURE TRIM callouts).
  (setvar "CLAYER" "TEXT")
  (peb-label-with-leader "VALLEY GUTTER"
                         (list (+ ivL 1500.0) (+ H 800.0)) (list (+ ivL 120.0) (+ H 120.0)) "H" 160)
  (princ))

(defun draw-rc-support (x0 x1 topY roller / w bx bx1 bx2 pt slot lbl lx)
  ;;  Roof-on-RCC support (owner 15-Jul markups 1/2/3/5): a THICK base plate sitting ON the RCC column top —
  ;;  ONLY the column width, NOT extended inward — with 2 anchor bolts hooking down into the concrete.
  ;;  roller=T  → anchor bolts sit in SLOTTED holes (the roofing-system ROLLER end, free to slide for thermal
  ;;              movement); roller=nil → PINNED (fixed).  One end of the roof is roller, the other pinned.
  (setvar "CLAYER" "PLATES")
  (setq w (- x1 x0) pt 70.0)                                   ; thick plate (exaggerated for section visibility)
  (peb-solid-quad (list x0 topY) (list x1 topY) (list x0 (+ topY pt)) (list x1 (+ topY pt)))
  (setq bx1 (+ x0 (* w 0.27)) bx2 (+ x0 (* w 0.73)) slot 120.0)
  (foreach bx (list bx1 bx2)
    (command "DONUT" 0 (* 40 *PEB-TEXT-SCALE*) (list bx (+ topY (/ pt 2.0))) "")   ; anchor bolt head/nut
    (command "LINE" (list bx (+ topY pt)) (list bx (- topY 450.0)) "")             ; anchor rod into the concrete
    (if roller                                                                     ; SLOTTED hole (roller)
      (progn
        (command "LINE" (list (- bx slot) topY) (list (+ bx slot) topY) "")
        (command "LINE" (list (- bx slot) (+ topY pt)) (list (+ bx slot) (+ topY pt)) ""))))
  ;; PINNED / ROLLER SUPPORT text labels removed (owner markup 19) — the slotted-hole geometry already shows the
  ;; roller end vs the fixed (pinned) end, so the callouts are redundant.
  (princ))

(defun draw-rc-ridge (W H rise ht / dp x0 yTop yBot pt gp ext lxo rxo)
  ;;  RC ridge/peak connection: ONE SOLID plate (owner markup 15 — NO gap between the two halves; the bolted
  ;;  end-plates read as a single thick plate) spanning the web + 100mm BEYOND BOTH flanges, with FULL-WEB
  ;;  stiffener gussets on each side.  Peak rafter depth dp matches build-rc-rafter-polygon.
  (setq dp   (max 600.0 (* ht 1.10))
        x0   (/ W 2.0)
        yTop (+ H rise)                    ; top flange at the ridge
        yBot (- (+ H rise) dp)             ; bottom flange (underside) at the ridge
        pt   *PEB-CP-THK* gp (/ *PEB-CP-GAP* 2.0) ext *PEB-CP-EXT*   ; CP rule: 20mm plates, hairline HALF-gap
        lxo  (- x0 gp) rxo (+ x0 gp))      ; inner faces of the LEFT / RIGHT bolted end-plate
  (setvar "CLAYER" "PLATES")
  (peb-solid-quad (list (- lxo pt) (- yBot ext)) (list lxo (- yBot ext))        ; LEFT plate (SOLID thick)
                  (list (- lxo pt) (+ yTop ext)) (list lxo (+ yTop ext)))
  (peb-solid-quad (list rxo (- yBot ext)) (list (+ rxo pt) (- yBot ext))        ; RIGHT plate (SOLID thick)
                  (list rxo (+ yTop ext)) (list (+ rxo pt) (+ yTop ext)))
  ;; stiffener gussets at the TOP and BOTTOM flanges on the outer edge of each plate (owner markup 17 —
  ;; NOT a mid-web diamond; the gussets sit at the flange corners).
  ;; FILLED gussets kept within the plate end lines (owner markup 22): plate top = yTop+ext, bottom = yBot-ext.
  (draw-rc-gusset (- lxo pt) yTop (+ yTop ext) 130.0 -1 0.0)
  (draw-rc-gusset (- lxo pt) yBot (- yBot ext) 130.0 -1 0.0)
  (draw-rc-gusset (+ rxo pt) yTop (+ yTop ext) 130.0  1 0.0)
  (draw-rc-gusset (+ rxo pt) yBot (- yBot ext) 130.0  1 0.0)
  (princ))

;; RC rafter top-flange / underside Y at any x (mirrors build-rc-rafter-polygon; `inset` pulls the eaves in).
(defun rc-rafter-yt (W H rise inset x / hl)
  (setq hl (- (/ W 2.0) inset))
  (if (<= x (/ W 2.0)) (+ H (* rise (/ (- x inset)       hl)))
                       (+ H (* rise (/ (- (- W inset) x)  hl)))))
(defun rc-rafter-yb (W H rise ht inset x / de dp hl)
  (setq de (max 200.0 (* ht 0.35)) dp (max 600.0 (* ht 1.10)) hl (- (/ W 2.0) inset))
  (if (<= x (/ W 2.0)) (+ (- H de) (* (/ (- x inset)      hl) (- (- (+ H rise) dp) (- H de))))
                       (+ (- H de) (* (/ (- (- W inset) x) hl) (- (- (+ H rise) dp) (- H de))))))
(defun draw-rc-splice (x yTop yBot / pt gp ext lxo rxo)
  ;;  One rafter SPLICE connection at x: TWO bolted end-plates with a HAIRLINE 0.25-0.5mm gap (owner 16-Jul),
  ;;  each spanning the web + 100mm beyond both flanges, with FULL-WEB stiffener gussets on the outer edges.
  (setq pt *PEB-CP-THK* gp (/ *PEB-CP-GAP* 2.0) ext *PEB-CP-EXT* lxo (- x gp) rxo (+ x gp))   ; CP rule: 20mm plates, hairline HALF-gap
  (setvar "CLAYER" "PLATES")
  (peb-solid-quad (list (- lxo pt) (- yBot ext)) (list lxo (- yBot ext))
                  (list (- lxo pt) (+ yTop ext)) (list lxo (+ yTop ext)))
  (peb-solid-quad (list rxo (- yBot ext)) (list (+ rxo pt) (- yBot ext))
                  (list rxo (+ yTop ext)) (list (+ rxo pt) (+ yTop ext)))
  ;; FILLED gussets at the flanges, kept within the plate end lines (owner markups 17/22)
  (draw-rc-gusset (- lxo pt) yTop (+ yTop ext) 130.0 -1 0.0)
  (draw-rc-gusset (- lxo pt) yBot (- yBot ext) 130.0 -1 0.0)
  (draw-rc-gusset (+ rxo pt) yTop (+ yTop ext) 130.0  1 0.0)
  (draw-rc-gusset (+ rxo pt) yBot (- yBot ext) 130.0  1 0.0))
(defun draw-rc-splices (W H rise ht / inset hw nP i sx)
  ;;  Transport limit (owner 15-Jul): a rafter piece can't exceed 12m, so split EACH half (eave→peak) into
  ;;  equal pieces ≤12m and put a splice connection plate at every interior break.  `inset` = the fascia eave
  ;;  inset so splices stay on the actual (behind-parapet) rafter.
  (setq inset (if (and *PEB-RC-INSET* (> *PEB-RC-INSET* 0.0)) *PEB-RC-INSET* 0.0)
        hw (- (/ W 2.0) inset) nP (max 1 (fix (+ 0.999 (/ hw 12000.0)))) i 1)
  (while (< i nP)
    (setq sx (+ inset (* i (/ hw (float nP)))))
    (draw-rc-splice sx        (rc-rafter-yt W H rise inset sx)        (rc-rafter-yb W H rise ht inset sx))
    (draw-rc-splice (- W sx)  (rc-rafter-yt W H rise inset (- W sx))  (rc-rafter-yb W H rise ht inset (- W sx)))
    (setq i (1+ i))))

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
        ;; "VALLEY GUTTER" label + M-Ladder DOWN-ARROW (owner 14-Jul): explicit shaft + SOLID arrowhead.
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (/ (+ vXL vXR) 2.0) (+ H (* 1500 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "VALLEY GUTTER")
        (setvar "CLAYER" "ARROWS")
        (command "LINE" (list (/ (+ vXL vXR) 2.0) (+ H (* 1150 *PEB-TEXT-SCALE*)))
                        (list (/ (+ vXL vXR) 2.0) (- H 100.0)) "")
        (peb-solid-quad (list (- (/ (+ vXL vXR) 2.0) (* 130 *PEB-TEXT-SCALE*)) (- H 100.0))
                        (list (+ (/ (+ vXL vXR) 2.0) (* 130 *PEB-TEXT-SCALE*)) (- H 100.0))
                        (list (/ (+ vXL vXR) 2.0) (- H 250.0)) (list (/ (+ vXL vXR) 2.0) (- H 250.0)))))

    (setq i (1+ i)))
)

(defun draw-mg-multi-frame (W H rise ht rd cb mgGrid /
                            gW subX subColH midD intColW
                            mainCols mainRidges ridgeX gxL gxR
                            mgAcc mgSc mgG mgSp base sub nsub k)
  ;;  Multi-Gable from the canonical FRAME GRID (Tier 0): each gable carries its OWN sub-modules
  ;;  (unequal gables + unequal sub-modules allowed).  Draw the proven multi-gable outline
  ;;  (gable-boundary cols + per-gable ridges) via draw-frame-outline, then add each gable's
  ;;  INTERIOR sub-span columns as rectangles rising to the rafter underside.
  (setq midD    (max 300.0 (min 500.0 (- (* ht 0.5) 50.0))))
  (setq intColW 400.0)
  ;; scale gable widths to close EXACTLY on W
  (setq mgAcc 0.0) (foreach mgG mgGrid (setq mgAcc (+ mgAcc (apply '+ mgG))))
  (setq mgSc (if (> mgAcc 0.0) (/ W mgAcc) 1.0))
  ;; gable-boundary columns (0, g1-end, g2-end, ..., W) + one ridge per gable at its centre
  (setq mainCols (list 0.0) mainRidges '() base 0.0)
  (foreach mgG mgGrid
    (setq gW (* (apply '+ mgG) mgSc))
    (setq mainRidges (append mainRidges (list (+ base (/ gW 2.0)))))
    (setq base (+ base gW))
    (setq mainCols (append mainCols (list base))))
  (draw-frame-outline mainCols mainRidges H rise ht rd cb)
  ;; interior sub-span columns WITHIN each gable (its OWN sub-module boundaries)
  (setvar "CLAYER" "FRAME")
  (setq base 0.0)
  (foreach mgG mgGrid
    (setq gW (* (apply '+ mgG) mgSc))
    (setq gxL base  gxR (+ base gW)  ridgeX (+ base (/ gW 2.0)))
    (setq sub 0.0  nsub (length mgG)  k 0)
    (foreach mgSp mgG
      (setq k (1+ k))
      (if (< k nsub)                                  ; interior boundary (not the gable end / valley)
        (progn
          (setq sub (+ sub (* mgSp mgSc))  subX (+ gxL sub))
          (cond
            ((equal subX ridgeX 0.001) (setq subColH (+ H rise (- 0 rd))))
            ((< subX ridgeX) (setq subColH (- (+ H (* rise (/ (- subX gxL) (- ridgeX gxL)))) midD)))
            (T               (setq subColH (- (+ H (* rise (/ (- gxR subX) (- gxR ridgeX)))) midD))))
          (command "RECTANG" (list (- subX (/ intColW 2.0)) 0.0) (list (+ subX (/ intColW 2.0)) subColH)))))
    (setq base (+ base gW)))
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

(defun fr-col-top (H ht)
  ;;  Flat-roof STEEL column top = the MAIN-BEAM bottom (the beam bears on the column).
  ;;  = H - 125(concrete over crest) - 45(decking) - 550(main-beam depth) = H - 720.
  (- H 720.0))

(defun draw-fr-frame (W H ht cb / colTop)
  ;;  Flat Roof (owner 15-Jul): STRAIGHT steel columns (constant width = ht, NO haunch) up to the
  ;;  main-beam bearing; the RCC-on-steel roof (draw-floor-buildup) spans between them on top.
  (setq colTop (fr-col-top H ht))
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (command "RECTANG" (list 0.0 0.0)        (list ht colTop))        ; LEFT straight column
  (command "RECTANG" (list (- W ht) 0.0)   (list W  colTop))        ; RIGHT straight column
)

(defun draw-f2-frame (W H ht cb intXs / colTop xc)
  ;;  MULTI-STOREY FLAT ROOF (owner 15-Jul): FULL-HEIGHT straight steel columns — 2 EDGE + the INTERMEDIATE
  ;;  (mezzanine) columns at `intXs` (from MZ_COL_SPACING) — that carry BOTH the intermediate floor(s) AND
  ;;  the top flat roof.  Column top = roof main-beam bottom (H-720).  The mezzanine main beam frames INTO
  ;;  these same columns lower down.
  (setq colTop (- H 720.0))
  (setvar "CLAYER" "FRAME") (setvar "PLINEWID" 0.0)
  (command "RECTANG" (list 0.0 0.0)      (list ht colTop))            ; LEFT edge column
  (command "RECTANG" (list (- W ht) 0.0) (list W  colTop))            ; RIGHT edge column
  (foreach xc intXs                                                   ; INTERMEDIATE (mezzanine) columns
    (if (and (> xc (* ht 1.5)) (< xc (- W (* ht 1.5))))
      (command "RECTANG" (list (- xc (/ ht 2.0)) 0.0) (list (+ xc (/ ht 2.0)) colTop))))
)

;; G+1 / multi-storey flat roof takes its INTERMEDIATE FLOORS from the MEZZANINE sub-section (owner 15-Jul:
;; "write the building with more height, give the intermediate floors via the no. of Mezzanine").
;; Level of each floor = MZ1_CH_FFL_BEAM (clear height FFL → under the MAIN BEAM), stacked by MZ_FLOOR_HT.
(defun f2-mezz-levels (data / hb n fh out i)
  (setq hb (MSPL-Get-Num data "MZ1_CH_FFL_BEAM"))
  (if (or (null hb) (<= hb 0.0)) (setq hb 6000.0))
  (setq n  (MSPL-Get-Num data "MZ_NUM_FLOORS"))
  (setq n  (if (and n (>= n 1)) (fix n) 1))
  (setq fh (MSPL-Get-Num data "MZ_FLOOR_HT"))
  (if (or (null fh) (<= fh 0.0)) (setq fh 4000.0))
  (setq out '() i 0)
  (while (< i n) (setq out (append out (list (+ hb (* i fh))))) (setq i (1+ i)))
  out)
;; Intermediate (mezzanine) column X positions from MZ_COL_SPACING "N@S" (owner choice) = N bays of S.
;; Fallback: fewest columns so every bay is < 10 m.
(defun f2-int-col-xs (data wid / spec atp n s xs i)
  (setq spec (peb-tb-or (MSPL-Get-Str data "MZ_COL_SPACING") ""))
  (setq atp (vl-string-search "@" spec))
  (setq xs '())
  (if atp
    (progn (setq n (atoi (substr spec 1 atp)) s (atof (substr spec (+ atp 2))) i 1)
           (while (and (< i n) (< (* i s) (- wid 1.0)))
             (setq xs (append xs (list (* i s)))) (setq i (1+ i))))
    (progn (setq n (max 1 (fix (+ 0.999 (/ wid 10000.0)))) i 1)
           (while (< i n) (setq xs (append xs (list (* (/ wid (float n)) i)))) (setq i (1+ i)))))
  xs)
;; F2 (multi-storey flat roof) is engaged when a FLAT ROOF also has the mezzanine sub-section switched on.
(defun f2-active-p (data)
  (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_TOGGLE") "")) "YES"))
;; Column-beam junction connection (owner 16-Jul, STRICT): TWO solid plates, EACH 30mm thick, EXTENDING 100mm
;; beyond the vertical (column) web on BOTH sides.  Column-side plate just below the beam-bottom seam, beam-side
;; plate just above it (2mm gap).  Drawn at the top flat roof AND every intermediate/mezzanine floor beam.
(defun draw-f2-connplate (colX0 colX1 beamBot beamD isL isR / y0 y1 pt)
  ;;  VERTICAL connection plate(s) at a beam-to-column junction (owner 16-Jul: "vertical connection plates —
  ;;  each beam connected column-to-column").  A plate on the column FACE where a beam frames in, running the
  ;;  full beam depth + 100mm beyond BOTH flanges.  True plate 30mm (drawn thicker for visibility on the tall
  ;;  section).  isL/isR = T when there is NO beam on that side (edge column) → skip that plate.
  (setq y0 (- beamBot 100.0) y1 (+ (+ beamBot beamD) 100.0) pt 180.0)
  (setvar "CLAYER" "PLATES")
  (if (not isL)                                                              ; beam frames in from the LEFT
    (peb-solid-quad (list (- colX0 pt) y0) (list colX0 y0) (list (- colX0 pt) y1) (list colX0 y1)))
  (if (not isR)                                                              ; beam frames in from the RIGHT
    (peb-solid-quad (list colX1 y0) (list (+ colX1 pt) y0) (list colX1 y1) (list (+ colX1 pt) y1))))

(defun draw-floor-buildup (x0 x1 yTop beamD joistD slabT lbls / span deckCrest bTop bBot bf jw jBotF jx nJ step jLabX drop ov cx0 cx1)
  ;;  `lbls` = T draws the 4 detailed labels (CONCRETE/DECKING/JOIST/BEAM); nil = geometry only (used by the
  ;;  G+1 intermediate floor, which carries a single "INTERMEDIATE FLOOR" callout instead).
  ;;  FLAT-ROOF RCC-on-steel build-up (owner 15-Jul spec):
  ;;    125mm CONCRETE  on  0.70mm PROFILED DECKING PANEL  on  STEEL JOISTS @ 1.5m,
  ;;    the joists sitting WITHIN the MAIN BEAM web with their TOPS FLUSH with the main-beam top flange.
  ;;  The MAIN BEAM spans the full width column-to-column, so in this cross-section we see its WEB +
  ;;  TOP/BOTTOM FLANGES in elevation; the JOISTS run into the page so we see their I-section cut @ 1.5m.
  (setq span (- x1 x0))
  (setq bf   25.0)                         ; drawn flange thickness
  (setq deckCrest (- yTop slabT))          ; concrete-above-crest bottom (slabT = 125mm over the crest)
  (setq bTop (- deckCrest 45.0))           ; corrugation TROUGH = beam/joist top flange (flush); 45mm deep
  (setq bBot (- bTop beamD))               ; MAIN BEAM bottom flange
  ;; ── 125mm RCC concrete slab (fills the decking flutes) — FLAT top (no slope).  AR-CONC at the SAME
  ;; scale as the Roof-System RCC columns (draw-rcc-columns) so it reads as a proper concrete section. ──
  (setq ov 235.0 cx0 (- x0 ov) cx1 (+ x1 ov))   ; concrete/decking extend to the wall edge (past the columns)
  (setvar "CLAYER" "RCC-COLUMN")
  (setvar "PLINEWID" 0.0)
  (command "RECTANG" (list cx0 bTop) (list cx1 yTop))
  (command "HATCH" "AR-CONC" (* 14.0 *PEB-TEXT-SCALE*) 0 "L" "")   ; owner: reduce the hatch scale -> finer concrete texture
  ;; ── 0.70mm PROFILED DECKING sheet — this section looks ALONG the corrugation, so it reads as TWO
  ;;    horizontal lines 45mm apart: BOTTOM solid (decking sheeting line on the flush beam/joist top) +
  ;;    TOP dashed (corrugation crest, hidden).  The concrete (hatched above) shows from the bottom line up.
  (setvar "CLAYER" "CLADDING")
  (command "LINE" (list cx0 bTop) (list cx1 bTop) "")            ; decking bottom line (solid, on the beam top)
  (setvar "CELTYPE" "DASHED")
  (command "LINE" (list cx0 deckCrest) (list cx1 deckCrest) "")  ; corrugation crest 45mm up (dashed/hidden)
  (setvar "CELTYPE" "BYLAYER")
  ;; ── MAIN BEAM — full-width I-section in elevation (top flange, bottom flange, end web edges) ──
  (setvar "CLAYER" "FRAME")
  (command "RECTANG" (list x0 (- bTop bf)) (list x1 bTop))      ; top flange (full width)
  (command "RECTANG" (list x0 bBot) (list x1 (+ bBot bf)))      ; bottom flange (full width)
  (command "LINE" (list x0 (- bTop bf)) (list x0 (+ bBot bf)) "")   ; left web edge
  (command "LINE" (list x1 (- bTop bf)) (list x1 (+ bBot bf)) "")   ; right web edge
  ;; ── JOIST I-sections @ 1.5 m, ~300mm deep, nested WITHIN the beam web, tops FLUSH under the beam top flange ──
  (setq jw 75.0)                           ; joist flange half-width
  (setq jBotF (- (- bTop bf) 300.0))       ; joist bottom flange = 300mm below the beam top flange (inside the web)
  (setq nJ   (max 2 (fix (/ span 1500.0))))
  (setq step (/ span (float nJ)))
  (setq jx   (+ x0 step))
  (while (< jx (- x1 1.0))
    (command "LINE" (list (- jx jw) (- bTop bf)) (list (+ jx jw) (- bTop bf)) "")   ; joist top flange (flush)
    (command "LINE" (list (- jx jw) jBotF)       (list (+ jx jw) jBotF) "")         ; joist bottom flange (300 deep)
    (command "LINE" (list jx (- bTop bf))        (list jx jBotF) "")                ; joist web
    (setq jx (+ jx step)))
  ;; ── Labels ──
  (if lbls
    (progn
      (setvar "CLAYER" "TEXT")
      (setq jLabX (+ x0 (* step 2.0)))         ; a real joist station for the joist leader
      ;; roof labels — SHORT legs (800), spread HORIZONTALLY so nothing overlaps (owner: no long M-Ladder legs)
      (peb-label-with-leader "125mm THICK CONCRETE"
                             (list (+ x0 (* span 0.28)) (+ yTop 800.0))
                             (list (+ x0 (* span 0.28)) (- yTop (/ slabT 2.0)))
                             "V" 220)
      (peb-label-with-leader "0.70mm PROFILED DECKING PANEL"
                             (list (+ x0 (* span 0.45)) (+ yTop 800.0))
                             (list (+ x0 (* span 0.45)) (* (+ bTop deckCrest) 0.5))
                             "V" 220)
      (peb-label-with-leader "STEEL JOIST @ 1.5m C/C"
                             (list (+ x0 (* span 0.42)) (- bBot 800.0))
                             (list (+ x0 (* span 0.42)) (* (+ (- bTop bf) jBotF) 0.5))
                             "V" 220)
      (peb-label-with-leader "MAIN BEAM"
                             (list (+ x0 (* span 0.80)) (- bBot 800.0))
                             (list (+ x0 (* span 0.80)) (+ bBot (/ bf 2.0)))
                             "V" 220)))
  (princ))

(defun fr-dp (ox oy sc lx ly) (list (+ ox (* lx sc)) (+ oy (* ly sc))))  ; detail local->world

(defun draw-fr-detail (ox oy sc / x rbx tScale)
  ;;  Zoomed JOIST-CONNECTION detail (owner 15-Jul) for the flat roof, drawn at `sc`x scale at (ox,oy)
  ;;  [oy = the flush beam-top level, ly=0].  This is the section PERPENDICULAR to the main frame, so the
  ;;  MAIN BEAM shows as an I-CUT (550 deep) and the STEEL JOIST (300 deep) frames into the beam WEB with
  ;;  its top FLUSH, seated by a CLIP ANGLE + bolts.  Above: 0.70mm PROFILED DECKING (45mm corrugation,
  ;;  visible here) + 125mm CONCRETE filling the flutes, with rebar.
  ;; ---- 125mm concrete slab (fills flutes) ----
  (setvar "CLAYER" "RCC-COLUMN") (setvar "PLINEWID" 0.0)
  (command "RECTANG" (fr-dp ox oy sc -520 0) (fr-dp ox oy sc 130 170))
  (command "HATCH" "AR-CONC" (* 14.0 sc) 0 "L" "")
  ;; ---- 0.70mm profiled decking (trapezoidal, 45mm) over the beam+joist top — DOUBLE LINE (sheet faces) ----
  (setvar "CLAYER" "CLADDING")
  (foreach dk (list 0.0 13.0)           ; two parallel profiles = the 0.70mm folded sheet thickness
    (setq x -520) (command "PLINE")
    (while (< x 130)
      (command (fr-dp ox oy sc x (+ 45 dk)))
      (command (fr-dp ox oy sc (min 130 (+ x 40)) (+ 45 dk)))
      (command (fr-dp ox oy sc (min 130 (+ x 55)) dk))
      (command (fr-dp ox oy sc (min 130 (+ x 95)) dk))
      (setq x (+ x 100)))
    (command (fr-dp ox oy sc 130 (+ 45 dk))) (command ""))
  ;; ---- MAIN BEAM I-cut (centre), 550 deep ----
  (setvar "CLAYER" "FRAME")
  (command "RECTANG" (fr-dp ox oy sc -100 -25)  (fr-dp ox oy sc 100 0))     ; top flange
  (command "RECTANG" (fr-dp ox oy sc -100 -550) (fr-dp ox oy sc 100 -525))  ; bottom flange
  (command "RECTANG" (fr-dp ox oy sc -13 -525)  (fr-dp ox oy sc 13 -25))    ; web
  ;; ---- STEEL JOIST (frames into the web from the left, flush top), 300 deep ----
  (command "RECTANG" (fr-dp ox oy sc -450 -300) (fr-dp ox oy sc -13 0))     ; joist web face
  (command "LINE" (fr-dp ox oy sc -450 -18)  (fr-dp ox oy sc -13 -18) "")   ; top-flange line
  (command "LINE" (fr-dp ox oy sc -450 -282) (fr-dp ox oy sc -13 -282) "")  ; bottom-flange line
  ;; ---- clip angle (L) on the beam web + 2 bolts ----
  (setvar "CLAYER" "PLATES")
  (command "PLINE" (fr-dp ox oy sc 13 -40) (fr-dp ox oy sc 13 -260)
                   (fr-dp ox oy sc 45 -260) "")                             ; vertical leg on web + seat
  (command "DONUT" 0 (* 14 sc) (fr-dp ox oy sc -40 -90)  "")                ; bolt
  (command "DONUT" 0 (* 14 sc) (fr-dp ox oy sc -40 -210) "")                ; bolt
  ;; ---- rebar dots in the concrete ----
  (setq rbx -470)
  (while (< rbx 90) (command "DONUT" 0 (* 9 sc) (fr-dp ox oy sc rbx 120) "") (setq rbx (+ rbx 90)))
  ;; ---- labels + detail title ----
  (setvar "CLAYER" "TEXT")
  (peb-label-with-leader "125mm R.C.C. SLAB"  (fr-dp ox oy sc 620 260) (fr-dp ox oy sc 60 120)  "H" 260)
  (peb-label-with-leader "0.70mm PROFILED DECKING PANEL" (fr-dp ox oy sc 620 60) (fr-dp ox oy sc 90 22) "H" 260)
  (peb-label-with-leader "STEEL JOIST @ 1.5m C/C" (fr-dp ox oy sc -880 -120) (fr-dp ox oy sc -300 -150) "H" 260)
  (peb-label-with-leader "CLIP ANGLE + BOLTS" (fr-dp ox oy sc -880 -320) (fr-dp ox oy sc -40 -150) "H" 260)
  (peb-label-with-leader "MAIN BEAM (550 DEEP)" (fr-dp ox oy sc 620 -430) (fr-dp ox oy sc 0 -400) "H" 260)
  (txt-bold "MC" (fr-dp ox oy sc -180 -645) (peb-th 'SMALL) 0 "DETAIL - A")
  (txt "MC" (fr-dp ox oy sc -180 -730) (peb-th 'SMALL) 0 "JOIST CONNECTION  (N.T.S.)")
  (princ))

(defun draw-fr-drainage (wid H ht / drnX topY frCT botY)
  ;;  Flat-roof ROOF DRAINAGE OUTLET + DOWNSPOUT (owner 15-Jul): the flat roof drains internally through a
  ;;  drainage outlet (domed grate) cut through the slab + decking, then a downspout down inside the
  ;;  building — NOT the normal PEB eave gutter.  Placed near the LOW (left) side that the fall drains to.
  (setq frCT (fr-col-top H ht))            ; deck / beam-bottom level
  (setq drnX (+ ht 550.0))                 ; drain just INSIDE the left column (drains near the columns)
  (setq topY (+ H 40.0))                   ; slab top at the drain
  (setq botY 1500.0)                       ; downspout runs down to ~1.5 m AFL
  (setvar "CLAYER" "GUTTER") (setvar "PLINEWID" 0.0)
  ;; outlet body cut through the slab + decking
  (command "RECTANG" (list (- drnX 95.0) frCT) (list (+ drnX 95.0) topY))
  ;; domed grate on top
  (command "ARC" (list (- drnX 95.0) topY) (list drnX (+ topY 130.0)) (list (+ drnX 95.0) topY))
  ;; downspout pipe down into the building
  (command "LINE" (list (- drnX 55.0) frCT) (list (- drnX 55.0) botY) "")
  (command "LINE" (list (+ drnX 55.0) frCT) (list (+ drnX 55.0) botY) "")
  (command "LINE" (list (- drnX 55.0) botY) (list (+ drnX 55.0) botY) "")
  ;; labels
  (setvar "CLAYER" "TEXT")
  (peb-label-with-leader "DRAINAGE OUTLET (BY OTHERS)"
                         (list drnX (+ H 800.0)) (list drnX (+ topY 130.0)) "V" 220)   ; short leg, same 220 text
  (peb-label-with-leader "DOWNSPOUT (BY OTHERS)"
                         (list (+ drnX 2600.0) (+ botY 700.0)) (list (+ drnX 55.0) (+ botY 700.0)) "H" 220)
  (princ))

(defun draw-fr-detb (ox oy sc / x seg dk rbx)
  ;;  Zoomed ROOF-DRAINAGE detail (owner 15-Jul, ref screenshot 12) for the flat roof, drawn at `sc`x at
  ;;  (ox,oy) [oy = slab-BOTTOM / deck-top level, ly=0].  A drainage OUTLET (domed strainer + sump) is set
  ;;  into the 125mm slab, the 0.70mm profiled decking is FIELD-CUT to suit, and a DOWNSPOUT drops below —
  ;;  all "by others".  Same drawing language as DETAIL-A so the two details read as a set.
  ;; ---- 125mm concrete slab, cut either side of the outlet ----
  (setvar "CLAYER" "RCC-COLUMN") (setvar "PLINEWID" 0.0)
  (command "RECTANG" (fr-dp ox oy sc -640 0) (fr-dp ox oy sc -90 170))
  (command "HATCH" "AR-CONC" (* 14.0 sc) 0 "L" "")
  (command "RECTANG" (fr-dp ox oy sc 90 0) (fr-dp ox oy sc 640 170))
  (command "HATCH" "AR-CONC" (* 14.0 sc) 0 "L" "")
  ;; ---- 0.70mm profiled decking under the slab, FIELD-CUT at the outlet (gap -90..90) ----
  (setvar "CLAYER" "CLADDING")
  (foreach seg (list (list -640.0 -90.0) (list 90.0 640.0))
    (foreach dk (list 0.0 13.0)          ; two parallel profiles = the 0.70mm folded sheet thickness
      (setq x (car seg)) (command "PLINE")
      (while (< x (cadr seg))
        (command (fr-dp ox oy sc x (+ 45 dk)))
        (command (fr-dp ox oy sc (min (cadr seg) (+ x 40)) (+ 45 dk)))
        (command (fr-dp ox oy sc (min (cadr seg) (+ x 55)) dk))
        (command (fr-dp ox oy sc (min (cadr seg) (+ x 95)) dk))
        (setq x (+ x 100)))
      (command (fr-dp ox oy sc (cadr seg) (+ 45 dk))) (command "")))
  ;; ---- drainage OUTLET set BELOW the concrete level (owner 15-Jul #14): recessed sump + strainer,
  ;;      NOT protruding above the slab; strainer dome top sits at/just under the concrete surface ----
  (setvar "CLAYER" "GUTTER")
  (command "RECTANG" (fr-dp ox oy sc -78 -70) (fr-dp ox oy sc 78 95))                     ; sump body (in slab)
  (command "ARC" (fr-dp ox oy sc -72 95) (fr-dp ox oy sc 0 158) (fr-dp ox oy sc 72 95))   ; strainer dome (recessed)
  (command "LINE" (fr-dp ox oy sc -38 110) (fr-dp ox oy sc -38 150) "")                   ; grate bars
  (command "LINE" (fr-dp ox oy sc 0 100)   (fr-dp ox oy sc 0 158) "")
  (command "LINE" (fr-dp ox oy sc 38 110)  (fr-dp ox oy sc 38 150) "")
  ;; ---- DOWNSPOUT below the sump (clamp band + pipe) ----
  (command "RECTANG" (fr-dp ox oy sc -64 -128) (fr-dp ox oy sc 64 -70))                   ; clamp band
  (command "LINE" (fr-dp ox oy sc -46 -128) (fr-dp ox oy sc -46 -520) "")                 ; pipe walls
  (command "LINE" (fr-dp ox oy sc 46 -128)  (fr-dp ox oy sc 46 -520) "")
  (command "LINE" (fr-dp ox oy sc -46 -520) (fr-dp ox oy sc 46 -520) "")
  ;; ---- rebar dots in the slab (skip the outlet zone) ----
  (setvar "CLAYER" "RCC-COLUMN")
  (setq rbx -590)
  (while (< rbx 620)
    (if (or (< rbx -120) (> rbx 120))
      (command "DONUT" 0 (* 9 sc) (fr-dp ox oy sc rbx 120) ""))
    (setq rbx (+ rbx 90)))
  ;; ---- labels + detail title ----
  (setvar "CLAYER" "TEXT")
  (peb-label-with-leader "DRAINAGE OUTLET (BY OTHERS)"
                         (fr-dp ox oy sc 820 300) (fr-dp ox oy sc 20 150) "H" 260)
  (peb-label-with-leader "FIELD CUT PANEL HOLES\\PTO SUIT DRAINAGE OUTLET"
                         (fr-dp ox oy sc 820 40) (fr-dp ox oy sc 95 25) "H" 260)
  (peb-label-with-leader "DOWNSPOUT (BY OTHERS)"
                         (fr-dp ox oy sc 820 -360) (fr-dp ox oy sc 46 -360) "H" 260)
  (txt-bold "MC" (fr-dp ox oy sc 0 -700) (peb-th 'SMALL) 0 "DETAIL - B")
  (txt "MC" (fr-dp ox oy sc 0 -785) (peb-th 'SMALL) 0 "ROOF DRAINAGE  (N.T.S.)")
  (princ))

(defun draw-petrol-frame (W H ht cb / ovh cx1 cx2 rt colw ppS mid)
  ;;  PETROL PUMP / CNG CANOPY (owner 9-Jul): a near-flat roof carried on 1-2 rows of columns with
  ;;  CANTILEVER overhangs on both sides — the roof slab spans the full width and projects beyond the
  ;;  two (inset) column lines.  Open underneath (no walls).  Section = across the width.
  (setq ovh  (* W 0.22)              ; side cantilever overhang (each side)
        cx1  ovh cx2 (- W ovh)       ; the two column lines (inset from the roof edges)
        rt   (max (* ht 0.8) 250.0)  ; roof slab band depth
        colw (max cb 300.0)
        ppS  180.0                   ; slight fall rise at the high points (matches the deck)
        mid  (/ W 2.0))
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  ;; owner 18-Jul: the FRAME roof band TOP follows the deck's shallow-W SLOPE (high at both edges + centre,
  ;; low at the two valleys over the columns) so the purlins land ON the frame; bottom stays flat.
  (command "PLINE"
    (list 0.0  (+ H ppS)) (list cx1 H) (list mid (+ H ppS)) (list cx2 H) (list W (+ H ppS))
    (list W (- H rt)) (list 0.0 (- H rt)) "C")
  ;; left column (floor up to the roof underside)
  (command "PLINE"
    (list (- cx1 (/ colw 2.0)) 0.0) (list (- cx1 (/ colw 2.0)) (- H rt))
    (list (+ cx1 (/ colw 2.0)) (- H rt)) (list (+ cx1 (/ colw 2.0)) 0.0) "C")
  ;; right column
  (command "PLINE"
    (list (- cx2 (/ colw 2.0)) 0.0) (list (- cx2 (/ colw 2.0)) (- H rt))
    (list (+ cx2 (/ colw 2.0)) (- H rt)) (list (+ cx2 (/ colw 2.0)) 0.0) "C")
)

(defun draw-cc-frame (W H slopeRise ht cb lowAtCol / eL eR ds dt)
  ;;  SINGLE-SIDED CANTILEVER: ONE column on the LEFT (back), rafter cantilevers out to the right
  ;;  (open front).  No right column.  TWO slope types (owner 8-Jul; names corrected 9-Jul -- these
  ;;  are NOT "Falcon/Butterfly 1-wing"; Falcon and Butterfly name only the 2-wing pair):
  ;;   - lowAtCol = nil  → SLOPE AWAY FROM COLUMNS: column-side HIGH, free end LOW (drains at the free end).
  ;;   - lowAtCol = T    → SLOPE TOWARDS COLUMNS:   column-side LOW, free end HIGH (drains at the column).
  (setq eL (if lowAtCol H            (+ H slopeRise))    ; left / column eave
        eR (if lowAtCol (+ H slopeRise) H))              ; right / free-end eave
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  ;; SINGLE-SIDE cantilever web (owner 13-Jul): DEEP ~1100mm at the support, ~500mm at the free
  ;; tip, for a 12 m wing (scaled by the projection W).
  (setq ds (max 450.0 (* (/ W 12000.0) 1100.0)))   ; support web depth
  (setq dt (max 250.0 (* (/ W 12000.0)  500.0)))   ; tip web depth
  ;; STRAIGHT column (owner 13-Jul: cantilever columns are NOT tapered) -- the inner face is
  ;; vertical at x = ht, so the column is a constant-width member; the deep rafter cantilevers off its top.
  (command "PLINE"
    (list 0.0       0.0)                   ; column base outside
    (list 0.0       eL)                    ; eave-left outside (column)
    (list W         eR)                    ; eave-right outside (free end, open)
    (list W         (- eR dt))             ; rafter tip inside-bottom (THIN ~500 at the free end)
    (list ht        (- eL ds))             ; support underside (DEEP ~1100 at the column top)
    (list ht        0.0)                   ; column inside-base -> vertical inner face = STRAIGHT column
    "C")
)

;;  peb-arc3-y — Y on the CIRCULAR arc through 3 points at a query X (UPPER branch — a roof arch bulges up
;;  above its circle centre).  Falls back to a parabola if the 3 points are collinear.  Used to cut the
;;  arched rafter EXACTLY at the connection plate (owner 16-Jul markup 13: rafter ends at the connection,
;;  it does not run out to the eave — only the sheeting overhangs to the gutter).
(defun peb-arc3-y (x1 y1 x2 y2 x3 y3 xq / a b c d e f det cx cy r dd)
  (setq a (- x2 x1) b (- y2 y1) c (- x3 x1) d (- y3 y1))
  (setq e (+ (* a (+ x1 x2)) (* b (+ y1 y2))))
  (setq f (+ (* c (+ x1 x3)) (* d (+ y1 y3))))
  (setq det (* 2.0 (- (* a d) (* b c))))
  (if (equal det 0.0 1e-9)
    (+ y1 (* 4.0 (- y2 y1) (/ (- xq x1) (- x3 x1)) (- 1.0 (/ (- xq x1) (- x3 x1)))))   ; parabola fallback
    (progn
      (setq cx (/ (- (* d e) (* b f)) det)
            cy (/ (- (* a f) (* c e)) det)
            r  (sqrt (+ (expt (- x1 cx) 2) (expt (- y1 cy) 2))))
      (setq dd (- (* r r) (expt (- xq cx) 2)))
      (+ cy (sqrt (max 0.0 dd))))))

(defun draw-acs-frame (W H rise ht cb /
                        midX peakY innerH innerW colTop yoC yiC cutX)
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
  ;; The BOTTOM flange STOPS at the INNER edge of the (extended) rafter connection plate — cutX = cb + 110
  ;; (the plate/stiffener extension), so it does not cross the extended plate (owner 16-Jul markup 19).
  ;; The TOP flange still runs full out to the eave.  yoC/yiC = outer/inner rafter Y at that cut.
  (setq cutX (+ cb 110.0))
  (setq yoC (peb-arc3-y 0.0 H midX peakY W H cutX)
        yiC (- yoC innerH))
  ;; Column TOP drops below the rafter underside by 2 plates + gap so the connection stacks cleanly
  ;; (markup 10): column -> cap plate -> 1mm hairline gap -> rafter plate -> rafter underside (30+30+1).
  (setq colTop (- yiC 61.0))
  ;; LEFT column (rectangular pier) — OUTER face AT x=0 (owner 16-Jul): match the CS convention so the
  ;; shared girt/brick/base-plate/knee routines (all anchored to x=0 / x=W) land OUTSIDE the column.
  (command "RECTANG"
    (list 0.0 0.0)
    (list cb  colTop))
  ;; RIGHT column (rectangular pier) — OUTER face AT x=W
  (command "RECTANG"
    (list (- W cb) 0.0)
    (list W        colTop))
  ;; OUTER (top) curved rafter — FULL: the TOP flange runs right out to the column OUTER flange at the eave
  ;; (owner 16-Jul markup 09): (0, H) → (midX, peakY) → (W, H)
  (command "ARC" (list 0.0 H) (list midX peakY) (list W H))
  ;; INNER (bottom) curved rafter — CUT at the extended plate inner edge (cutX): bottom flange stops there
  (command "ARC" (list cutX yiC) (list midX (- peakY innerH)) (list (- W cutX) yiC))
  ;; Close the TOP flange onto the connection plate at each eave (short vertical end face at the outer flange).
  (command "LINE" (list 0.0 H) (list 0.0 yiC) "")
  (command "LINE" (list W   H) (list W   yiC) "")
)

(defun draw-ams-frame (W H rise ht cb /
                        halfW peakY innerH q1 q3 peakInnerY colTop colTopC
                        hc yoLs yoLc yoRc yoRs lsX lcX rcX rsX)
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
  ;; Quarter-point control: LOW enough that each arch is still RISING as it reaches the centre, so the two
  ;; arches form a clean PEAK (not a depression) at the centre column — owner 16-Jul markup AMS-3.
  (setq peakInnerY (+ H (* 0.72 rise)))
  ;; Rafter CUT points (owner 16-Jul markup 13): each arch ENDS at its connection plates — the OUTER
  ;; springings (cb / W-cb) and the CENTRE column edges (halfW±hc) — not at the eave.  Only sheeting overhangs.
  ;; Bottom flanges STOP at the EXTENDED plate inner edges (±110 past the column flanges) — markup 19.
  (setq hc   (/ cb 2.0)
        lsX  (+ cb 110.0)                     ; left  springing cut
        lcX  (- halfW hc 110.0)               ; left  arch @ centre-col plate edge
        rcX  (+ halfW hc 110.0)               ; right arch @ centre-col plate edge
        rsX  (- W cb 110.0)                   ; right springing cut
        yoLs (peb-arc3-y 0.0 H q1 peakInnerY halfW peakY lsX)
        yoLc (peb-arc3-y 0.0 H q1 peakInnerY halfW peakY lcX)
        yoRc (peb-arc3-y halfW peakY q3 peakInnerY W H rcX)
        yoRs (peb-arc3-y halfW peakY q3 peakInnerY W H rsX))
  ;; Column TOPS drop below the rafter underside by 2 plates + gap (owner 16-Jul markup 10).
  (setq colTop  (- yoLs innerH 62.0)                 ; eave columns: below the springing underside
        colTopC (- yoLc innerH 62.0))                ; centre column: below the centre-edge underside
  ;; LEFT column — OUTER face AT x=0 (owner 16-Jul, matches CS so girts/brick/plates land outside)
  (command "RECTANG"
    (list 0.0 0.0)
    (list cb  colTop))
  ;; CENTER column rises to just below the peak (interior column stays CENTRED on halfW)
  (command "RECTANG"
    (list (- halfW hc) 0.0)
    (list (+ halfW hc) colTopC))
  ;; RIGHT column — OUTER face AT x=W
  (command "RECTANG"
    (list (- W cb) 0.0)
    (list W        colTop))
  ;; LEFT arch OUTER (FULL — top flange runs to the eave outer flange and over the centre column):
  (command "ARC" (list 0.0 H) (list q1 peakInnerY) (list halfW peakY))
  ;; LEFT arch INNER (CUT at lsX .. lcX — bottom flange stops at the extended connection plates)
  (command "ARC" (list lsX (- yoLs innerH)) (list q1 (- peakInnerY innerH)) (list lcX (- yoLc innerH)))
  ;; RIGHT arch OUTER (FULL): (halfW, peakY) → (q3, peakInnerY) → (W, H)
  (command "ARC" (list halfW peakY) (list q3 peakInnerY) (list W H))
  ;; RIGHT arch INNER (CUT at rcX .. rsX)
  (command "ARC" (list rcX (- yoRc innerH)) (list q3 (- peakInnerY innerH)) (list rsX (- yoRs innerH)))
  ;; Close TOP flanges onto the plates at the eaves (x=0/W).  Centre: bottom flanges meet the extended plate.
  (command "LINE" (list 0.0 H) (list 0.0 (- yoLs innerH)) "")
  (command "LINE" (list W   H) (list W   (- yoRs innerH)) "")
)

;;  ── Butterfly / Falcon cantilever web-depth (shared, owner 18-Jul) ──────────────────────────────
;;  ONE source for the tapered-wing depth so the FRAME outline (draw-bf-frame / draw-falcon2-frame)
;;  and the CONNECTION-PLATE stack (BF plate dispatch) can never drift apart.
;;  - Deepened for VISUALIZATION: the mast reads as a real deep haunch, not a hairline.
;;  - VARIES with span: a smaller canopy gets a proportionally shallower wing (W/24000 factor).
;;  - CAPPED at 42% of the clear height H: if the canopy is LOW/SHORT the haunch can't exceed the
;;    column it lands on (owner 18-Jul: "should vary in case depth or height decreases").
(defun bf-mast-depth (W H / d)
  (setq d (max 600.0 (* (/ W 24000.0) 1100.0)))   ; span-scaled DEEP mast web (was 700 @ 24m)
  (min d (* 0.42 H)))                               ; short-canopy guard: never deeper than 0.42*C.H
(defun bf-tip-depth (W)
  (max 350.0 (* (/ W 24000.0) 600.0)))             ; span-scaled THIN tip web (was 400 @ 24m)

;;  peb-bf-valley-x — the butterfly/canopy VALLEY (or Falcon peak) position, mm from the LEFT eave.  Owner
;;  18-Jul markup 15: driven by the IF "Cantilever span" (one wing), serialized as BP_CANT_SPAN — the
;;  ridgeOffset field is intentionally hidden for canopies.  Blank / degenerate => centred (W/2); clamped
;;  2% off each eave.  (BF is excluded from the CS/MS/RC rise-recompute, so `rise` stays central and the
;;  per-wing slope in draw-bf-frame is the ENTERED roof slope on BOTH wings — 1:10, 1:13, 1:15, anything.)
(defun peb-bf-valley-x (data W / v)
  (setq v (MSPL-Get-Num data "BP_CANT_SPAN"))
  (if (and v (> v (* W 0.02)) (< v (* W 0.98))) v (/ W 2.0)))

(defun draw-bf-frame (W H rise ht cb intColW valleyX valleyH / cx de dp halfCol slope leftRise rightRise vy)
  ;;  Butterfly: CENTER column only, NO side columns.  Two rafters slope UP-OUTWARD from the valley to the
  ;;  high side eaves.  Owner 18-Jul markup 15: the valley (and column) can be OFF-CENTRE (valleyX) — both
  ;;  wings keep the SAME fall, so the LONGER wing's tip sits HIGHER (leftRise / rightRise differ).
  ;;  Wings are TAPERED (owner 13-Jul): DEEP at the mast (dp) and THIN at the free tips (de).
  (setq cx (if valleyX valleyX (/ W 2.0)))
  ;; BP_VALLEY_HEIGHT (owner 21-Jul): explicit valley (low centre) height in mm; blank/0 ⇒ vy = H (today's
  ;; behaviour — valley at eave level). All roof/haunch/eave levels below are measured from vy.
  (setq vy (if (and valleyH (> valleyH 0.0)) valleyH H))
  (setq intColW (max intColW 400.0))
  (setq halfCol (/ intColW 2.0))
  (setq slope     (/ rise (/ W 2.0)))          ; fall slope (rise per run) — identical on both wings
  (setq leftRise  (* slope cx))                ; longer wing -> higher tip
  (setq rightRise (* slope (- W cx)))
  ;; TWO-side cantilever web (owner 18-Jul): deepened for visualization + span-scaled + C.H-capped
  ;; via the shared bf-mast-depth / bf-tip-depth helpers (see above).
  (setq dp (bf-mast-depth W H))   ; mast (deep) web depth
  (setq de (bf-tip-depth  W))     ; tip (thin) web depth

  ;; Center column (rectangular) at the valley — TOPS OUT below the rafter underside (H-dp) by the 2-plate
  ;; connection stack (owner 16-Jul markup 2), so the two wings land on a connection-plate pair on the top.
  (setvar "CLAYER" "FRAME")
  (command "RECTANG"
    (list (- cx halfCol) 0.0)
    (list (+ cx halfCol) (- vy dp 62.0)))

  ;; Frame outline: butterfly (V top), underside tapers de (tip) -> dp (mast); tips at their own rises.
  ;; All levels measured from vy (valley Y = BP_VALLEY_HEIGHT, or H when unset).
  (command "PLINE"
    (list 0.0       (+ vy leftRise))            ; LEFT high eave outside (tip top)
    (list cx        vy)                          ; VALLEY (lowest roof point, under the column)
    (list W         (+ vy rightRise))           ; RIGHT high eave outside (tip top)
    (list W         (+ vy rightRise (- 0 de)))  ; right tip UNDERSIDE (thin)
    (list (+ cx halfCol) (- vy dp))             ; mast right haunch (column top, deep)
    (list (- cx halfCol) (- vy dp))             ; mast left haunch (column top, deep)
    (list 0.0       (+ vy leftRise (- 0 de)))   ; left tip UNDERSIDE (thin)
    "C")
)

(defun draw-falcon2-frame (W H rise ht cb intColW / cx de dp halfCol)
  ;;  FALCON (2 wings) — CENTER column, PEAK at centre, two wings slope DOWN-OUTWARD to the LOW
  ;;  side eaves (drains at the free ends).  The vertical MIRROR of the Butterfly (owner 8-Jul).
  ;;  TWO-side cantilever web (owner 18-Jul): DEEP mast, THIN tips, via the shared bf-mast-depth /
  ;;  bf-tip-depth helpers (deepened for visualization, span-scaled, C.H-capped).
  (setq cx (/ W 2.0) intColW (max intColW 400.0))
  (setq halfCol (/ intColW 2.0))
  (setq dp (bf-mast-depth W H))   ; mast (deep) web depth
  (setq de (bf-tip-depth  W))     ; tip (thin) web depth
  ;; Center column — TOPS OUT below the rafter underside (peak-dp) by the 2-plate connection stack, so the
  ;; two wings land on a horizontal connection-plate pair on the column top (owner 16-Jul markup 2).
  (setvar "CLAYER" "FRAME")
  (command "RECTANG"
    (list (- cx halfCol) 0.0)
    (list (+ cx halfCol) (- (+ H rise) dp 62.0)))
  ;; Frame outline: peak top; underside tapers de (tip) -> dp (mast)
  (command "PLINE"
    (list 0.0       H)                            ; LEFT low eave (tip top)
    (list cx        (+ H rise))                   ; PEAK (centre top, highest)
    (list W         H)                            ; RIGHT low eave (tip top)
    (list W         (- H de))                     ; right tip UNDERSIDE (thin ~400)
    (list (+ cx halfCol) (+ H rise (- 0 dp)))     ; mast right haunch (column top, deep ~700)
    (list (- cx halfCol) (+ H rise (- 0 dp)))     ; mast left haunch (column top, deep ~700)
    (list 0.0       (- H de))                     ; left tip UNDERSIDE (thin ~400)
    "C")
)

(defun draw-lt-frame (W H slopeRise ht cb / wallW midDlt wallTopY beamBotY hLx ltTP)
  ;;  Lean-To frame: one PEB column at LEFT (low side),
  ;;  existing masonry/concrete wall at RIGHT (high side).
  ;;  Sloped rafter goes from low column up to the existing wall.
  (setq wallW 230.0)       ; existing wall thickness (mm)

  ;; Existing wall on RIGHT: owner 15-Jul — BRICK MASONRY body + an RCC BEAM (bond beam) at the TOP where
  ;; the steel rafter bears and the CHEMICAL ANCHORS land (you anchor into the RCC beam, not the brick).
  (setq wallTopY (+ H slopeRise (* 500 *PEB-TEXT-SCALE*)))
  (setq beamBotY (- (- (+ H slopeRise) ht) 200.0))        ; RCC beam bottom = just below the rafter bearing
  ;; brick masonry body (FFL -> beam underside)
  (setvar "CLAYER" "BRICK-WALL")
  (command "RECTANG" (list W 0.0) (list (+ W wallW) beamBotY))
  (command "HATCH" "BRICK" 150 0 "L" "")
  ;; RCC bond beam at the top (concrete)
  (setvar "CLAYER" "RCC-COLUMN")
  (command "RECTANG" (list W beamBotY) (list (+ W wallW) wallTopY))
  (command "HATCH" "AR-CONC" 60 0 "L" "")

  ;; PEB frame — owner 15-Jul: a SINGLE-SLOPE frame (same rafter as stype SS) with the LEFT steel column
  ;; and the RIGHT end BEARING on the existing RCC wall (no right steel column).  Rafter is HAUNCHED
  ;; (deep = ht) at the left knee AND the wall bearing, taper down to THIN (midD) over hLx, then runs
  ;; STRAIGHT at depth midD across the middle -- identical to Single Slope.
  (setvar "CLAYER" "FRAME")
  (setvar "PLINEWID" 0.0)
  (setq ltTP (ss-taper-params (list 0.0 W) W slopeRise ht))
  (setq midDlt (car ltTP) hLx (cadr ltTP))
  (command "PLINE"
    (list 0.0      0.0)                         ; bottom-left outside (left steel column base)
    (list 0.0      H)                           ; low eave top (left)
    (list W        (+ H slopeRise))             ; high eave top — rafter top ends at the wall
    (list (- W 45.0) (- (+ H slopeRise) ht))    ; RIGHT knee/bearing bottom (DEEP ht) at the wall face
    (list (- (- W 45.0) hLx) (- (ss-topY (- (- W 45.0) hLx) H slopeRise W) midDlt))  ; right haunch end (THIN)
    (list (+ ht hLx)         (- (ss-topY (+ ht hLx) H slopeRise W) midDlt))          ; left haunch end (THIN) — straight thin between
    (list ht       (- H ht))                    ; left knee (DEEP ht)
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
  ;; Anchor bolts: PINNED (default) = 2 donuts at 25%/75%; FIXED = 4 donuts (moment base) at 14/38/62/86%.
  ;; Count comes from *BASE-BOLTS* (set per column-group by the callers from BP_EXT/INT_BASE_COND); nil ⇒ 2.
  (if (and *BASE-BOLTS* (>= *BASE-BOLTS* 4))
    (foreach f '(0.14 0.38 0.62 0.86)
      (command "DONUT" 0 (* 2 boltR) (list (+ xLeft (* (- xRight xLeft) f)) boltY) ""))
    (progn
      (command "DONUT" 0 (* 2 boltR) (list (+ xLeft (* (- xRight xLeft) 0.25)) boltY) "")
      (command "DONUT" 0 (* 2 boltR) (list (+ xLeft (* (- xRight xLeft) 0.75)) boltY) "")))
)

(defun draw-base-plates (W cb ep / boltR)
  ;;  Base plates for the LEFT and RIGHT outer columns (CS / SS / etc.).
  ;;  Each plate is RAISED above FFL on a small concrete pedestal,
  ;;  with anchor bolts visible through the plate.
  (setq boltR (* 25 *PEB-TEXT-SCALE*))
  (setq *BASE-BOLTS* (if *BASE-BOLTS-EXT* *BASE-BOLTS-EXT* 2))   ; both are exterior main columns
  (draw-base-plate-at 0.0     cb        ep boltR)   ; LEFT
  (draw-base-plate-at (- W cb) W        ep boltR)   ; RIGHT
)

;;  peb-conn-plate-pair — the STANDARD rafter-column connection: an upper (rafter) end plate
;;  over a lower (column) cap plate, bolted at the interface.  Owner 13-Jul: the detail is common
;;  to every frame; only LOCATION and SIZE change.  Drawn as a horizontal stack centred at cx with
;;  the plate TOP at topY (= column top / rafter underside), reaching halfSpan each side.
(defun peb-conn-plate-pair (cx topY halfSpan ep nBolt / boltR i bx loBot stH stW xl xr)
  (setvar "CLAYER" "PLATES")
  (setq boltR (* 25 *PEB-TEXT-SCALE*))
  ;; CP RULE: TWO SOLID *PEB-CP-THK* plates with a *PEB-CP-GAP* hairline seam, NO bolts, GP gussets both flanges.
  (setq ep *PEB-CP-THK* stH 110.0 stW 100.0)
  (setq loBot (- topY ep *PEB-CP-GAP* ep))
  (setq xl (- cx halfSpan) xr (+ cx halfSpan))
  (peb-solid-quad (list xl (- topY ep)) (list xr (- topY ep)) (list xl topY) (list xr topY))          ; rafter plate (SOLID)
  (peb-solid-quad (list xl loBot) (list xr loBot) (list xl (- topY ep *PEB-CP-GAP*)) (list xr (- topY ep *PEB-CP-GAP*))) ; column plate (SOLID)
  ;; GP gussets at BOTH flanges: TOP (above the upper plate) and BOTTOM (below the lower plate), each outer edge.
  (draw-stiff-bot xl loBot stW stH  1)
  (draw-stiff-bot xr loBot stW stH -1)
  (draw-stiff-top xl topY stW stH  1)
  (draw-stiff-top xr topY stW stH -1))

;;  draw-valley-col-plates — the MULTI-GABLE VALLEY connection detail, extracted so BOTH the MG
;;  gable-boundary column AND the Butterfly/Falcon canopy valley reuse the SAME code (owner 18-Jul
;;  markup 14: "copy the code from Multi-Gable").  Two vertical end plates flank EACH column flange
;;  face (4 plates total), 3 bolts per side, a web stiffener across the plate bottom.  The plates run
;;  from plateBot (just below the rafter underside / column top) up to plateTop (just above the rafter
;;  top flange at the valley), so they bolt the two wing/gable rafter ends to the column and each other.
(defun draw-valley-col-plates (x plateBot plateTop / boltR vHalfCol vPThk
                                vL1xL vL1xR vL2xL vL2xR vR1xL vR1xR vR2xL vR2xR
                                vMidY vBoltY1 vBoltY2 vBoltY3)
  (setvar "CLAYER" "PLATES")
  (setq boltR (* 25 *PEB-TEXT-SCALE*))
  ;; CP RULE: SOLID *PEB-CP-THK* plates, *PEB-CP-GAP* hairline seam, NO bolts, GP gussets both flanges.
  (setq vHalfCol 200.0 vPThk *PEB-CP-THK*)     ; 400 mm column body, CP-rule end plates
  (setq vL1xR (- x vHalfCol) vL1xL (- vL1xR vPThk)           ; LEFT flange face pair (inner plate at column)
        vL2xR (- vL1xL *PEB-CP-GAP*) vL2xL (- vL2xR vPThk)   ; outer (wing) plate, hairline seam away
        vR1xL (+ x vHalfCol) vR1xR (+ vR1xL vPThk)           ; RIGHT flange face pair
        vR2xL (+ vR1xR *PEB-CP-GAP*) vR2xR (+ vR2xL vPThk))
  ;; LEFT pair — TWO SOLID plates
  (peb-solid-quad (list vL1xL plateBot) (list vL1xR plateBot) (list vL1xL plateTop) (list vL1xR plateTop))
  (peb-solid-quad (list vL2xL plateBot) (list vL2xR plateBot) (list vL2xL plateTop) (list vL2xR plateTop))
  ;; RIGHT pair — TWO SOLID plates
  (peb-solid-quad (list vR1xL plateBot) (list vR1xR plateBot) (list vR1xL plateTop) (list vR1xR plateTop))
  (peb-solid-quad (list vR2xL plateBot) (list vR2xR plateBot) (list vR2xL plateTop) (list vR2xR plateTop))
  ;; Column-web stiffener at plate bottom
  (command "RECTANG" (list (- x vHalfCol) (- plateBot 20.0)) (list (+ x vHalfCol) plateBot))
  ;; GP gussets — FILLED SOLID at BOTH the top flange (plateTop) AND bottom flange (plateBot), on the OUTER
  ;; edge of each flange pair (one leg on the plate, one on the flange).
  (draw-rc-gusset vL2xL (- plateTop 50.0) plateTop 100.0 -1 0.0)
  (draw-rc-gusset vR2xR (- plateTop 50.0) plateTop 100.0  1 0.0)
  (draw-rc-gusset vL2xL (+ plateBot 50.0) plateBot 100.0 -1 0.0)
  (draw-rc-gusset vR2xR (+ plateBot 50.0) plateBot 100.0  1 0.0)
  (princ))

;;  peb-conn-plate-depth — a connection / splice plate SIZED TO THE MEMBER DEPTH (owner 14-Jul): a
;;  vertical bolted end-plate centred at cx spanning the rafter from its BOTTOM flange (yBot) to its
;;  TOP flange (yTop), EXTENDED 100 mm BEYOND both flanges (so it is never "small / in the air").
;;  plateT = plate half-thickness drawn each side of the seam; bolts run down the web line.
(defun peb-conn-plate-depth (cx yBot yTop plateT nBolt / boltR ext pB pT i by yb yt hg)
  (setvar "CLAYER" "PLATES")
  (setq boltR (* 18 *PEB-TEXT-SCALE*))
  (setq ext *PEB-CP-EXT*)                    ; extend beyond top AND bottom flanges
  (setq hg  (/ *PEB-CP-GAP* 2.0))            ; half hairline seam
  (setq yb (min yBot yTop) yt (max yBot yTop))
  (setq pB (- yb ext) pT (+ yt ext))
  ;; CP RULE: TWO SOLID plates with a *PEB-CP-GAP* hairline seam, NO bolts.
  (peb-solid-quad (list (- cx plateT) pB) (list (- cx hg) pB)
                  (list (- cx plateT) pT) (list (- cx hg) pT))   ; plate left of seam (SOLID)
  (peb-solid-quad (list (+ cx hg) pB) (list (+ cx plateT) pB)
                  (list (+ cx hg) pT) (list (+ cx plateT) pT))   ; plate right of seam (SOLID)
  ;; GP gussets — FILLED SOLID at TOP (yt) and BOTTOM (yb) flanges, on both plate outer edges.
  (draw-rc-gusset (- cx plateT) yt (+ yt ext) 100.0 -1 0.0)
  (draw-rc-gusset (+ cx plateT) yt (+ yt ext) 100.0  1 0.0)
  (draw-rc-gusset (- cx plateT) yb (- yb ext) 100.0 -1 0.0)
  (draw-rc-gusset (+ cx plateT) yb (- yb ext) 100.0  1 0.0)
  (princ))

;;  draw-knee-hplate — the ROTATED (horizontal) column-rafter KNEE connection (owner 14-Jul, STRICT):
;;  the moment joint LAID at the corner — a base plate welded to the RAFTER BOTTOM sitting on the
;;  COLUMN TOP, bolted along a HORIZONTAL seam (this is the vertical splice detail rotated 90 deg).
;;    xL..xR  = horizontal span of the plate (the column/rafter web depth in section) + 100 ext each end
;;    ySeam   = the column-top / rafter-underside elevation (the bolt line)
;;    plateT  = each plate's thickness (drawn above AND below the seam)
;;    rcc = T  -> ROOF-ON-RCC: ONE base plate on the rafter bottom sitting on the RCC top, with anchor
;;               bolts hooking DOWN into the concrete (no steel column-cap plate).
;;    rcc = nil-> STEEL column: column-top plate BELOW the seam + rafter-bottom plate ABOVE it, bolted.
;;  dirOut selects which END carries the stiffener triangles (owner 14-Jul, "Sample @ Haunch @ Eave —
;;  Stiffener on Outer Side"): -1 = OUTER is the LEFT end (x0), +1 = OUTER is the RIGHT end (x1),
;;  nil = both ends (interior column under a continuous rafter).
(defun draw-knee-hplate (xL xR ySeam plateT nBolt rcc dirOut / boltR ext i bx x0 x1 topY loBot stW stH gH stTop gap)
  (setvar "CLAYER" "PLATES")
  (setq ext 100.0)
  (setq x0 (- xL ext) x1 (+ xR ext))
  (if rcc
    ;; RCC ("Roofing System"): ONE base plate welded to the rafter bottom, sitting on the RCC column
    ;; top, with anchor bolts hooking DOWN into the concrete.
    (progn
      (setq boltR (* 18 *PEB-TEXT-SCALE*) plateT 30.0)   ; 30mm base plate
      (peb-solid-quad (list x0 ySeam) (list x1 ySeam)
                      (list x0 (+ ySeam plateT)) (list x1 (+ ySeam plateT)))   ; SOLID base plate
      (setq i 1)
      (while (<= i nBolt)
        (setq bx (+ x0 (* (/ (float i) (1+ nBolt)) (- x1 x0))))
        (command "DONUT" 0 (* boltR 2) (list bx ySeam) "")
        (command "LINE" (list bx ySeam) (list bx (- ySeam (* plateT 4.0))) "")
        (setq i (1+ i))))
    ;; STEEL: the STANDARD I-shape connection ROTATED to the corner — upper (rafter-bottom) plate +
    ;; lower (column-top) plate, bolts along the seam, and stiffener triangles on the OUTER side.
    (progn
      ;; STANDING RULE: REAL 20mm plates, 1mm hairline gap between them, NO bolts shown.  Two SOLID plates
      ;; straddling the seam — upper welded to the rafter bottom (sits AT the column-rafter junction),
      ;; lower on the column top.
      (setq plateT *PEB-CP-THK* gap *PEB-CP-GAP* stW 100.0 stH 110.0)   ; CP rule: 20mm plates, hairline gap
      ;; EAVE knee (dirOut ±1): the 2 plates STRADDLE the seam (rafter underside = column top).
      ;; INTERIOR column (dirOut nil): the RAFTER (upper) plate top is FLUSH with the rafter bottom flange
      ;; (= ySeam) and the COLUMN (lower) plate sits below the gap (owner 14-Jul).
      (if dirOut
        (setq topY (+ ySeam (/ gap 2.0) plateT) loBot (- ySeam (/ gap 2.0) plateT))
        (setq topY ySeam                        loBot (- ySeam plateT gap plateT)))
      (peb-solid-quad (list x0 (- topY plateT)) (list x1 (- topY plateT))
                      (list x0 topY) (list x1 topY))                            ; rafter plate (SOLID)
      (peb-solid-quad (list x0 loBot) (list x1 loBot)
                      (list x0 (+ loBot plateT)) (list x1 (+ loBot plateT)))    ; column plate (SOLID)
      ;; INTERIOR column: GP gussets at BOTH flanges (top of upper plate AND bottom of lower plate), both ends.
      (if (null dirOut)
        (progn
          (draw-stiff-bot (+ x0 ext) loBot stW stH -1)
          (draw-stiff-bot (- x1 ext) loBot stW stH  1)
          (draw-stiff-top (+ x0 ext) topY stW stH -1)
          (draw-stiff-top (- x1 ext) topY stW stH  1)))
      ;; STIFFENER = a LINE extending FROM THE RAFTER OUTER (TOP) FLANGE down to the connection plate (owner
      ;; 14-Jul, "stiffeners will line extend from rafter outer flange — do as marked").  A VERTICAL
      ;; stiffener sits on the OUTER flange (x0+ext / x1-ext) rising all the way to the rafter OUTER flange,
      ;; plus the DIAGONAL gusset from the plate INNER end up to that same top point — the two form the knee
      ;; triangle on the OUTSIDE.  The caller publishes *PEB-KNEE-TOPY* = the rafter top-flange Y at the eave
      ;; (= H); without it, fall back to a member-depth rise (plate span minus the ext).  Eave knees only.
      (setq gH (- (- x1 x0) (* 2.0 ext)))
      (setq stTop (if (and *PEB-KNEE-TOPY* (> *PEB-KNEE-TOPY* (+ topY gH))) *PEB-KNEE-TOPY* (+ topY gH)))
      ;; WHICH MEMBER GETS WHICH (owner 25-Aug, refining the same day's first note):
      ;; "On Rafters Stiffeners are okay" + "on Columns the Stiffeners must be on
      ;; the outer flanges".  In this detail the two plates straddle a horizontal
      ;; seam at the column top / rafter underside, so:
      ;;    topY  = top of the UPPER plate  -> the RAFTER side  -> BOTH flanges
      ;;    loBot = bottom of the LOWER plate -> the COLUMN side -> OUTER flange only
      ;; Hence the mirrored inner stiffener is drawn for the rafter and NOT for the
      ;; column.  The outer pair is the 14-Jul arrangement, unchanged.
      ;; The vertical + diagonal stay OUTSIDE only: those two are the knee GUSSET
      ;; triangle, which has to land on the rafter OUTER flange — there is no inner
      ;; counterpart for them to rise to.
      (if (and dirOut (< dirOut 0))             ; LEFT eave knee: outer flange at x0+ext, inner end x1
        (progn
          (draw-stiff-top (+ x0 ext) topY stW stH -1)   ; small stiffener OUTSIDE the top flange
          (draw-stiff-bot (+ x0 ext) loBot stW stH -1)  ; small stiffener OUTSIDE the bottom flange
          (draw-stiff-top (- x1 ext) topY stW stH  1)   ; RAFTER: mirror on the INNER top flange
          ;; NO inner stiffener on loBot — the COLUMN carries the outer flange only.
          (command "LINE" (list (+ x0 ext) topY) (list (+ x0 ext) stTop) "")   ; vertical stiffener up to rafter outer flange
          (command "LINE" (list x1 topY)         (list (+ x0 ext) stTop) "")))  ; diagonal gusset
      (if (and dirOut (> dirOut 0))             ; RIGHT eave knee: outer flange at x1-ext, inner end x0
        (progn
          (draw-stiff-top (- x1 ext) topY stW stH 1)    ; small stiffener OUTSIDE the top flange
          (draw-stiff-bot (- x1 ext) loBot stW stH 1)   ; small stiffener OUTSIDE the bottom flange
          (draw-stiff-top (+ x0 ext) topY stW stH -1)   ; RAFTER: mirror on the INNER top flange
          ;; NO inner stiffener on loBot — the COLUMN carries the outer flange only.
          (command "LINE" (list (- x1 ext) topY) (list (- x1 ext) stTop) "")   ; vertical stiffener up to rafter outer flange
          (command "LINE" (list x0 topY)         (list (- x1 ext) stTop) "")))))  ; diagonal gusset
  (setq *PEB-KNEE-TOPY* nil)   ; consume the per-knee top-flange hint so it never leaks to the next frame
  (princ))

;;  draw-cant-vplate — CANTILEVER column-rafter connection, owner 18-Jul: apply the BUTTERFLY (Multi-Gable
;;  valley) plate detail — TWO plates bolted at the seam: one on the SIDE OF THE COLUMN (left of the seam)
;;  and one on the BACKSIDE OF THE WING (right of the seam), each extended 100 mm past both flanges, with
;;  3 bolts down the seam and stiffener triangles top + bottom.  (Matches draw-valley-col-plates' outline
;;  plates + donut bolts, but as the one-sided cantilever pair.)  plateT/nBolt kept for call compatibility.
(defun draw-cant-vplate (cx yBot yTop plateT nBolt slope / vPThk gap ext pB pT
                          xCol1 xCol2 xWing1 xWing2 stW stH)
  (setvar "CLAYER" "PLATES")
  ;; CP STANDING RULE: two SOLID plates, *PEB-CP-THK* thick, *PEB-CP-GAP* hairline seam, NO bolts, each
  ;; extended *PEB-CP-EXT* past both flanges, with SMALL GP gusset triangles at BOTH flanges. (Canopy/valley:
  ;; the plates sit on the SIDE of the column — this pair is the side-mounted CP.)
  (if (not slope) (setq slope 0.0))   ; canopy beam flange slope (0 = horizontal); the GP flange leg follows it
  (setq vPThk *PEB-CP-THK* gap *PEB-CP-GAP* ext *PEB-CP-EXT*)
  (setq pB (- (min yBot yTop) ext) pT (+ (max yBot yTop) ext))
  (setq xCol2  (- cx (/ gap 2.0)) xCol1  (- xCol2 vPThk)    ; COLUMN-side plate (left of seam)
        xWing1 (+ cx (/ gap 2.0)) xWing2 (+ xWing1 vPThk))  ; WING-back plate  (right of seam)
  (peb-solid-quad (list xCol1  pB) (list xCol2  pB) (list xCol1  pT) (list xCol2  pT))   ; plate on the SIDE OF THE COLUMN
  (peb-solid-quad (list xWing1 pB) (list xWing2 pB) (list xWing1 pT) (list xWing2 pT))   ; plate on the BACKSIDE OF THE WING
  ;; GP gusset triangles — FILLED SOLID within the *PEB-CP-EXT* extension, at BOTH the top flange (yTop→pT)
  ;; AND the bottom flange (yBot→pB), on the outer edge of each plate (one leg on the plate, one on flange).
  (setq stW *PEB-CP-EXT*)
  ;; GP = SMALL solid stiffener triangles tying each CP plate to its flange (column flange + rafter/beam
  ;; flange), the flange leg following the flange SLOPE (flange corner y shifted by ±stW*slope).  Drawn with
  ;; peb-solid-quad (plot-safe) — one corner on the CP, one corner ON the flange line.
  (peb-solid-quad (list (- xCol1 stW) (- yTop (* stW slope))) (list xCol1 yTop) (list xCol1 pT) (list xCol1 pT))   ; col plate, TOP
  (peb-solid-quad (list xWing2 yTop) (list (+ xWing2 stW) (+ yTop (* stW slope))) (list xWing2 pT) (list xWing2 pT)) ; wing plate, TOP
  (peb-solid-quad (list (- xCol1 stW) (- yBot (* stW slope))) (list xCol1 yBot) (list xCol1 pB) (list xCol1 pB))   ; col plate, BOTTOM
  (peb-solid-quad (list xWing2 yBot) (list (+ xWing2 stW) (+ yBot (* stW slope))) (list xWing2 pB) (list xWing2 pB)) ; wing plate, BOTTOM
  (princ))

;;  peb-cw-one — draw ONE catwalk as OUTER LINES ONLY at a column (owner 14-Jul): a narrow walkway deck
;;  projecting from the column + a handrail (two posts + top & mid rail).  dir = +1 projects to +x, -1 to
;;  -x.  Deck top at yWalk; deck a thin band; rail ~1050 high.  No grating hatch — outline only.
(defun peb-cw-one (xc yWalk cwW railH dir / xo)
  (setq xo (+ xc (* dir cwW)))                        ; outer (free) edge of the walkway
  (setvar "CLAYER" "FRAME")
  ;; walkway deck — thin outline band
  (command "PLINE" (list xc (- yWalk 60.0)) (list xo (- yWalk 60.0))
                   (list xo yWalk) (list xc yWalk) "C")
  ;; handrail — outer post, inner post (at the column), top rail, mid rail
  (command "LINE" (list xo yWalk) (list xo (+ yWalk railH)) "")
  (command "LINE" (list xc yWalk) (list xc (+ yWalk railH)) "")
  (command "LINE" (list xc (+ yWalk railH)) (list xo (+ yWalk railH)) "")
  (command "LINE" (list xc (+ yWalk (* railH 0.5))) (list xo (+ yWalk (* railH 0.5))) "")
  (princ))

;;  peb-draw-catwalk — CATWALK in the cross-section (owner 14-Jul, ref manual §Glossary/Ch.11): a narrow
;;  grated walkway with handrail, its framing connected to the rigid-frame COLUMNS, INSIDE or OUTSIDE the
;;  shell.  STRICT: draw the OUTER LINES ONLY.  Driven by CW_ keys (blank => nothing drawn):
;;    CW_TOGGLE   = Yes/No
;;    CW_LOCATION = Inside | Outside   (side of the column the walkway projects)
;;    CW_HEIGHT   = walkway level above FFL (mm; default 60% of clear height)
;;    CW_WIDTH    = walkway width (mm; default 750)
;;    CW_SIDE     = Both | Left | Right (which eave column; default Both)
;;  Placed at the eave columns (first/last of cols).  Left column: Inside=+x, Outside=-x; right mirror.
(defun peb-draw-catwalk (data wid cols H ht / loc cwH cwW side yWalk lc rc railH dirL dirR)
  (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CW_TOGGLE") "")) "YES")
    (progn
      (setq loc  (strcase (peb-tb-or (MSPL-Get-Str data "CW_LOCATION") "INSIDE")))
      (setq side (strcase (peb-tb-or (MSPL-Get-Str data "CW_SIDE") "BOTH")))
      (setq cwH  (MSPL-Get-Num data "CW_HEIGHT"))
      (if (or (null cwH) (<= cwH 0.0)) (setq cwH (* 0.60 (- H ht))))
      (setq cwW  (MSPL-Get-Num data "CW_WIDTH"))
      (if (or (null cwW) (<= cwW 0.0)) (setq cwW 750.0))
      (setq railH 1050.0 yWalk cwH lc (car cols) rc (last cols))
      ;; project direction: OUTSIDE = away from the shell; INSIDE = into the shell
      (setq dirL (if (= loc "OUTSIDE") -1 1)          ; left column
            dirR (if (= loc "OUTSIDE")  1 -1))        ; right column (mirror)
      (if (member side '("BOTH" "LEFT"))  (peb-cw-one lc yWalk cwW railH dirL))
      (if (member side '("BOTH" "RIGHT")) (peb-cw-one rc yWalk cwW railH dirR))
      ;; label with a leader to the deck
      (setvar "CLAYER" "TEXT")
      (peb-label-with-leader "CATWALK (OUTER LINE)"
        (list (+ lc (* dirL (+ cwW 1400.0))) (+ yWalk 300.0))
        (list (+ lc (* dirL (/ cwW 2.0)))    yWalk)
        "H" 200)))
  (princ))

;;  draw-arch-conn-plates — connection plates for the ARCHED types (owner 13-Jul): a plate pair at
;;  each column-arch SPRINGING, plus mid-arch SPLICE plate pairs every <=12 m along the arch (the arch
;;  is a continuous member spliced to <=12 m shipping pieces).  Splice Y follows the parabolic arch.
;;  peb-arch-knee — the arched-frame column-arch connection (owner 16-Jul, markup 10): TWO SOLID plates
;;  ONLY — a plate on the RAFTER BOTTOM (top flush with the arch underside) + a COLUMN-CAP plate below a
;;  1 mm hairline gap — with NO diagonal stiffener/gusset (curved frames drop the knee triangle).  The steel column
;;  tops out at capBot (= rafterBotY - 62), sitting cleanly BELOW the plates (draw-acs/ams-frame match this).
;;  peb-arch-knee — arched-frame column/rafter connection (owner 16-Jul markups 10/13/16).  Two SOLID plates
;;  (rafter + column-cap) spanning the column with NO overhang into the span (markup 16: DO NOT extend), plus
;;  a SOLID stiffener plate welded between the column INNER flange and the connection plate, pointing INTO the
;;  column.  dirIn picks the inner flange: +1 = LEFT knee (inner flange at x1), -1 = RIGHT knee (inner flange
;;  at x0), 0 = CENTRE column (both edges are inner flanges).
(defun peb-arch-knee (xL xR rafterBotY dirIn / x0 x1 plateT gap gw rafBot rafTop capTop capBot stH px0 px1)
  (setvar "CLAYER" "PLATES")
  (setq plateT *PEB-CP-THK* gap *PEB-CP-GAP* gw 110.0 x0 xL x1 xR)   ; CP rule: 20mm plates, hairline gap
  (setq rafTop rafterBotY rafBot (- rafterBotY plateT))       ; rafter-bottom plate (welded to rafter)
  (setq capTop (- rafBot gap) capBot (- capTop plateT))       ; column-cap plate (welded to column)
  ;; The top plates EXTEND on the inner-flange side by the stiffener width so the stiffener's full top edge
  ;; welds to the plate (owner 16-Jul markup 18) — extension is exactly the stiffener projection, no more.
  (setq px0 (if (<= dirIn 0) (- x0 gw) x0)
        px1 (if (>= dirIn 0) (+ x1 gw) x1))
  (peb-solid-quad (list px0 rafBot) (list px1 rafBot) (list px0 rafTop) (list px1 rafTop))   ; rafter plate (SOLID)
  (peb-solid-quad (list px0 capBot) (list px1 capBot) (list px0 capTop) (list px1 capTop))   ; column-cap plate (SOLID)
  ;; SOLID stiffener plate welded to the column INNER flange, on the OUTSIDE of it (the SPAN/rafter side),
  ;; NOT flush with the web inside the column (owner 16-Jul markup 17): filled triangle, vertical edge ON the
  ;; inner flange, projecting INTO the span — its top edge runs under the extended plate.
  (setq stH 130.0)
  (if (>= dirIn 0) (draw-rc-gusset x1 capBot (- capBot stH) gw  1 0.0))   ; left/centre-right inner flange -> into span (+x)
  (if (<= dirIn 0) (draw-rc-gusset x0 capBot (- capBot stH) gw -1 0.0))   ; right/centre-left  inner flange -> into span (-x)
  ;; GP gussets at the TOP flange (rafter underside, rafTop) too — CP rule: gusset at BOTH flanges.
  (if (>= dirIn 0) (draw-rc-gusset x1 rafTop (+ rafTop stH) gw  1 0.0))
  (if (<= dirIn 0) (draw-rc-gusset x0 rafTop (+ rafTop stH) gw -1 0.0))
  (princ))

(defun draw-arch-conn-plates (stype W H rise ep cb / innerH step x ay t2 hc yiL)
  (setq innerH 200.0)                                       ; arch web depth (matches the frame)
  (if (or (null cb) (<= cb 0.0)) (setq cb 400.0))           ; guard: fall back to legacy width
  (setq hc (/ cb 2.0))
  ;; Rafter-bottom Y at the OUTER springing CUT (x=cb+110, the extended plate inner edge) — must match the cut
  ;; rafter (draw-acs/ams-frame) so the bottom flange meets the plate exactly (owner 16-Jul markup 19).
  (if (= stype "ACS")
    (setq yiL (- (peb-arc3-y 0.0 H (/ W 2.0) (+ H rise) W H (+ cb 110.0)) innerH))
    (setq yiL (- (peb-arc3-y 0.0 H (/ W 4.0) (+ H (* 0.72 rise)) (/ W 2.0) (+ H rise) (+ cb 110.0)) innerH)))
  ;; SPRINGING knees — 2 solid plates, NO diagonal (owner 16-Jul), spanning the actual column width.
  (peb-arch-knee 0.0            cb              yiL  1)                 ; left springing  (inside = +x)
  (peb-arch-knee (- W cb)       W               yiL -1)                 ; right springing (inside = -x)
  (if (= stype "AMS")
    (peb-arch-knee (- (/ W 2.0) hc) (+ (/ W 2.0) hc)
      (- (peb-arc3-y 0.0 H (/ W 4.0) (+ H (* 0.72 rise)) (/ W 2.0) (+ H rise) (- (/ W 2.0) hc 110.0)) innerH) 0))  ; centre column (both)
  ;; SPLICE plates every <=12 m along the arch + SOLID flange stiffeners both sides (owner 16-Jul markup 11).
  (setq step (/ W (float (1+ (fix (/ W 12000.0))))))
  (setq x step)
  (while (< x (- W 1.0))
    (if (> (abs (- x (/ W 2.0))) 400.0)                     ; skip if it lands on the peak springing
      (progn
        (setq t2 (/ (- x (/ W 2.0)) (/ W 2.0)))
        (setq ay (+ H (* rise (- 1.0 (* t2 t2)))))          ; parabolic arch OUTER Y at x
        (peb-conn-plate-depth x (- ay innerH) ay 40.0 2)    ; the 2-plate vertical splice
        ;; SOLID stiffener gussets at TOP (ay) and BOTTOM (ay-innerH) flanges, both plate faces
        (draw-rc-gusset (- x 40.0) ay             (+ ay 100.0)             100.0 -1 0.0)
        (draw-rc-gusset (+ x 40.0) ay             (+ ay 100.0)             100.0  1 0.0)
        (draw-rc-gusset (- x 40.0) (- ay innerH)  (- ay innerH 100.0)      100.0 -1 0.0)
        (draw-rc-gusset (+ x 40.0) (- ay innerH)  (- ay innerH 100.0)      100.0  1 0.0)))
    (setq x (+ x step)))
  (princ))

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
      ((= i 0)              ; LEFT end column (exterior)
        (setq *BASE-BOLTS* (if *BASE-BOLTS-EXT* *BASE-BOLTS-EXT* 2))
        (draw-base-plate-at x (+ x cb) ep boltR))
      ((= i (1- n))         ; RIGHT end column (exterior)
        (setq *BASE-BOLTS* (if *BASE-BOLTS-EXT* *BASE-BOLTS-EXT* 2))
        (draw-base-plate-at (- x cb) x ep boltR))
      (T                    ; interior column (rectangular)
        (setq *BASE-BOLTS* (if *BASE-BOLTS-INT* *BASE-BOLTS-INT* 2))
        (setq thisW (if (listp intColW) (nth i intColW) intColW))
        (draw-base-plate-at (- x (/ thisW 2.0))
                            (+ x (/ thisW 2.0)) ep boltR)))
    (setq i (1+ i)))
)

(defun peb-solid-quad (bl br tl tr)
  ;;  Filled 2D SOLID quad — bl/br = bottom-left/right corners, tl/tr = top-left/right.
  ;;  (SOLID's no-bowtie vertex order is p1=BL p2=BR p3=TL p4=TR.)  Used to render the
  ;;  connection plates as SOLID thick plates (owner 14-Jul) instead of thin outlines.
  (command "_.SOLID" bl br tl tr ""))

;; ── CP (CONNECTION PLATES) — owner standing rule 19-Jul ──────────────────────────────
;;  Every bolted connection in a section = TWO filled-solid plates, uniform thickness, a small
;;  hairline seam, extended 100 mm past both rafter flanges, with GP (gusset) triangles at BOTH
;;  flanges (one leg on the plate extension, one on the flange).  These constants are the SINGLE
;;  source of the numbers so the whole rule is tuned in one place.
(setq *PEB-CP-THK* 30.0)   ; each plate thickness (mm)  — UNIFORM across all connections (owner: 30mm)
(setq *PEB-CP-GAP* 1.5)    ; hairline seam gap between the two plates (mm)
(setq *PEB-CP-EXT* 100.0)  ; plate extension past each flange (mm) — the GP gusset zone

(defun draw-stiff-top (xOuter yEdge w h dx)
  ;;  Triangular stiffener ABOVE the upper plate — FILLED SOLID (owner 18-Jul: standing gusset rule; matches
  ;;  the cantilever + valley connections).  yEdge = top edge Y of the upper plate; apex `h` above.
  (peb-solid-quad (list xOuter yEdge) (list (+ xOuter (* dx w)) yEdge)
                  (list xOuter (+ yEdge h)) (list xOuter (+ yEdge h))))

(defun draw-stiff-bot (xOuter yEdge w h dx)
  ;;  Triangular stiffener BELOW the lower plate — FILLED SOLID (owner 18-Jul).  yEdge = bottom edge Y of the
  ;;  lower plate; apex `h` below.
  (peb-solid-quad (list xOuter (- yEdge h)) (list xOuter (- yEdge h))
                  (list xOuter yEdge) (list (+ xOuter (* dx w)) yEdge)))

(defun draw-stiff-fullweb (xEdge yBot yTop w dir)
  ;;  FULL-WEB stiffener gusset (owner 16-Jul markup 15): the stiffener spans the WHOLE web (yBot flange -> yTop
  ;;  flange) against the connection plate edge, tapering to a point `w` outward at mid-web — NOT just a small
  ;;  triangle at the outer flange lines.  dir = +1 (right of plate) / -1 (left).
  (command "PLINE"
    (list xEdge yBot)
    (list (+ xEdge (* dir w)) (/ (+ yBot yTop) 2.0))
    (list xEdge yTop)
    "C"))

(defun draw-rc-gusset (xEdge yFlange plateEnd w dir slope)
  ;;  FILLED stiffener gusset (owner markup 22 + slope rule): a SOLID triangle on the OUTER face of the
  ;;  connection plate, in the flange->plate-end extension zone — from the flange corner (xEdge,yFlange) along
  ;;  the plate edge to the plate END (xEdge,plateEnd) and out by w ALONG THE FLANGE to
  ;;  (xEdge+dir*w, yFlange+dir*w*slope).  `slope` = the rafter-flange dy/dx so the flange leg lies EXACTLY on
  ;;  the sloped flange line (owner: NOT horizontal); pass 0.0 for a truly horizontal flange.  It stays WITHIN
  ;;  the plate end line (does NOT poke past it) and is fully hatched (solid).
  ;; 3-point SOLID: p1 p2 p3, then "" to finish the triangle (4th point = Enter) and "" to exit the loop.
  (command "_.SOLID"
    (list xEdge yFlange)
    (list (+ xEdge (* dir w)) (+ yFlange (* dir w slope)))
    (list xEdge plateEnd)
    "" ""))

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

;; ── RULE 4B.52 - A COLUMN IN THE MIDDLE OF THE FRAME TAKES THE CONNECTION ────────────
;;
;;   "Whenever the Column is in the Middle of the Frame - then Remove the Connection Plates
;;    b/w the Rafters & Give Connection Plate b/w top of the column to Bottom of the Rafter"
;;                                                                     - owner, 30-Aug-2026
;;
;; The column-top connection ALREADY existed (draw-ms-interior-plates, draw-mg-ridge-col-plates).
;; What was missing is the other half of the sentence: the rafter-to-rafter plate must GO.
;;
;; It survived because draw-rafter-stiffeners places its plates by DISTANCE ALONG THE RAFTER -
;; knee end, ridge start, apex, 12 m splices - and knows nothing about columns. The apex pair was
;; suppressed only by `apexHasCol`, a flag set by testing whether an interior column sits within
;; 1 mm of wid/2. On MSPL-26-278 (Multi-Span, one interior column) that test could not succeed:
;;
;;     building width   30480      <- what wid/2 was measured against
;;     STEEL width      30010      <- BP_WIDTH_MOD_REF is "Out to out of Steel Column"
;;     ridge/apex       15005      <- centre of the STEEL width
;;     interior column  14770      <- grid D
;;
;; Three different numbers, so the flag was nil and a rafter-to-rafter pair was drawn 235 mm from
;; the middle column's centreline - the exact condition the owner is banning.
;;
;; The fix is not a better wid/2 test. It is to stop asking "is this the apex?" and ask the
;; question the rule actually asks: IS THERE A COLUMN UNDER THIS PLATE? Each entry is
;; (x clearance), where clearance = half the column web + the plate extension - i.e. the plate is
;; suppressed exactly when it would land on the column's own connection zone.
(defun peb-plate-over-column-p (kxL noPlateXs / p found)
  (setq found nil)
  (foreach p noPlateXs
    (if (and (car p) (cadr p) (< (abs (- kxL (car p))) (cadr p))) (setq found T)))
  found
)

;; The interior members of a column list, each paired with its own no-plate clearance.
;; webFn is called with the column's index so Multi-Span can use its per-module web width
;; (ms-col-web-at); pass nil for a fixed width.
(defun peb-interior-col-clearances (cols webFn fixedWeb / out i n w)
  (setq out '() n (length cols) i 1)
  (while (< i (1- n))
    (setq w (if webFn (apply webFn (list cols i)) fixedWeb))
    (setq out (cons (list (nth i cols) (+ (/ w 2.0) *PEB-CP-EXT*)) out))
    (setq i (1+ i)))
  (reverse out)
)

(defun draw-rafter-plate-pair (kxL kyBot kyTop plateThk plateExt slopeL slopeR vShift /
                                 thk gap ext gw lxo lxi rxi rxo pB pT yb yt)
  ;;  CP RULE: draw a pair of SOLID splice plates centred on the seam at (kxL), a *PEB-CP-GAP* hairline
  ;;  apart, each *PEB-CP-THK* thick, extended *PEB-CP-EXT* past BOTH flanges, with GP gusset triangles at
  ;;  the top AND bottom flange on each plate's OUTER edge.  Optionally shifted by vShift (+ = UP).
  ;;  slopeL/slopeR + plateThk/plateExt retained for caller compatibility but the CP globals drive the size.
  (setq thk *PEB-CP-THK* gap *PEB-CP-GAP* ext *PEB-CP-EXT* gw 100.0)
  (setq lxi (- kxL (/ gap 2.0)))            ; left plate inner edge (at the seam)
  (setq lxo (- kxL (+ thk (/ gap 2.0))))    ; left plate outer edge
  (setq rxi (+ kxL (/ gap 2.0)))            ; right plate inner edge (at the seam)
  (setq rxo (+ kxL (+ thk (/ gap 2.0))))    ; right plate outer edge
  (setq yb (+ kyBot vShift) yt (+ kyTop vShift))    ; bottom / top flange Y (shifted)
  (setq pB (- yb ext) pT (+ yt ext))                ; plate bottom / top (ext past flanges)
  ;; LEFT + RIGHT SOLID plates
  (peb-solid-quad (list lxo pB) (list lxi pB) (list lxo pT) (list lxi pT))
  (peb-solid-quad (list rxi pB) (list rxo pB) (list rxi pT) (list rxo pT))
  ;; GP gussets — TOP flange (yt) and BOTTOM flange (yb), each plate outer edge.  The flange leg follows the
  ;; local rafter-flange slope (slopeL for the LEFT plate, slopeR for the RIGHT plate); both flanges on a given
  ;; half share the same slope.
  (draw-rc-gusset lxo yt (+ yt ext) gw -1 slopeL)
  (draw-rc-gusset rxo yt (+ yt ext) gw  1 slopeR)
  (draw-rc-gusset lxo yb (- yb ext) gw -1 slopeL)
  (draw-rc-gusset rxo yb (- yb ext) gw  1 slopeR)
)

(defun draw-rafter-stiffeners (cols ridges H rise ht rd apexHasCol noPlateXs /
                                 midD kneeL ridgeL stiffSize plateExt plateThk boltR
                                 slL slLnL slR slLnR slopeL slopeR splCaL splSaL splCaR splSaR
                                 midSecLen splDist nSpl spcLen splI
                                 half hEave hSa hCa hSlLn hSlope hDir
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
  (setq plateThk   *PEB-CP-THK*)   ; vertical connection plate thickness (CP rule; draw-rafter-plate-pair reads the global)
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
    ;; owner 22-Jul: PER-HALF slope so plates + mid-splices seat on the TRUE rafter even at an OFF-CENTRE ridge
    ;; (was slopeR = -slopeL, and the mid-splice used the LEFT slope-length/projection for BOTH halves).
    (setq slL   (- rxC xL) slLnL (sqrt (+ (* slL slL) (* rise rise)))
          splCaL (/ slL slLnL) splSaL (/ rise slLnL) slopeL (/ rise slL))
    (setq slR   (- xR rxC) slLnR (sqrt (+ (* slR slR) (* rise rise)))
          splCaR (/ slR slLnR) splSaR (/ rise slLnR) slopeR (- 0 (/ rise slR)))

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
    (if (not (or (peb-plate-already-drawn kxL kyBot) (peb-plate-over-column-p kxL noPlateXs)))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    ;; LEFT KNEE END: standard plate detail (2 plates + 3 bolts + 2 stiffeners)
    ;; CP: draw-rafter-plate-pair now draws the SOLID plates + GP gussets itself (no bolts, no outline stiffeners).
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeL slopeL 0.0)
      ))   ; end (if (not peb-plate-already-drawn) … LEFT KNEE END)

    ;; LEFT RIDGE START: web changes from midD → rd here.  Both plates
    ;; are in the LEFT half rafter (slope = +tanA).
    (setq kxL (car (nth 1 rPts)))
    (setq kyBot (cadr (nth 1 rPts)))
    (setq kyTop (+ kyBot midD))
    (if (not (or (peb-plate-already-drawn kxL kyBot) (peb-plate-over-column-p kxL noPlateXs)))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeL slopeL 0.0)
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
    (if (not (or (peb-plate-already-drawn kxL kyBot) (peb-plate-over-column-p kxL noPlateXs)))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    ;; Apex: LEFT plate is in LEFT half (slope=+tanA), RIGHT plate in RIGHT half (slope=-tanA)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeL slopeR 0.0)
      ))   ; end (if (not peb-plate-already-drawn) … RIDGE APEX)
      ))   ; end (if (not apexHasCol))

    ;; RIGHT RIDGE START: web changes from rd → midD here.  Both plates
    ;; are in the RIGHT half rafter (slope = -tanA = slopeR).
    (setq kxL (car (nth 3 rPts)))
    (setq kyBot (cadr (nth 3 rPts)))
    (setq kyTop (+ kyBot midD))
    (if (not (or (peb-plate-already-drawn kxL kyBot) (peb-plate-over-column-p kxL noPlateXs)))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeR slopeR 0.0)
      ))   ; end (if (not peb-plate-already-drawn) … RIGHT RIDGE START)

    ;; RIGHT KNEE END: both plates are in the RIGHT half rafter (slope = -tanA = slopeR)
    (setq kxL (car (nth 4 rPts)))
    (setq kyBot (cadr (nth 4 rPts)))
    (setq kyTop (+ kyBot midD))
    (if (not (or (peb-plate-already-drawn kxL kyBot) (peb-plate-over-column-p kxL noPlateXs)))
      (progn
        (peb-record-plate-drawn kxL kyBot)
    (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt slopeR slopeR 0.0)
      ))   ; end (if (not peb-plate-already-drawn) … RIGHT KNEE END)

    ;; ===== MID-SPAN SPLICE PLATES (12 m max piece rule) — PER HALF =====
    ;; owner 22-Jul: each half has its OWN mid-section length/slope (off-centre ridge), so splice each half
    ;; independently — its own slope-length, projection, piece count and plate angle.  hDir = +1 left (xL +dist
    ;; toward ridge), -1 right (xR -dist toward ridge).  (Was: one length/slope from the LEFT half for both.)
    (foreach half (list (list xL splSaL splCaL slLnL slopeL  1.0)
                        (list xR splSaR splCaR slLnR slopeR -1.0))
      (setq hEave (nth 0 half) hSa (nth 1 half) hCa (nth 2 half) hSlLn (nth 3 half)
            hSlope (nth 4 half) hDir (nth 5 half))
      (setq midSecLen (- hSlLn ridgeL kneeL))
      (setq nSpl (fix (/ (- midSecLen 0.001) 12000.0)))
      (if (> nSpl 0)
        (progn
          (setq spcLen (/ midSecLen (+ nSpl 1.0)) splI 1)
          (while (<= splI nSpl)
            (setq splDist (+ kneeL (* splI spcLen)))
            (setq kxL   (+ hEave (* hDir (* splDist hCa))))
            (setq kyBot (- (+ H (* splDist hSa)) midD))
            (setq kyTop (+ kyBot midD))
            (if (not (or (peb-plate-already-drawn kxL kyBot) (peb-plate-over-column-p kxL noPlateXs)))
              (progn
                (peb-record-plate-drawn kxL kyBot)
                (draw-rafter-plate-pair kxL kyBot kyTop plateThk plateExt hSlope hSlope 0.0)))
            (setq splI (1+ splI))))))

    (setq i (1+ i))
  )
)

(defun draw-haunch-plates (cols H ht ep valleyStyle ridgeX rcc /
                                          boltR plateY seamY upTopY upBotY loTopY loBotY
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
  ;; Knee SEAM = rafter underside at the eave = column top.  Steel gables have the DEEP haunch at the
  ;; eave (H-ht); ROOF-ON-RCC has a SHALLOW eave (de = max(200, ht*0.35)), so its underside is H-de.
  (setq seamY (if rcc (- H (max 200.0 (* ht 0.35))) (- H ht)))
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
        ;; ROTATED knee (owner 14-Jul): HORIZONTAL base plate welded to the rafter bottom, sitting on
        ;; the column top (seam at H-ht = rafter underside = column top), spanning the column depth (ht)
        ;; inward.  rcc=T (Roof-on-RCC) draws ONE base plate on the concrete with anchor bolts.
        (setq *PEB-KNEE-TOPY* H)                            ; rafter OUTER (top) flange at the eave
        (draw-knee-hplate x (+ x ht) seamY 45.0 4 rcc -1)   ; left end knee — outer = left
      )
      ;; --- RIGHT END column: horizontal base plate, column depth extends inward (-x) ---
      ((= i (1- nCols))
        (setq *PEB-KNEE-TOPY* H)                            ; rafter OUTER (top) flange at the eave
        (draw-knee-hplate (- x ht) x seamY 45.0 4 rcc 1)   ; right end knee — outer = right
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
            ;; owner 18-Jul: valley detail extracted to the shared draw-valley-col-plates (reused by the
            ;; Butterfly/Falcon canopy).  plateBot = 50 below the haunch corner (H-ht); plateTop = 50 above
            ;; the rafter top flange at the valley (H).
            (draw-valley-col-plates x (- (- H ht) 50.0) (+ H 50.0)))
          (T
            ;; --- Non-valley interior column under a continuous rafter: HORIZONTAL base plate at the
            ;;     column top (owner 14-Jul), spanning the column depth centred on the column. ---
            (draw-knee-hplate (- x (/ ht 2.0)) (+ x (/ ht 2.0)) seamY 45.0 4 rcc nil))))
    )
    (setq i (1+ i))
  )
)

(defun draw-ridge-plate (W H rise rd ep)
  ;;  Ridge connection plate (vertical, at the ridge centerline).  Owner 15-Jul (markups 6/7): the plate MUST
  ;;  extend 100mm BEYOND BOTH flanges — 100 above the top flange AND 100 below the bottom flange (it used to
  ;;  stop 100mm ABOVE the bottom flange).  Top flange at ridge = H+rise; bottom flange (underside) = H+rise-rd.
  (setvar "CLAYER" "PLATES")
  (command "RECTANG"
    (list (- (/ W 2.0) (/ ep 2.0)) (- (+ H rise (- 0 rd)) 100.0))   ; bottom = bottom flange - 100
    (list (+ (/ W 2.0) (/ ep 2.0)) (+ (+ H rise)          100.0)))  ; top    = top flange + 100
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
  ;; CP RULE: TWO SOLID *PEB-CP-THK* plates, *PEB-CP-GAP* hairline seam, NO bolts; GP gussets both flanges.
  (setq ep      *PEB-CP-THK*)
  (setq upTopY  (- (+ H rise) rd))           ; rafter underside at ridge / column top
  (setq upBotY  (- upTopY ep))               ; upper (rafter) plate bottom edge
  (setq loTopY  (- upBotY *PEB-CP-GAP*))     ; lower (column) plate top edge (hairline seam)
  (setq loBotY  (- loTopY ep))               ; lower plate bottom edge
  (setq intColW 400.0)                       ; matches draw-mg-multi-frame
  (setq halfCol (/ intColW 2.0))             ; = 200
  (setq ext     100.0)                       ; 100 mm extension each end
  (setq stiffH  100.0)
  (setq outerX  (- x halfCol ext))           ; = x - 300
  (setq innerX  (+ x halfCol ext))           ; = x + 300
  ;; LEFT + RIGHT half plates (SOLID), rafter plate on top, column plate below the gap.
  (peb-solid-quad (list outerX upBotY) (list x upBotY) (list outerX upTopY) (list x upTopY))   ; L rafter
  (peb-solid-quad (list outerX loBotY) (list x loBotY) (list outerX loTopY) (list x loTopY))   ; L column
  (peb-solid-quad (list x upBotY) (list innerX upBotY) (list x upTopY) (list innerX upTopY))   ; R rafter
  (peb-solid-quad (list x loBotY) (list innerX loBotY) (list x loTopY) (list innerX loTopY))   ; R column
  ;; Outer-end stiffeners (top + bottom) JUST till the plate extension (100mm), no beyond (owner 14-Jul).
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
  (txt-bold "MC" (list tx ty) (peb-th 'SMALL) 0 "DETAIL-A: TYPICAL VALLEY DETAILS")
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
  ;; same rule as draw-slope-tag: the clearance is a function of the glyph, not a constant
  (txt "MC" (list (+ cx (/ run 2.0)) (- ay (* (peb-th 'MARK) s 0.85))) (peb-th 'MARK) 0 (rtos slopeD 2 0))
  (txt "MC" (list (+ bx (* 240 s)) (+ ay (/ rise 2.0))) (peb-th 'SMALL) 0 "1")
  (txt-bold "MC" (list (+ cx (/ run 2.0)) (+ by (* 350 s))) (peb-th 'SMALL) 0 (strcat "SLOPE " slopeStr))
)

(defun draw-slope-tag (cx cy slopeD upRight / s th run rise ax ay bx by labX labY labOne)
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
  ;; ── SIZE AND PLACEMENT BOTH FOLLOW THE LADDER (owner 28-Aug: "check the SLOPE 1:10
  ;; text and fix its size and placement, must be as per the developed rule") ──────────
  ;; The triangle was a fixed 900·s and the two labels were placed by offsets baked off the
  ;; OLD hard-coded 220 text - 190·s, 220·s, 110·s are all echoes of that number. When the
  ;; text moved onto the ladder the offsets stayed behind, so the digits overhung the
  ;; horizontal leg and collided with the roof sheeting below.
  ;;
  ;; THE RULE: a placement offset that exists to clear TEXT must be computed FROM that
  ;; text's height, never from a number that happened to suit one size. `th` below is the
  ;; single source; change the rung and the whole tag re-proportions itself.
  (setq th (* (peb-th 'MARK) s))         ; the drawn height of the tag's digits
  (setq run (max (* 900 s) (* th 2.6)))  ; triangle scales with its own labels
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
  ;; ONE CALLOUT, NOT TWO LOOSE DIGITS.
  ;; The ratio used to be split - the denominator under the horizontal leg and a separate
  ;; "1" beside the vertical leg. At a normal roof pitch that vertical leg is tiny: at 1:10
  ;; the rise is a tenth of the run, so the "1" had nothing to sit against and landed on the
  ;; roof sheeting, and the pair read as "110" rather than a ratio. Written as a single
  ;; "1:10" under the leg it is unambiguous at ANY pitch, and there is only one thing to
  ;; keep clear of the roof.
  ;; ABOVE the triangle, not below it. The caller lifts the tag only 300·s clear of the
  ;; sheeting, so anything placed under the horizontal leg lands ON the roof line - which is
  ;; where the digits were sitting. Above the apex there is open air at every pitch.
  (setq labX (+ cx (/ (* upRight run) 2.0)))
  (setq labY (+ ay rise (* th 0.80)))
  (txt "MC" (list labX labY) (peb-th 'MARK) 0 (strcat "1:" (rtos slopeD 2 0)))
)

(defun draw-rc-brick-hidden (W H / bw seg xo xi y)
  ;;  ROOFING SYSTEM (RC) brick masonry, FLUSH with the RCC columns (owner 16-Jul): the section is cut AT a
  ;;  pillar and the brick runs BETWEEN pillars (beyond the cut), so the column is drawn WIDENED out to the
  ;;  brick face (see draw-rcc-columns brickExt) and the brick masonry is shown as HIDDEN (dotted) lines WITHIN
  ;;  that widened zone — a dashed interface at the structural column face + a few dashed courses.
  ;;  (NOT-flush case = dotted outline OUTSIDE the column; not used here.)
  (setq bw (if (and *PEB-RC-BRICKEXT* (> *PEB-RC-BRICKEXT* 0.0)) *PEB-RC-BRICKEXT* 200.0))
  (setvar "CLAYER" "BRICK-WALL")
  (setvar "CELTYPE" "HIDDEN") (setvar "CELTSCALE" 300.0)
  ;; each seg = (outer-face-x  structural-face-x) of the brick zone
  (foreach seg (list (list (- 0.0 bw) 0.0) (list (+ W bw) W))
    (setq xo (car seg) xi (cadr seg))
    (command "LINE" (list xi 0.0) (list xi H) "")            ; dashed interface at the structural column face
    (setq y 600.0)
    (while (< y (- H 300.0))                                 ; dashed brick courses within the flush zone
      (command "LINE" (list xo y) (list xi y) "")
      (setq y (+ y 600.0))))
  (setvar "CELTYPE" "BYLAYER") (setvar "CELTSCALE" 1.0)
  (princ))

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

(defun draw-cladding (data W H rise brickH monoRise rightH rccRight throatWin / rHt rEndX rDrop reEL reEY reEYR tLo tHi apexY yLo yHi
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
  ;; rightH (optional) lets a SINGLE-SLOPE building carry the sheeting up to its HIGH eave
  ;; (H + monoRise) instead of the low H, so the tall wall isn't left bare.
  (setq rHt (if rightH rightH H))
  (if (and (< brickH rHt) (not rccRight))          ; rccRight (LEAN-TO): right side is the existing masonry wall -> no PEB wall sheeting
    (progn
      (command "LINE"
        (list (+ W girtDepth) (- brickH 50.0))
        (list (+ W girtDepth) rHt) "")
      (command "LINE"
        (list (+ W girtDepth cladThk) (- brickH 50.0))
        (list (+ W girtDepth cladThk) rHt) "")
      (command "LINE"
        (list (+ W girtDepth)         rHt)
        (list (+ W girtDepth cladThk) rHt) "")
      (command "LINE"
        (list (+ W girtDepth)         (- brickH 50.0))
        (list (+ W girtDepth cladThk) (- brickH 50.0)) "")
    )
  )

  ;; --- ROOF SHEETING: 2 parallel sloped lines, extended 270mm into the gutter at each eave. ---
  ;; SINGLE SLOPE (monoRise non-nil): ONE continuous line low-eave(H) -> high-eave(H+monoRise).
  ;; GABLE (default): two slopes meeting at the ridge (W/2, H+rise).
  (if monoRise
    (progn
      (setq slpDrop (* 270.0 (/ monoRise W)))    ; overhang drop at the low end
      ;; rccRight (LEAN-TO): the high end TUCKS to the existing wall face (x=W) with NO 270mm overhang.
      (setq rEndX (if rccRight W (+ W 270.0)))
      (setq rDrop (if rccRight 0.0 slpDrop))
      ;; The two eave ends, lifted out of the LINE calls below so a parapet can move
      ;; one of them without disturbing the other (they are no longer symmetric).
      (setq reEL  -270.0
            reEY  (+ H purlinH (- 0 slpDrop))
            reEYR (+ H monoRise purlinH rDrop))
      ;; PARAPET eave (FA_*): NO 270 overhang — the sheet is TRIMMED inboard, over
      ;; the valley gutter at the parapet base, so it drips into the trough instead
      ;; of running straight through the panel.  Only the eave that actually carries
      ;; the parapet moves; the other keeps its overhang.
      (if *PEB-FA-PARA-L*
        (setq reEL (peb-para-sheet-in)
              reEY (+ H purlinH (* (peb-para-sheet-in) (/ monoRise W)))))
      (if (and *PEB-FA-PARA-R* (not rccRight))
        (setq rEndX (- W (peb-para-sheet-in))
              reEYR (+ H monoRise purlinH (- 0 (* (peb-para-sheet-in) (/ monoRise W))))))
      (command "LINE" (list reEL reEY)
                      (list rEndX reEYR) "")
      (command "LINE" (list reEL (+ reEY cladThk))
                      (list rEndX (+ reEYR cladThk)) "")
      (command "LINE" (list reEL reEY)
                      (list reEL (+ reEY cladThk)) "")
      (command "LINE" (list rEndX reEYR)
                      (list rEndX (+ reEYR cladThk)) ""))
    (progn
      (setq slpDrop (* 270.0 (/ sa ca)))
      ;; owner 16-Jul markup 16: for the RC FASCIA the roof is TRIMMED at the valley gutter (eave at the rafter
      ;; top, x=inset, NO 270mm overhang past the parapet); otherwise the standard 270mm eave overhang.
      (if (and *PEB-RC-INSET* (> *PEB-RC-INSET* 0.0))
        (setq reEL *PEB-RC-INSET* rEndX (- W *PEB-RC-INSET*) reEY (+ H purlinH))
        (setq reEL -270.0 rEndX (+ W 270.0) reEY (+ H purlinH (- 0 slpDrop))))
      ;; Left and right eaves used to share reEY.  A parapet on ONE sidewall breaks
      ;; that symmetry, so the right end carries its own Y from here on.
      (setq reEYR reEY)
      ;; PARAPET eave (FA_*): NO 270 overhang — the sheet is TRIMMED inboard, over
      ;; the valley gutter at the parapet base, so it drips into the trough instead
      ;; of running straight through the panel.  The sheet CLIMBS as it runs inboard,
      ;; hence + (not -) the slope drop over that distance.
      (if *PEB-FA-PARA-L*
        (setq reEL (peb-para-sheet-in)
              reEY (+ H purlinH (* (peb-para-sheet-in) (/ sa ca)))))
      (if *PEB-FA-PARA-R*
        (setq rEndX (- W (peb-para-sheet-in))
              reEYR (+ H purlinH (* (peb-para-sheet-in) (/ sa ca)))))
      ;; owner 19-Jul UNIVERSAL RULE (roof monitor): when a THROAT window is present the roof
      ;; sheeting is TRIMMED at the two throat-edge purlins (the O.W. opening) — no sheeting spans
      ;; the throat.  throatWin = (throatLo throatHi) in X; nil => original continuous gable sheeting.
      (if throatWin
        (progn
          (setq tLo (car throatWin) tHi (cadr throatWin) apexY (+ H rise purlinH))
          (setq yLo (+ reEY (* (- apexY reEY) (/ (- tLo reEL) (- (/ W 2.0) reEL)))))
          (setq yHi (+ apexY (* (- reEYR apexY) (/ (- tHi (/ W 2.0)) (- rEndX (/ W 2.0))))))
          (command "LINE" (list reEL reEY) (list tLo yLo) "")                                  ; L slope outer -> throat edge
          (command "LINE" (list reEL (+ reEY cladThk)) (list tLo (+ yLo cladThk)) "")          ; L slope inner
          (command "LINE" (list tLo yLo) (list tLo (+ yLo cladThk)) "")                        ; L throat trimmed edge cap
          (command "LINE" (list tHi yHi) (list rEndX reEYR) "")                                ; R slope outer throat edge -> eave
          (command "LINE" (list tHi (+ yHi cladThk)) (list rEndX (+ reEYR cladThk)) "")        ; R slope inner
          (command "LINE" (list tHi yHi) (list tHi (+ yHi cladThk)) "")                        ; R throat trimmed edge cap
          (command "LINE" (list reEL reEY) (list reEL (+ reEY cladThk)) "")                    ; L eave cap
          (command "LINE" (list rEndX reEYR) (list rEndX (+ reEYR cladThk)) ""))               ; R eave cap
        (progn
          (command "LINE" (list reEL reEY) (list (/ W 2.0) (+ H rise purlinH)) "")
          (command "LINE" (list reEL (+ reEY cladThk)) (list (/ W 2.0) (+ H rise purlinH cladThk)) "")
          (command "LINE" (list (/ W 2.0) (+ H rise purlinH)) (list rEndX reEYR) "")
          (command "LINE" (list (/ W 2.0) (+ H rise purlinH cladThk)) (list rEndX (+ reEYR cladThk)) "")
          (command "LINE" (list reEL reEY) (list reEL (+ reEY cladThk)) "")
          (command "LINE" (list rEndX reEYR) (list rEndX (+ reEYR cladThk)) "")))))

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
  ;; HEADINGS ARE BOLD (owner 28-Aug: "wall and roof sheeting headings in sections must be
;; BOLD, apply similar changes to other drawings for more professional look").
;; "WALL SHEETING:" / "ROOF SHEETING:" are the heading line; the spec beneath stays
;; regular. That contrast is what separates a callout from its body text on the page -
;; drawn at one weight the two ran together and read as one grey block.
;;
;; ALL DRAWING-BODY TEXT IS UPPERCASE (owner rule + Mammut master).  `txt` applies
  ;; (strcase ...) itself, but this spec reaches paper through an MLEADER, which bypasses
  ;; it - so "0.50 mm AZ150 PPGL (S-Type) + 50mm Fiberglass Insulation" printed in mixed
  ;; case among all-caps labels and read as a different typeface (owner 28-Aug).
  ;; Upper-cased where it is BUILT, so the MLEADER and txt paths cannot disagree.
  (setq rLine1 (strcase (strcat (car rParts) ":")))
  (setq rLine2 (strcase (cadr rParts)))
  ;; ROOF CLADDING label X: locked at 1/3 of the half-rafter span IN
  ;; FROM the right eave (per user clarification: "1/3 from right side
  ;; eave").  rWrapW sized to fit the remaining halfR/3 of available
  ;; space to the right edge minus a small margin.
  ;; owner 14-Jul: shift the ROOF SHEETING M-Ladder + text LEFT of 0.83·W, but keep the leader drop clear
  ;; of the RIGHT slope symbol (0.75·W landed on it) — settle at 0.80·W.
  (setq labRX  (- W (/ (/ W 2.0) 2.5)))             ; W - halfR/2.5 = 0.80·W
  (setq rWrapW (max 1500.0
                    (min 8000.0
                         (- (- W labRX) (* 300 *PEB-TEXT-SCALE*)))))
  (setq rTextW rWrapW)                              ; back-compat
  ;; Anchor labRY to the SAME Y as the wall sheeting labWY so both
  ;; sheeting MLEADERs sit on the same horizontal level (per user
  ;; spec).  Wall sheeting uses H + 1800·TS, so roof sheeting matches.
  (setq rDx (abs (- labRX (/ W 2.0))))
  ;; roof arrow tip on the sheeting at labRX -- MONO roof follows monoRise (so SS/LT point at the real
  ;; single slope, not a gable height); gable follows the ridge line.
  (setq rTargetY (if monoRise
                   (+ H (* monoRise (/ labRX W)) purlinH cladThk)
                   (- (+ H rise purlinH cladThk) (* rise (/ rDx (/ W 2.0))))))
  ;; owner 14-Jul (revised): raise the ROOF M-Ladder UP to the SAME LEVEL as the WALL M-Ladder so both
  ;; sheeting labels align along the top; the leader leg lengthens to reach the roof.  Lifted a further
  ;; 3 rows (H + 3800·TS) so a LONG sandwich-panel build-up (2 wrapped lines below the bar) clears the roof.
  (setq labRY (+ H (* 3800 *PEB-TEXT-SCALE*)))
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
      ;; format code "{\\Fromand.shx; … }".
      (setvar "CLAYER" "TEXT")
      ;; Pre-split spec into max 2 lines (same as wall sheeting).
      (setq rLine2_2L (peb-split-2-lines rLine2))
      (setq rBarY     (+ labRY (* 175 *PEB-TEXT-SCALE*)))
      (setq rBarLen   300.0)                  ; 300 mm bar (Option B)
      ;; \H0.72x; shrinks the whole panel callout (heading + build-up spec)
      ;; to 0.72x the MLEADER body height so the full sandwich fits inside
      ;; the section as a compact leader.
      (setq rCombined
        (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;" rLine1 "}\\P" rLine2_2L "}"))
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
          (setq rHeadY (+ rBarY (* (peb-th 'SMALL) *PEB-TEXT-SCALE*)))
          (setq rSpecY (- rBarY (* 60  *PEB-TEXT-SCALE*)))
          ;; Heading bold above bar
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labRX rHeadY)
                    (* (peb-th 'SMALL) *PEB-TEXT-SCALE*) 0 "ML"
                    (strcat "{\\Fromand.shx;" rLine1 "}"))))
          (if (vl-catch-all-error-p mtResult)
            (txt-bold "ML" (list labRX rHeadY) (peb-th 'SMALL) 0 rLine1))
          ;; Spec regular below bar
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labRX rSpecY)
                    (* (peb-th 'SMALL) *PEB-TEXT-SCALE*) 0 "TL" rLine2_2L)))
          (if (vl-catch-all-error-p mtResult)
            (setq nRSpec (txt-wrap "TL" (list labRX rSpecY) (peb-th 'SMALL) 0 rBarLen rLine2_2L)))
          (setvar "CLAYER" "ARROWS")
          (setvar "PLINEWID" 0.0)
          ;; Bar
          (command "LINE"
            (list labRX rBarY)
            (list (+ labRX rBarLen) rBarY) "")
          ;; Vertical leader DOWN from LEFT end of bar to just above the sheeting; SMALL arrowhead (160×55).
          (command "LINE"
            (list labRX rBarY)
            (list labRX (+ rTargetY (* 160 *PEB-TEXT-SCALE*))) "")
          (command "PLINE"
            (list labRX (+ rTargetY (* 160 *PEB-TEXT-SCALE*)))
            "W" (* 55 *PEB-TEXT-SCALE*) 0
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
          ;; owner 14-Jul: thin LEG (leader line) + a SMALL arrowhead (160×55, same as the eave-gutter arrow);
          ;; both the wall & roof M-Ladders read the same.  Leg = bar → just above the roof; head = small ▼.
          (setvar "CLAYER" "ARROWS")
          (setvar "PLINEWID" 0.0)
          (command "LINE" (list labRX rBarY) (list labRX (+ rTargetY (* 160 *PEB-TEXT-SCALE*))) "")
          (command "PLINE" (list labRX (+ rTargetY (* 160 *PEB-TEXT-SCALE*)))
                           "W" (* 55 *PEB-TEXT-SCALE*) 0 (list labRX rTargetY) "")
          (setvar "PLINEWID" 0.0)
        )
      )
    )
    (T
      ;; --- Single-line fallback ---
      (txt "ML" (list labRX labRY) (peb-th 'SMALL) 0 roofLbl)
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
  ;; owner 15-Jul: ROOFING SYSTEM (RC) has full-height masonry walls — NO wall sheeting + NO wall M-Ladder.
  (if (not *PEB-NO-WALL-SHEET*) (progn
  (setq wParts (split-at-first-digit wallLbl))
  (setq wLine1 (strcase (strcat (car wParts) ":")))
  (setq wLine2 (strcase (cadr wParts)))
  (setq labWX (- 0 girtDepth cladThk))           ; -235 (sheet outer face)
  ;; Anchor labWY clear of the EAVE GUTTER label below it.  Eave gutter
  ;; sits at gyTopOut + 450·TS ≈ H + 681 + 450·TS.  Three wrapped lines
  ;; of wall spec eat ~3·220·TS = 660·TS of space below labWY, so
  ;; labWY must clear that band by at least one text height.  Using
  ;; H + 1800·TS ensures the wall text bottom stays well above the
  ;; gutter label across all reasonable scales.
  ;; owner 14-Jul: raise the WALL SHEETING M-Ladder well clear of the EAVE GUTTER text; lifted to 3800·TS
  ;; (3 rows above the earlier 3100) so a LONG sandwich-panel spec wrapping below the bar still clears the
  ;; frame.  labRY (roof) matches this level so both M-Ladders align along the top.
  (setq labWY (+ H (* 3800 *PEB-TEXT-SCALE*)))
  ;; wWrapW: tighter cap so wall MTEXT doesn't sprawl past mid-rafter
  ;; into the PURLIN label area on narrow buildings.  Was halfL/2 minus
  ;; margin (still 3–4 m wide on a 15 m building); now halfL × 0.3
  ;; which leaves more rafter space for other labels.  Floor 1200 mm
  ;; so very narrow sections still produce a useable wrap.
  (setq wWrapW (max 1200.0
                    (min 8000.0
                         (* (/ W 2.0) 0.3))))
  ;; owner 14-Jul: a single-skin spec (no "+" build-up) must fit on ONE line so the "(S-Type)" profile
  ;; suffix stays beside "…(PPGL)".  Widen the wrap only for that case — short text won't sprawl (it keeps
  ;; its natural width); the wider cap just prevents an unwanted mid-spec wrap.
  (if (not (vl-string-search "+" wLine2))
    (setq wWrapW (max wWrapW 5400.0)))
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
      ;; "{\\Fromand.shx; … }" so the surrounding spec text stays in
      ;; regular weight at the same body size, which is now (peb-th 'SMALL) - see below.
;;
;; TEXT SIZE COMES FROM THE LADDER, NOT FROM A NUMBER (owner 28-Aug: "make sure all
;; the texts are based on the defined text only ... I have seen the deviation of
;; FIBERGLASS INSULATION which have different text type").  He was right: this whole
;; roof/wall sheeting spec block was drawn at a hard-coded 220, and txt multiplies by
;; *PEB-TEXT-SCALE*, so it printed at about 0.8 mm on A4 - below every rung of
;; *PEB-TEXT-HEIGHTS*, whose SMALLEST is SMALL 550 (2.0 mm).  Nothing else on any sheet
;; was that small, which is exactly why the insulation line looked like a different
;; typeface.  Heights AND the paired vertical offsets now both read (peb-th 'SMALL),
;; so the block keeps its proportions and follows the ladder if the ladder moves.
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
      ;; \H0.72x; shrinks the whole panel callout (heading + build-up spec)
      ;; to 0.72x the MLEADER body height — compact leader that fits inside
      ;; the section.
      (setq wCombined
        (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;" wLine1 "}\\P" wLine2_2L "}"))
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
          (setq wHeadY (+ wBarY (* (peb-th 'SMALL) *PEB-TEXT-SCALE*)))
          (setq wSpecY (- wBarY (* 60  *PEB-TEXT-SCALE*)))
          ;; Heading bold above bar
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labWX wHeadY)
                    (* (peb-th 'SMALL) *PEB-TEXT-SCALE*) 0 "ML"
                    (strcat "{\\Fromand.shx;" wLine1 "}"))))
          (if (vl-catch-all-error-p mtResult)
            (txt-bold "ML" (list labWX wHeadY) (peb-th 'SMALL) 0 wLine1))
          ;; Spec regular below bar
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labWX wSpecY)
                    (* (peb-th 'SMALL) *PEB-TEXT-SCALE*) 0 "TL" wLine2_2L)))
          (if (vl-catch-all-error-p mtResult)
            (txt-wrap "TL" (list labWX wSpecY) (peb-th 'SMALL) 0 wBarLen wLine2_2L))
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
          ;; Horizontal line going RIGHT to just before the wall sheet; the SINGLE small arrowhead below
          ;; the cond (160×55) supplies the tip, so no separate (big) arrow here.
          (command "LINE"
            (list wExtX wTargetY)
            (list (- labWX (* 160 *PEB-TEXT-SCALE*)) wTargetY) "")
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
          ;; (wall-sheeting arrowhead is drawn ONCE below the cond — see the single 160×55 tip.)
        )
      )
    )
    (T
      ;; --- Single-line fallback ---
      (txt "ML" (list labWX labWY) (peb-th 'SMALL) 0 wallLbl)))
  ;; owner 14-Jul: the SINGLE wall-sheeting M-Ladder arrowhead — a SMALL triangle (160×55) pointing RIGHT at
  ;; the sheeting line, SAME size as the eave-gutter / COLUMN / GIRT arrows.  (The per-branch overlays were
  ;; removed so there is exactly ONE arrow here.)
  (setvar "CLAYER" "ARROWS")
  (setvar "PLINEWID" 0.0)
  (command "PLINE" (list (- labWX (* 160 *PEB-TEXT-SCALE*)) wTargetY)
                   "W" (* 55 *PEB-TEXT-SCALE*) 0
                   (list labWX wTargetY) "")
  (setvar "PLINEWID" 0.0)
  ;; Group the hand-rolled drawing for click-once-select-all.
  (peb-group-entities (peb-collect-entities-since lastBefore) "PEBLBL")
  (setvar "PLINEWID" 0.0)
  ))  ; end (if (not *PEB-NO-WALL-SHEET*) ...)
)

(defun draw-cladding-mg (data W H rise brickH numGab /
                         cladThk purlinH girtDepth gW i gxL gxR ridgeX y ribStep
                         slopeLen sa ca slpDrop d xT yT roofLbl wallLbl
                         rParts rLine1 rLine2 rBarY rBarLen rTargetY rDx rTextW rWrapW nRSpec
                         rLine2_2L rCombined mlResult mtResult
                         labRX labRY gxL_last ridgeX_last mgEL mgEY mgER mgERY
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
  ;; The two OUTER eave ends.  Standard = 270 past the column, matching the eave
  ;; gutter.  PARAPET eave (FA_*) = TRIMMED inboard over the valley gutter at the
  ;; parapet base, because a parapet stands in the wall plane and the overhang
  ;; would otherwise run straight through the panel.  Only the eave carrying the
  ;; parapet moves.  (Inner gable junctions are untouched -- they drain to their
  ;; own valley gutters and never meet a parapet.)
  (setq mgEL  -270.0
        mgEY  (+ H purlinH (- 0 slpDrop))
        mgER  (+ W 270.0)
        mgERY (+ H purlinH (- 0 slpDrop)))
  (if *PEB-FA-PARA-L*
    (setq mgEL (peb-para-sheet-in)
          mgEY (+ H purlinH (* (peb-para-sheet-in) (/ sa ca)))))
  (if *PEB-FA-PARA-R*
    (setq mgER  (- W (peb-para-sheet-in))
          mgERY (+ H purlinH (* (peb-para-sheet-in) (/ sa ca)))))
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
        ;; Outer left eave: 270mm past the column to match the gutter -- or trimmed
        ;; inboard over the valley gutter when this wall carries a parapet.
        (command "LINE"
          (list mgEL    mgEY)
          (list ridgeX  (+ H rise purlinH)) "")
        (command "LINE"
          (list mgEL    (+ mgEY cladThk))
          (list ridgeX  (+ H rise purlinH cladThk)) "")
        ;; Eave cap at extension end
        (command "LINE"
          (list mgEL    mgEY)
          (list mgEL    (+ mgEY cladThk)) "")
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
        ;; Outer right eave: 270mm past the column -- or trimmed inboard on a parapet.
        (command "LINE"
          (list ridgeX (+ H rise purlinH))
          (list mgER   mgERY) "")
        (command "LINE"
          (list ridgeX (+ H rise purlinH cladThk))
          (list mgER   (+ mgERY cladThk)) "")
        ;; Eave cap at extension end
        (command "LINE"
          (list mgER   mgERY)
          (list mgER   (+ mgERY cladThk)) "")
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
  ;; ALL DRAWING-BODY TEXT IS UPPERCASE (owner rule + Mammut master).  `txt` applies
  ;; (strcase ...) itself, but this spec reaches paper through an MLEADER, which bypasses
  ;; it - so "0.50 mm AZ150 PPGL (S-Type) + 50mm Fiberglass Insulation" printed in mixed
  ;; case among all-caps labels and read as a different typeface (owner 28-Aug).
  ;; Upper-cased where it is BUILT, so the MLEADER and txt paths cannot disagree.
  (setq rLine1 (strcase (strcat (car rParts) ":")))
  (setq rLine2 (strcase (cadr rParts)))
  ;; ROOF CLADDING label X: 1/3 of the LAST gable's half-span IN FROM
  ;; the right eave.
  (setq labRX  (- W (/ (/ gW 2.0) 3.0)))            ; W - (gW/2)/3 = W - gW/6
  ;; Anchor labRY to the SAME Y as the wall sheeting label so both
  ;; sheeting MLEADERs sit on the same horizontal level (same rule as CS).
  (setq labRY  (+ H (* 3800 *PEB-TEXT-SCALE*)))   ; owner 14-Jul: 3 rows up (match CS) for long sandwich specs
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
      ;; \H0.72x; shrinks the whole panel callout (heading + build-up spec)
      ;; to 0.72x the MLEADER body height so the full sandwich fits inside
      ;; the section as a compact leader.
      (setq rCombined
        (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;" rLine1 "}\\P" rLine2_2L "}"))
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
              (list (list labRX (+ rBarY (* (peb-th 'SMALL) *PEB-TEXT-SCALE*)))
                    (* (peb-th 'SMALL) *PEB-TEXT-SCALE*) 0 "ML"
                    (strcat "{\\Fromand.shx;" rLine1 "}"))))
          (if (vl-catch-all-error-p mtResult)
            (txt-bold "ML" (list labRX (+ rBarY (* (peb-th 'SMALL) *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 rLine1))
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labRX (- rBarY (* 60 *PEB-TEXT-SCALE*)))
                    (* (peb-th 'SMALL) *PEB-TEXT-SCALE*) 0 "TL" rLine2_2L)))
          (if (vl-catch-all-error-p mtResult)
            (setq nRSpec (txt-wrap "TL" (list labRX (- rBarY (* 60 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 rBarLen rLine2_2L)))
          (setvar "CLAYER" "ARROWS")
          (setvar "PLINEWID" 0.0)
          (command "LINE"
            (list labRX rBarY)
            (list (+ labRX rBarLen) rBarY) "")
          (command "LINE"
            (list labRX rBarY)
            (list labRX (+ rTargetY (* 160 *PEB-TEXT-SCALE*))) "")
          (command "PLINE"
            (list labRX (+ rTargetY (* 160 *PEB-TEXT-SCALE*)))
            "W" (* 55 *PEB-TEXT-SCALE*) 0
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
      (txt "ML" (list labRX labRY) (peb-th 'SMALL) 0 roofLbl)
      (draw-l-leader (+ labRX (* 5000 *PEB-TEXT-SCALE*))
                     (- labRY (* 250 *PEB-TEXT-SCALE*))
                     ridgeX_last
                     (+ H rise purlinH cladThk)
                     "V")))

  ;; === WALL SHEETING label: ONE 4-vertex MLEADER (matches CS) ===
  (setq wParts (split-at-first-digit wallLbl))
  (setq wLine1 (strcase (strcat (car wParts) ":")))
  (setq wLine2 (strcase (cadr wParts)))
  (setq labWX  (- 0.0 girtDepth cladThk))      ; -235 : outer face of wall sheet
  (setq labWY  (+ H (* 3800 *PEB-TEXT-SCALE*)))   ; owner 14-Jul: 3 rows up (match CS) for long sandwich specs
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
      ;; \H0.72x; shrinks the whole panel callout (heading + build-up spec)
      ;; to 0.72x the MLEADER body height — compact leader that fits inside
      ;; the section.
      (setq wCombined
        (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;" wLine1 "}\\P" wLine2_2L "}"))
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
          (setq wHeadY (+ wBarY (* (peb-th 'SMALL) *PEB-TEXT-SCALE*)))
          (setq wSpecY (- wBarY (* 60  *PEB-TEXT-SCALE*)))
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labWX wHeadY)
                    (* (peb-th 'SMALL) *PEB-TEXT-SCALE*) 0 "ML"
                    (strcat "{\\Fromand.shx;" wLine1 "}"))))
          (if (vl-catch-all-error-p mtResult)
            (txt-bold "ML" (list labWX wHeadY) (peb-th 'SMALL) 0 wLine1))
          (setq mtResult
            (vl-catch-all-apply 'peb-make-mtext-line
              (list (list labWX wSpecY)
                    (* (peb-th 'SMALL) *PEB-TEXT-SCALE*) 0 "TL" wLine2_2L)))
          (if (vl-catch-all-error-p mtResult)
            (txt-wrap "TL" (list labWX wSpecY) (peb-th 'SMALL) 0 wBarLen wLine2_2L))
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
            (list (- labWX (* 160 *PEB-TEXT-SCALE*)) wTargetY) "")
          (command "PLINE"
            (list (- labWX (* 160 *PEB-TEXT-SCALE*)) wTargetY)
            "W" (* 55 *PEB-TEXT-SCALE*) 0
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
      (txt "ML" (list labWX labWY) (peb-th 'SMALL) 0 wallLbl)))
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

;;  draw-purlins-mono — Z-purlins along a SINGLE mono slope (owner 14-Jul: SS/LT purlins must follow
;;  the one-way rafter, not a gable/double-slope).  Rafter top runs (0,H) -> (W, H+monoRise); each
;;  purlin is a Z perpendicular to that slope, top flange against the sheeting.
(defun draw-purlins-mono (W H monoRise / depth wtop wbot lip lipDx lipDy slopeLen sa ca
                          nP purlinSpacing uX uY vX vY d x y
                          v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  (setvar "CLAYER" "PURLINS")
  (setq depth 200.0 wtop 60.0 wbot 60.0 lip 20.0 lipDx (* lip 0.5) lipDy (* lip 0.866))
  (setq slopeLen (sqrt (+ (* W W) (* monoRise monoRise))))
  (setq sa (/ monoRise slopeLen) ca (/ W slopeLen))
  (setq uX ca uY sa vX (- 0 sa) vY ca)          ; along slope / perpendicular up
  (setq nP (max 1 (fix (+ 0.5 (/ slopeLen 1500.0)))) purlinSpacing (/ slopeLen nP))
  (setq d purlinSpacing)
  (while (<= d (- slopeLen 1.0))
    (setq x (* d ca) y (+ H (* d sa)))
    (setq v6x (+ x (* (- lipDx wbot) uX) (* lipDy vX)) v6y (+ y (* (- lipDx wbot) uY) (* lipDy vY)))
    (setq v5x (+ x (* (- 0 wbot) uX)) v5y (+ y (* (- 0 wbot) uY)))
    (setq v4x x v4y y)
    (setq v3x (+ x (* depth vX)) v3y (+ y (* depth vY)))
    (setq v2x (+ x (* wtop uX) (* depth vX)) v2y (+ y (* wtop uY) (* depth vY)))
    (setq v1x (+ x (* (- wtop lipDx) uX) (* (- depth lipDy) vX)) v1y (+ y (* (- wtop lipDx) uY) (* (- depth lipDy) vY)))
    (command "PLINE" (list v6x v6y) "W" 1.5 1.5 (list v5x v5y) (list v4x v4y) (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
    (setvar "FILLETRAD" 4.0)
    (command "FILLET" "P" (entlast))
    (setq d (+ d purlinSpacing)))
  (setvar "PLINEWID" 0.0))

;; one Z-section purlin at (cx cy) in the given (u,v) rafter frame — used to FORCE a purlin
;; exactly on a throat edge (roof-monitor rule); mirrors the inline profile in draw-purlins.
(defun draw-z-purlin (cx cy uX uY vX vY depth wtop wbot lipDx lipDy /
                      v1x v1y v2x v2y v3x v3y v4x v4y v5x v5y v6x v6y)
  (setvar "CLAYER" "PURLINS")
  (setq v6x (+ cx (* (- lipDx wbot) uX) (* lipDy vX)) v6y (+ cy (* (- lipDx wbot) uY) (* lipDy vY))
        v5x (+ cx (* (- 0 wbot) uX)) v5y (+ cy (* (- 0 wbot) uY))
        v4x cx v4y cy
        v3x (+ cx (* depth vX)) v3y (+ cy (* depth vY))
        v2x (+ cx (* wtop uX) (* depth vX)) v2y (+ cy (* wtop uY) (* depth vY))
        v1x (+ cx (* (- wtop lipDx) uX) (* (- depth lipDy) vX)) v1y (+ cy (* (- wtop lipDx) uY) (* (- depth lipDy) vY)))
  (command "PLINE" (list v6x v6y) "W" 1.5 1.5 (list v5x v5y) (list v4x v4y) (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
  (setvar "FILLETRAD" 4.0)
  (command "FILLET" "P" (entlast)))

(defun draw-purlins (W H rise throatWin / depth wtop wbot lip lipDx lipDy
                     slopeLen sa ca d xL yL xR yR nP purlinSpacing
                     d_ridge_offset d_ridge_purlin tLo tHi
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
  ;; P1 (owner 19-Jul): a purlin is FORCED at the eave (d=0) / under the eave+valley gutters; the run to the
  ;; ridge-offset is then BALANCE-SPACED into bays of 1.25-1.5 m: n = ceil(run/1500), stepped to n-1 if that
  ;; would drop the bay below 1250 (so every intermediate spacing lands in [1250,1500]).
  (setq nP (max 1 (fix (+ 0.9999 (/ d_ridge_purlin 1500.0)))))
  (if (and (> nP 1) (< (/ d_ridge_purlin nP) 1250.0)) (setq nP (1- nP)))
  (setq purlinSpacing (/ d_ridge_purlin nP))
  ;; roof-monitor THROAT window (X): skip purlins inside it, force one on each edge (owner 19-Jul).
  ;; The two guards below KEEP a purlin when it falls OUTSIDE the throat — left half
  ;; keeps `xL < tLo`, right half keeps `xR > tHi`.  So with NO throat the sentinels
  ;; have to be the values that make those tests always TRUE: tLo = +BIG, tHi = -BIG.
  ;; They were the other way round (-1e12 / +1e12), which made both tests always FALSE
  ;; and silently dropped EVERY purlin on a normal roof — only the eave ones, drawn
  ;; elsewhere, survived (owner 25-Aug: "purlins are missing").
  (setq tLo (if throatWin (car throatWin) 1e12) tHi (if throatWin (cadr throatWin) -1e12))

  ;; LEFT half: u along rafter toward ridge = (ca, sa); v perp up = (-sa, ca)
  (setq uX ca   uY sa)
  (setq vX (- 0 sa)   vY ca)
  (setq d 0.0)                 ; P1: FIRST purlin AT the eave (under the eave gutter)
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
    (if (< xL tLo)                       ; skip purlins INSIDE the monitor throat
      (progn
        (command "PLINE"
          (list v6x v6y)
          "W" 1.5 1.5
          (list v5x v5y) (list v4x v4y)
          (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
        (setvar "FILLETRAD" 4.0)   ; smaller radius to keep lip visible
        (command "FILLET" "P" (entlast))))
    (setq d (+ d purlinSpacing)))
  ;; FORCE a purlin exactly on the LEFT throat edge so the trimmed sheeting dies into it
  (if throatWin (draw-z-purlin tLo (+ H (* (/ tLo ca) sa)) uX uY vX vY depth wtop wbot lipDx lipDy))

  ;; (No purlin AT the ridge centreline - 600mm gap left for the ridge panel)

  ;; RIGHT half: u along rafter toward ridge = (-ca, sa); v perp up = (sa, ca)
  (setq uX (- 0 ca)   uY sa)
  (setq vX sa   vY ca)
  (setq d 0.0)                 ; P1: FIRST purlin AT the eave (under the eave gutter)
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
    (if (> xR tHi)                       ; skip purlins INSIDE the monitor throat
      (progn
        (command "PLINE"
          (list v6x v6y)
          "W" 1.5 1.5
          (list v5x v5y) (list v4x v4y)
          (list v3x v3y) (list v2x v2y) (list v1x v1y) "")
        (setvar "FILLETRAD" 4.0)   ; smaller radius to keep lip visible
        (command "FILLET" "P" (entlast))))
    (setq d (+ d purlinSpacing)))
  ;; FORCE a purlin exactly on the RIGHT throat edge
  (if throatWin (draw-z-purlin tHi (+ H (* (/ (- W tHi) ca) sa)) uX uY vX vY depth wtop wbot lipDx lipDy))

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
  ;; P1 (owner 19-Jul): a purlin is FORCED at the eave (d=0) / under the eave+valley gutters; the run to the
  ;; ridge-offset is then BALANCE-SPACED into bays of 1.25-1.5 m: n = ceil(run/1500), stepped to n-1 if that
  ;; would drop the bay below 1250 (so every intermediate spacing lands in [1250,1500]).
  (setq nP (max 1 (fix (+ 0.9999 (/ d_ridge_purlin 1500.0)))))
  (if (and (> nP 1) (< (/ d_ridge_purlin nP) 1250.0)) (setq nP (1- nP)))
  (setq purlinSpacing (/ d_ridge_purlin nP))
  (setq purlinH depth)

  (setq i 0)
  (while (< i numGab)
    (setq gxL (* i gW))
    (setq gxR (+ gxL gW))

    ;; --- LEFT half of gable i ---
    (setq uX ca  uY sa)
    (setq vX (- 0 sa)  vY ca)
    (setq d 0.0)                 ; P1: FIRST purlin AT the eave / valley (under the eave + valley gutters)
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
    (setq d 0.0)                 ; P1: FIRST purlin AT the eave / valley (under the eave + valley gutters)
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

(defun draw-girts (W H brickH rightH leftOnly / depth wtop wbot lip lipDx lipDy
                   girtSpacing nG y topY botY desSpacing labGX labGY
                   topYr nGr girtSpacingR
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

  ;; RIGHT wall girts: from botY to topYr.  rightH (optional, = high eave of a single slope)
  ;; makes the right girts climb to the HIGH eave; otherwise topYr = topY (symmetric gable).
  ;; leftOnly (LEAN-TO): the right side is the existing masonry wall -> NO PEB girts there.
  (if (not leftOnly)
    (progn
  (setq topYr (if rightH (- rightH 160.0) topY))
  (setq nGr   (max 1 (fix (+ 0.5 (/ (- topYr botY) desSpacing)))))
  (setq girtSpacingR (/ (- topYr botY) nGr))
  (setq y botY)
  (while (<= y (+ topYr 0.5))
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
    (setq y (+ y girtSpacingR)))))

  ;; "GIRT" leader label — native MLEADER with grouped fallback.
  ;; Arrow tip snapped to an actual girt position (2nd girt from bottom).
  (setvar "CLAYER" "TEXT")
  (setq labGX (max 1800.0 (+ ht 800.0)))
  (setq labGY (+ botY girtSpacing))
  (peb-label-pline-leader "GIRT"
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

(defun peb-pipe-line (x1 y1 x2 y2 / es)
  ;; DOTTED down-pipe line (owner 19-Jul G2, UNIVERSAL): every VALLEY / CANTILEVER downpipe renders with the
  ;; mm-based PEBPIPE dotted linetype so it reads as a pipe, not a solid member.  Per-entity LT scale = 1/LTSCALE
  ;; makes the dots render at TRUE mm size (the huge global LTSCALE would otherwise stretch the pattern to solid).
  (if (not (tblsearch "LTYPE" "PEBPIPE"))
    (vl-catch-all-apply (function (lambda ()
      (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbLinetypeTableRecord") '(2 . "PEBPIPE") '(70 . 0)
                     '(3 . "Pipe __ __ __") '(72 . 65) '(73 . 2) '(40 . 150.0)
                     '(49 . 60.0) '(74 . 0) '(49 . -90.0) '(74 . 0)))))))
  (setq es (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
  (if (tblsearch "LTYPE" "PEBPIPE")
    (entmake (list '(0 . "LINE") (cons 8 "GUTTER") '(6 . "PEBPIPE") (cons 48 es) (cons 370 30)
                   (cons 10 (list x1 y1 0.0)) (cons 11 (list x2 y2 0.0))))
    (progn (setvar "CLAYER" "GUTTER")                    ; fallback: solid if the linetype couldn't be created
           (command "LINE" (list x1 y1) (list x2 y2) "")))
  (princ))

(defun draw-downpipes (W H brickH mono / dpW dpOff dpX1L dpX2L dpX1R dpX2R dpTop
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
  ;; owner 19-Jul: EAVE down pipe stays SOLID (only VALLEY/CANTILEVER down pipes are dotted — see G2).
  (command "LINE" (list dpX1L 0.0)   (list dpX1L dpTop) "")
  (command "LINE" (list dpX2L 0.0)   (list dpX2L dpTop) "")
  (command "LINE" (list dpX1L dpTop) (list dpX2L dpTop) "")
  (command "LINE" (list dpX1L 0.0)   (list dpX2L 0.0)   "")
  ;; RIGHT side pipe (no label) — SKIPPED for a mono roof (drains to the LOW/left eave only)
  (if (not mono)
    (progn
      (setq dpX1R (+ W dpOff))
      (setq dpX2R (+ dpX1R dpW))
      (command "LINE" (list dpX1R 0.0)   (list dpX1R dpTop) "")
      (command "LINE" (list dpX2R 0.0)   (list dpX2R dpTop) "")
      (command "LINE" (list dpX1R dpTop) (list dpX2R dpTop) "")
      (command "LINE" (list dpX1R 0.0)   (list dpX2R 0.0)   "")))
  ;; "DOWN PIPE" leader label — native MLEADER with grouped fallback.
  ;; LEFT side only, INSIDE the building, mid-height of brick wall.
  (setvar "CLAYER" "TEXT")
  (setq labDX (max 1800.0 (+ ht 800.0)))
  ;; Half the BRICK height puts the callout mid-brick — but a fully SHEETED wall has
  ;; brickH = 0, which dropped the text onto the FFL line and the ground hatch, where
  ;; it was unreadable (owner 25-Aug audit).  With no brick to sit against, hang it a
  ;; quarter of the way up the wall instead.
  (setq labDY (if (> brickH 400.0) (* brickH 0.5) (* H 0.25)))
  (peb-label-pline-leader "DOWN PIPE"
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
  (peb-label-pline-leader "COLUMN"
                         (list labCX labCY)        ; labelPos (inside bldg)
                         (list 250.0 labCY)        ; arrowPt on inner flange
                         "H"
                         220)
  (setvar "PLINEWID" 0.0)
)

(defun draw-eave-features (W H mono slope /
                          inH outH botW innerX outerX rslope
                          gyTopIn gyBot gyTopOut gL gR
                          tx ty ax arrowX arrowY)
  ;;  MAIMAAR-standard eave gutter (open-top trough):
  ;;     INNER (toward building) vertical = 165 mm  with drip-lip on top
  ;;                                          (roof sheeting drops water here)
  ;;     OUTER (away from building) vert  = 196 mm  with hem fold
  ;;                                          (taller wall retains water)
  ;;     BOTTOM flat                       = 190 mm  (= 20 + 170)
  ;;  Inner top sits at H + 200 = roof-sheeting bottom level at the eave.
  (setvar "CLAYER" "GUTTER")
  ;; G3 (owner 19-Jul, UNIVERSAL): anchor the INNER LIP to the roof-sheet BOTTOM at the lip x (= eave ±200), so
  ;; the sheet laps OVER the lip and drips into the trough — not a fixed H+200 that floats above the sloped
  ;; sheet.  slope = roof rise/run at the eave; the sheet bottom (rafter top + purlin 200) drops slope*200 over
  ;; the 200 mm lip offset.  slope nil/0 => the legacy H+200 (flat sheet at the rafter line).
  (setq rslope (if slope slope 0.0))
  (setq inH    165.0)               ; INNER vertical height (was 196 - corrected)
  (setq outH   196.0)               ; OUTER vertical height (was 165 - corrected)
  (setq botW   190.0)
  (setq gyTopIn  (- (+ H 200.0) (* rslope 200.0)))   ; inner lip = roof-sheet bottom at the lip x (owner G3)
  (setq gyBot    (- gyTopIn inH))   ; bottom y = inner top - 165
  (setq gyTopOut (+ gyBot outH))    ; outer top = bottom + 196

  ;; ----- LEFT side eave gutter (per picture 2 reference) -----
  ;; Inner side (toward building) at innerX=-200, height=165 with 100mm lip
  ;;   bent INWARD into the gutter trough (= away from building, -x direction).
  ;;   Roof sheet rests on top of this lip.
  ;; Outer side (away from building) at outerX=-390, height=196 with hem fold.
  (setq innerX -200.0)
  (setq outerX (- innerX botW))
  ;; PARAPET (FA_*): this eave has no gutter.  A parapet stands in the wall
  ;; plane, so a trough at 200..390 OUTBOARD would hang in open air outside the
  ;; building -- the roof drains inboard into the valley gutter drawn by
  ;; peb-fascia-parapet instead.  Flag set once in C:PEB-SECTION.
  (if (not *PEB-FA-PARA-L*)
  (progn
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
    "")))

  ;; ----- RIGHT side eave gutter — SKIPPED for a mono roof (water drains to the LOW/left eave) -----
  ;; … and skipped for a PARAPET on this eave, same reason as the left side.
  (if (and (not mono) (not *PEB-FA-PARA-R*))
  (progn
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
    "")))

  ;; ----- "EAVE GUTTER" labels — same rule as PURLIN/wall sheeting --
  ;; Arrow segment vertical 1200·TS (so MLEADER renders arrowhead),
  ;; horizontal "bar" segment exactly 300 mm with text starting at the
  ;; bar's right end.  Text X = arrow X + 300.
  (setvar "CLAYER" "TEXT")
  ;; ---- ONE gutter callout for the whole section (owner 25-Aug) ------------
  ;; Not one EAVE GUTTER callout -- ONE gutter callout, full stop.  It rides the
  ;; ANNOTATED eave (the same one that carries the fascia dims), and names whatever
  ;; gutter that eave actually has: if it is a parapet, peb-fascia-parapet writes
  ;; VALLEY GUTTER there and this routine stays silent, which is why the parapet
  ;; case is tested FIRST.  A building with a parapet on one wall and a fascia on
  ;; the other used to get both labels -- two gutters, but still two callouts.
  ;;
  ;; The last two clauses are the fallback: if the annotated eave has no gutter at
  ;; all (a MONO roof drains to the low/left eave only, so the right one is dry),
  ;; the callout moves to the eave that does, rather than vanishing off the sheet.
  (setq gL (not *PEB-FA-PARA-L*)                        ; left eave HAS an eave gutter
        gR (and (not mono) (not *PEB-FA-PARA-R*)))      ; right eave HAS one
  (cond
    ;; annotated eave is a PARAPET -> its VALLEY GUTTER is the section's one callout
    ((if *PEB-FA-LAB-R* *PEB-FA-PARA-R* *PEB-FA-PARA-L*) nil)
    ((and gL (or (not *PEB-FA-LAB-R*) (not gR)))
      (setq ax (- 0.0 botW (* 100 *PEB-TEXT-SCALE*)))    ; arrow X
      (setq tx (+ ax 300.0))                             ; text 300 right of arrow
      (setq ty (+ gyTopOut (* 1200.0 *PEB-TEXT-SCALE*)))
      (peb-label-with-leader "EAVE GUTTER"
                             (list tx ty)                ; labelPos
                             (list ax gyTopOut)          ; arrowPt
                             "V"
                             220))
    (gR
      (setq ax (+ W botW (* 100 *PEB-TEXT-SCALE*)))      ; arrow X
      (setq tx (+ ax 300.0))                             ; text 300 right of arrow
      (setq ty (+ gyTopOut (* 1200.0 *PEB-TEXT-SCALE*)))
      (peb-label-with-leader "EAVE GUTTER"
                             (list tx ty)
                             (list ax gyTopOut)
                             "V"
                             220)))
  (setvar "PLINEWID" 0.0)
)

;; ============================================================================
;; VERTICAL FASCIA — cross-section detail   (Ref. Manual Ch.10 §10.4, p.238-244)
;; ----------------------------------------------------------------------------
;;  Owner 25-Jul: "develop the single one — the Vertical one.  Capture the IDEA
;;  from the manual, but get the MATERIAL from our best reference drawings."
;;
;;  IDEA (manual p.240 "VERTICAL FASCIA WITH EAVE GUTTER AND SOFFIT"):
;;    - projection  = 600 mm from the wall STEEL LINE (standard; up to 1500)
;;    - a 200 mm deep frame cage sits behind the fascia panel
;;    - height is VARIABLE, set by the roof slope = peak - eave (do NOT invent it)
;;    - cap flashing on top, soffit + soffit edge trim + sill trim at the bottom,
;;      optional back-up panel, gutter tucked BEHIND the fascia projection.
;;
;;  MATERIAL / vocabulary — our own archive, collected in
;;  reference/Folder_C/14_Fascia-Parapet/ :
;;    MSPL-21-062 "FASCIA COLUMN" · MSPL-23-154 "FASCIA PURLIN"
;;    MSPL-23-147 "FASCIA TUBE"   · MSPL-23-056 "FASCIA WITH 50mm PU SANDWICH"
;;    MSPL-22-029 "FASCIA LAYOUT PLAN" (0.5mm PPGI wall cladding house standard)
;;
;;  WHY the cage is 400..600 out: our eave gutter occupies x = 200..390 outboard
;;  of the steel line (draw-eave-features), so the manual's 200 mm cage lands
;;  exactly in the clear zone outboard of it — the gutter ends up concealed
;;  behind the fascia, which is precisely the manual's arrangement.
;;
;;  Section axes: x=0 is NSW, x=W is FSW (same mapping peb-ridge-x uses); y=0 FFL.
;;  Only the STANDARD VERTICAL type draws here — curved/parapet keep the plan band.
;;  Everything is DERIVED from the BSF keys FA_<W>_*; nothing is recomputed.
;; ============================================================================
(defun draw-fascia-vertical (data W H rise monoRise / nsw mono hL hR rL rR)
  (if (= (strcase (peb-tb-or (MSPL-Get-Str data "FA_TOGGLE") "")) "YES")
    (progn
      ;; Callouts go on the LEFT (NSW) eave when it carries a fascia, else on the right —
      ;; one set only (see peb-fascia-side).  The right eave has the title block/notes
      ;; beside it, so long material text must never start there.
      ;; Read back from C:PEB-SECTION rather than recomputed: draw-eave-features has
      ;; already placed the section's ONE gutter callout off the same answer, and the
      ;; two must not drift apart.
      (setq nsw (not *PEB-FA-LAB-R*))
      ;; ---- ONE EAVE HEIGHT PER WALL (owner 25-Aug: "fascias are not shown on
      ;; mono-slope buildings").  A gable has both eaves at H, so one H served
      ;; both sides.  A MONO roof does not: the NSW/left eave is the LOW one at H
      ;; and the FSW/right is the HIGH one at H + monoRise.  Passing H to both
      ;; drew the right-hand fascia 4.5 m below its own eave on the 04_SingleSlope
      ;; sample -- floating halfway down the wall sheeting.
      ;;
      ;; The auto HEIGHT follows the same manual rule (fascia height = peak minus
      ;; eave) read per wall: from the LOW eave the roof climbs the full monoRise,
      ;; so that is what has to be hidden; the HIGH eave IS the peak, so there is
      ;; nothing to hide and it falls back to the default height.
      (setq mono (and monoRise (> monoRise 0.0)))
      (setq hL H
            hR (if mono (+ H monoRise) H)
            rL (if mono monoRise rise)
            rR (if mono 0.0 rise))
      ;; Annotate ONE eave only (a cross-section is symmetric and our own reference
      ;; drawings call the fascia out once): the left/NSW eave when it has a fascia,
      ;; otherwise the right.  The other eave draws geometry only.
      (vl-catch-all-apply
        (function (lambda () (peb-fascia-side data "NSW" -1.0 0.0 hL rL nsw))))
      (vl-catch-all-apply
        (function (lambda () (peb-fascia-side data "FSW"  1.0 W   hR rR (not nsw)))))))
  (setvar "CLAYER" "0")
  (setvar "PLINEWID" 0.0)
  (princ))

;; one sidewall fascia.  w = wall key, sgn = outboard direction (-1 NSW / +1 FSW),
;; xs = that wall's steel line X, H = eave height, rise = ridge rise above eave.
;; one C-section fascia girt — our "FASCIA PURLIN", the manual's TOP / BOTTOM GIRT.
;; OPEN C (never solid): web against the fascia panel, flanges running back into the cage,
;; short lips returning at the inboard mouth.  xWeb = panel inner face, xBack = cage back.
;; Width 12.0 is the engine's own cold-formed-C weight (see draw-purlins, which draws a
;; 200-deep C with 60 flanges + 20 lips the same way).  At 1.0/1.5 the girt plotted as a
;; grey hairline while every other member on the sheet was bold.
(defun peb-fascia-girt (xWeb xBack yTop yBot / lip)
  (setq lip (min 40.0 (* (abs (- yTop yBot)) 0.30)))
  (command "PLINE" (list xBack (- yTop lip)) "W" 12.0 12.0
                   (list xBack yTop)
                   (list xWeb  yTop)
                   (list xWeb  yBot)
                   (list xBack yBot)
                   (list xBack (+ yBot lip)) "")
  (setvar "PLINEWID" 0.0)
  (princ))

;; ---- CURVED-FASCIA QUARTER ROUNDS ------------------------------------------
;; The manual dimensions every curve R=500 (p.241/242/243).  Both helpers draw ONE
;; quarter of that circle as a 3-point ARC — the same idiom draw-arch-roof uses —
;; so the sweep is true geometry, not a faceted approximation.
;;
;;   peb-fascia-quarter      BOTTOM sweep: vertical at full projection, turning
;;                           inboard until it runs horizontal at the steel line.
;;   peb-fascia-quarter-top  TOP sweep: the same quarter mirrored in Y, carrying
;;                           the face up and back OVER the cage (p.242).
;;
;; `p` is the projection the vertical face sits at and `r` the radius, so the
;; inner face is drawn by passing (p - panelThickness) and (r - panelThickness):
;; concentric arcs, which is what keeps the panel a constant thickness round the
;; bend.  `yEdge` is the outermost Y the sweep reaches (the panel's bottom / top).
;; `side` is documentation only — the caller says which face it is drawing.
(defun peb-fascia-quarter (xs sgn p r yEdge side / cx cy k)
  (setq cx (+ xs (* sgn (- p r)))                 ; centre sits r inboard of the face
        cy (+ yEdge r)                            ; … and r above the edge
        k  (* r 0.70710678))                      ; 45 degrees along the sweep
  (command "ARC" (list (+ cx (* sgn r)) cy)                   ; start: on the vertical face
                 (list (+ cx (* sgn k)) (- cy k))             ; mid:   45 degrees round
                 (list cx (- cy r)))                          ; end:   horizontal, inboard
  (princ))

(defun peb-fascia-quarter-top (xs sgn p r yEdge side / cx cy k)
  (setq cx (+ xs (* sgn (- p r)))
        cy (- yEdge r)                            ; centre r BELOW the top edge
        k  (* r 0.70710678))
  (command "ARC" (list cx (+ cy r))                            ; start: horizontal, inboard
                 (list (+ cx (* sgn k)) (+ cy k))              ; mid:   45 degrees round
                 (list (+ cx (* sgn r)) cy))                   ; end:   on the vertical face
  (princ))

;; ============================================================================
;; PARAPET FASCIA  (Ref. Manual Ch.10 10.4 p.244 -- the fifth standard fascia)
;; ----------------------------------------------------------------------------
;; The other four fascias HANG OFF the building: a panel out on a 600 projection
;; with a girt cage behind it.  The parapet is not that -- it is the WALL ITSELF
;; carried up past the eave, and two things follow from that:
;;
;;   * there is NO projection.  The parapet stands in the wall-cladding plane
;;     (200 out to the girt face, 235 to the sheet face -- draw-cladding's own
;;     numbers), so nothing can be concealed behind it and nothing overhangs.
;;
;;   * there is therefore NO eave gutter.  Our eave gutter lives at 200..390
;;     OUTBOARD (draw-eave-features), which on a parapet wall is beyond the
;;     panel face -- it would hang in open air outside the building.  The roof
;;     drains INBOARD instead, into a VALLEY GUTTER at the parapet base.  That
;;     is the manual's arrangement and it is the same one draw-rc-fascia
;;     already uses for the concrete parapet on an RC frame.
;;
;; Because of that second point the parapet cannot be drawn by this routine
;; alone: the eave gutter has to be suppressed and the roof sheet trimmed, and
;; BOTH of those are drawn BEFORE the fascia detail runs.  So C:PEB-SECTION sets
;; *PEB-FA-PARA-L* / *PEB-FA-PARA-R* once, up front, and draw-eave-features and
;; draw-cladding read them.  The three constants below are the contract between
;; those routines and this one -- they live in ONE place so the trimmed sheet
;; edge and the trough it drips into can never drift apart.
;;
;; KNOWN LIMIT: the sheet trim is wired into draw-cladding (CS/MS/SS/LT) and
;; draw-cladding-mg (MG).  The ARCHED frames (ACS/AMS) draw their own curved
;; sheeting inline and are NOT trimmed -- a parapet on an arch still gets its
;; eave gutter suppressed, but the curved sheet runs past the panel face.
;; ============================================================================
(defun peb-para-gut-out () 120.0)   ; valley gutter OUTER wall, inboard of the steel line
(defun peb-para-gut-in  () 520.0)   ; valley gutter INNER upstand, inboard of the steel line
(defun peb-para-sheet-in () 300.0)  ; roof sheet is trimmed HERE -- over the trough, so it drips in

;; Is this wall's fascia the parapet one?  The same three BSF keys, read in the
;; same order, as peb-fascia-side's own dispatch -- master toggle, wall toggle,
;; then the type.  BSF is the single truth; this only reads it.
(defun peb-fascia-parapet-p (data w)
  (and (= (strcase (peb-tb-or (MSPL-Get-Str data "FA_TOGGLE") "")) "YES")
       (= (strcase (peb-tb-or (MSPL-Get-Str data (strcat "FA_" w "_TOGGLE")) "")) "YES")
       (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data (strcat "FA_" w "_TYPE")) ""))
                "*PARAPET*")))

;; one sidewall parapet.  Same arguments as peb-fascia-side, which dispatches here.
(defun peb-fascia-parapet (data w sgn xs H rise lab / fh bak gd pt
                                xGi xPi xPo xTo yB yT gh gc gb
                                gOut gIn gBot gTop)
  ;; ---- BSF: the same keys and the same precedence as the other four --------
  ;; HEIGHT -- a typed FA_<W>_HT wins outright; the auto value is the one the
  ;; vertical fascia uses (rise + 235 = the ridge SHEETING top, purlin 200 +
  ;; cladding 35 above the rafter rise), so the parapet hides the peak behind it.
  (setq fh (MSPL-Get-Num data (strcat "FA_" w "_HT")))
  ;; Same rule as the fascia: typed wins, else rise+235 with a 1200 floor (the old
  ;; second test was dead code -- see peb-fascia-side).
  (if (or (null fh) (<= fh 0.0)) (setq fh (max 1200.0 (+ rise 235.0))))
  (setq bak (= (strcase (peb-tb-or (MSPL-Get-Str data (strcat "FA_" w "_BACKUP")) "NO")) "YES"))
  ;; FA_<W>_PANEL is not read either now the callouts are gone (it only fed the text).
  ;; FA_<W>_PROJ and FA_<W>_SOFFIT are deliberately NOT read: a parapet has no
  ;; projection to dimension and no soffit to draw.  FA_<W>_GUTTER is not read
  ;; either -- its BSF default is "Eave", but an eave gutter cannot exist outside
  ;; a parapet, so the gutter is DERIVED from the type, which is the real truth.

  ;; ---- geometry -- the wall plane, continued ------------------------------
  (setq gd 200.0 pt 35.0)                               ; girt depth / panel thickness (draw-cladding)
  (setq xGi xs                                          ; INNER face of the parapet framing = steel line
        xPi (+ xs (* sgn gd))                           ; panel INNER face = outer face of the girts
        xPo (+ xs (* sgn (+ gd pt)))                    ; panel OUTER face -- FLUSH with the wall sheet below
        xTo (+ xPo (* sgn 15.0)))                       ; trims wrap 15 proud, same as the fascia
  (setq yB H yT (+ H fh))
  ;; girt depth on the sheet + edge clearance -- the same clamps the fascia
  ;; uses, so the two girts never meet on a short parapet
  (setq gh (max 60.0 (min 150.0 (* fh 0.16))))
  (setq gc (max 30.0 (min  70.0 (* fh 0.07))))
  ;; BOTTOM-GIRT BASE.  The fascia hangs its cage 400 out, in clear air; the
  ;; parapet's cage is in the wall plane, and the EAVE PURLIN is already there --
  ;; draw-purlins forces one at the eave (rule P1) and its Z reaches ~200 above
  ;; the rafter top, x -197..-103 on the NSW.  Starting the bottom girt at gc
  ;; (67 above the eave) drew it straight THROUGH that purlin, so it starts a
  ;; purlin-depth clear instead.  On a very short parapet the clamp pulls it back
  ;; down rather than letting the two girts meet.
  (setq gb (max (+ yB 30.0)
                (min (+ yB 230.0) (- yT gc gh gh 40.0))))

  ;; ---- PARAPET PANEL (cut) ------------------------------------------------
  ;; Capped at the TOP only.  The bottom is deliberately left OPEN: this is the
  ;; wall sheet running on past the eave, and a line across at yB would draw a
  ;; horizontal joint that does not exist on the building.
  (setvar "CLAYER" "CLADDING")
  (command "PLINE" (list xPo yB) "W" 1.5 1.5
                   (list xPo yT) (list xPi yT) (list xPi yB) "")

  ;; ---- CAP FLASHING (coping) -- folded over the top of the parapet --------
  ;; It falls INBOARD.  A coping sheds into the valley gutter behind it, never
  ;; down the face of the building -- the opposite of the fascia cap, which has
  ;; no gutter behind it to shed into.
  (command "PLINE" (list xTo (- yT 140.0)) "W" 1.0 1.0
                   (list xTo (+ yT 45.0))
                   (list xGi (+ yT 10.0))
                   (list xGi (- yT 140.0)) "")

  ;; ---- PARAPET GIRTS -- the wall girts continued above the eave -----------
  ;; The same open C the fascia cage carries (peb-fascia-girt): web against the
  ;; panel, flanges running back inboard.  Top girt under the coping, bottom
  ;; girt just above the eave.
  (setvar "CLAYER" "GIRTS")
  (peb-fascia-girt xPi xGi (- yT gc) (- yT gc gh))
  (peb-fascia-girt xPi xGi (+ gb gh) gb)
  ;; ---- PARAPET COLUMN -- the frame column carried up past the eave --------
  ;; structural member -> the same 12.0 weight the girts and purlins carry
  (setvar "CLAYER" "FRAME")
  (command "PLINE" (list xPi (- yT gc gh)) "W" 12.0 12.0
                   (list xGi (- yT gc gh))
                   (list xGi (+ gb gh))
                   (list xPi (+ gb gh)) "C")
  (setvar "PLINEWID" 0.0)

  ;; ---- VALLEY GUTTER at the parapet base ----------------------------------
  ;; A box gutter sitting on the rafter top, INBOARD of the eave purlin -- whose
  ;; flanges reach 60 either side of the steel line (draw-purlins forces a
  ;; purlin at d=0), hence the 120 start.  draw-cladding has already trimmed the
  ;; roof sheet to peb-para-sheet-in, so the sheet stops OVER the trough and
  ;; drips into it.  The inner upstand is held at H+190 -- just under the sheet
  ;; underside AT THE EAVE (H+200) -- so the sheeting laps OVER it at ANY slope,
  ;; since the sheet only climbs as it runs inboard.
  (setq gOut (- xs (* sgn (peb-para-gut-out)))
        gIn  (- xs (* sgn (peb-para-gut-in)))
        gBot (+ H 20.0)                                 ; trough bottom, just clear of the rafter top flange
        gTop (+ H 450.0))                               ; outer wall, carried up the parapet inner face
  (setvar "CLAYER" "GUTTER")
  (command "PLINE" (list gOut gTop) "W" 1.5 1.5
                   (list gOut gBot)
                   (list gIn  gBot)
                   (list gIn  (+ H 190.0)) "")

  ;; ---- BACK-UP PANEL (optional) -- inner skin, gutter up to the coping ----
  (if bak
    (progn (setvar "CLAYER" "CLADDING")
           (command "PLINE" (list xGi gTop) "W" 1.0 1.0 (list xGi yT) "")))

  ;; ---- LABELS + DIM -- only on the SIDE THE CALLER NOMINATED --------------
  ;; Same rule as the fascia: a cross-section is symmetric, so the callouts go
  ;; on ONE eave.  Same text column, same leader helper, same offsets -- the two
  ;; details have to read as one family on the sheet.
  (if lab
    (progn
      (setvar "CLAYER" "TEXT")
      ;; ---- NO PARAPET CALLOUTS (owner 25-Aug, same ruling as the fascia) -------
      ;; CAP FLASHING / PARAPET PANEL / PARAPET GIRT / PARAPET COLUMN are gone.
      ;; VALLEY GUTTER STAYS — it is the gutter M-Ladder, not a fascia label, and on
      ;; a parapet eave it is the ONLY gutter callout on the sheet (draw-eave-features
      ;; suppresses the eave one here).  The height dim stays too.
      ;; VALLEY GUTTER reads from INSIDE the building -- it is inboard of the
      ;; wall line, so its text cannot share the outboard column.  Kept CLOSE to
      ;; the eave and HIGH: at 2200 inboard / eave+900 the text ran straight into
      ;; the roof SLOPE TAG, which the engine parks at 75% of the half-span at
      ;; about eave+800.  Both offsets scale with the text (a bigger building
      ;; draws bigger text), because it is the TEXT that has to clear, not the mm.
      (peb-label-pline-leader "VALLEY GUTTER"
        (list (- xs (* sgn (* 700.0 *PEB-TEXT-SCALE*))) (+ H (* 1200.0 *PEB-TEXT-SCALE*)))
        (list (/ (+ gOut gIn) 2.0) (+ H 40.0)) "H" 220)
      ;; the manual dims the parapet HEIGHT.  There is no projection to dim and
      ;; no 200 cage -- those two dims belong to the other four fascias only.
      (vl-catch-all-apply
        (function (lambda ()
          (peb-dim-height-stretch xPo (+ xPo (* sgn (* 4200.0 *PEB-TEXT-SCALE*)))
                                  yB yT (rtos fh 2 0)))))))
  (setvar "CLAYER" "0")
  (setvar "PLINEWID" 0.0)
  (princ))

(defun peb-fascia-side (data w sgn xs H rise lab / typ proj fh dep pt sof bak
                             xO xPi xCo xCi yB yT gh gc cmode rad yCB yCT)
  (setq typ (strcase (peb-tb-or (MSPL-Get-Str data (strcat "FA_" w "_TYPE")) "")))
  ;; ---- WHICH OF THE MANUAL'S FIVE STANDARD FASCIAS IS THIS? ----------------
  ;; Ch.10 §10.4 p.239 "STANDARD FASCIAS VIEWED AT ENDWALL" lists exactly five:
  ;; Vertical · Bottom Curved · Top & Bottom Curved · Center Curved · Parapet.
  ;; The first four share one carcass (cage, girts, bracket, cap flashing) and
  ;; differ ONLY in the panel profile, so they run through the common body below
  ;; with `cmode` switching the outline.  The Parapet is a different animal — a
  ;; wall extension standing ON the steel line with no projection at all — so it
  ;; gets its own routine.  Match order matters: "TOP & BOTTOM" must be tested
  ;; before the bare "BOTTOM".
  (setq cmode
    (cond ((wcmatch typ "*PARAPET*")                              "P")
          ((and (wcmatch typ "*TOP*") (wcmatch typ "*BOTTOM*"))   "TB")
          ((wcmatch typ "*CENT*")                                 "C")
          ((wcmatch typ "*BOTTOM*")                               "B")
          ((wcmatch typ "*CURV*")                                 "B")   ; bare "Curved" = the bottom one
          (T                                                      "V")))
  (cond
    ;; wall not toggled -> nothing
    ((/= (strcase (peb-tb-or (MSPL-Get-Str data (strcat "FA_" w "_TOGGLE")) "")) "YES") nil)
    ;; parapet — its own detail (no projection, valley gutter behind it)
    ((= cmode "P") (peb-fascia-parapet data w sgn xs H rise lab))
    (T
      ;; ---- read the BSF, defaults ONLY where the manual states one ----------
      (setq proj (MSPL-Get-Num data (strcat "FA_" w "_PROJ")))
      (if (or (null proj) (<= proj 0.0)) (setq proj 600.0))     ; manual standard
      ;; HEIGHT — owner 25-Jul: the auto height must actually HIDE THE PEAK.  The manual
      ;; says the height is set by the roof slope (peak - eave), but the visible peak is
      ;; the ridge SHEETING top, which sits purlin (200) + cladding (35) ABOVE the rafter
      ;; rise.  So auto = rise + 235 and the fascia top lands exactly on the ridge sheet.
      ;; A typed FA_<W>_HT still wins outright — BSF is the single truth.
      (setq fh (MSPL-Get-Num data (strcat "FA_" w "_HT")))
      ;; A typed FA_<W>_HT still wins outright.  The AUTO value gets a 1200 floor:
      ;; the old second line read (if (<= fh 0.0) 1200) AFTER fh was already set to
      ;; rise+235, so it could only fire for a rise below -235 -- it was dead, and a
      ;; flat roof (rise 0) silently produced a 235 mm fascia.  The floor also
      ;; covers the HIGH eave of a mono roof, where there is no peak to hide.
      (if (or (null fh) (<= fh 0.0)) (setq fh (max 1200.0 (+ rise 235.0))))
      (setq sof (= (strcase (peb-tb-or (MSPL-Get-Str data (strcat "FA_" w "_SOFFIT")) "YES")) "YES"))
      (setq bak (= (strcase (peb-tb-or (MSPL-Get-Str data (strcat "FA_" w "_BACKUP")) "NO")) "YES"))
      ;; FA_<W>_PANEL is no longer read here: it only ever fed the FASCIA PANEL
      ;; callout, and the callouts are gone.  The panel spec still reaches the
      ;; proposal and the estimate from the BSF, which is where it belongs.
      ;; ---- geometry — a 1:1 MIRROR of the manual's p.240 sidewall detail -----
      ;; Every element is OPEN LINEWORK (PLINE outlines, no SOLID/HATCH anywhere), which
      ;; is how the manual draws it and what reads correctly at proposal scale.
      ;;   manual dim 600 = wall STEEL LINE -> fascia panel OUTER face
      ;;   manual dim 200 = fascia panel    -> back of the girt cage
      ;; Stack, outer to inner: fascia panel | girt cage (top + bottom girt, fascia
      ;; bracket/column between them) | back-up panel (optional) | eave gutter | wall.
      (setq pt  35.0)                                           ; panel thickness
      (setq dep (max 120.0 (min 200.0 (- proj 400.0))))         ; cage depth, <=200 (manual)
      (setq xO  (+ xs (* sgn proj)))                            ; panel OUTER face
      (setq xPi (+ xs (* sgn (- proj pt))))                     ; panel INNER face
      (setq xCi (+ xs (* sgn (- proj dep))))                    ; cage BACK — 400 out, so it
                                                                ; clears our gutter at 200..390
      (setq xCo (+ xO (* sgn 15.0)))                            ; trims wrap 15 proud of the panel
      (setq yB  H)                                              ; fascia bottom / soffit = eave
      (setq yT  (+ H fh))                                       ; top — hides the ridge sheet
      ;; girt depth + edge clearance, shrunk on a short fascia so the two girts never meet
      (setq gh (max 60.0 (min 150.0 (* fh 0.16))))
      (setq gc (max 30.0 (min  70.0 (* fh 0.07))))

      ;; ---- CURVE RADIUS -----------------------------------------------------
      ;; The manual dimensions every curved variant R=500 (p.241 bottom curved,
      ;; p.242 top & bottom, p.243 centre) alongside the same 600 projection and
      ;; 200 cage.  Clamp it so a shallow or short fascia cannot produce an arc
      ;; bigger than the panel it belongs to: the sweep must fit inside BOTH the
      ;; projection (it returns to the steel line) and the height.
      (setq rad (max 150.0 (min 500.0 (- proj 100.0) (* fh 0.45))))
      (setq yCB (+ yB rad))                                     ; bottom tangent point
      (setq yCT (- yT rad))                                     ; top tangent point (TB only)
      ;; ---- FASCIA PANEL (cut) ----------------------------------------------
      ;; One outer face, four profiles.  All OPEN linework — 3-point ARCs, the
      ;; idiom the rest of this engine already uses for the arch roof.
      (setvar "CLAYER" "CLADDING")
      (cond
        ;; ---- CENTER CURVED (p.243): the face BOWS OUTBOARD — both ends sit
        ;; back at the cage face (meeting the top and bottom girts) and the
        ;; crown reaches full projection at mid height.  It keeps a soffit.
        ((= cmode "C")
         ;; outer face of the bow …
         (command "ARC" (list xCi yT) (list xO (* 0.5 (+ yB yT))) (list xCi yB))
         ;; … and its inner face, one panel thickness in
         (command "ARC" (list xCi (- yT pt)) (list xPi (* 0.5 (+ yB yT))) (list xCi (+ yB pt))))
        ;; ---- BOTTOM CURVED (p.241) and TOP & BOTTOM CURVED (p.242): a flat
        ;; face with a quarter-round sweeping back INBOARD to the steel line.
        ;; The bottom curve replaces the soffit — the manual draws no soffit
        ;; panel on these two, the sweep itself closes the underside.
        ((or (= cmode "B") (= cmode "TB"))
         ;; outer face, top down to the bottom tangent
         (command "PLINE" (list xO (if (= cmode "TB") yCT yT)) "W" 1.5 1.5 (list xO yCB) "")
         ;; bottom quarter-round: vertical at xO -> horizontal at the steel line
         (peb-fascia-quarter xs sgn proj rad yB "OUT")
         (peb-fascia-quarter xs sgn (- proj pt) (- rad pt) (+ yB pt) "IN")
         ;; inner face
         (command "PLINE" (list xPi (if (= cmode "TB") yCT yT)) "W" 1.5 1.5
                          (list xPi (+ yCB 0.0)) "")
         (if (= cmode "TB")
           (progn
             ;; top quarter-round, mirrored in Y: vertical face sweeping up and
             ;; back over the cage, terminating at the ANGLE (manual p.242).
             (peb-fascia-quarter-top xs sgn proj rad yT "OUT")
             (peb-fascia-quarter-top xs sgn (- proj pt) (- rad pt) (- yT pt) "IN"))
           ;; plain bottom-curved: square top, closed across
           (command "PLINE" (list xO yT) "W" 1.5 1.5 (list xPi yT) "")))
        ;; ---- STANDARD VERTICAL (p.240): flat face, square top and bottom ----
        (T
         (command "PLINE" (list xO yB) "W" 1.5 1.5 (list xO yT)
                          (list xPi yT) (list xPi yB) "C")))
      ;; ---- CAP FLASHING — folded trim wrapping OVER the top of the cage -----
      ;; outer leg down the face, over the top falling slightly inboard, inner leg down.
      (command "PLINE" (list xCo (- yT 140.0)) "W" 1.0 1.0
                       (list xCo (+ yT 30.0))
                       (list xCi (+ yT 75.0))
                       (list xCi (- yT 70.0)) "")
      ;; ---- TOP + BOTTOM GIRT (our "FASCIA PURLIN") — C-section, opening inboard
      (setvar "CLAYER" "GIRTS")
      (peb-fascia-girt xPi xCi (- yT gc) (- yT gc gh))          ; top girt, under the cap
      (peb-fascia-girt xPi xCi (+ yB gc gh) (+ yB gc))          ; bottom girt, over the sill
      ;; ---- FASCIA BRACKET / COLUMN — the member between the two girts -------
      ;; structural member -> the same 12.0 weight the girts and purlins carry
      (setvar "CLAYER" "FRAME")
      (command "PLINE" (list xPi (- yT gc gh)) "W" 12.0 12.0
                       (list xCi (- yT gc gh))
                       (list xCi (+ yB gc gh))
                       (list xPi (+ yB gc gh)) "C")
      (setvar "PLINEWID" 0.0)
      ;; ---- MOUNTING BRACKET — what actually holds the fascia on the building --
      ;; Owner 25-Aug: "vertical fascia is 500mm away from columns".  The cage backs
      ;; onto xCi (400 out) and the column stands on the steel line, so the detail
      ;; left a 400 mm void with nothing drawn across it and the whole assembly read
      ;; as floating in front of the wall.  This is the bracket it hangs off.
      ;; Height: 300 ABOVE the eave, so it passes OVER the eave gutter (that trough
      ;; occupies 200..390 out and tops out around eave+235) rather than straight
      ;; through it — which is how the real bracket clears it.  It also clears the
      ;; wall sheeting, which stops at the eave.
      ;; Structural member -> the same 12.0 weight the girts and the fascia column
      ;; carry, so it reads as steel and not as a trim line.
      (setvar "CLAYER" "FRAME")
      (command "PLINE" (list xs (+ yB 300.0)) "W" 12.0 12.0
                       (list xCi (+ yB 300.0)) "")
      (setvar "PLINEWID" 0.0)
      ;; ---- BACK-UP PANEL (optional — manual p.240 lower detail) -------------
      (if bak
        (progn (setvar "CLAYER" "CLADDING")
               (command "PLINE" (list xCi yB) "W" 1.0 1.0 (list xCi yT) "")))
      ;; ---- SILL TRIM at the bottom outer corner (always, manual) ------------
      (setvar "CLAYER" "CLADDING")
      (command "PLINE" (list xCo (+ yB 140.0)) "W" 1.0 1.0
                       (list xCo (- yB 15.0))
                       (list xPi (- yB 15.0)) "")
      ;; ---- SOFFIT PANEL + SOFFIT EDGE TRIM ---------------------------------
      (if sof
        (progn
          (command "PLINE" (list xO yB) "W" 1.5 1.5 (list xs yB)
                           (list xs (- yB pt)) (list xO (- yB pt)) "C")
          ;; edge trim: short return wrapping the soffit's outer end
          (command "PLINE" (list xCo (- yB pt 60.0)) "W" 1.0 1.0
                           (list xCo (- yB pt))
                           (list (+ xO (* sgn -60.0)) (- yB pt)) "")))
      ;; ---- LABELS + DIMS — only on the SIDE THE CALLER NOMINATED -----------
      ;; A cross-section is symmetric: our own reference drawings (MSPL-20-057,
      ;; MSPL-23-056) call the fascia out ONCE, not on both eaves.  Labelling both
      ;; sides also pushed the long material text into the notes panel on the right.
      ;; Leaders are STRAIGHT ("S") fanning to a text column — the manual's own style
      ;; — because four callouts cannot share a fascia only `fh` (~1 m) tall.
      (if lab
        (progn
          (setvar "CLAYER" "TEXT")
          ;; ---- NO FASCIA CALLOUTS (owner 25-Aug: "remove the labeling of fascias") --
          ;; CAP FLASHING / FASCIA PANEL / FASCIA PURLIN / FASCIA COLUMN / SILL TRIM /
          ;; SOFFIT PANEL are all gone.  The geometry names itself at this scale and the
          ;; six-leader fan was the densest thing on the eave.  The DIMS stay: they carry
          ;; the height, projection and cage depth, which no amount of linework shows.
          ;; (If they ever come back, they hung off a text column at xO + 2500·TS.)
          ;; The HEIGHT dim goes
          ;; OUTBOARD of the text column (4200 > the 2500 text offset) so no leader ever
          ;; crosses its witness line; the other eave then stays completely clean.  On the
          ;; dim-only eave these collided with the engine's EAVE GUTTER label and the
          ;; vertical CLEAR HEIGHT text, which spans the whole wall.
          (vl-catch-all-apply
            (function (lambda ()
              (peb-dim-height-stretch xO (+ xO (* sgn (* 4200.0 *PEB-TEXT-SCALE*)))
                                      yB yT (rtos fh 2 0)))))
          (vl-catch-all-apply
            (function (lambda ()
              (peb-dim-h-stretch xs xO (- yB (* 3400.0 *PEB-TEXT-SCALE*))
                                 (rtos proj 2 0)))))
          ;; the manual dims the cage depth too (its "200"), stacked above the projection
          (vl-catch-all-apply
            (function (lambda ()
              (peb-dim-h-stretch xCi xO (- yB (* 2100.0 *PEB-TEXT-SCALE*))
                                 (rtos dep 2 0)))))))
      ;; ---- DIMS go on the OPPOSITE eave from the callouts ---------------------
      ;; The two dims the manual itself calls out (fascia height + projection).  Putting
      ;; them on the labelled side forced every leader to cross the height witness line;
      ;; the unlabelled eave is empty, so the pair reads cleanly there.  When only ONE
      ;; wall carries a fascia it takes both, and the dim sits inboard of the text column.
      (setvar "PLINEWID" 0.0)))
  (princ))

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

;; Letter for a FRAME column in the section: its position in the MERGED width grid
;; — width-module lines plus end-wall columns — which is exactly what the Column
;; Layout Plan letters.  The section used to letter by its own column index, so a
;; clear span called its two columns A and B while the plan called the same two
;; lines A and D (with B and C the end-wall columns between them).  Falls back to
;; the plain index if the merged grid is unavailable.
(defun peb-sec-grid-letter (cx wgrid idx mods / k best bd)
  (if (null wgrid)
    (chr (+ 65 idx))
    (progn
      (setq k 0 best idx bd 1e18)
      (foreach st wgrid
        (if (< (abs (- st cx)) bd) (setq bd (abs (- st cx)) best k))
        (setq k (1+ k)))
      ;; peb-width-letter, not (chr 65+best): the plan letters the width REVERSED (A at
      ;; the far side wall), so this printed the section back to front - A where the plan
      ;; says F (owner 26-Aug).  See the audit table on peb-width-letter.
      ;; peb-width-mark: the merged grid carries the infill posts too, and a post takes the
      ;; primed letter of the main line above it rather than a letter of its own (4B.61).
      (if (boundp 'peb-width-mark)
        (peb-width-mark (nth best wgrid) wgrid mods)
        (if (boundp 'peb-width-letter) (peb-width-letter best (length wgrid)) (chr (+ 65 best)))))))

(defun draw-grid-bubble (cx cy r label)
  ;;  Single circle grid bubble (bottom of column), with grid letter inside.
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (setvar "CLAYER" "GRID")
  (command "CIRCLE" (list cx cy) r)
  (setvar "TEXTSTYLE" "PEB-TITLE")
  (command "TEXT" "J" "MC" (list cx cy) (* r 0.7) 0 label)
)

;; ---- CANTILEVER-SHADE NAMING (owner 9-Jul) ------------------------------------------------------
;; Duplicate of the Plan engine's copy (Plan loads last and wins; kept here so Section stands alone).
;; "Butterfly"/"Falcon" name ONLY the 2-wing pair.  The 1-wing pair is "Single-Sided Cantilever",
;; qualified by slope direction relative to its single column line -- NOT "Butterfly/Falcon 1-wing".
(defun peb-canopy-name (stype data)
  (cond
    ((= stype "BF")
      (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES")
        "FALCON CANOPY (CENTRE PEAK)"
        "BUTTERFLY CANOPY (VALLEY)"))
    ((= stype "CC")
      ;; short forms (owner 9-Jul): UPWARD = slope towards the columns (low at the column, rises to
      ;; the free end); DOWNWARD = otherwise.  Slope read from the column outward to the free edge.
      (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_LOW_AT_COLUMN") "")) "YES")
        "CANTILEVER - SLOPES UPWARD"
        "CANTILEVER - SLOPES DOWNWARD"))
    (T nil)
  )
)

(defun peb-structure-label (stype)
  (cond
    ((= stype "CS") "CLEAR SPAN GABLE")
    ((= stype "SS") "SINGLE SLOPE")
    ((= stype "MS") "MULTI-SPAN")
    ((= stype "LT") "LEAN-TO")
    ((= stype "MG") "MULTI-GABLE")
    ((= stype "FR") "FLAT ROOF")
    ((= stype "F2") "FLAT ROOF (G+1)")
    ((= stype "RC") "ROOF ON RCC COLUMNS")
    ((member stype '("CC" "BF")) (if *PEB-CANOPY-NAME* *PEB-CANOPY-NAME* "CANTILEVER CANOPY"))
    ((= stype "PP") "PETROL PUMP CANOPY")
    ((= stype "ACS") "ARCHED CLEAR SPAN")
    ((= stype "AMS") "ARCHED MULTI-SPAN")
    (T "CLEAR SPAN GABLE")
  )
)

;; ===================== MAIN COMMAND =====================

(defun split-at-first-digit (s / p)
  ;;  Split a sheeting label "<X> SHEETING  <spec>" into ("<X> SHEETING" "<spec>") — the heading is
  ;;  ALWAYS "... SHEETING" and the material (which may start with a letter like "AZ") stays in the spec
  ;;  (owner 13-Jul: the heading must read "WALL SHEETING", not "WALL SHEETING AZ").  Splitting at the
  ;;  first digit put "AZ" (or any letters before the first number) into the heading — wrong.  Fall back
  ;;  to the old first-digit split only if "SHEETING" is somehow absent.
  (setq p (vl-string-search "SHEETING" (strcase s)))
  (if p
    (list (vl-string-trim " " (substr s 1 (+ p 8)))       ; up to & incl "SHEETING" (8 chars)
          (vl-string-trim " " (substr s (+ p 9))))         ; the spec (may start with "AZ ...")
    (list s nil)))

(defun peb-split-2-lines (txt / words idx total halfTotal acc line1 line2 w orig)
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
  (setq orig txt)                     ; keep the full string for the short-spec test
  ;; Tokenize on spaces.
  (setq words '())
  (while (setq idx (vl-string-search " " txt))
    (if (> idx 0) (setq words (cons (substr txt 1 idx) words)))
    (setq txt (substr txt (+ idx 2))))
  (if (> (strlen txt) 0) (setq words (cons txt words)))
  (setq words (reverse words))
  (cond
    ((<= (length words) 1) (or (car words) ""))
    ;; Single-skin specs stay on ONE line — only the "+" build-ups (insulated / sandwich) wrap to two.
    ;; owner 14-Jul: the profile suffix "(S-Type)" (or "(PPGI)") MUST sit on the SAME line as the finish
    ;; "…(PPGL)", never wrapped onto its own line.  A single-skin spec has no "+", so gate on that.
    ((not (vl-string-search "+" orig)) orig)
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
  ;; owner 14-Jul: smaller, cleaner leader arrowheads (COLUMN/GIRT/DOWN PIPE etc.) — was 250 x 80.
  (setq arrowSize (* 160 *PEB-TEXT-SCALE*))
  (setq aw (* 55 *PEB-TEXT-SCALE*))
  (cond
    ((= arrowDir "V")
      ;; First leg horizontal from text TO targetX at textY (skip if zero-length -> no stray tail dot)
      (if (> (abs (- targetX textX)) 1.0)
        (command "LINE" (list textX textY) (list targetX textY) ""))
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
      ;; First leg vertical from text TO targetY at textX (skip if zero-length -> no stray tail dot)
      (if (> (abs (- targetY textY)) 1.0)
        (command "LINE" (list textX textY) (list textX targetY) ""))
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
  ;; scaled, like its horizontal sibling: a bare 100.0 collapses to invisible on a big building
  (setq extLen (* 100.0 *PEB-DIM-SCALE*))
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
  (txt "MC" (list txtX midY) (peb-th 'SMALL) 90 label)
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
(defun tb-mtext (x y h wid attach str col / lwl)
  ;; owner UNIVERSAL RULE 22-Jul: ALL title-block / body text = ROMAND.  Entity style = ROMAND (romand.shx),
  ;; and any string WITHOUT an explicit {\F..} font code is wrapped in \Fromand.shx.  NB: the SHX font code
  ;; is CAPITAL \F; lowercase \f is the TrueType form and mis-parses an SHX name (that was the drift).  No Arial.
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
;; owner UNIVERSAL RULE: MAIN HEADINGS are BOLD but STILL ROMAND.  romand.shx has no TrueType bold, so
;; "bold" = a HEAVIER PEN (0.50mm) on the romand strokes; strip any incoming {\F..;TEXT} font wrapper.
(defun tb-mtext-bold (x y h wid attach str col / raw lw)
  (setq raw str)
  (if (and raw (vl-string-search "\\F" raw))
    (progn
      (setq raw (vl-string-subst "" "{\\Fromand.shx;" raw))
      (if (and (> (strlen raw) 0) (= (substr raw (strlen raw) 1) "}"))
        (setq raw (substr raw 1 (1- (strlen raw)))))))
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
;; ONE line, capped at the desired height mh (Arial char width ~ 0.60 x height).
(defun tb-fith (s mw mh)
  ;; AUTOFIT (owner STANDING RULE 22-Jul: dynamic text FILLS its field — grows large, only shrinks a LONG
  ;; value to fit).  Char-width ratio = romand ALL-CAPS true advance ~0.86 (uppercase romand is wide).  The
  ;; "too small" complaint was really the \f-vs-\F font bug (text rendered the NARROW Arial fallback, so it
  ;; looked tiny) — fixed separately; here 0.86 sizes to fill without overflow.  min(field-height, width/(n*0.86)).
  (min mh (/ mw (* (max 1.0 (float (strlen s))) 0.86))))

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

;; Mammut-MIRROR vertical title strip:  NOTES + disclaimer + DESIGN-LOAD table
;; anchored at the TOP, PROJECT-INFORMATION block anchored at the BOTTOM (exact
;; mirror of the Mammut proposal-drawing title block).  Every value links to the IF.
(defun peb-titleblock-mammut (X0 Y0 W H data
                              / white grey green cyan midX cw val lbl bv sm s tbBlind
                              yCur bt rh bottomH lx vx ux c1x c2x tb-get tb-hdiv)
  (setq white 7 grey 8 green 3 cyan 4)
  ;; content SIZE height: global *PEB-TB-SIZEH* caps it for a very tall (F2) flush strip so text stays
  ;; readable (top section top-aligned at Y0+H, bottom section bottom-aligned at Y0, gap in the middle).
  ;; Normally nil → s = H (fills the strip; every existing frame unchanged).
  (setq s (if (and *PEB-TB-SIZEH* (> *PEB-TB-SIZEH* 0.0)) *PEB-TB-SIZEH* H))
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
  (setq rh (* s 0.058) bt yCur yCur (- yCur rh))
  (tb-mtext midX (+ yCur (* rh 0.5))
    (tb-fith "MAIMAAR STEEL (PVT) LTD - NOT FOR CONSTRUCTION" cw (* s 0.0105)) cw 5
    (strcat "THIS DOCUMENT IS A PROPOSAL DRAWING OF\\P"
            "MAIMAAR STEEL (PVT) LTD - NOT FOR CONSTRUCTION") cyan)
  (tb-hdiv yCur)
  ;; ----- DESIGN-LOAD table (Mammut format) -----
  (setq lx (+ X0 (* W 0.05)) vx (+ X0 (* W 0.60)) ux (+ X0 (* W 0.80)))
  (setq rh (* s 0.052) bt yCur yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* s 0.0150))
    (tb-fith "SUPPORT IT'S OWN DEAD LOAD PLUS:" cw (* s 0.0120)) cw 1
    (strcat "THE BUILDING HAS BEEN DESIGNED TO\\P"
            "SUPPORT IT'S OWN DEAD LOAD PLUS:") green)
  (foreach r (list
       (list "LIVE LOAD ON ROOF"      (tb-get "LL_ROOF")  "KN/SQ.M.")
       (list "LIVE LOAD ON FRAME"     (tb-get "LL_FRAME") "KN/SQ.M.")
       (list "WIND SPEED"             (tb-get "WIND")     "KPH")
       (list "EXPOSURE CATEGORY"      (tb-get "EXPOSURE") "")
       (list "ADD'L. COLLATERAL LOAD" (tb-get "COLL")     "")
       (list "ROOF SNOW LOAD"         (tb-get "SNOW")     "KN/SQ.M.")
       (list "SEISMIC LOAD"           (tb-get "SEISMIC")  "")
       (list "TEMPERATURE LOAD"       (tb-get "TEMP")     "")
       (list "RAINFALL INTENSITY"     (tb-get "RAIN")     "MM/HR"))
    (setq rh (* s 0.0200) yCur (- yCur rh))
    (tb-mtext lx (+ yCur (* rh 0.5)) sm 0 4 (car r) white)
    (tb-mtext vx (+ yCur (* rh 0.5)) (tb-fith (cadr r) (* W 0.19) val) 0 4 (cadr r) green)
    (if (/= (caddr r) "")
      (tb-mtext ux (+ yCur (* rh 0.5)) sm 0 4 (caddr r) grey)))
  (setq rh (* s 0.024) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (+ yCur (* rh 0.4))
    (tb-fith (strcat "AS PER " (tb-get "CODE") " METAL BUILDING SYSTEMS MANUAL")
             cw (* s 0.0100)) cw 1
    (strcat "{\\Fromand.shx;AS PER " (tb-get "CODE")
            " METAL BUILDING SYSTEMS MANUAL}") green)
  (tb-hdiv yCur)

  ;; ============ BOTTOM : PROJECT INFORMATION (anchored to bottom) ============
  (setq bottomH (* s 0.515))
  (setq yCur (+ Y0 bottomH))
  (tb-hdiv yCur)
  ;; rev table : two sub-rows x cols
  (setq rh (* s 0.026))
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
  (setq bt yCur rh (* s 0.058) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "PROJECT :" grey)
  ;; owner 23-Jul: BLIND (for-estimate) version leaves PROJECT blank so the client isn't revealed.
  (setq tbBlind (peb-blind-p data))
  (tb-mtext midX (+ yCur (* rh 0.30)) (tb-fith (if tbBlind "" (tb-get "PROJECT")) cw bv) cw 5 (if tbBlind "" (tb-get "PROJECT")) green)
  (tb-hdiv yCur)
  ;; CUSTOMER
  (setq bt yCur rh (* s 0.048) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "CUSTOMER :" grey)
  ;; owner 23-Jul: CUSTOMER shown in the full version, blank in the BLIND (for-estimate) version.
  (tb-mtext midX (+ yCur (* rh 0.28)) (tb-fith (if tbBlind "" (tb-get "CUSTOMER")) cw bv) cw 5 (if tbBlind "" (tb-get "CUSTOMER")) green)
  (tb-hdiv yCur)
  ;; STEEL CONTRACTOR : enlarged logo + MAIMAAR wordmark + address (owner 10-Jul; mirrors Plan.lsp).
  ;; Hierarchy LOGO > NAME > ADDRESS.  The address used to sit inside the logo box and print white;
  ;; it is now below the wordmark, in grey.  Wordmark capped at bv (= the CUSTOMER value height) so a
  ;; proposal sheet still reads as addressed to the client.
  (setq bt yCur rh (* s 0.175) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.3)) lbl cw 1 "STEEL CONTRACTOR :" grey)
  (peb-tb-place-logo (+ X0 (* W 0.14)) (+ yCur (* rh 0.60))
                     (+ X0 (* W 0.86)) (- bt (* lbl 2.4)))
  ;; MTEXT width 0 = no wrap; fit to 0.80*cw because bold caps advance ~0.82 (tb-fith assumes 0.74).
  ;; A two-line "…(PVT)" / "LTD" in an ezdxf PNG preview is a renderer artifact, not the drawing.
  (tb-mtext-bold midX (+ yCur (* rh 0.48))
            (tb-fith "MAIMAAR STEEL (PVT) LTD" cw bv) 0 5
            "MAIMAAR STEEL (PVT) LTD" white)
  (tb-mtext (+ X0 (* W 0.06)) (+ yCur (* rh 0.39)) (* sm 0.72) cw 1 (tb-get "ADDR") grey)
  (tb-hdiv yCur)
  ;; quote / bldg rows
  (foreach pr (list (list "QUOTE NO." (tb-get "QUOTE"))
                    (list "Bldg. No." (tb-get "BLDGNO"))
                    (list "Bldg. Name." (tb-get "BLDGNAME"))
                    (list "No. Of Identical Bldg." (tb-get "IDENTICAL")))
    (setq rh (* s 0.024) yCur (- yCur rh))
    ;; owner 23-Jul: PROPOSAL (QUOTE) NO. row is PROMINENT — bold LABEL + bold value (heavier pen, same height
    ;; so it can't overrun the row); the tracking ref for ALL communication, never blanked (even blind).
    (if (= (car pr) "QUOTE NO.")
      (progn
        (tb-mtext-bold (+ X0 (* W 0.05)) (+ yCur (* rh 0.50)) lbl 0 4 (car pr) grey)
        (tb-mtext-bold (+ X0 (* W 0.52)) (+ yCur (* rh 0.50))
              (tb-fith (strcat ": " (cadr pr)) (* W 0.44) (* s 0.009)) (* W 0.45) 4
              (strcat ": " (cadr pr)) green))
      (progn
        (tb-mtext (+ X0 (* W 0.05)) (+ yCur (* rh 0.50)) lbl 0 4 (car pr) grey)
        (tb-mtext (+ X0 (* W 0.52)) (+ yCur (* rh 0.50))
              (tb-fith (strcat ": " (cadr pr)) (* W 0.44) val) (* W 0.45) 4
              (strcat ": " (cadr pr)) green)))
    (tb-hdiv yCur))
  ;; Drawing Title
  (setq bt yCur rh (* s 0.045) yCur (- yCur rh))
  (tb-mtext (+ X0 (* W 0.04)) (- bt (* lbl 1.2)) lbl cw 1 "Drawing Title :" grey)
  (tb-mtext-bold midX (+ yCur (* rh 0.26)) (tb-fith (tb-get "DRGTITLE") cw bv) cw 5
            (tb-get "DRGTITLE") green)
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

;; ── MEZZANINE in cross-section (owner 8-Jul) ──────────────────────────────────
;; Draws the intermediate mezzanine floor across the width: the deck/slab band, the
;; main-beam bottom line, and the support columns from FFL up to the beam.  Host-aware:
;; steel I columns for a PEB building; hatched concrete columns + a "chemically anchored"
;; note for an existing RCC building.  Section frame across the WIDTH: x=0..wid, y=0 = FFL.
;; MULTI-FLOOR mezzanine in section (owner 8-Jul): draws 1..N stacked mezzanine floors under the
;; (sloped) building roof.  Each floor = deck/slab band + beam-top (joists) + beam-bottom lines +
;; a "MEZZANINE FLOOR-n" label, at level = MZ1_CH_FFL_BEAM + (n-1)*MZ_FLOOR_HT.  Support columns run
;; CONTINUOUSLY from the floor up to the top floor's beam — steel I (PEB) or concrete (existing RCC,
;; with a chemical-anchor note).  Extent is full-interior or partial (MZ1_WID width).
(defun peb-draw-mezz-section (data wid frameCols / mzRcc chBeam thk beamD colW x0 x1 mm lst xs acc s prev cx band mzsp th
                              pb0 pb1 ffl bD lblH
                              numFloors floorHt f lvl bTop sTop topLvl
                              beamBot beamTop jd joistTop deckTop slabTop jsp jw jx labX labY
                              fcs s0 s1 g nsub i j)
  (if (/= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_TOGGLE") "")) "YES")
    (princ)
    (progn
      ;; ensure the mezzanine layer exists — a standalone section render (no Plan sheet first)
      ;; would otherwise fail on (setvar "CLAYER" "COMP-MEZZ") and silently skip the mezzanine.
      (if (boundp 'peb-comp-layer)
        (vl-catch-all-apply (function (lambda () (peb-comp-layer "COMP-MEZZ" 6))))
        (vl-catch-all-apply (function (lambda () (command "_.-LAYER" "_Make" "COMP-MEZZ" "_Color" "6" "" "")))))
      (setq mzRcc  (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_RCC") "")) "YES")
            chBeam (MSPL-Get-Num data "MZ1_CH_FFL_BEAM")
            thk    (MSPL-Get-Num data "MZ1_FLOOR_THK")
            beamD  500.0 colW 300.0 prev (getvar "CLAYER"))
      (if (or (null chBeam) (<= chBeam 0.0)) (setq chBeam 3000.0))
      (if (or (null thk)    (<= thk 0.0))    (setq thk 150.0))
      ;; number of stacked floors (1..N) + floor-to-floor height
      (setq numFloors (MSPL-Get-Num data "MZ_NUM_FLOORS"))
      (setq numFloors (if (and numFloors (>= numFloors 1)) (fix numFloors) 1))
      (if (> numFloors 30) (setq numFloors 30))
      (setq floorHt (MSPL-Get-Num data "MZ_FLOOR_HT"))
      (if (or (null floorHt) (<= floorHt 0.0)) (setq floorHt (+ chBeam beamD thk 300.0)))
      ;; ── RULE 4B.35 — A SHEET USES THE SAME PLACEMENT THE PLAN USES ───────────────
      ;; Owner 29-Aug: "Section Must Match with Column Layout Plan" — and before that,
      ;; "Mezzanine Section is not matching with Plan".
      ;;
      ;; This used to invent its own extent: a flat 6% inset off each side wall, narrowed
      ;; only by MZ1_WID — a key the CRM has never emitted, so that line was dead and the 6%
      ;; always won. The mezzanine therefore drew ~88% of the width, centred, whatever the
      ;; BSF actually said. On MSPL-26-271 the plan places it A→G, 49,721 mm hard against the
      ;; FSW; the section drew 56,000 mm floating in the middle. Two sheets, one building.
      ;;
      ;; peb-mz-width-band is the SAME function the Column Layout Plan and the Mezzanine
      ;; Floor Plan use, so all three sheets cannot disagree. It resolves MZ_WIDTH_GRID_FROM/TO
      ;; against the width-grid stations, falling back to MZ_WIDTH_ANCHOR + MZ_WIDTH_EXTENT.
      ;;
      ;; SEED THE STATION LIST FIRST, AND UNCONDITIONALLY. peb-mz-width-band reads the global
      ;; *PEB-WGRID-YS*, which only the PLAN drawer writes and nothing ever clears. In a
      ;; multi-area building every plan is emitted before any section, so the section would
      ;; otherwise resolve its grid letters against ANOTHER AREA's grid. peb-fr-ew-stations is
      ;; the list this sheet already letters its own bubbles from, so seeding from it makes the
      ;; band agree with the letters printed beside it — rule 4B.8.
      (vl-catch-all-apply (function (lambda ()
        (setq *PEB-WGRID-YS* (peb-fr-ew-stations data wid "LEW")))))
      (setq band (peb-mz-width-band data wid (max 300.0 (min 1000.0 (* wid 0.10)))))
      ;; Rule 4B.37: the band comes back in PLAN width coordinates; the section is drawn
      ;; mirrored so grid A reads on the left, so carry the band across with it.  The two
      ;; ends SWAP - the far edge of the band becomes its near edge.  pb0/pb1 keep the
      ;; plan-space pair, because peb-mezz-col-ys below is a plan-space function too.
      (setq pb0 (car band) pb1 (cadr band))
      (setq x0 (- wid pb1) x1 (- wid pb0))
      ;; support-column stations MODULE-TO-MODULE (owner 12-Jul): subdivide each PEB frame-column gap
      ;; by ~6 m (economical mezz spacing) and place stubs ONLY at the intermediate points — NEVER at a
      ;; frame column, because the PEB column already carries the mezz beam there.  This stops two
      ;; columns (the full-height PEB column + a mezz stub) landing in the same place (owner: "2 columns
      ;; coming at the same place").  A clear span (frame cols only at the two ends) gets evenly-spaced
      ;; intermediate stubs.  Falls back to the two walls if no frame cols were passed.
      ;; Rule 4B.35 again: take the stub stations from peb-mezz-col-ys — the SAME function the
      ;; Mezzanine Floor Plan uses — so the columns in the section stand where the plan draws
      ;; them. It honours the estimator's own MZ_COL_SPACING ("5@8331+1@8065" here); the old
      ;; local ~6000 mm subdivision below ignored that entirely, so the two sheets showed
      ;; columns in different places on the same building.
      ;; A stub is dropped wherever a PEB frame column already stands (owner 12-Jul: "2 columns
      ;; coming at the same place"), and clipped to the mezzanine band.
      (setq fcs (vl-sort (if (and frameCols (> (length frameCols) 1)) frameCols (list 0.0 wid)) '<))
      ;; TARGET SPACING COMES FROM THE ESTIMATOR, NOT FROM A CONSTANT.  This asked for stations on a
      ;; hard-coded 6 m target while the Mezzanine Floor Plan asked on MZ_COL_SPACING, so on a job that
      ;; relies on auto-division the two sheets subdivided the same module differently.  One input, both
      ;; sheets.  (On MSPL-26-279 the explicit 5@15240 chain overrides it either way.)
      (setq mzTgt (car (peb-width-order
                         (peb-parse-mod-expression
                           (peb-tb-or (MSPL-Get-Str data "MZ_COL_SPACING") "")))))
      (if (or (null mzTgt) (<= mzTgt 0.0)) (setq mzTgt 6000.0))
      (setq mzsp (vl-catch-all-apply
                   (function (lambda () (peb-mezz-col-ys data wid pb0 pb1 mzTgt)))))
      (if (vl-catch-all-error-p mzsp) (setq mzsp nil))
      (setq xs '())
      ;; OWNER 1-Sep-2026: "existing columns of main building columns will support Mezzanine Beams and
      ;; Joists" - so a stub standing on a PEB column is NOT drawn; only genuine additional columns are.
      ;;
      ;; 5 mm could never catch one.  The stub chain is walked across the DECK BAND (inset 1000 mm a
      ;; side) and rescaled to close on it, so its stations land 199-600 mm off the frame grid - and
      ;; every single one survived this test, which is why the section drew a mezzanine column beside
      ;; each full-height building column.  Same physical test the Mezzanine Floor Plan now uses: inside
      ;; half a column depth is inside the column, so it IS that column.
      (setq mzSecTol (/ (peb-col-web-depth wid) 2.0))
      (if mzsp
        (foreach acc mzsp
          (setq acc (- wid acc))            ; plan space -> section space (rule 4B.37)
          (if (and (> acc (+ x0 1.0)) (< acc (- x1 1.0))
                   (not (vl-some (function (lambda (p) (< (abs (- p acc)) mzSecTol))) fcs)))
            (setq xs (append xs (list acc)))))
        ;; fallback, unchanged: subdivide each frame-column gap by ~6 m
        (progn
          (setq i 0)
          (while (< i (1- (length fcs)))
            (setq s0 (nth i fcs) s1 (nth (1+ i) fcs) g (- s1 s0))
            (setq nsub (max 1 (fix (+ 0.5 (/ g 6000.0)))))
            (setq j 1)
            (while (< j nsub)
              (setq acc (+ s0 (* (/ g (float nsub)) j)))
              (if (and (> acc (+ x0 1.0)) (< acc (- x1 1.0))) (setq xs (append xs (list acc))))
              (setq j (1+ j)))
            (setq i (1+ i)))))
      (setq topLvl (+ chBeam (* (1- numFloors) floorHt)))    ; beam-bottom of the TOP floor
      ;; ── continuous support columns FFL → top floor beam (steel PEB / concrete RCC) ──
      (foreach cx xs
        (if mzRcc
          (progn (setvar "CLAYER" "RCC-COLUMN")
                 (command "_.RECTANG" (list (- cx colW) 0.0) (list (+ cx colW) topLvl)))
          (progn (setvar "CLAYER" "COMP-MEZZ")
                 (command "_.RECTANG" (list (- cx (/ colW 2.0)) 0.0) (list (+ cx (/ colW 2.0)) topLvl)))))
      ;; ── each stacked floor: a LAYERED build-up (owner 12-Jul: "close details — decking panels,
      ;;    concrete on top, main beams & joist in section").  From the beam bottom up:
      ;;      MEZZANINE BEAM (deep)  →  JOISTS (cut ticks)  →  PROFILED DECK (45 rib)  →  R.C. SLAB.
      ;;    Each on its dedicated layer (COMP-MEZZ-BEAM/JOIST-SEC/JOIST) so colour + line-weight match
      ;;    the Mezzanine Floor Plan.  Slab top = F.F.L of the floor.  Dims from the Mammut manual. ──
      ;; Each stacked floor uses the SAME build-up coding as the flat-roof intermediate floor (owner 15/16-Jul):
      ;; MAIN BEAM 700mm deep -> JOISTS -> 0.70mm PROFILED DECKING -> concrete (thickness = MZ1_FLOOR_THK).
      (setq f 1)
      (while (<= f numFloors)
        (setq lvl     (+ chBeam (* (1- f) floorHt))          ; MAIN BEAM BOTTOM (FFL -> under beam)
              slabTop (+ lvl 700.0 45.0 thk))                ; concrete TOP = beambot + 700 beam + 45 deck + thk
        ;; -- RULE 4B.7 - THE SLAB LANDS WHERE THE BSF SAYS IT DOES --------------------
        ;; The build-up above ASSUMES a 700 mm main beam, so the slab top it computes is the
        ;; engine's own guess. The BSF states the answer directly: MZ1_CH_FFL_SLAB is the
        ;; mezzanine F.F.L, MZ1_CH_FFL_BEAM the beam soffit under it. On MSPL-26-271 those are
        ;; 5,791 and 4,877, which imply a 744 mm beam, not 700 - so the drawn slab sat 44 mm
        ;; below the level the title block and the estimate both quote, and the CLEAR HEIGHT
        ;; OVER MEZZANINE dimension came out 4,313 against the BSF's own 4,267.
        ;;
        ;; Take the beam depth FROM the two stated levels instead of assuming it. The slab then
        ;; lands exactly on the BSF F.F.L, the over-height closes on MZ1_CH_SLAB_RAFTER, and
        ;; the drawing cannot contradict the data it was built from. Joist depth follows the
        ;; beam (rule 4B.32 - joists are FLUSH with the main beams, never stacked on them).
        ;; No BSF level, or one that cannot physically hold the deck + slab: keep the 700 guess.
        (setq ffl (MSPL-Get-Num data (strcat "MZ" (itoa f) "_CH_FFL_SLAB")))
        (if (and ffl (> ffl 0.0)) nil (setq ffl (MSPL-Get-Num data "MZ1_CH_FFL_SLAB")))
        (setq bD 700.0)
        (if (and ffl (> (- ffl lvl 45.0 thk) 150.0) (< (- ffl lvl 45.0 thk) 2500.0))
          (setq bD (- ffl lvl 45.0 thk) slabTop ffl))
        (draw-floor-buildup x0 x1 slabTop bD bD thk nil)
        (setvar "CLAYER" "TEXT")
        ;; ── RULE 4B.27 — A GAP THAT CLEARS TEXT IS COMPUTED FROM THE TEXT ─────────────
        ;; These two labels used baked offsets — 260 above the slab, 200 past x1. `txt` plots
        ;; (peb-th 'SMALL) MULTIPLIED by *PEB-TEXT-SCALE*, which on a 93 m building is ~1,140 mm,
        ;; so a 260 offset on a middle-centred string put nearly half the glyph height THROUGH
        ;; the slab it was labelling. And "F.F.L MEZZANINE" at x1+200 sat OUTSIDE the building,
        ;; in the column the CLEAR HEIGHT and BRICK MASONRY dimensions occupy — all three
        ;; overprinted each other.
        ;;
        ;; Both offsets now come from the plotted text height, and both labels stay INSIDE the
        ;; slab band, stacked 1.3 text-heights apart so they cannot touch at any building size.
        (setq th (* (peb-th 'SMALL) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)))
        (setq labX (/ (+ x0 x1) 2.0))
        ;; -- RULE 4B.27 - A LABEL MUST FIT THE THING IT LABELS ------------------------
        ;; peb-th 'SMALL is a PLOTTED height, multiplied again by TEXT-SCALE inside txt - on a
        ;; 93 m building that is ~1,140 mm a character-height, so this 44-character string drew
        ;; ~30 m wide: half the building, straight through the frame columns either side of the
        ;; mezzanine. The rung is a CAP, not a promise; shrink to whatever fits the band, and if
        ;; even that is too small to read, drop the long note and keep the short one.
        (setq lblH (peb-fit-txt-h (strcat (rtos thk 2 0) "mm R.C. SLAB ON 0.70mm PROFILED DECK PANEL")
                                  (* (- x1 x0) 0.90) (peb-th 'SMALL)))
        (if (> lblH (* (peb-th 'SMALL) 0.35))
          (txt "MC" (list labX (+ slabTop (* th 2.1))) lblH 0
               (strcat (rtos thk 2 0) "mm R.C. SLAB ON 0.70mm PROFILED DECK PANEL")))
        (setq lblH (peb-fit-txt-h "F.F.L MEZZANINE" (* (- x1 x0) 0.45) (peb-th 'SMALL)))
        (txt "MR" (list (- x1 (* th 0.4)) (+ slabTop (* th 0.8))) lblH 0
             (if (> numFloors 1) (strcat "F.F.L MEZZ-" (itoa f)) "F.F.L MEZZANINE"))
        (setq f (1+ f)))
      ;; existing-RCC host: one chemical-anchor callout
      (if mzRcc
        (progn (setvar "CLAYER" "TEXT")
               (txt "MC" (list (/ (+ x0 x1) 2.0) (+ chBeam (/ beamD 2.0))) (peb-th 'SMALL) 0
                    "BEAMS CHEM. ANCHORED TO EXISTING RCC COLUMNS")))
      (setvar "CLAYER" prev)
      (princ))))

;; Existing RCC BUILDING frame in section (owner 8-Jul): full-height concrete columns + a FLAT RCC
;; roof slab (concrete) — NOT a steel rafter/gable.  Used for the mezzanine-in-existing-RCC set,
;; where the roof is RCC too (no steel roof, purlins or cladding).  Slab drawn as a double-line
;; band (no hatch — keeps the command stream clean so the mezzanine that follows still draws).
(defun peb-mz-rcc-sec-p (data)
  (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_RCC") "")) "YES"))
(defun draw-rcc-building-frame (cols wid H cb / slabT prev rw x)
  (setq slabT (max 250.0 (* cb 0.9)) rw (* cb 1.2) prev (getvar "CLAYER"))
  (setvar "CLAYER" "RCC-COLUMN")
  ;; concrete columns full height — OUTLINE rectangles (NO hatch: a HATCH here corrupts the
  ;; command stream and silently kills the mezzanine draw that follows).  The RCC-COLUMN layer
  ;; colour reads as concrete.
  (foreach x cols
    (cond
      ((equal x (car cols)  0.001) (command "_.RECTANG" (list x 0.0) (list (+ x rw) H)))
      ((equal x (last cols) 0.001) (command "_.RECTANG" (list (- x rw) 0.0) (list x H)))
      (T (command "_.RECTANG" (list (- x (/ rw 2.0)) 0.0) (list (+ x (/ rw 2.0)) H)))))
  ;; flat RCC roof slab (double-line band)
  (command "_.RECTANG" (list 0.0 H) (list wid (+ H slabT)))
  (command "_.LINE" (list 0.0 (+ H (* slabT 0.5))) (list wid (+ H (* slabT 0.5))) "")
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (/ wid 2.0) (+ H slabT 500.0)) (peb-th 'SMALL) 0 "EXISTING RCC ROOF SLAB (BY OTHERS)")
  (setvar "CLAYER" prev))

;; ============================================================================
;;  ROOF MONITOR — migrated from the standalone MAIMAAR_PEB_Monitor.lsp (owner 19-Jul).
;;  The monitor is a MINI STANDARD PEB GABLE FRAME straddling the main ridge: two
;;  LEGS (columns) seated on the main rafter — one each side of the peak — carrying
;;  two RAFTERS up to the monitor ridge.  Leg positions come from BOTH widths:
;;    · inner clear between legs = THROAT width (RM_THROAT_WIDTH) — the vent opening
;;    · eave-to-eave extent      = OVERALL width (RM_OVERALL_WIDTH)
;;  Built to Design Manual §10.7 (hot-rolled Standard + Curved-eave).  Universal
;;  rules applied: purlins/sheeting FOLLOW the rafter; CP/GP plates at every frame
;;  joint (leg base / knee / ridge); ALL text ROMAND (txt); OPEN dim arrows; BYLAYER.
;;  Coordinate frame (section): FFL y=0, eave rafter-top y=H, ridge apex (ridgeX,H+rise).
;; ============================================================================
;;
;; ############################################################################
;; #  ROOF MONITOR — STANDING RULES  (owner 21-Jul — KEEP AT TOP, FOLLOW EXACTLY) #
;; ############################################################################
;;  R1  HEIGHT = throat / 2  (governing proportion)                    -> rmh (/ throat 2.0)
;;  R2  PURLINS + SHEETING FOLLOW the rafter profile on BOTH sides; a purlin on BOTH eave
;;      EDGES + the ridge, interior purlins EQUALLY spaced, drawn ABOVE the rafter flange.
;;  R3  CP (connection plates): TWO solid 30mm plates, 1.5mm seam, NO bolts, 100mm PAST the
;;      flanges, and the plates FOLLOW THE RAFTER FLANGE SLOPE (tilted, not horizontal).
;;  R4  GP (gusset): filled solid, ON THE RAFTER SLOPE, within the 100mm CP zone.
;;  R5  CP/GP centred EXACTLY on the legs (leg body extends OUTWARD from xLi/xRi).
;;  R6  SLOPE notation on BOTH rafters, exactly 50mm ABOVE the sheeting line, following slope.
;;  R7  DIMENSIONS: colour = WHITE (ACI 7 -> plots BLACK); arrowheads = OPEN (not filled);
;;      text = ROMAND; dual mm & ft; SMALL (scoped scale); throat dim BELOW the rafter.
;;  R8  NO ridge cap on the monitor apex.
;;  R9  ALL text ROMAND; layers per the Rule Book (PLATES/FRAME/CLADDING/PURLINS/GIRTS/DIMENSIONS).
;; ############################################################################

;; ---- monitor geometry helpers (rm-*) --------------------------------------
(defun rm-unit (dx dy / len)
  (setq len (sqrt (+ (* dx dx) (* dy dy))))
  (if (<= len 1e-9) (setq len 1.0))
  (list (/ dx len) (/ dy len)))

(defun rm-member (x1 y1 x2 y2 depth s lay / u ux uy nx ny ox oy)
  ;; prismatic member as a closed outline: axis is one face, body `depth` to side s.
  (setq u (rm-unit (- x2 x1) (- y2 y1)) ux (car u) uy (cadr u)
        nx (* (- uy) s) ny (* ux s) ox (* nx depth) oy (* ny depth))
  (setvar "CLAYER" lay)
  (command "_.PLINE" (list x1 y1) (list x2 y2)
                     (list (+ x2 ox) (+ y2 oy)) (list (+ x1 ox) (+ y1 oy)) "C"))

(defun rm-line (x1 y1 x2 y2 lay)
  (setvar "CLAYER" lay) (command "_.LINE" (list x1 y1) (list x2 y2) ""))

(defun rm-purlins (x1 y1 x2 y2 n depth s lay / u ux uy nx ny i tt px py)
  ;; n purlin ticks along the (sloped) axis — FOLLOW the frame (STANDING rule).
  (setq u (rm-unit (- x2 x1) (- y2 y1)) ux (car u) uy (cadr u)
        nx (* (- uy) s) ny (* ux s) i 1)
  (setvar "CLAYER" lay)
  (while (<= i n)
    (setq tt (/ (- i 0.5) (float n))
          px (+ x1 (* (- x2 x1) tt)) py (+ y1 (* (- y2 y1) tt)))
    (command "_.LINE" (list px py) (list (+ px (* nx depth)) (+ py (* ny depth))) "")
    (setq i (1+ i))))

(defun rm-mesh (x1 y1 x2 y2 / u ux uy nx ny i n tt px py)
  ;; bird-screen wire mesh: closure line + perpendicular cross ticks.
  (command "_.LINE" (list x1 y1) (list x2 y2) "")
  (setq u (rm-unit (- x2 x1) (- y2 y1)) ux (car u) uy (cadr u) nx (- uy) ny ux n 6 i 1)
  (while (<= i n)
    (setq tt (/ i (float (1+ n))) px (+ x1 (* (- x2 x1) tt)) py (+ y1 (* (- y2 y1) tt)))
    (command "_.LINE" (list (- px (* nx 70.0)) (- py (* ny 70.0)))
                      (list (+ px (* nx 70.0)) (+ py (* ny 70.0))) "")
    (setq i (1+ i))))

;; STANDING/UNIVERSAL RULE (owner 21-Jul): the dim TEXT AUTOSIZES to fit BETWEEN the two arrows.  Return the
;; largest text height <= baseH whose rendered string width fits the run (minus the two arrows + a margin);
;; ROMAND char width ~0.62*height, and txt-dim renders at height*(*PEB-TEXT-SCALE*), so factor TS in here.
(defun rm-dim-fit-h (str span baseH / ts availw w)
  (setq ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        availw (- (abs span) (* 2.0 (* 260.0 *PEB-DIM-SCALE*)) 150.0)
        w (max 1.0 (* (strlen str) 0.62 ts)))
  (if (< availw 220.0) (setq availw 220.0))
  (max 110.0 (min baseH (/ availw w))))

(defun rm-dim-h (x1 yo1 x2 yo2 ydim str / mid oc h)
  ;; STANDING RULE (universal): monitor dims WHITE (ACI 7 -> plots black), OPEN arrows, ROMAND text on the
  ;; DIMENSIONS layer, AUTOSIZED to fit BETWEEN the two arrows (base 300, shrunk when the run is narrow).
  (setq oc (getvar "CECOLOR") h (rm-dim-fit-h str (- x2 x1) 300.0))
  (setvar "CLAYER" "DIMENSIONS") (setvar "CECOLOR" "7")
  (command "_.LINE" (list x1 yo1) (list x1 ydim) "")
  (command "_.LINE" (list x2 yo2) (list x2 ydim) "")
  (command "_.LINE" (list x1 ydim) (list x2 ydim) "")
  (rm-arrow-h x1 ydim "R") (rm-arrow-h x2 ydim "L")
  (setq mid (/ (+ x1 x2) 2.0))
  (txt-dim "MC" (list mid (+ ydim (* 360 *PEB-DIM-SCALE*))) h 0 str)
  (setvar "CECOLOR" oc))

(defun rm-dim-v (yo1 xo1 yo2 xo2 xdim str / midY oc h)
  ;; STANDING RULE (universal): WHITE, OPEN arrows, ROMAND, AUTOSIZED to fit between the two arrows.
  (setq oc (getvar "CECOLOR") h (rm-dim-fit-h str (- yo1 yo2) 300.0))
  (setvar "CLAYER" "DIMENSIONS") (setvar "CECOLOR" "7")
  (command "_.LINE" (list xo1 yo1) (list xdim yo1) "")
  (command "_.LINE" (list xo2 yo2) (list xdim yo2) "")
  (command "_.LINE" (list xdim yo1) (list xdim yo2) "")
  (rm-arrow-v xdim yo1 "U") (rm-arrow-v xdim yo2 "D")
  (setq midY (/ (+ yo1 yo2) 2.0))
  (txt-dim "MC" (list (- xdim (* 460 *PEB-DIM-SCALE*)) midY) h 90 str)
  (setvar "CECOLOR" oc))

(defun rm-label (ptx pty tx ty just str)
  (setvar "CLAYER" "TEXT")
  (command "_.LINE" (list ptx pty) (list tx ty) "")
  (txt just (list (if (= just "ML") (+ tx (* 80 *PEB-TEXT-SCALE*)) (- tx (* 80 *PEB-TEXT-SCALE*))) ty)
       160 0 str))

;; M-LADDER member callout (owner 21-Jul): OPEN arrow at the member tip, riser UP to level `lvl`, then a
;; horizontal bar to `landx`, ROMAND text at the bar end.  Drawn on the (white) TEXT layer -> plots black.
;; Callers STAGGER `lvl` so no two bars/labels collide; to avoid a riser cutting another bar, give the
;; INNER member (nearer the ridge) the HIGHER level and land ladders on their own side.
(defun rm-mladder (tipx tipy lvl landx txt / a b right)
  (setq right (> landx tipx) a (* 210 *PEB-TEXT-SCALE*) b (* 75 *PEB-TEXT-SCALE*))
  (setvar "CLAYER" "TEXT") (setvar "PLINEWID" 0.0)
  ;; (M-ladder arrow)
  (command "_.PLINE" (list (- tipx b) (+ tipy a)) (list tipx tipy) (list (+ tipx b) (+ tipy a)) "")  ; open arrow (down at member)
  (command "_.LINE" (list tipx tipy) (list tipx lvl) "")                                             ; riser UP
  (command "_.LINE" (list tipx lvl) (list landx lvl) "")                                             ; horizontal bar
  (txt-rom (if right "ML" "MR")
           (list (if right (+ landx (* 90 *PEB-TEXT-SCALE*)) (- landx (* 90 *PEB-TEXT-SCALE*))) lvl) 150 0 txt))

(defun rm-mon-purlins (x1 y1 x2 y2 n depth skipLast / dx dy L ux uy vx vy i iEnd tt px py)
  ;; Z-purlins on the monitor rafter TOP FLANGE — ABOVE it and FOLLOWING its slope (universal rule).
  ;; n purlins placed edge-to-edge INCLUSIVE (tt = i/(n-1)) so a purlin lands on BOTH ends of the run
  ;; and the interior ones are EQUALLY spaced (owner 21-Jul).  The offset normal is forced to point UP
  ;; (vy>0) so purlins sit ABOVE the rafter on BOTH sides — the right rafter runs the other way, which
  ;; used to push them BELOW.  skipLast=T omits the tt=1 purlin so the shared RIDGE purlin isn't doubled.
  (setq dx (- x2 x1) dy (- y2 y1) L (sqrt (+ (* dx dx) (* dy dy))))
  (if (<= L 1e-6) (setq L 1.0))
  (if (< n 2) (setq n 2))
  (setq ux (/ dx L) uy (/ dy L) vx (- uy) vy ux)
  (if (< vy 0.0) (setq vx (- vx) vy (- vy)))          ; normal points UP -> purlins ABOVE the rafter
  (setq iEnd (if skipLast (1- n) n) i 0)
  (while (< i iEnd)
    (setq tt (/ (float i) (float (1- n))) px (+ x1 (* dx tt)) py (+ y1 (* dy tt)))
    (draw-z-purlin px py ux uy vx vy depth 60.0 60.0 10.0 17.3)   ; Z200/60/20, as the main roof
    (setq i (1+ i))))

(defun rm-mon-sheeting (x1 y1 x2 y2 depth thk / dx dy L ux uy vx vy b1x b1y b2x b2y t1x t1y t2x t2y)
  ;; ROOF SHEETING on ONE monitor slope - the SAME pattern as the main roof (owner 31-Aug:
  ;; "roof monitor sheeting will have same pattern as of roof sheeting - profile sheeting on
  ;; both side of peak line").  A cladThk band resting on the purlin TOP FLANGE, on CLADDING,
  ;; capped at the eave end, drawn once per side so both slopes read off the peak line.
  ;;
  ;; WHY THE OFFSET IS PERPENDICULAR HERE AND VERTICAL ON THE MAIN ROOF.  draw-purlins states the
  ;; rule: purlins are "tilted perpendicular to the rafter so the top flange sits flush against the
  ;; bottom of the sheeting".  The main roof can add purlinH to Y and still land flush because its
  ;; slope is shallow (1:10 -> a ~1 mm error).  The monitor is a 45 deg mini-gable by R1 (height =
  ;; throat/2), where a vertical 200 misses the purlin top by ~83 mm - the sheeting floats off the
  ;; purlins and reads wrong.  So the band is offset along the SAME normal rm-mon-purlins uses.
  ;; Call with the EAVE as (x1,y1) and the RIDGE as (x2,y2): the cap then lands at the eave, and the
  ;; two slopes meet cleanly on the peak line.
  (setq dx (- x2 x1) dy (- y2 y1) L (sqrt (+ (* dx dx) (* dy dy))))
  (if (<= L 1e-6) (setq L 1.0))
  (setq ux (/ dx L) uy (/ dy L) vx (- uy) vy ux)
  (if (< vy 0.0) (setq vx (- vx) vy (- vy)))          ; normal points UP - sheeting ABOVE the rafter
  (setq b1x (+ x1 (* depth vx))         b1y (+ y1 (* depth vy))
        b2x (+ x2 (* depth vx))         b2y (+ y2 (* depth vy))
        t1x (+ x1 (* (+ depth thk) vx)) t1y (+ y1 (* (+ depth thk) vy))
        t2x (+ x2 (* (+ depth thk) vx)) t2y (+ y2 (* (+ depth thk) vy)))
  (command "_.LINE" (list b1x b1y) (list b2x b2y) "")   ; outer face
  (command "_.LINE" (list t1x t1y) (list t2x t2y) "")   ; inner face
  (command "_.LINE" (list b1x b1y) (list t1x t1y) ""))  ; eave end cap, as the main roof caps its eave

(defun rm-leg-cap (cx cy w gdir gslope / pt hg)
  ;; LEG-TOP connection: two SOLID plates at the seam (rafter bottom <-> leg top), 1.5mm hairline gap,
  ;; NO bolts, NO plate at the peak.  Plus ONE GP gusset on the THROAT side whose flange leg lies ON the
  ;; RAFTER SLOPE (standing CP/GP rule, owner 21-Jul): gdir = throat/ridge direction (+1 = ridge to the
  ;; RIGHT of the leg, -1 = to the LEFT); gslope is fed to draw-rc-gusset so the flange rises toward the ridge.
  ;; owner 21-Jul: the CP plates FOLLOW the rafter flange slope (`gslope`), not horizontal — tilt each
  ;; plate so its edges are parallel to the rafter (tl/tr = the y-rise at the left/right plate edge).
  (setq pt *PEB-CP-THK* hg (/ *PEB-CP-GAP* 2.0) tl (* (- w) gslope) tr (* w gslope))
  (setvar "CLAYER" "PLATES")
  (peb-solid-quad (list (- cx w) (+ cy hg tl)) (list (+ cx w) (+ cy hg tr))
                  (list (- cx w) (+ cy hg pt tl)) (list (+ cx w) (+ cy hg pt tr)))          ; rafter-bottom plate (on the slope)
  (peb-solid-quad (list (- cx w) (+ (- cy hg pt) tl)) (list (+ cx w) (+ (- cy hg pt) tr))
                  (list (- cx w) (+ (- cy hg) tl)) (list (+ cx w) (+ (- cy hg) tr)))        ; leg-top plate (on the slope)
  ;; GP filled-solid on the rafter slope, within the 100mm CP zone, throat side.
  (draw-rc-gusset (+ cx (* gdir w)) (+ cy hg (* gdir w gslope)) (- cy hg pt 100.0) 100.0 gdir gslope))

(defun rm-eave-curved (ex ey dir sz rtop rslope / st si R ySof sofL stubLen gx)
  ;; CURVED EAVE — mirrors manual §10.7 "Roof Monitor with Curved Panel" (deep study 22-Jul).  The ROOF
  ;; SHEETING (TWO SKINS) rolls from the roof plane in ONE big ~180° R~500 arc bulging OUTBOARD, curling DOWN
  ;; and UNDER to a HORIZONTAL SOFFIT (the "SHEETING ANGLE") that runs INBOARD.  A SHORT STUB POST sits at the
  ;; rafter END (connection plate to the rafter bottom flange); a Z-GIRT supports the soffit.  Purlins are on
  ;; the STRAIGHT rafter only (rm-mon-purlins) — the curve carries only clips (none here).  2 skins = concentric
  ;; arcs R / R-35 (true 35mm offset).  ex,ey = rafter END; dir = outboard; rtop = rafter depth; rslope = slope.
  (setq st      (+ ey rtop 125.0)                ; OUTER roof-sheet skin at the eave = TOP of the curve
        si      (- st 35.0)                      ; INNER skin (35mm inside)
        R       (min 460.0 (* sz 0.32))          ; curve radius (proportional to R500) — TUNE vs manual overlay
        ySof    (- st (* 2.0 R))                 ; curve FOOT = horizontal soffit level (180deg -> 2R below top)
        sofL    (min 700.0 (* sz 0.42))          ; soffit run INBOARD (~ the O.W./2 reach)
        stubLen (+ rtop 130.0)                   ; SHORT stub post
        gx      (- ex (* dir (* sofL 0.5))))     ; Z-girt position on the soffit
  ;; 1) SHORT STUB POST at the rafter end (rafter bottom flange -> a short way down).  FRAME.
  (rm-member ex ey ex (- ey stubLen) 90.0 (- dir) "FRAME")
  ;; 2) CONNECTION PLATE: stub post <-> rafter BOTTOM FLANGE (standing CP rule, tilted to the rafter slope).
  (vl-catch-all-apply (function (lambda () (rm-leg-cap ex ey 130.0 (- dir) rslope))))
  ;; 3) CURVE PANEL — TWO SKINS: one big ~180deg arc bulging OUTBOARD, roof (top) -> soffit (foot).  CLADDING.
  (setvar "CLAYER" "CLADDING")
  (command "_.ARC" (list ex st) (list (+ ex (* dir R)) (- st R)) (list ex ySof))                    ; outer skin
  (command "_.ARC" (list ex si) (list (+ ex (* dir (- R 35.0))) (- st R)) (list ex (+ ySof 35.0)))  ; inner skin (concentric)
  ;; 4) BOTTOM SOFFIT — TWO SKINS, horizontal, from the curve foot running INBOARD (the "sheeting angle").  CLADDING.
  (command "_.LINE" (list ex ySof)          (list (- ex (* dir sofL)) ySof) "")
  (command "_.LINE" (list ex (+ ySof 35.0)) (list (- ex (* dir sofL)) (+ ySof 35.0)) "")
  ;; 5) Z-GIRT on the soffit inner face (web UP into the interior, flanges along the soffit) — magenta.
  (vl-catch-all-apply (function (lambda ()
    (draw-z-purlin gx (+ ySof 35.0) (- dir) 0.0 0.0 1.0 80.0 40.0 40.0 8.0 12.0))))
  ;; 6) DRIP TRIM at the curve foot / soffit outboard edge — GUTTER layer.
  (setvar "CLAYER" "GUTTER")
  (command "_.LINE" (list ex ySof) (list (+ ex (* dir 100.0)) (- ySof 55.0)) ""))

(defun rm-eave-zoom (ex ey dir)
  ;; STANDARD (Eave-Trim) eave: DRIP TRIM only.  The OUTSIDE-FOAM-CLOSURE zoom bubble (a circle + solid
  ;; dot + leader + label) was REMOVED 21-Jul — on the monitor section it floated off the eave as a
  ;; LOOSE PARTICLE, and it was drawn on the RIGHT eave only (asymmetric).  The eave-trim edge is the
  ;; real element on the overview section; the foam-closure construction detail belongs on a dedicated
  ;; zoom-detail sheet, not clutter on the monitor.  Now called on BOTH eaves for symmetry.
  (setvar "CLAYER" "GUTTER")
  (command "_.PLINE" (list ex ey) (list (+ ex (* dir 120.0)) ey) (list (+ ex (* dir 120.0)) (- ey 80.0)) ""))

;; ---- the drawer -----------------------------------------------------------
;; rm-type-name — the ROOF MONITOR's single display name (owner 22-Jul: one M-Ladder shows the monitor NAME,
;; no per-part labels).  The BSF/PEB manual §10.7 defines ONE monitor shape (raised gable/ridge monitor) with
;; TWO eave variants — "STANDARD ROOF MONITOR" (Eave Trim) and "ROOF MONITOR WITH CURVED PANEL" (Curved Eave
;; Panel) — which is exactly the BSF `eaveCondition` field.  Name follows that variant (RM_TYPE reserved for a
;; future explicit type field, if ever added).
(defun rm-type-name (data / ev ty)
  (setq ev (strcase (peb-tb-or (MSPL-Get-Str data "RM_EAVE_TYPE") ""))
        ty (strcase (peb-tb-or (MSPL-Get-Str data "RM_TYPE") "")))
  (cond ((or (vl-string-search "CURV" ev) (wcmatch ty "*CURV*")) "ROOF MONITOR WITH CURVED PANEL")
        (T "ROOF MONITOR")))

(defun peb-draw-roof-monitor (data wid H rise ridgeX ht rd cb slopeD /
        prev throat overallW rmh eaveType bird curved
        roofY halfT halfO sL sR legBaseYL legBaseYR legTopYL legTopYR monRidgeY eaveYL eaveYR
        xLi xRi eaveLx eaveRx mDep pDep pt hg gW rmConstr monPL monPR)
  (setq prev (getvar "CLAYER"))
  (if (or (null slopeD) (<= slopeD 0.0)) (setq slopeD 10.0))

  ;; ---- read BSF/PEB_Data RM_* with fallbacks ----
  (setq throat (MSPL-Get-Num data "RM_THROAT_WIDTH"))
  (if (or (null throat) (<= throat 0.0)) (setq throat (MSPL-Get-Num data "RM_OVERALL_WIDTH")))
  (if (or (null throat) (<= throat 0.0)) (setq throat (min 3500.0 (* wid 0.20))))
  (setq overallW (MSPL-Get-Num data "RM_OVERALL_WIDTH"))
  ;; OVERALL = THROAT x 2 (owner 31-Aug) - the SAME derivation peb-monitor-band uses on the plan.
  ;; This used to be throat + 1800 here and a flat 3000 on the plan, so a blank field produced a
  ;; section and a roof plan that drew the same monitor 200 mm apart.
  (if (or (null overallW) (<= overallW throat)) (setq overallW (* throat 2.0)))
  ;; owner 21-Jul: monitor HEIGHT = HALF the throat width (governing proportion rule for the monitor).
  (setq rmh (/ throat 2.0))
  (setq eaveType (strcase (MSPL-Get-Str data "RM_EAVE_TYPE"))
        bird     (strcase (MSPL-Get-Str data "RM_BIRD_MESH"))
        curved   (or (vl-string-search "CURV" eaveType) (vl-string-search "CURVED" eaveType)))
  ;; construction type (BS roof_monitor.constructionType -> RM_CONSTR): member depths per type
  ;; (rafter mDep / leg pDep).  Built-Up = deeper welded I; Cold-Formed = shallow C/Z; Hot-Rolled = IPE (default).
  (setq rmConstr (strcase (MSPL-Get-Str data "RM_CONSTR")))
  ;; MEMBER DEPTHS COME FROM THE QE, not from a drawing-side guess (owner 31-Aug: "in the Section of
  ;; the Roof Monitor, it will be shown Web of 200mm of legs and rafter"; then "monitor leg is 100mm
  ;; not 200 i think"; then "check it in QE Data ... roof monitor legs size and rafter size").
  ;; Checked, and the QE settles it - computeRoofMonitor in quickest/accessories.ts bills ONE frame
  ;; section for the monitor, so the legs and the rafter ARE the same member:
  ;;    Hot-Rolled   IPEa  -> mbsdb.json "IPE-200A", erp HRB-IPE-200A-100-18.40-12000-2
  ;;    Cold-Formed  C20G  -> mbsdb.json "C200X60X2.0 Galvanized"
  ;;    purlins      Z20G  -> "Z 200X2.0"
  ;; All 200 deep.  The 100 is the IPE-200A FLANGE WIDTH - it is the "-100-" in that ERP code - and
  ;; not the web, which is why 100 looked plausible.  The old 180/160 and 150 matched nothing at all.
  (cond
    ((or (vl-string-search "BUILT" rmConstr) (vl-string-search "BU" rmConstr))
       (setq mDep 240.0 pDep 200.0))                                   ; Built-up (BU): the QE gives
                                                                       ; BU no catalogue depth ("Light
                                                                       ; Built-Up ... upto 10 mm HR
                                                                       ; coil"), so this one is left
                                                                       ; as it was rather than guessed.
    ((or (vl-string-search "COLD" rmConstr) (vl-string-search "C20" rmConstr) (vl-string-search "CF" rmConstr))
       (setq mDep 200.0 pDep 200.0))                                   ; Cold-Formed  = C200x60x2.0
    (T (setq mDep 200.0 pDep 200.0)))                                  ; Hot-Rolled (IPEa) = IPE-200A

  ;; ---- mini-PEB-frame geometry — PER-SIDE rafter slopes so the monitor seats on the TRUE
  ;;      rafter even at an OFF-CENTRE ridge (BP_RIDGE_OFFSET) or unequal pitches.  sL/sR = rise/run
  ;;      each side; for a central ridge sL=sR=1/slopeD (identical to before).  Both monitor rafters
  ;;      meet rmh above the peak.  (universal rule: monitor slope = the frame slope it sits on.)
  (setq roofY (+ H rise)
        halfT (/ throat 2.0) halfO (/ overallW 2.0)
        sL (if (> ridgeX 1.0) (/ rise ridgeX) (/ 1.0 slopeD))
        sR (if (> (- wid ridgeX) 1.0) (/ rise (- wid ridgeX)) (/ 1.0 slopeD))
        legBaseYL (- roofY (* halfT sL))  legBaseYR (- roofY (* halfT sR))   ; leg seats on true rafter
        legTopYL  (+ legBaseYL rmh)       legTopYR  (+ legBaseYR rmh)
        monRidgeY (+ roofY rmh)
        eaveYL    (- monRidgeY (* halfO sL)) eaveYR (- monRidgeY (* halfO sR))
        xLi (- ridgeX halfT) xRi (+ ridgeX halfT)
        eaveLx (- ridgeX halfO) eaveRx (+ ridgeX halfO))

  ;; 1) LEGS on the main rafter, both sides of the peak
  (rm-member xLi legBaseYL xLi legTopYL pDep  1 "FRAME")
  (rm-member xRi legBaseYR xRi legTopYR pDep -1 "FRAME")
  ;; 2) SINGLE-PIECE RAFTER across BOTH leg tops — ONE gabled member (owner ref: no splice at the
  ;;    peak; the monitor rafter is a single small piece).  Bottom flange passes through the leg tops.
  (setvar "CLAYER" "FRAME")
  (command "_.PLINE"
    (list eaveLx eaveYL) (list ridgeX monRidgeY) (list eaveRx eaveYR)                             ; bottom flange
    (list eaveRx (+ eaveYR mDep)) (list ridgeX (+ monRidgeY mDep)) (list eaveLx (+ eaveYL mDep))  ; top flange
    "C")
  ;; 3) BYPASS Z-PURLINS on the rafter top flange, then SHEETING (2 skins) OVER them — universal
  ;;    rule: purlins + sheeting FOLLOW the rafter slope, drawn with the engine's real Z-purlin.
  ;; ── MONITOR PURLINS (owner 26-Aug: "also the roof monitor purlins") ────────
  ;; A purlin is a purlin: the monitor carries the SAME Z200 the main roof does, at
  ;; the SAME spacing rule.  They were drawn 90 deep with a 45 flange and one every
  ;; ~600 mm — half-size and twice as dense as the roof beside them, which at sheet
  ;; scale read as a faint hatch rather than as purlins, so the monitor looked bare
  ;; next to a main roof carrying visible Z's.
  ;;
  ;; Spacing follows rule P1, the same as draw-purlins: a purlin on BOTH ends of the
  ;; run and the interior ones equally spaced, aiming at 1.25-1.5 m.
  (setq monPL (max 2 (+ 1 (fix (+ 0.9999
                (/ (distance (list eaveLx (+ eaveYL mDep)) (list ridgeX (+ monRidgeY mDep))) 1500.0)))))
        monPR (max 2 (+ 1 (fix (+ 0.9999
                (/ (distance (list eaveRx (+ eaveYR mDep)) (list ridgeX (+ monRidgeY mDep))) 1500.0))))))
  ;; depth 200 / flange 60 / lip 20 — the identical Z the main roof purlins use.
  (rm-mon-purlins eaveLx (+ eaveYL mDep) ridgeX (+ monRidgeY mDep) monPL 200.0 nil)  ; left half: eave..ridge (incl the shared ridge)
  (rm-mon-purlins eaveRx (+ eaveYR mDep) ridgeX (+ monRidgeY mDep) monPR 200.0 T)    ; right half: eave.. (skip the shared ridge)
  (setvar "CLAYER" "CLADDING")     ; universal rule: roof sheeting = CLADDING (same as the main roof)
  ;; One run per slope, each starting at its own eave, so the sheeting reads off the peak line on
  ;; BOTH sides and sits flush on the purlin tops.  It used to be two PLINEs offset +90/+125 in Y,
  ;; which on a 45 deg monitor put the sheet 110 mm INSIDE the 200-deep purlins it is supposed to
  ;; rest on - the band cut straight through them.  200 = purlin depth, 35 = cladThk (main roof).
  (rm-mon-sheeting eaveLx (+ eaveYL mDep) ridgeX (+ monRidgeY mDep) 200.0 35.0)
  (rm-mon-sheeting eaveRx (+ eaveYR mDep) ridgeX (+ monRidgeY mDep) 200.0 35.0)
  ;; ridge cap over the sheeting apex — REMOVED 21-Jul (owner: the small cap on the monitor apex is not wanted).
  ;; 5) BIRD SCREEN mesh — DROPPED from the section (owner 22-Jul "clean geometry + width only"): the diagonal
  ;;    mesh hatch was visual noise at section scale.  It belongs on the enlarged monitor DETAIL, not here.
  ;; 6) EAVE — curved variant adds R500 panel + drip trim + stub post; STANDARD variant gets the
  ;;    eave-trim + OUTSIDE-FOAM-CLOSURE zoom bubble (universal §10.7 detail, both eave types now covered).
  (if curved
    (vl-catch-all-apply (function (lambda () (rm-eave-curved eaveRx eaveYR  1 rmh mDep (- sR))
                                            (rm-eave-curved eaveLx eaveYL -1 rmh mDep sL))))
    (vl-catch-all-apply (function (lambda () (rm-eave-zoom eaveRx eaveYR 1) (rm-eave-zoom eaveLx eaveYL -1)))))

  ;; 7) CONNECTION PLATES — at the LEG TOPS (leg top ↔ rafter bottom flange) and LEG BASES ONLY.
  ;;    Owner ref: NO plate at the monitor peak/middle — the rafter is one single piece.
  (setvar "CLAYER" "PLATES")
  ;; leg-top connections (leg ↔ single rafter) — plate pair + small gussets down the leg
  ;; owner 21-Jul: plate pair centred EXACTLY ON the leg (leg body extends OUTWARD — left to -x, right
  ;; to +x — so the cap sits on the leg centre, not offset into the throat).  GP follows the rafter slope.
  (vl-catch-all-apply (function (lambda () (rm-leg-cap (- xLi (/ pDep 2.0)) legTopYL (+ (/ pDep 2.0) 100.0)  1 sL))))
  (vl-catch-all-apply (function (lambda () (rm-leg-cap (+ xRi (/ pDep 2.0)) legTopYR (+ (/ pDep 2.0) 100.0) -1 (- sR)))))
  ;; leg BASE plates — short solid seat plate flush on the main-rafter TOP FLANGE (per side)
  (vl-catch-all-apply (function (lambda ()
    (peb-solid-quad (list (- xLi pDep 55.0) (- legBaseYL 55.0)) (list (+ xLi 55.0) (- legBaseYL 55.0))
                    (list (- xLi pDep 55.0) legBaseYL)          (list (+ xLi 55.0) legBaseYL)))))
  (vl-catch-all-apply (function (lambda ()
    (peb-solid-quad (list (- xRi 55.0) (- legBaseYR 55.0)) (list (+ xRi pDep 55.0) (- legBaseYR 55.0))
                    (list (- xRi 55.0) legBaseYR)          (list (+ xRi pDep 55.0) legBaseYR)))))

  ;; 8) UNIVERSAL RULES — M-LADDER callout (peb-make-mleader: arrow → leg → bar → text) + open-arrow
  ;;    DIMENSIONS (overall width across the eaves, throat at the base).  Same rules as the roof/wall
  ;;    sheeting M-Ladders and the frame dim chain (owner: rules developed today).
  ;; (standalone "ROOF MONITOR" callout removed 21-Jul — redundant; every member label already reads "ROOF MONITOR …")
  ;; open-arrow dims (universal): OVERALL WIDTH (top, across the eaves) + THROAT WIDTH (owner 22-Jul: throat is
  ;; IMPORTANT — kept).  Now that the bird-screen mesh + slope tags are gone there is clean space for the throat
  ;; dim below the legs; dropped to -1550 (was -1100) so it clears the main-rafter purlin markers.
  ;; owner 22-Jul: OVERALL WIDTH (above the roof) + THROAT WIDTH (below the legs).  Both kept — throat is
  ;; important.  Now that the bird-screen mesh + slope tags are gone, the throat dim at -1050 below the leg
  ;; base reads cleanly (this is the position that rendered well originally).
  (vl-catch-all-apply (function (lambda ()
    (rm-dim-h eaveLx (+ monRidgeY mDep 300.0) eaveRx (+ monRidgeY mDep 300.0) (+ monRidgeY mDep 520.0) (peb-dim-mmft overallW)))))
  ;; owner 22-Jul: throat-width dim just BELOW the main rafter in the clear interior (the throat opening itself
  ;; is covered by the rafter peak + purlins, which hid the dim there).  Witness lines rise from the leg seats;
  ;; kept as short as the rafter allows so it reads directly under the throat.
  (vl-catch-all-apply (function (lambda ()
    (rm-dim-h xLi legBaseYL xRi legBaseYR (- H 300.0) (peb-dim-mmft throat)))))

  ;; 9) UNIVERSAL RULE — MEMBER NOMENCLATURE LABELS (every member labelled, manual §10.7), monitor
  ;;    SLOPE tag, and monitor HEIGHT dim.  Migrated from the retired standalone, adapted to the section
  ;;    coord frame.  (Text landings are first-cut — nudge on render if any overlap the frame chain.)
  ;; M-LADDERS at STAGGERED LEVELS so the labels never collide (owner 21-Jul, per marked reference).
  ;; Each leader tips on its member, rises straight up to ITS OWN level, then a horizontal bar to a side
  ;; landing; RIGHT-side ladders (purlin/rafter/bird-screen) and LEFT-side ladders (post/ridge-panel) sit
  ;; at different heights on each side so no two risers/bars/labels overlap.
  ;; SINGLE M-LADDER (owner 22-Jul): ONE callout showing the ROOF MONITOR NAME (its BSF type).  ALL per-part
  ;; member labels removed (RAFTER / PURLIN / RIDGE PANEL / POST / BIRD SCREEN / CURVED PANEL / DRIP TRIM).
  ;; Tip on the rafter apex, riser up to a clear level, bar out to a right landing.  Off on the clean detail.
  (if (not *RM-CLEAN*)
    (vl-catch-all-apply (function (lambda ()
      (rm-mladder ridgeX (+ monRidgeY mDep) (+ monRidgeY mDep 950.0) (+ eaveRx 900.0) (rm-type-name data))))))
  ;; monitor roof SLOPE tags REMOVED from the section (owner 22-Jul "clean the monitor"): at section scale the
  ;; per-side 1/sL, 1/sR tags collided with the overall-width dim and the peak, and only duplicated the main
  ;; rafter slope already shown on the frame.  The monitor's own per-side pitch belongs on the enlarged
  ;; monitor DETAIL, not on the small section.
  ;; monitor HEIGHT (throat) dim DROPPED from the section (owner 22-Jul "clean geometry + width only") — it was
  ;; cramped on the left of the short legs.  Overall-width dim + ROOF MONITOR label are the section's monitor set.
  (setvar "CLAYER" prev)
  (princ))

;; ============================================================================
;;  peb-draw-crane-section — CRANE footprint on the cross-section, migrated from the
;;  plan drawer peb-draw-crane.  Per toggled crane it draws (all HIDDEN / dotted):
;;    · runway beams on the two columns of ITS module,
;;    · the bridge girder spanning between them,
;;    · the trolley + hoist hung under the bridge, with the hook to the hook height,
;;  plus a "CAP <n>MT CRANE" label.  RULES mirror the plan: the module comes from
;;  CRn_GRID_FROM_W / CRn_GRID_TO_W (else full width); the span is between the two
;;  module columns; the hook height is CRn_HOOK_HEIGHT.  Coords: X = 0..wid across
;;  the width, Y = 0..H (FFL..eave).  Self-contained (no dependency on the plan file).
;; ============================================================================
(defun peb-crane-sec-line (xa ya xb yb)
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 6 "HIDDEN") (cons 48 300.0)
                 (list 10 xa ya 0.0) (list 11 xb yb 0.0))))
(defun peb-crane-sec-box (xa ya xb yb)
  (peb-crane-sec-line xa ya xb ya) (peb-crane-sec-line xb ya xb yb)
  (peb-crane-sec-line xb yb xa yb) (peb-crane-sec-line xa yb xa ya))
;; owner-chosen SHORT-DASH thick line for the crane BRIDGE (150 dash / 120 gap, true mm), matching the
;; plan's CRANEBRG.  Bridge = "by others" reference member, drawn dashed (the crane BEAM stays solid).
(defun peb-crane-sec-dash (xa ya xb yb / es)
  (if (not (tblsearch "LTYPE" "CRANEBRG"))
    (vl-catch-all-apply (function (lambda ()
      (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbLinetypeTableRecord") '(2 . "CRANEBRG") '(70 . 0)
                     '(3 . "Crane bridge __ __ __") '(72 . 65) '(73 . 2) '(40 . 270.0)
                     '(49 . 150.0) '(74 . 0) '(49 . -120.0) '(74 . 0)))))))
  (setq es (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
  (if (tblsearch "LTYPE" "CRANEBRG")
    (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 6 "CRANEBRG") (cons 48 es) (cons 370 15)
                   (list 10 xa ya 0.0) (list 11 xb yb 0.0)))
    (peb-crane-sec-line xa ya xb yb)))
(defun peb-crane-sec-dbox (xa ya xb yb)
  (peb-crane-sec-dash xa ya xb ya) (peb-crane-sec-dash xb ya xb yb)
  (peb-crane-sec-dash xb yb xa yb) (peb-crane-sec-dash xa yb xa ya))

;; solid (continuous) primitives for the DETAILED HOIST symbol — a small crisp detail
;; reads badly in HIDDEN dashes, and both the manual (Tech §10.6 p262-263) and the Maimaar
;; house reference draw the hoist body/hook in solid lines.
(defun peb-crane-sec-sline (xa ya xb yb)
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC")
                 (list 10 xa ya 0.0) (list 11 xb yb 0.0))))
(defun peb-crane-sec-sbox (xa ya xb yb)
  (peb-crane-sec-sline xa ya xb ya) (peb-crane-sec-sline xb ya xb yb)
  (peb-crane-sec-sline xb yb xa yb) (peb-crane-sec-sline xa yb xa ya))
(defun peb-crane-sec-circ (cx cy r)
  (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-CRANE-SEC")
                 (list 10 cx cy 0.0) (cons 40 r))))
(defun peb-crane-sec-arc (cx cy r a0 a1)   ; a0/a1 in DEGREES (entmake ARC wants radians)
  (entmake (list (cons 0 "ARC") (cons 8 "COMP-CRANE-SEC")
                 (list 10 cx cy 0.0) (cons 40 r)
                 (cons 50 (* a0 (/ pi 180.0))) (cons 51 (* a1 (/ pi 180.0))))))
(defun peb-crane-sec-cross (cx cy a)
  (peb-crane-sec-sline (- cx a) cy (+ cx a) cy)
  (peb-crane-sec-sline cx (- cy a) cx (+ cy a)))

;; DETAILED HOIST / TROLLEY in ELEVATION (manual Tech §10.6 p262-263; Maimaar house reference
;; = the magenta EOT hoist).  cx = hook centreline, topY = hang line just under the bridge,
;; s = section scale (u).  Trolley body (drum housing) + centre-cross, LEFT open-C end frame,
;; RIGHT stepped connector -> motor CYLINDER (vertical hatch + rounded end + nub), bottom
;; MOUNTING plate with 4 bolt dots, HOOK block + curved hook.  Returns the hook-tip y.
(defun peb-crane-sec-hoist (cx topY s / bt bb ym ct cbb pb hy hr i xh d bax bay)
  (setq bt (- topY (* s 0.06)) bb (- bt (* s 0.70)) ym (/ (+ bt bb) 2.0))
  ;; main body (drum housing) + centre cross
  (peb-crane-sec-sbox (- cx (* s 0.70)) bb (+ cx (* s 0.70)) bt)
  (peb-crane-sec-cross cx ym (* s 0.12))
  ;; LEFT open-C end frame (opening faces the body)
  (peb-crane-sec-sline (- cx (* s 0.94)) (- ym (* s 0.17)) (- cx (* s 0.94)) (+ ym (* s 0.17)))
  (peb-crane-sec-sline (- cx (* s 0.94)) (+ ym (* s 0.17)) (- cx (* s 0.80)) (+ ym (* s 0.17)))
  (peb-crane-sec-sline (- cx (* s 0.94)) (- ym (* s 0.17)) (- cx (* s 0.80)) (- ym (* s 0.17)))
  ;; RIGHT stepped connector block
  (peb-crane-sec-sbox (+ cx (* s 0.70)) (- ym (* s 0.22)) (+ cx (* s 0.98)) (+ ym (* s 0.22)))
  ;; motor CYLINDER + vertical hatch + rounded right end + end nub
  (setq ct (+ ym (* s 0.18)) cbb (- ym (* s 0.18)))
  (peb-crane-sec-sline (+ cx (* s 0.98)) cbb (+ cx (* s 1.36)) cbb)
  (peb-crane-sec-sline (+ cx (* s 0.98)) ct  (+ cx (* s 1.36)) ct)
  (peb-crane-sec-sline (+ cx (* s 0.98)) cbb (+ cx (* s 0.98)) ct)
  (peb-crane-sec-arc (+ cx (* s 1.36)) ym (* s 0.18) 270.0 90.0)
  (setq i 1)
  (while (<= i 4)
    (setq xh (+ cx (* s (+ 0.98 (* i 0.076)))))
    (peb-crane-sec-sline xh cbb xh ct) (setq i (1+ i)))
  (peb-crane-sec-sbox (+ cx (* s 1.54)) (- ym (* s 0.10)) (+ cx (* s 1.64)) (+ ym (* s 0.10)))
  ;; bottom MOUNTING plate + 4 bolt dots + centre cross
  (setq pb (- bb (* s 0.32)))
  (peb-crane-sec-sbox (- cx (* s 0.78)) pb (+ cx (* s 0.78)) bb)
  (foreach d (list (list (- cx (* s 0.60)) (- bb (* s 0.09)))
                   (list (+ cx (* s 0.60)) (- bb (* s 0.09)))
                   (list (- cx (* s 0.60)) (+ pb (* s 0.09)))
                   (list (+ cx (* s 0.60)) (+ pb (* s 0.09))))
    (peb-crane-sec-circ (car d) (cadr d) (* s 0.05)))
  (peb-crane-sec-cross cx (/ (+ pb bb) 2.0) (* s 0.09))
  ;; HOOK block + curved hook + throat cross
  (peb-crane-sec-sbox (- cx (* s 0.12)) (- pb (* s 0.12)) (+ cx (* s 0.12)) pb)
  ;; open-J hook: shank -> belly curve (top->left->bottom->lower-right, mouth upper-right) -> inward barb
  (setq hy (- pb (* s 0.50)) hr (* s 0.20))
  (peb-crane-sec-sline cx (- pb (* s 0.12)) cx (+ hy hr))                 ; shank to top of curve
  (peb-crane-sec-arc cx hy hr 90.0 315.0)                                ; belly curve
  (setq bax (+ cx (* hr 0.707)) bay (- hy (* hr 0.707)))                 ; arc end (315 deg)
  (peb-crane-sec-sline bax bay (+ cx (* hr 0.10)) (- hy (* hr 0.02)))    ; inward barb tip
  (peb-crane-sec-cross cx hy (* s 0.05))
  (- hy hr))

(defun peb-crane-sec-colhw (cols idx ht u / w)
  ;; OFFSET from a column's grid line to its INNER FLANGE (where the crane beam bears).
  ;; INTERIOR column: centred on its line -> inner flange = HALF the web.
  ;; SIDE / END column: its FULL depth sits INSIDE the sheeting line -> inner flange = full depth.
  (if (and idx (> idx 0) (< idx (1- (length cols))) (boundp 'ms-col-web-at))
    (progn                                             ; interior — half web
      (setq w (ms-col-web-at cols idx))
      (if (or (null w) (<= w 0.0)) (setq w ht))
      (max (* u 0.30) (/ w 2.0)))
    (max (* u 0.60) ht)))                              ; side/end — full column depth

;; approximate ROOF-UNDERSIDE y at x, so an UNDERHUNG crane beam hangs from the real rafter line
;; (each rail's hanger is a different length).  Eave/valley = H, rising linearly to H+rise at the
;; nearest ridge; half-gable width ~ wid/(2*Ngables).  Flat/no-ridge => single central gable.
(defun peb-crane-raf-y (x H rise wid ridges ht rd / rx d hw ry midD kneeL htv)
  ;; TRUE rafter UNDERSIDE at x, using the SAME cigar geometry as the frame polygon
  ;; (cigar-rafter-underside-y) so it is correct on OFF-CENTRE ridges and in the knee/ridge
  ;; taper zones.  Falls back to a linear eave->ridge approximation if the cigar helper errors
  ;; or isn't available.  ht/rd may be nil (older callers) -> sensible defaults.
  (if (or (null rise) (<= rise 0.0))
    H
    (progn
      (setq htv (if (and ht (> ht 0.0)) ht (* H 0.5))
            rx  (if (and ridges (> (length ridges) 0)) (car ridges) (/ wid 2.0)))
      (if ridges (foreach r ridges (if (< (abs (- x r)) (abs (- x rx))) (setq rx r))))
      (setq midD  (max 300.0 (min 500.0 (- (* htv 0.5) 50.0)))
            kneeL (vl-catch-all-apply (function (lambda () (car (cigar-taper-lengths wid)))))
            ry    (if (and (numberp kneeL) (boundp 'cigar-rafter-underside-y))
                    (vl-catch-all-apply (function (lambda ()
                      (cigar-rafter-underside-y x 0.0 wid rx H rise htv (if rd rd rise) midD kneeL kneeL))))
                    nil))
      (if (numberp ry) ry
        (progn (setq hw (/ wid (* 2.0 (max 1 (length ridges)))) d (abs (- x rx)))
               (+ H (* rise (max 0.0 (- 1.0 (/ d hw))))))))))

(defun peb-draw-crane-section (data wid cols H ht clearHt rise rd ridges
                                / u sc n pre cap cls hookH nC gfW gtW cf ct xL xR midX capStr
                                  idxL idxR hwL hwR brkLen fw ft beamD railNubH etH bd
                                  capY bridgeTop bridgeBot railTop beamTop beamBot hoistTop hoistBot
                                  xBL xBR cb cx bx dir hw labeled hkTip modCount modSeen k a total idxInMod hoistX
                                  brD gpH bxi rW dW wx typ isUH braceDir rafYL rafYR rafY bdBS)
  (if (= (strcase (MSPL-Get-Str data "CR_TOGGLE")) "YES")
    (progn
      (setq u  (max 250.0 (/ wid 45.0))
            sc (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
      (if (or (null cols) (< (length cols) 2)) (setq cols (list 0.0 wid)))
      (setq nC (length cols))
      (if (or (null clearHt) (<= clearHt 0.0)) (setq clearHt (* H 0.80)))
      (if (boundp 'safe-load-ltype) (vl-catch-all-apply (function (lambda () (safe-load-ltype "HIDDEN")))))
      (if (not (tblsearch "LAYER" "COMP-CRANE-SEC"))
        (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbLayerTableRecord")
                       (cons 2 "COMP-CRANE-SEC") (cons 70 0) (cons 62 1) (cons 6 "Continuous"))))
      (setvar "CLAYER" "COMP-CRANE-SEC")
      ;; pre-count cranes per width-module (by grid letters) so SERIES cranes get spread, not stacked
      (setq modCount '() modSeen '() n 1)
      (while (<= n 3)
        (setq pre (strcat "CR" (itoa n) "_"))
        (if (= (strcase (MSPL-Get-Str data (strcat pre "TOGGLE"))) "YES")
          (progn
            (setq k (strcat (strcase (MSPL-Get-Str data (strcat pre "GRID_FROM_W")))
                            "_" (strcase (MSPL-Get-Str data (strcat pre "GRID_TO_W"))))
                  a (assoc k modCount))
            (if a (setq modCount (subst (cons k (1+ (cdr a))) a modCount))
                  (setq modCount (cons (cons k 1) modCount)))))
        (setq n (1+ n)))
      (setq n 1)
      (while (<= n 3)
        (setq pre (strcat "CR" (itoa n) "_"))
        (if (= (strcase (MSPL-Get-Str data (strcat pre "TOGGLE"))) "YES")
          (progn                       ; UNIVERSAL: show only ONE crane per section (the first enabled)
          (vl-catch-all-apply (function (lambda ( / )
            ;; ── inputs from BS (crane_system -> CR* keys) ──
            (setq cap   (MSPL-Get-Num data (strcat pre "CAP"))
                  cls   (MSPL-Get-Str data (strcat pre "CMAA_CLASS"))
                  hookH (MSPL-Get-Num data (strcat pre "HOOK_HEIGHT"))
                  gfW   (strcase (MSPL-Get-Str data (strcat pre "GRID_FROM_W")))
                  gtW   (strcase (MSPL-Get-Str data (strcat pre "GRID_TO_W")))
                  ;; UNIVERSAL RULE (type-aware): draw per CRn_TYPE — Top-Running (beam on a column
                  ;; bracket, DETAIL-1) vs UNDERHUNG (beam HUNG FROM THE RAFTER, DETAIL-2, manual p260).
                  typ   (strcase (MSPL-Get-Str data (strcat pre "TYPE")))
                  isUH  (or (wcmatch typ "*UNDER*") (wcmatch typ "*UH*") (wcmatch typ "*HUNG*")))
            (if (or (null cap) (<= cap 0.0)) (setq cap 5.0))
            ;; module column x-range (default = full width; section grid letter A = LEFT col = cols[0])
            (setq xL (nth 0 cols) xR (nth (1- nC) cols) idxL 0 idxR (1- nC))
            (if (and (> nC 2) (= (strlen gfW) 1) (= (strlen gtW) 1)
                     (>= (ascii gfW) 65) (>= (ascii gtW) 65))
              (progn
                (setq cf (max 0 (min (1- nC) (- (ascii gfW) 65 (if (> (ascii gfW) 73) 1 0))))
                      ct (max 0 (min (1- nC) (- (ascii gtW) 65 (if (> (ascii gtW) 73) 1 0)))))
                (if (/= cf ct) (setq idxL (min cf ct) idxR (max cf ct)
                                     xL (nth idxL cols) xR (nth idxR cols)))))
            (if (< (- xR xL) 1.0) (setq xL (nth 0 cols) xR (nth (1- nC) cols) idxL 0 idxR (1- nC)))
            ;; UNIVERSAL RULE (owner): a TR crane runs COLUMN TO COLUMN — within ONE module.  A single
            ;; bridge can NOT pass THROUGH an interior column, so if the width grid range spans interior
            ;; columns, clamp the rails to a SINGLE adjacent-column module (each module has its own crane).
            (if (> idxR (1+ idxL))
              (setq idxR (1+ idxL) xR (nth idxR cols)))
            ;; ── vertical stack, built DOWN from the rafter ceiling so the bridge never overrides
            ;;    the roof:  rafter/clearHt > bridge > end-truck > rail > I-beam > bracket ; hoist+hook below.
            (setq fw       (max 180.0 (* u 0.32))         ; I-beam flange half-width — READABLE on the frame
                  ft       (max 60.0 (* u 0.14))          ; flange thickness (true 200mm shown in the PLAN)
                  beamD    (* fw 4.0)                     ; crane beam depth = 4x flange (realistic I proportion)
                  railNubH (* u 0.28)                     ; crane rail on top of the beam
                  etH      (* u 0.55)                     ; end-truck (bridge-to-rail) connection height
                  bdBS     (MSPL-Get-Num data (strcat pre "BRIDGE"))   ; bridge girder depth from BS (CRn_BRIDGE, mm)
                  bd       (if (and bdBS (> bdBS 0.0))    ; use the real depth (clamped drawable), else representative
                             (max (* u 0.5) (min (* u 2.0) bdBS)) (* u 0.90))
                  brkLen   (* u 1.00))                    ; bracket cantilever length off the column face
            ;; vertical stack — differs by TYPE:
            ;;   TR: beam ON a column bracket -> rail on top -> end-truck WHEEL on rail -> bridge ABOVE.
            ;;   UH: beam HUNG from the rafter -> trolley/end-truck rides the beam BOTTOM flange -> bridge BELOW.
            (if isUH
              (setq beamTop  (- clearHt (* u 0.95))        ; beam hung just below the rafter (hanger drop)
                    beamBot  (- beamTop beamD)
                    railTop  beamBot                       ; underhung running surface = beam BOTTOM flange
                    bridgeTop (- beamBot ft (* u 0.12))    ; end-truck + bridge UNDER the beam bottom flange
                    bridgeBot (- bridgeTop bd)
                    hoistTop bridgeBot
                    hoistBot (- bridgeBot (* u 1.40)))
              (setq capY     (- clearHt (* u 0.60))        ; TR ceiling: bridge top kept clear of the rafters
                    bridgeTop capY
                    bridgeBot (- bridgeTop bd)
                    railTop  (- bridgeBot etH)             ; top of rail (bridge end-truck rides on it)
                    beamTop  (- railTop railNubH)          ; top of the crane I-beam
                    beamBot  (- beamTop beamD)
                    hoistTop bridgeBot
                    hoistBot (- bridgeBot (* u 1.40))))
            (setq idxL (vl-position xL cols) idxR (vl-position xR cols)
                  hwL  (peb-crane-sec-colhw cols idxL ht u)
                  hwR  (peb-crane-sec-colhw cols idxR ht u)
                  ;; UNIVERSAL RULE (owner): the crane beam sits ON each column's INNER FLANGE and
                  ;; the bridge spans beam-to-beam.  hwL/hwR are the per-column offsets to the inner
                  ;; flange (side col = full depth inside the line; interior = half web), so the beam
                  ;; centre lands exactly on the inner flange and never overshoots a column.
                  xBL  (+ xL hwL fw)                      ; left  beam: OUTER flange edge ON the inner flange
                  xBR  (- xR (+ hwR fw)))                 ; right beam: OUTER flange edge ON the inner flange
            (if (< (- xBR xBL) (* u 2.0)) (setq xBL (+ xL (* u 0.8)) xBR (- xR (* u 0.8))))
            ;; UNDERHUNG: now that the rails (xBL/xBR) are known, hang the LEVEL crane beam from the
            ;; real rafter line — beam top = just below the LOWER of the two rafter points; each rail's
            ;; hanger (drawn in the connection loop) then reaches its own rafter height.
            (setq rafYL (peb-crane-raf-y xBL H rise wid ridges ht rd)
                  rafYR (peb-crane-raf-y xBR H rise wid ridges ht rd))
            (if isUH
              (setq beamTop  (- (min rafYL rafYR) (* u 0.90))
                    beamBot  (- beamTop beamD)
                    railTop  beamBot
                    bridgeTop (- beamBot ft (* u 0.12))
                    bridgeBot (- bridgeTop bd)
                    hoistTop bridgeBot
                    hoistBot (- bridgeBot (* u 1.40)))
              ;; TOP-RUNNING — clamp the bridge below BOTH the clear height AND the TRUE rafter underside
              ;; at the two rails (owner STANDING RULE: bridge never crosses the rafter; off-centre safe).
              (setq capY     (min (- clearHt (* u 0.60)) (- (min rafYL rafYR) (* u 0.40)))
                    bridgeTop capY
                    bridgeBot (- bridgeTop bd)
                    railTop  (- bridgeBot etH)
                    beamTop  (- railTop railNubH)
                    beamBot  (- beamTop beamD)
                    hoistTop bridgeBot
                    hoistBot (- bridgeBot (* u 1.40))))
            (setq midX (/ (+ xBL xBR) 2.0) capStr (rtos cap 2 0))
            ;; hook height (from BS) clamped to sit below the hoist and above the floor
            (if (or (null hookH) (<= hookH 0.0)) (setq hookH (- hoistBot (* u 1.8))))
            (setq hookH (max (* clearHt 0.12) (min hookH (- hoistBot (* u 0.5)))))
            ;; ── per module column: the TR crane-beam-to-column CONNECTION (manual DETAIL-1) ──
            ;;    stack up:  built-up BRACKET (flanges + SOLID web) + triangular GUSSET off the
            ;;    column inner flange  ->  crane BEAM (I) on it  ->  cap channel + small I-RAIL
            ;;    ->  END-CARRIAGE WHEEL  ->  bridge.  Steel members drawn SOLID.
            (setq brD (* fw 2.4)                          ; bracket depth (proportional to the beam)
                  gpH (* fw 1.8))                         ; gusset (GP) height below the bracket
            (if isUH
              ;; ── UNDERHUNG (manual p260 DETAIL-2): beam HUNG from the rafter via a hanger stub +
              ;;    a BRACE ANGLE; the trolley/end-carriage rides the beam BOTTOM flange; bridge BELOW ──
              (foreach cb (list (list xBL 1.0) (list xBR -1.0))
                (setq bx (car cb) braceDir (cadr cb)
                      rafY (peb-crane-raf-y bx H rise wid ridges ht rd))                         ; this rail's true rafter y
                (peb-crane-sec-sbox (- bx (* fw 0.55)) beamTop (+ bx (* fw 0.55)) rafY)         ; hanger stub -> rafter
                (peb-crane-sec-sline (+ bx (* braceDir u 1.05)) rafY
                                     (+ bx (* braceDir fw 0.55)) (+ beamTop (* u 0.05)))        ; BRACE ANGLE
                (peb-crane-sec-sbox (- bx fw) (- beamTop ft) (+ bx fw) beamTop)                 ; beam top flange
                (peb-crane-sec-sbox (- bx fw) beamBot (+ bx fw) (+ beamBot ft))                 ; beam bottom flange (running surface)
                (peb-crane-sec-sline bx (- beamTop ft) bx (+ beamBot ft))                       ; beam web
                (setq rW (* etH 0.28) dW (* fw 0.72))
                (foreach wx (list (- bx dW) (+ bx dW))
                  (peb-crane-sec-circ wx (- beamBot ft rW) rW))                                 ; WHEEL under the bottom flange
                (peb-crane-sec-sbox (- bx (* fw 1.05)) bridgeTop (+ bx (* fw 1.05)) (- beamBot ft (* rW 2.05)))) ; end-truck -> bridge
              (foreach cb (list (list xL xBL 1.0 hwL) (list xR xBR -1.0 hwR))
              (setq cx  (+ (car cb) (* (caddr cb) (cadddr cb)))   ; column INNER FLANGE
                    bx  (cadr cb) dir (caddr cb)
                    bxi (+ bx (* dir fw)))                        ; beam INNER edge (into the module)
              ;; BRACKET — built-up rectangular section, clean OUTLINE (web box + flange lines)
              (peb-crane-sec-sbox cx (- beamBot brD) bxi beamBot)                      ; bracket web (outline)
              (peb-crane-sec-sline cx beamBot bxi beamBot)                             ; top flange (beam seat)
              (peb-crane-sec-sline cx (- beamBot brD) bxi (- beamBot brD))             ; bottom flange
              ;; triangular GUSSET PLATE (GP) — FILLED SOLID (owner STANDING CP/GP rule: GP = small solid
              ;; stiffener triangle) tying the bracket/beam to the column inner flange, + crisp outline edges
              (entmake (list (cons 0 "SOLID") (cons 8 "COMP-CRANE-SEC")
                             (list 10 cx (- beamBot brD) 0.0)                ; A  bracket-bottom @ column
                             (list 11 cx (- beamBot brD gpH) 0.0)            ; B  apex down the column
                             (list 12 bxi (- beamBot brD) 0.0)              ; C  bracket-bottom @ beam edge
                             (list 13 bxi (- beamBot brD) 0.0)))            ; C (triangle: pt4 = pt3)
              (peb-crane-sec-sline cx (- beamBot brD) cx (- beamBot brD gpH))          ; GP vertical (at column)
              (peb-crane-sec-sline cx (- beamBot brD gpH) bxi (- beamBot brD))         ; GP hypotenuse
              ;; CRANE BEAM — I-section (200mm flange), outer flange edge ON the inner flange, SOLID
              (peb-crane-sec-sbox (- bx fw) (- beamTop ft) (+ bx fw) beamTop)          ; top flange
              (peb-crane-sec-sbox (- bx fw) beamBot (+ bx fw) (+ beamBot ft))          ; bottom flange
              (peb-crane-sec-sline bx (- beamTop ft) bx (+ beamBot ft))               ; web
              ;; CAP CHANNEL + small I-RAIL on top of the beam (SOLID)
              (peb-crane-sec-sbox (- bx (* u 0.14)) beamTop (+ bx (* u 0.14)) (+ beamTop (* railNubH 0.35))) ; cap channel
              (peb-crane-sec-sline (- bx (* u 0.10)) railTop (+ bx (* u 0.10)) railTop)                       ; rail head
              (peb-crane-sec-sline bx (+ beamTop (* railNubH 0.35)) bx railTop)                               ; rail web
              (peb-crane-sec-sline (- bx (* u 0.10)) (+ beamTop (* railNubH 0.35)) (+ bx (* u 0.10)) (+ beamTop (* railNubH 0.35))) ; rail base
              ;; END CARRIAGE + WHEELS (manual tech_p262/263): the bridge end-truck rides on the rail via
              ;; TWO flanged wheels; draw both wheels ON the rail + the end-truck frame up to the bridge.
              (setq rW (* etH 0.30) dW (* fw 0.72))
              (foreach wx (list (- bx dW) (+ bx dW))
                (peb-crane-sec-circ wx (+ railTop rW) rW)                         ; wheel on the rail
                (peb-crane-sec-sline wx (+ railTop rW) wx (+ railTop (* rW 2.05)))) ; axle stub to the frame
              (peb-crane-sec-sline (- bx dW) (+ railTop (* rW 2.05)) (+ bx dW) (+ railTop (* rW 2.05))) ; axle beam
              (peb-crane-sec-sbox (- bx (* fw 1.05)) (+ railTop (* rW 2.05)) (+ bx (* fw 1.05)) bridgeBot))) ; end-truck frame
            ;; ── crane BRIDGE girder — spans c/c of rails (on the end trucks for TR / under the beams for
            ;;    UH) — DASHED (by others).  PER-FRAME RULE: this typical section is a frame WITHIN the
            ;;    crane run, so the crane is shown; per-frame sections outside the run would omit it. ──
            (peb-crane-sec-dbox xBL bridgeBot xBR bridgeTop)
            ;; ── spread SERIES cranes: if >1 crane shares this width-module, offset each hoist
            ;;    across the bridge span so symbols + labels never stack on an identical midX ──
            (setq k        (strcat gfW "_" gtW)
                  total    (if (assoc k modCount) (cdr (assoc k modCount)) 1)
                  a        (assoc k modSeen)
                  idxInMod (if a (cdr a) 0)
                  hoistX   (+ xBL (* (/ (+ idxInMod 1.0) (+ total 1.0)) (- xBR xBL))))
            (if a (setq modSeen (subst (cons k (1+ idxInMod)) a modSeen))
                  (setq modSeen (cons (cons k 1) modSeen)))
            ;; ── DETAILED HOIST symbol (manual §10.6) at its spread position, then the
            ;;    lifting CABLE dropping from the hook tip to the hook-height marker near the floor ──
            (setq hkTip (peb-crane-sec-hoist hoistX bridgeBot u))
            (peb-crane-sec-line hoistX hkTip hoistX hookH)
            ;; ── HOOK HEIGHT — compact M-Ladder: a SOLID up-arrow at the hook + value/cap/class stacked ──
            (entmake (list (cons 0 "SOLID") (cons 8 "COMP-CRANE-SEC")            ; up-arrow AT the hook
                           (list 10 hoistX hookH 0.0)
                           (list 11 (- hoistX (* u 0.16)) (- hookH (* u 0.5)) 0.0)
                           (list 12 (+ hoistX (* u 0.16)) (- hookH (* u 0.5)) 0.0)
                           (list 13 (+ hoistX (* u 0.16)) (- hookH (* u 0.5)) 0.0)))
            (txt-rom "MC" (list hoistX (- hookH (* u 0.95))) (/ (* u 0.40) sc) 0.0
                      (strcat "HOOK HEIGHT : " (rtos hookH 2 0)))
            (txt-rom "MC" (list hoistX (- hookH (* u 1.70))) (/ (* u 0.52) sc) 0.0
                      (strcat "CAP " capStr " MT"))
            (if (and cls (/= cls ""))
              (txt-rom "MC" (list hoistX (- hookH (* u 2.35))) (/ (* u 0.36) sc) 0.0
                        (strcat "CMAA CLASS " cls)))
            ;; CRANE SPAN (centre-to-centre of rails) — the actual rail span (inner flange to inner flange)
            (txt-rom "MC" (list hoistX (- hookH (* u 2.90))) (/ (* u 0.34) sc) 0.0
                      (strcat "SPAN c/c RAILS : " (rtos (- xBR xBL) 2 0)))
            ;; ── part labels drawn ONCE (manual convention), spaced with leaders into clear space ──
            (if (not labeled)
              (progn
                ;; CRANE BRIDGE — shifted toward the module centre, clear of the knee
                (txt-rom "MC" (list (+ midX (* u 1.6)) (+ bridgeTop (* u 0.62))) (/ (* u 0.40) sc) 0.0 "CRANE BRIDGE (BY OTHERS)")
                ;; HOIST — short leader off the RIGHT of the hoist into open space
                (peb-crane-sec-line (+ hoistX (* u 0.85)) (- hoistTop (* u 0.55)) (+ hoistX (* u 1.45)) (- hoistTop (* u 0.55)))
                (txt-rom "ML" (list (+ hoistX (* u 1.55)) (- hoistTop (* u 0.55))) (/ (* u 0.40) sc) 0.0 "HOIST (BY OTHERS)")
                ;; CRANE BEAM — leader from the crane beam down-inward to the label (type-aware name)
                (peb-crane-sec-line xBL beamBot (+ xBL (* u 1.1)) (- beamBot (* u 0.9)))
                (txt-rom "ML" (list (+ xBL (* u 1.2)) (- beamBot (* u 0.9))) (/ (* u 0.40) sc) 0.0
                          (if isUH "CRANE BEAM (BY OTHERS)" "CRANE BEAM"))
                ;; CRANE RAIL (BY OTHERS) — TR only (rail sits on the beam TOP; UH runs on the bottom flange)
                (if (not isUH)
                  (progn
                    (peb-crane-sec-line xBL railTop (+ xBL (* u 1.3)) (+ railTop (* u 0.85)))
                    (txt-rom "ML" (list (+ xBL (* u 1.4)) (+ railTop (* u 0.85))) (/ (* u 0.34) sc) 0.0
                              "CRANE RAIL (BY OTHERS)")))
                ;; HEIGHT OF CRANE BEAM — noted once (top of crane beam above FFL)
                (txt-rom "MC" (list (+ midX (* u 1.6)) (+ bridgeTop (* u 1.35))) (/ (* u 0.36) sc) 0.0
                          (strcat "HEIGHT OF CRANE BEAM : " (rtos railTop 2 0)))
                ;; ── Mammut Zealcon house-polish (owner 19-Jul) ──
                ;; CL OF RAFTER — bridge centre = rafter centreline; label offset LEFT (the bridge/height
                ;; labels sit right of centre) via a short tick + leader so nothing overlaps
                (peb-crane-sec-line midX (+ bridgeTop (* u 0.15)) midX (+ bridgeTop (* u 0.80)))
                (peb-crane-sec-line midX (+ bridgeTop (* u 0.80)) (- midX (* u 1.35)) (+ bridgeTop (* u 0.80)))
                (txt-rom "MR" (list (- midX (* u 1.45)) (+ bridgeTop (* u 0.80))) (/ (* u 0.30) sc) 0.0 "CL OF RAFTER")
                ;; LEVEL DATUM at the crane beam (metres from FFL) — Mammut-style level tag, left of the rail
                (entmake (list (cons 0 "SOLID") (cons 8 "COMP-CRANE-SEC")
                               (list 10 (- xBL (* u 0.55)) railTop 0.0)
                               (list 11 (- xBL (* u 0.78)) (+ railTop (* u 0.22)) 0.0)
                               (list 12 (- xBL (* u 0.78)) (- railTop (* u 0.22)) 0.0)
                               (list 13 (- xBL (* u 0.78)) (- railTop (* u 0.22)) 0.0)))
                (txt-rom "MR" (list (- xBL (* u 0.90)) railTop) (/ (* u 0.30) sc) 0.0
                          (strcat "CRANE BEAM +" (rtos (/ railTop 1000.0) 2 3) " M"))
                ;; AT GRID note — the crane frame applies only at its run grid lines (Mammut convention)
                (if (/= (MSPL-Get-Str data (strcat pre "GRID_LOC")) "")
                  (txt-rom "MC" (list hoistX (- hookH (* u 3.45))) (/ (* u 0.30) sc) 0.0
                            (strcat "CRANE AT " (strcase (MSPL-Get-Str data (strcat pre "GRID_LOC"))) " ONLY")))
                (setq labeled T)))
            (princ))))
          (setq n 3)))               ; drew one crane -> break the loop (one per section)
        (setq n (1+ n)))
      (setvar "CLAYER" "0")))
  (princ))

;; simple 45° concrete cross-hatch inside a rectangle (manual — reliable headless, unlike AR-CONC)
(defun peb-sec-xhatch (x0 y0 x1 y1 / d xx)
  (setq d (- y1 y0) xx x0)
  (while (< xx x1)
    (command "_.LINE" (list xx y0) (list (min x1 (+ xx d)) (+ y0 (min d (- x1 xx)))) "")
    (setq xx (+ xx 300.0)))
  (setq xx (- x0 d))
  (while (< xx x1)
    (command "_.LINE" (list (max x0 xx) (+ y0 (max 0.0 (- x0 xx)))) (list (min x1 (+ xx d)) (+ y0 (min d (- x1 xx)))) "")
    (setq xx (+ xx 300.0))))

;; RAISED-BASE DETAIL on the CROSS SECTION (owner 29-Jul): to the RIGHT of the typical frame, show how the
;; steel typical column at grid rbFrom..rbTo lands on the EXISTING RCC building — existing RCC column (0 ->
;; +rbFloor) + the first-floor RCC beam/slab (built in concrete) + an RCC pedestal (+rbFloor -> +rbBase), with
;; the STEEL column starting on top at +rbBase. Sets *PEB-SEC-DETAIL-R* so the sheet border widens to include it.
(defun peb-sec-raised-detail (data wid H / rf rb gf gt ts ox cw colH rxL rxR)
  (if (= (peb-tb-or (MSPL-Get-Str data "BP_RAISED_ON") "0") "1")
    (progn
      (setq rf (atof (peb-tb-or (MSPL-Get-Str data "BP_RAISED_FLOOR") "0"))
            rb (atof (peb-tb-or (MSPL-Get-Str data "BP_RAISED_BASE") "0"))
            gf (peb-tb-or (MSPL-Get-Str data "BP_RAISED_GRID_FROM") "4")
            gt (peb-tb-or (MSPL-Get-Str data "BP_RAISED_GRID_TO") "5")
            ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
            ox (+ wid (* 9000 ts)) cw 700.0 colH 3000.0)
      (if (> rb 0.0)
        (progn
          (setvar "CECOLOR" "BYLAYER")
          ;; ground line
          (setvar "CLAYER" "GROUND")
          (command "_.LINE" (list (- ox (* 2600 ts)) 0.0) (list (+ ox cw (* 2600 ts)) 0.0) "")
          ;; EXISTING RCC COLUMN (0 -> rf) + FIRST-FLOOR BEAM/SLAB at rf + RCC PEDESTAL (rf -> rb) : grey concrete
          (setvar "CLAYER" "HATCHR")
          (vl-catch-all-apply (function (lambda () (setvar "CECOLOR" "RGB:150,150,150"))))
          (command "_.RECTANG" (list ox 0.0) (list (+ ox cw) rf))                                   ; RCC column
          (peb-sec-xhatch ox 0.0 (+ ox cw) rf)
          (setq rxL (- ox (* 1900 ts)) rxR (+ ox cw (* 1900 ts)))
          (command "_.RECTANG" (list rxL rf) (list rxR (+ rf 380.0)))                                ; first-floor beam/slab
          (peb-sec-xhatch rxL rf rxR (+ rf 380.0))
          (command "_.RECTANG" (list (+ ox 70.0) (+ rf 380.0)) (list (+ ox cw -70.0) rb))            ; RCC pedestal
          (peb-sec-xhatch (+ ox 70.0) (+ rf 380.0) (+ ox cw -70.0) rb)
          (setvar "CECOLOR" "BYLAYER")
          ;; STEEL COLUMN (I-section, double line) starting on the pedestal at rb + base plate
          (setvar "CLAYER" "COLUMNS")
          (command "_.RECTANG" (list (+ ox (* cw 0.5) -130.0) rb) (list (+ ox (* cw 0.5) 130.0) (+ rb colH)))
          (setvar "CLAYER" "PLATES")
          (command "_.RECTANG" (list (+ ox (* cw 0.5) -300.0) (- rb 45.0)) (list (+ ox (* cw 0.5) 300.0) (+ rb 45.0)))
          ;; level ticks + labels (to the right)
          (setvar "CLAYER" "TEXT")
          (txt "MC" (list (+ ox (* cw 0.5)) (- 0.0 (* 1000 ts))) (* 320 ts) 0
               (strcat "DETAIL @ GRID " gf "-" gt " - STEEL COLUMN ON EXISTING RCC"))
          ;; labels stacked at WELL-SEPARATED heights (with short leaders) so they don't overlap
          (setvar "CLAYER" "TEXT")
          (command "_.LINE" (list (+ ox (* cw 0.5)) (+ rb (* colH 0.62))) (list (+ rxR (* 300 ts)) (+ rb (* colH 0.62))) "")
          (txt "ML" (list (+ rxR (* 400 ts)) (+ rb (* colH 0.62))) (* 250 ts) 0 "STEEL TYPICAL COLUMN (BY MAIMAAR)")
          (command "_.LINE" (list (+ ox cw -70.0) (+ rf 380.0 (* 0.5 (- rb (+ rf 380.0))))) (list (+ rxR (* 300 ts)) (+ rb 900.0)) "")
          (txt "ML" (list (+ rxR (* 400 ts)) (+ rb 900.0)) (* 250 ts) 0 (strcat "RCC PEDESTAL TO +" (rtos (/ rb 1000.0) 2 3) " M (STEEL BASE)"))
          (command "_.LINE" (list rxR (+ rf 190.0)) (list (+ rxR (* 300 ts)) (- rf 600.0)) "")
          (txt "ML" (list (+ rxR (* 400 ts)) (- rf 600.0)) (* 250 ts) 0 (strcat "EXISTING 1st-FLOOR RCC BEAM / SLAB  +" (rtos (/ rf 1000.0) 2 3) " M"))
          (command "_.LINE" (list (+ ox cw) (* rf 0.45)) (list (+ rxR (* 300 ts)) (* rf 0.30)) "")
          (txt "ML" (list (+ rxR (* 400 ts)) (* rf 0.30)) (* 250 ts) 0 "EXISTING RCC COLUMN (BY OTHERS)")
          (setq *PEB-SEC-DETAIL-R* (+ rxR (* 16000 ts)))))))
  (princ))

(defun C:PEB-SECTION
  ( / dataFile data
    project client propinput propno fulldate
    bldgno revno
    len wid widInput stype slopeStr slopeD rise ridgeXoff
    H clearHt ht rd cb fw ep purlinD brickH
    windspeed exposure collateral
    maxSize areaM2
    c0 c1 c2 c3 c4 c5 c6
    tbTop tbBot tbW tbXShift
    mzCH mzFFL mzOver dimX3 dimX4
    borderL borderR borderB borderT
    logoX logoY logoScale
    ext extY
    dimX1 dimX2 d y
    loadValX bubR
    layout cols ridges i rx cx prevCol curCol modw wgrid
    numGab effSpan slopeRise spanPerGab gWmg haunchCols msApexX msRidgeX peakClr msWidths
    bubY tbShift tbScale cxL cyL cxR cyR tagRun
    dimX1 dimX2 dimX3 dimX4
    leftCol rightCol halfL halfR midLX midRX midLY midRY
    nCols bubX
    loadValW rowY lineH rowGap nL pjValX pjValW rowPad rTops yy
    oldEnts shiftAmt
    rcDe rcIn
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
  (if (not (member stype '("CS" "SS" "MS" "LT" "MG" "FR" "F2" "RC" "CC" "BF" "ACS" "AMS" "PP")))
    (setq stype "CS"))
  ;; A FLAT ROOF with the MEZZANINE sub-section switched on becomes a MULTI-STOREY flat roof (F2): the
  ;; intermediate floor(s) + full-height columns are drawn by the F2 branches (owner 15-Jul workflow).
  (if (and (member stype '("FR" "F2")) (f2-active-p data)) (setq stype "F2"))
  ;; proper canopy name for this sheet; nil for non-canopy stypes (reset every sheet, never stale).
  (setq *PEB-CANOPY-NAME* (peb-canopy-name stype data))

  ;; ── PARAPET FASCIA flags (FA_*) ───────────────────────────────────────
  ;; The parapet is the only fascia that stands IN the wall plane, so on a parapet
  ;; eave the gutter would hang outside the building and the 270 roof-sheet
  ;; overhang would run straight through the panel.  draw-eave-features and
  ;; draw-cladding both run BEFORE the fascia detail, so the decision is taken
  ;; here, ONCE, and read from there.  Set on EVERY sheet (never left stale from
  ;; the previous drawing).  RC has its own concrete parapet (draw-rc-fascia) and
  ;; is excluded -- it suppresses its own eave gutter through *PEB-RC-FASCIA*.
  (setq *PEB-FA-PARA-L* (and (/= stype "RC") (peb-fascia-parapet-p data "NSW")))
  (setq *PEB-FA-PARA-R* (and (/= stype "RC") (peb-fascia-parapet-p data "FSW")))
  ;; WHICH EAVE CARRIES THE ANNOTATION.  A cross-section is symmetric, so the
  ;; engine annotates ONE eave: the left/NSW when it has a fascia, else the right.
  ;; draw-fascia-vertical used to work this out for itself, but draw-eave-features
  ;; now needs the same answer to decide where the ONE gutter callout goes -- and it
  ;; runs FIRST.  Resolved here so the two can never disagree; draw-fascia-vertical
  ;; reads it back rather than recomputing.
  (setq *PEB-FA-LAB-R*
    (and (= (strcase (peb-tb-or (MSPL-Get-Str data "FA_TOGGLE") "")) "YES")
         (/= (strcase (peb-tb-or (MSPL-Get-Str data "FA_NSW_TOGGLE") "")) "YES")))

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
  ;; owner 9-Jul: an OFF-CENTRE ridge (BP_RIDGE_OFFSET) makes the two pitches unequal, because both
  ;; eaves sit at H.  Convention (matches proposalData.ts, which already bills it this way):
  ;; the stated slope governs the LONGER run, so rise = max(off, W-off) / slopeD and the SHORT side
  ;; comes out steeper.  A central ridge gives back (W/2)/slopeD exactly -- no change to the common
  ;; case.  Gable stypes only: MG has per-gable central ridges, and ACS/AMS crowns must stay central.
  (if (member stype '("CS" "MS" "RC"))
    (progn
      (setq ridgeXoff (peb-ridge-x data wid))
      (setq rise (/ (max ridgeXoff (- wid ridgeXoff)) slopeD))))

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
  ;; haunch depth 700-1100mm for a 15-50 m span — the rule now lives in
  ;; peb-haunch-depth so the title block can add the SAME depth it draws.
  (setq ht      (if (boundp 'peb-haunch-depth)
                  (peb-haunch-depth effSpan)
                  (max 700.0 (min 1100.0 (+ 700.0 (* (/ (- effSpan 15000.0) 35000.0) 400.0))))))
  ;; Ridge depth ~70% of haunch (visible vertical depth), per Chapter 3 / user guidance.
  (setq rd      (max 600.0 (min 1000.0 (- ht 100.0))))         ; ridge depth: ht-100mm (600-1000mm for span 15-50m)
  (setq cb      (max 250.0 (min 400.0 (+ 250.0 (* (/ (- effSpan 15000.0) 35000.0) 150.0)))))   ; column base: 250-400mm for span 15-50m
  (setq fw      200.0)                                        ; flange width
  (setq ep      20.0)                                         ; end plate thickness (typical 20-24mm)
  (setq purlinD 200.0)                                        ; Z-purlin standard

  ;; ── BSF-DRIVEN FIDELITY (owner 21-Jul) — all CONDITIONAL: blank/default reproduces today's drawing ──
  ;; BP_COL_WEB_STYLE "Straight" ⇒ constant-depth end columns: set the base web = haunch web so the inner
  ;; face is vertical (build-frame-polygon slopes cb→ht; cb=ht ⇒ no taper). Blank/"Tapered Web" ⇒ unchanged.
  (if (= (strcase (peb-tb-or (MSPL-Get-Str data "BP_COL_WEB_STYLE") "")) "STRAIGHT") (setq cb ht))
  ;; BP_EXT/INT_BASE_COND "Fixed" ⇒ 4-bolt moment base plate; "Pinned" (default) ⇒ 2 bolts. Read by
  ;; draw-base-plate-at via *BASE-BOLTS*, set per-column-group by draw-base-plates / -multi below.
  (setq *BASE-BOLTS-EXT* (if (= (strcase (peb-tb-or (MSPL-Get-Str data "BP_EXT_BASE_COND") "")) "FIXED") 4 2))
  (setq *BASE-BOLTS-INT* (if (= (strcase (peb-tb-or (MSPL-Get-Str data "BP_INT_BASE_COND") "")) "FIXED") 4 2))
  (setq *BASE-BOLTS* *BASE-BOLTS-EXT*)

  ;; ── HEIGHT BASIS (owner 25-Jul) ─────────────────────────────
  ;; Honor the BSF "Height — Measured At" basis (HEIGHT_REF), the SAME way the plan's height tag
  ;; (peb-height-tag-label) and the length/width dims already read their own basis. The section works
  ;; INTERNALLY in CLEAR height (rafter underside at the haunch; H = clearHt + ht). When the height was
  ;; measured at the EAVE, the entered number IS the eave (top of steel / purlin line), so derive the
  ;; internal clear height by dropping the haunch (clearHt = eave - ht) -> H then lands EXACTLY on the
  ;; entered eave height and the height dim (below) reads it to the purlin, not the haunch.
  ;; CLEAR is tested FIRST — "Clear Height at Eave" also contains "EAVE" (same trap as peb-height-tag-label);
  ;; blank -> clear (the BSF heightBasis list defaults to "Clear Height at Eave").
  (setq heightRef (strcase (peb-tb-or (MSPL-Get-Str data "HEIGHT_REF") "")))
  (setq eaveBasis (and (not (wcmatch heightRef "*CLEAR*")) (wcmatch heightRef "*EAVE*")))
  ;; EAVE HEIGHT IS FFL TO THE TOP OF THE EAVE STRUT / PURLIN (owner, 3-Sep-2026).
  ;; The entered number therefore carries BOTH the haunch AND the purlin above the clear height,
  ;; so BOTH come out of it here. Backing out only the haunch made the drawn building one purlin
  ;; depth (200 mm) shorter than the height the customer stated, and put the section's own EAVE
  ;; HEIGHT arrow at the top of the rafter instead of the top of the purlin — while the title
  ;; block on the SAME sheet printed clear + haunch + purlin (peb-tb-eave-height). One sheet,
  ;; two different eave heights: exactly the contradiction rule 4B.7 exists to stop.
  ;; peb-clear-height (Plan.lsp) already backs out `peb-eave-add` = haunch + purlin; this is the
  ;; section saying the same thing with its own locals.
  (if (and eaveBasis (> clearHt (+ ht purlinD 1.0))) (setq clearHt (- clearHt ht purlinD)))

  ;; Eave height = top of rafter at the haunch.
  ;; Rafter UNDERSIDE at the haunch sits exactly at clearHt (user input, or eave-ht when eave-basis).
  ;; Purlins and sheeting sit ABOVE H (H + purlinD, H + purlinD + cladThk).
  (setq H (+ clearHt ht))   ; roof concrete-slab top (F2/G+1 too: roof comes from the tall eave height)

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
  (setq *PEB-BUB-FIT* (peb-bub-fit "SECTION"))
  ;; (setup-maimaar-dim is defined above and was used by the
  ;;  peb-dim-*-native helpers, but the current code path uses the
  ;;  hand-rolled dim-line-h / draw-height-dim functions which don't
  ;;  need a registered dimstyle — they emit primitives directly.)
  ;; Fix the Standard multileader style so MLEADERs get a visible
  ;; "Closed Filled" arrowhead.  Without this, the style ships with
  ;; arrow set to "_None" and ArrowSize is irrelevant.
  (peb-setup-mleader-style)

  ;; ── Default DIMTXSTY = PEB-DIM (ROMAND) for every dim in the run ──
  ;; owner 19-Jul STANDING RULE: all dimension text is ROMAND (Roman Duplex).  Set globally now so even
  ;; dims that bypass peb-dim-set-vars (e.g., legacy callers) still pick up the right text style.
  (vl-catch-all-apply
    (function (lambda () (setvar "DIMTXSTY" "ROMAND"))))

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
  ;; owner 15-Jul STANDARD: ARIAL (proportional TrueType) for body/title/dim — matches the approved
  ;; frame set (was romans.shx single-stroke).  entmake via peb-std-ttf-style avoids the TTF -STYLE
  ;; prompt-count hang; falls back to the romans .shx styles only if Standard.lsp isn't loaded.
  ;; owner 19-Jul UNIVERSAL RULE: ALL TEXT = ROMAND (romand.shx) everywhere — labels, M-ladders, member
  ;; callouts, notes, titles, dimensions.  (Title-block company name stays bold via its own MTEXT \\fArial|b1.)
  (make-text-style "PEB-TITLE" "romand.shx")
  (make-text-style "PEB-BODY"  "romand.shx")
  (make-text-style "PEB-DIM"   "romand.shx")
  ;; owner 19-Jul STANDING RULE: dedicated dimension text style literally NAMED "ROMAND" (font romand.shx)
  ;; so the AutoCAD Properties "Text style" field reads ROMAND.  Every dimension's DIMTXSTY points here.
  (make-text-style "ROMAND" "romand.shx")
  ;; owner 19-Jul UNIVERSAL: the title-block MTEXT uses the "Standard" text style (tb-mtext) — repoint it to
  ;; ROMAND (romand.shx) + oblique 0 so ALL title-block body text (notes / load table / project fields) is
  ;; ROMAND upright.  Bold headers + company name keep their inline \fArial|b1 override, so they stay bold.
  (vl-catch-all-apply
    (function (lambda (/ so sd)
      (setq so (tblobjname "STYLE" "Standard"))
      (if so (progn (setq sd (entget so))
                    (if (assoc 3  sd) (setq sd (subst (cons 3 "romand.shx") (assoc 3 sd) sd)))
                    (if (assoc 50 sd) (setq sd (subst (cons 50 0.0) (assoc 50 sd) sd)))
                    (entmod sd))))))

  ;; ── Linetypes ────────────────────────────────────────────────
  (safe-load-ltype "CENTER")
  (safe-load-ltype "HIDDEN")
  (safe-load-ltype "DASHDOT")

  ;; ── Layers ───────────────────────────────────────────────────
  ;; Prefer the shared Presentation Standards DB when MAIMAAR_PEB_Standard.lsp
  ;; is loaded (single source of truth for the whole proposal set); otherwise
  ;; fall back to this inline block.
  ;; SINGLE SOURCE (29-Jun): layers come ONLY from MAIMAAR_PEB_Standard.lsp.
  ;; The old inline Phase-2 fallback block was DROPPED so stale brick values can
  ;; never mix with the owner-locked standard.  Standard must be loaded first.
  (if (boundp 'peb-std-setup)
    (vl-catch-all-apply (function (lambda () (peb-std-setup))))
    (princ "\n** MAIMAAR_PEB_Standard.lsp NOT loaded — load it FIRST; it is the single source of every line brick. **"))

  ;; ── Compute section layout (cols + ridges) based on stype ───
  (setq layout (compute-section-layout data stype wid))
  (setq cols   (car  layout))
  (setq ridges (cadr layout))
  ;; -- RULE 4B.37 - THE SECTION IS VIEWED FROM THE OTHER SIDE (owner 29-Aug) ----
  ;; "Section should be shown from other side ... keep the Grid Line A on Left Side",
  ;; "start the Grid from A to J then".
  ;;
  ;; The section is built in the PLAN's own width direction: x = 0 is the NEAR side
  ;; wall.  But the plan letters the width from the FAR side wall (peb-width-letter,
  ;; grid A = FSW), so the section came out lettered J..A left-to-right - back to
  ;; front against every other sheet in the set.
  ;;
  ;; The fix is applied HERE, to cols/ridges, and nowhere else, because every piece
  ;; of section geometry - frame outline, columns, purlins, the module dim chain, the
  ;; bubbles - is derived from these two lists.  Mirroring the finished sheet instead
  ;; would flip the title block and the data table with it, and mirroring at each
  ;; drawer would be a dozen chances to miss one (which is exactly how the width
  ;; chain came to be reversed in the first place - see rule 4B.34).
  ;;
  ;; Mirroring about the building's own centre leaves the bbox identical, so the
  ;; frame, the tiling and the A4 viewport fit are all unaffected.
  ;;
  ;; From here down x is SECTION space.  Anything that consults a PLAN-space list
  ;; (the merged width grid, the mezzanine band) un-mirrors at the point of use.
  (setq cols   (vl-sort (mapcar (function (lambda (v) (- wid v))) cols)   '<))
  (setq ridges (vl-sort (mapcar (function (lambda (v) (- wid v))) ridges) '<))

  ;; ── Floor / ground line ──────────────────────────────────────
  (draw-floor-line wid ext)
  ;; "FFL ±0.00" elevation marker — centered under the building (X = wid/2).  Cantilever canopies
  ;; (BF/CC/PP) carry a column ON the centre line, so shift the marker clear of it (owner 16-Jul markup 4).
  (draw-ffl-marker (if (member stype '("BF" "CC" "PP")) (+ (/ wid 2.0) 1800.0) (/ wid 2.0)) 0.0)

  ;; ── Frame outline (stype-aware dispatcher) ───────────────────
  (cond
    ;; existing RCC building host: concrete columns + FLAT RCC roof slab (no steel roof) — owner 8-Jul
    ((peb-mz-rcc-sec-p data)
      (draw-rcc-building-frame cols wid H cb))
    ((= stype "SS")
      (setq slopeRise (/ wid slopeD))
      (setq ssTP (ss-taper-params cols wid slopeRise ht))                 ; (midD hLx) — shared w/ plates
      (draw-ss-frame cols wid H slopeRise ht cb (cadr ssTP) (car ssTP))
      ;; SSMS: draw the interior columns (clear-span SSCS has none — cols = (0 W))
      (if (> (length cols) 2) (draw-ss-interior-cols cols wid H slopeRise ht)))
    ((= stype "RC")
      ;; Two arrangements (owner markups 4/9): FA_TOGGLE=Yes → RCC PARAPET/FASCIA (columns above roof + valley
      ;; gutter); else plain roof-on-RCC with eave gutters.  Parapet height above eave = FA_NSW_HT (def 1200).
      (setq *PEB-RC-FASCIA* (= (strcase (peb-tb-or (MSPL-Get-Str data "FA_TOGGLE") "")) "YES"))
      (setq rcParaH (MSPL-Get-Num data "FA_NSW_HT"))
      (if (or (null rcParaH) (<= rcParaH 0.0)) (setq rcParaH 1200.0))
      (draw-rc-frame wid H rise ht rd *PEB-RC-FASCIA* rcParaH))
    ((= stype "LT")
      (setq slopeRise (/ wid slopeD))
      (draw-lt-frame wid H slopeRise ht cb))
    ((= stype "FR")
      (draw-fr-frame wid H ht cb))
    ((= stype "F2")
      (draw-f2-frame wid H ht cb (f2-int-col-xs data wid)))
    ((= stype "PP")
      ;; Petrol Pump / CNG canopy — near-flat roof on inset columns, cantilever both sides.
      (draw-petrol-frame wid H ht cb))
    ((= stype "CC")
      (setq slopeRise (/ wid slopeD))
      (draw-cc-frame wid H slopeRise ht cb
                     (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_LOW_AT_COLUMN") "")) "YES")))
    ((= stype "BF")
      ;; BF stype covers BOTH 2-wing canopies: Butterfly (valley, default) and Falcon (centre peak)
      ;; when CC_FALCON_PEAK=Yes (owner 8-Jul).
      (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES")
        (draw-falcon2-frame wid H rise ht cb 400.0)
        (draw-bf-frame wid H rise ht cb 400.0 (peb-bf-valley-x data wid)
                       (MSPL-Get-Num data "BP_VALLEY_HEIGHT"))))
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
      (draw-mg-multi-frame wid H rise ht rd cb (peb-mg-grid data wid)))
    (T
      ;; CS, MG (spanPerGab=1) and other standard gable-type frames
      (draw-frame-outline cols ridges H rise ht rd cb)))

  ;; ── Mezzanine floor in section (deck + beam + support columns) ──
  ;; Skip for F2: the multi-storey FLAT ROOF branch already draws its intermediate floor(s) + full-height
  ;; columns with the flat-roof build-up coding (700 beam), so the generic mezzanine drawer would double it.
  (if (/= stype "F2")
    (vl-catch-all-apply (function (lambda () (peb-draw-mezz-section data wid cols)))))

  ;; ── Catwalk (owner 14-Jul): OUTER LINES only, installed at the columns INSIDE or OUTSIDE ──
  (vl-catch-all-apply (function (lambda () (peb-draw-catwalk data wid cols H ht))))

  ;; ── Crane footprint in section (migrated from the plan; runway + bridge + hook per module) ──
  (vl-catch-all-apply (function (lambda () (peb-draw-crane-section data wid cols H ht clearHt rise rd ridges))))

  ;; ── Roof monitor at the peak (owner 13-Jul) — only for frames with a ridge/peak ──
  (setq *RM-THROAT-WIN* nil)
  (if (and ridges (car ridges)
           (member stype '("CS" "MS" "RC" "MG"))    ; owner 19-Jul: monitor only on TRUE-PEAK gable frames — excludes SS/mono, ACS/AMS (arch crown), BF (valley), PP/LT/FR/F2 where a "ridge" is not a straight-gable peak
           (= (strcase (peb-tb-or (MSPL-Get-Str data "RM_TOGGLE") "")) "YES"))
    (progn
      (vl-catch-all-apply (function (lambda () (peb-draw-roof-monitor data wid H rise (car ridges) ht rd cb slopeD))))
      ;; throat window for the main roof sheeting/purlins (trim + edge purlins). Same throat +
      ;; fallback the drawer uses; centred on the ridge station (car ridges).
      (setq *RM-TH* (MSPL-Get-Num data "RM_THROAT_WIDTH"))
      (if (or (null *RM-TH*) (<= *RM-TH* 0.0)) (setq *RM-TH* (MSPL-Get-Num data "RM_OVERALL_WIDTH")))
      (if (or (null *RM-TH*) (<= *RM-TH* 0.0)) (setq *RM-TH* (min 3500.0 (* wid 0.20))))
      (setq *RM-THROAT-WIN* (list (- (car ridges) (/ *RM-TH* 2.0)) (+ (car ridges) (/ *RM-TH* 2.0))))))

  ;; ── Connection plates ────────────────────────────────────────
  ;; For MG: plates only at HAUNCH columns (left/right outer + valley
  ;; columns between gables).  Sub-span intermediate columns are not
  ;; haunch points - they sit under the rafter and do not need plates.
  (cond
    ;; existing RCC building: no steel haunch/base plates (concrete frame) — owner 8-Jul
    ((peb-mz-rcc-sec-p data) nil)
    ((= stype "PP")
      ;; Petrol Pump (cantilever) — owner 14-Jul: place the connection plates here too, UN-rotated
      ;; (vertical), at the SIDE of each box column / backside of the roof-beam web.  Geometry mirrors
      ;; draw-petrol-frame: columns inset at ovh & W-ovh, roof band (H-rt .. H), box width max(cb,300).
      (progn
        (setq ppOvhP (* wid 0.22) ppRtP (max (* ht 0.8) 250.0) ppCwP (max cb 300.0))
        (setq ppC1 ppOvhP ppC2 (- wid ppOvhP))
        (draw-base-plate-at (- ppC1 (/ ppCwP 2.0)) (+ ppC1 (/ ppCwP 2.0)) cb (* 25 *PEB-TEXT-SCALE*))
        (draw-base-plate-at (- ppC2 (/ ppCwP 2.0)) (+ ppC2 (/ ppCwP 2.0)) cb (* 25 *PEB-TEXT-SCALE*))
        ;; I-shape (vertical) connection plate on the INNER face of each box column, spanning the roof-beam depth
        ;; trailing nil = slope (the roof beam here is horizontal).  draw-cant-vplate
        ;; takes SIX arguments and already turns a nil slope into 0.0 -- but the
        ;; argument still has to be PASSED, or the branch aborts silently.
        (draw-cant-vplate (+ ppC1 (/ ppCwP 2.0)) (- H ppRtP) H 45.0 3 nil)
        (draw-cant-vplate (- ppC2 (/ ppCwP 2.0)) (- H ppRtP) H 45.0 3 nil)))
    ((= stype "MG")
      (progn
        ;; Gable boundaries (valleys) + per-gable ridge centres from the canonical FRAME GRID
        ;; (Tier 0) — unequal gables OK.  haunchCols = 0, valley1, valley2, ..., wid.
        (setq mgGrid (peb-mg-grid data wid))
        (setq mgAcc 0.0) (foreach mgG mgGrid (setq mgAcc (+ mgAcc (apply '+ mgG))))
        (setq mgSc (if (> mgAcc 0.0) (/ wid mgAcc) 1.0))
        (setq haunchCols (list 0.0) mgRidgeXs '() cum 0.0)
        (foreach mgG mgGrid
          (setq gWmg (* (apply '+ mgG) mgSc))
          (setq mgRidgeXs (append mgRidgeXs (list (+ cum (/ gWmg 2.0)))))
          (setq cum (+ cum gWmg))
          (setq haunchCols (append haunchCols (list cum))))
        (draw-base-plates-multi haunchCols cb ep 400.0)
        ;; Standard knee-haunch + valley-seam plates at the gable boundaries (4-vertical-plate valley).
        (draw-haunch-plates haunchCols H ht ep T nil nil)
        (draw-rafter-stiffeners haunchCols mgRidgeXs H rise ht rd nil
          (peb-interior-col-clearances haunchCols nil 400.0))
        ;; Ridge-column plates only where a gable's centre coincides with an interior sub-span
        ;; column (its centre is a sub-module boundary — e.g. a 2-sub-module gable).
        (setq cum 0.0)
        (foreach mgG mgGrid
          (setq gWmg (* (apply '+ mgG) mgSc) ridgeX (+ cum (/ gWmg 2.0)) sub 0.0 hit nil)
          (foreach sp mgG
            (setq sub (+ sub (* sp mgSc)))
            (if (equal (+ cum sub) ridgeX 1.0) (setq hit T)))
          (if hit (draw-mg-ridge-col-plates ridgeX H rise rd ep))
          (setq cum (+ cum gWmg)))))
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
        ;; Against the REAL ridge, not wid/2: with BP_WIDTH_MOD_REF = "Out to out of Steel
        ;; Column" the ridge sits at the centre of the STEEL width, which is not wid/2, and with
        ;; BP_RIDGE_OFFSET it is nowhere near it. Testing wid/2 meant a column genuinely under
        ;; the apex was missed - it then got the generic interior detail instead of the
        ;; ridge-column one, and (before 4B.52) kept a rafter plate over its head as well.
        (setq msApexX nil)
        (setq msRidgeX (if ridges (car ridges) (/ wid 2.0)))
        (setq i 1)
        (while (< i (1- (length cols)))
          (if (< (abs (- (nth i cols) msRidgeX)) 1.0)
            (setq msApexX (nth i cols)))
          (setq i (1+ i)))
        ;; END-column haunch plates ONLY — pass (0, wid) so draw-haunch-plates
        ;; renders the LEFT-end and RIGHT-end haunch details and nothing else.
        ;; Interior MS columns use the new draw-ms-interior-plates helper
        ;; below, which positions plates at the actual cigar-rafter underside
        ;; and sizes them to the per-column web (300-600 mm based on module).
        (draw-haunch-plates (list 0.0 wid) H ht ep nil nil nil)
        ;; Rafter web transition plates + 12 m mid-span splices.
        ;; CRITICAL: pass (0, wid) NOT cols — draw-rafter-stiffeners uses
        ;; cols[i] / cols[i+1] as the gable boundaries flanking ridges[i],
        ;; and for MS the gable spans the FULL building width, not the
        ;; first module.  Without this, transition X positions and the
        ;; 12 m piece-rule are computed against a tiny sub-segment.
        (draw-rafter-stiffeners (list 0.0 wid) ridges H rise ht rd
          (if msApexX T nil)                             ; suppress apex if ridge col
          ;; …and suppress ANY rafter-to-rafter plate that lands on an interior column,
          ;; whether or not that column happens to sit under the apex (rule 4B.52).
          (peb-interior-col-clearances cols (function ms-col-web-at) 400.0))
        ;; Interior MS column connection plates — cigar-aware Y, web-sized.
        (draw-ms-interior-plates cols wid H rise ht rd ep msApexX)
        (if msApexX
          (draw-mg-ridge-col-plates msApexX H rise rd ep))))
    ((member stype '("ACS" "AMS"))
      ;; Arched frames — base plates + column-arch SPRINGING plates + mid-arch SPLICE plates
      ;; every <=12 m (owner 13-Jul).  Handled by draw-arch-conn-plates.
      (cond
        ((= stype "ACS") (draw-base-plates wid cb ep))
        ((= stype "AMS") (draw-base-plates-multi cols cb ep 400.0)))
      (draw-arch-conn-plates stype wid H rise ep cb))
    ((member stype '("BF" "CC"))
      ;; Canopies (owner 13-Jul): NO plates at the free wing tips.  Base plate at the mast/support
      ;; column base + the STANDARD 2-plate rafter-column connection at the mast/support column TOP.
      ;; Owner 14-Jul: canopy connection plates come on the SIDE(S) of the column (where the wing rafter
      ;; attaches), depth-aware (web + 100 beyond flanges) — not a small plate floating at the top centre.
      (if (= stype "CC")
        (progn
          (setq eLp (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_LOW_AT_COLUMN") "")) "YES")
                        H (+ H (/ wid slopeD))))
          (setq ccSlp (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_LOW_AT_COLUMN") "")) "YES")
                          (/ 1.0 slopeD) (/ -1.0 slopeD)))   ; beam top-flange slope at the column (GP follows it)
          (setq dsP (max 450.0 (* (/ wid 12000.0) 1100.0)))
          (draw-base-plate-at 0.0 ht ep (* 25 *PEB-TEXT-SCALE*))   ; base matches the straight column width (ht)
          ;; yTop = the SLOPED top flange at the plate x=ht so the GP stiffener meets the flange (not floating).
          (draw-cant-vplate ht (- eLp dsP) (+ eLp (* ccSlp ht)) 45.0 3 ccSlp))
        (progn
          (setq dpP (bf-mast-depth wid H))                          ; MUST match draw-bf/falcon frame haunch depth
          (setq bfPk  (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES"))
          (setq bfVx  (if bfPk (/ wid 2.0) (peb-bf-valley-x data wid)))   ; valley/column x (markup 15 offset)
          (setq bfBotY (if bfPk (- (+ H rise) dpP) (- H dpP))
                bfTopY (if bfPk (+ H rise) H))
          (draw-base-plate-at (- bfVx 200.0) (+ bfVx 200.0) ep (* 25 *PEB-TEXT-SCALE*))
          ;; owner 18-Jul markup 14: the two wings meet over the column with the SAME connection detail as
          ;; the Multi-Gable valley — 4 vertical end plates flanking the column + bolts + web stiffener.
          (draw-valley-col-plates bfVx (- bfBotY 50.0) (+ bfTopY 50.0)))))
    ((= stype "SS")
      ;; SINGLE SLOPE: (1) a KNEE connection plate at EACH column-rafter junction (on the deep underside
      ;; topY-ht), and (2) a RAFTER SPLICE plate ~3-4 m from EVERY column at the haunch end (deep->thin
      ;; transition, on the thin underside topY-midD) -- owner 14-Jul: the moment/web-depth changes
      ;; sharply there.  Uses ss-taper-params so the splice X = the polygon taper end exactly.
      (setq slopeRiseP (/ wid slopeD))
      (setq ssTPp (ss-taper-params cols wid slopeRiseP ht) midDp (car ssTPp) hLxp (cadr ssTPp))
      (if (> (length cols) 2)
        (draw-base-plates-multi cols cb ep 400.0)     ; SSMS: base plate at every column
        (draw-base-plates       wid cb ep))           ; SSCS: two end columns
      ;; (1) ROTATED knee base plate at each column top — HORIZONTAL, welded to rafter bottom, on the
      ;;     column top (owner 14-Jul). Column top = rafter underside at the column = ss-topY(cx)-ht.
      ;; owner 17-Jul: SINGLE SLOPE knees now use the BUTTERFLY connection detail — TWO SOLID connection
      ;; plates + SOLID gusset plates tying the plates into the web and both flange faces
      ;; (peb-conn-plate-pair), replacing the old thin-line diagonal-gusset knee.  SS-only change; the
      ;; shared gable knee (CS/MS/MG via draw-haunch-plates -> draw-knee-hplate) is untouched.
      ;; Each plate spans the member depth (ht) on the column top: left/right end knees sit inside the
      ;; end column, interior (SSMS) columns straddle their station.
      (setq ssFirst (car cols) ssLast (last cols))
      (foreach cx cols
        (setq ssSeam (- (ss-topY cx H slopeRiseP wid) ht))
        (cond
          ((equal cx ssFirst 1.0) (peb-conn-plate-pair (+ cx (/ ht 2.0)) ssSeam (/ ht 2.0) 30.0 0))
          ((equal cx ssLast  1.0) (peb-conn-plate-pair (- cx (/ ht 2.0)) ssSeam (/ ht 2.0) 30.0 0))
          (T                      (peb-conn-plate-pair cx ssSeam (/ ht 2.0) 30.0 0))))
      ;; (2) splice plates at the haunch ends — sized to the THIN rafter depth (topY-midD .. topY) + 100
      (setq ssNC (length cols) ssK 0)
      (while (< ssK ssNC)
        (setq ssCx (nth ssK cols))
        (cond
          ((= ssK 0)          (setq ssSplXs (list (+ ht hLxp))))
          ((= ssK (1- ssNC))  (setq ssSplXs (list (- (- wid ht) hLxp))))
          (T                  (setq ssSplXs (list (- ssCx hLxp) (+ ssCx hLxp)))))
        (foreach ssSx ssSplXs
          (peb-conn-plate-depth ssSx (- (ss-topY ssSx H slopeRiseP wid) midDp) (ss-topY ssSx H slopeRiseP wid) 40.0 2))
        (setq ssK (1+ ssK))))
    ((= stype "LT")
      ;; LEAN-TO: ONE steel column on the LEFT; the RIGHT end BEARS on the existing RCC/masonry wall.
      ;; (owner 14-Jul) Depth-aware knee plate at the steel column, a 3-4 m rafter splice from the
      ;; LOW-EAVE side (sharp web-depth change per the bending-moment diagram), and a bearing/end
      ;; plate with CHEMICAL ANCHOR BOLTS where the steel rafter lands on the existing wall.
      (setq slopeRise (/ wid slopeD))
      (setq ltMidD (max 300.0 (* ht 0.45)))
      (setq ltHL   (max 3000.0 (min 4000.0 (car (cigar-taper-lengths wid)))))
      (draw-base-plate-at 0.0 cb ep (* 25 *PEB-TEXT-SCALE*))
      ;; ROTATED knee (owner 14-Jul): HORIZONTAL base plate on the LEFT steel column top, welded to the
      ;; rafter bottom (seam at H-ht), spanning the column depth (ht) inward.
      (draw-knee-hplate 0.0 ht (- H ht) 45.0 4 nil -1)   ; LT left steel column — outer = left
      ;; ONE rafter SPLICE at mid-span (owner 15-Jul): TWO solid plates (40 thick, 1mm hairline gap, no bolts)
      ;; spanning the web + 100 beyond BOTH flanges, with a stiffener gusset (100x100) on BOTH sides AT the
      ;; TOP and BOTTOM flange (the gussets sit inside the 100 extension, NOT sticking out past the plate).
      (setq ltMidX (/ wid 2.0))
      (setq ltTopY (+ H (* slopeRise 0.5)))                    ; top flange at mid-span
      (setq ltUndY (- ltTopY ltMidD))                          ; bottom flange at mid-span
      (peb-conn-plate-depth ltMidX ltUndY ltTopY 40.0 2)       ; 2 solid plates, 100 beyond flanges, no bolts
      (draw-stiff-top (- ltMidX 40.0) ltTopY 100.0 100.0 -1)   ; top-left gusset  (flange -> plate edge)
      (draw-stiff-top (+ ltMidX 40.0) ltTopY 100.0 100.0  1)   ; top-right gusset
      (draw-stiff-bot (- ltMidX 40.0) ltUndY 100.0 100.0 -1)   ; bottom-left gusset
      (draw-stiff-bot (+ ltMidX 40.0) ltUndY 100.0 100.0  1)   ; bottom-right gusset
      ;; Bearing / end plate at the existing wall (right) + CHEMICAL ANCHOR BOLTS into the masonry
      (setvar "CLAYER" "PLATES")
      (setq ltWtop (+ H slopeRise))
      (setq ltWbot (- (+ H slopeRise) ht))
      (command "RECTANG" (list (- wid 45.0) (- ltWbot 100.0)) (list wid (+ ltWtop 100.0)))
      (setq ltI 1)
      (while (<= ltI 3)
        (setq ltBy (+ (- ltWbot 100.0) (* (/ (float ltI) 4.0) (- (+ ltWtop 100.0) (- ltWbot 100.0)))))
        (command "LINE" (list wid ltBy) (list (+ wid 170.0) ltBy) "")
        (command "DONUT" 0 (* 30 *PEB-TEXT-SCALE*) (list (+ wid 150.0) ltBy) "")
        (setq ltI (1+ ltI)))
      (setvar "CLAYER" "TEXT")
      (peb-label-pline-leader "CHEMICAL ANCHOR BOLTS"
                             (list (+ wid 2700.0) (+ ltWbot (* ht 0.35)))
                             (list (+ wid 160.0)  (+ ltWbot (* ht 0.35)))
                             "H" 220))
    ((= stype "FR")
      ;; FLAT ROOF: base plate at each STRAIGHT column + a beam-on-column CONNECTION PLATE (30mm) with
      ;; STIFFENERS at the column top (frCT = column top = main-beam bottom bearing).
      (setq frCT (fr-col-top H ht))
      (draw-base-plate-at 0.0 ht ep (* 25 *PEB-TEXT-SCALE*))
      (draw-base-plate-at (- wid ht) wid ep (* 25 *PEB-TEXT-SCALE*))
      (setvar "CLAYER" "PLATES")
      ;; LEFT column: cap plate + stiffener on the INNER face (x = ht) only.
      (peb-solid-quad (list 0.0 (- frCT 30.0)) (list ht (- frCT 30.0))
                      (list 0.0 frCT) (list ht frCT))
      (draw-stiff-bot ht (- frCT 30.0) 100.0 130.0 -1)          ; inner gusset (into the column)
      ;; RIGHT column: cap plate + stiffener on the INNER face (x = wid-ht) only.
      (peb-solid-quad (list (- wid ht) (- frCT 30.0)) (list wid (- frCT 30.0))
                      (list (- wid ht) frCT) (list wid frCT))
      (draw-stiff-bot (- wid ht) (- frCT 30.0) 100.0 130.0 1))  ; inner gusset (into the column)
    ((= stype "F2")
      ;; MULTI-STOREY FLAT ROOF: base plate at EACH column + the TWO-PLATE connection (owner 16-Jul: 2 plates,
      ;; each 30mm, extending 100mm beyond the column web both sides — drawn thicker for visibility) at EVERY
      ;; column-beam junction: the top flat roof AND every intermediate/mezzanine floor beam.
      (setq frCT  (- H 720.0)
            f2ixs (vl-remove-if-not
                    (function (lambda (xc) (and (> xc (* ht 1.5)) (< xc (- wid (* ht 1.5))))))
                    (f2-int-col-xs data wid)))
      ;; base plates
      (draw-base-plate-at 0.0 ht ep (* 25 *PEB-TEXT-SCALE*))
      (draw-base-plate-at (- wid ht) wid ep (* 25 *PEB-TEXT-SCALE*))
      (foreach xc f2ixs
        (draw-base-plate-at (- xc (/ ht 2.0)) (+ xc (/ ht 2.0)) ep (* 25 *PEB-TEXT-SCALE*)))
      ;; VERTICAL connection plates at every column, at every beam level (each mezzanine floor + the roof).
      ;; Beam depth = 700 at the mezzanine floors, 550 at the roof.  Edge columns get a plate on the INNER
      ;; face only (beam on one side); interior columns get a plate on BOTH faces.
      (foreach by (append (f2-mezz-levels data) (list frCT))
        (setq bd (if (equal by frCT 1.0) 550.0 700.0))
        (draw-f2-connplate 0.0 ht by bd T nil)                 ; left edge  → beam on the RIGHT only
        (draw-f2-connplate (- wid ht) wid by bd nil T)         ; right edge → beam on the LEFT only
        (foreach xc f2ixs
          (draw-f2-connplate (- xc (/ ht 2.0)) (+ xc (/ ht 2.0)) by bd nil nil))))
    ((= stype "RC")
      ;; ROOF ON RCC COLUMNS (owner 15-Jul): NO steel base plates at the FFL (the columns ARE concrete).
      ;; Support = a thick base plate ON each column top (column width only) with anchor bolts — PINNED on the
      ;; LEFT, ROLLER (slotted) on the RIGHT so the roof can expand.  Rafter web splice/ridge plates as usual.
      (setq rcDe (max 200.0 (* ht 0.35))
            rcIn (if (and *PEB-RC-INSET* (> *PEB-RC-INSET* 0.0)) *PEB-RC-PARAW* 0.0))
      ;; base plate caps the column top INBOARD of the parapet slice (parapet face -> inner column face), so it
      ;; carries the rafter eave + valley gutter without clashing with the concrete parapet extension.
      (draw-rc-support rcIn 500.0 (- H rcDe) nil)               ; LEFT column → PINNED
      (draw-rc-support (- wid 500.0) (- wid rcIn) (- H rcDe) T) ; RIGHT column → ROLLER
      (draw-rc-ridge wid H rise ht)                            ; ridge plate (extends beyond both flanges)
      (draw-rc-splices wid H rise ht))                         ; rafter splice plates every <=12m (transport limit)
    (T
      (progn
        (draw-base-plates   wid cb ep)
        ;; CS = steel (two-plate knee).
        (draw-haunch-plates cols H ht ep nil nil nil)
        (if (= stype "CS")
          (draw-rafter-stiffeners cols ridges H rise ht rd nil
            (peb-interior-col-clearances cols nil 400.0))))))

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
        ;; G2 (owner 19-Jul): Ø100 DOTTED valley DOWN PIPE — two PEBPIPE lines down the gable-boundary column,
        ;; from the trough bottom (vY0+10) to FFL (100 mm apart = pipe dia); a valley must show a drain pipe.
        (peb-pipe-line (- cx 50.0) (+ vY0 10.0) (- cx 50.0) 0.0)
        (peb-pipe-line (+ cx 50.0) (+ vY0 10.0) (+ cx 50.0) 0.0)
        ;; Label + M-Ladder DOWN-ARROW to the valley trough (owner 14-Jul).  Explicit shaft + SOLID
        ;; arrowhead so the arrow always renders (the native MLEADER tip does not plot).
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list cx (+ vY0 200.0 (* 1500 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "VALLEY GUTTER")
        (setvar "CLAYER" "ARROWS")
        (command "LINE" (list cx (+ vY0 200.0 (* 1150 *PEB-TEXT-SCALE*)))
                        (list cx (+ vY0 200.0 (* 400  *PEB-TEXT-SCALE*))) "")
        (peb-solid-quad (list (- cx (* 130 *PEB-TEXT-SCALE*)) (+ vY0 200.0 (* 400 *PEB-TEXT-SCALE*)))
                        (list (+ cx (* 130 *PEB-TEXT-SCALE*)) (+ vY0 200.0 (* 400 *PEB-TEXT-SCALE*)))
                        (list cx (+ vY0 200.0)) (list cx (+ vY0 200.0)))   ; down-arrow head (SOLID)
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
    ;; existing RCC building: no steel cladding / purlins / girts / eave / rafter — RCC walls & roof
    ;; are existing (by others).  Skip the whole steel wall/roof-element block (owner 8-Jul).
    ((peb-mz-rcc-sec-p data) nil)
    ;; ── BF (Butterfly): center column only, no walls ──
    ;; Add COLUMN label pointing at center column inner flange.
    ((= stype "BF")
      ;; owner 18-Jul markup 20: label the CENTRE column at its ACTUAL valley position (bfVx, not wid/2), with
      ;; the text on the TAIL (short-leg) side and the leader pointing straight AT the column (no overshoot).
      (setq bfVx (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES")
                   (/ wid 2.0) (peb-bf-valley-x data wid)))   ; T1.1: label the valley column at its ACTUAL station (BP_CANT_SPAN), matching the geometry — was peb-ridge-x (BP_RIDGE_OFFSET), the wrong source
      (if (< bfVx (/ wid 2.0))
        (peb-label-pline-leader "COLUMN"                       ; short leg on the LEFT => label on the LEFT
                               (list (- bfVx 3000.0) (- H ht 700.0))
                               (list (- bfVx 200.0)  (- H ht 700.0)) "H" 220)
        (peb-label-pline-leader "COLUMN"                       ; short leg on the RIGHT => label on the RIGHT
                               (list (+ bfVx 3000.0) (- H ht 700.0))
                               (list (+ bfVx 200.0)  (- H ht 700.0)) "H" 220))
      (if (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_FALCON_PEAK") "")) "YES")
        ;; ── FALCON finishing (owner 14-Jul): centre PEAK, wings slope DOWN-OUTWARD to the free
        ;;    tips.  NO valley gutter (Falcon drains at the TIPS, not the centre); FALL points
        ;;    OUTWARD; purlins + sheeting follow the wing slopes; no brick masonry (open canopy). ──
        (progn
          (setq bfcx (/ wid 2.0))
          (setq bfm  (/ rise bfcx))                 ; wing rise per run (high at peak, low at tips)
          (setvar "CLAYER" "CLADDING")
          ;; owner 18-Jul: sheet ENDS AT THE RAFTER LINE (low tips x=0 / x=wid) — NO overhang past the rafter.
          ;; LEFT wing deck (2 lines): centre PEAK (bfcx) down-out to the LEFT low tip (rafter line, x=0).
          (command "LINE" (list bfcx (+ H rise 200.0)) (list 0.0 (+ H 200.0)) "")
          (command "LINE" (list bfcx (+ H rise 235.0)) (list 0.0 (+ H 235.0)) "")
          ;; RIGHT wing deck (2 lines): centre PEAK down-out to the RIGHT low tip (rafter line, x=wid).
          (command "LINE" (list bfcx (+ H rise 200.0)) (list wid (+ H 200.0)) "")
          (command "LINE" (list bfcx (+ H rise 235.0)) (list wid (+ H 235.0)) "")
          ;; EAVE TRIM wraps the sheet+purlin edge AT the rafter line (no overhang): top leg IN over the sheet,
          ;; fold DOWN at the tip, bottom leg back IN under the purlin (owner 18-Jul markup 18/edge).
          (setvar "CLAYER" "CLADDING")
          (setvar "PLINEWID" 0.0)
          (command "PLINE"
            (list  30.0 (+ (+ H 235.0) 40.0))
            (list   0.0 (+ (+ H 235.0) 40.0))
            (list   0.0 (- H 40.0))
            (list  30.0 (- H 40.0))
            "")
          (command "PLINE"
            (list (- wid 30.0) (+ (+ H 235.0) 40.0))
            (list wid (+ (+ H 235.0) 40.0))
            (list wid (- H 40.0))
            (list (- wid 30.0) (- H 40.0))
            "")
          ;; FALL callouts on each wing (drain OUTWARD toward the tips)
          (txt "MC" (list (* wid 0.22) (+ H (* rise 0.62) 700.0)) (peb-th 'SMALL) 0 "FALL")
          (txt "MC" (list (* wid 0.78) (+ H (* rise 0.62) 700.0)) (peb-th 'SMALL) 0 "FALL")
          ;; TWO slope tags — left wing rises up-RIGHT to the peak (+1), right wing up-LEFT (-1)
          (draw-slope-tag (* bfcx 0.5) (+ H (* rise 0.5) 235.0 (* 300 *PEB-TEXT-SCALE*)) slopeD  1)
          (draw-slope-tag (* bfcx 1.5) (+ H (* rise 0.5) 235.0 (* 300 *PEB-TEXT-SCALE*)) slopeD -1)
          ;; Purlins on both wings follow the slopes + a purlin at EACH low tip edge (owner 18-Jul).
          (peb-deck-purlins 0.0 (+ H 200.0) bfcx (+ H rise 200.0))
          (peb-deck-purlins bfcx (+ H rise 200.0) wid (+ H 200.0))
          (peb-z-purlin-at 150.0 (+ (+ H 200.0) (* bfm 150.0))
                           (/ 1.0 (sqrt (+ 1.0 (* bfm bfm)))) (/ bfm (sqrt (+ 1.0 (* bfm bfm)))))
          (peb-z-purlin-at (- wid 150.0) (+ (+ H 200.0) (* bfm 150.0))
                           (/ 1.0 (sqrt (+ 1.0 (* bfm bfm)))) (/ (- 0 bfm) (sqrt (+ 1.0 (* bfm bfm)))))
          (peb-canopy-roof-label data (* wid 0.72) (+ H (* rise 0.56) 200.0)
                                 (+ H rise (* 2600 *PEB-TEXT-SCALE*))))
        ;; ── BUTTERFLY finishing: deck on both wings + central VALLEY GUTTER + DOWN SPOUT + FALL ──
        ;; Reference (Nestle Butterfly Canopy): wings drain INWARD to a centre valley gutter & downspout.
        (progn
          (setq bfcx (peb-bf-valley-x data wid))       ; VALLEY position (markup 15 offset; default centre)
          (setq bfm  (/ rise (/ wid 2.0)))             ; fall slope (rise per run) — SAME on both wings
          (setq bfLR (* bfm bfcx))                     ; LEFT wing rise (tip height above the valley)
          (setq bfRR (* bfm (- wid bfcx)))             ; RIGHT wing rise (longer wing => higher tip)
          (setq bfBrkY (+ H 200.0 (* bfm 265.0)))      ; deck Y where the sheet ends 75mm INTO the gutter
          (setvar "CLAYER" "CLADDING")
          ;; owner 18-Jul: the sheet ENDS AT THE RAFTER LINE (tip x=0 / x=wid) — NO overhang past the rafter.
          ;; LEFT wing deck (2 lines): rafter tip down toward the valley, ending 75mm inside the gutter lip.
          (command "LINE" (list 0.0 (+ H bfLR 200.0)) (list (- bfcx 265.0) bfBrkY) "")
          (command "LINE" (list 0.0 (+ H bfLR 235.0)) (list (- bfcx 265.0) (+ bfBrkY 35.0)) "")
          (command "LINE" (list (- bfcx 265.0) bfBrkY) (list (- bfcx 265.0) (+ bfBrkY 35.0)) "")   ; sheet end-cap
          ;; RIGHT wing deck (2 lines): mirror
          (command "LINE" (list (+ bfcx 265.0) bfBrkY) (list wid (+ H bfRR 200.0)) "")
          (command "LINE" (list (+ bfcx 265.0) (+ bfBrkY 35.0)) (list wid (+ H bfRR 235.0)) "")
          (command "LINE" (list (+ bfcx 265.0) bfBrkY) (list (+ bfcx 265.0) (+ bfBrkY 35.0)) "")   ; sheet end-cap
          ;; EAVE TRIM wraps the sheet+purlin edge AT the rafter line (no overhang): top leg IN over the sheet,
          ;; fold DOWN at the tip (x=0 / x=wid), bottom leg back IN under the purlin (owner 18-Jul markup 18/edge).
          (command "PLINE"
            (list  30.0 (+ (+ H bfLR 235.0) 40.0))
            (list   0.0 (+ (+ H bfLR 235.0) 40.0))
            (list   0.0 (- (+ H bfLR) 40.0))
            (list  30.0 (- (+ H bfLR) 40.0))
            "")
          (command "PLINE"
            (list (- wid 30.0) (+ (+ H bfRR 235.0) 40.0))
            (list wid (+ (+ H bfRR 235.0) 40.0))
            (list wid (- (+ H bfRR) 40.0))
            (list (- wid 30.0) (- (+ H bfRR) 40.0))
            "")
          ;; VALLEY GUTTER — tapered trapezoidal trough (owner markup 17) centred on the valley (bfcx).
          (setvar "CLAYER" "GUTTER")
          (setvar "PLINEWID" 0.0)
          (command "PLINE"
            (list (- bfcx 390.0) bfBrkY)                ; left lip — folded OUT
            (list (- bfcx 330.0) bfBrkY)                ; left top inner corner (mouth)
            (list (- bfcx 140.0) (+ H 40.0))            ; TAPERED left wall down to the trough
            (list (+ bfcx 140.0) (+ H 40.0))            ; flat trough bottom
            (list (+ bfcx 330.0) bfBrkY)                ; TAPERED right wall up to the right mouth
            (list (+ bfcx 390.0) bfBrkY)                ; right lip — folded OUT
            "")
          (setvar "CLAYER" "TEXT")
          (txt "MC" (list bfcx (+ H (max bfLR bfRR) (* 900 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "VALLEY GUTTER")
          ;; M-Ladder DOWN-ARROW to the valley gutter: shaft + SOLID head.
          (setvar "CLAYER" "ARROWS")
          (setvar "PLINEWID" 0.0)
          (command "LINE" (list bfcx (+ H (max bfLR bfRR) (* 550 *PEB-TEXT-SCALE*)))
                          (list bfcx (+ bfBrkY 230.0)) "")
          (peb-solid-quad (list (- bfcx (* 130 *PEB-TEXT-SCALE*)) (+ bfBrkY 230.0))
                          (list (+ bfcx (* 130 *PEB-TEXT-SCALE*)) (+ bfBrkY 230.0))
                          (list bfcx (+ bfBrkY 30.0)) (list bfcx (+ bfBrkY 30.0)))
          ;; owner 18-Jul markup 20: the Ø100 DOWN PIPE — 2 dotted lines down the MIDDLE of the column, from
          ;; the valley gutter trough down to FFL (100 mm apart = pipe dia).  Define a mm-based DOTTED linetype
          ;; (dot every 120 mm) once, then draw each LINE with a per-entity scale 1/LTSCALE so the dots render
          ;; at TRUE mm size (same technique as peb-ridge-line; the huge global LTSCALE would otherwise stretch
          ;; the pattern past the line and it renders solid — a plain "DOT" linetype isn't loaded here).
          (if (not (tblsearch "LTYPE" "PEBPIPE"))
            (vl-catch-all-apply (function (lambda ()
              (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                             '(100 . "AcDbLinetypeTableRecord") '(2 . "PEBPIPE") '(70 . 0)
                             '(3 . "Pipe __ __ __") '(72 . 65) '(73 . 2) '(40 . 150.0)
                             '(49 . 60.0) '(74 . 0) '(49 . -90.0) '(74 . 0)))))))
          (setq bfEs (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
          ;; 0.30 mm (DXF 370 = 30) — owner's chosen weight for the down pipe dashed line.
          (if (tblsearch "LTYPE" "PEBPIPE")
            (progn
              (entmake (list '(0 . "LINE") (cons 8 "GUTTER") '(6 . "PEBPIPE") (cons 48 bfEs) (cons 370 30)
                             (cons 10 (list (- bfcx 50.0) (+ H 40.0) 0.0)) (cons 11 (list (- bfcx 50.0) 0.0 0.0))))
              (entmake (list '(0 . "LINE") (cons 8 "GUTTER") '(6 . "PEBPIPE") (cons 48 bfEs) (cons 370 30)
                             (cons 10 (list (+ bfcx 50.0) (+ H 40.0) 0.0)) (cons 11 (list (+ bfcx 50.0) 0.0 0.0)))))
            (progn
              (setvar "CLAYER" "GUTTER")
              (command "LINE" (list (- bfcx 50.0) (+ H 40.0)) (list (- bfcx 50.0) 0.0) "")
              (command "LINE" (list (+ bfcx 50.0) (+ H 40.0)) (list (+ bfcx 50.0) 0.0) "")))
          ;; DOWN SPOUT label pointing at the down pipe
          (peb-label-with-leader "DOWN SPOUT"
                                 (list (+ bfcx 2300.0) (* H 0.45))
                                 (list (+ bfcx 60.0)   (* H 0.45))
                                 "H" 220)
          ;; FALL callouts on each wing (drain toward the valley), at each wing's mid-run + own height
          (txt "MC" (list (* bfcx 0.45) (+ H (* bfLR 0.55) 700.0)) (peb-th 'SMALL) 0 "FALL")
          (txt "MC" (list (+ bfcx (* (- wid bfcx) 0.55)) (+ H (* bfRR 0.55) 700.0)) (peb-th 'SMALL) 0 "FALL")
          ;; TWO slope tags — left wing rises up-LEFT (upRight=-1), right wing up-RIGHT (upRight=+1)
          (draw-slope-tag (* bfcx 0.5) (+ H (* bfLR 0.5) 235.0 (* 300 *PEB-TEXT-SCALE*)) slopeD -1)
          (draw-slope-tag (/ (+ bfcx wid) 2.0) (+ H (* bfRR 0.5) 235.0 (* 300 *PEB-TEXT-SCALE*)) slopeD  1)
          ;; Purlins on both wings + ROOF SHEETING callout (per-wing rise)
          (peb-deck-purlins 0.0 (+ H bfLR 200.0) bfcx (+ H 200.0))
          (peb-deck-purlins bfcx (+ H 200.0) wid (+ H bfRR 200.0))
          ;; owner 18-Jul markup 16: a purlin EACH SIDE of the valley (up-slope of the gutter lip).
          (peb-z-purlin-at (- bfcx 470.0) (+ bfBrkY (* bfm 205.0))
                           (/  1.0 (sqrt (+ 1.0 (* bfm bfm)))) (/ (- 0 bfm) (sqrt (+ 1.0 (* bfm bfm)))))
          (peb-z-purlin-at (+ bfcx 470.0) (+ bfBrkY (* bfm 205.0))
                           (/ -1.0 (sqrt (+ 1.0 (* bfm bfm)))) (/ (- 0 bfm) (sqrt (+ 1.0 (* bfm bfm)))))
          ;; owner 18-Jul markup: a purlin at EACH wing EDGE (at the rafter tip, just inside) — the deck-purlin
          ;; run starts 1500mm in, leaving the edge bare, and the eave trim needs an edge purlin to wrap under.
          (peb-z-purlin-at 150.0 (- (+ H bfLR 200.0) (* bfm 150.0))
                           (/  1.0 (sqrt (+ 1.0 (* bfm bfm)))) (/ (- 0 bfm) (sqrt (+ 1.0 (* bfm bfm)))))
          (peb-z-purlin-at (- wid 150.0) (- (+ H bfRR 200.0) (* bfm 150.0))
                           (/ -1.0 (sqrt (+ 1.0 (* bfm bfm)))) (/ (- 0 bfm) (sqrt (+ 1.0 (* bfm bfm)))))
          (peb-canopy-roof-label data (+ bfcx (* (- wid bfcx) 0.44)) (+ H (* bfRR 0.44) 200.0)
                                 (+ H bfRR (* 2600 *PEB-TEXT-SCALE*))))))
    ;; ── CC (Cantilever Canopy): one back column, open front ──
    ;; Add COLUMN label pointing at the back (left) column inner flange.
    ((= stype "CC")
      (peb-label-pline-leader "COLUMN"
                             (list (max 1800.0 (+ ht 800.0))
                                   (- H ht 700.0))
                             (list 250.0 (- H ht 700.0))      ; arrow at left col inner flange
                             "H"
                             220)
      ;; ── Cantilever-canopy finishing: roof deck + tip fascia + fall + ONE slope tag + downspout ──
      ;; TM p42 (canopy = cantilever below/at eave, one-end support) + reference LOADING DECK/FALL.
      (setq ccLow  (= (strcase (peb-tb-or (MSPL-Get-Str data "CC_LOW_AT_COLUMN") "")) "YES"))
      (setq ccRise (/ wid slopeD))
      (setq ccEL   (if ccLow H (+ H ccRise)))     ; column-side eave
      (setq ccER   (if ccLow (+ H ccRise) H))     ; free-tip eave
      (setq ccS    (/ (- ccER ccEL) wid))         ; deck slope (rise per run)
      ;; roof deck: two parallel lines 200 above the rafter top.  owner 18-Jul: sheet ENDS AT THE RAFTER LINE
      ;; both ends (back column x=0, free tip x=wid) — NO overhang past the rafter.
      (setvar "CLAYER" "CLADDING")
      (command "LINE" (list 0.0 (+ ccEL 200.0)) (list wid (+ ccER 200.0)) "")
      (command "LINE" (list 0.0 (+ ccEL 235.0)) (list wid (+ ccER 235.0)) "")
      ;; owner 18-Jul: NO fascia — the HIGH eave gets the wrapping EAVE TRIM (butterfly-style); the LOW
      ;; (draining) eave gets a GUTTER + DOWN PIPE instead (below).
      (if (not ccLow)   ; left / column eave is HIGH
        (command "PLINE"
          (list  30.0 (+ (+ ccEL 235.0) 40.0))
          (list   0.0 (+ (+ ccEL 235.0) 40.0))
          (list   0.0 (- ccEL 40.0))
          (list  30.0 (- ccEL 40.0))
          ""))
      (if ccLow         ; right / free eave is HIGH
        (command "PLINE"
          (list (- wid 30.0) (+ (+ ccER 235.0) 40.0))
          (list wid (+ (+ ccER 235.0) 40.0))
          (list wid (- ccER 40.0))
          (list (- wid 30.0) (- ccER 40.0))
          ""))
      ;; a purlin at EACH edge (back column tip + free tip), just inside the rafter line (owner 18-Jul).
      (peb-z-purlin-at 150.0 (+ ccEL 200.0 (* ccS 150.0))
                       (/ 1.0 (sqrt (+ 1.0 (* ccS ccS)))) (/ ccS (sqrt (+ 1.0 (* ccS ccS)))))
      (peb-z-purlin-at (- wid 150.0) (+ ccEL 200.0 (* ccS (- wid 150.0)))
                       (/ 1.0 (sqrt (+ 1.0 (* ccS ccS)))) (/ ccS (sqrt (+ 1.0 (* ccS ccS)))))
      ;; ONE slope tag on the single rafter — direction follows which side is LOW
      (setq ccTagX (* wid 0.45))
      (draw-slope-tag ccTagX (+ ccEL (* ccS ccTagX) 235.0 (* 300 *PEB-TEXT-SCALE*))
                      slopeD (if ccLow 1 -1))
      ;; FALL callout at mid-deck
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (* wid 0.62) (+ ccEL (* ccS (* wid 0.62)) 900.0)) (peb-th 'SMALL) 0 "FALL")
      ;; owner 18-Jul: EAVE GUTTER at the LOW (draining) eave + Ø100 dotted DOWN PIPE down the column to FFL.
      (setq ccLowY (if ccLow ccEL ccER) ccDir (if ccLow -1.0 1.0) ccLowX (if ccLow 0.0 wid))
      ;; G1 (owner 19-Jul, UNIVERSAL): a gutter belongs ONLY on a drained/SUPPORTED edge — the column eave.
      ;; When the canopy drains at the FREE/OPEN cantilever TIP (ccLow = nil) draw NO gutter and NO "GUTTER"
      ;; text there (the open edge just drips).  So the gutter trough + label are gated on ccLow.
      (if ccLow
        (progn
          (setvar "CLAYER" "GUTTER") (setvar "PLINEWID" 0.0)
          (command "PLINE"
            (list ccLowX (+ ccLowY 235.0))
            (list (+ ccLowX (* ccDir 60.0)) (+ ccLowY 235.0))         ; outer top lip
            (list (+ ccLowX (* ccDir 60.0)) (+ ccLowY 20.0))          ; down the outer wall
            (list (+ ccLowX (* ccDir 230.0)) (+ ccLowY 20.0))         ; trough bottom
            (list (+ ccLowX (* ccDir 270.0)) (+ ccLowY 235.0))        ; up the inner lip (at the sheet)
            "")
          (setvar "CLAYER" "TEXT")
          (txt "MC" (list (+ ccLowX (* ccDir 900.0)) (+ ccLowY 950.0)) (peb-th 'SMALL) 0 "GUTTER")))
      ;; DOWN PIPE (dotted, thin) down the column + DOWN SPOUT label — only when draining at the (back) column.
      (if ccLow
        (progn
          (if (not (tblsearch "LTYPE" "PEBPIPE"))
            (vl-catch-all-apply (function (lambda ()
              (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                             '(100 . "AcDbLinetypeTableRecord") '(2 . "PEBPIPE") '(70 . 0)
                             '(3 . "Pipe __ __ __") '(72 . 65) '(73 . 2) '(40 . 150.0)
                             '(49 . 60.0) '(74 . 0) '(49 . -90.0) '(74 . 0)))))))
          (setq ccEs (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0)
                gcx  (+ ccLowX (* ccDir 145.0)))                    ; gutter outlet centre
          (if (tblsearch "LTYPE" "PEBPIPE")
            (progn
              ;; ELBOW / BEND: connect the gutter outlet DOWN-and-IN to the vertical down pipe (owner 18-Jul).
              (entmake (list '(0 . "LINE") (cons 8 "GUTTER") '(6 . "PEBPIPE") (cons 48 ccEs) (cons 370 30)
                             (cons 10 (list (- gcx 50.0) (+ ccLowY 20.0) 0.0)) (cons 11 (list 60.0  (- ccLowY 120.0) 0.0))))
              (entmake (list '(0 . "LINE") (cons 8 "GUTTER") '(6 . "PEBPIPE") (cons 48 ccEs) (cons 370 30)
                             (cons 10 (list (+ gcx 50.0) (+ ccLowY 20.0) 0.0)) (cons 11 (list 160.0 (- ccLowY 120.0) 0.0))))
              ;; vertical DOWN PIPE
              (entmake (list '(0 . "LINE") (cons 8 "GUTTER") '(6 . "PEBPIPE") (cons 48 ccEs) (cons 370 30)
                             (cons 10 (list 60.0  (- ccLowY 120.0) 0.0)) (cons 11 (list 60.0  0.0 0.0))))
              (entmake (list '(0 . "LINE") (cons 8 "GUTTER") '(6 . "PEBPIPE") (cons 48 ccEs) (cons 370 30)
                             (cons 10 (list 160.0 (- ccLowY 120.0) 0.0)) (cons 11 (list 160.0 0.0 0.0))))))
          (peb-label-with-leader "DOWN SPOUT"
                                 (list -2100.0 (* H 0.5))
                                 (list 60.0    (* H 0.5))
                                 "H" 220)))
      ;; Purlins along the wing + ROOF SHEETING callout (like Clear Span)
      (peb-deck-purlins 0.0 (+ ccEL 200.0) wid (+ ccER 200.0))
      ;; raise the ROOFING SYSTEM label CLEAR above the HIGH eave (owner 17-Jul: was colliding with
      ;; the FALL tag / slope) — same generous top band the Butterfly/Falcon peaks get.
      (peb-canopy-roof-label data (* wid 0.72) (+ ccEL (* ccS (* wid 0.72)) 200.0)
                             (+ (max ccEL ccER) 200.0 (* 2600 *PEB-TEXT-SCALE*))))
    ;; ── LT (Lean-To): one PEB column on left, masonry wall on right ──
    ;; LT has a sloped roof (single slope from low eave to wall top), so
    ;; it gets the full set of labels: COLUMN (left), GIRTS, DOWN PIPE
    ;; on the wall side, ROOF SHEETING along the slope, and slope tag.
    ((= stype "LT")
      ;; LEAN-TO: PEB column + sloped roof on the LEFT (low eave), bearing on the
      ;; existing RCC/masonry wall on the RIGHT (high eave).  Route through the SAME
      ;; standard routines as the gable/single-slope frames so the sheeting, purlins,
      ;; roof/wall/girt/downpipe/column M-Ladders READ IDENTICALLY — with the right
      ;; (existing-wall) side suppressed (no PEB wall sheeting / girts / gutter).
      (setq monoRise (/ wid slopeD))               ; = draw-lt-frame's slopeRise
      ;; Brick wall on the LEFT (PEB column) side only; right side is the existing wall.
      (if (and brickH (> brickH 0))
        (progn
          (setvar "CLAYER" "BRICK-WALL")
          (command "RECTANG" (list (- 0.0 200.0) 0.0) (list 0.0 brickH))
          (command "HATCH" "BRICK" 150 0 "L" "")))
      ;; trailing nil = throatWin (see the SS branch): eight arguments silently
      ;; aborted the whole section.  A lean-to carries no roof monitor either.
      (draw-cladding      data wid H rise brickH monoRise nil T nil)  ; mono roof (tucks to wall) + LEFT wall sheeting + roof/wall M-Ladders; skip right wall
      (draw-purlins-mono  wid H monoRise)                         ; standard mono purlins (match CS/SS)
      (draw-girts         wid H brickH nil T)                     ; LEFT girts only + GIRT M-Ladder
      (draw-downpipes     wid H brickH T)                         ; LOW-side downpipe + DOWN PIPE + COLUMN M-Ladders
      (draw-eave-features wid H T (/ monoRise wid))               ; LOW-side eave gutter (lip anchored to sheet)
      (draw-rafter-label  wid H monoRise ht)
      ;; EXISTING WALL callout (right) — text RIGHT-justified so it sits to the LEFT of its own rightward
      ;; leader (no text/leader overlap); clean horizontal arrowhead at the wall face, no tail dot.
      (setq ltEwY (- H ht 700.0))
      (peb-label-no-leader "EXISTING WALL" (list (- wid 2500.0) ltEwY) (peb-th 'SMALL) 0 "MR")
      (setvar "CLAYER" "ARROWS")
      (draw-l-leader (- wid 2500.0) ltEwY wid ltEwY "H"))
    ((member stype '("ACS" "AMS"))
      ;; Arched frames — brick walls + girts + downpipes + eave features apply normally (column locations).
      ;; Roof cladding + Z-purlins follow the CURVED rafter; wall sheeting added here (arches bypass draw-cladding).
      (draw-brick-wall    wid brickH)
      (draw-girts         wid H brickH nil nil)
      (peb-arch-wall-sheeting wid H brickH)      ; owner 16-Jul: wall sheeting lines OUTSIDE girts, brick->eave/gutter
      (draw-downpipes     wid H brickH nil)
      ;; trailing nil = slope.  draw-eave-features takes FOUR arguments; three
      ;; silently aborted the arched-frame branch the same way.  nil is what the
      ;; call already meant: "no slope given" -> the legacy flat H+200 gutter lip.
      (draw-eave-features wid H nil nil)
      ;; ── Curved roof cladding: arcs offset 200/235 above the rafter (2 lines = sheet thickness) ──
      ;; Same 3-point arcs as the frame's rafter (draw-acs-frame / draw-ams-frame).  Z-purlins ride the
      ;; RAFTER OUTER arc (H..H+rise) so their 200 mm web sits in the gap BELOW the sheeting (owner 16-Jul).
      (setvar "CLAYER" "CLADDING")
      (if (= stype "ACS")
        (progn
          (command "ARC" (list 0.0 (+ H 200.0)) (list (/ wid 2.0) (+ H rise 200.0)) (list wid (+ H 200.0)))
          (command "ARC" (list 0.0 (+ H 235.0)) (list (/ wid 2.0) (+ H rise 235.0)) (list wid (+ H 235.0)))
          (draw-purlins-arc 0.0 H (/ wid 2.0) (+ H rise) wid H))
        (progn                                   ; AMS: two arches meeting at the centre peak
          (setq amHalf (/ wid 2.0) amQ1 (/ wid 4.0) amQ3 (* wid 0.75) amPk (+ H (* rise 0.72)))
          (command "ARC" (list 0.0 (+ H 200.0)) (list amQ1 (+ amPk 200.0)) (list amHalf (+ H rise 200.0)))
          (command "ARC" (list 0.0 (+ H 235.0)) (list amQ1 (+ amPk 235.0)) (list amHalf (+ H rise 235.0)))
          (command "ARC" (list amHalf (+ H rise 200.0)) (list amQ3 (+ amPk 200.0)) (list wid (+ H 200.0)))
          (command "ARC" (list amHalf (+ H rise 235.0)) (list amQ3 (+ amPk 235.0)) (list wid (+ H 235.0)))
          (draw-purlins-arc 0.0 H amQ1 amPk amHalf (+ H rise))
          (draw-purlins-arc amHalf (+ H rise) amQ3 amPk wid H)))
      ;; ROOF SHEETING rides OVER the gutter INNER wall (at -200 / W+200, top H+200) then DROPS INTO the
      ;; trough — the sheeting ends INSIDE the gutter and the gutter inner sheeting line sits BELOW it
      ;; (owner 16-Jul markup 19).  3-point path: eave -> up over the inner lip -> down into the trough.
      (setvar "CLAYER" "CLADDING") (setvar "PLINEWID" 0.0)
      (command "PLINE" (list 0.0 (+ H 200.0)) (list -205.0 (+ H 212.0)) (list -330.0 (+ H 110.0)) "")
      (command "PLINE" (list 0.0 (+ H 235.0)) (list -205.0 (+ H 247.0)) (list -330.0 (+ H 145.0)) "")
      (command "PLINE" (list wid (+ H 200.0)) (list (+ wid 205.0) (+ H 212.0)) (list (+ wid 330.0) (+ H 110.0)) "")
      (command "PLINE" (list wid (+ H 235.0)) (list (+ wid 205.0) (+ H 247.0)) (list (+ wid 330.0) (+ H 145.0)) "")
      ;; ROOF + WALL SHEETING callouts (arches bypass draw-cladding, so add them here)
      (peb-arch-sheeting-labels data wid H rise)
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
      (draw-girts         wid H brickH nil nil)
      (draw-downpipes     wid H brickH nil)
      (draw-eave-features wid H nil (/ rise (/ (/ wid numGab) 2.0)))   ; outer-gable eave, lip anchored to sheet
      (draw-rafter-label  (/ wid numGab) H rise ht))
    ((= stype "PP")
      ;; Petrol Pump / CNG canopy (owner 14-Jul): an OPEN, near-flat canopy on TWO inset BOX columns.
      ;; The roof falls SLIGHTLY to a VALLEY GUTTER over EACH box column; each valley has a DOWN PIPE
      ;; running down INSIDE the box column.  Centre + both outer edges are the high points (a shallow
      ;; W).  Tube purlins carry the sheeting; a ceiling/soffit lines the underside.  No brick wall.
      ;; NO eave gutters (owner 16-Jul: remove eave gutters from the canopies) — PP drains to the valley
      ;; gutters over the box columns; the outer edges keep only the fascia band.
      (setq ppOvh (* wid 0.22))                       ; matches draw-petrol-frame overhang -> valley X
      (setq ppCx1 ppOvh)                              ; left column / valley line
      (setq ppCx2 (- wid ppOvh))                      ; right column / valley line
      (setq ppMid (/ wid 2.0))                        ; centre high point
      (setq ppS   180.0)                              ; SLIGHT fall rise at the high points
      (setq ppRt  (max (* ht 0.8) 250.0))             ; roof band depth (matches draw-petrol-frame)
      (setq ppCw  (max cb 300.0))                     ; box-column width (matches frame)
      ;; ── Box-column inner outline (hollow tube shown in section, 45 mm wall) ──
      (setvar "CLAYER" "FRAME")
      (setvar "PLINEWID" 0.0)
      (foreach ppx (list ppCx1 ppCx2)
        (command "RECTANG"
          (list (- ppx (- (/ ppCw 2.0) 45.0)) 0.0)
          (list (+ ppx (- (/ ppCw 2.0) 45.0)) (- H ppRt))))
      ;; ── Roof sheeting deck (2 lines) — shallow W: high at both edges + centre, low at the valleys ──
      (setvar "CLAYER" "CLADDING")
      ;; owner 18-Jul: sheet ENDS AT THE RAFTER LINE at both outer edges (x=0 / x=wid) — NO overhang.
      (command "PLINE"
        (list 0.0   (+ H 200.0 ppS)) (list ppCx1 (+ H 200.0))
        (list ppMid (+ H 200.0 ppS)) (list ppCx2 (+ H 200.0))
        (list wid   (+ H 200.0 ppS)) "")
      (command "PLINE"
        (list 0.0   (+ H 235.0 ppS)) (list ppCx1 (+ H 235.0))
        (list ppMid (+ H 235.0 ppS)) (list ppCx2 (+ H 235.0))
        (list wid   (+ H 235.0 ppS)) "")
      ;; ── Tube purlins following each of the four sloped deck segments + a purlin at each outer edge ──
      (peb-deck-purlins 0.0   (+ H 200.0 ppS) ppCx1 (+ H 200.0))
      (peb-deck-purlins ppCx1 (+ H 200.0)     ppMid (+ H 200.0 ppS))
      (peb-deck-purlins ppMid (+ H 200.0 ppS) ppCx2 (+ H 200.0))
      (peb-deck-purlins ppCx2 (+ H 200.0)     wid   (+ H 200.0 ppS))
      (setq ppES (/ ppS ppCx1))                       ; near-flat outer-segment slope
      (peb-z-purlin-at 150.0 (- (+ H 200.0 ppS) (* ppES 150.0))
                       (/ 1.0 (sqrt (+ 1.0 (* ppES ppES)))) (/ (- 0 ppES) (sqrt (+ 1.0 (* ppES ppES)))))
      (peb-z-purlin-at (- wid 150.0) (- (+ H 200.0 ppS) (* ppES 150.0))
                       (/ 1.0 (sqrt (+ 1.0 (* ppES ppES)))) (/ ppES (sqrt (+ 1.0 (* ppES ppES)))))
      ;; raise the ROOFING SYSTEM label CLEAR above the VALLEY GUTTER / FALL callouts (owner 17-Jul:
      ;; was overlapping them on the near-flat deck).
      (peb-canopy-roof-label data (* wid 0.72) (+ H 200.0 ppS) (+ H 200.0 ppS (* 2600 *PEB-TEXT-SCALE*)))
      ;; ── VALLEY GUTTER trough + DOWN PIPE (inside the box column) at EACH column ──
      (foreach ppx (list ppCx1 ppCx2)
        (setvar "CLAYER" "GUTTER")
        (setvar "PLINEWID" 0.0)
        (command "PLINE"
          (list (- ppx 320.0) (+ H 250.0))
          (list (- ppx 150.0) (+ H  60.0))
          (list (+ ppx 150.0) (+ H  60.0))
          (list (+ ppx 320.0) (+ H 250.0))
          "")
        ;; G2 (owner 19-Jul): DOTTED down pipe through the box column (valley trough down to the floor) — the
        ;; universal PEBPIPE dotted linetype so the valley/cantilever pipe reads as a pipe (was solid CLADDING).
        (peb-pipe-line (- ppx 70.0) (+ H 60.0) (- ppx 70.0) 300.0)
        (peb-pipe-line (+ ppx 70.0) (+ H 60.0) (+ ppx 70.0) 300.0))
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list ppCx1 (+ H 200.0 ppS (* 900 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "VALLEY GUTTER")
      (txt "MC" (list ppCx2 (+ H 200.0 ppS (* 900 *PEB-TEXT-SCALE*))) (peb-th 'SMALL) 0 "VALLEY GUTTER")
      ;; FALL callouts — roof falls toward the two valley gutters
      (txt "MC" (list (* (+ 0.0   ppCx1) 0.5) (+ H ppS 520.0)) (peb-th 'SMALL) 0 "FALL")
      (txt "MC" (list (* (+ ppCx1 ppMid) 0.5) (+ H ppS 520.0)) (peb-th 'SMALL) 0 "FALL")
      (txt "MC" (list (* (+ ppMid ppCx2) 0.5) (+ H ppS 520.0)) (peb-th 'SMALL) 0 "FALL")
      (txt "MC" (list (* (+ ppCx2 wid)   0.5) (+ H ppS 520.0)) (peb-th 'SMALL) 0 "FALL")
      ;; DOWN PIPE + BOX COLUMN + CEILING/SOFFIT callouts (owner 18-Jul: NO fascia on canopy frames — the
      ;; FASCIA callout removed; the roof-slab edge itself stays as the structural edge).
      (peb-label-with-leader "DOWN PIPE (IN BOX COLUMN)"
                             (list (- ppCx1 2900.0) (* H 0.55))
                             (list (- ppCx1 90.0)   (* H 0.55))
                             "H" 220)
      (peb-label-with-leader "BOX COLUMN"
                             (list (- ppCx1 2900.0) (* H 0.30))
                             (list (- ppCx1 (/ ppCw 2.0)) (* H 0.30))
                             "H" 220)
      (peb-label-with-leader "CEILING / SOFFIT"
                             (list ppMid (- (- H ppRt) 900.0))
                             (list ppMid (- H ppRt))
                             "V" 220))
    ((= stype "FR")
      ;; FLAT ROOF (owner 14-Jul): NO purlins / roof sheeting.  Instead a floor BUILD-UP —
      ;; R.C.C. slab on corrugated METAL DECK, on steel JOISTS (clip-angle), on the MAIN BEAM.
      ;; The SAME detail is reused for gable-roof mezzanine intermediate floors & multi-storey
      ;; flat-roof floors.  Walls / girts / downpipes / eave features stay as normal.
      ;; owner 15-Jul: FLAT ROOF = brick masonry to 3.048m + metal SHEETING above; STRAIGHT steel columns;
      ;; RCC-on-steel roof build-up (125 concrete on 0.70 profiled decking on 300mm joists @1.5m nested
      ;; flush in the 550mm main beam).
      (draw-brick-wall    wid brickH)                        ; brick to 3.048m (dwarf wall)
      (draw-girts         wid H brickH nil nil)              ; girts on the sheeted portion
      (draw-floor-buildup 0.0 wid H 550.0 550.0 125.0 T)     ; 550 main beam, 300 joists flush, 45 decking, 125 concrete
      ;; COLUMN label (draw-downpipes usually supplies it; the flat roof has no PEB downpipe)
      (peb-label-pline-leader "COLUMN"
                             (list (max 1800.0 (+ ht 800.0)) (- (fr-col-top H ht) 700.0))
                             (list (+ ht 50.0) (- (fr-col-top H ht) 700.0)) "H" 220)
      ;; internal ROOF DRAINAGE (outlet + downspout) — flat roof does NOT use the normal PEB eave gutter
      (draw-fr-drainage wid H ht)
      ;; wall sheeting (2 lines each side) from the brick top up to the eave
      (if (and brickH (< brickH H))
        (progn
          (setvar "CLAYER" "CLADDING")
          (command "LINE" (list -200.0 brickH) (list -200.0 H) "")
          (command "LINE" (list -235.0 brickH) (list -235.0 H) "")
          (command "LINE" (list (+ wid 200.0) brickH) (list (+ wid 200.0) H) "")
          (command "LINE" (list (+ wid 235.0) brickH) (list (+ wid 235.0) H) "")))
      ;; WALL SHEETING callout — 4-leg raised M-Ladder, SAME as the other sections.
      (setvar "CLAYER" "TEXT")
      (setq frWc (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;WALL SHEETING:}\\P"
                         (peb-split-2-lines (peb-panel-label data "WALL")) "}"))
      ;; Raise is MODEST here (H+1500·TS, not Clear Span's H+3800·TS): the flat roof has NO eave gutter and
      ;; only a 1-line wall spec below the label, so it sits just above the eave and leaves the upper-left
      ;; clear for DETAIL-B.  Graphic (4-leg ladder, bold heading above bar / spec below) is identical.
      (setq frWtY (- H 300.0)
            frWeX -1735.0
            frWlY (+ H (* 1500 *PEB-TEXT-SCALE*))
            frWbY (+ (+ H (* 1500 *PEB-TEXT-SCALE*)) (* 175 *PEB-TEXT-SCALE*)))
      (setq frMl
        (vl-catch-all-apply 'peb-make-mleader
          (list (list (list -235.0 frWtY) (list frWeX frWtY)
                      (list frWeX frWbY) (list (+ frWeX 300.0) frWbY)) frWc)))
      ;; Match Clear Span's draw-cladding: anchor the text at the BOTTOM-OF-TOP-LINE so the bold heading
      ;; floats ABOVE the bar and the spec drops BELOW it (owner: "use same M-Ladder as Clear Span").
      (if (not (vl-catch-all-error-p frMl))
        (progn
          (vl-catch-all-apply (function (lambda () (vla-put-TextAttachmentDirection frMl 0))))
          (vl-catch-all-apply (function (lambda () (vla-put-TextLeftAttachmentType  frMl 5))))
          (vl-catch-all-apply (function (lambda () (vla-put-TextRightAttachmentType frMl 5))))))
      (setvar "CLAYER" "ARROWS") (setvar "PLINEWID" 0.0)
      (command "PLINE" (list (- -235.0 (* 160 *PEB-TEXT-SCALE*)) frWtY)
                       "W" (* 55 *PEB-TEXT-SCALE*) 0 (list -235.0 frWtY) "")
      (setvar "PLINEWID" 0.0)
      ;; ── Callout "A" around a joist-beam connection + the ZOOMED DETAIL (reduced, moved ABOVE the frame) ──
      (setvar "CLAYER" "TEXT")
      (command "CIRCLE" (list (* wid 0.5) (- H 350.0)) 650.0)
      (txt "MC" (list (* wid 0.5) (- H 1550.0)) (peb-th 'SMALL) 0 "A")
      (draw-fr-detail 27000.0 14600.0 6.5)
      ;; ── Callout "B" around the drainage outlet + the ZOOMED DRAINAGE DETAIL (top-LEFT corner) ──
      (setvar "CLAYER" "TEXT")
      (command "CIRCLE" (list (+ ht 550.0) (- H 250.0)) 620.0)
      (txt "MC" (list (+ ht 2400.0) (- H 2050.0)) (peb-th 'SMALL) 0 "B")
      (draw-fr-detb 1400.0 14900.0 4.3))
    ((= stype "F2")
      ;; DOUBLE-STOREY (G+1) FLAT ROOF (owner 15-Jul): TOP floor = the SAME flat roof (build-up + internal
      ;; drainage + DETAIL-A/B); an INTERMEDIATE floor (same RCC-on-steel build-up, NO drainage) is added at
      ;; mid-height, carried on 4 FULL-HEIGHT columns (2 edge + 2 intermediate @ <10m).  H = roof slab TOP.
      ;; INTERMEDIATE FLOORS come from the MEZZANINE sub-section (owner 15-Jul): level = MZ1_CH_FFL_BEAM
      ;; (FFL → under main beam), concrete thickness = MZ1_FLOOR_THK, stacked by MZ_FLOOR_HT.  Each floor uses
      ;; the SAME build-up coding as the flat roof but with a DEEPER 700mm main beam.  Roof stays 550/125.
      (setq f2Thk  (MSPL-Get-Num data "MZ1_FLOOR_THK")
            f2Thk  (if (and f2Thk (> f2Thk 0.0)) f2Thk 125.0)
            f2Lvls (f2-mezz-levels data)               ; list of intermediate MAIN-BEAM-BOTTOM levels
            f2rbot (- H 720.0))                        ; roof main-beam bottom = column top
      (draw-brick-wall    wid brickH)                            ; brick to 3.048m (dwarf wall, full height)
      (draw-girts         wid f2rbot brickH nil nil)             ; girts up the full-height sheeted wall
      (foreach lvl f2Lvls                                        ; each mezzanine/intermediate floor: 700 beam, thk concrete
        (draw-floor-buildup 0.0 wid (+ lvl 745.0 f2Thk) 700.0 700.0 f2Thk nil))
      (draw-floor-buildup 0.0 wid H     550.0 550.0 125.0 nil)   ; ROOF (550 beam / 125 concrete; broken out in DETAIL-A)
      (draw-fr-drainage   wid H ht)                              ; internal ROOF drainage only (none at mid floors)
      ;; ONE callout per floor.
      (setvar "CLAYER" "TEXT")
      (peb-label-with-leader "TOP FLAT ROOF\\P(RCC ON STEEL DECK) - SEE DETAIL-A"
                             (list (* wid 0.62) (+ H 950.0))
                             (list (* wid 0.62) (- H 60.0)) "V" 220)
      (foreach lvl f2Lvls
        (peb-label-with-leader (strcat "INTERMEDIATE FLOOR (MEZZANINE)\\P"
                                       (rtos f2Thk 2 0) "mm R.C. SLAB - NO DRAINAGE")
                               (list (* wid 0.34) (+ lvl 745.0 f2Thk 950.0))
                               (list (* wid 0.34) (+ lvl 745.0 f2Thk 40.0)) "V" 220))
      ;; wall sheeting (2 lines each side) from the brick top up to the roof eave
      (if (and brickH (< brickH f2rbot))
        (progn
          (setvar "CLAYER" "CLADDING")
          (command "LINE" (list -200.0 brickH) (list -200.0 f2rbot) "")
          (command "LINE" (list -235.0 brickH) (list -235.0 f2rbot) "")
          (command "LINE" (list (+ wid 200.0) brickH) (list (+ wid 200.0) f2rbot) "")
          (command "LINE" (list (+ wid 235.0) brickH) (list (+ wid 235.0) f2rbot) "")))
      ;; COLUMN label (full-height column)
      (setvar "CLAYER" "TEXT")
      (peb-label-pline-leader "COLUMN (FULL HEIGHT)"
                             (list (max 1800.0 (+ ht 800.0)) (- f2rbot 900.0))
                             (list (+ ht 50.0) (- f2rbot 900.0)) "H" 220)
      ;; WALL SHEETING callout — 4-leg raised M-Ladder, SAME construction as Clear Span (anchored at the roof eave)
      (setvar "CLAYER" "TEXT")
      (setq frWc (strcat "{\\C7;\\H0.42x;{\\Fromand.shx;WALL SHEETING:}\\P"
                         (peb-split-2-lines (peb-panel-label data "WALL")) "}"))
      ;; Minimal raise (f2rbot+300·TS) so the label sits just above the roof eave, BELOW the detail band.
      (setq frWtY (- f2rbot 300.0)
            frWeX -1735.0
            frWlY (+ f2rbot (* 300 *PEB-TEXT-SCALE*))
            frWbY (+ (+ f2rbot (* 300 *PEB-TEXT-SCALE*)) (* 175 *PEB-TEXT-SCALE*)))
      (setq frMl
        (vl-catch-all-apply 'peb-make-mleader
          (list (list (list -235.0 frWtY) (list frWeX frWtY)
                      (list frWeX frWbY) (list (+ frWeX 300.0) frWbY)) frWc)))
      (if (not (vl-catch-all-error-p frMl))
        (progn
          (vl-catch-all-apply (function (lambda () (vla-put-TextAttachmentDirection frMl 0))))
          (vl-catch-all-apply (function (lambda () (vla-put-TextLeftAttachmentType  frMl 5))))
          (vl-catch-all-apply (function (lambda () (vla-put-TextRightAttachmentType frMl 5))))))
      (setvar "CLAYER" "ARROWS") (setvar "PLINEWID" 0.0)
      (command "PLINE" (list (- -235.0 (* 160 *PEB-TEXT-SCALE*)) frWtY)
                       "W" (* 55 *PEB-TEXT-SCALE*) 0 (list -235.0 frWtY) "")
      (setvar "PLINEWID" 0.0)
      ;; ── DETAILS MOVED TO A SEPARATE SHEET (owner 16-Jul): DETAIL-A (joist connection) + DETAIL-B (roof
      ;;    drainage) are NO LONGER on the section — only the A/B CALLOUT circles stay, referencing the
      ;;    separate "FLAT ROOF DETAILS" sheet.  The frame heading sits 5 rows below the top border (the
      ;;    header + border read *PEB-F2-HEAD-SUB*, now at the normal above-frame position). ──
      (setq *PEB-F2-HEAD-SUB* (+ H rise (* 5100.0 *PEB-TEXT-SCALE*)))
      (setvar "CLAYER" "TEXT")
      (command "CIRCLE" (list (* wid 0.5) (- H 350.0)) 650.0)          ; callout A (roof joist connection)
      (txt "MC" (list (* wid 0.5) (- H 1550.0)) (peb-th 'SMALL) 0 "A")
      (command "CIRCLE" (list (+ ht 550.0) (- H 250.0)) 620.0)         ; callout B (roof drainage)
      (txt "MC" (list (+ ht 2400.0) (- H 2050.0)) (peb-th 'SMALL) 0 "B"))
    ((= stype "SS")
      ;; SINGLE SLOPE: low (left) eave = H, HIGH (right) eave = H + monoRise.  The RIGHT wall
      ;; sheeting + girts must climb to the HIGH eave (not the low H, which left the tall wall
      ;; bare); the roof drains DOWN-slope to the LOW eave, so the gutter + downpipe live on the
      ;; LOW (left) side only.  Roof cladding follows the ONE mono slope (monoRise).
      (setq monoRise (/ wid slopeD))
      (setq ssHR (+ H monoRise))
      (draw-brick-wall    wid brickH)
      ;; NOTE the trailing nil: draw-cladding takes NINE arguments (throatWin last).
      ;; Called with eight, AutoLISP does not raise a catchable error -- it silently
      ;; unwinds the WHOLE evaluation, so every remaining line of C:PEB-SECTION
      ;; (cladding, purlins, girts, gutter, FASCIA, slope tags, grid, dims, title
      ;; block) was never drawn.  A mono roof carries no roof monitor, hence nil.
      (draw-cladding      data wid H rise brickH monoRise ssHR nil nil)   ; rightH = high eave
      (draw-purlins-mono  wid H monoRise)                        ; MONO purlins follow the one slope (not gable)
      (draw-girts         wid H brickH ssHR nil)                  ; right girts to the high eave
      (draw-downpipes     wid H brickH T)                         ; mono -> low-side downpipe only
      (draw-eave-features wid H T (/ monoRise wid))               ; mono -> low-side gutter (lip anchored to sheet)
      (draw-rafter-label  wid H rise ht))
    ((= stype "RC")
      ;; ROOFING SYSTEM on RCC columns (owner 16-Jul): the SECTION is cut THROUGH the RCC column, so the wall
      ;; at the cut IS the concrete column (drawn by draw-rcc-columns) — NO separate brick hatch, NO wall
      ;; sheeting, NO girts.  Only the metal ROOF sheeting sits on the steel rafters.
      (setq monoRise nil)
      (setq *PEB-NO-WALL-SHEET* T)                 ; suppress wall-sheeting geometry + WALL SHEETING M-Ladder
      (draw-cladding      data wid H rise H monoRise nil nil *RM-THROAT-WIN*)   ; brickH=H -> roof sheeting only, no wall sheet
      (draw-purlins       wid H rise *RM-THROAT-WIN*)
      (draw-eave-strut    wid H rise)
      ;; NO draw-girts (no sheeted wall).  Fascia option → valley gutter (no eave gutter/brick).  PLAIN option
      ;; (owner markup 20) → BRICK MASONRY on the OUTER side of each RCC column (full height) + an EAVE GUTTER
      ;; hanging JUST OUTSIDE the column, with a downpipe.
      (if (not *PEB-RC-FASCIA*)
        (progn (draw-rc-brick-hidden wid H)        ; brick masonry BEYOND the cut → dotted/hidden outline
               (draw-downpipes   wid H H nil)      ; downpipe against the wall
               (draw-eave-features wid H nil (/ rise (/ wid 2.0)))))  ; eave gutter outside column, lip on sheet
      (draw-rafter-label  wid H rise ht)
      (setq *PEB-NO-WALL-SHEET* nil))
    (T
      ;; Gable frames (CS / MS): symmetric eaves at H, gable roof cladding (monoRise nil).
      (setq monoRise nil)
      (draw-brick-wall    wid brickH)
      (draw-cladding      data wid H rise brickH monoRise nil nil *RM-THROAT-WIN*)   ; throat-trimmed sheeting
      (draw-purlins       wid H rise *RM-THROAT-WIN*)                                 ; edge purlins, none in throat
      (draw-eave-strut    wid H rise)
      (draw-girts         wid H brickH nil nil)
      (draw-downpipes     wid H brickH nil)
      ;; RCC-parapet/fascia replaces the eave gutter with a valley gutter (drawn by draw-rc-fascia).
      (if (not (and (= stype "RC") *PEB-RC-FASCIA*))
        (draw-eave-features wid H nil (/ rise (/ wid 2.0))))   ; gable eave, lip anchored to the sheet (owner G3)
      (draw-rafter-label  wid H rise ht)))

  ;; ── VERTICAL FASCIA (FA_*) on the sidewalls of a normal PEB frame ──
  ;; The RC frame type has its OWN concrete parapet/fascia (draw-rc-fascia), so it is
  ;; excluded here; every other frame type gets the manual's vertical fascia detail.
  (if (/= stype "RC")
    (vl-catch-all-apply
      ;; monoRise is nil on a gable and the mono rise on SS/LT -- it is what tells
      ;; the fascia that the two eaves sit at different heights.
      (function (lambda () (draw-fascia-vertical data wid H rise monoRise)))))

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
  (cond
    ;; arched (curved rafter self-documents), canopies (BF/CC draw their OWN direction-correct
    ;; tag; PP is flat), and FLAT ROOF (level, nominal drainage only) — skip the ridge-pair tag loop.
    ((member stype '("ACS" "AMS" "BF" "CC" "PP" "FR" "F2")) nil)
    ((member stype '("SS" "LT"))
      ;; SINGLE SLOPE: exactly ONE tag, rising low(left) -> high(right) — a mono
      ;; roof has no ridge, so the old per-half pair (one up-right, one up-left) was wrong.
      (setq monoRise (/ wid slopeD))
      (setq cxM (* wid 0.40))
      ;; Slope tag must ride JUST ABOVE the mono sheeting line and FOLLOW the slope (owner 14-Jul, STRICT).
      ;; Sheeting top = H + monoRise*(x/W) + purlinH(200) + cladThk(35) = +235; add a 180mm gap so the tag
      ;; sits clearly above the sheeting, parallel to it (draw-slope-tag's hypotenuse already = the slope).
      (setq cyM (+ H (* monoRise (/ cxM wid)) 235.0 (* 300 *PEB-TEXT-SCALE*)))
      (draw-slope-tag cxM cyM slopeD 1))
    (T
  (foreach rx ridges
    ;; figure out which columns flank this ridge
    (setq leftCol  0.0)
    (setq rightCol wid)
    (foreach cx cols
      (if (and (< cx rx) (> cx leftCol))  (setq leftCol  cx))
      (if (and (> cx rx) (< cx rightCol)) (setq rightCol cx)))
    (setq halfL (- rx leftCol))
    (setq halfR (- rightCol rx))
    ;; ── RULE 4B.53: "Alway keep away from the Peakline" (owner 30-Aug) ────────────────
    ;; The X and the Y of this tag used to be measured from DIFFERENT things: the Y already
    ;; knew that a Multi-Span rafter is CONTINUOUS over its interior columns and so rises from
    ;; the OUTER eave (hLref/hRref, below), but the X took its midpoint between the nearest
    ;; COLUMNS. On MSPL-26-278 the interior column sits at 14770 and the ridge at 15005, so the
    ;; "half rafter" the X used was 235 mm long and the 1:10 callout was planted 41 mm from the
    ;; peak line. With two interior columns it is 2.5 m; with three, 1.9 m.
    ;; ONE reference for both: the same outer stations the height uses. MG keeps its valleys,
    ;; where the rafter really does start.
    (setq hLref (if (= stype "MG") leftCol  0.0))
    (setq hRref (if (= stype "MG") rightCol wid))
    ;; X position: middle of each half-rafter span (50% from eave, 50% from ridge).
    (setq midLX (+ hLref (* (- rx hLref) 0.5)))
    (setq midRX (- hRref (* (- hRref rx) 0.5)))
    ;; …and a hard floor on the clearance, so no future change to the midpoint can walk the
    ;; callout back onto the ridge. A quarter of the half-span, and never less than a glyph and
    ;; a half — expressed in TEXT-SCALE units so it holds at any sheet scale.
    (setq peakClr (max (* 1800 *PEB-TEXT-SCALE*) (* 0.25 (- rx hLref))))
    (if (> midLX (- rx peakClr)) (setq midLX (- rx peakClr)))
    (setq peakClr (max (* 1800 *PEB-TEXT-SCALE*) (* 0.25 (- hRref rx))))
    (if (< midRX (+ rx peakClr)) (setq midRX (+ rx peakClr)))
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
    ;; HEIGHT reference for the sheeting line at the tag X: the rafter top rises from the true EAVE to the
    ;; ridge.  For MULTI-GABLE the interior columns ARE valleys, so the rise is measured valley->ridge
    ;; (leftCol/rightCol).  For MULTI-SPAN the interior columns sit UNDER a CONTINUOUS rafter, so the rise
    ;; must be measured from the OUTER eave (0 / wid) — using leftCol there put the tag BELOW the sheeting
    ;; (owner 14-Jul: slope symbol must sit ABOVE the sheeting line, same as Clear Span).
    (setq cxL (- midLX (/ tagRun 2.0)))
    (setq cyL (+ H (* rise (/ (- cxL hLref) (- rx hLref)))
                  235.0 (* 300 *PEB-TEXT-SCALE*)))   ; slope symbol 50mm ABOVE the sheeting line (owner 14-Jul)
    (setq cxR (+ midRX (/ tagRun 2.0)))
    (setq cyR (+ H (* rise (/ (- hRref cxR) (- hRref rx)))
                  235.0 (* 300 *PEB-TEXT-SCALE*)))   ; slope symbol 50mm ABOVE the sheeting line (owner 14-Jul)
    (draw-slope-tag cxL cyL slopeD  1)
    (draw-slope-tag cxR cyR slopeD -1)
  )))                                 ; close foreach, T-clause, cond

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
  (setq bubR (peb-bub-r))   ; 4B.31 - was 380 x TS, half the size of every other sheet
  ;; owner 14-Jul: with interior columns the overall O/O dim sits deeper (module dims + spacing), so it
  ;; landed ON the bubbles.  Drop the bubbles BELOW it for multi-column frames so the bubble line + vertical
  ;; ticks do not overlap the overall-width dimension.
  (setq bubY (- 0.0 (if (> (length cols) 2) (* 4600 *PEB-TEXT-SCALE*) (* 3300 *PEB-TEXT-SCALE*))))
  (setq i 0)
  (setq nCols (length cols))
  ;; the plan's merged width grid, so both sheets letter the same lines the same way
  (setq wgrid (vl-catch-all-apply
                (function (lambda () (peb-fr-ew-stations data wid "LEW")))))
  (if (or (vl-catch-all-error-p wgrid) (not (listp wgrid))) (setq wgrid nil))
  (foreach cx cols
    (cond
      ((= i 0)            (setq bubX (- cx 235.0)))   ; leftmost outer
      ((= i (1- nCols))   (setq bubX (+ cx 235.0)))   ; rightmost outer
      (T                  (setq bubX cx)))            ; interior
    ;; cx is SECTION space (mirrored above); wgrid is PLAN space, so un-mirror to look
    ;; the letter up.  peb-width-letter then still returns A for the far side wall -
    ;; which the mirror has just placed on the LEFT.  Rule 4B.37.
    ;; THE SAME BUBBLE THE PLAN DRAWS (owner 3-Sep: "sync all the bubbles").  This sheet had its
    ;; own plain-circle drawer at half the radius, so the one set of drawings carried two kinds of
    ;; grid bubble.  grid-bubble is the house mark - the green shield with its pointer aimed at
    ;; the grid line - and "U" aims it up at the column standing above it.
    (grid-bubble bubX bubY
                 (peb-sec-grid-letter (- wid cx) wgrid i
                   (if (boundp 'peb-width-mods) (peb-width-mods data wid) nil)) "U")   ; letters follow the PLAN grid
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
  ;; owner 14-Jul: push the height dims further OUT so the rotated BRICK-MASONRY text clears the eave
  ;; DOWN PIPE (was wid+800 / wid+1000·scale — the 2-line text reached back over the pipe).
  ;; owner 14-Jul: for a SINGLE-SLOPE (mono) roof the CLEAR HEIGHT is taken on the LOW eave side — put the
  ;; height dims on the LEFT (objX = -235, dimX negative).  Gable/arched keep them on the RIGHT.
  (if monoRise
    (setq hObjX -235.0
          dimX1 (min (- 1500.0) (- (* 1600 *PEB-DIM-SCALE*)))
          dimX2 (- dimX1 (peb-dim-text-spacing "vertical")))
    (setq hObjX wid
          dimX1 (max (+ wid 1500.0) (+ wid (* 1600 *PEB-DIM-SCALE*)))
          dimX2 (+ dimX1 (peb-dim-text-spacing "vertical"))))
  ;; Drawn dims, then overridden to colour 0 (ByBlock).  UNIFORM dim text (320).
  ;; RC = concrete column wall; BF/CC/PP = cantilever canopies (no walls/sheeting on the sides, so NO brick
  ;; masonry — owner 16-Jul markup 5).
  (if (and brickH (> brickH 0) (/= stype "RC") (not (member stype '("BF" "CC" "PP"))))
    (progn
      (setq *PEB-DIM-TXT* 320.0)
      (peb-dim-height-stretch hObjX dimX1 0.0 brickH
        (strcat (peb-dim-mft brickH) "\\PBRICK MASONRY"))
      (setq *PEB-DIM-TXT* nil)
      (peb-recolor-last-dim 0)))                  ; ByBlock
  (setq *PEB-DIM-TXT* 320.0)
  ;; owner 25-Jul: when the height was measured at the EAVE, dimension the EAVE HEIGHT up to the eave
  ;; line, NOT the CLEAR HEIGHT to the haunch (0 -> H-ht). Clear-basis is unchanged.
  ;; owner 3-Sep-2026: the eave line is the TOP OF THE EAVE STRUT / PURLIN, so the arrow runs
  ;; 0 -> H + purlinD, not 0 -> H (H is the top of the rafter at the haunch, one purlin lower).
  ;; The basis conversion above takes the same purlin back out of the entered figure, so this
  ;; arrow lands EXACTLY on the number typed into the BSF.
  (if eaveBasis
    ;; "<>" is AutoCAD's MEASUREMENT placeholder, so these were formatted by the DIMSTYLE:
    ;; DIMALTU 4 (architectural) suppresses the -0", and AutoCAD cannot comma-group a native
    ;; dimension at all.  The section therefore printed 30480 [100'] next to the plan's
    ;; 121,920 [400'-0"] — the same quantity in two formats in one document (owner 27-Aug).
    ;; peb-dim-mft is the builder the plan and the elevations already use.
    (peb-dim-height-stretch hObjX dimX2 0.0 (+ H purlinD)
      (strcat (peb-dim-mft (+ H purlinD)) "\\PEAVE HEIGHT"))
    (peb-dim-height-stretch hObjX dimX2 0.0 (- H ht)
      (strcat (peb-dim-mft (- H ht)) "\\PCLEAR HEIGHT")))
  (setq *PEB-DIM-TXT* nil)
  (peb-recolor-last-dim 0)                        ; ByBlock

  ;; -- RULE 4B.38 - THE TWO HEIGHTS A MEZZANINE CREATES (owner 29-Aug) ---------------
  ;; "Show the dimensions from FFL to Bottom of Mezzanine Beam (Clear Height) and Also
  ;;  Show the Height from FFL of Mezzanine to Bttom of Rafter at Haunch as well."
  ;;
  ;; The sheet dimensions the BUILDING's clear height above; these are the two the
  ;; MEZZANINE creates - the headroom under the deck and the headroom over it, which are
  ;; the figures a customer actually reads a mezzanine on.
  ;;
  ;; THEY BELONG HERE, NOT IN THE MEZZANINE DRAWER. Drawn there they were placed at the
  ;; mezzanine's free edge INSIDE the frame, and a rotated two-line dim label is far taller
  ;; than the 4.9 m it annotates - both texts overran the frame, each other, the module
  ;; chain and the rafter leader into one illegible stack (measured on MSPL-26-271).
  ;; Out here they take the next columns in the SAME chain as BRICK MASONRY and CLEAR
  ;; HEIGHT, spaced by peb-dim-text-spacing - the mechanism that already guarantees two
  ;; rotated dim texts clear each other at any drawing scale - so overrun is harmless.
  ;;
  ;; VALUES COME FROM THE BSF, NOT FROM THE DRAWN GEOMETRY. MZ1_CH_FFL_BEAM and
  ;; MZ1_CH_SLAB_RAFTER are stated fields; the estimate and the TFP quote them. The
  ;; mezzanine drawer now lands its slab on MZ1_CH_FFL_SLAB (rule 4B.7) so the arrows
  ;; measure exactly what these print. Only if the BSF omits the over-height is it
  ;; derived, from H - ht - the same expression the CLEAR HEIGHT dimension above uses.
  (if (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_TOGGLE") "")) "YES")
    (progn
      (setq mzCH   (MSPL-Get-Num data "MZ1_CH_FFL_BEAM")
            mzFFL  (MSPL-Get-Num data "MZ1_CH_FFL_SLAB")
            mzOver (MSPL-Get-Num data "MZ1_CH_SLAB_RAFTER"))
      (if (and mzFFL (<= mzFFL 0.0)) (setq mzFFL nil))
      (if (and mzFFL (or (null mzOver) (<= mzOver 0.0)))
        (setq mzOver (- (- H ht) mzFFL)))
      (setq dimX3 (if monoRise (- dimX2 (peb-dim-text-spacing "vertical"))
                               (+ dimX2 (peb-dim-text-spacing "vertical"))))
      (setq dimX4 (if monoRise (- dimX3 (peb-dim-text-spacing "vertical"))
                               (+ dimX3 (peb-dim-text-spacing "vertical"))))
      (setq *PEB-DIM-TXT* 320.0)
      (if (and mzCH (> mzCH 300.0))
        (progn
          (peb-dim-height-stretch hObjX dimX3 0.0 mzCH
            (strcat (peb-dim-mft mzCH) "\\PC.H UNDER MEZZ. BEAM"))
          (peb-recolor-last-dim 0)))
      ;; a deck close under the eave has no headroom worth printing, and a near-zero
      ;; dimension with two arrowheads is noise, not information.
      (if (and mzFFL mzOver (> mzOver 300.0))
        (progn
          (peb-dim-height-stretch hObjX dimX4 mzFFL (+ mzFFL mzOver)
            (strcat (peb-dim-mft mzOver) "\\PC.H OVER MEZZANINE"))
          (peb-recolor-last-dim 0)))
      (setq *PEB-DIM-TXT* nil)))

  ;; owner 16-Jul markup 14: arched frames — extend the CLEAR HEIGHT witness line UP to the eave gutter (H)
  ;; so it references the top of the structure (the measured value stays 7000 = H-ht).  The extension runs
  ;; from the object face out to the dim line at the eave level.
  (if (member stype '("ACS" "AMS"))
    (progn
      (setvar "CLAYER" "DIMENSIONS")
      (setvar "PLINEWID" 0.0)
      (command "LINE" (list hObjX (- H ht)) (list hObjX H) "")     ; witness continues up the object face to the eave
      (command "LINE" (list hObjX H)        (list dimX2 H) "")))   ; horizontal reference at the eave gutter
  ;; owner 18-Jul (markup 13): canopies do NOT extend the CLEAR HEIGHT witness up to the roof — the
  ;; up-witness + top horizontal reference read as stray stepped lines at the free tip.  Removed; the
  ;; plain CLEAR HEIGHT dimension (drawn above, 0 -> H-ht) stands on its own.  (Arched frames above keep
  ;; their up-witness because they reference the eave gutter.)

  ;; Width dimensions at the bottom — VLA path via peb-dim-h-stretch
  ;; (single grip-editable AcDbRotatedDimension; falls back to hand-
  ;; rolled dim-line-h if VLA unavailable so the drawing always renders).
  ;; Module chain dimensions:
  ;;   - INTERIOR modules: C/C (column centerline to column centerline)
  ;;   - END modules:      C/O (interior-col centerline → OUTER FACE of
  ;;                       wall sheeting, i.e., -235 on LEFT, wid+235 on RIGHT)
  ;; This keeps the sum of modules equal to widInput (Excel input value,
  ;; out-to-out of sheeting line).
  ;; owner 14-Jul: module dims share the SAME uniform text size (320) as the overall width + height dims.
  (setq *PEB-DIM-TXT* 320.0)
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
  (setq *PEB-DIM-TXT* nil)
  ;; Overall width dimension OUT-TO-OUT OF SHEETING LINE.
  ;; "<>" substitutes measured value at render — stretch updates the
  ;; "75000" while keeping the "0/0 OF SHEETING LINE" suffix as-is.
  ;; Y position auto-adjusted: module dim at -1500·DS, overall dim
  ;; offset BELOW that by peb-dim-text-spacing (auto-scales with
  ;; DIMTXT × DIMSCALE so dim texts always have a visible gap).
  (setq *PEB-DIM-TXT* 320.0)                   ; owner 14-Jul: match the height dims (uniform dim text)
  ;; owner 29-Jul: overall-width LABEL now follows the IF "Measured At" basis (BP_WIDTH_REF), so the
  ;; section matches the plan (235 = "C/C STEEL", not the old hard-coded "0/0 OF SHEETING LINE"). A blank
  ;; basis falls back to the sheeting label so every existing (O/O-sheeting) building is unchanged.
  (setq wsfx (MSPL-Get-Str data "WIDTH_REF"))
  (setq wsfx (if (and wsfx (/= wsfx "")) (peb-basis-suffix wsfx) "0/0 OF SHEETING LINE"))
  (peb-dim-h-stretch -235.0 (+ wid 235.0)
                     (- 0.0
                        (+ (if (> (length cols) 2)
                             (+ (* 1500 *PEB-DIM-SCALE*) (peb-dim-text-spacing "horizontal"))
                             (* 1500 *PEB-DIM-SCALE*))
                           (* 450 *PEB-DIM-SCALE*)))   ; owner 14-Jul: drop the O/O dim clear of the FFL line + FFL text
                     (strcat (peb-dim-mft (+ wid 470.0)) "\\P" wsfx))
  (setq *PEB-DIM-TXT* nil)
  (peb-recolor-last-dim 0)                    ; ByBlock for overall width dim

  ;; ── Title (frame type prominently displayed for review) ─────
  ;; Re-assert stype from the data (defensive: a dim/label helper can clobber the dynamic binding).
  (setq stype (strcase (MSPL-Get-Str data "STYPE")))
  (if (and (member stype '("FR" "F2")) (f2-active-p data)) (setq stype "F2"))
  (if (not (member stype '("CS" "SS" "MS" "LT" "MG" "FR" "F2" "RC" "CC" "BF" "ACS" "AMS" "PP"))) (setq stype "CS"))
  (setq *PEB-CANOPY-NAME* (peb-canopy-name stype data))   ; re-assert alongside stype (same defensive reason)
  (setvar "CLAYER" "TEXT")
  ;; owner 14-Jul: lift the whole TITLE BLOCK 3 rows (+700·TS) so the frame sits LOWER relative to the top
  ;; matter — this keeps the raised sheeting M-Ladders + a long sandwich spec clear of the title.
  ;; Heading base Y: F2 (G+1) LIFTS the whole heading so it sits 10 rows above the two details
  ;; (*PEB-F2-HEAD-SUB*, computed in the F2 branch); all other frames keep H+rise+5100·TS.
  ;; owner 23-Jul: lift the title block a further ~3 rows so the SPAN|C.H|RIDGE|SLOPE info bar clears the
  ;; ROOF/WALL SHEETING M-Ladder headings below it (they were overlapping). 5100 -> 6200 (+1100·TS).
  (setq hdBase (if (and (= stype "F2") *PEB-F2-HEAD-SUB*)
                 *PEB-F2-HEAD-SUB*
                 (+ H rise (* 6200 *PEB-TEXT-SCALE*))))
  ;; Top line: frame type (e.g. CLEAR SPAN GABLE / MULTI-GABLE / SINGLE SLOPE)
  (txt-bold "MC"
            (list (/ wid 2.0) (+ hdBase (* 1900 *PEB-TEXT-SCALE*)))
            500 0
            (peb-structure-label stype))
  ;; Second line: generic "BUILDING CROSS-SECTION"
  (txt-bold "MC"
            (list (/ wid 2.0) (+ hdBase (* 1100 *PEB-TEXT-SCALE*)))
            350 0
            "BUILDING CROSS-SECTION")
  ;; Underline beneath title
  (setvar "CLAYER" "TEXT")
  (command "LINE"
    (list (- (/ wid 2.0) (* 6000 *PEB-TEXT-SCALE*))
          (+ hdBase (* 700 *PEB-TEXT-SCALE*)))
    (list (+ (/ wid 2.0) (* 6000 *PEB-TEXT-SCALE*))
          (+ hdBase (* 700 *PEB-TEXT-SCALE*))) "")
  ;; Subtitle: short summary line - use widInput (out-to-out of sheeting,
  ;; matches the dimension shown at the bottom of the section).
  (txt-bold "MC"
       (list (/ wid 2.0) hdBase)
       260 0
     (if (= stype "F2")
       ;; Multi-storey flat roof: roof clear height + count of mezzanine (intermediate) floors.
       (strcat (rtos (/ widInput 1000.0) 2 1) "m SPAN  |  ROOF C.H "
               (rtos (/ (- H ht) 1000.0) 2 1) "m  |  + "
               (itoa (length (f2-mezz-levels data))) " MEZZANINE FLOOR(S)")
       (strcat (rtos (/ widInput 1000.0) 2 1) "m SPAN  |  "
               "C.H " (rtos (/ (- H ht) 1000.0) 2 1) "m  |  "
               (cond
                 ((member stype '("PP" "FR")) "FLAT ROOF")
                 ;; SS / LT are SINGLE-SLOPE: no ridge -- the top height is the HIGH eave.
                 ((member stype '("SS" "LT"))
                  (strcat "HIGH EAVE " (rtos (/ (+ H (peb-purlin-depth) (/ wid slopeD)) 1000.0) 2 1)
                          "m  |  SLOPE " slopeStr))
                 ;; ACS / AMS are ARCHED: a curved roof has a CROWN, not a ridge, and no straight slope ratio.
                 ((member stype '("ACS" "AMS"))
                  (strcat "ARCHED ROOF  |  CROWN " (rtos (/ (+ H rise) 1000.0) 2 1) "m"))
                 ;; BF / CC are CANOPIES: a cantilever canopy has a drainage FALL, not a ridge.
                 ((member stype '("BF" "CC"))
                  (strcat "CANOPY  |  FALL " slopeStr))
                 ;; RIDGE ON THE SAME BASIS AS THE EAVE HEIGHT (owner 27-Aug).  The title
                 ;; block's EAVE HEIGHT is clear + haunch + PURLIN (peb-tb-eave-height), and
                 ;; this read H + rise — clear + haunch + rise, no purlin.  So the two heights
                 ;; on one sheet were measured to different things: 7,173 and 8,497 on B-03.
                 ;; Both now read to the top of the purlin, which is what the eave figure
                 ;; already meant, so ridge = eave + rise exactly.
                 (T (strcat "RIDGE " (rtos (/ (+ H (peb-purlin-depth) rise) 1000.0) 2 1)
                            "m  |  SLOPE " slopeStr))))))

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
  ;; RAISED BASE (owner 29-Jul): part of the building (grid rbFrom..rbTo) rests on an existing RCC building.
  ;; Draw a DETAIL to the right of the typical frame — the existing RCC column + first-floor beam/slab (built
  ;; in concrete) + RCC pedestal, with the STEEL typical column starting above it at +rbBase.
  (setq *PEB-SEC-DETAIL-R* nil)
  (vl-catch-all-apply (function (lambda () (peb-sec-raised-detail data wid H))))
  (setq borderL (min (- (* 6000 *PEB-DIM-SCALE*))
                     (- c0 (* 800 *PEB-TEXT-SCALE*))))
  (setq borderR (max (+ wid (* 6000 *PEB-DIM-SCALE*))
                     (+ c6 (* 800 *PEB-TEXT-SCALE*))
                     (if *PEB-SEC-DETAIL-R* *PEB-SEC-DETAIL-R* 0.0)))
  (setq borderB (- tbBot (* 1200 *PEB-TEXT-SCALE*)))
  ;; owner 23-Jul: this is the operative top-border Y for the section sheet. The title was lifted (hdBase
  ;; 5100->6200) so its info bar clears the sheeting labels; the border top is raised 6500->10500·TS to keep
  ;; "CLEAR SPAN GABLE" (top at hdBase+1900·TS = H+rise+8100·TS) a clear ~3 ROWS below the inner border line.
  (setq borderT (+ H rise (* 10500 *PEB-TEXT-SCALE*)))
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
  ;; owner 14-Jul: the top border must sit CLEAR ABOVE the frame label.  The title is drawn at
  ;; 7000*PEB-TEXT-SCALE (its top edge ~7250*TS); raise the border top to 8000*PEB-TEXT-SCALE so a visible
  ;; GAP shows between the double-line top border and "CLEAR SPAN GABLE".  MUST use *PEB-TEXT-SCALE* (the
  ;; SAME scale the title uses) — tbScale differs from it and left the title touching the border.
  ;; STRICT (owner 16-Jul, ALL drawings): the title-block strip is FLUSH with the sheet double-line border on
  ;; TOP/BOTTOM/RIGHT.  For F2 the heading is LIFTED, so the strip top must reach the raised border (border top
  ;; = 5 rows above the heading top line; strip top = border + 480·TS).  The title-block CONTENT is capped to a
  ;; natural height inside peb-titleblock-mammut so it stays readable (top section top-aligned, bottom section
  ;; bottom-aligned, gap absorbed in the middle) instead of stretching.
  (setq tbFrmT (if (and (= stype "F2") *PEB-F2-HEAD-SUB*)
                 (+ *PEB-F2-HEAD-SUB* (* 1900 *PEB-TEXT-SCALE*) (* (+ (* 5.0 420.0) 480.0) *PEB-TEXT-SCALE*))
                 (+ H rise (* 8000.0 *PEB-TEXT-SCALE*))))
  (setq tbBldgR (+ wid (* 6000.0 *PEB-DIM-SCALE*)))     ; right of the frame + dims
  (setq tbStripH (- tbFrmT tbFrmB))
  (setq tbStripW (max 10000.0                           ; absolute floor: notes text must not wrap/overlap on narrow frames (LT/canopy)
                      (* wid 0.26)                      ; not too thin
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
      (cons "EXPOSURE" (peb-tb-or (MSPL-Get-Str data "EXPOSURE") "B"))
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
      (cons "DRGTITLE"  "CROSS SECTION")
      (cons "SCALE"     "N.T.S.")
      (cons "SHEETSIZE" (if (= stype "F2") "A0" "A1"))   ; G+1 is taller → larger sheet
      (cons "SHEETNO"   (strcat "PRO-" tbBno))))
  ;; Content-sizing cap (global, read by peb-titleblock-mammut): normally nil (content fills the strip, every
  ;; existing frame unchanged).  For F2 the strip is TALL (flush to the raised border), so cap the content to
  ;; its natural height so text stays readable and the extra height becomes a clean middle gap.
  (setq *PEB-TB-SIZEH* (if (= stype "F2") (min tbStripH (* tbStripW 1.6)) nil))
  ;; owner 29-Jul: skip the EMBEDDED section title block when the caller suppresses it (*PEB-SUPPRESS-TB*).
  ;; The A4 paperspace Layout provides ONE title block on the sheet; drawing it here too gave a DOUBLE title
  ;; block inside the viewport.  (Plan/Framing already gate via peb-frame-and-titleblock; the Section drew it
  ;; inline, ungated.)
  (if (not *PEB-SUPPRESS-TB*)
    (peb-titleblock-mammut tbStripX tbFrmB tbStripW tbStripH tbData))
  (setq *PEB-TB-SIZEH* nil)
  ;; Drawing border wraps the section + the title strip.
  ;; owner 14-Jul STRICT: the RIGHT-SIDE TITLE BLOCK must be FLUSH on all 3 outer sides (right, top,
  ;; bottom) with the sheet's double-line frame — its own box line coincides with the border's INNER line
  ;; so the two read as one joined frame.  draw-border draws its inner rectangle 0.6*margin (= 480*TS)
  ;; OUTSIDE (x1,y1,x2,y2); so pull borderR/T/B 480*TS INSIDE the strip edges to land the inner line
  ;; exactly on the strip's right/top/bottom.  borderL is left as-is (wraps the section on the left).
  (setq borderL (- (* 6000.0 *PEB-DIM-SCALE*))
        borderB (+ tbFrmB (* 480.0 *PEB-TEXT-SCALE*))
        borderR (- (+ tbStripX tbStripW) (* 480.0 *PEB-TEXT-SCALE*))
        borderT (- tbFrmT (* 480.0 *PEB-TEXT-SCALE*)))   ; flush with the (F2-raised) title-block strip top

  ;; Restore drawing scales (title block done)
  (setq *PEB-TEXT-SCALE* *PEB-OLD-TEXT-SCALE*)
  (setq *PEB-DIM-SCALE*  *PEB-OLD-DIM-SCALE*)

  ;; Drawing border — borderL/B/R/T already computed above (before
  ;; the table) so the table sits flush against them.  Just draw
  ;; the rectangle here.  Suppressed sheets (A4 Layout) get their border from the Layout, not the Model.
  (if (not *PEB-SUPPRESS-TB*)
    (draw-border borderL borderB borderR borderT))

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

;; ── SEPARATE "FLAT ROOF DETAILS" sheet (owner 16-Jul): DETAIL-A (joist connection) + DETAIL-B (roof
;; drainage) enlarged on their own sheet, referenced by the A/B callouts on the section. ──
(defun peb-fr-details-from-file (path / data tbFrmB tbFrmT tbStripH tbStripW tbStripX tbData)
  (setq data (if (> (strlen path) 0) (MSPL-Read-Data path) nil))
  (vl-catch-all-apply (function (lambda () (peb-std-setup))))
  (setq *PEB-TEXT-SCALE* 1.0 *PEB-DIM-SCALE* 1.0)
  (setvar "CLAYER" "TEXT")
  ;; heading, centred over the details area (left of the title block)
  (txt-bold "MC" (list 9000.0 22300.0) (peb-th 'DIM) 0 "FLAT ROOF - CONSTRUCTION DETAILS")
  (command "LINE" (list 3000.0 21650.0) (list 15000.0 21650.0) "")
  ;; DETAIL-A (joist connection) on TOP, DETAIL-B (roof drainage) BELOW — stacked so both keep the full left
  ;; width for their labels while the title block occupies the right.
  (draw-fr-detail  9000.0 16400.0 8.0)
  (draw-fr-detb    9000.0  8000.0 6.0)
  ;; ── flush title block on the RIGHT (owner 16-Jul) ──
  (setq tbFrmB 2500.0 tbFrmT 23500.0 tbStripH (- tbFrmT tbFrmB)
        tbStripW 11000.0 tbStripX 21500.0)
  (setq tbData
    (list
      (cons "REV" "00")
      (cons "DATE" (peb-tb-or (MSPL-Get-Str data "TBDATE") "07-MAY-2026"))
      (cons "DRN" "M.H") (cons "CHK" "YEA")
      (cons "LL_ROOF"  (peb-tb-or (MSPL-Get-Str data "LIVEROOF")  "0.57"))
      (cons "LL_FRAME" (peb-tb-or (MSPL-Get-Str data "LIVEFRAME") "0.57"))
      (cons "WIND"     (peb-tb-or (peb-num-only (MSPL-Get-Str data "WINDSPEED")) "135"))
      (cons "EXPOSURE" (peb-tb-or (MSPL-Get-Str data "EXPOSURE") "B"))
      (cons "COLL"     "0")
      (cons "SNOW"     (peb-tb-snow (MSPL-Get-Str data "SNOW")))
      (cons "SEISMIC"  (peb-tb-zone (MSPL-Get-Str data "SEISMIC")))
      (cons "TEMP"     "-")
      (cons "RAIN"     (peb-tb-or (MSPL-Get-Str data "RAIN") "120"))
      (cons "CODE"     (peb-tb-or (MSPL-Get-Str data "DESIGNCODE") "MBMA 2006"))
      (cons "PROJECT"  (peb-tb-or (MSPL-Get-Str data "PROJECT") "STRUCTURE TYPE REFERENCE SET"))
      (cons "CUSTOMER" (peb-tb-or (MSPL-Get-Str data "CLIENT") "MAIMAAR - INTERNAL"))
      (cons "ADDR"
        (strcat "Lahore Office\\P238, First Floor, Lalazar Commercial Area,\\P"
                "Raiwind Road, Lahore, Pakistan\\PWeb: www.maimaargroup.com\\PCell : +(92-300) 807 4007"))
      (cons "QUOTE"    (peb-tb-or (MSPL-Get-Str data "PROPOSAL_FULL") "MSPL-26-000"))
      (cons "BLDGNO"   "01")
      (cons "BLDGNAME" "")
      (cons "IDENTICAL" "1")
      (cons "DRGTITLE" "CONSTRUCTION DETAILS")
      (cons "SCALE"    "N.T.S.")
      (cons "SHEETSIZE" "A1")
      (cons "SHEETNO"  "PRO-01-D")))
  (setq *PEB-TB-SIZEH* (min tbStripH (* tbStripW 1.6)))   ; keep content readable, flush strip, gap in middle
  (peb-titleblock-mammut tbStripX tbFrmB tbStripW tbStripH tbData)
  (setq *PEB-TB-SIZEH* nil)
  ;; border flush with the title block on top/bottom/right (strict rule)
  (draw-border -2500.0
               (+ tbFrmB (* 480.0 *PEB-TEXT-SCALE*))
               (- (+ tbStripX tbStripW) (* 480.0 *PEB-TEXT-SCALE*))
               (- tbFrmT (* 480.0 *PEB-TEXT-SCALE*)))
  (princ))

(defun peb-section-from-file (path / prev-last prev-max-x e new-set offset)
  ;; ── Pre-draw: capture state of the drawing before our entities ──
  (setq prev-last (entlast))
  ;; the frame must wrap THIS sheet, not every sheet drawn so far (see
  ;; peb-frame-and-titleblock).  Same marker the tiler already uses.
  (setq *PEB-SHEET-MARK* prev-last)           ;; nil if drawing is empty
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
  (peb-tile-place prev-last prev-max-x)   ; left→right tile, fixed gap, no box overlap

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
