;;; ===========================================================================================
;;;  MAIMAAR PEB — OVERHEAD CRANE
;;;  Library component. PURE GEOMETRY: this file draws, it never reads the data file and never
;;;  decides placement. The sheet works out where the crane goes and hands over coordinates.
;;;  Read ../GOLDEN_RULES.md first — rule 32 (indicative, not detailed) binds this component
;;;  harder than any other: a crane is the thing a customer looks hardest at, and an
;;;  approval-grade bracket detail on an A4 at 1:300 is exactly what that rule forbids.
;;; ===========================================================================================

;; ── THE PEN LADDER: DENSITY AND WEIGHT IDENTIFY THE PART ───────────────────────────────────
;;
;; Owner 5-Sep-2026: "increase the thickness of the dotted lines & with different thickness and
;; density of these dotted lines show the Clear Difference b/w the Different Components of the
;; Bridge. For the Crane Motor More Denser to Clear Its Identification."
;;
;; Everything on the crane is dotted, because none of it is Maimaar's steel. But "all dotted" then
;; says nothing about WHICH part you are looking at — girder, end truck, trolley and motor came out
;; identical. On a MONOCHROME plot colour carries nothing, so the only two variables left are
;; DENSITY (dot pitch) and WEIGHT (lineweight). Use both, together, so the difference survives
;; both the screen and the print:
;;
;;   part            pitch   weight      reads as
;;   girder / main beam  130   0.35 mm   the long member you follow across the span
;;   end truck            90   0.30 mm   a defined block at each end
;;   trolley / crab       90   0.30 mm   the same class of object, riding the girder
;;   wheels               70   0.25 mm   small and fine, four of them
;;   MOTOR                40   0.50 mm   DENSEST and HEAVIEST - it reads almost solid, which is
;;                                       the point: the motor is the one part you must be able to
;;                                       pick out at a glance.
;;
;; One linetype per pitch, named CRNDOT<pitch> and made on demand, so a new density is one number
;; and never a second definition to keep in step.
(defun peb-crn-pen (xa ya xb yb pitch lw / nm es)
  ;; ── SOLID BY DEFAULT (owner 5-Sep-2026, from the reference section) ───────────────────────
  ;; The reference — a crane in a PEB cross-section — draws the bridge, hoist and crane beams
  ;; SOLID and says they are out of scope with a LABEL: "Crane Bridge (Not By SSIPL)", "Hoist
  ;; (not By SSIPL)". Owner on it: "This is clear Solid picture."
  ;;
  ;; That is the better mechanism, and it reverses the earlier "show the bridge dotted" only in
  ;; METHOD, not in intent. Scope was always meant to be readable; a faint linetype was one way to
  ;; say it and a label is the other, and the label is unambiguous where a dash is not — every
  ;; hidden line on the sheet is dashed, so a dashed crane says "behind something", not "not ours".
  ;; It also fixes the readability the owner kept pushing at: dots at 300 read as a scatter, at 130
  ;; as a line, and solid simply reads.
  ;;
  ;; The WEIGHT ladder stays and now does the identifying on its own: girder / truck / wheel /
  ;; motor are still four distinct pens, which is what tells the parts apart on a monochrome plot.
  ;; *PEB-CRN-DOTTED* flips the whole component back to dotted in one place if a job wants it.
  (setq es (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
  (if (and (boundp '*PEB-CRN-DOTTED*) *PEB-CRN-DOTTED*)
    (progn
      (setq nm (strcat "CRNDOT" (itoa (fix pitch))))
      (if (not (tblsearch "LTYPE" nm))
        (vl-catch-all-apply (function (lambda ()
          (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                         '(100 . "AcDbLinetypeTableRecord") (cons 2 nm) '(70 . 0)
                         (cons 3 (strcat "Crane dotted " (itoa (fix pitch)))) '(72 . 65) '(73 . 2)
                         (cons 40 pitch) '(49 . 0.0) '(74 . 0) (cons 49 (- pitch)) '(74 . 0)))))))
      (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC")
                     (cons 6 (if (tblsearch "LTYPE" nm) nm "HIDDEN"))
                     (cons 48 es) (cons 370 (fix lw))
                     (list 10 xa ya 0.0) (list 11 xb yb 0.0))))
    (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                   (list 10 xa ya 0.0) (list 11 xb yb 0.0)))))

;; the rungs
(defun peb-crn-dash  (xa ya xb yb) (peb-crn-pen xa ya xb yb 130.0 30))  ; girder / main beam
(defun peb-crn-truck (xa ya xb yb) (peb-crn-pen xa ya xb yb  90.0 20))  ; end truck, trolley
(defun peb-crn-wheel (xa ya xb yb) (peb-crn-pen xa ya xb yb  70.0 13))  ; wheels
(defun peb-crn-motor (xa ya xb yb) (peb-crn-pen xa ya xb yb  40.0 35))  ; MOTOR - densest, heaviest

;; ── THE BRIDGE GIRDER, SEEN IN A BUILDING CROSS-SECTION ────────────────────────────────────
;;
;; In a cross-section you are looking ALONG the runway, so the runway beams are cut (they show as
;; small boxes on the columns) and the BRIDGE is seen in ELEVATION, spanning rail to rail. It is
;; the only crane member you see at its full length, which is why it carries the reading.
;;
;; It was one plain dashed rectangle. A rectangle is a box, not a girder — nothing in it says
;; plate girder, says depth, or says which way the load goes. Three things fix that, and no more
;; than three (rule 32):
;;
;;   1. FLANGES.  A girder reads as a girder because you can see a top and a bottom flange with a
;;      web between. Two inset lines, one under the top edge and one over the bottom edge.
;;   2. END DIAPHRAGMS + INTERMEDIATE STIFFENERS.  A welded plate girder of this span is
;;      stiffened at intervals, and the vertical ticks are what make it read as fabricated steel
;;      rather than a drawn box. Spaced by DEPTH, not by a fixed count, so a deep short bridge
;;      and a shallow long one both come out looking right.
;;   3. NOTHING ELSE.  No walkway, no handrail, no festoon, no bolt. Those live on the approval
;;      drawing.
;;
;; Pen: peb-crn-dash above — the same CRANEBRG short-dash the section and plan already use.
;;
;;   x0 y0 x1 y1  the girder box: rail-to-rail span, bridgeBot to bridgeTop
;;
;; Degrades honestly: too shallow to carry flanges (under ~4 stiffener widths) and it draws the
;; plain box it always did, rather than inventing detail it has no room for.
(defun peb-crn-bridge-elev (x0 y0 x1 y1 / w d fl st n i x tp ed)
  (setq w (abs (- x1 x0))
        d (abs (- y1 y0)))
  (if (or (< w 1.0) (< d 1.0))
    (princ)
    (progn
      ;; ── THE WEB REDUCES AT THE ENDS (owner 5-Sep-2026: "Draw the Geometry of Section on
      ;;    Edges the Web of Bridge Reduces") ─────────────────────────────────────────────────
      ;; A welded box girder is deepest at mid-span where the moment is, and tapers toward each
      ;; end where it only has to deliver shear into the end truck. Drawn as a constant-depth
      ;; box it reads as a piece of tube, not a designed member. The taper runs over the outer
      ;; 12% of the span each side and takes the end down to 55% of the mid-span depth.
      ;; THE TOP STAYS STRAIGHT; THE REDUCTION IS TAKEN FROM UNDERNEATH (owner 5-Sep-2026: "Top
      ;; View of Crane Bridge is Straight and Web from the Bottom Side Turns to Reduce on Both
      ;; Edges"). It has to be: the trolley runs on the TOP flange, so that line is level for the
      ;; whole span and cannot taper. The depth comes off the SOFFIT, which rises toward each end
      ;; where the girder only has shear left to deliver. Tapering both faces, as this did, would
      ;; put a kink in the trolley's own running surface.
      (setq tp (* w 0.12)
            ed (max (* d 0.40) (- d (peb-crn-end-reduction))))   ; END depth, after the soffit rise
      (peb-crn-dash x0 y1 x1 y1)                                    ; TOP - straight, full span
      (peb-crn-dash x0 (- y1 ed) (+ x0 tp) y0)                      ; soffit rising into the end
      (peb-crn-dash (+ x0 tp) y0 (- x1 tp) y0)                      ; soffit, full depth run
      (peb-crn-dash (- x1 tp) y0 x1 (- y1 ed))                      ; soffit rising into the end
      (peb-crn-dash x0 (- y1 ed) x0 y1)                             ; the reduced ends
      (peb-crn-dash x1 (- y1 ed) x1 y1)
      (setq fl (* d 0.18))                        ; flange thickness as a fraction of the depth
      (if (> d (* fl 4.0))
        (progn
          (peb-crn-dash x0 (- y1 fl) x1 (- y1 fl))                       ; top flange - straight
          (peb-crn-dash (+ x0 tp) (+ y0 fl) (- x1 tp) (+ y0 fl))         ; bottom flange, full run
          (peb-crn-dash x0 (- y1 ed (- 0 fl)) (+ x0 tp) (+ y0 fl))       ; and up the taper
          (peb-crn-dash (- x1 tp) (+ y0 fl) x1 (- y1 ed (- 0 fl)))))
      ;; stiffeners at roughly 1.5 x depth, which is what a welded plate girder actually carries;
      ;; clamped so a very long shallow bridge does not turn into a comb.
      (setq st (max (* d 1.5) (/ w 12.0))
            n  (max 1 (min 10 (fix (/ w st))))
            i  1)
      (while (< i n)
        (setq x (+ x0 (* (/ w (float n)) i)))
        (peb-crn-dash x (+ y0 fl) x (- y1 fl))
        (setq i (1+ i)))
      (princ))))

;; ═══════════════════════════════════════════════════════════════════════════════════════════
;;  SIZING RULES — BRIDGE GIRDER AND CRANE BEAM, BY SPAN
;;  (owner 5-Sep-2026: "Develop the Rules for Size of Bridge and Crane Beams for Different Spans")
;; ═══════════════════════════════════════════════════════════════════════════════════════════
;;
;; ANCHORED ON A BUILT JOB, NOT A RULE OF THUMB. Owner: "Recently we have done the production of
;; bridge which was almost 1000mm deep for 50 Ft span of 10 Tons Capacity."
;;
;;      50 ft = 15,240 mm span · 10 MT · 1,000 mm deep   ->   span / 15.24
;;
;; That one measured point replaces the span/18 this component had been carrying, which was a
;; stylised guess and was labelled as such on the sheet. A number from a girder that was actually
;; fabricated outranks any table (rule 20).
;;
;; CAPACITY MATTERS TOO, but weakly — depth is driven by span first. A 50 MT bridge on the same
;; span is deeper than a 10 MT one, not five times deeper. The exponent 0.20 puts Thal's 50 MT at
;; 21.335 m span at about 1,940 mm, which is the right order for that machine.
;;
;;      d = (span / 15.24) x (capacity / 10) ^ 0.20
;;
;; Clamped to span/22 .. span/11 so an odd capacity can never produce a silly section.
;; THE END REDUCTION IS A FIXED AMOUNT, NOT A RATIO (owner 5-Sep-2026: "at the Edges It Reduces
;; to 300-350mm from the Bottom Side"). Read as the soffit RISING 300-350 mm toward each end, so
;; the 1,000 mm girder finishes about 675 deep where it meets the end carriage — which is the
;; normal proportion for that connection. Taken as a fixed rise rather than a percentage because
;; that is how it was described and how it is fabricated: the same cut whatever the span.
;; Floored at 40% of mid-span depth so a shallow girder cannot taper away to nothing.
(defun peb-crn-end-reduction () 325.0)

(defun peb-crn-girder-depth (span cap / d)
  (if (or (null cap) (<= cap 0.0)) (setq cap 10.0))
  (setq d (* (/ span 15.24) (expt (/ cap 10.0) 0.20)))
  (max (/ span 22.0) (min (/ span 11.0) d)))

;; THE CRANE BEAM spans the BAY, not the crane span — a different member with a different rule.
;; Depth about bay/12 is the working proportion for a built-up runway in this class. Thal 125-23
;; states the construction: "All runway beams for crane lifts less than or equal to 15MT are
;; built-up sections with double side fillet weld" — so at and below 15 MT it is a plate girder,
;; and above that a heavier section, which is why the rule steepens there.
(defun peb-crn-beam-depth (bay cap / d)
  (if (or (null cap) (<= cap 0.0)) (setq cap 10.0))
  (setq d (/ bay (if (<= cap 15.0) 12.0 10.0)))
  (max 400.0 d))

;; Girder width in plan follows the depth — a box girder is about half as wide as it is deep.
(defun peb-crn-girder-width (d) (* d 0.55))
;; Is this runway a built-up plate girder? (Thal rule, quoted above.)
(defun peb-crn-beam-builtup-p (cap) (<= (if cap cap 10.0) 15.0))

;; ── A ROUNDED BOX ──────────────────────────────────────────────────────────────────────────
;; Owner 5-Sep-2026: "Draw its Exact Rounding Shape Not Rectangular". Zoomed 11x on the reference
;; every body of the hoist — motor, gearbox, drum housing, bottom plate — is drawn with FILLETED
;; corners. Sharp rectangles read as fabricated steel; a hoist is a machine casting, and the
;; rounding is most of what says so.
;;
;; Drawn as a closed LWPOLYLINE with bulges rather than lines-plus-arcs: one entity, and the
;; bulge for a 90-degree fillet is tan(90/4) = 0.41421356.
(defun peb-crn-rbox (x0 y0 x1 y1 r lw / b)
  (setq b 0.41421356)
  (if (> r (* 0.45 (min (abs (- x1 x0)) (abs (- y1 y0)))))
    (setq r (* 0.45 (min (abs (- x1 x0)) (abs (- y1 y0))))))
  (entmake (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity") (cons 8 "COMP-CRANE-SEC")
                 (cons 100 "AcDbPolyline") (cons 90 8) (cons 70 1) (cons 370 (fix lw))
                 (cons 10 (list (+ x0 r) y0)) (cons 42 0.0)
                 (cons 10 (list (- x1 r) y0)) (cons 42 b)
                 (cons 10 (list x1 (+ y0 r))) (cons 42 0.0)
                 (cons 10 (list x1 (- y1 r))) (cons 42 b)
                 (cons 10 (list (- x1 r) y1)) (cons 42 0.0)
                 (cons 10 (list (+ x0 r) y1)) (cons 42 b)
                 (cons 10 (list x0 (- y1 r))) (cons 42 0.0)
                 (cons 10 (list x0 (+ y0 r))) (cons 42 b))))

;; ── THE HOOK ───────────────────────────────────────────────────────────────────────────────
;; A hook is not an arc. Off the reference: a shank, a throat that sweeps round below it, and a
;; TIP that curls back up on the far side. Two concentric arcs make the body and a small arc
;; closes the tip; the throat opening faces LEFT, as the reference draws it.
;;   cx cy  hook centre (the throat's centre) · R outer radius · t material thickness
(defun peb-crn-hook (cx cy R t lw / a)
  (defun a (r s e)
    (entmake (list (cons 0 "ARC") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                   (list 10 cx cy 0.0) (cons 40 r) (cons 50 s) (cons 51 e))))
  (a R 2.9671 6.1087)                       ; outer sweep, 170deg round to 350deg
  (a (- R t) 2.9671 5.4978)                 ; inner sweep, stops short so the tip tapers
  ;; the tip, closing outer to inner
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                 (list 10 (+ cx (* R (cos 5.4978))) (+ cy (* R (sin 5.4978))) 0.0)
                 (list 11 (+ cx (* (- R t) (cos 5.4978))) (+ cy (* (- R t) (sin 5.4978))) 0.0)))
  ;; the shank, up from the throat top
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                 (list 10 (- cx R) cy 0.0) (list 11 (- cx R) (+ cy (* R 1.15)) 0.0)))
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                 (list 10 (- cx (- R t)) cy 0.0) (list 11 (- cx (- R t)) (+ cy (* R 1.15)) 0.0)))
  (princ))

;; ── THE CRANE BEAM, RAIL, WHEEL AND BRACKET — TRACED FROM THE REFERENCE ────────────────────
;; Cropped from reference/crane-in-PEB-section_reference.webp at 8x and read off. Top to bottom
;; the junction is:
;;
;;     the BRIDGE GIRDER, its end NOTCHED down where the carriage sits
;;     the WHEEL HOUSING, a small inverted-U bracket
;;     the WHEEL — a spool, waisted at the middle, which is what a crane wheel looks like
;;     the RAIL, a short section on the beam's top flange
;;     the CRANE BEAM — a rectangle with a WEB centre line (that is how the reference draws it)
;;     the BRACKET, cantilevered off the column face
;;
;; SCOPE IS DRAWN, NOT JUST LABELLED. Owner: "Since we will be providing the Crane Beam, so show
;; the Crane Beam in Solid Lines." So beam, rail and bracket go on the SOLID structural pen and
;; the crane itself — girder, carriage, wheel, hoist — stays on the crane pen. The line tells you
;; whose steel it is; the label tells you what it is.
;;
;;   cx      the rail centreline (the wheel lands here)
;;   railY   top of rail
;;   bd bw   crane beam depth and width
;;   colX    column face the bracket cantilevers off (nil = no bracket)
;;   solid   the caller's solid-line function
(defun peb-crn-beam-sec (cx railY bd bw colX solid / by0 by1 ft wt rw rh)
  ;; ── AN I-SECTION, NOT A RECTANGLE (owner 5-Sep-2026: "Crane Beam is I-Beam not Rectangular";
  ;;    "Enlarge it and See it Carefull") ──────────────────────────────────────────────────────
  ;; Zoomed 22x on the reference the beam is plainly a flanged section: a distinct top flange
  ;; line, a web, a bottom flange line — with the rail on the top flange and its clips either
  ;; side of the web. Drawn as a filled rectangle it is a box section, which is a different
  ;; member and the wrong one: a crane runway on this span is a built-up I (Thal 125-23: "built-up
  ;; sections with double side fillet weld"), and the flanges are the whole point of it.
  (setq ft (* bd 0.11)                        ; flange thickness
        wt (* bw 0.16)                        ; web thickness
        rh (* bd 0.13)                        ; rail height
        rw (* bw 0.30)                        ; rail width
        by1 (- railY rh)                      ; top of the top flange
        by0 (- by1 bd))                       ; underside of the bottom flange
  ;; RAIL on the top flange, with a clip each side of the web
  (apply solid (list (- cx (/ rw 2.0)) railY (+ cx (/ rw 2.0)) railY))
  (apply solid (list (- cx (/ rw 2.0)) by1 (- cx (/ rw 2.0)) railY))
  (apply solid (list (+ cx (/ rw 2.0)) by1 (+ cx (/ rw 2.0)) railY))
  ;; TOP FLANGE
  (apply solid (list (- cx (/ bw 2.0)) by1 (+ cx (/ bw 2.0)) by1))
  (apply solid (list (- cx (/ bw 2.0)) (- by1 ft) (+ cx (/ bw 2.0)) (- by1 ft)))
  (apply solid (list (- cx (/ bw 2.0)) (- by1 ft) (- cx (/ bw 2.0)) by1))
  (apply solid (list (+ cx (/ bw 2.0)) (- by1 ft) (+ cx (/ bw 2.0)) by1))
  ;; WEB — the two faces, running flange to flange
  (apply solid (list (- cx (/ wt 2.0)) (- by1 ft) (- cx (/ wt 2.0)) (+ by0 ft)))
  (apply solid (list (+ cx (/ wt 2.0)) (- by1 ft) (+ cx (/ wt 2.0)) (+ by0 ft)))
  ;; BOTTOM FLANGE
  (apply solid (list (- cx (/ bw 2.0)) by0 (+ cx (/ bw 2.0)) by0))
  (apply solid (list (- cx (/ bw 2.0)) (+ by0 ft) (+ cx (/ bw 2.0)) (+ by0 ft)))
  (apply solid (list (- cx (/ bw 2.0)) by0 (- cx (/ bw 2.0)) (+ by0 ft)))
  (apply solid (list (+ cx (/ bw 2.0)) by0 (+ cx (/ bw 2.0)) (+ by0 ft)))
  ;; BRACKET off the column face — the cantilever carrying the beam
  (if colX
    (progn
      (apply solid (list colX by1 cx by1))
      (apply solid (list colX by1 colX (- by0 (* bd 0.30))))
      (apply solid (list colX (- by0 (* bd 0.30)) (- cx (/ bw 2.0)) by0))))
  (princ))

;; ── THE CARRIAGE AND ITS WHEEL, seen along the runway ──────────────────────────────────────
;; The piece that was missing: the bridge appeared to float above the rail with nothing carrying
;; it. Traced order — girder underside, wheel housing, spool wheel, rail.
;;   cx  rail centreline · railY top of rail · gy0 girder underside · tw carriage width
(defun peb-crn-truck-sec (cx railY gy0 tw / g wr wy)
  (setq g (- gy0 railY))
  (if (> g 1.0)
    (progn
      ;; WHEEL — a spool: full-diameter top and bottom, waisted at the middle
      (setq wr (* tw 0.30) wy (+ railY (* g 0.34)))
      (peb-crn-wheel (- cx wr) railY (+ cx wr) railY)
      (peb-crn-wheel (- cx wr) (+ railY (* g 0.68)) (+ cx wr) (+ railY (* g 0.68)))
      (peb-crn-wheel (- cx wr) railY (- cx (* wr 0.55)) wy)
      (peb-crn-wheel (- cx (* wr 0.55)) wy (- cx wr) (+ railY (* g 0.68)))
      (peb-crn-wheel (+ cx wr) railY (+ cx (* wr 0.55)) wy)
      (peb-crn-wheel (+ cx (* wr 0.55)) wy (+ cx wr) (+ railY (* g 0.68)))
      ;; WHEEL HOUSING — the inverted U hanging off the girder end
      (peb-crn-truck (- cx (/ tw 2.0)) (+ railY (* g 0.62)) (- cx (/ tw 2.0)) gy0)
      (peb-crn-truck (+ cx (/ tw 2.0)) (+ railY (* g 0.62)) (+ cx (/ tw 2.0)) gy0)
      (peb-crn-truck (- cx (/ tw 2.0)) (+ railY (* g 0.62)) (- cx (* wr 1.05)) (+ railY (* g 0.62)))
      (peb-crn-truck (+ cx (* wr 1.05)) (+ railY (* g 0.62)) (+ cx (/ tw 2.0)) (+ railY (* g 0.62)))
      (peb-crn-truck (- cx (/ tw 2.0)) gy0 (+ cx (/ tw 2.0)) gy0)))
  (princ))

;; ── THE HOIST, TRACED FROM THE REFERENCE ───────────────────────────────────────────────────
;; Owner 5-Sep-2026: "develop the similar view exact shape of Hoist Motor ... crop the Hoist Motor
;; and Draw its Exact Geometry". Traced off reference/crane-in-PEB-section_reference.webp, cropped
;; and enlarged 6x. Left to right the assembly is:
;;
;;   end cap  |  FINNED MOTOR  |  shoulder  |  mid box  |  MAIN DRUM HOUSING  |  end box + sheave
;;   with a bolted BOTTOM PLATE under the housing, and the HOOK hanging from it.
;;
;; Proportions are fractions of the overall length L, read off the crop; the hook centreline sits
;; at 0.70 L from the left end, which is where the reference hangs it. STYLISED in size (a real
;; hoist is chosen by the crane maker) but the SHAPE and the order of the parts are traced.
;;
;;   hx    hook centreline
;;   topY  the girder underside the hoist hangs from
;;   L     overall length of the assembly
(defun peb-crn-hoist-elev (hx topY L / x0 f y r m i xf)
  (setq x0 (- hx (* L 0.70))
        r  (* L 0.022)                        ; corner fillet, read off the reference
        m  35)                                ; the motor pen
  (defun f (a) (+ x0 (* L a)))
  (defun y (a) (- topY (* L a)))
  ;; MAIN DRUM HOUSING — the big rounded body
  (peb-crn-rbox (f 0.50) (y 0.30) (f 0.87) (y 0.00) (* r 1.4) m)
  ;; gearbox / mid body
  (peb-crn-rbox (f 0.33) (y 0.25) (f 0.51) (y 0.05) r m)
  ;; coupling shoulder
  (peb-crn-rbox (f 0.23) (y 0.22) (f 0.34) (y 0.08) (* r 0.8) m)
  ;; FINNED MOTOR — rounded body with its cooling ribs
  (peb-crn-rbox (f 0.08) (y 0.23) (f 0.24) (y 0.07) (* r 0.8) m)
  (setq i 1)
  (while (< i 6)
    (setq xf (f (+ 0.085 (* 0.026 i))))
    (peb-crn-motor xf (y 0.075) xf (y 0.225))
    (setq i (1+ i)))
  ;; end cap / fan cover
  (peb-crn-rbox (f 0.025) (y 0.25) (f 0.085) (y 0.05) (* r 0.6) m)
  ;; right end box + sheave eye
  (peb-crn-rbox (f 0.86) (y 0.24) (f 1.00) (y 0.06) (* r 0.8) m)
  (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-CRANE-SEC") (cons 370 18)
                 (list 10 (f 0.94) (y 0.15) 0.0) (cons 40 (* L 0.030))))
  ;; BOTTOM PLATE — rounded, bolted, four bolts as the reference shows
  (peb-crn-rbox (f 0.48) (y 0.42) (f 0.90) (y 0.28) r m)
  (foreach xf (list (f 0.52) (f 0.86))
    (foreach i (list (y 0.32) (y 0.38))
      (entmake (list (cons 0 "CIRCLE") (cons 8 "COMP-CRANE-SEC") (cons 370 13)
                     (list 10 xf i 0.0) (cons 40 (* L 0.012))))))
  ;; THE HOOK — shank from the plate, then the hooked profile
  (peb-crn-hook hx (y 0.60) (* L 0.10) (* L 0.032) 25)
  (princ))

;; ── THE BRIDGE IN PLAN (TOP VIEW), WITH ITS COMPONENTS ────────────────────────────────────
;;
;; ORIENTATION, WHICH WAS WRONG AND IS THE WHOLE POINT OF THIS VIEW (owner 5-Sep-2026: "This is
;; not Correct ... it is giving the resemblance of crane"). In plan:
;;
;;     the BRIDGE spans the building WIDTH        -> horizontal here, x0 to x1
;;     the RUNWAYS run along the building LENGTH  -> PERPENDICULAR to it, at x0 and x1
;;     an END TRUCK runs along its RUNWAY         -> its long axis is ACROSS the girder, not
;;                                                   along it, and its length is the WHEEL BASE
;;     the two WHEELS of each truck sit on that runway, one fore and one aft
;;
;; Drawn the other way round it still reads vaguely crane-like, which is exactly the trap: the
;; parts are all present and the arrangement is impossible. A bridge whose end trucks point along
;; its own span cannot travel.
;;
;;   x0 y0 x1 y1  the girder: rail centre to rail centre in x; y0/y1 = the girder's own width
;;   et           end-truck length ALONG THE RUNWAY = the wheel base (0 = skip the trucks)
;;   wr           wheel radius (0 = skip the wheels)
(defun peb-crn-bridge-plan (x0 y0 x1 y1 et wr / gw yc tw ex sgn e wy)
  (setq gw (abs (- y1 y0)) yc (/ (+ y0 y1) 2.0)
        tw (* gw 1.35))                          ; end-truck width, measured ALONG the girder
  (if (or (< (abs (- x1 x0)) 1.0) (< gw 1.0))
    (princ)
    (progn
      ;; the girder itself
      (peb-crn-dash x0 y0 x1 y0) (peb-crn-dash x1 y0 x1 y1)
      (peb-crn-dash x1 y1 x0 y1) (peb-crn-dash x0 y1 x0 y0)
      (if (> et 1.0)
        (foreach e (list (list x0 1.0) (list x1 -1.0))
          (setq ex (car e) sgn (cadr e))
          ;; END TRUCK — long axis ACROSS the girder (it runs on the runway), length = wheel base
          (peb-crn-truck (- ex (* sgn (* tw 0.15))) (- yc (/ et 2.0))
                         (+ ex (* sgn (* tw 0.85))) (- yc (/ et 2.0)))
          (peb-crn-truck (- ex (* sgn (* tw 0.15))) (+ yc (/ et 2.0))
                         (+ ex (* sgn (* tw 0.85))) (+ yc (/ et 2.0)))
          (peb-crn-truck (- ex (* sgn (* tw 0.15))) (- yc (/ et 2.0))
                         (- ex (* sgn (* tw 0.15))) (+ yc (/ et 2.0)))
          (peb-crn-truck (+ ex (* sgn (* tw 0.85))) (- yc (/ et 2.0))
                         (+ ex (* sgn (* tw 0.85))) (+ yc (/ et 2.0)))
          ;; TWO WHEELS PER TRUCK (manual: NWb = 2) — fore and aft ON the runway, so they sit on
          ;; the truck's two ends, straddling the rail line at ex.
          (if (> wr 1.0)
            (foreach wy (list (- yc (* et 0.34)) (+ yc (* et 0.34)))
              (peb-crn-wheel (- ex wr) (- wy wr) (+ ex wr) (- wy wr))
              (peb-crn-wheel (- ex wr) (+ wy wr) (+ ex wr) (+ wy wr))
              (peb-crn-wheel (- ex wr) (- wy wr) (- ex wr) (+ wy wr))
              (peb-crn-wheel (+ ex wr) (- wy wr) (+ ex wr) (+ wy wr))))))
      (princ))))

;; ── THE TROLLEY, AND THE MOTOR ON IT ────────────────────────────────────────────────
;; The trolley rides the girder and carries the hoist; the HOIST MOTOR sits on it, drawn on the
;; densest, heaviest rung so it can be picked out at a glance — owner: "For the Crane Motor More
;; Denser to Clear Its Identification". Everything on a crane is dotted; the motor is the one part
;; that has to read almost solid.
(defun peb-crn-trolley-plan (cx y0 y1 tl / gw yc mo ml)
  (setq gw (abs (- y1 y0)) yc (/ (+ y0 y1) 2.0))
  (peb-crn-truck (- cx (/ tl 2.0)) (- y0 (* gw 0.45)) (+ cx (/ tl 2.0)) (- y0 (* gw 0.45)))
  (peb-crn-truck (- cx (/ tl 2.0)) (+ y1 (* gw 0.45)) (+ cx (/ tl 2.0)) (+ y1 (* gw 0.45)))
  (peb-crn-truck (- cx (/ tl 2.0)) (- y0 (* gw 0.45)) (- cx (/ tl 2.0)) (+ y1 (* gw 0.45)))
  (peb-crn-truck (+ cx (/ tl 2.0)) (- y0 (* gw 0.45)) (+ cx (/ tl 2.0)) (+ y1 (* gw 0.45)))
  ;; hook centre — what a hook approach is measured to
  (peb-crn-truck (- cx (* gw 0.30)) yc (+ cx (* gw 0.30)) yc)
  (peb-crn-truck cx (- yc (* gw 0.30)) cx (+ yc (* gw 0.30)))
  ;; the HOIST MOTOR, sitting on the trolley
  (setq ml (* tl 0.42) mo (* gw 0.95))
  (peb-crn-motor (- cx (/ ml 2.0)) (+ y1 (* gw 0.45)) (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45)))
  (peb-crn-motor (- cx (/ ml 2.0)) (+ y1 (* gw 0.45) mo) (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45) mo))
  (peb-crn-motor (- cx (/ ml 2.0)) (+ y1 (* gw 0.45)) (- cx (/ ml 2.0)) (+ y1 (* gw 0.45) mo))
  (peb-crn-motor (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45)) (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45) mo))
  ;; shaft line, so it reads as a motor and not another box
  (peb-crn-motor (- cx (/ ml 2.0)) (+ y1 (* gw 0.45) (/ mo 2.0))
                 (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45) (/ mo 2.0)))
  (princ))

;; ── THE BRIDGE TRAVEL MOTOR, on an end truck ───────────────────────────────────────────────
;; A top-running bridge is driven from its end truck. Same densest pen as the hoist motor — the
;; two are the same class of thing and must read alike.
(defun peb-crn-bridge-motor (ex sgn et y0 y1 / gw mo ml mx0 mx1 yb)
  (setq gw (abs (- y1 y0)) mo (* gw 0.90) ml (* et 0.34)
        mx0 (+ ex (* sgn (* et 0.33))) mx1 (+ mx0 (* sgn ml))
        yb (- y0 (* gw 0.60) mo))
  (peb-crn-motor mx0 yb mx1 yb)
  (peb-crn-motor mx0 (+ yb mo) mx1 (+ yb mo))
  (peb-crn-motor mx0 yb mx0 (+ yb mo))
  (peb-crn-motor mx1 yb mx1 (+ yb mo))
  (peb-crn-motor mx0 (+ yb (/ mo 2.0)) mx1 (+ yb (/ mo 2.0)))
  (princ))



(princ "\nMAIMAAR PEB Overhead Crane component loaded.")
(princ)

;;; ===========================================================================================
;;;  THE SAMPLE — BRIDGE TOP VIEW + SIDE VIEW, AT SIZE
;;;
;;;  DEVELOPMENT CODE, SEPARATE FROM THE BSF-SYNCHRONISED ENGINE (owner 3-Sep-2026: "this
;;;  develop coding will be separate from Synchronized Coding of BSF Based generated Drawings").
;;;  Nothing below is called by the proposal set — the sheets call peb-crn-bridge-elev /
;;;  peb-crn-bridge-plan only. This exists so the bridge can be drawn and LOOKED at in seconds
;;;  at a size where its detail is actually visible, instead of judging a 356 mm girder on an
;;;  A4 at 1:209 where it is 1.7 mm tall.
;;;
;;;  SIDE VIEW  = along the girder — what the cross-section shows: span, depth, flanges,
;;;               stiffeners, end trucks landing on the rails.
;;;  TOP VIEW   = from above — what the column layout plan shows: the girder between the two
;;;               runways, end trucks across it, trolley riding it.
;;;
;;;  Real numbers, from the reference (see reference/NOTES.md) — Thal 125-23, the house crane
;;;  shed: 10 MT, span 21.335 m. Nothing here is invented; change these and the sample follows.
;;; ===========================================================================================

;; NEVER NAME A LOCAL AFTER A FUNCTION. This took `txt` as its label parameter, which shadowed
;; the `txt` FUNCTION — so (txt "MC" ...) tried to call a string, threw, and killed the rest of
;; the sample silently: the side view and its labels drew, and the span dimension, the whole top
;; view and every label after it did not. Same class as the LISP silent-failure rule; the sheet
;; just stops, with no error anywhere.
(defun peb-crn-sample-dim (x0 x1 y lbl th / t1)
  (setq t1 (* th 0.55))
  (peb-crn-dash x0 y x1 y)
  (peb-crn-dash x0 (- y t1) x0 (+ y t1))
  (peb-crn-dash x1 (- y t1) x1 (+ y t1))
  (txt "MC" (list (/ (+ x0 x1) 2.0) (+ y (* th 0.9))) th 0.0 lbl))

;; Maimaar's OWN steel is solid - only the crane is dotted.
(defun peb-crn-sample-solid (xa ya xb yb)
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 25)
                 (list 10 xa ya 0.0) (list 11 xb yb 0.0))))

