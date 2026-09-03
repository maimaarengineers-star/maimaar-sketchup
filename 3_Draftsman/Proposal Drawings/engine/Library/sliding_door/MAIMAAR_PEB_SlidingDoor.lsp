;;; ============================================================================
;;;  MAIMAAR_PEB_SlidingDoor.lsp — SLIDING DOOR GEOMETRY
;;;  PEB COMPONENT LIBRARY · Library/sliding_door/
;;; ============================================================================
;;;
;;;  WHY THIS FILE EXISTS (owner, 3-Sep-2026).
;;;
;;;  "We have decided to develop the library for different components of PEB Building to use
;;;   in the PEB Drawings Main Engine for generation of the PD's ... complete the full sliding
;;;   door - 100% matching with Sample Drawings of Jobs."
;;;
;;;  Every accessory placed on an elevation is today a RECTANG, plus two diagonals if the type
;;;  string says "door" (MAIMAAR_PEB_Elevation.lsp placement loop). A louver, a light panel and
;;;  a sliding door all plot identical. This module draws the SLIDING DOOR the way MAIMAAR
;;;  DRAWS IT, traced from two issued job drawings.
;;;
;;;  ── TRACED FROM THE VECTORS, NOT FROM THE TEXT (golden rule 19) ───────────────────────
;;;  Both sheets were imported with reference/view_reference.js and MEASURED. That mattered:
;;;  the text stream and the geometry disagree in this set (the panel field dimensioned
;;;  302|1448|1448|302 is drawn as three equal bays), and it overturned two things this file
;;;  originally had wrong.
;;;
;;;  **THERE IS NO DIAGONAL BRACE.** The first version drew one, on the strength of a shop
;;;  drawing listing DOOR_ROUND_BAR DRB-1 = D12 x 4500 with a 45 deg note. Both elevations
;;;  show what that bar really is: the FLOOR GUIDE RAIL, running the whole slide length below
;;;  FFL on short stubs, with L50x5 clips at ~830 centres. ROUND_BAR on MSPL-030 points at the
;;;  same rail. A sliding door leaf is a panel in a frame; it is not braced like a portal.
;;;
;;;  **THERE IS NO STILE GRID ON THE ELEVATION.** The reference manual designs the leaf on a
;;;  1500 x 1500 stile-and-rail grid (p755-758), and that design is real - but the stiles are
;;;  BEHIND the panel and neither issued drawing shows them. What the drawings show is the
;;;  SANDWICH PANEL field between cover trims. The manual sizes the members; the drawing draws
;;;  the door. This file draws the door.
;;;
;;;  ── WHAT THE TWO JOBS SHOW ────────────────────────────────────────────────────────────
;;;
;;;    MSPL-027 SSD-01 (Awan Sports, Bhan Stitching Hall No.02) 05-Nov-2021 — SINGLE leaf
;;;      leaf 2313 wide x 2206 high over a 4500 opening, parking 2152 into the pocket
;;;      TRIM TR-2 vertical strip at the leaf edge · TRIM TR-1 band along the bottom
;;;      Sandwich_Panel 2200x1155, ribbed across the whole leaf, joint at the panel edge
;;;      U-CHANNEL UC-1 = PL3x214 track over, running the full slide length on NEW_CLIP NCL-1
;;;      U-CLIP UCL-1 at the bottom corners · bottom rail on short stubs, full length
;;;      DOOR_ANGLE DA-3 = L50x5 x4500 · DOOR_ROUND_BAR DRB-1 = D12 x4500 (the FLOOR RAIL)
;;;      NEW_ANGLE NAN-1 = L50x5 x77, 18 no. · NEW_PLATE NPL-1 = FLT5x50 x105, 9 no.
;;;
;;;    MSPL-030 SDS-01 (Awan Sports, Initial Paddle Sanding Hall) 01-Apr-2022 — DOUBLE leaf
;;;      assembly 7972 (8382 over trims), set 410 off the grid; each leaf 3985
;;;      MEASURED leaf height 2430 (2462 over trims); leaf underside 12 clear of FFL
;;;      leaf: COVER_TRIM strip each end, then the panel field 302 | 1448 | 1448 | 302
;;;      floor rail stubs at 125 | 890 | 990 | 990 | 990 | 990 | 990 | 990 | 890 | 125
;;;      DOOR_HEADER + OPENING_CHANNEL + DOOR_WHEEL at the head, HOOD_TRIM over it
;;;      floor guide 200 below FFL
;;;
;;;    The approval sheet the customer signs (MSPL-030 sheet 18) annotates it in PLAN only:
;;;    the wall band breaks into a BOW-TIE, labelled  SLIDING DOOR / 2438 x 3048.
;;;
;;;  ── STANDING RULES OBSERVED ──────────────────────────────────────────────────────────
;;;   * PURE GEOMETRY. Every drawer takes origin + size + hand as ARGUMENTS. NOTHING here
;;;     reads the BSF; the caller owns the data (the BSF is the single source of truth).
;;;   * No title block, no sheet, no frame — those are the building engine's job.
;;;   * Layer "SLIDING DOOR" comes from Rule_Book/PEB_LAYERS.csv (ACI 30 / 0.50).
;;;   * PEN, NOT COLOUR. The proposal PDF plots monochrome, so ACI carries nothing on the
;;;     deliverable. Every entity sets its own (cons 370 n):
;;;         leaf outline + trims   0.50     track, rails, header      0.35
;;;         panel joints           0.25     clips, wheels, stubs      0.18
;;;         sandwich rib field     0.05     (golden rule M3)
;;;   * NO hand-driven LAYER / STYLE / TEXT commands, and no linetype the drawing may lack:
;;;     an entmake naming a missing LTYPE is rejected IN SILENCE. Dashes are drawn as strokes.
;;;   * Dimensions are LINE + TEXT primitives, never DIM commands.
;;;   * mm, 1:1, model space.
;;;
;;;  NAME PREFIX peb-sld-  —  NOT peb-sd-, which is already the sheet-profile family in
;;;  MAIMAAR_PEB_Framing.lsp. Colliding would silently redefine the sheeting profile the whole
;;;  DETAILS sheet is drawn with.
;;; ============================================================================

