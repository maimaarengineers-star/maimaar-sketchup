;;; ===========================================================================================
;;;  MAIMAAR PEB — OVERHEAD CRANE
;;;  Library component. PURE GEOMETRY: this file draws, it never reads the data file and never
;;;  decides placement. The sheet works out where the crane goes and hands over coordinates.
;;;  Read ../GOLDEN_RULES.md first — rule 32 (indicative, not detailed) binds this component
;;;  harder than any other: a crane is the thing a customer looks hardest at, and an
;;;  approval-grade bracket detail on an A4 at 1:300 is exactly what that rule forbids.
;;; ===========================================================================================

;; ── THE DASHED PEN, OWNED HERE ─────────────────────────────────────────────────────────────
;; The crane is BY OTHERS, and this set says that with a short dash (CRANEBRG, 150/120 true mm) —
;; the same linetype the section and the plan already use, so the assembly cannot drift into two
;; pens (rule 3). Defined here rather than taken as an argument: AutoLISP cannot call a variable
;; holding a lambda as `(peb-crn-dash x y ...)`, that needs `apply`, and a component that quietly needs
;; its caller to pass a function is a component waiting to fall back silently.
(defun peb-crn-dash (xa ya xb yb / es)
  (if (not (tblsearch "LTYPE" "CRANEBRG"))
    (vl-catch-all-apply (function (lambda ()
      (entmake (list '(0 . "LTYPE") '(100 . "AcDbSymbolTableRecord")
                     '(100 . "AcDbLinetypeTableRecord") '(2 . "CRANEBRG") '(70 . 0)
                     '(3 . "Crane bridge . . . .") '(72 . 65) '(73 . 2) '(40 . 300.0)
                     '(49 . 0.0) '(74 . 0) '(49 . -300.0) '(74 . 0)))))))
  (setq es (if (> (getvar "LTSCALE") 0.0) (/ 1.0 (getvar "LTSCALE")) 1.0))
  (if (tblsearch "LTYPE" "CRANEBRG")
    (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC") (cons 6 "CRANEBRG")
                   (cons 48 es) (cons 370 15) (list 10 xa ya 0.0) (list 11 xb yb 0.0)))
    (entmake (list (cons 0 "LINE") (cons 8 "COMP-CRANE-SEC")
                   (list 10 xa ya 0.0) (list 11 xb yb 0.0)))))

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

