;;; ============================================================================
;;;  MAIMAAR_PEB_Accessory.lsp — WALL / ROOF ACCESSORY GEOMETRY
;;;  STEP 1 of 5: THE LIGHT PANEL   (WALL LIGHT on a wall · SKY LIGHT on the roof)
;;; ============================================================================
;;;
;;;  WHY THIS FILE EXISTS (owner, 3-Sep-2026).
;;;
;;;  Every accessory placed on an elevation was drawn as a PLAIN RECTANGLE. The whole of
;;;  MAIMAAR_PEB_Elevation.lsp's placement loop is a RECTANG plus, if the type says "door",
;;;  two diagonals. A translucent light panel, a louver and a sliding door all came out
;;;  identical. This module starts closing that, one accessory at a time, the way the
;;;  staircase was built: its own module, its own sample sheet, verified alone first.
;;;
;;;  ── ONE PRODUCT, TWO NAMES ────────────────────────────────────────────────────────────
;;;  "on Wall it is called Wall Light not Skylight, though both have the same material — as
;;;   we say purlins and girts" (owner). Same panel, same fiberglass, same profile; the NAME
;;;   follows the surface, exactly as one cold-formed Z is a purlin on the roof and a girt on
;;;   the wall. Every drawer here takes the name as an argument and hard-codes neither.
;;;
;;;  ── THE PROFILE FOLLOWS THE SHEETING ──────────────────────────────────────────────────
;;;  "on walls wall lights will be always Standard S-Profile, but Skylight can be Seamlock or
;;;   S-Profile" (owner). Lock seam is a ROOF-ONLY sheeting option (panelDefaults.js), so a
;;;   wall can never be seam-lock and the wall light needs no profile choice at all.
;;;
;;;      WALL LIGHT   always  Standard S Profile 35-250 · 1000 net cover · 1.5 mm
;;;      SKY LIGHT    either  Standard S Profile 35-250 · 1000 net cover · 1.5 mm
;;;                       or  the LOCK SEAM sheet profile · 470 cover · 2.0 mm
;;;
;;;  The S profile is NOT re-authored here — it calls peb-sd-sprofile, the very function the
;;;  DETAILS sheet draws the steel sheet with, so the panel and the sheet beside it can never
;;;  disagree. A seam-lock roof's sky light does the same thing with peb-sd-lockseam: same
;;;  profile as the sheet, the MATERIAL is the only difference (owner 3-Sep-2026).
;;;
;;;  ── WHY IT LOOKS DIFFERENT FROM THE SHEETING: PEN, NOT COLOUR ─────────────────────────
;;;  "once it is converted in pdf, it should look bit different from sheeting" (owner).
;;;  THE PROPOSAL PDF PLOTS MONOCHROME — MAIMAAR_PEB_PDF.lsp:90 and :140, and
;;;  drawingRender.ts:394 and :1263, all set monochrome.ctb with PlotWithPlotStyles. Every ACI
;;;  colour collapses to black on the deliverable, so the cyan layer carries NO information
;;;  there. Only lineweight does.
;;;
;;;      steel sheeting      SHEETING     0.09 mm   (PEB_LAYERS.csv)
;;;      light panel outline SKY/WALL LIGHT 0.50 mm (PEB_LAYERS.csv, added 3-Sep-2026)
;;;      translucency fill   same layer   0.05 mm   (peb-sky-hatch hard-codes (cons 370 5))
;;;
;;;  A 5.5x pen ratio against the sheet, and a legal ISO 128-20 line-group pair. The outline
;;;  ALSO carries (cons 370 50) on the entity, so it is right even in a drawing whose layer
;;;  table did not come from the standard.
;;;
;;;  ── STANDING RULES OBSERVED ──────────────────────────────────────────────────────────
;;;   * Layers come from PEB_LAYERS.csv — DIMENSIONS (not "DIM"), GIRTS (not "GIRT"),
;;;     SHEETING at ACI 4. An ad-hoc layer inherits no lineweight and drifts from the standard.
;;;   * NO hand-driven LAYER / STYLE commands: an `acad` command left open eats the rest of
;;;     the script silently and catches nothing.
;;;   * Dimensions are LINE + TEXT primitives, not DIM commands, so a DIMSTYLE missing from a
;;;     standalone run cannot stall the script.
;;;   * mm, 1:1 in model space. peb-th carries the text ladder.
;;; ============================================================================