;; ---------------------------------------------------------------------------
;; 1) THE NUMBERS — every one measured off an issued drawing.
;;    Functions, not variables, so nothing downstream can reassign them mid-drawing.
;; ---------------------------------------------------------------------------
(defun peb-sld-layer      () "SLIDING DOOR")
(defun peb-sld-aci        () 30)

;; the leaf
(defun peb-sld-trim-w     ()   70.0)   ; COVER_TRIM at the JAMB end of the leaf     — MSPL-030 plan
;; THE LEAF IS NOT SYMMETRIC. MSPL-030 dimensions it  539 | 302 | 1448 | 1448 | 302  — a wide
;; LEADING strip carrying the meeting stile and its cover trim, then the panel field beyond it.
;; Drawing the leaf symmetric put a 513 closer at BOTH ends and lost the meeting stile entirely.
(defun peb-sld-lead-w     ()  539.0)   ; the leading (meeting) strip               — MSPL-030
(defun peb-sld-trim-h     ()   80.0)   ; the top and bottom trim band              — MSPL-030 plan
(defun peb-sld-panel-w    () 1448.0)   ; sandwich panel cover in the leaf           — MSPL-030
(defun peb-sld-sill-clr   ()   12.0)   ; leaf underside above FFL                   — MSPL-030
(defun peb-sld-head-lap   ()  100.0)   ; leaf overlaps the header by                — MSPL-030 head

;; the head
(defun peb-sld-track-dep  ()  214.0)   ; U-CHANNEL track, PL3x214                   — MSPL-027 UC-1
(defun peb-sld-track-gap  ()  200.0)   ; track soffit clear above the leaf top      — MSPL-030
(defun peb-sld-hood-dep   ()  195.0)   ; HOOD_TRIM over the wheel                   — MSPL-030 B-B
(defun peb-sld-clip-w     ()  100.0)   ; U-CLIP / NEW_CLIP, PL3x100                 — MSPL-027 UCL

;; the floor
(defun peb-sld-rail-dep   ()   65.0)   ; bottom rail band                           — MSPL-030 plan
(defun peb-sld-guide-dep  ()  200.0)   ; floor guide rail below FFL                 — MSPL-030
(defun peb-sld-stub-h     ()  200.0)   ; the stubs the floor rail sits on           — MSPL-030
(defun peb-sld-stub-end   ()  125.0)   ; first stub in from the end                 — MSPL-030
(defun peb-sld-stub-2nd   ()  890.0)   ; then                                       — MSPL-030
(defun peb-sld-stub-typ   ()  990.0)   ; and typical                                — MSPL-030
(defun peb-sld-bar-dia    ()   12.0)   ; ROUND BAR D12 — the FLOOR RAIL, not a brace  MSPL-176
(defun peb-sld-wheel-dia  ()   20.0)   ; WHEEL DIA 20, running ON the rail          — MSPL-121

;; ---- THE WICKET DOOR ------------------------------------------------------------------
;; A personnel door inside the leaf, so the sliding door need not be opened to walk through.
;; It is STANDARD on the current sheets and was missing entirely from the first version.
;; Traced from MSPL-121 (2024): 914 [3'-0"] x 1981 [6'-6"], sill 305 [1'-0"] above FFL, set
;; 305 in from the trailing end of the leaf. Maimaar sizes these doors in FEET and the metric
;; figures are the conversions — 9144 = 30', 3048 = 10', 2438 = 8', 914 = 3', 1981 = 6'-6".
(defun peb-sld-wicket-w    () 914.0)
(defun peb-sld-wicket-h    () 1981.0)
(defun peb-sld-wicket-sill () 305.0)
(defun peb-sld-wicket-off  () 305.0)

;; the opening
(defun peb-sld-jamb-dep   ()  200.0)   ; framed-opening jamb / header, 200C — manual p750
(defun peb-sld-jamb-lap   ()  410.0)   ; assembly set off the grid                  — MSPL-030
(defun peb-sld-meet-lap   ()   75.0)   ; leaf-to-leaf / leaf-to-jamb cover overlap

;; pens
(defun peb-sld-lw-out   () 50)
(defun peb-sld-lw-track () 35)
(defun peb-sld-lw-mem   () 25)
(defun peb-sld-lw-clip  () 18)
(defun peb-sld-lw-fill  ()  5)   ; every material fill at 0.05 — golden rule M3
(defun peb-sld-lw-thin  ()  9)

;; ---------------------------------------------------------------------------
;; 2) PRIMITIVES THAT CARRY A PEN
;;    peb-line / peb-poly (MAIMAAR_PEB_Standard.lsp) set NO lineweight, so anything drawn
;;    through them inherits LWDEFAULT 0.25 and a 0.50 leaf outline would plot the same as a
;;    0.05 rib. These are the same entmake with (cons 370 lw) added — nothing more.
;; ---------------------------------------------------------------------------
(defun peb-sld-ln (x1 y1 x2 y2 lw)
  (entmake (list (cons 0 "LINE") (cons 8 (peb-sld-layer)) (cons 370 lw)
                 (list 10 x1 y1 0.0) (list 11 x2 y2 0.0))))

