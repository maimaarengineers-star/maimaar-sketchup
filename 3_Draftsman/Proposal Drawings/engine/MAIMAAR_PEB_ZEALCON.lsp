;; ============================================================================
;;  MAIMAAR_PEB_ZEALCON.lsp  —  exact reproduction of the Zealcon COLUMN LAY-OUT
;;  PLAN (everything EXCEPT the title block).  Hardcoded to Zealcon's building,
;;  in Zealcon's CAD standard.  Gold-standard to match + source of style-correct
;;  primitives to fold into the IF-driven engine.  Run:  (C:ZEALCON-PLAN)
;;  Origin = grid 1 / A at (0,0).  All mm.
;; ============================================================================
(vl-load-com)

;; ---- batch-safe entmake helpers -------------------------------------------
(defun z-line (x1 y1 x2 y2 lay col)
  (entmake (list (cons 0 "LINE") (cons 8 lay) (cons 62 col)
                 (list 10 x1 y1 0.0) (list 11 x2 y2 0.0))))
(defun z-poly (pts lay col closed)
  (entmake (append
    (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 lay) (cons 62 col)
          (cons 100 "AcDbPolyline") (cons 90 (length pts)) (cons 70 (if closed 1 0)))
    (mapcar (function (lambda (p) (list 10 (car p) (cadr p)))) pts))))
(defun z-txt (x y h rotdeg str lay col)        ; middle-centre TEXT
  (entmake (list (cons 0 "TEXT") (cons 8 lay) (cons 62 col)
                 (list 10 x y 0.0) (list 11 x y 0.0) (cons 40 h) (cons 1 str)
                 (cons 50 (* rotdeg (/ pi 180.0))) (cons 7 "Standard")
                 (cons 72 1) (cons 73 2))))
(defun z-solid (p1 p2 p3 p4 lay col)
  (entmake (list (cons 0 "SOLID") (cons 8 lay) (cons 62 col)
                 (list 10 (car p1)(cadr p1) 0.0) (list 11 (car p2)(cadr p2) 0.0)
                 (list 12 (car p3)(cadr p3) 0.0) (list 13 (car p4)(cadr p4) 0.0))))
(defun z-circle (x y r lay col)
  (entmake (list (cons 0 "CIRCLE") (cons 8 lay) (cons 62 col)
                 (list 10 x y 0.0) (cons 40 r))))
(defun z-layer (name col ltype)
  (if (not (tblsearch "LAYER" name))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 name) (cons 70 0)
                   (cons 62 col) (cons 6 (if ltype ltype "Continuous"))))))

;; GREEN pentagon grid bubble (apex toward the building) + number.
;;   dir = "D" (apex down, top bubbles) or "R" (apex right, left bubbles)
(defun z-bubble (x y r lab dir / p)
  (cond
    ((= dir "D")
     (setq p (list (list (- x r)(+ y (* r 0.45))) (list (+ x r)(+ y (* r 0.45)))
                   (list (+ x r)(- y (* r 0.15))) (list x (- y r))
                   (list (- x r)(- y (* r 0.15)))))
     (z-poly p "Z-BUB" 3 T)
     (z-txt x (+ y (* r 0.18)) (* r 0.95) 0 lab "Z-BUBTXT" 3))
    (T
     (setq p (list (list (+ x (* r 0.45))(- y r)) (list (+ x (* r 0.45))(+ y r))
                   (list (- x (* r 0.15))(+ y r)) (list (- x r) y)
                   (list (- x (* r 0.15))(- y r))))
     (z-poly p "Z-BUB" 3 T)
     (z-txt (+ x (* r 0.18)) y (* r 0.95) 0 lab "Z-BUBTXT" 3))))

;; dotted (DASHED) cyan X across a bay [x0,x1] x [y0,y1]
(defun z-brace (x0 x1 y0 y1)
  (z-line x0 y0 x1 y1 "Z-CROSS" 4)
  (z-line x0 y1 x1 y0 "Z-CROSS" 4))

;; red FILL marker (small pentagon + vertical "FILL")
(defun z-fill (x y / r)
  (setq r 360.0)
  (z-poly (list (list (- x r)(+ y (* r 0.45))) (list (+ x r)(+ y (* r 0.45)))
                (list (+ x r)(- y (* r 0.15))) (list x (- y r))
                (list (- x r)(- y (* r 0.15)))) "Z-FILL" 1 T)
  (z-txt (- x (* r 2.2)) y 360.0 90 "FILL" "Z-FILL" 1))

