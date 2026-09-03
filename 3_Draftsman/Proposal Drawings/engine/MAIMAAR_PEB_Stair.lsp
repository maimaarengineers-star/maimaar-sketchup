;; ============================================================================
;; MAIMAAR_PEB_Stair.lsp  --  STAIRCASE DETAIL SHEET  (PRO-10)
;; ----------------------------------------------------------------------------
;; A staircase drawn as a staircase, at detail scale, on its own sheet.
;;
;; WHY A SEPARATE SHEET (owner 1-Sep-2026: "Make the Totally seperate Section of the
;; Staircase ... along with showing in the building sections").  On the Column Layout Plan a
;; stair is a 1,200 mm band on a 76 m building - at 1:200 its treads fall 0.3 mm apart and every
;; label collides.  The building plan therefore shows WHERE the stair is; this sheet shows WHAT
;; it is.  Two drawings, two jobs, one set of ST<n>_* facts behind both.
;;
;; REFERENCE, NOT INVENTION.  Every element and every string below is lifted from the Mammut
;; Technical Manual, Chapter 12 "STAIRCASE & LADDERS", Section 12.1, sheets 3 and 5 of 13
;; (Design Manual/Technical Manual.pdf p309 and p311) - see PD_RULEBOOK.md, "STAIRCASE - the
;; Mammut convention".  The manual standard is a flight with a TOP landing and, where the climb
;; needs it, a MID landing; that is exactly what ST<n>_TOP_LANDING / ST<n>_MID_LANDING already
;; carry, so this sheet draws the manual case without inventing a new field.
;;
;; The manual names these parts, and so do we, verbatim:
;;   STRINGER . TREAD (TYP.) . TOP LANDING BEAM . TOP LANDING PLATFORM . MID-LANDING BEAM .
;;   MID-LANDING PLATFORM . MID-LANDING POST . CABLE BRACING . UP . STAIRCASE LENGTH
;;
;; All text is ROMAND and dimension arrows are OPEN (house rules).  Raw mm throughout; only
;; txt-bold divides its height by *PEB-TEXT-SCALE*.
;; ============================================================================

;; ---- THE STEP STANDARD  (owner 1-Sep-2026) ----------------------------------------------
;; "Tread will be of 300mm and Riser of 150mm - Standard. (Default)"
;;
;; A HOUSE RULE, and it outranks both of the numbers that were here before: the 280 going I
;; measured off 055-MSPL, and the 175 riser I had INFERRED from the drawn pitch because neither
;; manual ever dimensions a riser.  One job is a data point; the house standard is the rule.
;;
;; It is also the better stair.  2R + G = 600, mid-range of the 550-700 comfort rule, at a 26.6
;; degree pitch instead of 32.  Everything downstream - flight length, footprint, how many
;; landings the international rule demands - is derived from these two numbers, so they are the
;; only place a job standard needs to change.
;; ---- THE STAIR SHEET'S TEXT HEIGHT  (owner 3-Sep-2026) -----------------------------------
;; "enlarge the staircase labelling text, still not visible properly."
;;
;; Every drawer on this sheet sized its text as `u * 1.6`, where u is the stair WIDTH over 12 -
;; 100 mm on a 1,200 stair, so 160 model units of text.  At the sheet's own 1:143 that plots at
;; 1.1 mm: under half the 2.5 mm the rest of the set uses, and below the size a printed A4 can
;; hold at all.  The stair was sizing its lettering off the stair instead of off the sheet -
;; rule 4B.1, the one fault this engine keeps repeating.
;;
;; One factor, one place - and it is still 1.6 TODAY, on purpose.  Raising it alone makes the
;; sheet WORSE, which is worth recording: at 3.5 the text grew but every gap around it did not,
;; because this sheet positions its labels in multiples of `u` - "5400 FLIGHT RUN" ran into
;; "1200 LANDING", the floor names ran into PLAN and ELEVATION, and the bigger extents dropped
;; the auto-fit from 1:143 to 1:182, so most of the gain was handed straight back.
;;
;; Rule 4B.27 is the answer: a gap that exists to clear TEXT must be computed from that text's
;; height, never from a number that happened to suit one size.  So the enlargement lands with
;; the label-gap rework, not before it - and when it does, it changes here, once.
(defun peb-stair-th (u) (* u 2.2))

(defun peb-stair-going () 300.0)   ; TREAD

;; ---- STANDING RULE: ALL RISERS MUST BE EQUAL  (owner 3-Sep-2026) -------------------------
;; This REVERSES the 1-Sep implementation, and the reversal is the right way round.
;;
;; The riser was held at exactly 150 and the remainder taken at the base, so a 5,380 storey drew
;; 36 x 150 = 5,400 and the stair sprang from -20.  Every riser measured 150 - except the first
;; one a person actually steps on, which measured 130 from the finished floor.  A 20 mm odd
;; riser at the foot of a flight is a trip hazard, and it fails the uniformity both IBC 1011.5.4
;; and BS 5395 require (risers within about 3 mm of each other).  The sheet was drawing a stair
;; that could not be built to code and saying so in its own note.
;;
;; EQUALITY IS THE INVARIANT.  150 is the target the count aims at, not a value to be held at
;; the cost of the one riser that matters:
;;     count = round(height / 150)          <- 150 chooses how many
;;     riser = height / count               <- and the height decides the rest
;; 5,380 / 36 = 149.44 mm, identical throughout.  The stair springs from F.F.L, the head lands
;; on the deck, and there is no remainder left over to hide in a grout bed.
;;
;; peb-stair-rise now needs the height.  peb-stair-risers still asks the NOMINAL, because it is
;; choosing the count - asking the actual riser there would be circular.
(defun peb-stair-rise-nom () 150.0)          ; the target the step count is chosen against
(defun peb-stair-rise (hgt / n)
  (setq n (peb-stair-risers hgt))
  (if (> n 0) (/ (float hgt) (float n)) (peb-stair-rise-nom)))

;; ---- MEMBER SIZES, off Maimaar's own issued drawing --------------------------------------
;; 055-MSPL Style Textile, "STAIR CASE FOR FF2 MEZZANINE", sheet 06 ELEVATION AT GRID-B.
;; An issued for-approval drawing outranks the manual and outranks any inference of mine.
(defun peb-stair-stringer-d () 200.0)    ; Stringer C-200x75x6x6 - a channel, 200 deep
(defun peb-stair-rail-h     () 1100.0)   ; handrail height - see the note below
(defun peb-stair-rail-mid   () 550.0)    ; the intermediate tube, mid-height

;; THE HANDRAIL IS 1100, NOT 900.  The manual's 475/425 are rail SPACINGS drawn above a
;; mezzanine deck, and reading them as a stair handrail height was my error - it produced a rail
;; a person could fall over.  The issued drawing dimensions 1100 twice, and the BSF has said so
;; all along: its field reads "1.1m High Handrails Included".  Three sources agreed; the sheet
;; was the only thing that did not.

;; Risers for a climb.  Never fewer than two - one riser is a step, not a staircase.
(defun peb-stair-risers (hgt / n)
  (setq n (fix (+ 0.5 (/ (max 300.0 hgt) (peb-stair-rise-nom)))))
  (max 2 n))

;; ---- HOW MANY LANDINGS  (owner 1-Sep-2026) ----------------------------------------------
;; "no. of landing will be as per the international rules ... after how many steps landing must
;; come ... staircase to be divided equally".
;;
;; TWO limits, and the stair must satisfy BOTH - whichever demands more flights wins:
;;
;;   * RISERS PER FLIGHT.  A flight is limited to 18 risers before a landing is required.
;;     This is the count rule, and it is the one a person means by "after how many steps".
;;   * RISE BETWEEN LANDINGS.  IBC 1011.8 caps a flight at 3658 mm (12 ft) of vertical rise
;;     between floor levels or landings.  A shallow riser can satisfy the count and still break
;;     this one, which is exactly why both are checked.
;;
;; Then the steps are DIVIDED EQUALLY.  31 risers over 2 flights is 16/15, never 18/13 - an
;; equal split is what makes the landing arrive where a climber expects it, and it is what the
;; owner asked for.  The remainder goes to the LOWEST flights, so any odd step is taken early
;; in the climb rather than at the top where a person is already tired.
;;
;; ---- WHY 18 AND NOT 12  (measured off 055-MSPL, 1-Sep-2026) -----------------------------
;; The count cap was 12, which is not in IBC at all - IBC's only flight limit is the 3658 mm
;; rise.  I had taken 12 from the stricter end of the BS 5395 range, and it was wrong twice:
;;
;;   1. MAIMAAR'S OWN ISSUED DRAWING CONTRADICTS IT.  055-MSPL Style Textile, the multi-storey
;;      U-type staircase, numbers every riser on its floor plans.  Counted off the drawing:
;;      flight 1 = risers 1-13, flight 2 = 14-27, flight 3 = 28-41, flight 4 = 42-55,
;;      flight 5 = 56-69.  That is 13, 14, 14, 14, 14 - never 12, and never more than 15.
;;      An issued approval drawing outranks my reading of a code range.
;;   2. IT BROKE THE U.  A U-TYPE STAIRCASE HAS EXACTLY TWO FLIGHTS PER STOREY - that is what
;;      the shape IS: up one band, full landing, back down the other.  At a 12-riser cap a
;;      5,380 mm mezzanine (36 risers) demanded THREE flights, the elevation drew three, and
;;      the U plan drawer - which can only lay out two bands - silently dropped the third.
;;      The plan then showed a 3,600 mm climb against the elevation's 5,380 (owner, 1-Sep-2026:
;;      "there is contradiction b/w the plan and section").  At 18 the same stair is 2 x 18,
;;      the U geometry holds, and the two views agree by construction.
;;
;; ---- THE STANDARD, AND THE SLACK ALLOWED AGAINST IT  (owner 1-Sep-2026) ------------------
;; "Add the Rule of no. of landing based on the no. of steps must be less than approved as per
;; the internal standards", and "There must be Autodivision Rule & should be flexible till 2-4
;; steps", and "our priority is to keep the rise to 150mm".
;;
;; THE APPROVED MAXIMUM IS 15 STEPS IN ONE FLIGHT.  It is 055-MSPL's own highest flight: that
;; drawing numbers every riser, and counted off it the flights are 13 . 14 . 14 . 14 . 14.  I
;; briefly set a flat 18 here, which is the right CEILING but the wrong STANDARD - it quietly
;; licenses every flight to run three steps longer than anything Maimaar has ever issued.
;;
;; THE TOLERANCE IS SPENT ON THE CAP, TO BUY FEWER LANDINGS - never on making flights unequal.
;; A flight may run up to 3 steps past the approved 15 rather than force a whole extra flight
;; and landing for the sake of one or two steps.  Once the flight COUNT is fixed the steps are
;; still divided equally, so the tolerance decides how MANY flights and the equal split decides
;; how LONG each one is.  Two mechanisms, two jobs, neither a magic number.
;;
;; AND THE 150 RISE OUTRANKS BOTH.  The slack is never taken by stretching the riser: the rise
;; stays at peb-stair-rise, the step count follows from the climb, and only the flight count is
;; negotiable.  A 5,380 mm mezzanine is 35.9 risers, so 36 steps at 149.4 - the COUNT rounds,
;; the riser does not.
;;
;; The proof that this is the right rule is that it reproduces the reference exactly, on three
;; different storeys, including its odd single top flight:
;;   5054 rise -> 27 steps -> ceil(27/18)=2 -> 14/13   drawing shows 13 . 14   OK
;;   5203 rise -> 28 steps -> ceil(28/18)=2 -> 14/14   drawing shows 14 . 14   OK
;;   2583 rise -> 14 steps -> ceil(14/18)=1 -> 14      drawing shows 14 alone  OK
(defun peb-stair-max-risers () 15)      ; MAIMAAR APPROVED MAXIMUM steps per flight
(defun peb-stair-step-tol   () 3)       ; the 2-4 step flexibility, spent on the cap
(defun peb-stair-max-rise   () 3658.0)  ; IBC 1011.8, rise between landings

;; The ceiling actually used to decide the flight count.
(defun peb-stair-flight-cap ()
  (+ (peb-stair-max-risers) (peb-stair-step-tol)))

;; -> a list of riser counts, one per flight.  (length) is the flight count; landings = n-1.
;; THE ONE SOURCE.  Every view reads this; no drawer may compute its own split.  The 279-26
;; fault was a drawer that read the rule and then drew something else.
(defun peb-stair-flights (hgt / nris nf base rem out i)
  (setq nris (peb-stair-risers hgt)
        nf   (max (fix (+ 0.999 (/ (float nris) (float (peb-stair-flight-cap)))))
                  (fix (+ 0.999 (/ (max 1.0 hgt) (peb-stair-max-rise)))))
        nf   (max 1 nf)
        base (fix (/ nris nf))
        rem  (- nris (* base nf))
        out  '()
        i    0)
  (while (< i nf)
    (setq out (append out (list (+ base (if (< i rem) 1 0))))
          i   (1+ i)))
  out)


;; ---- EVERY RISER IS EXACTLY 150, AND THE ODD MILLIMETRES GO AT THE BASE ------------------
;; Owner, 1-Sep-2026: "height b/w the top of floor and landing must be same as of 150 - all
;; equal steps", after "our priority is to keep the rise to 150mm".
;;
;; The four drawers used to compute rise = hgt / total-risers, which is EQUAL but not 150: a
;; 5,380 mm mezzanine came out at 149.4 and its landing sat on +2690, not a multiple of the
;; standard.  The sheet's own note admitted it - "36 STEPS AT 149MM".
;;
;; So the riser is the constant and the CLIMB is what gives.  round(h/150)*150 cannot miss the
;; real height by more than half a riser - 75 mm - because the count was rounded:
;;
;;   5380 -> 36 steps -> 5400 drawn, 20 mm over    4877 -> 33 -> 4950, 73 mm over
;;   3000 -> 20 steps -> 3000 drawn, exact         7000 -> 47 -> 7050, 50 mm over
;;
;; THE LEFTOVER IS TAKEN AT THE BASE, NEVER AT THE TOP.  The top tread IS the mezzanine floor;
;; a stair that stops 20 mm short of the floor it serves is wrong in a way nobody can build
;; around, and a 20 mm lip at the head of a flight is a trip hazard.  The bottom is where the
;; adjustment belongs and where it already exists physically - the section draws 200 mm
;; pedestals and the reference carries a `non-shrink grout` layer under every base plate.
;; Setting a base plate 20 mm into its grout bed is ordinary practice.
;;
;; So the stair BASE sits at -leftover and the head lands exactly on the mezzanine.  The rule
;; note declares the offset rather than hiding it.

;; ---- THE STAIR WELL, MEASURED OFF THE REFERENCE  (owner: "landing must match with
;; reference drawings") -------------------------------------------------------------------
;; 055-MSPL dimensions its stair out-to-out at 2600 and splits it 1200 + 200 + 1200: two
;; 1,200 flight bands with a 200 gap between them.  That 200 is not an arbitrary gap - it is
;; the STRINGER DEPTH, because what separates the two flights is the two stringers standing
;; back to back.  The drawing calls the member `Stringer 75 x6x200x6mm`, and 200 is the number
;; peb-stair-stringer-d already returns.
;;
;; So the well is derived from the member, not guessed: a 12% -of-width rule gave 144 on a
;; 1,200 stair, which made our out-to-out 2,544 where the reference's is 2,600.  Deriving it
;; puts the two drawings on the same number without hard-coding anything.
(defun peb-stair-well (wdt)
  (peb-stair-stringer-d))

;; The landing along the climb.  A turn needs a full stair width to stand and turn in, so the
;; landing is never shorter than the stair is wide; 055-MSPL dimensions 1220 for its 1,200
;; flight, which is that rule with a construction tolerance on it.
(defun peb-stair-landing-w (wdt)
  (max 900.0 wdt))

;; the climb the stair actually draws: whole steps of exactly 150
(defun peb-stair-drawn-climb (hgt)
  (* (peb-stair-rise hgt) (float (apply '+ (peb-stair-flights hgt)))))

;; ZERO, ALWAYS - and kept as a function because every drawer asks it.
;; With an equal riser derived from the height there is no remainder: count x (height/count) IS
;; the height, so the stair springs from F.F.L and the head lands on the deck.  The grout-bed
;; offset this used to return existed only to absorb the error of holding 150 exactly, and that
;; error is what made the bottom riser 130.  See peb-stair-rise.
(defun peb-stair-base-offset (hgt) 0.0)

;; ---- ANNOTATION BELONGS ON THE SHEET THAT CAN READ IT  (2-Sep-2026) ----------------------
;; The mezzanine floor plan draws the staircase with these SAME drawers - one source, so the two
;; sheets cannot disagree about what the stair looks like.  But it draws it INSIDE a 55 m
;; building on an A4 sheet, and every dimension, leader and note below is sized off the STAIR
;; (u = width/12 = 100 mm on a 1,200 stair), not off the sheet's text ladder.  At the floor
;; plan's scale that annotation plots at roughly a sixth of 'SMALL - the ladder's own floor -
;; so "6600 STAIRCASE LENGTH" came out as an unreadable black smudge lying across the deck.
;; Rule 4B.26 again: text sized off the thing instead of off the sheet.
;;
;; The answer is not to grow the text - it would then cover the bays either side of the stair -
;; it is that the numbers belong on the STAIRCASE SHEET, which is drawn at stair scale and
;; exists to carry them.  The floor plan needs the stairwell, the treads, the landing and the
;; climb arrow; the mezzanine plan labels the hole itself with OPENING - ST<n>.
;;
;; So a caller that is placing a stair inside another drawing sets *PEB-STAIR-PLAIN*, and the
;; text-only helpers below stand down.  Geometry is never suppressed - only annotation.
(defun peb-stair-plain-p ()
  (and (boundp '*PEB-STAIR-PLAIN*) *PEB-STAIR-PLAIN*))

;; A leader with its note: a line from the part out to clear air, text beyond it.
(defun peb-stair-note (px py ty th s / up)
  (if (peb-stair-plain-p) (princ) (progn
  (setq up (> ty py))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 px py 0.0) (list 11 px ty 0.0)))
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold (if up "BC" "TC")
            (list px (if up (+ ty (* th 0.35)) (- ty (* th 0.35))))
            (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 s))))


;; An ELBOW leader: out from the part, then sideways to a text column, text beside it.
;;
;; WHY NOT A STRAIGHT LEADER.  peb-stair-note centres its text on the leader, so two notes whose
;; parts are close together collide however far apart their ROWS are - the strings are longer
;; than the gap between the things they point at.  That is what printed "STRINGERSTRINGER" and
;; buried MID-LANDING PLATFORM under PLAN.  Staggering rows only hides it until a longer string
;; appears; routing the text sideways to a clear column fixes it for good, and it is what the
;; manual sheets do.
;;
;; `side` is -1 to run left (text right-aligned, ending at tx) or +1 to run right (left-aligned).
(defun peb-stair-note-elbow (px py ty tx side th s)
  (if (peb-stair-plain-p) (princ) (progn
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 px py 0.0) (list 11 px ty 0.0)))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 px ty 0.0) (list 11 tx ty 0.0)))
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold (if (< side 0) "MR" "ML")
            (list (+ tx (* side th 0.4)) ty)
            (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 s))))

