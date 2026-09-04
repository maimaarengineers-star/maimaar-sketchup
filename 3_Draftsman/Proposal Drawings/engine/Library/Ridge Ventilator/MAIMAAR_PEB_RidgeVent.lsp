;;; ============================================================================
;;;  MAIMAAR_PEB_RidgeVent.lsp — GRAVITY RIDGE VENTILATOR   ***SYMBOL ONLY***
;;;  PEB COMPONENT LIBRARY — Library/Ridge Ventilator/
;;; ============================================================================
;;;
;;;  SCOPE — READ THIS FIRST.
;;;
;;;  "Only symbol for the Proposal Drawings ... In Next Phases we will develop the complete
;;;   in all respect. Symbol means should be excellent presentation once we should place in
;;;   the PD Section and Elevation."  — owner, 4-Sep-2026
;;;
;;;  So this file draws a SYMBOL, deliberately: the ventilator's true outside profile at its
;;;  true size, placed correctly on the ridge, drawn well enough to carry a proposal — and
;;;  NOT its 20-odd fabricated parts. The approval drawing has those (L-1..L-5A, T-1..T-4,
;;;  CH-1, CL-1, CL-2, MSB bolts, screws) and a later phase will draw them. A proposal sheet
;;;  at 1:150 cannot show a 0.5 mm brace plate and should not pretend to.
;;;
;;;  A symbol is not a licence to invent. EVERY dimension below is traced off Maimaar's own
;;;  approval drawing, so the symbol is the real thing simplified — never a cartoon.
;;;
;;;  ── WHAT IT IS FOR ───────────────────────────────────────────────────────────────────
;;;  The ridge ventilator is the OUTLET of the ventilation system. The louvers are the
;;;  INTAKE (Library/Louver/). Air enters low through the louvers, warms, rises, and is
;;;  discharged here at the ridge. The two are one system: the reference manual sizes them
;;;  against each other — free INLET area must exceed 150% of the ventilation area.
;;;
;;;  ── TRACED, from MSPL-203 (Afridi Markets / DHL Warehouse, 2025) ─────────────────────
;;;  The job where the ridge ventilator was IN MAIMAAR'S OWN SCOPE, so its approval sheet
;;;  "RIDGE VENTILATOR DETAILS" (drawing 20) is Maimaar's own product, not a manual's.
;;;  SECTION A-A (FRAMING) dimensions it completely:
;;;
;;;         overall width            600            (300 + 300 about the ridge)
;;;         overall height           542            above the roof line at the ridge
;;;         hood underside           288            clear of the roof sheet — THE THROAT
;;;         wind-band (skirt) depth  203
;;;         top flat                 400            with a 120 turned-down return each end
;;;         unit length             3000            TOP VIEW, and the RV-01 legend
;;;         bird mesh              12 x 12 GI       TOP VIEW note
;;;         purlins                200Z 1.5         either side of the opening
;;;
;;;  Cross-checked against the industry manual's Section 13.7 table (reference/NOTES.md):
;;;  MRV 300 / MRV 600, both 3000 mm long, throat area = throat x length, and the damper is
;;;  an option on the 300 only. Maimaar's own unit is a 600 throat (300 + 300).
;;;
;;;  ── HOW IT IS PRESENTED ──────────────────────────────────────────────────────────────
;;;  On a 22.8 m cross section a 542 mm hood is 3 mm of paper. It reads because of PEN and
;;;  because the THROAT IS LEFT OPEN — the gap under the hood is the one feature that says
;;;  "ventilator" rather than "box on the ridge", so the outline is deliberately NOT closed
;;;  along the bottom. The proposal PDF plots monochrome, so pen is the only signal that
;;;  survives (MAIMAAR_PEB_PDF.lsp:90 / :140, drawingRender.ts:394 / :1263).
;;;
;;;      hood outline   RIDGE-VENT  0.50      throat / mesh hint  RIDGE-VENT  0.13
;;;      roof sheeting  SHEETING    0.09      leader + text       TEXT        0.13
;;;
;;;  ── STANDING RULES OBSERVED ──────────────────────────────────────────────────────────
;;;   * PURE GEOMETRY. Everything arrives as an argument; nothing here reads the BSF. The
;;;     one exception is the sample harness at the bottom, which is marked as such.
;;;   * Layers from Rule_Book/PEB_LAYERS.csv. RIDGE-VENT was added there rather than
;;;     inventing another ad-hoc layer (golden rule M4).
;;;   * No hand-driven LAYER / STYLE / TEXT via `command` — an open acad prompt eats the
;;;     rest of the script silently.
;;;   * Dimensions are LINE + TEXT primitives, never DIM commands.
;;;   * mm, 1:1 in model space.
;;; ============================================================================