;; hand-drawn leader: line tip->elbow + filled arrow at tip + text at elbow
(defun z-leader (tx ty ex ey str lay col / a hl dx dy d ux uy)
  (z-line tx ty ex ey lay col)
  (setq dx (- tx ex) dy (- ty ey) d (sqrt (+ (* dx dx)(* dy dy))))
  (if (> d 1.0)
    (progn (setq ux (/ dx d) uy (/ dy d) hl 350.0)
      (z-solid (list tx ty)
               (list (- tx (* hl ux)) (- ty (* hl uy)))
               (list (- tx (* hl ux)) (- ty (* hl uy)))
               (list tx ty) lay col)))
  (z-txt ex (+ ey 250.0) 500.0 0 str lay col))

;; ---- the drawing -----------------------------------------------------------
(defun C:ZEALCON-PLAN ( / bayPts widthPts L W i j n x x0 x1 y bub dimY1 dimY2
                          gridTop gridLeft dimX1 dimX2 ax cy)
  (setvar "FILEDIA" 0) (setvar "CMDECHO" 0)
  (if (not (tblsearch "LTYPE" "DASHED"))
    (vl-catch-all-apply (function (lambda () (command "_.-LINETYPE" "_Load" "DASHED" "acad.lin" "")))))
  (setvar "LTSCALE" 100.0)
  (z-layer "Z-OUTLINE" 7 "Continuous") (z-layer "Z-GRID" 3 "DASHED")
  (z-layer "Z-BUB" 3 "Continuous") (z-layer "Z-BUBTXT" 3 "Continuous")
  (z-layer "Z-DIM" 7 "Continuous") (z-layer "Z-COL" 1 "Continuous")
  (z-layer "Z-CROSS" 4 "DASHED") (z-layer "Z-AREA" 7 "Continuous")
  (z-layer "Z-FILL" 1 "Continuous") (z-layer "Z-BB" 6 "Continuous")
  (z-layer "Z-TITLE" 5 "Continuous") (z-layer "Z-CRANE" 7 "Continuous")

  (setq bayPts   (list 0.0 5750.0 11500.0 17600.0 23700.0 28900.0 34100.0 39300.0)
        widthPts (list 0.0 6200.0 12400.0)
        L 39300.0 W 12400.0)
  (setq gridTop  (+ W 5500.0) gridLeft (- 0.0 5500.0)
        dimY1    (+ W 1800.0) dimX1 (- 0.0 1800.0))

  ;; building outline (eave)
  (z-poly (list (list 0 0)(list L 0)(list L W)(list 0 W)) "Z-OUTLINE" 7 T)

  ;; vertical grid lines + top bubbles (1..8)
  (setq i 0)
  (foreach x bayPts
    (z-line x 0.0 x (- gridTop 600.0) "Z-GRID" 3)
    (z-bubble x gridTop 600.0 (itoa (1+ i)) "D")
    (setq i (1+ i)))
  ;; horizontal grid lines + left bubbles (A..C)
  (setq j 0)
  (foreach y widthPts
    (z-line (+ gridLeft 600.0) y L y "Z-GRID" 3)
    (z-bubble gridLeft y 600.0 (chr (+ 65 j)) "R")
    (setq j (1+ j)))

  ;; columns — small red filled square at each grid node
  (foreach x bayPts
    (foreach y widthPts
      (z-solid (list (- x 180)(- y 180)) (list (+ x 180)(- y 180))
               (list (- x 180)(+ y 180)) (list (+ x 180)(+ y 180)) "Z-COL" 1)))

  ;; LENGTH dim chain (individual bays) at top + overall note
  (z-line 0.0 dimY1 L dimY1 "Z-DIM" 7)
  (setq i 0)
  (while (< i (length bayPts))
    (setq x (nth i bayPts))
    (z-line x (- dimY1 200.0) x (+ dimY1 200.0) "Z-DIM" 7)        ; tick
    (if (< (1+ i) (length bayPts))
      (z-txt (/ (+ x (nth (1+ i) bayPts)) 2.0) (+ dimY1 350.0) 550.0 0
             (rtos (- (nth (1+ i) bayPts) x) 2 0) "Z-DIM" 7))
    (setq i (1+ i)))
  (z-txt (/ L 2.0) (+ dimY1 1400.0) 600.0 0
         "BUILDING LENGTH: 39300 CENTER TO CENTER OF STEEL COLUMN" "Z-DIM" 7)

  ;; WIDTH dim chain (modules) at left + note (vertical)
  (z-line dimX1 0.0 dimX1 W "Z-DIM" 7)
  (setq j 0)
  (while (< j (length widthPts))
    (setq y (nth j widthPts))
    (z-line (- dimX1 200.0) y (+ dimX1 200.0) y "Z-DIM" 7)
    (if (< (1+ j) (length widthPts))
      (z-txt (- dimX1 350.0) (/ (+ y (nth (1+ j) widthPts)) 2.0) 550.0 90
             (rtos (- (nth (1+ j) widthPts) y) 2 0) "Z-DIM" 7))
    (setq j (1+ j)))
  (z-txt (- dimX1 1400.0) (/ W 2.0) 600.0 90
         "BUILDING WIDTH: 12400 C/C OF STEEL COLUMN" "Z-DIM" 7)

  ;; AREA tags
  (foreach a (list (list "AREA-01" 11500.0) (list "AREA-02" 31500.0))
    (setq ax (cadr a) cy (/ W 2.0))
    (z-poly (list (list (- ax 1600)(- cy 500)) (list (+ ax 1600)(- cy 500))
                  (list (+ ax 1600)(+ cy 500)) (list (- ax 1600)(+ cy 500))) "Z-AREA" 7 T)
    (z-txt ax cy 650.0 0 (car a) "Z-AREA" 7))

  ;; cross-bracing (dotted cyan X) in 2 braced bays + BRACED BAY + note
  (foreach bb (list (list 5750.0 11500.0) (list 28900.0 34100.0))
    (setq x0 (car bb) x1 (cadr bb))
    (z-brace x0 x1 0.0 W)
    (z-txt (/ (+ x0 x1) 2.0) (/ W 2.0) 700.0 90 "BRACED BAY" "Z-BB" 6))
  (z-leader 6000.0 -200.0 4500.0 -1800.0 "CROSS BRACING (TYP.)" "Z-DIM" 7)

  ;; FILL markers at braced columns
  (foreach fp (list (list 5750.0 (* W 0.72)) (list 5750.0 (* W 0.28))
                    (list 28900.0 (* W 0.72)) (list 28900.0 (* W 0.28)))
    (z-fill (car fp) (cadr fp)))

  ;; BEARING FRAME BOTH ENDS leader (top-left)
  (z-leader 0.0 W (- 0.0 3500.0) (+ W 2600.0) "BEARING FRAME BOTH ENDS" "Z-DIM" 7)

  ;; crane: beam line (mid) + crane symbol + run note
  (z-line 5750.0 (/ W 2.0) 34100.0 (/ W 2.0) "Z-CRANE" 7)
  (z-poly (list (list 22000 (- (/ W 2.0) 300))(list 23200 (- (/ W 2.0) 300))
                (list 23200 (+ (/ W 2.0) 300))(list 22000 (+ (/ W 2.0) 300))) "Z-CRANE" 7 T)
  (z-txt 17600.0 (+ (/ W 2.0) 400.0) 450.0 0 "CRANE RUN: 12200   02MT CRANE" "Z-CRANE" 7)
  (z-leader 11500.0 (* W 0.62) 13500.0 (* W 0.80) "CRANE BEAM" "Z-DIM" 7)

  ;; ridge line + rafter + roof/ladder labels
  (z-leader 17600.0 (/ W 2.0) 15000.0 (* W 0.62) "RIDGE LINE" "Z-DIM" 7)
  (z-leader 34100.0 (* W 0.55) 36500.0 (* W 0.62) "C/L OF RAFTER" "Z-DIM" 7)
  (z-leader 0.0 0.0 (- 0.0 2500.0) (- 0.0 1500.0) "CAGE LADDER" "Z-DIM" 7)
  (z-leader 5750.0 0.0 4000.0 (- 0.0 1500.0) "CAGE LADDER" "Z-DIM" 7)
  (z-leader 1000.0 0.0 (- 0.0 1500.0) (- 0.0 2600.0) "LOW ROOF" "Z-DIM" 7)
  (z-leader L (* W 0.30) (+ L 2600.0) (* W 0.20) "HIGH ROOF" "Z-DIM" 7)
  (z-txt (- gridLeft 1200.0) (- 0.0 1200.0) 600.0 0 "LEW" "Z-DIM" 7)
  (z-leader (* L 0.72) 0.0 (* L 0.80) (- 0.0 1800.0) "NEAR SIDE WALL" "Z-DIM" 7)

  ;; title (blue, big, bottom-centre)  — NO title block
  (z-txt (/ L 2.0) (- 0.0 5500.0) 1600.0 0 "COLUMN LAY-OUT PLAN" "Z-TITLE" 5)

  (command "_.ZOOM" "_E")
  (princ "\nZealcon column-layout plan drawn."))
(princ "\nMAIMAAR_PEB_ZEALCON.lsp loaded — run (C:ZEALCON-PLAN).")
(princ)