(defun peb-sld-lnL (x1 y1 x2 y2 lay lw)
  (entmake (list (cons 0 "LINE") (cons 8 lay) (cons 370 lw)
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

(defun peb-sld-tri (p1 p2 p3 lay)
  (entmake (list (cons 0 "SOLID") (cons 8 lay)
                 (list 10 (car p1) (cadr p1) 0.0) (list 11 (car p2) (cadr p2) 0.0)
                 (list 12 (car p3) (cadr p3) 0.0) (list 13 (car p3) (cadr p3) 0.0))))

;; A dashed line drawn as STROKES, not as a linetype. The engine already refuses to trust a
;; pattern it cannot see (real HATCH fails under acad /b, so peb-mezz-hatch strokes its own 45
;; lines). Same here: an entity naming a linetype the drawing's table lacks is REJECTED IN
;; SILENCE — the parked leaf simply is not there, and nothing appears in the log.
(defun peb-sld-dash (x1 y1 x2 y2 lw dash / dx dy len n i t0 t1 st)
  (if (or (null dash) (<= dash 0.0)) (setq dash 180.0))
  (setq dx (- x2 x1) dy (- y2 y1) len (sqrt (+ (* dx dx) (* dy dy))) st (* dash 1.6))
  (if (> len 1.0)
    (progn
      (setq n (max 1 (fix (/ len st))) i 0)
      (while (< i n)
        (setq t0 (/ (* i st) len) t1 (min 1.0 (/ (+ (* i st) dash) len)))
        (peb-sld-ln (+ x1 (* dx t0)) (+ y1 (* dy t0))
                    (+ x1 (* dx t1)) (+ y1 (* dy t1)) lw)
        (setq i (1+ i)))))
  (princ))

(defun peb-sld-dash-box (x0 y0 x1 y1 lw dash)
  (peb-sld-dash x0 y0 x1 y0 lw dash) (peb-sld-dash x1 y0 x1 y1 lw dash)
  (peb-sld-dash x1 y1 x0 y1 lw dash) (peb-sld-dash x0 y1 x0 y0 lw dash)
  (princ))

;; The layer, made batch-safe: entmake, never (command "_.LAYER"). If PEB_LAYERS.csv has already
;; been played in (the normal engine run) tblsearch finds it and this touches nothing.
(defun peb-sld-layer-ensure ()
  (if (not (tblsearch "LAYER" (peb-sld-layer)))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 (peb-sld-layer))
                   (cons 70 0) (cons 62 (peb-sld-aci)))))
  (setvar "CLAYER" (peb-sld-layer))
  (princ))

(defun peb-sld-layer-need (nm col)
  (if (not (tblsearch "LAYER" nm))
    (entmake (list (cons 0 "LAYER") (cons 100 "AcDbSymbolTableRecord")
                   (cons 100 "AcDbLayerTableRecord") (cons 2 nm) (cons 70 0) (cons 62 col))))
  (princ))

;; ---------------------------------------------------------------------------
;; 3) THE PANEL FIELD
;;    MSPL-030 divides a 3495 field as 302 | 1448 | 1448 | 302 — whole panels in the middle and
;;    an equal closer at each end. That is the rule, not the numbers: as many whole panels as
;;    fit, the remainder split evenly between the two closers.
;;    Returns the joint offsets from the field's left edge (the two ends excluded).
;; ---------------------------------------------------------------------------
(defun peb-sld-joints (w / pw n closer i x out)
  (setq pw (peb-sld-panel-w))
  (setq n (fix (/ w pw)))
  (if (< n 1) (setq n 1))
  (setq closer (/ (- w (* n pw)) 2.0))
  ;; a closer narrower than an eighth of a panel reads as a slip, not as a closer — drop one
  ;; whole panel and let the two closers grow, which is what a detailer does on the board.
  ;; THE THRESHOLD IS CALIBRATED, NOT GUESSED: MSPL-030's own closer is 302 on a 1448 panel,
  ;; i.e. 0.209. A 0.20 guard threw that very case away and collapsed 302|1448|1448|302 into
  ;; 1002|1448|1002 — the drawing the rule was derived from stopped reproducing.
  (if (and (> n 1) (< closer (* pw 0.12)))
    (progn (setq n (1- n)) (setq closer (/ (- w (* n pw)) 2.0))))
  (setq out (list closer) x closer i 0)
  (while (< i n)
    (setq x (+ x pw))
    (if (< x (- w 1.0)) (setq out (cons x out)))
    (setq i (1+ i)))
  (reverse out))

