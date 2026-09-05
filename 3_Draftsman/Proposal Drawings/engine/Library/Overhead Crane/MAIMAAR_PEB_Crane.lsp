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
;; ── ONE PEN, DEFINED ONCE ────────────────────────────────────────────────────────────
      ;; This used to build a CRNDOT pattern of its own, per pitch, so the component carried four
      ;; linetypes the rest of the set knew nothing about. The PD now defines the crane's linetype
      ;; centrally - peb-crane-ltype, CRANEHID at 300/150, which is what Mammut's sheet measures -
      ;; and this asks for it whenever the drawing has it. The per-pitch fallback stays for the
      ;; library's own standalone sample, which loads no sheet engine.
      ;;
      ;; The WEIGHT drops to 5 (0.05 mm) with it: the owner's spec is one weight for the whole
      ;; crane, so the girder/truck/wheel/motor ladder does not apply when this is drawn onto a
      ;; proposal sheet. It still applies on the library's own sample, which never sets the flag.
      (if (boundp 'peb-crane-ltype)
        (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC")
                       (cons 6 (peb-crane-ltype)) (cons 48 (peb-crane-lts))
                       (cons 62 7) (cons 370 5)
                       (list 10 xa ya 0.0) (list 11 xb yb 0.0)))
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
                         (list 10 xa ya 0.0) (list 11 xb yb 0.0))))))
    (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                   (list 10 xa ya 0.0) (list 11 xb yb 0.0)))))

;; the rungs
(defun peb-crn-dash  (xa ya xb yb) (peb-crn-pen xa ya xb yb 130.0 30))  ; girder / main beam
(defun peb-crn-truck (xa ya xb yb) (peb-crn-pen xa ya xb yb  90.0 20))  ; end truck, trolley
(defun peb-crn-wheel (xa ya xb yb) (peb-crn-pen xa ya xb yb  70.0 13))  ; wheels
(defun peb-crn-motor (xa ya xb yb) (peb-crn-pen xa ya xb yb  40.0 35))

;; ── THE MOTOR, DOTTED, ON THE PLAN ─────────────────────────────────────────────────────────
;; Owner 5-Sep-2026: "Show the Motor from the Top View in Dotted Line."
;;
;; Everything on this component draws SOLID by default - see the note in peb-crn-pen: the
;; reference sheet says scope with a LABEL, not with a linetype. The motors on the TOP VIEW are
;; the exception the owner has asked for, and they are a good one: seen from above a motor is
;; carried on the far side of the girder or under the trolley, so it is genuinely a hidden
;; outline there, which is exactly what a dashed line is for.
;;
;; *PEB-CRN-DOTTED* is bound as a LOCAL, so it is T only for the duration of this call and
;; AutoLISP hands it back afterwards. That is the same dynamic-scope mechanism that made naming a
;; local `t` so destructive; used on a variable of our own it is the right tool.
(defun peb-crn-motor-dot (xa ya xb yb / *PEB-CRN-DOTTED*)
  (setq *PEB-CRN-DOTTED* T)
  (peb-crn-pen xa ya xb yb 40.0 35))  ; MOTOR - densest, heaviest

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
;; THE END WEB. Owner 5-Sep-2026, the sentence that closed it:
;;   "Actually Girder Depth is more but once it reach to Ends, End Web Reduces to 300-350mm to
;;    Keep on the End Carriage"
;; So the two 300-350 figures are the SAME figure, and now the reason is plain: the girder's end
;; web is cut down to the depth of the end carriage BECAUSE that is what it lands on. It is not a
;; proportion of the girder - it is the carriage's depth, and the GH table gives 345 for a 250
;; wheel, which sits inside the quoted band.
;; The band was given three times and settled upward each time: "300-350mm", then "Girder Depth
;; Reduce form 1200mm to 350mm-400 with one Tapered Cut Just Before the It Reaches to End
;; Carriage", then "which reduces to 350-450mm on Edges". 400 is the middle of the last and
;; sits inside the one before it. ONE tapered cut, just before the carriage - not a long wedge,
;; and not two cuts.
(defun peb-crn-girder-end-web () 400.0)

(defun peb-crn-bridge-elev (x0 y0 x1 y1 / w d fl tp ed ep)
  (setq w (abs (- x1 x0))
        d (abs (- y1 y0)))
  (if (or (< w 1.0) (< d 1.0))
    (princ)
    (progn
      ;; ── A DEEP STRAIGHT BOX THAT DROPS TO THE CARRIAGE AT EACH END ─────────────────────────
      ;; Three messages, in order, and the drawing only settled when all three were held at once:
      ;;
      ;;   "Crane Bridge is Deep Rectangular Box & Stiffners Hide inside & do not visible on
      ;;    Side View"
      ;;   "Shape is not like a Notch but Straight Box Rest on on Crane End Carriage on Both
      ;;    Sides"                                   <- marked in red on this very view
      ;;   "Actually Girder Depth is more but once it reach to Ends, End Web Reduces to 300-350mm
      ;;    to Keep on the End Carriage"
      ;;
      ;; The reduction is REAL, and it was drawn wrong twice before this. First over the outer
      ;; 12% of the span, which turns a 21 m girder into a 2.5 m long wedge at each end - that is
      ;; the NOTCH the owner circled. Then removed altogether, which lost the landing.
      ;;
      ;; What is right: the box runs STRAIGHT AND FULL DEPTH almost to the end, then the soffit
      ;; rises over a SHORT length - about one girder depth - to leave 350-450 where it sits on
      ;; the carriage. On this sheet that is 1.4 m of taper in a 21.3 m span, 6% not 24%, and it
      ;; reads as a box landing on a carriage rather than as a wedge.
      ;;
      ;; THE TOP STAYS STRAIGHT, ALWAYS. The trolley runs on it, so it cannot taper.
      ;; The end depth is the CARRIAGE's depth, not a fraction of the girder's - see
      ;; peb-crn-girder-end-web above.
      ;;
      ;; Pen: peb-crn-dash - the CRANEBRG short-dash, because the bridge is the crane supplier's
      ;; scope and not Maimaar's.
      ;; THE END PIECE IS SHORT. Owner 5-Sep-2026: "and Pieces Length is hardly may be 400mm" /
      ;; "which Just Rest on Crane End Carriage". So the reduced end is a STUB about 400 long -
      ;; just enough to seat on the carriage - and the taper is ONE cut running from the stub
      ;; back up to full depth. Not a wedge that eats a tenth of the span.
      (setq ed (min (* d 0.55) (peb-crn-girder-end-web))     ; never deeper than the girder
            ep (min (* w 0.03) 400.0)                        ; the stub that rests on the carriage
            tp (min (* w 0.09) (* 1.2 (- d ed))))            ; the single tapered cut
      (peb-crn-dash x0 y1 x1 y1)                                    ; TOP - straight, full span
      (peb-crn-dash x0 (- y1 ed) (+ x0 ep) (- y1 ed))               ; the 400 stub, on the carriage
      (peb-crn-dash (+ x0 ep) (- y1 ed) (+ x0 ep tp) y0)            ; ONE tapered cut, up to depth
      (peb-crn-dash (+ x0 ep tp) y0 (- x1 ep tp) y0)                ; soffit - straight, full depth
      (peb-crn-dash (- x1 ep tp) y0 (- x1 ep) (- y1 ed))
      (peb-crn-dash (- x1 ep) (- y1 ed) x1 (- y1 ed))
      (peb-crn-dash x0 (- y1 ed) x0 y1)                             ; the end web, on the carriage
      (peb-crn-dash x1 (- y1 ed) x1 y1)
      ;; the box's own top and bottom plates. At 0.18 d the plate came to 216 on a 1,200 girder,
      ;; and the guard below - twice the plate must fit inside the 400 end web - then failed, so
      ;; the girder plotted as a bare outline with no plates at all. 0.11 d is both nearer a real
      ;; box girder's plate and thin enough to survive into the reduced end.
      (setq fl (* d 0.11))
      (if (and (> d (* fl 4.0)) (> ed (* fl 2.0)))
        (progn
          (peb-crn-dash x0 (- y1 fl) x1 (- y1 fl))                             ; top plate
          (peb-crn-dash (+ x0 ep tp) (+ y0 fl) (- x1 ep tp) (+ y0 fl))         ; bottom plate
          (peb-crn-dash x0 (+ (- y1 ed) fl) (+ x0 ep) (+ (- y1 ed) fl))        ; along the stub
          (peb-crn-dash (- x1 ep) (+ (- y1 ed) fl) x1 (+ (- y1 ed) fl))
          (peb-crn-dash (+ x0 ep) (+ (- y1 ed) fl) (+ x0 ep tp) (+ y0 fl))     ; up the cut
          (peb-crn-dash (- x1 ep tp) (+ y0 fl) (- x1 ep) (+ (- y1 ed) fl))))
      ;; NO STIFFENERS. Owner: "No Need to show the Stiffners and they hide in the Box of Crane
      ;; Bridge". A closed box carries its diaphragms inside; nothing of them shows on an
      ;; elevation, so the comb of vertical lines this used to draw was inventing a detail that
      ;; does not exist on the real machine. (The crane BEAM keeps its stiffeners - an I-section
      ;; carries them on the OUTSIDE of the web, and they are on Maimaar's own cutting list as
      ;; ST4, 128 off.)
      (princ))))

;; ── WHAT THE "300-350" ACTUALLY WAS ────────────────────────────────────────────────────────
;; Owner 5-Sep-2026, settling it: "It is straight Box but Depth of only 300-350mm while other
;; Bridge Depth is 1000mm-1400mm sometime."
;;
;; So the 300-350 is the END CARRIAGE, not a taper in the girder. Two earlier messages -
;; "the Web of Bridge Reduces" at the edges, and "at the Edges It Reduces to 300-350mm from the
;; Bottom Side" - were read here as a girder that thins toward its ends, and a peb-crn-end-depth
;; rule was built on that reading. It was wrong twice over: first as a fixed 325, then as a
;; 0.325 ratio, and the drawing that came out of it was the wedge the owner circled and called a
;; notch.
;;
;; The truth is simpler and the whole assembly now agrees with it:
;;      BRIDGE GIRDER   straight box, 1000-1400 deep   (span/15.24 -> 1000 at 15,240; 1400 at 21,335)
;;      END CARRIAGE    straight box, 300-350 deep     (GH table A10 = 345 for a 250 wheel)
;; The girder is deep because it spans; the carriage is shallow because it only has to carry the
;; girder onto two wheels. The step between the two is what the eye reads at the end of the
;; bridge - not a taper in the girder itself.
;;
;; peb-crn-end-depth is GONE rather than kept "in case": a rule nobody calls is a rule nobody
;; maintains, and this one encoded a misreading.

(defun peb-crn-girder-depth (span cap / d)
  (if (or (null cap) (<= cap 0.0)) (setq cap 10.0))
  (setq d (* (+ 500.0 (/ span 30.5)) (expt (/ cap 10.0) 0.20)))
  (max (/ span 30.0) (min (/ span 11.0) d)))

;; ── THE CRANE BEAM — READ OFF THE MSPL-032 SINGLE-PART SHEET ───────────────────────────────
;; Owner 5-Sep-2026: "i am talking about MSPL-032" / "Show the Solid Thickness of Crane Beam
;; Plates Webs and Flanges". So this is no longer a recollection — it is the fabrication sheet.
;;
;; reference/MSPL-032_crane-beams-and-plates.pdf, single parts (the sheet is RASTER: neither
;; PDFIMPORT nor the text layer reads it, the five embedded crops in reference/single-parts/ are
;; the source):
;;
;;      CRB-1   PL 8 X 400    5936 long    4 off      web plate
;;      CRB-2   PL 8 X 400    6086 long    4 off      web plate
;;      OF34    PL 10 X 225   5936 long    4 off      flange
;;      OF37    PL 10 X 225   5936 long    4 off      flange
;;      OF35    PL 10 X 225   6086 long    4 off      flange
;;      OF33    PL 10 X 225   6086 long    4 off      flange
;;      ST4     FL 8 X 108    400 tall     128 off    web stiffener
;;
;; Two web marks, four flange marks, two flanges to a beam: eight runway beams, 5936 and 6086
;; long, which are the 6096 (20 ft) runway bays less the end gaps. The building is 30480 O/O
;; across in two 15240 (50 ft) spans — the 50 ft crane span the owner quoted.
;;
;; THE THREE PARTS AGREE WITH EACH OTHER, which is what makes them trustworthy:
;;      (225 - 8) / 2 = 108.5  ->  ST4 is FL 8 X 108
;; the stiffener runs from the web face to the flange tip, so its 108 confirms both the 225
;; flange and the 8 web independently. Overall section depth = 400 + 10 + 10 = 420.
;;
;; The owner recalled "400mm Web and 300mm Flange". The web is exactly 400; the flange on the
;; sheet is 225, not 300, and the stiffener proves it. The sheet wins — golden rule 19.
;;
;; It spans the BAY, not the crane span. bay/12 — the figure this carried — needs a 4.8 m bay to
;; produce 400, and real bays are 6 to 8 m, so it was over-sizing by a quarter to a half.
;; bay/15 gives exactly 400 at the 6096 bay MSPL-032 was built on. Capacity lifts it, and more
;; strongly than it lifts the bridge, because a runway carries the wheel loads directly.
(defun peb-crn-beam-depth (bay cap / d)
  (if (or (null cap) (<= cap 0.0)) (setq cap 10.0))
  (if (or (null bay) (<= bay 0.0)) (setq bay 6096.0))
  (setq d (* (/ bay 15.0) (expt (/ cap 10.0) 0.25)))
  ;; snapped to 25 mm - a web is cut from plate to a round width, and the raw 406 this returns
  ;; at the MSPL-032 bay would have printed "PL 8 X 406" against a sheet that says 400.
  (setq d (* 25.0 (fix (+ 0.5 (/ d 25.0)))))
  (max 400.0 d))

;; Plate is bought in stock thicknesses, so a derived thickness is SNAPPED to one. Without this
;; the section would call out "PL 8.4 X 400", which is not a plate anyone can cut.
(defun peb-crn-plate-round (t1 / r)
  (setq r 6.0)
  (foreach n (list 6.0 8.0 10.0 12.0 16.0 20.0 25.0 32.0) (if (<= n t1) (setq r n)))
  r)

