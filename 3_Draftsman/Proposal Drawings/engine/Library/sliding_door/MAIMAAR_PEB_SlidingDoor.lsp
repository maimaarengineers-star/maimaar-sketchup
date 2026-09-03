;;; ============================================================================
;;;  MAIMAAR_PEB_SlidingDoor.lsp — SLIDING DOOR GEOMETRY
;;;  PEB COMPONENT LIBRARY · Library/sliding_door/
;;; ============================================================================
;;;
;;;  WHY THIS FILE EXISTS (owner, 3-Sep-2026).
;;;
;;;  "We have decided to develop the library for different components of PEB Building to use
;;;   in the PEB Drawings Main Engine for generation of the PD's."
;;;
;;;  Every accessory placed on an elevation is today a RECTANG, plus two diagonals if the type
;;;  string says "door" (MAIMAAR_PEB_Elevation.lsp placement loop). A louver, a light panel and
;;;  a sliding door all plot identical. This module draws the SLIDING DOOR properly, alone, in
;;;  its own folder, on its own terminal — then it is clubbed into the main engine with ONE
;;;  load line and ONE dispatch entry (see README.md "Syncing").
;;;
;;;  ── WHERE EVERY NUMBER CAME FROM ──────────────────────────────────────────────────────
;;;  NOTHING here is invented. Two real Maimaar jobs and the reference PEB technical manual:
;;;
;;;    MSPL-027 (Awan Sports, Bhan Stitching Hall No.02) SSD-01, 05-Nov-2021 — SINGLE leaf
;;;      leaf 4500 x 2206 · sandwich panel infill 2200x1155 · track U-CHANNEL UC-1 = PL3x214
;;;      bottom rail DOOR_ANGLE DA-3 = L50x5 x4500 · diagonal DOOR_ROUND_BAR DRB-1 = D12 x4500
;;;      clips U-CLIP PL3x100 · NEW_ANGLE L50x5 x77 (18 no.) · NEW_PLATE FLT5x50 x105 (9 no.)
;;;      slide-back 1154, run 5991 over a 4500 opening
;;;
;;;    MSPL-030 (Awan Sports, Initial Paddle Sanding Hall) SDS-01, 01-Apr-2022 — DOUBLE leaf
;;;      track 7972 (8382 over trims) · leaf 3936/3937 · stile grid 125 / 890 / 990 typical
;;;      sandwich panels 1448 wide with 302 edges · DOOR_HEADER + OPENING_CHANNEL + DOOR_WHEEL
;;;      HOOD_TRIM over the wheel · ROUND_BAR diagonal · floor guide 200 below FFL, 12 clear
;;;
;;;    Reference PEB technical manual (see reference/RefManual_*.pdf)
;;;      p750  "120 mm deep sections are used as framing members of sliding doors."
;;;            Framed-opening jambs and headers are C-sections, single or double back-to-back;
;;;            200C15 up to 3000 long, 250C when the girt is 250 deep.
;;;      p754  Jamb tributary width for a SLIDING DOOR (or open access) = 0.5 m.
;;;            For a ROLL-UP door it is (framed opening / 2 + 0.5) — a sliding door leaf carries
;;;            its own wind load to its own track, which is WHY the jamb is so much lighter.
;;;      p755-758  DSD (double sliding door) leaf design, 3 m x 6 m leaf in a 6000x6000 opening:
;;;            inner stile span 1.50 m width 1.50 m -> 120C20
;;;            central stile span 6.00 m width 1.50 m -> 2 x 120C20 (edge stile = half of it)
;;;            bottom stile span 3.00 m width 0.75 m
;;;            => a 1500 x 1500 STILE / RAIL GRID on the leaf. That is the module used here.
;;;      p750  connection bolts 12 mm dia HSB Gr. 8.8.
;;;
;;;  TRACED vs STYLISED (rulebook 4B.24 — a stylised shape under correct dimensions is honest,
;;;  invented dimensions are not):
;;;      TRACED     leaf/opening proportions, the 1500 stile-rail module, L50x5 frame angle,
;;;                 D12 diagonal, 214-deep track channel, 200 track gap, 12 sill clearance,
;;;                 120C leaf framing, 200C/250C jamb + header, leaf overrun past the jamb.
;;;      STYLISED   the section SHAPE of each member (a stile plots as a single 0.25 line at
;;;                 PD scale, not as a C-profile), the rib sheen pitch on the panel infill, and
;;;                 the hood/cover trims — those are DETAIL-drawing items, not proposal items.
;;;
;;;  ── STANDING RULES OBSERVED ──────────────────────────────────────────────────────────
;;;   * PURE GEOMETRY. Every drawer takes origin + size + hand as ARGUMENTS. NOTHING here
;;;     reads the BSF; the caller owns the data (the BSF is the single source of truth).
;;;   * No title block, no sheet, no frame — those are the building engine's job.
;;;   * Layer "SLIDING DOOR" comes from Rule_Book/PEB_LAYERS.csv. An ad-hoc layer inherits no
;;;     lineweight and drifts from the standard.
;;;   * PEN, NOT COLOUR. The proposal PDF plots monochrome (monochrome.ctb — PDF.lsp:90/:140,
;;;     drawingRender.ts:394/:1263), so ACI carries NOTHING on the deliverable. Only lineweight
;;;     does, and every entity here carries its own (cons 370 n):
;;;         leaf + opening outline  0.50    stiles & rails        0.25
;;;         track channel           0.35    diagonal round bar    0.18
;;;         panel rib sheen         0.09    slide arrow           0.18
;;;   * NO hand-driven LAYER / STYLE / TEXT commands. An acad command left open eats the rest
;;;     of the script silently and catches nothing (the LISP silent-failure class).
;;;   * Dimensions are LINE + TEXT primitives, never DIM commands, so a DIMSTYLE missing from a
;;;     standalone run cannot stall the script.
;;;   * mm, 1:1, model space.
;;;
;;;  NAME PREFIX peb-sld-  —  NOT peb-sd-, which is already the SHEETING DETAIL family in
;;;  MAIMAAR_PEB_Framing.lsp - the sheet-profile / sandwich drawers. Colliding would silently
;;;  redefine the sheeting profile the whole DETAILS sheet is drawn with.
;;; ============================================================================