;; An overall dimension: extension lines, OPEN arrowheads (never a solid), label above.
;; ---- A DIMENSION IS NOT A HEADING  (owner 3-Sep-2026) ------------------------------------
;; "Do the audit of labelling of staircase and fix, and also apply the default text - I think
;;  ROMAND was selected."  ROMAND is right and is the universal rule (Standard.lsp: ALL drawing
;; text is romand.shx).  What this sheet got wrong was WHICH ROMAND STYLE, and on WHAT LAYER.
;;
;; Every label here - dimensions included - went through txt-bold, which sets TEXTSTYLE to
;; PEB-TITLE and CELWEIGHT to 30.  So the staircase sheet drew its DIMENSIONS in the title style
;; at heading weight, where every other sheet in the set uses txt-dim / PEB-DIM at normal
;; weight.  Same font, wrong voice: on this one sheet a dimension shouted like a caption.
;;
;; And it drew them on STAIR-TEXT, a layer made ad hoc at ACI 7 that is in neither *PEB-LAYERS*
;; nor PEB_LAYERS.csv, so it inherits no lineweight from the standard.  Dimension geometry
;; belongs on DIMENSIONS, which does.  Notes and captions stay where they are - they ARE text.
(defun peb-stair-dim (x0 x1 y th s / t2)
  (if (peb-stair-plain-p) (princ) (progn
  (peb-comp-layer "DIMENSIONS" 6)
  (setq t2 (* th 0.9))
  (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS") (list 10 x0 y 0.0) (list 11 x1 y 0.0)))
  (foreach xx (list x0 x1)
    (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS")
                   (list 10 xx (- y (* t2 1.2)) 0.0) (list 11 xx (+ y (* t2 1.2)) 0.0))))
  (foreach p (list (list x0 1.0) (list x1 -1.0))
    (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS")
                   (list 10 (car p) y 0.0)
                   (list 11 (+ (car p) (* (cadr p) t2 1.4)) (+ y (* t2 0.45)) 0.0)))
    (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS")
                   (list 10 (car p) y 0.0)
                   (list 11 (+ (car p) (* (cadr p) t2 1.4)) (- y (* t2 0.45)) 0.0))))
  (setvar "CLAYER" "DIMENSIONS")
  (txt-dim "BC" (list (/ (+ x0 x1) 2.0) (+ y (* t2 0.5)))
            (/ t2 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0
            (peb-stair-dimtext (abs (- x1 x0)) s)))))