;; The proportions that go with the depth, all from the sheet above.
(defun peb-crn-beam-flange (d) (* d 0.5625))                    ; 225 on a 400 web
(defun peb-crn-web-thk    (d) (peb-crn-plate-round (* d 0.02)))  ; PL 8  on a 400 web
(defun peb-crn-flange-thk (d) (peb-crn-plate-round (* d 0.025))) ; PL 10 on a 400 web
(defun peb-crn-stiff-thk  (d) (peb-crn-web-thk d))               ; ST4 is the same 8 as the web
;; the stiffener reaches from the web face to the flange tip - that is what makes it 108
;; FLOORED, not rounded: (225 - 8) / 2 is 108.5 and the sheet says FL 8 X 108. A stiffener is
;; cut short of the flange tip, never proud of it, so the half-millimetre always goes downwards.
(defun peb-crn-stiff-width (d)
  (float (fix (/ (- (peb-crn-beam-flange d) (peb-crn-web-thk d)) 2.0))))
;; ── THE RAIL ──────────────────────────────────────────────────────────
;; Owner 5-Sep-2026, in order, each message narrowing the last:
;;   "Railing was too small Almost 100mm deep ... and small in the sides welded in the middle of
;;    Crane Beam and Wheel on Top of Crane Rail"
;;   "See the Ratio of Crane Beam and Crane Rail" (sending reference/1-2-1.png)
;;   "Crane is relatively too small and just in the middle of Crane Beam"
;;   "Crane Rail is Also 50mmx50mm I Section Like a Railing" / "Railway Track"
;;   "As per My Idea and Wheel Rest of Crane Rail"
;;
;; So: 50 X 50, AN I-SECTION - a railway track in miniature, foot / web / head, with the wheel
;; resting on the head. Not the 100 x 68 this carried: on a 400 deep beam that drew a rail a
;; quarter of the beam's depth, and the whole point of the reference photograph was that the rail
;; is SMALL against the beam. 50 on 400 is one eighth, which is what the reference shows.
;;
;; Held as a RATIO of the web depth so it tracks a bigger beam, and floored at 50 so it never
;; drops below the section actually used.
;; STIFFENER SPACING, counted off the sheet rather than assumed. ST4 is 128 off. There are
;; eight beams (CRB-1 x4 at 5936, CRB-2 x4 at 6086), and a stiffener comes in PAIRS - one each
;; side of the web - so 128 / 8 / 2 = 8 pairs per beam, and 5936 / 8 is about 742.
(defun peb-crn-stiff-spacing (bmlen n)
  (if (or (null bmlen) (<= bmlen 0.0)) (setq bmlen 5936.0))
  (if (or (null n) (<= n 0)) (setq n 8))
  (/ bmlen (float n)))

(defun peb-crn-rail-depth  (d) (max 50.0 (* d 0.125)))    ; 50 on the built 400
(defun peb-crn-rail-width  (d) (max 50.0 (* d 0.125)))    ; square - "50mmx50mm I Section"

;; ══ THE END CARRIAGE ═══════════════════════════════════════════════════════════════════════
;; Owner 5-Sep-2026: "There are End Carriage on Both Ends with Wheels on Bottom" / "have a look
;; of End Carriage Shape" / "with a Wheel on bottom runs on Crane Rail", sending the GH Cranes &
;; Components END CARRIAGES catalogue, now in reference/.
;;
;; It is a WELDED BOX with an end plate each end, a wheel at each end projecting below it, and
;; the travel gearmotor hung on one of them. The girders land on top of it - for a double girder
;; crane, at two seats spaced the trolley span apart. That is the shape; here are its numbers.
;;
;; GH "END CARRIAGES FOR SINGLE AND DOUBLE GIRDER CRANES", read off the dimension table
;; (reference/End carriages .../end-carriages-6405_4b.jpg):
;;
;;   wheel D    A10 depth   A2-A1 overhang   A5 end    A16 width
;;     100         228           332          118/160     ---
;;     125         235           360          125         103
;;     160         302.5         435          160         103
;;     250         345           565          250         128
;;     315         477.5         625          315         128
;;
;; A5 IS THE WHEEL DIAMETER at every size from 125 up - the end of the box is one wheel deep.
;; A1 is the wheel base and A2 the overall length, so A2 = wheel base + the overhang above.
(defun peb-crn-carriage-row (wd)
  (cond ((<= wd 112.0) (list 100.0 228.0   332.0 118.0  90.0))
        ((<= wd 142.0) (list 125.0 235.0   360.0 125.0 103.0))
        ((<= wd 205.0) (list 160.0 302.5   435.0 160.0 103.0))
        ((<= wd 282.0) (list 250.0 345.0   565.0 250.0 128.0))
        (T             (list 315.0 477.5   625.0 315.0 128.0))))

;; Wheel diameter, off the GH WHEEL SELECTION CHART (double girder band):
;;   <=3.2 T -> 125 · <=6.3 T -> 160 · <=12.5 T -> 250 · <=20 T -> 315 · <=25 T -> 400 · else 500
;; The chart's own footnote is worth keeping: "Given information is approximate. Final wheel
;; diameter depends on speed, duty and rail width." So this sizes a PROPOSAL drawing, nothing
;; more - the crane supplier picks the wheel.
;; This picks the ROW OF THE CATALOGUE - it is a band, not the wheel that gets drawn. The two
;; used to be the same function, which meant the owner's measured wheel could not be honoured
;; without also shrinking the carriage box off its own table.
(defun peb-crn-carriage-band (cap)
  (if (or (null cap) (<= cap 0.0)) (setq cap 10.0))
  (cond ((<= cap 3.2)  125.0) ((<= cap 6.3)  160.0) ((<= cap 12.5) 250.0)
        ((<= cap 20.0) 315.0) ((<= cap 25.0) 400.0) (T 500.0)))

;; ── THE WHEEL AS IT IS ON THE JOB ──────────────────────────────────────────────────────────
;; Owner 5-Sep-2026: "Wheel Height is only 100mm and out of which 25mm is overlapped on the
;; Crane Beam."
;;
;; ...then corrected: "sorry overlap of wheel with crane rail only 15mm". So the wheel stands 100
;; overall and 15 of that laps DOWN past the top of rail - the flanges straddling the rail head,
;; which is what keeps it on the track - leaving 85 above the rail.
;;
;; THIS DISAGREES WITH THE CATALOGUE AND THE DISAGREEMENT IS DELIBERATE. GH puts a 250 wheel
;; under a 10 MT double-girder crane, and 250 is what this drew. The owner has measured 100 on
;; the job, and a measured figure outranks a vendor band - the same ruling that took the crane
;; beam flange from the recalled 300 to the sheet's 225. The catalogue still sizes the CARRIAGE
;; BOX, because that is a separate figure the owner confirmed independently ("only 345 deep").
(defun peb-crn-wheel-dia     (cap) 100.0)
(defun peb-crn-wheel-overlap (cap) 15.0)   ; corrected from 25 - owner, 5-Sep-2026