;; ---------------------------------------------------------------------------
;; 1) THE NUMBERS — every one of them sourced above. Functions, not variables,
;;    so nothing downstream can reassign them mid-drawing.
;; ---------------------------------------------------------------------------
(defun peb-sld-layer      () "SLIDING DOOR")
(defun peb-sld-aci        () 30)        ; orange in the DWG the draughtsman works in; the plotted
                                        ; PDF is monochrome, so this changes nothing on the deliverable
(defun peb-sld-angle-leg  ()   50.0)    ; L50x5 perimeter / rail angle       — MSPL-027 DA-1/2/3
(defun peb-sld-angle-thk  ()    5.0)
(defun peb-sld-bar-dia    ()   12.0)    ; D12 round-bar diagonal             — MSPL-027 DRB-1
(defun peb-sld-track-dep  ()  214.0)    ; U-channel track, PL3x214           — MSPL-027 UC-1
(defun peb-sld-track-gap  ()  200.0)    ; track soffit clear above leaf top  — MSPL-030
(defun peb-sld-sill-clr   ()   12.0)    ; leaf underside above FFL           — MSPL-030
(defun peb-sld-guide-dep  ()  200.0)    ; floor guide below FFL              — MSPL-030
(defun peb-sld-jamb-dep   ()  200.0)    ; framed-opening jamb / header, 200C — manual p750
(defun peb-sld-head-lap   ()  100.0)    ; leaf overlaps the header by        — MSPL-030 head detail
(defun peb-sld-meet-lap   ()   75.0)    ; leaf-to-leaf overlap at the meeting stile (COVER_TRIM)
(defun peb-sld-jamb-lap   ()  410.0)    ; leaf overrun past the jamb         — MSPL-030 (410)
(defun peb-sld-module     () 1500.0)    ; TARGET stile / rail module         — manual DSD p755-758
;; PANEL INFILL MODULE — NOT a literal here. The leaf on MSPL-027 and MSPL-030 is clad in
;; SANDWICH PANEL, so the leaf reads at the sandwich module declared beside the drawer that owns
;; the profile -- peb-sandwich-module in MAIMAAR_PEB_Framing.lsp. Golden rule 3: one source
;; ONE source, not two equal numbers. A local 250 here would have been the S-profile pitch - the
;; wrong product - and would have drifted the day somebody re-measured the panel.
;; It also separates the door from its surroundings by GEOMETRY (rule M1): the sidewall around it
;; ribs at the 250 S pitch, the leaf at 184, and the two plainly differ on the page.

;; pens — the whole reason this reads as a door and not as a rectangle
(defun peb-sld-lw-out   () 50)
(defun peb-sld-lw-mem   () 25)
(defun peb-sld-lw-track () 35)
(defun peb-sld-lw-bar   () 18)
(defun peb-sld-lw-rib   ()  9)   ; a 0.09 LINE - a thin edge, e.g. the parked ghost
(defun peb-sld-lw-fill  ()  5)   ; a 0.05 FILL - rule M3, every material fill at 0.05

;; ---------------------------------------------------------------------------
;; 2) PRIMITIVES THAT CARRY A PEN
;;    peb-line / peb-poly (MAIMAAR_PEB_Standard.lsp) set NO lineweight, so anything drawn
;;    through them inherits LWDEFAULT 0.25 and a 0.50 leaf outline would plot the same as a
;;    0.09 rib. These are the same entmake with (cons 370 lw) added — nothing more.
;; ---------------------------------------------------------------------------
(defun peb-sld-lnL (x1 y1 x2 y2 lay lw)
  (entmake (list (cons 0 "LINE") (cons 8 lay) (cons 370 lw)
                 (list 10 x1 y1 0.0) (list 11 x2 y2 0.0))))

(defun peb-sld-ln (x1 y1 x2 y2 lw)
  (entmake (list (cons 0 "LINE") (cons 8 (peb-sld-layer)) (cons 370 lw)
                 (list 10 x1 y1 0.0) (list 11 x2 y2 0.0))))

(defun peb-sld-pl (pts lw closed / e)
  (setq e (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 (peb-sld-layer))
                (cons 370 lw) (cons 100 "AcDbPolyline") (cons 90 (length pts))
                (cons 70 (if closed 1 0))))
  (foreach p pts (setq e (append e (list (list 10 (car p) (cadr p))))))
  (entmake e))