;; ---- TRACED CONSTANTS (MSPL-203, SECTION A-A + TOP VIEW) -------------------
(defun peb-rv-half     () 300.0)    ; 300 + 300 about the ridge = 600 overall
(defun peb-rv-height   () 542.0)    ; apex above the roof line at the ridge
(defun peb-rv-throat   () 288.0)    ; clear gap, roof sheet to hood underside
(defun peb-rv-skirt    () 203.0)    ; wind band depth
(defun peb-rv-top-flat () 400.0)    ; flat between the two turned-down returns
(defun peb-rv-return   () 120.0)    ; the turned-down return at each top edge
(defun peb-rv-len      () 3000.0)   ; one unit, TOP VIEW and the RV-01 legend
(defun peb-rv-mesh     () "12 x 12 G.I. BIRD MESH")

;; ---- PENS (1/100 mm — the only signal that survives the monochrome plot) ---
(defun peb-rv-lw       ()  50)      ; hood outline      0.50
(defun peb-rv-lw-thin  ()  13)      ; throat / mesh     0.13
(defun peb-rv-layer    () "RIDGE-VENT")
(defun peb-rv-aci      ()  4)

;; Derived: the top of the wind band, and where the hood roof starts.
(defun peb-rv-skirt-top () (+ (peb-rv-throat) (peb-rv-skirt)))   ; 288 + 203 = 491

;; ---------------------------------------------------------------------------
;;  ENTITY HELPERS — each carries an explicit pen, because peb-comp-layer sets colour
;;  only and anything it invents would inherit LWDEFAULT 0.25.
;; ---------------------------------------------------------------------------
(defun peb-rv-line (x0 y0 x1 y1 lay lw)
  (entmake (list (cons 0 "LINE") (cons 8 lay) (cons 370 lw)
                 (list 10 x0 y0 0.0) (list 11 x1 y1 0.0))))

(defun peb-rv-poly (pts lw closed / e lay)
  (setq lay (getvar "CLAYER")
        e (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 lay)
                (cons 370 lw) (cons 100 "AcDbPolyline")
                (cons 90 (length pts)) (cons 70 (if closed 1 0))))
  (foreach p pts (setq e (append e (list (list 10 (car p) (cadr p))))))
  (entmake e))

(defun peb-rv-txt (just pt h rot s)
  (setvar "CLAYER" "TEXT")
  (txt just pt h rot s))

;; ---------------------------------------------------------------------------
;;  THE PROFILE — the hood seen END-ON, which is the view BOTH the cross section and the
;;  end-wall elevation need. Returned as a point list about (0,0) at the ridge, so the
;;  caller only has to know where the ridge is.
;;
;;  Left skirt bottom -> left skirt top -> apex -> right skirt top -> right skirt bottom.
;;  FIVE points, and the bottom is deliberately left OPEN: that gap is the throat, and it
;;  is the whole reason the thing is on the roof.
;; ---------------------------------------------------------------------------
(defun peb-rv-profile (ox oy sc / h thr ktop a pts)
  (if (or (null sc) (<= sc 0.0)) (setq sc 1.0))
  (setq h (* (peb-rv-half) sc) thr (* (peb-rv-throat) sc)
        ktop (* (peb-rv-skirt-top) sc) a (* (peb-rv-height) sc))
  (list (list (- ox h) (+ oy thr)) (list (- ox h) (+ oy ktop)) (list ox (+ oy a))
        (list (+ ox h) (+ oy ktop)) (list (+ ox h) (+ oy thr))))