;; ── HOW WIDE IT IS, AND THE GAP UNDER THE CARRIAGE ─────────────────────────────────────────
;; Owner 5-Sep-2026, marking up the section itself (Rendered Pictures/"The small gap bw the Crane
;; Rail and End Carriage & Wheel Width is only 15-20mm showing the lines of wheel depth which
;; runs on the crane railing"):
;;
;;   "The small gap b/w the Crane Rail and End Carriage & Wheel Width is only 15-20mm, showing
;;    the lines of wheel depth which runs on the crane railing"
;;
;; The red was on the two vertical lines rising off the rail and on the space beside them. So
;; BOTH figures are 15-20, and 18 is taken for each:
;;
;;   WHEEL WIDTH   18 - the tread, seen end-on. It was drawn 60 wide with 87 across the flanges,
;;                 which made a squat block where the owner wants two lines. Seen along the
;;                 runway a wheel IS two lines: the tread is all the width there is.
;;   RAIL GAP      18 - top of rail to the underside of the carriage box.
;;
;; THIS RE-DERIVES THE LAP INTO THE CARRIAGE. A 100 wheel that laps 15 below the rail shows 85
;; above it, and if only 18 of that is open gap then 67 is inside the box - not the 50 given
;; earlier ("Wheel is 50mm overlapping with end carriage", itself prefixed "i think"). The three
;; cannot all hold at once, so the two the owner has just marked on the drawing are taken as
;; given and the lap is computed from them. If the 50 is the firm one, set peb-crn-rail-gap to
;; 35 and the lap returns to 50 on its own.
(defun peb-crn-wheel-width (cap) 18.0)
(defun peb-crn-rail-gap    (cap) 18.0)

;; ── THE CARRIAGE, AS THE OWNER HAS IT ──────────────────────────────────────────────────────
;; Owner 5-Sep-2026: "Also EndCarriage will be 300mmx300 Box i think & Wheel is 50mm overlapping
;; with end carriage."
;;
;; So a SQUARE 300 x 300 box, and the wheel stands 50 up inside it. With the wheel's own two
;; figures that closes the whole stack, and every number in it now comes from the owner:
;;
;;      carriage top      TOR + 218     <- the girder's reduced end web lands here
;;      carriage soffit   TOR +  18         200 x 200 box, 1500 long
;;      wheel top         TOR +  85         the wheel laps 67 up into the box
;;      TOP OF RAIL       TOR   0
;;      wheel bottom      TOR -  15         and 15 down past the rail, flanges either side
;;
;; 100 wheel, 15 down, 50 up: the wheel is 100 tall and 85 of it is above the rail, of which 50
;; is inside the carriage, leaving 35 of it visible between the rail and the box. Every one of
;; those figures is the owner's and they close on each other, which is the check that they are
;; remembered right - peb-crn-carriage-soffit derives the 35 rather than storing it.
;;
;; The GH catalogue said 345 deep and 128 wide for this size. The owner's 300 x 300 is used - a
;; figure from the job outranks a vendor band - but GH still supplies A2 - A1, the overhang past
;; the wheel centres, which the owner has not given.
;; 200 x 200, decreased from the 300 x 300 first given (owner 5-Sep-2026: "Decrease the size of
;; 200x200mm"). Still well under the girder it carries, which is the proportion that matters.
(defun peb-crn-carriage-depth      (cap) 200.0)
(defun peb-crn-carriage-width      (cap) 200.0)
;; DERIVED, not stored: 100 wheel, less the 15 below the rail, less the 18 of open gap.
(defun peb-crn-wheel-in-carriage   (cap)
  (- (peb-crn-wheel-dia cap) (peb-crn-wheel-overlap cap) (peb-crn-rail-gap cap)))
;; ── AND IT IS SHORT ────────────────────────────────────────────────────────────────────────
;; Owner 5-Sep-2026: "Length of End Carriage is Not Much - Maximum 1500mm i think."
;;
;; The carriage length IS the wheel base plus a stub past each wheel centre, so this fixes the
;; wheel base too: 1500 overall, 150 from the end of the box to each wheel centre, leaves
;; A1 = 1200. That also replaces GH's A2 - A1 of 565, which went with a 250 wheel and a much
;; longer carriage; on a 100 wheel a 150 stub is the right proportion.
;;
;; TWO OTHER FIGURES POINT HIGHER AND ARE WORTH KNOWING, not overriding:
;;   - the live BSF (MSPL-26-276) carries a 3,900 wheel base for this crane
;;   - CMAA's usual guidance is a wheel base of at least span/7, which on 21,335 is about 3,050
;; A short wheel base under a long span is what makes a crane skew on its runway. The owner's
;; figure is drawn because it is the one measured; both others are printed in the data block so
;; the disagreement is on the sheet rather than buried in a comment.
(defun peb-crn-carriage-length (cap) 1500.0)
(defun peb-crn-carriage-clear  (cap)  150.0)   ; end of the box to the wheel centre
(defun peb-crn-wheel-base (cap)
  (max 600.0 (- (peb-crn-carriage-length cap) (* 2.0 (peb-crn-carriage-clear cap)))))
(defun peb-crn-carriage-over  (cap) (* 2.0 (peb-crn-carriage-clear cap)))   ; A2 - A1
(defun peb-crn-carriage-end   (cap) (nth 3  (peb-crn-carriage-row (peb-crn-carriage-band cap))))

;; top of rail -> underside of the carriage box. That IS the gap the owner marked.
(defun peb-crn-carriage-soffit (cap) (peb-crn-rail-gap cap))

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
;; NOTE THE PARAMETER NAME. This took "tk", not "t", and the reason is worth the line:
;; T is the AutoLISP TRUE constant. Binding it as a local rebinds truth itself for the whole
;; dynamic extent of the call, and AutoLISP does not always hand it back. Everything downstream
;; that ends a cond with (T ...) - which is most helpers, txt included - then falls straight
;; through and returns nil. Nothing errors. The drawing simply STOPS, and the sheet looks like a
;; sheet that finished early rather than one that broke. This cost the whole hoist detail, the
;; enlarged beam detail and the data block off the sample sheet, with vl-catch-all-apply
;; reporting "no error" the entire time.
(defun peb-crn-hook (cx cy R tk lw / a)
  (defun a (r s e)
    (entmake (list (cons 0 "ARC") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                   (list 10 cx cy 0.0) (cons 40 r) (cons 50 s) (cons 51 e))))
  (a R 2.9671 6.1087)                       ; outer sweep, 170deg round to 350deg
  (a (- R tk) 2.9671 5.4978)                 ; inner sweep, stops short so the tip tapers
  ;; the tip, closing outer to inner
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                 (list 10 (+ cx (* R (cos 5.4978))) (+ cy (* R (sin 5.4978))) 0.0)
                 (list 11 (+ cx (* (- R tk) (cos 5.4978))) (+ cy (* (- R tk) (sin 5.4978))) 0.0)))
  ;; the shank, up from the throat top
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                 (list 10 (- cx R) cy 0.0) (list 11 (- cx R) (+ cy (* R 1.15)) 0.0)))
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 (fix lw))
                 (list 10 (- cx (- R tk)) cy 0.0) (list 11 (- cx (- R tk)) (+ cy (* R 1.15)) 0.0)))
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
(defun peb-crn-beam-sec (cx railY bd bw colX solid / by0 by1 ft wt rw rh sw st)
  ;; ── AN I-SECTION, NOT A RECTANGLE (owner 5-Sep-2026: "Crane Beam is I-Beam not Rectangular";
  ;;    "Enlarge it and See it Carefull") ────────────────────────────────────────────
  ;; Zoomed 22x on the reference the beam is plainly a flanged section: a distinct top flange
  ;; line, a web, a bottom flange line — with the rail on the top flange and its clips either
  ;; side of the web. Drawn as a filled rectangle it is a box section, which is a different
  ;; member and the wrong one: a crane runway on this span is a built-up I (Thal 125-23: "built-up
  ;; sections with double side fillet weld"), and the flanges are the whole point of it.
  ;;
  ;; PLATE THICKNESS IS NOW REAL, NOT A RATIO (owner 5-Sep-2026: "Show the Solid Thickness of
  ;; Crane Beam Plates Webs and Flanges"). It used to carry ft = 0.11 x depth and wt = 0.16 x
  ;; width — 44 and 48 mm on the MSPL-032 section, where the sheet says 10 and 8. A five-fold
  ;; error, invisible at building scale, and exactly what the enlarged detail exists to expose.
  ;;
  ;;   bd  WEB depth (the 400 of PL 8 X 400)   — overall section is bd + 2 x flange thickness
  ;;   bw  FLANGE width (the 225 of PL 10 X 225)
  (setq ft (peb-crn-flange-thk bd)            ; PL 10 on the built 400
        wt (peb-crn-web-thk bd)               ; PL 8  on the built 400
        st (peb-crn-stiff-thk bd)             ; ST4, the same 8
        sw (peb-crn-stiff-width bd)           ; 108 = (225 - 8) / 2
        rh (peb-crn-rail-depth bd)            ; rail ~0.25 x web  (100 on the built 400)
        rw (peb-crn-rail-width bd)            ; narrow, welded on the beam centreline
        by1 (- railY rh)                      ; top of the top flange
        by0 (- by1 bd (* 2.0 ft)))            ; underside of the bottom flange
  ;; RAIL on the top flange, with a clip each side of the web
  (apply solid (list (- cx (/ rw 2.0)) railY (+ cx (/ rw 2.0)) railY))
  (apply solid (list (- cx (/ rw 2.0)) by1 (- cx (/ rw 2.0)) railY))
  (apply solid (list (+ cx (/ rw 2.0)) by1 (+ cx (/ rw 2.0)) railY))
  ;; TOP FLANGE — a plate ft thick
  (apply solid (list (- cx (/ bw 2.0)) by1 (+ cx (/ bw 2.0)) by1))
  (apply solid (list (- cx (/ bw 2.0)) (- by1 ft) (+ cx (/ bw 2.0)) (- by1 ft)))
  (apply solid (list (- cx (/ bw 2.0)) (- by1 ft) (- cx (/ bw 2.0)) by1))
  (apply solid (list (+ cx (/ bw 2.0)) (- by1 ft) (+ cx (/ bw 2.0)) by1))
  ;; WEB — the two faces, wt apart, running flange to flange
  (apply solid (list (- cx (/ wt 2.0)) (- by1 ft) (- cx (/ wt 2.0)) (+ by0 ft)))
  (apply solid (list (+ cx (/ wt 2.0)) (- by1 ft) (+ cx (/ wt 2.0)) (+ by0 ft)))
  ;; BOTTOM FLANGE
  (apply solid (list (- cx (/ bw 2.0)) by0 (+ cx (/ bw 2.0)) by0))
  (apply solid (list (- cx (/ bw 2.0)) (+ by0 ft) (+ cx (/ bw 2.0)) (+ by0 ft)))
  (apply solid (list (- cx (/ bw 2.0)) by0 (- cx (/ bw 2.0)) (+ by0 ft)))
  (apply solid (list (+ cx (/ bw 2.0)) by0 (+ cx (/ bw 2.0)) (+ by0 ft)))
  ;; STIFFENER ST4 either side of the web, web face to flange tip — seen edge-on in section, so
  ;; it is st thick and sw wide. 128 off on MSPL-032, which is why it belongs on the section.
  (if (> sw (* st 1.5))
    (progn
      (apply solid (list (+ cx (/ wt 2.0)) (- by1 ft) (+ cx (/ wt 2.0) sw) (- by1 ft)))
      (apply solid (list (- cx (/ wt 2.0)) (- by1 ft) (- cx (/ wt 2.0) sw) (- by1 ft)))))
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
;;   et           END CARRIAGE length along the runway (0 = skip them)
;;   wb           the WHEEL BASE inside it - the two are no longer the same number, because the
;;                carriage runs a stub past each wheel centre
;;   wr           wheel radius (0 = skip the wheels)
(defun peb-crn-bridge-plan (x0 y0 x1 y1 et cw wb cap / gw yc ex sgn e wy ww wl)
  ;; ── SYNCED WITH THE SIDE VIEW ──────────────────────────────────────────────────────────────
  ;; Owner 5-Sep-2026: "Sync the side view with the Top View."
  ;;
  ;; Everything here now comes from the same rules the side view and the section use, so the two
  ;; views cannot drift:
  ;;
  ;;   END CARRIAGE   et long ALONG THE RUNWAY (1500) x cw ACROSS THE GIRDER (200)
  ;;   WHEELS         2 per carriage at the wheel base (1200), each 18 across x 100 along
  ;;
  ;; It used to draw the carriage 1.35 x the girder width - about 1,166 across where the box is
  ;; 200 - and the wheels as squares of 0.16 x girder depth, about 192, where a wheel is 18 x 100.
  ;; Both were stylised placeholders from before any of these figures were known, and they made
  ;; the top view disagree with every other view on the sheet.
  (setq gw (abs (- y1 y0)) yc (/ (+ y0 y1) 2.0)
        ww (* (peb-crn-wheel-width cap) 0.5)     ; half the wheel ACROSS the girder - 9
        wl (* (peb-crn-wheel-dia cap) 0.5))      ; half the wheel ALONG the runway - 50
  (if (or (< (abs (- x1 x0)) 1.0) (< gw 1.0))
    (princ)
    (progn
      ;; the girder itself
      (peb-crn-dash x0 y0 x1 y0) (peb-crn-dash x1 y0 x1 y1)
      (peb-crn-dash x1 y1 x0 y1) (peb-crn-dash x0 y1 x0 y0)
      (if (> et 1.0)
        (foreach e (list (list x0 1.0) (list x1 -1.0))
          (setq ex (car e) sgn (cadr e))
          ;; END CARRIAGE - long axis ALONG THE RUNWAY, centred on the rail line at ex
          (peb-crn-truck (- ex (* cw 0.5)) (- yc (/ et 2.0)) (+ ex (* cw 0.5)) (- yc (/ et 2.0)))
          (peb-crn-truck (- ex (* cw 0.5)) (+ yc (/ et 2.0)) (+ ex (* cw 0.5)) (+ yc (/ et 2.0)))
          (peb-crn-truck (- ex (* cw 0.5)) (- yc (/ et 2.0)) (- ex (* cw 0.5)) (+ yc (/ et 2.0)))
          (peb-crn-truck (+ ex (* cw 0.5)) (- yc (/ et 2.0)) (+ ex (* cw 0.5)) (+ yc (/ et 2.0)))
          ;; TWO WHEELS PER CARRIAGE (manual: NWb = 2), at the wheel base, on the rail line
          (foreach wy (list (- yc (* wb 0.5)) (+ yc (* wb 0.5)))
            (peb-crn-wheel (- ex ww) (- wy wl) (+ ex ww) (- wy wl))
            (peb-crn-wheel (- ex ww) (+ wy wl) (+ ex ww) (+ wy wl))
            (peb-crn-wheel (- ex ww) (- wy wl) (- ex ww) (+ wy wl))
            (peb-crn-wheel (+ ex ww) (- wy wl) (+ ex ww) (+ wy wl)))))
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
  (peb-crn-motor-dot (- cx (/ ml 2.0)) (+ y1 (* gw 0.45)) (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45)))
  (peb-crn-motor-dot (- cx (/ ml 2.0)) (+ y1 (* gw 0.45) mo) (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45) mo))
  (peb-crn-motor-dot (- cx (/ ml 2.0)) (+ y1 (* gw 0.45)) (- cx (/ ml 2.0)) (+ y1 (* gw 0.45) mo))
  (peb-crn-motor-dot (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45)) (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45) mo))
  ;; shaft line, so it reads as a motor and not another box
  (peb-crn-motor-dot (- cx (/ ml 2.0)) (+ y1 (* gw 0.45) (/ mo 2.0))
                 (+ cx (/ ml 2.0)) (+ y1 (* gw 0.45) (/ mo 2.0)))
  (princ))

;; ── THE BRIDGE TRAVEL MOTOR, on an end truck ───────────────────────────────────────────────
;; A top-running bridge is driven from its end truck. Same densest pen as the hoist motor — the
;; two are the same class of thing and must read alike.
(defun peb-crn-bridge-motor (ex sgn et y0 y1 / gw mo ml mx0 mx1 yb)
  (setq gw (abs (- y1 y0)) mo (* gw 0.90) ml (* et 0.34)
        mx0 (+ ex (* sgn (* et 0.33))) mx1 (+ mx0 (* sgn ml))
        yb (- y0 (* gw 0.60) mo))
  (peb-crn-motor-dot mx0 yb mx1 yb)
  (peb-crn-motor-dot mx0 (+ yb mo) mx1 (+ yb mo))
  (peb-crn-motor-dot mx0 yb mx0 (+ yb mo))
  (peb-crn-motor-dot mx1 yb mx1 (+ yb mo))
  (peb-crn-motor-dot mx0 (+ yb (/ mo 2.0)) mx1 (+ yb (/ mo 2.0)))
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
(defun peb-crn-sample-dim (x0 x1 y lbl th / aL aW tk)
  (setq aL (* th 0.78) aW (* th 0.25) tk (* th 0.45))
  (peb-crn-dimline x0 y x1 y)
  (peb-crn-ahead x0 y -1 aL aW)
  (peb-crn-ahead x1 y  1 aL aW)
  (peb-crn-dimline x0 (- y tk) x0 (+ y tk))
  (peb-crn-dimline x1 (- y tk) x1 (+ y tk))
  (txt "MC" (list (/ (+ x0 x1) 2.0) (+ y (* th 0.85))) th 0.0 lbl))

;; Maimaar's OWN steel is solid - only the crane is dotted.
(defun peb-crn-sample-solid (xa ya xb yb)
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 25)
                 (list 10 xa ya 0.0) (list 11 xb yb 0.0))))

;; the same steel, but BEHIND the cutting plane - a stiffener between two cuts, seen through the
;; section. Same layer, lighter pen: on a monochrome plot the weight is the only thing that
;; separates what is cut from what is merely visible, since colour carries nothing.
(defun peb-crn-sample-thin (xa ya xb yb)
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 370 13)
                 (list 10 xa ya 0.0) (list 11 xb yb 0.0))))

;; ── DIMENSIONS, TO THE SET'S OWN RULES ─────────────────────────────────────────────────────
;; PD_RULEBOOK §0 S55: "Dimension arrowheads are the OPEN V, at 300/95. Leader and callout heads
;; stay FILLED. Ticks are retired." S58: "Dimensions go in the PEB-DIM style at normal weight on
;; the DIMENSIONS layer." This sheet was drawing plain ticks on the component layer, which is the
;; one thing on it that did not look like a Maimaar drawing.
;;
;; Built from primitives rather than a native DIMLINEAR for the reason peb-fr-overall-h gives:
;; DIMLINEAR runs its extension lines from the definition points to the dim line, which on these
;; details would drive them straight through the geometry being measured. Same shape as
;; peb-fr-dimarrow so the two families read alike - plain line, open V tipping outward at each
;; end, witness tick at each extent, value centred above.
;;
;; The head is sized off the TEXT, not off *PEB-DIM-SCALE*: these four pages each plot at their
;; own scale, so one model-space arrowhead would come out four different sizes on paper. 0.78 x
;; text height puts it at about the 300/95 proportion the set uses.
(defun peb-crn-ahead (x y dir aL aW)
  (peb-crn-dimline x y (- x (* dir aL)) (+ y aW))
  (peb-crn-dimline x y (- x (* dir aL)) (- y aW)))

(defun peb-crn-aheadv (x y dir aL aW)          ; the same head, turned for a vertical dim
  (peb-crn-dimline x y (+ x aW) (- y (* dir aL)))
  (peb-crn-dimline x y (- x aW) (- y (* dir aL))))

(defun peb-crn-dimline (xa ya xb yb)
  (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS") (cons 370 18)
                 (list 10 xa ya 0.0) (list 11 xb yb 0.0))))

(defun peb-crn-dimh (x0 x1 y lbl th / aL aW tk)
  (setq aL (* th 0.78) aW (* th 0.25) tk (* th 0.45))
  (peb-crn-dimline x0 y x1 y)
  (peb-crn-ahead x0 y -1 aL aW)
  (peb-crn-ahead x1 y  1 aL aW)
  (peb-crn-dimline x0 (- y tk) x0 (+ y tk))
  (peb-crn-dimline x1 (- y tk) x1 (+ y tk))
  (txt "MC" (list (/ (+ x0 x1) 2.0) (+ y (* th 0.95))) th 0.0 lbl))

;; S72 - "A dimension too small for its text puts the TEXT outside." romand has no metrics here,
;; so the width comes from peb-crn-em, measured at 0.94.
(defun peb-crn-dimv (y0 y1 x lbl th / aL aW tk)
  (setq aL (* th 0.78) aW (* th 0.25) tk (* th 0.45))
  (peb-crn-dimline x y0 x y1)
  (peb-crn-aheadv x y0 -1 aL aW)
  (peb-crn-aheadv x y1  1 aL aW)
  (peb-crn-dimline (- x tk) y0 (+ x tk) y0)
  (peb-crn-dimline (- x tk) y1 (+ x tk) y1)
  (if (< (* (strlen lbl) th (peb-crn-em)) (abs (- y1 y0)))
    (txt "MC" (list (- x (* th 0.95)) (/ (+ y0 y1) 2.0)) th 90.0 lbl)
    (txt "ML" (list (+ x (* th 0.9)) (/ (+ y0 y1) 2.0)) th 0.0 lbl)))

;; a leader: elbow out of the part, then the note
(defun peb-crn-note (px py tx ty lbl th just)
  (peb-crn-sample-solid px py tx ty)
  (peb-crn-sample-solid tx ty (+ tx (if (equal just "ML") (* th 0.8) (- 0 (* th 0.8)))) ty)
  (txt just (list (+ tx (if (equal just "ML") (* th 1.1) (- 0 (* th 1.1)))) ty) th 0.0 lbl))

;; ── HOW WIDE A STRING ACTUALLY IS ──────────────────────────────────────────────────────────
;; MEASURED, not estimated. Everything on this sheet that had to know a string's width used
;; 0.62 em per character - the figure in scratchpad/measure_dxf.js - and that figure is WRONG for
;; the style peb-std-setup installs. Asking AutoCAD for the bounding box of an 88-character line
;; set at height 100 gives:
;;
;;      em-per-char = 0.9417
;;
;; a 52 % underestimate. It is why the two-column data block printed straight through itself at a
;; gutter that the arithmetic said was clear, and why several label placements on this sheet
;; needed a second pass after they were "checked". A string is half again as wide as the estimate
;; everyone has been using.
;;
;; Kept as a function so the next person who measures it has one place to correct.
(defun peb-crn-em () 0.94)

