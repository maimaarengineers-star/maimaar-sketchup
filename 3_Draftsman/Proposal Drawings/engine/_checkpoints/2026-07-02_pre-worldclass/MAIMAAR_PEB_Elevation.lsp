;; ============================================================================
;;  MAIMAAR_PEB_Elevation.lsp  —  WALL ELEVATIONS (NSW / FSW / LEW / REW)
;; ----------------------------------------------------------------------------
;;  Draws the four wall-face elevations of a building, each showing the wall
;;  outline + roof profile, columns at grid, girts, brick base, and every wall
;;  ACCESSORY (door/window/louver) from the [PLACEMENTS] section at its true
;;  position/size with its MARK.  Consumes the shared Presentation Standards DB
;;  + helpers (txt, MSPL-Get-*, peb-parse-mod-expression) — load AFTER
;;  Standard/Section/Plan.  Entry: (peb-elevation-from-file "<PEB_Data.txt>").
;;
;;  Side walls (NSW=near, FSW=far) span the LENGTH; end walls (LEW/REW) span the
;;  WIDTH and carry the gable.  All mm.  The four are stacked vertically.
;; ============================================================================

;; cumulative grid stations (mm) from a grouped spacing expr; fallback [0,total].
(defun peb-elev-stations (expr total / lst cum out)
  (setq lst (peb-parse-mod-expression expr))
  (if (or (null lst) (= (length lst) 0))
    (list 0.0 total)
    (progn (setq cum 0.0 out (list 0.0))
      (foreach s lst (setq cum (+ cum s)) (setq out (append out (list cum))))
      out)))

;; one wall elevation at origin (ox,oy).
(defun peb-draw-elevation (surf ox oy data / len wid eaveH slopeD rise brickH
                            faceLen stations isEnd top prev i x g cnt pre psurf pat
                            pw ph psill ptyp mark gx0 gx1 yb)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        eaveH  (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT") "4000"))
        slopeD (atof (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        brickH (atof (peb-tb-or (MSPL-Get-Str data "BRICKHEIGHT") "0")))
  (if (<= eaveH 0.0) (setq eaveH 4000.0))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (setq isEnd (member surf '("LEW" "REW")))
  (setq rise (/ (/ wid 2.0) slopeD))            ; gable rise at ridge (symmetric)
  (if isEnd
    (setq faceLen wid stations (peb-elev-stations (MSPL-Get-Str data "MODEXPR") wid))
    (setq faceLen len stations (peb-elev-stations (MSPL-Get-Str data "BAYEXPR") len)))
  (setq top (+ oy eaveH))
  (setq prev (getvar "CLAYER"))

  ;; ground line
  (setvar "CLAYER" "GROUND")
  (command "_.LINE" (list (- ox 600) oy) (list (+ ox faceLen 600) oy) "")
  ;; wall box (eave height)
  (setvar "CLAYER" "CLADDING")
  (command "_.LINE" (list ox oy) (list ox top) "")
  (command "_.LINE" (list (+ ox faceLen) oy) (list (+ ox faceLen) top) "")
  (command "_.LINE" (list ox top) (list (+ ox faceLen) top) "")
  ;; roof profile
  (setvar "CLAYER" "STRUCTURE")
  (if isEnd
    (progn   ; gable triangle (end walls show the gable)
      (command "_.LINE" (list ox top) (list (+ ox (/ faceLen 2.0)) (+ top rise)) "")
      (command "_.LINE" (list (+ ox (/ faceLen 2.0)) (+ top rise)) (list (+ ox faceLen) top) ""))
    (progn   ; side wall: low-pitch eave-to-ridge line shown faintly above
      (command "_.LINE" (list ox top) (list (+ ox faceLen) top) "")))

  ;; columns at grid stations
  (setvar "CLAYER" "COLUMNS")
  (foreach g stations
    (command "_.LINE" (list (+ ox g) oy) (list (+ ox g) top) ""))

  ;; girts (horizontal) from brick top to eave at ~1500 spacing
  (setvar "CLAYER" "GIRTS")
  (setq yb (+ oy (max brickH 0.0)) i 1)
  (while (< (+ yb (* i 1500.0)) top)
    (command "_.LINE" (list ox (+ yb (* i 1500.0))) (list (+ ox faceLen) (+ yb (* i 1500.0))) "")
    (setq i (1+ i)))
  ;; brick base line
  (if (> brickH 0.0)
    (progn (setvar "CLAYER" "BRICK-WALL")
           (command "_.LINE" (list ox (+ oy brickH)) (list (+ ox faceLen) (+ oy brickH)) "")))

  ;; openings on THIS face
  (setq cnt (atoi (peb-tb-or (MSPL-Get-Str data "PL_COUNT") "0")) i 1)
  (while (<= i cnt)
    (setq pre   (strcat "PL" (itoa i) "_")
          psurf (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "SURFACE")) ""))
          pat   (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "AT")) "0"))
          pw    (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "WIDTH")) "0"))
          ph    (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "HEIGHT")) "0"))
          psill (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "SILL")) "0"))
          ptyp  (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "TYPE")) ""))
          mark  (peb-tb-or (MSPL-Get-Str data (strcat pre "MARK")) ""))
    (if (and (= psurf surf) (> pw 0.0))
      (progn
        (if (<= ph 0.0) (setq ph (if (vl-string-search "DOOR" ptyp) 3000.0 1200.0)))
        (if (and (<= psill 0.0) (not (vl-string-search "DOOR" ptyp))) (setq psill 900.0))
        (setq gx0 (+ ox (- pat (/ pw 2.0))) gx1 (+ ox (+ pat (/ pw 2.0))))
        (setvar "CLAYER" "OPEN")
        (command "_.RECTANG" (list gx0 (+ oy psill)) (list gx1 (+ oy psill ph)))
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (/ (+ gx0 gx1) 2.0) (+ oy psill (/ ph 2.0))) (* 260 *PEB-TEXT-SCALE*) 0 mark)))
    (setq i (1+ i)))

  ;; title
  (setvar "CLAYER" "TEXT")
  (txt-bold "MC" (list (+ ox (/ faceLen 2.0)) (- oy (* 1400 *PEB-TEXT-SCALE*)))
            (* 400 *PEB-TEXT-SCALE*) 0 (strcat surf " ELEVATION"))
  (setvar "CLAYER" prev))

