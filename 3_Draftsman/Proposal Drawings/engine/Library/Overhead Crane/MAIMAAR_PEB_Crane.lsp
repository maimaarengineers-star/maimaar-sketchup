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
  (setq nm (strcat "CRNDOT" (itoa (fix pitch))))
  (if (not (tblsearch "LTYPE" nm))
    (vl-catch-all-apply (function (lambda ()
      (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbLinetypeTableRecord") (cons 2 nm) '(70 . 0)
                     (cons 3 (strcat "Crane dotted " (itoa (fix pitch)))) '(72 . 65) '(73 . 2)
                     (cons 40 pitch) '(49 . 0.0) '(74 . 0) (cons 49 (- pitch)) '(74 . 0)))))))
  (setq es (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
  (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC")
                 (cons 6 (if (tblsearch "LTYPE" nm) nm "HIDDEN"))
                 (cons 48 es) (cons 370 (fix lw))
                 (list 10 xa ya 0.0) (list 11 xb yb 0.0))))

;; the rungs
(defun peb-crn-dash  (xa ya xb yb) (peb-crn-pen xa ya xb yb 130.0 35))  ; girder / main beam
(defun peb-crn-truck (xa ya xb yb) (peb-crn-pen xa ya xb yb  90.0 30))  ; end truck, trolley
(defun peb-crn-wheel (xa ya xb yb) (peb-crn-pen xa ya xb yb  70.0 25))  ; wheels
(defun peb-crn-motor (xa ya xb yb) (peb-crn-pen xa ya xb yb  40.0 50))  ; MOTOR - densest, heaviest

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
(defun peb-crn-bridge-elev (x0 y0 x1 y1 / w d fl st n i x)
  (setq w (abs (- x1 x0))
        d (abs (- y1 y0)))
  (if (or (< w 1.0) (< d 1.0))
    (princ)
    (progn
      ;; the girder outline
      (peb-crn-dash x0 y0 x1 y0) (peb-crn-dash x1 y0 x1 y1) (peb-crn-dash x1 y1 x0 y1) (peb-crn-dash x0 y1 x0 y0)
      (setq fl (* d 0.18))                        ; flange thickness as a fraction of the depth
      (if (> d (* fl 4.0))
        (progn
          (peb-crn-dash x0 (+ y0 fl) x1 (+ y0 fl))        ; bottom flange
          (peb-crn-dash x0 (- y1 fl) x1 (- y1 fl))))      ; top flange
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

;; ── THE BRIDGE IN PLAN (TOP VIEW), WITH ITS COMPONENTS ────────────────────────────────────
;;
;; Seen from above: the girder spanning between the two runways, an END TRUCK at each end, and
;; the WHEELS that carry it onto the rails.
;;
;; TRACED TO THE MANUAL, not chosen. Mammut design manual ch.8 "Crane Loads" (MBMA 02 / 06),
;; symbol list: "NWb = Number of end truck wheels at ONE END of the bridge", and its worked
;; 10 MT example states plainly "Number of end truck wheels = 2". So a bridge rides on FOUR
;; wheels, two per end truck. That is a fact about the object and the top view has to show it —
;; an end truck drawn as a bare box does not.
;;
;;   x0 y0 x1 y1  the girder in plan: rail centre to rail centre; y0/y1 = the girder's own width
;;   et           end-truck length along the runway (0 = skip the trucks)
;;   wr           wheel radius (0 = skip the wheels)
(defun peb-crn-bridge-plan (x0 y0 x1 y1 et wr / w gw yc eo wOfs e sgn ex xw)
  (setq w (abs (- x1 x0)) gw (abs (- y1 y0)) yc (/ (+ y0 y1) 2.0))
  (if (or (< w 1.0) (< gw 1.0))
    (princ)
    (progn
      (peb-crn-dash x0 y0 x1 y0) (peb-crn-dash x1 y0 x1 y1)
      (peb-crn-dash x1 y1 x0 y1) (peb-crn-dash x0 y1 x0 y0)
      (setq eo (* gw 0.60))                     ; how far the end truck stands proud of the girder
      (if (> et 1.0)
        (foreach e (list (list x0 1.0) (list x1 -1.0))
          (setq sgn (cadr e) ex (car e))
          ;; END TRUCK — the frame carrying the bridge onto the rail: across the girder and
          ;; wider than it, because that is what it is.
          (peb-crn-truck ex (- y0 eo) (+ ex (* sgn et)) (- y0 eo))
          (peb-crn-truck ex (+ y1 eo) (+ ex (* sgn et)) (+ y1 eo))
          (peb-crn-truck ex (- y0 eo) ex (+ y1 eo))
          (peb-crn-truck (+ ex (* sgn et)) (- y0 eo) (+ ex (* sgn et)) (+ y1 eo))
          ;; TWO WHEELS PER END TRUCK (manual: NWb = 2), at the truck's wheel base.
          (if (> wr 1.0)
            (progn
              (setq wOfs (* et 0.28))
              (foreach xw (list (+ ex (* sgn wOfs)) (+ ex (* sgn (- et wOfs))))
                (peb-crn-wheel (- xw wr) (- yc (* gw 1.05)) (+ xw wr) (- yc (* gw 1.05)))
                (peb-crn-wheel (- xw wr) (+ yc (* gw 1.05)) (+ xw wr) (+ yc (* gw 1.05)))
                (peb-crn-wheel (- xw wr) (- yc (* gw 1.05)) (- xw wr) (- yc (* gw 0.70)))
                (peb-crn-wheel (+ xw wr) (- yc (* gw 1.05)) (+ xw wr) (- yc (* gw 0.70)))
                (peb-crn-wheel (- xw wr) (+ yc (* gw 0.70)) (- xw wr) (+ yc (* gw 1.05)))
                (peb-crn-wheel (+ xw wr) (+ yc (* gw 0.70)) (+ xw wr) (+ yc (* gw 1.05))))))))
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

(defun peb-draw-crane-sample (span cap wbase / d et gw rw wr yc y0 yT x0 x1 th tl rx0 rx1 sy L hx hy)
  ;; STYLISED PROPORTIONS, stated as such (rule 20). Depth ~ span/18 is the working proportion for
  ;; a welded box girder in this capacity range; a job's own CRn_BRIDGE overrides it. Everything
  ;; TRACED is named on the sheet itself, so the drawing carries its own provenance.
  (setq d  (/ span 18.0)
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
  (peb-crn-sample-solid rx0 (- y0 (* gw 2.6)) rx1 (- y0 (* gw 2.6)))
  (peb-crn-sample-solid rx0 (- y0 (* gw 1.4)) rx1 (- y0 (* gw 1.4)))
  (peb-crn-sample-solid rx0 (+ yT (* gw 1.4)) rx1 (+ yT (* gw 1.4)))
  (peb-crn-sample-solid rx0 (+ yT (* gw 2.6)) rx1 (+ yT (* gw 2.6)))
  (peb-crn-bridge-plan x0 y0 x1 yT et wr)
  (peb-crn-trolley-plan (/ span 2.0) y0 yT tl)
  (peb-crn-bridge-motor x0 1.0 et y0 yT)          ; bridge travel motor on the left truck
  (txt "MC" (list (/ span 2.0) (+ yT (* gw 6.4))) (* th 1.6) 0.0 "CRANE BRIDGE  -  TOP VIEW")
  (txt "MC" (list (/ span 2.0) (+ yT (* gw 5.4))) (* th 0.9) 0.0
       "(BRIDGE SHOWN DOTTED - NORMALLY NOT IN MAIMAAR SCOPE)")
  (txt "MC" (list (/ span 2.0) (- y0 (* gw 4.4))) (* th 0.9) 0.0 "TROLLEY")
  (txt "MC" (list (/ span 2.0) (+ yT (* gw 2.3))) (* th 0.9) 0.0 "HOIST MOTOR")
  (txt "ML" (list (+ x0 (* et 0.9)) (- y0 (* gw 2.2))) (* th 0.9) 0.0 "BRIDGE TRAVEL MOTOR")
  (txt "ML" (list (+ x0 (* et 0.15)) (+ yT (* gw 3.2))) (* th 0.9) 0.0 "END TRUCK")
  (txt "ML" (list rx0 (- y0 (* gw 3.4))) (* th 0.9) 0.0 "RUNWAY BEAM + RAIL")
  (txt "MC" (list (+ x0 (/ et 2.0)) (- y0 (* gw 5.4))) (* th 0.9) 0.0 "2 WHEELS PER END TRUCK")
  (peb-crn-sample-dim x0 x1 (+ yT (* gw 4.0))
                      (strcat "CRANE SPAN  C/C RAILS   " (rtos span 2 0)) th)
  (if (> wbase 0.0)
    (peb-crn-sample-dim x0 (+ x0 et) (- y0 (* gw 6.6))
                        (strcat "WHEEL BASE  " (rtos wbase 2 0)) th))

  ;; ══ SIDE VIEW - below, for reference ═════════════════════════════════════════════════════
  (setq sy (- 0.0 (* d 9.5)))
  (peb-crn-bridge-elev x0 sy x1 (+ sy d))
  (peb-crn-sample-solid (- x0 (* et 1.1)) (- sy (* d 0.55)) (+ x0 (* et 1.1)) (- sy (* d 0.55)))
  (peb-crn-sample-solid (- x1 (* et 1.1)) (- sy (* d 0.55)) (+ x1 (* et 1.1)) (- sy (* d 0.55)))
  (peb-crn-dash x0 sy x0 (- sy (* d 0.55)))
  (peb-crn-dash x1 sy x1 (- sy (* d 0.55)))
  (txt "MC" (list (/ span 2.0) (+ sy d (* th 2.4))) (* th 1.2) 0.0 "SIDE VIEW  -  ALONG THE GIRDER")
  (txt "ML" (list (+ x1 (* th 1.0)) (+ sy (/ d 2.0))) (* th 0.9) 0.0
       (strcat "GIRDER DEPTH " (rtos d 2 0) "  (STYLISED - SPAN/18)"))
  (txt "ML" (list (+ x1 (* th 1.0)) (- sy (* d 0.55))) (* th 0.9) 0.0 "RUNWAY RAIL")
  ;; ── THE HOIST MOTOR AND THE HOOK — WHAT THE BUILDING HEIGHT IS QUOTED TO ──────────────────
  ;; Owner 5-Sep-2026: "Motor with Crane Hook. Mostly Gives the Height of Building from FFL to
  ;; Crane Hook (Crane Hook Height)". The manual says the same from the other end — "Eave height
  ;; is a function of ... Clearance above Crane beam / Crane hook height requirement" (GUIDELINE
  ;; FOR DESIGN OF METAL BUILDING, Eave Height). So the hook is not decoration on this view: it
  ;; is the datum the customer's building height is set from, and the side view is where that
  ;; chain is visible — girder, motor, hook, and the drop to FFL.
  (setq hx (/ span 2.0) hy (- sy (* d 2.9)))
  ;; hoist motor sitting on the girder
  (peb-crn-motor (- hx (* d 0.55)) sy (+ hx (* d 0.55)) sy)
  (peb-crn-motor (- hx (* d 0.55)) (- sy (* d 0.62)) (+ hx (* d 0.55)) (- sy (* d 0.62)))
  (peb-crn-motor (- hx (* d 0.55)) sy (- hx (* d 0.55)) (- sy (* d 0.62)))
  (peb-crn-motor (+ hx (* d 0.55)) sy (+ hx (* d 0.55)) (- sy (* d 0.62)))
  (peb-crn-motor (- hx (* d 0.55)) (- sy (* d 0.31)) (+ hx (* d 0.55)) (- sy (* d 0.31)))
  ;; the rope drop and the hook
  (peb-crn-truck hx (- sy (* d 0.62)) hx hy)
  (peb-crn-truck (- hx (* d 0.22)) hy (+ hx (* d 0.22)) hy)
  (peb-crn-truck (- hx (* d 0.22)) hy (- hx (* d 0.22)) (- hy (* d 0.30)))
  (peb-crn-truck (+ hx (* d 0.22)) hy (+ hx (* d 0.22)) (- hy (* d 0.30)))
  (peb-crn-truck hx (- hy (* d 0.30)) hx (- hy (* d 0.75)))
  (txt "ML" (list (+ hx (* d 0.8)) (- sy (* d 0.31))) (* th 0.9) 0.0 "HOIST MOTOR")
  (txt "ML" (list (+ hx (* d 0.8)) (- hy (* d 0.40))) (* th 0.9) 0.0 "CRANE HOOK")
  (txt "MC" (list hx (- hy (* d 1.7))) (* th 0.9) 0.0
       "HOOK HEIGHT IS MEASURED FFL TO HERE - IT SETS THE EAVE HEIGHT")

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
      "MOTORS SHOWN FOR IDENTIFICATION - the manual names no bridge/hoist motor"
      "HOOK HEIGHT FFL-TO-HOOK SETS THE EAVE HEIGHT  -  manual, Eave Height guideline")
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