;; ── ONE TEXT SIZE ON PAPER, ACROSS FOUR DIFFERENT SCALES ───────────────────────────────────
;; PD_RULEBOOK §0 S57: "One text height per sheet, from the ladder, sized for PAPER.
;; *PEB-TEXT-SCALE* is computed from the SHEET, never from the building."
;;
;; This set breaks that rule in a way a single-sheet drawing cannot. The four pages are plotted
;; from four DIFFERENT WINDOWS onto the same A1 paper, so each has its own scale - page 1 fits a
;; 21 m span, page 3 fits a 420 mm section blown up 15x. One model-space text height therefore
;; came out four different sizes on paper, and that alone is most of why the set did not read as
;; one document.
;;
;; So each page gets the model-space height that plots to the SAME millimetres. Work backwards:
;; find which of width or height binds on a 841 x 594 sheet, take that scale, and divide.
;; The frame is allowed for - it adds 3 % margin each side and a strip below.
(defun peb-crn-page-th (w h mm / sc)
  (setq w  (* w 1.06)                       ; the margins peb-crn-page-frame adds
        h  (* h 1.135)                      ; the margins plus the title strip
        sc (if (>= (/ w h) (/ 841.0 594.0)) (/ 841.0 w) (/ 594.0 h)))
  (/ mm sc))

;; 3.2 mm of body text on A1. Titles run 1.15 - 1.6 x that, notes 0.85 x, which keeps the whole
;; set inside the 2 - 5 mm band the house sheets use.
(defun peb-crn-paper-text () 3.2)

;; ── WHAT WAS ACTUALLY DRAWN, MEASURED ──────────────────────────────────────────────────────
;; The page windows used to be hand-written expressions that had to be kept in step with the
;; drawing by hand - and were not. A note anchored 2.4 girder-depths left of the girder, then
;; running its own text 9,000 further left, fell straight off the left edge of page 2; the window
;; formula had no way of knowing the text was there, because romand text carries no extents in
;; the DXF and nothing measured it.
;;
;; So the windows are now MEASURED instead. Every entity in a page's Y band is asked for its
;; bounding box and the union is the page. A label can no longer be clipped by a window that did
;; not know about it, and there is no pair of expressions left to drift apart.
;;
;; TEXT is the reason this has to go through vla-GetBoundingBox rather than the DXF: AutoCAD
;; knows the extents of a romand string, the file does not.
(defun peb-crn-band-extent (ylo yhi / ms x0 y0 x1 y1 p1 p2 cy)
  (setq ms (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object))))
  (vlax-for e ms
    (if (not (vl-catch-all-error-p
               (vl-catch-all-apply (function (lambda () (vla-GetBoundingBox e (quote p1) (quote p2)))))))
      (progn
        (setq p1 (vlax-safearray->list p1) p2 (vlax-safearray->list p2)
              cy (/ (+ (cadr p1) (cadr p2)) 2.0))
        (if (and (>= cy ylo) (<= cy yhi))
          (setq x0 (if x0 (min x0 (car p1)) (car p1))
                x1 (if x1 (max x1 (car p2)) (car p2))
                y0 (if y0 (min y0 (cadr p1)) (cadr p1))
                y1 (if y1 (max y1 (cadr p2)) (cadr p2)))))))
  (if x0 (list x0 y0 x1 y1) nil))

;; 17690 -> "17,690". The set's own peb-comma lives in Plan.lsp and this library must not
;; depend on a sheet engine, so it carries its own.
(defun peb-crn-comma (n / s i out)
  (setq s (rtos n 2 0) i (strlen s) out "")
  (while (> i 0)
    (setq out (strcat (substr s i 1) out))
    (setq i (1- i))
    (if (and (> i 0) (= 0 (rem (- (strlen s) i) 3))) (setq out (strcat "," out))))
  out)

;; ── A BORDER AND A TITLE STRIP ─────────────────────────────────────────────────────────────
;; Owner 5-Sep-2026: "Keep doing the audit Fixing, Polishing to make the Drawing Most Beautiful."
;;
;; The four pages carried a view title and nothing else - no border, no identity, no sheet
;; number. A drawing floating on white paper reads as a sketch however careful the geometry is,
;; and this is the cheapest thing that changes that. The strip also stops the sheet lying about
;; what it is: it says DEVELOPMENT SAMPLE, because it is one.
;;
;; Drawn from the plot window itself, so a page that grows keeps its frame.
;;   wx0 wy0 wx1 wy1  the page's content window · ttl sheet title · n of tot · th text height
(defun peb-crn-page-frame (wx0 wy0 wx1 wy1 ttl n tot th cap spn / m sh fy0 bx0 bx1 by1 c1 c2)
  (setq m   (* (- wx1 wx0) 0.030)             ; margin round the content
        sh  (* (- wy1 wy0) 0.075)             ; title strip height
        bx0 (- wx0 m)  bx1 (+ wx1 m)
        by1 (+ wy1 m)  fy0 (- wy0 m sh)       ; the strip hangs below the content
        c1  (+ bx0 (* (- bx1 bx0) 0.46))      ; the two dividers in the strip
        c2  (+ bx0 (* (- bx1 bx0) 0.78)))
  ;; the border - heavier than anything inside it, so the eye reads it as the edge
  ;; GROUP ORDER MATTERS (S86): entity properties - 8, 370 - go AFTER (cons 100 "AcDbEntity")
  ;; and BEFORE the second subclass marker. Written the other way round this entmake returns nil
  ;; and the border silently does not exist, which is exactly how it first rendered: a title
  ;; strip floating with no box round it.
  (entmake (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity")
                 (cons 8 "COMP-CRANE-SEC") (cons 370 50)
                 (cons 100 "AcDbPolyline") (cons 90 4) (cons 70 1)
                 (list 10 bx0 fy0) (list 10 bx1 fy0) (list 10 bx1 by1) (list 10 bx0 by1)))
  ;; the strip, and its two dividers
  (peb-crn-sample-solid bx0 (+ fy0 sh) bx1 (+ fy0 sh))
  (peb-crn-sample-solid c1 fy0 c1 (+ fy0 sh))
  (peb-crn-sample-solid c2 fy0 c2 (+ fy0 sh))
  ;; left cell - who and what
  (txt "ML" (list (+ bx0 (* m 0.5)) (+ fy0 (* sh 0.66))) (* th 1.15) 0.0
       "MAIMAAR STEEL (PVT) LTD")
  (txt "ML" (list (+ bx0 (* m 0.5)) (+ fy0 (* sh 0.30))) (* th 0.85) 0.0
       "OVERHEAD CRANE  -  COMPONENT LIBRARY")
  ;; middle cell - the sheet
  (txt "ML" (list (+ c1 (* m 0.5)) (+ fy0 (* sh 0.66))) (* th 1.15) 0.0 ttl)
  ;; The capacity and span come IN - the strip used to carry "SPAN 21,335" as a literal, which
  ;; went stale the moment the sample was pointed at MSPL-26-276 and its 17,690 span. A title
  ;; block that disagrees with the drawing above it is worse than no title block.
  ;;
  ;; And no middle dots: romand has no glyph for U+00B7 and printed it as "?" - S54 says all text
  ;; is romand, so the text has to stay inside what romand can set.
  (txt "ML" (list (+ c1 (* m 0.5)) (+ fy0 (* sh 0.30))) (* th 0.85) 0.0
       (strcat (rtos cap 2 0) " MT   -   SPAN " (peb-crn-comma spn)
               "   -   DEVELOPMENT SAMPLE, NOT A CUSTOMER DELIVERABLE"))
  ;; right cell - where you are in the set
  (txt "MC" (list (+ c2 (* (- bx1 c2) 0.5)) (+ fy0 (* sh 0.66))) (* th 1.4) 0.0
       (strcat "SHEET " (itoa n) " OF " (itoa tot)))
  (txt "MC" (list (+ c2 (* (- bx1 c2) 0.5)) (+ fy0 (* sh 0.30))) (* th 0.85) 0.0
       "SCALE: TO FIT")
  (list bx0 (- fy0 (* m 0.5)) bx1 (+ by1 (* m 0.5))))     ; the window to plot, frame included

;; ── THE CRANE BEAM, ENLARGED — THE VIEW THAT SHOWS THE PLATE THICKNESSES ───────────────
;; Owner 5-Sep-2026: "Show the Solid Thickness of Crane Beam Plates Webs and Flanges", and
;; earlier "Crop the Close View of the Junction of Crane Bridge with the I-Beam of Shed and
;; Bracket". Both are the same drawing: at building scale an 8 mm web is a fifth of a hair and
;; the bracket is three lines, so the section has to be blown up before either can be judged.
;;
;; Every figure below is off reference/MSPL-032_crane-beams-and-plates.pdf — see the single-part
;; table at peb-crn-beam-depth. Drawn SOLID throughout: the beam, the rail, the bracket and the
;; column are all Maimaar's steel. Only the wheel and the girder above it are the crane, and
;; those stay dotted, which is the whole point of showing them together.
;;
;;   cx cy   rail centreline, at the underside of the bottom flange
;;   bd      web depth (400 on MSPL-032)   .   k  enlargement   .   th  text height
;; ── THE END CARRIAGE, DRAWN ────────────────────────────────────────────────────────────────
;; Side elevation, seen along the runway - which is the view the catalogue draws it in and the
;; one that shows what the owner asked for: the box, and a wheel on the bottom at each end
;; running on the crane rail.
;;
;;   cx cy   centre of the carriage, at TOP OF RAIL   ·   wb wheel base   ·   cap capacity
;;   k       enlargement                              ·   th text height
;; ── THE END CARRIAGE SEEN END-ON ───────────────────────────────────────────────────────────
;; What the SIDE VIEW along the girder actually shows at each end: the carriage across the page,
;; the girder landing square on top of it, and one wheel below on the rail (the second is behind
;; the first - the wheel base runs into the page in this view). Its whole point is the STEP: a
;; 1,400 girder sitting on a 345 carriage.
;;
;;   cx  the rail centreline · railY top of rail · girderY girder soffit · cap capacity
(defun peb-crn-carriage-endon (cx railY girderY cap / wd ov dp r fl hw yb)
  (setq wd (peb-crn-wheel-dia cap)     ov (peb-crn-wheel-overlap cap)
        dp (peb-crn-carriage-depth cap)
        ;; seen end-on the box shows its WIDTH. GH gives A16 = 128 for the box itself, but what
        ;; the eye sees at the end of a bridge is the box plus the wheel flanges standing either
        ;; side of the rail, so it is drawn a little wider than the box alone.
        hw (* (peb-crn-carriage-width cap) 0.5)      ; the box is square: 300 across, end-on
        yb (+ railY (peb-crn-carriage-soffit cap)))  ; box soffit, 25 above the rail
  ;; the box - straight, and only 300-350 deep against a 1000-1400 girder
  (peb-crn-dash (- cx hw) yb (+ cx hw) yb)
  (peb-crn-dash (- cx hw) girderY (+ cx hw) girderY)
  (peb-crn-dash (- cx hw) yb (- cx hw) girderY)
  (peb-crn-dash (+ cx hw) yb (+ cx hw) girderY)
  ;; ── THE WHEEL, SEEN END-ON: SMALL, AND ALL STRAIGHT LINES ────────────────────────────────
  ;; Owner 5-Sep-2026: "End View Will of Wheel will be small and Straight Lines."
  ;; Looking along the runway you are looking at the wheel EDGE-ON, so what shows is its tread
  ;; width and its two flanges - a small stepped rectangle, not a circle. The circle belongs on
  ;; the carriage elevation (page 4), where the wheel is seen from its side; drawn as a circle
  ;; here it claimed a view this one does not have.
  ;;
  ;;      75 above the rail   |‾‾|      narrow body, the tread
  ;;      ------------------ TOP OF RAIL
  ;;      25 lapped below   |____|      flanges, wider, straddling the rail head
  ;; TWO LINES AND A PAIR OF FLANGES. The tread is 18 wide, so end-on that is all the wheel is:
  ;; two verticals off the rail head running up into the carriage. The flanges are the only part
  ;; wider than the tread, and they show only in the 15 that laps below the rail.
  (setq r (* (peb-crn-wheel-width cap) 0.5)     ; half the tread - 9
        fl (* (peb-crn-rail-width 400.0) 0.52)) ; half across the flanges, just outside the head
  (peb-crn-wheel (- cx r) (- railY ov) (- cx r) (+ railY (- wd ov)))  ; the two lines of the tread
  (peb-crn-wheel (+ cx r) (- railY ov) (+ cx r) (+ railY (- wd ov)))
  (peb-crn-wheel (- cx r) (+ railY (- wd ov)) (+ cx r) (+ railY (- wd ov)))
  (peb-crn-wheel (- cx fl) railY (- cx r) railY)                      ; step out to the flanges
  (peb-crn-wheel (+ cx fl) railY (+ cx r) railY)
  (peb-crn-wheel (- cx fl) railY (- cx fl) (- railY ov))              ; flanges, lapping 15 down
  (peb-crn-wheel (+ cx fl) railY (+ cx fl) (- railY ov))
  (peb-crn-wheel (- cx fl) (- railY ov) (- cx r) (- railY ov))
  (peb-crn-wheel (+ cx fl) (- railY ov) (+ cx r) (- railY ov))
  (princ))

