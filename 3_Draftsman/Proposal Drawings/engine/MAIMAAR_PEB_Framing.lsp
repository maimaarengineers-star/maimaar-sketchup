;; ============================================================================
;;  MAIMAAR_PEB_Framing.lsp  —  ROOF FRAMING plan (+ WALL FRAMING later)
;; ----------------------------------------------------------------------------
;;  ROOF FRAMING (top view): building outline + main frames (rafters across the
;;  width at each bay grid) + purlins (along the length at ~1.5 m rows) + ridge +
;;  roof X cross-bracing in the braced bays + FALL arrows w/ slope ratio + roof
;;  accessories (SURFACE=ROOF skylights/vents, roof monitor band).  Matches the
;;  Maimaar approval-drawing "ROOF FRAMING".  Load AFTER Standard/Section/Plan
;;  (reuses peb-parse-mod-expression, peb-braced-bays, peb-draw-bracing, txt,
;;  MSPL-Get-*, peb-tile-gap).  All mm.  Entry: (peb-roof-framing-from-file ...).
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

  ;; roof X cross-bracing in the braced bays (reuse plan logic)
  (vl-catch-all-apply (function (lambda () (peb-draw-bracing bayPts wid ox oy))))

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

;; ----------------------------------------------------------------------------
;;  WALL FRAMING (side + end) — the structural skeleton of each wall: columns +
;;  girts + eave strut + wall X-bracing + base plates + framed openings + marks.
;;  Distinct from the cladding Elevations (Phase E). Matches Maimaar approval
;;  "SIDE WALL FRAMING" / "END WALL FRAMING".
;; ----------------------------------------------------------------------------
(defun peb-draw-wall-framing (surf ox oy data / len wid eaveH slopeD rise brickH
                              faceLen stations isEnd top prev i x g braced b x0 x1
                              cnt pre psurf pat pw mark)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        eaveH  (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT") "4000"))
        slopeD (atof (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        brickH (atof (peb-tb-or (MSPL-Get-Str data "BRICKHEIGHT") "0")))
  (if (<= eaveH 0.0) (setq eaveH 4000.0))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (setq isEnd (member surf '("LEW" "REW")) rise (/ (/ wid 2.0) slopeD))
  (if isEnd
    (setq faceLen wid
          stations (peb-fr-stations (peb-tb-or (if (= surf "LEW")
                                                  (MSPL-Get-Str data "EWLEXPR")
                                                  (MSPL-Get-Str data "EWREXPR"))
                                                (MSPL-Get-Str data "MODEXPR")) wid))
    (setq faceLen len stations (peb-fr-stations (MSPL-Get-Str data "BAYEXPR") len)))
  (setq top (+ oy eaveH) prev (getvar "CLAYER"))

  ;; foundation line
  (setvar "CLAYER" "GROUND")
  (command "_.LINE" (list (- ox 500) oy) (list (+ ox faceLen 500) oy) "")
  ;; eave strut (top chord of the wall) + (gable rafters for end walls)
  (setvar "CLAYER" "STRUCTURE")
  (command "_.LINE" (list ox top) (list (+ ox faceLen) top) "")
  (if isEnd
    (progn
      (command "_.LINE" (list ox top) (list (+ ox (/ faceLen 2.0)) (+ top rise)) "")
      (command "_.LINE" (list (+ ox (/ faceLen 2.0)) (+ top rise)) (list (+ ox faceLen) top) "")))
  ;; columns (red) + base plates at each station
  (foreach g stations
    (setvar "CLAYER" "COLUMNS")
    (command "_.LINE" (list (+ ox g) oy) (list (+ ox g) top) "")
    (setvar "CLAYER" "PLATES")
    (command "_.RECTANG" (list (+ ox g -180) oy) (list (+ ox g 180) (+ oy 60))))
  ;; girts (magenta) at ~1700 from brick to eave
  (setvar "CLAYER" "GIRTS")
  (setq i 1)
  (while (< (+ oy (max brickH 0.0) (* i 1700.0)) top)
    (command "_.LINE" (list ox (+ oy (max brickH 0.0) (* i 1700.0)))
                      (list (+ ox faceLen) (+ oy (max brickH 0.0) (* i 1700.0))) "")
    (setq i (1+ i)))
  ;; wall X-bracing — braced bays (side walls) / end bays (end walls)
  (setvar "CLAYER" "CROSS")
  (setq braced (if isEnd (list 0 (- (length stations) 2)) (peb-braced-bays stations)))
  (foreach b braced
    (if (and (>= b 0) (< (1+ b) (length stations)))
      (progn
        (setq x0 (+ ox (nth b stations)) x1 (+ ox (nth (1+ b) stations)))
        (command "_.LINE" (list x0 oy) (list x1 top) "")
        (command "_.LINE" (list x0 top) (list x1 oy) ""))))
  ;; framed openings on this wall (jamb posts + header)
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
        (command "_.RECTANG" (list (+ ox pat (- (/ pw 2.0))) oy)
                             (list (+ ox pat (/ pw 2.0)) (* 0.75 top)))
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (+ ox pat) (* 0.85 top)) (* 240 *PEB-TEXT-SCALE*) 0 mark)))
    (setq i (1+ i)))
  ;; title
  (setvar "CLAYER" "TEXT")
  (txt-bold "MC" (list (+ ox (/ faceLen 2.0)) (- oy (* 1400 *PEB-TEXT-SCALE*)))
            (* 400 *PEB-TEXT-SCALE*) 0
            (strcat (if isEnd "END" "SIDE") " WALL FRAMING - " surf))
  (setvar "CLAYER" prev))