(defun peb-sld-box (x0 y0 x1 y1 lw)
  (peb-sld-pl (list (list x0 y0) (list x1 y0) (list x1 y1) (list x0 y1)) lw T))

;; TEXT via entmake, never (command "_.TEXT") — an open TEXT prompt swallows the rest of a /b run.
;; jh: 0 left 1 centre 2 right (group 72) · jv: 0 base 2 middle 3 top (group 73).
(defun peb-sld-tx (x y h rot str lay jh jv)
  (entmake (list (cons 0 "TEXT") (cons 8 lay)
                 (list 10 x y 0.0) (list 11 x y 0.0) (cons 40 h) (cons 1 str)
                 (cons 50 (* rot (/ 3.14159265358979 180.0)))
                 (cons 7 (if (tblsearch "STYLE" "PEB-BODY") "PEB-BODY" "Standard"))
                 (cons 72 jh) (cons 73 jv))))

;; filled triangle — arrow heads and the tick on a dimension line
(defun peb-sld-tri (p1 p2 p3 lay)
  (entmake (list (cons 0 "SOLID") (cons 8 lay)
                 (list 10 (car p1) (cadr p1) 0.0) (list 11 (car p2) (cadr p2) 0.0)
                 (list 12 (car p3) (cadr p3) 0.0) (list 13 (car p3) (cadr p3) 0.0))))

;; HIDDEN, made batch-safe: entmake the LTYPE record, never (command "_.-LINETYPE" ...) which
;; asks for a file and would sit on an open prompt (rule 10). A standalone drawing has only
;; CONTINUOUS loaded, and an entity naming a linetype the table lacks is REJECTED IN SILENCE -
;; which is how a parked-leaf ghost turns into nothing at all with no error anywhere.
(defun peb-sld-ltype-ensure ()
  (if (not (tblsearch "LTYPE" "HIDDEN"))
    (entmake (list (cons 0 "LTYPE") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLinetypeTableRecord") (cons 2 "HIDDEN") (cons 70 0)
                   (cons 3 "Hidden __ __ __ __ __ __ __ __ __ __ __ __") (cons 72 65)
                   (cons 73 2) (cons 40 9.525) (cons 49 6.35) (cons 74 0)
                   (cons 49 -3.175) (cons 74 0))))
  (princ))

;; The layer, made batch-safe: entmake, never (command "_.LAYER"). If PEB_LAYERS.csv has already
;; been played in (the normal engine run) tblsearch finds it and this touches nothing.
(defun peb-sld-layer-ensure ()
  (peb-sld-ltype-ensure)
  (if (not (tblsearch "LAYER" (peb-sld-layer)))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 (peb-sld-layer))
                   (cons 70 0) (cons 62 (peb-sld-aci)))))
  (princ))

;; A dashed line drawn as STROKES, not as a linetype.
;; The engine already refuses to trust a pattern it cannot see (real HATCH fails under acad /b,
;; so peb-mezz-hatch strokes its own 45 lines). The same applies here: an entity naming a
;; linetype the drawing's table lacks is REJECTED IN SILENCE - the parked leaf simply is not
;; there, with nothing in the log. Strokes cannot fail that way.
(defun peb-sld-dash (x1 y1 x2 y2 lw dash / dx dy len n i t0 t1)
  (if (or (null dash) (<= dash 0.0)) (setq dash 180.0))
  (setq dx (- x2 x1) dy (- y2 y1) len (sqrt (+ (* dx dx) (* dy dy))))
  (if (> len 1.0)
    (progn
      (setq n (max 1 (fix (/ len (* dash 1.6)))) i 0)
      (while (< i n)
        (setq t0 (/ (* i (* dash 1.6)) len)
              t1 (min 1.0 (/ (+ (* i (* dash 1.6)) dash) len)))
        (peb-sld-ln (+ x1 (* dx t0)) (+ y1 (* dy t0))
                    (+ x1 (* dx t1)) (+ y1 (* dy t1)) lw)
        (setq i (1+ i)))))
  (princ))

(defun peb-sld-dash-box (x0 y0 x1 y1 lw dash)
  (peb-sld-dash x0 y0 x1 y0 lw dash) (peb-sld-dash x1 y0 x1 y1 lw dash)
  (peb-sld-dash x1 y1 x0 y1 lw dash) (peb-sld-dash x0 y1 x0 y0 lw dash)
  (princ))

;; ---------------------------------------------------------------------------
;; 3) THE STILE / RAIL GRID
;;    The manual designs a 3 m x 6 m leaf on a 1500 x 1500 grid. A leaf is never exactly a
;;    multiple of 1500, so the module is CHOSEN, not assumed: the number of panels nearest the
;;    target, then divided equally. MSPL-030's leaf came out at 990 by exactly this logic on a
;;    3936 leaf; the manual's comes out at 1500 on a 3000 leaf. One rule, both answers.
;; ---------------------------------------------------------------------------
(defun peb-sld-ndiv (len target / n)
  (if (or (null target) (<= target 0.0)) (setq target (peb-sld-module)))
  (setq n (fix (+ 0.5 (/ len target))))
  (max 1 n))