;; ---- A DIMENSION MUST CARRY ITS MEASUREMENT  (owner 1-Sep-2026: "show the clear dimensions")
;; The main views were printing a dimension line with a DESCRIPTION and no number - "STAIRCASE
;; LENGTH", "MID-LANDING HEIGHT", "OUT TO OUT WIDTH".  That is a caption sitting on a dimension
;; line, not a dimension: nobody can build or check from it, and the sheet looked dimensioned
;; while telling the reader nothing.
;;
;; The measurement is computed HERE, from the two endpoints the helper is already given, rather
;; than passed in by each caller.  Two reasons, and the second is the important one: a caller
;; cannot forget, and the number cannot disagree with the line it is written on.
;;
;; The format is the reference's own - value first, description after ("6318 C/C OF STEEL
;; LINE").  A caller that passes a string already starting with a digit has done its own
;; measuring and is left alone; a caller that passes nothing gets the bare number.
(defun peb-stair-dimtext (v s)
  ;; MILLIMETRES, and feet only on an OVERALL extent (rules 4B.11 / 4B.14).  General Note 1 on
  ;; every sheet already says ALL DIMENSIONS ARE IN MM, and 4B.14's own worked example shows a
  ;; derived value as a bare number - "no ft needed".  Putting [ft'-in"] on EVERY dimension here
  ;; was tried and it doubled the length of every label on a sheet whose views are 6 m wide:
  ;; "5400 [17'-9"] FLIGHT RUN" ran straight into "1200 [3'-11"] LANDING", and the step detail's
  ;; five labels collapsed into each other.  The two OVERALL dims - staircase length and
  ;; staircase height - carry the feet, and they ask peb-dim-mmft themselves.
  (cond ((or (null s) (= s "")) (rtos v 2 0))
        ((wcmatch s "#*")       s)                     ; already carries its own value
        (T (strcat (rtos v 2 0) " " s))))

;; An OVERALL extent: millimetres and feet-inches together, per 4B.11.  Passed as the label so
;; peb-stair-dimtext's "#*" branch leaves it alone.
(defun peb-stair-dim-overall (v s)
  (strcat (if (boundp 'peb-dim-mmft) (peb-dim-mmft v) (rtos v 2 0)) " " s))

;; Draw dimension with breakdown below (for compound dimensions like width = flight + column + flight)
(defun peb-stair-dim-breakdown (x0 x1 y th s breakdown / t2)
  "Draw a dimension with a breakdown line below it.
  breakdown: string like \"(1200 + 200 + 1200)\" to show under the main dimension"
  (peb-stair-dim x0 x1 y th s)
  (if breakdown
    (progn
      (setq t2 (* th 0.9))
      (setvar "CLAYER" "STAIR-TEXT")
      (txt-bold "BC" (list (/ (+ x0 x1) 2.0) (- y (* t2 2.5)))
                (/ (* th 0.75) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0
                breakdown))))

;; ---- WHICH SHAPE ------------------------------------------------------------------------
;; ST<n>_TYPE is one of Single / Double / U-Shape / L-Shape, and the four are genuinely
;; DIFFERENT PLANS, not one plan with a different caption.  The first cut of this sheet drew a
;; straight double flight and lettered it "U-SHAPE", which is a drawing that contradicts its own
;; title - the owner spotted it immediately.  The shape is the drawing.
;;
;;   Single   one flight, straight.                              [___________>
;;   Double   two flights in line, landing between.              [_____][____>
;;   U-Shape  two flights side by side, 180 deg at the landing.  [_____]
;;                                                               <_____]
;;   L-Shape  two flights at 90 deg, quarter-turn landing.       [_____]
;;                                                                     |
(defun peb-stair-shape (typ midl / u)
  (setq u (strcase (if typ typ "")))
  (cond ((wcmatch u "*U-SHAPE*,*U SHAPE*,*USHAPE*") "U")
        ((wcmatch u "*L-SHAPE*,*L SHAPE*,*LSHAPE*") "L")
        ;; "Double" means two flights; so does any stair the BSF gave a mid landing.
        ((or (wcmatch u "*DOUBLE*") midl) "D")
        (T "S")))

;; ---- the PLAN view of one staircase -----------------------------------------------------
;; Origin (ox,oy) is the FOOT of the flight, on the centreline of the stair width.  The stair
;; climbs in +x so the drawing reads left to right, as the manual sheet does.
;; trd  = ST<n>_TREAD       ("Checkered" / "Grating" / "Pan")   - what the treads ARE
;; pfl  = ST<n>_PLAT_FLOOR  ("Checkered Plate" ...)             - what the landings ARE
;; Both come from the BSF and are lettered on the sheet: the manual lists four interchangeable
;; tread types, so a drawing that does not say which one is drawing a stair nobody can buy.
(defun peb-stair-plan (ox oy wdt hgt topl midl lbl trd pfl /
                       u th going fl nf lw tlw y0 y1 x xa xcur i k n ytxt r xs xe)
  (setq u     (max 60.0 (/ wdt 12.0))
        th    (peb-stair-th u)
        going (peb-stair-going)
        fl    (peb-stair-flights hgt)          ; risers per flight, already divided equally
        nf    (length fl)
        lw    (max 900.0 wdt)                  ; landing width, along the climb
        tlw   (if topl lw 0.0)
        y0    (- oy (/ wdt 2.0))
        y1    (+ oy (/ wdt 2.0))
        xa    ox
        xcur  ox)

  ;; --- FLIGHTS and the LANDINGS between them.  nf-1 landings, by the international rule.
  (setq i 0)
  (while (< i nf)
    (setq xs xcur
          xe (+ xs (* going (nth i fl))))
    ;; treads of this flight
    (peb-comp-layer "STAIR-TREAD" 7)
    (setq k 1 n (nth i fl))
    (while (< k n)
      (setq x (+ xs (* k going)))
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TREAD")
                     (list 10 x y0 0.0) (list 11 x y1 0.0)))
      (setq k (1+ k)))
    (setq xcur xe)
    ;; an intermediate landing after every flight but the last
    (if (< i (1- nf))
      (progn
        (peb-comp-layer "STAIR-LANDING" 3)
        (peb-comp-poly (list (list xcur y0) (list (+ xcur lw) y0)
                             (list (+ xcur lw) y1) (list xcur y1)))
        (foreach xx (list xcur (+ xcur lw))
          (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                         (list 10 xx y0 0.0) (list 11 xx y1 0.0))))
        ;; TWO columns, under the ends of the landing beam, one on each stringer line.
        (foreach cy (list (+ y0 (/ (peb-stair-col-bf) 2.0)) (- y1 (/ (peb-stair-col-bf) 2.0)))
          (peb-stair-col-plan (- (+ xcur lw) (/ (peb-stair-col-d) 2.0)) cy))
        (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                       (list 10 xcur y0 0.0) (list 11 (+ xcur lw) y1 0.0)))
        (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                       (list 10 xcur y1 0.0) (list 11 (+ xcur lw) y0 0.0)))
        (setq xcur (+ xcur lw))))
    (setq i (1+ i)))

  ;; --- TOP LANDING at the head.
  (if topl
    (progn
      (peb-comp-layer "STAIR-LANDING" 3)
      (peb-comp-poly (list (list xcur y0) (list (+ xcur tlw) y0)
                           (list (+ xcur tlw) y1) (list xcur y1)))
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                     (list 10 xcur y0 0.0) (list 11 xcur y1 0.0)))
      (setq xcur (+ xcur tlw))))
  (setq xe xcur)

  ;; --- STRINGERS along the whole assembly, both edges.
  (peb-comp-layer "STAIR-STRINGER" 1)
  (foreach yy (list y0 y1)
    (entmake (list (cons 0 "SOLID") (cons 8 "STAIR-STRINGER")
                   (list 10 xa (- yy (* u 0.35)) 0.0) (list 11 xe (- yy (* u 0.35)) 0.0)
                   (list 12 xa (+ yy (* u 0.35)) 0.0) (list 13 xe (+ yy (* u 0.35)) 0.0))))

  ;; --- UP: line up the centre, solid head at the top, open circle at the foot.
  (peb-comp-layer "STAIR-TEXT" 7)
  (peb-stair-arrow (+ xa (* u 1.2)) oy (- xe tlw (* u 0.6)) oy u T)
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "MR" (list (- xa (* u 0.4)) oy)
            (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "UP")

  ;; --- LABELLING: climb direction and caption only.  See the note in peb-stair-plan-u.
  (setq ytxt (+ y1 (* u 2.4)))

  (peb-stair-dim xa xe (+ ytxt (* u (if (> nf 1) 9.6 4.0))) th
                 (peb-stair-dim-overall (abs (- xe xa)) "STAIRCASE LENGTH"))
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "MC" (list (/ (+ xa xe) 2.0) (- y0 (* u 9.2)))
            (/ (* th 1.25) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "PLAN")
  (if lbl
    (txt-bold "MC" (list (/ (+ xa xe) 2.0) (- y0 (* u 11.8)))
              (/ (* th 1.05) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 lbl))
  (list xa xe y0 y1))

;; ---- U-SHAPE PLAN -----------------------------------------------------------------------
;; Flight 1 climbs +x in the LOWER band; the FULL landing spans the whole width at the far end;
;; flight 2 climbs BACK in -x in the UPPER band, separated by a stair well.  The whole thing is
;; therefore about half as long as the same climb laid out straight - which is the reason a U is
;; specified in the first place, and the reason drawing it straight was not a cosmetic slip.
;;
;; ---- A U HOLDS TWO FLIGHTS.  MORE THAN TWO MEANS MORE THAN ONE PLAN. ---------------------
;; (owner, 1-Sep-2026: "there is contradiction b/w the plan and section", and: 055-MSPL "is
;; special for multi-storey U-Type Staircase, Section, Plan, Column Layout Plan").
;;
;; The old drawer took `(nth 0 fl)` and `(nth 1 fl)` and drew those two, whatever the length of
;; `fl`.  On MSPL-26-279 the split came back THREE long, so the elevation climbed 5,380 mm and
;; the plan climbed 3,600 - the third flight was not drawn, not flagged, just gone.  Reading the
;; same list as the elevation is not enough on its own; the plan has to DRAW ALL OF IT.
;;
;; 055-MSPL Style Textile shows how Maimaar's own draftsmen handle a climb that will not fit in
;; one U: its sheet index carries "MAIN BEAM - CHECKERED PLATE - TUBE - STRINGER - LAYOUT PLAN"
;; THREE TIMES, one per floor, each plan holding that floor's two flights, with the riser
;; numbering running continuously across them (1-13, 14-27 | 28-41, 42-55 | 56-69).
;;
;; So: flights are taken in PAIRS, and each pair is one plan block, stacked down the sheet and
;; captioned by the level it belongs to.  Two flights (the normal mezzanine stair) produce
;; exactly one block and one caption - identical to what this drawer produced before, which is
;; what keeps the ordinary case unchanged.  An odd last flight draws its lower band alone.
(defun peb-stair-plan-u (ox oy wdt hgt topl midl lbl trd pfl /
                         u fl nf well dep pitch nblk b f1 f2 ex ext y lastb rise lo hi)
  ;; ONE SPLIT, BOTH VIEWS (owner: "Each Type Plan must match with SECTION").
  (setq u     (max 60.0 (/ wdt 12.0))
        fl    (peb-stair-flights hgt)
        nf    (length fl)
        rise  (peb-stair-rise hgt)               ; EQUAL - height/count, see peb-stair-rise
        well  (peb-stair-well wdt)
        dep   (+ wdt wdt well)
        nblk  (fix (/ (+ nf 1) 2))              ; pairs of flights = plan blocks = storeys
        ;; block to block.  A block is not just `dep` tall: it carries a dimension chain up to
        ;; 13u above it and a stringer leader plus its level caption 9u below, so a pitch of
        ;; dep+15u put the lower block's dimensions through the upper block's caption.
        pitch (peb-stair-plan-u-pitch wdt)      ; ONE definition - see peb-stair-plan-u-pitch
        ;; SAME DATUM AS THE ELEVATION.  The captions name levels, and the elevation marks
        ;; those same levels beside the stair - so they must be measured from the same place.
        ;; Starting at 0.0 measured them from the stair BASE while the elevation measures from
        ;; F.F.L, and on any storey that is not a whole number of risers the two views would
        ;; have printed different numbers for the same landing.  That is the 279-26 fault in
        ;; another costume: two views, one fact, no shared source.
        lo    (peb-stair-base-offset hgt)
        b     0)
  (while (< b nblk)
    (setq f1    (nth (* 2 b) fl)
          f2    (if (< (+ (* 2 b) 1) nf) (nth (+ (* 2 b) 1) fl) nil)
          lastb (= b (1- nblk))
          ;; the level this block climbs TO - flight 1 plus flight 2 if there is one
          hi    (+ lo (* rise (+ f1 (if f2 f2 0))))
          y     (- oy (* b pitch))
          ex    (peb-stair-plan-u1 ox y wdt f1 f2 well dep
                                   ;; only the LAST block reaches the top landing; the ones
                                   ;; below it land on a floor, not on the mezzanine deck.
                                   (and topl lastb)
                                   ;; captions: one plan needs no level, several name theirs.
                                   (if (= nblk 1) nil (peb-stair-level-caption lo hi))
                                   ;; every block above the first steps off an outward landing
                                   (> b 0)
                                   ;; ...and the tower reaches out there on every plan of it
                                   (> nblk 1)))
    (setq lo hi)
    (setq ext (if ext (list (min (nth 0 ext) (nth 0 ex)) (max (nth 1 ext) (nth 1 ex))
                            (min (nth 2 ext) (nth 2 ex)) (max (nth 3 ext) (nth 3 ex)))
                ex))
    (setq b (1+ b)))
  ;; The caption sits under the LAST block, so it reads as the title of the set.
  (peb-stair-plan-u-caption (nth 0 ext) (nth 1 ext) (- oy (* (1- nblk) pitch) (/ dep 2.0))
                            u (* u 1.6) lbl)
  ext)

;; ONE U BLOCK: two flights round a FULL landing.  `f2` nil draws a single flight (the odd one
;; at the top of an over-tall climb).  `sub` is the block's own caption, or nil for a lone plan.
(defun peb-stair-plan-u1 (ox oy wdt f1 f2 well dep topl sub startland towerout /
                          u th going run1 run2 lw yb0 yb1 yt0 yt1 xa xb xL xc i n x xout)
  (setq u     (max 60.0 (/ wdt 12.0))
        th    (peb-stair-th u)
        going (peb-stair-going)
        lw    (peb-stair-landing-w wdt)         ; full-landing width, along the climb
        run1  (* going f1)
        run2  (* going (if f2 f2 0))
        yb0   (- oy (/ dep 2.0))                ; lower band (flight 1, going up)
        yb1   (+ yb0 wdt)
        yt1   (+ oy (/ dep 2.0))                ; upper band (flight 2, coming back)
        yt0   (- yt1 wdt)
        xa    ox
        xb    (+ xa run1)                       ; head of flight 1 = edge of the full landing
        xL    (+ xb lw)                         ; far edge of the full landing
        ;; flight 2 turns at the INNER edge of the landing - xb, the head of flight 1 -
              ;; not at its outer face.  Off xL it started a whole landing further along and
              ;; the two flights no longer sat over one another.
        xc    (- xb run2)                       ; far end of flight 2, back toward the start
        ;; the outward face at the near end.  Set HERE, with the rest of the geometry, because
        ;; the column loop reads it long before the landing that occupies it is drawn - it was
        ;; assigned further down and every block died on (+ nil 100.0), which the driver's
        ;; per-stair catch swallowed into a 43-entity sheet.
        xout  (- xa lw))

  ;; --- STRINGERS: both edges of every flight drawn, and the outer edges of the landing.
  ;; With no second flight the upper band does not exist, so its two stringers and its end are
  ;; not drawn - an empty band closed by stringers reads as a flight that is missing its treads.
  (peb-comp-layer "STAIR-STRINGER" 1)
  (foreach s (if f2
               (list (list xa xL yb0) (list xa xb yb1) (list xc xb yt0) (list xc xL yt1))
               (list (list xa xL yb0) (list xa xL yb1)))
    (entmake (list (cons 0 "SOLID") (cons 8 "STAIR-STRINGER")
                   (list 10 (car s) (- (caddr s) (* u 0.35)) 0.0)
                   (list 11 (cadr s) (- (caddr s) (* u 0.35)) 0.0)
                   (list 12 (car s) (+ (caddr s) (* u 0.35)) 0.0)
                   (list 13 (cadr s) (+ (caddr s) (* u 0.35)) 0.0))))
  ;; the ends
  (foreach e (if f2
               (list (list xa yb0 yb1) (list xL yb0 yt1) (list xc yt0 yt1))
               (list (list xa yb0 yb1) (list xL yb0 yb1)))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-STRINGER")
                   (list 10 (car e) (cadr e) 0.0) (list 11 (car e) (caddr e) 0.0))))

  ;; --- TREADS, per flight, never across the landing.
  (peb-comp-layer "STAIR-TREAD" 7)
  (setq i 1 n f1)
  (while (< i n)
    (setq x (+ xa (* i going)))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TREAD")
                   (list 10 x yb0 0.0) (list 11 x yb1 0.0)))
    (setq i (1+ i)))
  (if f2
    (progn
      (setq i 1 n f2)
      (while (< i n)
        (setq x (- xb (* i going)))
        (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TREAD")
                       (list 10 x yt0 0.0) (list 11 x yt1 0.0)))
        (setq i (1+ i)))))

  ;; --- THE FULL LANDING at the turn (owner, 1-Sep-2026: "First Landing will be full width of
  ;; the stair").  It spans the WHOLE stairwell - both flight bands and the well between them -
  ;; which is why it is a FULL landing and not a half one: a person climbs flight 1, turns on
  ;; it, and sets off up flight 2.  A lone flight has no turn, so its landing is one band deep.
  (peb-comp-layer "STAIR-LANDING" 3)
  (peb-comp-poly (if f2
                   (list (list xb yb0) (list xL yb0) (list xL yt1) (list xb yt1))
                   (list (list xb yb0) (list xL yb0) (list xL yb1) (list xb yb1))))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 xb yb0 0.0) (list 11 xb (if f2 yt1 yb1) 0.0)))
  ;; --- FOUR COLUMNS, AT THE FOUR CORNERS OF THE STAIR TOWER (owner: "there will be 4
  ;;     columns").  Not two, which is what this drew before, and not four PER LANDING.
  ;;
  ;;     Why four and why fixed: flight 1 starts on the floor and the last flight lands on the
  ;;     mezzanine, so both ends of the staircase are already carried - the intermediate
  ;;     landings are the only parts with nothing under them.  The landings alternate ends as
  ;;     the stair switches back, so a far-end landing spans the far pair of columns and a
  ;;     near-end landing spans the near pair.  Add landings and you add no columns; you re-use
  ;;     the same four lines further up.  055-MSPL settles it: five flights, four intermediate
  ;;     landings, three storeys - and its schedule still reads CBP-01 (QTY-04).
  ;; THE COLUMNS BELONG TO THE TOWER, NOT TO THE BLOCK.  `towerout` says the tower reaches
  ;; a landing outward at the near end somewhere up the climb - so EVERY floor plan puts its
  ;; near columns there, including the ground block that has no landing of its own at that end.
  ;; Otherwise the same four columns appear at two different x on two plans of one staircase.
  (foreach cx (list (+ (if towerout xout xa) (/ (peb-stair-col-d) 2.0))
                    (- xL (/ (peb-stair-col-d) 2.0)))
    (foreach cy (list (+ yb0 (/ (peb-stair-col-bf) 2.0))
                      (- (if f2 yt1 yb1) (/ (peb-stair-col-bf) 2.0)))
      (peb-stair-col-plan cx cy)))
  ;; --- the WELL between the flights: open, so it must read as a void, not as floor.
  (if f2
    (progn
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING") (list 10 xa yb1 0.0) (list 11 xb yb1 0.0)))
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING") (list 10 xc yt0 0.0) (list 11 xb yt0 0.0)))
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING") (list 10 xb yb1 0.0) (list 11 xb yt0 0.0)))))

  ;; --- NO TOP LANDING PLATFORM.  Owner, 1-Sep-2026: "2nd landing will be Mezzanine Floor",
  ;; "next landing will directly to to mezzanine Floor".  The last flight arrives ON the
  ;; mezzanine deck; drawing a platform in front of it invents a step that is not there.
  ;; ST<n>_TOP_LANDING no longer drives any geometry - it is read for the sheet title only.

  ;; --- UP: one arrow per flight, following the climb round the turn; the word at the foot.
  (peb-comp-layer "STAIR-TEXT" 7)
  (peb-stair-arrow (+ xa (* u 1.2)) (/ (+ yb0 yb1) 2.0) (- xb (* u 0.6)) (/ (+ yb0 yb1) 2.0) u T)
  (if f2
    (peb-stair-arrow (- xL (* u 1.2)) (/ (+ yt0 yt1) 2.0) (+ xc (* u 0.6)) (/ (+ yt0 yt1) 2.0) u nil))
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "MR" (list (- xa (* u 0.4)) (/ (+ yb0 yb1) 2.0))
            (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "UP")

  ;; --- LABELLING: almost none, and that is deliberate.
  ;;
  ;; The approval drawings this geometry came from letter every part, because they instruct a
  ;; fabricator.  A proposal drawing has a different reader and a different job: it shows the
  ;; customer WHAT THEY ARE BUYING.  Copying approval-density annotation onto it produces a
  ;; crowded sheet that says less, not more (owner, 1-Sep-2026: "not much in detailed labelling.
  ;; but Excellent outlook and presentation").
  ;;
  ;; So the plan carries the climb direction and, when there is more than one of them, which
  ;; level it is.  The parts are named once, on the section, where naming them explains
  ;; something.  `sub` is that level caption, and nil for a stair that needs only one plan.
  ;; --- THE LANDING THIS BLOCK STARTS FROM, PROJECTING OUTWARD  (owner, 1-Sep-2026:
  ;; "Landing of 2nd intermediate should be outward").
  ;;
  ;; Block 1 starts on the floor and has no such landing.  Every block above it starts by
  ;; stepping off the landing that the flight below arrived on - and that landing sits at the
  ;; NEAR end, projecting OUTWARD past the foot of flight 1.  It was not drawn on any plan at
  ;; all: block 1 drew flights 1-2 and their far landing, block 2 drew flights 3-4 and theirs,
  ;; and the landing between them - the one you actually turn on to get from one to the other -
  ;; fell down the gap between two blocks.
  ;;
  ;; Outward is the only place it can go.  Hung back over the foot of flight 1 it would leave
  ;; no headroom on the bottom steps.
  (if startland
    (progn
      (peb-comp-layer "STAIR-LANDING" 3)
      (peb-comp-poly (list (list xout yb0) (list xa yb0)
                           (list xa (if f2 yt1 yb1)) (list xout (if f2 yt1 yb1))))
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                     (list 10 xa yb0 0.0) (list 11 xa (if f2 yt1 yb1) 0.0)))))

  ;; --- THE STRINGER, NAMED ON EVERY FLOOR PLAN (owner 1-Sep-2026: "show the different plan
  ;; of each floor stringer").  055-MSPL letters `Stringer 75 x6x200x6mm` along a flight edge on
  ;; each of its three floor plans, not once for the set - because each plan is read on its own
  ;; and a plan that does not name its long edges is a pair of parallel lines.
  ;;
  ;; This is a deliberate exception to "part names live on the section": the owner asked for it
  ;; and the reference does it. The name only, not the size - PD is blind by default.
  (peb-comp-layer "STAIR-TEXT" 7)
  (peb-stair-note (+ xa (* run1 0.30)) yb0 (- yb0 (* u 2.6)) th "STRINGER")

  ;; THE PLAN OWNS THE FOOTPRINT, so it dimensions all of it - not just the overall length.
  ;; A single "STAIRCASE LENGTH" over the whole thing cannot be built from: it does not say how
  ;; much of that is flight and how much is landing, which is the first thing anyone setting it
  ;; out needs.  A chain of run + landing, with the overall above it, does.
  (peb-stair-dim xa xb (+ (if f2 yt1 yb1) (* u 6.0)) th "FLIGHT RUN")
  (peb-stair-dim xb xL (+ (if f2 yt1 yb1) (* u 6.0)) th "LANDING")
  (if startland (peb-stair-dim xout xa (+ (if f2 yt1 yb1) (* u 6.0)) th "LANDING"))
  (peb-stair-dim (if towerout xout xa) xL (+ (if f2 yt1 yb1) (* u 12.0)) th
                 (peb-stair-dim-overall (abs (- xL (if towerout xout xa))) "STAIRCASE LENGTH"))
  ;; and the depth across the stair, which is the other half of the footprint
  (peb-stair-vdim (- (if towerout xout xa) (* u 3.4)) yb0 (if f2 yt1 yb1) th
                  "O/O OF STEEL COLUMN")
  (if sub
    (progn
      (setvar "CLAYER" "STAIR-TEXT")
      (txt-bold "MC" (list (/ (+ xa xL) 2.0) (- yb0 (* u 8.0)))
                (/ (* th 1.05) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 sub)))
  (list (if towerout xout xa) (if (and topl (not f2)) (+ xL lw) xL)
        yb0 (if f2 yt1 yb1)))

;; ---- THE LEVEL CAPTION, IN THE REFERENCE'S OWN WORDS -------------------------------------
;; 055-MSPL captions its three floor plans "PLAN FROM F.F.L TO 5054mm LEVEL", "PLAN FROM 5054 TO
;; 10257mm LEVEL", "PLAN FROM 10257 TO 12840mm LEVEL".  I had captioned them "PLAN AT LEVEL 1".
;; The ordinal tells a reader nothing they cannot already count; the LEVELS tell them which part
;; of the climb they are looking at and tie the plan to the elevation's own level markers, which
;; are drawn in exactly those numbers.  Take the wording from the drawing.
;;
;; `lo` and `hi` are heights above F.F.L in mm.  Zero prints as F.F.L, as it does on the sheet.
(defun peb-stair-level-caption (lo hi)
  (strcat "PLAN FROM " (if (< (abs lo) 100.0) "F.F.L" (rtos lo 2 0))
          " TO " (rtos hi 2 0) "mm LEVEL"))

;; The caption under the whole set of plan blocks: "PLAN", and the stair's own title.
;; It is drawn ONCE, under the last block, so a multi-storey U reads as one plan set rather
;; than as three unrelated drawings that happen to be stacked.
;; The set caption sits BELOW the last block's own level caption, which is at ybot-8u.  At
;; ybot-9.2u the two printed on the same line - 1.2u apart is 120 mm, and the text is 190 mm
;; tall.  It hangs past the block pitch on purpose: only the LAST block carries it, and
;; peb-stair-elev-drop already clears the space beneath.
(defun peb-stair-plan-u-caption (xa xL ybot u th lbl)
  (if (peb-stair-plain-p) (princ) (progn
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "MC" (list (/ (+ xa xL) 2.0) (- ybot (* u 13.0)))
            (/ (* th 1.25) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "PLAN")
  (if lbl
    (txt-bold "MC" (list (/ (+ xa xL) 2.0) (- ybot (* u 15.6)))
              (/ (* th 1.05) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 lbl))))
  (princ))

;; One climb arrow: a line with a solid head at the far end.  `circ` puts the open circle at the
;; start, which the manual shows only at the very foot of the staircase.
(defun peb-stair-arrow (x0 y0 x1 y1 u circ / dx s)
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 x0 y0 0.0) (list 11 x1 y1 0.0)))
  (setq s (if (> x1 x0) 1.0 -1.0) dx (* s u 1.6))
  (entmake (list (cons 0 "SOLID") (cons 8 "STAIR-TEXT")
                 (list 10 (- x1 dx) (- y1 (* u 0.55)) 0.0)
                 (list 11 (- x1 dx) (+ y1 (* u 0.55)) 0.0)
                 (list 12 x1 y1 0.0) (list 13 x1 y1 0.0)))
  (if circ
    (entmake (list (cons 0 "CIRCLE") (cons 8 "STAIR-TEXT")
                   (list 10 x0 y0 0.0) (cons 40 (* u 0.45))))))

;; ---- L-SHAPE PLAN -----------------------------------------------------------------------
;; Flight 1 climbs +x; a SQUARE quarter-turn landing sits at its head; flight 2 climbs +y out
;; of that landing, at 90 degrees.  The landing is square because both flights are the same
;; width and the turn has to accept a full tread depth on either leg - a rectangular landing
;; would pinch the inside of the turn, which is where people actually walk.
;;
;; The treads of flight 2 run ACROSS its climb, i.e. horizontally, so they are drawn as x-lines
;; while flight 1 draws y-lines.  Getting that the wrong way round is the tell-tale of an L that
;; was copied from a straight flight.
;; THE L HAD THE SAME FAULT THE U DID, one step worse: it never read peb-stair-flights at all.
;; It halved the risers itself - `(fix (/ nris 2.0))` and the remainder - so on an ODD riser
;; count the plan gave flight 1 the SHORTER half while the elevation's equal split gave it the
;; longer one, and the two views disagreed by one step; and like the U it could only ever draw
;; two flights.  Both views now read the one list, and flights beyond the second get their own
;; plan block, the way 055-MSPL draws a storey per plan.
(defun peb-stair-plan-l (ox oy wdt hgt topl midl lbl trd pfl /
                         u fl nf nblk b f1 f2 lw pitch ex ext y lastb rise lo hi)
  (setq u     (max 60.0 (/ wdt 12.0))
        fl    (peb-stair-flights hgt)
        nf    (length fl)
        rise  (peb-stair-rise hgt)               ; EQUAL - height/count
        lw    (max 900.0 wdt)
        nblk  (fix (/ (+ nf 1) 2))
        lo    (peb-stair-base-offset hgt)   ; same datum as the elevation - see the U wrapper
        b     0)
  (while (< b nblk)
    (setq f1    (nth (* 2 b) fl)
          f2    (if (< (+ (* 2 b) 1) nf) (nth (+ (* 2 b) 1) fl) nil)
          lastb (= b (1- nblk))
          hi    (+ lo (* rise (+ f1 (if f2 f2 0))))
          ;; each block is as tall as its own second flight, so the pitch is measured per block
          pitch (+ wdt (* (peb-stair-going) (if f2 f2 0)) lw (* u 12.0))
          y     (if ext (- (nth 2 ext) pitch) oy)
          ex    (peb-stair-plan-l1 ox y wdt f1 f2 (and topl lastb) trd pfl
                                   (if (= nblk 1) nil (peb-stair-level-caption lo hi))))
    (setq lo hi)
    (setq ext (if ext (list (min (nth 0 ext) (nth 0 ex)) (max (nth 1 ext) (nth 1 ex))
                            (min (nth 2 ext) (nth 2 ex)) (max (nth 3 ext) (nth 3 ex)))
                ex))
    (setq b (1+ b)))
  ;; the set is captioned once, under the lowest block
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "MC" (list (/ (+ (nth 0 ext) (nth 1 ext)) 2.0) (- (nth 2 ext) (* u 3.6)))
            (/ (* u 2.0) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "PLAN")
  (if lbl
    (txt-bold "MC" (list (/ (+ (nth 0 ext) (nth 1 ext)) 2.0) (- (nth 2 ext) (* u 6.2)))
              (/ (* u 1.68) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 lbl))
  ext)

;; ONE L BLOCK: flight 1 along x, a square quarter-turn landing, flight 2 along y.
(defun peb-stair-plan-l1 (ox oy wdt f1 f2 topl trd pfl sub /
                          u th going run1 run2 lw
                          x0 x1 xb yb0 yb1 yt i n x y ytxt r xlo xhi ylo yhi)
  (setq u     (max 60.0 (/ wdt 12.0))
        th    (peb-stair-th u)
        going (peb-stair-going)
        lw    (max 900.0 wdt)                  ; top-landing width
        run1  (* going f1)
        run2  (* going (if f2 f2 0))
        x0    ox                               ; foot of flight 1
        xb    (+ x0 run1)                      ; head of flight 1 = quarter-turn landing
        x1    (+ xb wdt)                       ; far edge of the landing (square: wdt x wdt)
        yb0   oy                               ; flight 1 band
        yb1   (+ yb0 wdt)
        yt    (+ yb1 run2))                    ; head of flight 2

  ;; --- STRINGERS: flight 1 along x, flight 2 along y, and the outside of the turn.
  (peb-comp-layer "STAIR-STRINGER" 1)
  (foreach s (list (list x0 x1 yb0) (list x0 xb yb1))     ; horizontal edges
    (entmake (list (cons 0 "SOLID") (cons 8 "STAIR-STRINGER")
                   (list 10 (car s) (- (caddr s) (* u 0.35)) 0.0)
                   (list 11 (cadr s) (- (caddr s) (* u 0.35)) 0.0)
                   (list 12 (car s) (+ (caddr s) (* u 0.35)) 0.0)
                   (list 13 (cadr s) (+ (caddr s) (* u 0.35)) 0.0))))
  (foreach s (list (list yb1 yt xb) (list yb0 yt x1))      ; vertical edges (flight 2)
    (entmake (list (cons 0 "SOLID") (cons 8 "STAIR-STRINGER")
                   (list 10 (- (caddr s) (* u 0.35)) (car s) 0.0)
                   (list 11 (- (caddr s) (* u 0.35)) (cadr s) 0.0)
                   (list 12 (+ (caddr s) (* u 0.35)) (car s) 0.0)
                   (list 13 (+ (caddr s) (* u 0.35)) (cadr s) 0.0))))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-STRINGER")
                 (list 10 x0 yb0 0.0) (list 11 x0 yb1 0.0)))

  ;; --- TREADS: flight 1 across x (y-lines), flight 2 across y (x-lines).
  ;; Counted off the RISER COUNT, not re-derived from the run - the run came from the count in
  ;; the first place, and dividing it back out is how a rounding error becomes a missing tread.
  (peb-comp-layer "STAIR-TREAD" 7)
  (setq i 1 n f1)
  (while (< i n)
    (setq x (+ x0 (* i going)))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TREAD")
                   (list 10 x yb0 0.0) (list 11 x yb1 0.0)))
    (setq i (1+ i)))
  (setq i 1 n (if f2 f2 0))
  (while (< i n)
    (setq y (+ yb1 (* i going)))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TREAD")
                   (list 10 xb y 0.0) (list 11 x1 y 0.0)))
    (setq i (1+ i)))

  ;; --- QUARTER-TURN LANDING, square, with its beam on the flight-1 edge and the post.
  (peb-comp-layer "STAIR-LANDING" 3)
  (peb-comp-poly (list (list xb yb0) (list x1 yb0) (list x1 yb1) (list xb yb1)))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 xb yb0 0.0) (list 11 xb yb1 0.0)))
  (setq r (max 30.0 (* u 0.5)))
  (entmake (list (cons 0 "CIRCLE") (cons 8 "STAIR-LANDING")
                 (list 10 (- x1 (* u 1.2)) (+ yb0 (* u 1.2)) 0.0) (cons 40 r)))

  ;; --- TOP LANDING at the head of flight 2.
  (if topl
    (progn
      (peb-comp-poly (list (list xb yt) (list x1 yt) (list x1 (+ yt lw)) (list xb (+ yt lw))))
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                     (list 10 xb yt 0.0) (list 11 x1 yt 0.0)))))

  ;; --- UP: one arrow per flight, turning the corner; the word at the foot.
  (peb-comp-layer "STAIR-TEXT" 7)
  (peb-stair-arrow (+ x0 (* u 1.2)) (/ (+ yb0 yb1) 2.0) (- xb (* u 0.6)) (/ (+ yb0 yb1) 2.0) u T)
  (peb-stair-arrow-v (/ (+ xb x1) 2.0) (+ yb1 (* u 1.0)) (- yt (* u 0.6)) u)
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "MR" (list (- x0 (* u 0.4)) (/ (+ yb0 yb1) 2.0))
            (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "UP")

  ;; --- notes.  The L is tall, so the flight-2 notes go to its RIGHT, not above.
  (setq ytxt (- yb0 (* u 2.4)))
  (peb-stair-note (/ (+ x0 xb) 2.0) yb0 ytxt th
                  (if (and trd (/= trd "")) (strcat "TREAD (TYP.) - " (strcase trd)) "TREAD (TYP.)"))
  (peb-stair-note (+ x0 (* run1 0.18)) yb1 (+ yb1 (* u 2.4)) th "STRINGER")
  (peb-stair-note (/ (+ xb x1) 2.0) yb0 (- yb0 (* u 5.6)) th "QUARTER-TURN LANDING")
  (if topl
    (peb-stair-note-r x1 (+ yt (/ lw 2.0)) (+ x1 (* u 3.0)) th
                      (if (and pfl (/= pfl ""))
                        (strcat "TOP LANDING PLATFORM - " (strcase pfl))
                        "TOP LANDING PLATFORM")))

  (setq xlo x0 xhi x1 ylo (- yb0 (* u 5.6)) yhi (if topl (+ yt lw) yt))
  (peb-stair-dim xlo xhi (+ yhi (* u 2.6)) th
                 (peb-stair-dim-overall (abs (- xhi xlo)) "STAIRCASE LENGTH"))
  ;; The block's own caption - which LEVEL it is.  nil for a stair that needs one plan, whose
  ;; single "PLAN" caption is drawn by the wrapper underneath the set.
  (if sub
    (progn
      (setvar "CLAYER" "STAIR-TEXT")
      (txt-bold "MC" (list (/ (+ xlo xhi) 2.0) (- ylo (* u 1.6)))
                (/ (* th 1.05) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 sub)))
  (list xlo xhi ylo yhi))