;; ── THE END CARRIAGE BODY - PURE GEOMETRY ──────────────────────────────────────────────────
;; Split out from the dimensioned detail so the SIDE VIEW can draw the same carriage in place,
;; at building scale, under each end of the bridge. Owner 5-Sep-2026: "Show the End Carriage as
;; well on the Crane BRIDGE Side View".
;;
;; Drawn IN PLANE - its full A2 length across the page, both wheels showing. Strictly, looking at
;; the bridge's side face the carriage runs into the page and only one wheel is visible; drawn
;; that way it came out as a 425 mm box against a 21 m span, which is honest and tells the reader
;; nothing. Every crane GA rotates it into the plane for this view, and so does this.
;;
;;   cx  centre of the carriage   ·   cy  TOP OF RAIL   ·   wb wheel base   ·   cap capacity
;;   k   enlargement (1.0 at building scale)
(defun peb-crn-carriage-body (cx cy wb cap k / wd lp dp ov r x0 x1 a b yb yt wy gx i)
  (setq wd (peb-crn-wheel-dia cap)     lp (peb-crn-wheel-overlap cap)
        dp (peb-crn-carriage-depth cap)   ov (peb-crn-carriage-over cap)
        r  (* k wd 0.5)
        ;; 100 tall, of which 25 laps below the top of rail (owner, 5-Sep-2026), so the wheel
        ;; centre is 25 above the rail and the box lands on the wheel top, 75 above it.
        wy (+ cy (* k (- (* wd 0.5) lp)))  ; wheel centre
        yb (+ cy (* k (peb-crn-carriage-soffit cap)))   ; box soffit - the wheel laps 50 into it
        yt (+ yb (* k dp))                ; top of the box, where the girder lands
        x0 (- cx (* k (+ wb ov) 0.5))     ; A2 overall
        x1 (+ cx (* k (+ wb ov) 0.5))
        a  (- cx (* k wb 0.5))            ; the two wheel centres, A1 apart
        b  (+ cx (* k wb 0.5)))
  ;; THE BOX
  (peb-crn-dash x0 yb x1 yb)
  (peb-crn-dash x0 yt x1 yt)
  (peb-crn-dash x0 yb x0 yt)
  (peb-crn-dash x1 yb x1 yt)
  (peb-crn-dash (+ x0 (* k 65.0)) yb (+ x0 (* k 65.0)) yt)      ; the end plates, A3 in
  (peb-crn-dash (- x1 (* k 65.0)) yb (- x1 (* k 65.0)) yt)
  ;; THE WHEELS, ON THE BOTTOM, RUNNING ON THE RAIL - round, double flanged
  (foreach gx (list a b)
    (progn
      (setq i 0)
      (while (< i 16)
        (peb-crn-wheel (+ gx (* r (cos (* i (/ pi 8.0))))) (+ wy (* r (sin (* i (/ pi 8.0)))))
                       (+ gx (* r (cos (* (1+ i) (/ pi 8.0)))))
                       (+ wy (* r (sin (* (1+ i) (/ pi 8.0))))))
        (setq i (1+ i)))
      (peb-crn-wheel (- gx (* r 0.16)) wy (+ gx (* r 0.16)) wy)                   ; axle
      ;; the flanges reach down to the bottom of the 25 that laps past the rail
      (peb-crn-wheel (- gx (* r 1.16)) (- cy (* k lp)) (- gx (* r 1.16)) (+ cy (* r 0.30)))
      (peb-crn-wheel (+ gx (* r 1.16)) (- cy (* k lp)) (+ gx (* r 1.16)) (+ cy (* r 0.30)))
      (peb-crn-wheel (- gx (* r 1.16)) (- cy (* k lp)) (- gx (* r 0.90)) (- cy (* k lp)))
      (peb-crn-wheel (+ gx (* r 1.16)) (- cy (* k lp)) (+ gx (* r 0.90)) (- cy (* k lp)))))
  ;; NO SEATS ON TOP. Owner 5-Sep-2026: "your drawings are showing boxes on the End Carriage.
  ;; there are no such boxes. Bridge Just Rest On It." This used to draw two raised seat boxes on
  ;; the carriage top, taken from the GH catalogue's double-girder arrangement where the girders
  ;; land at two bolted pads. On this crane the bridge simply lands on the top of the box, so the
  ;; top of the carriage is a plain line and nothing stands on it.
  ;; THE TRAVEL GEARMOTOR, on one wheel
  (peb-crn-motor (+ b (* r 1.3)) (+ yb (* k dp 0.18)) (+ b (* r 3.1)) (+ yb (* k dp 0.18)))
  (peb-crn-motor (+ b (* r 1.3)) (+ yb (* k dp 0.72)) (+ b (* r 3.1)) (+ yb (* k dp 0.72)))
  (peb-crn-motor (+ b (* r 1.3)) (+ yb (* k dp 0.18)) (+ b (* r 1.3)) (+ yb (* k dp 0.72)))
  (peb-crn-motor (+ b (* r 3.1)) (+ yb (* k dp 0.18)) (+ b (* r 3.1)) (+ yb (* k dp 0.72)))
  (princ))

;; ── THE SAME CARRIAGE, DIMENSIONED, AS ITS OWN DETAIL ──────────────────────────────────────
(defun peb-crn-carriage-elev (cx cy wb cap k th / wd dp ov x0 x1 a b r yb yt)
  (setq wd (peb-crn-wheel-dia cap)
        dp (peb-crn-carriage-depth cap)   ov (peb-crn-carriage-over cap)
        r  (* k wd 0.5)
        yb (+ cy (* k (peb-crn-carriage-soffit cap)))        yt (+ yb (* k dp))
        x0 (- cx (* k (+ wb ov) 0.5))     x1 (+ cx (* k (+ wb ov) 0.5))
        a  (- cx (* k wb 0.5))            b  (+ cx (* k wb 0.5)))
  ;; THE RAIL it runs on - Maimaar's steel, so solid
  (peb-crn-sample-solid (- x0 (* k 420.0)) cy (+ x1 (* k 420.0)) cy)
  (peb-crn-sample-solid (- x0 (* k 420.0)) (- cy (* k 50.0)) (+ x1 (* k 420.0)) (- cy (* k 50.0)))
  (txt "ML" (list (+ x1 (* k 500.0)) (- cy (* k 25.0))) (* th 0.9) 0.0
       "CRANE RAIL  (MAIMAAR SCOPE)")
  (peb-crn-carriage-body cx cy wb cap k)
  ;; dimensions and notes
  (peb-crn-dimh a b (+ yt (* k dp 1.5)) (strcat "WHEEL BASE  A1  " (rtos wb 2 0)) th)
  (peb-crn-dimh x0 x1 (+ yt (* k dp 2.4)) (strcat "OVERALL  A2  " (rtos (+ wb ov) 2 0)) th)
  (peb-crn-dimv yb yt (- x0 (* k 620.0)) (strcat "A10  " (rtos dp 2 0)) th)
  (peb-crn-note b cy (+ x1 (* k 500.0)) (+ cy (* k dp 0.55))
                (strcat "WHEEL  DIA " (rtos wd 2 0)
                        "  DOUBLE FLANGED, ON THE BOTTOM") th "ML")
  (peb-crn-note (+ b (* r 2.2)) (+ yb (* k dp 0.45)) (+ x1 (* k 500.0)) (+ yb (* k dp 1.15))
                "TRAVEL GEARMOTOR" th "ML")
  (peb-crn-note cx yt (- x0 (* k 620.0)) (+ yt (* k dp 0.95))
                (strcat "WELDED BOX  " (rtos (peb-crn-carriage-width cap) 2 0) " X "
                        (rtos (peb-crn-carriage-depth cap) 2 0)
                        " BOX  -  THE BRIDGE JUST RESTS ON TOP") th "MR")
  (txt "MC" (list cx (- cy (* k 50.0) (* th 2.2))) (* th 1.05) 0.0
       "END CARRIAGE  -  ONE AT EACH END OF THE BRIDGE")
  (txt "MC" (list cx (- cy (* k 50.0) (* th 3.9))) (* th 0.9) 0.0
       "OWNER'S MEASURED SIZES  -  CRANE SUPPLIER'S SCOPE, SHOWN FOR CLEARANCE")
  (princ))