;; draw all four elevations stacked vertically.
(defun peb-draw-all-elevations (data / wid eaveH slopeD rise gap step)
  (setq wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        eaveH  (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT") "4000"))
        slopeD (atof (peb-tb-or (MSPL-Get-Str data "SLOPE") "10")))
  (if (<= eaveH 0.0) (setq eaveH 4000.0))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (setq rise (/ (/ wid 2.0) slopeD))
  (setq step (+ eaveH rise (* 5500 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))))
  (peb-draw-elevation "NSW" 0.0 0.0          data)
  (peb-draw-elevation "FSW" 0.0 step         data)
  (peb-draw-elevation "LEW" 0.0 (* 2 step)   data)
  (peb-draw-elevation "REW" 0.0 (* 3 step)   data))

(defun C:PEB-ELEVATION ( / data dataFile)
  (vl-load-com)
  (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (setq dataFile (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*) *PEB-DATA-FILE* nil))
  (if dataFile
    (progn
      (setq data (MSPL-Read-Data dataFile))
      (if data (peb-draw-all-elevations data)))
    (princ "\nNo data file."))
  (princ))

;; tiled like peb-plan-from-file: each call shifts its new entities right of the
;; existing drawing so section/plan/elevations sit side by side in one model space.
(defun peb-elevation-from-file (path / prev-last prev-max-x e new-set offset)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  (if prev-last
    (progn
      (command "_.REGEN")
      (setq prev-max-x (car (getvar "EXTMAX")))
      (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-ELEVATION)
  (setq *PEB-DATA-FILE* nil)
  (peb-tile-place prev-last prev-max-x)   ; left→right tile, fixed gap, no box overlap
  (princ))

(princ "\nMAIMAAR_PEB_Elevation.lsp loaded — run (peb-elevation-from-file ...).")
(princ)