;; A vertical climb arrow (flight 2 of an L), head at the top.
(defun peb-stair-arrow-v (x y0 y1 u)
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 x y0 0.0) (list 11 x y1 0.0)))
  (entmake (list (cons 0 "SOLID") (cons 8 "STAIR-TEXT")
                 (list 10 (- x (* u 0.55)) (- y1 (* u 1.6)) 0.0)
                 (list 11 (+ x (* u 0.55)) (- y1 (* u 1.6)) 0.0)
                 (list 12 x y1 0.0) (list 13 x y1 0.0))))

;; A note whose leader runs sideways - used where a note above or below would collide.
(defun peb-stair-note-r (px py tx th s)
  (if (peb-stair-plain-p) (princ) (progn
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 px py 0.0) (list 11 tx py 0.0)))
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "ML" (list (+ tx (* th 0.3)) py)
            (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 s))))

;; ---- SECTION / ELEVATION of one staircase -----------------------------------------------
;; The manual pairs every PLAN with an ELEVATION on the same sheet, and the elevation is where a
;; staircase is actually understood: the climb, the landing heights, the handrail, and how the
;; top lands on the mezzanine deck.  Drawn to sheets 3-6 of Chapter 12.
;;
;; A DEVELOPED elevation.  Flights are laid out along the climb, so a U and an L give the same
;; elevation as a straight run of the same rise - which is correct, and is what the manual draws:
;; an elevation of a U with the return flight superimposed on the first would be unreadable and
;; would tell you nothing the plan has not already said.
;;
;; y = 0 is FINISH FLOOR LEVEL.  Everything above is real height in mm, so the drawing can be
;; scaled off - STAIRCASE HEIGHT and FULL LANDING HEIGHT are the two dimensions that matter and
;; they must be true.
;; PLAN AND ELEVATION MUST SPAN THE SAME LENGTH (owner, 1-Sep-2026: "Length of plan and Section
;; Should be same").  They are two projections of ONE object, drawn one above the other - if the
;; elevation runs longer than the plan it is not a projection of it, and nothing can be read
;; across between the two views.
;;
;; That forces the U to be drawn as a TRUE elevation rather than a developed one: the return
;; flight climbs BACK over the first, at a higher level, inside the same horizontal extent.  It
;; is the same rule that hides the second landing column behind the first - an elevation shows
;; what the eye sees along one direction, not the run unfolded flat.
;;
;;   developed (wrong here)   [___/___/___/___>        plan is half this long
;;   true elevation           [___/  <___/             same length as the plan
;;
;; Determine the maximum height a column pair should extend to.
;; In a U-stair, landings alternate ends: 0=RIGHT, 1=LEFT, 2=RIGHT, 3=LEFT, ...
;; Each column pair runs to the highest landing at their end, or to mezzanine if none.
;; col-index: 0 = left (xlo), 1 = right (xhi)
;; landing-heights: list of Y for landings 0, 1, 2, ... (not including base or head)
;; shp: "U" or "L" (affects which end each landing is on)



(defun peb-stair-elev (ox oy wdt hgt topl midl lbl trd shp /
                       u th going fl nf lw tlw hr1 hr2 rise dir ybase xnext
                       xa xcur ycur i k n x y xs xe ys ye ytxt hmid xmid xlo xhi lvls xrcc
                       fl nf rise nland colr colsum col-height)
  (setq u     (max 60.0 (/ wdt 12.0))
        th    (peb-stair-th u)
        going (peb-stair-going)
        fl    (peb-stair-flights hgt)       ; the SAME split the plan used - one rule, two views
        nf    (length fl)
        lw    (max 900.0 wdt)
        tlw   (if topl lw 0.0)
        hr1   (- (peb-stair-rail-h) (peb-stair-rail-mid))   ; top rail above the mid tube
        hr2   (peb-stair-rail-mid)                        ; the intermediate tube
        rise  (peb-stair-rise hgt)            ; EQUAL - height/count, never a held 150
        ;; THE STAIR STARTS AT ITS BASE, WHICH IS NOT ALWAYS F.F.L.  With a 150 riser held
        ;; exactly, the climb is steps*150 and that overshoots the storey by up to half a
        ;; riser; the difference is taken in the grout bed under the base plates so the HEAD
        ;; lands exactly on the mezzanine.  oy stays the F.F.L datum - every level marker is
        ;; still measured from it - but the first tread springs from ybase.
        ybase (+ oy (peb-stair-base-offset hgt))
        xa    ox xcur ox ycur ybase
        lvls  (list ybase))       ; the base first; each landing and the head are added below


  ;; --- FINISH FLOOR LEVEL: the datum every height is measured from.
  (peb-comp-layer "STAIR-TEXT" 7)
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 (- xa (* u 3.0)) oy 0.0) (list 11 (+ xa 1000.0) oy 0.0)))
  ;; --- and the BASE, when it does not coincide with it.  Drawing only one of the two would
  ;; leave the bottom riser floating with nothing to explain the gap.
  (if (> (abs (peb-stair-base-offset hgt)) 0.5)
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                   (list 10 (- xa (* u 3.0)) ybase 0.0) (list 11 (+ xa 600.0) ybase 0.0))))

  ;; --- climb each flight, landing after each but the last.
  (setq i 0 xlo ox xhi ox)
  (while (< i nf)
    ;; A U folds: odd flights climb back the way they came, over the flight below.
    (setq dir (if (and (= shp "U") (= (rem i 2) 1)) -1.0 1.0))
    (setq xs xcur ys ycur
          xe (+ xs (* dir going (nth i fl)))
          ye (+ ys (* rise  (nth i fl))))
    (setq xlo (min xlo xs xe) xhi (max xhi xs xe))
    ;; stringer as a sloping band
    (peb-comp-layer "STAIR-STRINGER" 1)
    (peb-stair-slab xs ys xe ye (peb-stair-stringer-d))   ; C-200x75x6x6
    ;; the step profile
    (peb-comp-layer "STAIR-TREAD" 7)
    (setq k 0 n (nth i fl))
    (while (< k n)
      (setq x (+ xs (* dir k going)) y (+ ys (* k rise)))
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TREAD")
                     (list 10 x y 0.0) (list 11 (+ x (* dir going)) y 0.0)))
      (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TREAD")
                     (list 10 (+ x (* dir going)) y 0.0) (list 11 (+ x (* dir going)) (+ y rise) 0.0)))
      (setq k (1+ k)))
    ;; handrail over this flight
    (peb-comp-layer "STAIR-RAIL" 5)
    (peb-stair-rail xs ys xe ye hr1 hr2)
    (setq xcur xe ycur ye)
    ;; intermediate landing + the post that carries it to the floor
    (if (< i (1- nf))
      (progn
        ;; THE LANDING PROJECTS OUTWARD, IN THE DIRECTION THE FLIGHT WAS TRAVELLING.
        ;; Owner, 1-Sep-2026: "Landing of 2nd intermediate should be outward."
        ;;
        ;; The polygon used to be drawn from xcur to xcur+lw - always to the RIGHT - while the
        ;; cursor moved by dir*lw.  On flight 1 (dir +1) those agree, which is why a two-flight
        ;; stair never showed it.  On flight 2 the stair is travelling LEFT, so the landing was
        ;; drawn back over the flight that had just climbed it instead of projecting past its
        ;; end.  A 3-landing stair is the first case where the two disagree.
        ;;
        ;; Outward is also the only place it can physically go: a landing hanging back over the
        ;; foot of the flight below would leave no headroom on the bottom steps.
        (setq xnext (+ xcur (* dir lw)))
        (peb-comp-layer "STAIR-LANDING" 3)
        (peb-comp-poly (list (list xcur ycur) (list xnext ycur)
                             (list xnext (+ ycur (* u 0.8))) (list xcur (+ ycur (* u 0.8)))))
        (peb-stair-toeplate (min xcur xnext) (max xcur xnext) ycur)
        (peb-comp-layer "STAIR-RAIL" 5)
        (peb-stair-rail xcur ycur xnext ycur hr1 hr2)
        (if (= i 0) (setq hmid ycur))
        (setq lvls (append lvls (list ycur)))
        (setq xlo (min xlo xnext) xhi (max xhi xnext))
        ;; THE NEXT FLIGHT STARTS FROM THE LANDING'S INNER EDGE - the cursor does NOT move out
        ;; with the landing (owner, 1-Sep-2026: "stringer will start from right edge of 2nd
        ;; landing", the right edge being the inner one on a landing that projects left).
        ;;
        ;; Advancing the cursor to the OUTER face made every flight start one landing further
        ;; along than the last, so instead of a switchback stacking in one footprint the stair
        ;; walked sideways down the sheet - 0->5100, then 6300->1200, then 0->5100 again.  A
        ;; two-flight stair hides it; a three-landing stair is where it becomes obvious, and it
        ;; is what the red marking on the markup is crossing out.
        ;;
        ;; Leaving the cursor put makes the flights overlap in x, which is correct: they are at
        ;; different DEPTHS, and an elevation looks along the depth.  That is what a switchback
        ;; looks like drawn flat.
        ))
    (setq i (1+ i)))

  ;; --- THE HEAD LANDS ON THE MEZZANINE DECK - there is no top landing platform.
  ;; Owner, 1-Sep-2026: "2nd landing will be Mezzanine Floor".  What used to be drawn here was
  ;; a platform in front of the deck, i.e. a step that does not exist.  The deck itself is
  ;; drawn as a short run of floor so the flight visibly arrives ON something.
  (peb-comp-layer "STAIR-LANDING" 3)
  (peb-comp-poly (list (list xcur ycur) (list (+ xcur (* dir lw)) ycur)
                       (list (+ xcur (* dir lw)) (+ ycur (* u 0.8)))
                       (list xcur (+ ycur (* u 0.8)))))
  (setq xcur (+ xcur (* dir lw)))
  (setq xlo (min xlo xcur) xhi (max xhi xcur))
  ;; ---- THE COLUMNS THAT CARRY THE MID-LANDINGS  (owner 3-Sep-2026) ---------------------
  ;; "In case of Intermediate Floors, the columns will extend till highest mid-landing.  In case
  ;;  mid-landings are > 1, 4 columns will come on 4 corners - only if the landings are more
  ;;  than 1.  Overall: the columns support the mid-landing between the floors, and the stringer
  ;;  rests on the F.F.L for each floor."
  ;;
  ;; Two things follow, and they settle what three earlier passes at this left unresolved:
  ;;
  ;; HOW HIGH.  A column exists to hold up a MID-LANDING - the one place between two floors
  ;; where a flight has nothing else to land on.  At every floor the stringer bears on the
  ;; F.F.L itself, so nothing needs carrying there.  The columns therefore stop at the HIGHEST
  ;; mid-landing and go no further: above it the last flight is already held at both ends, by
  ;; the landing it leaves and by the deck it arrives on.  Running them to the mezzanine drew
  ;; steel standing in air carrying nothing - the markup "this side encircled column will not go
  ;; in the air as there no support required in case of one mid landing".
  ;;
  ;; HOW MANY.  Four corner columns are for a tower with SEVERAL mid-landings, which land at
  ;; alternate ends and so need a pair at each.  With exactly ONE mid-landing there is only one
  ;; end to hold: one pair, at that landing's own end.  The other pair was the one in the air.
  ;;
  ;; nland = flights - 1.  The U alternates ends, so landing i is at xhi for even i and xlo for
  ;; odd i; the topmost is at xhi when nland is odd and xlo when it is even.
  (setq fl    (peb-stair-flights hgt)
        nf    (length fl)
        rise  (peb-stair-rise hgt)
        nland (1- nf))
  (if (> nland 0)
    (progn
      ;; the TOPMOST mid-landing: every flight below it, which is all of them but the last
      (setq colr 0 colsum 0)
      (while (< colr (1- nf))
        (setq colsum (+ colsum (nth colr fl)) colr (1+ colr)))
      (setq col-height (+ ybase (* rise colsum)))
      (peb-comp-layer "STAIR-LANDING" 3)
      (if (> nland 1)
        ;; several landings, alternating ends -> a pair at each corner: four columns
        (progn
          (peb-stair-col-elev (+ xlo (/ (peb-stair-col-d) 2.0)) ybase col-height)
          (peb-stair-col-elev (- xhi (/ (peb-stair-col-d) 2.0)) ybase col-height))
        ;; ONE landing -> ONE pair, at the end that landing is actually on
        (if (= (rem (1- nland) 2) 0)
          (peb-stair-col-elev (- xhi (/ (peb-stair-col-d) 2.0)) ybase col-height)
          (peb-stair-col-elev (+ xlo (/ (peb-stair-col-d) 2.0)) ybase col-height)))))

  ;; The "MEZZANINE LEVEL" leader that stood here is GONE (owner 3-Sep-2026).  It printed at the
  ;; same point as the MEZZANINE FLOOR slab label below and the two smeared into each other; the
  ;; slab label says it, and the numeric level marker to the right measures it.
  ;; The columns are NAMED on the section, which owns the part names - repeating the label here
  ;; broke that rule and, being forty characters hung off the left edge, dragged the sheet
  ;; extents 7 m further left and cost the whole drawing a scale step for one duplicate word.
  ;; LEVEL MARKERS: the base, every landing, and the head - measured from the finished floor.
  (setq lvls (append lvls (list ycur)))
  (foreach lv lvls (peb-stair-level (+ xhi (* u 1.2)) lv oy th))
  ;; The "F.F.L" elbow that stood here is GONE (owner 3-Sep-2026), for the same reason the
  ;; "MEZZANINE LEVEL" leader above it went.  ONE level was being named THREE times: this elbow
  ;; hung off the left edge, the GROUND FLOOR mark with its triangle sat a few millimetres under
  ;; it, and the numeric marker on the right already reads +0MM.  Three labels crowding one line
  ;; is not emphasis - the elbow's text ran into the rotated 2,690 dimension beside it, and its
  ;; leader dragged the sheet extents further left for a word the mark already says.
  ;; Each fact once: the mark NAMES the level, the marker MEASURES it.

  ;; --- CONCRETE FLOOR SYMBOLS at ground and mezzanine levels
  (peb-comp-layer "STAIR-LANDING" 3)
  ;; -- THE RCC FLOOR IS TRIMMED AT THE STAIRCASE (owner 3-Sep-2026) --------------------
  ;; "the RCC floor was extended to staircase, it should be trim at the last step of
  ;; staircase."  Both slabs ran to `xa + 800` - 800 mm PAST the foot of the flight - so the
  ;; concrete was drawn under the first step, through the very riser it is supposed to stop at.
  ;; A floor does not continue into a stairwell; it stops where the stair starts.
  ;;   ground floor  -> the FIRST step, which is xa: the flight springs from there.
  ;;   mezzanine     -> the LAST step, the head.  The deck run drawn at the head already moved
  ;;                    xcur out by dir*lw, so the head is xcur back-tracked by that.
  (setq xrcc xa)
  ;; Ground level concrete (F.F.L)
  (peb-comp-poly (list (list (- xlo (* u 3.0)) (- oy 100.0)) (list xrcc (- oy 100.0))
                             (list xrcc oy) (list (- xlo (* u 3.0)) oy)))
  ;; Concrete hatch pattern at ground
  (foreach i (list (* u 0.5) (* u 1.0) (* u 1.5) (* u 2.0))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                   (list 10 (- xlo (* u 3.0)) (- oy (- i 100.0)) 0.0)
                   (list 11 xrcc (- oy (- i 100.0)) 0.0))))
  (peb-stair-floor-mark (- xlo (* u 3.0)) oy th "GROUND FLOOR" -1 (+ 100.0 (* u 2.0)))

  ;; Mezzanine level concrete — trimmed at the HEAD, the last step (see above)
  (setq xrcc (- xcur (* dir lw)))
  ;; Mezzanine level concrete
  (peb-comp-poly (list (list (- xlo (* u 3.0)) ycur) (list xrcc ycur)
                             (list xrcc (+ ycur 100.0)) (list (- xlo (* u 3.0)) (+ ycur 100.0))))
  ;; Concrete hatch pattern at mezzanine
  (foreach i (list (* u 0.5) (* u 1.0) (* u 1.5) (* u 2.0))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                   (list 10 (- xlo (* u 3.0)) (+ ycur i) 0.0)
                   (list 11 xrcc (+ ycur i) 0.0))))
  (peb-stair-floor-mark (- xlo (* u 3.0)) ycur th "MEZZANINE FLOOR" 1 (+ 100.0 (* u 2.0)))

  ;; --- LABELLING: the LEVELS carry this view, nothing else needs to.
  ;; A reader of an elevation wants to know how high each landing is and where it meets the
  ;; mezzanine.  Stringer / tread / handrail / expansion-bolt notes are fabrication information
  ;; and belong on the approval drawing.
  ;; OUTSIDE the columns, not between them and the stair.  Measured off xlo - the tower's own
  ;; left face - rather than off xa, which is the foot of flight 1 and sits well inside the
  ;; tower once the mezzanine deck and any outward landing are counted.  The rotated text was
  ;; landing on the column line.
  (if (and hmid (> nf 1))
    (peb-stair-vdim (- xlo (* u 3.0)) oy hmid th "FULL LANDING HEIGHT"))
  (peb-stair-vdim (- xlo (* u 6.4)) oy (+ oy hgt) th
                  (peb-stair-dim-overall hgt "STAIRCASE HEIGHT"))

  (setvar "CLAYER" "STAIR-TEXT")
  ;; -- THE CAPTION PAIR CLEARS THE FLOOR MARKS, AND EACH OTHER (rule 4B.27) --------------
  ;; These sat at 11u and 13.8u below the datum - gaps written in `u`, the stair's geometry
  ;; unit, while the text they exist to clear is written in `th`.  Raise the text and the gaps
  ;; do not follow: "ELEVATION" landed on the GROUND FLOOR mark and its subtitle landed on
  ;; "ELEVATION", 2.8u apart when the two lines together stand 2.35 x th tall.  Measured in
  ;; text heights they hold at any size.
  (txt-bold "MC" (list (/ (+ xlo xhi) 2.0) (- oy (* th 6.2)))
            (/ (* th 1.25) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "ELEVATION")
  (if lbl
    (txt-bold "MC" (list (/ (+ xlo xhi) 2.0) (- oy (* th 8.1)))
              (/ (* th 1.1) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 lbl))
  (princ))

;; ---- LEVEL MARKER  (owner 1-Sep-2026) ---------------------------------------------------
;; The convention on Maimaar's own stair sections: a level line with a triangle on it and the
;; height beside it - "+8675mm", "+11188mm" (MEC-1146 Colgate Stairs No. 4, CROSS SECTION @
;; GRID B & C).  It is what ties the staircase to the building; without it a section shows a
;; stair floating at no particular height.
;;
;; These are GEOMETRY, not designed member sizes, so they belong on a proposal drawing: the
;; heights come from the BSF's own mezzanine floor height and the landing split.
(defun peb-stair-level (x y base th / t2 s)
  ;; SIGN THE LEVEL, DO NOT ASSUME IT IS POSITIVE.  The "+" used to be hard-coded, which was
  ;; harmless while every level was above the datum - and became "+-20mm" on the drawing the
  ;; moment the stair base dropped below F.F.L to hold the 150 riser exactly.  rtos already
  ;; writes the minus sign, so the prefix belongs only on a positive value.
  (setq t2 (* th 0.85)
        s  (strcat (if (< (- y base) -0.5) "" "+") (rtos (- y base) 2 0) "mm"))
  (peb-comp-layer "STAIR-TEXT" 7)
  ;; the level line
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 x y 0.0) (list 11 (+ x (* t2 7.0)) y 0.0)))
  ;; the triangle, sitting ON the line and pointing down at it
  (entmake (list (cons 0 "SOLID") (cons 8 "STAIR-TEXT")
                 (list 10 (+ x (* t2 1.0)) (+ y (* t2 1.1)) 0.0)
                 (list 11 (+ x (* t2 2.6)) (+ y (* t2 1.1)) 0.0)
                 (list 12 (+ x (* t2 1.8)) y 0.0) (list 13 (+ x (* t2 1.8)) y 0.0)))
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "BL" (list (+ x (* t2 3.0)) (+ y (* t2 0.35)))
            (/ t2 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 s))