(defun peb-crn-beam-detail (cx cy bd k th / bw ft wt sw st rh rw
                            y0 ybf ywt y1 yr xw xf xs wr gy ex ep i n rk rx ry
                            wd lp tw fw)
  (setq bw (peb-crn-beam-flange bd)  ft (peb-crn-flange-thk bd)
        wt (peb-crn-web-thk bd)      st (peb-crn-stiff-thk bd)
        sw (peb-crn-stiff-width bd)  rh (peb-crn-rail-depth bd)
        rw (peb-crn-rail-width bd)
        y0  cy                                   ; underside of the bottom flange
        ybf (+ cy (* k ft))                      ; top of the bottom flange
        ywt (+ cy (* k (+ ft bd)))               ; underside of the top flange
        y1  (+ cy (* k (+ ft bd ft)))            ; top of the top flange
        yr  (+ y1 (* k rh))                      ; top of rail
        xf  (* k (/ bw 2.0))                     ; flange half width
        xw  (* k (/ wt 2.0))                     ; web half thickness
        xs  (* k sw))                            ; stiffener reach

  ;; ══ 1. THE SECTION ═══════════════════════════════════════════════════════════════════════
  ;; NOTE WHAT IS NOT HERE: the stiffener. It reaches from the web face to the flange tip - that
  ;; is what makes it 108 - so drawing its outline in the section puts a line exactly on the
  ;; flange tips and the I closes up into a BOX, which is a different member. The cut falls
  ;; between stiffeners; they belong in the elevation beside this, and that is where they are.
  ;; BOTTOM FLANGE
  (peb-crn-sample-solid (- cx xf) y0  (+ cx xf) y0)
  (peb-crn-sample-solid (- cx xf) ybf (+ cx xf) ybf)
  (peb-crn-sample-solid (- cx xf) y0  (- cx xf) ybf)
  (peb-crn-sample-solid (+ cx xf) y0  (+ cx xf) ybf)
  ;; TOP FLANGE
  (peb-crn-sample-solid (- cx xf) ywt (+ cx xf) ywt)
  (peb-crn-sample-solid (- cx xf) y1  (+ cx xf) y1)
  (peb-crn-sample-solid (- cx xf) ywt (- cx xf) y1)
  (peb-crn-sample-solid (+ cx xf) ywt (+ cx xf) y1)
  ;; WEB - the two faces
  (peb-crn-sample-solid (- cx xw) ybf (- cx xw) ywt)
  (peb-crn-sample-solid (+ cx xw) ybf (+ cx xw) ywt)
  ;; THE RAIL, 50 x 50, on the beam centreline - foot / web / head, a railway track
  (setq wr (* k rw 0.5))
  (peb-crn-sample-solid (- cx wr) y1 (+ cx wr) y1)
  (peb-crn-sample-solid (- cx wr) (+ y1 (* k rh 0.26)) (+ cx wr) (+ y1 (* k rh 0.26)))
  (peb-crn-sample-solid (- cx wr) y1 (- cx wr) (+ y1 (* k rh 0.26)))
  (peb-crn-sample-solid (+ cx wr) y1 (+ cx wr) (+ y1 (* k rh 0.26)))
  (peb-crn-sample-solid (- cx wr) (+ y1 (* k rh 0.26)) (- cx (* wr 0.36)) (+ y1 (* k rh 0.40)))
  (peb-crn-sample-solid (+ cx wr) (+ y1 (* k rh 0.26)) (+ cx (* wr 0.36)) (+ y1 (* k rh 0.40)))
  (peb-crn-sample-solid (- cx (* wr 0.36)) (+ y1 (* k rh 0.40)) (- cx (* wr 0.36)) (+ y1 (* k rh 0.66)))
  (peb-crn-sample-solid (+ cx (* wr 0.36)) (+ y1 (* k rh 0.40)) (+ cx (* wr 0.36)) (+ y1 (* k rh 0.66)))
  (peb-crn-sample-solid (- cx (* wr 0.36)) (+ y1 (* k rh 0.66)) (- cx (* wr 0.72)) (+ y1 (* k rh 0.80)))
  (peb-crn-sample-solid (+ cx (* wr 0.36)) (+ y1 (* k rh 0.66)) (+ cx (* wr 0.72)) (+ y1 (* k rh 0.80)))
  (peb-crn-sample-solid (- cx (* wr 0.72)) (+ y1 (* k rh 0.80)) (- cx (* wr 0.72)) yr)
  (peb-crn-sample-solid (+ cx (* wr 0.72)) (+ y1 (* k rh 0.80)) (+ cx (* wr 0.72)) yr)
  (peb-crn-sample-solid (- cx (* wr 0.72)) yr (+ cx (* wr 0.72)) yr)
  ;; ── THE WHEEL, AT THE SIZE IT ACTUALLY IS ────────────────────────────────────────────────
  ;; Owner 5-Sep-2026: "Wheel Height is only 100mm and out of which 25mm is overlapped on the
  ;; Crane Beam" / "End View Will of Wheel will be small and Straight Lines."
  ;;
  ;; This is a section THROUGH the beam, so we are looking ALONG the runway and the wheel is
  ;; edge-on: what shows is the tread width and the two flanges, all straight lines. It used to
  ;; be drawn here by peb-crn-truck-sec - a spool wheel with a waisted middle, which is the view
  ;; from the SIDE of the wheel and belongs on the carriage elevation, not on this section.
  ;;
  ;; And it is SMALL: 100 tall against a 420 beam, with 25 of that lapping down past the top of
  ;; rail. The previous 250 came off the GH catalogue band; the 100 is measured.
  (setq wd (peb-crn-wheel-dia 10.0) lp (peb-crn-wheel-overlap 10.0)
        tw (* k (peb-crn-wheel-width 10.0) 0.5)  ; half the tread - the wheel is 18 wide
        fw (* k rw 0.52)                         ; half across the flanges, just outside the head
        gy (+ yr (* k (peb-crn-carriage-soffit 10.0)) (* k (peb-crn-carriage-depth 10.0))))
  ;; the two lines of the tread, off the rail head and up into the carriage
  (peb-crn-wheel (- cx tw) (- yr (* k lp)) (- cx tw) (+ yr (* k (- wd lp))))
  (peb-crn-wheel (+ cx tw) (- yr (* k lp)) (+ cx tw) (+ yr (* k (- wd lp))))
  (peb-crn-wheel (- cx tw) (+ yr (* k (- wd lp))) (+ cx tw) (+ yr (* k (- wd lp))))
  (peb-crn-wheel (- cx fw) yr (- cx tw) yr)                              ; step out to the flanges
  (peb-crn-wheel (+ cx fw) yr (+ cx tw) yr)
  (peb-crn-wheel (- cx fw) yr (- cx fw) (- yr (* k lp)))                 ; flanges, lapping 15 down
  (peb-crn-wheel (+ cx fw) yr (+ cx fw) (- yr (* k lp)))
  (peb-crn-wheel (- cx fw) (- yr (* k lp)) (- cx tw) (- yr (* k lp)))
  (peb-crn-wheel (+ cx fw) (- yr (* k lp)) (+ cx tw) (- yr (* k lp)))
  ;; THE END CARRIAGE sitting on it - a 300 x 300 box, with the top 50 of the wheel inside it
  (peb-crn-dash (- cx (* k 150.0)) (+ yr (* k (peb-crn-carriage-soffit 10.0)))
                (+ cx (* k 150.0)) (+ yr (* k (peb-crn-carriage-soffit 10.0))))
  (peb-crn-dash (- cx (* k 150.0)) (+ yr (* k (peb-crn-carriage-soffit 10.0))) (- cx (* k 150.0)) gy)
  (peb-crn-dash (+ cx (* k 150.0)) (+ yr (* k (peb-crn-carriage-soffit 10.0))) (+ cx (* k 150.0)) gy)
  (peb-crn-dash (- cx (* k 150.0)) gy (+ cx (* k 150.0)) gy)
  (peb-crn-dash (- cx (* k 210.0)) gy (+ cx (* k 210.0)) gy)             ; girder soffit over it
  (peb-crn-dash (- cx (* k 210.0)) gy (- cx (* k 210.0)) (+ gy (* k 260.0)))
  (peb-crn-dash (+ cx (* k 210.0)) gy (+ cx (* k 210.0)) (+ gy (* k 260.0)))
  ;; and the two figures the owner gave, on the drawing rather than in a note
  (peb-crn-dimv (- yr (* k lp)) (+ yr (* k (- wd lp))) (- cx (* fw 2.4))
                (rtos wd 2 0) th)
  (peb-crn-dimv (- yr (* k lp)) yr (+ cx (* fw 2.4))
                (rtos lp 2 0) th)
  ;; the gap dim goes on the LEFT - on the right it sat shoulder to shoulder with the 15 lap
  (peb-crn-dimv yr (+ yr (* k (peb-crn-rail-gap 10.0))) (- cx (* fw 4.2))
                (rtos (peb-crn-rail-gap 10.0) 2 0) th)
  (peb-crn-dimv (+ yr (* k (peb-crn-carriage-soffit 10.0))) gy (- cx (* k 230.0))
                (rtos (peb-crn-carriage-depth 10.0) 2 0) th)
  ;; THE BRACKET - the beam SITS ON IT (reference/1-2-1.png), so its top is at the bottom flange.
  ;; Mazzella, on measuring span: allow for "cantilevers or haunches that the runway beam may be
  ;; sitting on" - the haunch is why the runway centreline stands off the column.
  (peb-crn-sample-solid (- cx (* xf 4.6)) (- y0 (* k bd 1.05)) (- cx (* xf 4.6)) (+ y1 (* k bd 0.10)))
  (peb-crn-sample-solid (- cx (* xf 5.6)) (- y0 (* k bd 1.05)) (- cx (* xf 5.6)) (+ y1 (* k bd 0.10)))
  (peb-crn-sample-solid (- cx (* xf 4.6)) y0 (+ cx (* xf 1.25)) y0)
  (peb-crn-sample-solid (+ cx (* xf 1.25)) y0 (+ cx (* xf 1.25)) (- y0 (* k bd 0.12)))
  (peb-crn-sample-solid (+ cx (* xf 1.25)) (- y0 (* k bd 0.12))
                        (- cx (* xf 4.6)) (- y0 (* k bd 0.92)))
  (peb-crn-sample-solid (- cx (* xf 4.6)) (- y0 (* k bd 0.92)) (- cx (* xf 4.6)) y0)
  ;; section dimensions
  ;; clear BELOW the bracket haunch. Inside the web it printed over the section; at 0.30 below
  ;; the soffit it printed over the haunch diagonal, which crosses the centreline at about 0.29.
  (peb-crn-dimh (- cx xf) (+ cx xf) (- y0 (* k bd 1.15)) (strcat "FLANGE  " (rtos bw 2 0)) th)
  (peb-crn-dimv ybf ywt (+ cx (* xf 2.0)) (strcat "WEB  " (rtos bd 2 0)) th)
  (peb-crn-dimv y0 y1 (+ cx (* xf 3.1)) (strcat "OVERALL  " (rtos (+ bd ft ft) 2 0)) th)
  (txt "MC" (list cx (- y0 (* k bd 1.55))) (* th 1.05) 0.0 "SECTION")

  ;; ══ 2. THE ELEVATION - WHERE THE STIFFENERS LIVE ═════════════════════════════════════════
  ;; 128 stiffeners go into this job. They are the reason the section exists and they cannot be
  ;; shown in it, so the beam is drawn along its length beside it: rail on top, stiffener each
  ;; side of the web at spacing, bearing stiffeners over the bracket.
  ;; drawn at the TRUE spacing, two bays of it - an elevation with six stiffeners crammed into
  ;; 1.4 m would have been a picture of a beam nobody builds, and three bays made the elevation
  ;; so long that the section next to it could not be read.
  (setq n  2
        ex (+ cx (* xf 9.0))                                    ; left end of the elevation
        ep (* k (peb-crn-stiff-spacing 5936.0 8) n))            ; three bays at the real pitch
  (peb-crn-sample-solid ex y0 (+ ex ep) y0)                          ; bottom flange
  (peb-crn-sample-solid ex ybf (+ ex ep) ybf)
  (peb-crn-sample-solid ex ywt (+ ex ep) ywt)                        ; top flange
  (peb-crn-sample-solid ex y1 (+ ex ep) y1)
  (peb-crn-sample-solid ex y0 ex y1)
  (peb-crn-sample-solid (+ ex ep) y0 (+ ex ep) y1)
  (peb-crn-sample-solid ex y1 (+ ex ep) y1)
  ;; the rail running along the top, seen from the side: foot line and head line
  (peb-crn-sample-solid ex (+ y1 (* k rh 0.26)) (+ ex ep) (+ y1 (* k rh 0.26)))
  (peb-crn-sample-solid ex yr (+ ex ep) yr)
  (peb-crn-sample-solid ex y1 ex yr)
  (peb-crn-sample-solid (+ ex ep) y1 (+ ex ep) yr)
  ;; the stiffeners, at spacing
  (setq i 1)
  (while (<= i n)
    (setq rx (+ ex (* ep (/ (- i 0.5) (float n)))))
    (peb-crn-sample-solid rx ybf rx ywt)
    (setq i (1+ i)))
  (peb-crn-dimh (+ ex (* ep (/ 0.5 (float n)))) (+ ex (* ep (/ 1.5 (float n))))
                (+ yr (* k bd 0.22))
                (strcat "STIFFENER SPACING  " (rtos (peb-crn-stiff-spacing 5936.0 8) 2 0)
                        "  (8 PAIRS PER BEAM)") th)
  (txt "MC" (list (+ ex (/ ep 2.0)) (- y0 (* k bd 1.55))) (* th 1.05) 0.0
       "ELEVATION  -  ALONG THE BEAM")

  ;; ══ 3. THE RAIL, BLOWN UP AGAIN ══════════════════════════════════════════════════════════
  ;; Owner 5-Sep-2026: "You may see the Exact Shape the Crane Beam and Crane Rail on Top". At the
  ;; section's own enlargement a 50 mm rail on a 420 mm beam is a speck - correct, and useless.
  ;; So it gets its own scale, 5x the section's, and the two figures the trade actually quotes:
  ;; Mazzella label them RAIL HEAD WIDTH (B) and RAIL HEIGHT (D), which is what sets the wheel.
  ;; UNDER the elevation, not beside the title. At 5x the section scale a full 225 flange is
  ;; 11 m of paper - wider than the elevation it belongs to - so only a SHORT piece of flange is
  ;; cut, just enough either side of the rail to show it landing on the centreline.
  ;; between the two views, and low enough that its own dimensions clear their captions. Sitting
  ;; under the elevation it shared an x with "ELEVATION - ALONG THE BEAM" and its RAIL FOOT
  ;; dimension printed straight through it.
  (setq rk (* k 5.0) rx (+ cx (* xf 4.0)) ry (- y0 (* k bd 3.4))
        wr (* rk rw 0.5))
  (peb-crn-sample-solid (- rx wr) ry (+ rx wr) ry)
  (peb-crn-sample-solid (- rx wr) (+ ry (* rk rh 0.26)) (+ rx wr) (+ ry (* rk rh 0.26)))
  (peb-crn-sample-solid (- rx wr) ry (- rx wr) (+ ry (* rk rh 0.26)))
  (peb-crn-sample-solid (+ rx wr) ry (+ rx wr) (+ ry (* rk rh 0.26)))
  (peb-crn-sample-solid (- rx wr) (+ ry (* rk rh 0.26)) (- rx (* wr 0.36)) (+ ry (* rk rh 0.40)))
  (peb-crn-sample-solid (+ rx wr) (+ ry (* rk rh 0.26)) (+ rx (* wr 0.36)) (+ ry (* rk rh 0.40)))
  (peb-crn-sample-solid (- rx (* wr 0.36)) (+ ry (* rk rh 0.40)) (- rx (* wr 0.36)) (+ ry (* rk rh 0.66)))
  (peb-crn-sample-solid (+ rx (* wr 0.36)) (+ ry (* rk rh 0.40)) (+ rx (* wr 0.36)) (+ ry (* rk rh 0.66)))
  (peb-crn-sample-solid (- rx (* wr 0.36)) (+ ry (* rk rh 0.66)) (- rx (* wr 0.72)) (+ ry (* rk rh 0.80)))
  (peb-crn-sample-solid (+ rx (* wr 0.36)) (+ ry (* rk rh 0.66)) (+ rx (* wr 0.72)) (+ ry (* rk rh 0.80)))
  (peb-crn-sample-solid (- rx (* wr 0.72)) (+ ry (* rk rh 0.80)) (- rx (* wr 0.72)) (+ ry (* rk rh)))
  (peb-crn-sample-solid (+ rx (* wr 0.72)) (+ ry (* rk rh 0.80)) (+ rx (* wr 0.72)) (+ ry (* rk rh)))
  (peb-crn-sample-solid (- rx (* wr 0.72)) (+ ry (* rk rh)) (+ rx (* wr 0.72)) (+ ry (* rk rh)))
  ;; a slice of the top flange under it, so the "in the middle of the beam" reads
  (peb-crn-sample-solid (- rx (* wr 2.6)) ry (+ rx (* wr 2.6)) ry)
  (peb-crn-sample-solid (- rx (* wr 2.6)) (- ry (* rk ft)) (+ rx (* wr 2.6)) (- ry (* rk ft)))
  (peb-crn-sample-solid (- rx (* wr 2.6)) ry (- rx (* wr 2.6)) (- ry (* rk ft)))
  (peb-crn-sample-solid (+ rx (* wr 2.6)) ry (+ rx (* wr 2.6)) (- ry (* rk ft)))
  (peb-crn-dimh (- rx (* wr 0.72)) (+ rx (* wr 0.72)) (+ ry (* rk rh 1.30))
                (strcat "RAIL HEAD WIDTH  " (rtos (* rw 0.72) 2 0)) th)
  (peb-crn-dimh (- rx wr) (+ rx wr) (+ ry (* rk rh 1.90))
                (strcat "RAIL FOOT  " (rtos rw 2 0)) th)
  (peb-crn-dimv ry (+ ry (* rk rh)) (- rx (* rk bw 0.72))
                (strcat "RAIL HEIGHT  " (rtos rh 2 0)) th)
  (txt "MC" (list rx (- ry (* rk ft) (* th 2.4))) (* th 0.9) 0.0
       (strcat "ON THE " (rtos bw 2 0) " TOP FLANGE, ON THE BEAM CENTRELINE"))
  ;; CMAA/AISC put a number on "on the centreline": the eccentricity of the rail centreline from
  ;; the girder web may not exceed three quarters of the web thickness. On an 8 web that is 6 mm.
  (txt "MC" (list rx (- ry (* rk ft) (* th 4.0))) (* th 0.85) 0.0
       (strcat "CMAA/AISC: RAIL TO WEB ECCENTRICITY <= 0.75 x WEB  =  "
               (rtos (* wt 0.75) 2 0) " MAX"))
  (txt "MC" (list rx (- ry (* rk ft) (* th 4.0))) (* th 1.05) 0.0 "CRANE RAIL  -  BLOWN UP 5x")

  ;; ══ THE CALLOUTS ═════════════════════════════════════════════════════════════════════════
  (peb-crn-note (+ cx xw) (* 0.5 (+ ybf ywt)) (+ cx (* xf 5.4)) (* 0.5 (+ ybf ywt))
                (strcat "WEB PLATE   PL " (rtos wt 2 0) " X " (rtos bd 2 0)
                        "   (CRB-1 / CRB-2)") th "ML")
  (peb-crn-note (- cx (* xf 0.55)) (* 0.5 (+ ywt y1)) (- cx (* xf 6.4)) (+ y1 (* k bd 0.80))
                (strcat "TOP FLANGE   PL " (rtos ft 2 0) " X " (rtos bw 2 0)
                        "   (OF34 / OF35)") th "MR")
  (peb-crn-note (- cx (* xf 0.55)) (* 0.5 (+ y0 ybf)) (+ cx (* xf 5.4)) (- y0 (* k bd 0.16))
                (strcat "BOTTOM FLANGE   PL " (rtos ft 2 0) " X " (rtos bw 2 0)
                        "   (OF33 / OF37)") th "ML")
  ;; the leader must START ON THE ELEVATION: at 2.5/n it sat past the right end once the
  ;; elevation went from three bays to two, and drew a line out of empty space.
  (peb-crn-note (+ ex (* ep (/ 1.4 (float n)))) (* 0.5 (+ ybf ywt))
                (+ ex ep (* xf 0.8)) (+ ywt (* k bd 0.20))
                (strcat "STIFFENER   FL " (rtos st 2 0) " X " (rtos sw 2 0)
                        "   BOTH SIDES   (ST4, 128 OFF)") th "ML")
  (peb-crn-note cx (+ y1 (* k rh 0.5)) (- cx (* xf 6.4)) (+ y1 (* k bd 1.45))
                (strcat "CRANE RAIL   " (rtos rw 2 0) " X " (rtos rh 2 0)
                        " I-SECTION, LIKE A RAILWAY TRACK") th "MR")
  (peb-crn-note (- cx (* xf 2.2)) (- y0 (* k bd 0.42)) (- cx (* xf 6.4)) (- y0 (* k bd 0.78))
                "CRANE BEAM BRACKET / HAUNCH OFF THE COLUMN" th "MR")
  (peb-crn-note (- cx (* xf 5.1)) (+ ybf (* k bd 0.55)) (- cx (* xf 6.4)) (+ ybf (* k bd 0.90))
                "BUILDING COLUMN" th "MR")
  (peb-crn-note cx (- gy (* k 150.0)) (+ cx (* xf 4.2)) (+ y1 (* k bd 1.75))
                (strcat "END CARRIAGE  " (rtos (peb-crn-carriage-width 10.0) 2 0) " X "
                        (rtos (peb-crn-carriage-depth 10.0) 2 0)
                        " BOX  -  THE WHEEL LAPS "
                        (rtos (peb-crn-wheel-in-carriage 10.0) 2 0) " UP INTO IT") th "ML")
  (peb-crn-note cx (+ gy (* k bd 0.10)) (- cx (* xf 6.4)) (+ y1 (* k bd 2.10))
                (strcat "END CARRIAGE WHEEL  " (rtos wd 2 0) " HIGH X "
                        (rtos (peb-crn-wheel-width 10.0) 2 0) " WIDE, "
                        (rtos lp 2 0) " LAPPED ONTO THE RAIL  (CRANE - BY OTHERS)") th "MR")

  (txt "MC" (list (+ cx (* xf 5.0)) (+ y1 (* k bd 3.10))) (* th 1.5) 0.0
       "CRANE BEAM  -  SECTION, ELEVATION AND RAIL")
  (txt "MC" (list (+ cx (* xf 5.0)) (+ y1 (* k bd 2.70))) (* th 0.95) 0.0
       "PLATE SIZES READ OFF THE MSPL-032 SINGLE-PART SHEET  (MAIMAAR FACTORY, 10 MT)")
  (princ))

