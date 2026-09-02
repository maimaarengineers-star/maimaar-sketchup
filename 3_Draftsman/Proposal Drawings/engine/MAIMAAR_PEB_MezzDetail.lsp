;; ============================================================================
;;  MAIMAAR_PEB_MezzDetail.lsp
;;  MEZZANINE FLOOR SECTION  -  a PROPOSAL sheet, drawn from the IF / BSF
;;
;;  ---------------------------------------------------------------------------
;;  STANDALONE DEVELOPMENT FILE (owner, 1-Sep-2026)
;;  ---------------------------------------------------------------------------
;;  "Keep it separate because other files are being edited by other terminals.
;;   Once we developed then we will copy there and will delete this separate file."
;;
;;  So this file touches NOTHING else.  It edits no engine file, adds no layer to
;;  PEB_LAYERS.csv or _PEB_LAYERS_generated.lsp, and defines no name that already
;;  exists anywhere in the engine.  Everything private is prefixed  mzd-  and the
;;  layers it needs are created on demand with the SAME names/colours/weights the
;;  generated standard already carries, so lifting this file into
;;  MAIMAAR_PEB_Framing.lsp later is a copy, not a merge.
;;
;;  Only THREE public names are exported, all new:
;;      peb-draw-mezz-detail        (data ox oy)   - the drawer
;;      C:PEB-MEZZ-DETAIL                          - the command
;;      peb-mezz-detail-from-file   (path)         - the pipeline entry point
;;
;;  ---------------------------------------------------------------------------
;;  WHAT THIS SHEET IS  -  owner, 1-Sep
;;  ---------------------------------------------------------------------------
;;  "Make the beautiful presentation - no need to show much details.  Just for
;;   idea, we have to show the mezzanine section based on BSF/IF Data."
;;
;;  That settles the sheet's job, and it is NOT a shop drawing.  A customer
;;  reading a proposal needs to see WHAT a mezzanine is on their building - a
;;  floor carried on columns and beams, at the levels their own BSF states - not
;;  how a joist is bolted to a beam.  So the sheet carries:
;;
;;      VIEW A  MEZZANINE FLOOR SECTION - the idea.  Columns off the floor slab,
;;              main beam spanning them, joists on the beam, the floor over.
;;              Levels and spans dimensioned, and every one of them the BSF's.
;;      VIEW B  FLOOR BUILD-UP, enlarged - the one close-up worth keeping, since
;;              the decking sheet is the thing a customer cannot picture.
;;      DATA    the IF / BSF values, stated plainly, so the drawing and the offer
;;              can be checked against each other in one glance.
;;      NOTES   three lines, not eight.
;;
;;  DELIBERATELY REMOVED from the earlier version, as "much details": the clip
;;  angle and its bolts, the rebar dots, the joist-to-beam connection view, the
;;  secondary-joist case, and five of the eight notes.  A connection detail is an
;;  APPROVAL-drawing item; putting one on a proposal sheet invites the customer to
;;  treat it as fabrication information, which rule 4B.7's whole family exists to
;;  prevent.  The code for the true corrugation is kept - VIEW B needs it.
;;
;;  ---------------------------------------------------------------------------
;;  PROVENANCE  -  RULE 4B.43, UNPARKED
;;  ---------------------------------------------------------------------------
;;  Owner, 29-Aug: "Mezzanine Floor Detail is not the one we developed last time."
;;  Owner,  1-Sep: "I think we already built the mezzanine details showing the
;;                  joists, main beams, decking panel view and RCC Concrete."
;;
;;  Both true.  The build-up HAD been developed - 15-Jul, commit 945c6d9, as
;;  `draw-fr-detail` in MAIMAAR_PEB_Section.lsp ("DETAIL - A / JOIST CONNECTION"),
;;  wired to the FLAT-ROOF path only (Section.lsp:9551, 10288).  Render on file:
;;  _render\typeplans\a_detail.png.  The mezzanine instead got `peb-sd-mezz-floor`
;;  (Framing.lsp:3102), a SECOND reconstruction - which is why the owner rejected
;;  it and why 4B.43 was PARKED (`mzOnSd nil`) pending "the real geometry".
;;  VIEW B here is that geometry, carried over and simplified to proposal level.
;;
;;  ---------------------------------------------------------------------------
;;  EVERY NUMBER ON THIS SHEET IS THE BSF's  (rules 4B.7 . 4B.32 . 4B.49)
;;  ---------------------------------------------------------------------------
;;  FLOOR THICKNESS   MZ<n>_FLOOR_THK  - owner 1-Sep: "thickness of Floor will be
;;                    same as will be mentioned in IF/BSF".  Read, never assumed,
;;                    and STATED THREE TIMES off that one field: VIEW A's floor
;;                    callout, VIEW B's slab ladder, and the DATA panel.
;;  F.F.L / CLEAR HT  MZ<n>_CH_FFL_SLAB / MZ<n>_CH_FFL_BEAM
;;  main beam depth   FFL - beam soffit - build-up   (4B.7 - the SAME derivation
;;                    peb-draw-mezz-section uses, so the detail, the section and
;;                    the Mezzanine Floor Plan cannot disagree about one floor)
;;  column spacing    MZ_COL_SPACING   (first module of the estimator's chain)
;;  joist spacing     MZ_JOIST         (the cross section still hard-codes 1500)
;;  floor system      MZ<n>_FLOOR / MZ<n>_FLOOR_MAT - deck+slab . grating or
;;                    chequered plate . precast/hollow-core (beams only, no joists)
;;  loads             MZ<n>_DL / _LL / _CL
;;  Joist tops are FLUSH with the main beam top flange - rule 4B.32.
;;
;;  ---------------------------------------------------------------------------
;;  LABELS ARE M-LADDERS, AND TEXT OBEYS THE LADDER (owner 1-Sep)
;;  ---------------------------------------------------------------------------
;;  MEASURED OFF THE REFERENCE SHEET, not off memory:
;;  _render\Section_Final_Clear_Span_Gable.pdf.  There, COLUMN / GIRT / DOWN
;;  PIPE are HORIZONTAL leaders - text left-aligned on ONE landing line, running
;;  straight across to a FILLED solid arrowhead at the member, each label at ITS
;;  OWN member's height.  No vertical rail, no stacked levels, no long legs.
;;
;;  That is the convention `mzd-callouts` implements.  An earlier version here
;;  stacked every label above the slab and dropped a long riser to the member -
;;  which is the owner's standing complaint about the roof labels ("no long
;;  M-Ladder legs") and why the landings did not match the rest of the set.
;;  A label leaves its member's own height ONLY when a neighbour is inside one
;;  text height, and then by the least that clears it, with a jog capped at one
;;  text height.  Each view owns its landing lane; the lane is measured from the
;;  labels themselves.
;;
;;  TEXT (rules 4B.9 / 4B.27):
;;    * every height comes from *PEB-TEXT-HEIGHTS* via `mzd-th` - zero hard-coded.
;;      (`rm-mladder` passes a raw 150 to txt-rom; that one thing is NOT copied,
;;      because 4B.9 forbids it.)
;;    * bold is a heavier PEN on romand (CELWEIGHT 30), not another font.
;;    * EVERY clearance is computed FROM the plotted text height (`mzd-h`) - the
;;      fault 4B.27 calls "the one that keeps biting".
;;    * the sheet heading is CAPPED against the width it titles (4B.17).
;;    * *PEB-TEXT-SCALE* = this sheet's own face width / 45000 (4B.9 / 4B.16).
;;
;;  AUDITED (1-Sep, on the rendered DXF): 0 text collisions, one text style
;;  (ROMAND) throughout, every text height on a ladder rung, nothing on layer 0.
;; ============================================================================

(vl-load-com)

;; ---------------------------------------------------------------------------
;;  TUNABLES - drawn sizes that are NOT stated by the BSF.  All in one place so
;;  the owner can move any of them without reading the code.
;; ---------------------------------------------------------------------------
(setq *MZD-DECK-RIB*    45.0)    ; profiled deck rib DEPTH  (mm)
(setq *MZD-DECK-PITCH* 200.0)    ; rib PITCH, crest to crest
(setq *MZD-DECK-FLAT*   80.0)    ; flat of the trough / crest (slopes take the rest)
(setq *MZD-DECK-GAUGE*   0.70)   ; the TRUE gauge - stated in the label
(setq *MZD-DECK-DRAWT*  10.0)    ; the gauge as DRAWN: 0.70 mm cannot read as two
                                 ; skins at any sheet scale (rule 4B.31)
(setq *MZD-BEAM-FLANGE* 350.0)   ; main beam flange width
(setq *MZD-BEAM-TF*      25.0)   ; main beam flange thickness
(setq *MZD-BEAM-WEB*     16.0)   ; main beam web thickness
(setq *MZD-JOIST-FLANGE* 175.0)  ; joist flange width
(setq *MZD-JOIST-TF*      14.0)  ; joist flange thickness
(setq *MZD-JOIST-WEB*     10.0)  ; joist web thickness
(setq *MZD-JOIST-RATIO*    0.55) ; joist depth as a fraction of the beam depth
(setq *MZD-COL-WIDTH*   300.0)   ; mezzanine column, as the cross section draws it
(setq *MZD-PLANK-DEPTH* 200.0)   ; precast / hollow-core plank depth
(setq *MZD-PLATE-DRAWT*  12.0)   ; chequered plate / grating, as drawn
(setq *MZD-CONC-SCALE*   10.0)   ; AR-CONC pattern scale at true size
;; column bays in VIEW A is now DERIVED from the module (mzd-geom "BAYS"):
;; a 15,240 module shows one bay, a tight one shows two.  Nothing reads this.
(setq *MZD-DIM-DUAL*      T)     ; standing rule 3: dimensions read mm [ft-in]
(setq *MZD-LEG*           5.0)   ; M-Ladder VERTICAL LEG, in text heights (owner
                                 ; 1-Sep: "increase the vertical legs").  It is
                                 ; the L's upright, so it has to read AS a leg -
                                 ; at 1.1 the callouts looked like plain
                                 ; horizontal leaders.  Paired with SHORT bars:
                                 ; the tips sit near the landing, so the L reads
                                 ; as a tall upright and a short arm, not as a
                                 ; long rule across the drawing.
(setq *MZD-TS*            1.0)   ; sheet text scale - computed, do not set by hand

;; ---------------------------------------------------------------------------
;;  DATA - a private reader, so this file runs whether or not Plan/Section is
;;  loaded.  Same KEY=VALUE shape their v3 reader parses.
;; ---------------------------------------------------------------------------
(defun mzd-read-data (path / f line s alist pos k v)
  (setq alist '() f (open path "r"))
  (if (null f)
    (progn (princ (strcat "\nMZD: cannot open " path)) nil)
    (progn
      (while (setq line (read-line f))
        (setq s (vl-string-trim " \t\r" line))
        (cond
          ((= s "") nil)
          ((= (substr s 1 1) ";") nil)
          ((and (= (substr s 1 1) "[")
                (= (substr s (strlen s) 1) "]")) nil)
          (T (setq pos (vl-string-search "=" s))
             (if pos
               (progn
                 (setq k (vl-string-trim " " (substr s 1 pos))
                       v (vl-string-trim " " (substr s (+ pos 2))))
                 (setq alist (cons (cons k v) alist)))))))
      (close f)
      (reverse alist))))

;; ---- THIS SHEET READS THE FLOOR IT IS DRAWING  (3-Sep-2026) -------------------------------
;; Every field below is written MZ1_… because the sheet was built when a building had one
;; mezzanine.  The renderer asks for one details sheet PER FLOOR, so on a G+2 the second sheet
;; was detailing the first floor and calling it the second - two sheets, same numbers, one of
;; them wrong.  Re-pointing the KEY in the two readers rather than at the fifteen call sites
;; means a field added to this sheet later cannot forget to do it.
(defun mzd-floor-num ()
  (if (and (boundp '*PEB-MEZZ-FLOOR-NUM*) *PEB-MEZZ-FLOOR-NUM* (> *PEB-MEZZ-FLOOR-NUM* 1))
    *PEB-MEZZ-FLOOR-NUM*
    1))

(defun mzd-key (key)
  (if (and (> (mzd-floor-num) 1) (wcmatch key "MZ1_*"))
    (strcat "MZ" (itoa (mzd-floor-num)) "_" (substr key 5))
    key))

(defun mzd-str (data key / p)
  (setq p (assoc (mzd-key key) data))
  (if p (cdr p) ""))

(defun mzd-num (data key def / s v)
  (setq s (mzd-str data key))
  (if (= s "")
    def
    (progn (setq v (distof s 2))
           (if (and v (/= v 0.0)) v def))))

;; MZ_COL_SPACING is the estimator's module chain - "5@8331+1@8065", "2@5000".
;; VIEW A shows a REPRESENTATIVE bay, so it takes the FIRST module rather than
;; inventing a spacing of its own (rule 4B.49: what the drawing states, it owes).
(defun mzd-first-mod (s def / p i ch out)
  (setq p (vl-string-search "@" s))
  (if (null p)
    def
    (progn
      (setq out "" i (+ p 2))
      (while (and (<= i (strlen s))
                  (or (and (>= (ascii (substr s i 1)) 48)
                           (<= (ascii (substr s i 1)) 57))
                      (= (substr s i 1) ".")))
        (setq out (strcat out (substr s i 1)) i (1+ i)))
      (setq ch (distof out 2))
      (if (and ch (> ch 500.0)) ch def))))

;; ---------------------------------------------------------------------------
;;  LAYERS - created on demand, with the names/colours/weights the generated
;;  standard already carries.  Nothing is added to PEB_LAYERS.csv.
;; ---------------------------------------------------------------------------
;; USE THE ENGINE'S OWN LAYER MAKER  (3-Sep-2026).  peb-ensure-layer builds the record with
;; entmake and only falls back to the -LAYER command for a layer that already exists, which is
;; what every other sheet in the set goes through.  Driving -LAYER by hand here meant this sheet
;; had its own, unproven, prompt sequence - and a `command` that misses a prompt does NOT raise a
;; LISP error, so the vl-catch-all-apply around it caught nothing: the command simply stayed open
;; and swallowed everything after it.  The fallback is kept for a standalone load with no engine.
(defun mzd-layer (name col lt lw)
  (if (boundp 'peb-ensure-layer)
    (vl-catch-all-apply
      (function (lambda () (peb-ensure-layer name (atoi col) lt lw))))
    (vl-catch-all-apply
      (function (lambda ()
        (command "_.-LAYER" "_Make" name "_Color" col name
                            "_LType" lt name "_LWeight" (rtos lw 2 2) name "")))))
  (princ))

(defun mzd-layers ( / )
  ;; EVERY LAYER THIS FILE EVER MAKES CURRENT MUST BE IN THIS LIST.  `setvar
  ;; "CLAYER"` on a layer that does not exist ERRORS, and the error takes the
  ;; whole rest of the drawer with it - the block comes out as a few stray lines
  ;; with no message.  BOLTS was dropped from here when the bolts were taken off
  ;; the sheet, then the bolts came back and the layer did not: the detail lost
  ;; its deck, its concrete, its dimension and every label, and rendered eight
  ;; entities.  This is the same fault the engine hit on the curved eave panel.
  ;; The check is mechanical - compare this list against every CLAYER string in
  ;; the file - so it belongs in the render audit, not in anyone's memory.
  ;;
  ;; DASHED must exist before CELTYPE can select it - but LOAD IT ONLY IF IT IS NOT ALREADY
  ;; THERE.  peb-std-setup has loaded it by the time this runs, and -LINETYPE _Load on a linetype
  ;; that exists asks "Linetype DASHED is already loaded.  Reload it?" - a prompt this call has
  ;; no answer for.  The one "" it passes went to that question instead of ending the command,
  ;; so -LINETYPE STAYED OPEN and ate every following (command ...) as an option: seventeen
  ;; "Invalid option keyword" lines and then "; error: Function cancelled", with the whole
  ;; MEZZANINE SECTION DETAILS sheet lost.  Nothing about the message says linetype.
  ;; peb-std-ltype is the engine's own guarded loader and does exactly this test.
  (if (boundp 'peb-std-ltype)
    (vl-catch-all-apply (function (lambda () (peb-std-ltype "DASHED"))))
    (if (not (tblsearch "LTYPE" "DASHED"))
      (vl-catch-all-apply
        (function (lambda () (command "_.-LINETYPE" "_Load" "DASHED" "acad.lin" ""))))))
  (mzd-layer "COMP-MEZZ-BEAM"      "5" "Continuous" 0.50)
  (mzd-layer "COMP-MEZZ-JOIST"     "8" "Continuous" 0.25)
  (mzd-layer "CLADDING"            "5" "Continuous" 0.18)
  (mzd-layer "RCC-COLUMN"          "8" "Continuous" 0.35)
  (mzd-layer "GROUND"              "7" "Continuous" 0.50)
  (mzd-layer "GROUND-HATCH"        "8" "Continuous" 0.09)
  (mzd-layer "PLATES"              "1" "Continuous" 0.35)
  (mzd-layer "BOLTS"               "7" "Continuous" 0.09)
  (mzd-layer "ARROWS"              "3" "Continuous" 0.13)
  (mzd-layer "DIMENSIONS"          "6" "Continuous" 0.13)
  (mzd-layer "TEXT"                "7" "Continuous" 0.13)
  (princ))

;; ---------------------------------------------------------------------------
;;  TEXT - ROMAND everywhere (standing rule 1).  Rule 7 is the trap this avoids:
;;  an SHX \F override over a TrueType base style silently falls back to Arial, so
;;  the STYLE itself is made romand.shx rather than overridden inline.
;; ---------------------------------------------------------------------------
;; TEXT MUST BE THE SAME OBJECT THE REST OF THE SET DRAWS (owner 1-Sep: "text is
;; not matching what decided").  Checked against the accepted DETAILS sheet's own
;; DXF (details_v2.dxf), which settles it - a raster cannot, because the preview
;; renderer substitutes its own font for an SHX:
;;
;;      accepted sheet : Standard=romand.shx  PEB-BODY=romand.shx  PEB-TITLE=
;;                       romand.shx  PEB-DIM=romand.shx   ALL width 1.0,
;;                       and its text is drawn in PEB-BODY / PEB-TITLE.
;;      this sheet was : Standard=arial.ttf, one style named ROMAND at width 0.85,
;;                       everything drawn in it.
;;
;; Two faults.  The WIDTH FACTOR 0.85 made every string on this sheet narrower
;; than the same string anywhere else in the set.  And leaving `Standard` on
;; arial.ttf is the rule-7 trap itself: anything that ever falls back to the base
;; style silently becomes Arial, and an SHX \F override cannot rescue a TrueType
;; base.  So all four styles are forced to romand.shx at width 1.0, `Standard`
;; with them, FONTALT behind them, and the drawing uses PEB-BODY / PEB-TITLE /
;; PEB-DIM by name - the same styles the Cover, Plan and Section use.
;; USE THE ENGINE'S OWN STYLE MAKER  (3-Sep-2026) - same reasoning as mzd-layer above.
;; peb-std-textstyle builds the record and only falls back to the -STYLE command where it must,
;; and Standard.lsp's own note explains why hand-driving -STYLE is dangerous under acad /b: miss
;; one of the prompts a .shx font asks for and the command sits there waiting FOREVER.  It does
;; not error, so nothing catches it: the sheet stops mid-draw, the render script's remaining
;; lines are typed into the open prompt, and acad.exe runs until the pipeline's timeout kills
;; it - taking the whole page set, not just this sheet.  The fallback is kept for a standalone
;; load with no engine beside it.
(defun mzd-style1 (name)
  (if (boundp 'peb-std-textstyle)
    (vl-catch-all-apply
      (function (lambda () (peb-std-textstyle name "romand.shx"))))
    (vl-catch-all-apply
      (function (lambda ()
        (command "_.-STYLE" name "romand.shx" 0.0 1.0 0.0 "_N" "_N" "_N")))))
  (princ))

(defun mzd-style ( / n)
  (foreach n '("ROMAND" "PEB-BODY" "PEB-TITLE" "PEB-DIM" "Standard")
    (mzd-style1 n))
  (vl-catch-all-apply (function (lambda () (setvar "FONTALT" "romand.shx"))))
  (princ))

(defun mzd-th (sym / p)
  ;; rule 4B.9 - the ladder IS the standard.  The engine's own table when it is
  ;; loaded beside this file, else the same rungs literally.
  (if (and (boundp '*PEB-TEXT-HEIGHTS*) *PEB-TEXT-HEIGHTS*)
    (if (setq p (assoc sym *PEB-TEXT-HEIGHTS*)) (cdr p) 830)
    (cond ((eq sym 'MARK)     400)
          ((eq sym 'SMALL)    550)
          ((eq sym 'DIM)      700)
          ((eq sym 'ANNOT)    830)
          ((eq sym 'LABEL)    970)
          ((eq sym 'HEADING) 1400)
          ((eq sym 'TITLE)   1650)
          (T                  830))))

;; the ladder rung as PLOTTED in model units - 4B.27's clearance rule needs this,
;; not the paper number, because every gap on this sheet derives from it.
(defun mzd-h (sym) (* (mzd-th sym) *MZD-TS*))

;; PLOTTED WIDTH OF A STRING.
;;
;; The ratio was MEASURED, not assumed: 60 text spans lifted out of the reference
;; sheet (_render\Section_Final\1_Clear_Span_Gable.pdf) with their own font sizes
;; give romand a character width of  min 0.417 . median 0.594 . mean 0.588 .
;; max 0.678  of the text height.
;;
;; So the engine's own 0.62 (`peb-fit-txt-h`) is the honest average, and it is
;; kept for DIMENSION AUTOSIZE, where under-estimating only shrinks text a little.
;; LAYOUT is the opposite case - a column that under-estimates puts a label
;; through its own value, which is what "CLEAR HEIGHT UNDER BEAM" did on the
;; MSPL-26-279 sheet - so layout uses 0.75, clear of the measured maximum with
;; room for a string this sample did not contain.  Over-estimating a layout costs
;; white space; under-estimating costs a collision, so the asymmetry is bought
;; deliberately.
;;
;; (An earlier version of this file used 0.95 here, on a misreading of the
;; title-block fitter's constant.  0.95 is not a character width: it made the
;; data panel wider than the section it sat under and drove the sheet to 4.9:1.)
(defun mzd-tw (str h) (* 0.62 h (strlen str)))
;; 0.75 -> 0.90 (3-Sep-2026), MEASURED OFF THIS SHEET'S OWN PLOT.  The first sheet this module
;; ever produced put VIEW B across the end of the notes, and the arithmetic names the culprit:
;; the notes column was allotted 0.75 x height x 75 characters plus its gutter, and note 3 ran
;; to just about exactly that - so the true plotted character is ~0.85 of the height here, not
;; the 0.678 maximum the reference-sheet sample suggested.  A layout that under-estimates puts
;; a label through the thing beside it; one that over-estimates costs white space.  0.90 clears
;; the measurement with margin, and it is used by EVERY lane and column on this sheet, so the
;; correction lands everywhere the old number was quietly too small.
(defun mzd-tw-safe (str h) (* 0.90 h (strlen str)))

;; ---- DRAW TEXT THE WAY THE REST OF THE SET DRAWS IT  (3-Sep-2026) -------------------------
;; This module wrote its own TEXT call - (command "_.TEXT" "_J" just pt h rot str) - and it was
;; the one call in the engine that nothing else shared.  Under acad /b that sheet never once
;; got past its first view: the prompt sequence is not what this call assumed, and a `command`
;; that misses a prompt does not raise a LISP error, it just STAYS OPEN and swallows every
;; instruction after it as input.  VIEW A's title is the last text in the drawer, so there was
;; nothing after it to swallow, and acad sat at that prompt until the render timed out - taking
;; the whole page set with it, not just this sheet.
;;
;; The engine's own txt / txt-bold / txt-dim (MAIMAAR_PEB_Plan.lsp) are the proven form and are
;; used by every other sheet, so this now goes through them: one text path for the whole set,
;; and a fix there fixes here.  They take the ladder height BEFORE *PEB-TEXT-SCALE*, while this
;; sheet's mzd-h has already multiplied it in, so the scale is divided back out - the height
;; that reaches paper is unchanged.  The local form is kept as a fallback for a standalone load
;; with no engine beside it.
(defun mzd-tscale ( )
  (if (and *PEB-TEXT-SCALE* (> *PEB-TEXT-SCALE* 0.0)) *PEB-TEXT-SCALE* 1.0))

(defun mzd-txt (just pt h rot str)
  (if (boundp 'txt)
    (txt just pt (/ h (mzd-tscale)) rot str)
    (progn (setvar "TEXTSTYLE" "PEB-BODY")
           (command "TEXT" "J" just pt h rot str)))
  (princ))

(defun mzd-txt-d (just pt h rot str)
  (if (boundp 'txt-dim)
    (txt-dim just pt (/ h (mzd-tscale)) rot str)
    (progn (setvar "TEXTSTYLE" "PEB-DIM")
           (command "TEXT" "J" just pt h rot str)))
  (princ))

(defun mzd-txt-b (just pt h rot str)
  ;; rule 4B.27 (2): BOLD IS A HEAVIER PEN, not another font - romand.shx has no
  ;; bold cut.  txt-bold is that pen; the blue is this sheet's own title colour.
  (setvar "CECOLOR" "5")
  (if (boundp 'txt-bold)
    (txt-bold just pt (/ h (mzd-tscale)) rot str)
    (progn (setvar "CELWEIGHT" 30)
           (setvar "TEXTSTYLE" "PEB-TITLE")
           (command "TEXT" "J" just pt h rot str)
           (setvar "CELWEIGHT" -1)))
  (setvar "CECOLOR" "BYLAYER")
  (princ))

;; rule 4B.17 - a heading is CAPPED by the drawing it titles.
(defun mzd-head-h (str faceLen / cap h)
  (setq cap (mzd-h 'HEADING))
  (if (or (null faceLen) (<= faceLen 0.0) (= str ""))
    cap
    (progn
      (setq h (/ (* faceLen 0.34) (* 0.62 (max 1 (strlen str)))))
      (max (* cap 0.45) (min cap h)))))

;; ---------------------------------------------------------------------------
;;  DIMENSIONS - standing rule 2: arrowheads are the OPEN type, never the filled
;;  triangle.  Standing rule 3: mm and ft-in together.  Drawn as primitives, not
;;  as AutoCAD DIM entities, so a detail at its own scale cannot inherit the
;;  building sheet's DIMSCALE.  Arrow size derives from the DIM rung (4B.27).
;; ---------------------------------------------------------------------------
(defun mzd-mmft (mm / ti ft inch)
  (if (not *MZD-DIM-DUAL*)
    (rtos mm 2 0)
    (progn
      (setq ti (fix (+ 0.5 (/ mm 25.4))))
      (setq ft (/ ti 12) inch (- ti (* ft 12)))
      (strcat (rtos mm 2 0) " [" (itoa ft) "'-" (itoa inch) "\"]"))))

(defun mzd-asz ( ) (* (mzd-h 'DIM) 0.343))   ; the 240/700 the engine's dims use

(defun mzd-open-v (x y ux uy sz / px py)
  ;; an open V whose point is at (x y), opening along the unit vector (ux uy)
  (setq px (* uy sz 0.30) py (* ux sz -0.30))
  (command "_.LINE" (list x y)
                    (list (+ x (* ux sz) px) (+ y (* uy sz) py)) "")
  (command "_.LINE" (list x y)
                    (list (- (+ x (* ux sz)) px) (- (+ y (* uy sz)) py)) "")
  (princ))

(defun mzd-dim-v (x y0 y1 ox0 ox1 label / prev sz yl yh h)
  (setq prev (getvar "CLAYER") sz (mzd-asz))
  (setq yl (min y0 y1) yh (max y0 y1))
  (setvar "CLAYER" "DIMENSIONS")
  (command "_.LINE" (list ox0 yl) (list x yl) "")
  (command "_.LINE" (list ox1 yh) (list x yh) "")
  (command "_.LINE" (list x yl) (list x yh) "")
  (if (> (- yh yl) (* sz 2.2))
    (progn (mzd-open-v x yl 0.0  1.0 sz)
           (mzd-open-v x yh 0.0 -1.0 sz))
    (progn (mzd-open-v x yl 0.0 -1.0 sz)
           (mzd-open-v x yh 0.0  1.0 sz)))
  (setvar "CLAYER" "TEXT")
  ;; The text sits BESIDE a vertical dim, ROTATED with it - the house style for
  ;; vertical dims (4B.27 speaks of the section's "rotated 2-line texts").
  ;;
  ;; RULE 6 (DIM AUTOSIZE) APPLIES ON THIS AXIS TOO.  Rotating the text turns its
  ;; LENGTH into a vertical measurement, so a short run overruns its own arrows
  ;; and lands on whatever dimension sits above it - a 986 mm slab band carrying
  ;; a 2,646 mm rotated string, on the test job.  So: shrink to fit between the
  ;; arrows, and when even the floor size will not fit, place it OUTSIDE, beyond
  ;; the top arrow, which is what a real dimension style does with a short run.
  (setq h (mzd-h 'DIM))
  (if (> (mzd-tw label h) (- yh yl (* sz 2.0)))
    (setq h (max (* (mzd-h 'DIM) 0.45)
                 (/ (- yh yl (* sz 2.0)) (* 0.62 (max 1 (strlen label)))))))
  (if (> (mzd-tw label h) (- yh yl (* sz 2.0)))
    (mzd-txt-d "ML" (list (- x (* h 0.75)) (+ yh (* sz 0.8))) h 90 label)
    (mzd-txt-d "MC" (list (- x (* h 0.75)) (* 0.5 (+ yl yh))) h 90 label))
  (setvar "CLAYER" prev)
  (princ))

(defun mzd-dim-h (x0 x1 y oy0 oy1 label / prev sz xl xh h)
  (setq prev (getvar "CLAYER") sz (mzd-asz))
  (setq xl (min x0 x1) xh (max x0 x1))
  (setvar "CLAYER" "DIMENSIONS")
  (command "_.LINE" (list xl oy0) (list xl (- y (* sz 0.5))) "")
  (command "_.LINE" (list xh oy1) (list xh (- y (* sz 0.5))) "")
  (command "_.LINE" (list xl y) (list xh y) "")
  (if (> (- xh xl) (* sz 2.2))
    (progn (mzd-open-v xl y  1.0 0.0 sz)
           (mzd-open-v xh y -1.0 0.0 sz))
    (progn (mzd-open-v xl y -1.0 0.0 sz)
           (mzd-open-v xh y  1.0 0.0 sz)))
  (setvar "CLAYER" "TEXT")
  ;; rule 6 (DIM AUTOSIZE): the text shrinks to fit BETWEEN the two arrows.
  (setq h (mzd-h 'DIM))
  (if (> (mzd-tw label h) (- xh xl (* sz 2.0)))
    (setq h (max (* (mzd-h 'DIM) 0.45)
                 (/ (- xh xl (* sz 2.0)) (* 0.62 (max 1 (strlen label)))))))
  (mzd-txt-d "MC" (list (* 0.5 (+ xl xh)) (+ y (* sz 0.55))) h 0 label)
  (setvar "CLAYER" prev)
  (princ))

;; ---------------------------------------------------------------------------
;;  M-LADDER  -  the engine's own callout shape (rm-mladder, Section.lsp:7529)
;; ---------------------------------------------------------------------------
;; A CALLOUT ARROW IS FILLED.  Standing rule 2 splits the two: dimension heads are
;; the OPEN type, leader/callout heads stay FILLED.  Measured off the reference
;; sheet (_render\Section_Final\1_Clear_Span_Gable.pdf), where COLUMN / GIRT /
;; DOWN PIPE all terminate in a solid triangle.

;; ---------------------------------------------------------------------------
;;  THE M-LADDER IS AN L  (owner: "MLadders must have the legs of L-Shape")
;;
;;  Arrow on the member -> SHORT VERTICAL LEG -> horizontal BAR to the common
;;  landing -> text.  That is `rm-mladder`'s own shape (Section.lsp:7529, riser
;;  then bar) and `draw-l-leader`'s, and it is what the reference sheet's
;;  WALL SHEETING / ROOF SHEETING / EAVE GUTTER callouts use.
;;
;;  I had reduced these to straight horizontal leaders after reading only the
;;  COLUMN / GIRT / DOWN PIPE labels, which happen to sit at their own heights
;;  and so show no leg.  That threw away the L.  The rule is the L with a SHORT
;;  leg - short, because the owner's standing complaint on the roof labels was
;;  long legs, not legs.  The leg here starts at ONE text height and only grows
;;  when a neighbour forces this label off its member's height (4B.27).
;; ---------------------------------------------------------------------------
(defun mzd-callout (tipx tipy lvl landx str / prev asz aw)
  ;; MATCHED TO Section.lsp (owner 1-Sep: "match the labeling and text with
  ;; Section.Lsp Coding ... & match the MLADDERS").
  ;;
  ;; `peb-label-with-leader` IS the Section's labeller, and its "V" form is
  ;; exactly this shape: horizontal bar at the TEXT level, vertical leg down at
  ;; the TARGET, tapered arrow landing on the member.  So the label is handed to
  ;; it rather than re-drawn here - same MLEADER, same arrowhead, same text - and
  ;; the height is taken off the ladder (`peb-th`-equivalent RAW value, because
  ;; that helper scales it internally, exactly as `txt` does).
  ;;
  ;; The local branch below is a faithful copy of `draw-l-leader` "V" for the
  ;; standalone case: layer ARROWS, arrowSize 160 x scale, width 55 x scale,
  ;; tapered PLINE to the tip.  Same numbers, so the two paths cannot diverge.
  (setq prev (getvar "CLAYER"))
  (if (boundp 'peb-label-with-leader)
    (vl-catch-all-apply
      (function (lambda ()
        (peb-label-with-leader str (list landx lvl) (list tipx tipy)
                               "V" (mzd-th 'ANNOT)))))
    (progn
      (setq asz (* 160.0 *MZD-TS*) aw (* 55.0 *MZD-TS*))
      (setvar "CLAYER" "ARROWS")
      (setvar "PLINEWID" 0.0)
      (if (> (abs (- tipx landx)) 1.0)
        (command "_.LINE" (list landx lvl) (list tipx lvl) ""))      ; the BAR
      (if (< tipy lvl)
        (progn
          (command "_.LINE" (list tipx lvl) (list tipx (+ tipy asz)) "")
          (command "_.PLINE" (list tipx (+ tipy asz)) "_W" aw 0 (list tipx tipy) ""))
        (progn
          (command "_.LINE" (list tipx lvl) (list tipx (- tipy asz)) "")
          (command "_.PLINE" (list tipx (- tipy asz)) "_W" aw 0 (list tipx tipy) "")))
      (setvar "PLINEWID" 0.0)
      (setvar "CLAYER" "TEXT")
      (mzd-txt (if (> landx tipx) "ML" "MR")
               (list (+ landx (* (mzd-h 'ANNOT) (if (> landx tipx) 0.35 -0.35))) lvl)
               (mzd-h 'ANNOT) 0 str)))
  (setvar "CLAYER" prev)
  (princ))

(defun mzd-callouts (items landx / th sorted prev y)
  ;; THE LANDING RULE, taken from the reference sheet rather than from memory.
  ;;
  ;; On a Maimaar section a member callout is a HORIZONTAL leader: text on a
  ;; common landing line, running straight across to a filled arrow at the
  ;; member, each label sitting at ITS OWN member's height.  There is no vertical
  ;; rail and no stacked level - the owner's standing complaint about the roof
  ;; labels was exactly that, "no long M-Ladder legs".  The earlier version here
  ;; stacked every label above the slab and ran a riser down to the member, which
  ;; is why the landings did not match the rest of the set.
  ;;
  ;; A label moves off its member's height ONLY when a neighbour is inside one
  ;; text height of it, and then by the least that clears it (4B.27: the gap that
  ;; clears text comes from the text).  Walking bottom-up keeps the order.
  ;; EVERY callout gets a LEG - that is what makes it an L (owner 1-Sep).  The leg
  ;; starts at *MZD-LEG* text heights and only grows when the label above forces
  ;; this one further up.
  (setq th (mzd-h 'ANNOT)
        sorted (vl-sort items (function (lambda (a b) (< (cadr a) (cadr b)))))
        prev nil)
  (foreach it sorted
    (setq y (+ (cadr it) (* th *MZD-LEG*)))
    (if (and prev (< (- y prev) (* th 1.35))) (setq y (+ prev (* th 1.35))))
    (mzd-callout (car it) (cadr it) y landx (caddr it))
    (setq prev y))
  (princ))

(defun mzd-lane (strs / w h)
  ;; the landing lane a set of ladder labels needs: the widest label plus a clear
  ;; text height either side (4B.27 - the gap comes FROM the text).
  (setq w 0.0 h (mzd-h 'ANNOT))
  (foreach s strs (setq w (max w (mzd-tw-safe s h))))
  (+ w (* h 1.2)))

;; ---------------------------------------------------------------------------
;;  PARTS
;; ---------------------------------------------------------------------------
(defun mzd-conc (x0 x1 y0 y1 / )
  (setvar "CLAYER" "RCC-COLUMN")
  (setvar "PLINEWID" 0.0)
  (command "_.RECTANG" (list x0 y0) (list x1 y1))
  (vl-catch-all-apply
    (function (lambda ()
      (command "_.HATCH" "AR-CONC" *MZD-CONC-SCALE* 0 "_L" ""))))
  (princ))

(defun mzd-rebar (x0 x1 y d / x step)
  ;; REINFORCEMENT in the topping (owner 1-Sep: "show the reinforcement bars as
  ;; well").  Bars run into the page, so they cut as dots - the same reading the
  ;; accepted DETAIL-A gives them.  Sized and spaced off the SLAB, so a 75 mm
  ;; slab does not get the bar a 150 mm slab gets.
  (setvar "CLAYER" "RCC-COLUMN")
  (setq step (/ (- x1 x0) 9.0) x (+ x0 (* step 0.5)))
  (while (< x x1)
    (command "_.DONUT" 0 d (list x y) "")
    (setq x (+ x step)))
  (princ))

(defun mzd-deck-run (x0 x1 yb off / x sl)
  ;; ONE skin of the profiled deck, offset `off` above the steel.  Starts on a
  ;; trough, so the sheet always bears on the beam / joist top flange.
  (setq sl (max 5.0 (/ (- *MZD-DECK-PITCH* (* 2.0 *MZD-DECK-FLAT*)) 2.0)))
  (setvar "PLINEWID" 0.0)
  (command "_.PLINE" (list x0 (+ yb off)))
  (setq x x0)
  (while (< x x1)
    (command (list (min x1 (+ x *MZD-DECK-FLAT*)) (+ yb off)))
    (command (list (min x1 (+ x *MZD-DECK-FLAT* sl)) (+ yb *MZD-DECK-RIB* off)))
    (command (list (min x1 (+ x *MZD-DECK-FLAT* sl *MZD-DECK-FLAT*))
                   (+ yb *MZD-DECK-RIB* off)))
    (command (list (min x1 (+ x *MZD-DECK-PITCH*)) (+ yb off)))
    (setq x (+ x *MZD-DECK-PITCH*)))
  (command "")
  (princ))

(defun mzd-deck (x0 x1 yb / )
  ;; two skins = the folded sheet.  Drawn at *MZD-DECK-DRAWT*; the LABEL states
  ;; the true 0.70 mm gauge, so the exaggeration misstates nothing (4B.31).
  (setvar "CLAYER" "CLADDING")
  (mzd-deck-run x0 x1 yb 0.0)
  (mzd-deck-run x0 x1 yb *MZD-DECK-DRAWT*)
  (princ))

(defun mzd-joist-cut (cx yTop jd / hf ht hw)
  ;; JOIST in CROSS-SECTION.  yTop is its top flange, FLUSH under the main beam
  ;; top flange - rule 4B.32, never seated on top of it.
  (setq hf (/ *MZD-JOIST-FLANGE* 2.0) ht *MZD-JOIST-TF* hw (/ *MZD-JOIST-WEB* 2.0))
  (setvar "CLAYER" "COMP-MEZZ-JOIST")
  (setvar "PLINEWID" 0.0)
  (command "_.RECTANG" (list (- cx hf) (- yTop ht)) (list (+ cx hf) yTop))
  (command "_.RECTANG" (list (- cx hw) (+ (- yTop jd) ht)) (list (+ cx hw) (- yTop ht)))
  (command "_.RECTANG" (list (- cx hf) (- yTop jd)) (list (+ cx hf) (+ (- yTop jd) ht)))
  (princ))

(defun mzd-beam-cut (cx yTop bd / hf ht hw)
  ;; MAIN BEAM in CROSS-SECTION - the cut runs ALONG a joist, so the beam, which
  ;; is perpendicular to it, is cut: two flanges and the web between.
  (setq hf (/ *MZD-BEAM-FLANGE* 2.0) ht *MZD-BEAM-TF* hw (/ *MZD-BEAM-WEB* 2.0))
  (setvar "CLAYER" "COMP-MEZZ-BEAM")
  (setvar "PLINEWID" 0.0)
  (command "_.RECTANG" (list (- cx hf) (- yTop ht)) (list (+ cx hf) yTop))
  (command "_.RECTANG" (list (- cx hw) (+ (- yTop bd) ht)) (list (+ cx hw) (- yTop ht)))
  (command "_.RECTANG" (list (- cx hf) (- yTop bd)) (list (+ cx hf) (+ (- yTop bd) ht)))
  (princ))

(defun mzd-joist-elev (x0 x1 yTop jd / )
  ;; JOIST in ELEVATION, running into the beam web - web face plus its two flange
  ;; lines, the same reading the accepted DETAIL-A has.
  (setvar "CLAYER" "COMP-MEZZ-JOIST")
  (setvar "PLINEWID" 0.0)
  (command "_.RECTANG" (list x0 (- yTop jd)) (list x1 yTop))
  (command "_.LINE" (list x0 (- yTop *MZD-JOIST-TF*))
                    (list x1 (- yTop *MZD-JOIST-TF*)) "")
  (command "_.LINE" (list x0 (+ (- yTop jd) *MZD-JOIST-TF*))
                    (list x1 (+ (- yTop jd) *MZD-JOIST-TF*)) "")
  (princ))

(defun mzd-clip (xWeb yTop jd / t0 y0 y1 bx r)
  ;; THE BOLTED CONNECTION (owner 1-Sep: "show the bolting connections").
  ;; A clip angle against the main beam web on the JOIST side - which is where it
  ;; physically sits - with the joist web bolted through it.  This is the piece
  ;; the accepted DETAIL-A carries and the one a customer asks about when they
  ;; want to know how the floor is held up.
  (setq t0 (* *MZD-JOIST-WEB* 1.4)
        y0 (- yTop *MZD-JOIST-TF* (* jd 0.14))
        y1 (+ (- yTop jd) *MZD-JOIST-TF* (* jd 0.14))
        bx (- xWeb (* *MZD-JOIST-FLANGE* 0.62))
        r  (* *MZD-JOIST-WEB* 2.4))
  (setvar "CLAYER" "PLATES")
  (setvar "PLINEWID" 0.0)
  ;; the angle: leg on the web, plus its outstanding leg turned toward the joist
  (command "_.RECTANG" (list (- xWeb t0) y1) (list xWeb y0))
  (command "_.PLINE" (list (- xWeb t0) y1)
                     (list (- xWeb t0 (* *MZD-JOIST-FLANGE* 0.45)) y1) "")
  ;; the bolts through the joist web
  (setvar "CLAYER" "BOLTS")
  (command "_.DONUT" 0 r (list bx (- y0 (* (- y0 y1) 0.28))) "")
  (command "_.DONUT" 0 r (list bx (- y0 (* (- y0 y1) 0.72))) "")
  (princ))

(defun mzd-beam-elev (x0 x1 yTop bd / )
  ;; MAIN BEAM in ELEVATION - the cut runs across the joists, so the beam, which
  ;; is perpendicular to them, is seen along its length: two flange bands and the
  ;; web face between.  The ends are left OPEN: the beam runs on past this slice.
  (setvar "CLAYER" "COMP-MEZZ-BEAM")
  (setvar "PLINEWID" 0.0)
  (command "_.RECTANG" (list x0 (- yTop *MZD-BEAM-TF*)) (list x1 yTop))
  (command "_.RECTANG" (list x0 (- yTop bd)) (list x1 (+ (- yTop bd) *MZD-BEAM-TF*)))
  (princ))

(defun mzd-column (cx y0 y1 / hw bp)
  ;; MEZZANINE COLUMN - tube, so it reads as a rectangle in section, on a base
  ;; plate at floor level.  Same width the cross section gives it.
  (setq hw (/ *MZD-COL-WIDTH* 2.0) bp (* *MZD-COL-WIDTH* 0.9))
  (setvar "CLAYER" "COMP-MEZZ-BEAM")
  (setvar "PLINEWID" 0.0)
  (command "_.RECTANG" (list (- cx hw) y0) (list (+ cx hw) y1))
  (setvar "CLAYER" "PLATES")
  (command "_.RECTANG" (list (- cx bp) y0) (list (+ cx bp) (+ y0 (* *MZD-COL-WIDTH* 0.10))))
  (princ))

(defun mzd-ground (x0 x1 y / x step d)
  ;; the building's own floor, so the mezzanine reads as standing IN a building
  ;; rather than floating.  Ticks, not a HATCH: a HATCH here has to be bounded,
  ;; and an unbounded one is the classic way to hang a headless render.
  (setq d (* (mzd-h 'ANNOT) 0.42) step (* d 1.5))
  (setvar "CLAYER" "GROUND")
  (setvar "PLINEWID" 0.0)
  (command "_.LINE" (list x0 y) (list x1 y) "")
  (setvar "CLAYER" "GROUND-HATCH")
  (setq x (+ x0 step))
  (while (< x x1)
    (command "_.LINE" (list x y) (list (- x d) (- y d)) "")
    (setq x (+ x step)))
  (princ))

(defun mzd-level (x y str dir landx / th w tx)
  ;; LEVEL TAG - the drafting symbol for a stated floor level: a filled triangle
  ;; standing on the level line, the value beside it.  This is the one mark that
  ;; makes a section read as a set of LEVELS, which is what the BSF states.
  (setq th (mzd-h 'ANNOT) w (* th 0.42))
  (setvar "CLAYER" "TEXT")
  (setvar "PLINEWID" 0.0)
  ;; the tag runs to the SAME landing its side's callouts use, so the level and
  ;; the member labels share one alignment instead of colliding in mid-air - on
  ;; MSPL-26-279 "F.F.L. MEZZANINE" printed straight through "STEEL JOISTS".
  (command "_.LINE" (list (+ x (* th 0.6 dir)) y) (list landx y) "")
  (command "_.SOLID" (list x y)
                     (list (- x w) (+ y (* w 1.7)))
                     (list (+ x w) (+ y (* w 1.7)))
                     (list (+ x w) (+ y (* w 1.7))) "")
  (setq tx (+ landx (* th 0.35 dir)))
  (mzd-txt (if (> dir 0.0) "ML" "MR") (list tx (+ y (* th 0.62))) th 0 str)
  (princ))

(defun mzd-bubble (cx cy lab / th r)
  ;; the mark that ties VIEW B back to the place on VIEW A it is taken from.
  (setq th (mzd-h 'ANNOT) r (* th 0.90))
  (setvar "CLAYER" "TEXT")
  (setvar "PLINEWID" 0.0)
  (command "_.CIRCLE" (list cx cy) r)
  (mzd-txt "MC" (list cx cy) th 0 lab)
  (princ))

(defun mzd-plate (x0 x1 yb / )
  (setvar "CLAYER" "CLADDING")
  (setvar "PLINEWID" 0.0)
  (command "_.RECTANG" (list x0 yb) (list x1 (+ yb *MZD-PLATE-DRAWT*)))
  (princ))

(defun mzd-precast (x0 x1 yb thk / pd x step)
  (setq pd *MZD-PLANK-DEPTH*)
  (setvar "CLAYER" "RCC-COLUMN")
  (setvar "PLINEWID" 0.0)
  (command "_.RECTANG" (list x0 yb) (list x1 (+ yb pd)))
  (setq step (* pd 1.3) x (+ x0 (* step 0.6)))
  (while (< x (- x1 (* pd 0.35)))
    (command "_.CIRCLE" (list x (+ yb (* pd 0.5))) (* pd 0.30))
    (setq x (+ x step)))
  (mzd-conc x0 x1 (+ yb pd) (+ yb pd thk))
  (princ))

;; ---------------------------------------------------------------------------
;;  GEOMETRY - one derivation, read by both views, so they cannot disagree
;; ---------------------------------------------------------------------------
(defun mzd-sys (data / s)
  (setq s (strcase (mzd-str data "MZ1_FLOOR")))
  (if (= s "") (setq s (strcase (mzd-str data "MZ1_FLOOR_MAT"))))
  (cond ((or (vl-string-search "PRECAST" s) (vl-string-search "HOLLOW" s)) "PRECAST")
        ((or (vl-string-search "GRAT" s) (vl-string-search "CHEQ" s)
             (vl-string-search "PLATE" s))                                 "GRATING")
        (T                                                                 "DECK")))

(defun mzd-geom (data / sys thk jsp csp ffl chb bd jd topH bdOk fflOk chbOk)
  (setq sys (mzd-sys data)
        thk (mzd-num data "MZ1_FLOOR_THK" 150.0)     ; IF / BSF - owner 1-Sep
        jsp (mzd-num data "MZ_JOIST"     1250.0)
        csp (mzd-first-mod (mzd-str data "MZ_COL_SPACING") 6000.0))
  (if (< thk 40.0)  (setq thk 150.0))
  (if (< jsp 300.0) (setq jsp 1250.0))
  ;; build-up ABOVE top-of-steel, per floor system
  (setq topH (cond ((= sys "GRATING") *MZD-PLATE-DRAWT*)
                   ((= sys "PRECAST") (+ *MZD-PLANK-DEPTH* thk))
                   (T                 (+ *MZD-DECK-RIB* thk))))
  ;; RULE 4B.7 - the beam depth is what the two STATED levels imply, not a house
  ;; constant.  Identical arithmetic to peb-draw-mezz-section.
  (setq ffl (mzd-num data "MZ1_CH_FFL_SLAB" 0.0)
        chb (mzd-num data "MZ1_CH_FFL_BEAM" 0.0)
        bd  700.0 bdOk nil fflOk (> ffl 0.0) chbOk (> chb 0.0))
  (if (and fflOk chbOk
           (> (- ffl chb topH) 150.0) (< (- ffl chb topH) 2500.0))
    (setq bd (- ffl chb topH) bdOk T))
  (if (not chbOk) (setq chb 3000.0))             ; the cross section's own default
  ;; ---- WHAT IS STATED, AND WHAT IS ONLY DRAWN -----------------------------
  ;; MSPL-26-279 is the case that matters: MZ1_FLOOR_THK=75, MZ1_CH_FFL_BEAM=5029,
  ;; and MZ1_CH_FFL_SLAB=0 - BLANK.  The geometry still needs a slab top, so one
  ;; is computed; but a computed level is NOT a BSF level, and this sheet is
  ;; headed "PER IF / BSF".  Printing 5,849 there would be the silent-fabrication
  ;; fault the sync contract calls C4 - the drawing inventing a fact and the
  ;; customer reading it as the offer's.  So the derived value is carried for
  ;; DRAWING only, and every consumer is told whether it was STATED.
  (if (not fflOk) (setq ffl (+ chb bd topH)))
  (setq jd (max 250.0 (* bd *MZD-JOIST-RATIO*)))
  (if (= sys "PRECAST") (setq jd 0.0))           ; precast = MAIN BEAMS ONLY
  (list (cons "SYS" sys) (cons "THK" thk) (cons "JSP" jsp) (cons "CSP" csp)
        (cons "BD" bd)   (cons "JD" jd)   (cons "TOPH" topH)
        (cons "CHB" chb) (cons "FFL" ffl)
        (cons "FFL-OK" fflOk) (cons "CHB-OK" chbOk) (cons "BD-OK" bdOk)
        ;; a 15,240 module two bays wide makes a 30 m view beside a 6 m one - the
        ;; sheet turns into a ribbon.  Wide modules show ONE bay, which still
        ;; reads as "columns, beam, floor"; tight ones show two.
        (cons "BAYS" (if (> csp 9000.0) 1 2))))

(defun mzd-g (g key) (cdr (assoc key g)))

(defun mzd-topping (sys x0 x1 yb thk flat / )
  ;; the floor ABOVE top-of-steel, whichever system the BSF selected.
  ;; `flat` = T when the cut runs ALONG the deck rib, where the sheet reads as
  ;; two lines rather than a corrugation - which is the case in VIEW A.
  (cond
    ((= sys "GRATING") (mzd-plate x0 x1 yb))
    ((= sys "PRECAST") (mzd-precast x0 x1 yb thk))
    (T (mzd-conc x0 x1 yb (+ yb *MZD-DECK-RIB* thk))
       (mzd-rebar x0 x1 (+ yb *MZD-DECK-RIB* (* thk 0.55)) (* thk 0.15))
       (if flat
         (progn
           (setvar "CLAYER" "CLADDING")
           (command "_.LINE" (list x0 yb) (list x1 yb) "")
           (setvar "CELTYPE" "DASHED")
           (command "_.LINE" (list x0 (+ yb *MZD-DECK-RIB*))
                             (list x1 (+ yb *MZD-DECK-RIB*)) "")
           (setvar "CELTYPE" "BYLAYER"))
         (mzd-deck x0 x1 yb))))
  (princ))

(defun mzd-floor-label (sys thk / )
  ;; the FLOOR THICKNESS here is MZ1_FLOOR_THK, the same field VIEW B dimensions
  ;; and the DATA panel lists - one source, so the three cannot disagree.
  (cond ((= sys "GRATING") "CHEQUERED PLATE / GRATING FLOOR")
        ((= sys "PRECAST") (strcat (rtos thk 2 0)
                                   " mm SCREED ON PRECAST HOLLOW-CORE PLANK"))
        (T (strcat (rtos thk 2 0) " mm R.C. SLAB ON "
                   (rtos *MZD-DECK-GAUGE* 2 2) " mm PROFILED STEEL DECK"))))

;; a view's own title block, placed a text-derived distance under its lowest ink
(defun mzd-title (cx ybot nameStr subStr / th w)
  (setq th (mzd-h 'ANNOT))
  (setvar "CLAYER" "TEXT")
  (mzd-txt-b "MC" (list cx (- ybot (* th 1.8))) (mzd-h 'LABEL) 0 nameStr)
  ;; a rule under the name - the one piece of pure presentation on the sheet, and
  ;; it is sized from the NAME it underlines, not from the view.
  (setq w (* 0.5 (mzd-tw-safe nameStr (mzd-h 'LABEL))))
  (setvar "CELWEIGHT" 30)
  (setvar "CECOLOR" "5")
  (command "_.LINE" (list (- cx w) (- ybot (* th 2.55)))
                    (list (+ cx w) (- ybot (* th 2.55))) "")
  (setvar "CECOLOR" "BYLAYER")
  (setvar "CELWEIGHT" -1)
  (mzd-txt "MC" (list cx (- ybot (* th 3.5))) th 0 subStr)
  (princ))

(defun mzd-title-drop ( ) (* (mzd-h 'ANNOT) 4.7))

;; ===========================================================================
;;  VIEW A  -  MEZZANINE FLOOR SECTION.  The idea, at building scale: columns off
;;  the building floor, main beam spanning them, joists on the beam, floor over.
;;  The cut runs ACROSS the joists (so they read as cut sections) and therefore
;;  ALONG the deck rib, which is why the deck is two lines here and a corrugation
;;  in VIEW B.
;; ===========================================================================
(defun mzd-view-a (ox oy g landL landR / sys thk jsp csp bd jd chb ffl topH bays
                                         x0 x1 fx0 fx1 tos n cx jx th
                                         above bubx prev)
  (setq prev (getvar "CLAYER") th (mzd-h 'ANNOT)
        sys (mzd-g g "SYS") thk (mzd-g g "THK") jsp (mzd-g g "JSP")
        csp (mzd-g g "CSP") bd  (mzd-g g "BD")  jd  (mzd-g g "JD")
        chb (mzd-g g "CHB") ffl (mzd-g g "FFL") topH (mzd-g g "TOPH")
        bays (mzd-g g "BAYS"))
  (setq x0  ox
        x1  (+ ox (* csp bays))
        ;; the floor oversails the end columns - a mezzanine has an edge, and a
        ;; slab that stops dead on its last column reads as a beam, not a floor
        fx0 (- x0 (* csp 0.16))
        fx1 (+ x1 (* csp 0.16))
        tos (+ oy chb bd))                          ; TOP OF STEEL
  ;; ---- the building's own floor -------------------------------------------
  (mzd-ground (- fx0 (* csp 0.10)) (+ fx1 (* csp 0.10)) oy)
  ;; ---- columns -------------------------------------------------------------
  (setq n 0)
  (while (<= n bays)
    (mzd-column (+ x0 (* csp n)) oy (+ oy chb))
    (setq n (1+ n)))
  ;; ---- main beam, then joists on it, then the floor over both --------------
  (mzd-beam-elev fx0 fx1 tos bd)
  (if (> jd 0.0)
    (progn
      (setq jx (+ fx0 (* jsp 0.5)))
      (while (< jx fx1)
        (mzd-joist-cut jx (- tos *MZD-BEAM-TF*) jd)      ; flush - rule 4B.32
        (setq jx (+ jx jsp)))))
  (mzd-topping sys fx0 fx1 tos thk T)
  ;; ---- levels and spans, all of them the BSF's ----------------------------
  ;; the level tag carries a NUMBER only when the BSF states one (MSPL-26-279
  ;; leaves MZ1_CH_FFL_SLAB blank); otherwise it names the level and stops.
  ;; LEFT lane, because the RIGHT lane belongs to the member callouts.
  (mzd-level fx0 (+ tos topH)
             (if (mzd-g g "FFL-OK")
               (strcat "F.F.L. MEZZANINE   " (rtos ffl 2 0))
               "F.F.L. MEZZANINE")
             -1.0 landL)
  (mzd-dim-v (- fx0 (* th 1.2)) oy (+ oy chb) x0 fx0 (mzd-mmft chb))
  (setq n 0)
  (while (< n bays)
    (mzd-dim-h (+ x0 (* csp n)) (+ x0 (* csp (1+ n))) (- oy (* th 2.4))
               oy oy (mzd-mmft csp))
    (setq n (1+ n)))
  ;; ---- the bubble that ties VIEW B to where it is taken -------------------
  (setq bubx (+ fx0 (* (- fx1 fx0) 0.78)))
  (mzd-bubble bubx (+ tos topH (* th 2.2)) "B")
  (setvar "CLAYER" "TEXT")
  (command "_.LINE" (list bubx (+ tos topH (* th 1.3)))
                    (list bubx (+ tos (* topH 0.5))) "")
  ;; ---- M-LADDERS, one landing line, staggered by the rule ------------------
  ;; THE BAR IS SHORT BECAUSE THE TIP IS NEAR THE LANDING (owner 1-Sep).  A tip
  ;; taken from the middle of the view drags its bar across the whole drawing;
  ;; taken from the last quarter, the same label reads as a tall L with a short
  ;; arm.  The members run the full width, so choosing where to point at them
  ;; costs nothing.
  (setq above (list (list (+ fx0 (* (- fx1 fx0) 0.74)) (+ tos (* topH 0.55))
                          (mzd-floor-label sys thk))
                    (list (+ fx0 (* (- fx1 fx0) 0.88)) (+ (- tos bd) (* *MZD-BEAM-TF* 0.5))
                          (strcat "MAIN BEAM  " (rtos bd 2 0) " DEEP"))))
  (if (> jd 0.0)
    ;; land the arrow on a REAL joist station, not on a fraction of the width
    (setq above (append above
                  (list (list (+ fx0 (* jsp (+ 0.5 (fix (/ (* (- fx1 fx0) 0.62) jsp)))))
                              (- tos *MZD-BEAM-TF* (* jd 0.5))
                              (strcat "STEEL JOISTS @ " (rtos jsp 2 0) " C/C"))))))
  (mzd-callouts above landR)
  (mzd-callouts (list (list x0 (+ oy (* chb 0.55)) "MEZZANINE COLUMN")) landL)
  ;; ---- title ---------------------------------------------------------------
  (mzd-title (* 0.5 (+ fx0 fx1)) (- oy (* th 4.0))
             "MEZZANINE FLOOR SECTION" "SECTION ACROSS JOISTS  (N.T.S.)")
  (setvar "CLAYER" prev)
  (- oy (* th 4.0) (mzd-title-drop)))

;; ===========================================================================
;;  VIEW B  -  FLOOR BUILD-UP, enlarged.  The decking sheet is the one thing a
;;  customer cannot picture from a note, so it gets the treatment rule 4B.31
;;  reserves for anything that must READ: its own scale, with the TRUE values
;;  written beside it.  This is `draw-fr-detail`'s build-up, stripped of the
;;  connection hardware that belongs on an approval drawing.
;; ===========================================================================
(defun mzd-view-b (ox oy g sc landx / thk jd x0 x1 yb th cx
                                      rib pit flat drawt jf jt jw conc
                                      sRib sThk above prev)
  (setq prev (getvar "CLAYER") th (mzd-h 'ANNOT)
        thk (mzd-g g "THK") jd (mzd-g g "JD"))
  ;; scale the DRAWN profile only; every label still states the true value
  (setq rib *MZD-DECK-RIB* pit *MZD-DECK-PITCH* flat *MZD-DECK-FLAT*
        drawt *MZD-DECK-DRAWT*
        jf *MZD-JOIST-FLANGE* jt *MZD-JOIST-TF* jw *MZD-JOIST-WEB*
        ;; THE CONCRETE PATTERN IS A TUNABLE LIKE THE REST (3-Sep-2026).  It was the one that
        ;; did NOT get scaled here, so VIEW B drew the slab nine times bigger with an AR-CONC
        ;; pattern still set for true size: nine times as many stones in the same box, which
        ;; plots as a SOLID BLACK BAR.  The sheet's only close-up - the thing rule 4B.31 says
        ;; a customer cannot picture from a note - came out as a smudge.
        conc *MZD-CONC-SCALE*)
  (setq sRib (* rib sc) sThk (* thk sc))
  (setq *MZD-DECK-RIB* sRib *MZD-DECK-PITCH* (* pit sc) *MZD-DECK-FLAT* (* flat sc)
        *MZD-DECK-DRAWT* (* drawt sc)
        *MZD-JOIST-FLANGE* (* jf sc) *MZD-JOIST-TF* (* jt sc) *MZD-JOIST-WEB* (* jw sc)
        *MZD-CONC-SCALE* (* conc sc))
  (setq x0 ox x1 (+ ox (* pit sc 3.0)) yb oy cx (* 0.5 (+ x0 x1)))
  (mzd-conc x0 x1 yb (+ yb sRib sThk))
  (mzd-deck x0 x1 yb)
  ;; one joist under it, cut, its top FLUSH with the deck bearing (4B.32).  Only
  ;; the top of the joist is shown - the depth is dimensioned on VIEW A.
  (if (> jd 0.0) (mzd-joist-cut cx yb (* jd sc 0.42)))
  ;; restore the true tunables the instant the drawing is done
  (setq *MZD-DECK-RIB* rib *MZD-DECK-PITCH* pit *MZD-DECK-FLAT* flat
        *MZD-DECK-DRAWT* drawt
        *MZD-JOIST-FLANGE* jf *MZD-JOIST-TF* jt *MZD-JOIST-WEB* jw
        *MZD-CONC-SCALE* conc)
  ;; ---- NO DIMENSIONS HERE, AND THAT IS THE DECISION -----------------------
  ;; Two stacked bands 296 and 986 deep cannot both carry a rotated dimension on
  ;; one line without one of them landing on the other, and forcing them outside
  ;; only moves the collision.  Every value they would have carried is already
  ;; STATED: the floor thickness in the ladder below, in VIEW A's floor callout
  ;; and in the DATA panel; the rib and pitch in the deck ladder.  A proposal
  ;; sheet owes the reader the number, not necessarily a dimension line - and the
  ;; owner asked for "no need to show much details".
  ;; ---- M-LADDERS: the build-up named, with its true figures ----------------
  (setq above (list (list (+ x0 (* pit sc 0.45)) (+ yb sRib (* sThk 0.5))
                          (strcat (rtos thk 2 0) " mm R.C. SLAB - PER IF / BSF"))
                    (list (+ x0 (* pit sc 1.55)) (+ yb (* sRib 0.5))
                          (strcat (rtos *MZD-DECK-GAUGE* 2 2)
                                  " mm PROFILED STEEL DECK  |  "
                                  (rtos rib 2 0) " RIB @ " (rtos pit 2 0) " PITCH"))))
  (mzd-callouts above landx)
  ;; ---- title, carrying the bubble letter so the two views are tied ---------
  (mzd-title cx (- yb (* th (if (> jd 0.0) 3.2 1.4)))
             "B    FLOOR BUILD-UP"
             (strcat "ENLARGED x" (rtos sc 2 0) "  (N.T.S.)"))
  (setvar "CLAYER" prev)
  (- yb (* th (if (> jd 0.0) 3.2 1.4)) (mzd-title-drop)))

;; ===========================================================================
;;  DATA PANEL  -  the IF / BSF values, stated plainly.  Owner 1-Sep: the sheet
;;  exists to show the mezzanine "based on BSF/IF Data", so the data is on it,
;;  not only implied by the geometry.  A row whose field the BSF left blank is
;;  DROPPED rather than printed as zero - a stated zero is a claim.
;; ===========================================================================
(defun mzd-row (lab val) (list lab val))

(defun mzd-panel (ox oy title rows / prev th y w lw)
  (setq prev (getvar "CLAYER") th (mzd-h 'ANNOT) y oy lw 0.0)
  (foreach r rows (setq lw (max lw (mzd-tw-safe (car r) th))))
  (setq w (+ lw (* th 2.0)))
  (setvar "CLAYER" "TEXT")
  (mzd-txt-b "ML" (list ox y) (mzd-h 'LABEL) 0 title)
  (setvar "CELWEIGHT" 30)
  (setvar "CECOLOR" "5")
  (setvar "PLINEWID" 0.0)
  (command "_.LINE" (list ox (- y (* th 0.85)))
                    (list (+ ox w (* th 9.0)) (- y (* th 0.85))) "")
  (setvar "CECOLOR" "BYLAYER")
  (setvar "CELWEIGHT" -1)
  (setq y (- y (* th 2.1)))
  (foreach r rows
    (mzd-txt "ML" (list ox y) th 0 (car r))
    (mzd-txt "ML" (list (+ ox w) y) th 0 (strcat ":   " (cadr r)))
    (setq y (- y (* th 1.5))))
  (setvar "CLAYER" prev)
  (+ y (* th 0.6)))

(defun mzd-data-rows (data g / sys rows dl ll cl fl n)
  (setq sys (mzd-g g "SYS") rows '())
  (setq fl (mzd-str data "MZ1_FLOOR"))
  (if (= fl "") (setq fl (mzd-str data "MZ1_FLOOR_MAT")))
  (if (= fl "")
    (setq fl (cond ((= sys "GRATING") "Grating / Chequered Plate")
                   ((= sys "PRECAST") "Precast / Hollow-Core")
                   (T "Galvanized Steel Deck + RCC Slab"))))
  ;; ---- STATED vs DERIVED --------------------------------------------------
  ;; This panel is headed "PER IF / BSF", so anything under it is a claim about
  ;; what the BSF says.  MSPL-26-279 is the case that proves it matters: it
  ;; states MZ1_FLOOR_THK=75 and MZ1_CH_FFL_BEAM=5029 but leaves
  ;; MZ1_CH_FFL_SLAB BLANK.  The drawing still needs a slab top, so one is
  ;; computed - but printing that computed 5,849 here as an F.F.L. would be the
  ;; drawing inventing a level and the customer reading it as the offer's.
  ;; A derived figure is therefore MARKED, never passed off as stated.
  (setq rows (list (mzd-row "FLOOR SYSTEM" (strcase fl))
                   (mzd-row "FLOOR THICKNESS"
                            (strcat (rtos (mzd-g g "THK") 2 0) " mm"))))
  (setq rows (append rows
    (list (mzd-row "F.F.L. MEZZANINE"
                   (if (mzd-g g "FFL-OK")
                     (strcat (rtos (mzd-g g "FFL") 2 0) " mm")
                     "NOT STATED ON THE BSF"))
          (mzd-row "CLEAR HEIGHT UNDER BEAM"
                   (if (mzd-g g "CHB-OK")
                     (strcat (rtos (mzd-g g "CHB") 2 0) " mm")
                     "NOT STATED ON THE BSF"))
          (mzd-row "MAIN BEAM DEPTH"
                   (strcat (rtos (mzd-g g "BD") 2 0) " mm"
                           (if (mzd-g g "BD-OK") "" "   (INDICATIVE)"))))))
  (if (> (mzd-g g "JD") 0.0)
    (setq rows (append rows
      (list (mzd-row "JOIST SPACING"
                     (strcat (rtos (mzd-g g "JSP") 2 0) " mm C/C"))))))
  (setq rows (append rows
    (list (mzd-row "COLUMN SPACING"
                   (strcat (rtos (mzd-g g "CSP") 2 0) " mm")))))
  (setq n (mzd-num data "MZ_NUM_FLOORS" 1.0))
  (if (> n 1.0)
    (setq rows (append rows
      (list (mzd-row "NO. OF MEZZANINE FLOORS" (rtos n 2 0))))))
  ;; a load row only if the BSF actually carries loads
  (setq dl (mzd-num data "MZ1_DL" 0.0)
        ll (mzd-num data "MZ1_LL" 0.0)
        cl (mzd-num data "MZ1_CL" 0.0))
  (if (> (+ dl ll cl) 0.0)
    (setq rows (append rows
      (list (mzd-row "DESIGN LOADS  (KN/SQ.M.)"
                     (strcat "D.L " (rtos dl 2 2) "    L.L " (rtos ll 2 2)
                             "    COLL. " (rtos cl 2 2)))))))
  rows)

;; ===========================================================================
;;  NOTES  -  three lines.  Owner 1-Sep: "no need to show much details."
;; ===========================================================================
;; THE NOTES ARE WRITTEN ONCE AND MEASURED FROM THE SAME PLACE (3-Sep-2026).
;; The sheet layout used to size the notes column from its OWN copy of note 3, typed out a
;; second time where the columns are placed.  Two copies of one string is a column width that
;; goes wrong the moment anybody edits a note - and it had: VIEW B started before the notes
;; ended, and the enlarged floor build-up sat on top of "...REINFORCEMENT & CONNECTIONS".
;; One list, read by the drawer and by the measurer.
(defun mzd-note-lines ( )
  ;; Note 3 is BROKEN SHORTER than it reads in prose.  At 75 characters it was the longest
  ;; string on the sheet by a wide margin, and it is the string the notes COLUMN is measured
  ;; from - so the small per-character error in an estimated width was multiplied 75 times and
  ;; VIEW B landed on the end of it.  Wrapped at the comma, no line is long enough for the
  ;; estimate to drift that far, and three short lines read better on A4 than two long ones.
  (list "1.  ALL DIMENSIONS ARE IN MM."
        "2.  LEVELS, FLOOR SYSTEM & LOADS ARE AS STATED IN THE IF / BSF."
        "3.  INDICATIVE PROPOSAL DRAWING - MEMBER SIZES,"
        "     REINFORCEMENT & CONNECTIONS PER THE APPROVAL"
        "     DRAWING.  NOT FOR CONSTRUCTION."))

;; The width the notes column needs: the widest line it will actually draw, plus the same
;; clear text-height either side that mzd-lane gives a ladder (4B.27 - the gap comes FROM
;; the text).
(defun mzd-notes-w (th / w)
  (setq w 0.0)
  (foreach s (mzd-note-lines) (setq w (max w (mzd-tw-safe s th))))
  (+ w (* th 1.2)))

(defun mzd-notes (ox oy / prev th y s lines)
  (setq prev (getvar "CLAYER") th (mzd-h 'ANNOT) y oy)
  (setq lines (mzd-note-lines))
  (setvar "CLAYER" "TEXT")
  (mzd-txt-b "ML" (list ox y) (mzd-h 'LABEL) 0 "NOTES")
  (setq y (- y (* th 2.1)))
  (foreach s lines
    (mzd-txt "ML" (list ox y) th 0 s)
    (setq y (- y (* th 1.5))))
  (setvar "CLAYER" prev)
  y)

;; ===========================================================================
;;  THE SHEET
;;
;;  VIEW A carries the sheet on the left.  The right column stacks VIEW B, the
;;  DATA panel and the NOTES - so a reader goes picture, then numbers, then
;;  qualifications, in that order.  Each view owns its landing lane on its own
;;  outer edge, so no ladder from one can reach into the other, and every lane
;;  and gap is measured from the text rather than guessed.
;; ===========================================================================
(defun peb-draw-mezz-detail (data ox oy / g sys thk jsp csp bd faceW th rEdge r
                                          laneL laneR viewAW colGap
                                          landL axo landR bandY rows
                                          dataW notesW c1 c2 c3
                                          yA yB yD yN ybot sc prev)
  (setq prev (getvar "CLAYER"))
  (mzd-layers)
  (mzd-style)
  (setq g   (mzd-geom data))
  (setq sys (mzd-g g "SYS") thk (mzd-g g "THK") jsp (mzd-g g "JSP")
        csp (mzd-g g "CSP") bd  (mzd-g g "BD"))
  ;; ---- TEXT SIZE COMES FROM THIS SHEET, NOT FROM A BUILDING (4B.9 / 4B.16) --
  ;; The ladder is stated in millimetres of PAPER and *PEB-TEXT-SCALE* is
  ;; faceWidth/45000, so ANNOT plots at its stated 3.0 mm whatever the sheet
  ;; measures.  Estimated first, because every lane below depends on the height.
  ;; THE DIVISOR IS THE SHEET, NOT THE VIEW.  The ladder is millimetres of PAPER,
  ;; and a sheet is fitted to about 277 mm of A4.  For ANNOT (830) to land on its
  ;; stated 3.0 mm:   830 x TS x 277 / W = 3.0   ->   TS = W / 76,630,  where W is
  ;; the FINISHED SHEET width, not the drawing's.  The engine's familiar
  ;; faceMax/45000 is the same number in disguise: its sheets come out about 1.7x
  ;; the building face once dims and labels are added, and 1.7/76,630 ~ 1/45,000.
  ;;
  ;; Taking 45,000 with a face that was ALREADY most of the sheet made the text
  ;; 65% oversized, which widened every lane and every column that is measured
  ;; from it - the 4.9:1 sheet.  Estimate the SHEET here, and divide by 76,630.
  (setq viewAW (* csp (+ (mzd-g g "BAYS") 0.32)))
  (setq faceW (* viewAW 1.90))                   ; VIEW A plus both landing lanes
  (setq *MZD-TS* (/ faceW 76630.0))
  (setq *PEB-TEXT-SCALE* *MZD-TS*)
  (setq *PEB-DIM-SCALE*  *MZD-TS*)
  (setq th (mzd-h 'ANNOT))
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  ;; VIEW B's enlargement: sized so the build-up fills the right column rather
  ;; than being a stamp in the corner - it is the sheet's only close-up.
  (setq sc (max 3.0 (/ (* th 13.0) (* *MZD-DECK-PITCH* 3.0))))
  ;; ---- lanes, measured from the widest label each side will carry ----------
  ;; the LEFT lane now also carries the F.F.L. tag, so it is measured with it.
  (setq laneL (mzd-lane (list "MEZZANINE COLUMN" "F.F.L. MEZZANINE   00000")))
  (setq laneR (mzd-lane (list (mzd-floor-label sys thk)
                              (strcat "MAIN BEAM  " (rtos bd 2 0) " DEEP")
                              (strcat "STEEL JOISTS @ " (rtos jsp 2 0) " C/C")
                              (strcat (rtos thk 2 0) " mm R.C. SLAB - PER IF / BSF"))))
  ;; ---- horizontal layout ---------------------------------------------------
  (setq landL (+ ox laneL))                       ; VIEW A's left landing
  (setq axo   (+ landL (* th 3.6)))               ; VIEW A origin (first column)
  ;; the landing sits just past the floor's own edge - any further out and the
  ;; bars lengthen for no reason (the lane beyond it holds the text).
  (setq landR (+ axo (* csp (mzd-g g "BAYS")) (* csp 0.16) (* th 1.2)))
  ;; ---- THE SHEET IS A 2 x 2, NOT A TALL COLUMN BESIDE A SHORT ONE ----------
  ;; Stacking VIEW B + DATA + NOTES down the right made a column roughly twice
  ;; VIEW A's height, so the sheet came out with a quarter of itself empty at the
  ;; bottom left.  The text blocks are PAPER-sized (4B.10) while VIEW A's height
  ;; is the building's, so that imbalance only gets worse on a taller mezzanine -
  ;; it is structural, not a nudge.  Drawings on the top row, words on the bottom
  ;; band, and the sheet fills its border either way.
  ;;
  ;; VIEW B is dropped so its SLAB TOP sits level with VIEW A's, because the two
  ;; are the same floor at two scales and a reader should meet them on one line.
  (setq yA (mzd-view-a axo oy g landL landR))
  ;; ---- BOTTOM BAND: DATA | NOTES | the build-up ---------------------------
  ;; VIEW A is as wide as the customer's own module - 15,240 on MSPL-26-279 - so
  ;; hanging a tall text column beside it drove the sheet to nearly 4:1, which no
  ;; A4 border can frame without wasting most of itself (4B.28).  Everything that
  ;; is not the section goes UNDER it in one band of three columns; the sheet then
  ;; lands near 2:1 whatever the module, and the band's own columns are measured
  ;; from their text rather than guessed.
  (setq rows (mzd-data-rows data g))
  (setq dataW 0.0)
  (foreach r rows
    (setq dataW (max dataW (mzd-tw-safe (strcat (car r) "     :   " (cadr r)) th))))
  (setq notesW (mzd-notes-w th))
  (setq bandY (- yA (* th 1.8)))
  ;; VIEW B GETS A WIDER GUTTER THAN THE TEXT COLUMNS DO.  mzd-tw-safe is an ESTIMATE of a
  ;; plotted string (0.75 of the height per character, deliberately over the measured mean),
  ;; and on the 75-character note 3 the small per-character error adds up to more than the
  ;; three text-heights that used to sit between the notes and VIEW B - so the enlarged floor
  ;; build-up printed across the end of the sentence.  Six heights clears it with room for a
  ;; longer note, and the sheet has the width to spare: there is nothing to its right.
  (setq c1 ox
        c2 (+ c1 dataW  (* th 3.0))
        c3 (+ c2 notesW (* th 6.0)))
  (setq yD (mzd-panel c1 bandY "MEZZANINE DATA  -  PER IF / BSF" rows))
  (setq yN (mzd-notes c2 bandY))
  ;; the build-up hangs from the band's top line like the two text blocks beside it
  (setq yB (mzd-view-b c3
                       (- bandY (* (+ (mzd-g g "THK") *MZD-DECK-RIB*) sc) (* th 2.2))
                       g sc (+ c3 (* *MZD-DECK-PITCH* sc 3.0) (* th 1.8))))
  ;; ---- sheet heading, clear below everything, centred on the REAL sheet -----
  ;; The right edge is MEASURED off the widest thing the right column actually
  ;; draws - VIEW B with its lane, the widest data row, the longest note - rather
  ;; than assumed from VIEW A's width.  Centring a heading on a guessed edge is
  ;; how a sheet ends up visibly off-centre in its border (4B.28).
  (setq ybot (min yD yN yB))
  (setq rEdge (max (+ landR laneR)
                   (+ c3 (* *MZD-DECK-PITCH* sc 3.0) (* th 1.8)
                      (mzd-lane (list (strcat (rtos thk 2 0)
                                              " mm R.C. SLAB - PER IF / BSF")
                                      (strcat (rtos *MZD-DECK-GAUGE* 2 2)
                                              " mm PROFILED STEEL DECK  |  "
                                              (rtos *MZD-DECK-RIB* 2 0) " RIB @ "
                                              (rtos *MZD-DECK-PITCH* 2 0)
                                              " PITCH"))))))
  (setq faceW (- rEdge ox))
  (setvar "CLAYER" "TEXT")
  (mzd-txt-b "MC" (list (* 0.5 (+ ox rEdge)) (- ybot (* th 2.8)))
             (mzd-head-h "MEZZANINE FLOOR - SECTION & FLOOR BUILD-UP" faceW) 0
             "MEZZANINE FLOOR - SECTION & FLOOR BUILD-UP")
  (setvar "CLAYER" prev)
  (setvar "CLAYER" "0")
  (princ))

;; ===========================================================================
;;  THE DELIVERABLE:  A SMALL MEZZANINE DETAIL FOR THE **DETAILS SHEET**
;;
;;  Owner, 1-Sep: "we have to show small detail of mezzanine in the Details
;;  Section for Customer Understanding."
;;
;;  So the destination is `peb-draw-sheeting-details` (Framing.lsp:2985) - the
;;  sheet that already carries the panel profile and the eave gutter - and this
;;  is the block that fills the empty half rule 4B.43 was written about.  It is
;;  the slot the PARKED `peb-sd-mezz-floor` was left holding.
;;
;;  WHAT IT IS NOT: a sheet.  No heading, no title block, no data panel, no notes
;;  - the DETAILS sheet owns all of those.  Above all it does NOT set
;;  *PEB-TEXT-SCALE*: that sheet deliberately sets its own (1000/45000, so ANNOT
;;  plots ~2 mm on a ~1 m detail), and a block that re-scales text inside someone
;;  else's sheet is how one sheet ends up with two lettering sizes (4B.9).  It
;;  ADOPTS the caller's scale instead.
;;
;;  WHAT A CUSTOMER NEEDS TO SEE, and nothing more: what the floor is made of -
;;  concrete on a profiled steel deck, carried on a joist, carried on the main
;;  beam.  Drawn at TRUE size in the DETAILS sheet's own ~1 m space, so the
;;  75 mm slab and 45 mm rib are honest fractions of a 1,400 mm block instead of
;;  hairlines on a building.
;;
;;  Call it as:   (peb-sd-mezz-detail ox oy data)
;; ===========================================================================
(defun peb-sd-mezz-detail (ox oy data / g sys thk jd bd th x0 x1 yb
                                        jt cx above prev)
  (setq prev (getvar "CLAYER"))
  (mzd-layers)
  (mzd-style)
  ;; ADOPT the host sheet's lettering scale - never impose one.
  (setq *MZD-TS* (if (and (boundp '*PEB-TEXT-SCALE*) *PEB-TEXT-SCALE*)
                   *PEB-TEXT-SCALE* 1.0))
  (setq g   (mzd-geom data)
        sys (mzd-g g "SYS") thk (mzd-g g "THK")
        jd  (mzd-g g "JD")  bd  (mzd-g g "BD")
        th  (mzd-h 'ANNOT))
  ;; ---- THE CUT IS THE ACCEPTED ONE (draw-fr-detail, 15-Jul) ----------------
  ;; It runs ALONG a joist, which is what lets the deck show its TRUE corrugation
  ;; - the whole point of the block for a customer.  That cut crosses the MAIN
  ;; BEAM, so the beam is CUT (an I) and the joist is seen in ELEVATION running
  ;; into its web.  The first version of this block cut the JOIST while still
  ;; drawing the corrugation, which cannot both be true of one cut: cutting the
  ;; joists means looking along the ribs, and then the deck is two flat lines.
  (setq x0 ox
        x1 (+ ox (* *MZD-DECK-PITCH* 7.0))     ; ~1,400 - seven ribs reads as a sheet
        yb oy                                  ; TOP OF STEEL
        jt (- oy *MZD-BEAM-TF*)                ; joist top, flush (4B.32)
        cx (- x1 (* *MZD-BEAM-FLANGE* 0.75)))  ; main beam centreline, near the end
  ;; ---- MAIN BEAM, cut.  Its real depth: it is the member the floor stands on.
  (mzd-beam-cut cx yb bd)
  ;; ---- JOIST in elevation, framing into the beam web, top FLUSH (4B.32)
  (if (> jd 0.0)
    (progn
      (mzd-joist-elev x0 (- cx (/ *MZD-BEAM-WEB* 2.0)) jt jd)
      (mzd-clip (- cx (/ *MZD-BEAM-WEB* 2.0)) jt jd)))
  ;; ---- the floor itself: deck in TRUE corrugation, concrete over
  (mzd-topping sys x0 x1 yb thk nil)
  ;; ---- the one dimension a customer checks against the offer
  (mzd-dim-v (+ x1 (* th 0.9)) (+ yb *MZD-DECK-RIB*) (+ yb *MZD-DECK-RIB* thk)
             x1 x1 (mzd-mmft thk))
  ;; ---- L-ladders, short legs, one landing
  (setq above (list (list (+ x0 (* (- x1 x0) 0.88)) (+ yb *MZD-DECK-RIB* (* thk 0.5))
                          (mzd-floor-label sys thk))))
  (setq above (append above
                (list (list cx (- yb (* bd 0.82))
                            (strcat "MAIN BEAM  " (rtos bd 2 0) " DEEP"
                                    (if (mzd-g g "BD-OK") "" "  (INDICATIVE)"))))))
  (if (> jd 0.0)
    (setq above (append above
                  ;; AIM AT THE MEMBER, NOT NEAR IT.  Two arrows were landing
                  ;; wrong: the joist arrow sat exactly on a BOLT (the bolt
                  ;; column and the 0.90-of-width tip resolve to the same x), and
                  ;; the clip-angle arrow pointed at bare joist web a whole
                  ;; flange-width away from the angle.  Both tips are now taken
                  ;; from the geometry that draws those parts - the joist web
                  ;; clear of the bolt column, and the angle's own face - so they
                  ;; cannot drift apart when a size changes.
                  (list (list (+ x0 (* (- cx x0) 0.70)) (- jt (* jd 0.30))
                              (strcat "STEEL JOIST @ " (rtos (mzd-g g "JSP") 2 0)
                                      " C/C - TOP FLUSH"))
                        (list (- cx (/ *MZD-BEAM-WEB* 2.0) (* *MZD-JOIST-WEB* 0.7))
                              (- jt (* jd 0.75))
                              "CLIP ANGLE - BOLTED CONNECTION")))))
  (mzd-callouts above (+ x1 (* th 1.2)))
  ;; ---- the block's own name, in the DETAILS sheet's own idiom
  (setvar "CLAYER" "TEXT")
  (mzd-txt-b "ML" (list x0 (+ yb *MZD-DECK-RIB* thk (* th 2.4))) (mzd-h 'LABEL) 0
             "MEZZANINE FLOOR BUILD-UP")
  (mzd-txt "ML" (list x0 (- yb bd (* th 1.6))) th 0
           "INDICATIVE - PER THE APPROVAL DRAWING.")
  (setvar "CLAYER" prev)
  (princ))

(defun C:PEB-MEZZ-DETAIL ( / dataFile data)
  (vl-load-com)
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup)
    (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (setq dataFile (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*) *PEB-DATA-FILE* nil))
  (if (null dataFile)
    (setq dataFile (getfiled "Select PEB_Data file" "" "txt" 4)))
  (if (null dataFile)
    (princ "\nPEB-MEZZ-DETAIL: no data file.")
    (progn
      (setq data (if (boundp 'MSPL-Read-Data)
                   (MSPL-Read-Data dataFile)
                   (mzd-read-data dataFile)))
      ;; SKIP CLEANLY when the area carries no mezzanine, so the render pipeline
      ;; may call this for EVERY area and only the ones with a mezzanine make a
      ;; sheet - the same guard C:PEB-MEZZ-FLOOR uses.
      (if (/= (strcase (mzd-str data "MZ_TOGGLE")) "YES")
        (progn (princ "\nPEB-MEZZ-DETAIL: no mezzanine on this area - skipped.")
               (setvar "CLAYER" "0"))
        (progn
          (setq *MZD-ERR* (vl-catch-all-apply
                            (function (lambda () (peb-draw-mezz-detail data 0.0 0.0)))))
          (if (vl-catch-all-error-p *MZD-ERR*)
            (progn
              (princ (strcat "
PEB-MEZZ-DETAIL FAILED: " (vl-catch-all-error-message *MZD-ERR*)))
              (vl-catch-all-apply (function (lambda ( / f)
                (setq f (open "C:/maimaar_render/mzd_err.txt" "a"))
                (if f (progn (write-line (vl-catch-all-error-message *MZD-ERR*) f) (close f))))))))
          ;; CLOSE ANYTHING THE FAILURE LEFT OPEN.  A (command ...) that is refused a prompt does
          ;; not raise a LISP error - it just STAYS ACTIVE, and from then on every line of the
          ;; render script is typed into it as input.  That is how one bad option keyword on this
          ;; sheet ate the title block, the plot and the QUIT, and left acad.exe running until the
          ;; pipeline's timeout killed it - a whole page set lost to a sheet that had already
          ;; drawn.  A bare (command) cancels whatever is active, so the sheet finishes and plots
          ;; with whatever it managed to draw, and the failure stays this sheet's problem.
          (vl-catch-all-apply (function (lambda () (command))))
          (vl-catch-all-apply (function (lambda ()
            (peb-frame-and-titleblock data "MEZZANINE FLOOR SECTION"))))
          (vl-catch-all-apply (function (lambda () (command "_.ZOOM" "_E"))))))))
  (princ))

;; Pipeline entry point, shaped exactly like peb-mezz-floor-from-file so wiring it
;; into peb-all-sheets later is one line and no other change.
;; `floorNum` is OPTIONAL and defaults to 1.  The renderer has always passed it - it draws one
;; details sheet per mezzanine floor - but this took a single argument, so every call raised
;; "too many arguments" and the sheet plotted as an EMPTY A4 frame with a title block on it.
;; Nothing said so: the caller wraps the sheet, the error was swallowed, and MEZZANINE SECTION
;; DETAILS came out blank at scale 1:1 (the scale of nothing) on every proposal that had a
;; mezzanine.
(defun peb-mezz-detail-from-file (path floorNum / prev-last prev-max-x)
  (setq *PEB-MEZZ-FLOOR-NUM* (if (and floorNum (> floorNum 0)) floorNum 1))
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE*  1.0))
  (setq prev-last (entlast))
  (setq *PEB-SHEET-MARK* prev-last)
  (if prev-last
    (progn (command "_.REGEN")
           (setq prev-max-x (car (getvar "EXTMAX")))
           (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-MEZZ-DETAIL)
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place)
    (vl-catch-all-apply (function (lambda () (peb-tile-place prev-last prev-max-x)))))
  (princ))

;; PREVIEW the DETAILS-sheet block on its own, under the SAME conditions the
;; DETAILS sheet imposes - its 1000/45000 lettering scale - so what is reviewed
;; here is what will appear there.  Previewing it at any other scale would prove
;; nothing about how it lands on the real sheet.
(defun C:PEB-MEZZ-SD ( / dataFile data)
  (vl-load-com)
  (setvar "CMDECHO" 0)
  (setvar "OSMODE" 0)
  (setq dataFile (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*) *PEB-DATA-FILE* nil))
  (if (null dataFile)
    (setq dataFile (getfiled "Select PEB_Data file" "" "txt" 4)))
  (if (null dataFile)
    (princ "\nPEB-MEZZ-SD: no data file.")
    (progn
      (setq data (if (boundp 'MSPL-Read-Data)
                   (MSPL-Read-Data dataFile)
                   (mzd-read-data dataFile)))
      (if (/= (strcase (mzd-str data "MZ_TOGGLE")) "YES")
        (princ "\nPEB-MEZZ-SD: no mezzanine on this area - skipped.")
        (progn
          (setq *PEB-TEXT-SCALE* (/ 1000.0 45000.0))   ; the DETAILS sheet's own
          (setq *PEB-DIM-SCALE*  *PEB-TEXT-SCALE*)
          (peb-sd-mezz-detail 0.0 0.0 data)
          (vl-catch-all-apply (function (lambda () (command "_.ZOOM" "_E"))))))))
  (princ))

(princ "\nMAIMAAR_PEB_MezzDetail.lsp loaded - MEZZANINE FLOOR SECTION (proposal).")
(princ "\n  Command: PEB-MEZZ-DETAIL     Pipeline: (peb-mezz-detail-from-file <PEB_Data.txt>)")
(princ)