;; ---- A NAMED FLOOR CARRIES THE LEVEL SYMBOL  (owner 3-Sep-2026) -------------------------
;; "modify as marked - show the levels."  The mezzanine line on the elevation had TWO labels
;; landing on the same point - a "MEZZANINE LEVEL" leader note and the "MEZZANINE FLOOR" slab
;; label - printed one on top of the other into an unreadable smear, and neither of them was a
;; level MARK.  The leader is gone (it said nothing the slab label does not) and the slab label
;; now carries the same downward triangle the numeric levels use, so a named floor and a
;; dimensioned level read as the same kind of thing.
;;
;; The text runs RIGHT from the mark, not left: a long string hung off the left edge is what
;; once dragged the sheet extents 7 m out and cost the whole drawing a scale step.
(defun peb-stair-floor-mark (x y th name dir clear / t2 yl ytx)
  ;; `dir` is +1 when the slab's ink lies BELOW y (the mezzanine, whose concrete and hatch run
  ;; upward from it) and -1 when it lies ABOVE (the ground floor).  `clear` is how far that ink
  ;; reaches, so the mark is placed past it: the first pass at this put the text at the floor
  ;; line itself and the concrete hatch struck straight through every letter.
  ;; The triangle points AT the floor line; the level line and text sit clear of the slab.
  ;; The DROP below the line is not the mirror of the RISE above it (owner 3-Sep-2026).
  ;; Text grows UPWARD from its baseline, so a mark whose text sits ABOVE the line needs only a
  ;; gap (0.35), while one whose text sits BELOW it needs the gap PLUS the whole plotted height.
  ;; Taking 1.15 for both put the level line through the middle of GROUND FLOOR's lettering while
  ;; MEZZANINE FLOOR, drawn by the same call in the other direction, read perfectly - the classic
  ;; sign of a gap that was tuned in one direction and mirrored into the other.  2.75 is measured
  ;; off the plot: this sheet's bold lettering caps out near 2.3 x t2, and 0.35 clears it (4B.27).
  (setq t2  (* th 0.85)
        yl  (+ y (* dir (+ clear (* t2 1.3))))
        ytx (if (> dir 0) (+ yl (* t2 0.35)) (- yl (* t2 2.75))))
  (peb-comp-layer "STAIR-TEXT" 7)
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 x yl 0.0) (list 11 (+ x (* t2 7.5)) yl 0.0)))
  (entmake (list (cons 0 "SOLID") (cons 8 "STAIR-TEXT")
                 (list 10 (+ x (* t2 1.0)) (+ yl (* dir t2 1.1)) 0.0)
                 (list 11 (+ x (* t2 2.6)) (+ yl (* dir t2 1.1)) 0.0)
                 (list 12 (+ x (* t2 1.8)) yl 0.0) (list 13 (+ x (* t2 1.8)) yl 0.0)))
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "BL" (list (+ x (* t2 3.2)) ytx)
            (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 name))

;; A sloping member of depth `d`, drawn as a closed band from (x0,y0) to (x1,y1).
(defun peb-stair-slab (x0 y0 x1 y1 d)
  (peb-comp-poly (list (list x0 y0) (list x1 y1) (list x1 (- y1 d)) (list x0 (- y0 d)))))

;; The handrail over a run: top rail at h1+h2, mid rail at h2, and POSTS along the run.
;;
;; PROPORTION IS THE POINT (owner 1-Sep-2026: "Draw the Side View proportionally").  Two rails
;; with a post only at each end enclose a long empty parallelogram, and at sheet scale that
;; reads as a solid ramp, not as a railing - which is exactly how the first elevation came out.
;; The manual's elevations carry a post roughly every 1.5 m, and it is the posts, not the rails,
;; that make a handrail legible.
;; NOTE the local list: `tt`, never `t`.  T is AutoLISP's TRUE constant - declaring it local and
;; assigning a float to it silently breaks every (if ...) and (cond ... (T ...)) that runs
;; afterwards.  It truncated this elevation to a single flight, and vl-catch-all-apply swallowed
;; the error so the sheet just came out half-drawn.
(defun peb-stair-rail (x0 y0 x1 y1 h1 h2 / L n i tt px py)
  (foreach h (list h2 (+ h1 h2))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-RAIL")
                   (list 10 x0 (+ y0 h) 0.0) (list 11 x1 (+ y1 h) 0.0))))
  ;; posts: both ends always, then intermediates at ~1500 along the run
  (setq L (distance (list x0 y0) (list x1 y1))
        n (max 1 (fix (/ L 1500.0)))
        i 0)
  (while (<= i n)
    (setq tt (/ (float i) (float n))
          px (+ x0 (* tt (- x1 x0)))
          py (+ y0 (* tt (- y1 y0))))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-RAIL")
                   (list 10 px py 0.0) (list 11 px (+ py h1 h2) 0.0)))
    (setq i (1+ i))))


;; ---- THE LANDING COLUMN  (owner 1-Sep-2026) ---------------------------------------------
;; TWO corrections, and both are structural, not cosmetic.
;;
;; 1. THERE ARE TWO OF THEM, ONE EACH SIDE - never one in the middle.  The landing beam SPANS
;;    between the columns, so they stand under its ends, on the two stringer lines.  A single
;;    column on the centreline would have the beam cantilevering both ways off a point support,
;;    and it would stand in the middle of the platform where people walk.  Owner, 1-Sep-2026:
;;    "Staircase columns on both sides not in the middle".
;;
;; 2. IT IS AN I-SECTION, NOT A LINE.  A single line says "something vertical is here"; it does
;;    not say which way the section faces, and a reader cannot tell a column from a leader.
;;    Flanges and web, always.
;;
;; Section: 200 deep x 150 flange is the light built-up column these landings carry.
(defun peb-stair-col-d  () 200.0)
(defun peb-stair-col-bf () 150.0)

;; ELEVATION: seen from the side, the flanges are the two outer faces and the web is the line
;; between them.
(defun peb-stair-col-elev (cx y0 y1 / d)
  (setq d (peb-stair-col-d))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 (- cx (/ d 2.0)) y0 0.0) (list 11 (- cx (/ d 2.0)) y1 0.0)))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 (+ cx (/ d 2.0)) y0 0.0) (list 11 (+ cx (/ d 2.0)) y1 0.0)))
  ;; the web, on the centreline
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 cx y0 0.0) (list 11 cx y1 0.0)))
  ;; base plate
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 (- cx d) y0 0.0) (list 11 (+ cx d) y0 0.0))))