(defun peb-draw-crane-sample (span cap wbase / d et cl wb gw rw wr yc y0 yT x0 x1 th th1 th2 th3 th4 tl rx0 rx1 sy L hx hy rxc cbd cry gey pp pg1 pg2 pg3 pg4 dbi dby dbl dbw dbn)
  ;; STYLISED PROPORTIONS, stated as such (rule 20). Depth ~ span/18 is the working proportion for
  ;; a welded box girder in this capacity range; a job's own CRn_BRIDGE overrides it. Everything
  ;; TRACED is named on the sheet itself, so the drawing carries its own provenance.
  (setq d  (peb-crn-girder-depth span cap)
        ;; the girder's plan width from its own rule - the side view and the section both
        ;; work off peb-crn-girder-width, and the top view now does too
        gw (peb-crn-girder-width d)
        ;; `et` is now purely a LAYOUT PITCH - the spacing the top view's labels, dimension
        ;; lines and page window are set out on. It used to be the wheel base, which meant that
        ;; shortening the carriage from 3,900 to 1,500 would have collapsed the whole top view
        ;; along with it. The real carriage and its wheel base are cl and wb below.
        et (* d 3.0)
        cl (peb-crn-carriage-length cap)          ; END CARRIAGE, 1500 - owner, 5-Sep-2026
        wb (peb-crn-wheel-base cap)               ; the wheel base inside it, 1200
        rw (* d 0.30)
        wr (* d 0.16)
        th (* d 0.30)
        x0 0.0 x1 span
        tl (* gw 2.4))

  ;; ══ FOUR PAGES, NOT ONE SHEET ════════════════════════════════════════════════════════════
  ;; Owner 5-Sep-2026: "Or Better to Expand the Drawings on 4 Pages so that you may Review It
  ;; Closely To Develop the Right Product" / "Expand All Drawings During Development so that you
  ;; can do the Proper Audit".
  ;;
  ;; That is the right call and it replaces the two-column squeeze. One sheet forced every
  ;; drawing to share a scale set by the largest of them - the 21 m span - so the crane beam
  ;; section, the rail and the carriage were all plotted at a size chosen by something else. Four
  ;; pages let each drawing be plotted to fit ITS OWN page, which is what makes a detail
  ;; reviewable rather than merely present.
  ;;
  ;;      1  TOP VIEW           2  SIDE VIEW + HOIST DETAIL
  ;;      3  CRANE BEAM         4  END CARRIAGE + DATA
  ;;
  ;; The blocks are laid out down model space on a 90,000 pitch - far more than any block needs,
  ;; so a block can grow without ever reaching its neighbour - and the four plot windows are
  ;; recorded in *PEB-CRN-PAGES* for the render harness to plot one page each. Generous pitch is
  ;; deliberate: every collision on this sheet so far has come from a block's own head-room
  ;; reaching further than the gap allowed for it.
  (setq pp  90000.0
        pg1 0.0
        pg2 (- pp)
        pg3 (* -2.0 pp)
        pg4 (* -3.0 pp))

  ;; ── ONE TEXT SIZE ON PAPER (S57) ────────────────────────────────────────────────────────
  ;; A text height has to be chosen BEFORE the text is drawn, so unlike the page WINDOWS - which
  ;; are measured off the finished drawing - these are estimates of each page's final size. They
  ;; only have to be close: a 10 % error in text height is invisible, whereas a 10 % error in a
  ;; window clips a label off the sheet, which is why the two are worked out differently.
  (setq th1 (peb-crn-page-th (+ (* et 4.9) span) (* et 7.7)  (peb-crn-paper-text))
        th2 (peb-crn-page-th (+ (* d 25.0) span) (* d 16.0)  (peb-crn-paper-text))
        th3 (peb-crn-page-th (* span 3.70)       (* span 2.60) (peb-crn-paper-text))
        th4 (peb-crn-page-th (+ (* d 13.0) span) (* d 34.0)  (peb-crn-paper-text)))

  ;; ══ PAGE 1 - TOP VIEW ════════════════════════════════════════════════════════════════════
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
  (peb-crn-bridge-plan x0 y0 x1 yT cl (peb-crn-carriage-width cap) wb cap)
  (peb-crn-trolley-plan (/ span 2.0) y0 yT tl)
  (peb-crn-bridge-motor x0 1.0 cl y0 yT)          ; bridge travel motor on the left carriage
  (txt "MC" (list (/ span 2.0) (+ yc (* et 2.95))) (* th1 1.6) 0.0 "CRANE BRIDGE  -  TOP VIEW")
  (txt "MC" (list (/ span 2.0) (+ yc (* et 2.55))) (* th1 0.9) 0.0
       "CRANE BRIDGE, HOIST AND MOTORS - NOT IN MAIMAAR SCOPE (BY OTHERS)")
  (txt "MC" (list (/ span 2.0) (- yc (* gw 2.4))) (* th1 0.9) 0.0 "TROLLEY")
  (txt "MC" (list (/ span 2.0) (+ yc (* gw 3.1))) (* th1 0.9) 0.0 "HOIST MOTOR")
  (txt "ML" (list (+ x0 (* gw 2.2)) (- yc (* gw 2.9))) (* th1 0.9) 0.0 "BRIDGE TRAVEL MOTOR")
  (peb-crn-note x0 (+ yc (* cl 0.5)) (- x0 (* cl 0.55)) (+ yc (* cl 1.15))
                (strcat "END CARRIAGE  " (rtos cl 2 0) " LONG") (* th1 0.9) "MR")
  (txt "MC" (list x0 (- yc (* et 2.15))) (* th1 0.9) 0.0 "RUNWAY BEAM + RAIL")
  (peb-crn-note x1 (- yc (* wb 0.5)) (+ x1 (* et 0.45)) (- yc (* et 1.05))
                "2 WHEELS AT THE BOTTOM OF EACH END CARRIAGE" (* th1 0.9) "ML")
  (peb-crn-sample-dim x0 x1 (+ yc (* et 2.15))
                      (strcat "CRANE SPAN  -  C/C OF RUNWAY BEAMS   " (rtos span 2 0)) th1)
  (peb-crn-sample-dim x0 x1 (- yc (* et 2.50))
                      (strcat "BRIDGE TRAVELS ALONG THE RUNWAYS - END CARRIAGE " (rtos cl 2 0)
                              " LONG, WHEEL BASE " (rtos wb 2 0)) th1)

  ;; ══ PAGE 2 - SIDE VIEW ═══════════════════════════════════════════════════════════════════
  (setq sy (+ pg2 (* d 3.0)))
  (peb-crn-bridge-elev x0 sy x1 (+ sy d))
  ;; each END of the side view: the crane beam in section on its bracket, and the end truck
  ;; sitting on the rail carrying the girder. Beam and bracket are MAIMAAR'S steel, so solid.
  ;; THE CARRIAGE NEEDS ROOM TO BE SEEN. The rail sits 0.85 x girder-depth below the girder
  ;; underside — on the real machine the carriage is compact, but drawn at 0.30 the wheel had
  ;; nowhere to go and the girder appeared to rest straight on the rail. The gap is what shows
  ;; the wheel, and the wheel is what says the bridge travels.
  ;; THE CHAIN, AT ITS REAL PROPORTIONS. Girder soffit -> end carriage (300-350 deep) -> wheel
  ;; -> rail -> crane beam. The rail used to be placed 0.85 x girder depth below the soffit,
  ;; which is a made-up number; it is now carriage depth + 0.3 x wheel diameter below it, which
  ;; is what the GH table and the wheel actually give. On this sheet that is 420, not 1,190 -
  ;; and the step from a 1,400 girder onto a 345 carriage is the whole shape of the end.
  ;; the carriage sits under the REDUCED END WEB, not under the full-depth soffit - the whole
  ;; point of the reduction is that the girder end and the carriage are the same depth there.
  (setq cbd (peb-crn-beam-depth 6096.0 cap)
        gey (- (+ sy d) (min (* d 0.55) (peb-crn-girder-end-web)))   ; underside of the end web
        ;; girder end web lands on the carriage top; from there down it is 300 of box and then
        ;; the 25 of wheel that still shows below the box before the rail
        cry (- gey (peb-crn-carriage-depth cap) (peb-crn-carriage-soffit cap)))
  ;; END-ON, WITH ONE WHEEL. Owner 5-Sep-2026: "End Carriage End View Will be Show with One
  ;; Wheel End View" / "as other Side View will hide". Looking at the bridge's side face, the
  ;; carriage runs INTO the page: you see its width, and the near wheel hides the far one. It was
  ;; briefly drawn in plane here - rotated flat so both wheels showed - which is a common GA
  ;; convention but is not what this view sees. The full carriage, both wheels and all its
  ;; dimensions live in the END CARRIAGE detail further down the sheet, which is the right place
  ;; for them.
  (peb-crn-carriage-endon x0 cry gey cap)
  (peb-crn-carriage-endon x1 cry gey cap)
  (peb-crn-beam-sec x0 cry cbd (peb-crn-beam-flange cbd)
                    (- x0 (* d 1.90)) (function peb-crn-sample-solid))
  (peb-crn-beam-sec x1 cry cbd (peb-crn-beam-flange cbd)
                    (+ x1 (* d 1.90)) (function peb-crn-sample-solid))
  ;; ── THE TWO DEPTHS, DIMENSIONED ──────────────────────────────────────────────────────────
  ;; These are the figures the owner has been setting all along - "make the bridge depth to
  ;; 1200mm", "which reduces to 350-450mm on Edges" - so the view should state them rather than
  ;; leave them to be scaled off. The dim lines are solid because a dimension is drawing
  ;; furniture, not steel; the LINETYPE says whose scope the member is, and these are not members.
  (peb-crn-dimv sy (+ sy d) (* span 0.70) (rtos d 2 0) (* th2 0.9))
  (peb-crn-dimv (- (+ sy d) (min (* d 0.55) (peb-crn-girder-end-web))) (+ sy d)
                (+ x1 (* d 1.3))
                (rtos (min (* d 0.55) (peb-crn-girder-end-web)) 2 0) (* th2 0.9))
  (txt "MC" (list (/ span 2.0) (+ sy d (* th2 2.4))) (* th2 1.2) 0.0 "SIDE VIEW  -  ALONG THE GIRDER")
  (txt "ML" (list (+ x1 (* d 3.2)) (+ sy (* d 0.55))) (* th2 0.9) 0.0
       (strcat "CRANE BRIDGE - GIRDER DEPTH " (rtos d 2 0) "  (RULE: 500 + SPAN/30.5)  -  STRAIGHT BOX, ONE TAPERED CUT AT EACH END"))
  (txt "ML" (list (+ x1 (* d 3.2)) (- sy (* d 0.75))) (* th2 0.9) 0.0 "CRANE BEAM + RAIL  (MAIMAAR SCOPE - SOLID)")
  (txt "ML" (list (+ x1 (* d 3.2)) (- sy (* d 1.45))) (* th2 0.9) 0.0 "CRANE BEAM BRACKET  (MAIMAAR SCOPE)")
  (txt "MR" (list (- x0 (* d 2.4)) (- sy (* d 0.22))) (* th2 0.9) 0.0
       (strcat "END CARRIAGE  -  STRAIGHT BOX, ONLY " (rtos (peb-crn-carriage-depth cap) 2 0) " DEEP"))
  (txt "MR" (list (- x0 (* d 2.4)) (- sy (* d 0.62))) (* th2 0.9) 0.0 "WHEEL ON THE BOTTOM, ON THE RAIL")
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
  (txt "ML" (list (+ hx (* d 1.15)) (- sy (* d 0.55))) (* th2 0.9) 0.0 "HOIST (BY OTHERS)")
  (txt "ML" (list (+ hx (* d 1.15)) (- sy (* d 1.35))) (* th2 0.9) 0.0 "CRANE HOOK")
  (txt "MC" (list (/ span 2.0) (- sy (* d 2.6))) (* th2 0.85) 0.0
       "HOOK HEIGHT IS MEASURED FFL TO THE HOOK - IT SETS THE EAVE HEIGHT")

  ;; ══ PAGE 3 - CRANE BEAM: SECTION, ELEVATION AND RAIL ═════════════════════════════════════
  ;; On its own page the detail no longer has to be squeezed under the side view, so it gets its
  ;; datum straight from the page and its title has all the head-room it wants. (That head-room
  ;; is 16,865 units - k*420 + 3.10*k*400 - and misjudging it put this title on top of the side
  ;; view three times while everything was still on one sheet.)
  (setq sy (- pg3 (* d 4.0)))
  ;; 0.30 of the span, not 0.20. The section and the elevation share one scale, and at 0.20 the
  ;; 225-wide section stood beside a 3-bay elevation eight times its width - true to scale and
  ;; useless to read. Half the fix is here; the other half is the elevation, cut from three bays
  ;; to two (see peb-crn-beam-detail), which is still enough to show a spacing.
  (peb-crn-beam-detail (* span 0.34) sy cbd
                       (/ (* span 0.30) (+ cbd (* 2.0 (peb-crn-flange-thk cbd))))
                       (* th3 0.92))
  (setq sy (- sy (* span 0.42)))

  ;; ══ PAGE 2, LOWER - THE HOIST, ENLARGED ═════════════════════════════════════════════════
  ;; Spread, not crammed. The side view of a 21 m girder is a wide, short drawing: the page fits
  ;; it BY WIDTH, so the two views can be pushed apart until they fill the sheet's height without
  ;; either of them plotting one millimetre smaller. At 4.5 d the pair used half the page and the
  ;; other half was blank.
  ;; The page fits this block BY WIDTH - it is a 17.7 m girder with a note column beside it - so
  ;; the height is free until it runs out. An A1 sheet is 594/841 of its width, so the block can
  ;; be about 0.71 x its own width tall before the fit changes hands, and every millimetre up to
  ;; that point is page being used rather than page being wasted.
  ;;
  ;; MEASURED, and then solved - two guesses in a row were wrong in opposite directions.
  ;;
  ;; The catch is that the FRAME's margins scale with the page WIDTH (m = 3 % of it) while its
  ;; title strip scales with the height, so the framed aspect is not the content's aspect:
  ;;
  ;;      framed_W = 1.092 W        framed_H = 1.140 H + 0.062 W
  ;;
  ;; and the fit stays on the width only while framed_W / framed_H >= 841/594, i.e.
  ;;
  ;;      H <= 0.622 W
  ;;
  ;; Measured at 20 d the block was 50,232 x 37,793 - over that limit, so the fit changed hands
  ;; to the HEIGHT and everything on the page shrank. 17 d was still over it. 13.5 d gives about
  ;; 30,800 against a limit of 31,300: the two views sit at the top and bottom of the sheet at
  ;; the full width-fitted scale, which is the most page this drawing can use.
  (setq sy (- pg2 (* d 13.5)))

  ;; ══ HOIST DETAIL, AT LARGE SCALE ════════════════════════════════════════════════════════
  ;; The hoist drawn at true scale on a 21 m span is a blob — 3 m of machine against 21 m of
  ;; girder, and the 0.60 mm motor pen closes its fins. That is not a fault in the tracing, it is
  ;; what happens to any detail at building scale, and it is why the reference sheet shows the
  ;; hoist large. So it gets its own detail here, at roughly 4x, where the traced shape can
  ;; actually be judged: end cap, finned motor, shoulder, mid box, drum housing, sheave pin,
  ;; bolted bottom plate, hook.
  (peb-crn-hoist-elev (* span 0.30) sy (* span 0.34))
  (txt "MC" (list (* span 0.30) (+ sy (* th2 2.6))) (* th2 1.2) 0.0 "HOIST DETAIL  -  ENLARGED")
  (txt "ML" (list (* span 0.52) (- sy (* span 0.05))) (* th2 0.85) 0.0
       "TRACED FROM reference/crane-in-PEB-section_reference.webp")
  (txt "ML" (list (* span 0.52) (- sy (* span 0.09))) (* th2 0.85) 0.0
       "END CAP / FINNED MOTOR / SHOULDER / MID BOX / DRUM HOUSING / SHEAVE / PLATE / HOOK")

  ;; ══ THE END CARRIAGE ═════════════════════════════════════════════════════════════════════
  ;; Owner 5-Sep-2026: "There are End Carriage on Both Ends with Wheels on Bottom" / "with a
  ;; Wheel on bottom runs on Crane Rail". The top view shows two of them and the side view shows
  ;; them end-on, where the wheel base runs into the page and only one wheel of each is visible.
  ;; Neither view answers "what shape is it", so it gets its own elevation, drawn along the
  ;; runway where both wheels and the whole box can be seen.
  ;; drawn ACROSS THE SHEET, not tucked in a corner: a 4.5 m carriage 345 deep is a long thin
  ;; object, and at a third of the span its box came out barely taller than the text labelling
  ;; it. At 0.95 of the span the box is about 1.4 m of drawing and the wheels can be seen.
  ;; ══ PAGE 4 - END CARRIAGE ════════════════════════════════════════════════════════════════
  (setq sy (+ pg4 (* d 1.0)))
  (peb-crn-carriage-elev (* span 0.5) sy wb cap
                         (/ (* span 0.80) (+ wb (peb-crn-carriage-over cap)))
                         (* th4 0.92))
  (setq sy (- sy (* d 8.0)))

  ;; ══ THE DATA BLOCK - every number, and where it came from ════════════════════════════════
  ;; the data block used to sit under the hook drop and needed 6.4 d of air; it now follows the
  ;; end carriage, which ends cleanly, so 2.2 d is enough. The 6.4 left a hand's width of blank
  ;; sheet between the last drawing and the notes.
  ;; ══ PAGE 4, LOWER - THE DATA BLOCK ═══════════════════════════════════════════════════════
  (setq sy (- pg4 (* d 5.0)))
  ;; ── TWO COLUMNS, GUTTERED OFF THE LONGEST LINE ──────────────────────────────────────────
  ;; Set as one column this block ran 24 lines deep and about as wide as it was tall, which made
  ;; page 4 nearly square - and a square drawing on a 1.42 sheet is fitted by its HEIGHT and
  ;; plots small, throwing the width away. Two columns turn the same text into a wide, short
  ;; block and the whole page plots larger for nothing.
  ;;
  ;; The column offset is MEASURED off the longest line, not guessed. Guessed at 46 ems it was
  ;; shorter than the longest line and the two columns printed straight through each other.
  ;; romand carries no metrics here, so the width comes from peb-crn-em -
  ;; MEASURED at 0.94 em, not the 0.62 that was assumed and that made these two columns overlap.
  (setq dbl (list
      (strcat "CAPACITY  " (rtos cap 2 0) " MT  -  BSF MSPL-26-276, area 5172")
      (strcat "SPAN  " (rtos span 2 0) "  C/C OF RUNWAY BEAMS  -  BSF ; RUNWAY LENGTH 30,480")
      "HOOK HEIGHT  6,000 FFL TO HOOK  -  BSF ; SERVICE CLASS C, LOADING CATEGORY 3"
      "LOADS  84 VERTICAL / 11 HORIZONTAL  -  BSF ; MAKE: KONE, TOP RUNNING, PENDANT"
      "BUILDING  30,480 X 18,290, EAVE 10,670, BAYS 1@7,240 + 2@8,000 + 1@7,240  -  BSF"
      "SECTION SOURCE  the crane beam plates are MSPL-032's, not this job's  -  see sheet 3"
      "TYPE  TOP RUNNING (TR)  -  manual ch.8 lists TR / monorail / underhung / jib / semi-gantry"
      "END CARRIAGE WHEELS  2 PER END, 4 TOTAL  -  manual ch.8  NWb = 2  (worked 10 MT example)"
      "WHEEL  100 HIGH X 18 WIDE; 15 LAPS DOWN ONTO THE RAIL  -  owner, 5-Sep-2026"
      "   18 OF OPEN GAP ABOVE THE RAIL, THEN 67 INSIDE THE CARRIAGE  -  the 67 is DERIVED"
      "   (the GH catalogue band would give 250 at 10 MT - the measured figure is used)"
      "RUNWAY TOLERANCE  RAIL TO WEB ECCENTRICITY <= 0.75 x WEB THICKNESS  -  CMAA/AISC"
      "END CARRIAGE  WELDED BOX, WHEELS ON THE BOTTOM; THE BRIDGE JUST RESTS ON TOP"
      "   200 X 200 SQUARE BOX, 1500 LONG, UNDER A 1000-1400 GIRDER  -  owner, 5-Sep-2026"
      "WHEEL BASE  1200, FROM A 1500 CARRIAGE LESS 150 EACH END  -  owner"
      (strcat "   NOTE  the live BSF (MSPL-26-276) carries 3,900 ; CMAA guidance is >= span/7 = "
              (peb-crn-comma (/ span 7.0)))
      "   a short wheel base under a long span is what lets a crane skew on its runway"
      "   STACK  TOR -15 wheel bottom / 0 rail / +18 box soffit / +85 wheel top / +218 box top"
      "VERTICAL IMPACT  10%  PENDANT OPERATED  -  manual table 8.3"
      "CMAA SERVICE CLASS  C  -  manual table 8.1"
      "LONGITUDINAL  10% OF MAX WHEEL LOAD, AT TOP OF RAILS  -  manual ch.8 sec 2.4.4"
      "RUNWAY BEAM  BUILT-UP, DOUBLE SIDE FILLET WELD (<= 15 MT)  -  Thal 125-23 spec"
      "SCOPE IS SAID BY THE LABEL, NOT BY THE LINETYPE  -  ref: crane-in-PEB-section"
      "HOOK HEIGHT FFL-TO-HOOK SETS THE EAVE HEIGHT  -  manual, Eave Height guideline"
      "GIRDER DEPTH  (500 + span/30.5) x (cap/10)^0.20  -  1000 at 15,240 span, 1200 at 21,335"
      "GIRDER END  ONE TAPERED CUT TO A 400 DEEP STUB ~400 LONG, RESTING ON THE END CARRIAGE"
      "CRANE BEAM  bay/15 x (cap/10)^0.25, snapped to 25 ; 400 WEB AT A 6,096 BAY, 10 MT"
      "CRANE BEAM PLATES  WEB PL 8 X 400 / FLANGE PL 10 X 225 / STIFFENER FL 8 X 108"
      "   MSPL-032 single parts: CRB-1,2 x4 each ; OF33,34,35,37 x4 each ; ST4 x128"
      "   (225 - 8) / 2 = 108 - THE STIFFENER CONFIRMS BOTH THE FLANGE AND THE WEB"
      "GIRDER  1000 deep at 50 ft (15,240) span, 10 MT  -  Maimaar production, 2026")
        dbw 0)
  (foreach L dbl (setq dbw (max dbw (strlen L))))
  (setq dbw (* dbw th4 0.85 (peb-crn-em))                    ; the longest line
        dbn (fix (+ 0.99 (/ (length dbl) 2.0))))     ; lines per column, before adjustment
  ;; ...backed off to a GROUP BOUNDARY. A line that starts with a space is a continuation of the
  ;; one above it, so a column that begins on one starts mid-thought - which is how the wheel-base
  ;; group came to be split across the gutter, its heading at the foot of column 1 and its three
  ;; continuations at the head of column 2.
  (while (and (> dbn 1) (= " " (substr (nth dbn dbl) 1 1)))
    (setq dbn (1- dbn)))
  (setq
        dbi 0
        dby sy)
  (foreach L dbl
    (txt "ML" (list (+ x0 (if (< dbi dbn) 0.0 (+ dbw (* th4 3.0))))
                    (- dby (* th4 1.8 (rem dbi dbn))))
         (* th4 0.85) 0.0 L)
    (setq dbi (1+ dbi)))
  (setq sy (- dby (* th4 1.8 dbn)))

  ;; ── THE FOUR PLOT WINDOWS ────────────────────────────────────────────────────────────────
  ;; Fitted to each block rather than to a common box: the whole point of four pages is that a
  ;; small drawing is no longer plotted at the scale the biggest one needs. Read by
  ;; sample/render_sample.js, which plots one page per window and merges them into one PDF.
  ;; ── THE FOUR PAGES, FRAMED ──────────────────────────────────────────────────────────────
  ;; The windows are worked out first, then each one gets a border and title strip drawn round
  ;; it, and peb-crn-page-frame hands back the slightly larger window that includes the frame -
  ;; so the frame can never be the thing that falls off the edge of its own page.
  ;; ── THE FOUR PAGES ──────────────────────────────────────────────────────────────────────
  ;; Each window is the MEASURED extent of everything drawn in that page's band, padded a little,
  ;; then framed. peb-crn-page-frame hands back the window that includes its own border, so the
  ;; frame can never be the thing that falls off the edge of its own page.
  (setq *PEB-CRN-PAGES*
    (mapcar
      (function
        (lambda (pg)
          (peb-crn-page-frame
            (- (nth 0 (nth 1 pg)) (* (- (nth 2 (nth 1 pg)) (nth 0 (nth 1 pg))) 0.015))
            (- (nth 1 (nth 1 pg)) (* (- (nth 3 (nth 1 pg)) (nth 1 (nth 1 pg))) 0.030))
            (+ (nth 2 (nth 1 pg)) (* (- (nth 2 (nth 1 pg)) (nth 0 (nth 1 pg))) 0.015))
            (+ (nth 3 (nth 1 pg)) (* (- (nth 3 (nth 1 pg)) (nth 1 (nth 1 pg))) 0.030))
            (nth 2 pg) (nth 0 pg) 4 (* (nth 3 pg) 0.9) cap span)))
      (list
        (list 1 (peb-crn-band-extent (- pg1 (* pp 0.5)) (+ pg1 (* pp 0.5)))
                "CRANE BRIDGE  -  TOP VIEW" th1)
        (list 2 (peb-crn-band-extent (- pg2 (* pp 0.5)) (+ pg2 (* pp 0.5)))
                "SIDE VIEW ALONG THE GIRDER, AND THE HOIST" th2)
        (list 3 (peb-crn-band-extent (- pg3 (* pp 0.5)) (+ pg3 (* pp 0.5)))
                "CRANE BEAM  -  SECTION, ELEVATION AND RAIL" th3)
        (list 4 (peb-crn-band-extent (- pg4 (* pp 0.5)) (+ pg4 (* pp 0.5)))
                "END CARRIAGE, AND THE DATA THIS SHEET IS BUILT ON" th4))))
  (princ))