;; ---------------------------------------------------------------------------
;; 4) ONE LEAF, in its CLOSED position — exactly as MSPL-027 and MSPL-030 draw it.
;;      x0 y0   bottom-left of the leaf        w h   leaf size
;;      ribs    T = the sandwich rib field, nil = leave it clear
;;
;;    Order matters: rib field first at 0.05, then the panel joints, then the trims, so every
;;    member plots over the fill and nothing competes with the outline.
;; ---------------------------------------------------------------------------
(defun peb-sld-leaf (x0 y0 w h lead ribs wicket / x1 y1 tw lw th fx0 fx1 x mod)
  ;; lead = +1 the leaf leads to the RIGHT (its meeting strip is at the right-hand end),
  ;;        -1 it leads to the LEFT. On a bi-parting pair the two leaves lead at each other.
  (peb-sld-layer-ensure)
  (if (null lead) (setq lead 1))
  (setq x1 (+ x0 w) y1 (+ y0 h)
        tw (peb-sld-trim-w) lw (peb-sld-lead-w) th (peb-sld-trim-h)
        fx0 (if (> lead 0) (+ x0 tw) (+ x0 lw))
        fx1 (if (> lead 0) (- x1 lw) (- x1 tw)))
  ;; -- SANDWICH PANEL rib field. The module is peb-sandwich-module, declared beside the drawer
  ;;    that owns the profile in MAIMAAR_PEB_Framing.lsp — golden rule 3, ONE source, so the
  ;;    leaf and the wall beside it can never disagree about what a sandwich panel looks like.
  (if ribs
    (progn
      (setq mod (peb-sandwich-module) x (+ fx0 mod))
      (while (< x (- fx1 1.0))
        (peb-sld-ln x (+ y0 th) x (- y1 th) (peb-sld-lw-fill))
        (setq x (+ x mod)))))
  ;; -- panel joints
  (foreach j (peb-sld-joints (- fx1 fx0))
    (peb-sld-ln (+ fx0 j) (+ y0 th) (+ fx0 j) (- y1 th) (peb-sld-lw-mem)))
  ;; -- the leading strip and the jamb-end COVER_TRIM, plus the top and bottom bands (TR-1/TR-2)
  (peb-sld-box x0 y0 fx0 y1 (peb-sld-lw-out))
  (peb-sld-box fx1 y0 x1 y1 (peb-sld-lw-out))
  ;; the meeting stile, drawn inside the leading strip
  (if (> lead 0)
    (peb-sld-ln (- x1 (* lw 0.45)) (+ y0 th) (- x1 (* lw 0.45)) (- y1 th) (peb-sld-lw-mem))
    (peb-sld-ln (+ x0 (* lw 0.45)) (+ y0 th) (+ x0 (* lw 0.45)) (- y1 th) (peb-sld-lw-mem)))
  (peb-sld-ln fx0 (+ y0 th) fx1 (+ y0 th) (peb-sld-lw-mem))
  (peb-sld-ln fx0 (- y1 th) fx1 (- y1 th) (peb-sld-lw-mem))
  ;; -- the wicket door (ONE per door, not one per leaf), then the outline last, heaviest
  (if wicket (peb-sld-wicket x0 y0 w h lead))
  (peb-sld-box x0 y0 x1 y1 (peb-sld-lw-out))
  (princ))

;; THE WICKET DOOR in the leaf. Drawn as the opening it is: a frame, the leaf line inside it,
;; a handle, and the sill it stands on. lead says which end of the leaf to set it in from — it
;; goes at the TRAILING end, away from the meeting stile, so it clears the jamb when closed.
(defun peb-sld-wicket (x0 y0 w h lead / wx wy ww wh f)
  (peb-sld-layer-ensure)
  (setq ww (peb-sld-wicket-w) wh (peb-sld-wicket-h)
        wy (+ y0 (peb-sld-wicket-sill))
        wx (if (> lead 0)
             (+ x0 (peb-sld-lead-w) (peb-sld-wicket-off))      ; leads right -> wicket at the left
             (- (+ x0 w) (peb-sld-lead-w) (peb-sld-wicket-off) ww))
        f  38.0)
  ;; only if it actually fits inside the panel field with something to spare
  (if (and (> w (+ ww (* 3.0 (peb-sld-lead-w)))) (> h (+ wh (peb-sld-wicket-sill) 150.0)))
    (progn
      (peb-sld-box wx wy (+ wx ww) (+ wy wh) (peb-sld-lw-out))
      (peb-sld-box (+ wx f) (+ wy f) (- (+ wx ww) f) (- (+ wy wh) f) (peb-sld-lw-mem))
      ;; the handle, on the side it opens from
      (peb-sld-ln (- (+ wx ww) (* f 4.0)) (+ wy (* wh 0.45))
                  (- (+ wx ww) (* f 4.0)) (+ wy (* wh 0.55)) (peb-sld-lw-clip))
      (peb-sld-tx (+ wx (/ ww 2.0)) (- wy (* (peb-sld-dim-th) 1.1)) (peb-sld-dim-th) 0.0
                  "WICKET DOOR" "TEXT" 1 2)))
  (princ))

;; a U-CLIP / DOOR_WHEEL bracket — the little square that sits on the bottom rail under each
;; leaf corner and each panel joint (MSPL-027 UCL-1/2, MSPL-030 DOOR_WHEEL)
(defun peb-sld-clip (cx y / c r)
  ;; the bracket, and the WHEEL in it. MSPL-121 draws the wheels as filled discs on the rail and
  ;; calls them WHEEL DIA 20mm; MSPL-176 lists 2 no. per leaf. This is a BOTTOM-ROLLING door -
  ;; the wheel runs ON the D12 round bar and the top channel only guides it.
  (setq c (/ (peb-sld-clip-w) 2.0) r (/ (peb-sld-wheel-dia) 2.0))
  (peb-sld-box (- cx c) (- y c) (+ cx c) (+ y c) (peb-sld-lw-clip))
  (entmake (list (cons 0 "CIRCLE") (cons 8 (peb-sld-layer)) (cons 370 (peb-sld-lw-clip))
                 (list 10 cx (- y c) 0.0) (cons 40 (max r (* c 0.30)))))
  (princ))