;; PLAN: the I seen from above - two flanges with the web between them.
(defun peb-stair-col-plan (cx cy / d bf tw)
  (setq d (peb-stair-col-d) bf (peb-stair-col-bf) tw 20.0)
  (foreach xx (list (- cx (/ d 2.0)) (+ cx (/ d 2.0)))          ; the two flanges
    (peb-comp-poly (list (list (- xx (/ tw 2.0)) (- cy (/ bf 2.0)))
                         (list (+ xx (/ tw 2.0)) (- cy (/ bf 2.0)))
                         (list (+ xx (/ tw 2.0)) (+ cy (/ bf 2.0)))
                         (list (- xx (/ tw 2.0)) (+ cy (/ bf 2.0))))))
  (peb-comp-poly (list (list (- cx (/ d 2.0)) (- cy (/ tw 2.0)))  ; the web
                       (list (+ cx (/ d 2.0)) (- cy (/ tw 2.0)))
                       (list (+ cx (/ d 2.0)) (+ cy (/ tw 2.0)))
                       (list (- cx (/ d 2.0)) (+ cy (/ tw 2.0))))))


;; X BRACING between the two landing columns, as the Colaro approval elevation draws it.
(defun peb-stair-brace (x0 x1 y0 y1)
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 x0 y0 0.0) (list 11 x1 y1 0.0)))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 x0 y1 0.0) (list 11 x1 y0 0.0)))
  ;; the horizontal tie at the head, closing the tower
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 x0 y1 0.0) (list 11 x1 y1 0.0))))

;; TOE PLATE - the kick plate at a landing edge.  The manual letters it on every elevation; it
;; is what stops a dropped tool falling on whoever is below, and it is 100 mm high.
(defun peb-stair-toeplate (x0 x1 y)
  (peb-comp-poly (list (list x0 y) (list x1 y) (list x1 (+ y 100.0)) (list x0 (+ y 100.0)))))

;; A VERTICAL dimension with open arrows, label read up the line.
(defun peb-stair-vdim (x y0 y1 th s / t2)
  (if (peb-stair-plain-p) (princ) (progn
  (peb-comp-layer "DIMENSIONS" 6)
  (setq t2 (* th 0.9))
  (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS") (list 10 x y0 0.0) (list 11 x y1 0.0)))
  (foreach yy (list y0 y1)
    (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS")
                   (list 10 (- x (* t2 1.2)) yy 0.0) (list 11 (+ x (* t2 1.2)) yy 0.0))))
  (foreach p (list (list y0 1.0) (list y1 -1.0))
    (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS")
                   (list 10 x (car p) 0.0)
                   (list 11 (+ x (* t2 0.45)) (+ (car p) (* (cadr p) t2 1.4)) 0.0)))
    (entmake (list (cons 0 "LINE") (cons 8 "DIMENSIONS")
                   (list 10 x (car p) 0.0)
                   (list 11 (- x (* t2 0.45)) (+ (car p) (* (cadr p) t2 1.4)) 0.0))))
  (setvar "CLAYER" "DIMENSIONS")
  (txt-dim "BC" (list (- x (* t2 0.5)) (/ (+ y0 y1) 2.0))
            (/ t2 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 90.0
            (peb-stair-dimtext (abs (- y1 y0)) s)))))


;; ---- CROSS SECTION THROUGH A FLIGHT  (owner 1-Sep-2026) ---------------------------------
;; "in MAMMUT MANUAL, THEY HAVE DRAWN 3D, we have to give them the Section".
;;
;; The manual's stair sheets are PICTORIAL - shaded stringers and tube handrails drawn in
;; perspective.  They explain the product; they are not what a customer or a checker measures.
;; Maimaar's own approval set does it properly: "CROSS SECTION AT D-D" on the Colaro job
;; (E:\Maimaar Steel Pvt Ltd\Jobs0-MSPL ... Approval Package) is an orthographic cut
;; with the members sectioned and every plate and bolt called out.
;;
;; This is that cut, taken ACROSS a flight and looking up the climb: both stringers in section,
;; the tread spanning between them, a handrail each side, the toe plates, and the two dimensions
;; that govern - the out-to-out width and the 475/425 handrail set-out.
(defun peb-stair-section (ox oy wdt hgt lbl trd pfl / well dep
                          u th fl nf rise lvl lvls
                          cd cbf xl xr xcl xcr yb yt i prev bw)
  ;; ---- SECTION A-A, CUT AT THE LANDING ---------------------------------------------------
  ;; Concept taken from Maimaar's own approval sets - 055-MSPL Style Textile "ELEVATION AT
  ;; GRID-1 & 2" and 1146-MEC Colgate "CROSS SECTION @ GRID B & C".
  ;;
  ;; WHY CUT AT THE LANDING AND NOT THROUGH A FLIGHT.  A cut through a flight shows a tread
  ;; between two stringers - true, but it explains nothing a reader did not already assume.
  ;; The cut at the LANDING is the one that shows what the staircase actually IS: a
  ;; self-supporting BRACED TOWER of two columns, cross-braced, carrying a landing beam at
  ;; every level, standing on its own pedestals.  That is the fact a customer is buying and it
  ;; is invisible on every other view.
  ;;
  ;; It also reconciles the two things that looked contradictory: along the run you see ONE
  ;; column line (the other hides behind it); across the stair - this cut - you see BOTH, with
  ;; the bracing between them.  Same structure, two directions.
  ;;
  ;; THE COLUMNS ARE AT THE CORNERS OF THE TOWER, NOT BESIDE THE FLIGHT  (owner, 1-Sep-2026:
  ;; "in section the column is shown the middle. columns must be on 4 corners, reference
  ;; 2022-055-MSPL").  This view used to put them on the flight's own edges, +/- wdt/2 - which
  ;; on a U is the middle of the tower, because a U is TWO flight bands plus the well between
  ;; them.  So the section drew a stair standing on columns planted in the middle of its own
  ;; stairwell, and it disagreed with the layout plan, which had them 2,544 apart on the same
  ;; job.  Two views of one structure that could not both be true.
  ;;
  ;; The tower is `dep` wide - wdt + well + wdt - and the four columns stand at its corners;
  ;; this cut sees the near pair with the far pair directly behind them.  The FLIGHT still
  ;; occupies only wdt in the middle, which is why the landing beam spans past it to reach the
  ;; columns: that span is the thing this view exists to show.
  ;;
  ;; NAMES ONLY.  Sizes, gussets and bolts are approval-stage content and stay off a proposal.
  (setq u    (max 60.0 (/ wdt 12.0))
        th   (* u 1.5)
        fl   (peb-stair-flights hgt)
        nf   (length fl)
        rise (peb-stair-rise hgt)             ; EQUAL - height/count
        cd   (peb-stair-col-d)
        cbf  (peb-stair-col-bf)
        well (peb-stair-well wdt)        ; the stair well between the two flight bands
        dep  (+ wdt wdt well)            ; OUT TO OUT of the tower - what the columns stand on
        xl   (- ox (/ wdt 2.0))          ; the flight's own edges (the stringer lines)
        xr   (+ ox (/ wdt 2.0))
        xcl  (- ox (/ dep 2.0))          ; the COLUMN lines - the corners of the tower
        xcr  (+ ox (/ dep 2.0))
        yb   (+ oy (peb-stair-base-offset hgt))  ; the stair BASE - see peb-stair-base-offset
        yt   (+ oy hgt))                 ; mezzanine level

  ;; the landing levels this tower carries, measured up from the base at exactly 150 a step
  (setq lvls '() lvl yb i 0)
  (while (< i nf)
    (setq lvl (+ lvl (* rise (nth i fl))))
    (setq lvls (append lvls (list lvl)) i (1+ i)))

  ;; ---- PEDESTALS --------------------------------------------------------------------------
  (peb-comp-layer "STAIR-LANDING" 3)
  (foreach xx (list xcl xcr)
    (peb-comp-poly (list (list (- xx cd) (- yb 200.0)) (list (+ xx cd) (- yb 200.0))
                         (list (+ xx cd) yb) (list (- xx cd) yb))))
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                 (list 10 (- xcl (* u 2.0)) (- yb 200.0) 0.0)
                 (list 11 (+ xcr (* u 2.0)) (- yb 200.0) 0.0)))

  ;; ---- THE COLUMNS, trimmed to the heights they carry (STRUCTURAL RULE) ----------------------
  ;; REVISED per owner markup: "Trim the Columns at this level as marked.PNG"
  ;; RULE: Each column pair runs only as high as it carries load, NOT to the mezzanine.
  ;; For a 1-landing stair: LEFT column (near) carries landing + flight above → runs to mezzanine.
  ;;                        RIGHT column (far) carries landing only → stops at landing.
  ;; This prevents columns floating in mid-air where they carry no structural load.
  ;;
  ;; COLUMN TRIM RULE (owner 2-Sep-2026): columns extend to first landing only
  ;; Calculate first landing height: base + (first flight risers × 150mm)
  (setq rise (peb-stair-rise hgt)
        col-height (+ yb (* rise (nth 0 fl))))
  ;; Draw columns - both to first landing height
  (peb-stair-col-elev xcl yb col-height)
  (peb-stair-col-elev xcr yb col-height)

  ;; ---- LANDING BEAM at every landing, and the deck at the head ---------------------------
  (setq prev yb bw 120.0)
  (foreach lv lvls
    (peb-comp-layer "STAIR-LANDING" 3)
    (peb-comp-poly (list (list xcl lv) (list xcr lv) (list xcr (+ lv bw)) (list xcl (+ lv bw))))
    ;; ---- X BRACING in the panel below this level -----------------------------------------
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                   (list 10 xcl prev 0.0) (list 11 xcr lv 0.0)))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-LANDING")
                   (list 10 xcl lv 0.0) (list 11 xcr prev 0.0)))
    (setq prev lv))

  ;; ---- LANDING PLATFORM and HANDRAIL both sides at the head -------------------------------
  ;; THE PLATFORM REACHES THE COLUMNS, because this cut is taken at a FULL landing - one that
  ;; spans the whole tower, both flight bands and the well.  Drawing it only as wide as a
  ;; single flight was the same error as the columns: it showed the flight, not the tower, and
  ;; contradicted the plan beside it (owner: "section must show the column view as per the
  ;; plan. both are contradictory").
  (peb-comp-layer "STAIR-TREAD" 7)
  (peb-comp-poly (list (list xcl yt) (list xcr yt) (list xcr (+ yt 40.0)) (list xcl (+ yt 40.0))))
  (peb-comp-layer "STAIR-RAIL" 5)
  (foreach xx (list xcl xcr)
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-RAIL")
                   (list 10 xx (+ yt 40.0) 0.0) (list 11 xx (+ yt 40.0 (peb-stair-rail-h)) 0.0))))
  (foreach h (list (peb-stair-rail-mid) (peb-stair-rail-h))
    (entmake (list (cons 0 "LINE") (cons 8 "STAIR-RAIL")
                   (list 10 xcl (+ yt 40.0 h) 0.0) (list 11 xcr (+ yt 40.0 h) 0.0))))

  ;; ---- labels: column identification and structural rule -----------------------------------
  (peb-comp-layer "STAIR-TEXT" 7)
  ;; Main label: Column identification with quantity
  (peb-stair-note-elbow xcr (+ yb (* hgt 0.30)) (+ yb (* hgt 0.30)) (+ xcr (* u 3.0)) 1 th
                        "STAIRCASE COLUMNS (4 NOS.)")
  ;; Sub-label: Explain the trim rule clearly
  (peb-stair-note-elbow xcr (+ yb (* hgt 0.20)) (+ yb (* hgt 0.20)) (+ xcr (* u 3.0)) 1 th
                        "TRIMMED TO LANDING HEIGHTS")
  (peb-stair-note-elbow ox (+ yb (* hgt 0.16)) (+ yb (* hgt 0.16)) (- xcl (* u 3.0)) -1 th
                        "BRACING")
  (if lvls
    (peb-stair-note-elbow ox (nth 0 lvls) (nth 0 lvls) (- xcl (* u 3.0)) -1 th "LANDING BEAM"))
  (peb-stair-note-elbow ox (+ yt 40.0) (+ yt (* u 2.0)) (- xcl (* u 3.0)) -1 th
                        (if (and pfl (/= pfl "")) (strcat "LANDING PLATFORM - " (strcase pfl)) "LANDING PLATFORM"))
  (peb-stair-note-elbow xcr (+ yt 40.0 (peb-stair-rail-h)) (+ yt 40.0 (peb-stair-rail-h))
                        (+ xcr (* u 3.0)) 1 th "HANDRAIL")
  (peb-stair-note-elbow ox (- yb 200.0) (- yb (* u 2.4)) (- xcl (* u 3.0)) -1 th "PEDESTAL")

  ;; ---- dimensions the BSF states, and the levels -----------------------------------------
  ;; ---- ONE FACT, ONE PLACE  (owner 1-Sep-2026: "clear the mixed labelling") ---------------
  ;; This view used to repeat three things the ELEVATION already carries: STAIRCASE HEIGHT, the
  ;; full set of +NNNNmm level markers, and the stair's own title.  Stating the same fact twice
  ;; in two views is worse than stating it once, because a reader who notices a difference has
  ;; no way to tell which one is authoritative - and there is no reason for them ever to agree
  ;; except that both happen to be computed correctly today.
  ;;
  ;; So the views divide the work: the PLAN owns the footprint, the ELEVATION owns the climb
  ;; (levels and heights), and the SECTION owns what only it can show - the width across the
  ;; stair, and the names of the parts.  This is the one dimension that is genuinely the
  ;; section's own.
  ;; TWO WIDTHS, TWO NAMES.  The tower (column to column) and the flight are different
  ;; measurements and were being given the same words in different views - the layout plan said
  ;; "2544 O/O OF STEEL COLUMN" while this one said "OUT TO OUT WIDTH" over 1200.  Same phrase
  ;; for the same measurement everywhere, or the reader cannot tell them apart.
  ;; O/O OF STEEL COLUMN with breakdown: wdt + column depth + wdt
  (peb-stair-dim-breakdown xcl xcr (- yb (* th 4.6)) (* th 0.9) "O/O OF STEEL COLUMN"
                           (strcat "(" (rtos wdt 2 0) " + " (rtos cd 2 0) " + " (rtos wdt 2 0) ")"))
  ;; -- SPACED IN TEXT HEIGHTS, NOT IN `u` (rule 4B.27) ---------------------------------
  ;; These four sat at 2.6u / 5.2u / 8.4u / 10.6u below the cut.  Each row carries a dimension
  ;; line, its label, and - for the O/O row - a breakdown line under it, so at 2.6u apart with
  ;; text 2.2u tall they printed into one another.  In text heights the stack holds at any size.
  (peb-stair-dim xl  xr  (- yb (* th 2.2)) (* th 0.9) "STAIR WIDTH")

  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "MC" (list ox (- yb (* th 8.6)))
            (/ (* th 1.3) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "SECTION A-A")
  (txt-bold "MC" (list ox (- yb (* th 10.3)))
            (/ (* th 0.95) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "AT LANDING")
  ;; the stair's title is drawn once, under the elevation - `lbl` is accepted and ignored here
  (princ))

