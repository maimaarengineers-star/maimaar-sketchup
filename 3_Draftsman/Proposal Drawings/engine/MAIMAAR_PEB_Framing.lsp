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
                              prev cnt pre psurf pat pw mark midY)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (atof (peb-tb-or (MSPL-Get-Str data "SLOPE") "10")))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
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
  ;; ridge line (gable centre)
  (setvar "CLAYER" "RIDGE")
  (command "_.LINE" (list ox midY) (list (+ ox len) midY) "")

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
  (setvar "CLAYER" "TEXT")
  (txt-bold "MC" (list (+ ox (/ len 2.0)) (- oy (* 1600 *PEB-TEXT-SCALE*)))
            (* 450 *PEB-TEXT-SCALE*) 0 "ROOF FRAMING PLAN")
  (setvar "CLAYER" prev))

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
                              gsp gy cnt pre psurf pat pw mark expr ov noteY)
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
  (setq colhw (* 0.5 (if (boundp 'peb-col-web-depth)
                       (vl-catch-all-apply (function (lambda () (* 0.32 (peb-col-web-depth wid)))))
                       220.0)))
  (if (or (not (numberp colhw)) (< colhw 70.0)) (setq colhw 110.0))

  ;; 1. base / foundation line
  (setvar "CLAYER" "GROUND")
  (command "_.LINE" (list (- ox (* 0.03 faceLen)) base)
                    (list (+ ox faceLen (* 0.03 faceLen)) base) "")

  ;; 2. I-columns (slender rectangle) + base plates at every station
  (foreach g stations
    (setq x (+ ox g)
          yTop (if isEnd
                 (peb-fr-topy g faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                 (+ base wallEave)))
    (setvar "CLAYER" "COLUMNS")
    (command "_.RECTANG" (list (- x colhw) base) (list (+ x colhw) yTop))
    (setvar "CLAYER" "PLATES")
    (command "_.RECTANG" (list (- x (* colhw 1.7)) (- base (* colhw 0.28)))
                         (list (+ x (* colhw 1.7)) (+ base (* colhw 0.28)))))

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
      (setvar "CLAYER" "STRUCTURE")
      (setq i 0)
      (while (< (1+ i) (length pts))
        (command "_.LINE" (nth i pts) (nth (1+ i) pts) "")
        (setq i (1+ i)))
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

  ;; 4. girts (secondary) from brick height up to eave + a note
  (setvar "CLAYER" "GIRTS")
  (setq gsp 1800.0 i 1)
  (while (< (+ base (max brickH 0.0) (* i gsp)) (+ base eaveH))
    (setq gy (+ base (max brickH 0.0) (* i gsp)))
    (command "_.LINE" (list ox gy) (list (+ ox faceLen) gy) "")
    (setq i (1+ i)))
  (setvar "CLAYER" "TEXT")
  (txt "ML" (list (+ ox faceLen (* 350 *PEB-TEXT-SCALE*)) (+ base (* eaveH 0.5)))
       (* 240 *PEB-TEXT-SCALE*) 0 (strcat "GIRTS @ " (rtos gsp 2 0)))

  ;; 5. wall X cross-bracing (side = braced bays; end = the two end bays)
  (setq braced (if isEnd (list 0 (- (length stations) 2))
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

  ;; 7. grid bubbles below the base (side = numbers, end = letters) + stalk
  (setq bubGap (* 1700 *PEB-TEXT-SCALE*) i 0)
  (foreach g stations
    (setq lbl (if isEnd (peb-fr-letter i) (itoa (1+ i))))
    (setvar "CLAYER" "GRID-LINES")
    (command "_.LINE" (list (+ ox g) base) (list (+ ox g) (- base (* bubGap 0.45))) "")
    (vl-catch-all-apply (function (lambda () (grid-bubble (+ ox g) (- base bubGap) lbl))))
    (setq i (1+ i)))

  ;; 8. title
  (setvar "CLAYER" "TEXT")
  (txt-bold "MC" (list (+ ox (/ faceLen 2.0)) (+ base eaveH rise (* 2600 *PEB-TEXT-SCALE*)))
            (* 420 *PEB-TEXT-SCALE*) 0 (strcat surf " FRAMING ELEVATION"))

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
