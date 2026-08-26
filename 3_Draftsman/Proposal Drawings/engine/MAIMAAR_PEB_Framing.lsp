;; ============================================================================
;;  MAIMAAR_PEB_Framing.lsp  —  ROOF FRAMING plan + STEEL FRAMING ELEVATIONS
;; ----------------------------------------------------------------------------
;;  ROOF FRAMING (top view): building outline + main frames (rafters across the
;;  width at each bay grid) + purlins (along the length at ~1.5 m rows) + ridge +
;;  roof X cross-bracing in the braced bays + FALL arrows w/ slope ratio + roof
;;  accessories (SURFACE=ROOF skylights/vents, roof monitor band).  Matches the
;;  Maimaar approval-drawing "ROOF FRAMING".
;;
;;  STEEL FRAMING ELEVATIONS (side + end): the bare structural skeleton of each
;;  wall — base plates + I-columns + eave strut / rafter profile (gable / mono /
;;  flat / butterfly per STYPE) + girts + wall X-bracing + grid bubbles + eave &
;;  bay dims.  Derived from the SAME data file as the Column Layout Plan; it is
;;  the long-wall / end-wall view of the rigid frame the Section draws in cross.
;;  Distinct from the Wall Elevation (which carries sheeting/openings).
;;
;;  Load AFTER Standard/Section/Plan (reuses peb-parse-mod-expression, slope-denom,
;;  peb-braced-bays, peb-col-web-depth, grid-bubble, peb-dim-height-stretch,
;;  peb-fmt-expr, peb-comma, txt/txt-bold, MSPL-Get-*, peb-tile-place, peb-tb-or).
;;  All mm.  Entries: (peb-framing-from-file ...) and (peb-roof-framing-from-file ...).
;; ============================================================================

(defun peb-fr-stations (expr total / lst cum out)
  (setq lst (peb-parse-mod-expression expr))
  (if (or (null lst) (= (length lst) 0))
    (list 0.0 total)
    (progn (setq cum 0.0 out (list 0.0))
      (foreach s lst (setq cum (+ cum s)) (setq out (append out (list cum)))) out)))

;; a simple FALL arrow from (x,y0) toward (x,y1) with a head + slope ratio text.
(defun peb-fr-fall (x y0 y1 slopeD / dir hb prev)
  (setq prev (getvar "CLAYER") dir (if (> y1 y0) 1.0 -1.0) hb 350.0)
  (setvar "CLAYER" "ARROWS")
  (command "_.LINE" (list x y0) (list x y1) "")
  (command "_.LINE" (list x y1) (list (- x hb) (- y1 (* dir hb))) "")
  (command "_.LINE" (list x y1) (list (+ x hb) (- y1 (* dir hb))) "")
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (+ x (* 700 *PEB-TEXT-SCALE*)) (/ (+ y0 y1) 2.0))
       (* 240 *PEB-TEXT-SCALE*) 0 (strcat "1:" (rtos slopeD 2 0)))
  (setvar "CLAYER" prev))

(defun peb-draw-roof-framing (data ox oy / len wid slopeD bayPts purlSp nRows i x y
                              prev cnt pre psurf pat pw mark midY j bubGap bubR
                              stype mgGables mgGableW mgRid mgVal base hiNSW mgi k
                              loB hiB ry vy fx wgrid bx0 bx1 by0 by1 nPan panH)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (atof (peb-tb-or (MSPL-Get-Str data "SLOPE") "10")))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  ;; owner 7-Jul: set drawing scale from building size (parity with the other sheets)
  (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ (max len wid 1.0) 45000.0))) *PEB-DIM-SCALE* *PEB-TEXT-SCALE*)
  (setq bayPts (peb-fr-stations (MSPL-Get-Str data "BAYEXPR") len))
  (setq midY (+ oy (/ wid 2.0)) prev (getvar "CLAYER"))

  ;; building outline / eave lines
  (setvar "CLAYER" "STRUCTURE")
  (command "_.RECTANG" (list ox oy) (list (+ ox len) (+ oy wid)))
  ;; main frames (rafters in plan) at each bay grid, across the width
  (foreach g bayPts
    (command "_.LINE" (list (+ ox g) oy) (list (+ ox g) (+ oy wid)) ""))
  ;; purlins along the length at ~1.5 m rows across the width
  (setvar "CLAYER" "PURLINS")
  (setq purlSp 1500.0 nRows (fix (+ 0.5 (/ wid purlSp))))
  (if (< nRows 2) (setq nRows 2))
  (setq i 1)
  (while (< i nRows)
    (setq y (+ oy (* (/ wid (float nRows)) i)))
    (command "_.LINE" (list ox y) (list (+ ox len) y) "")
    (setq i (1+ i)))
  ;; ── RIDGE / VALLEY lines + FALL arrows — by STRUCTURE TYPE ──────────
  ;; Registers with the Roof Sheeting Plan.  Reference-verified labels (real
  ;; Maimaar/Mammut approval DXFs): ridge = "RIDGE LINE" (dash-dot), valley =
  ;; "VALLEY GUTTER" (dash-dot, never "VALLEY LINE"); slope = the "1:NN" ratio
  ;; tag drawn by peb-fr-fall (Maimaar convention).  Roof monitors carry NO
  ;; text label in any reference, so none is emitted here.
  (setq stype (strcase (peb-tb-or (MSPL-Get-Str data "STYPE") "CS")))
  (cond
    ;; ---- MULTI-GABLE: N ridge lines + (N-1) valley gutters ----
    ((= stype "MG")
     (setq mgGables (MSPL-Get-Int data "NUMGABLES"))
     (if (or (null mgGables) (< mgGables 2)) (setq mgGables 2))
     (setq mgGableW (/ wid (float mgGables)) mgRid '() mgVal '() mgi 0)
     (while (< mgi mgGables)
       (setq base (* mgi mgGableW))
       (setq mgRid (append mgRid (list (+ base (/ mgGableW 2.0)))))
       (if (< mgi (1- mgGables)) (setq mgVal (append mgVal (list (+ base mgGableW)))))
       (setq mgi (1+ mgi)))
     (setvar "CLAYER" "RIDGE")
     (foreach ry mgRid (command "_.LINE" (list ox (+ oy ry)) (list (+ ox len) (+ oy ry)) ""))
     (setvar "CLAYER" "GRID")
     (foreach vy mgVal (command "_.LINE" (list ox (+ oy vy)) (list (+ ox len) (+ oy vy)) ""))
     (setvar "CLAYER" "TEXT")
     (foreach ry mgRid
       (txt "ML" (list (+ ox (* len 0.02)) (+ oy ry (* 300 *PEB-TEXT-SCALE*)))
            (* 240 *PEB-TEXT-SCALE*) 0 "RIDGE LINE"))
     (foreach vy mgVal
       (txt "ML" (list (+ ox (* len 0.72)) (+ oy vy (* 300 *PEB-TEXT-SCALE*)))
            (* 240 *PEB-TEXT-SCALE*) 0 "VALLEY GUTTER"))
     ;; falls: each ridge crest down to its two neighbours (valley or eave)
     (foreach fx (list (* len 0.25) (* len 0.75))
       (setq k 0)
       (foreach ry mgRid
         (setq loB (if (= k 0) 0.0 (nth (1- k) mgVal))
               hiB (if (< k (length mgVal)) (nth k mgVal) wid))
         (peb-fr-fall (+ ox fx) (+ oy ry) (+ oy (+ loB (* (- ry loB) 0.18))) slopeD)
         (peb-fr-fall (+ ox fx) (+ oy ry) (+ oy (- hiB (* (- hiB ry) 0.18))) slopeD)
         (setq k (1+ k)))))
    ;; ---- BUTTERFLY: central valley gutter, falls both eaves -> centre ----
    ((= stype "BF")
     (setvar "CLAYER" "GRID")
     (command "_.LINE" (list ox midY) (list (+ ox len) midY) "")
     (setvar "CLAYER" "TEXT")
     (txt "MC" (list (+ ox (* len 0.5)) (+ midY (* 400 *PEB-TEXT-SCALE*)))
          (* 240 *PEB-TEXT-SCALE*) 0 "VALLEY GUTTER")
     (foreach fx (list (* len 0.25) (* len 0.75))
       (peb-fr-fall (+ ox fx) (+ oy (* wid 0.06)) (+ oy (* wid 0.44)) slopeD)
       (peb-fr-fall (+ ox fx) (+ oy (* wid 0.94)) (+ oy (* wid 0.56)) slopeD)))
    ;; ---- MONO / SINGLE-SLOPE / LEAN-TO: no ridge, one-way fall ----
    ((member stype '("SS" "LT" "CC"))
     (setq hiNSW (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data "RA_MONO_HIGH") "")) "*NSW*"))
     (setvar "CLAYER" "TEXT")
     (txt "MC" (list (+ ox (* len 0.5)) (+ oy (* wid 0.5))) (* 300 *PEB-TEXT-SCALE*) 0
          (if (= stype "LT") "LEAN-TO ROOF" "SINGLE SLOPE ROOF"))
     (foreach fx (list (* len 0.25) (* len 0.75))
       (if hiNSW
         (peb-fr-fall (+ ox fx) (+ oy (* wid 0.10)) (+ oy (* wid 0.90)) slopeD)   ; high NSW -> low FSW
         (peb-fr-fall (+ ox fx) (+ oy (* wid 0.90)) (+ oy (* wid 0.10)) slopeD)))) ; high FSW -> low NSW
    ;; ---- FLAT: no ridge; inward drain arrows to centre ----
    ((= stype "FR")
     (setvar "CLAYER" "TEXT")
     (txt "MC" (list (+ ox (* len 0.5)) (+ midY (* 400 *PEB-TEXT-SCALE*))) (* 300 *PEB-TEXT-SCALE*) 0 "FLAT ROOF")
     (foreach fx (list (* len 0.25) (* len 0.75))
       (peb-fr-fall (+ ox fx) (+ oy (* wid 0.06)) (+ oy (* wid 0.42)) slopeD)
       (peb-fr-fall (+ ox fx) (+ oy (* wid 0.94)) (+ oy (* wid 0.58)) slopeD)))
    ;; ---- GABLE (CS / MS / RC / default): central ridge, falls ridge -> both eaves ----
    (T
     (setvar "CLAYER" "RIDGE")
     (command "_.LINE" (list ox midY) (list (+ ox len) midY) "")
     (setvar "CLAYER" "TEXT")
     (txt "ML" (list (+ ox (* len 0.02)) (+ midY (* 300 *PEB-TEXT-SCALE*)))
          (* 240 *PEB-TEXT-SCALE*) 0 "RIDGE LINE")
     (foreach fx (list (* len 0.25) (* len 0.75))
       (peb-fr-fall (+ ox fx) midY (+ oy (* wid 0.12)) slopeD)
       (peb-fr-fall (+ ox fx) midY (+ oy (* wid 0.88)) slopeD))))

  ;; ── ROOF CROSS-BRACING, IN PANELS (owner 26-Aug) ───────────────────────────
  ;; "Roof Framing Plan must have the bracings in PARTS as per the engineering rule."
  ;;
  ;; It used to draw ONE X spanning the braced bay from eave to eave — a single
  ;; diagonal ~30 m long, which is not how roof bracing is built.  Real roof bracing
  ;; is panelised: a run of X panels between the two frames, each panel roughly
  ;; SQUARE, so the diagonals sit near 45 degrees and actually work as bracing.
  ;;
  ;; PANEL COUNT IS A FUNCTION OF THE BUILDING WIDTH (owner 26-Aug: "No. of roof
  ;; bracing crosses must be based on the engineering rules — develop the rules
  ;; based on width of building").
  ;;
  ;; It uses the SAME width division the end-wall columns use, peb-ew-auto-cols:
  ;; aim for ~6.25 m a panel and hold every panel inside 6.0-6.5 m.  Two reasons
  ;; that is the right divisor rather than a fresh number:
  ;;   * it is already the engine's engineering rule for dividing a width, so the
  ;;     bracing cannot disagree with the end-wall framing about the same building;
  ;;   * the panel NODES then land on the very grid lines the sheets letter (A..F
  ;;     on B-03), which is where a brace should be connected.
  ;; 30480 wide -> 5 panels;  13716 -> 3.  An earlier cut divided by the bay length
  ;; instead, which made the panel count depend on the bay spacing rather than the
  ;; width.
  ;; (This is the ROOF plane; the COLUMN LAYOUT plan carries the WALL bracing via
  ;; peb-draw-bracing.)
  (vl-catch-all-apply (function (lambda ()
    (setq prev (getvar "CLAYER"))
    (setvar "CLAYER" "CROSS")
    (foreach b (peb-braced-bays bayPts)
      (setq bx0 (+ ox (nth b bayPts))
            bx1 (+ ox (nth (1+ b) bayPts))
            nPan (vl-catch-all-apply (function (lambda () (peb-ew-auto-cols wid))))
            nPan (if (and (numberp nPan) (> nPan 0)) nPan 1)
            panH (/ wid (float nPan))
            k    0)
      (while (< k nPan)
        (setq by0 (+ oy (* k panH)) by1 (+ oy (* (1+ k) panH)))
        (command "_.LINE" (list bx0 by0) (list bx1 by1) "")
        (command "_.LINE" (list bx0 by1) (list bx1 by0) "")
        (setq k (1+ k))))
    (setvar "CLAYER" prev))))

  ;; FALL arrows (ridge -> each eave) at a few stations
  (foreach fx (list (* len 0.25) (* len 0.75))
    (peb-fr-fall (+ ox fx) midY (+ oy (* wid 0.12)) slopeD)
    (peb-fr-fall (+ ox fx) midY (+ oy (* wid 0.88)) slopeD))

  ;; roof accessories: SURFACE=ROOF placements (skylights/vents) as small marks
  (setq cnt (atoi (peb-tb-or (MSPL-Get-Str data "PL_COUNT") "0")) i 1)
  (while (<= i cnt)
    (setq pre   (strcat "PL" (itoa i) "_")
          psurf (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "SURFACE")) ""))
          pat   (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "AT")) "0"))
          pw    (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "WIDTH")) "0"))
          mark  (peb-tb-or (MSPL-Get-Str data (strcat pre "MARK")) ""))
    (if (and (= psurf "ROOF") (> pw 0.0))
      (progn
        (setvar "CLAYER" "OPEN")
        (command "_.RECTANG" (list (+ ox pat (- (/ pw 2.0))) (- midY (/ pw 2.0)))
                             (list (+ ox pat (/ pw 2.0)) (+ midY (/ pw 2.0))))
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (+ ox pat) midY) (* 240 *PEB-TEXT-SCALE*) 0 mark)))
    (setq i (1+ i)))

  ;; bay spacing chain (verbatim IF) + title
  (if (and (boundp 'peb-fmt-expr) (vl-string-search "@" (peb-tb-or (MSPL-Get-Str data "BAYEXPR") "")))
    (progn
      (vl-catch-all-apply (function (lambda ()
        (peb-dim-h-stretch ox (+ ox len) (+ oy wid (* 900 *PEB-DIM-SCALE*))
                           (peb-fmt-expr (MSPL-Get-Str data "BAYEXPR"))))))))
  ;; grid bubbles — numbers (top) + letters A/B at the eaves (owner 7-Jul, parity with other sheets)
  (setq bubGap (* 3500 *PEB-TEXT-SCALE*) bubR (if *PEB-BUBRAD* *PEB-BUBRAD* (* 620 *PEB-TEXT-SCALE*)) j 1)
  (foreach g bayPts
    (setvar "CLAYER" "GRID")
    (command "_.LINE" (list (+ ox g) (+ oy wid)) (list (+ ox g) (+ oy wid bubGap)) "")
    (grid-bubble (+ ox g) (+ oy wid bubGap bubR) (itoa j) "D")
    (setq j (1+ j)))
  (setvar "CLAYER" "GRID")
  (command "_.LINE" (list ox oy) (list (- ox bubGap) oy) "")
  ;; WIDTH LETTERS MUST MATCH THE OTHER SHEETS (rulebook 4B.8).  These were hardcoded
  ;; "A" and "B" — the two eave lines — while the plan, section and both elevations
  ;; letter the MERGED width grid (width modules + end-wall columns).  On B-03 that
  ;; grid runs A..F, so the far eave is F, not B, and this sheet was naming the same
  ;; line differently from every other sheet in the set.
  (setq wgrid (vl-catch-all-apply (function (lambda () (peb-fr-ew-stations data wid "LEW")))))
  (if (or (vl-catch-all-error-p wgrid) (not (listp wgrid)) (< (length wgrid) 2)) (setq wgrid nil))
  (grid-bubble (- ox bubGap bubR) oy "A" "R")
  (command "_.LINE" (list ox (+ oy wid)) (list (- ox bubGap) (+ oy wid)) "")
  (grid-bubble (- ox bubGap bubR) (+ oy wid)
               (if wgrid (chr (+ 65 (1- (length wgrid)))) "B") "R")
  ;; blue title (below the roof) + shared title block
  (setvar "CLAYER" "TEXT")
  (setvar "CECOLOR" "5")
  (txt-bold "MC" (list (+ ox (/ len 2.0)) (- oy (* 3200 *PEB-TEXT-SCALE*)))
            ;; plain height — txt-bold applies TEXT-SCALE itself (rulebook 4B.2).
            ;; (* 450 TS) scaled by TS SQUARED, so this title grew with the building.
            300.0 0 "ROOF FRAMING PLAN")
  (setvar "CECOLOR" "BYLAYER")
  (setvar "CLAYER" prev)
  (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data "ROOF FRAMING PLAN")))))