;; ---------------------------------------------------------------------------
;; 4) ONE LEAF, drawn in its CLOSED position.
;;      x0 y0   bottom-left of the leaf
;;      w  h    leaf size
;;      hand    +1 = this leaf slides to the RIGHT to open, -1 = to the LEFT
;;      ribs    T = draw the sandwich-panel rib sheen, nil = leave the panel clear
;;    The diagonal runs from the BOTTOM of the leading (opening-side) edge UP to the top of the
;;    trailing edge, which is how a leaf hung from a top track is actually braced: the sag it
;;    resists is the far bottom corner dropping away from the two wheels.
;; ---------------------------------------------------------------------------
(defun peb-sld-leaf (x0 y0 w h hand ribs / x1 y1 nv nh dv dh i x y bx0 bx1)
  (peb-sld-layer-ensure)
  (setq x1 (+ x0 w) y1 (+ y0 h))
  ;; -- panel rib sheen first, so every member plots ON TOP of it
  (if ribs
    (progn
      (setq x (+ x0 (peb-sandwich-module)))
      (while (< x (- x1 1.0))
        (peb-sld-ln x (+ y0 2.0) x (- y1 2.0) (peb-sld-lw-fill))
        (setq x (+ x (peb-sandwich-module))))))
  ;; -- the stile / rail grid, 0.25
  (setq nv (peb-sld-ndiv w (peb-sld-module)) dv (/ w (float nv))
        nh (peb-sld-ndiv h (peb-sld-module)) dh (/ h (float nh)))
  (setq i 1)
  (while (< i nv)                                       ; intermediate VERTICAL stiles
    (setq x (+ x0 (* i dv)))
    (peb-sld-ln x y0 x y1 (peb-sld-lw-mem))
    (setq i (1+ i)))
  (setq i 1)
  (while (< i nh)                                       ; intermediate HORIZONTAL rails
    (setq y (+ y0 (* i dh)))
    (peb-sld-ln x0 y x1 y (peb-sld-lw-mem))
    (setq i (1+ i)))
  ;; -- D12 diagonal brace, 0.18, leading bottom corner -> trailing top corner
  (if (> hand 0) (setq bx0 x1 bx1 x0) (setq bx0 x0 bx1 x1))
  (peb-sld-ln bx0 y0 bx1 y1 (peb-sld-lw-bar))
  ;; -- L50x5 perimeter frame, drawn as the outline plus its inner face, 0.50 / 0.25
  (peb-sld-box x0 y0 x1 y1 (peb-sld-lw-out))
  (peb-sld-box (+ x0 (peb-sld-angle-leg)) (+ y0 (peb-sld-angle-leg))
               (- x1 (peb-sld-angle-leg)) (- y1 (peb-sld-angle-leg)) (peb-sld-lw-mem))
  (princ))

;; ---------------------------------------------------------------------------
;; 5) THE TOP TRACK — the U-channel the door wheels run in, and the wheels.
;;    Two lines 214 apart (MSPL-027 UC-1 = PL3x214) plus a wheel disc per leaf pair. The track
;;    must run the WHOLE slide length or the drawing promises a door that cannot open.
;; ---------------------------------------------------------------------------
(defun peb-sld-track (xa xb ytop / yb r)
  (peb-sld-layer-ensure)
  (setq yb (- ytop (peb-sld-track-dep)) r 55.0)
  (peb-sld-ln xa ytop xb ytop (peb-sld-lw-track))
  (peb-sld-ln xa yb   xb yb   (peb-sld-lw-track))
  (peb-sld-ln xa ytop xa yb   (peb-sld-lw-track))
  (peb-sld-ln xb ytop xb yb   (peb-sld-lw-track))
  (princ))

;; a DOOR_WHEEL sitting in the track over the point x
(defun peb-sld-wheel (x ytop / cy r)
  (setq r 55.0 cy (- ytop (/ (peb-sld-track-dep) 2.0)))
  (entmake (list (cons 0 "CIRCLE") (cons 8 (peb-sld-layer)) (cons 370 (peb-sld-lw-mem))
                 (list 10 x cy 0.0) (cons 40 r)))
  (princ))

;; ---------------------------------------------------------------------------
;; 6) THE FRAMED OPENING — jamb each side + header, the 200C/250C the leaf hangs beside.
;;    Drawn as the opening line and the outer face of the member, 0.35.
;; ---------------------------------------------------------------------------
(defun peb-sld-opening (ox oy ow oh / d xl xr yt)
  (peb-sld-layer-ensure)
  (setq d (peb-sld-jamb-dep) xl ox xr (+ ox ow) yt (+ oy oh))
  (peb-sld-ln xl oy xl yt (peb-sld-lw-track))              ; jamb, opening face
  (peb-sld-ln xr oy xr yt (peb-sld-lw-track))
  (peb-sld-ln (- xl d) oy (- xl d) yt (peb-sld-lw-track))  ; jamb, outer face
  (peb-sld-ln (+ xr d) oy (+ xr d) yt (peb-sld-lw-track))
  (peb-sld-ln (- xl d) yt (+ xr d) yt (peb-sld-lw-track))  ; header soffit
  (peb-sld-ln (- xl d) (+ yt d) (+ xr d) (+ yt d) (peb-sld-lw-track))
  (peb-sld-ln (- xl d) yt (- xl d) (+ yt d) (peb-sld-lw-track))
  (peb-sld-ln (+ xr d) yt (+ xr d) (+ yt d) (peb-sld-lw-track))
  (princ))