(defun peb-sld-leaf-clips (x0 y0 w lead / tw lw fx0 fx1)
  (if (null lead) (setq lead 1))
  (setq tw (peb-sld-trim-w) lw (peb-sld-lead-w)
        fx0 (if (> lead 0) (+ x0 tw) (+ x0 lw))
        fx1 (if (> lead 0) (- (+ x0 w) lw) (- (+ x0 w) tw)))
  (peb-sld-clip (+ x0 (* tw 0.5)) y0)
  (peb-sld-clip (- (+ x0 w) (* tw 0.5)) y0)
  (foreach j (peb-sld-joints (- fx1 fx0)) (peb-sld-clip (+ fx0 j) y0))
  (princ))

;; ---------------------------------------------------------------------------
;; 5) THE HEAD — the U-channel track the wheels run in, its clips, and the hood trim over it.
;;    The track must run the WHOLE slide length or the drawing promises a door that cannot open.
;; ---------------------------------------------------------------------------
(defun peb-sld-track (xa xb ytop / yb x)
  (peb-sld-layer-ensure)
  (setq yb (- ytop (peb-sld-track-dep)))
  ;; the channel itself, INSIDE the hood that covers it — drawn light, because on the elevation
  ;; it is behind the trim and only its line shows
  (peb-sld-ln xa yb xb yb (peb-sld-lw-mem))
  (setq x (+ xa (peb-sld-stub-2nd)))
  (while (< x (- xb 200.0))
    (peb-sld-ln x ytop x (+ ytop (peb-sld-clip-w)) (peb-sld-lw-clip))
    (setq x (+ x (* 2.0 (peb-sld-stub-typ)))))
  (princ))

(defun peb-sld-hood (xa xb ytop)
  ;; HOOD_TRIM, the band the elevation actually shows at the head: from the track soffit up
  ;; over the channel and the wheels. One band, not a band on top of another band.
  (peb-sld-layer-ensure)
  (peb-sld-box xa (- ytop (peb-sld-track-dep)) xb (+ ytop (peb-sld-hood-dep))
               (peb-sld-lw-track))
  (princ))

;; ---------------------------------------------------------------------------
;; 6) THE FLOOR — the bottom rail and the D12 guide, on stubs at 125 / 890 / 990.
;;    This is what DOOR_ROUND_BAR actually is. It is not a brace.
;; ---------------------------------------------------------------------------
(defun peb-sld-floor (xa xb yffl / yb x)
  (peb-sld-layer-ensure)
  (setq yb (- yffl (peb-sld-rail-dep)))
  (peb-sld-ln xa yffl xb yffl (peb-sld-lw-track))
  (peb-sld-ln xa yb   xb yb   (peb-sld-lw-track))
  (setq x (+ xa (peb-sld-stub-end)))
  (peb-sld-ln x yb x (- yb (peb-sld-stub-h)) (peb-sld-lw-clip))
  (setq x (+ x (peb-sld-stub-2nd)))
  (while (< x (- xb (peb-sld-stub-end)))
    (peb-sld-ln x yb x (- yb (peb-sld-stub-h)) (peb-sld-lw-clip))
    (setq x (+ x (peb-sld-stub-typ))))
  (setq x (- xb (peb-sld-stub-end)))
  (peb-sld-ln x yb x (- yb (peb-sld-stub-h)) (peb-sld-lw-clip))
  (princ))

;; ---------------------------------------------------------------------------
;; 7) THE FRAMED OPENING — the 200C jamb each side and the header the track hangs from.
;; ---------------------------------------------------------------------------
(defun peb-sld-opening (ox oy ow oh / d xl xr yt)
  (peb-sld-layer-ensure)
  (setq d (peb-sld-jamb-dep) xl ox xr (+ ox ow) yt (+ oy oh))
  (peb-sld-ln (- xl d) oy (- xl d) yt (peb-sld-lw-track))
  (peb-sld-ln xl oy xl yt (peb-sld-lw-track))
  (peb-sld-ln xr oy xr yt (peb-sld-lw-track))
  (peb-sld-ln (+ xr d) oy (+ xr d) yt (peb-sld-lw-track))
  (peb-sld-ln (- xl d) yt (+ xr d) yt (peb-sld-lw-track))
  (peb-sld-ln (- xl d) (+ yt d) (+ xr d) (+ yt d) (peb-sld-lw-track))
  (princ))

;; ---------------------------------------------------------------------------
;; 8) THE LEAF IN ITS PARKED POSITION, and the slide arrow.
;;    A sliding door that shows only the closed leaf tells the customer nothing about the wall
;;    it needs. MSPL-027 parks a 2313 leaf into 2152 of clear wall; MSPL-030 needs a whole leaf
;;    each side. Drawn dashed as strokes so it can never be mistaken for the leaf itself.
;; ---------------------------------------------------------------------------
(defun peb-sld-ghost (x0 y0 w h / th)
  (peb-sld-layer-ensure)
  (peb-sld-dash-box x0 y0 (+ x0 w) (+ y0 h) (peb-sld-lw-mem) 200.0)
  (setq th (max 90.0 (* h 0.075)))
  (peb-sld-tx (+ x0 (/ w 2.0)) (+ y0 (* h 0.55)) th 0.0 "LEAF PARKED" "TEXT" 1 2)
  (peb-sld-tx (+ x0 (/ w 2.0)) (+ y0 (* h 0.55) (* th -1.6)) th 0.0 "(DOOR OPEN)" "TEXT" 1 2)
  (princ))

(defun peb-sld-arrow (x y len dir / xe hl)
  (peb-sld-layer-ensure)
  (setq xe (+ x (* dir len)) hl (* len 0.18))
  (peb-sld-ln x y xe y (peb-sld-lw-clip))
  (peb-sld-tri (list xe y)
               (list (- xe (* dir hl)) (+ y (* hl 0.42)))
               (list (- xe (* dir hl)) (- y (* hl 0.42))) (peb-sld-layer))
  (princ))