;; ============================================================================
;;  STEEL FRAMING ELEVATIONS  (side walls NSW/FSW + end walls LEW/REW)
;; ----------------------------------------------------------------------------
;;  The bare structural frame — NO sheeting — as seen looking square-on at each
;;  wall.  Reuses the Column-Layout-Plan geometry (bayPts along the length,
;;  ewStations across the width, roof profile per STYPE, braced bays, column web
;;  depth).  Draws: base line + base plates, I-columns, eave strut / rafter
;;  profile (gable peak / mono slope / flat / butterfly valley), girts, wall
;;  X-bracing, grid bubbles, a per-wall title, an eave-height dim and a bay dim
;;  chain.  Matches the Maimaar approval "SIDE WALL FRAMING" / "END WALL FRAMING".
;; ----------------------------------------------------------------------------

;; STYPE -> roof-profile family for the elevation.
;;   G = gable (ridge peak)      M = mono / single-slope      F = flat      B = butterfly (valley)
(defun peb-fr-rooftype (stype)
  (cond ((member stype '("SS" "LT" "CC")) "M")
        ((= stype "FR") "F")
        ((= stype "BF") "B")
        (T "G")))

;; grid-letter for the Nth (0-based) end-wall column: 0->A .. 25->Z, 26->AA ...
(defun peb-fr-letter (i / hi)
  (if (< i 26)
    (chr (+ 65 i))
    (progn (setq hi (- (/ i 26) 1))
      (strcat (chr (+ 65 hi)) (chr (+ 65 (- i (* 26 (1+ hi)))))))))

;; Parse a wall's open-wall condition ("Open up to 3.950 M for Brickwork (By Others), Rest Height Sheeted")
;; -> the brick/open height in mm. "Fully Sheeted" / blank / no "up to" -> 0 (sheeted to floor).
(defun peb-fr-openwall-ht (s / u p q ch c num)
  (setq u (strcase (if s s "")))
  (if (not (wcmatch u "*UP TO*")) 0.0
    (progn
      (setq p (vl-string-search "UP TO " u) num "")
      (if p
        (progn
          (setq q (substr u (+ p 7)) ch 1)
          (while (<= ch (strlen q))
            (setq c (substr q ch 1))
            (cond ((or (wcmatch c "#") (= c ".")) (setq num (strcat num c) ch (1+ ch)))
                  ((and (= c " ") (= num "")) (setq ch (1+ ch)))     ; skip leading spaces
                  (T (setq ch (1+ (strlen q))))))                    ; stop once the number ends
          (* (atof num) 1000.0))
        0.0))))

;; Height (mm) of the RAISED grid-segment condition inside a COMPOUND OW_<surf> string (owner 29-Jul writes
;; "... + Open up to X M ... between Grids ..."). The main wall uses the FIRST condition (peb-fr-openwall-ht);
;; the raised band uses the "between Grids" segment's height. Returns 0 when there is no such segment.
(defun peb-fr-seg-openwall-ht (s / u p k lastk seg)
  (setq u (strcase (if s s "")) p (vl-string-search "BETWEEN GRID" u))
  (if p
    (progn
      (setq k 0 lastk -1)
      (while (and (setq k (vl-string-search " + " s k)) (< k p))
        (setq lastk k k (+ k 3)))
      (setq seg (if (>= lastk 0) (substr s (+ lastk 4)) s))
      (peb-fr-openwall-ht seg))
    0.0))

;; spans from an IF expression, scaled to close EXACTLY on `total` (parity with
;; the Plan's ewStations handling); always returns (0.0 ... total).
(defun peb-fr-scaled-stations (expr total / lst sum sc acc out)
  (setq lst (peb-parse-mod-expression expr))
  (if (or (null lst) (= (length lst) 0))
    (list 0.0 total)
    (progn
      (setq sum 0.0) (foreach s lst (setq sum (+ sum s)))
      (setq sc (if (> sum 0.0) (/ total sum) 1.0) acc 0.0 out (list 0.0))
      (foreach s lst (setq acc (+ acc (* s sc))) (setq out (append out (list acc))))
      out)))

;; END-WALL COLUMN STATIONS — the width-module (main frame) lines MERGED with the
;; end-wall column lines, which is exactly what the plan grids and letters.
;; Explicit IF spacing (BP_EW_LEFT/RIGHT_SPACING) wins; otherwise the shared auto
;; rule (peb-ew-auto-stations) applies.
;;
;; This used to read MODEXPR alone, so on a CLEAR SPAN — whose width module is a
;; single 1@<wid> — the elevation drew two corner columns and nothing between,
;; while the plan lettered A..D off its own rule.  The two sheets described the
;; same wall differently and the girts looked unsupported across the full span.
;; One leg of a wall X-brace, drawn at TRUE linetype size (see the caller).
(defun peb-fr-brace-line (x0 y0 x1 y1 es)
  (entmake (list '(0 . "LINE") (cons 8 "CROSS") (cons 48 es)
                 (cons 10 (list x0 y0 0.0)) (cons 11 (list x1 y1 0.0)))))

(defun peb-fr-ew-stations (data wid surf / expr st ew out)
  (setq st (peb-fr-scaled-stations (peb-tb-or (MSPL-Get-Str data "MODEXPR") "") wid))
  (setq expr (peb-tb-or (if (= surf "LEW") (MSPL-Get-Str data "EWLEXPR")
                                           (MSPL-Get-Str data "EWREXPR")) ""))
  (setq ew (if (/= expr "")
             (peb-fr-scaled-stations expr wid)
             (if (boundp 'peb-ew-auto-stations) (peb-ew-auto-stations wid) nil)))
  (setq out st)
  (foreach s ew
    (if (not (vl-some (function (lambda (p) (< (abs (- p s)) 1.0))) out))
      (setq out (append out (list s)))))
  (vl-sort out '<))

;; Top-of-steel Y at width-station x for an END wall (LEW/REW).  faceLen = wid.
;;   G: peak at centre (rise above eave)      B: valley at centre (eaves high)
;;   M: linear from low eave to high eave      F: flat at eave
;; eaveLo/eaveHi are absolute eave heights above base; rise = (wid/2)/slope.
(defun peb-fr-topy (x faceLen base eaveH eaveHi eaveLo rise rtype hiSide / half)
  (setq half (/ faceLen 2.0))
  (cond
    ((= rtype "G") (+ base eaveH (* rise (- 1.0 (/ (abs (- x half)) half)))))
    ((= rtype "B") (+ base eaveH (* rise (/ (abs (- x half)) half))))
    ((= rtype "M") (if hiSide
                     (+ base eaveLo (* (- eaveHi eaveLo) (/ x faceLen)))
                     (+ base eaveHi (- 0 (* (- eaveHi eaveLo) (/ x faceLen))))))
    (T (+ base eaveH))))

;; A horizontal dimension CHAIN drawn from primitives (batch-safe, independent of
;; the wall's base Y — unlike peb-dim-h-stretch which pins its def-points to y=0).
;; A small OPEN-V arrowhead drawn from primitives (owner 29-Jul: match the plan/section
;; dimension arrows, which use DIMBLK "_OPEN"). tip = the station point; dir +1 draws ">"
;; (tip on the right, barbs to the left), dir -1 draws "<" (tip on the left, barbs to the right).
(defun peb-fr-dimarrow (x y dir aL aW)
  (setvar "CLAYER" "DIMENSIONS")
  (command "_.LINE" (list x y) (list (- x (* dir aL)) (+ y aW)) "")
  (command "_.LINE" (list x y) (list (- x (* dir aL)) (- y aW)) ""))

(defun peb-fr-dimchain (ox y stations / ts i x0 x1 aL aW)
  (if (< (length stations) 2) nil
    (progn
      (setq ts (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0)
            aL (* 300 ts)                    ; open-arrow length along the dim line
            aW (* 95 ts)                     ; half-width -> slim open "V" like DIMBLK _OPEN
            i  0)
      (setvar "CLAYER" "DIMENSIONS")
      (command "_.LINE" (list (+ ox (car stations)) y)
                        (list (+ ox (last stations)) y) "")
      ;; each bay = its own dim segment: OPEN arrowheads at both ends, so interior grids get
      ;; the "> <" meeting pair exactly like the plan/section chains (no more tick slashes).
      (while (< (1+ i) (length stations))
        (setq x0 (+ ox (nth i stations)) x1 (+ ox (nth (1+ i) stations)))
        (peb-fr-dimarrow x0 y -1 aL aW)      ; "<" tip at bay start
        (peb-fr-dimarrow x1 y  1 aL aW)      ; ">" tip at bay end
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (/ (+ x0 x1) 2.0) (- y (* 340 ts))) (* 230 ts) 0
             (peb-comma (rtos (- (nth (1+ i) stations) (nth i stations)) 2 0)))
        (setq i (1+ i))))))

(defun peb-draw-framing-elev (surf ox oy data / len wid slopeD stype rtype
                              eaveH eaveHi eaveLo brickH hiName hiSide wallEave
                              faceLen stations isEnd base colhw rise ridgeRise
                              i x g yTop pts cx prev braced b x0 x1 y0 y1 lbl bubGap
                              gsp gy cnt pre psurf pat pw mark expr ov noteY
                              ewHang hangHt cnt2 gbase
                              p0 p1 sdx sdy slen ux uy nx ny pdep npl jj tt px py rdep owText
                              bc bx0 by0 bx1 by1 owU isRcc hEnt
                              rbOn rbFrom rbTo rbFloor rbBase nLen ewGrid ewRaised rx0 rx1 gridNum plateY hasR gbaseR ltsE
                              ewMain webD rdepC rdepL gg d0 d1)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (slope-denom (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        stype  (strcase (peb-tb-or (MSPL-Get-Str data "STYPE") "CS"))
        brickH (atof (peb-tb-or (MSPL-Get-Str data "BRICKHEIGHT") "0")))
  (setq eaveH (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT")
                      (peb-tb-or (MSPL-Get-Str data "EAVE_HEIGHT")
                        (peb-tb-or (MSPL-Get-Str data "BP_EAVE_HEIGHT") "6000")))))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (if (<= eaveH 0.0)  (setq eaveH 6000.0))
  (if (= stype "ACS") (setq stype "CS"))     ; arched plans mirror straight geometry
  (if (= stype "AMS") (setq stype "MS"))
  (setq rtype  (peb-fr-rooftype stype)
        isEnd  (and (member surf '("LEW" "REW")) T)
        hiName (strcase (peb-tb-or (MSPL-Get-Str data "RA_MONO_HIGH") ""))
        eaveLo eaveH
        eaveHi (+ eaveH (/ wid slopeD))
        ridgeRise (/ (/ wid 2.0) slopeD)
        rise   ridgeRise
        prev   (getvar "CLAYER")
        base   oy)
  (setq hiSide (if (vl-string-search "FSW" hiName) T nil))   ; end-wall mono: high at x=wid (FSW side)
  ;; this SIDE wall's own eave height (mono => one wall high, one low)
  (cond
    ((/= rtype "M") (setq wallEave eaveH))
    ((= surf "NSW") (setq wallEave (if (vl-string-search "NSW" hiName) eaveHi eaveLo)))
    ((= surf "FSW") (setq wallEave (if (vl-string-search "FSW" hiName) eaveHi eaveLo)))
    (T              (setq wallEave eaveH)))
  ;; stations + face length
  (if isEnd
    (setq faceLen wid
          stations (peb-fr-ew-stations data wid surf))
    (setq faceLen len
          stations (peb-fr-scaled-stations (peb-tb-or (MSPL-Get-Str data "BAYEXPR") "") len)))
  ;; ── COLUMN FLANGE WIDTH IN ELEVATION (owner 26-Aug) ────────────────────────
  ;; What you see edge-on in a wall elevation is the column's FLANGE, and a flange
  ;; is a flange — it does not grow with the span the way the web depth does.
  ;;   END wall  : 200 mm   ("normally columns flanges are also 200mm")
  ;;   SIDE wall : 300 mm   ("for side framing 300 flange showing is okay")
  ;;
  ;; It used to be derived from the web depth (0.46 x D, halved), so on a 30 m
  ;; building the columns were drawn 506 mm wide — flanges fatter than the 200 mm
  ;; rafter web beside them, which is what made the rafter look too thin.
  (setq colhw (if isEnd 100.0 150.0))

  ;; 1. base / foundation line
  (setvar "CLAYER" "GROUND")
  (command "_.LINE" (list (- ox (* 0.03 faceLen)) base)
                    (list (+ ox faceLen (* 0.03 faceLen)) base) "")

  ;; 2. I-columns (slender rectangle) + base plates at every station.
  ;; HANGING COLUMNS (owner 25-Jul): when THIS end wall's frame is "Main Frame with Hanging Columns",
  ;; the INTERIOR end-wall columns do NOT run to FFL — they HANG from the rafter down to the open-wall
  ;; line (BP_EW_LEFT/RIGHT_BRICK_HT: the "Open up to X M" height) and carry NO base plate; only the two
  ;; CORNER columns keep the full height + base plate. LEW/REW read their OWN frame + open height (owner:
  ;; the two end walls may differ). Side walls + non-hanging end walls are UNCHANGED (ewHang nil).
  (setq ewHang (and isEnd
                    (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data
                                (if (= surf "LEW") "EW_LEFT_FRAME" "EW_RIGHT_FRAME")) ""))
                             "*HANGING*")))
  (setq hangHt (if ewHang
                 (atof (peb-tb-or (MSPL-Get-Str data
                          (if (= surf "LEW") "BP_EW_LEFT_BRICK_HT" "BP_EW_RIGHT_BRICK_HT")) "0"))
                 0.0))
  ;; end-wall rafter depth per station, computed ONCE (see the column loop)
  (setq ewMain (and isEnd
                    (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data
                                (if (= surf "LEW") "EW_LEFT_FRAME" "EW_RIGHT_FRAME")) ""))
                             "*MAIN*")))
  (setq webD (vl-catch-all-apply (function (lambda () (peb-col-web-depth wid)))))
  (if (or (not (numberp webD)) (< webD 200.0)) (setq webD 600.0))
  ;; BEARING FRAME rafter = a 200 mm web (owner 26-Aug: "End Walls Rafter must have
  ;; less depth, normally it is only 200mm web").  It is a fixed section, not a
  ;; fraction of the column — a bearing end wall carries only its own cladding.
  ;; MAIN FRAME keeps the tapered rigid-frame depth off the column web.
  (setq rdepC 200.0 rdepL nil)
  (if isEnd
    (foreach gg stations
      (setq rdepL (append rdepL
        (list (if ewMain
                (* webD (+ 0.55 (* 0.45 (if (> faceLen 1.0)
                                          (/ (abs (- gg (/ faceLen 2.0))) (/ faceLen 2.0))
                                          0.0))))
                rdepC))))))
  (setq cnt2 (length stations) i 0)
  ;; ---- RAISED BASE (owner 29-Jul): grids [rbFrom..rbTo] rest on an existing RCC floor at +rbFloor; an RCC
  ;; pedestal + brick carry the existing pillars up to +rbBase where the STEEL columns start (shorter cols).
  ;; Side-wall station i => length-grid (i+1); an END wall raises wholesale if its own length-grid is in the
  ;; range (LEW = grid 1, REW = grid nLen). rx0..rx1 = the raised horizontal band of THIS wall (relative ox). ----
  (setq rbOn    (= (peb-tb-or (MSPL-Get-Str data "BP_RAISED_ON") "0") "1")
        rbFrom  (atoi (peb-tb-or (MSPL-Get-Str data "BP_RAISED_GRID_FROM") "0"))
        rbTo    (atoi (peb-tb-or (MSPL-Get-Str data "BP_RAISED_GRID_TO") "0"))
        rbFloor (atof (peb-tb-or (MSPL-Get-Str data "BP_RAISED_FLOOR") "0"))
        rbBase  (atof (peb-tb-or (MSPL-Get-Str data "BP_RAISED_BASE") "0")))
  (if (or (not rbOn) (<= rbBase 0.0)) (setq rbOn nil))
  (setq nLen (length (peb-fr-scaled-stations (peb-tb-or (MSPL-Get-Str data "BAYEXPR") "") len)))
  (if (< nLen 2) (setq nLen 2))
  (setq ewGrid   (cond ((= surf "LEW") 1) ((= surf "REW") nLen) (T 0))
        ewRaised (and rbOn isEnd (>= ewGrid rbFrom) (<= ewGrid rbTo))
        hasR nil rx0 0.0 rx1 0.0)
  (if rbOn
    (if isEnd
      (if ewRaised (setq hasR T rx0 0.0 rx1 faceLen))            ; whole end wall sits on the existing floor
      (if (and (>= rbTo 1) (<= rbFrom nLen) (<= rbFrom rbTo))    ; SIDE wall: raised band grid rbFrom..rbTo
        (setq hasR T
              rx0 (if (<= rbFrom 1) 0.0 (nth (- rbFrom 1) stations))     ; existing building starts AT grid rbFrom
              rx1 (if (>= rbTo nLen) faceLen (nth (- rbTo 1) stations)))))) ; ...and ends AT grid rbTo (owner: "b/w GL 4-5 only")
  ;; existing RCC structure under the raised band: top-of-floor line at +rbFloor, the building's vertical
  ;; edges (step up from FFL), an RCC pedestal + brick band (rbFloor -> rbBase, where the steel base lands),
  ;; and two labels. Drawn BEFORE the columns so the steel overdraws it.
  (if (and rbOn hasR)
    (progn
      ;; existing floor line + the existing building's outer vertical edges (0 -> steel base)
      (setvar "CLAYER" "GROUND")
      (command "_.LINE" (list (+ ox rx0) (+ base rbFloor)) (list (+ ox rx1) (+ base rbFloor)) "")
      (if (> rx0 1.0)             (command "_.LINE" (list (+ ox rx0) base) (list (+ ox rx0) (+ base rbBase)) ""))
      (if (< rx1 (- faceLen 1.0)) (command "_.LINE" (list (+ ox rx1) base) (list (+ ox rx1) (+ base rbBase)) ""))
      ;; BRICK MASONRY infill across the existing zone (FFL -> steel base): brick colour + AR-B816
      (peb-fr-material-fill (+ ox rx0) base (- rx1 rx0) rbBase 0.0 "Brickwork (By Others)")
      ;; RCC PILLARS (existing, extended by the pedestal) at each RAISED column station — grey concrete over
      ;; the brick, so the elevation reads "RCC pillars with brick masonry between" (owner 29-Jul).
      (setq bc 0)
      (foreach g stations
        (if (or (and (not isEnd) (>= (1+ bc) rbFrom) (<= (1+ bc) rbTo)) (and isEnd ewRaised))
          (peb-fr-rcc-pillar (+ ox g) base (+ base rbBase) (max 250.0 (* colhw 1.5))))
        (setq bc (1+ bc)))
      ;; steel-base (pedestal-top) line
      (setvar "CLAYER" "STRUCTURE")
      (command "_.LINE" (list (+ ox rx0) (+ base rbBase)) (list (+ ox rx1) (+ base rbBase)) "")
      (setvar "CLAYER" "TEXT")
      (peb-fr-masked-label (+ ox (* 0.5 (+ rx0 rx1))) (+ base (* rbFloor 0.45)) (* 255 *PEB-TEXT-SCALE*)
           (strcat "EXISTING RCC BUILDING (BY OTHERS) - 1st FLOOR +" (rtos (/ rbFloor 1000.0) 2 3)))
      (peb-fr-masked-label (+ ox (* 0.5 (+ rx0 rx1))) (+ base rbBase (* 330.0 *PEB-TEXT-SCALE*)) (* 235 *PEB-TEXT-SCALE*)
           (strcat "RCC PILLARS + BRICK INFILL TO +" (rtos (/ rbBase 1000.0) 2 3) " (STEEL BASE)"))))
  (foreach g stations
    (setq x    (+ ox g)
          ;; column top = roof line MINUS the rafter depth = the underside of the
          ;; rafter's bottom flange (owner 26-Aug, both frame types).
          yTop (if isEnd
                 (- (peb-fr-topy g faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                    (if rdepL (nth i rdepL) rdepC))
                 (+ base wallEave))
          ;; b = CORNER column? (first or last station); gridNum = this column's LENGTH grid; y0 = its foot.
          ;; RAISED grids start on the existing floor at +rbBase (short column); else hanging line; else FFL.
          b       (or (= i 0) (= i (1- cnt2)))
          gridNum (if isEnd ewGrid (1+ i))
          y0      (cond ((and rbOn (>= gridNum rbFrom) (<= gridNum rbTo)) (+ base rbBase))
                        ((and ewHang (not b) (> hangHt 0.0)) (+ base hangHt))
                        (T base))
          plateY  y0)
    (setvar "CLAYER" "COLUMNS")
    (command "_.RECTANG" (list (- x colhw) y0) (list (+ x colhw) yTop))
    ;; base plate wherever the column lands on a foundation OR on the RCC pedestal (raised) — NOT on a
    ;; hanging-column interior foot (that lands on the carrying beam, no plate).
    (if (not (and ewHang (not b) (> hangHt 0.0)
                  (not (and rbOn (>= gridNum rbFrom) (<= gridNum rbTo)))))
      (progn
        (setvar "CLAYER" "PLATES")
        (command "_.RECTANG" (list (- x (* colhw 1.7)) (- plateY (* colhw 0.28)))
                             (list (+ x (* colhw 1.7)) (+ plateY (* colhw 0.28))))
        ;; anchor bolts under the base plate (ref: the "III" ticks) — two short stubs
        (setvar "CLAYER" "BOLTS")
        (command "_.LINE" (list (- x (* colhw 0.75)) (- plateY (* colhw 0.28)))
                          (list (- x (* colhw 0.75)) (- plateY (* colhw 1.05))) "")
        (command "_.LINE" (list (+ x (* colhw 0.75)) (- plateY (* colhw 0.28)))
                          (list (+ x (* colhw 0.75)) (- plateY (* colhw 1.05))) "")))
    (setq i (1+ i)))
  ;; carrying beam the hanging columns land on (at the open-wall line, corner->corner) + a label
  (if (and ewHang (> hangHt 0.0) (>= cnt2 2))
    (progn
      (setvar "CLAYER" "STRUCTURE")
      (command "_.LINE" (list (+ ox (car stations)) (+ base hangHt))
                        (list (+ ox (last stations)) (+ base hangHt)) "")
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (+ ox (/ faceLen 2.0)) (+ base hangHt (* 380 *PEB-TEXT-SCALE*)))
           (* 240 *PEB-TEXT-SCALE*) 0 "HANGING COLUMNS (NO BASE PLATE)")))

  ;; 3. eave strut + rafter / roof profile
  (if isEnd
    (progn
      ;; polyline through each column top + the ridge/valley apex at mid-span
      (setq pts '())
      (foreach g stations
        (setq pts (append pts (list (list (+ ox g)
                    (peb-fr-topy g faceLen base eaveH eaveHi eaveLo rise rtype hiSide))))))
      (if (member rtype '("G" "B"))
        (progn
          (setq cx (/ faceLen 2.0))
          (if (not (vl-some '(lambda (p) (< (abs (- (- (car p) ox) cx)) 1.0)) pts))
            (setq pts (append pts (list (list (+ ox cx)
                        (peb-fr-topy cx faceLen base eaveH eaveHi eaveLo rise rtype hiSide))))))))
      (setq pts (vl-sort pts '(lambda (a b) (< (car a) (car b)))))
      ;; rafter as a DOUBLE-line member (top = roof line through the column tops; bottom = underside offset
      ;; perpendicular into the roof by the member depth), so it reads as a beam, not a hairline (ref).
      (setvar "CLAYER" "STRUCTURE")
      ;; rdep MUST stay assigned — the FLANGE BRACES further down still measure off
      ;; it.  Dropping it (an earlier attempt did) left it nil, the brace arithmetic
      ;; errored, and the ENTIRE end-wall draw unwound silently: no error, no
      ;; geometry, no sheet.
      (setq rdep (* 380.0 *PEB-TEXT-SCALE*) i 0)
      ;; The rafter UNDERSIDE is offset by the depth at each end instead — tapered
      ;; for a main frame, constant for a bearing frame — so it lands exactly on the
      ;; column tops, which are set to the same depth below the roof line.
      (while (< (1+ i) (length pts))
        (setq p0 (nth i pts) p1 (nth (1+ i) pts)
              sdx (- (car p1) (car p0)) sdy (- (cadr p1) (cadr p0))
              slen (sqrt (+ (* sdx sdx) (* sdy sdy)))
              d0 (if ewMain
                   (* webD (+ 0.55 (* 0.45 (if (> faceLen 1.0)
                       (/ (abs (- (- (car p0) ox) (/ faceLen 2.0))) (/ faceLen 2.0)) 0.0))))
                   rdepC)
              d1 (if ewMain
                   (* webD (+ 0.55 (* 0.45 (if (> faceLen 1.0)
                       (/ (abs (- (- (car p1) ox) (/ faceLen 2.0))) (/ faceLen 2.0)) 0.0))))
                   rdepC))
        (command "_.LINE" p0 p1 "")
        (if (> slen 1.0)
          (command "_.LINE"
            (list (+ (car p0) (* (/ sdy slen) d0)) (- (cadr p0) (* (/ sdx slen) d0)))
            (list (+ (car p1) (* (/ sdy slen) d1)) (- (cadr p1) (* (/ sdx slen) d1))) ""))
        (setq i (1+ i)))
      ;; (Proposal Drawing: member marks + sizes/spacings omitted — those are set by design at approval stage.)
      ;; PURLINS (owner 28-Jul, ref: END WALL FRAMING shows the Z-purlins as short ticks sitting ON the
      ;; rafter). Walk each rafter segment at ~1.5 m and drop a short perpendicular stub on the OUTBOARD side.
      (setvar "CLAYER" "PURLINS")
      (vl-catch-all-apply (function (lambda () (setvar "CECOLOR" "RGB:135,135,135"))))  ; purlins/sag rods GREY (DWG)
      ;; visible purlin depth in the FRAMING view = the 60 mm lip (owner 28-Jul: Z200 web is edge-on; the
      ;; lip/flange is what shows). Real 60 mm (NOT text-scaled) so it stays true across building sizes.
      (setq pdep 60.0 i 0)
      (while (< (1+ i) (length pts))
        (setq p0 (nth i pts) p1 (nth (1+ i) pts)
              sdx (- (car p1) (car p0)) sdy (- (cadr p1) (cadr p0))
              slen (sqrt (+ (* sdx sdx) (* sdy sdy))))
        (if (> slen 1.0)
          (progn
            (setq ux (/ sdx slen) uy (/ sdy slen) nx (- uy) ny ux   ; nx,ny = outboard/up normal
                  npl (fix (/ slen 1500.0)) jj 1)
            (while (<= jj npl)
              (setq tt (/ (* jj 1500.0) slen)
                    px (+ (car p0) (* tt sdx)) py (+ (cadr p0) (* tt sdy)))
              (command "_.LINE" (list px py) (list (+ px (* nx pdep)) (+ py (* ny pdep))) "")
              (setq jj (1+ jj)))))
        (setq i (1+ i)))
      ;; SAG RODS — a zig-zag between the purlin tops down each rafter segment (ref: the yellow diagonals).
      (setvar "CLAYER" "PURLINS")
      (setq i 0)
      (while (< (1+ i) (length pts))
        (setq p0 (nth i pts) p1 (nth (1+ i) pts)
              sdx (- (car p1) (car p0)) sdy (- (cadr p1) (cadr p0))
              slen (sqrt (+ (* sdx sdx) (* sdy sdy))))
        (if (> slen 3000.0)
          (progn
            (setq ux (/ sdx slen) uy (/ sdy slen) nx (- uy) ny ux
                  npl (fix (/ slen 1500.0)) jj 1)
            (while (< jj npl)
              (setq tt (/ (* jj 1500.0) slen)
                    px (+ (car p0) (* tt sdx)) py (+ (cadr p0) (* tt sdy))
                    tt (/ (* (1+ jj) 1500.0) slen))
              (command "_.LINE" (list (+ px (* nx pdep)) (+ py (* ny pdep)))
                                (list (+ (car p0) (* tt sdx)) (+ (cadr p0) (* tt sdy))) "")
              (setq jj (1+ jj)))))
        (setq i (1+ i)))
      (setvar "CECOLOR" "BYLAYER")
      ;; FLANGE BRACES — a short dashed diagonal at each KNEE (rafter end at a corner column). Proposal Drawing:
      ;; brace LINES shown, no "FB" mark.
      (setvar "CLAYER" "CROSS")
      (if (>= (length pts) 2)
        (progn
          (setq p0 (car pts) p1 (nth 1 pts))                         ; left knee
          (command "_.LINE" (list (car p0) (cadr p0))
                            (list (+ (car p0) (* (- (car p1) (car p0)) 0.14)) (- (cadr p0) 1000.0)) "")
          (setq p0 (last pts) p1 (nth (- (length pts) 2) pts))       ; right knee
          (command "_.LINE" (list (car p0) (cadr p0))
                            (list (+ (car p0) (* (- (car p1) (car p0)) 0.14)) (- (cadr p0) 1000.0)) "")))
      ;; HAUNCH at each knee — a tapered soffit from the corner-column inner face up to the rafter underside
      ;; ~2.6 m inboard, deepening the rafter-column junction (ref: the tapered knee). Segments taken
      ;; left->right (as pts is sorted) so the perpendicular underside offset always drops BELOW the rafter.
      (setvar "CLAYER" "STRUCTURE")
      (if (>= (length pts) 3)
        (progn
          (setq p0 (nth 0 pts) p1 (nth 1 pts)
                sdx (- (car p1) (car p0)) sdy (- (cadr p1) (cadr p0)) slen (sqrt (+ (* sdx sdx) (* sdy sdy))))
          (if (> slen 2600.0)
            (progn
              (setq tt (/ 2600.0 slen) px (+ (car p0) (* tt sdx)) py (+ (cadr p0) (* tt sdy)))
              (command "_.LINE" (list (+ (car p0) colhw) (- (cadr p0) (* 780.0 *PEB-TEXT-SCALE*)))
                                (list (+ px (* (/ sdy slen) rdep)) (- py (* (/ sdx slen) rdep))) "")))
          (setq p1 (nth (1- (length pts)) pts) p0 (nth (- (length pts) 2) pts)
                sdx (- (car p1) (car p0)) sdy (- (cadr p1) (cadr p0)) slen (sqrt (+ (* sdx sdx) (* sdy sdy))))
          (if (> slen 2600.0)
            (progn
              (setq tt (/ (- slen 2600.0) slen) px (+ (car p0) (* tt sdx)) py (+ (cadr p0) (* tt sdy)))
              (command "_.LINE" (list (- (car p1) colhw) (- (cadr p1) (* 780.0 *PEB-TEXT-SCALE*)))
                                (list (+ px (* (/ sdy slen) rdep)) (- py (* (/ sdx slen) rdep))) "")))))
      ;; ridge tick (gable) at the peak
      (if (= rtype "G")
        (progn (setvar "CLAYER" "RIDGE")
          (command "_.LINE" (list (+ ox (/ faceLen 2.0)) (+ base eaveH))
                            (list (+ ox (/ faceLen 2.0)) (+ base eaveH rise)) ""))))
    (progn
      ;; SIDE wall: horizontal eave strut (this wall's eave) + dashed ridge above (gable)
      (setvar "CLAYER" "STRUCTURE")
      (command "_.LINE" (list ox (+ base wallEave)) (list (+ ox faceLen) (+ base wallEave)) "")
      (if (= rtype "G")
        (progn (setvar "CLAYER" "RIDGE")
          (command "_.LINE" (list ox (+ base wallEave rise))
                            (list (+ ox faceLen) (+ base wallEave rise)) "")))))

  ;; 4. girts + sheeting-base + brick/RCC hatch + condition label — drawn PER WALL-FACE SEGMENT (owner 29-Jul)
  ;; so a RAISED band (on the existing floor) starts its brick/sheeting from +rbBase, not FFL. See
  ;; peb-fr-wallface. gy = the ABSOLUTE eave top for the girts (roof is continuous; side walls use wallEave,
  ;; end walls the low eave eaveH). gbase = sheeting-base height (hanging end wall = hangHt; else OW_<surf>).
  (setq owText (peb-tb-or (MSPL-Get-Str data (strcat "OW_" surf)) "")
        gbase  (if (and ewHang (> hangHt 0.0)) hangHt (peb-fr-openwall-ht owText))
        gbaseR (peb-fr-seg-openwall-ht owText)                 ; raised-band brick height (compound OW segment)
        gy     (if isEnd (+ base eaveH) (+ base wallEave)))
  (if (<= gbaseR 0.0) (setq gbaseR gbase))                    ; no per-segment condition -> reuse the main height
  ;; On the RAISED band the RCC pedestal + brick already carry UP TO the steel base (+rbBase); the brick that
  ;; remains ABOVE the base = (brick-height-from-FFL - rbBase), clamped to 0. When the brick just reaches the
  ;; base (235 REW: 3.95 brick on a 3.95 base) that is 0 -> SHEETED above (owner 29-Jul: "sheeting above 3950,
  ;; not brick"). A wall with brick taller than the base still shows the excess as brick, then sheeted.
  (cond
    ((and rbOn ewRaised)                                       ; whole END wall sits on the existing floor
      (peb-fr-wallface ox faceLen (+ base rbBase) (max 0.0 (- gbase rbBase)) colhw owText gy nil))
    ((and rbOn hasR (not isEnd))                               ; SIDE wall: normal [0..rx0] + raised [rx0..rx1] (+ tail)
      (if (> rx0 1.0)
        (peb-fr-wallface ox rx0 base gbase colhw owText gy (and ewHang (> hangHt 0.0))))
      (peb-fr-wallface (+ ox rx0) (- rx1 rx0) (+ base rbBase) (max 0.0 (- gbaseR rbBase)) colhw owText gy nil)
      (if (< rx1 (- faceLen 1.0))
        (peb-fr-wallface (+ ox rx1) (- faceLen rx1) base gbase colhw owText gy nil)))
    ((and (wcmatch (strcase owText) "*OPEN*") (<= gbase 100.0))  ; FULL-HEIGHT OPEN for access — frame only + label
      (setvar "CLAYER" "TEXT")
      (peb-fr-masked-label (+ ox (/ faceLen 2.0)) (+ base (* (if isEnd eaveH wallEave) 0.45)) (* 360 *PEB-TEXT-SCALE*)
           "FULL HEIGHT OPEN FOR ACCESS (BY OTHERS)"))
    (T                                                         ; normal wall — one face at FFL
      (peb-fr-wallface ox faceLen base gbase colhw owText gy (and ewHang (> hangHt 0.0)))))
  ;; (Proposal Drawing: girt/purlin SIZE + SPACING call-outs omitted — set by design at approval stage.)

  ;; 4b. GIRTS UP THE GABLE — end walls only, and only where there is a gable/valley
  ;; triangle above the eave to girt (owner 26-Aug).  See peb-fr-gable-girts.
  (if (and isEnd (member rtype '("G" "B")))
    (vl-catch-all-apply (function (lambda ()
      (peb-fr-gable-girts ox stations faceLen base eaveH eaveHi eaveLo rise rtype hiSide 1400.0)))))

  ;; 5. wall X cross-bracing — SIDE walls only (braced bays). The reference END WALL FRAMING carries NO
  ;; X cross-bracing (it uses girts + purlins + flange braces instead), and X-braces looked wrong crossing
  ;; the open bay below the hanging columns — so end walls skip it (owner 28-Jul, per old reference drawings).
  (setq braced (if isEnd nil
                          (vl-catch-all-apply (function (lambda () (peb-braced-bays stations))))))
  (if (vl-catch-all-error-p braced) (setq braced nil))
  (setvar "CLAYER" "CROSS")
  ;; TRUE-SIZE LINETYPE (owner 26-Aug: "show the bracings as well").  The braces were
  ;; being drawn correctly and then not plotting: layer CROSS carries the DOT linetype,
  ;; and the sheet set leaves LTSCALE at ~84 (the PLAN sheet raises it from 1 and
  ;; peb-std-setup does not put it back), at which the pattern stops rendering and the
  ;; X disappears from the sheet.  Rendered standalone, at LTSCALE 1, the same code
  ;; drew them fine -- which is why this looked like "no bracing is generated".
  ;; Same fix the engine already uses for the ridge line and the crane runway: draw the
  ;; LINE with a PER-ENTITY linetype scale of 1/LTSCALE (DXF 48) so the pattern is a
  ;; true mm size whatever the drawing's global LTSCALE. No global state is touched.
  (setq ltsE (getvar "LTSCALE"))
  (setq ltsE (if (> ltsE 0.0) (/ 1.0 ltsE) 1.0))
  (foreach b braced
    (if (and (numberp b) (>= b 0) (< (1+ b) (length stations)))
      (progn
        (setq x0 (+ ox (nth b stations)) x1 (+ ox (nth (1+ b) stations))
              y0 base
              y1 (min (if isEnd (peb-fr-topy (nth b stations) faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                                 (+ base wallEave))
                      (if isEnd (peb-fr-topy (nth (1+ b) stations) faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                                 (+ base wallEave))))
        (peb-fr-brace-line x0 y0 x1 y1 ltsE)
        (peb-fr-brace-line x0 y1 x1 y0 ltsE))))

  ;; 6. framed openings on THIS wall (jamb posts + header + mark)
  (setq cnt (atoi (peb-tb-or (MSPL-Get-Str data "PL_COUNT") "0")) i 1)
  (while (<= i cnt)
    (setq pre   (strcat "PL" (itoa i) "_")
          psurf (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "SURFACE")) ""))
          pat   (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "AT")) "0"))
          pw    (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "WIDTH")) "0"))
          mark  (peb-tb-or (MSPL-Get-Str data (strcat pre "MARK")) ""))
    (if (and (= psurf surf) (> pw 0.0))
      (progn
        (setvar "CLAYER" "OPEN")
        (command "_.RECTANG" (list (+ ox pat (- (/ pw 2.0))) base)
                             (list (+ ox pat (/ pw 2.0)) (+ base (* eaveH 0.72))))
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (+ ox pat) (+ base (* eaveH 0.80))) (* 230 *PEB-TEXT-SCALE*) 0 mark)))
    (setq i (1+ i)))

  ;; 7. grid bubbles below the base (side = numbers, end = letters) + stalk. Bigger bubble (owner 28-Jul,
  ;; KMFoods ref) via a local *PEB-BUBRAD* bump, restored after so other sheets are unaffected.
  (setq bubGap (* 2100 *PEB-TEXT-SCALE*) i 0 ov *PEB-BUBRAD* *PEB-BUBRAD* (* 900 *PEB-TEXT-SCALE*))
  (foreach g stations
    (setq lbl (if isEnd (peb-fr-letter i) (itoa (1+ i))))
    (setvar "CLAYER" "GRID-LINES")
    (command "_.LINE" (list (+ ox g) base) (list (+ ox g) (- base (* bubGap 0.45))) "")
    (vl-catch-all-apply (function (lambda () (grid-bubble (+ ox g) (- base bubGap) lbl "U"))))
    (setq i (1+ i)))
  (setq *PEB-BUBRAD* ov)

  ;; 8. title — blue + full wall name (owner 7-Jul, consistent with the Wall Elevations sheet)
  (setvar "CLAYER" "TEXT")
  (setvar "CECOLOR" "5")
  (txt-bold "MC" (list (+ ox (/ faceLen 2.0)) (+ base eaveH rise (* 2600 *PEB-TEXT-SCALE*)))
            ;; HEADING SIZE (owner 26-Aug: "Wall Framing Heading must be small in size").
            ;; txt-bold ALREADY multiplies the height by *PEB-TEXT-SCALE*, so the old
            ;; (* 500 *PEB-TEXT-SCALE*) scaled by TEXT-SCALE **SQUARED**.  On a medium
            ;; building TS is about 1 and nobody noticed; on the 122 m shed TS is ~3, so
            ;; the heading came out 9x instead of 3x and ran the full width of the wall.
            ;; Pass the plain height and let txt-bold scale it once.  300, not the
            ;; original 500, because the owner wants it smaller than it was designed.
            300.0 0
            (strcat surf " - "
                    (cond ((= surf "NSW") "NEAR SIDE WALL") ((= surf "FSW") "FAR SIDE WALL")
                          ((= surf "LEW") "LEFT END WALL")  ((= surf "REW") "RIGHT END WALL") (T "WALL"))
                    " FRAMING"))
  (setvar "CECOLOR" "BYLAYER")

  ;; 9. eave-height dim (left) + bay/station dim chain (below the bubbles)
  (vl-catch-all-apply (function (lambda ()
    (peb-dim-height-stretch ox (- ox (* 1500 *PEB-DIM-SCALE*)) base (+ base eaveH)
                            (peb-comma (rtos eaveH 2 0))))))
  (setq noteY (- base bubGap (* 1500 *PEB-DIM-SCALE*)))
  (vl-catch-all-apply (function (lambda () (peb-fr-dimchain ox noteY stations))))
  (setvar "CLAYER" prev)
  (princ))

;; Condition label with an opaque WIPEOUT mask behind it so it reads clearly OVER the brick/RCC hatch
;; (owner 29-Jul: "the brick masonry height text on the hatching is not clearly visible").  A wipeout plots
;; as blank paper (no border when WIPEOUTFRAME 0), hiding the hatch ONLY under the text.  Drawn AFTER the
;; hatch and BEFORE the text, so: hatch < wipeout < text.  Catch-guarded → falls back to plain text if the
;; WIPEOUT command is unavailable headless (no worse than before).
(defun peb-fr-masked-label (cx cy h str / w x0 x1 y0 y1)
  (setq w  (* (max 1 (strlen str)) h 0.66)
        x0 (- cx (* w 0.5) h) x1 (+ cx (* w 0.5) h)
        y0 (- cy (* h 0.95))  y1 (+ cy (* h 0.95)))
  (setvar "WIPEOUTFRAME" 0)   ; no plotted border → the mask is invisible, only the text shows (clean)
  (vl-catch-all-apply (function (lambda ()
    (command "_.WIPEOUT" (list x0 y0) (list x1 y0) (list x1 y1) (list x0 y1) ""))))
  (txt "MC" (list cx cy) h 0 str))

;; Existing RCC pillar in the raised zone of an ELEVATION (owner 29-Jul: "RCC pillars, and between them brick
;; masonry"): a grey concrete column (cx±hw, y0->y1) with a 45° concrete cross-hatch, drawn OVER the brick.
(defun peb-fr-rcc-pillar (cx y0 y1 hw / yy)
  (setvar "CLAYER" "HATCHR")
  (vl-catch-all-apply (function (lambda () (setvar "CECOLOR" "RGB:150,150,150"))))
  (command "_.RECTANG" (list (- cx hw) y0) (list (+ cx hw) y1))
  (setq yy (- y0 (* 2.0 hw)))
  (while (< yy y1)
    (command "_.LINE" (list (- cx hw) (max y0 yy)) (list (+ cx hw) (min y1 (+ yy (* 2.0 hw)))) "")
    (setq yy (+ yy 300.0)))
  (setvar "CECOLOR" "BYLAYER")
  (princ))

;; Masked condition label for a SHEETING-elevation segment (brick/open by others, at height gbase from cy's base).
(defun peb-sh-label (cx cy gbase owText / owU)
  (setq owU (strcase owText))
  (setvar "CLAYER" "TEXT")
  (peb-fr-masked-label cx cy (* 300 *PEB-TEXT-SCALE*)
     (strcat (cond ((wcmatch owU "*ACCESS*")               "OPEN FOR ACCESS (BY OTHERS)")
                   ((wcmatch owU "*PRE-CAST*,*PRECAST*")   "PRE-CAST RCC PANELS (BY OTHERS)")
                   ((wcmatch owU "*RCC*,*R.C.C*,*CONCRETE*") "RCC WALL (BY OTHERS)")
                   ((wcmatch owU "*BLOCK*")                "BLOCKWALL (BY OTHERS)")
                   (T                                      "BRICK WALL (BY OTHERS)"))
             " - H=" (rtos (/ gbase 1000.0) 2 2) " M")))

;; Draw ONE wall-face SEGMENT of a FRAMING elevation: dense girts (sheeted zone) + sheeting-base line +
;; brick/RCC hatch + the condition label. Factored out of peb-draw-framing-elev (owner 29-Jul) so a wall can
;; be drawn in SEGMENTS at DIFFERENT bases — a normal segment at FFL and a RAISED segment sitting on an
;; existing RCC floor start from different `wbase`. [ox0 .. ox0+flen] horizontally; brick from `wbase` up to
;; `wbase+gbase`; girts from there up to `eaveTop-200` (eaveTop is ABSOLUTE — the roof line is continuous, so
;; a raised segment's girts still stop at the true eave). skipBaseLine = T for a hanging-column end wall.
;; ── GIRTS IN THE V (GABLE) PORTION OF AN END WALL (owner 26-Aug) ─────────────
;; "girts must support on the post columns & will not extend till full width, only
;;  till internal post columns based on the slope; the spacing can be adjusted."
;;
;; Below the eave a girt runs the full width — every post reaches it.  Above the
;; eave the wall is a triangle, so a girt only exists where the ROOF is above it:
;; it lands on the innermost posts tall enough to carry it and stops there.  Each
;; level up the gable is therefore shorter than the one below, and once fewer than
;; two posts reach the level nothing more is drawn.
;;
;; All parameters are gg-prefixed on purpose: AutoLISP is dynamically scoped and
;; the caller is mid-way through locals with names like faceLen / stations / rise.
(defun peb-fr-gable-girts (ggOx ggSt ggFace ggBase ggEave ggHi ggLo ggRise ggType ggHiSide ggSp
                           / ggY ggTop ggL ggR ggS ggPdep ggN)
  (setvar "CLAYER" "GIRTS")
  ;; SPACING ADAPTS TO THE TRIANGLE (owner: "the spacing can be adjusted accordingly").
  ;; A fixed 1400 put the first gable girt ABOVE the ridge on a shallow roof — B-01's
  ;; gable rises only 686 mm — so nothing was drawn at all.  Divide the rise instead:
  ;; ggN levels at rise/(ggN+1), where ggN is how many 1400s fit.  A triangle too
  ;; shallow to hold one girt correctly gets none.
  (setq ggN (fix (/ ggRise ggSp)))
  (if (< ggN 1) (setq ggN 0))
  (setq ggPdep 60.0
        ggSp   (if (> ggN 0) (/ ggRise (+ ggN 1.0)) 0.0)
        ggY    (+ ggBase ggEave ggSp))
  (if (<= ggN 0) (setq ggY (+ ggBase ggEave ggRise 1e6)))   ; no room -> loop never runs
  (while
    (progn
      (setq ggL nil ggR nil)
      (foreach ggS ggSt
        (setq ggTop (peb-fr-topy ggS ggFace ggBase ggEave ggHi ggLo ggRise ggType ggHiSide))
        (if (> ggTop (+ ggY 250.0))                    ; this post reaches the level
          (progn (if (null ggL) (setq ggL ggS)) (setq ggR ggS))))
      (and ggL ggR (> (- ggR ggL) 1.0)))               ; ... and at least two do
    (command "_.LINE" (list (+ ggOx ggL) ggY) (list (+ ggOx ggR) ggY) "")
    (command "_.LINE" (list (+ ggOx ggL) (+ ggY ggPdep)) (list (+ ggOx ggR) (+ ggY ggPdep)) "")
    (setq ggY (+ ggY ggSp)))
  (princ))

(defun peb-fr-wallface (ox0 flen wbase gbase colhw owText eaveTop skipBaseLine / gsp pdep i gy owU isRcc hEnt bc bx0 by0 bx1 by1)
  (setvar "CLAYER" "GIRTS")
  (setq gsp 1400.0 pdep 60.0 i 1)
  (while (< (+ wbase gbase (* i gsp)) (- eaveTop 200.0))
    (setq gy (+ wbase gbase (* i gsp)))
    (command "_.LINE" (list ox0 gy) (list (+ ox0 flen) gy) "")
    (command "_.LINE" (list ox0 (+ gy pdep)) (list (+ ox0 flen) (+ gy pdep)) "")
    (setq i (1+ i)))
  (if (> gbase 200.0)
    (progn
      (if (not skipBaseLine)
        (progn (setvar "CLAYER" "GIRTS")
          (command "_.LINE" (list ox0 (+ wbase gbase)) (list (+ ox0 flen) (+ wbase gbase)) "")))
      (setq owU (strcase owText) isRcc (wcmatch owU "*PRE-CAST*,*PRECAST*,*RCC*,*CONCRETE*,*R.C.C*"))
      (if (and (> gbase 500.0) (not (wcmatch owU "*ACCESS*")) (not (wcmatch owU "*GLAZ*")))
        (progn
          (setvar "CLAYER" (if isRcc "HATCHR" "BRICK-WALL"))
          (vl-catch-all-apply (function (lambda () (setvar "CECOLOR" (if isRcc "RGB:150,150,150" "RGB:200,132,96")))))
          (command "_.RECTANG" (list (+ ox0 colhw 40.0) (+ wbase 40.0)) (list (- (+ ox0 flen) colhw 40.0) (+ wbase gbase -40.0)))
          (setq hEnt (entlast))
          (vl-catch-all-apply (function (lambda () (setenv "MaxHatch" "50000000"))))
          (vl-catch-all-apply (function (lambda ()
            (command "_.-HATCH" "_P" (if isRcc "AR-CONC" "AR-B816")
                     (if isRcc (* 120.0 *PEB-TEXT-SCALE*) (* 20.0 *PEB-TEXT-SCALE*)) 0.0 "_S" (entlast) "" ""))))
          (if (and isRcc (eq (entlast) hEnt))                       ; RCC hatch aborted -> manual 45° cross-hatch
            (progn
              (setq bc (- 0.0 gbase))
              (while (< bc flen)
                (setq bx0 (if (>= bc 0.0) bc 0.0) by0 (if (>= bc 0.0) 0.0 (- 0.0 bc))
                      bx1 (if (<= (+ bc gbase) flen) (+ bc gbase) flen) by1 (if (<= (+ bc gbase) flen) gbase (- flen bc)))
                (command "_.LINE" (list (+ ox0 bx0) (+ wbase by0)) (list (+ ox0 bx1) (+ wbase by1)) "")
                (setq bc (+ bc 750.0)))
              (setq bc 0.0)
              (while (< bc (+ flen gbase))
                (setq bx0 (if (<= bc flen) bc flen) by0 (if (<= bc flen) 0.0 (- bc flen))
                      bx1 (if (>= (- bc gbase) 0.0) (- bc gbase) 0.0) by1 (if (>= (- bc gbase) 0.0) gbase bc))
                (command "_.LINE" (list (+ ox0 bx0) (+ wbase by0)) (list (+ ox0 bx1) (+ wbase by1)) "")
                (setq bc (+ bc 750.0)))))
          (setvar "CECOLOR" "BYLAYER")))
      (setvar "CLAYER" "TEXT")
      (peb-fr-masked-label (+ ox0 (/ flen 2.0)) (+ wbase (* gbase 0.42)) (* 300 *PEB-TEXT-SCALE*)
           (strcat (cond ((wcmatch owU "*ACCESS*")               "OPEN FOR ACCESS (BY OTHERS)")
                         ((wcmatch owU "*PRE-CAST*,*PRECAST*")   "PRE-CAST RCC PANELS (BY OTHERS)")
                         ((wcmatch owU "*RCC*,*R.C.C*,*CONCRETE*") "RCC WALL (BY OTHERS)")
                         ((wcmatch owU "*BLOCK*")                "BLOCKWALL (BY OTHERS)")
                         ((wcmatch owU "*GLAZ*")                 "GLAZING (BY OTHERS)")
                         (T                                      "BRICK WALL (BY OTHERS)"))
                   " - H=" (rtos (/ gbase 1000.0) 2 2) " M"))))
  (princ))

;; Brick / RCC material fill for a wall zone (0..faceLen x 0..gbase from base), synced to the wall condition.
;; Brick/Block -> AR-B816 (light-brick colour); Pre-Cast/RCC/Concrete -> AR-CONC aggregate (grey) w/ manual
;; cross-hatch fallback; Access/Glazing/Open -> nothing. Shared by the framing + sheeting elevations. colhw
;; insets the fill from the columns (0 for sheeting = full width).
(defun peb-fr-material-fill (ox base faceLen gbase colhw owText / owU isRcc hEnt bc bx0 by0 bx1 by1)
  (setq owU (strcase owText)
        isRcc (wcmatch owU "*PRE-CAST*,*PRECAST*,*RCC*,*CONCRETE*,*R.C.C*"))
  (if (and (> gbase 500.0) (not (wcmatch owU "*ACCESS*")) (not (wcmatch owU "*GLAZ*")))
    (progn
      (setvar "CLAYER" (if isRcc "HATCHR" "BRICK-WALL"))
      (vl-catch-all-apply (function (lambda () (setvar "CECOLOR" (if isRcc "RGB:150,150,150" "RGB:200,132,96")))))
      (command "_.RECTANG" (list (+ ox colhw 40.0) (+ base 40.0))
                           (list (- (+ ox faceLen) colhw 40.0) (+ base gbase -40.0)))
      (setq hEnt (entlast))
      (vl-catch-all-apply (function (lambda () (setenv "MaxHatch" "50000000"))))
      (vl-catch-all-apply (function (lambda ()
        (command "_.-HATCH" "_P" (if isRcc "AR-CONC" "AR-B816")
                 (if isRcc (* 120.0 *PEB-TEXT-SCALE*) (* 20.0 *PEB-TEXT-SCALE*)) 0.0 "_S" (entlast) "" ""))))
      (if (and isRcc (eq (entlast) hEnt))
        (progn
          (setq bc (- 0.0 gbase))
          (while (< bc faceLen)
            (setq bx0 (if (>= bc 0.0) bc 0.0) by0 (if (>= bc 0.0) 0.0 (- 0.0 bc))
                  bx1 (if (<= (+ bc gbase) faceLen) (+ bc gbase) faceLen)
                  by1 (if (<= (+ bc gbase) faceLen) gbase (- faceLen bc)))
            (command "_.LINE" (list (+ ox bx0) (+ base by0)) (list (+ ox bx1) (+ base by1)) "")
            (setq bc (+ bc 750.0)))
          (setq bc 0.0)
          (while (< bc (+ faceLen gbase))
            (setq bx0 (if (<= bc faceLen) bc faceLen) by0 (if (<= bc faceLen) 0.0 (- bc faceLen))
                  bx1 (if (>= (- bc gbase) 0.0) (- bc gbase) 0.0) by1 (if (>= (- bc gbase) 0.0) gbase bc))
            (command "_.LINE" (list (+ ox bx0) (+ base by0)) (list (+ ox bx1) (+ base by1)) "")
            (setq bc (+ bc 750.0)))))
      (setvar "CECOLOR" "BYLAYER")))
  (princ))

;; SHEETING ELEVATION — the CLAD face of a wall: profiled vertical sheeting over the sheeted zone, brick/RCC
;; by others below (synced to the wall condition), the gable/eave outline, openings, grid bubbles + dim chain.
(defun peb-draw-sheeting-elev (surf ox oy data / len wid slopeD stype rtype eaveH eaveHi eaveLo hiName hiSide
                              wallEave faceLen stations isEnd base rise ridgeRise i g x yTop pts cx prev lbl
                              bubGap ov gbase owText sp sx cnt pre psurf pat pw noteY owU
                              rbOn rbFrom rbTo rbFloor rbBase nLen ewGrid ewRaised rx0 rx1 hasR gbaseR bc sbase sgb)
  (setq len (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (slope-denom (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        stype (strcase (peb-tb-or (MSPL-Get-Str data "STYPE") "CS")))
  (setq eaveH (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT")
                     (peb-tb-or (MSPL-Get-Str data "EAVE_HEIGHT")
                       (peb-tb-or (MSPL-Get-Str data "BP_EAVE_HEIGHT") "6000")))))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (if (<= eaveH 0.0) (setq eaveH 6000.0))
  (if (= stype "ACS") (setq stype "CS"))
  (if (= stype "AMS") (setq stype "MS"))
  (setq rtype (peb-fr-rooftype stype)
        isEnd (and (member surf '("LEW" "REW")) T)
        hiName (strcase (peb-tb-or (MSPL-Get-Str data "RA_MONO_HIGH") ""))
        eaveLo eaveH eaveHi (+ eaveH (/ wid slopeD))
        ridgeRise (/ (/ wid 2.0) slopeD) rise ridgeRise
        prev (getvar "CLAYER") base oy)
  (setq hiSide (if (vl-string-search "FSW" hiName) T nil))
  (cond ((/= rtype "M") (setq wallEave eaveH))
        ((= surf "NSW") (setq wallEave (if (vl-string-search "NSW" hiName) eaveHi eaveLo)))
        ((= surf "FSW") (setq wallEave (if (vl-string-search "FSW" hiName) eaveHi eaveLo)))
        (T (setq wallEave eaveH)))
  (if isEnd
    (setq faceLen wid
          ;; same merged end-wall stations the FRAMING elevation uses, so the two
          ;; elevations and the plan all letter the identical columns.
          stations (peb-fr-ew-stations data wid surf))
    (setq faceLen len
          stations (peb-fr-scaled-stations (peb-tb-or (MSPL-Get-Str data "BAYEXPR") "") len)))
  (setq owText (peb-tb-or (MSPL-Get-Str data (strcat "OW_" surf)) "")
        gbase (peb-fr-openwall-ht owText))
  ;; RAISED BASE (owner 29-Jul) — mirror the framing so the sheeting elevations SYNC: grids [rbFrom..rbTo]
  ;; sit on an existing RCC floor; the raised band's brick/sheeting starts from +rbBase.
  (setq rbOn    (= (peb-tb-or (MSPL-Get-Str data "BP_RAISED_ON") "0") "1")
        rbFrom  (atoi (peb-tb-or (MSPL-Get-Str data "BP_RAISED_GRID_FROM") "0"))
        rbTo    (atoi (peb-tb-or (MSPL-Get-Str data "BP_RAISED_GRID_TO") "0"))
        rbFloor (atof (peb-tb-or (MSPL-Get-Str data "BP_RAISED_FLOOR") "0"))
        rbBase  (atof (peb-tb-or (MSPL-Get-Str data "BP_RAISED_BASE") "0")))
  (if (or (not rbOn) (<= rbBase 0.0)) (setq rbOn nil))
  (setq nLen (length (peb-fr-scaled-stations (peb-tb-or (MSPL-Get-Str data "BAYEXPR") "") len)))
  (if (< nLen 2) (setq nLen 2))
  (setq ewGrid   (cond ((= surf "LEW") 1) ((= surf "REW") nLen) (T 0))
        ewRaised (and rbOn isEnd (>= ewGrid rbFrom) (<= ewGrid rbTo))
        gbaseR   (peb-fr-seg-openwall-ht owText)
        hasR nil rx0 0.0 rx1 0.0)
  (if (<= gbaseR 0.0) (setq gbaseR gbase))
  (if rbOn
    (if isEnd
      (if ewRaised (setq hasR T rx0 0.0 rx1 faceLen))
      (if (and (>= rbTo 1) (<= rbFrom nLen) (<= rbFrom rbTo))
        (setq hasR T
              rx0 (if (<= rbFrom 1) 0.0 (nth (- rbFrom 1) stations))       ; existing building AT grid rbFrom..rbTo
              rx1 (if (>= rbTo nLen) faceLen (nth (- rbTo 1) stations))))))  ; (owner: "b/w GL 4-5 only")
  ;; brick that remains ABOVE the steel base on the raised band = (brick-from-FFL - rbBase), clamped to 0.
  ;; 0 -> sheeted above the base (owner 29-Jul: "sheeting above 3950, not brick").
  (if (and rbOn hasR) (setq gbaseR (max 0.0 (- gbaseR rbBase))))
  ;; ground line
  (setvar "CLAYER" "GROUND")
  (command "_.LINE" (list (- ox (* 0.03 faceLen)) base) (list (+ ox faceLen (* 0.03 faceLen)) base) "")
  ;; roof / eave OUTLINE
  (setvar "CLAYER" "STRUCTURE")
  (if isEnd
    (progn
      (setq pts '())
      (foreach g stations
        (setq pts (append pts (list (list (+ ox g) (peb-fr-topy g faceLen base eaveH eaveHi eaveLo rise rtype hiSide))))))
      (if (member rtype '("G" "B"))
        (progn (setq cx (/ faceLen 2.0))
          (if (not (vl-some '(lambda (p) (< (abs (- (- (car p) ox) cx)) 1.0)) pts))
            (setq pts (append pts (list (list (+ ox cx) (peb-fr-topy cx faceLen base eaveH eaveHi eaveLo rise rtype hiSide))))))))
      (setq pts (vl-sort pts '(lambda (a b) (< (car a) (car b)))) i 0)
      (while (< (1+ i) (length pts)) (command "_.LINE" (nth i pts) (nth (1+ i) pts) "") (setq i (1+ i))))
    (command "_.LINE" (list ox (+ base wallEave)) (list (+ ox faceLen) (+ base wallEave)) ""))
  ;; two vertical end edges (base -> roof)
  (command "_.LINE" (list ox base)
                    (list ox (if isEnd (peb-fr-topy 0.0 faceLen base eaveH eaveHi eaveLo rise rtype hiSide) (+ base wallEave))) "")
  (command "_.LINE" (list (+ ox faceLen) base)
                    (list (+ ox faceLen) (if isEnd (peb-fr-topy faceLen faceLen base eaveH eaveHi eaveLo rise rtype hiSide) (+ base wallEave))) "")
  ;; existing raised RCC structure (mirror the framing): brick masonry infill + RCC PILLARS at the grid lines
  (if (and rbOn hasR)
    (progn
      (setvar "CLAYER" "GROUND")
      (command "_.LINE" (list (+ ox rx0) (+ base rbFloor)) (list (+ ox rx1) (+ base rbFloor)) "")
      (if (> rx0 1.0)             (command "_.LINE" (list (+ ox rx0) base) (list (+ ox rx0) (+ base rbBase)) ""))
      (if (< rx1 (- faceLen 1.0)) (command "_.LINE" (list (+ ox rx1) base) (list (+ ox rx1) (+ base rbBase)) ""))
      (peb-fr-material-fill (+ ox rx0) base (- rx1 rx0) rbBase 0.0 "Brickwork (By Others)")
      (setq bc 0)
      (foreach g stations
        (if (or (and (not isEnd) (>= (1+ bc) rbFrom) (<= (1+ bc) rbTo)) (and isEnd ewRaised))
          (peb-fr-rcc-pillar (+ ox g) base (+ base rbBase) 300.0))
        (setq bc (1+ bc)))
      (setvar "CLAYER" "STRUCTURE")
      (command "_.LINE" (list (+ ox rx0) (+ base rbBase)) (list (+ ox rx1) (+ base rbBase)) "")
      (setvar "CLAYER" "TEXT")
      (peb-fr-masked-label (+ ox (* 0.5 (+ rx0 rx1))) (+ base (* rbFloor 0.45)) (* 250 *PEB-TEXT-SCALE*)
           (strcat "EXISTING RCC BUILDING (BY OTHERS) - 1st FLOOR +" (rtos (/ rbFloor 1000.0) 2 3)))
      (peb-fr-masked-label (+ ox (* 0.5 (+ rx0 rx1))) (+ base rbBase (* 320.0 *PEB-TEXT-SCALE*)) (* 230 *PEB-TEXT-SCALE*)
           (strcat "RCC PILLARS + BRICK INFILL TO +" (rtos (/ rbBase 1000.0) 2 3) " (STEEL BASE)"))))
  ;; FULL-HEIGHT OPEN FOR ACCESS (owner 29-Jul: LEW is "not fully sheeted but FULL OPEN ... full height till
  ;; peak, open for access") — NO sheeting, NO brick; just the frame outline (already drawn) + an OPEN label.
  (if (and (wcmatch (strcase owText) "*OPEN*") (<= gbase 100.0) (not (and rbOn hasR)))
    (progn
      (setvar "CLAYER" "TEXT")
      (peb-fr-masked-label (+ ox (/ faceLen 2.0)) (+ base (* eaveH 0.45)) (* 360 *PEB-TEXT-SCALE*)
           "FULL HEIGHT OPEN FOR ACCESS (BY OTHERS)"))
    (progn
      ;; brick / RCC by others below the sheeting line — PER SEGMENT (normal at FFL, raised band at +rbBase)
      (if (and rbOn hasR)
        (progn
          (if (> rx0 1.0) (peb-fr-material-fill ox base rx0 gbase 0.0 owText))
          (peb-fr-material-fill (+ ox rx0) (+ base rbBase) (- rx1 rx0) gbaseR 0.0 owText)
          (if (< rx1 (- faceLen 1.0)) (peb-fr-material-fill (+ ox rx1) base (- faceLen rx1) gbase 0.0 owText)))
        (peb-fr-material-fill ox base faceLen gbase 0.0 owText))
      ;; sheeting-base line(s)
      (setvar "CLAYER" "STRUCTURE")
      (if (and rbOn hasR)
        (progn
          (if (and (> rx0 1.0) (> gbase 100.0)) (command "_.LINE" (list ox (+ base gbase)) (list (+ ox rx0) (+ base gbase)) ""))
          (command "_.LINE" (list (+ ox rx0) (+ base rbBase gbaseR)) (list (+ ox rx1) (+ base rbBase gbaseR)) "")
          (if (and (< rx1 (- faceLen 1.0)) (> gbase 100.0)) (command "_.LINE" (list (+ ox rx1) (+ base gbase)) (list (+ ox faceLen) (+ base gbase)) "")))
        (if (> gbase 100.0) (command "_.LINE" (list ox (+ base gbase)) (list (+ ox faceLen) (+ base gbase)) "")))
      ;; PROFILED SHEETING — vertical lines from the (segment) sheeting base up to the roof/eave, ~333 mm apart
      (setvar "CLAYER" "CLADDING")
      (setq sp 333.0 sx sp)
      (while (< sx faceLen)
        (setq yTop (if isEnd (peb-fr-topy sx faceLen base eaveH eaveHi eaveLo rise rtype hiSide) (+ base wallEave))
              sgb  (if (and rbOn hasR (>= sx rx0) (< sx rx1)) (+ base rbBase gbaseR) (+ base gbase)))
        (if (> yTop (+ sgb 100.0))
          (command "_.LINE" (list (+ ox sx) sgb) (list (+ ox sx) yTop) ""))
        (setq sx (+ sx sp)))
      ;; condition label(s) — per segment
      (if (and rbOn hasR)
        (progn
          (if (and (> rx0 1.0) (> gbase 200.0)) (peb-sh-label (+ ox (* 0.5 rx0)) (+ base (* gbase 0.42)) gbase owText))
          (if (> gbaseR 200.0) (peb-sh-label (+ ox (* 0.5 (+ rx0 rx1))) (+ base rbBase (* gbaseR 0.42)) gbaseR owText)))
        (if (> gbase 200.0) (peb-sh-label (+ ox (/ faceLen 2.0)) (+ base (* gbase 0.42)) gbase owText)))))
  ;; openings (doors / windows) — a clear rectangle cut in the sheeting
  (setq cnt (atoi (peb-tb-or (MSPL-Get-Str data "PL_COUNT") "0")) i 1)
  (while (<= i cnt)
    (setq pre (strcat "PL" (itoa i) "_")
          psurf (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "SURFACE")) ""))
          pat (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "AT")) "0"))
          pw (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "WIDTH")) "0")))
    (if (and (= psurf surf) (> pw 0.0))
      (progn (setvar "CLAYER" "OPEN")
        (command "_.RECTANG" (list (+ ox pat (- (/ pw 2.0))) base) (list (+ ox pat (/ pw 2.0)) (+ base (* eaveH 0.72))))))
    (setq i (1+ i)))
  ;; grid bubbles + title + dim chain (mirror the framing)
  (setq bubGap (* 2100 *PEB-TEXT-SCALE*) i 0 ov *PEB-BUBRAD* *PEB-BUBRAD* (* 900 *PEB-TEXT-SCALE*))
  (foreach g stations
    (setq lbl (if isEnd (peb-fr-letter i) (itoa (1+ i))))
    (setvar "CLAYER" "GRID-LINES")
    (command "_.LINE" (list (+ ox g) base) (list (+ ox g) (- base (* bubGap 0.45))) "")
    (vl-catch-all-apply (function (lambda () (grid-bubble (+ ox g) (- base bubGap) lbl "U"))))
    (setq i (1+ i)))
  (setq *PEB-BUBRAD* ov)
  (setvar "CLAYER" "TEXT") (setvar "CECOLOR" "5")
  (txt-bold "MC" (list (+ ox (/ faceLen 2.0)) (+ base eaveH rise (* 2600 *PEB-TEXT-SCALE*))) 300.0 0                     ; plain height — txt-bold applies TEXT-SCALE itself
            (strcat surf " - "
                    (cond ((= surf "NSW") "NEAR SIDE WALL") ((= surf "FSW") "FAR SIDE WALL")
                          ((= surf "LEW") "LEFT END WALL") ((= surf "REW") "RIGHT END WALL") (T "WALL"))
                    " SHEETING"))
  (setvar "CECOLOR" "BYLAYER")
  (setq noteY (- base bubGap (* 1500 *PEB-DIM-SCALE*)))
  (vl-catch-all-apply (function (lambda () (peb-fr-dimchain ox noteY stations))))
  (setvar "CLAYER" prev)
  (princ))

;; Draw a SET of elevations (framing or sheeting) for the given walls, stacked, with a title block.
;; kind = "F" (framing) | "S" (sheeting). Shared by the all / side / end variants — the pipeline splits
;; side vs end onto their OWN sheets for BIG buildings so each elevation prints large + legible (owner 28-Jul).
(defun peb-draw-elev-set (data walls kind title / wid len slopeD eaveH ts step i surf faceMax)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (slope-denom (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        eaveH  (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT")
                       (peb-tb-or (MSPL-Get-Str data "EAVE_HEIGHT")
                         (peb-tb-or (MSPL-Get-Str data "BP_EAVE_HEIGHT") "6000")))))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (if (<= eaveH 0.0)  (setq eaveH 6000.0))
  ;; ── TEXT / DIM / BUBBLE SCALE RULE (owner 26-Aug) ─────────────────────────
  ;; "overall size of end frames is too small & dim bubbles and text too big —
  ;;  expand the framing plan accordingly; the dim text should be proportionate."
  ;;
  ;; Scale from the WIDEST DRAWING ON THIS SHEET, not from the building.
  ;; peb-elev-from-file sizes text off max(LENGTH, WIDTH) — the building's longest
  ;; dimension — whichever wall the sheet actually shows.  So the END WALL sheet of
  ;; a 122 x 30 m shed got text sized for 122 m and drew it on a 30 m elevation:
  ;; bubbles and dimensions came out ~4x oversized, and because ZOOM Extents then
  ;; has to fit that text, the frame itself was squeezed small.
  ;;   end-wall set  (LEW/REW) -> the drawn width is WIDTH
  ;;   side-wall set (NSW/FSW) -> the drawn width is LENGTH
  ;;   all four on one sheet   -> the larger of the two, as before
  (setq faceMax
    (cond ((not (vl-some (function (lambda (w) (member w '("NSW" "FSW")))) walls)) wid)
          ((not (vl-some (function (lambda (w) (member w '("LEW" "REW")))) walls)) len)
          (T (max len wid))))
  (if (<= faceMax 0.0) (setq faceMax (max len wid 1.0)))
  (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ faceMax 45000.0)))
        *PEB-DIM-SCALE*  *PEB-TEXT-SCALE*)
  (setq ts   *PEB-TEXT-SCALE*
        step (+ eaveH (/ wid slopeD) (* 9000 ts)) i 0)   ; tall enough for full mono rise + titles/dims
  (foreach surf walls
    (if (= kind "F") (peb-draw-framing-elev  surf 0.0 (* i step) data)
                     (peb-draw-sheeting-elev surf 0.0 (* i step) data))
    (setq i (1+ i)))
  (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data title))))
  (princ))

(defun peb-draw-all-framing   (data) (peb-draw-elev-set data '("NSW" "FSW" "LEW" "REW") "F" "FRAMING ELEVATIONS"))
(defun peb-draw-side-framing  (data) (peb-draw-elev-set data '("NSW" "FSW")             "F" "SIDE WALL FRAMING ELEVATIONS"))
(defun peb-draw-end-framing   (data) (peb-draw-elev-set data '("LEW" "REW")             "F" "END WALL FRAMING ELEVATIONS"))
(defun peb-draw-all-sheeting  (data) (peb-draw-elev-set data '("NSW" "FSW" "LEW" "REW") "S" "SHEETING ELEVATIONS"))
(defun peb-draw-side-sheeting (data) (peb-draw-elev-set data '("NSW" "FSW")             "S" "SIDE WALL SHEETING ELEVATIONS"))
(defun peb-draw-end-sheeting  (data) (peb-draw-elev-set data '("LEW" "REW")             "S" "END WALL SHEETING ELEVATIONS"))

;; Generic elevation-sheet loader: scale from building size, draw via drawFn(data), tile beside other sheets.
(defun peb-elev-from-file (path drawFn / prev-last prev-max-x data ms)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (setq prev-last (entlast))
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path
        data (MSPL-Read-Data path))
  (if data
    (progn
      (setq ms (max (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
                    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))))
      ;; same continuous scale rule as the Plan (0.80 floor, 4.00 cap)
      (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ ms 45000.0))) *PEB-DIM-SCALE* *PEB-TEXT-SCALE*)
      (apply drawFn (list data))))
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place)
    (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x)))))
  (princ))

;; FROM-FILE entry points — one per (type, wall-set). The render pipeline picks all-4 (small buildings) or
;; the side/end split (big buildings) so each printed elevation stays large + legible.
(defun peb-framing-from-file        (path) (peb-elev-from-file path 'peb-draw-all-framing))
(defun peb-framing-sides-from-file  (path) (peb-elev-from-file path 'peb-draw-side-framing))
(defun peb-framing-ends-from-file   (path) (peb-elev-from-file path 'peb-draw-end-framing))
(defun peb-sheeting-from-file       (path) (peb-elev-from-file path 'peb-draw-all-sheeting))
(defun peb-sheeting-sides-from-file (path) (peb-elev-from-file path 'peb-draw-side-sheeting))
(defun peb-sheeting-ends-from-file  (path) (peb-elev-from-file path 'peb-draw-end-sheeting))

;; interactive commands (read *PEB-DATA-FILE*)
(defun C:PEB-FRAMING ( / )  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*) (peb-framing-from-file  *PEB-DATA-FILE*)) (princ))
(defun C:PEB-SHEETING ( / ) (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*) (peb-sheeting-from-file *PEB-DATA-FILE*)) (princ))

;; Backward-compatible aliases (older orchestrators called the wall-framing names).
(defun C:PEB-WALL-FRAMING ( / ) (C:PEB-FRAMING))
(defun peb-wall-framing-from-file (path) (peb-framing-from-file path))

(defun C:PEB-ROOF-FRAMING ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (progn (setq data (MSPL-Read-Data *PEB-DATA-FILE*))
           (if data (peb-draw-roof-framing data 0.0 0.0))))
  (princ))

;; tiled like peb-plan-from-file so it sits beside the other sheets.
(defun peb-roof-framing-from-file (path / prev-last prev-max-x)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-ROOF-FRAMING)
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place)
    (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x)))))
  (princ))

(princ "\nMAIMAAR_PEB_Framing.lsp loaded — (peb-framing-from-file ...) elevations + (peb-roof-framing-from-file ...) plan.")
(princ)
