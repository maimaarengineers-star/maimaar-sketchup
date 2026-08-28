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
       (peb-th 'ANNOT) 0 (strcat "1:" (rtos slopeD 2 0)))
  (setvar "CLAYER" prev))

(defun peb-draw-roof-framing (data ox oy / len wid slopeD bayPts purlSp nRows i x y
                              prev cnt pre psurf pat pw mark midY j bubGap bubR ovr
                              prng pi0 pi1 px0 pOfs
                              stype mgGables mgGableW mgRid mgVal base hiNSW mgi k
                              loB hiB ry vy fx wgrid bx0 bx1 by0 by1 nPan panH)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (atof (peb-tb-or (MSPL-Get-Str data "SLOPE") "10")))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (setq bayPts (peb-fr-stations (MSPL-Get-Str data "BAYEXPR") len))
  ;; ── MATCH-LINE PART SLICE (owner 26-Aug) ─────────────────────────────────
  ;; A 4:1 building cannot use the height of a 1.1:1 drawing area, so a long sheet is
  ;; cut into parts joined by a MATCH LINE (see peb-part-range).  The slice is applied
  ;; HERE, before anything is drawn: every element below is driven off bayPts and len,
  ;; so shortening those two draws this part and nothing else, at roughly twice the
  ;; scale, with no other change to the routine.
  ;; pOfs keeps the grid numbers TRUE - part 2 starts at grid 9, not grid 1.
  (setq pOfs 0 prng (peb-part-range (length bayPts)))
  (if prng
    (progn
      (setq pi0 (car prng) pi1 (cadr prng) pOfs pi0)
      (setq bayPts (peb-sub-list bayPts pi0 pi1))
      (setq px0 (car bayPts))
      (setq bayPts (mapcar (function (lambda (ss) (- ss px0))) bayPts))
      (setq len (last bayPts))))
  ;; TEXT-SCALE AFTER the slice, from the length actually drawn.  Sized from the whole
  ;; building it left every label on a half-sheet at full-building size - the heading
  ;; then overhung the plan and, being the widest thing on the sheet, drove the plot
  ;; extents and threw away most of the scale the split had just won (owner 26-Aug).
  (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ (max len wid 1.0) 45000.0)))
        *PEB-DIM-SCALE*  *PEB-TEXT-SCALE*)
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
  ;; ── MEMBER LABELS (owner 26-Aug) ────────────────────────────────────────
  ;; "Label the girts and purlins ... as per Mammut Sample Drawings and Maimaar Own
  ;; Drawings."  Checked the reference sets first: they label members with a PLAIN
  ;; leader carrying the member name and nothing else — MAIMAAR_03 Poultry Shed has a
  ;; single "PURLINS" leader in model space, and the KMFoods sheets label "PURLIN" /
  ;; "EAVE STRUT" the same way.  No size and no spacing: General Note 1 already says
  ;; the framing is indicative and note 2 defers sizes to the approved design, so a
  ;; number here would be asserting something the sheet explicitly does not promise.
  ;; Both labels sit BELOW the plan, clear of the heading (which is at 3200 * scale).
  ;; SECTION MARK, not just the member name (owner 26-Aug: "marking of purlins like
  ;; Purlin Type 150Z15").  The nomenclature is Maimaar's own, RULES/06_PEB_COMPONENTS:
  ;;   depth + section + thickness x 10   ->  200Z15 = 200 mm Z at 1.5 mm
  ;; and the eave strut is a C-profile 180ES20/25.
  ;;
  ;; The BSF export carries NO purlin depth or gauge, so nothing here is read from the
  ;; project - the depth is the one the engine actually DRAWS (peb-purlin-depth, 200 mm)
  ;; and the gauge is the documented standard (1.5).  It is marked (TYP.) and General
  ;; Note 2 still defers the final size to the approved design, so the sheet shows the
  ;; standard type without promising a designed section.
  (vl-catch-all-apply (function (lambda ()
    (peb-label-with-leader
      (strcat "PURLIN TYPE : " (rtos (peb-purlin-depth) 2 0) "Z15 (TYP.)")
      (list (+ ox (* len 0.26)) (- oy (* 1050.0 *PEB-DIM-SCALE*)))
      (list (+ ox (* len 0.26)) (+ oy (* (/ wid (float nRows)) 2.0)))
      "S" 600.0))))
  (vl-catch-all-apply (function (lambda ()
    (peb-label-with-leader "EAVE STRUT : 180ES20"
      (list (+ ox (* len 0.66)) (- oy (* 1050.0 *PEB-DIM-SCALE*)))
      (list (+ ox (* len 0.66)) oy)
      "S" 600.0))))
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
            (peb-th 'ANNOT) 0 "RIDGE LINE"))
     (foreach vy mgVal
       (txt "ML" (list (+ ox (* len 0.72)) (+ oy vy (* 300 *PEB-TEXT-SCALE*)))
            (peb-th 'ANNOT) 0 "VALLEY GUTTER"))
     ;; falls: each ridge crest down to its two neighbours (valley or eave)
     )
    ;; ---- BUTTERFLY: central valley gutter, falls both eaves -> centre ----
    ((= stype "BF")
     (setvar "CLAYER" "GRID")
     (command "_.LINE" (list ox midY) (list (+ ox len) midY) "")
     (setvar "CLAYER" "TEXT")
     (txt "MC" (list (+ ox (* len 0.5)) (+ midY (* 400 *PEB-TEXT-SCALE*)))
          (peb-th 'ANNOT) 0 "VALLEY GUTTER")
     )
    ;; ---- MONO / SINGLE-SLOPE / LEAN-TO: no ridge, one-way fall ----
    ((member stype '("SS" "LT" "CC"))
     (setq hiNSW (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data "RA_MONO_HIGH") "")) "*NSW*"))
     (setvar "CLAYER" "TEXT")
     (txt "MC" (list (+ ox (* len 0.5)) (+ oy (* wid 0.5))) (* 300 *PEB-TEXT-SCALE*) 0
          (if (= stype "LT") "LEAN-TO ROOF" "SINGLE SLOPE ROOF"))
     )
    ;; ---- FLAT: no ridge; inward drain arrows to centre ----
    ((= stype "FR")
     (setvar "CLAYER" "TEXT")
     (txt "MC" (list (+ ox (* len 0.5)) (+ midY (* 400 *PEB-TEXT-SCALE*))) (* 300 *PEB-TEXT-SCALE*) 0 "FLAT ROOF")
     )
    ;; ---- GABLE (CS / MS / RC / default): central ridge, falls ridge -> both eaves ----
    (T
     (setvar "CLAYER" "RIDGE")
     (command "_.LINE" (list ox midY) (list (+ ox len) midY) "")
     (setvar "CLAYER" "TEXT")
     (txt "ML" (list (+ ox (* len 0.02)) (+ midY (* 300 *PEB-TEXT-SCALE*)))
          (peb-th 'ANNOT) 0 "RIDGE LINE")
     ))

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

  ;; ── FALL ARROWS: THE SHARED GLYPH, NOT A LOCAL ONE (owner 26-Aug) ──────────
  ;; "The same Roof Slope Arrow can be placed for the Roof Sheeting and Roof Framing
  ;; Plan."  peb-fall-glyph-set is already the single source of truth for these -
  ;; its own header says IDENTICAL on the Column Layout Plan AND the Roof Plan
  ;; (owner 7-Jul) - but this sheet drew its own peb-fr-fall instead: a plain line
  ;; with a two-line OPEN arrowhead and a bare "1:10".  Three plan sheets in one set
  ;; showed the fall three different ways.
  ;;
  ;; The reference sets agree with the shared glyph, not with the local one: KMFoods
  ;; and ColdStorage draw a SOLID filled head with the ratio labelled ("SLOPE" over
  ;; "1:07"), and Roshan draws the pentagon this marker was built from.  None of them
  ;; uses a bare open arrow.
  ;;
  ;; peb-fall-glyph-set places in absolute model coords; both roof drawers are called
  ;; at 0,0 and tiled afterwards by peb-tile-place, so ox/oy are zero here.
  (setq *PEB-ROOF-SLOPE* (format-slope (MSPL-Get-Str data "SLOPE")))
  (vl-catch-all-apply (function (lambda ()
    (peb-fall-glyph-set data stype len wid bayPts mgRid mgGableW))))

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
  ;; The verbatim IF bay expression describes the WHOLE building, so it is wrong on a
  ;; match-line part - sheet 1 of 2 was captioned "1@7250 + 13@8263 + 1@7250" over nine
  ;; grids (owner 26-Aug).  The part's own overall dim already gives its true length.
  (if (and (null prng)
           (boundp 'peb-fmt-expr) (vl-string-search "@" (peb-tb-or (MSPL-Get-Str data "BAYEXPR") "")))
    (progn
      (vl-catch-all-apply (function (lambda ()
        (peb-dim-h-stretch ox (+ ox len) (+ oy wid (* 900 *PEB-DIM-SCALE*))
                           (peb-fmt-expr (MSPL-Get-Str data "BAYEXPR"))))))))
  ;; OVERALL LENGTH + WIDTH in metres AND feet on the same dim lines (owner 26-Aug).
  ;; This sheet carried only the bay chain, so the one number a customer looks for -
  ;; how long and how wide the building is - was the one number missing from it.
  ;; The LENGTH dim goes ABOVE the grid bubbles, not between them and the bay
  ;; chain -- at 2600 it sat inside the bubble row and struck bubbles 8 and 9.
  ;; bubGap/bubR are set just below, so mirror the same worst-case stack here.
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-h ox (+ ox len)
      (+ oy wid (* *PEB-DIM-SCALE* (+ 1200.0 (* 3.2 1100.0) 2400.0)))
      (peb-dim-mft len)))))
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-v (- ox (* 2000 *PEB-DIM-SCALE*)) oy (+ oy wid) (peb-dim-mft wid)))))

  ;; grid bubbles — numbers (top) + letters A/B at the eaves (owner 7-Jul, parity with other sheets)
  (setq bubR (peb-bub-radius (peb-min-spacing bayPts))
        bubGap (+ (* 1200.0 *PEB-TEXT-SCALE*) (* 2.2 bubR))
        j (1+ pOfs) ovr *PEB-BUBRAD* *PEB-BUBRAD* bubR)
  (foreach g bayPts
    (setvar "CLAYER" "GRID")
    ;; the stalk starts ABOVE the bay chain (which sits at 900 * DIM-SCALE), so the
    ;; chain text never has a run of stalks drawn through it (owner 26-Aug)
    (command "_.LINE" (list (+ ox g) (+ oy wid (* 1800 *PEB-DIM-SCALE*)))
                      (list (+ ox g) (+ oy wid bubGap)) "")
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
  ;; y=0 is the NEAR side wall, which the plan letters LAST — not "A" (owner 26-Aug).
  ;; See the audit table on peb-width-letter.
  (grid-bubble (- ox bubGap bubR) oy
               (if wgrid (peb-width-letter 0 (length wgrid)) "A") "R")
  (command "_.LINE" (list ox (+ oy wid)) (list (- ox bubGap) (+ oy wid)) "")
  (grid-bubble (- ox bubGap bubR) (+ oy wid)
               (if wgrid (peb-width-letter (1- (length wgrid)) (length wgrid)) "B") "R")
  (setq *PEB-BUBRAD* ovr)
  ;; MATCH LINE on whichever edge of this part is a cut (owner 26-Aug).  It names the
  ;; sheet the drawing continues onto, so the two halves can be read as one building.
  (if prng
    (progn
      (if (> pi0 0)
        (peb-match-line ox (- oy (* 900.0 *PEB-TEXT-SCALE*)) (+ oy wid (* 900.0 *PEB-TEXT-SCALE*))
                        (itoa (1- *PEB-PART-P*))))
      (if (< *PEB-PART-P* *PEB-PART-N*)
        (peb-match-line (+ ox len) (- oy (* 900.0 *PEB-TEXT-SCALE*)) (+ oy wid (* 900.0 *PEB-TEXT-SCALE*))
                        (itoa (1+ *PEB-PART-P*))))))

  ;; blue title (below the roof) + shared title block
  (setvar "CLAYER" "TEXT")
  (setvar "CECOLOR" "5")
  (txt-bold "MC" (list (+ ox (/ len 2.0)) (- oy (* 3200 *PEB-TEXT-SCALE*)))
            ;; The ladder, raw — txt-bold applies TEXT-SCALE itself (rulebook 4B.2).
            ;; Was 300 (1.1 mm on paper), which is why this heading did not match
            ;; the other sheets (owner 26-Aug).
            (peb-th 'HEADING) 0 (peb-part-title "ROOF FRAMING PLAN"))
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
;; ── AN ELEVATION LETTERS ITS GRID EXACTLY LIKE THE PLAN (owner 26-Aug) ───────
;; "Match the grid numbering of all elevations with plan."
;;
;; Width letters: the plan draws A at the FSW and the last letter at the NSW, via
;; (peb-grid-letter (- nWid 1 j)) -- reversed, because station 0 is y=0, the NSW.
;; The elevations used peb-fr-letter i, so A landed on the NSW: the same building
;; lettered one way on the plan and the opposite way on its own end-wall elevation.
;; peb-grid-letter also SKIPS I (it reads as a 1); peb-fr-letter did not, so the two
;; ran one letter apart from the ninth grid on.
;;
;; Both offsets are applied for the same reason the plan applies them: on a
;; multi-area building the grid CONTINUES across areas instead of restarting.
;;
;; nSt = how many stations this wall has; i = 0-based station index along the wall.
(defun peb-fr-grid-label (i nSt isEnd)
  (if isEnd
    (peb-grid-letter (+ (- nSt 1 i) (if *PEB-GRID-LET-OFS* *PEB-GRID-LET-OFS* 0)))
    (itoa (+ (1+ i) (if *PEB-GRID-NUM-OFS* *PEB-GRID-NUM-OFS* 0)))))

;; Retained: still used where a plain running letter is wanted, with no plan to match.
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
;; ── A BRACE MUST PLOT, WHATEVER LTSCALE DOES LATER (owner 26-Aug) ────────────
;; The CROSS layer is a DOT linetype, and a DOT pattern only renders when its dot
;; spacing is small relative to the line.  The caller compensates with a per-entity
;; scale of 1/LTSCALE (group 48) read AT DRAW TIME — which holds right up until
;; something changes LTSCALE afterwards.  In the PDF pipeline peb-add-layout runs
;; after the sheet is drawn, so by plot time the ratio was stale, the dots spaced
;; out past the length of each diagonal, and the roof bracing plotted as NOTHING.
;; It rendered correctly through the single-sheet path, which is exactly why this
;; kept slipping through: the geometry was always there (30 CROSS lines on B-03
;; sheet 1) — only the plot was empty.  Second time this class has bitten.
;;
;; The line is now explicitly CONTINUOUS, so no pattern, nothing to scale, nothing
;; downstream can switch it off.  It stays on CROSS: cyan and 0.18 mm, so it still
;; reads as secondary bracing against the 0.35 mm framing.  es is kept in the
;; signature (callers still pass it) but no longer decides whether the brace exists.
(defun peb-fr-brace-line (x0 y0 x1 y1 es)
  ;; No per-entity linetype or scale: the CROSS layer is CONTINUOUS now, so there is
  ;; nothing to compensate for.  es stays in the signature (callers still pass it) but
  ;; no longer decides whether the brace is visible.  An entity-level (6 . "Continuous")
  ;; did NOT survive entmake here — the DXF came back BYLAYER — which is why this has to
  ;; be the layer's own linetype rather than an override.
  (entmake (list '(0 . "LINE") (cons 8 "CROSS")
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

;; ── ONE OVERALL DIMENSION BAR (owner 26-Aug) ─────────────────────────────────
;; The total length/width, in metres AND feet, on a single line under the bay
;; chain.  Drawn by hand in the SAME style as peb-fr-dimchain -- plain line, OPEN
;; arrow tipping outward at each end, short witness tick at each extent, value
;; centred above -- so the two lines read as one family.
;;
;; Deliberately NOT a native DIMLINEAR.  DIMLINEAR runs its extension lines from
;; the definition points to the dim line, and this line sits below the chain AND
;; the grid bubbles: on the 122 m wall that drew a pair of 17.5 m verticals right
;; through both of them.
(defun peb-fr-overall-h (x0 x1 y label / ts aL aW tick)
  (setq ts   (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0)
        aL   (* 300 ts)
        aW   (* 95 ts)
        tick (* 300 ts))
  (setvar "CLAYER" "DIMENSIONS")
  (command "_.LINE" (list x0 y) (list x1 y) "")
  (peb-fr-dimarrow x0 y -1 aL aW)
  (peb-fr-dimarrow x1 y  1 aL aW)
  (command "_.LINE" (list x0 (- y tick)) (list x0 (+ y tick)) "")
  (command "_.LINE" (list x1 (- y tick)) (list x1 (+ y tick)) "")
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (/ (+ x0 x1) 2.0) (+ y (* 0.95 (peb-th 'DIM) ts))) (peb-th 'DIM) 0 label))

;; The same bar stood on end, for the overall HEIGHT.  peb-dim-height-stretch drew
;; this natively at DIMTXT, which plotted about 1.5 mm -- noticeably smaller than
;; every other number on the sheet.  Same style, same ladder entry, reads 90 deg.
(defun peb-fr-overall-v (x y0 y1 label / ts aL aW tick)
  (setq ts   (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0)
        aL   (* 300 ts)
        aW   (* 95 ts)
        tick (* 300 ts))
  (setvar "CLAYER" "DIMENSIONS")
  (command "_.LINE" (list x y0) (list x y1) "")
  (command "_.LINE" (list x y0) (list (+ x aW) (+ y0 aL)) "")
  (command "_.LINE" (list x y0) (list (- x aW) (+ y0 aL)) "")
  (command "_.LINE" (list x y1) (list (+ x aW) (- y1 aL)) "")
  (command "_.LINE" (list x y1) (list (- x aW) (- y1 aL)) "")
  (command "_.LINE" (list (- x tick) y0) (list (+ x tick) y0) "")
  (command "_.LINE" (list (- x tick) y1) (list (+ x tick) y1) "")
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (- x (* 0.95 (peb-th 'DIM) ts)) (/ (+ y0 y1) 2.0)) (peb-th 'DIM) 90 label))

(defun peb-fr-dimchain (ox y stations / ts i x0 x1 aL aW th thR mb)
  (if (< (length stations) 2) nil
    (progn
      (setq ts (if *PEB-DIM-SCALE* *PEB-DIM-SCALE* 1.0)
            aL (* 300 ts)                    ; open-arrow length along the dim line
            aW (* 95 ts)                     ; half-width -> slim open "V" like DIMBLK _OPEN
            i  0)
      ;; TEXT HEIGHT (owner 26-Aug: "dim sizes are very large", then "it should not
      ;; be too small or too big").  This passed (* 230 ts) to `txt`, and `txt`
      ;; multiplies by *PEB-TEXT-SCALE* itself, so the height was 230 x TS-SQUARED:
      ;; 3.7 mm of paper on the 122 m wall but only 1.4 mm on a small shed.  The
      ;; number was never sized -- it just drifted with the building.
      ;;
      ;; Pass a single-scaled height instead and it plots the SAME on every sheet:
      ;; 420 -> 420 * 265/45000 = 2.5 mm, the ISO dimension-text size.  `txt` applies
      ;; TEXT-SCALE itself, so hand it th/TS to land exactly there.  The bay cap only
      ;; bites on tight spacings, where fitting inside the bay matters more.
      (setq th (* (peb-th 'DIM) *PEB-TEXT-SCALE*)
            mb (peb-min-spacing stations))
      (if (> mb 1.0) (setq th (min th (* 0.16 mb))))
      (setq th (max (* 170.0 *PEB-TEXT-SCALE*) th)
            thR (/ th (if (> *PEB-TEXT-SCALE* 0.01) *PEB-TEXT-SCALE* 1.0)))
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
        (txt "MC" (list (/ (+ x0 x1) 2.0) (- y (* 0.85 th) (* 120.0 ts))) thR 0
             (peb-comma (rtos (- (nth (1+ i) stations) (nth i stations)) 2 0)))
        (setq i (1+ i))))))

(defun peb-draw-framing-elev (surf ox oy data / len wid slopeD stype rtype
                              eaveH eaveHi eaveLo brickH hiName hiSide wallEave
                              faceLen stations isEnd base colhw rise ridgeRise
                              i x g yTop pts cx prev braced b x0 x1 y0 y1 lbl bubGap bubR revView hdTxt
                              prng pi0 pi1 px0 pOfs pnTot
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
  ;; ── AN ELEVATION IS VIEWED FROM OUTSIDE (owner 26-Aug) ────────────────────
  ;; Standing outside a wall, the along-wall axis runs one way for two of the four
  ;; walls and the OTHER way for the other two.  The engine drew all four left to
  ;; right in model order, so half of them were effectively drawn from INSIDE.
  ;;
  ;; With the plan as reference (grid 1 at the LEW, letter A at the FSW):
  ;;   NSW  looking +Y : screen-right = +X  ->  1..16 left to right   (as drawn)
  ;;   FSW  looking -Y : screen-right = -X  ->  16..1                 MIRROR
  ;;   REW  looking -X : screen-right = +Y  ->  F..A                  (as drawn)
  ;;   LEW  looking +X : screen-right = -Y  ->  A..F                  MIRROR
  ;;
  ;; Mirroring the STATION LIST does the whole job: every column, girt, brace and
  ;; dimension in this routine is driven off it, so they all follow.  Openings carry
  ;; their own along-wall position and are mirrored where they are read, and a mono
  ;; end wall has to swap which end is high.  Labels use the ORIGINAL index, so grid
  ;; numbers and letters stay true to the plan while the geometry flips.
  ;; ── MATCH-LINE PART SLICE, BEFORE THE MIRROR (owner 27-Aug) ──────────────
  ;; A 122 m x 6 m wall stacked two-up is about 4:1 once its annotation is counted, and
  ;; a 1.1:1 drawing area cannot use the height — the same geometry that drove the roof
  ;; plans to a match line.  The slice happens FIRST, in model order, so pi0/pi1 always
  ;; mean the same physical bays; the mirror below then flips whichever part this is.
  (setq pOfs 0 pnTot (length stations) prng (peb-part-range (length stations)))
  (if prng
    (progn
      (setq pi0 (car prng) pi1 (cadr prng) pOfs pi0)
      (setq stations (peb-sub-list stations pi0 pi1))
      (setq px0 (car stations))
      (setq stations (mapcar (function (lambda (ss) (- ss px0))) stations))
      (setq faceLen (last stations))))
  (setq revView (and (member surf '("LEW" "FSW")) T))
  (if revView
    (progn
      (setq stations (reverse (mapcar (function (lambda (ss) (- faceLen ss))) stations)))
      (if isEnd (setq hiSide (not hiSide)))))
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
           (strcat "EXISTING RCC BUILDING (BY OTHERS) - 1st FLOOR +" (peb-comma (rtos rbFloor 2 0))))
      (peb-fr-masked-label (+ ox (* 0.5 (+ rx0 rx1))) (+ base rbBase (* 330.0 *PEB-TEXT-SCALE*)) (* 235 *PEB-TEXT-SCALE*)
           (strcat "RCC PILLARS + BRICK INFILL TO +" (peb-comma (rtos rbBase 2 0)) " (STEEL BASE)"))))
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
  ;; GIRTS label — same plain-leader convention as the roof purlins above.  Placed above
  ;; the wall and off-centre so it clears the blue heading, which is centred on the wall.
  (vl-catch-all-apply (function (lambda ()
    (peb-label-with-leader
      (strcat "GIRT TYPE : " (rtos (peb-purlin-depth) 2 0) "Z15 (TYP.)")
      (list (+ ox (* faceLen 0.78)) (+ base eaveH rise (* 900.0 *PEB-DIM-SCALE*)))
      (list (+ ox (* faceLen 0.70)) (+ base gbase 2800.0))
      "S" 600.0))))
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
          pat   (if revView (- faceLen pat) pat)   ; outside view — see the mirror note
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
  ;; Bubble size: see peb-bub-radius.  900 x TEXT-SCALE tracked the wall's LENGTH,
  ;; so on the 122 m side wall the bubbles were 4.9 m across and nearly touching
  ;; (owner 26-Aug: "Proportionally bubbles and dim sizes are very large").  Now
  ;; capped against the tightest bay AND this elevation's height; the stalk gap and
  ;; the dim chain below both follow the radius, so the stack under the wall stays
  ;; in proportion whatever the aspect ratio.
  (setq bubR (peb-bub-radius (peb-min-spacing stations)))
  (setq bubGap (+ (* 700.0 *PEB-TEXT-SCALE*) (* 2.2 bubR))
        i 0 ov *PEB-BUBRAD* *PEB-BUBRAD* bubR)
  (foreach g stations
    ;; pOfs keeps the numbers TRUE on a match-line part: part 2 starts at grid 9.
    (setq lbl (peb-fr-grid-label
                (+ pOfs (if revView (- (length stations) 1 i) i))
                pnTot isEnd))
    (setvar "CLAYER" "GRID-LINES")
    (command "_.LINE" (list (+ ox g) base) (list (+ ox g) (- base (* bubGap 0.45))) "")
    (vl-catch-all-apply (function (lambda () (grid-bubble (+ ox g) (- base bubGap) lbl "U"))))
    (setq i (1+ i)))
  (setq *PEB-BUBRAD* ov)

  ;; 8. title — blue + full wall name (owner 7-Jul, consistent with the Wall Elevations sheet)
  ;; MATCH LINE on whichever DRAWN edge is a cut.  The mirror swaps them: on a reversed
  ;; wall (LEW/FSW) the low-grid end is drawn on the RIGHT, so the cut edges swap too.
  (if prng
    (progn
      (if (if revView (< pi1 (1- pnTot)) (> pi0 0))
        (peb-match-line ox (- base (* 700.0 *PEB-DIM-SCALE*))
                        (+ base eaveH rise (* 700.0 *PEB-DIM-SCALE*))
                        (itoa (if revView (1+ *PEB-PART-P*) (1- *PEB-PART-P*)))))
      (if (if revView (> pi0 0) (< pi1 (1- pnTot)))
        (peb-match-line (+ ox faceLen) (- base (* 700.0 *PEB-DIM-SCALE*))
                        (+ base eaveH rise (* 700.0 *PEB-DIM-SCALE*))
                        (itoa (if revView (1- *PEB-PART-P*) (1+ *PEB-PART-P*)))))))

  (setvar "CLAYER" "TEXT")
  (setvar "CECOLOR" "5")
  (setq hdTxt (strcat surf " - "
                (cond ((= surf "NSW") "NEAR SIDE WALL") ((= surf "FSW") "FAR SIDE WALL")
                      ((= surf "LEW") "LEFT END WALL")  ((= surf "REW") "RIGHT END WALL") (T "WALL"))
                " FRAMING"))
  (txt-bold "MC" (list (+ ox (/ faceLen 2.0)) (+ base eaveH rise (* 2600 *PEB-TEXT-SCALE*)))
            ;; HEADING SIZE.  txt-bold ALREADY multiplies by *PEB-TEXT-SCALE*, so the
            ;; original (* 500 *PEB-TEXT-SCALE*) scaled by TEXT-SCALE **SQUARED** and
            ;; ran the full width of the 122 m wall.  Fixing that overshot to 300, which
            ;; plots at 1.1 mm; the owner then asked for headings that MATCH across
            ;; sheets and are not too small.  One ladder entry now settles both.
            ;; capped against the wall's own width — see peb-head-h (owner 27-Aug)
            (peb-head-h (peb-part-title hdTxt) faceLen) 0 (peb-part-title hdTxt))
  (setvar "CECOLOR" "BYLAYER")

  ;; 9. eave-height dim (left) + bay/station dim chain (below the bubbles)
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-v (- ox (* 1500 *PEB-DIM-SCALE*)) base (+ base eaveH)
                      (peb-dim-mft eaveH)))))
  ;; the dim chain clears the bubble by its ACTUAL radius, not a fixed drop
  (setq noteY (- base bubGap bubR (* 600.0 *PEB-DIM-SCALE*)))
  (vl-catch-all-apply (function (lambda () (peb-fr-dimchain ox noteY stations))))
  ;; OVERALL LENGTH of the wall, below the bay chain, metres AND feet on the one
  ;; line (owner 26-Aug).  The bay chain above stays in mm per the sheet note.
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-h ox (+ ox faceLen) (- noteY (* 2600.0 *PEB-DIM-SCALE*))
                      (peb-dim-mft faceLen)))))
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
             " - H=" (peb-comma (rtos gbase 2 0)))))

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
                   " - H=" (peb-comma (rtos gbase 2 0))))))
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
                              bubGap bubR ov gbase owText sp sx cnt pre psurf pat pw noteY owU revView hdTxt
                              prng pi0 pi1 px0 pOfs pnTot
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
  ;; viewed from OUTSIDE — same rule as the framing elevation, see the note there
  ;; ── MATCH-LINE PART SLICE, BEFORE THE MIRROR (owner 27-Aug) ──────────────
  ;; A 122 m x 6 m wall stacked two-up is about 4:1 once its annotation is counted, and
  ;; a 1.1:1 drawing area cannot use the height — the same geometry that drove the roof
  ;; plans to a match line.  The slice happens FIRST, in model order, so pi0/pi1 always
  ;; mean the same physical bays; the mirror below then flips whichever part this is.
  (setq pOfs 0 pnTot (length stations) prng (peb-part-range (length stations)))
  (if prng
    (progn
      (setq pi0 (car prng) pi1 (cadr prng) pOfs pi0)
      (setq stations (peb-sub-list stations pi0 pi1))
      (setq px0 (car stations))
      (setq stations (mapcar (function (lambda (ss) (- ss px0))) stations))
      (setq faceLen (last stations))))
  (setq revView (and (member surf '("LEW" "FSW")) T))
  (if revView
    (progn
      (setq stations (reverse (mapcar (function (lambda (ss) (- faceLen ss))) stations)))
      (if isEnd (setq hiSide (not hiSide)))))
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
           (strcat "EXISTING RCC BUILDING (BY OTHERS) - 1st FLOOR +" (peb-comma (rtos rbFloor 2 0))))
      (peb-fr-masked-label (+ ox (* 0.5 (+ rx0 rx1))) (+ base rbBase (* 320.0 *PEB-TEXT-SCALE*)) (* 230 *PEB-TEXT-SCALE*)
           (strcat "RCC PILLARS + BRICK INFILL TO +" (peb-comma (rtos rbBase 2 0)) " (STEEL BASE)"))))
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
          pat (if revView (- faceLen pat) pat)      ; outside view — see the mirror note
          pw (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "WIDTH")) "0")))
    (if (and (= psurf surf) (> pw 0.0))
      (progn (setvar "CLAYER" "OPEN")
        (command "_.RECTANG" (list (+ ox pat (- (/ pw 2.0))) base) (list (+ ox pat (/ pw 2.0)) (+ base (* eaveH 0.72))))))
    (setq i (1+ i)))
  ;; grid bubbles + title + dim chain (mirror the framing)
  ;; Bubble size: see peb-bub-radius.  900 x TEXT-SCALE tracked the wall's LENGTH,
  ;; so on the 122 m side wall the bubbles were 4.9 m across and nearly touching
  ;; (owner 26-Aug: "Proportionally bubbles and dim sizes are very large").  Now
  ;; capped against the tightest bay AND this elevation's height; the stalk gap and
  ;; the dim chain below both follow the radius, so the stack under the wall stays
  ;; in proportion whatever the aspect ratio.
  (setq bubR (peb-bub-radius (peb-min-spacing stations)))
  (setq bubGap (+ (* 700.0 *PEB-TEXT-SCALE*) (* 2.2 bubR))
        i 0 ov *PEB-BUBRAD* *PEB-BUBRAD* bubR)
  (foreach g stations
    ;; pOfs keeps the numbers TRUE on a match-line part: part 2 starts at grid 9.
    (setq lbl (peb-fr-grid-label
                (+ pOfs (if revView (- (length stations) 1 i) i))
                pnTot isEnd))
    (setvar "CLAYER" "GRID-LINES")
    (command "_.LINE" (list (+ ox g) base) (list (+ ox g) (- base (* bubGap 0.45))) "")
    (vl-catch-all-apply (function (lambda () (grid-bubble (+ ox g) (- base bubGap) lbl "U"))))
    (setq i (1+ i)))
  (setq *PEB-BUBRAD* ov)
  (setvar "CLAYER" "TEXT") (setvar "CECOLOR" "5")
  ;; MATCH LINE on whichever DRAWN edge is a cut.  The mirror swaps them: on a reversed
  ;; wall (LEW/FSW) the low-grid end is drawn on the RIGHT, so the cut edges swap too.
  (if prng
    (progn
      (if (if revView (< pi1 (1- pnTot)) (> pi0 0))
        (peb-match-line ox (- base (* 700.0 *PEB-DIM-SCALE*))
                        (+ base eaveH rise (* 700.0 *PEB-DIM-SCALE*))
                        (itoa (if revView (1+ *PEB-PART-P*) (1- *PEB-PART-P*)))))
      (if (if revView (> pi0 0) (< pi1 (1- pnTot)))
        (peb-match-line (+ ox faceLen) (- base (* 700.0 *PEB-DIM-SCALE*))
                        (+ base eaveH rise (* 700.0 *PEB-DIM-SCALE*))
                        (itoa (if revView (1- *PEB-PART-P*) (1+ *PEB-PART-P*)))))))

  (setq hdTxt (strcat surf " - "
                (cond ((= surf "NSW") "NEAR SIDE WALL") ((= surf "FSW") "FAR SIDE WALL")
                      ((= surf "LEW") "LEFT END WALL") ((= surf "REW") "RIGHT END WALL") (T "WALL"))
                " SHEETING"))
  (txt-bold "MC" (list (+ ox (/ faceLen 2.0)) (+ base eaveH rise (* 2600 *PEB-TEXT-SCALE*)))
            (peb-head-h (peb-part-title hdTxt) faceLen) 0 (peb-part-title hdTxt))
  (setvar "CECOLOR" "BYLAYER")
  ;; SHEETING MLEADER — the wall equivalent of the roof sheeting plan's (owner 26-Aug).
  ;; PN_WALL_OUTER_PROFILE is real BSF data; placed above the wall and off-centre so it
  ;; clears the blue heading, matching where the framing sheet puts its GIRT TYPE mark.
  (vl-catch-all-apply (function (lambda ()
    (peb-label-with-leader
      (strcat "WALL SHEETING : "
              (strcase (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_PROFILE") "STANDARD PROFILE")))
      (list (+ ox (* faceLen 0.74)) (+ base eaveH rise (* 900.0 *PEB-DIM-SCALE*)))
      (list (+ ox (* faceLen 0.66)) (+ base (* eaveH 0.55)))
      "S" 600.0))))
  ;; OVERALL HEIGHT — the sheeting sheet never carried one; the framing sheet beside
  ;; it did, so the pair disagreed about what the wall measured (owner 26-Aug).
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-v (- ox (* 1500 *PEB-DIM-SCALE*)) base (+ base eaveH)
                      (peb-dim-mft eaveH)))))
  ;; the dim chain clears the bubble by its ACTUAL radius, not a fixed drop
  (setq noteY (- base bubGap bubR (* 600.0 *PEB-DIM-SCALE*)))
  (vl-catch-all-apply (function (lambda () (peb-fr-dimchain ox noteY stations))))
  ;; OVERALL LENGTH of the wall, below the bay chain, metres AND feet on the one
  ;; line (owner 26-Aug).  The bay chain above stays in mm per the sheet note.
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-h ox (+ ox faceLen) (- noteY (* 2600.0 *PEB-DIM-SCALE*))
                      (peb-dim-mft faceLen)))))
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
  ;; On a match-line part the sheet shows only its own slice, so the scale — and the
  ;; stacking pitch derived from it — must follow the PART.  Sized from the whole wall it
  ;; left every label on a half-sheet at full-wall size: the same mistake the roof plans
  ;; made first time round.
  (if (and *PEB-PART-N* (> *PEB-PART-N* 1))
    (setq faceMax (/ faceMax (float *PEB-PART-N*))))
  (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ faceMax 45000.0)))
        *PEB-DIM-SCALE*  *PEB-TEXT-SCALE*)
  ;; VERTICAL PITCH between stacked elevations.  (* 9000 ts) was a guess, and it
  ;; stopped being true the moment the overall metres/feet dim line went in below
  ;; each wall: the FSW dim line landed on the NSW heading.  Size it from what is
  ;; actually drawn, worst case -- peb-bub-radius caps bubR at 1100 * TEXT-SCALE:
  ;;   below the base : bubble gap 700 + stalk 2.2*bubR + bubble bubR
  ;;                    + chain clearance 600 + overall dim 2600 + slack 1800
  ;;   above the wall : heading offset 2600 + 1.6 * the heading's own height
  (setq ts   *PEB-TEXT-SCALE*
        step (+ eaveH (/ wid slopeD)
                (* ts (+ 700.0 (* 3.2 1100.0) 600.0 2600.0 1800.0
                         2600.0 (* 1.6 (peb-th 'HEADING)))))
        i 0)
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
  ;; the frame must wrap THIS sheet, not every sheet drawn so far (see
  ;; peb-frame-and-titleblock).  Same marker the tiler already uses.
  (setq *PEB-SHEET-MARK* prev-last)
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
;; PART-AWARE side-wall entry points — one A4 per match-line part.  Only the SIDE walls
;; split: an end wall is the building's WIDTH, which already fits (owner 27-Aug).
(defun peb-framing-sides-part-from-file (path p n)
  (setq *PEB-PART-P* p *PEB-PART-N* n)
  (peb-framing-sides-from-file path)
  (setq *PEB-PART-P* nil *PEB-PART-N* nil) (princ))
(defun peb-sheeting-sides-part-from-file (path p n)
  (setq *PEB-PART-P* p *PEB-PART-N* n)
  (peb-sheeting-sides-from-file path)
  (setq *PEB-PART-P* nil *PEB-PART-N* nil) (princ))
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
  ;; the frame must wrap THIS sheet, not every sheet drawn so far (see
  ;; peb-frame-and-titleblock).  Same marker the tiler already uses.
  (setq *PEB-SHEET-MARK* prev-last)
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

;; ── ROOF SHEETING PLAN (owner 26-Aug) ────────────────────────────────────────
;; The twin of the Roof Framing Plan: same outline, same grid, same annotation
;; standard — but it shows the CLADDING, not the steel.
;;
;;   * Sheeting runs go DOWN-SLOPE, ridge to eave, so in plan they are lines
;;     ACROSS the width repeating along the length at the panel cover width.
;;     That is deliberately perpendicular to the framing plan's purlin lines, so
;;     the two sheets can never be mistaken for one another at a glance.
;;   * The slope tags sit ON TOP of the sheeting (owner: "show the roof sheeting
;;     with showing the slopes on top") — one fall arrow per roof plane, tagged
;;     with the 1:NN ratio, exactly as the framing plan tags it.
;;   * Skylights come FROM THE BSF (RA_SKYLIGHTS) through the same
;;     peb-draw-roof-accessories the plan uses.  One source, no second opinion —
;;     if the BSF says zero, this sheet draws none (owner: "if applicable").
(defun peb-draw-roof-sheeting (data ox oy / len wid slopeD bayPts prev midY i x y
                               cover nRuns stype mgGables mgGableW base mgi ry mgRid
                               mgVal bubGap bubR ovr j fx hiNSW wgrid lbl
                               prng pi0 pi1 px0 pOfs)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (atof (peb-tb-or (MSPL-Get-Str data "SLOPE") "10")))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (setq bayPts (peb-fr-stations (MSPL-Get-Str data "BAYEXPR") len))
  ;; ── MATCH-LINE PART SLICE (owner 26-Aug) ─────────────────────────────────
  ;; A 4:1 building cannot use the height of a 1.1:1 drawing area, so a long sheet is
  ;; cut into parts joined by a MATCH LINE (see peb-part-range).  The slice is applied
  ;; HERE, before anything is drawn: every element below is driven off bayPts and len,
  ;; so shortening those two draws this part and nothing else, at roughly twice the
  ;; scale, with no other change to the routine.
  ;; pOfs keeps the grid numbers TRUE - part 2 starts at grid 9, not grid 1.
  (setq pOfs 0 prng (peb-part-range (length bayPts)))
  (if prng
    (progn
      (setq pi0 (car prng) pi1 (cadr prng) pOfs pi0)
      (setq bayPts (peb-sub-list bayPts pi0 pi1))
      (setq px0 (car bayPts))
      (setq bayPts (mapcar (function (lambda (ss) (- ss px0))) bayPts))
      (setq len (last bayPts))))
  ;; TEXT-SCALE AFTER the slice, from the length actually drawn.  Sized from the whole
  ;; building it left every label on a half-sheet at full-building size - the heading
  ;; then overhung the plan and, being the widest thing on the sheet, drove the plot
  ;; extents and threw away most of the scale the split had just won (owner 26-Aug).
  (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ (max len wid 1.0) 45000.0)))
        *PEB-DIM-SCALE*  *PEB-TEXT-SCALE*)
  (setq midY   (+ oy (/ wid 2.0))
        prev   (getvar "CLAYER")
        stype  (strcase (peb-tb-or (MSPL-Get-Str data "STYPE") "CS")))

  ;; --- roof outline -------------------------------------------------------
  (setvar "CLAYER" "STRUCTURE")
  (command "_.RECTANG" (list ox oy) (list (+ ox len) (+ oy wid)))

  ;; --- sheeting runs: one line per panel side-lap, at the cover width ------
  ;; 1000 mm is the cover of the standard profile; the panel SCHEDULE lives in the
  ;; proposal, so this sheet only has to read as sheeting, not to be counted off.
  (setvar "CLAYER" "SHEETING")
  (setq cover 1000.0
        nRuns (fix (/ len cover))
        i 1)
  (if (> nRuns 400) (setq nRuns 400))          ; a very long shed would just go black
  (while (< i nRuns)
    (setq x (+ ox (* cover i)))
    (command "_.LINE" (list x oy) (list x (+ oy wid)) "")
    (setq i (1+ i)))

  ;; --- main frame lines, light, so the grid still reads through the sheeting -
  (setvar "CLAYER" "GRID-LINES")
  (foreach g bayPts
    (command "_.LINE" (list (+ ox g) oy) (list (+ ox g) (+ oy wid)) ""))

  ;; --- ridge / valley + the falls, ON TOP of the sheeting ------------------
  (cond
    ;; MULTI-GABLE: N ridges, N-1 valley gutters
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
     (foreach ry mgVal (command "_.LINE" (list ox (+ oy ry)) (list (+ ox len) (+ oy ry)) ""))
     (setvar "CLAYER" "TEXT")
     (foreach ry mgRid
       (txt "ML" (list (+ ox (* len 0.02)) (+ oy ry (* 300 *PEB-TEXT-SCALE*)))
            (peb-th 'ANNOT) 0 "RIDGE LINE"))
     (foreach ry mgVal
       (txt "ML" (list (+ ox (* len 0.72)) (+ oy ry (* 300 *PEB-TEXT-SCALE*)))
            (peb-th 'ANNOT) 0 "VALLEY GUTTER"))
     )
    ;; BUTTERFLY: one central valley, both planes fall inwards
    ((= stype "BF")
     (setvar "CLAYER" "GRID")
     (command "_.LINE" (list ox midY) (list (+ ox len) midY) "")
     (setvar "CLAYER" "TEXT")
     (txt "MC" (list (+ ox (* len 0.5)) (+ midY (* 400 *PEB-TEXT-SCALE*)))
          (peb-th 'ANNOT) 0 "VALLEY GUTTER")
     )
    ;; MONO / LEAN-TO / CANOPY: no ridge, one fall the whole way across
    ((member stype '("SS" "LT" "CC"))
     (setq hiNSW (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data "RA_MONO_HIGH") "")) "*NSW*"))
     )
    ;; GABLE (clear span / multi-span): ridge down the middle, falls both ways
    (T
     (setvar "CLAYER" "RIDGE")
     (command "_.LINE" (list ox midY) (list (+ ox len) midY) "")
     (setvar "CLAYER" "TEXT")
     (txt "ML" (list (+ ox (* len 0.02)) (+ midY (* 300 *PEB-TEXT-SCALE*)))
          (peb-th 'ANNOT) 0 "RIDGE LINE")
     ))

  ;; --- SHEETING MLEADER (owner 26-Aug) -------------------------------------
  ;; "Framing plans must give the nomenclature of Purlins & Girts and Sheeting Plans
  ;; must give the MLEADER for the Sheeting."  So the member nomenclature lives on the
  ;; FRAMING sheets only; this sheet carries one mleader naming the cladding it shows.
  ;; The profile is REAL project data - PN_ROOF_OUTER_PROFILE straight off the BSF.
  (vl-catch-all-apply (function (lambda ()
    (peb-label-with-leader
      (strcat "ROOF SHEETING : "
              (strcase (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_PROFILE") "STANDARD PROFILE")))
      (list (+ ox (* len 0.34)) (- oy (* 1050.0 *PEB-DIM-SCALE*)))
      (list (+ ox (* len 0.34)) (+ oy (* wid 0.30)))
      "S" 600.0))))

  ;; --- fall arrows: the SAME shared glyph the Column Layout Plan and the Roof
  ;;     Framing Plan use, so all three plan sheets show the fall identically
  ;;     (owner 26-Aug).  See the note in peb-draw-roof-framing.
  (setq *PEB-ROOF-SLOPE* (format-slope (MSPL-Get-Str data "SLOPE")))
  (vl-catch-all-apply (function (lambda ()
    (peb-fall-glyph-set data stype len wid bayPts mgRid mgGableW))))

  ;; --- skylights / vents / roof openings, straight from the BSF ------------
  (if (boundp 'peb-draw-roof-accessories)
    (vl-catch-all-apply (function (lambda () (peb-draw-roof-accessories data len wid)))))

  ;; --- overall length + width, metres AND feet on the one line -------------
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-h ox (+ ox len)
      (+ oy wid (* *PEB-DIM-SCALE* (+ 1200.0 (* 3.2 1100.0) 2400.0)))
      (peb-dim-mft len)))))
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-v (- ox (* 2000 *PEB-DIM-SCALE*)) oy (+ oy wid) (peb-dim-mft wid)))))

  ;; --- bay chain (verbatim IF expression) ---------------------------------
  ;; The verbatim IF bay expression describes the WHOLE building, so it is wrong on a
  ;; match-line part - sheet 1 of 2 was captioned "1@7250 + 13@8263 + 1@7250" over nine
  ;; grids (owner 26-Aug).  The part's own overall dim already gives its true length.
  (if (and (null prng)
           (boundp 'peb-fmt-expr) (vl-string-search "@" (peb-tb-or (MSPL-Get-Str data "BAYEXPR") "")))
    (vl-catch-all-apply (function (lambda ()
      (peb-dim-h-stretch ox (+ ox len) (+ oy wid (* 900 *PEB-DIM-SCALE*))
                         (peb-fmt-expr (MSPL-Get-Str data "BAYEXPR")))))))

  ;; --- grid bubbles: numbers along the length, letters at the eaves --------
  (setq bubR   (peb-bub-radius (peb-min-spacing bayPts))
        bubGap (+ (* 1200.0 *PEB-TEXT-SCALE*) (* 2.2 bubR))
        j (1+ pOfs) ovr *PEB-BUBRAD* *PEB-BUBRAD* bubR)
  (foreach g bayPts
    (setvar "CLAYER" "GRID")
    ;; the stalk starts ABOVE the bay chain (which sits at 900 * DIM-SCALE), so the
    ;; chain text never has a run of stalks drawn through it (owner 26-Aug)
    (command "_.LINE" (list (+ ox g) (+ oy wid (* 1800 *PEB-DIM-SCALE*)))
                      (list (+ ox g) (+ oy wid bubGap)) "")
    (grid-bubble (+ ox g) (+ oy wid bubGap bubR) (itoa j) "D")
    (setq j (1+ j)))
  ;; The MERGED width grid must be resolved BEFORE either eave letter is drawn — it was
  ;; computed between them, so the near eave always fell back to the literal "A" and this
  ;; sheet printed A at BOTH eaves (owner 26-Aug: "sync all the sheeting, especially the
  ;; grid lines, with each other").
  (setq wgrid (vl-catch-all-apply (function (lambda () (peb-fr-ew-stations data wid "LEW")))))
  (if (or (vl-catch-all-error-p wgrid) (not (listp wgrid)) (< (length wgrid) 2)) (setq wgrid nil))
  (setvar "CLAYER" "GRID")
  (command "_.LINE" (list ox oy) (list (- ox bubGap) oy) "")
  ;; y=0 is the NEAR side wall, which the plan letters LAST — not "A" (owner 26-Aug).
  ;; See the audit table on peb-width-letter.
  (grid-bubble (- ox bubGap bubR) oy
               (if wgrid (peb-width-letter 0 (length wgrid)) "A") "R")
  (command "_.LINE" (list ox (+ oy wid)) (list (- ox bubGap) (+ oy wid)) "")
  ;; peb-grid-letter, not (chr 65+n): the plan skips I, so this must too
  (setq lbl (if wgrid (peb-width-letter (1- (length wgrid)) (length wgrid)) "B"))
  (grid-bubble (- ox bubGap bubR) (+ oy wid) lbl "R")
  (setq *PEB-BUBRAD* ovr)

  ;; MATCH LINE on whichever edge of this part is a cut (owner 26-Aug).  It names the
  ;; sheet the drawing continues onto, so the two halves can be read as one building.
  (if prng
    (progn
      (if (> pi0 0)
        (peb-match-line ox (- oy (* 900.0 *PEB-TEXT-SCALE*)) (+ oy wid (* 900.0 *PEB-TEXT-SCALE*))
                        (itoa (1- *PEB-PART-P*))))
      (if (< *PEB-PART-P* *PEB-PART-N*)
        (peb-match-line (+ ox len) (- oy (* 900.0 *PEB-TEXT-SCALE*)) (+ oy wid (* 900.0 *PEB-TEXT-SCALE*))
                        (itoa (1+ *PEB-PART-P*))))))

  ;; --- heading + title block ----------------------------------------------
  (setvar "CLAYER" "TEXT")
  (setvar "CECOLOR" "5")
  (txt-bold "MC" (list (+ ox (/ len 2.0)) (- oy (* 3200 *PEB-TEXT-SCALE*)))
            (peb-th 'HEADING) 0 (peb-part-title "ROOF SHEETING PLAN"))
  (setvar "CECOLOR" "BYLAYER")
  (setvar "CLAYER" prev)
  (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data "ROOF SHEETING PLAN")))))

(defun C:PEB-ROOF-SHEETING ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (progn (setq data (MSPL-Read-Data *PEB-DATA-FILE*))
           (if data (peb-draw-roof-sheeting data 0.0 0.0))))
  (princ))

;; tiled like the roof framing plan so it sits beside the other sheets.

;; ── DETAILS (owner 26-Aug as SHEETING PROFILE DETAILS; renamed DETAILS 27-Aug) ─
;; The sheet stopped being about one thing: it is where the details this project
;; actually buys are collected (rulebook 4B.24).  ONLY what the BSF declares appears —
;; a lock-seam section only on a lock-seam roof, a sandwich section only on a sandwich
;; panel — because a detail for something not in the offer is a scope argument later.
;; "There should be one page of detailed sheeting sections — in case of Standard S
;;  Profile its profile details should be shown; in case of seamlock, BOTH standard
;;  for walls and lockseam for roof shown in the same drawing ... for customer
;;  understanding."
;;
;; EVERY NUMBER HERE IS SOURCED, none invented:
;;   * "Standard S Profile 35-250" is the BSF's own option name (panelDefaults.js) —
;;     35 mm rib height at 250 mm rib pitch; 4 pitches = the 1000 mm cover.
;;   * Lock seam: the 1219 mm coil is slit into 2 x 610 mm strips, each roll-forming
;;     to 460 mm effective cover, concealed clip fixing, no face screws
;;     (services/estimation/quickest/cladding.ts — the same figure the estimate prices).
;;   * Material / thickness / finish / colour come straight off the BSF.
;; The seam HEIGHT is not carried anywhere, so the seam is drawn to shape and left
;; undimensioned rather than given a made-up number.
;;
;; ── THE S PROFILE IS THE ONE SECTION HERE THAT IS *NOT* TRACED ──────────────────────
;; Its NUMBERS are real and come from the BSF - 35 rib height, 250 rib pitch, 1000 cover -
;; and those are what the sheet dimensions and labels. Its RIB SHAPE is stylised: the
;; proportions below are chosen to look like a trapezoidal sheet, not measured off a
;; drawing.
;;
;; That is deliberate, and it is recorded here so nobody later mistakes it for measured
;; geometry. Searched ~3,500 MSPL approval PDFs across 2024-2025 (owner 27-Aug: "check the
;; approval drawing pdf, it always have the sheeting profile"). The profile panels that
;; exist there are SANDWICH PANEL PROFILE (20), PROFILE LINER PANEL (18), LOCK SEAM SHEET
;; PROFILE (16) and SKYLIGHT PROFILE (9) - the NON-DEFAULT products. The standard S profile
;; is only ever NAMED on those drawings, never sectioned, because it is the house default.
;; So there is nothing to trace; the roll-former's datasheet ("Lahore profile" in the BOQs)
;; would be the source if an exact section is ever wanted.
;;
;; Drawing a stylised shape under CORRECT dimensions is honest; inventing dimensions would
;; not be (rulebook 4B.24). The lock seam and the sandwich beside it ARE traced.
;;
;; One pitch of the S profile, left to right, over `pit`:
;;   flat pan .68  |  web up .08  |  crown .16  |  web down .08   (of the pitch)
(defun peb-sd-sprofile (x0 y0 n pit ht / i x pts)
  (setq i 0 pts (list (list x0 y0)))
  (while (< i n)
    (setq x (+ x0 (* i pit)))
    (setq pts (append pts (list (list (+ x (* pit 0.68)) y0)
                                (list (+ x (* pit 0.76)) (+ y0 ht))
                                (list (+ x (* pit 0.92)) (+ y0 ht))
                                (list (+ x pit)          y0))))
    (setq i (1+ i)))
  (setvar "CLAYER" "SHEETING")
  (setq i 0)
  (while (< (1+ i) (length pts))
    (command "_.LINE" (nth i pts) (nth (1+ i) pts) "")
    (setq i (1+ i)))
  pts)

;; One lock-seam pan: flat, then the standing seam upstand at each edge.
;; ── LOCK SEAM SHEET PROFILE — TRACED FROM A MAIMAAR APPROVAL DRAWING ────────────────
;; Owner 27-Aug: "get the exact profile of M35-250 & LOCKSEAM SHEETING ... check the
;; approval drawing pdf, it always have the sheeting profile."  He was right: every MSPL
;; approval sheet carries the panel section in its right-hand column beside the eave gutter
;; and the skylight.
;;
;; Source: E:\Maimaar Steel Pvt Ltd\Jobs59-MSPL_PAECO ... \Approval drawing;;         Pdf.pdf  — panel titled "LOCK SEAM SHEET PROFILE".
;;
;;   470 overall (the NET COVERING WIDTH, owner: "610 mm sheet produces 470 mm net covering
;;   width of lockseam including overlap" - which is why the estimate's coil/cover is 610/470)
;;   pan  : 92 | 10 rib | 145 | 10 rib | 91          the two ribs at 155 centres
;;   left  seam: 23 -> 32 at 119 deg -> 25 -> 15 -> 10 hook
;;   right seam: 22 -> 32 at 148 deg -> 25 -> 25 -> 10
;;
;; The seam legs are drawn to those lengths and angles; the pan breakdown is exact. This
;; replaces the proportional shape that stood here before, which was invented.
(defun peb-sd-lockseam (x0 y0 n cov ht / i x k)
  (setvar "CLAYER" "SHEETING")
  (setq k (/ cov 470.0))            ; scale the traced 470 section to the caller's module
  (setq i 0)
  (while (< i n)
    (setq x (+ x0 (* i cov)))
    ;; one 470 module, left hook -> left seam -> pan with its two ribs -> right seam -> hook
    (peb-sd-poly (list
      (list (+ x (* k   2.0)) (+ y0 (* k  62.0)))   ; top of the left hook (10)
      (list (+ x (* k   2.0)) (+ y0 (* k  52.0)))
      (list (+ x (* k  17.0)) (+ y0 (* k  52.0)))   ; 15 across
      (list (+ x (* k  17.0)) (+ y0 (* k  27.0)))   ; 25 down
      (list (+ x (* k  49.0)) (+ y0 (* k  11.0)))   ; 32 at 119 deg
      (list (+ x (* k  71.0)) (+ y0 0.0))           ; 23 into the pan
      (list (+ x (* k 163.0)) (+ y0 0.0))           ; 92 pan
      (list (+ x (* k 163.0)) (+ y0 (* k   8.0)))   ; 10 rib up
      (list (+ x (* k 173.0)) (+ y0 (* k   8.0)))
      (list (+ x (* k 173.0)) (+ y0 0.0))
      (list (+ x (* k 318.0)) (+ y0 0.0))           ; 145 pan
      (list (+ x (* k 318.0)) (+ y0 (* k   8.0)))   ; 10 rib up
      (list (+ x (* k 328.0)) (+ y0 (* k   8.0)))
      (list (+ x (* k 328.0)) (+ y0 0.0))
      (list (+ x (* k 419.0)) (+ y0 0.0))           ; 91 pan
      (list (+ x (* k 441.0)) (+ y0 (* k  11.0)))   ; 22 out of the pan
      (list (+ x (* k 453.0)) (+ y0 (* k  41.0)))   ; 32 at 148 deg
      (list (+ x (* k 453.0)) (+ y0 (* k  62.0)))   ; 25 up
      (list (+ x (* k 468.0)) (+ y0 (* k  62.0)))   ; 25 across
      (list (+ x (* k 468.0)) (+ y0 (* k  52.0)))))  ; 10 down - receives the next panel
    (setq i (1+ i)))
  (princ))

;; ── SANDWICH PANEL SECTION — TRACED FROM A MAIMAAR APPROVAL DRAWING ─────────────────
;; Source: E:\Maimaar Steel Pvt Ltd\Jobs584-MSPL_AZ Engineering ... \Approval
;;         Drawing\Rev-00\Pdf.pdf, panel "SANDWICH PANEL PROFILE" (the same section
;;         appears on 202-MSPL and 205-MSPL, so it is the house panel, not a one-off).
;;
;;   920 cover = 5 modules of 184        rib 32 wide at the crown, 32 tall above the core
;;   flat between ribs 106               16 at each end (the half-rib that laps the next panel)
;;   core 50 on those jobs — but the CORE HERE IS WHATEVER THE BSF SAYS (PN_*_PIR_THK),
;;   because the drawing follows the specification; only the profile is fixed.
;;   skins 0.5 mm PPGL outer / 0.5 mm PPGI liner (0.45/0.5 Aluzinc on 202-MSPL).
;;
;; Replaces the previous version, which reused the single-skin S profile at 250 pitch and
;; 35 rib on top of the core. A sandwich's outer face is NOT the S profile: it is this
;; 184-module 32 rib, and the two look plainly different on the page.
(defun peb-sd-sandwich (x0 y0 n pit ht thk / i x w mod rib crown flat lap top)
  (setq mod 184.0 rib 32.0 crown 32.0 flat 106.0 lap 16.0)
  (setq top (+ y0 thk))
  (setq w (+ (* n mod) lap))                       ; n modules plus the closing lap
  (setvar "CLAYER" "SHEETING")
  ;; OUTER SKIN, left to right: the opening lap, then n × (flat, rib up, crown, rib down)
  (setq i 0 x (+ x0 lap))
  (peb-sd-poly (list (list x0 top) (list x top)))   ; 16 lap
  (while (< i n)
    (setq x (+ x0 lap (* i mod)))
    (peb-sd-poly (list
      (list x                         top)
      (list (+ x (* rib 0.55))        (+ top rib))          ; up the rib
      (list (+ x (* rib 0.55) crown)  (+ top rib))          ; 32 crown
      (list (+ x (+ (* rib 1.10) crown)) top)               ; down the rib
      (list (+ x mod)                 top)))                ; 106 flat to the next module
    (setq i (1+ i)))
  ;; FLAT INNER LINER, and the core closed at both ends
  (peb-sd-poly (list (list x0 y0) (list (+ x0 w) y0)))
  (peb-sd-poly (list (list x0 y0) (list x0 top)))
  (peb-sd-poly (list (list (+ x0 w) y0) (list (+ x0 w) top)))
  ;; light core hatching, drawn as strokes so it cannot depend on a hatch pattern
  (setvar "CLAYER" "HATCH")
  (setq i 1)
  (while (< (* i (/ thk 1.4)) w)
    (setq x (+ x0 (* i (/ thk 1.4))))
    (command "_.LINE" (list (min x (+ x0 w)) y0)
                      (list (max x0 (- x thk)) top) "")
    (setq i (1+ i)))
  (princ))

;; Draw an open polyline through a list of points.
(defun peb-sd-poly (pts / i)
  (setq i 0)
  (while (< (1+ i) (length pts))
    (command "_.LINE" (nth i pts) (nth (1+ i) pts) "")
    (setq i (1+ i)))
  (princ))

;; ── EAVE GUTTER SECTION — TRACED FROM A REAL MAIMAAR TRIM (owner 27-Aug) ─────────────
;; Source: Jobs59-MSPL_PAECO ... \Approval drawing\Eave Gutter;;         169-MSPL_Eave Gutter.pdf  — a dimensioned trim development.
;;
;; WHY THIS IS FAIR AT PROPOSAL STAGE while an installed gutter detail is not: it is a
;; PRODUCT PROFILE, like the sheeting section beside it. Its shape and gauge are fixed by
;; the fold, not by design — no fall, no outlet spacing, no bracket centres, which are the
;; things only settled at approval stage. Every number below is off that drawing.
;;
;; Walked from the inside base-left corner, x right, y up:
;;   base 165 -> front leg 150 up -> 50 lip out at 84 deg
;;   back:  103 up -> 42 sloped at 135 deg (30 rise) -> 70 up -> 20 lip out at 96 deg
;;   overall depth 203, which the drawing dimensions as 103 + 30 + 70.
(defun peb-sd-eave-gutter (x0 y0 sc / p)
  (setvar "CLAYER" "SHEETING")
  (setq p (list
    (list (+ x0 (* sc -50.0))  (+ y0 (* sc 207.0)))   ; back top lip, 20 out at 96 deg
    (list (+ x0 (* sc -30.0))  (+ y0 (* sc 203.0)))   ; top of the back leg
    (list (+ x0 (* sc -30.0))  (+ y0 (* sc 133.0)))   ; down 70
    (list (+ x0 0.0)           (+ y0 (* sc 103.0)))   ; 42 sloped at 135 deg (30 rise)
    (list (+ x0 0.0)           (+ y0 0.0))            ; down 103 to the base
    (list (+ x0 (* sc 165.0))  (+ y0 0.0))            ; base 165
    (list (+ x0 (* sc 165.0))  (+ y0 (* sc 150.0)))   ; front leg 150 up
    (list (+ x0 (* sc 213.0))  (+ y0 (* sc 158.0)))))  ; 50 lip out at 84 deg
  (peb-sd-poly p)
  p)

;; IS THIS A PROFILE WE ACTUALLY KNOW HOW TO DRAW? (rulebook 4B.24)
;; The shape is chosen by substring against the BSF's profile text, and the vocabulary is
;; small and controlled today ("Standard S Profile" variants, "Lock Seam Profile (roof
;; only)").  The danger is the day a new product is added to panelDefaults.js: an
;; unrecognised name would fall through to the STANDARD S section and draw a definite,
;; WRONG product.  Under the scope-of-work rule that is the worst available failure — the
;; customer is holding our drawing.  So say so instead of guessing.
(defun peb-sd-known-p (prof ptype thk)
  (setq prof (strcase (if prof prof "")) ptype (strcase (if ptype ptype "")))
  (or (vl-string-search "LOCK" prof) (vl-string-search "SEAM" prof)
      (and (> thk 0.0) (vl-string-search "SANDWICH" ptype))
      (vl-string-search "STANDARD" prof)
      (vl-string-search "S PROFILE" prof)
      (= prof "")))                       ; blank = the house standard, which we do know

(defun peb-sd-panel (ox y lock ttl mat fin col ptype thk / pit ht cov panW gA sand dep)
  ;; ONE panel detail: the section, its rib/pitch dimensions, the cover dimension,
  ;; and that panel's OWN specification off the BSF.
  (setq pit 250.0 ht 35.0 cov 470.0 panW 1000.0)   ; 470 = gola c/c per MSPL fabrication BOQs
  (setq sand (and (> thk 0.0) (vl-string-search "SANDWICH" (strcase ptype))))
  ;; The title clears the panel by its ACTUAL depth — a 50 mm sandwich core is deeper
  ;; than a 35 mm rib, and a fixed offset put the title straight through it.
  (setq dep (cond (lock 38.0) (sand (+ thk ht)) (T ht)))
  (setvar "CLAYER" "TEXT") (setvar "CECOLOR" "5")
  (txt-bold "ML" (list ox (+ y dep 55.0)) (peb-th 'LABEL) 0 ttl)
  (setvar "CECOLOR" "BYLAYER")
  (cond
    (lock (peb-sd-lockseam ox y 2 cov 38.0)
          (setq gA "CONCEALED CLIP FIXING - NO FACE SCREWS"))
    (sand (peb-sd-sandwich ox y 4 pit ht thk)
          ;; the core thickness is dimensioned because it IS the specified value
          (vl-catch-all-apply (function (lambda ()
            (peb-fr-overall-v (- ox 90.0) y (+ y thk) (strcat (rtos thk 2 0) " CORE")))))
          (setq gA (strcat "35 RIB  |  250 PITCH  |  " (rtos thk 2 0)
                           " CORE, PROFILED OUTER + FLAT LINER")))
    (T    (peb-sd-sprofile ox y 4 pit ht)
          (vl-catch-all-apply (function (lambda ()
            (peb-fr-overall-h (+ ox (* pit 0.84)) (+ ox (* pit 1.84)) (- y 55.0)
                              (rtos pit 2 0)))))
          (setq gA "35 RIB HEIGHT  |  250 RIB PITCH")))
  ;; the cover dim spans ONE panel of THIS profile — a lock-seam sheet covers 460, not
  ;; the 1000 a trapezoidal sheet covers, and the bar said 1,000 while the note beside it
  ;; said 460 (owner 27-Aug).
  (if lock (setq panW cov))
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-h ox (+ ox panW) (- y 135.0)
                      (strcat (peb-comma (rtos panW 2 0)) " COVER")))))
  (setvar "CLAYER" "TEXT")
  (txt "ML" (list ox (- y 200.0)) (peb-th 'ANNOT) 0 gA)
  (txt "ML" (list ox (- y 250.0)) (peb-th 'ANNOT) 0
       (strcase (strcat (if (/= ptype "") (strcat ptype "  |  ") "")
                        (if (/= mat "") mat "PANEL AS SPECIFIED")
                        (if (/= fin "") (strcat "  |  " fin) "")
                        (if (/= col "") (strcat "  |  " col) ""))))
  (princ))

(defun peb-sd-title (lock data typeKey / ty)
  ;; The shorthand in brackets is the SECTION's label for the same product — that sheet
  ;; calls them "(S-Type)" and "(Seam-Lock)" (owner 14-Jul, because Maimaar runs both and
  ;; the label must say which).  Carrying the shorthand here ties the two sheets together,
  ;; so a reader meeting "(S-Type)" on the section can see on THIS sheet what it is,
  ;; instead of meeting two names for one panel (owner 27-Aug).
  (setq ty (strcase (peb-tb-or (MSPL-Get-Str data typeKey) "")))
  (cond (lock "LOCK SEAM PROFILE (SEAM-LOCK)")
        ((vl-string-search "SANDWICH" ty) "SANDWICH PANEL (S-TYPE OUTER SKIN)")
        (T "STANDARD S PROFILE 35-250 (S-TYPE)")))

(defun peb-draw-sheeting-details (data ox oy / prev rp wp lockR lockW y rSig wSig same et gx)
  (setq prev (getvar "CLAYER"))
  (setq rp (strcase (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_PROFILE") "STANDARD PROFILE"))
        wp (strcase (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_PROFILE") "STANDARD PROFILE")))
  (setq lockR (or (vl-string-search "LOCK" rp) (vl-string-search "SEAM" rp))
        lockW (or (vl-string-search "LOCK" wp) (vl-string-search "SEAM" wp)))
  ;; Text is sized from THIS sheet, not from a building: the ladder's usual
  ;; faceMax/45000 (floored at 0.80) would put 660 mm lettering on a 1000 mm detail.
  ;; Keeping the whole sheet inside ~1000 x 900 lets it plot at 1:5, so the section
  ;; is ~200 mm across the page instead of a stamp in the corner.
  (setq *PEB-TEXT-SCALE* (/ 1000.0 45000.0) *PEB-DIM-SCALE* *PEB-TEXT-SCALE*)

  ;; ONLY THE PROFILE THE BSF SELECTS IS DRAWN (owner 27-Aug).  When the roof and the
  ;; wall are the SAME product there is one detail, titled for both; when they differ -
  ;; a lock-seam roof over standard walls, the case the owner asked for on 26-Aug - both
  ;; are drawn.  Nothing speculative is ever shown: a building with no lock seam never
  ;; gets a lock-seam section.
  (setq rSig (strcat (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_PROFILE") "") "|"
                     (peb-tb-or (MSPL-Get-Str data "PN_ROOF_TYPE") "") "|"
                     (peb-tb-or (MSPL-Get-Str data "PN_ROOF_PIR_THK") "") "|"
                     (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_MAT") ""))
        wSig (strcat (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_PROFILE") "") "|"
                     (peb-tb-or (MSPL-Get-Str data "PN_WALL_TYPE") "") "|"
                     (peb-tb-or (MSPL-Get-Str data "PN_WALL_PIR_THK") "") "|"
                     (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_MAT") "")))
  (setq same (= (strcase rSig) (strcase wSig)))
  ;; Refuse rather than guess: an unrecognised profile gets a stated line, not a section
  ;; that would claim the wrong product (rulebook 4B.24).
  (if (not (peb-sd-known-p rp (MSPL-Get-Str data "PN_ROOF_TYPE")
                           (atof (peb-tb-or (MSPL-Get-Str data "PN_ROOF_PIR_THK") "0"))))
    (progn (setvar "CLAYER" "TEXT")
           (txt "ML" (list ox 0.0) (peb-th 'ANNOT) 0
                (strcat "ROOF SHEETING - " rp))
           (txt "ML" (list ox -180.0) (peb-th 'ANNOT) 0
                "SECTION NOT SHOWN - PROFILE PER THE TECHNICAL & FINANCIAL PROPOSAL."))
  (peb-sd-panel ox 0.0 lockR
    (strcat (if same "ROOF & WALL SHEETING - " "ROOF SHEETING - ")
            (peb-sd-title lockR data "PN_ROOF_TYPE"))
    (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_MAT") "")
    (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_FINISH") "")
    (peb-tb-or (MSPL-Get-Str data "PN_ROOF_OUTER_COLOR") "")
    (peb-tb-or (MSPL-Get-Str data "PN_ROOF_TYPE") "")
    (atof (peb-tb-or (MSPL-Get-Str data "PN_ROOF_PIR_THK") "0"))))
  ;; PITCH between the two details.  A panel occupies from (y + depth + title) down to
  ;; its two spec lines at y-250, so -380 put the WALL title straight through the ROOF's
  ;; specification (owner 27-Aug).  -520 clears the deepest case (a sandwich core).
  (if (not same)
    (peb-sd-panel ox -520.0 lockW
      (strcat "WALL SHEETING - " (peb-sd-title lockW data "PN_WALL_TYPE"))
      (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_MAT") "")
      (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_FINISH") "")
      (peb-tb-or (MSPL-Get-Str data "PN_WALL_OUTER_COLOR") "")
      (peb-tb-or (MSPL-Get-Str data "PN_WALL_TYPE") "")
      (atof (peb-tb-or (MSPL-Get-Str data "PN_WALL_PIR_THK") "0"))))

  (setq y (if same -360.0 -880.0))
  (setvar "CLAYER" "TEXT")
  (txt "ML" (list ox y) (peb-th 'ANNOT) 0
       "PROFILE SHOWN INDICATIVE - PANEL SUPPLIED PER THE APPROVED DESIGN.")

  ;; ── EAVE GUTTER, ONLY WHERE THE BUILDING HAS ONE (owner 27-Aug, rulebook 4B.24) ─────
  ;; BP_EAVE_TYPE is the building's own eave condition: "Eave Gutters & Downspouts",
  ;; "Eave Trim", "Curved Eave with/without projection", or "Valley Gutter".  The gutter
  ;; section is drawn ONLY for the gutter cases - an eave-trim or curved-eave building must
  ;; not carry a gutter detail, because the drawing is part of the offer and a detail for
  ;; something not sold is a scope argument at handover.
  ;;
  ;; VALLEY GUTTER IS NOT DRAWN YET, and is deliberately not substituted with the eave
  ;; section: they are different products (owner: only multi-gable jobs get valley gutters),
  ;; and no dimensioned valley profile exists in the Jobs tree - only a BOQ of valley trims
  ;; (job 171).  A valley building gets the honest line instead of the wrong picture.
  ;; SECOND COLUMN, not a third row.  Stacking the gutter under the panels made the sheet
  ;; tall and narrow: the fit rule then scaled everything down to suit the height, the
  ;; drawings shrank, and the DETAILS heading was stranded in the middle of the page.  Beside
  ;; them the sheet stays close to the drawing box's own 1.10:1, which is what fills it.
  (setq et (strcase (peb-tb-or (MSPL-Get-Str data "BP_EAVE_TYPE") "")))
  (setq gx (+ ox 1500.0))
  (setvar "CLAYER" "TEXT")
  (cond
    ((vl-string-search "VALLEY" et)
      (setvar "CECOLOR" "5")
      (txt-bold "ML" (list gx 170.0) (peb-th 'LABEL) 0 "VALLEY GUTTER")
      (setvar "CECOLOR" "BYLAYER")
      (txt "ML" (list gx 0.0) (peb-th 'ANNOT) 0 "SECTION PER THE APPROVAL DRAWING.")
      (txt "ML" (list gx -160.0) (peb-th 'ANNOT) 0 "1.2 mm PPG.L  |  COLOUR AS SHEET"))
    ((vl-string-search "GUTTER" et)
      (setvar "CECOLOR" "5")
      (txt-bold "ML" (list gx 170.0) (peb-th 'LABEL) 0 "EAVE GUTTER")
      (setvar "CECOLOR" "BYLAYER")
      ;; the trim is 203 deep; 0.55 gives it the same visual weight as a panel section
      (vl-catch-all-apply (function (lambda ()
        (peb-sd-eave-gutter (+ gx 120.0) 0.0 0.55))))
      ;; kept short so the column does not run into the title strip
      (txt "ML" (list gx -200.0) (peb-th 'ANNOT) 0 "165 BASE  |  203 DEEP")
      (txt "ML" (list gx -360.0) (peb-th 'ANNOT) 0 "1.2 mm PPG.L  |  3 M")
      (txt "ML" (list gx -520.0) (peb-th 'ANNOT) 0 "COLOUR AS SHEET")))

  (setvar "CECOLOR" "5")
  ;; The heading sits BELOW everything on the sheet, at a fixed depth clear of both
  ;; columns.  Hanging it off the panel column's own y put it in the middle of the page
  ;; as soon as a second column was added beside it (owner 27-Aug).
  (txt-bold "MC" (list (+ ox 900.0) -800.0) (peb-th 'HEADING) 0
            "DETAILS")
  (setvar "CECOLOR" "BYLAYER")
  (setvar "CLAYER" prev)
  (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data "DETAILS")))))

(defun C:PEB-SHEETING-DETAILS ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (progn (setq data (MSPL-Read-Data *PEB-DATA-FILE*))
           (if data (peb-draw-sheeting-details data 0.0 0.0))))
  (princ))

(defun peb-sheeting-details-from-file (path / prev-last prev-max-x)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  (setq *PEB-SHEET-MARK* prev-last)
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-SHEETING-DETAILS)
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place)
    (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x)))))
  (princ))

;; PART-AWARE entry points.  The pipeline calls these once per part; each renders a
;; complete A4 sheet covering its own slice of the building, joined by a MATCH LINE.
;; Part 1 of 1 is exactly the old behaviour, so nothing changes for a normal building.
(defun peb-roof-framing-part-from-file (path p n)
  (setq *PEB-PART-P* p *PEB-PART-N* n)
  (peb-roof-framing-from-file path)
  (setq *PEB-PART-P* nil *PEB-PART-N* nil)
  (princ))

(defun peb-roof-sheeting-part-from-file (path p n)
  (setq *PEB-PART-P* p *PEB-PART-N* n)
  (peb-roof-sheeting-from-file path)
  (setq *PEB-PART-P* nil *PEB-PART-N* nil)
  (princ))

(defun peb-roof-sheeting-from-file (path / prev-last prev-max-x)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  ;; the frame must wrap THIS sheet, not every sheet drawn so far (see
  ;; peb-frame-and-titleblock).  Same marker the tiler already uses.
  (setq *PEB-SHEET-MARK* prev-last)
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-ROOF-SHEETING)
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place)
    (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x)))))
  (princ))

(princ "\nMAIMAAR_PEB_Framing.lsp loaded — (peb-framing-from-file ...) elevations + (peb-roof-framing-from-file ...) plan.")
(princ)