;; ---------------------------------------------------------------------------
;; 9) THE COMPLETE ELEVATION.
;;      ox oy   bottom-left of the FRAMED OPENING, on FFL
;;      ow oh   framed opening, clear
;;      leaves  1 = single sliding door (SSD), 2 = double / bi-parting (DSD)
;;      hand    SINGLE leaf only: +1 parks to the right, -1 to the left. Ignored when leaves=2.
;;      lbl     callout under the door, or nil
;;    Returns (xmin ymin xmax ymax), so a caller placing it on a sheeting elevation knows what
;;    to keep clear — the door needs far more wall than the opening.
;; ---------------------------------------------------------------------------
(defun peb-sld-elevation (ox oy ow oh leaves hand lbl
                          / lw lh lb lt ytop tx0 tx1 xL xR run th)
  (peb-sld-layer-ensure)
  (if (null hand) (setq hand -1))
  (setq lb   (+ oy (peb-sld-sill-clr))
        lt   (+ oy oh (peb-sld-head-lap))
        lh   (- lt lb)
        ytop (+ lt (peb-sld-track-gap) (peb-sld-track-dep)))
  (peb-sld-opening ox oy ow oh)
  (if (= leaves 2)
    (progn
      (setq lw  (+ (/ ow 2.0) (peb-sld-meet-lap))
            xL  (- ox (peb-sld-meet-lap))
            xR  (+ ox (/ ow 2.0))
            run (+ lw 100.0)
            tx0 (- xL run)
            tx1 (+ xR lw run))
      (peb-sld-track tx0 tx1 ytop)
      (peb-sld-hood  tx0 tx1 ytop)
      (peb-sld-floor tx0 tx1 oy)
      (peb-sld-ghost (- xL run) lb lw lh)
      (peb-sld-ghost (+ xR lw 100.0) lb lw lh)
      (peb-sld-leaf xL lb lw lh  1 T T)        ; left leaf leads RIGHT, and carries the wicket
      (peb-sld-leaf xR lb lw lh -1 T nil)      ; right leaf leads LEFT
      (peb-sld-leaf-clips xL lb lw  1)
      (peb-sld-leaf-clips xR lb lw -1)
      (peb-sld-arrow (+ xL (* lw 0.5)) (+ lb (* lh 0.62)) (* lw 0.30) -1)
      (peb-sld-arrow (+ xR (* lw 0.5)) (+ lb (* lh 0.62)) (* lw 0.30)  1))
    (progn
      (setq lw  (+ ow (* 2.0 (peb-sld-meet-lap)))
            xL  (- ox (peb-sld-meet-lap))
            run (+ lw 100.0)
            tx0 (if (> hand 0) (- xL 100.0) (- xL run))
            tx1 (if (> hand 0) (+ xL lw run) (+ xL lw 100.0)))
      (peb-sld-track tx0 tx1 ytop)
      (peb-sld-hood  tx0 tx1 ytop)
      (peb-sld-floor tx0 tx1 oy)
      (peb-sld-ghost (if (> hand 0) (+ xL lw 100.0) (- xL run)) lb lw lh)
      (peb-sld-leaf xL lb lw lh (- 0 hand) T T) ; the leading edge is the one that closes
      (peb-sld-leaf-clips xL lb lw (- 0 hand))
      (peb-sld-arrow (+ xL (* lw 0.5)) (+ lb (* lh 0.62)) (* lw 0.22) hand)))
  (if lbl
    (progn
      (setq th (max 90.0 (* oh 0.055)))
      (peb-sld-tx (+ ox (/ ow 2.0))
                  (- oy (peb-sld-rail-dep) (peb-sld-stub-h) (* th 1.9)) th 0.0
                  lbl "TEXT" 1 2)))
  (list tx0 (- oy (peb-sld-rail-dep) (peb-sld-stub-h)) tx1 (+ ytop (peb-sld-hood-dep))))

;; ---------------------------------------------------------------------------
;; 10) THE PLAN SYMBOL — the one Maimaar already issues.
;;     Traced from reference/MSPL-030_2021_APPROVAL-sheet18_sliding-door-on-elevation.pdf, the
;;     sheet the customer signs: the wall band BREAKS at the opening and becomes a BOW-TIE —
;;     each leaf a wedge tapering from the full wall thickness at its own jamb to a point where
;;     the leaves meet — annotated on two centred lines,
;;
;;            SLIDING DOOR
;;             2438 x 3048
;;
;;     The first version of this function invented an offset line with a dashed pocket. It was
;;     readable and it was wrong: there is already a house symbol, and a component that draws
;;     its own makes two sheets of the same job disagree.
;; ---------------------------------------------------------------------------
(defun peb-sld-plan (ox oy ow wt leaves lbl / xm yb ym th c)
  (peb-sld-layer-ensure)
  (peb-sld-layer-need "SHEETING" 4)
  (if (or (null wt) (<= wt 0.0)) (setq wt 100.0))
  (setq yb (- oy wt) xm (+ ox (/ ow 2.0)) ym (/ (+ oy yb) 2.0))
  (peb-sld-lnL (- ox (* ow 1.6)) oy ox oy "SHEETING" 25)
  (peb-sld-lnL (- ox (* ow 1.6)) yb ox yb "SHEETING" 25)
  (peb-sld-lnL (+ ox ow) oy (+ ox ow (* ow 1.6)) oy "SHEETING" 25)
  (peb-sld-lnL (+ ox ow) yb (+ ox ow (* ow 1.6)) yb "SHEETING" 25)
  (if (= leaves 2)
    (progn
      (peb-sld-pl (list (list ox oy) (list xm ym) (list ox yb)) (peb-sld-lw-mem) nil)
      (peb-sld-pl (list (list (+ ox ow) oy) (list xm ym) (list (+ ox ow) yb))
                  (peb-sld-lw-mem) nil))
    (peb-sld-pl (list (list ox oy) (list (+ ox ow) ym) (list ox yb)) (peb-sld-lw-mem) nil))
  ;; RULE 14 — scaled off the DOOR, through the one dial, not off the opening width. Off the
  ;; opening it came out 438 tall on a 7972 door and buried the symbol it was labelling.
  (setq th (peb-sld-dim-th) c (+ oy (* th 1.2)))
  (peb-sld-tx xm (+ c (* th 1.6)) th 0.0 "SLIDING DOOR" "TEXT" 1 2)
  (peb-sld-tx xm c th 0.0 (if lbl lbl (strcat (rtos ow 2 0) " WIDE")) "TEXT" 1 2)
  (princ))