(defun C:PEB-CRANE-SAMPLE ( / )
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  ;; Component scale, not building scale - see the note in the wall-light sample: peb-th's ladder
  ;; is tuned for a 48 m building and would dwarf a girder drawn on its own.
  (setq *PEB-TEXT-SCALE* 1.0 *PEB-DIM-SCALE* 1.0)
  ;; ── DRIVEN BY THE LIVE BSF, PROPOSAL MSPL-26-276 ──────────────────────────────────────────
  ;; Owner 5-Sep-2026: "Keep working and Sync with Proposal 276-26."
  ;;
  ;; inquiry 5401, area 5172, component crane_system - read straight off the CRM:
  ;;
  ;;      capacity        10 MT            span            17.69 m
  ;;      hook height     6.0 m            wheel base      3.9 m
  ;;      runway length   30.48 m          type            Top Running (TR), Pendant
  ;;      service class   C                loading cat.    3
  ;;      manufacturer    Kone             loads           84 vert / 11 horiz
  ;;      building        30.48 x 18.29 m, eave 10.67, bays 1@7.24 + 2@8.00 + 1@7.24
  ;;
  ;; The span, capacity and wheel base come from there. The CRANE BEAM SECTION does NOT - it stays
  ;; anchored on MSPL-032, whose single-part sheet is the only place the actual plate sizes exist,
  ;; and it says so on its own page. Two sources, each named where it is used, rather than one
  ;; blurred set of numbers that belongs to neither job.
  (peb-draw-crane-sample 17690.0 10.0 3900.0)
  (command "_.ZOOM" "_E")
  (princ "\nCrane sample drawn: 4 pages, from BSF MSPL-26-276.")
  (princ))