;; ---------------------------------------------------------------------------
;; 7) SLIDE-DIRECTION ARROW — the one mark that makes a sliding door read as sliding and not
;;    as a fixed panel. dir +1 right, -1 left.
;; ---------------------------------------------------------------------------
(defun peb-sld-arrow (x y len dir / xe hl)
  (peb-sld-layer-ensure)
  (setq xe (+ x (* dir len)) hl (* len 0.18))
  (peb-sld-ln x y xe y (peb-sld-lw-bar))
  (peb-sld-tri (list xe y)
               (list (- xe (* dir hl)) (+ y (* hl 0.42)))
               (list (- xe (* dir hl)) (- y (* hl 0.42))) (peb-sld-layer))
  (princ))

;; ---------------------------------------------------------------------------
;; 7b) THE LEAF IN ITS PARKED (OPEN) POSITION.
;;     A sliding door that shows only the closed leaf tells the customer nothing about the
;;     wall it needs. MSPL-027 needed 1154 of clear wall to park a 4500 leaf; MSPL-030 needed a
;;     whole leaf width each side. Drawn at 0.09 - present, never competing with the door.
;; ---------------------------------------------------------------------------
(defun peb-sld-ghost (x0 y0 w h / th)
  (peb-sld-layer-ensure)
  (peb-sld-dash-box x0 y0 (+ x0 w) (+ y0 h) (peb-sld-lw-mem) 200.0)
  (setq th (max 90.0 (* h 0.040)))
  (peb-sld-tx (+ x0 (/ w 2.0)) (+ y0 (* h 0.55)) th 0.0 "LEAF PARKED" "TEXT" 1 2)
  (peb-sld-tx (+ x0 (/ w 2.0)) (+ y0 (* h 0.55) (* th -1.6)) th 0.0 "(DOOR OPEN)" "TEXT" 1 2)
  (princ))

(defun peb-sld-context (xa xb ybot ytop ox ow cover girt / x y)
  ;; RULE 7 - the wall is SHEETING and GIRTS, the layers the rest of the engine already draws a
  ;; wall on. Putting it on the door's own layer made the whole elevation read as door: same
  ;; colour in the DWG, same 0.50 family on the plot. The door must be the ONLY thing at 0.50.
  (if (not (tblsearch "LAYER" "SHEETING"))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 "SHEETING") (cons 70 0) (cons 62 4))))
  (if (not (tblsearch "LAYER" "GIRTS"))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 "GIRTS") (cons 70 0) (cons 62 6))))
  (if (or (null cover) (<= cover 0.0)) (setq cover (peb-sheet-rib-pitch)))
  (if (or (null girt)  (<= girt  0.0)) (setq girt 1800.0))
  ;; sheeting ribs at the S pitch, stopped clear of the opening
  (setq x xa)
  (while (< x xb)
    (if (or (< x (- ox (peb-sld-jamb-dep))) (> x (+ ox ow (peb-sld-jamb-dep))))
      (peb-sld-lnL x ybot x ytop "SHEETING" 9))
    (setq x (+ x cover)))
  ;; girts through the wall, broken at the opening
  (setq y girt)
  (while (< y ytop)
    (peb-sld-lnL xa y (- ox (peb-sld-jamb-dep)) y "GIRTS" 13)
    (peb-sld-lnL (+ ox ow (peb-sld-jamb-dep)) y xb y "GIRTS" 13)
    (setq y (+ y girt)))
  (peb-sld-lnL xa ytop xb ytop "SHEETING" 13)
  (peb-sld-lnL xa ybot xb ybot "SHEETING" 25)
  (princ))