;; ---- the standard panel (components.js LIGHT_SPEC) --------------------------
(defun peb-acc-light-w    () 1000.0)     ; net cover, crown to crown — never a variable
(defun peb-acc-light-l    () 3250.0)     ; standard length; the BSF may shorten it
(defun peb-acc-light-thk  () 1.5)        ; fiberglass skin, S-profile panel
(defun peb-acc-sl-thk     () 2.0)        ; seam-lock skylight — MSPL-169 / MSPL-224 as built
;; THE SECTION IS THE SHEETING PROFILE — 100% (owner 3-Sep-2026). Not "the same numbers", the
;; SAME SOURCE: peb-sheet-rib-pitch / -rib-height live beside peb-sd-sprofile in
;; MAIMAAR_PEB_Framing.lsp and are what the DETAILS sheet draws the steel sheet from. Change the
;; sheet profile there and this panel follows in the same commit. The literals below are only a
;; fallback for a standalone load where Framing.lsp is not present.
(defun peb-acc-rib-pitch  ()
  (if (boundp 'peb-sheet-rib-pitch)  (peb-sheet-rib-pitch)  250.0))
(defun peb-acc-rib-height ()
  (if (boundp 'peb-sheet-rib-height) (peb-sheet-rib-height)  35.0))
(defun peb-acc-light-mat  () "FIBERGLASS")
(defun peb-acc-lw         () 50)         ; 0.50 mm - the pen that separates it from the sheet
;; GLASS COLOUR (owner 3-Sep-2026: "color should be translucent/Glass Type ... the drawings
;; should look real"). ACI 151 is the pale blue the trade uses for glazing; saturated cyan (4)
;; read as a solid plastic slab. It changes NOTHING on the plotted PDF - that is monochrome -
;; but the DWG the draughtsman works in, and any colour print, now reads as glass.
(defun peb-acc-glass-col  () 151)
;; ...and the sheen is FINER than the roof plan's. peb-draw-skylights-per-bay hatches a plan
;; symbol at cover/4 - four fat stripes, right for a 1 m mark on a roof plan seen small. On a
;; panel drawn at size those stripes read as stripes, not as glass, so the elevation uses /8.
;; DENSE ENOUGH TO READ AS A SOLID GLOSSY SHEET (owner 3-Sep-2026: "It must look like solid
;; sheet with glossy color slightly different from wall sheeting").
;;
;; It is a LINE FILL, not a filled region, and that is deliberate. A true SOLID/HATCH fill
;; plots BLACK on monochrome.ctb - the panel would become a black rectangle on the very PDF
;; the customer receives, which is worse than the stripes it replaced. Real HATCH entities do
;; not survive `acad /b` either (the roof plan says so where it hatches skylights).
;; So the fill is 25 lines across the cover at the lightest pen in the standard (0.05): on
;; screen, in the glass colour, it reads as one glossy sheet; on the monochrome plot it reads
;; as a light tint, still plainly different from the plain white steel sheeting beside it.
;; THE RIBS ARE A SCALE PARAMETER TOO (owner 4-Sep-2026: "sid walls sheeting is still
;; showing the Grids").
;; The panel is profiled, so at size it carries a rib line every 250. On the WALL SHEETING
;; ELEVATION at 1:300 that is a line every 0.8 mm - and, worse, the plain steel sheeting it sits
;; in draws ONE line per 1000 PANEL JOINT. So the light band came out four times denser than the
;; cladding around it, and 44 of them in a row read as a grid of little squares.
;; Rule: at proposal scale the band shows its OUTLINE and its PANEL JOINTS, exactly like the
;; sheeting beside it. The ribs stay for the library sample and any detail drawn at size.
(defun peb-acc-ribs-on ()
  (not (and (boundp '*PEB-ACC-NO-RIBS*) *PEB-ACC-NO-RIBS*)))

(defun peb-acc-sheen-div  ()
  ;; SCALE PARAMETER, NOT A SECOND OPINION. 25 is right for a panel drawn at size. A roof plan
  ;; shows the same panel as a ~1000 x 3000 mark on a 48 m building, where 25 lines across the
  ;; cover smear into a solid block - so the ROOF PLAN sets *PEB-ACC-SHEEN-DIV* to 4 around its
  ;; call. One drawer, one geometry, the density chosen for the scale it is seen at; that is
  ;; different from the two independent implementations this replaced.
  (if (and (boundp '*PEB-ACC-SHEEN-DIV*) *PEB-ACC-SHEEN-DIV*) *PEB-ACC-SHEEN-DIV* 25.0))

;; The layer for a surface. "ROOF" -> SKY LIGHT, any wall -> WALL LIGHT (owner: purlins/girts).
;; ── RULE G1: ANCHORED GIRT DIVISION ─────────────────────────────────────────────────────
;;
;;   "We have to adjust the girts to accommodate the WL Wall Lights within the range of spacing
;;    of girts, and if it is not possible, we need to add more girts to have the same level."
;;                                                              - owner, 4-Sep-2026
;;
;; THE PANEL IS FIXED; THE GIRTS MOVE TO MEET IT. That is the opposite of what the engine did:
;; peb-fr-wallface stepped a blind 1400 ladder up from the dado and the light band was placed
;; afterwards with no relationship to it. A fiberglass panel is a bought product fixed along BOTH
;; edges - it cannot be asked to land wherever the ladder happens to stop.
;;
;; ANCHORS - levels a girt MUST land on:
;;    1. the top of the dado          (the sheeting base line)
;;    2. the band SILL                -+ "needs the Girts on Both Sides ... up and down"
;;    3. the band HEAD                -+
;;    4. the TOP GIRT = clear - 200   the drop clears the haunch fillet
;;
;; A GIRT MAY NEVER SIT ABOVE THE COLUMN IT FIXES TO. The column stops at the clear height; above
;; it there is nothing to fix to at either end of the wall, which is exactly the defect this
;; replaces - the old ceiling was `clear + haunch`, up to 1100 mm too high.
;;
;; DIVISION between consecutive anchors:
;;      N = ceil(zone / MAX), spacing = zone / N, insert N-1 intermediates.
;; The ceil IS the "add more girts" clause: a zone too tall for one space gets however many it
;; takes to bring every space back inside the range. Anchors are never moved to tidy the
;; arithmetic - girts are added instead.
;;
;; Returns the levels ABOVE the dado top, ascending. The dado top itself is the sheeting base
;; line and is drawn by the caller.
(defun peb-acc-girt-max () 1400.0)      ; house maximum girt spacing
(defun peb-acc-girt-drop () 200.0)      ; top girt below the clear height

(defun peb-acc-girt-levels (dadoTop clearHt sill head / top anch out i lo hi zone n k)
  (setq top (- clearHt (peb-acc-girt-drop)))
  (if (<= top dadoTop) (setq top (+ dadoTop 1.0)))
  ;; collect the anchors that actually lie in the sheeted zone
  (setq anch (list dadoTop top))
  (if (and sill (> sill dadoTop) (< sill top)) (setq anch (cons sill anch)))
  (if (and head (> head dadoTop) (< head top)) (setq anch (cons head anch)))
  ;; sort ascending and drop duplicates (a band head that coincides with the top girt is ONE
  ;; anchor, not two - a duplicate would divide a zero-height zone)
  (setq anch (vl-sort anch '(lambda (a b) (< a b))))
  (setq out nil i 0)
  (while (< (1+ i) (length anch))
    (setq lo (nth i anch) hi (nth (1+ i) anch) zone (- hi lo))
    (if (> zone 1.0)
      (progn
        (setq n (fix (+ 0.999 (/ zone (peb-acc-girt-max)))))   ; ceil
        (if (< n 1) (setq n 1))
        (setq k 1)
        (while (<= k n)
          (setq out (cons (+ lo (* k (/ zone n))) out))
          (setq k (1+ k)))))
    (setq i (1+ i)))
  ;; ascending, de-duplicated to the millimetre
  (setq out (vl-sort out '(lambda (a b) (< a b))))
  (setq anch nil)
  (foreach k out
    (if (or (null anch) (> (abs (- k (car anch))) 1.0)) (setq anch (cons k anch))))
  (reverse anch))

;; ── NO LIGHT PANELS IN THE CORNERS (STANDING RULE, owner 4-Sep-2026) ────────────────────
;;
;;   "Do NOT provide the wall lights on both side corners. The reason is the High Wind Vortices
;;    there and there are chances of High Wind Pressure on Corners."
;;
;; This is a structural rule, not a drafting preference. At a windward corner the flow separates
;; and sheds vortices, and the local suction there is far higher than over the middle of the
;; wall - which is exactly why every wind code gives a wall its own CORNER ZONE with a heavier
;; pressure coefficient. A fiberglass light panel is the weakest sheet on the building; putting
;; it where the peak suction lands is asking for it to be the first thing to go.
;;
;; The zone width is the codes' own `a` (ASCE 7 / MBMA end zone), so the drawing agrees with what
;; the frame was designed to:
;;
;;      a = min(0.10 x least plan dimension, 0.4 x eave height)
;;      but not less than max(0.04 x least plan dimension, 900 mm)
;;
;; For 22.86 x 5.486 m that is min(2286, 2194) = 2194, floored at max(914, 900) -> a = 2194 mm.
;; Every wall keeps `a` clear at BOTH ends; the band lives in the interior zone only.
(defun peb-acc-corner-zone (leastPlanMm eaveMm / a floorA)
  (if (or (null leastPlanMm) (<= leastPlanMm 0.0)) (setq leastPlanMm 20000.0))
  (if (or (null eaveMm) (<= eaveMm 0.0)) (setq eaveMm 6000.0))
  (setq a     (min (* 0.10 leastPlanMm) (* 0.4 eaveMm))
        floorA (max (* 0.04 leastPlanMm) 900.0))
  (max a floorA))

(defun peb-acc-light-layer (surf)
  (if (and surf (wcmatch (strcase surf) "*ROOF*")) "SKY LIGHT" "WALL LIGHT"))
;; ...and the NAME that goes in a callout, on the same rule.
;; "FIBERGLASS WALL LIGHT", never a bare "wall light" (owner 4-Sep-2026: "use the Word -
;; Fiberglass Wall Lights - to avoid the confusion"). On a drawing that also carries electrical
;; symbols, "wall light" reads as a luminaire. The roof one is unambiguous, so it stays SKY LIGHT.
(defun peb-acc-light-name (surf)
  (if (and surf (wcmatch (strcase surf) "*ROOF*")) "SKY LIGHT" "FIBERGLASS WALL LIGHT"))

;; A closed polyline carrying an explicit pen (peb-comp-poly sets none, so a light panel drawn
;; through it would inherit LWDEFAULT 0.25 and read almost like the 0.09 sheet).
(defun peb-acc-poly (pts lw / e)
  (setq e (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 (getvar "CLAYER"))
                (cons 370 lw) (cons 100 "AcDbPolyline") (cons 90 (length pts)) (cons 70 1)))
  (foreach p pts (setq e (append e (list (list 10 (car p) (cadr p))))))
  (entmake e))

(defun peb-acc-line (x0 y0 x1 y1 lay lw)
  (entmake (list (cons 0 "LINE") (cons 8 lay) (cons 370 lw)
                 (list 10 x0 y0 0.0) (list 11 x1 y1 0.0))))

;; ---------------------------------------------------------------------------
;;  THE PANEL IN ELEVATION — outline (heavy pen), the rib lines that say it is profiled,
;;  and the 45-degree fill that says it is translucent. Ribs sit ON the pitch lines, matching
;;  peb-sd-sprofile, so both side laps land on a rib.
;; ---------------------------------------------------------------------------
;;  FLAT MODE - THE PANEL *IS* SHEETING (owner 4-Sep-2026: "Side Wall Sheeting Grid box removal
;;  is very important. It Should show as Sheeting").
;;
;;  On a wall sheeting elevation the cladding drawer has ALREADY laid a vertical joint line every
;;  1000 from the brick top clean through to the eave - measured on B-01, x = 534,651 / 535,651 /
;;  536,651 ... each running 3,048 -> 6,480. The fiberglass panel is the SAME profile in a
;;  different material and sits in that same run of joints.
;;
;;  So everything this drawer normally puts on the panel is duplication or worse:
;;    * its 4-sided outline repeats those joints as its two side edges, and adds a horizontal
;;      top and bottom PER PANEL - 44 panels in a row = 44 closed boxes;
;;    * the 45-degree sheen then draws diagonals inside each box, and a box with diagonals is
;;      the DOOR symbol on this very sheet, not glazing;
;;    * the rib lines at 250 came in four times denser than the cladding beside them.
;;  Together that is the grid being reported. It is not a density problem to be tuned - the
;;  geometry itself is wrong at this scale.
;;
;;  FLAT MODE draws the band EDGE ONLY: the sill line and the head line across this panel's
;;  width. Butted panel to panel they form the two continuous lines that say "fiberglass from
;;  here to here", with the sheeting's own joints running through them. That is how the band
;;  appears on an approval drawing, and it is what "show as sheeting" means.
;;  The full panel - outline, ribs, sheen - is unchanged for the library sample and for anything
;;  drawn at size, where all three read correctly.
(defun peb-acc-elev-flat ()
  (and (boundp '*PEB-ACC-ELEV-FLAT*) *PEB-ACC-ELEV-FLAT*))

(defun peb-acc-light-elev (x0 y0 w h surf / pit i c lay lw)
  (setq pit (peb-acc-rib-pitch) lay (peb-acc-light-layer surf) lw (peb-acc-lw))
  (peb-comp-layer lay (peb-acc-glass-col))
  (if (peb-acc-elev-flat)
    (progn
      (peb-acc-line x0 y0        (+ x0 w) y0        lay lw)     ; sill of the band
      (peb-acc-line x0 (+ y0 h)  (+ x0 w) (+ y0 h)  lay lw)     ; head of the band
      ;; ── AND ITS TWO SIDE EDGES: A LIGHT IS A PANEL IN THE RUN ─────────────────────────
      ;; PD_RULEBOOK S17: "A light panel is a CLADDING item: it replaces a sheet on the module,
      ;; it is not an opening cut into one." Maimaar's own erection sheets say the same in the
      ;; field - WL-1/(1700) sits inline in the panel sequence beside SWS-5/(628), marked and
      ;; lengthed exactly like a sheet.
      ;;
      ;; Splitting the cladding into three courses (the sheet really does break at the
      ;; wall-light girts) left this band with NO vertical lines at all, so 44 separate 1000
      ;; panels drew as one undivided strip. These are the panel's own side edges; because the
      ;; panels butt, they land on the same 1000 stations as the courses above and below and
      ;; the vertical rhythm runs unbroken brickwork to eave - which is S43's "one line per
      ;; panel joint at the cover width" applied to the band as well as the steel.
      ;;
      ;; On the WALL LIGHT pen (0.50), not CLADDING (0.18): the band is a different material
      ;; and on a monochrome plot lineweight is the only thing that can say so.
      (peb-acc-line x0 y0 x0 (+ y0 h) lay lw)                   ; left edge
      (peb-acc-line (+ x0 w) y0 (+ x0 w) (+ y0 h) lay lw)       ; right edge
      ;; ── IT MUST READ AS NATURAL LIGHT (owner 4-Sep-2026: "show the wall lights like natural
      ;;    lighting") ────────────────────────────────────────────────────────────────────────
      ;; Sill and head alone say "a gap in the sheeting"; they do not say DAYLIGHT COMES THROUGH
      ;; HERE. The single-diagonal wash is the standard elevation convention for glazing, and on
      ;; a monochrome plot - where colour carries nothing and only lineweight survives - it is
      ;; the only thing that can say it.
      ;;
      ;; DENSITY IS THE WHOLE PROBLEM, and it is why this was switched off rather than tuned.
      ;; peb-sky-hatch takes MODEL mm. The at-size default is cover/25 = 40 mm, which on a 48.77 m
      ;; elevation at 1:300 lands the lines 0.13 mm apart: solid black smear, worse than nothing.
      ;; cover/3 = 333 mm is about 1.1 mm on the same sheet - three or four strokes across a
      ;; panel, which reads as glass and still plots as a tint against the plain white steel.
      ;; peb-sky-hatch IS the fiberglass hatch - the same routine the roof skylights use, so the
      ;; wall light and the roof light are hatched as the one material they are (owner 4-Sep-2026:
      ;; "the wall lights are made of fiberglass so use the same material for Hatching").
      (peb-sky-hatch x0 y0 (+ x0 w) (+ y0 h) (/ w 3.0)))
    (progn
      (peb-acc-poly (list (list x0 y0) (list (+ x0 w) y0)
                          (list (+ x0 w) (+ y0 h)) (list x0 (+ y0 h))) lw)
      (setq i 1)
      (while (and (peb-acc-ribs-on) (< (* i pit) (- w 1.0)))
        (setq c (+ x0 (* i pit)))
        (peb-acc-line c y0 c (+ y0 h) lay lw)
        (setq i (1+ i)))
      (peb-sky-hatch x0 y0 (+ x0 w) (+ y0 h) (/ w (peb-acc-sheen-div)))))  ; 0.05 mm, lightest pen
  (princ))

;; ---------------------------------------------------------------------------
;;  THE S-PROFILE PANEL IN SECTION — the REAL Standard S Profile 35-250, borrowed whole from
;;  the DETAILS sheet so the light panel and the steel sheet are the same section.
;; ---------------------------------------------------------------------------
(defun peb-acc-light-profile (x0 y0 n surf / pts prev lay)
  (setq lay (peb-acc-light-layer surf))
  (peb-comp-layer lay (peb-acc-glass-col))
  (setq prev (if (boundp '*PEB-SPROF-LAYER*) *PEB-SPROF-LAYER* nil))
  (setq *PEB-SPROF-LAYER* lay)
  (setq pts (peb-sd-sprofile x0 y0 n (peb-acc-rib-pitch) (peb-acc-rib-height)))
  (setq *PEB-SPROF-LAYER* prev)
  ;; peb-sd-sprofile draws with plain LINEs at no explicit pen; re-draw the run as one heavy
  ;; polyline so the section reads at 0.50 like the rest of the panel.
  (peb-comp-layer lay (peb-acc-glass-col))
  (peb-acc-poly pts (peb-acc-lw))
  pts)

;; ---------------------------------------------------------------------------
;;  THE SEAM-LOCK SKY LIGHT IN SECTION — TRACED from Maimaar's own approval drawings,
;;  MSPL-169 (PAECO Kasur, 2025) and MSPL-224 (PAECO Kasur, 2026), both of which carry:
;;
;;               36
;;                      100
;;        132°    124°          75
;;   152    134    65    134    152
;;      SKYLIGHT PROFILE : THK. 2mm
;;
;;  One rib in a 637-wide panel: pan 152 · web 134 · crown 65 · web 134 · pan 152, rib 75 deep.
;;  This is the skylight made to sit WITH lock-seam sheeting; it is NOT peb-sd-lockseam, which
;;  is the lock-seam SHEET itself (470 cover, ribs at 155 centres). Two different products on
;;  one roof, so two different sections.
;;
;;  The dimensions were read off the PDF's extracted text, not off its vectors — so they are
;;  reproduced exactly and the shape between them is drawn straight. Correct dimensions under
;;  a straight-line shape is honest (rulebook 4B.24); inventing dimensions would not be.
;; ---------------------------------------------------------------------------
;; ── THE SEAM-LOCK SKY LIGHT — SAME PROFILE, MATERIAL IS THE ONLY DIFFERENCE ─────────────
;;
;; "same profile - only material difference" (owner, 3-Sep-2026). So this does NOT carry a
;; bespoke section. It calls peb-sd-lockseam — the lock-seam SHEET profile already traced from
;; the owner's own DXF (470 cover, ribs at 155 centres, Framing.lsp:2753) — and changes only
;; what makes it a light panel: the layer, the glass colour, the 0.50 pen and the 2.0 mm skin.
;; Exactly what peb-acc-light-profile does for the S-profile roof and wall. One profile per
;; building's sheeting, one drawer, no second section to keep in step (rules 1 and 3).
;;
;; WHAT THE PAECO SHEET ACTUALLY SHOWS, and why it is not drawn here.
;; MSPL-224 / MSPL-169 carry a SEPARATE "SKYLIGHT PROFILE : THK. 2mm" beside the lock-seam
;; sheet. Measured off the imported DXF (not off the dimension text — rule 19) it is
;;      152 big rib | 134 pan | 65 small stiffener rib | 134 pan | 152 big rib  = 637 overall
;;      big rib 75 deep · small rib 36 deep · crown 25 · COVER 484 crown-to-crown
;; with a 25x25x1.2 tube on the middle rib. That is a supplier's own product, and the reading
;; is recorded in README.md so the measurement is not lost. The house rule is the one above.
;; ── THE PROFILE DISPATCHER — the BSF decides, the drawer obeys ──────────────────────────
;; RA_SKY_PROFILE carries the BSF's answer ("Standard S Profile 35-250" or "Lock Seam Profile"),
;; defaulted from the building's own roofPanelProfile because the panel IS the sheet profile and
;; only the material differs. This is the single place that reads it, so no drawer has to guess.
;; A WALL is never lock seam (roof-only sheeting option), so `peb-acc-light-profile` is used
;; directly there and this dispatcher is for the roof.
(defun peb-acc-light-section (x0 y0 n surf profile)
  (if (and profile (wcmatch (strcase profile) "*LOCK*SEAM*"))
    (peb-acc-sl-profile x0 y0 surf)
    (peb-acc-light-profile x0 y0 n surf)))

;; ...and the thickness that goes with it: 1.5 mm on an S profile, 2.0 on a lock seam.
(defun peb-acc-thk-for (profile)
  (if (and profile (wcmatch (strcase profile) "*LOCK*SEAM*"))
    (peb-acc-sl-thk) (peb-acc-light-thk)))

(defun peb-acc-sl-cover () 470.0)   ; the lock-seam sheet's cover — the panel matches it
(defun peb-acc-sl-rib   ()  38.0)   ; the height peb-sd-panel passes for a lock seam

(defun peb-acc-sl-profile (x0 y0 surf / prev lay)
  (setq lay (peb-acc-light-layer surf))
  (peb-comp-layer lay (peb-acc-glass-col))
  (setq prev (if (boundp '*PEB-SPROF-LAYER*) *PEB-SPROF-LAYER* nil))
  (setq *PEB-SPROF-LAYER* lay)
  (peb-sd-lockseam x0 y0 1 (peb-acc-sl-cover) (peb-acc-sl-rib))
  (setq *PEB-SPROF-LAYER* prev)
  (princ))

;; ---------------------------------------------------------------------------
;;  Plain 2-tick dimensions, from primitives. Layer DIMENSIONS (the standard), not "DIM".
;; ---------------------------------------------------------------------------
(defun peb-acc-dim-h (x0 x1 y off txtstr / yy ts t1)
  (setq ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0) yy (+ y off) t1 (* 120.0 ts))
  (peb-comp-layer "DIMENSIONS" 6)
  (peb-acc-line x0 y x0 yy "DIMENSIONS" 13)
  (peb-acc-line x1 y x1 yy "DIMENSIONS" 13)
  (peb-acc-line x0 yy x1 yy "DIMENSIONS" 13)
  (peb-acc-line (- x0 t1) (- yy t1) (+ x0 t1) (+ yy t1) "DIMENSIONS" 13)
  (peb-acc-line (- x1 t1) (- yy t1) (+ x1 t1) (+ yy t1) "DIMENSIONS" 13)
  ;; TEXT ON THE FAR SIDE OF THE DIMENSION LINE FROM THE OBJECT. It was always placed ABOVE the
  ;; line, so a dimension taken BELOW a panel put its text back on the panel edge - "1000 COVER"
  ;; sat across the sheet it was measuring. The sign of `off` says which way the dimension was
  ;; taken, so it also says which side the text belongs on.
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (/ (+ x0 x1) 2.0)
                  (if (< off 0.0) (- yy (* (peb-th 'ANNOT) ts 1.1))
                                  (+ yy (* (peb-th 'ANNOT) ts 0.9))))
       (peb-th 'ANNOT) 0.0 txtstr)
  (princ))

(defun peb-acc-dim-v (y0 y1 x off txtstr / xx ts t1)
  (setq ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0) xx (+ x off) t1 (* 120.0 ts))
  (peb-comp-layer "DIMENSIONS" 6)
  (peb-acc-line x y0 xx y0 "DIMENSIONS" 13)
  (peb-acc-line x y1 xx y1 "DIMENSIONS" 13)
  (peb-acc-line xx y0 xx y1 "DIMENSIONS" 13)
  (peb-acc-line (- xx t1) (- y0 t1) (+ xx t1) (+ y0 t1) "DIMENSIONS" 13)
  (peb-acc-line (- xx t1) (- y1 t1) (+ xx t1) (+ y1 t1) "DIMENSIONS" 13)
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (if (< off 0.0) (- xx (* (peb-th 'ANNOT) ts 1.1))
                                  (+ xx (* (peb-th 'ANNOT) ts 0.9)))
                  (/ (+ y0 y1) 2.0))
       (peb-th 'ANNOT) 90.0 txtstr)
  (princ))

;; ---------------------------------------------------------------------------
;;  VIEW 3 — THE SIDE WALL, WITH THE BAND IN CONTEXT (owner: "show the wall lights on the
;;  side wall"). The NSW elevation of THIS building, from the BSF: brickwork dado, the light
;;  band at its real sill, the clear-height line its head lands on, columns on the bay grid.
;; ---------------------------------------------------------------------------
(defun peb-acc-side-wall (ox oy L clear brick sill panL nbay / ts bw i x n px cover)
  (setq ts (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        bw (/ L (max 1 nbay)) cover (peb-acc-light-w))
  ;; wall outline + the sheeting face
  (peb-comp-layer "SHEETING" 4)
  (peb-acc-poly (list (list ox oy) (list (+ ox L) oy)
                      (list (+ ox L) (+ oy clear)) (list ox (+ oy clear))) 9)
  ;; columns on the bay grid
  (peb-comp-layer "COLUMNS" 1)
  (setq i 0)
  (while (<= i nbay)
    (setq x (+ ox (* i bw)))
    (peb-acc-line x oy x (+ oy clear) "COLUMNS" 50)
    (setq i (1+ i)))
  ;; the brickwork dado, by others
  (if (> brick 0.0)
    (progn
      (peb-comp-layer "BRICK-WALL" 30)
      (peb-acc-poly (list (list ox oy) (list (+ ox L) oy)
                          (list (+ ox L) (+ oy brick)) (list ox (+ oy brick))) 25)))
  ;; THE BAND — whole panels at 1000 cover, as many as the wall takes
  (setq n (fix (/ L cover)) i 0)
  (while (< i n)
    (setq px (+ ox (* i cover)))
    (peb-acc-light-elev px (+ oy sill) cover panL "NSW")
    (setq i (1+ i)))
  ;; the clear-height line the head lands on
  (peb-comp-layer "DIMENSIONS" 6)
  (peb-acc-line ox (+ oy clear) (+ ox L) (+ oy clear) "DIMENSIONS" 13)
  (peb-acc-dim-v oy (+ oy brick) ox (- (* 900.0 ts)) (strcat (rtos brick 2 0) " BRICKWORK"))
  (peb-acc-dim-v oy (+ oy sill) ox (- (* 2400.0 ts)) (strcat (rtos sill 2 0) " SILL"))
  (peb-acc-dim-v oy (+ oy clear) ox (- (* 3900.0 ts)) (strcat (rtos clear 2 0) " CLEAR HT"))
  (peb-acc-dim-h ox (+ ox L) oy (- (* 1100.0 ts))
                 (strcat (rtos L 2 0) "  (" (itoa nbay) " BAYS)"))
  ;; ONE L-LEADER, NOT A LABEL PER PANEL (owner 3-Sep-2026: "no need to mention the labeling
  ;; of wall lights - just show the wall lights ... Only L-Type ladder with Text 'Wall Light -
  ;; Type' ... Maximum Write the Qty"). A band of 48 panels annotated individually is noise; the
  ;; band reads as a band, and ONE typical callout carries the quantity.
  ;; peb-label-with-leader is the house MLEADER helper - "V" is its 3-vertex L (vertical leg off
  ;; the arrow, then a horizontal landing to the text).
  (if (boundp 'peb-label-with-leader)
    (vl-catch-all-apply
      (function (lambda ()
        (peb-label-with-leader
          (strcat (itoa n) " No. WALL LIGHT - TYPE")
          (list (+ ox L (* 2600.0 ts)) (+ oy clear (* 1200.0 ts)))   ; text lands clear of the wall
          (list (+ ox (* 2.5 cover)) (+ oy sill (/ panL 2.0)))       ; arrow on a panel in the band
          "V" (peb-th 'ANNOT)))))
    (progn (setvar "CLAYER" "TEXT")
           (txt "ML" (list (+ ox L (* 200.0 ts)) (+ oy sill (/ panL 2.0))) (peb-th 'ANNOT) 0.0
                (strcat (itoa n) " No. WALL LIGHT - TYPE"))))
  (princ))

;; ---------------------------------------------------------------------------
;;  THE SAMPLE — ONE PANEL, WITH ITS MATERIAL (owner 3-Sep-2026: "only make one sample
;;  with material").
;;
;;  It used to draw three views on one sheet: a 1000-wide panel detail, a profile section,
;;  and a 48,770-long side wall. Offsets were in mm, so the two small views collapsed into an
;;  unreadable overlap beside the wall - three scales on one page cannot work. ONE view, at
;;  one scale, is both what was asked for and the fix.
;;
;;  This is a HARNESS, not a PD sheet. The deliverable is the drawers above; the proposal set
;;  gets no detail page (owner: "We do not need to give the detail sheeting in PD").
;; ---------------------------------------------------------------------------
(defun peb-draw-light-sample (data ox oy / w h thk ts matTxt panTxt sill clear secY noteY slY)
  (setq ts  (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        w   (peb-acc-light-w) h (peb-acc-light-l) thk (peb-acc-light-thk)
        clear 5486.0)
  ;; EVERY NUMBER FROM THE BSF when the data file carries one - the BSF is the single source
  ;; of truth, and the sill it computed is drawn, never re-derived here.
  (if data
    (progn
      (if (> (MSPL-Get-Num data "WA_LIGHT_W")   0.0) (setq w   (MSPL-Get-Num data "WA_LIGHT_W")))
      (if (> (MSPL-Get-Num data "WA_LIGHT_L")   0.0) (setq h   (MSPL-Get-Num data "WA_LIGHT_L")))
      (if (> (MSPL-Get-Num data "WA_LIGHT_THK") 0.0) (setq thk (MSPL-Get-Num data "WA_LIGHT_THK")))
      (if (> (MSPL-Get-Num data "BP_EAVE_HEIGHT") 0.0) (setq clear (MSPL-Get-Num data "BP_EAVE_HEIGHT")))))
  (setq sill (MSPL-Get-Num data "WA_LIGHT_SILL"))
  (if (or (null sill) (<= sill 0.0)) (setq sill (- clear h)))
  (setq panTxt (if data (peb-tb-or (MSPL-Get-Str data "WA_LIGHT_PANEL") "") "")
        matTxt (if data (peb-tb-or (MSPL-Get-Str data "WA_LIGHT_MAT")   "") ""))
  (if (= panTxt "") (setq panTxt "SINGLE SKIN CLEAR TRANSLUCENT"))
  (if (= matTxt "") (setq matTxt (peb-acc-light-mat)))

  ;; the panel itself - profiled, translucent, at the heavy pen
  (peb-acc-light-elev ox oy w h "NSW")
  (peb-acc-dim-h ox (+ ox w) oy (- (* 620.0 ts)) (strcat (rtos w 2 0) " COVER"))
  (peb-acc-dim-v oy (+ oy h) (+ ox w) (* 620.0 ts) (rtos h 2 0))

  ;; ── THE SECTION, ALIGNED UNDER THE ELEVATION ────────────────────────────────────────────
  ;; Same scale, same x-origin, so every rib in the section lines up with its own rib line in
  ;; the elevation above - which is the whole point of putting a section under a view rather
  ;; than beside it. The rib is 35 deep against a 1000 cover, so it reads as a shallow zigzag:
  ;; that IS the profile, drawn true, not flattened for convenience.
  ;; peb-acc-light-profile delegates to peb-sd-sprofile, the same S-profile the steel sheet is
  ;; drawn with, then re-strokes it at the light panel's 0.50 pen.
  (setq secY (- oy (* 2900.0 ts)))
  (peb-acc-light-profile ox secY 4 "NSW")
  (peb-acc-dim-h ox (+ ox w) secY (- (* 1300.0 ts))
                 (strcat (rtos w 2 0) " COVER   (4 x " (rtos (peb-acc-rib-pitch) 2 0) ")"))
  (peb-acc-dim-v secY (+ secY (peb-acc-rib-height)) (+ ox w) (* 620.0 ts)
                 (rtos (peb-acc-rib-height) 2 0))
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (+ ox (/ w 2.0)) (- secY (* 3300.0 ts))) (peb-th 'ANNOT) 0.0
       "SECTION - STANDARD S PROFILE 35-250, BOTH SIDE LAPS ON A RIB")

  ;; ── THE SEAM-LOCK ROOF VARIANT — the same panel on a lock-seam roof ─────────────────────
  ;; Shown because it is the whole point of the rule: identical material, identical treatment,
  ;; the ONLY difference is which sheet profile the building has.
  (setq slY (- secY (* 6200.0 ts)))
  (peb-acc-sl-profile ox slY "ROOF")
  (peb-acc-dim-h ox (+ ox (peb-acc-sl-cover)) slY (- (* 1300.0 ts))
                 (strcat (rtos (peb-acc-sl-cover) 2 0) " COVER"))
  (setvar "CLAYER" "TEXT")
  (txt "MC" (list (+ ox (/ (peb-acc-sl-cover) 2.0)) (- slY (* 3300.0 ts))) (peb-th 'ANNOT) 0.0
       (strcat "SKY LIGHT ON A LOCK SEAM ROOF - THE LOCK SEAM SHEET PROFILE, THK "
               (rtos (peb-acc-sl-thk) 2 1) " mm"))

  ;; ONE L-leader, carrying the type - the same annotation the wall sheeting plan will use.
  (if (boundp 'peb-label-with-leader)
    (vl-catch-all-apply
      (function (lambda ()
        (peb-label-with-leader "FIBERGLASS WALL LIGHT - TYPE"
          (list (+ ox (* w 2.2)) (+ oy (* h 0.92)))
          (list (+ ox (* w 0.5)) (+ oy (* h 0.62)))
          "V" (peb-th 'ANNOT))))))

  ;; ── THE NOTE BLOCK — GENERAL INFORMATION ONLY (owner 3-Sep-2026: "Labelling Should be
  ;; General for information"). This is a TYPICAL detail in a component library, so it states
  ;; what is true of EVERY light panel, never one job's figures. A note reading "SILL 3962" is
  ;; right for MSPL-26-266 and wrong for the next building that reads the sheet; the RULE is
  ;; right for both, and the actual numbers belong on the building's own sheeting elevation.
  ;; Placed below the SECTION, not below the elevation - the section sits between them.
  (setq noteY (- slY (* 5200.0 ts)))
  (setvar "CLAYER" "TEXT")
  (txt "ML" (list ox noteY) (peb-th 'ANNOT) 0.0
       (strcat "FIBERGLASS WALL LIGHT - " panTxt " " matTxt ", " (rtos thk 2 1) " mm THK"))
  (txt "ML" (list ox (- noteY (* (peb-th 'ANNOT) ts 1.7))) (peb-th 'ANNOT) 0.0
       (strcat "STANDARD S PROFILE 35-250 - SAME PROFILE AS THE WALL SHEETING, "
               (rtos w 2 0) " NET COVER"))
  (txt "ML" (list ox (- noteY (* (peb-th 'ANNOT) ts 3.4))) (peb-th 'ANNOT) 0.0
       "THE SAME PANEL ON THE ROOF IS CALLED SKY LIGHT. A GIRT RUNS ABOVE AND BELOW THE BAND.")
  (txt "ML" (list ox (- noteY (* (peb-th 'ANNOT) ts 5.1))) (peb-th 'ANNOT) 0.0
       "PANEL REPLACES A SHEET ON THE SAME MODULE, BOTH SIDE LAPS ON A RIB -")
  (txt "ML" (list ox (- noteY (* (peb-th 'ANNOT) ts 6.8))) (peb-th 'ANNOT) 0.0
       "IT IS NOT AN OPENING CUT INTO A SHEET.")
  (txt "ML" (list ox (- noteY (* (peb-th 'ANNOT) ts 8.9))) (peb-th 'ANNOT) 0.0
       "WIDTH IS FIXED. LENGTH VARIES WITH THE BUILDING - THE HEAD ALWAYS SITS ON THE")
  (txt "ML" (list ox (- noteY (* (peb-th 'ANNOT) ts 10.6))) (peb-th 'ANNOT) 0.0
       "CLEAR HEIGHT LINE, SO SILL = CLEAR HEIGHT - PANEL LENGTH.")
  (setvar "CLAYER" "0")
  (princ))

;; ---------------------------------------------------------------------------
;;  SHEET ENTRY POINTS — the peb-<x>-from-file pattern every other sheet uses.
;; ---------------------------------------------------------------------------
(defun C:PEB-LIGHT-SAMPLE ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  ;; TEXT SCALE FOR A COMPONENT, NOT A BUILDING. peb-th's ladder is tuned for a sheet showing a
  ;; 48 m building; used unchanged on a 1000 x 1524 panel the callouts came out three times
  ;; taller than the thing they annotate. The building sheets set *PEB-TEXT-SCALE* from their
  ;; own span - the Section sheet uses max(width/35000, (H+rise)/10000) - and a component sample
  ;; scales off the
  ;; PANEL instead, so annotation is proportional to what is drawn.
  (setq *PEB-TEXT-SCALE* 0.10 *PEB-DIM-SCALE* 0.10)
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (setq data (MSPL-Read-Data *PEB-DATA-FILE*)))
  (peb-draw-light-sample data 0.0 0.0)
  (if (and data (boundp 'peb-frame-and-titleblock))
    (vl-catch-all-apply
      (function (lambda () (peb-frame-and-titleblock data "WALL LIGHT - TYPICAL DETAIL")))))
  (princ))

(defun peb-light-sample-from-file (path / prev-last prev-max-x)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  (setq *PEB-SHEET-MARK* prev-last)
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-LIGHT-SAMPLE)
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place)
    (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x)))))
  (princ))

(princ "\nMAIMAAR_PEB_Accessory.lsp loaded - (peb-light-sample-from-file ...) wall light sample.")
(princ)
