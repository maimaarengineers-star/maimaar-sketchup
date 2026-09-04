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

(defun peb-draw-roof-framing (data ox oy / len wid slopeD bayPts purlSp nRows i x y wMods
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
  (setq *PEB-BUB-FIT* (peb-bub-fit "ROOF"))
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
  ;; ;; peb-width-mark, not peb-width-letter: the merged grid now carries the infill POSTS as well as
  ;; the module lines, so counting straight through it gave the far wall a letter that counted the
  ;; posts too - K where the plan says F.  A main line takes its letter, a post takes a prime.
  (setq wMods (vl-catch-all-apply (function (lambda () (peb-width-mods data wid)))))
  (if (vl-catch-all-error-p wMods) (setq wMods nil))
  (grid-bubble (- ox bubGap bubR) oy
               (if wgrid (peb-width-mark (nth 0 wgrid) wgrid wMods) "A") "R")
  (command "_.LINE" (list ox (+ oy wid)) (list (- ox bubGap) (+ oy wid)) "")
  (grid-bubble (- ox bubGap bubR) (+ oy wid)
               (if wgrid (peb-width-mark (nth (1- (length wgrid)) wgrid) wgrid wMods) "B") "R")
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
;; `marks` is the merged width grid's marks in plan order (peb-width-marks): a width-MODULE line
;; takes a plain letter, an infill post takes the primed letter of the main above it (4B.61).
;; Without it every station counted as a main and the far wall came out K where the plan says F.
;; nil `marks` keeps the old straight-count behaviour, which is right when there is no module
;; chain to judge against.
(defun peb-fr-grid-label (i nSt isEnd marks)
  (if isEnd
    (if (and marks (>= i 0) (< i (length marks)))
      (nth i marks)
      (peb-grid-letter (+ (- nSt 1 i) (if *PEB-GRID-LET-OFS* *PEB-GRID-LET-OFS* 0))))
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
  ;; Rule 4B.34 — BOTH of these run ACROSS THE WIDTH and are written from grid A downward,
  ;; so they go through peb-width-stations (which reverses) rather than the plain
  ;; peb-fr-scaled-stations, which also serves LENGTH chains and must not reverse.
  (setq st (peb-width-stations (peb-tb-or (MSPL-Get-Str data "MODEXPR") "") wid))
  (setq expr (peb-tb-or (if (= surf "LEW") (MSPL-Get-Str data "EWLEXPR")
                                           (MSPL-Get-Str data "EWREXPR")) ""))
  (setq ew (if (/= expr "")
             (peb-width-stations expr wid)
             (if (boundp 'peb-ew-auto-stations) (peb-ew-auto-stations wid) nil)))
  (setq out st)
  (foreach s ew
  ;; Rule 4B.34 / grid merge tolerance: 5 mm, not 1 mm. Two chains across the SAME width
  ;; (the width module and the end-wall columns) are entered independently and each is
  ;; rounded to whole millimetres on export, so the same physical line can arrive from the
  ;; two chains up to a couple of mm apart. At 1.0 mm — and the test is "<", so exactly
  ;; 1 mm FAILED — those survived as separate stations and the sheet grew duplicate grid
  ;; letters printed on top of each other (MSPL-26-271 came out A..M for a 9-line grid).
  ;; No two real columns are 5 mm apart, so this cannot merge lines that differ.
    (if (not (vl-some (function (lambda (p) (< (abs (- p s)) 5.0))) out))
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

;; == ROOF MONITOR ON THE WALL ELEVATIONS =========================================
;; Owner 31-Aug: "A Huge Bug now. Elevations Do not Show the Roof Monitor Lines."
;;
;; NOT a regression - the elevations never had it.  The monitor lived on exactly two
;; surfaces: the SECTION (peb-draw-roof-monitor, Section.lsp) and the ROOF PLAN
;; (peb-draw-monitor / peb-monitor-band, Plan.lsp).  All four wall elevations read no
;; RM_* key whatsoever, so a shed carrying a 1500 throat monitor printed end walls
;; whose roof line ran straight over the ridge as though nothing sat on it.
;;
;; THE DERIVATION BELOW IS THE SECTION'S, VERBATIM, so the three surfaces cannot drift:
;;   throat  = RM_THROAT_WIDTH  (falls back to RM_OVERALL_WIDTH)
;;   overall = RM_OVERALL_WIDTH, and when blank or <= throat -> throat * 2 (owner 31-Aug)
;;   height  = throat / 2 - STANDING RULE R1, *not* RM_HEIGHT.  The section ignores that
;;             key too; one monitor drawn to two different heights on two sheets of one
;;             set is precisely the class of bug that sharing this derivation avoids.
;;
;; The legs are seated with peb-fr-topy - the SAME function that drew the roof line on
;; this very sheet - so they land ON the drawn roof for any roof type, rather than on a
;; separately computed one that could float above it or sink below it.
;;
;; THE TWO VIEWS SHOW DIFFERENT THINGS (one object, two projections):
;;   END wall  (LEW/REW) - the CROSS-SECTION: a mini gable straddling the peak, legs at
;;             ridge +/- throat/2, its roof overhanging each leg out to +/- overall/2.
;;             The monitor END is sheeted closed, so NO vent opening is drawn there.
;;   SIDE wall (NSW/FSW) - the LENGTH: a raised band over the ridge spanning grids
;;             RM_GRID_FROM..RM_GRID_TO.  THIS face is the vent, so the throat opening
;;             and its bird mesh (RM_BIRD_MESH) show here and only here.
;; Rule 4B.58.
(defun peb-fr-mon-geom (data / on throat overall)
  ;; -> (throat overall height), or nil when the building carries no monitor.
  (setq on (strcase (peb-tb-or (MSPL-Get-Str data "RM_TOGGLE") "")))
  (if (or (= on "YES") (= on "Y") (= on "TRUE") (= on "1"))
    (progn
      (setq throat (MSPL-Get-Num data "RM_THROAT_WIDTH"))
      (if (or (null throat) (<= throat 0.0))
        (setq throat (MSPL-Get-Num data "RM_OVERALL_WIDTH")))
      (if (and throat (> throat 0.0))
        (progn
          (setq overall (MSPL-Get-Num data "RM_OVERALL_WIDTH"))
          (if (or (null overall) (<= overall throat)) (setq overall (* throat 2.0)))
          (list throat overall (/ throat 2.0)))))))

(defun peb-fr-monitor (data ox base faceLen eaveH eaveHi eaveLo rise rtype hiSide isEnd
                       wallEave slopeD stations kind
                       / m throat overall rmh halfT halfO prev cx s apexY
                         legL legR legTopL legTopR ridgeY eaveY
                         nSt gFrom gTo mx0 mx1 bandH nT i px mesh
                         isSht sxm ytop lx)
  (setq m (peb-fr-mon-geom data))
  ;; Only a GABLE carries a monitor: it straddles a RIDGE, and rtype "B" puts a VALLEY at
  ;; mid-span (see peb-fr-topy) - seating a monitor there would draw it inside a gutter.
  (if (and m (= rtype "G") (> faceLen 1.0) (> rise 0.0) (> slopeD 0.0))
    (progn
      ;; kind "S" = a SHEETING elevation, "F" = a FRAMING one.  The framing sheets keep the clean
      ;; outline; only the sheeting sheets get panel lines, the same split the rest of these two
      ;; drawers already observe.
      (setq prev   (getvar "CLAYER")
            throat (car m) overall (cadr m) rmh (caddr m)
            halfT  (/ throat 2.0)
            halfO  (/ overall 2.0)
            isSht  (= kind "S"))
      (if isEnd
        ;; ---- END WALL: the monitor in cross-section, straddling the drawn peak -------
        ;; Skipped when the monitor is as wide as the building - that is not a monitor,
        ;; it is a data error, and drawing it would bury the end wall underneath it.
        (if (< overall (* faceLen 0.60))
          (progn
            (setq cx      (/ faceLen 2.0)
                  s       (/ rise cx)          ; the slope of the roof AS DRAWN on this sheet
                  apexY   (peb-fr-topy cx faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                  legL    (peb-fr-topy (- cx halfT) faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                  legR    (peb-fr-topy (+ cx halfT) faceLen base eaveH eaveHi eaveLo rise rtype hiSide)
                  ridgeY  (+ apexY rmh)
                  eaveY   (- ridgeY (* halfO s))   ; monitor roof follows the MAIN slope
                  legTopL (+ legL rmh)
                  legTopR (+ legR rmh))
            ;; The two legs, seated on the main rafter - on the FRAMING sheet only.
            ;; A sheeting elevation shows no structure BEHIND its sheeting: the end wall on this very
            ;; sheet draws its panel lines and brick with no columns at all.  The monitor legs are the
            ;; same thing at a smaller scale, and once the end sheeting ran the full 3000 they sat 150
            ;; from a sheet line - a quarter of a millimetre at 1:234 - and printed as a doubled line
            ;; at each leg.  Omitting them is not hiding a member; it is the sheet being consistent
            ;; about what it shows.
            (if (not isSht)
              (progn
                (setvar "CLAYER" "STRUCTURE")
                (command "_.LINE" (list (+ ox (- cx halfT)) legL) (list (+ ox (- cx halfT)) legTopL) "")
                (command "_.LINE" (list (+ ox (+ cx halfT)) legR) (list (+ ox (+ cx halfT)) legTopR) "")))
            ;; its own gable roof, overhanging each leg out to overall/2
            (setvar "CLAYER" "CLADDING")
            (command "_.PLINE" (list (+ ox (- cx halfO)) eaveY)
                               (list (+ ox cx) ridgeY)
                               (list (+ ox (+ cx halfO)) eaveY) "")
            ;; eave returns - the fascia depth at each overhang, so the roof reads as a
            ;; sheeted plane with a real edge instead of two bare lines meeting in a V.
            (command "_.LINE" (list (+ ox (- cx halfO)) eaveY)
                              (list (+ ox (- cx halfO)) (- eaveY (* 0.18 rmh))) "")
            (command "_.LINE" (list (+ ox (+ cx halfO)) eaveY)
                              (list (+ ox (+ cx halfO)) (- eaveY (* 0.18 rmh))) "")
            ;; NAME IT (owner 31-Aug: "write the roof monitor name in elevations for clearity").
            ;; The roof plan names it and the section labels it; the elevations were showing an
            ;; unlabelled box sitting on the ridge, which is only obvious to someone who already
            ;; knows the building has a monitor.
            ;; LEADER TO THE SIDE, not a caption above.  The monitor stands on the PEAK and the
            ;; sheet heading is centred over the same peak, so ANY centred label above it lands
            ;; directly under the title and reads as a subtitle of the drawing rather than as a
            ;; label on a part.  Measured: at 2.0 text-heights it OVERLAPPED the heading by 79.5,
            ;; and at 1.15 it cleared by only 294 - 1.3 mm on paper - which still read as a
            ;; subtitle.  Height alone cannot fix it; the label has to leave the centreline.
            ;; It goes LEFT: the right-hand side already carries the GIRT TYPE leader and its text.
            ;; The leader sits at the monitor mid-height, so it points at the monitor itself
            ;; rather than at the roof, and the text is right-justified onto the leader tail.
            (setq lx (- cx halfO))
            (setvar "CLAYER" "DIMENSIONS")
            (command "_.LINE" (list (+ ox lx) (/ (+ eaveY ridgeY) 2.0))
                              (list (+ ox (- lx (* 1800 *PEB-TEXT-SCALE*))) (/ (+ eaveY ridgeY) 2.0)) "")
            (setvar "CLAYER" "TEXT")
            (txt "MR" (list (+ ox (- lx (* 2100 *PEB-TEXT-SCALE*))) (/ (+ eaveY ridgeY) 2.0))
                 (peb-th 'SMALL) 0 "ROOF MONITOR")
            ;; THE MONITOR END, SHEETED (owner 31-Aug: "on both ends Sheeting will be there for
            ;; roof monitor", "vertical sheets").  On a SHEETING elevation the wall beneath it is
            ;; filled with panel lines, so an outline alone reads as nothing being there at all -
            ;; which is exactly how this was reported.
            ;;
            ;; LEG TO LEG only, the THROAT (owner's choice 31-Aug).  The roof overhangs 750 past
            ;; each leg with an OPEN soffit - that is how a mini gable frame closes - so sheeting
            ;; out to overall/2 would draw a wall where the building has none.
            ;;
            ;; Pitch 333 is the SAME sp the wall sheeting further down this very sheet uses, so the
            ;; monitor matches the wall under it instead of carrying its own private sheeting scale.
            (if isSht
              (progn
                ;; FULL OVERALL WIDTH, extensions included (owner 31-Aug: "On both Ends Sheeting are
                ;; complete including Both Sides Extensions").  Not leg to leg: the monitor end is
                ;; closed right out to the roof edge, so the 750 extension each side is sheeted too.
                ;;
                ;; EVENLY distributed, never a fixed pitch run from one edge.  A fixed 333 from the
                ;; left leg had left the last line 168 from the right one - half a pitch - and the two
                ;; printed as a single thickened line.  n = overall/333 rounded down, spaced
                ;; overall/(n+1): 9 lines at 300 on a 3000 overall, symmetric about the ridge, clear
                ;; of both roof edges, and near enough the wall sheeting's own 333 to match it.
                (setvar "CLAYER" "CLADDING")
                (setq nT (fix (/ overall 333.0)))
                (if (< nT 1) (setq nT 1))
                (setq i 1)
                (while (<= i nT)
                  (setq sxm (+ (- cx halfO) (* overall (/ (float i) (float (1+ nT))))))
                  ;; top = the monitor RAFTER UNDERSIDE at this x, the same line the leg tops were
                  ;; measured landing on exactly (12415.9 on 269); bottom = the main roof, seated
                  ;; with peb-fr-topy like every other thing on this sheet.
                  (setq ytop (- ridgeY (* (abs (- sxm cx)) s)))
                  (command "_.LINE"
                    (list (+ ox sxm)
                          (peb-fr-topy sxm faceLen base eaveH eaveHi eaveLo rise rtype hiSide))
                    (list (+ ox sxm) ytop) "")
                  (setq i (1+ i)))))))
        ;; ---- SIDE WALL: the monitor along its LENGTH, raised over the ridge ----------
        (progn
          (setq apexY  (+ base wallEave rise)        ; the ridge, as THIS sheet draws it
                ridgeY (+ apexY rmh)
                eaveY  (- ridgeY (* halfO (/ 1.0 slopeD)))
                bandH  (- eaveY apexY)
                nSt    (length stations)
                gFrom  (MSPL-Get-Num data "RM_GRID_FROM")
                gTo    (MSPL-Get-Num data "RM_GRID_TO")
                mx0    0.0
                mx1    faceLen)
          ;; Grid numbers map onto stations only on a WHOLE wall.  A match-line PART sheet
          ;; carries a SLICE of the stations with its own local origin, so grid 1 is no
          ;; longer stations[0]; there the monitor spans the full drawn face rather than a
          ;; confidently wrong pair of stations.  A monitor covering every grid is the full
          ;; face anyway, so it takes the same path and needs no station lookup at all.
          (if (and gFrom gTo (> gFrom 0.0) (> gTo gFrom) (<= (fix gTo) nSt)
                   (or (null *PEB-PART-N*) (<= *PEB-PART-N* 1))
                   (not (and (<= gFrom 1.0) (>= (fix gTo) nSt))))
            (setq mx0 (nth (1- (fix gFrom)) stations)
                  mx1 (nth (1- (fix gTo))   stations)))
          (if (> (- mx1 mx0) 1.0)
            (progn
              ;; end edges: up from the main roof to the monitor ridge
              (setvar "CLAYER" "STRUCTURE")
              (command "_.LINE" (list (+ ox mx0) apexY) (list (+ ox mx0) ridgeY) "")
              (command "_.LINE" (list (+ ox mx1) apexY) (list (+ ox mx1) ridgeY) "")
              ;; the near eave of the monitor roof, and its ridge on the far side
              (setvar "CLAYER" "CLADDING")
              (command "_.LINE" (list (+ ox mx0) eaveY) (list (+ ox mx1) eaveY) "")
              (setvar "CLAYER" "RIDGE")
              (command "_.LINE" (list (+ ox mx0) ridgeY) (list (+ ox mx1) ridgeY) "")
              ;; NAME IT (owner 31-Aug: "write the roof monitor name in elevations for clearity").
              ;; The roof plan names it and the section labels it; the elevations were showing an
              ;; unlabelled box sitting on the ridge, which is only obvious to someone who already
              ;; knows the building has a monitor.
              (setvar "CLAYER" "TEXT")
              (txt "MC" (list (+ ox (/ (+ mx0 mx1) 2.0))
                              (+ ridgeY (* 1.15 (peb-th 'SMALL) *PEB-TEXT-SCALE*)))
                   (peb-th 'SMALL) 0 "ROOF MONITOR")
              ;; THE MONITOR'S ROOF SHEETING on its slope (owner 31-Aug: "roof sheeting of slope
              ;; will be shown and opening will be shown below it").  Pitch 1000 = the roof COVER
              ;; width peb-draw-roof-sheeting uses, so these are the SAME runs the roof plan draws.
              ;;
              ;; This band is only (rmh - halfO/slopeD) tall - 150 on a 1500 throat at 1:10 -
              ;; because the monitor follows the MAIN slope (the Section derives it that way).
              ;; That is the true projection, not an error; it is simply thin on paper.
              (if (and isSht (> (- ridgeY eaveY) 1.0))
                (progn
                  (setvar "CLAYER" "CLADDING")
                  (setq sxm (+ mx0 1000.0))
                  (while (< sxm mx1)
                    (command "_.LINE" (list (+ ox sxm) eaveY) (list (+ ox sxm) ridgeY) "")
                    (setq sxm (+ sxm 1000.0)))))
              ;; THE VENT.  This face is the whole reason the monitor exists (owner: "at
              ;; peak, the reason of Fumes"), so the opening is drawn AS an opening: the
              ;; throat band between the main roof and the monitor eave, ticked when a
              ;; bird mesh is specified.  Ticks sit ~2 m apart so they read as a grille at
              ;; 1:378; a true mesh hatch at that scale smears into a solid grey tone.
              (if (> bandH 1.0)
                (progn
                  ;; No line along the bottom of the band: the RIDGE line already runs the full
                  ;; length at exactly this Y on both side sheets, and a second one on OPEN at the
                  ;; same coordinates is a duplicate entity, not a darker line.
                  (setvar "CLAYER" "OPEN")
                  ;; BIRD MESH is CLADDING, so it belongs on the sheeting sheet only (owner 31-Aug:
                  ;; "in Framing Sidewall Elevations Sidelines are Showing (Vertical Lines), these
                  ;; should not be there.  Will show the opening from the side and roof sheeting
                  ;; line on the top").  At 1 m pitch over a 61 m monitor that is 60 ticks, and on
                  ;; the FRAMING elevation - which carries no sheeting of any kind - they read as a
                  ;; comb across the top of the wall rather than as a mesh.
                  ;; The framing sheet keeps what the owner asked for and nothing else: the opening
                  ;; band bounded by the main roof below and the monitor eave above, and the roof
                  ;; line on top.  Same split as the monitor legs, in the other direction.
                  (setq mesh (strcase (peb-tb-or (MSPL-Get-Str data "RM_BIRD_MESH") "")))
                  (if (and isSht (or (= mesh "YES") (= mesh "Y") (= mesh "TRUE")))
                    (progn
                      ;; The SAME stations as the roof sheeting above: mx0 + n*1000, the roof COVER
                      ;; width.  Evenly-distributed 2 m ticks landed between the sheet lines, so the
                      ;; opening and the sheeting over it read as two mismatched grilles stacked on
                      ;; each other instead of as one monitor divided on one module.
                      (setq px (+ mx0 1000.0))
                      (while (< px mx1)
                        (command "_.LINE" (list (+ ox px) apexY) (list (+ ox px) eaveY) "")
                        (setq px (+ px 1000.0)))
                      ;; ...AND A HORIZONTAL, so the mesh reads as BOXES (owner 31-Aug: "normally
                      ;; it is galvanised wire mesh ... with Boxes ... so that Bird may not enter in
                      ;; the building").  It is WRM in the QE - "Galvanized Wire Mesh (1.219m x
                      ;; 30.4m Rolls)", billed by m2 - a SQUARE mesh, and verticals alone drew it as
                      ;; slats or a louvre, which is a different product that a bird walks through.
                      ;; ONE horizontal, not a fine hatch: the opening band is 600 tall, which is
                      ;; 1.6 mm at 1:375.  A true mesh pitch there is far below the plotted
                      ;; lineweight and fills solid grey; a 2-row grid of 1000 x 300 boxes is the
                      ;; coarsest thing that still reads unmistakably as mesh rather than as slats.
                      (command "_.LINE" (list (+ ox mx0) (/ (+ apexY eaveY) 2.0))
                                        (list (+ ox mx1) (/ (+ apexY eaveY) 2.0)) "")))))))))
      (setvar "CLAYER" prev)))
  (princ))


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
        aL   (* 240 ts)      ; 240/85 - the set's one OPEN arrowhead, see peb-fr-dimarrow
        aW   (* 85 ts)
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
        aL   (* 240 ts)      ; 240/85 - the set's one OPEN arrowhead, see peb-fr-dimarrow
        aW   (* 85 ts)
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
            ;; 240/85, the size every other OPEN head in the set uses (Section's rm-arrow-*,
            ;; MezzDetail's mzd-open-v via the DIM rung).  These were 300/95 - a fourth arrow
            ;; length in a set that is supposed to have one (owner: "sync ... the dimensions").
            aL (* 240 ts)                    ; open-arrow length along the dim line
            aW (* 85 ts)                     ; half-width -> slim open "V" like DIMBLK _OPEN
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


;; ============================================================================
;;  CANOPIES ON A WALL ELEVATION  (rule 4B.44, owner 29-Aug: "Also pls draw the canopies")
;;
;;  The canopies reached the Column Layout Plan and stopped there - Framing.lsp, Elevation.lsp
;;  and Section.lsp had no canopy handling at all.  On MSPL-26-271 that means two 62'-1"
;;  entrance canopies over the customer's front door are absent from the very sheet a customer
;;  looks at to see the front of their building.
;;
;;  In elevation a canopy is its FASCIA: a band at the canopy level running the canopy's length,
;;  with its soffit line under it.  The projection is toward the viewer and cannot be drawn, so
;;  it is stated in the label - that is what "PROJ." means.
;;
;;  THE VIEW IS FROM OUTSIDE, so `stations` has already been mirrored for FSW/LEW before this is
;;  called (see the mirror note above).  A plan grid g therefore sits at position n-g in the
;;  mirrored list, and an offset measured from the start grid runs the other way.  Getting this
;;  wrong puts a canopy over the wrong door on exactly the two walls that carry them.
;; ============================================================================

;; ============================================================================
;;  DOORS ON A WALL ELEVATION  (rule 4B.47, owner 29-Aug)
;;  "Show the Sutter Doors b/w the Columns", "Auto-Shutter Door",
;;  "one shutter per bay, 7m x 3.5m, both entrance and exit".
;;
;;  Doors reached the PROPOSAL and the ESTIMATE but never the drawing - there was not one door
;;  key in drawingData.ts.  A building could be quoted with four auto shutters across its front
;;  and drawn with a blank wall, and nothing in the set would show the disagreement.
;;
;;  ONE DOOR PER BAY, centred between its two columns, because a shutter spans column to column:
;;  a three-bay doorway is three shutters, not one 23 m door.  The CRM expands the grid range to
;;  one indexed instance per bay (DR_<W>_<n>_GRID_FROM/TO), so the engine never has to guess how
;;  many leaves a range means.
;;
;;  The width is CLAMPED to the clear bay.  An entered 7,000 in a 7,734 bay is a real door; the
;;  same 7,000 typed against a 6 m bay is a typo, and drawing it would put a door through the
;;  columns either side.  Clamping shows the mistake at its true size instead of hiding it.
;;
;;  THE VIEW IS FROM OUTSIDE, so `stations` is already mirrored for FSW/LEW: plan grid g sits at
;;  position n-g.  Getting that wrong puts the entrance door at the far end of the building.
;; ============================================================================
;; DISCONTINUOUS RUN — `perBay` panels centred in each bay, plain sheeting between the groups.
;; The two end sheets are kept clear the same way: a bay is skipped when its group would fall
;; inside them. Returns how many panels were drawn, so the leader reports what is on the wall.
(defun peb-fr-wl-per-bay (data surf ox base faceLen stations sill panL cover perBay endSheets
                          / nSt i x0 x1 grpW gx k drawn clearL clearR)
  (setq nSt (length stations) drawn 0 i 0
        grpW   (* perBay cover)
        clearL (* endSheets cover)
        clearR (- faceLen (* endSheets cover)))
  (while (< (1+ i) nSt)
    (setq x0 (nth i stations) x1 (nth (1+ i) stations))
    ;; centre the group in the bay
    (setq gx (- (/ (+ x0 x1) 2.0) (/ grpW 2.0)))
    (if (and (>= gx clearL) (<= (+ gx grpW) clearR) (< grpW (abs (- x1 x0))))
      (progn
        (setq k 0)
        (while (< k perBay)
          (peb-acc-light-elev (+ ox gx (* k cover)) (+ base sill) cover panL surf)
          (setq drawn (1+ drawn) k (1+ k)))))
    (setq i (1+ i)))
  drawn)

;; ── WALL LIGHTS ON THE WALL SHEETING ELEVATION ─────────────────────────────────────────
;; STANDING RULE (owner 3-Sep-2026): "wall lights will come on the Walls Sheeting Plan". It is a
;; CLADDING item - it replaces a sheet on the sheet module - so it is drawn where the sheeting is
;; drawn, not on the framing elevation.
;;
;; Everything comes from the BSF and nothing is re-derived here (golden rule 24):
;;   WA_LIGHT_ON     the Include tick - the gate, same as every other accessory
;;   WA_LIGHT_WALLS  which walls carry the band
;;   WA_LIGHT_SILL   already computed as clear height - panel length, so the head lands on the
;;                   clear-height line; the drawing just reads it
;;   WA_LIGHT_L/_W   the panel, _W being the sheet cover
;;
;; The panel is drawn by the COMPONENT LIBRARY - the same drawer the roof plan and the sample
;; use (rule 1). No panel geometry lives in this file.
(defun peb-fr-wall-lights (data surf ox base faceLen stations
                           / on walls sill panL cover n i px lay qty ts czone usable x0
                             lenMm widMm eaveMm endSheets cont perBay)
  (setq on    (strcase (peb-tb-or (MSPL-Get-Str data "WA_LIGHT_ON") "No"))
        walls (strcase (peb-tb-or (MSPL-Get-Str data "WA_LIGHT_WALLS") ""))
        sill  (MSPL-Get-Num data "WA_LIGHT_SILL")
        panL  (MSPL-Get-Num data "WA_LIGHT_L")
        cover (MSPL-Get-Num data "WA_LIGHT_W")
        cont  (peb-tb-or (MSPL-Get-Str data "WA_LIGHT_CONTINUITY") "Continuous")
        perBay (max 1 (MSPL-Get-Int data "WA_LIGHT_PER_BAY"))
        qty   (MSPL-Get-Int data "WA_LIGHT_QTY")
        ts    (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        lenMm (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        widMm (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        eaveMm (+ (peb-clear-height data) (peb-eave-add data)))
  (if (or (null cover) (<= cover 0.0)) (setq cover 1000.0))
  (if (and (= on "YES") (boundp 'peb-acc-light-elev)
           sill panL (> panL 0.0) (>= sill 0.0) (> faceLen cover)
           (or (wcmatch walls "*ALL*4*") (wcmatch walls (strcat "*" surf "*"))
               (and (wcmatch walls "*BOTH*SIDEWALL*") (member surf '("NSW" "FSW")))))
    (progn
      (setq lay (getvar "CLAYER"))
      ;; ── TWO PLAIN SHEETS AT EACH END, THEN THE LIGHTS IN THE MIDDLE ─────────────────────
      ;; "we always must have sheeting on both side 2 sheets same sheeting and then apply in the
      ;; middle" - and "on side walls if have 48 meter then after deduction of 2 wall lights on
      ;; both sides, balance should left 44 No's" (owner 4-Sep-2026).
      ;;
      ;; TWO. FLAT. This briefly read `max(2, ceil(cornerZone / cover))`, which rounded the clear
      ;; end up to 3 sheets on this building and left 42 where 44 was expected. The wind vortices
      ;; at the corner are the REASON the two sheets are there; they are not a second calculation
      ;; to layer on top of the number. And two is the visual limit as well - "if we will leave
      ;; more panels on sides, then it do not look good": stop three or four sheets short and the
      ;; wall reads as two blank ends with a strip in the middle.
      (setq endSheets 2)
      (setq usable (- faceLen (* 2.0 endSheets cover)))
      (setq n (if (> usable cover) (fix (/ usable cover)) 0))
      (setq x0 (+ ox (* endSheets cover)) i 0)
      ;; CONTINUOUS fills that middle run; DISCONTINUOUS puts `perBay` panels in each bay and
      ;; leaves plain sheeting between the groups (owner: the No. per Bay dropdown).
      (if (and (wcmatch (strcase cont) "*DISCONT*") stations (> (length stations) 1))
        (setq n (peb-fr-wl-per-bay data surf ox base faceLen stations sill panL cover perBay endSheets))
        (while (< i n)
          (setq px (+ x0 (* i cover)))
          (peb-acc-light-elev px (+ base sill) cover panL surf)
          (setq i (1+ i))))
      ;; ── A GIRT ON BOTH SIDES OF THE BAND (owner 4-Sep-2026) ─────────────────────────────
      ;; "Fiberglass Wall Lights ... needs the Girts on Both Sides." A fiberglass panel is the
      ;; weakest sheet on the wall and it is not self-supporting across its length: it has to be
      ;; fixed along BOTH edges, so a girt runs at the SILL and another at the HEAD of the band.
      ;; Without them the panel is held only by the sheets it laps, which is what fails first
      ;; under the suction the corner rule is also guarding against.
      ;; Drawn the full length of the wall, because that is how a girt runs - it does not start
      ;; and stop with the band.
      (if (> n 0)
        (progn
          (peb-comp-layer "GIRTS" 6)
          (peb-acc-line ox (+ base sill)      (+ ox faceLen) (+ base sill)      "GIRTS" 13)
          (peb-acc-line ox (+ base sill panL) (+ ox faceLen) (+ base sill panL) "GIRTS" 13)))
      ;; ONE leader per ELEVATION, carrying THIS WALL'S OWN COUNT (owner 4-Sep-2026: "Give
      ;; separate no. on each elevation ... if on the endwall 10 No's skylights are coming, then
      ;; we may write 10 No's").
      ;;
      ;; It used to print WA_LIGHT_QTY - the BSF's TOTAL for the whole building - on every wall,
      ;; so a 93-panel job read "93 No." on the NSW and "93 No." again on the FSW: 186 to anyone
      ;; reading the sheet. An elevation must describe what that elevation shows. The building
      ;; total belongs to the accessory schedule and the estimate, not to four separate leaders.
      ;; `n` is the whole panels actually drawn on THIS wall, so the label and the drawing agree
      ;; by construction.
      (if (boundp 'peb-label-with-leader)
        (vl-catch-all-apply
          (function (lambda ()
            (peb-label-with-leader
              (strcat (itoa n) " No. FIBERGLASS WALL LIGHT - TYPE")
              (list (+ ox faceLen (* 2000.0 ts)) (+ base sill panL))
              (list (+ x0 (* 1.5 cover)) (+ base sill (/ panL 2.0)))
              "V" (peb-th 'ANNOT))))))
      (setvar "CLAYER" lay)))
  (princ))

(defun peb-fr-doors (data surf ox base faceLen stations revView
                     / nSt dk qty gf gt dw dh dtyp dop x0 x1 cx bayClear di dsy lab prev
                       sldOK)
  (setq qty (MSPL-Get-Int data (strcat "DR_" surf "_N")))
  (if (or (null stations) (< (length stations) 2) (null qty) (< qty 1))
    (princ)
    (progn
      (setq prev (getvar "CLAYER") nSt (length stations))
      (if (> qty 40) (setq qty 40))
      (setq dk 1)
      (while (<= dk qty)
        (setq gf   (MSPL-Get-Int data (strcat "DR_" surf "_" (itoa dk) "_GRID_FROM"))
              gt   (MSPL-Get-Int data (strcat "DR_" surf "_" (itoa dk) "_GRID_TO"))
              dw   (MSPL-Get-Num data (strcat "DR_" surf "_" (itoa dk) "_W"))
              dh   (MSPL-Get-Num data (strcat "DR_" surf "_" (itoa dk) "_H"))
              dtyp (strcase (peb-tb-or (MSPL-Get-Str data (strcat "DR_" surf "_" (itoa dk) "_TYPE")) "DOOR"))
              dop  (MSPL-Get-Str data (strcat "DR_" surf "_" (itoa dk) "_OPERATION")))
        (if (and gf gt (> gf 0) (> gt gf) (<= gt nSt) dw dh (> dw 0.0) (> dh 0.0))
          (progn
            (if revView
              (setq x0 (nth (- nSt gt) stations) x1 (nth (- nSt gf) stations))
              (setq x0 (nth (1- gf) stations)    x1 (nth (1- gt) stations)))
            (setq bayClear (abs (- x1 x0)) cx (/ (+ x0 x1) 2.0))
            ;; leave a column's face either side rather than butting the door into the steel
            (if (> dw (* bayClear 0.92)) (setq dw (* bayClear 0.92)))
            (if (> (- dw 100.0) 0.0)
              (progn
                (peb-comp-layer "COMP-DOOR" 4)
                (setvar "CLAYER" "COMP-DOOR")
                ;; ── A SLIDING DOOR IS DRAWN BY ITS OWN COMPONENT ──────────────────────────
                ;; Every accessory on this elevation used to be the RECTANG below, so a louver,
                ;; a light panel and a sliding door plotted identically. Library/Sliding Doors
                ;; draws the real thing: leaf, cover trims, panel field at the cladding's own
                ;; pitch, top track and hood, floor rail on its stubs, wheels, and the pilot
                ;; door when the BSF says there is one.
                ;;   NO PARKED GHOST on a building elevation - it would run into the next bay.
                ;;   The label below is left to this file, so every door on the sheet is named
                ;;   the same way whatever drew it.
                ;; TRY the component, and fall back to the rectangle if it is not loaded or
                ;; it throws. A type test would have answered only the first of those, and when
                ;; it answered wrongly the sheet fell through to a plain rectangle with nothing
                ;; anywhere to say so - the silent-failure class this engine keeps meeting.
                (setq sldOK nil)
                (if (wcmatch dtyp "*SLID*")
                  (setq sldOK
                    (not (vl-catch-all-error-p
                      (vl-catch-all-apply 'peb-sld-elevation
                        (list (+ ox cx (/ dw -2.0)) base dw dh
                              (peb-sld-leaves-of dop)
                              -1
                              (peb-sld-ptype-of
                                (MSPL-Get-Str data
                                  (strcat "DR_" surf "_" (itoa dk) "_CLADDING")))
                              (peb-sld-wicket-of
                                (MSPL-Get-Str data
                                  (strcat "DR_" surf "_" (itoa dk) "_PILOT")))
                              nil nil))))))
                (if (not sldOK)
                  (command "_.RECTANG" (list (+ ox cx (/ dw -2.0)) base)
                                       (list (+ ox cx (/ dw  2.0)) (+ base dh))))
                ;; a roll-up reads by its slats; a swing door does not have them, and a
                ;; sliding door has already drawn its own face
                (if (wcmatch dtyp "*ROLL*")
                  (progn
                    (setq di 1)
                    (while (< di 6)
                      (setq dsy (+ base (* dh (/ di 6.0))))
                      (command "_.LINE" (list (+ ox cx (/ dw -2.0)) dsy)
                                        (list (+ ox cx (/ dw  2.0)) dsy) "")
                      (setq di (1+ di)))))
                (setvar "CLAYER" "TEXT")
                ;; -- THE LABEL GOES INSIDE THE DOOR ------------------------------------------
                ;; Above the door it had nowhere to go: the canopy fascia label sits ~1,200 above
                ;; the 3,658 soffit and the door label ~1,600 above its own 3,500 head, so the two
                ;; landed within 255 mm of each other - and two doors in adjacent bays ran their
                ;; labels together as well.  A 7,000 x 3,500 leaf has room for its own name, and a
                ;; label inside the thing it names cannot collide with anything outside it.
                ;; Two lines - what it is, then how big - each shrunk to fit the leaf (rule 4B.27).
                (setq lab (if (wcmatch dtyp "*ROLL*")
                            (if (and dop (wcmatch (strcase dop) "*ELECTRIC*"))
                              "AUTO SHUTTER DOOR" "ROLL-UP SHUTTER DOOR")
                            dtyp))
                ;; WHERE THE LABEL GOES depends on whether the door has a FACE.
                ;; An empty rectangle has room inside it and that is where the label belongs -
                ;; above the door it collided with the canopy fascia callout. A SLIDING door is
                ;; no longer empty: it has a leaf, a panel face, cover trims and a meeting stile,
                ;; and the two lines landed unreadably across all of them. So a drawn door hangs
                ;; its label BELOW the floor rail, clear of everything it names.
                (setq dsy (if sldOK (- base 900.0) (+ base (* dh 0.60))))
                (vl-catch-all-apply (function (lambda ()
                  (txt "MC" (list (+ ox cx) dsy)
                       (peb-fit-txt-h lab (* dw 0.80) (peb-th 'SMALL)) 0 lab))))
                (setq lab (strcat (peb-comma (rtos dw 2 0)) " x " (peb-comma (rtos dh 2 0))))
                (setq dsy (if sldOK (- base 1500.0) (+ base (* dh 0.40))))
                (vl-catch-all-apply (function (lambda ()
                  (txt "MC" (list (+ ox cx) dsy)
                       (peb-fit-txt-h lab (* dw 0.55) (peb-th 'SMALL)) 0 lab))))))))
        (setq dk (1+ dk)))
      (setvar "CLAYER" prev)
      (princ))))

(defun peb-fr-canopy (data surf ox base faceLen stations revView wallEave
                      / nSt k qty gf gt off cnLen proj hC x0 x1 pa pb fd prev lab)
  (if (or (null stations) (< (length stations) 2)
          (/= (strcase (peb-tb-or (MSPL-Get-Str data "CN_TOGGLE") "")) "YES")
          (/= (strcase (peb-tb-or (MSPL-Get-Str data (strcat "CN_" surf "_TOGGLE")) "")) "YES"))
    (princ)
    (progn
      (setq prev (getvar "CLAYER") nSt (length stations))
      (setq qty (MSPL-Get-Num data (strcat "CN_" surf "_N")))
      (setq qty (if (and qty (>= qty 1)) (fix qty) 1))
      (if (> qty 12) (setq qty 12))
      (setq k 1)
      (while (<= k qty)
        (setq gf     (MSPL-Get-Int data (strcat "CN_" surf "_" (itoa k) "_GRID_FROM"))
              gt     (MSPL-Get-Int data (strcat "CN_" surf "_" (itoa k) "_GRID_TO"))
              off    (MSPL-Get-Num data (strcat "CN_" surf "_" (itoa k) "_OFF"))
              cnLen  (MSPL-Get-Num data (strcat "CN_" surf "_" (itoa k) "_LEN"))
              proj   (MSPL-Get-Num data (strcat "CN_" surf "_" (itoa k) "_WIDTH")))
        (if (null off) (setq off 0.0))
        ;; grid anchors -> along-wall positions IN THIS VIEW's direction
        (if (and gf gt (> gf 0) (> gt 0) (<= gf nSt) (<= gt nSt))
          (progn
            (if revView
              (setq pa (nth (- nSt gt) stations) pb (nth (- nSt gf) stations))
              (setq pa (nth (1- gf) stations)    pb (nth (1- gt) stations)))
            ;; honour the entered LENGTH from the anchor (rule 4B.33) rather than stretching
            ;; the canopy across the whole grid range it happens to sit in.
            (if (and cnLen (> cnLen 0.0) (< cnLen (- pb pa)))
              (if revView
                (setq x1 (- pb off) x0 (- x1 cnLen))
                (setq x0 (+ pa off) x1 (+ x0 cnLen)))
              (setq x0 pa x1 pb))
            (setq x0 (max 0.0 (min x0 faceLen)) x1 (max 0.0 (min x1 faceLen)))
            (if (> (- x1 x0) 100.0)
              (progn
                ;; level: the entered eave height if given, else hung off this wall's own eave
                (setq hC (MSPL-Get-Num data (strcat "CN_" surf "_" (itoa k) "_EAVE_HT")))
                (if (or (null hC) (<= hC 0.0)) (setq hC wallEave))
                ;; Fascia depth. 3% of the eave plotted at ~0.6 mm on the A4 - drawn, and
                ;; indistinguishable from the wall's own top line. A canopy fascia with its
                ;; gutter is genuinely ~600 deep, so 5.5% both reads and is true.
                (setq fd (max 300.0 (* wallEave 0.055)))
                (peb-comp-layer "COMP-CANOPY" 6)
                (setvar "CLAYER" "COMP-CANOPY")
                (command "_.RECTANG" (list (+ ox x0) (- (+ base hC) fd)) (list (+ ox x1) (+ base hC)))
                (command "_.LINE" (list (+ ox x0) (- (+ base hC) fd (* fd 0.55)))
                                  (list (+ ox x1) (- (+ base hC) fd (* fd 0.55))) "")
                (setvar "CLAYER" "TEXT")
                (setq lab (strcat "CANOPY" (if (and proj (> proj 0.0))
                                             (strcat "  -  " (peb-comma (rtos proj 2 0)) " PROJ.") "")))
                (vl-catch-all-apply (function (lambda ()
                  (txt "MC" (list (+ ox (/ (+ x0 x1) 2.0)) (+ base hC (* fd 1.9)))
                       (peb-th 'SMALL) 0 lab))))))))
        (setq k (1+ k)))
      (setvar "CLAYER" prev)
      (princ))))

(defun peb-draw-framing-elev (surf ox oy data / len wid slopeD stype rtype
                              eaveH clrH eaveHi eaveLo brickH hiName hiSide wallEave
                              faceLen stations isEnd base colhw rise ridgeRise
                              i x g yTop pts cx prev braced b x0 x1 y0 y1 lbl bubGap bubR revView hdTxt gMarks
                              prng pi0 pi1 px0 pOfs pnTot
                              gsp gy cnt pre psurf pat pw ptyp psill ph mark expr ov noteY
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
  (setq clrH (peb-clear-height data))
  ;; Rule 4B.7 — the entered number is the CLEAR height (peb-clear-height backs out an
  ;; eave-basis figure). The DRAWN eave is that plus the haunch and the purlin, which is
  ;; exactly what the title block on this very sheet prints. Holding both in one variable
  ;; is what drew the wall 1,300 mm short and then dimensioned it as the full height.
  (setq eaveH (+ clrH (peb-eave-add data)))
  ;; ── FEED RULE G1 (owner 4-Sep-2026) ────────────────────────────────────────────────────
  ;; The girt levels are anchored on the clear height and on the light band's sill and head, so
  ;; peb-fr-wallface needs all three. They travel as specials because AutoLISP is dynamically
  ;; scoped and wallface is called from five places mid-way through a wall of locals - threading
  ;; three more parameters through every call site would be a bigger change than the rule.
  ;; The band levels are what the BSF already settled (WA_LIGHT_SILL / _HEAD); nothing is
  ;; re-derived here (golden rule 24).
  ;; NO `let` HERE - AutoLISP has no such function. Using it threw "no function definition: LET",
  ;; which killed the drawer and produced a BLANK sheeting elevation with a title block and
  ;; nothing else. Plain setq, and a nil when the value is absent or zero.
  (setq *PEB-WF-CLEAR* clrH)
  (setq *PEB-WF-SILL* (MSPL-Get-Num data "WA_LIGHT_SILL"))
  (if (or (null *PEB-WF-SILL*) (<= *PEB-WF-SILL* 0.0)) (setq *PEB-WF-SILL* nil))
  (setq *PEB-WF-HEAD* (MSPL-Get-Num data "WA_LIGHT_HEAD"))
  (if (or (null *PEB-WF-HEAD*) (<= *PEB-WF-HEAD* 0.0)) (setq *PEB-WF-HEAD* nil))

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
  ;; The marks for this merged width grid, in plan order - see peb-fr-grid-label.  Only an END
  ;; wall letters the width; a side wall numbers the bays and never asks for these.
  (setq gMarks nil)
  (if isEnd
    (progn
      (setq gMarks (vl-catch-all-apply
                     (function (lambda ()
                       (peb-width-marks stations (peb-width-mods data wid))))))
      (if (vl-catch-all-error-p gMarks) (setq gMarks nil))))
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
      ;; A CLEAN RAFTER at the knees and the peak (owner 31-Aug, marked up on PRO-04: "Fix these
      ;; Lines & Show the Clean Rafter").  Three things used to be drawn here and all three are gone:
      ;;
      ;;   FLANGE BRACES - one bare diagonal per knee, from the eave corner 14% along the rafter and
      ;;     1000 straight down, ENDING IN MID-AIR.  A brace that terminates on nothing does not read
      ;;     as a brace; it reads as a stray line someone forgot to trim.
      ;;   HAUNCH - a second bare diagonal per knee, from the column inner face up to a point 2600
      ;;     along the rafter, also unterminated.  It crossed the flange brace, so each knee carried
      ;;     an X of two lines that met nothing.  It was also REDUNDANT: the end-wall rafter is
      ;;     already drawn as a TAPERED double-line member (see ewMain / d0 above), which is the
      ;;     haunch.  The line was drawing a second time, badly, what the member already shows.
      ;;   RIDGE TICK - a dashed vertical at the peak running the full rise (1524 on 269) from eave
      ;;     level up to the apex, so it hung down through the rafter into the frame.  The apex of a
      ;;     gable needs no marker, and the roof monitor now stands on it.
      ;;
      ;; These are approval/shop-drawing details.  This sheet says "FRAMING SHOWN IS INDICATIVE ONLY"
      ;; in its own notes, and at 1:234 the three of them cost the rafter its readability and bought
      ;; no information.  If a brace or haunch is ever wanted back it must be drawn as a CLOSED shape
      ;; that lands on the members at both ends - never as a single line stopping in space.
      )
    (progn
      ;; SIDE wall: horizontal eave strut (this wall's eave) + dashed ridge above (gable)
      (setvar "CLAYER" "STRUCTURE")
      (command "_.LINE" (list ox (+ base wallEave)) (list (+ ox faceLen) (+ base wallEave)) "")
      (if (= rtype "G")
        (progn (setvar "CLAYER" "RIDGE")
          (command "_.LINE" (list ox (+ base wallEave rise))
                            (list (+ ox faceLen) (+ base wallEave rise)) "")
          ;; CLOSE THE ROOF BAND.  Viewed square-on to a long wall, the near roof slope projects as a
          ;; RECTANGLE from eave level to ridge level over the full length, and the gable rake at each
          ;; end projects as a VERTICAL line - the rake runs away from the viewer, so it foreshortens
          ;; to a point in plan-x.  Both sheets drew the eave and (here) the ridge and left the band
          ;; open at its ends, so the ridge read as a line floating over the wall rather than as the
          ;; top of a roof.  A roof monitor seated at its TRUE height then had nothing under it at all
          ;; (owner 31-Aug).  These two edges are the roof; the monitor stands on them.
          (setvar "CLAYER" "STRUCTURE")
          (command "_.LINE" (list ox (+ base wallEave)) (list ox (+ base wallEave rise)) "")
          (command "_.LINE" (list (+ ox faceLen) (+ base wallEave))
                            (list (+ ox faceLen) (+ base wallEave rise)) "")))))


  ;; ROOF MONITOR (owner 31-Aug: "Elevations Do not Show the Roof Monitor Lines").  Drawn
  ;; AFTER the roof profile so it sits on top of the line it straddles, and wrapped the way
  ;; every other optional piece on this sheet is: a monitor that cannot be drawn must not be
  ;; able to unwind the whole elevation, which is exactly how the end wall was lost once
  ;; before (see the rdep note above).
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-monitor data ox base faceLen eaveH eaveHi eaveLo rise rtype hiSide isEnd
                    wallEave slopeD stations "F"))))

  ;; 4. girts + sheeting-base + brick/RCC hatch + condition label — drawn PER WALL-FACE SEGMENT (owner 29-Jul)
  ;; so a RAISED band (on the existing floor) starts its brick/sheeting from +rbBase, not FFL. See
  ;; peb-fr-wallface. gy = the ABSOLUTE eave top for the girts (roof is continuous; side walls use wallEave,
  ;; end walls the low eave eaveH). gbase = sheeting-base height (hanging end wall = hangHt; else OW_<surf>).
  (setq owText (peb-tb-or (MSPL-Get-Str data (strcat "OW_" surf)) "")
        gbase  (if (and ewHang (> hangHt 0.0)) hangHt (peb-fr-openwall-ht owText))
        gbaseR (peb-fr-seg-openwall-ht owText)                 ; raised-band brick height (compound OW segment)
        gy     (if isEnd (+ base eaveH) (+ base wallEave)))
  (setq gbase  (peb-fr-brick-clamp gbase  surf data)           ; see peb-fr-brick-clamp
        gbaseR (peb-fr-brick-clamp gbaseR surf data))
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
          ptyp  (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "TYPE")) ""))
          mark  (peb-tb-or (MSPL-Get-Str data (strcat pre "MARK")) ""))
    (if (and (= psurf surf) (> pw 0.0))
      (progn
        ;; AT ITS OWN SILL AND HEIGHT, not a fraction of the eave — see peb-fr-open-sill.
        (setq psill (peb-fr-open-sill data pre ptyp)
              ph    (peb-fr-open-ht   data pre ptyp))
        (peb-fr-draw-opening data pre ptyp
                             (+ ox pat (- (/ pw 2.0))) (+ ox pat (/ pw 2.0))
                             (+ base psill) (+ base psill ph))
        ;; the mark goes just ABOVE the opening it names. It used to sit at 0.80 x eave,
        ;; which for a louver in the brickwork was two metres clear of the thing it labels.
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (+ ox pat) (+ base psill ph (* 420 *PEB-TEXT-SCALE*)))
             (* 230 *PEB-TEXT-SCALE*) 0 mark)))
    (setq i (1+ i)))

  ;; 6b. THE MEZZANINE BEAM, ON THE END WALL  (owner 3-Sep-2026) --------------------------
  ;; "Once we draw the End Wall Framing plan, Mezzanine Beam should also be visible b/w the post
  ;;  columns where Joist will connect."
  ;;
  ;; The end wall IS a bay line, so a mezzanine main beam sits in it - and this elevation drew
  ;; nothing of the mezzanine at all.  A reader looking for where the floor meets the end frame
  ;; found bare girts, and the one sheet that could show the joist-to-beam connection did not.
  ;;
  ;; The main beams run ACROSS THE WIDTH, so on an end wall they are seen in ELEVATION - a band
  ;; spanning between the posts.  The joists run along the LENGTH, so they are seen END-ON,
  ;; spaced across the width at the joist spacing, their tops FLUSH under the beam top (4B.32).
  ;;
  ;; Every level and depth comes from the SAME derivation the mezzanine details sheet uses
  ;; (peb-mz-* / the MZ1_CH_* levels), so the two sheets cannot state different steel.
  (if (and isEnd (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_TOGGLE") "")) "YES"))
    (vl-catch-all-apply (function (lambda ( / mzChb mzThk mzBd mzFfl mzTopH mzJsp mzJd mzG
                                             mzBand mzB0 mzB1 mzX0 mzX1 mzTop mzBot jx jn)
      (setq mzChb (atof (peb-tb-or (MSPL-Get-Str data "MZ1_CH_FFL_BEAM") "0"))
            mzThk (atof (peb-tb-or (MSPL-Get-Str data "MZ1_FLOOR_THK") "0"))
            mzFfl (atof (peb-tb-or (MSPL-Get-Str data "MZ1_CH_FFL_SLAB") "0"))
            mzJsp (atof (peb-tb-or (MSPL-Get-Str data "MZ_JOIST") "0")))
      (if (< mzThk 40.0)  (setq mzThk 150.0))
      (if (< mzJsp 300.0) (setq mzJsp 1250.0))
      (if (<= mzChb 0.0)  (setq mzChb 3000.0))
      (setq mzTopH (+ 45.0 mzThk))                     ; deck rib + slab, as the detail sheet builds it
      (setq mzBd 700.0)                                ; the detail sheet's default...
      (if (and (> mzFfl 0.0) (> (- mzFfl mzChb mzTopH) 150.0)
                             (< (- mzFfl mzChb mzTopH) 2500.0))
        (setq mzBd (- mzFfl mzChb mzTopH)))            ; ...or what two STATED levels imply
      (setq mzJd (max 250.0 (* mzBd 0.55)))            ; *MZD-JOIST-RATIO*
      ;; ...and if the mezzanine-DETAILS module happens to be loaded on this sheet, ask IT
      ;; instead.  The arithmetic above is a faithful copy of mzd-geom, but a copy is a second
      ;; chance to disagree about the same floor, and 4B.7 is that the beam depth is whatever
      ;; the two stated levels imply - stated once.  Where both are present, one of them wins.
      (if (and (boundp 'mzd-geom) (boundp 'mzd-g))
        (setq mzG    (mzd-geom data)
              mzBd   (mzd-g mzG "BD")    mzJd  (mzd-g mzG "JD")
              mzTopH (mzd-g mzG "TOPH")  mzChb (mzd-g mzG "CHB")
              mzJsp  (mzd-g mzG "JSP")))
      ;; the deck's own width extent, the same band the mezzanine floor plan draws
      (setq mzBand (if (boundp 'peb-mz-width-band) (peb-mz-width-band data wid 0.0) (list 0.0 wid))
            mzB0   (car mzBand) mzB1 (cadr mzBand))
      ;; ...mapped into this elevation, which is viewed from OUTSIDE (see the mirror note above)
      (setq mzX0 (+ ox (if revView (- faceLen mzB1) mzB0))
            mzX1 (+ ox (if revView (- faceLen mzB0) mzB1)))
      (setq mzBot (+ base mzChb) mzTop (+ base mzChb mzBd))
      (if (> (- mzX1 mzX0) 1.0)
        (progn
          ;; THE JOISTS FIRST, so the heavier beam reads on top of them where they meet.
          (peb-comp-layer "COMP-MEZZ-JOIST" 3)
          (setq jn 1 jx (+ mzX0 mzJsp))
          (while (< jx (- mzX1 1.0))
            (entmake (list (cons 0 "LINE") (cons 8 "COMP-MEZZ-JOIST")
                           (list 10 jx (- mzTop mzJd) 0.0) (list 11 jx mzTop 0.0)))
            (setq jx (+ jx mzJsp) jn (1+ jn)))
          ;; THE BEAM: a band between the posts, top and bottom flange.
          (peb-comp-layer "COMP-MEZZ-BEAM" 5)
          (foreach yy (list mzTop mzBot)
            (entmake (list (cons 0 "LINE") (cons 8 "COMP-MEZZ-BEAM")
                           (list 10 mzX0 yy 0.0) (list 11 mzX1 yy 0.0))))
          (foreach xx (list mzX0 mzX1)
            (entmake (list (cons 0 "LINE") (cons 8 "COMP-MEZZ-BEAM")
                           (list 10 xx mzBot 0.0) (list 11 xx mzTop 0.0))))
          ;; and the deck it carries, so the level reads as a FLOOR and not a lone beam
          (peb-comp-layer "COMP-MEZZ-JOIST" 3)
          (entmake (list (cons 0 "LINE") (cons 8 "COMP-MEZZ-JOIST")
                         (list 10 mzX0 (+ mzTop mzTopH) 0.0) (list 11 mzX1 (+ mzTop mzTopH) 0.0)))
          ;; ONE label - and it LEAVES the drawing, in this sheet's own leader idiom.
          ;;
          ;; The first cut laid the string along the deck line: 54 characters running through six
          ;; columns, every girt, and the beam it was naming, with the deck line struck clean
          ;; through the middle of the lettering.  There is no gap inside a framing elevation big
          ;; enough for a sentence (4B.27) - the sheet answers that by taking the words OUT, on a
          ;; leader, to the annotation row above the roof.  This is the same peb-label-with-leader
          ;; call the GIRT TYPE mark makes, on the same row, at the opposite end so the two labels
          ;; cannot meet; and the leader's vertical leg is set BETWEEN two posts, not on one.
          ;;
          ;; The row is shared, so the two labels are placed by where their text ENDS, not where
          ;; it starts: at 0.32 this one ran to 0.81 and printed straight into "GIRT TYPE" at 0.78
          ;; ("...WITH BEGMRTTOPPE : 200Z15").  Held at 0.13 it finishes near 0.62 - a clear bay
          ;; and a half short of the girt mark, on both the mirrored REW and the LEW.
          (vl-catch-all-apply (function (lambda ()
            (peb-label-with-leader
              "MEZZANINE BEAM - JOISTS FLUSH WITH BEAM TOP"
              (list (+ ox (* faceLen 0.13)) (+ base eaveH rise (* 900.0 *PEB-DIM-SCALE*)))
              (list (+ ox (* faceLen 0.08)) mzTop)
              "S" 600.0))))))
      (princ)))))

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
                pnTot isEnd gMarks))
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
    (peb-fr-overall-v (- ox (* 1500 *PEB-DIM-SCALE*)) base (+ base clrH)
                      ;; SAY WHICH HEIGHT IT IS (owner 31-Aug: "in plan we write the word Clear
                      ;; Height, here also we have to mention this in elevation ... what i want
                      ;; the sync in all the drawings of the building").  The elevations printed a
                      ;; bare number while the plan tagged its areas CLEAR HT./EAVE HT. and the
                      ;; section spelled CLEAR HEIGHT down the wall - three sheets of one set, and
                      ;; only two of them said what the number meant.
                      ;; peb-height-tag-abbr is the PLAN helper's abbreviated sibling, called here
                      ;; rather than copied, so the sheets cannot drift on WHICH basis it is even
                      ;; though they print it at three different lengths.  C.H / E.H per the owner:
                      ;; this string already carries mm and feet, so the label has to be short.
                      (strcat (peb-dim-mft clrH) " "
                              (peb-height-tag-abbr (MSPL-Get-Str data "HEIGHT_REF")))))))
  ;; the dim chain clears the bubble by its ACTUAL radius, not a fixed drop
  (setq noteY (- base bubGap bubR (* 600.0 *PEB-DIM-SCALE*)))
  (vl-catch-all-apply (function (lambda () (peb-fr-dimchain ox noteY stations))))
  ;; OVERALL LENGTH of the wall, below the bay chain, metres AND feet on the one
  ;; line (owner 26-Aug).  The bay chain above stays in mm per the sheet note.
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-h ox (+ ox faceLen) (- noteY (* 2600.0 *PEB-DIM-SCALE*))
                      ;; ...and WHICH PLANE it is measured on, the same way the Column Layout Plan
                      ;; states it (owner 31-Aug: "also show the dimensions as O/O, C/C ... like we
                      ;; mention the column layout plan").  peb-basis-suffix is the plan's helper,
                      ;; read from the plan's OWN keys - LENGTH_REF/BAY_REF for a side wall,
                      ;; WIDTH_REF/WIDTH_MOD_REF for an end wall (Plan.lsp:5959, 5982).  Sharing
                      ;; the keys is the point: PRO-01 and the elevations can no longer disagree
                      ;; about what plane the building was measured on.
                      (strcat (peb-dim-mft faceLen) " "
                              (peb-basis-suffix
                                (if isEnd
                                  (peb-tb-or (MSPL-Get-Str data "WIDTH_REF")
                                             (MSPL-Get-Str data "WIDTH_MOD_REF"))
                                  (peb-tb-or (MSPL-Get-Str data "LENGTH_REF")
                                             (MSPL-Get-Str data "BAY_REF")))))))))
  ;; rule 4B.44 - canopies on this wall, drawn last so the fascia reads over the framing
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-canopy data surf ox base faceLen stations revView wallEave))))
  ;; rule 4B.47 - shutter / personnel doors, one per bay
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-doors data surf ox base faceLen stations revView))))
  (setvar "CLAYER" prev)
  (princ))

;; ---- MASONRY STOPS AT THE STEEL IT MEETS  (owner 3-Sep-2026) ----------------------------
;; MSPL-26-279 states BP_BRICK_HT 5,029 (16'-6") and MZ1_CH_FFL_BEAM 4,877 (16'-0").  Both are
;; deliberate round imperial figures and BOTH ARE RIGHT - they describe different places.  The
;; brick dado is 16'-6" where nothing crosses it; the clear height under the mezzanine beam is
;; 16'-0".  They only conflict on the END WALL, where the mezzanine main beam lies IN the wall
;; plane: there the brick was drawn straight through 152 mm of steel, and the sheet said H=5,029
;; under a beam whose soffit it had just drawn at 4,877.
;;
;; A mason does not build through a beam.  So where the mezzanine reaches this end wall, the
;; masonry stops at the beam soffit and the label says which level it stopped at - the drawing
;; stays buildable and the BSF keeps both of its numbers.  Side walls are untouched: the beams
;; run INTO them end-on, so the wall is notched at each beam rather than capped.
;;
;; Gated on the mezzanine actually reaching THIS end: MZ_GRID_BAY_FROM 1 means it starts at the
;; LEW, MZ_GRID_BAY_TO at the last grid means it runs to the REW.  A mezzanine that stops short
;; leaves the brick at its full height, which is what it does on site.
(defun peb-fr-brick-clamp (gbase surf data / chb gf gt nb)
  (if (and (> gbase 0.0)
           (member surf '("LEW" "REW"))
           (= (strcase (peb-tb-or (MSPL-Get-Str data "MZ_TOGGLE") "")) "YES"))
    (progn
      (setq chb (atof (peb-tb-or (MSPL-Get-Str data "MZ1_CH_FFL_BEAM") "0"))
            gf  (MSPL-Get-Int data "MZ_GRID_BAY_FROM")
            gt  (MSPL-Get-Int data "MZ_GRID_BAY_TO")
            nb  (MSPL-Get-Int data "NUMBAYS"))
      (if (or (null gf) (< gf 1)) (setq gf 1))
      (if (or (null nb) (< nb 1)) (setq nb 1))
      (if (or (null gt) (< gt 2))  (setq gt (1+ nb)))
      (if (and (> chb 100.0) (< chb gbase)
               (if (= surf "LEW") (<= gf 1) (>= gt (1+ nb))))
        (setq gbase chb))))
  gbase)

;; The clamp is invisible unless the label says so: H=4,877 under a stated 16'-6" dado reads as
;; a mistake until the reader is told the beam is what stopped it.
(defun peb-fr-brick-note (gbase owText)
  (if (and (> gbase 0.0) (< gbase (- (peb-fr-openwall-ht owText) 1.0)))
    "  (TO MEZZ. BEAM SOFFIT)"
    ""))

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
             " - H=" (peb-comma (rtos gbase 2 0))
             (peb-fr-brick-note gbase owText))))

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

(defun peb-fr-wallface (ox0 flen wbase gbase colhw owText eaveTop skipBaseLine
                        / gsp pdep i gy owU isRcc hEnt bc bx0 by0 bx1 by1 lv)
  (setvar "CLAYER" "GIRTS")
  ;; ── RULE G1: THE GIRTS ARE ANCHORED, NOT STEPPED (owner 4-Sep-2026) ────────────────────
  ;; This was `gsp 1400.0` stepped up from the dado while below `eaveTop - 200`. Two things were
  ;; wrong with it:
  ;;   * the -200 exactly cancels the purlin depth inside peb-eave-add, so the real ceiling was
  ;;     `clear height + HAUNCH` - 700 mm at a 15 m span, 1100 at 50 m. The ladder was allowed to
  ;;     climb up to 1100 mm ABOVE the clear height, i.e. above the column it fixes to, with
  ;;     nothing to carry it at either end of the wall. That is the defect the owner spotted:
  ;;     "top girts is going up from the Clear Height and there is not support for that on both
  ;;      sides columns."
  ;;   * it was a fixed step, so the last space was whatever was left over.
  ;;
  ;; Now the levels come from peb-acc-girt-levels in the component library: anchored on the dado
  ;; top, the light band's sill and head, and a top girt at `clear - 200`, with each zone between
  ;; anchors divided into equal spaces no greater than the maximum. ONE source, shared with the
  ;; sheeting elevation, so the same wall cannot show girts at two different heights on two
  ;; sheets (golden rule 3).
  (setq pdep 60.0)
  (setq lv (if (and (boundp 'peb-acc-girt-levels)
                    (boundp '*PEB-WF-CLEAR*) *PEB-WF-CLEAR* (> *PEB-WF-CLEAR* 0.0))
             (peb-acc-girt-levels (+ wbase gbase)
                                  (+ wbase (if (boundp '*PEB-WF-CLEAR*) *PEB-WF-CLEAR* 0.0))
                                  (if (and (boundp '*PEB-WF-SILL*) *PEB-WF-SILL*)
                                    (+ wbase *PEB-WF-SILL*) nil)
                                  (if (and (boundp '*PEB-WF-HEAD*) *PEB-WF-HEAD*)
                                    (+ wbase *PEB-WF-HEAD*) nil))
             nil))
  (if lv
    (foreach gy lv
      (command "_.LINE" (list ox0 gy) (list (+ ox0 flen) gy) "")
      (command "_.LINE" (list ox0 (+ gy pdep)) (list (+ ox0 flen) (+ gy pdep)) ""))
    ;; fallback: the old ladder, for a standalone load with no library present
    (progn
      (setq gsp 1400.0 i 1)
      (while (< (+ wbase gbase (* i gsp)) (- eaveTop 200.0))
        (setq gy (+ wbase gbase (* i gsp)))
        (command "_.LINE" (list ox0 gy) (list (+ ox0 flen) gy) "")
        (command "_.LINE" (list ox0 (+ gy pdep)) (list (+ ox0 flen) (+ gy pdep)) "")
        (setq i (1+ i)))))
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
                   " - H=" (peb-comma (rtos gbase 2 0))
                   (peb-fr-brick-note gbase owText)))))
  (princ))

;; Brick / RCC material fill for a wall zone (0..faceLen x 0..gbase from base), synced to the wall condition.
;; Brick/Block -> AR-B816 (light-brick colour); Pre-Cast/RCC/Concrete -> AR-CONC aggregate (grey) w/ manual
;; cross-hatch fallback; Access/Glazing/Open -> nothing. Shared by the framing + sheeting elevations. colhw
;; insets the fill from the columns (0 for sheeting = full width).
;; ── AN OPENING'S TRUE SILL AND HEIGHT ──────────────────────────────────────────────────
;;
;;  BOTH wall elevations drew EVERY framed opening as a rectangle from the wall base up to
;;  0.72 x the eave height:
;;
;;      (command "_.RECTANG" (list ... base) (list ... (+ base (* eaveH 0.72))))
;;
;;  so a 914-high louver sitting inside a 3048 brickwall came out as a 4.66 m tall box
;;  starting at the floor, and a louver, a window and a personnel door were the same box.
;;  On MSPL-26-266 all twelve louvers and all twelve windows plotted at 0 -> 4662.6.
;;
;;  The BSF has carried PL*_SILL and PL*_HEIGHT the whole time - 266 says sill 2134,
;;  height 914, and 2134 + 914 = 3048 = exactly the brick height, so the louver head is
;;  meant to land on top of the brickwork. Nothing read them. These two read them, and the
;;  defaults are MAIMAAR_PEB_Elevation.lsp:250's, so the three wall views cannot disagree
;;  about where an opening sits.
(defun peb-fr-open-sill (data pre ptyp / s)
  (setq s (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "SILL")) "0")))
  (if (and (<= s 0.0) (not (vl-string-search "DOOR" ptyp))) 900.0 (max s 0.0)))

(defun peb-fr-open-ht (data pre ptyp / h)
  (setq h (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "HEIGHT")) "0")))
  (if (> h 0.0) h (if (vl-string-search "DOOR" ptyp) 3000.0 1200.0)))

;; A LOUVER IS DRAWN AS A LOUVER (golden rule 1: one product, one drawer) by the component
;; library; everything else keeps the clear rectangle these sheets have always used - only
;; now at its own sill and height. peb-lv-elev draws the framed opening AND the louver, so
;; the 22 frame margin and the blade pitch come from the traced Section 13.8 numbers and not
;; from anything re-derived here.
;;
;; showScreen is nil on a wall elevation: the insect-screen mesh is a 120 fill, and twelve
;; louvers' worth of it at wall scale is a grey smear. The break-and-mesh view belongs on a
;; detail, where there is room for it.
(defun peb-fr-draw-opening (data pre ptyp x0 x1 ybot ytop / scr m)
  (if (and (wcmatch ptyp "*LOUVER*") (boundp 'peb-lv-elev))
    (progn
      (setq scr (not (wcmatch (strcase (peb-tb-or (MSPL-Get-Str data "LV_SCREEN") "with"))
                              "*WITHOUT*"))
            m   (peb-lv-margin))
      ;; MASK THE FILL BEHIND IT. A framed opening in brickwork is a HOLE, and the brick hatch
      ;; was running straight through the louver - coursing visible between the blades. A
      ;; WIPEOUT hides only what was drawn BEFORE it (see Plan.lsp:6673), and peb-fr-material-fill
      ;; runs well before this loop, so the mask lands on the brick and on nothing after it.
      ;; Same device and the same catch guard as the brick-height label's mask above.
      (vl-catch-all-apply (function (lambda ()
        (setvar "WIPEOUTFRAME" 0)
        (command "_.WIPEOUT" (list (- x0 m) (- ybot m)) (list (+ x1 m) (- ybot m))
                             (list (+ x1 m) (+ ytop m)) (list (- x0 m) (+ ytop m)) ""))))
      (peb-lv-elev x0 ybot (- x1 x0) (- ytop ybot)
                   (peb-tb-or (MSPL-Get-Str data "LV_TYPE") ptyp) scr nil))
    (progn (setvar "CLAYER" "OPEN")
           (command "_.RECTANG" (list x0 ybot) (list x1 ytop))))
  (princ))

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
                              bubGap bubR ov gbase owText sp sx cnt pre psurf pat pw ptyp psill ph noteY owU revView hdTxt
                              prng pi0 pi1 px0 pOfs pnTot gMarks
                              rbOn rbFrom rbTo rbFloor rbBase nLen ewGrid ewRaised rx0 rx1 hasR gbaseR bc sbase sgb)
  (setq len (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (slope-denom (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        stype (strcase (peb-tb-or (MSPL-Get-Str data "STYPE") "CS")))
  (setq clrH (peb-clear-height data))
  ;; Rule 4B.7 — the entered number is the CLEAR height (peb-clear-height backs out an
  ;; eave-basis figure). The DRAWN eave is that plus the haunch and the purlin, which is
  ;; exactly what the title block on this very sheet prints. Holding both in one variable
  ;; is what drew the wall 1,300 mm short and then dimensioned it as the full height.
  (setq eaveH (+ clrH (peb-eave-add data)))
  ;; ── FEED RULE G1 (owner 4-Sep-2026) ────────────────────────────────────────────────────
  ;; The girt levels are anchored on the clear height and on the light band's sill and head, so
  ;; peb-fr-wallface needs all three. They travel as specials because AutoLISP is dynamically
  ;; scoped and wallface is called from five places mid-way through a wall of locals - threading
  ;; three more parameters through every call site would be a bigger change than the rule.
  ;; The band levels are what the BSF already settled (WA_LIGHT_SILL / _HEAD); nothing is
  ;; re-derived here (golden rule 24).
  ;; NO `let` HERE - AutoLISP has no such function. Using it threw "no function definition: LET",
  ;; which killed the drawer and produced a BLANK sheeting elevation with a title block and
  ;; nothing else. Plain setq, and a nil when the value is absent or zero.
  (setq *PEB-WF-CLEAR* clrH)
  (setq *PEB-WF-SILL* (MSPL-Get-Num data "WA_LIGHT_SILL"))
  (if (or (null *PEB-WF-SILL*) (<= *PEB-WF-SILL* 0.0)) (setq *PEB-WF-SILL* nil))
  (setq *PEB-WF-HEAD* (MSPL-Get-Num data "WA_LIGHT_HEAD"))
  (if (or (null *PEB-WF-HEAD*) (<= *PEB-WF-HEAD* 0.0)) (setq *PEB-WF-HEAD* nil))

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
  ;; The same marks the FRAMING elevation letters with - one grid, one set of marks, on both
  ;; sheets and on the plan (rule 4B.8).
  (setq gMarks nil)
  (if isEnd
    (progn
      (setq gMarks (vl-catch-all-apply
                     (function (lambda ()
                       (peb-width-marks stations (peb-width-mods data wid))))))
      (if (vl-catch-all-error-p gMarks) (setq gMarks nil))))
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
        gbase (peb-fr-brick-clamp (peb-fr-openwall-ht owText) surf data))   ; see peb-fr-brick-clamp
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
    (progn
      (command "_.LINE" (list ox (+ base wallEave)) (list (+ ox faceLen) (+ base wallEave)) "")
      ;; THE RIDGE, as a reference line - the SAME convention peb-draw-framing-elev already uses on
      ;; its own side walls ("dashed ridge above (gable)").  This sheet omitted it, so the two
      ;; side-wall sheets disagreed about whether the building even has a roof, and a roof monitor
      ;; drawn at its true height had nothing underneath it: the band floated a clear 1524 above the
      ;; wall top and read as a stray strip rather than as something standing on the ridge.
      (if (= rtype "G")
        (progn (setvar "CLAYER" "RIDGE")
          (command "_.LINE" (list ox (+ base wallEave rise))
                            (list (+ ox faceLen) (+ base wallEave rise)) "")
          ;; CLOSE THE ROOF BAND.  Viewed square-on to a long wall, the near roof slope projects as a
          ;; RECTANGLE from eave level to ridge level over the full length, and the gable rake at each
          ;; end projects as a VERTICAL line - the rake runs away from the viewer, so it foreshortens
          ;; to a point in plan-x.  Both sheets drew the eave and (here) the ridge and left the band
          ;; open at its ends, so the ridge read as a line floating over the wall rather than as the
          ;; top of a roof.  A roof monitor seated at its TRUE height then had nothing under it at all
          ;; (owner 31-Aug).  These two edges are the roof; the monitor stands on them.
          (setvar "CLAYER" "STRUCTURE")
          (command "_.LINE" (list ox (+ base wallEave)) (list ox (+ base wallEave rise)) "")
          (command "_.LINE" (list (+ ox faceLen) (+ base wallEave))
                            (list (+ ox faceLen) (+ base wallEave rise)) "")
          ;; THE MAIN ROOF, SHEETED (owner 31-Aug).  On a SHEETING drawing this band was an empty
          ;; rectangle while the wall below it was full of panel lines.  Pitch 1000 = the roof
          ;; COVER width peb-draw-roof-sheeting uses.  Only here, never in the framing drawer.
          ;; No overlap with the monitor, which stands entirely ABOVE the ridge this band tops out at.
          (setvar "CLAYER" "CLADDING")
          (setq sx 1000.0)
          (while (< sx faceLen)
            (command "_.LINE" (list (+ ox sx) (+ base wallEave))
                              (list (+ ox sx) (+ base wallEave rise)) "")
            (setq sx (+ sx 1000.0)))
          ;; the two end edges just below draw with no setvar of their own, so CLAYER is left
          ;; on STRUCTURE for them rather than on RIDGE.
          (setvar "CLAYER" "STRUCTURE")))))
  ;; two vertical end edges (base -> roof)
  (command "_.LINE" (list ox base)
                    (list ox (if isEnd (peb-fr-topy 0.0 faceLen base eaveH eaveHi eaveLo rise rtype hiSide) (+ base wallEave))) "")
  (command "_.LINE" (list (+ ox faceLen) base)
                    (list (+ ox faceLen) (if isEnd (peb-fr-topy faceLen faceLen base eaveH eaveHi eaveLo rise rtype hiSide) (+ base wallEave))) "")

  ;; ROOF MONITOR (owner 31-Aug: "Elevations Do not Show the Roof Monitor Lines").  Drawn
  ;; AFTER the roof profile so it sits on top of the line it straddles, and wrapped the way
  ;; every other optional piece on this sheet is: a monitor that cannot be drawn must not be
  ;; able to unwind the whole elevation, which is exactly how the end wall was lost once
  ;; before (see the rdep note above).
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-monitor data ox base faceLen eaveH eaveHi eaveLo rise rtype hiSide isEnd
                    wallEave slopeD stations "S"))))

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
          pw (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "WIDTH")) "0"))
          ptyp (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "TYPE")) "")))
    (if (and (= psurf surf) (> pw 0.0))
      (progn
        ;; AT ITS OWN SILL AND HEIGHT — the same helper the framing elevation uses, so the
        ;; opening is cut in the sheeting exactly where the framing says it is.
        (setq psill (peb-fr-open-sill data pre ptyp)
              ph    (peb-fr-open-ht   data pre ptyp))
        (peb-fr-draw-opening data pre ptyp
                             (+ ox pat (- (/ pw 2.0))) (+ ox pat (/ pw 2.0))
                             (+ base psill) (+ base psill ph))))
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
                pnTot isEnd gMarks))
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
    (peb-fr-overall-v (- ox (* 1500 *PEB-DIM-SCALE*)) base (+ base clrH)
                      ;; SAY WHICH HEIGHT IT IS (owner 31-Aug: "in plan we write the word Clear
                      ;; Height, here also we have to mention this in elevation ... what i want
                      ;; the sync in all the drawings of the building").  The elevations printed a
                      ;; bare number while the plan tagged its areas CLEAR HT./EAVE HT. and the
                      ;; section spelled CLEAR HEIGHT down the wall - three sheets of one set, and
                      ;; only two of them said what the number meant.
                      ;; peb-height-tag-abbr is the PLAN helper's abbreviated sibling, called here
                      ;; rather than copied, so the sheets cannot drift on WHICH basis it is even
                      ;; though they print it at three different lengths.  C.H / E.H per the owner:
                      ;; this string already carries mm and feet, so the label has to be short.
                      (strcat (peb-dim-mft clrH) " "
                              (peb-height-tag-abbr (MSPL-Get-Str data "HEIGHT_REF")))))))
  ;; the dim chain clears the bubble by its ACTUAL radius, not a fixed drop
  (setq noteY (- base bubGap bubR (* 600.0 *PEB-DIM-SCALE*)))
  (vl-catch-all-apply (function (lambda () (peb-fr-dimchain ox noteY stations))))
  ;; OVERALL LENGTH of the wall, below the bay chain, metres AND feet on the one
  ;; line (owner 26-Aug).  The bay chain above stays in mm per the sheet note.
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-h ox (+ ox faceLen) (- noteY (* 2600.0 *PEB-DIM-SCALE*))
                      ;; ...and WHICH PLANE it is measured on, the same way the Column Layout Plan
                      ;; states it (owner 31-Aug: "also show the dimensions as O/O, C/C ... like we
                      ;; mention the column layout plan").  peb-basis-suffix is the plan's helper,
                      ;; read from the plan's OWN keys - LENGTH_REF/BAY_REF for a side wall,
                      ;; WIDTH_REF/WIDTH_MOD_REF for an end wall (Plan.lsp:5959, 5982).  Sharing
                      ;; the keys is the point: PRO-01 and the elevations can no longer disagree
                      ;; about what plane the building was measured on.
                      (strcat (peb-dim-mft faceLen) " "
                              (peb-basis-suffix
                                (if isEnd
                                  (peb-tb-or (MSPL-Get-Str data "WIDTH_REF")
                                             (MSPL-Get-Str data "WIDTH_MOD_REF"))
                                  (peb-tb-or (MSPL-Get-Str data "LENGTH_REF")
                                             (MSPL-Get-Str data "BAY_REF")))))))))
  ;; rule 4B.44 - canopies on this wall
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-canopy data surf ox base faceLen stations revView wallEave))))
  ;; rule 4B.47 - shutter / personnel doors, one per bay
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-doors data surf ox base faceLen stations revView)
     ;; ...and the WALL-LIGHT BAND. Only here, on the SHEETING elevation - the wall light is a
     ;; cladding item, so it is drawn where the sheeting is drawn (standing rule, owner 3-Sep-2026).
     ;; The framing elevation above deliberately does NOT get it.
     (peb-fr-wall-lights data surf ox base faceLen stations))))
  (setvar "CLAYER" prev)
  (princ))

;; Draw a SET of elevations (framing or sheeting) for the given walls, stacked, with a title block.
;; kind = "F" (framing) | "S" (sheeting). Shared by the all / side / end variants — the pipeline splits
;; side vs end onto their OWN sheets for BIG buildings so each elevation prints large + legible (owner 28-Jul).
(defun peb-draw-elev-set (data walls kind title / wid len slopeD eaveH ts step i surf faceMax)
  (setq len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH") "0"))
        slopeD (slope-denom (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        eaveH  (+ (peb-clear-height data) (peb-eave-add data)))   ; rule 4B.7 — the DRAWN eave
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
  ;; a SHEETING elevation carries the panel/liner spec bands a framing one does not, so it is
  ;; fitted smaller and its bubble plots smaller.  Same drawer, two sheet profiles.
  (setq *PEB-BUB-FIT* (peb-bub-fit (if (= kind "F") "FRAME-ELEV" "SHEET-ELEV")))
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
  (setq *PEB-BUB-FIT* (peb-bub-fit "FRAME-ELEV"))
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
(defun peb-draw-roof-sheeting (data ox oy / len wid slopeD bayPts prev midY i x y wMods
                               cover nRuns stype mgGables mgGableW base mgi ry mgRid
                               mgVal bubGap bubR ovr j fx hiNSW wgrid lbl
                               prng pi0 pi1 px0 pOfs bi mBnd mX0 mX1 mB mT lblX)
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
  (setq *PEB-BUB-FIT* (peb-bub-fit "ROOF"))
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
  ;; A run STOPS at the roof monitor - the cladding butts into the upstand, it does not pass under
  ;; it.  Drawn straight through, every run crossed the monitor band and the monitor stopped being
  ;; legible: five near-parallel lines with 59 more ruled across them read as a grey smudge, not as
  ;; an opening (owner 31-Aug, "simple But Excellent Outlook").  The band comes from
  ;; peb-monitor-band, the SAME call the monitor drawer uses, so the gap the sheeting leaves is
  ;; exactly the opening that gets drawn in it - they cannot drift apart.
  ;; The break is the THROAT, not the whole band.  The monitor roof merely passes OVER the main roof
  ;; - "overlap but not real overlap" (owner 31-Aug) - so the main sheeting continues underneath the
  ;; overhang either side and is genuinely cut only at the opening.  Breaking the full 3000 band said
  ;; the roof was cut twice as wide as it is.  peb-monitor-band returns (x0 x1 yBot yTop throat ridge),
  ;; so the opening is ridge +/- throat/2 - the SAME numbers the monitor drawer uses.
  (setq mBnd (if (boundp 'peb-monitor-band) (peb-monitor-band data len wid bayPts) nil))
  (if mBnd (setq mX0 (+ ox (nth 0 mBnd)) mX1 (+ ox (nth 1 mBnd))
                 mB  (+ oy (- (nth 5 mBnd) (/ (nth 4 mBnd) 2.0)))
                 mT  (+ oy (+ (nth 5 mBnd) (/ (nth 4 mBnd) 2.0)))))
  (while (< i nRuns)
    (setq x (+ ox (* cover i)))
    ;; only the runs that actually meet the monitor are broken; a partial-length monitor leaves the
    ;; rest of the roof sheeted end to end.
    (if (and mBnd (>= x mX0) (<= x mX1))
      (progn
        (command "_.LINE" (list x oy) (list x mB) "")
        (command "_.LINE" (list x mT) (list x (+ oy wid)) ""))
      (command "_.LINE" (list x oy) (list x (+ oy wid)) ""))
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
     ;; A roof monitor STANDS ON the ridge, so under it there is no ridge to show - the monitor's own
     ;; geometry is what tells you where the ridge runs (owner 31-Aug: "in case of roof Monitor, i
     ;; think there is no need of Ridge Line").  Drawn anyway, the line and its label ran straight
     ;; through the hatched opening and neither could be read.  So the ridge is drawn ONLY where the
     ;; monitor is not: a full-length monitor leaves none, a partial one keeps its end stubs - which
     ;; is exactly where a ridge IS exposed on the real roof.
     (setvar "CLAYER" "RIDGE")
     (if mBnd
       (progn
         (if (> mX0 (+ ox 1.0))          (command "_.LINE" (list ox midY)  (list mX0 midY) ""))
         (if (< mX1 (- (+ ox len) 1.0))  (command "_.LINE" (list mX1 midY) (list (+ ox len) midY) "")))
       (command "_.LINE" (list ox midY) (list (+ ox len) midY) ""))
     ;; ...and the label only where there is a ridge left to label.
     (setq lblX
       (cond ((null mBnd) (+ ox (* len 0.02)))
             ((> mX0 (+ ox 1.0)) (+ ox (* (- mX0 ox) 0.15)))
             ((< mX1 (- (+ ox len) 1.0)) (+ mX1 (* (- (+ ox len) mX1) 0.15)))
             (T nil)))
     (if lblX
       (progn
         (setvar "CLAYER" "TEXT")
         (txt "ML" (list lblX (+ midY (* 300 *PEB-TEXT-SCALE*)))
              (peb-th 'ANNOT) 0 "RIDGE LINE")))
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
    (vl-catch-all-apply (function (lambda () (peb-draw-roof-accessories data len wid bayPts)))))

  ;; --- roof monitor (owner 31-Aug: "show the roof Monitor as well on the Roof Plan") -------
  ;; It was drawn on NO shipped sheet. The 21-Jul ruling took it off the Column Layout Plan and sent
  ;; it to "the ROOF PLAN (to be built later)" — but that sheet (C:PEB-ROOF) is behind the
  ;; PEB_DRAFT_SHEETS gate and is not in the PDF pipeline, so the monitor fell through the gap: the
  ;; BSF declared it, the section drew it, and every plan the customer received showed a bare roof.
  ;; This is the roof plan that actually ships, so it belongs here, beside the other roof accessories.
  (if (boundp 'peb-draw-monitor)
    (vl-catch-all-apply (function (lambda () (peb-draw-monitor data len wid bayPts)))))

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

  ;; NO per-bay dimension chain.  It was added to match MSPL 2025/203 sheet 19, which dimensions
  ;; every bay across the top - and on THAT sheet it fits.  Here it does not: this is A4 at 1:378,
  ;; each dim prints millimetres AND feet, and 6,480 mm of bay is ~17 mm of paper.  AutoCAD pushed
  ;; every text outside its own arrows and the eight of them collided into one unreadable smear
  ;; across the top of the drawing (owner 31-Aug: "everything is overlapping").  The overall chain
  ;; below already carries the grid as "1@6480 + 6@8000 + 1@6480", and the bubbles number it.  A
  ;; dimension nobody can read is worse than one that was never drawn.

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
  ;; ;; peb-width-mark, not peb-width-letter: the merged grid now carries the infill POSTS as well as
  ;; the module lines, so counting straight through it gave the far wall a letter that counted the
  ;; posts too - K where the plan says F.  A main line takes its letter, a post takes a prime.
  (setq wMods (vl-catch-all-apply (function (lambda () (peb-width-mods data wid)))))
  (if (vl-catch-all-error-p wMods) (setq wMods nil))
  (grid-bubble (- ox bubGap bubR) oy
               (if wgrid (peb-width-mark (nth 0 wgrid) wgrid wMods) "A") "R")
  (command "_.LINE" (list ox (+ oy wid)) (list (- ox bubGap) (+ oy wid)) "")
  ;; peb-grid-letter, not (chr 65+n): the plan skips I, so this must too
  (setq lbl (if wgrid (peb-width-mark (nth (1- (length wgrid)) wgrid) wgrid wMods) "B"))
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
;; BOTH EDGES ARE PROFILED LAPS — THE SECTION STARTS AND ENDS ON A RIB (owner 28-Aug:
;; "both side laps are profiled and one sheet rest on the other while fixing ... left side
;; straight side to be corrected").
;;
;; That is how the sheet actually goes on: the rib at one edge sits over the rib at the
;; next sheet's edge, so a section of the panel shows a rib at BOTH ends, never a bare pan.
;;
;; It was drawn  flat .68 | up .08 | crown .16 | down .08  per pitch, i.e. the rib at the
;; END of its pitch. Across n pitches that opened with a long flat (the "left side straight
;; side") and closed on a rib foot — two different corners, and the left one showed a lap
;; that does not exist.
;;
;; Now the ribs sit ON the pitch lines: n+1 of them at 0, pit, 2·pit … n·pit, with the pan
;; spanning between. Both ends are the same rib.
;;
;; THE COIL MODEL, in the owner's words (28-Aug): "normally we have 1200 mm sheet which
;; after profiling converts to 1100, in which almost 100 goes for overlap and net sheeting
;; is 1000 mm — from GOLA TOP TO GOLA TOP is 1000 mm."
;;
;; So COVER IS MEASURED RIB CROWN TO RIB CROWN, and it is 1000 over four 250 pitches — which
;; is exactly what the "1,000 COVER" dimension below spans, and why the run must carry a rib
;; at each end rather than a pan: the end ribs ARE the 100 of overlap, one sheet resting on
;; the next.
;;
;; One rib, centred on its pitch line c:
;;   foot c-.16 | web up c-.08 | crown to c+.08 | web down to c+.16   (of the pitch)
;; ── THE SHEET PROFILE'S OWN NUMBERS, IN ONE PLACE (3-Sep-2026) ────────────────────────────
;; "Section should 100% match with Sheeting Profile" (owner). It did — but only because 250 and
;; 35 happened to be typed identically in two places: here for the DETAILS sheet, and again in
;; the light-panel component. Two literals that agree today are not a match; they are a match
;; waiting to be broken by whoever edits one of them. These accessors make the sheet the SOURCE,
;; and every other drawer reads the profile from it.
(defun peb-sheet-rib-pitch  () 250.0)   ; Standard S Profile 35-250 — 4 pitches = the 1000 cover
(defun peb-sheet-rib-height ()  35.0)
(defun peb-sheet-cover      () 1000.0)  ; crown to crown

(defun peb-sd-sprofile (x0 y0 n pit ht / i c pts)
  (setq i 0 pts '())
  (while (<= i n)
    (setq c (+ x0 (* i pit)))
    (setq pts (append pts (list (list (- c (* pit 0.16)) y0)
                                (list (- c (* pit 0.08)) (+ y0 ht))
                                (list (+ c (* pit 0.08)) (+ y0 ht))
                                (list (+ c (* pit 0.16)) y0))))
    (setq i (1+ i)))
  ;; LAYER OVERRIDE (owner 3-Sep-2026). The wall / sky light panel is THE SAME SHEET PROFILE
  ;; as the roof ("1.50mm thickness and have sheeting profile of roof"), so the accessory
  ;; drawer calls this very function rather than re-deriving the rib geometry — but its
  ;; output belongs on the light-panel layer, not on SHEETING. Unset ⇒ SHEETING, exactly as
  ;; before, so every existing caller is byte-identical.
  (setvar "CLAYER" (if (and (boundp '*PEB-SPROF-LAYER*) *PEB-SPROF-LAYER*)
                     *PEB-SPROF-LAYER* "SHEETING"))
  (setq i 0)
  (while (< (1+ i) (length pts))
    (command "_.LINE" (nth i pts) (nth (1+ i) pts) "")
    (setq i (1+ i)))
  pts)

;; One lock-seam pan: flat, then the standing seam upstand at each edge.
;; -- LOCK SEAM SHEET PROFILE - MEASURED OFF THE OWNER'S OWN SECTION -----------------
;; Owner 29-Aug: "SeamLock Sheet Profile.PNG, also update this."
;;
;; The shape that stood here carried the right DIMENSION SET but not the right shape: it had
;; been reconstructed from the numbers on an approval drawing, and reconstruction is guesswork
;; about which dimension belongs to which segment.  This version is TRACED - the green polyline
;; was extracted from the owner's PNG pixel by pixel and scaled by the one dimension that cannot
;; be misread, the 155 mm rib centres (333.5 px / 155 mm = 2.1516 px per mm).
;;
;; What the trace corrected:
;;   * the pan RIBS are shallow stiffening bumps ~3 mm tall, not the 8 mm square ribs drawn
;;     before - at 1:9 on the DETAILS sheet that is the difference between a lock seam and a
;;     trapezoidal profile;
;;   * the right-hand seam is a 10 wide x 25 tall CLOSED BOX (the male standing seam the next
;;     panel's hook closes over), not a 15 mm return;
;;   * the left seam carries TWO 25s - a vertical drop and a horizontal run - where only one
;;     was drawn;
;;   * the leg lengths now MEASURE what they are dimensioned: 32 and 23 on the left (119 deg
;;     into the pan), 32 and 22 on the right.  The old vertices measured 35.8 and 24.6.
;;
;; The traced panel is 486 wide and the module pitch is 470 - the 16 mm difference IS the lap,
;; the right seam sitting over the next panel's left hook.  That is the arithmetic check that
;; the trace is right, and it is why cover stays 470 (owner: "610 mm sheet produces 470 mm net
;; covering width of lockseam including overlap").
;;
;;   470 cover  |  pan 92 | rib | 145 | rib | 91, ribs at 155 centres
(defun peb-sd-lockseam (x0 y0 n cov ht / i x k)
  ;; -- THE OWNER'S OWN SECTION, VERBATIM (owner 29-Aug: "Drawing9.dxf ... Please see the DXF") --
  ;; Superseding the pixel trace of his PNG.  This is the LWPOLYLINE lifted straight out of his
  ;; DXF: 35 vertices, a CLOSED outline carrying the sheet's own 0.5 mm material thickness rather
  ;; than a single centre line, which is why the run appears twice - once on each face.
  ;;
  ;; It validates the trace it replaces and improves on it.  Traced: 486.0 x 64.9 with rib centres
  ;; at 155.1.  Actual: 485.5 x 65.5 with the rib centres at EXACTLY 155.000 (174.0 and 329.0) and
  ;; the ribs exactly 10.000 wide.  The pan reads 91.356 | 10 | 145.000 | 10 | 91.356 - dimensioned
  ;; on his sheet as 92 | 10 | 145 | 10 | 91, so the DIMENSIONS ARE HIS ROUNDINGS OF HIS OWN STEEL,
  ;; which is the only basis on which the drawing and its dimensions can agree (rule 4B.7).
  ;;
  ;; 485.5 wide on a 470 pitch leaves a 15.5 lap - and 15.5 is the hook's own width (0 -> 15.5),
  ;; the same self-check the trace closed on.
    ;; Same layer override as peb-sd-sprofile: the light panel is the SAME PROFILE in a
  ;; different material (owner 3-Sep-2026), so it calls this very function and only needs the
  ;; result on its own layer. Unset -> SHEETING, exactly as before.
  (setvar "CLAYER" (if (and (boundp '*PEB-SPROF-LAYER*) *PEB-SPROF-LAYER*)
                     *PEB-SPROF-LAYER* "SHEETING"))
  (setq k (/ cov 470.0))            ; scale his section to the caller's module
  (setq i 0)
  (while (< i n)
    (setq x (+ x0 (* i cov)))
    (peb-sd-poly (list
      (list (+ x (* k  251.500)) (+ y0 (* k   0.000)))
      (list (+ x (* k  178.743)) (+ y0 (* k   0.000)))
      (list (+ x (* k  178.027)) (+ y0 (* k   0.854)))
      (list (+ x (* k  177.161)) (+ y0 (* k   1.553)))
      (list (+ x (* k  176.175)) (+ y0 (* k   2.072)))
      (list (+ x (* k  175.109)) (+ y0 (* k   2.392)))
      (list (+ x (* k  174.000)) (+ y0 (* k   2.500)))
      (list (+ x (* k  172.891)) (+ y0 (* k   2.392)))
      (list (+ x (* k  171.825)) (+ y0 (* k   2.072)))
      (list (+ x (* k  170.839)) (+ y0 (* k   1.553)))
      (list (+ x (* k  169.973)) (+ y0 (* k   0.854)))
      (list (+ x (* k  169.257)) (+ y0 (* k   0.000)))
      (list (+ x (* k   77.500)) (+ y0 (* k   0.000)))
      (list (+ x (* k   58.223)) (+ y0 (* k  12.098)))
      (list (+ x (* k   42.500)) (+ y0 (* k  40.000)))
      (list (+ x (* k   15.500)) (+ y0 (* k  40.000)))
      (list (+ x (* k   15.500)) (+ y0 (* k  65.000)))
      (list (+ x (* k    0.500)) (+ y0 (* k  65.000)))
      (list (+ x (* k    0.500)) (+ y0 (* k  55.000)))
      (list (+ x (* k    0.000)) (+ y0 (* k  55.000)))
      (list (+ x (* k    0.000)) (+ y0 (* k  65.500)))
      (list (+ x (* k   16.000)) (+ y0 (* k  65.500)))
      (list (+ x (* k   16.000)) (+ y0 (* k  40.500)))
      (list (+ x (* k   42.792)) (+ y0 (* k  40.500)))
      (list (+ x (* k   58.596)) (+ y0 (* k  12.454)))
      (list (+ x (* k   77.644)) (+ y0 (* k   0.500)))
      (list (+ x (* k  169.000)) (+ y0 (* k   0.500)))
      (list (+ x (* k  169.777)) (+ y0 (* k   1.358)))
      (list (+ x (* k  170.699)) (+ y0 (* k   2.057)))
      (list (+ x (* k  171.735)) (+ y0 (* k   2.575)))
      (list (+ x (* k  172.848)) (+ y0 (* k   2.893)))
      (list (+ x (* k  174.000)) (+ y0 (* k   3.000)))
      (list (+ x (* k  175.152)) (+ y0 (* k   2.893)))
      (list (+ x (* k  176.265)) (+ y0 (* k   2.575)))
      (list (+ x (* k  177.301)) (+ y0 (* k   2.057)))
      (list (+ x (* k  178.223)) (+ y0 (* k   1.358)))
      (list (+ x (* k  179.000)) (+ y0 (* k   0.500)))
      (list (+ x (* k  324.000)) (+ y0 (* k   0.500)))
      (list (+ x (* k  324.777)) (+ y0 (* k   1.358)))
      (list (+ x (* k  325.699)) (+ y0 (* k   2.057)))
      (list (+ x (* k  326.735)) (+ y0 (* k   2.575)))
      (list (+ x (* k  327.848)) (+ y0 (* k   2.893)))
      (list (+ x (* k  329.000)) (+ y0 (* k   3.000)))
      (list (+ x (* k  330.152)) (+ y0 (* k   2.893)))
      (list (+ x (* k  331.265)) (+ y0 (* k   2.575)))
      (list (+ x (* k  332.301)) (+ y0 (* k   2.057)))
      (list (+ x (* k  333.223)) (+ y0 (* k   1.358)))
      (list (+ x (* k  334.000)) (+ y0 (* k   0.500)))
      (list (+ x (* k  425.356)) (+ y0 (* k   0.500)))
      (list (+ x (* k  444.404)) (+ y0 (* k  12.454)))
      (list (+ x (* k  460.208)) (+ y0 (* k  40.500)))
      (list (+ x (* k  485.000)) (+ y0 (* k  40.500)))
      (list (+ x (* k  485.000)) (+ y0 (* k  64.500)))
      (list (+ x (* k  475.500)) (+ y0 (* k  64.500)))
      (list (+ x (* k  475.500)) (+ y0 (* k  65.000)))
      (list (+ x (* k  485.500)) (+ y0 (* k  65.000)))
      (list (+ x (* k  485.500)) (+ y0 (* k  40.000)))
      (list (+ x (* k  460.500)) (+ y0 (* k  40.000)))
      (list (+ x (* k  444.777)) (+ y0 (* k  12.098)))
      (list (+ x (* k  425.500)) (+ y0 (* k   0.000)))
      (list (+ x (* k  333.743)) (+ y0 (* k   0.000)))
      (list (+ x (* k  333.027)) (+ y0 (* k   0.854)))
      (list (+ x (* k  332.161)) (+ y0 (* k   1.553)))
      (list (+ x (* k  331.175)) (+ y0 (* k   2.072)))
      (list (+ x (* k  330.109)) (+ y0 (* k   2.392)))
      (list (+ x (* k  329.000)) (+ y0 (* k   2.500)))
      (list (+ x (* k  327.891)) (+ y0 (* k   2.392)))
      (list (+ x (* k  326.825)) (+ y0 (* k   2.072)))
      (list (+ x (* k  325.839)) (+ y0 (* k   1.553)))
      (list (+ x (* k  324.973)) (+ y0 (* k   0.854)))
      (list (+ x (* k  324.257)) (+ y0 (* k   0.000)))))
    (setq i (1+ i)))
  (princ))

;; -- LOCK SEAM SHEET PROFILE: THE DIMENSIONED DETAIL (rule 4B.50, owner 29-Aug) ------
;; "you have not developed the New Seam Lock Sheet - Details."  Re-tracing the OUTLINE was only
;; half of it: the owner's section is a DETAIL - every fold dimensioned and both seam angles
;; called out - and the DETAILS sheet exists to carry exactly that.  An outline with one "470
;; COVER" bar tells a fabricator nothing he can roll from.
;;
;; Every figure below is DRAWN at the length it PRINTS (rule 4B.7): the pan chain above was
;; reset to its stated 92 | 10 | 145 | 10 | 91 precisely so these dimensions measure the steel,
;; not an approximation of it.
;;
;; The angle marks use %%d, AutoCAD's degree control code - the SHX fonts have no degree glyph
;; and a literal one plots as "?" (the same trap the em-dash set in rule 4B.36).
(defun peb-sd-lockseam-dims (ox y k / sdH sdV sdT yb yt)
  (setq yb (- y (* k 58.0))            ; pan chain, clear of the 470 COVER bar below it
        yt (+ y (* k 30.0)))           ; the 155 rib-centre dim, inside the pan
  (setq sdH (function (lambda (a b lab yy)
            (vl-catch-all-apply (function (lambda ()
              (peb-fr-overall-h (+ ox (* k a)) (+ ox (* k b)) yy lab)))))))
  (setq sdV (function (lambda (xx a b lab)
            (vl-catch-all-apply (function (lambda ()
              (peb-fr-overall-v (+ ox (* k xx)) (+ y (* k a)) (+ y (* k b)) lab)))))))
  (setq sdT (function (lambda (xx yy lab)
            (vl-catch-all-apply (function (lambda ()
              (txt "MC" (list (+ ox (* k xx)) (+ y (* k yy))) (peb-th 'SMALL) 0 lab)))))))
  ;; pan chain, left to right
  ;; Anchors are the OWNER'S OWN vertices out of Drawing9.dxf, so every bar spans the steel it
  ;; measures.  His pan reads 91.356 | 10.000 | 145.000 | 10.000 | 91.356 and he dimensions it
  ;; 92 | 10 | 145 | 10 | 91 — the labels are HIS roundings of HIS section, not ours of a trace.
  (apply sdH (list  77.644 169.000  "92"  yb))
  (apply sdH (list 169.000 179.000  "10"  yb))
  (apply sdH (list 179.000 324.000 "145"  yb))
  (apply sdH (list 324.000 334.000  "10"  yb))
  (apply sdH (list 334.000 425.356  "91"  yb))
  ;; rib CENTRE to rib CENTRE — 174.0 to 329.0 is EXACTLY 155, the figure that proves the chain
  (apply sdH (list 174.000 329.000 "155"  yt))
  ;; left seam
  (apply sdH (list   0.000  16.000  "15"  (+ y (* k 80.0))))
  (apply sdV (list   0.000  55.000  65.500 "10"))
  (apply sdV (list  16.000  40.500  65.500 "25"))
  (apply sdT (list  46.000  27.000  "32"))
  (apply sdT (list  70.000  10.000  "23"))
  (apply sdT (list  96.000  30.000  "119%%d"))
  ;; right seam
  (apply sdH (list 460.500 485.500  "25"  (+ y (* k 80.0))))
  (apply sdV (list 485.500  40.000  65.000 "25"))
  (apply sdT (list 480.500  72.000  "10"))
  (apply sdT (list 455.000  28.000  "32"))
  (apply sdT (list 432.000  10.000  "22"))
  (apply sdT (list 407.000  30.000  "148%%d"))
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
;; ---- the sandwich module, ONE source (rule 3) ------------------------------
;; Declared here beside the drawer that owns the profile, the way peb-sheet-rib-pitch is declared
;; beside the S profile. Read by peb-sd-sandwich below AND by any component clad in sandwich panel
;; (Library/sliding_door — the leaf infill on MSPL-027 and MSPL-030 is sandwich panel), so the
;; door leaf and the wall beside it can never disagree about what a sandwich panel looks like.
(defun peb-sandwich-module () 184.0)   ; crown to crown
(defun peb-sandwich-rib    ()  32.0)   ; rib width at the crown, and its height above the core
(defun peb-sandwich-lap    ()  16.0)   ; the half-rib that laps the next panel

(defun peb-sd-sandwich (x0 y0 n pit ht thk / i x w mod rib crown flat lap top)
  (setq mod  (peb-sandwich-module) rib (peb-sandwich-rib) crown (peb-sandwich-rib)
        lap  (peb-sandwich-lap)
        flat 106.0)                    ; the flat between ribs; 16 at each end laps the next panel
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

;; ── FIBERGLASS INSULATION ROLL (owner 28-Aug) ────────────────────────────────────────
;; "Can you show the symbol of insulation rolls in the details? It is already in the AutoCAD
;;  system ... normally we have been using the fiberglass insulation like the rolled wire,
;;  and fiberglass is NOT the rigid but less density glass fiber, and bottom there is
;;  lamination sheet. Also show the thickness as well."
;;
;; So three things the drawing has to say, and they are the reasons for what is drawn:
;;   * IT IS A SOFT BLANKET, NOT A BOARD.  A plain hatched rectangle reads as rigid board.
;;     The top is drawn as a scalloped, slightly irregular edge - the "rolled wire" look -
;;     so nobody reads it as PIR or a rigid slab.
;;   * THE LAMINATION SHEET IS ON THE BOTTOM.  Drawn as its own solid line under the
;;     blanket and named, because it is a separate supplied item, not part of the wool.
;;   * THE THICKNESS IS DIMENSIONED, off the BSF (PN_<KEY>_INSUL_THK).
;;
;; AutoCAD's own INSUL pattern fills the blanket - the owner asked for the system symbol,
;; not a hand-drawn one - via the same -HATCH call already proven here for AR-CONC and
;; AR-B816, with the MaxHatch bump and a catch-guard so a missing pattern still leaves a
;; readable band. The roll is 6x its thickness long and the pattern cell is 2x the
;; thickness: INSUL's cell is roughly square, so on a long thin band the loops clip into
;; straight dashes, and on a short one an over-fine cell turns to flat grey tone.
(defun peb-sd-insulation (ox y thk lbl / x1 y1 lam stp px pts wTop wBot wMid wAmp wLen)
  (setq lam (* thk 0.14))                    ; the lamination sheet on the underside
  (setq x1 (+ ox (* thk 6.0)) y1 (+ y thk))
  ;; ── BATT INSULATION: ONE WAVY LINE SPANNING THE FULL THICKNESS (owner 28-Aug) ────
  ;; "Complete thickness, show the glasswool lines 50 mm ... it is similar to the boundary
  ;;  wall's wire mesh roll ... insulation CAD hatch, batt, wavy line."
  ;;
  ;; That names the standard: the CAD BATT symbol is a SINGLE continuous wave whose loops
  ;; run face to face, so the wool visibly occupies the whole declared depth. It reads as
  ;; coiled mesh, which is the comparison he drew.
  ;;
  ;; What was tried and was WRONG, recorded so it is not tried again:
  ;;   * AutoCAD's INSUL hatch - lays ONE band of loops at its own cell height and leaves
  ;;     the rest of the boundary empty. On a 50 mm band that is a thin textured strip
  ;;     through the middle, which reads as a rigid board with a line in it. No cell size
  ;;     fixes it: the pattern does not stretch to its boundary.
  ;;   * Parallel fibre lines - they fill the depth, but parallel rules read as the
  ;;     laminations of a rigid board, the opposite of loose fibre.
  ;;
  ;; Amplitude is the full wool thickness. Wavelength is ~0.55 x thickness (owner: "show the
  ;; more dense wave") - at 1.15 the loops were round but sparse and the band read half
  ;; empty; tighter reads as packed fibre, which is what a batt is. 14 samples a wave keeps
  ;; it smooth at plot size.
  (setvar "CLAYER" "HATCH")
  (setq wTop y1 wBot (+ y lam))
  (setq wMid (* 0.5 (+ wTop wBot)) wAmp (* 0.5 (- wTop wBot)))
  (setq wLen (* thk 0.55))
  (setq stp (/ wLen 14.0) px ox pts '())
  (while (<= px x1)
    (setq pts (append pts (list
      (list px (+ wMid (* wAmp (sin (* 2.0 pi (/ (- px ox) wLen)))))))))
    (setq px (+ px stp)))
  (peb-sd-poly pts)
  ;; blanket outline, drawn after the wave so the faces stay crisp
  (setvar "CLAYER" "SHEETING")
  (command "_.RECTANG" (list ox wBot) (list x1 wTop))
  ;; LAMINATION SHEET on the bottom, its own layer of the build-up
  (command "_.RECTANG" (list ox y) (list x1 (+ y lam)))
  ;; THICKNESS dimension, off the BSF
  (vl-catch-all-apply (function (lambda ()
    (peb-fr-overall-v (- ox (* thk 1.1)) y y1 (strcat (rtos thk 2 0))))))
  (setvar "CLAYER" "TEXT") (setvar "CECOLOR" "5")
  (txt-bold "ML" (list ox (+ y1 (* thk 0.75))) (peb-th 'LABEL) 0 "INSULATION")
  (setvar "CECOLOR" "BYLAYER")
  (txt "ML" (list (+ x1 (* thk 0.5)) (+ y (* lam 0.5))) (peb-th 'MARK) 0 "LAMINATION SHEET")
  (txt "ML" (list ox (- y (* thk 1.9))) (peb-th 'ANNOT) 0 lbl)
  (txt "ML" (list ox (- y (* thk 3.1))) (peb-th 'MARK) 0
       "SOFT BLANKET - NON-RIGID, LOW DENSITY GLASS FIBRE")
  (princ))

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
  ;; pit/ht from the shared accessors above, so the panel section and every component that
  ;; reuses the profile cannot drift apart.
  (setq pit (peb-sheet-rib-pitch) ht (peb-sheet-rib-height) cov 470.0 panW (peb-sheet-cover))   ; 470 = gola c/c per MSPL fabrication BOQs
  (setq sand (and (> thk 0.0) (vl-string-search "SANDWICH" (strcase ptype))))
  ;; The title clears the panel by its ACTUAL depth — a 50 mm sandwich core is deeper
  ;; than a 35 mm rib, and a fixed offset put the title straight through it.
  ;; Clearance is measured off what is actually DRAWN above the pan.  The lock-seam section
  ;; reaches 65.5 - its standing seam - where the old constant assumed 38, which put the title
  ;; through the seam itself.  With the fold dimensions gone (4B.50) 75 clears the steel and
  ;; keeps the title tight to it.
  (setq dep (cond (lock 75.0) (sand (+ thk ht)) (T ht)))
  (setvar "CLAYER" "TEXT") (setvar "CECOLOR" "5")
  (txt-bold "ML" (list ox (+ y dep 55.0)) (peb-th 'LABEL) 0 ttl)
  (setvar "CECOLOR" "BYLAYER")
  (cond
    ;; ONE MODULE, matching the owner's own section (Drawing9.dxf).  Two were drawn so the seam
    ;; JOINT read - the male box of one panel closed over the next panel's hook - but his sample
    ;; shows a single module and the sheet must look like the thing he checks it against.  The
    ;; panel is 485.5 wide on a 470 pitch, so the 15.5 lap is still visible at the right-hand
    ;; seam without a second module to lap into.
    (lock (peb-sd-lockseam ox y 1 cov 38.0)
          ;; -- RULE 4B.50 REVISED - THE COVER WIDTH, AND NOTHING ELSE (owner 29-Aug) --------
          ;; "do not show detailed dimensions but only the covered width of the sheet", and
          ;; "just match the sample and only show the main main dimensions."
          ;;
          ;; The fold-by-fold set - 92/10/145/10/91, 155, the 15/10/25 seams, 32/23, 32/22,
          ;; 119 and 148 degrees - was built and is correct, but it does not belong on a
          ;; PROPOSAL drawing.  470 COVER is the figure a customer prices and a draughtsman
          ;; lays out from; the folds are a ROLL-FORMING dimension, settled by the mill, and
          ;; printing them here invites a discussion the proposal is not the place for.  Same
          ;; judgement as the mezzanine column section size (owner 12-Jul) and the joist
          ;; spacing (4B.49): what the drawing states, it owes.
          ;;
          ;; peb-sd-lockseam-dims is LEFT IN PLACE, not deleted - it is the approval-drawing
          ;; detail, correct and traced from the owner's own DXF, waiting for the sheet that
          ;; wants it.  Deleting it would just mean building it again.
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

(defun peb-draw-sheeting-details (data ox oy / prev rp wp lockR lockW y rSig wSig same et gx iThk iTyp iDen mzOnSd)
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
  (setq *PEB-BUB-FIT* (peb-bub-fit "DETAILS"))

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
  ;; ── INSULATION ROLL, under the panel column, ONLY where the BSF declares one ────────
  (setq iThk (atof (peb-tb-or (MSPL-Get-Str data "PN_ROOF_INSUL_THK") "0")))
  (if (<= iThk 0.0)
    (setq iThk (atof (peb-tb-or (MSPL-Get-Str data "PN_WALL_INSUL_THK") "0"))))
  (if (> iThk 0.0)
    (progn
      (setq iTyp (peb-tb-or (MSPL-Get-Str data "PN_ROOF_INSUL_TYPE")
                            (peb-tb-or (MSPL-Get-Str data "PN_WALL_INSUL_TYPE") "FIBERGLASS")))
      (setq iDen (peb-tb-or (MSPL-Get-Str data "PN_ROOF_INSUL_DENS")
                            (peb-tb-or (MSPL-Get-Str data "PN_WALL_INSUL_DENS") "")))
      (vl-catch-all-apply (function (lambda ()
        (peb-sd-insulation ox -900.0 iThk
          (strcat (rtos iThk 2 0) " MM  " (strcase iTyp)
                  (if (/= iDen "") (strcat "  |  " iDen " KG/M3") ""))))))))

  ;; SECOND COLUMN, not a third row.  Stacking the gutter under the panels made the sheet
  ;; tall and narrow: the fit rule then scaled everything down to suit the height, the
  ;; drawings shrank, and the DETAILS heading was stranded in the middle of the page.  Beside
  ;; them the sheet stays close to the drawing box's own 1.10:1, which is what fills it.
  ;; GUTTER GAUGE IS 0.50 mm - RULE 4B.51 (owner 30-Aug: "Gutters thickness is 0.50mm by
  ;; default", "not 1.20mm").  It printed 1.2 because that is what the ONE approval drawing the
  ;; profile was TRACED from (job 59, PAECO) happened to say.  A trace proves the SHAPE; the
  ;; gauge is a commercial standard and does not travel with it.  There is no BSF field for it,
  ;; so it is a literal - if a job ever needs a heavier gutter, ADD THE FIELD rather than edit
  ;; this string, which would re-commit every other proposal to that job's gauge.
  (setq et (strcase (peb-tb-or (MSPL-Get-Str data "BP_EAVE_TYPE") "")))
  (setq gx (+ ox 1500.0))
  (setvar "CLAYER" "TEXT")
  (cond
    ((vl-string-search "VALLEY" et)
      (setvar "CECOLOR" "5")
      (txt-bold "ML" (list gx 170.0) (peb-th 'LABEL) 0 "VALLEY GUTTER")
      (setvar "CECOLOR" "BYLAYER")
      (txt "ML" (list gx 0.0) (peb-th 'ANNOT) 0 "SECTION PER THE APPROVAL DRAWING.")
      (txt "ML" (list gx -160.0) (peb-th 'ANNOT) 0 "0.50 mm PPG.L  |  COLOUR AS SHEET"))
    ((vl-string-search "GUTTER" et)
      (setvar "CECOLOR" "5")
      (txt-bold "ML" (list gx 170.0) (peb-th 'LABEL) 0 "EAVE GUTTER")
      (setvar "CECOLOR" "BYLAYER")
      ;; the trim is 203 deep; 0.55 gives it the same visual weight as a panel section
      (vl-catch-all-apply (function (lambda ()
        (peb-sd-eave-gutter (+ gx 120.0) 0.0 0.55))))
      ;; kept short so the column does not run into the title strip
      (txt "ML" (list gx -200.0) (peb-th 'ANNOT) 0 "165 BASE  |  203 DEEP")
      (txt "ML" (list gx -360.0) (peb-th 'ANNOT) 0 "0.50 mm PPG.L  |  3 M")
      (txt "ML" (list gx -520.0) (peb-th 'ANNOT) 0 "COLOUR AS SHEET")))

  ;; -- RULE 4B.43 IS PARKED, NOT DELETED (owner 29-Aug) -------------------------------
  ;; "Mezzanine Floor Detail is not the one we developed last time. for the time being
  ;;  remove it."  The build-up drawn here was reconstructed from the cross section's own
  ;;  layering; it is NOT the detail already developed for this, which we have not found.
  ;;  Rather than ship a second, different detail of the same floor - which is the exact
  ;;  contradiction rule 4B.7 exists to prevent - the call is switched off and the drawer
  ;;  (peb-sd-mezz-floor) left in place, ready for the real geometry.
  ;;  The sheet therefore reverts to exactly what it was, heading included.
  (setq mzOnSd nil)

  (setvar "CECOLOR" "5")
  ;; The heading sits BELOW everything on the sheet, at a fixed depth clear of both
  ;; columns.  Hanging it off the panel column's own y put it in the middle of the page
  ;; as soon as a second column was added beside it (owner 27-Aug).  With the mezzanine
  ;; detail present it drops again, for the same reason.
  (txt-bold "MC" (list (+ ox 900.0) (if mzOnSd -3150.0 -1450.0)) (peb-th 'HEADING) 0
            "DETAILS")
  (setvar "CECOLOR" "BYLAYER")
  (setvar "CLAYER" prev)
  (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data "DETAILS")))))


;; ============================================================================
;;  MEZZANINE FLOOR - SECTIONAL DETAIL  (rule 4B.43, owner 29-Aug)
;;  "Also we developed the Sectional Details of Mezzanine Floor Showing the Concrete Etc."
;;
;;  The build-up existed only INSIDE the cross section, at building scale, where a 125 mm slab
;;  on a 45 mm deck plots at a third of a millimetre - drawn, and unreadable.  The DETAILS sheet
;;  is where a thing too small to read at building scale gets shown at its own scale, and half
;;  of that sheet was empty.
;;
;;  The cut runs ACROSS the joists, so joists appear as cut I-sections and the main beam - which
;;  runs perpendicular to them - as the deeper section at the left.  Joist tops are FLUSH with
;;  the beam top (rule 4B.32: joists never sit ON the main beams).
;;
;;  Every dimension is the BSF's, not a house constant: slab from MZ<n>_FLOOR_THK, and the beam
;;  depth from the two stated levels exactly as the cross section derives it (rule 4B.7), so the
;;  detail, the section and the mezzanine sheet cannot disagree about the same floor.
;; ============================================================================
(defun peb-sd-mezz-floor (ox oy data / thk bd jd ffl chb W deckT top bot i jx n lab prev)
  (setq prev (getvar "CLAYER"))
  (setq thk (MSPL-Get-Num data "MZ1_FLOOR_THK"))
  (if (or (null thk) (<= thk 0.0)) (setq thk 150.0))
  (setq ffl (MSPL-Get-Num data "MZ1_CH_FFL_SLAB")
        chb (MSPL-Get-Num data "MZ1_CH_FFL_BEAM")
        deckT 45.0 bd 700.0)
  (if (and ffl chb (> (- ffl chb deckT thk) 150.0) (< (- ffl chb deckT thk) 2500.0))
    (setq bd (- ffl chb deckT thk)))
  (setq jd (* bd 0.55) W 2600.0 top oy bot (- oy deckT))
  ;; --- concrete slab, with a light stipple so it reads as concrete, not as a void ---
  (setvar "CLAYER" "COMP-MEZZ")
  (command "_.RECTANG" (list ox top) (list (+ ox W) (+ top thk)))
  (setq i 0)
  (while (< i 13)
    (setq jx (+ ox 90.0 (* i (/ W 13.0))))
    (command "_.LINE" (list jx (+ top (* thk 0.25))) (list (+ jx (* thk 0.5)) (+ top (* thk 0.75))) "")
    (setq i (1+ i)))
  ;; --- 0.70 mm profiled deck: a ribbed line carrying the slab ---
  (setvar "CLAYER" "COMP-MEZZ-JOIST")
  (setq i 0)
  (while (< i 10)
    (setq jx (+ ox (* i (/ W 10.0))))
    (command "_.PLINE" (list jx top) (list (+ jx 50.0) bot)
             (list (+ jx 145.0) bot) (list (+ jx 195.0) top) (list (+ jx (/ W 10.0)) top) "")
    (setq i (1+ i)))
  ;; --- MAIN BEAM at the left: cut I-section, 350 flange ---
  (setvar "CLAYER" "COMP-MEZZ-BEAM")
  (command "_.RECTANG" (list (- (+ ox 260.0) 175.0) (- bot 60.0)) (list (+ ox 260.0 175.0) bot))
  (command "_.RECTANG" (list (- (+ ox 260.0) 30.0) (- bot bd -60.0)) (list (+ ox 260.0 30.0) (- bot 60.0)))
  (command "_.RECTANG" (list (- (+ ox 260.0) 175.0) (- bot bd)) (list (+ ox 260.0 175.0) (- bot bd -60.0)))
  ;; --- JOISTS: cut I-sections, 175 flange, tops FLUSH with the beam (rule 4B.32) ---
  (setvar "CLAYER" "COMP-MEZZ-JOIST")
  (setq n 1)
  (while (<= n 2)
    (setq jx (+ ox 260.0 (* n 1050.0)))
    (command "_.RECTANG" (list (- jx 87.5) (- bot 45.0)) (list (+ jx 87.5) bot))
    (command "_.RECTANG" (list (- jx 20.0) (- bot jd -45.0)) (list (+ jx 20.0) (- bot 45.0)))
    (command "_.RECTANG" (list (- jx 87.5) (- bot jd)) (list (+ jx 87.5) (- bot jd -45.0)))
    (setq n (1+ n)))
  ;; --- notes.  ANNOT is the rung the rest of this sheet's notes use. ---
  (setvar "CLAYER" "TEXT")
  (setvar "CECOLOR" "5")
  (txt-bold "ML" (list ox (+ top thk 420.0)) (peb-th 'LABEL) 0 "MEZZANINE FLOOR - SECTIONAL DETAIL")
  (setvar "CECOLOR" "BYLAYER")
  (txt "ML" (list (+ ox W 220.0) (+ top (* thk 0.5))) (peb-th 'ANNOT) 0
       (strcat (rtos thk 2 0) " mm R.C. SLAB"))
  (txt "ML" (list (+ ox W 220.0) (- top 230.0)) (peb-th 'ANNOT) 0
       "0.70 mm PROFILED STEEL DECK")
  (txt "ML" (list (+ ox W 220.0) (- bot (* bd 0.55))) (peb-th 'ANNOT) 0
       (strcat "MAIN BEAM  " (rtos bd 2 0) " DEEP  |  350 FLANGE"))
  (txt "ML" (list (+ ox W 220.0) (- bot (* bd 0.55) 260.0)) (peb-th 'ANNOT) 0
       (strcat "JOISTS  " (rtos jd 2 0) " DEEP  |  175 FLANGE, TOPS FLUSH"))
  (txt "ML" (list ox (- bot bd 320.0)) (peb-th 'ANNOT) 0
       "SLAB, DECK & REINFORCEMENT PER THE APPROVAL DRAWING.")
  (setvar "CLAYER" prev)
  (princ))

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