;; ---------------------------------------------------------------------------
;; 8) THE COMPLETE ELEVATION.
;;      ox oy   bottom-left of the FRAMED OPENING, on FFL
;;      ow oh   framed opening, clear
;;      leaves  1 = single sliding door (SSD), 2 = double / bi-parting (DSD)
;;      hand    for a SINGLE leaf only: +1 slides right, -1 slides left. Ignored when leaves=2.
;;      lbl     callout text, or nil for none
;;    Returns the (xmin ymin xmax ymax) extents it occupied, so a caller placing it on a
;;    sheeting elevation knows what to keep clear.
;; ---------------------------------------------------------------------------
(defun peb-sld-elevation (ox oy ow oh leaves hand lbl
                          / lw lh lb lt tx0 tx1 ytop lap runout xL xR th)
  (peb-sld-layer-ensure)
  (if (null hand) (setq hand -1))
  (setq lap    (peb-sld-jamb-lap)
        lb     (+ oy (peb-sld-sill-clr))                       ; leaf underside
        lt     (+ oy oh (peb-sld-head-lap))                    ; leaf top, over the header
        lh     (- lt lb)
        ytop   (+ lt (peb-sld-track-gap) (peb-sld-track-dep))) ; track TOP of channel
  (peb-sld-opening ox oy ow oh)
  (if (= leaves 2)
    ;; ---- DOUBLE / BI-PARTING. Each leaf covers half the opening plus the meeting lap at the
    ;;      centre and the jamb lap at its own end, and opens AWAY from the centre.
    (progn
      ;; Each leaf covers HALF the opening plus a cover overlap onto its own jamb. On a 6000
      ;; opening that is a 3075 leaf - the manual's "door leaf members of size 3 x 6" - so the
      ;; stile grid falls out at 1537, i.e. the published 1500 module, not a number chosen here.
      (setq lw     (+ (/ ow 2.0) (peb-sld-meet-lap))
            xL     (- ox (peb-sld-meet-lap))
            xR     (+ ox (/ ow 2.0))
            runout (+ lw 100.0)
            tx0    (- xL runout)
            tx1    (+ xR lw runout))
      (peb-sld-track tx0 tx1 ytop)
      (peb-sld-ghost (- xL runout) lb lw lh)               ; left leaf PARKED
      (peb-sld-ghost (+ xR lw 100.0) lb lw lh)             ; right leaf PARKED
      (peb-sld-leaf xL lb lw lh -1 T)
      (peb-sld-leaf xR lb lw lh  1 T)
      (peb-sld-wheel (+ xL (* lw 0.20)) ytop) (peb-sld-wheel (+ xL (* lw 0.80)) ytop)
      (peb-sld-wheel (+ xR (* lw 0.20)) ytop) (peb-sld-wheel (+ xR (* lw 0.80)) ytop)
      (peb-sld-arrow (+ xL (* lw 0.5)) (+ lb (* lh 0.5)) (* lw 0.30) -1)
      (peb-sld-arrow (+ xR (* lw 0.5)) (+ lb (* lh 0.5)) (* lw 0.30)  1))
    ;; ---- SINGLE. One leaf covers the whole opening and parks entirely to one side.
    (progn
      (setq lw     (+ ow (* 2.0 (peb-sld-meet-lap)))
            xL     (- ox (peb-sld-meet-lap))
            runout (+ lw 100.0)
            tx0    (if (> hand 0) (- xL 100.0) (- xL runout))
            tx1    (if (> hand 0) (+ xL lw runout) (+ xL lw 100.0)))
      (peb-sld-track tx0 tx1 ytop)
      (peb-sld-ghost (if (> hand 0) (+ xL lw 100.0) (- xL runout)) lb lw lh)
      (peb-sld-leaf xL lb lw lh hand T)
      (peb-sld-wheel (+ xL (* lw 0.15)) ytop) (peb-sld-wheel (+ xL (* lw 0.85)) ytop)
      (peb-sld-arrow (+ xL (* lw 0.5)) (+ lb (* lh 0.5)) (* lw 0.22) hand)))
  ;; ---- floor guide, and the FFL it sits on
  (peb-sld-ln (- ox (peb-sld-jamb-dep)) oy (+ ox ow (peb-sld-jamb-dep)) oy (peb-sld-lw-out))
  (peb-sld-ln ox (- oy (peb-sld-guide-dep)) (+ ox ow) (- oy (peb-sld-guide-dep))
              (peb-sld-lw-mem))
  ;; ---- callout
  (if lbl
    (progn
      (setq th (max 90.0 (* oh 0.035)))
      (peb-sld-tx (+ ox (/ ow 2.0)) (- oy (peb-sld-guide-dep) (* th 1.8)) th 0.0
                  lbl "TEXT" 1 2)))
  (list (- tx0 0.0) (- oy (peb-sld-guide-dep)) tx1 ytop))