;; ---------------------------------------------------------------------------
;;  VIEW 1 — THE SYMBOL, END-ON.  Cross section (PRO-02) and end-wall elevation.
;;
;;  ox oy = the RIDGE POINT — where the two roof slopes meet, on the top of the sheeting.
;;  `sc`  = an optional size multiplier. 1.0 draws the ventilator at its true 600 x 542.
;;          A cross section of a 22.8 m building plots that at about 3 mm, which is correct
;;          and legible; a caller that wants it emphasised passes a larger sc and the
;;          drawing stays honest because the LABEL still states the real size.
;;  `mesh` draws the bird-screen hint across the throat — dropped automatically when the
;;          plot is too small for it to be anything but ink.
;; ---------------------------------------------------------------------------
(defun peb-rv-symbol (ox oy sc mesh / lay pts h thr ts i n x step)
  (if (or (null sc) (<= sc 0.0)) (setq sc 1.0))
  (setq lay (peb-rv-layer) pts (peb-rv-profile ox oy sc)
        h (* (peb-rv-half) sc) thr (* (peb-rv-throat) sc)
        ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (peb-comp-layer lay (peb-rv-aci))
  ;; the hood — OPEN along the bottom, because that opening is the throat
  (peb-rv-poly pts (peb-rv-lw) nil)
  ;; the throat itself: the two wind-band bottom edges, drawn light so the hood stays the
  ;; heaviest thing here and the gap between them still reads as a gap.
  (peb-rv-line (- ox h) (+ oy thr) (- ox (* h 0.55)) (+ oy thr) lay (peb-rv-lw-thin))
  (peb-rv-line (+ ox (* h 0.55)) (+ oy thr) (+ ox h) (+ oy thr) lay (peb-rv-lw-thin))
  ;; BIRD SCREEN, only while it can be seen. The mesh is 12 x 12; drawn at that pitch on a
  ;; proposal section it is solid ink, so the hint is a handful of ticks across the throat
  ;; and the real mesh spec stays in the note. Same rule as the louver's blades: density
  ;; follows the PLOT, not the product.
  (if (and mesh (> (/ (* 2.0 h) (max ts 0.01)) 900.0))
    (progn
      (setq n 6 step (/ (* 2.0 h) (float (1+ n))) i 1)
      (while (<= i n)
        (setq x (+ (- ox h) (* i step)))
        (peb-rv-line x (+ oy (* thr 0.15)) x (+ oy (* thr 0.85)) lay (peb-rv-lw-thin))
        (setq i (1+ i)))))
  (princ))

;; ---------------------------------------------------------------------------
;;  VIEW 2 — THE SYMBOL IN PLAN.  The roof plan (PRO-07 / PRO-08).
;;
;;  Maimaar's own roof sheeting plan draws each unit as a heavy 3000 long bar sitting on
;;  the ridge line, with ONE "(TYP.) RIDGE VENTILATOR" callout and the count in the legend
;;  (MSPL-203 drawing 18: RV-01, 3,000, 8 No.). This reproduces that.
;;
;;  Maimaar fills the bar solid. A SOLID reaches the customer BLACK under monochrome.ctb
;;  (golden rule 5), so this draws the outline heavy and rakes it with light lines instead:
;;  it reads as the same dark bar without becoming a black blob that swallows the ridge
;;  line underneath it.
;;
;;  cx = centre of the unit along the ridge, ry = the ridge line's y on the plan.
;; ---------------------------------------------------------------------------
(defun peb-rv-plan (cx ry len sc / lay hw hl i n x step)
  (if (or (null sc) (<= sc 0.0)) (setq sc 1.0))
  (if (or (null len) (<= len 0.0)) (setq len (peb-rv-len)))
  (setq lay (peb-rv-layer) hl (/ len 2.0) hw (* (peb-rv-half) sc))
  (peb-comp-layer lay (peb-rv-aci))
  (peb-rv-poly (list (list (- cx hl) (- ry hw)) (list (+ cx hl) (- ry hw))
                     (list (+ cx hl) (+ ry hw)) (list (- cx hl) (+ ry hw))) (peb-rv-lw) T)
  ;; rake it so it reads dark without a SOLID
  (setq n (max 4 (fix (/ len 250.0))) step (/ len (float (1+ n))) i 1)
  (while (<= i n)
    (setq x (+ (- cx hl) (* i step)))
    (peb-rv-line x (- ry hw) x (+ ry hw) lay (peb-rv-lw-thin))
    (setq i (1+ i)))
  (princ))

;; ---------------------------------------------------------------------------
;;  THE CALLOUT — one per sheet, not one per unit (golden rule 17), in Maimaar's own
;;  wording from MSPL-203: "(TYP.) RIDGE VENTILATOR".  `qty` 0 omits the count.
;;
;;  `th` IS PASSED IN, and the caller takes it from the sheet it is drawing on. peb-th's
;;  ANNOT is 830 raw; the cross section draws its own PURLIN / RAFTER / EAVE GUTTER
;;  callouts at 199, because it scales that ladder by *PEB-TEXT-SCALE*. Handed the raw 830
;;  this label came out 747 tall - three and a half times every other callout on the sheet,
;;  running across the roof note and out over the title block. A component that annotates
;;  a building sheet must speak that sheet's size, not its own.
;; ---------------------------------------------------------------------------
(defun peb-rv-label (ax ay tx ty qty th / s)
  (setq th (if (and th (> th 0.0)) th (peb-th 'ANNOT))
        s (if (and qty (> qty 0))
            (strcat (itoa qty) " No. RIDGE VENTILATOR - " (rtos (peb-rv-len) 2 0) " LONG")
            "(TYP.) RIDGE VENTILATOR"))
  (if (boundp 'peb-label-with-leader)
    (vl-catch-all-apply
      (function (lambda () (peb-label-with-leader s (list tx ty) (list ax ay) "V" th))))
    (peb-rv-txt "ML" (list tx ty) th 0.0 s))
  (princ))

;; ---------------------------------------------------------------------------
;;  ONE PLACED VENTILATOR, ANNOTATED — what a sheet actually calls.
;;  Draws the symbol on the ridge and, when `label` is true, the single typical callout
;;  clear of the roof.  Returns the apex height so a caller can keep its dimensions clear.
;; ---------------------------------------------------------------------------
;;  `th` is THE HOST SHEET'S CALLOUT HEIGHT, and the caller supplies it. The cross section
;;  labels its own PURLIN / RAFTER / EAVE GUTTER at a literal 220 with the text 300 to the
;;  right of the arrow and 1200 x *PEB-TEXT-SCALE* above it (Section.lsp:5585, :6153); this
;;  follows that convention exactly, so the ventilator callout is indistinguishable in
;;  weight and placement from the ones already on the sheet. Handed peb-th's raw ANNOT it
;;  came out 673 tall against their 198 — three times everything else, straddling the roof
;;  note and running out over the title block.
(defun peb-rv-place (ox oy sc label qty th / a ts)
  (if (or (null sc) (<= sc 0.0)) (setq sc 1.0))
  (if (or (null th) (<= th 0.0)) (setq th (peb-th 'ANNOT)))
  (setq a  (* (peb-rv-height) sc)
        ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0))
  (peb-rv-symbol ox oy sc T)
  ;; The label goes just above the ridge and off to the right. Offsets are multiples of the
  ;; HOST SHEET'S text height, never of *PEB-TEXT-SCALE*: on the end-wall elevation, where the
  ;; callouts are 830, a 1200 x scale rise threw the text up into the sheet title. A gap
  ;; measured in text heights is the same gap on every sheet, whatever the scale.
  (if label
    (peb-rv-label ox (+ oy (* a 0.72))
                  (+ ox (* 1.2 th)) (+ oy a (* 1.1 th)) qty th))
  (+ oy a))

;; ---------------------------------------------------------------------------
;;  SAMPLE HARNESS — development code, not the proposal set.
;;  Draws the symbol at true size against a piece of ridge, with the traced dimensions, so
;;  it can be checked against reference/sectionAA_zoom.png in seconds.
;;  Text is sized off the COMPONENT (the light panel's sample broke by using peb-th's
;;  building ladder on a 1 m object); every gap here is a multiple of that height.
;; ---------------------------------------------------------------------------
(defun peb-rv-dim-h (x0 x1 y off th s / yy t1 up)
  (setq t1 (* 0.22 th) yy (+ y off) up (if (< off 0.0) -1.0 1.0))
  (peb-comp-layer "DIMENSIONS" 6)
  (peb-rv-line x0 y x0 yy "DIMENSIONS" 13) (peb-rv-line x1 y x1 yy "DIMENSIONS" 13)
  (peb-rv-line x0 yy x1 yy "DIMENSIONS" 13)
  (peb-rv-line (- x0 t1) (- yy t1) (+ x0 t1) (+ yy t1) "DIMENSIONS" 13)
  (peb-rv-line (- x1 t1) (- yy t1) (+ x1 t1) (+ yy t1) "DIMENSIONS" 13)
  (peb-rv-txt "MC" (list (/ (+ x0 x1) 2.0) (+ yy (* up 0.75 th))) th 0.0 s))

(defun peb-rv-dim-v (y0 y1 x off th s / xx t1 out)
  (setq t1 (* 0.22 th) xx (+ x off) out (if (< off 0.0) -1.0 1.0))
  (peb-comp-layer "DIMENSIONS" 6)
  (peb-rv-line x y0 xx y0 "DIMENSIONS" 13) (peb-rv-line x y1 xx y1 "DIMENSIONS" 13)
  (peb-rv-line xx y0 xx y1 "DIMENSIONS" 13)
  (peb-rv-line (- xx t1) (- y0 t1) (+ xx t1) (+ y0 t1) "DIMENSIONS" 13)
  (peb-rv-line (- xx t1) (- y1 t1) (+ xx t1) (+ y1 t1) "DIMENSIONS" 13)
  (peb-rv-txt "MC" (list (+ xx (* out 0.75 th)) (/ (+ y0 y1) 2.0)) th 90.0 s))

(defun peb-draw-rv-sample (data ox oy / th h a thr ktop slope run)
  (setq th 45.0                                   ; a twelfth of the 542 hood
        h (peb-rv-half) a (peb-rv-height) thr (peb-rv-throat) ktop (peb-rv-skirt-top)
        run (* h 3.2) slope (/ run 10.0))
  ;; a piece of ridge for it to sit on, so the symbol is seen in the only context it has
  (peb-comp-layer "SHEETING" 4)
  (peb-rv-line (- ox run) (- oy slope) ox oy "SHEETING" 9)
  (peb-rv-line ox oy (+ ox run) (- oy slope) "SHEETING" 9)
  ;; the symbol at TRUE SIZE
  (peb-rv-symbol ox oy 1.0 T)
  ;; the traced chain
  (peb-rv-dim-h (- ox h) (+ ox h) (+ oy a) (* 2.4 th) th (strcat (rtos (* 2 h) 2 0) " OVERALL"))
  (peb-rv-dim-v oy (+ oy a) (+ ox h) (* 2.4 th) th (strcat (rtos a 2 0) " HIGH"))
  (peb-rv-dim-v oy (+ oy thr) (- ox h) (* -2.4 th) th (strcat (rtos thr 2 0) " THROAT"))
  (peb-rv-dim-v (+ oy thr) (+ oy ktop) (- ox h) (* -6.0 th) th (strcat (rtos (peb-rv-skirt) 2 0) " WIND BAND"))
  (peb-rv-txt "MC" (list ox (- oy slope (* 3.0 th))) th 0.0
              (strcat "GRAVITY RIDGE VENTILATOR - SYMBOL - UNIT " (rtos (peb-rv-len) 2 0) " LONG"))
  (peb-rv-txt "MC" (list ox (- oy slope (* 4.8 th))) th 0.0
              (strcat "TRACED FROM MSPL-203 SECTION A-A - " (peb-rv-mesh)))
  (peb-rv-txt "MC" (list ox (- oy slope (* 6.6 th))) th 0.0
              "THROAT LEFT OPEN: THAT GAP IS WHAT MAKES IT A VENTILATOR")
  ;; and the same symbol at the size it really plots on a cross section, beside it
  (peb-rv-symbol (+ ox (* run 2.4)) oy 1.0 nil)
  (peb-rv-txt "MC" (list (+ ox (* run 2.4)) (- oy slope (* 3.0 th))) th 0.0 "AS PLACED, NO MESH HINT")
  (setvar "CLAYER" "0")
  (princ))

(defun C:PEB-RV-SAMPLE ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (setq *PEB-TEXT-SCALE* 0.10 *PEB-DIM-SCALE* 0.10)
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (setq data (MSPL-Read-Data *PEB-DATA-FILE*)))
  (peb-draw-rv-sample data 0.0 0.0)
  ;; NO TITLE BLOCK — a drawer must not draw a sheet, and an A1 frame round a 2 m symbol
  ;; leaves the annotation unreadable in the one PNG anybody checks it against.
  (princ))

(defun peb-rv-sample-from-file (path)
  (setq *PEB-DATA-FILE* path)
  (C:PEB-RV-SAMPLE))

(princ "\nMAIMAAR_PEB_RidgeVent.lsp loaded - PEB-RV-SAMPLE\n")
(princ)