;; ── THE BRIDGE IN PLAN ─────────────────────────────────────────────────────────────────────
;; Seen from above the bridge is a beam across the span with an end truck at each end riding the
;; runway. Same three rules: outline, the two girder edges, end trucks. The trolley is the
;; caller's — it carries the hook and belongs with the hoist.
;;
;;   x0 y0 x1 y1  the bridge in plan: runway to runway (y0/y1 = the girder's own width)
;;   et           end-truck length along the runway (0 = skip them)
(defun peb-crn-bridge-plan (x0 y0 x1 y1 et / w gw)
  (setq w (abs (- x1 x0)) gw (abs (- y1 y0)))
  (if (or (< w 1.0) (< gw 1.0))
    (princ)
    (progn
      (peb-crn-dash x0 y0 x1 y0) (peb-crn-dash x1 y0 x1 y1) (peb-crn-dash x1 y1 x0 y1) (peb-crn-dash x0 y1 x0 y0)
      ;; END TRUCKS — the frames that carry the bridge onto the rails. Drawn across the girder
      ;; at each end, wider than the girder, because that is what they are.
      (if (> et 1.0)
        (progn
          (peb-crn-dash x0 (- y0 (* gw 0.35)) (+ x0 et) (- y0 (* gw 0.35)))
          (peb-crn-dash x0 (+ y1 (* gw 0.35)) (+ x0 et) (+ y1 (* gw 0.35)))
          (peb-crn-dash (- x1 et) (- y0 (* gw 0.35)) x1 (- y0 (* gw 0.35)))
          (peb-crn-dash (- x1 et) (+ y1 (* gw 0.35)) x1 (+ y1 (* gw 0.35)))
          (peb-crn-dash x0 (- y0 (* gw 0.35)) x0 (+ y1 (* gw 0.35)))
          (peb-crn-dash x1 (- y0 (* gw 0.35)) x1 (+ y1 (* gw 0.35)))))
      (princ))))

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

(defun peb-draw-crane-sample (span cap / d et gw rw y0 yT x0 x1 th tx)
  ;; ── the girder, sized from the span ──────────────────────────────────────────────────────
  ;; Depth ~ span/18 is the working proportion for a welded box girder in this capacity range;
  ;; STYLISED (rule 20) — the real depth comes from the BSF's CRn_BRIDGE when a job states it.
  (setq d  (/ span 18.0)                 ; girder depth
        et (* d 1.60)                    ; end-truck length along the runway
        gw (* d 0.55)                    ; girder width, seen in plan
        rw (* d 0.35)                    ; runway beam width, seen in plan
        th (/ span 40.0)                 ; annotation height, proportional to what is drawn
        x0 0.0
        x1 span)

  ;; ── SIDE VIEW (along the girder) ─────────────────────────────────────────────────────────
  (setq y0 0.0 yT (+ y0 d))
  (peb-crn-bridge-elev x0 y0 x1 yT)
  ;; the two rails it lands on, and the end trucks bearing onto them
  (peb-crn-dash (- x0 (* et 0.6)) (- y0 (* d 0.55)) (+ x0 (* et 1.1)) (- y0 (* d 0.55)))
  (peb-crn-dash (- x1 (* et 1.1)) (- y0 (* d 0.55)) (+ x1 (* et 0.6)) (- y0 (* d 0.55)))
  (peb-crn-dash x0 y0 x0 (- y0 (* d 0.55)))
  (peb-crn-dash x1 y0 x1 (- y0 (* d 0.55)))
  (if (boundp 'txt)
    (progn
      (txt "MC" (list (/ span 2.0) (+ yT (* th 2.2))) th 0.0 "BRIDGE - SIDE VIEW (ALONG THE GIRDER)")
      (txt "ML" (list (+ x1 (* th 1.2)) (+ y0 (/ d 2.0))) (* th 0.8) 0.0
           (strcat "GIRDER DEPTH " (rtos d 2 0)))
      (txt "ML" (list (+ x1 (* th 1.2)) (- y0 (* d 0.55))) (* th 0.8) 0.0 "RUNWAY RAIL")))
  (peb-crn-sample-dim x0 x1 (- y0 (* d 1.7))
                      (strcat "CRANE SPAN  " (rtos span 2 0)) th)

  ;; ── TOP VIEW (from above), stacked below the side view ───────────────────────────────────
  (setq y0 (- 0.0 (* d 4.6)) yT (+ y0 gw))
  (peb-crn-bridge-plan x0 y0 x1 yT et)
  ;; the two runway beams the end trucks ride, running perpendicular to the girder
  (peb-crn-dash (- x0 (* et 0.6)) (- y0 (* gw 0.95)) (- x0 (* et 0.6)) (+ yT (* gw 0.95)))
  (peb-crn-dash (- x0 (* et 0.6) rw) (- y0 (* gw 0.95)) (- x0 (* et 0.6) rw) (+ yT (* gw 0.95)))
  (peb-crn-dash (+ x1 (* et 0.6)) (- y0 (* gw 0.95)) (+ x1 (* et 0.6)) (+ yT (* gw 0.95)))
  (peb-crn-dash (+ x1 (* et 0.6) rw) (- y0 (* gw 0.95)) (+ x1 (* et 0.6) rw) (+ yT (* gw 0.95)))
  ;; the trolley, riding the girder at mid-span
  (setq tx (/ span 2.0))
  (peb-crn-dash (- tx (* gw 1.1)) (- y0 (* gw 0.30)) (+ tx (* gw 1.1)) (- y0 (* gw 0.30)))
  (peb-crn-dash (- tx (* gw 1.1)) (+ yT (* gw 0.30)) (+ tx (* gw 1.1)) (+ yT (* gw 0.30)))
  (peb-crn-dash (- tx (* gw 1.1)) (- y0 (* gw 0.30)) (- tx (* gw 1.1)) (+ yT (* gw 0.30)))
  (peb-crn-dash (+ tx (* gw 1.1)) (- y0 (* gw 0.30)) (+ tx (* gw 1.1)) (+ yT (* gw 0.30)))
  (if (boundp 'txt)
    (progn
      (txt "MC" (list (/ span 2.0) (+ yT (* th 2.2))) th 0.0 "BRIDGE - TOP VIEW (FROM ABOVE)")
      (txt "MC" (list tx (- y0 (* th 1.6))) (* th 0.8) 0.0 "TROLLEY")
      (txt "MC" (list x0 (+ yT (* th 1.4))) (* th 0.8) 0.0 "END TRUCK")
      (txt "MC" (list (- x0 (* et 0.6) (/ rw 2.0)) (- y0 (* gw 2.6))) (* th 0.8) 90.0 "RUNWAY BEAM")
      (txt "MC" (list (/ span 2.0) (- y0 (* d 2.1))) (* th 0.9) 0.0
           (strcat (rtos cap 2 0) " MT  -  BRIDGE BY OTHERS (SHOWN DOTTED)"))))
  (princ))

(defun C:PEB-CRANE-SAMPLE ( / )
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  ;; Component scale, not building scale — see the note in the wall-light sample: peb-th's ladder
  ;; is tuned for a 48 m building and would dwarf a 21 m girder drawn on its own.
  (setq *PEB-TEXT-SCALE* 1.0 *PEB-DIM-SCALE* 1.0)
  ;; Thal 125-23, traced: 10 MT on a 21.335 m span.
  (peb-draw-crane-sample 21335.0 10.0)
  (command "_.ZOOM" "_E")
  (princ "\nBridge sample drawn: TOP + SIDE view.")
  (princ))