;; ---------------------------------------------------------------------------
;; 9) THE PLAN SYMBOL — what the door contributes to PRO-02 / the sheeting plan.
;;    The wall line broken by the opening, the leaf on the INSIDE face in its closed position
;;    (solid) and its open position (a light line into the pocket), and the track over.
;;      ox oy   left end of the opening, ON the wall line
;;      ow      framed opening
;;      wt      wall / sheeting thickness to offset the leaf by (0 = on the line)
;; ---------------------------------------------------------------------------
(defun peb-sld-plan (ox oy ow wt leaves lbl / xm yb th c)
  ;; THE SYMBOL MAIMAAR ALREADY ISSUES. Traced from the approval sheet
  ;; reference/MSPL-030_2021_APPROVAL-sheet18_sliding-door-on-elevation.pdf, which is what the
  ;; customer signs: the wall band BREAKS at the opening and becomes a BOW-TIE - each leaf a
  ;; wedge tapering from the full wall thickness at its own jamb to a point where the leaves
  ;; meet - annotated on two centred lines,
  ;;
  ;;        SLIDING DOOR
  ;;         2438 x 3048
  ;;
  ;; The first version of this function invented an offset line with a dashed pocket. It was
  ;; readable and it was wrong: there is already a house symbol, and a component that draws its
  ;; own makes two sheets of the same job disagree. Reference first.
  ;;
  ;;   ox oy   left end of the framed opening, ON the outer wall line
  ;;   ow      framed opening width
  ;;   wt      wall band thickness (0 -> 100, a sheeted wall drawn at proposal scale)
  ;;   leaves  1 = one wedge across the whole opening   2 = two wedges meeting at the centre
  ;;   lbl     the second annotation line, e.g. "2438 x 3048", or nil for the width alone
  (peb-sld-layer-ensure)
  (if (or (null wt) (<= wt 0.0)) (setq wt 100.0))
  (setq yb (- oy wt) xm (+ ox (/ ow 2.0)))
  ;; the wall, running away each side and BROKEN across the opening
  (peb-sld-lnL (- ox (* ow 1.6)) oy ox oy "SHEETING" 25)
  (peb-sld-lnL (- ox (* ow 1.6)) yb ox yb "SHEETING" 25)
  (peb-sld-lnL (+ ox ow) oy (+ ox ow (* ow 1.6)) oy "SHEETING" 25)
  (peb-sld-lnL (+ ox ow) yb (+ ox ow (* ow 1.6)) yb "SHEETING" 25)
  ;; the bow-tie
  (if (= leaves 2)
    (progn
      (peb-sld-pl (list (list ox oy) (list xm (/ (+ oy yb) 2.0)) (list ox yb))
                  (peb-sld-lw-mem) nil)
      (peb-sld-pl (list (list (+ ox ow) oy) (list xm (/ (+ oy yb) 2.0)) (list (+ ox ow) yb))
                  (peb-sld-lw-mem) nil))
    (peb-sld-pl (list (list ox oy) (list (+ ox ow) (/ (+ oy yb) 2.0)) (list ox yb))
                (peb-sld-lw-mem) nil))
  ;; the two annotation lines, centred over the opening
  (setq th (max 90.0 (* ow 0.055)) c (+ oy (* th 0.9)))
  (peb-sld-tx xm (+ c (* th 1.5)) th 0.0 "SLIDING DOOR" "TEXT" 1 2)
  (peb-sld-tx xm c th 0.0 (if lbl lbl (strcat (rtos ow 2 0) " WIDE")) "TEXT" 1 2)
  (princ))

