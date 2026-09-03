;;; ============================================================================
;;;  MAIMAAR_PEB_Louver.lsp — WALL LOUVER GEOMETRY  (FIXED · ADJUSTABLE · SAND-TRAP)
;;;  PEB COMPONENT LIBRARY — Library/louver/
;;; ============================================================================
;;;
;;;  WHY THIS FILE EXISTS.
;;;
;;;  Every accessory placed on an elevation is drawn by MAIMAAR_PEB_Elevation.lsp's
;;;  placement loop as a PLAIN RECTANGLE (line 252, a bare RECTANG on layer OPEN, plus two
;;;  diagonals when the type says "door"). A louver, a window and a light panel therefore
;;;  come out of the proposal set identical. This module closes that for the louver, the
;;;  way the light panel closed it for the translucent panel: its own folder, its own
;;;  reference, its own sample, verified alone before it is synced.
;;;
;;;  ── EVERY SIZE, NOT ONE SIZE ─────────────────────────────────────────────────────────
;;;  The catalogue standard is 1000 x 1000 fixed and 900 x 1000 adjustable, but the BSF
;;;  lets the estimator type any W and H (components.js LOUVER_SPEC: `w` and `h` are plain
;;;  number fields, defaulted to 1000), and the reference sheet itself is drawn at a 1500
;;;  louver width. So NOTHING here is hard-coded to a size. Width, height, type, screen and
;;;  material are ARGUMENTS; the blade count, the framed opening, the girt span and the
;;;  free area are all DERIVED from them by the formulas the reference gives:
;;;
;;;      framed opening   = louver + 2 x 22 frame                (1500 -> 1544, 900 -> 944)
;;;      openings N       = floor(H / 100) blade pitch           (1000 -> 10, as the manual)
;;;      free area AEFF   = N x C x L,  C = 0.035 m, L = width   (1.0 x 1.0 -> 0.35 m2)
;;;      with insect screen AEFF is HALVED
;;;
;;;  A 1000 x 1000 louver drawn through these comes out at exactly the catalogue numbers,
;;;  and a 2400 x 1500 one comes out right too. That is the point.
;;;
;;;  ── WHAT IS TRACED AND WHAT IS STYLISED (rulebook 4B.24) ─────────────────────────────
;;;  TRACED, off the industry Technical Manual, Chapter 13 / Section 13.8 "Louvers", pages
;;;  4-of-8 and 5-of-8 (fixed) and 7-of-8 and 8-of-8 (adjustable) — kept in reference/,
;;;  with every number and where it sits on the sheet listed in reference/NOTES.md:
;;;
;;;      frame margin        22 mm each side, every edge      (1500 + 44 = 1544 framed opg)
;;;      projection          105 mm off the steel line
;;;      accessory girt      48 mm clear of the framed opening, head and sill
;;;      blade pitch         100 mm  (N = 10 openings in a 1000 high louver)
;;;      clear between       35 mm  (C in AEFF = N x C x L)
;;;      blade face          65 mm  (pitch 100 - clear 35)
;;;      fasteners           SDS-4.8x20 self-drilling at 300 O.C.
;;;      standard sizes      fixed 1000 x 1000 · adjustable 900 x 1000
;;;
;;;  STYLISED, and said so on the drawing and in the README:
;;;      * the BLADE SECTION. The reference blade is a rolled Z with a return lip; it is
;;;        drawn here as a straight drainable slat sloping down to the outside. Correct
;;;        dimensions under a straight-line shape is honest; invented dimensions are not.
;;;      * the SAND-TRAP. Section 13.8 carries fixed and adjustable ONLY — there is no
;;;        sand-trap detail on it. It is drawn with VERTICAL blades at the same traced
;;;        pitch and clear, and labelled STYLISED until a real sand-trap sheet is traced.
;;;
;;;  ── WHY IT READS DIFFERENTLY FROM THE SHEETING: PEN, NOT COLOUR ──────────────────────
;;;  The proposal PDF plots MONOCHROME (MAIMAAR_PEB_PDF.lsp:90 and :140, drawingRender.ts
;;;  :394 and :1263 all set monochrome.ctb), so every ACI colour collapses to black on the
;;;  deliverable and carries no information there. Only lineweight does.
;;;
;;;      steel sheeting        SHEETING   0.09      louver frame     LOUVER  0.50
;;;      louver blades         LOUVER     0.25      insect screen    LOUVER  0.05
;;;
;;;  The frame outline also carries (cons 370 50) on the ENTITY, so it is right even in a
;;;  drawing whose layer table did not come from PEB_LAYERS.csv (where LOUVER was added at
;;;  ACI 3 / 0.50 on 3-Sep-2026, beside SKY LIGHT and WALL LIGHT).
;;;
;;;  ── STANDING RULES OBSERVED ──────────────────────────────────────────────────────────
;;;   * A DRAWER TAKES ARGUMENTS AND DRAWS GEOMETRY. Nothing here reads the BSF; the data
;;;     belongs to the caller. The one exception is peb-draw-louver-sample, which is the
;;;     harness, not a drawer, and is clearly marked.
;;;   * Layers come from Rule_Book/PEB_LAYERS.csv — LOUVER, DIMENSIONS (not "DIM"), GIRTS
;;;     (not "GIRT"). An ad-hoc layer inherits no lineweight and drifts from the standard.
;;;   * NO hand-driven LAYER / STYLE / TEXT via `command`. An acad command left open eats
;;;     the rest of the script silently and catches nothing.
;;;   * Dimensions are LINE + TEXT primitives, not DIM commands, so a DIMSTYLE missing from
;;;     a standalone run cannot stall the script.
;;;   * mm, 1:1 in model space.
;;; ============================================================================

