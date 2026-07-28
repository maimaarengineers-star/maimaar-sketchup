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
                              loB hiB ry vy fx)
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

  ;; ROOF cross-bracing in the braced bays — full-bay X (this is the ROOF plane;
  ;; the COLUMN LAYOUT plan carries the WALL bracing via peb-draw-bracing).
  (vl-catch-all-apply (function (lambda ()
    (setq prev (getvar "CLAYER"))
    (setvar "CLAYER" "CROSS")
    (foreach b (peb-braced-bays bayPts)
      (command "_.LINE" (list (+ ox (nth b bayPts)) oy) (list (+ ox (nth (1+ b) bayPts)) (+ oy wid)) "")
      (command "_.LINE" (list (+ ox (nth b bayPts)) (+ oy wid)) (list (+ ox (nth (1+ b) bayPts)) oy) ""))
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
  (grid-bubble (- ox bubGap bubR) oy "A" "R")
  (command "_.LINE" (list ox (+ oy wid)) (list (- ox bubGap) (+ oy wid)) "")
  (grid-bubble (- ox bubGap bubR) (+ oy wid) "B" "R")
  ;; blue title (below the roof) + shared title block
  (setvar "CLAYER" "TEXT")
  (setvar "CECOLOR" "5")
  (txt-bold "MC" (list (+ ox (/ len 2.0)) (- oy (* 3200 *PEB-TEXT-SCALE*)))
            (* 450 *PEB-TEXT-SCALE*) 0 "ROOF FRAMING PLAN")
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
(defun peb-fr-dimchain (ox y stations / ts i x0 x1 tick)
  (if (< (length stations) 2) nil
    (progn
      (setq ts (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0) tick (* 180 ts) i 0)
      (setvar "CLAYER" "DIMENSIONS")
      (command "_.LINE" (list (+ ox (car stations)) y)
                        (list (+ ox (last stations)) y) "")
      (while (< (1+ i) (length stations))
        (setq x0 (+ ox (nth i stations)) x1 (+ ox (nth (1+ i) stations)))
        (setvar "CLAYER" "DIMENSIONS")
        (command "_.LINE" (list x0 (- y tick)) (list x0 (+ y tick)) "")
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (/ (+ x0 x1) 2.0) (- y (* 340 ts))) (* 230 ts) 0
             (peb-comma (rtos (- (nth (1+ i) stations) (nth i stations)) 2 0)))
        (setq i (1+ i)))
      (setvar "CLAYER" "DIMENSIONS")
      (setq x1 (+ ox (last stations)))
      (command "_.LINE" (list x1 (- y tick)) (list x1 (+ y tick)) ""))))

(defun peb-draw-framing-elev (surf ox oy data / len wid slopeD stype rtype
                              eaveH eaveHi eaveLo brickH hiName hiSide wallEave
                              faceLen stations isEnd base colhw rise ridgeRise
                              i x g yTop pts cx prev braced b x0 x1 y0 y1 lbl bubGap
                              gsp gy cnt pre psurf pat pw mark expr ov noteY
                              ewHang hangHt cnt2 gbase
                              p0 p1 sdx sdy slen ux uy nx ny pdep npl jj tt px py rdep owText
                              bc bx0 by0 bx1 by1 owU isRcc)
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
          stations (peb-fr-scaled-stations
                     (peb-tb-or (if (= surf "LEW") (MSPL-Get-Str data "EWLEXPR")
                                                   (MSPL-Get-Str data "EWREXPR"))
                                (peb-tb-or (MSPL-Get-Str data "MODEXPR") "")) wid))
    (setq faceLen len
          stations (peb-fr-scaled-stations (peb-tb-or (MSPL-Get-Str data "BAYEXPR") "") len)))
  ;; column half-width in elevation (slender I) from the plan's web-depth rule
  ;; column half-width — heavier than before (owner 28-Jul, KMFoods ref: columns read as solid members)
  (setq colhw (* 0.5 (if (boundp 'peb-col-web-depth)
                       (vl-catch-all-apply (function (lambda () (* 0.46 (peb-col-web-depth wid)))))
                       300.0)))
  (if (or (not (numberp colhw)) (< colhw 100.0)) (setq colhw 150.0))

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
  (setq cnt2 (length stations) i 0)
  (foreach g stations
    (setq x    (+ ox g)
          yTop (if isEnd
                 (peb-fr-topy g faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                 (+ base wallEave))
          ;; b = CORNER column? (first or last station); y0 = this column's foot
          b    (or (= i 0) (= i (1- cnt2)))
          y0   (if (and ewHang (not b) (> hangHt 0.0)) (+ base hangHt) base))
    (setvar "CLAYER" "COLUMNS")
    (command "_.RECTANG" (list (- x colhw) y0) (list (+ x colhw) yTop))
    ;; base plate ONLY where the column lands on the foundation (corners always; interior unless hanging)
    (if (or (not ewHang) b (<= hangHt 0.0))
      (progn
        (setvar "CLAYER" "PLATES")
        (command "_.RECTANG" (list (- x (* colhw 1.7)) (- base (* colhw 0.28)))
                             (list (+ x (* colhw 1.7)) (+ base (* colhw 0.28))))
        ;; anchor bolts under the base plate (ref: the "III" ticks) — two short stubs
        (setvar "CLAYER" "BOLTS")
        (command "_.LINE" (list (- x (* colhw 0.75)) (- base (* colhw 0.28)))
                          (list (- x (* colhw 0.75)) (- base (* colhw 1.05))) "")
        (command "_.LINE" (list (+ x (* colhw 0.75)) (- base (* colhw 0.28)))
                          (list (+ x (* colhw 0.75)) (- base (* colhw 1.05))) "")))
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
      (setq rdep (* 380.0 *PEB-TEXT-SCALE*) i 0)
      (while (< (1+ i) (length pts))
        (setq p0 (nth i pts) p1 (nth (1+ i) pts)
              sdx (- (car p1) (car p0)) sdy (- (cadr p1) (cadr p0))
              slen (sqrt (+ (* sdx sdx) (* sdy sdy))))
        (command "_.LINE" p0 p1 "")
        (if (> slen 1.0)
          (command "_.LINE"
            (list (+ (car p0) (* (/ sdy slen) rdep)) (- (cadr p0) (* (/ sdx slen) rdep)))
            (list (+ (car p1) (* (/ sdy slen) rdep)) (- (cadr p1) (* (/ sdx slen) rdep))) ""))
        (setq i (1+ i)))
      ;; (Proposal Drawing: member marks + sizes/spacings omitted — those are set by design at approval stage.)
      ;; PURLINS (owner 28-Jul, ref: END WALL FRAMING shows the Z-purlins as short ticks sitting ON the
      ;; rafter). Walk each rafter segment at ~1.5 m and drop a short perpendicular stub on the OUTBOARD side.
      (setvar "CLAYER" "PURLINS")
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

  ;; 4. girts (secondary) from the sheeting base up to eave + a note. Sheeting starts at brick height,
  ;; or — on a hanging-column end wall — at the per-side open-wall line (so no girts hang in the open bay).
  (setvar "CLAYER" "GIRTS")
  ;; SYNC girts to THIS wall's OWN open-wall condition (owner 28-Jul: "framing must sync with wall conditions").
  ;; Girts fill the SHEETED zone only, densely (1400 C/C, drawn as the Z-girt's 60 mm visible lip), ABOVE the
  ;; brick/open line. A hanging-column end wall already carries its open height as hangHt; other walls read
  ;; OW_<surf> ("Open up to X M for Brickwork/Access ...") -> peb-fr-openwall-ht.
  (setq owText (peb-tb-or (MSPL-Get-Str data (strcat "OW_" surf)) "")
        gbase  (if (and ewHang (> hangHt 0.0)) hangHt (peb-fr-openwall-ht owText)))
  (setq gsp 1400.0 pdep 60.0 i 1)
  (while (< (+ base gbase (* i gsp)) (- (+ base eaveH) 200.0))
    (setq gy (+ base gbase (* i gsp)))
    (command "_.LINE" (list ox gy) (list (+ ox faceLen) gy) "")
    (command "_.LINE" (list ox (+ gy pdep)) (list (+ ox faceLen) (+ gy pdep)) "")
    (setq i (1+ i)))
  ;; brick/open zone below the sheeting line: a base line + a label straight from the wall condition, so the
  ;; framing visibly matches "brickwork by others" vs "open for access" at the right per-wall height.
  (if (> gbase 200.0)
    (progn
      ;; sheeting-base line (hanging end walls already have the carrying beam at this level, so skip it there)
      (if (not (and ewHang (> hangHt 0.0)))
        (progn (setvar "CLAYER" "GIRTS")
          (command "_.LINE" (list ox (+ base gbase)) (list (+ ox faceLen) (+ base gbase)) "")))
      ;; MASONRY / CONCRETE hatch by the wall condition (owner 28-Jul: real brick pattern + RCC where needed):
      ;;   Brickwork / Blockwall -> AR-B816 (running-bond brick, predefined pattern via -HATCH);
      ;;   Pre-Cast Panels / RCC / Concrete -> 45-deg CROSS-hatch drawn MANUALLY (the concrete-in-section look;
      ;;     AR-CONC is unreliable headless: it aborts "hatch too dense"). Access / Glazing / Open -> no fill.
      (setq owU (strcase owText)
            isRcc (wcmatch owU "*PRE-CAST*,*PRECAST*,*RCC*,*CONCRETE*,*R.C.C*"))
      (if (and (> gbase 500.0) (not (wcmatch owU "*ACCESS*")) (not (wcmatch owU "*GLAZ*")))
        (progn
          (setvar "CLAYER" "GIRTS")
          (if isRcc
            (progn
              ;; "/" diagonals (y = x - c), clipped to the zone box [0,faceLen] x [0,gbase]
              (setq bc (- 0.0 gbase))
              (while (< bc faceLen)
                (setq bx0 (if (>= bc 0.0) bc 0.0) by0 (if (>= bc 0.0) 0.0 (- 0.0 bc))
                      bx1 (if (<= (+ bc gbase) faceLen) (+ bc gbase) faceLen)
                      by1 (if (<= (+ bc gbase) faceLen) gbase (- faceLen bc)))
                (command "_.LINE" (list (+ ox bx0) (+ base by0)) (list (+ ox bx1) (+ base by1)) "")
                (setq bc (+ bc 750.0)))
              ;; "\" diagonals (y = c - x)
              (setq bc 0.0)
              (while (< bc (+ faceLen gbase))
                (setq bx0 (if (<= bc faceLen) bc faceLen) by0 (if (<= bc faceLen) 0.0 (- bc faceLen))
                      bx1 (if (>= (- bc gbase) 0.0) (- bc gbase) 0.0) by1 (if (>= (- bc gbase) 0.0) gbase bc))
                (command "_.LINE" (list (+ ox bx0) (+ base by0)) (list (+ ox bx1) (+ base by1)) "")
                (setq bc (+ bc 750.0))))
            (progn
              (command "_.RECTANG" (list (+ ox colhw 40.0) (+ base 40.0))
                                   (list (- (+ ox faceLen) colhw 40.0) (+ base gbase -40.0)))
              (vl-catch-all-apply (function (lambda ()
                (command "_.-HATCH" "_P" "AR-B816" (* 20.0 *PEB-TEXT-SCALE*) 0.0 "_S" (entlast) "" ""))))))))
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (+ ox (/ faceLen 2.0)) (+ base (* gbase 0.42))) (* 300 *PEB-TEXT-SCALE*) 0
           (strcat (cond ((wcmatch owU "*ACCESS*")               "OPEN FOR ACCESS (BY OTHERS)")
                         ((wcmatch owU "*PRE-CAST*,*PRECAST*")   "PRE-CAST RCC PANELS (BY OTHERS)")
                         ((wcmatch owU "*RCC*,*R.C.C*,*CONCRETE*") "RCC WALL (BY OTHERS)")
                         ((wcmatch owU "*BLOCK*")                "BLOCKWALL (BY OTHERS)")
                         ((wcmatch owU "*GLAZ*")                 "GLAZING (BY OTHERS)")
                         (T                                      "BRICK WALL (BY OTHERS)"))
                   " - H=" (rtos (/ gbase 1000.0) 2 2) " M"))))
  ;; (Proposal Drawing: girt/purlin SIZE + SPACING call-outs omitted — set by design at approval stage.)

  ;; 5. wall X cross-bracing — SIDE walls only (braced bays). The reference END WALL FRAMING carries NO
  ;; X cross-bracing (it uses girts + purlins + flange braces instead), and X-braces looked wrong crossing
  ;; the open bay below the hanging columns — so end walls skip it (owner 28-Jul, per old reference drawings).
  (setq braced (if isEnd nil
                          (vl-catch-all-apply (function (lambda () (peb-braced-bays stations))))))
  (if (vl-catch-all-error-p braced) (setq braced nil))
  (setvar "CLAYER" "CROSS")
  (foreach b braced
    (if (and (numberp b) (>= b 0) (< (1+ b) (length stations)))
      (progn
        (setq x0 (+ ox (nth b stations)) x1 (+ ox (nth (1+ b) stations))
              y0 base
              y1 (min (if isEnd (peb-fr-topy (nth b stations) faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                                 (+ base wallEave))
                      (if isEnd (peb-fr-topy (nth (1+ b) stations) faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                                 (+ base wallEave))))
        (command "_.LINE" (list x0 y0) (list x1 y1) "")
        (command "_.LINE" (list x0 y1) (list x1 y0) ""))))

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
            (* 500 *PEB-TEXT-SCALE*) 0
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

;; Stack the four framing elevations one above another (NSW, FSW, LEW, REW).
(defun peb-draw-all-framing (data / wid slopeD eaveH ts step)
  (setq wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (slope-denom (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        eaveH  (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT")
                       (peb-tb-or (MSPL-Get-Str data "EAVE_HEIGHT")
                         (peb-tb-or (MSPL-Get-Str data "BP_EAVE_HEIGHT") "6000")))))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (if (<= eaveH 0.0)  (setq eaveH 6000.0))
  (setq ts   (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        step (+ eaveH (/ wid slopeD) (* 9000 ts)))    ; tall enough for full mono rise + titles/dims
  (peb-draw-framing-elev "NSW" 0.0 0.0          data)
  (peb-draw-framing-elev "FSW" 0.0 step         data)
  (peb-draw-framing-elev "LEW" 0.0 (* 2.0 step) data)
  (peb-draw-framing-elev "REW" 0.0 (* 3.0 step) data)
  ;; owner 7-Jul: shared title block + border (portrait stack -> bottom-right corner block).
  (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data "FRAMING ELEVATIONS"))))
  (princ))

(defun C:PEB-FRAMING ( / data ms)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (progn
      (setq data (MSPL-Read-Data *PEB-DATA-FILE*))
      (if data
        (progn
          (setq ms (max (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
                        (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))))
          ;; same continuous scale rule as the Plan (0.80 floor, 4.00 cap)
          (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ ms 45000.0))))
          (setq *PEB-DIM-SCALE* *PEB-TEXT-SCALE*)
          (peb-draw-all-framing data)))))
  (princ))

;; tiled like peb-plan-from-file so it sits beside the other sheets.
(defun peb-framing-from-file (path / prev-last prev-max-x)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (princ (strcat "\nPEB-FRAMING using data file: " path))
  (C:PEB-FRAMING)
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place)
    (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x)))))
  (princ))

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