;; The A-A cut line on the PLAN, with its look-direction arrows - without this the section is
;; an orphan: nothing on the plan says where the cut was taken.
(defun peb-stair-cutline (x y0 y1 u th / o)
  (setq o (* u 1.6))
  (peb-comp-layer "STAIR-TEXT" 7)
  (entmake (list (cons 0 "LINE") (cons 8 "STAIR-TEXT")
                 (list 10 x (- y0 o) 0.0) (list 11 x (+ y1 o) 0.0)))
  (foreach yy (list (- y0 o) (+ y1 o))
    (setvar "CLAYER" "STAIR-TEXT")
    (txt-bold "MC" (list x (if (> yy y0) (+ yy (* th 0.9)) (- yy (* th 0.9))))
              (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 "A")))



;; ---- SPECIFICATION NOTE, entirely from the BSF ------------------------------------------
;; "note should be based on data filled by BS, for example, type of Floor, chequered plate, pan
;; etc. or other information" (owner, 1-Sep-2026).
;;
;; Every line here is a BSF field.  Nothing is hardcoded and nothing is assumed: where the form
;; is silent the note SAYS it is not stated, because a drawing that quietly invents a tread type
;; is worse than one that admits the gap - the reader cannot tell an invention from a fact.
;; "18" when every flight is the same, else "18 / 18 / 12" - the specification block states the
;; split, and a stair whose flights are equal should not be made to look as though they are not.
;; (Recovered: this was deleted along with the long rule note that used to be its only caller,
;;  which took the specification block's FLIGHTS line down with it - silently, because the
;;  drawer is wrapped and an undefined function just stops the block after its heading.)
(defun peb-stair-flight-list (fl / s eq n)
  (setq eq T n (car fl))
  (foreach f fl (if (/= f n) (setq eq nil)))
  (if eq
    (itoa n)
    (progn (setq s "")
           (foreach f fl (setq s (if (= s "") (itoa f) (strcat s " / " (itoa f)))))
           s)))

(defun peb-stair-specnote (ox oy wdt typ w hgt trd pfl hrail inmezz / u th y fl nsteps)
  ;; ONE text height for the whole sheet (owner 3-Sep-2026: "make this text more visible",
  ;; "overall make the staircase labelling precise").  Every other drawer on this sheet asks
  ;; peb-stair-th; this block kept its own 1.4u, so after the enlargement the SPECIFICATION -
  ;; the one block a reader goes to for the riser and the tread - was printing smaller than the
  ;; labels around it.  A second copy of a size is a second size.
  (setq u  (max 60.0 (/ wdt 12.0))
        th (peb-stair-th u)
        y  oy
        fl (peb-stair-flights hgt)
        nsteps (apply '+ fl))
  (peb-comp-layer "STAIR-TEXT" 7)
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "ML" (list ox y) (/ (* th 1.3) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0
            "STAIRCASE SPECIFICATION")
  (setq y (- y (* th 1.9)))
  ;; ---- ONLY THE MAIN INFORMATION  (owner 3-Sep-2026) ---------------------------------
  ;; "This text to be shortened - only main information, like riser height, tread etc."
  ;;
  ;; A six-line NOTE block used to stand below this one reciting the internal step-count
  ;; standard, the IBC clause and the landing derivation, and it ran straight through the
  ;; TYPICAL DETAIL OF STEEL CHECKERED PLATE STEP caption beside it.  None of it was
  ;; information a customer reads off a proposal drawing - it is the rulebook's material, and
  ;; the rulebook has it.  What a reader wants is the four figures that describe the stair, so
  ;; they are here, in one block, each stated once.
  (foreach ln
    ;; No space padding: ROMAND is PROPORTIONAL, so padded labels do not line their colons up -
    ;; they only look as though someone tried.  One separator, ragged left of it, honest.
    (list (strcat "NO. OF STEPS : " (itoa nsteps))
          (strcat "RISE PER STEP : " (rtos (peb-stair-rise hgt) 2 0) " MM (ALL EQUAL)")
          (strcat "TREAD (GOING) : " (rtos (peb-stair-going) 2 0) " MM")
          (strcat "FLIGHTS : " (itoa (length fl)) " OF " (peb-stair-flight-list fl))
          (strcat "INTERMEDIATE LANDINGS : " (itoa (1- (length fl)))))
    (txt-bold "ML" (list ox y) (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 ln)
    (setq y (- y (* th 1.5))))
  y)

;; ---- DESIGN LOADS  (owner 1-Sep-2026) ----------------------------------------------------
;; "we must mention the loads to be applied on the staircase - what is the standard specially
;; for the staircase ... In Different Locations - Production Hall, Shopping Malls".
;;
;; Source: BS 6399 - LIVE LOADS p47 (vertical) and
;; Table 4.10 p51 (horizontal on parapets, barriers and balustrades).  Both were dug out of the
;; manual rather than quoted from memory.
;;
;;   VERTICAL, stairs and landings          foot traffic only        3.0 kN/m2   4.0 kN point
;;                                          wheeled trolleys         4.0 kN/m2   4.0 kN
;;   Shop floors, sale and display          malls, retail            4.0 kN/m2   3.6 kN
;;   Plant rooms, boiler rooms, fan rooms                            7.5 kN/m2   4.5 kN
;;
;;   HORIZONTAL on the handrail             light access stairs      0.22 kN/m
;;                                          industrial / storage     0.36 kN/m
;;                                          stairs, landings         0.74 kN/m
;;                                          shopping malls, assembly 3.00 kN/m
;;
;; THE HANDRAIL LOAD IS THE ONE THAT BITES.  The same staircase carries 0.36 kN/m of rail load in
;; a production hall and 3.00 kN/m in a shopping mall - EIGHT TIMES - while the vertical load
;; barely moves.  A stair note that does not state its occupancy is not a specification.
(defun peb-stair-occupancy (usage / u)
  (setq u (strcase (if usage usage "")))
  (cond ((wcmatch u "*MALL*,*SHOP*,*RETAIL*,*SUPER*STORE*,*MARKET*")        "MALL")
        ((wcmatch u "*ASSEMBL*,*CINEMA*,*THEATRE*,*AUDITOR*,*HALL*WORSHIP*") "ASSEMBLY")
        ((wcmatch u "*BOILER*,*PLANT*ROOM*,*FAN*ROOM*")                      "PLANT")
        ((wcmatch u "*OFFICE*,*SHOWROOM*")                                   "OFFICE")
        ((wcmatch u "*PRODUCTION*,*FACTORY*,*INDUSTR*,*WAREHOUSE*,*STORAGE*,*WORKSHOP*,*MILL*,*UNIT*") "INDUSTRIAL")
        (T "DEFAULT")))

;; -> (vertical-udl  vertical-point  handrail-line  occupancy-text  assumed-flag)
(defun peb-stair-loads (usage / o)
  (setq o (peb-stair-occupancy usage))
  (cond
    ((= o "MALL")       (list "4.0" "3.6" "3.00" "SHOPPING MALL / RETAIL"   nil))
    ((= o "ASSEMBLY")   (list "4.0" "3.6" "3.00" "ASSEMBLY AREA"            nil))
    ((= o "PLANT")      (list "7.5" "4.5" "0.74" "PLANT / BOILER ROOM"      nil))
    ((= o "OFFICE")     (list "3.0" "4.0" "0.74" "OFFICE / SHOWROOM"        nil))
    ((= o "INDUSTRIAL") (list "3.0" "4.0" "0.36" "PRODUCTION / INDUSTRIAL"  nil))
    (T                  (list "3.0" "4.0" "0.74" "FOOT TRAFFIC (ASSUMED)"   T))))

;; The note block.  Sits under the views, headed, so it reads as part of the sheet's title
;; information rather than as a stray annotation.
;; ============================================================================
;; COLUMN & STRINGER BASE PLATE LAYOUT PLAN
;; ----------------------------------------------------------------------------
;; 055-MSPL's first sheet, APR-01: "STEEL COLUMN &  STRINGER BASE PLATE LAYOUT PLAN".  It is the
;; view we had nothing for, and it answers the one question the walking plan cannot: WHERE DOES
;; THIS STAIRCASE LAND ON THE FLOOR.  That is what a civil contractor needs and it is why the
;; reference gives it a sheet of its own rather than crowding it onto the plan.
;;
;; WHAT STANDS ON THE FLOOR, taken off the reference's own tags:
;;   CBP-01 (QTY-04) - four COLUMN base plates: a pair at each end of the stair tower and the
;;                     top-landing end, both on the outer stringer lines.
;;   SBP-01 (QTY-02) - two STRINGER base plates, where the bottom flight meets the floor.
;;
;; IT DOES NOT GROW WITH THE LANDING COUNT.  The columns run full height past the staircase and
;; every storey's landing hangs off the same two column lines (PD_RULEBOOK, "STAIRCASE"), so a
;; stair with four landings has the same four base plates as one with one.  That is exactly why
;; it is worth drawing once, separately, instead of repeating columns on every level plan.
;;
;; The dimension wording is the reference's, verbatim, including its habit of putting the
;; measured value first and the description after it.
(defun peb-stair-collayout (ox oy wdt hgt lbl /
                            u th fl going lw run1 xa xL yb0 yb1 dep well y out)
  (setq u     (max 60.0 (/ wdt 12.0))
        th    (peb-stair-th u)
        fl    (peb-stair-flights hgt)
        going (peb-stair-going)
        lw    (max 900.0 wdt)
        well  (peb-stair-well wdt)
        dep   (+ wdt wdt well)                  ; out-to-out of the U, across the run
        run1  (* going (nth 0 fl))
        ;; THE TOWER INCLUDES THE OUTWARD LANDING.  A stair with two or more intermediate
        ;; landings turns at BOTH ends, and the near-end landing projects outward past the foot
        ;; of flight 1 - so the column line at that end is a landing width further out.  Without
        ;; this the layout plan reported a 6,500 tower while the plan beside it dimensioned
        ;; 7,500 for the same staircase.
        out   (if (> (length fl) 2) lw 0.0)
        xa    (- ox out)                        ; near column line, outboard of the landing
        xL    (+ ox run1 lw)                    ; far face of the landing = the column line
        yb0   (- oy (/ dep 2.0))
        yb1   (+ oy (/ dep 2.0)))

  ;; --- the stair footprint, as a light outline so the plates read against something.
  (peb-comp-layer "STAIR-LANDING" 3)
  (peb-comp-poly (list (list xa yb0) (list xL yb0) (list xL yb1) (list xa yb1)))

  ;; --- FOUR COLUMNS: a pair on each of the two column lines, on the outer stringer lines.
  (foreach cx (list xa xL)
    (foreach cy (list (+ yb0 (/ (peb-stair-col-bf) 2.0)) (- yb1 (/ (peb-stair-col-bf) 2.0)))
      (peb-stair-col-plan (if (= cx xa)
                            (+ cx (/ (peb-stair-col-d) 2.0))
                            (- cx (/ (peb-stair-col-d) 2.0)))
                          cy)))

  ;; --- TWO STRINGER BASE PLATES at the foot of the bottom flight, on the stringer lines.
  (peb-comp-layer "STAIR-STRINGER" 1)
  ;; the stringer plates sit where flight 1 meets the floor - at ox, not at the outward
  ;; column line, which is a landing further out
  (foreach sy (list (+ yb0 (/ wdt 2.0)) (- yb1 (/ wdt 2.0)))
    (peb-comp-poly (list (list (+ ox (* u 1.6)) (- sy (* u 1.1)))
                         (list (+ ox (* u 4.4)) (- sy (* u 1.1)))
                         (list (+ ox (* u 4.4)) (+ sy (* u 1.1)))
                         (list (+ ox (* u 1.6)) (+ sy (* u 1.1))))))

  ;; --- THE PLATE MARKS, the reference's own tags and quantities.
  (peb-comp-layer "STAIR-TEXT" 7)
  (setvar "CLAYER" "STAIR-TEXT")
  (peb-stair-note-r (+ ox (* u 4.4)) (+ yb0 (/ wdt 2.0)) (+ ox (* u 5.4)) th "SBP-01 (QTY-02)")
  (peb-stair-note-r xL (- yb1 (/ (peb-stair-col-bf) 2.0)) (+ xL (* u 2.0)) th "CBP-01 (QTY-04)")

  ;; --- DIMENSIONS, in the reference's words.  It writes the measured value then what the
  ;; measurement is between - "6318 C/C OF STEEL LINE" - so we build the label the same way.
  ;; -- SPACED IN TEXT HEIGHTS (rule 4B.27), and the vertical dim pushed clear ------------
  ;; The long "C/C OF STEEL COLUMN TO BASE PLATE OF STRINGER" row ran at 4.2u under the plan
  ;; while the vertical O/O dim stood 3.2u to its left: once the lettering grew, the rotated
  ;; text and the horizontal label crossed each other.  Both are now measured off the text.
  (peb-stair-dim (- xa (/ (peb-stair-col-d) 2.0)) (+ xL (/ (peb-stair-col-d) 2.0))
                 (+ yb1 (* th 1.9)) th
                 "O/O OF STEEL COLUMN")
  (peb-stair-dim xa xL (+ yb1 (* th 3.8)) th
                 "C/C OF STEEL COLUMN")
  (peb-stair-dim (+ ox (* u 3.0)) xL (- yb0 (* th 2.6)) th
                 "C/C OF STEEL COLUMN TO BASE PLATE OF STRINGER")
  (peb-stair-vdim (- xa (* th 2.4)) yb0 yb1 th
                  "O/O OF STEEL COLUMN")

  (setq y (- yb0 (* th 4.8)))
  (txt-bold "MC" (list (/ (+ xa xL) 2.0) y)
            (/ (* th 1.25) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0
            "STEEL COLUMN & STRINGER BASE PLATE LAYOUT PLAN")
  (if lbl
    (txt-bold "MC" (list (/ (+ xa xL) 2.0) (- y (* th 1.7)))
              (/ (* th 1.05) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 lbl))
  (list xa xL (- y (* th 2.0)) (+ yb1 (* th 4.6))))


;; ============================================================================
;; TYPICAL STEP SECTION DETAIL
;; ----------------------------------------------------------------------------
;; 055-MSPL carries this as "Typical Detail of Steel Checkered Plate Step", and its dimensions
;; survived into the harvest: going 280, developed 286, nosing 25, plate 6.
;;
;; TAKE THE FORM FROM THE REFERENCE AND THE NUMBERS FROM OURSELVES.  The house standard is a 300
;; going on a 150 riser (owner, 1-Sep) and it outranks the 280/185 measured off one job - so the
;; detail is dimensioned from peb-stair-going / peb-stair-rise, which is also what stops it ever
;; drifting from the stair drawn beside it on the same sheet.
;;
;; WHAT IT SHOWS (owner chose tread + stringer + cleat): three steps in section, the checkered
;; plate tread carried on angle cleats welded to the stringer channel, going and riser
;; dimensioned, the nosing dimensioned, and the plate called out in the reference's own words.
;;
;; PARTS ARE NAMED, NOT SIZED.  PD is blind by default and a section size is designed-steel
;; information; the detail says STRINGER and TREAD CLEAT, and the sizes belong on the approval
;; drawing.  The plate THICKNESS is not a section size - it is what the customer is buying - so
;; it is stated.
(defun peb-stair-stepdetail (ox oy wdt hgt lbl / u th g r nos cl x y i x0 y0)
  (setq u   (max 60.0 (/ wdt 12.0))
        th  (* u 1.4)
        g   (peb-stair-going)
        r   (peb-stair-rise hgt)
        nos 25.0                                  ; nosing, off the reference
        cl  50.0                                  ; L-50 cleat leg
        x0  ox
        y0  oy)

  ;; --- THREE STEPS: the tread plate, its nosing, and the riser face behind it.
  (peb-comp-layer "STAIR-TREAD" 7)
  (setq i 0)
  (while (< i 3)
    (setq x (+ x0 (* i g)) y (+ y0 (* i r)))
    ;; the checkered plate tread, 6 mm thick, oversailing the step below by the nosing
    (peb-comp-poly (list (list (- x nos) y)
                         (list (+ x g) y)
                         (list (+ x g) (+ y 6.0))
                         (list (- x nos) (+ y 6.0))))
    ;; the angle cleat under it, welded to the stringer
    (peb-comp-layer "STAIR-STRINGER" 1)
    (peb-comp-poly (list (list x (- y cl)) (list (+ x 6.0) (- y cl))
                         (list (+ x 6.0) y) (list x y)))
    (peb-comp-poly (list (list x (- y 6.0)) (list (+ x cl) (- y 6.0))
                         (list (+ x cl) y) (list x y)))
    (peb-comp-layer "STAIR-TREAD" 7)
    (setq i (1+ i)))

  ;; --- THE STRINGER: the sloping channel the cleats are welded to, behind the steps.
  (peb-comp-layer "STAIR-STRINGER" 1)
  (peb-stair-slab (- x0 (* g 0.4)) (- y0 (* r 0.4))
                  (+ x0 (* g 3.0)) (+ y0 (* r 3.0)) (peb-stair-stringer-d))

  ;; --- DIMENSIONS: the two numbers that define every step, plus the nosing.
  (peb-comp-layer "STAIR-TEXT" 7)
  ;; -- THIS DETAIL EXISTS TO BE READ (owner 3-Sep-2026: "make this text more visible") ---
  ;; It is the one view drawn at a scale that can show what a step actually is, and its five
  ;; labels were placed 1.6u to 3u apart with text 2.2u tall - GOING sat on NOSING, and TREAD
  ;; CLEAT sat on STRINGER.  Every offset here is now a multiple of the text height, so the
  ;; labels keep their clearance whatever the lettering is set to (rule 4B.27).
  (peb-stair-dim (+ x0 g) (+ x0 (* 2.0 g)) (+ y0 (* 3.0 r) (* th 2.4)) th
                 "GOING")
  (peb-stair-vdim (- x0 (* th 1.8)) (+ y0 r) (+ y0 (* 2.0 r)) th
                  "RISER")
  (peb-stair-dim (- (+ x0 (* 2.0 g)) nos) (+ x0 (* 2.0 g)) (+ y0 (* 2.0 r) (* th 0.9)) th
                 "NOSING")

  ;; --- NAMES.  The reference's own wording for the plate; generic names for the steel.
  (peb-stair-note-r (+ x0 (* 3.0 g)) (+ y0 (* 3.0 r)) (+ x0 (* 3.0 g) (* th 1.0)) th
                    "STEEL CHECKERED PLATE, THICKNESS 6mm")
  (peb-stair-note (+ x0 (* 1.5 g)) (+ y0 (* 1.5 r) (- cl)) (- y0 (* th 2.2)) th "TREAD CLEAT")
  (peb-stair-note (+ x0 (* 0.3 g)) (- y0 (* r 0.2)) (- y0 (* th 3.7)) th "STRINGER")

  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "MC" (list (+ x0 (* 1.5 g)) (- y0 (* th 6.4)))
            (/ (* th 1.2) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0
            "TYPICAL DETAIL OF STEEL CHECKERED PLATE STEP")
  (if lbl
    (txt-bold "MC" (list (+ x0 (* 1.5 g)) (- y0 (* th 8.1)))
              (/ (* th 1.0) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 lbl))
  (princ))

(defun peb-stair-loadnote (ox oy wdt usage mzlive / u th L y ln)
  (setq u  (max 60.0 (/ wdt 12.0))
        th (* u 1.4)
        L  (peb-stair-loads usage)
        y  oy)
  (peb-comp-layer "STAIR-TEXT" 7)
  (setvar "CLAYER" "STAIR-TEXT")
  (txt-bold "ML" (list ox y) (/ (* th 1.3) (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0
            "DESIGN LOADS - STAIRCASE")
  (setq y (- y (* th 1.9)))
  (foreach ln
    (list (strcat "OCCUPANCY : " (nth 3 L))
          (strcat "LIVE LOAD (VERTICAL) : " (nth 0 L) " kN/m2 UDL, " (nth 1 L) " kN CONCENTRATED")
          (strcat "HANDRAIL (HORIZONTAL) : " (nth 2 L) " kN/m LINE LOAD AT TOP OF RAIL")
          (if (and mzlive (/= mzlive "") (/= mzlive "0"))
            (strcat "MEZZANINE LIVE LOAD (FROM BSF) : " mzlive " kN/m2")
            "MEZZANINE LIVE LOAD : NOT STATED ON THE BSF")
          ;; NEVER WRITE THE COMPETITOR'S NAME ON A MAIMAAR DRAWING (owner, standing rule,
          ;; restated 1-Sep-2026: "remove the word mammut form the drawing").  This was the ONLY
          ;; drawn string in the whole engine that broke it - everything else that greps is a
          ;; comment or the function name peb-titleblock-mammut, neither of which reaches paper.
          ;; BS 6399 IS the standard; the manual was only where I read it, and that provenance
          ;; belongs in PD_RULEBOOK.md, not on the customer's sheet.
          "REFERENCE : BS 6399 - LIVE LOADS, TABLE 4.10")
    (txt-bold "ML" (list ox y) (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0 ln)
    (setq y (- y (* th 1.5))))
  ;; Never let an assumption pass as a stated fact.
  (if (nth 4 L)
    (progn
      (txt-bold "ML" (list ox y) (/ th (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0
                "NOTE : BUILDING USE NOT STATED ON THE BSF - FOOT-TRAFFIC VALUES ASSUMED.")
      (setq y (- y (* th 1.5)))))
  y)

;; How far ABOVE its own origin does a shape reach?  Spacing that only counts the stair just
;; drawn is not enough: an L climbs in +y, so it grows UPWARDS into whatever was placed before
;; it.  That is why ST3 and ST4 collided - the gap after the U was ample, and the L reached back
;; up through it.  Advance for the stair about to be drawn, not just the one behind you.
;; The gap between a PLAN and the ELEVATION of the same stair: clear of the plan's own notes
;; below it, plus the elevation's full rise, since the elevation grows UP from its baseline.
;; The elevation's OWN notes sit above its full rise (hgt + handrail + 6.4u), and the plan's
;; captions hang ~12u below the plan.  Sum both or the two views letter over each other - the
;; first render printed "STRINGERSTRINGER" where the plan's note met the elevation's.
;; How many PLAN BLOCKS a U needs: flights in pairs, one pair per storey.  Two flights - the
;; ordinary mezzanine stair - is one block, so nothing about the normal sheet moves.
(defun peb-stair-plan-u-blocks (hgt)
  (fix (/ (+ (length (peb-stair-flights hgt)) 1) 2)))

;; The distance the plan reaches DOWN from its origin, which is what the elevation has to clear.
;; A multi-block U grows downward one pitch per extra block; forgetting that lands the elevation
;; on top of the second plan.
;; THE BLOCK PITCH, DEFINED ONCE.  It was written out in two places - here and in
;; peb-stair-plan-u - and the moment I widened one to clear a caption collision the other still
;; said dep+15u, so the elevation was placed 11u per block too high and printed through the
;; plan captions.  Exactly the fault this module keeps producing: one fact, two copies.
(defun peb-stair-plan-u-pitch (wdt / u)
  (setq u (max 60.0 (/ wdt 12.0)))
  (+ wdt wdt (peb-stair-well wdt) (* u 26.0)))

(defun peb-stair-plan-u-drop (hgt wdt)
  (* (1- (peb-stair-plan-u-blocks hgt)) (peb-stair-plan-u-pitch wdt)))

(defun peb-stair-elev-drop (shp hgt wdt / u)
  (setq u (max 60.0 (/ wdt 12.0)))
  (+ hgt 900.0 (* u (if (= shp "L") 20.0 26.0))
     (if (= shp "U") (peb-stair-plan-u-drop hgt wdt) 0.0)))

;; How far the plan reaches UP from its origin, which is what the driver must clear BEFORE
;; drawing it.  Only the L grows in +y (its second flight climbs the page).
;;
;; THIS FUNCTION WAS THE LAST PLACE THAT SPLIT THE RISERS ITSELF.  It read
;;   run2 = going * (nris - (fix (/ nris 2.0)))
;; which is the very fault the comments above peb-stair-plan-l record as removed: it assumed
;; TWO flights, and on an odd riser count it gave the remainder to the second flight where
;; peb-stair-flights gives it to the lowest.  A tall L therefore reserved space for a stair
;; shorter than the one drawn, and climbed into whatever was drawn above it - the collision this
;; function exists to prevent.  It now reads the one list and sums the real block heights, so it
;; is correct for any number of landings by construction.
(defun peb-stair-headroom (shp hgt wdt / u fl nf lw going tall b f2)
  (setq u     (max 60.0 (/ wdt 12.0))
        fl    (peb-stair-flights hgt)
        nf    (length fl)
        going (peb-stair-going)
        lw    (max 900.0 wdt))
  (if (/= shp "L")
    (* u 12.0)
    (progn
      ;; every L block reaches up by its own second flight; blocks stack downward, so the
      ;; clearance needed above is the TALLEST block, not the sum.
      (setq tall 0.0 b 0)
      (while (< b (fix (/ (+ nf 1) 2)))
        (setq f2   (if (< (+ (* 2 b) 1) nf) (nth (+ (* 2 b) 1) fl) 0)
              tall (max tall (* going f2))
              b    (1+ b)))
      (+ wdt tall lw (* u 6.0)))))

(defun peb-draw-stair-sheet (data / i tag wdt hgt topl midl typ oy lbl trd pfl shp
                                    usage mzlive hrail drawn ext nland err)
  (if (= (strcase (MSPL-Get-Str data "ST_TOGGLE")) "YES")
    (progn
      (setq usage  (MSPL-Get-Str data "USAGE")
            mzlive (MSPL-Get-Str data "MZ_LIVE_LOAD")
            drawn  nil
            i 1 oy 0.0)
      (while (<= i 4)
        (setq tag (strcat "ST" (itoa i) "_"))
        ;; ONE STAIRCASE PER SHEET.  Four stairs, each with a plan AND an elevation, forced the
        ;; sheet to 1:487 - every label a smudge.  The manual does not stack them either: each
        ;; type gets its own sheet ("3 of 13", "4 of 13" ...).  *PEB-STAIR-ONLY* selects one; if
        ;; nothing selects, the sheet falls back to drawing them all, which is right for a job
        ;; with a single stair.
        (if (and (or (null *PEB-STAIR-ONLY*) (= *PEB-STAIR-ONLY* i))
                 (= (strcase (MSPL-Get-Str data (strcat tag "TOGGLE"))) "YES"))
          ;; One bad stair must never take the sheet down with it - BUT IT MUST NOT FAIL
          ;; SILENTLY EITHER.  This catch once swallowed an unbound variable in the plan drawer
          ;; and produced a 43-entity sheet: no error, no message, just most of the drawing
          ;; missing.  The only tell was the entity count in the dump, and only because I
          ;; happened to look.  A caught error is now reported to the command line AND stamped
          ;; on the sheet, so a broken staircase announces itself instead of quietly shrinking.
          (progn
          (setq err
            (vl-catch-all-apply
            (function
              (lambda ()
                (setq wdt  (MSPL-Get-Num data (strcat tag "WIDTH"))
                      hgt  (MSPL-Get-Num data (strcat tag "HEIGHT"))
                      typ  (MSPL-Get-Str data (strcat tag "TYPE"))
                      topl (= (MSPL-Get-Str data (strcat tag "TOP_LANDING")) "1")
                      midl (= (MSPL-Get-Str data (strcat tag "MID_LANDING")) "1")
                      trd  (MSPL-Get-Str data (strcat tag "TREAD"))
                      pfl  (MSPL-Get-Str data (strcat tag "PLAT_FLOOR")))
                (if (or (null wdt) (<= wdt 0.0)) (setq wdt 1200.0))
                (if (or (null hgt) (<= hgt 0.0)) (setq hgt 3000.0))
                ;; THE TITLE NAMES WHAT ACTUALLY VARIES: the number of INTERMEDIATE landings.
                ;; It used to read "STAIRCASE WITH TOP-MID LANDING", which counts two landings
                ;; one of which is no longer a platform at all - the top one IS the mezzanine
                ;; floor (owner, 1-Sep-2026).  The intermediate count is what changes from job
                ;; to job, what the whole landing rule is about, and what the reader needs.
                ;; It is derived, like everything else, from the one flight list.
                (setq nland (1- (length (peb-stair-flights hgt))))
                (setq lbl (strcat "STAIR ST" (itoa i)
                                  (if (and typ (/= typ "")) (strcat " - " (strcase typ)) "")
                                  " STAIRCASE WITH " (itoa nland) " INTERMEDIATE LANDING"
                                  (if (= nland 1) "" "S")))
                ;; THE SHAPE IS THE DRAWING - dispatch on ST<n>_TYPE, never just caption it.
                (setq shp (peb-stair-shape typ midl))
                ;; Make room for what this shape reaches UP into, before drawing it.
                (setq oy (- oy (peb-stair-headroom shp hgt wdt)))
                ;; A COND over every shape, not an IF over one.  The first version branched on
                ;; "U" only, so L-Shape silently fell through to the straight drawer and printed
                ;; a straight stair captioned "L-SHAPE" - the very fault this dispatch exists to
                ;; prevent, reintroduced by handling one case instead of all of them.
                ;; PLAN on top, ELEVATION beneath it, type caption under both - the manual's
                ;; own sheet layout.  The plan is passed nil for the title so the pair is
                ;; captioned once, under the elevation, instead of twice.
                (setq ext
                  (cond
                    ((= shp "U")
                     (peb-stair-plan-u 0.0 oy wdt hgt topl midl nil trd pfl))
                    ((= shp "L")
                     (peb-stair-plan-l 0.0 oy wdt hgt topl midl nil trd pfl))
                    (T
                     (peb-stair-plan   0.0 oy wdt hgt topl midl nil trd pfl))))
                ;; THE A-A CUT GOES THROUGH THE LANDING, because that is where the section is
                ;; taken.  It used to sit a quarter along flight 1, which is a cut line that does
                ;; not match its own section - worse than no cut line at all.  The landing is at
                ;; the far end of the first flight: one flight run from the start.
                (if ext
                  (peb-stair-cutline (+ (nth 0 ext)
                                        (* (peb-stair-going) (nth 0 (peb-stair-flights hgt)))
                                        (* 0.5 (max 900.0 wdt)))
                                     (nth 2 ext) (nth 3 ext)
                                     (max 60.0 (/ wdt 12.0)) (* (max 60.0 (/ wdt 12.0)) 1.6)))
                ;; Drop clear of the plan and its notes, then the elevation of the SAME stair.
                (setq oy (- oy (peb-stair-elev-drop shp hgt wdt)))
                (peb-stair-elev 0.0 oy wdt hgt topl midl lbl trd shp)
                ;; SECTION A-A BESIDE the plan, not beneath everything.  The section is tall
                ;; and narrow while the plan and elevation are long and low, so stacking all
                ;; three down one A4 is what drove the sheet to 1:139.  Putting the section in
                ;; the space to the right of the views uses the page instead of fighting it.
                (peb-stair-section (+ (nth 1 ext) (* wdt 5.5)) (+ oy (* wdt 1.5))
                                   wdt hgt lbl trd pfl)
                ;; THE RIGHT-HAND COLUMN OF THE SHEET, AND WHY IT IS PACKED THIS WAY.
                ;;
                ;; Adding two views costs scale, and the sheet pays for empty space.  Laid out in
                ;; a row - section, then layout plan, then step detail, each a few widths further
                ;; right - the extents went from 19.7 m to 32.8 m and the plot fell from 1:96 to
                ;; 1:119.  A fifth of the drawing's legibility for nothing.
                ;;
                ;; So the right-hand space is filled in BOTH directions: the layout plan sits
                ;; beside the section, because it is long and low like the plan it explains, and
                ;; the step detail tucks UNDER the section, because it is small and the space
                ;; below a tall narrow section is otherwise wasted.  Same three views, ~1:98.
                (peb-stair-collayout (+ (nth 1 ext) (* wdt 10.0)) (+ oy (* wdt 1.5))
                                     wdt hgt nil)
                ;; TYPICAL STEP DETAIL - the one thing the plan and elevation draw at a scale too
                ;; coarse to show: what a step actually is.
                (peb-stair-stepdetail (+ (nth 1 ext) (* wdt 5.5)) (- oy (* wdt 6.0)) wdt hgt nil)
                ;; SPEC + LOADS, both read off the BSF.  Drawn once, under the elevation.
                (setq hrail (MSPL-Get-Str data (strcat tag "HANDRAILS")))
                ;; Close under the elevation.  Parking the notes 13 widths down stretched the
                ;; sheet extents and forced the scale to 1:165 - the drawing pays for empty space.
                (setq oy (peb-stair-specnote 0.0 (- oy (* wdt 3.0)) wdt
                                             typ wdt hgt trd pfl hrail
                                             (MSPL-Get-Str data (strcat tag "IN_MEZZ"))))
                ;; loads beside the specification, not under it - two short columns read
                ;; faster than one long one and cost the sheet no height.
                ;; REMOVED 2-Sep-2026: design loads now appear in title bar, detailed note removed
                ;; (peb-stair-loadnote (* wdt 7.0) oy wdt usage mzlive)
                ;; The six-line rule note that stood here is GONE (owner 3-Sep-2026: "this text
                ;; to be shortened - only main information").  It recited the internal step-count
                ;; standard and the IBC clause onto a customer sheet, and ran through the step
                ;; detail's caption doing it.  Its figures are in the specification block above;
                ;; its reasoning is in PD_RULEBOOK.md, which is where reasoning belongs.
                (setq drawn T)
                ;; clearance below the ELEVATION (its dims and caption hang under y=oy)
                (setq oy (- oy (* wdt 14.0)))
                (princ)))))
          (if (vl-catch-all-error-p err)
            (progn
              (princ (strcat "PEB-STAIR: ST" (itoa i) " FAILED - "
                             (vl-catch-all-error-message err)))
              (peb-comp-layer "STAIR-TEXT" 7)
              (setvar "CLAYER" "STAIR-TEXT")
              (txt-bold "ML" (list 0.0 (- oy (* (if (and wdt (> wdt 0.0)) wdt 1200.0) 2.0)))
                        (/ 240.0 (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)) 0.0
                        (strcat "*** STAIRCASE ST" (itoa i)
                                " COULD NOT BE DRAWN: " (vl-catch-all-error-message err)
                                " - THIS SHEET IS INCOMPLETE ***"))))))
        (setq i (1+ i)))))
  (setvar "CLAYER" "0")
  (princ))

(if (not (boundp '*PEB-STAIR-ONLY*)) (setq *PEB-STAIR-ONLY* nil))

(defun C:PEB-STAIR ( / data)
  (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*)
    (progn (setq data (MSPL-Read-Data *PEB-DATA-FILE*))
           (if data (peb-draw-stair-sheet data))))
  (princ))

;; `stairNo` selects WHICH staircase this sheet draws (1-4).  nil or 0 keeps the historic
;; draw-them-all fallback, which is right for a job with a single stair.
;;
;; peb-draw-stair-sheet has honoured *PEB-STAIR-ONLY* since it was written - "ONE STAIRCASE PER
;; SHEET ... four stairs, each with a plan AND an elevation, forced the sheet to 1:487, every
;; label a smudge" - but nothing ever set it.  So 279-26's two stairs stacked onto one sheet at
;; 1:289 and the owner could not read it: "staircase detail page is not so visible".  The
;; renderer now asks for one sheet per staircase and this is where the ask arrives.
(defun peb-stair-from-file (path stairNo / prev-last prev-max-x)
  (setq *PEB-STAIR-ONLY* (if (and stairNo (numberp stairNo) (> stairNo 0)) stairNo nil))
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  (setq *PEB-SHEET-MARK* prev-last)
  (if prev-last
    (progn (command "_.REGEN") (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-STAIR)
  (setq *PEB-DATA-FILE* nil)
  (setq *PEB-STAIR-ONLY* nil)          ; never leak the selection into the next sheet
  (if (boundp 'peb-tile-place)
    (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x)))))
  (princ))
(princ)