(defun peb-draw-crane-sample (span cap wbase / d et gw rw wr yc y0 yT x0 x1 th tl rx0 rx1 sy L hx hy rxc)
  ;; STYLISED PROPORTIONS, stated as such (rule 20). Depth ~ span/18 is the working proportion for
  ;; a welded box girder in this capacity range; a job's own CRn_BRIDGE overrides it. Everything
  ;; TRACED is named on the sheet itself, so the drawing carries its own provenance.
  (setq d  (peb-crn-girder-depth span cap)
        gw (* d 0.72)
        et (if (> wbase 0.0) wbase (* d 1.60))    ; end truck length = the WHEEL BASE when given
        rw (* d 0.30)
        wr (* d 0.16)
        th (* d 0.30)
        x0 0.0 x1 span
        tl (* gw 2.4))

  ;; ══ TOP VIEW - THE FOCUS OF THIS SHEET ═══════════════════════════════════════════════════
  (setq y0 0.0 yT gw yc (/ gw 2.0)
        rx0 (- x0 (* et 1.9)) rx1 (+ x1 (* et 1.9)))
  ;; the two RUNWAY BEAMS with their rails. Maimaar's own steel (Thal 125-23: "All runway beams
  ;; for crane lifts less than or equal to 15MT are built-up sections with double side fillet
  ;; weld"), so SOLID - only the crane is dotted.
  ;; RUNWAY BEAMS run ALONG THE BUILDING LENGTH - perpendicular to the bridge - so in plan they
  ;; are VERTICAL lines at each end of the girder, and the bridge travels up and down them.
  (foreach rxc (list x0 x1)
    (progn
      (peb-crn-sample-solid (- rxc (/ rw 2.0)) (- yc (* et 1.9)) (- rxc (/ rw 2.0)) (+ yc (* et 1.9)))
      (peb-crn-sample-solid (+ rxc (/ rw 2.0)) (- yc (* et 1.9)) (+ rxc (/ rw 2.0)) (+ yc (* et 1.9)))
      (peb-crn-sample-solid rxc (- yc (* et 1.9)) rxc (+ yc (* et 1.9)))))
  (peb-crn-bridge-plan x0 y0 x1 yT et wr)
  (peb-crn-trolley-plan (/ span 2.0) y0 yT tl)
  (peb-crn-bridge-motor x0 1.0 et y0 yT)          ; bridge travel motor on the left truck
  (txt "MC" (list (/ span 2.0) (+ yc (* et 3.6))) (* th 1.6) 0.0 "CRANE BRIDGE  -  TOP VIEW")
  (txt "MC" (list (/ span 2.0) (+ yc (* et 3.0))) (* th 0.9) 0.0
       "CRANE BRIDGE, HOIST AND MOTORS - NOT IN MAIMAAR SCOPE (BY OTHERS)")
  (txt "MC" (list (/ span 2.0) (- yc (* gw 2.4))) (* th 0.9) 0.0 "TROLLEY")
  (txt "MC" (list (/ span 2.0) (+ yc (* gw 3.1))) (* th 0.9) 0.0 "HOIST MOTOR")
  (txt "ML" (list (+ x0 (* gw 2.2)) (- yc (* gw 2.9))) (* th 0.9) 0.0 "BRIDGE TRAVEL MOTOR")
  (txt "MC" (list x0 (+ yc (* et 0.72))) (* th 0.9) 0.0 "END TRUCK")
  (txt "MC" (list x0 (- yc (* et 2.15))) (* th 0.9) 0.0 "RUNWAY BEAM + RAIL")
  (txt "MC" (list x1 (- yc (* et 1.15))) (* th 0.9) 0.0 "2 WHEELS PER END TRUCK")
  (peb-crn-sample-dim x0 x1 (+ yc (* et 2.4))
                      (strcat "CRANE SPAN  C/C RAILS   " (rtos span 2 0)) th)
  (if (> wbase 0.0)
    (peb-crn-sample-dim x0 x1 (- yc (* et 2.8))
                        (strcat "BRIDGE TRAVELS ALONG THE RUNWAYS - WHEEL BASE " (rtos wbase 2 0)) th))

  ;; ══ SIDE VIEW - below, for reference ═════════════════════════════════════════════════════
  (setq sy (- 0.0 (* et 3.6) (* d 5.0)))
  (peb-crn-bridge-elev x0 sy x1 (+ sy d))
  ;; each END of the side view: the crane beam in section on its bracket, and the end truck
  ;; sitting on the rail carrying the girder. Beam and bracket are MAIMAAR'S steel, so solid.
  ;; THE CARRIAGE NEEDS ROOM TO BE SEEN. The rail sits 0.85 x girder-depth below the girder
  ;; underside — on the real machine the carriage is compact, but drawn at 0.30 the wheel had
  ;; nowhere to go and the girder appeared to rest straight on the rail. The gap is what shows
  ;; the wheel, and the wheel is what says the bridge travels.
  (peb-crn-beam-sec x0 (- sy (* d 0.85)) (* d 0.95) (* d 0.80)
                    (- x0 (* d 1.90)) (function peb-crn-sample-solid))
  (peb-crn-beam-sec x1 (- sy (* d 0.85)) (* d 0.95) (* d 0.80)
                    (+ x1 (* d 1.90)) (function peb-crn-sample-solid))
  (peb-crn-truck-sec x0 (- sy (* d 0.85)) sy (* d 1.05))
  (peb-crn-truck-sec x1 (- sy (* d 0.85)) sy (* d 1.05))
  (txt "MC" (list (/ span 2.0) (+ sy d (* th 2.4))) (* th 1.2) 0.0 "SIDE VIEW  -  ALONG THE GIRDER")
  (txt "ML" (list (+ x1 (* d 2.0)) (+ sy (* d 0.55))) (* th 0.9) 0.0
       (strcat "CRANE BRIDGE - GIRDER DEPTH " (rtos d 2 0) "  (RULE: SPAN/15.24 AT 10 MT)"))
  (txt "ML" (list (+ x1 (* d 2.0)) (- sy (* d 1.05))) (* th 0.9) 0.0 "CRANE BEAM + RAIL  (MAIMAAR SCOPE - SOLID)")
  (txt "ML" (list (+ x1 (* d 2.0)) (- sy (* d 2.05))) (* th 0.9) 0.0 "CRANE BEAM BRACKET  (MAIMAAR SCOPE)")
  (txt "MR" (list (- x0 (* d 2.4)) (- sy (* d 0.40))) (* th 0.9) 0.0 "END TRUCK + WHEEL")
  ;; ── THE HOIST MOTOR AND THE HOOK — WHAT THE BUILDING HEIGHT IS QUOTED TO ──────────────────
  ;; Owner 5-Sep-2026: "Motor with Crane Hook. Mostly Gives the Height of Building from FFL to
  ;; Crane Hook (Crane Hook Height)". The manual says the same from the other end — "Eave height
  ;; is a function of ... Clearance above Crane beam / Crane hook height requirement" (GUIDELINE
  ;; FOR DESIGN OF METAL BUILDING, Eave Height). So the hook is not decoration on this view: it
  ;; is the datum the customer's building height is set from, and the side view is where that
  ;; chain is visible — girder, motor, hook, and the drop to FFL.
  (setq hx (/ span 2.0) hy (- sy (* d 1.9)))
  ;; the traced hoist assembly, hung from the girder underside
  (peb-crn-hoist-elev hx sy (* d 2.6))
  (txt "ML" (list (+ hx (* d 1.15)) (- sy (* d 0.55))) (* th 0.9) 0.0 "HOIST (BY OTHERS)")
  (txt "ML" (list (+ hx (* d 1.15)) (- sy (* d 1.35))) (* th 0.9) 0.0 "CRANE HOOK")
  (txt "MC" (list (/ span 2.0) (- sy (* d 2.6))) (* th 0.85) 0.0
       "HOOK HEIGHT IS MEASURED FFL TO THE HOOK - IT SETS THE EAVE HEIGHT")

  ;; ══ HOIST DETAIL, AT LARGE SCALE ════════════════════════════════════════════════════════
  ;; The hoist drawn at true scale on a 21 m span is a blob — 3 m of machine against 21 m of
  ;; girder, and the 0.60 mm motor pen closes its fins. That is not a fault in the tracing, it is
  ;; what happens to any detail at building scale, and it is why the reference sheet shows the
  ;; hoist large. So it gets its own detail here, at roughly 4x, where the traced shape can
  ;; actually be judged: end cap, finned motor, shoulder, mid box, drum housing, sheave pin,
  ;; bolted bottom plate, hook.
  (setq sy (- sy (* d 4.6)))
  (peb-crn-hoist-elev (* span 0.30) sy (* span 0.34))
  (txt "MC" (list (* span 0.30) (+ sy (* th 2.6))) (* th 1.2) 0.0 "HOIST DETAIL  -  ENLARGED")
  (txt "ML" (list (* span 0.50) (- sy (* span 0.05))) (* th 0.85) 0.0
       "TRACED FROM reference/crane-in-PEB-section_reference.webp")
  (txt "ML" (list (* span 0.50) (- sy (* span 0.09))) (* th 0.85) 0.0
       "END CAP / FINNED MOTOR / SHOULDER / MID BOX / DRUM HOUSING / SHEAVE / PLATE / HOOK")
  (setq sy (- sy (* span 0.20)))

  ;; ══ THE DATA BLOCK - every number, and where it came from ════════════════════════════════
  ;; clear of the hook drop, which now reaches sy - 4.6d
  (setq sy (- sy (* d 6.4)))
  (foreach L (list
      (strcat "CAPACITY  " (rtos cap 2 0) " MT")
      "TYPE  TOP RUNNING (TR)  -  manual ch.8 lists TR / monorail / underhung / jib / semi-gantry"
      "END TRUCK WHEELS  2 PER END, 4 TOTAL  -  manual ch.8  NWb = 2  (worked 10 MT example)"
      "VERTICAL IMPACT  10%  PENDANT OPERATED  -  manual table 8.3"
      "CMAA SERVICE CLASS  C  -  manual table 8.1"
      "LONGITUDINAL  10% OF MAX WHEEL LOAD, AT TOP OF RAILS  -  manual ch.8 sec 2.4.4"
      "RUNWAY BEAM  BUILT-UP, DOUBLE SIDE FILLET WELD (<= 15 MT)  -  Thal 125-23 spec"
      "SCOPE IS SAID BY THE LABEL, NOT BY THE LINETYPE  -  ref: crane-in-PEB-section"
      "HOOK HEIGHT FFL-TO-HOOK SETS THE EAVE HEIGHT  -  manual, Eave Height guideline"
      "GIRDER DEPTH  span/15.24 x (cap/10)^0.20 ; SOFFIT RISES 325 AT EACH END"
      "   1000 deep at 50 ft (15,240) span, 10 MT  -  Maimaar production, 2026")
    (progn
      (txt "ML" (list x0 sy) (* th 0.85) 0.0 L)
      (setq sy (- sy (* th 1.8)))))
  (princ))

(defun C:PEB-CRANE-SAMPLE ( / )
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  ;; Component scale, not building scale — see the note in the wall-light sample: peb-th's ladder
  ;; is tuned for a 48 m building and would dwarf a 21 m girder drawn on its own.
  (setq *PEB-TEXT-SCALE* 1.0 *PEB-DIM-SCALE* 1.0)
  ;; Thal 125-23, traced: 10 MT on a 21.335 m span.
  ;; Thal 125-23 traced: 10 MT on a 21.335 m span. Wheel base 3.9 m from the live BSF
  ;; (MSPL-26-276) - the manual gives the wheel COUNT, a job gives the base.
  (peb-draw-crane-sample 21335.0 10.0 3900.0)
  (command "_.ZOOM" "_E")
  (princ "\nBridge sample drawn: TOP + SIDE view.")
  (princ))