;; ---- TRACED CONSTANTS (Section 13.8) ---------------------------------------
(defun peb-lv-margin     ()  22.0)   ; frame, each edge -> framed opening = louver + 44
(defun peb-lv-girt-gap   ()  48.0)   ; accessory girt clear of the framed opening
(defun peb-lv-depth      () 105.0)   ; projection off the steel line
(defun peb-lv-pitch      () 100.0)   ; blade pitch — 10 openings in a 1000 high louver
(defun peb-lv-clear      ()  35.0)   ; C, the clear opening between two blades
(defun peb-lv-face       ()  65.0)   ; visible blade face = pitch - clear
(defun peb-lv-fastener   () "SDS-4.8X20 SELF DRILLING FASTENER AT 300 O.C.")

;; ---- CATALOGUE STANDARDS — a DEFAULT for a caller that has none, never a limit --------
(defun peb-lv-std-h      () 1000.0)
(defun peb-lv-std-w (kind) (if (eq kind 'ADJ) 900.0 1000.0))

;; ---- PENS (1/100 mm; the proposal plots monochrome, so this is the only signal) -------
(defun peb-lv-lw         ()  50)     ; frame outline   0.50
(defun peb-lv-lw-blade   ()  25)     ; blades          0.25
(defun peb-lv-lw-screen  ()   5)     ; insect screen   0.05
(defun peb-lv-lw-thin    ()  13)     ; dimensions / trims
(defun peb-lv-layer      () "LOUVER")
(defun peb-lv-aci        ()  3)

;; ---------------------------------------------------------------------------
;;  TEXT HEIGHT FOR A COMPONENT, NOT A BUILDING.
;;
;;  peb-th's ladder is tuned for an A1 sheet showing a 48 m building: ANNOT is 830 mm, which
;;  plots at 3.0 mm there. Used unchanged on a 1000 mm louver, ONE CAPTION IS 83% OF THE
;;  LOUVER'S OWN HEIGHT and every callout collides with its neighbour — which is exactly how
;;  the light panel's sample sheet broke, and *PEB-TEXT-SCALE* does not fix it because that
;;  scales OFFSETS, not heights.
;;
;;  So a component annotates off the COMPONENT. peb-lv-set-th is called once by whoever lays
;;  the view out, with the smallest louver on the sheet; everything below — text, ticks, the
;;  gaps between dimension lines, the column pitch — is a multiple of it, so the sheet stays
;;  proportionate at any size from a 900 mm louver to a 3 m one.
;; ---------------------------------------------------------------------------
(defun peb-lv-th ()
  (if (and (boundp '*PEB-LV-TH*) *PEB-LV-TH* (> *PEB-LV-TH* 0.0)) *PEB-LV-TH* 80.0))
(defun peb-lv-set-th (h) (setq *PEB-LV-TH* (max 24.0 h)) (peb-lv-th))
;; ROMAND's advance width is 0.62 of the cap height — the same figure peb-fit-txt-h uses.
;; This is how a caption's width is known BEFORE it is drawn, which is how columns get laid
;; out on a pitch that cannot overlap instead of on a guessed millimetre gap.
(defun peb-lv-txt-w (s) (* 0.62 (peb-lv-th) (strlen (if s s ""))))

;; ---------------------------------------------------------------------------
;;  TYPE. The BSF says "Fixed" / "Adjustable" / "Sand-trap" (components.js LOUVER_SPEC),
;;  the estimator writes "Sand Trap" and "sandtrap" too (estimation-louver.test.js pins all
;;  three spellings), and the placement loop passes whatever the mark says. Match loosely,
;;  once, here — so no drawer below ever compares a string again.
;; ---------------------------------------------------------------------------
(defun peb-lv-kind (s / u)
  (setq u (if s (strcase s) ""))
  (cond ((or (wcmatch u "*SAND*") (wcmatch u "*TRAP*")) 'SAND)
        ((wcmatch u "*ADJ*")                            'ADJ)
        (T                                              'FIXED)))

(defun peb-lv-kind-name (kind)
  (cond ((eq kind 'SAND) "SAND-TRAP LOUVER")
        ((eq kind 'ADJ)  "ADJUSTABLE LOUVER")
        (T               "FIXED LOUVER")))

;; ---------------------------------------------------------------------------
;;  THE DERIVED NUMBERS — every one of them a formula off W and H, so any size works.
;; ---------------------------------------------------------------------------
(defun peb-lv-fo-w (w) (+ w (* 2.0 (peb-lv-margin))))     ; 1500 -> 1544 · 900 -> 944
(defun peb-lv-fo-h (h) (+ h (* 2.0 (peb-lv-margin))))     ; 1000 -> 1044
(defun peb-lv-girt-span (h)                               ; girt to girt, head and sill
  (+ (peb-lv-fo-h h) (* 2.0 (peb-lv-girt-gap))))

;; N — the number of clear openings. A sand trap's blades run the other way, so its
;; openings count across the WIDTH; every other type counts up the HEIGHT.
(defun peb-lv-openings (w h kind / span)
  (setq span (if (eq kind 'SAND) w h))
  (max 1 (fix (/ span (peb-lv-pitch)))))

;; AEFF = N x C x L, in m2. L is the opening LENGTH — the run across the blade, which is
;; the width for a horizontal blade and the height for a sand trap's vertical one. An
;; insect screen halves it (Section 13.8: "should be further reduced by 50%").
(defun peb-lv-free-area (w h kind screened / n l a)
  (setq n (peb-lv-openings w h kind)
        l (/ (if (eq kind 'SAND) h w) 1000.0)
        a (* n (/ (peb-lv-clear) 1000.0) l))
  (if screened (/ a 2.0) a))

;; How many louvers a required free inlet area needs — the manual's own worked example
;; (73.4 m2 / 0.35 = 210 louvers of 1.0 x 1.0). Rounded UP: a part louver ventilates nothing.
(defun peb-lv-count-for-area (reqM2 w h kind screened / a n)
  (setq a (peb-lv-free-area w h kind screened))
  (if (<= a 0.0) 0 (progn (setq n (fix (/ reqM2 a)))
                          (if (< (* n a) reqM2) (1+ n) n))))

;; ---------------------------------------------------------------------------
;;  ENTITY HELPERS — every one carries an EXPLICIT pen. peb-comp-poly sets none, so a
;;  louver drawn through it would inherit LWDEFAULT 0.25 and read like the blades.
;; ---------------------------------------------------------------------------
(defun peb-lv-line (x0 y0 x1 y1 lay lw)
  (entmake (list (cons 0 "LINE") (cons 8 lay) (cons 370 lw)
                 (list 10 x0 y0 0.0) (list 11 x1 y1 0.0))))

(defun peb-lv-poly (pts lw / e lay)
  (setq lay (getvar "CLAYER")
        e (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 lay)
                (cons 370 lw) (cons 100 "AcDbPolyline")
                (cons 90 (length pts)) (cons 70 1)))
  (foreach p pts (setq e (append e (list (list 10 (car p) (cadr p))))))
  (entmake e))

(defun peb-lv-rect (x0 y0 x1 y1 lw)
  (peb-lv-poly (list (list x0 y0) (list x1 y0) (list x1 y1) (list x0 y1)) lw))

;; Component text, at the component's own height. One place, so no drawer picks a size.
(defun peb-lv-txt (just pt rot s)
  (setvar "CLAYER" "TEXT")
  (txt just pt (peb-lv-th) rot s))

;; ---------------------------------------------------------------------------
;;  THE INSECT SCREEN — a woven cross-hatch (BOTH diagonals, unlike peb-sky-hatch's single
;;  45-degree run: a screen is woven, a translucent panel is not) at the lightest pen on
;;  the sheet, 0.05, so it can never compete with the outline it sits inside.
;;
;;  SPACING 120, the value the materials catalogue records for it. That is close enough to
;;  the 100 blade pitch to be the very clash rule M2 warns about — two materials meeting on
;;  one sheet at similar frequency — which is why the elevation does NOT lay one over the
;;  other. The reference sheet already solved it: its LOUVER EXTERIOR view is split by a
;;  diagonal BREAK, screen on one side, blades on the other. Drawn that way, the two
;;  materials never overlap and each reads at its own frequency.
;;
;;  `brk` clips the fill to the LEFT of the break line x = x0 + a + b(y - y0); pass nil for
;;  a plain rectangular fill (which is what a section cut through a sand trap wants).
;; ---------------------------------------------------------------------------
(defun peb-lv-screen-hatch (x0 y0 x1 y1 spacing brk / lay lw c cmax step xa xb a b xcut)
  (if (or (null spacing) (<= spacing 0.0)) (setq spacing 120.0))
  (setq lay (getvar "CLAYER") lw (peb-lv-lw-screen) step (* spacing 1.41421356)
        a (if brk (car brk) 0.0) b (if brk (cadr brk) 0.0))
  ;; "/" diagonals:  y = x + c.  Break at x = x0+a+b(y-y0) -> x = (x0+a+b(c-y0))/(1-b)
  (setq c (+ (- y0 x1) step) cmax (- y1 x0))
  (while (< c cmax)
    (setq xa (max x0 (- y0 c)) xb (min x1 (- y1 c)))
    (if brk (setq xcut (/ (+ x0 a (* b (- c y0))) (- 1.0 b)) xb (min xb xcut)))
    (if (< (+ xa 1.0) xb) (peb-lv-line xa (+ xa c) xb (+ xb c) lay lw))
    (setq c (+ c step)))
  ;; "\" diagonals:  y = -x + c.  Break -> x = (x0+a+b(c-y0))/(1+b)
  (setq c (+ (+ y0 x0) step) cmax (+ y1 x1))
  (while (< c cmax)
    (setq xa (max x0 (- c y1)) xb (min x1 (- c y0)))
    (if brk (setq xcut (/ (+ x0 a (* b (- c y0))) (+ 1.0 b)) xb (min xb xcut)))
    (if (< (+ xa 1.0) xb) (peb-lv-line xa (- c xa) xb (- c xb) lay lw))
    (setq c (+ c step)))
  (princ))

;; ---------------------------------------------------------------------------
;;  THE BLADES IN ELEVATION.
;;
;;  Each pitch of 100 is one blade FACE of 65 and one CLEAR opening of 35 — both traced,
;;  so the drawn slat spacing IS the ventilation geometry, not a decorative stripe. The
;;  last part-pitch is dropped: a blade that does not fit is not fitted.
;;
;;  Horizontal for a fixed or adjustable louver; VERTICAL for a sand trap, whose blades
;;  stand up so the sand it stops can fall out of the bottom.
;; ---------------------------------------------------------------------------
;;  `brk` is (a b) — the break line x = x0 + a + b(y - y0). Blades are drawn to the RIGHT of
;;  it, the screen to the left, so the two never sit on top of each other. nil draws blades
;;  across the whole opening (what a band on a wall elevation wants, where there is no room
;;  to show a screen anyway).
;;  BLADE DENSITY FOLLOWS THE PLOT, NOT THE PRODUCT.
;;
;;  `ind` draws an INDICATIVE 4 strokes instead of every blade. On MSPL-26-266's side wall
;;  elevation the sheet plots at 1:259, so the traced 100 pitch is 0.39 mm on paper: nine
;;  blade pairs merge and each louver came out a SOLID BLACK BLOCK. That is golden rule 5 -
;;  a dense fill reaches the customer black - and no wall elevation ever drawn shows real
;;  blades anyway. The traced pitch is still what the DETAIL draws and still what AEFF is
;;  computed from; only what is legible at this scale changes.
(defun peb-lv-blades (x0 y0 w h kind brk ind / lay lw pit fac i n a b xs ys sp)
  (setq lay (getvar "CLAYER") lw (peb-lv-lw-blade)
        pit (peb-lv-pitch) fac (peb-lv-face)
        n   (peb-lv-openings w h kind) i 0)
  (if ind
    (progn
      (setq n 4 sp (/ (if (eq kind 'SAND) w h) 5.0) i 1)
      (while (<= i n)
        (if (eq kind 'SAND)
          (progn (setq a (+ x0 (* i sp)))
                 (peb-lv-line a y0 a (+ y0 h) lay lw))
          (progn (setq a (+ y0 (* i sp))
                       xs (if brk (+ x0 (car brk) (* (cadr brk) (- a y0))) x0))
                 (if (< (+ xs 1.0) (+ x0 w)) (peb-lv-line xs a (+ x0 w) a lay lw))))
        (setq i (1+ i)))
      (setq n 0 i 0)))
  (if (eq kind 'SAND)
    ;; VERTICAL blades (sand trap). The break runs bottom-left to top-right, so a blade at
    ;; x sits to the RIGHT of it only BELOW the height where the break reaches x — hence
    ;; each blade is clipped at its TOP, and the mesh shows through above the break.
    (while (< i n)
      (setq a (+ x0 (* i pit)) b (+ a fac))
      (setq ys (if brk (min (+ y0 h) (+ y0 (/ (- a x0 (car brk)) (cadr brk)))) (+ y0 h)))
      (if (> ys (+ y0 1.0))
        (progn (peb-lv-line a y0 a ys lay lw)
               (peb-lv-line b y0 b (min ys (+ y0 h)) lay lw)))
      (setq i (1+ i)))
    (while (< i n)                                   ; horizontal blades, top down
      (setq a (- (+ y0 h) (* i pit)) b (- a fac))
      (setq xs (if brk (+ x0 (car brk) (* (cadr brk) (- a y0))) x0))
      (if (< (+ xs 1.0) (+ x0 w)) (peb-lv-line xs a (+ x0 w) a lay lw))
      (setq xs (if brk (+ x0 (car brk) (* (cadr brk) (- b y0))) x0))
      (if (< (+ xs 1.0) (+ x0 w)) (peb-lv-line xs b (+ x0 w) b lay lw))
      (setq i (1+ i))))
  (princ))

;; ---------------------------------------------------------------------------
;;  VIEW 1 — LOUVER EXTERIOR, ANY SIZE.
;;
;;  The frame band (22 all round, so the outer line is the FRAMED OPENING and the inner is
;;  the LOUVER), the screen behind, the blades in front. This is the view the wall
;;  elevation and the wall sheeting plan will place; it is drawn from the louver's own
;;  bottom-left corner so a caller only has to know where the opening starts.
;;
;;  x0 y0 = bottom-left of the LOUVER (not of the framed opening).
;; ---------------------------------------------------------------------------
;;  `showScreen` splits the view with a break line the way the reference sheet does —
;;  mesh on one side, blades on the other. A DETAIL wants that; a louver drawn 40 mm wide
;;  in a band along a 48 m wall does not, so the band passes nil and gets blades edge to
;;  edge. The frame and the framed opening are the same either way.
(defun peb-lv-elev (x0 y0 w h type screened showScreen / kind m lay brk ind ts)
  (setq kind (peb-lv-kind type) m (peb-lv-margin) lay (peb-lv-layer)
        brk  (if (and screened showScreen) (list (* 0.34 w) (/ (* 0.30 w) h)) nil)
        ;; *PEB-TEXT-SCALE* is the engine's own "how big is this sheet's subject" factor and
        ;; every sheet sets it from its own span, so it is the one honest proxy a pure-geometry
        ;; drawer has for the plot scale. Below ~1.5 plotted mm a blade stops being a line and
        ;; starts being ink: 420 x ts is that threshold in model units.
        ts   (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        ind  (< (peb-lv-pitch) (* 420.0 ts)))
  (peb-comp-layer lay (peb-lv-aci))
  ;; the framed opening — the hole the building leaves for it
  (peb-lv-rect (- x0 m) (- y0 m) (+ x0 w m) (+ y0 h m) (peb-lv-lw))
  ;; the louver frame itself
  (peb-lv-rect x0 y0 (+ x0 w) (+ y0 h) (peb-lv-lw))
  ;; the screen behind, the blades in front, and the break that keeps them apart
  (if (and screened showScreen)
    (progn
      (peb-lv-screen-hatch x0 y0 (+ x0 w) (+ y0 h) 120.0 brk)
      (peb-comp-layer lay (peb-lv-aci))
      (peb-lv-line (+ x0 (car brk)) y0
                   (+ x0 (car brk) (* (cadr brk) h)) (+ y0 h) lay (peb-lv-lw-thin))))
  (peb-lv-blades x0 y0 w h kind brk ind)
  (princ))

;; ---------------------------------------------------------------------------
;;  Plain 2-tick dimensions from primitives, at the COMPONENT's text height. `off` is in
;;  millimetres and callers state it as a multiple of (peb-lv-th), so a dimension ladder
;;  never crowds its own text. Layer DIMENSIONS (the standard), never "DIM".
;; ---------------------------------------------------------------------------
(defun peb-lv-dim-h (x0 x1 y off txtstr / yy t1 th up)
  (setq th (peb-lv-th) t1 (* 0.22 th) yy (+ y off) up (if (< off 0.0) -1.0 1.0))
  (peb-comp-layer "DIMENSIONS" 6)
  (peb-lv-line x0 y x0 yy "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-line x1 y x1 yy "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-line x0 yy x1 yy "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-line (- x0 t1) (- yy t1) (+ x0 t1) (+ yy t1) "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-line (- x1 t1) (- yy t1) (+ x1 t1) (+ yy t1) "DIMENSIONS" (peb-lv-lw-thin))
  ;; the text sits on the OUTSIDE of the dimension line, whichever way the line went
  (peb-lv-txt "MC" (list (/ (+ x0 x1) 2.0) (+ yy (* up 0.75 th))) 0.0 txtstr)
  (princ))

(defun peb-lv-dim-v (y0 y1 x off txtstr / xx t1 th out)
  (setq th (peb-lv-th) t1 (* 0.22 th) xx (+ x off) out (if (< off 0.0) -1.0 1.0))
  (peb-comp-layer "DIMENSIONS" 6)
  (peb-lv-line x y0 xx y0 "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-line x y1 xx y1 "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-line xx y0 xx y1 "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-line (- xx t1) (- y0 t1) (+ xx t1) (+ y0 t1) "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-line (- xx t1) (- y1 t1) (+ xx t1) (+ y1 t1) "DIMENSIONS" (peb-lv-lw-thin))
  (peb-lv-txt "MC" (list (+ xx (* out 0.75 th)) (/ (+ y0 y1) 2.0)) 90.0 txtstr)
  (princ))

;; ---------------------------------------------------------------------------
;;  VIEW 2 — SECTION-B, the VERTICAL section (head, blades, sill).
;;
;;  x0 is the STEEL LINE; depth runs +x outward, height +y. Traced: the frame 22 at head
;;  and sill, the accessory girt 48 clear of the framed opening, the 105 projection, the
;;  blades at 100 pitch. STYLISED: the blade is a straight drainable slat falling to the
;;  outside — the reference blade is a rolled Z with a return lip, and that lip is not
;;  dimensioned anywhere on the sheet, so it is not invented here.
;;
;;  Returns the width it consumed, annotation included.
;; ---------------------------------------------------------------------------
(defun peb-lv-section-b (x0 y0 w h type / kind m d g lay pit fac i n ya yb fo th)
  (setq kind (peb-lv-kind type) m (peb-lv-margin) d (peb-lv-depth) g (peb-lv-girt-gap)
        lay (peb-lv-layer) pit (peb-lv-pitch) fac (peb-lv-face) fo (peb-lv-fo-h h)
        th (peb-lv-th))
  ;; the wall panel / steel line the louver is cut into
  (peb-comp-layer "SHEETING" 4)
  (peb-lv-line x0 (- y0 m g (* 0.9 d)) x0 (+ y0 h m g (* 0.9 d)) "SHEETING" 9)
  ;; accessory girts, head and sill — 48 clear of the framed opening, both ways
  (peb-comp-layer "GIRTS" 6)
  (peb-lv-rect (- x0 (* 0.9 d)) (+ y0 h m g) x0 (+ y0 h m g (* 0.55 d)) 13)
  (peb-lv-rect (- x0 (* 0.9 d)) (- y0 m g (* 0.55 d)) x0 (- y0 m g) 13)
  ;; the frame — head, sill and the outer face at 105
  (peb-comp-layer lay (peb-lv-aci))
  (peb-lv-rect x0 (+ y0 h) (+ x0 d) (+ y0 h m) (peb-lv-lw))         ; head member
  (peb-lv-rect x0 (- y0 m) (+ x0 d) y0        (peb-lv-lw))          ; sill member
  (peb-lv-line (+ x0 d) y0 (+ x0 d) (+ y0 h) lay (peb-lv-lw))       ; outer face
  ;; the blades in section — sloping DOWN to the outside so water runs off, one per pitch
  (setq n (peb-lv-openings w h kind) i 0)
  (if (eq kind 'SAND)
    (progn                                             ; vertical blades cut through — a band
      (peb-lv-screen-hatch x0 y0 (+ x0 d) (+ y0 h) 120.0 nil)
      (peb-lv-txt "MC" (list (+ x0 (* 0.5 d)) (+ y0 (* 0.5 h))) 90.0 "VERTICAL BLADES"))
    (while (< i n)
      (setq ya (- (+ y0 h) (* i pit)) yb (- ya fac))
      (peb-lv-line x0 ya (+ x0 d) yb lay (peb-lv-lw-blade))
      (setq i (1+ i))))
  ;; the operating linkage — the one thing that separates an adjustable from a fixed in
  ;; section. Section 13.8: "the louver blades operate in unison", on pivot clips.
  (if (eq kind 'ADJ)
    (peb-lv-line (+ x0 (* 0.35 d)) y0 (+ x0 (* 0.35 d)) (+ y0 h) lay (peb-lv-lw-blade)))
  ;; the chain the reference dimensions: 48 · 22 · H · 22 · 48
  (peb-lv-dim-v (+ y0 h m) (+ y0 h m g) x0 (* -2.6 th) (rtos g 2 0))
  (peb-lv-dim-v y0 (+ y0 h) (+ x0 d) (* 2.6 th) (strcat (rtos h 2 0) " LOUVER HEIGHT"))
  (peb-lv-dim-v (- y0 m) (+ y0 h m) (+ x0 d) (* 6.2 th)
                (strcat (rtos fo 2 0) " FRAMED OPENING HEIGHT"))
  (peb-lv-txt "MC" (list (+ x0 (* 0.5 d)) (- y0 m g (* 0.55 d) (* 2.2 th))) 0.0 "SECTION-B")
  (+ (* 0.9 d) d (* 8.0 th)))

;; ---------------------------------------------------------------------------
;;  VIEW 3 — SECTION-A, the HORIZONTAL section (jamb to jamb).
;;
;;  What it exists to carry is the 105 projection and the framed-opening WIDTH, which is
;;  the number the building has to leave a hole for. Same origin convention as the
;;  elevation: x0 y0 is the bottom-left of the LOUVER, y here being depth.
;;
;;  Returns the width it consumed, annotation included.
;; ---------------------------------------------------------------------------
(defun peb-lv-section-a (x0 y0 w type / m d lay th run)
  (setq m (peb-lv-margin) d (peb-lv-depth) lay (peb-lv-layer) th (peb-lv-th)
        run (max (* 0.45 w) (* 3.0 th)))
  ;; the wall panel, left and right of the opening, on the steel line
  (peb-comp-layer "SHEETING" 4)
  (peb-lv-line (- x0 m run) y0 (- x0 m) y0 "SHEETING" 9)
  (peb-lv-line (+ x0 w m) y0 (+ x0 w m run) y0 "SHEETING" 9)
  ;; the louver body, projecting 105 off the steel line
  (peb-comp-layer lay (peb-lv-aci))
  (peb-lv-rect (- x0 m) y0 (+ x0 w m) (+ y0 d) (peb-lv-lw))    ; incl. the 22 jambs
  (peb-lv-line x0 y0 x0 (+ y0 d) lay (peb-lv-lw))
  (peb-lv-line (+ x0 w) y0 (+ x0 w) (+ y0 d) lay (peb-lv-lw))
  (peb-lv-dim-v y0 (+ y0 d) (- x0 m) (* -2.2 th) (rtos d 2 0))
  (peb-lv-dim-h x0 (+ x0 w) y0 (* -2.6 th) (strcat (rtos w 2 0) " LOUVER WIDTH"))
  (peb-lv-dim-h (- x0 m) (+ x0 w m) y0 (* -5.4 th)
                (strcat (rtos (peb-lv-fo-w w) 2 0) " FRAMED OPENING WIDTH"))
  (peb-lv-txt "MC" (list (+ x0 (/ w 2.0)) (+ y0 d (* 1.4 th))) 0.0 (peb-lv-fastener))
  (peb-lv-txt "MC" (list (+ x0 (/ w 2.0)) (* 1.0 (- y0 (* 7.6 th)))) 0.0 "SECTION-A")
  (+ w (* 2.0 m) (* 2.0 run)))

;; ---------------------------------------------------------------------------
;;  ONE LOUVER, FULLY ANNOTATED, AT ANY SIZE — the exterior with its dimension chain, its
;;  type and its computed free area. This is the unit the sample tiles to prove that the
;;  size really is a variable, and the unit a detail sheet would place.
;;
;;  RETURNS THE WIDTH IT CONSUMED, ANNOTATION INCLUDED, so a caller lays the next one out
;;  beside it and the two cannot overlap. The light panel's sample sheet failed because it
;;  advanced by hand-picked millimetre offsets instead; a view that knows its own width is
;;  the fix.
;; ---------------------------------------------------------------------------
(defun peb-lv-detail (x0 y0 w h type screened / kind th n aeff m cap1 cap2 cap3 cw cx)
  (setq kind (peb-lv-kind type) th (peb-lv-th) m (peb-lv-margin)
        n (peb-lv-openings w h kind) aeff (peb-lv-free-area w h kind screened)
        cap1 (strcat (peb-lv-kind-name kind) "  " (rtos w 2 0) " x " (rtos h 2 0))
        cap2 (strcat "N " (itoa n) " x C 35 x L "
                     (rtos (/ (if (eq kind 'SAND) h w) 1000.0) 2 2)
                     " m  =  AEFF " (rtos aeff 2 3) " m2")
        cap3 (if screened "WITH INSECT SCREEN (AEFF HALVED)" "WITHOUT INSECT SCREEN"))
  ;; the column is as wide as the WIDEST thing in it — the framed opening, the vertical
  ;; dimension ladder on its right, or the longest caption under it.
  (setq cw (max (+ (peb-lv-fo-w w) (* 7.0 th))
                (peb-lv-txt-w cap1) (peb-lv-txt-w cap2) (peb-lv-txt-w cap3))
        cx (+ x0 (/ (- cw (peb-lv-fo-w w)) 2.0) m))     ; the louver, centred in its column
  (peb-lv-elev cx y0 w h type screened T)
  ;; the two dimensions that matter: the louver, and the hole the building must leave
  (peb-lv-dim-h cx (+ cx w) (- y0 m) (* -2.6 th) (strcat (rtos w 2 0) " LOUVER WIDTH"))
  (peb-lv-dim-h (- cx m) (+ cx w m) (- y0 m) (* -5.4 th)
                (strcat (rtos (peb-lv-fo-w w) 2 0) " FRAMED OPENING WIDTH"))
  (peb-lv-dim-v y0 (+ y0 h) (+ cx w m) (* 2.2 th) (rtos h 2 0))
  (peb-lv-dim-v (- y0 m) (+ y0 h m) (+ cx w m) (* 5.0 th) (rtos (peb-lv-fo-h h) 2 0))
  ;; the title, and the numbers the size actually changes
  (peb-lv-txt "MC" (list (+ x0 (/ cw 2.0)) (- y0 m (* 8.4 th))) 0.0 cap1)
  (peb-lv-txt "MC" (list (+ x0 (/ cw 2.0)) (- y0 m (* 10.0 th))) 0.0 cap2)
  (peb-lv-txt "MC" (list (+ x0 (/ cw 2.0)) (- y0 m (* 11.6 th))) 0.0 cap3)
  cw)

;; ---------------------------------------------------------------------------
;;  A BAND OF LOUVERS ON A WALL — how they actually appear on an elevation, one or more
;;  per bay at a sill. The caller owns the placement RULE (the BSF computes it, the
;;  drawing reads it); this only draws what it is handed.
;;
;;  ox oy = bottom-left of the WALL. bayPts = x offsets of the grid lines along it.
;;  perBay = louvers in each bay, centred on the bay. Returns how many it drew.
;; ---------------------------------------------------------------------------
(defun peb-lv-band-on-wall (ox oy bayPts perBay w h sill type screened / i j nb x0 x1 c pit drawn th)
  (setq nb (max 0 (1- (length bayPts))) i 0 drawn 0 th (peb-lv-th)
        perBay (max 1 (fix perBay)))
  (while (< i nb)
    (setq x0 (nth i bayPts) x1 (nth (1+ i) bayPts)
          pit (/ (- x1 x0) (float (1+ perBay))) j 1)
    (while (<= j perBay)
      (setq c (+ ox x0 (* j pit)))
      (peb-lv-elev (- c (/ w 2.0)) (+ oy sill) w h type screened nil)
      (setq drawn (1+ drawn) j (1+ j)))
    (setq i (1+ i)))
  ;; ONE L-leader for the whole band, carrying the quantity — the same rule the wall
  ;; lights follow: a band of louvers labelled one by one is noise, the band reads as a
  ;; band, and a single typical callout says what they are and how many.
  (if (and (> drawn 0) (boundp 'peb-label-with-leader))
    (vl-catch-all-apply
      (function (lambda ()
        (peb-label-with-leader
          (strcat (itoa drawn) " No. " (peb-lv-kind-name (peb-lv-kind type))
                  " " (rtos w 2 0) " x " (rtos h 2 0))
          (list (+ ox (nth nb bayPts) (* 4.0 th)) (+ oy sill h (* 4.0 th)))
          (list (+ ox (/ (+ (nth 0 bayPts) (nth 1 bayPts)) 2.0)) (+ oy sill (/ h 2.0)))
          "V" (peb-lv-th))))))
  drawn)

;; ---------------------------------------------------------------------------
;;  THE SAMPLE — THE HARNESS, NOT A DELIVERABLE.
;;
;;  It exists so the component can be LOOKED at in seconds instead of rendering a whole
;;  building, and it draws the one thing the code has to prove: that the SIZE is a
;;  variable. Four or five louvers, four sizes, three types, laid out left to right.
;;
;;  ONE SCALE, AND EVERY GAP COMPUTED. The light panel's sample put a 1000-wide panel and
;;  a 48,770-long wall on one sheet with offsets typed in millimetres, and the small views
;;  collapsed into an unreadable overlap. Here every view returns the width it consumed and
;;  the next one starts after it, and the text height is set from the SMALLEST louver on
;;  the sheet, so nothing can collide however the sizes change.
;; ---------------------------------------------------------------------------
(defun peb-lv-sample-sizes (data / w h ty sc)
  ;; THE BSF FIRST when it carries a louver, so the sample shows the real job's size, then
  ;; the catalogue sizes around it for comparison. The drawer re-derives nothing.
  (setq w  (if data (MSPL-Get-Num data "LV_W") 0.0)
        h  (if data (MSPL-Get-Num data "LV_H") 0.0)
        ty (if data (peb-tb-or (MSPL-Get-Str data "LV_TYPE") "Fixed") "Fixed")
        sc (if data (not (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data "LV_SCREEN") "with"))
                                  "*WITHOUT*"))
               T))
  (append
    (if (and w (> w 0.0) h (> h 0.0)) (list (list w h ty sc)) nil)
    (list (list 1000.0 1000.0 "Fixed"      T)       ; the catalogue standard
          (list  900.0 1000.0 "Adjustable" T)       ; the catalogue standard
          (list 1500.0 1000.0 "Fixed"      T)       ; the size the reference sheet is drawn at
          (list 2400.0 1500.0 "Sand-trap"  nil))))  ; a custom size, to prove nothing is fixed

(defun peb-draw-louver-sample (data ox oy / sizes x th gap s n aeff smallest y2 hmax)
  (setq sizes (peb-lv-sample-sizes data)
        smallest 1.0e9 hmax 0.0)
  (foreach s sizes (setq smallest (min smallest (car s) (cadr s))
                         hmax     (max hmax (cadr s))))
  ;; TEXT OFF THE COMPONENT: a twelfth of the smallest louver on the sheet. A 900 mm
  ;; louver gets 75 mm text — 8% of its own height, which reads; peb-th's 830 would have
  ;; been 92% of it.
  (setq th (peb-lv-set-th (/ smallest 9.0)) x ox)
  (peb-lv-txt "ML" (list ox (+ oy hmax (* 4.4 th))) 0.0 "WALL LOUVERS - ONE DRAWER, EVERY SIZE")
  (peb-lv-txt "ML" (list ox (+ oy hmax (* 2.6 th))) 0.0
       "FRAME 22 EACH EDGE - BLADE PITCH 100 - CLEAR C 35 - PROJECTION 105 - AEFF = N x C x L")
  (foreach s sizes
    (setq gap (peb-lv-detail x oy (car s) (cadr s) (caddr s) (cadddr s)))
    (setq x (+ x gap (* 2.5 th))))
  ;; the two sections, on their own row well below the elevations, at the SAME scale
  (setq y2 (- oy (* 22.0 th)))
  (setq gap (peb-lv-section-a ox (- y2 (peb-lv-depth)) 1000.0 "Fixed"))
  (setq gap (peb-lv-section-b (+ ox gap (* 6.0 th)) y2 1000.0 1000.0 "Fixed"))
  ;; the manual's own worked example, run through the derived formulas as a check
  (setq n (peb-lv-count-for-area 73.4 1000.0 1000.0 'FIXED nil)
        aeff (peb-lv-free-area 1000.0 1000.0 'FIXED nil))
  (peb-lv-txt "ML" (list ox (- y2 (* 12.0 th))) 0.0
       (strcat "CHECK - 1000 x 1000 FIXED: AEFF = " (rtos aeff 2 2)
               " m2; 73.4 m2 OF FREE INLET AREA NEEDS " (itoa n) " LOUVERS"))
  (peb-lv-txt "ML" (list ox (- y2 (* 13.8 th))) 0.0
       "BLADE SECTION IS STYLISED (STRAIGHT DRAINABLE SLAT); SAND-TRAP HAS NO TRACED DETAIL YET")
  (setvar "CLAYER" "0")
  (princ))

;; ---------------------------------------------------------------------------
;;  SHEET ENTRY POINTS — the peb-<x>-from-file pattern every other sheet uses.
;; ---------------------------------------------------------------------------
(defun C:PEB-LOUVER-SAMPLE ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  ;; *PEB-TEXT-SCALE* still drives anything the shared helpers draw (the title block, a
  ;; leader). The louver's OWN annotation is set by peb-lv-set-th off the smallest louver
  ;; on the sheet — see the note at peb-lv-th.
  (setq *PEB-TEXT-SCALE* 0.10 *PEB-DIM-SCALE* 0.10)
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (setq data (MSPL-Read-Data *PEB-DATA-FILE*)))
  (peb-draw-louver-sample data 0.0 0.0)
  ;; NO TITLE BLOCK. A drawer must not draw a sheet, and the harness has no reason to
  ;; either: an A1 frame round a 10 m row of louvers pushes the content into a third of the
  ;; raster PNGOUT produces, and the annotation stops being readable in the one image
  ;; anybody actually checks the component against. Zoomed to the louvers alone, the whole
  ;; raster is content. The title block belongs to the building sheets.
  (princ))

(defun peb-louver-sample-from-file (path)
  (setq *PEB-DATA-FILE* path)
  (C:PEB-LOUVER-SAMPLE))

(princ "\nMAIMAAR_PEB_Louver.lsp loaded - PEB-LOUVER-SAMPLE\n")
(princ)