;; ---------------------------------------------------------------------------
;; 11) WALL CONTEXT — DEVELOPMENT ONLY. The building engine draws its own wall; this exists so
;;     the door can be judged in a wall on the sample sheet. On SHEETING and GIRTS, never on
;;     the door's own layer: the first render put it there and the whole elevation read as door.
;; ---------------------------------------------------------------------------
(defun peb-sld-context (xa xb ybot ytop ox ow cover girt / x y)
  (peb-sld-layer-need "SHEETING" 4)
  (peb-sld-layer-need "GIRTS" 6)
  (if (or (null cover) (<= cover 0.0)) (setq cover (peb-sheet-rib-pitch)))
  (if (or (null girt)  (<= girt  0.0)) (setq girt 1800.0))
  (setq x xa)
  (while (< x xb)
    (if (or (< x (- ox (peb-sld-jamb-dep))) (> x (+ ox ow (peb-sld-jamb-dep))))
      (peb-sld-lnL x ybot x ytop "SHEETING" 9))
    (setq x (+ x cover)))
  (setq y girt)
  (while (< y ytop)
    (peb-sld-lnL xa y (- ox (peb-sld-jamb-dep)) y "GIRTS" 13)
    (peb-sld-lnL (+ ox ow (peb-sld-jamb-dep)) y xb y "GIRTS" 13)
    (setq y (+ y girt)))
  (peb-sld-lnL xa ytop xb ytop "SHEETING" 13)
  (peb-sld-lnL xa ybot xb ybot "SHEETING" 25)
  (princ))

;;; ============================================================================
;;;  12) SAMPLE — MSPL-030 SDS-01 REPRODUCED.
;;;
;;;  Not an invented "standard size". The sample draws the DOUBLE SLIDING DOOR of MSPL-030,
;;;  Awan Sports, Initial Paddle Sanding Hall, issued for erection 01-Apr-2022, at the sizes
;;;  MEASURED off that sheet's own vectors:
;;;
;;;      assembly           7972 (8382 over the trims), set 410 off grid 1
;;;      leaf               3986 each, two leaves
;;;      leaf height        2430 (2462 over trims), underside 12 clear of FFL
;;;      panel field        302 | 1448 | 1448 | 302
;;;      floor rail stubs   125 | 890 | 990 x6 | 890 | 125
;;;
;;;  So it can be laid beside reference/MSPL-030_2022_SDS-01_*.pdf and compared line for line.
;;;  DEVELOPMENT CODE — the building engine never calls it; it calls peb-sld-elevation /
;;;  peb-sld-plan with numbers from the BSF.
;;; ============================================================================

;; RULE 14 — peb-th's text ladder is tuned for a sheet showing a 48 m building; used unchanged
;; on a 2.4 m door the callouts come out taller than the door. A component sets its own, scaled
;; off WHAT IS DRAWN. *PEB-SLD-TXT* is the one dial; everything annotative reads it.
(setq *PEB-SLD-TXT* 110.0)
(defun peb-sld-set-txt (h) (setq *PEB-SLD-TXT* (max 60.0 h)) (princ))
(defun peb-sld-dim-th () (if *PEB-SLD-TXT* *PEB-SLD-TXT* 110.0))

;; RULE 16 — the text goes on the FAR side of the dimension line from the object it measures.
;; side is +1 when the object is ABOVE / RIGHT of the line, -1 when it is BELOW / LEFT.
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