;;; ============================================================================
;;;  10) SAMPLE — a DOUBLE SLIDING DOOR of a standard size, drawn alone.
;;;
;;;  Standard size chosen: FRAMED OPENING 6000 W x 6000 H, two leaves.
;;;  That is not a round number picked to look tidy — it is the exact case the reference
;;;  manual designs on p753-758 (framed opening 6000x6000, "designing the door leaf members of
;;;  size 3 x 6", DSD inner / central / edge / bottom stiles). Every member size annotated on
;;;  this sample therefore has a published calculation behind it:
;;;
;;;      leaf                 3 m x 6 m, two off             manual p755
;;;      stile / rail grid    1500 x 1500                    manual p755-758
;;;      inner stile          120C20                         manual p756
;;;      central stile        2 x 120C20                     manual p757
;;;      edge stile           half the central stile load    manual p757
;;;      leaf framing         120 mm deep C-sections         manual p750
;;;      jamb + header        200C25 / hot-rolled            manual p755 ("capacities much
;;;                                                          below required, even for double C")
;;;      perimeter angle      L50x5                          MSPL-027 DA-1/2/3
;;;      diagonal             D12 round bar                  MSPL-027 DRB-1
;;;      track                U-channel PL3x214              MSPL-027 UC-1
;;;      bolts                12 mm dia HSB Gr. 8.8          manual p750
;;;
;;;  This function is DEVELOPMENT CODE. The building engine never calls it — it calls
;;;  peb-sld-elevation / peb-sld-plan with numbers from the BSF.
;;; ============================================================================
;; RULE 16 - the text goes on the FAR side of the dimension line from the object it measures.
;; `side` is +1 when the object is ABOVE / RIGHT of the line and -1 when it is BELOW / LEFT; the
;; text is placed the other way. The helper that always wrote "above" put a dimension taken under
;; a panel straight back across the panel it was measuring.
(defun peb-sld-dim-h (x0 x1 y side txt / t2 e ty)
  (setq t2 (peb-sld-dim-th) e (* t2 0.8)
        ty (if (> side 0) (- y (* t2 1.35)) (+ y (* t2 0.45))))
  (peb-sld-ln x0 y x1 y (peb-sld-lw-fill))
  (peb-sld-ln x0 (- y e) x0 (+ y e) (peb-sld-lw-fill))
  (peb-sld-ln x1 (- y e) x1 (+ y e) (peb-sld-lw-fill))
  (peb-sld-tx (/ (+ x0 x1) 2.0) ty t2 0.0 txt "DIMENSIONS" 1 0))

(defun peb-sld-dim-v (y0 y1 x side txt / t2 e tx)
  (setq t2 (peb-sld-dim-th) e (* t2 0.8)
        tx (if (> side 0) (+ x (* t2 1.35)) (- x (* t2 0.45))))
  (peb-sld-ln x y0 x y1 (peb-sld-lw-fill))
  (peb-sld-ln (- x e) y0 (+ x e) y0 (peb-sld-lw-fill))
  (peb-sld-ln (- x e) y1 (+ x e) y1 (peb-sld-lw-fill))
  (peb-sld-tx tx (/ (+ y0 y1) 2.0) t2 90.0 txt "DIMENSIONS" 1 0))

;; RULE 14 - the text ladder in peb-th is tuned for a sheet showing a 48 m building; used
;; unchanged on a 6 m door the callouts come out taller than the door. A component sets its own,
;; scaled off WHAT IS DRAWN. *PEB-SLD-TXT* is the one dial; everything annotative reads it.
(setq *PEB-SLD-TXT* 150.0)
(defun peb-sld-set-txt (h) (setq *PEB-SLD-TXT* (max 60.0 h)) (princ))
(defun peb-sld-dim-th () (if *PEB-SLD-TXT* *PEB-SLD-TXT* 150.0))

(defun peb-sld-sample (/ ow oh ext y n)
  (peb-sld-layer-ensure)
  (if (not (tblsearch "LAYER" "TEXT"))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 "TEXT") (cons 70 0) (cons 62 7))))
  (if (not (tblsearch "LAYER" "DIMENSIONS"))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 "DIMENSIONS") (cons 70 0)
                   (cons 62 6))))
  (setq ow 6000.0 oh 6000.0)
  ;; RULE 14 - scale the annotation off the DOOR. 6000 high -> 150 text, which plots ~3 mm at
  ;; the 1:50 a door detail is shown at. Nothing here reads peb-th's building ladder.
  (peb-sld-set-txt (* oh 0.025))

  ;; ---- the wall the door sits in, drawn FIRST so every door line plots over it
  (peb-sld-context -4200.0 10200.0 0.0 7400.0 0.0 ow nil 1800.0)

  ;; ---- the elevation
  (setq ext (peb-sld-elevation 0.0 0.0 ow oh 2 nil
              "DOUBLE SLIDING DOOR  6000 W x 6000 H  (2 LEAVES 3075 x 6088)"))

  ;; ---- dimension strings: the opening, then the 1500 grid across one leaf
  (peb-sld-dim-h 0.0 ow (+ oh 1600.0) -1 "6000  FRAMED OPENING")
  (peb-sld-dim-h -3250.0 9250.0 (+ oh 2400.0) -1 "12500  TRACK  -  WALL REQUIRED EACH SIDE TO PARK A LEAF")
  (peb-sld-dim-v (peb-sld-sill-clr) (+ oh (peb-sld-head-lap))
                 (- 0.0 5000.0) 1 "6088  LEAF")
  (peb-sld-dim-v 0.0 oh (- 0.0 6200.0) 1 "6000  CLEAR")
  (setq n 0)
  (while (< n 4)                                   ; the RAIL module, up one leaf
    (peb-sld-dim-v (+ (peb-sld-sill-clr) (* n 1522.0))
                   (+ (peb-sld-sill-clr) (* (1+ n) 1522.0))
                   (+ ow 5100.0) -1 "1522")
    (setq n (1+ n)))
  ;; the STILE module across the right leaf - 3075 / 2 = 1537, i.e. the manual's 1500 grid
  (peb-sld-dim-h (/ ow 2.0) (+ (/ ow 2.0) 1537.5) (- 0.0 1500.0) 1 "1537")
  (peb-sld-dim-h (+ (/ ow 2.0) 1537.5) (+ ow (peb-sld-meet-lap)) (- 0.0 1500.0) 1 "1537")
  (peb-sld-dim-h (- 0.0 (peb-sld-meet-lap)) (/ ow 2.0) (- 0.0 2100.0) 1 "3075  LEAF")
  (peb-sld-dim-h (/ ow 2.0) (+ ow (peb-sld-meet-lap)) (- 0.0 2100.0) 1 "3075  LEAF")

  ;; ---- the plan symbol, below
  (peb-sld-plan 0.0 -4200.0 ow 100.0 2 "6000 x 6000")
  (peb-sld-tx (/ ow 2.0) -5300.0 (* (peb-sld-dim-th) 1.30) 0.0 "PLAN SYMBOL  -  AS ISSUED ON THE APPROVAL DRAWING"
              "TEXT" 1 2)

  ;; ---- the schedule of members, so the sample carries its own provenance
  (setq y -6400.0)
  (foreach s '("DOUBLE SLIDING DOOR  -  MEMBER SCHEDULE"
               "LEAF FRAMING            120 mm DEEP C-SECTIONS"
               "INNER STILE             120C20            SPAN 1500"
               "CENTRAL STILE           2 x 120C20        SPAN 6000"
               "EDGE STILE              120C20"
               "PERIMETER / RAIL ANGLE  L 50 x 5"
               "DIAGONAL BRACE          ROUND BAR  D 12"
               "TOP TRACK               U-CHANNEL  PL 3 x 214"
               "JAMB & HEADER           200C25 OR HOT-ROLLED"
               "PANEL INFILL            SANDWICH PANEL"
               "BOLTS                   12 mm DIA. HSB GR. 8.8")
    (peb-sld-tx -3000.0 y (* (peb-sld-dim-th) 1.30) 0.0 s "TEXT" 0 2)
    (setq y (- y (* (peb-sld-dim-th) 2.2))))
  (princ "\nSLIDING DOOR sample drawn: DSD 6000 x 6000.")
  (princ))

;; command wrapper, so the sample can also be drawn by hand inside an open AutoCAD
(defun c:SLDSAMPLE () (peb-sld-sample))

(princ "\nMAIMAAR_PEB_SlidingDoor.lsp loaded  -  peb-sld-elevation / peb-sld-plan / SLDSAMPLE")
(princ)