(defun peb-draw-all-wall-framing (data / wid eaveH slopeD rise step)
  (setq wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        eaveH  (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT") "4000"))
        slopeD (atof (peb-tb-or (MSPL-Get-Str data "SLOPE") "10")))
  (if (<= eaveH 0.0) (setq eaveH 4000.0))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (setq rise (/ (/ wid 2.0) slopeD)
        step (+ eaveH rise (* 5500 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))))
  (peb-draw-wall-framing "NSW" 0.0 0.0        data)
  (peb-draw-wall-framing "FSW" 0.0 step       data)
  (peb-draw-wall-framing "LEW" 0.0 (* 2 step) data)
  (peb-draw-wall-framing "REW" 0.0 (* 3 step) data))

(defun C:PEB-WALL-FRAMING ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (progn (setq data (MSPL-Read-Data *PEB-DATA-FILE*))
           (if data (peb-draw-all-wall-framing data))))
  (princ))

(defun peb-wall-framing-from-file (path / prev-last prev-max-x e new-set offset)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-WALL-FRAMING)
  (setq *PEB-DATA-FILE* nil)
  (if prev-max-x
    (progn
      (setq new-set (ssadd) e prev-last)
      (while (setq e (entnext e)) (ssadd e new-set))
      (if (> (sslength new-set) 0)
        (progn
          (setq offset (+ prev-max-x (if (boundp 'peb-tile-gap) (peb-tile-gap) 5000.0)))
          (command "_.MOVE" new-set "" "0,0,0" (list offset 0.0 0.0))
          (command "_.ZOOM" "_E")))))
  (princ))

(defun C:PEB-ROOF-FRAMING ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (progn (setq data (MSPL-Read-Data *PEB-DATA-FILE*))
           (if data (peb-draw-roof-framing data 0.0 0.0))))
  (princ))

;; tiled like peb-plan-from-file so it sits beside the other sheets.
(defun peb-roof-framing-from-file (path / prev-last prev-max-x e new-set offset)
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
  (if prev-max-x
    (progn
      (setq new-set (ssadd) e prev-last)
      (while (setq e (entnext e)) (ssadd e new-set))
      (if (> (sslength new-set) 0)
        (progn
          (setq offset (+ prev-max-x (if (boundp 'peb-tile-gap) (peb-tile-gap) 5000.0)))
          (command "_.MOVE" new-set "" "0,0,0" (list offset 0.0 0.0))
          (command "_.ZOOM" "_E")))))
  (princ))

(princ "\nMAIMAAR_PEB_Framing.lsp loaded — run (peb-roof-framing-from-file ...).")
(princ)