(defun peb-sld-sample (/ ow oh ext y x lw f0 f1 tx0 tx1)
  (peb-sld-layer-ensure)
  (peb-sld-layer-need "TEXT" 7)
  (peb-sld-layer-need "DIMENSIONS" 6)
  ;; MSPL-121 DOOR DETAILS, PAECO Skardu, issued for approval 02-Jul-2024 - the most complete
  ;; PD-level sliding door sheet in the archive, and the current convention. It carries a DOOR
  ;; PLAN and a DOOR ELEVATION, which is exactly what the proposal set has to emit.
  ;;   opening   9144 [30'] x 2438 [8']      DOUBLE SLIDING DOOR
  ;;   run       18288 [60'] = 9144 + 2 x 4572, i.e. each leaf parks its own width clear
  ;;   wicket    914 [3'] x 1981 [6'-6"], sill 305 [1'], in one leaf
  ;; Maimaar sizes these doors in FEET; every metric figure here is the conversion.
  (setq ow 9144.0 oh 2438.0)
  (peb-sld-set-txt (* oh 0.048))

  ;; the wall the door sits in - development scaffolding, not part of the component
  (peb-sld-context -6500.0 15700.0 0.0 4000.0 0.0 ow nil 1500.0)

  (setq ext (peb-sld-elevation 0.0 0.0 ow oh 2 nil
              "DOUBLE SLIDING DOOR  9144 [30'] x 2438 [8']  -  MSPL-121 REPRODUCED"))
  (setq tx0 (nth 0 ext) tx1 (nth 2 ext))

  ;; ---- the dimension strings the issued sheet carries
  (peb-sld-dim-h 0.0 ow (+ oh 1500.0) -1 "9144 [30]  FRAMED OPENING")
  (peb-sld-dim-h tx0 tx1 (+ oh 2200.0) -1
                 "18288 [60]  RUN  -  EACH LEAF PARKS ITS OWN WIDTH CLEAR OF THE OPENING")
  (setq lw (+ (/ ow 2.0) (peb-sld-meet-lap))
        f0 (+ (- 0.0 (peb-sld-meet-lap)) (peb-sld-trim-w))
        f1 (- (/ ow 2.0) (peb-sld-lead-w)))
  (peb-sld-dim-h (- 0.0 (peb-sld-meet-lap)) (/ ow 2.0) (- 0.0 900.0) 1 "4647  LEAF")
  (peb-sld-dim-h (/ ow 2.0) (+ ow (peb-sld-meet-lap)) (- 0.0 900.0) 1 "4647  LEAF")
  ;; the panel field of the left leaf, joint by joint
  (setq x f0)
  (foreach j (peb-sld-joints (- f1 f0))
    (peb-sld-dim-h x (+ f0 j) (- 0.0 1500.0) 1 (rtos (- (+ f0 j) x) 2 0))
    (setq x (+ f0 j)))
  (peb-sld-dim-h x f1 (- 0.0 1500.0) 1 (rtos (- f1 x) 2 0))
  (peb-sld-dim-h f1 (/ ow 2.0) (- 0.0 1500.0) 1 "539")
  (peb-sld-dim-v (peb-sld-sill-clr) (+ oh (peb-sld-head-lap)) (- tx0 900.0) 1 "2526  LEAF")
  (peb-sld-dim-v 0.0 oh (- tx0 1800.0) 1 "2438 [8]  CLEAR")

  ;; ---- the plan symbol, as issued on the approval sheet
  (peb-sld-plan 0.0 -3600.0 ow 150.0 2 "9144 x 2438")
  (peb-sld-tx (/ ow 2.0) -4700.0 (* (peb-sld-dim-th) 1.3) 0.0
              "PLAN SYMBOL  -  AS ISSUED ON THE APPROVAL DRAWING" "TEXT" 1 2)

  ;; ---- the member table, as MSPL-176 issues it (the current schedule)
  (setq y -5800.0)
  (foreach s '("SLIDING DOOR  -  MEMBER TABLE   (MSPL-176 2025, THE CURRENT SCHEDULE)"
               "U-CHANNEL # 01     96 x 70 x 3           TOP TRACK, FULL RUN"
               "U-CHANNEL # 02     80 x 50 x 2           LEAF TOP RAIL"
               "U-CHANNEL # 03     85 x 50 x 3           LEAF BOTTOM RAIL"
               "U-CHANNEL # 04     50 x 50 x 3"
               "U-CHANNEL # 05     200 x 60 x 20 x 1.5   JAMB AND HEADER"
               "TUBE               40 x 40 x 2           LEAF FRAME  (14 SWG)"
               "L-ANGLE # 01       38 x 38 x 3           FULL RUN"
               "L-ANGLE # 02       50 x 50 x 3 x 100     CLIPS, 8 No."
               "DOUBLE ANGLE # 01  50 x 50 x 3           FLOOR VEE"
               "ROUND BAR          D 12                  THE FLOOR RAIL"
               "WHEEL              D 20                  2 No. - IT RUNS ON THE RAIL"
               "CONNECTION PLATE   150 x 60 x 5, BOLT D 12"
               "INFILL             SANDWICH PANEL        (MSPL-121 USED PRIME SHEET 16 SWG)"
               "WICKET DOOR        914 [3] x 1981 [6-6], SILL 305 [1]"
               ""
               "NOTE  -  THERE IS NO DIAGONAL BRACE. THE D12 ROUND BAR IS THE FLOOR RAIL AND"
               "         THE WHEEL RUNS ON IT: THIS IS A BOTTOM-ROLLING DOOR, TOP-GUIDED."
               "         THE STILE GRID IS BEHIND THE PANEL AND IS NOT DRAWN IN ELEVATION."
               "         MAIMAAR SIZES THESE DOORS IN FEET; THE METRIC FIGURES CONVERT.")
    (peb-sld-tx (- tx0 1000.0) y (* (peb-sld-dim-th) 1.25) 0.0 s "TEXT" 0 2)
    (setq y (- y (* (peb-sld-dim-th) 2.1))))
  (princ "
SLIDING DOOR sample drawn: MSPL-121, double leaf, 9144 x 2438, with wicket.")
  (princ))


;; command wrapper, so the sample can also be drawn by hand inside an open AutoCAD
(defun c:SLDSAMPLE () (peb-sld-sample))

(princ "\nMAIMAAR_PEB_SlidingDoor.lsp loaded  -  peb-sld-elevation / peb-sld-plan / SLDSAMPLE")
(princ)
