;; ============================================================================
;;  MAIMAAR_PEB_Cover.lsp  —  Cover sheet (PRO-00) of the Proposal Drawing set
;; ----------------------------------------------------------------------------
;;  Matches the MAMMUT proposal-drawing COVER layout (clean, no side strip):
;;    triple border · large logo + company/contact (top centre) · boxed
;;    "PROPOSAL DRAWING" banner · "PROPOSAL / QUOTE NO." box · bottom TITLE
;;    BLOCK (Customer / Building Name / Project Title / Prepared / Checked /
;;    Date / Rev) · a compact List of Drawings.  All values link to the IF, so
;;    the cover stays consistent with the rest of the set (one source).
;;
;;  Pure entmake (batch-safe under acad /b).  Load AFTER the engine:
;;     (load ".../engine/MAIMAAR_PEB_Section.lsp")
;;     (load ".../engine/MAIMAAR_PEB_Plan.lsp")
;;     (load ".../engine/MAIMAAR_PEB_Cover.lsp")
;;     (peb-cover-from-file "...PEB_Data_B1_A1.txt")   ; or  C:PEB-COVER
;;
;;  Depends on engine helpers: MSPL-Read-Data, MSPL-Get-Str, tb-line/tb-rect/
;;  tb-mtext/tb-fith, peb-tb-place-logo, peb-pretty-date, format-date.
;; ----------------------------------------------------------------------------
;;  LAYOUT RULES  (so the cover is DYNAMIC for any future project & easy to tune)
;;  ------------------------------------------------------------------------
;;  R1 CANVAS-RELATIVE: the sheet is Hc (height) x Wc (width); cx = centre.
;;     EVERY coordinate and text height is a FRACTION of Hc -> the cover is
;;     resolution-independent and looks identical at any plotted size.  To move
;;     a block, change its Y fraction; to resize text, change its height fraction.
;;  R2 ZONES (Y, as fractions of Hc), top -> bottom:
;;        logo 0.772-0.960 · company 0.745 · tagline 0.714 · contact 0.687
;;        accent-rule 0.666 · PROPOSAL-DRAWING banner 0.448-0.642
;;        quote box 0.366-0.424 · bottom blocks 0.045-0.300 · footer 0.022
;;  R3 AUTOFIT (the key rule for variable text): every VARIABLE value is drawn
;;     with  (tb-fith TEXT MAXWIDTH CAPHEIGHT)  -> returns a height so the text
;;     fits MAXWIDTH on ONE line, capped at CAPHEIGHT.  Longer text in a future
;;     project therefore SHRINKS automatically and never overflows its box.
;;        * MAXWIDTH = the cell/box width x a margin factor (0.84-0.95).
;;        * CAPHEIGHT = the desired/maximum height for that field.
;;        * Bold CAPITAL text is wide -> for hero text use MAXWIDTH = inner-box
;;          width and divisor ~0.78 (see the PROPOSAL DRAWING banner).
;;  R4 WRAP rule: a long value that must stay big (the PROJECT TITLE) sits in a
;;     TALLER cell (rt) and is allowed to wrap to 2 lines INSIDE the cell.  To
;;     permit longer titles, increase rt; other rows use the standard rh.
;;  R5 ALL TEXT IS UPPERCASE: IF values are passed through (strcase ...); static
;;     text is written in capitals.
;;  R6 COLOURS (ACI): white 7 = lines/hero text · blue 5 = company name ·
;;     green 3 = brand accent + live IF values · grey 8 = field labels ·
;;     red 1 = NOT-FOR-CONSTRUCTION.  Inner border = green (brand frame).
;;  R7 To tune ONE field, change only its CAPHEIGHT (size) or its zone fraction
;;     (position) -- nothing else depends on it.  No values are hard-typed; they
;;     all come from the IF, so a different project just flows through.
;; ============================================================================

(defun peb-cover-draw (data / white grey green blue red cx Hc Wc get
                            bx0 bx1 by0 by1 tx0 tx1 lx0 lx1 mid rh rt y1 y2 y3 y4 y5 yy
                            proj cust bname loc quote rev dat drn chk propinput propno
                            bno ident nbld i sheets pitch sh blind nSh avail shH)
  ;; Colours come from the shared Presentation Standards DB (*PEB-COLORS* via
  ;; peb-color) when MAIMAAR_PEB_Standard.lsp is loaded, so the cover stays in
  ;; lock-step with the plan/section palette; otherwise use the R6 literals.
  (if (boundp 'peb-color)
    (setq white (peb-color 'WHITE) grey (peb-color 'GREY) green (peb-color 'GREEN)
          blue  (peb-color 'BLUE)  red  (peb-color 'RED))
    (setq white 7 grey 8 green 3 blue 5 red 1))
  ;; owner UNIVERSAL STANDING RULE 22-Jul: ALL cover text = ROMAND (romand.shx), no mixing.  ROOT CAUSE of the
  ;; recurring "mixed / not-romand" cover: the cover created NO text styles, so tb-mtext's request for the
  ;; "ROMAND" style silently fell back to the template "Standard" style = arial.ttf, and AutoCAD does NOT honour
  ;; an SHX \Fromand.shx override on a TrueType base style — so every field drifted back to Arial.
  ;; FIX (make the BASE style genuinely romand so it cannot drift):
  ;;   (a) create/repoint "ROMAND"   -> romand.shx  (the style tb-mtext draws in),
  ;;   (b) repoint  the  "Standard"  -> romand.shx upright (any fallback / plain text is romand too),
  ;;   (c) FONTALT -> romand.shx (any missing-font substitution also lands on romand).
  (foreach pr '(("ROMAND" . "romand.shx") ("Standard" . "romand.shx"))
    (vl-catch-all-apply
      (function (lambda ( / nm fn so sd)
        (setq nm (car pr) fn (cdr pr))
        (if (tblsearch "STYLE" nm)
          (progn (setq so (tblobjname "STYLE" nm) sd (entget so))
                 (if (assoc 3  sd) (setq sd (subst (cons 3 fn)  (assoc 3 sd)  sd)))
                 (if (assoc 4  sd) (setq sd (subst (cons 4 "")   (assoc 4 sd)  sd)))
                 (if (assoc 50 sd) (setq sd (subst (cons 50 0.0) (assoc 50 sd) sd)))
                 (entmod sd) (entupd so))
          (entmake (list '(0 . "STYLE") '(100 . "AcDbSymbolTableRecord")
                         '(100 . "AcDbTextStyleTableRecord") (cons 2 nm)
                         '(70 . 0) '(40 . 0.0) '(41 . 1.0) '(50 . 0.0) '(71 . 0) '(42 . 2.5)
                         (cons 3 fn) (cons 4 ""))))))))
  (vl-catch-all-apply (function (lambda () (setvar "FONTALT" "romand.shx"))))
  (defun get (k) (MSPL-Get-Str data k))
  ;; BLIND version toggle (drawings only) — see peb-blind-p in Standard.lsp.
  (setq blind (peb-blind-p data))
  (setq Hc 29700.0 Wc 42000.0 cx (/ Wc 2.0))
  ;; ---- values (IF-linked) ----
  (setq proj (get "PROJECT"))  (if (= proj "") (setq proj "UNNAMED PROJECT"))
  (setq cust (get "CLIENT"))   (if (= cust "") (setq cust "UNNAMED CLIENT"))
  (setq bname (get "TBBLDGNAME"))
  (setq loc  (get "LOCATION"))
  ;; owner STANDING RULE 22-Jul: the proposal reference is ALWAYS the BSF reference verbatim (looks like
  ;; MSPL-26-000).  The BSF sends it as HD_PROPOSAL_NO -> carried through UNTOUCHED as PROPOSAL_FULL (the
  ;; "PROPOSAL" key is digits-only, which mangles "MSPL-26-000" into "26000" - do NOT use it here).  Fallback,
  ;; only if the BSF sent nothing: build MSPL-26-<3-digit serial> from the digits.
  (setq quote (get "PROPOSAL_FULL"))
  (if (= quote "")
    (progn (setq propinput (get "PROPOSAL")) (if (= propinput "") (setq propinput "0"))
           (while (< (strlen propinput) 3) (setq propinput (strcat "0" propinput)))
           (setq quote (strcat "MSPL-26-" propinput))))
  (setq quote (strcase quote) propno quote)
  (setq rev (get "REVNO")) (if (or (= rev "0") (= rev "")) (setq rev "00"))
  (setq drn (get "TBDRN")) (if (= drn "") (setq drn "M.H"))
  (setq chk (get "TBCHK")) (if (= chk "") (setq chk "YEA"))
  (setq dat (get "TBDATE"))
  (if (= dat "") (setq dat (format-date (getvar "CDATE"))) (setq dat (peb-pretty-date dat)))
  (if (= bname "") (setq bname (strcat "BUILDING " (get "BLDGNO"))))
  (if (= bname "BUILDING ") (setq bname "BUILDING 01"))
  ;; building no. (zero-padded) + no. of identical buildings
  (setq bno (get "BLDGNO")) (if (= bno "") (setq bno "1"))
  (if (= (strlen bno) 1) (setq bno (strcat "0" bno)))
  (setq ident (get "IDENTICAL")) (if (= ident "") (setq ident "1"))
  (if (= (strlen ident) 1) (setq ident (strcat "0" ident)))
  ;; ALL text CAPITAL
  (setq proj (strcase proj) cust (strcase cust) bname (strcase bname)
        loc (strcase loc) quote (strcase quote) dat (strcase dat)
        drn (strcase drn) chk (strcase chk))

  ;; owner 5-Jul: THIN cover lines like Roshan — set layer 0 (all cover lines are BYLAYER on it) to a
  ;; fine 0.09 mm lineweight so the border/boxes render thin instead of the default 0.25 mm.
  (vl-catch-all-apply (function (lambda ()
    (vl-load-com)
    (vla-put-Lineweight
      (vla-item (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object))) "0") 9))))
  ;; ---- triple border (Mammut) : outer white x2 + inner BRAND-GREEN accent (modern) ----
  (tb-rect 0 0 Wc Hc white)
  (tb-rect (* Hc 0.010) (* Hc 0.010) (- Wc (* Hc 0.010)) (- Hc (* Hc 0.010)) white)
  (tb-rect (* Hc 0.017) (* Hc 0.017) (- Wc (* Hc 0.017)) (- Hc (* Hc 0.017)) green)

  ;; ---- logo + company + contact (top, centred) + accent rule ----
  (peb-tb-place-logo (- cx (* Hc 0.33)) (* Hc 0.772) (+ cx (* Hc 0.33)) (* Hc 0.960))
  (tb-mtext-bold cx (* Hc 0.745)
            (tb-fith "MAIMAAR STEEL (PVT) LTD" (* Wc 0.55) (* Hc 0.034)) (* Wc 0.9) 5
            "{\\Fromand.shx;MAIMAAR STEEL (PVT) LTD}" blue)
  ;; owner 22-Jul: give the top stack breathing room (the bold company name needs air; the 2-line contact block
  ;; was crowding the tagline) — tagline 0.714->0.711, contact 0.687->0.680, accent rule 0.666->0.660.
  (tb-mtext cx (* Hc 0.711)
            (tb-fith "PRE-ENGINEERED STEEL BUILDINGS" (* Wc 0.46) (* Hc 0.016)) (* Wc 0.9) 5
            "{\\Fromand.shx;PRE-ENGINEERED STEEL BUILDINGS}" green)
  (tb-mtext cx (* Hc 0.680)
    (tb-fith "WEB: WWW.MAIMAARGROUP.COM      E-MAIL: MAIMAAR.ENGINEERS@GMAIL.COM      CELL: +(92-300) 807 4007"
             (* Wc 0.90) (* Hc 0.0105)) (* Wc 0.9) 5
    (strcat "238, FIRST FLOOR, LALAZAR COMMERCIAL AREA, RAIWIND ROAD, LAHORE, PAKISTAN\\P"
            "WEB: WWW.MAIMAARGROUP.COM      E-MAIL: MAIMAAR.ENGINEERS@GMAIL.COM      CELL: +(92-300) 807 4007")
    white)
  (tb-line (- cx (* Hc 0.36)) (* Hc 0.660) (+ cx (* Hc 0.36)) (* Hc 0.660) green)

  ;; ---- PROPOSAL DRAWING banner (LARGE double box - the cover hero) ----
  (setq bx0 (- cx (* Hc 0.55)) bx1 (+ cx (* Hc 0.55)) by0 (* Hc 0.448) by1 (* Hc 0.642))
  (tb-rect bx0 by0 bx1 by1 white)
  (tb-rect (+ bx0 (* Hc 0.012)) (+ by0 (* Hc 0.012))
           (- bx1 (* Hc 0.012)) (- by1 (* Hc 0.012)) white)
  ;; fit the hero text WELL INSIDE the inner box (bold caps are wide -> use the
  ;; inner width and a conservative factor so it never touches the box lines)
  ;; owner 5-Jul: fit the hero text via tb-fith on the INNER box (width*0.64 covers bold-caps advance;
  ;; height*0.72 keeps clear of the top/bottom lines) so it can NEVER spill past the double-line box.
  ;; owner 22-Jul: the MAIN TITLE is BOLD (still romand) — tb-mtext-bold draws the romand strokes at a heavier
  ;; 0.50mm pen (romand.shx has no TrueType bold, so bold = heavier pen).
  (tb-mtext-bold cx (* Hc 0.545)
            (tb-fith "PROPOSAL DRAWING"
                     (* (- (- bx1 bx0) (* Hc 0.024)) 0.50)   ; bold ALL-CAPS advance ~1.0 -> conservative, clear margin
                     (* (- (- by1 by0) (* Hc 0.024)) 0.72))
            (- (- bx1 bx0) (* Hc 0.024)) 5
            "{\\Fromand.shx;PROPOSAL DRAWING}" white)

  ;; ---- PROPOSAL / QUOTE NO. box ----
  ;; owner 22-Jul: re-centre the box in the hero->blocks span (was hugging the hero at 0.366-0.424 with a big
  ;; void beneath) so the gap above and below is balanced; and BOLD it (sub-heading tier — a key identifier).
  (setq bx0 (- cx (* Hc 0.35)) bx1 (+ cx (* Hc 0.35)) by0 (* Hc 0.345) by1 (* Hc 0.403))
  (tb-rect bx0 by0 bx1 by1 white)
  (tb-mtext-bold cx (* Hc 0.374)
            (tb-fith (strcat "PROPOSAL / QUOTE NO. :   " quote) (* (- bx1 bx0) 0.92) (* Hc 0.022))
            (- bx1 bx0) 5 (strcat "{\\Fromand.shx;PROPOSAL / QUOTE NO. :   " quote "}") green)

  ;; ---- bottom-right TITLE BLOCK (Mammut) : non-uniform rows, PROJECT row taller ----
  (setq tx0 (* Wc 0.40) tx1 (* Wc 0.965) by0 (* Hc 0.045) by1 (* Hc 0.300)
        mid (/ (+ tx0 tx1) 2.0))
  (setq rh (* (- by1 by0) 0.155)   ; standard row height (5 rows)
        rt (* (- by1 by0) 0.225))  ; taller PROJECT TITLE row (2-line wrap)
  (tb-rect tx0 by0 tx1 by1 white)
  (setq y1 (- by1 rh)        ; under CUSTOMER
        y2 (- y1 rh)         ; under BUILDING NAME
        y3 (- y2 rt)         ; under PROJECT TITLE
        y4 (- y3 rh)         ; under BLDG NO. / IDENTICAL
        y5 (- y4 rh))        ; under PREPARED/CHECKED  (DATE/REV ends at by0)
  (tb-line tx0 y1 tx1 y1 white)
  (tb-line tx0 y2 tx1 y2 white)
  (tb-line tx0 y3 tx1 y3 white)
  (tb-line tx0 y4 tx1 y4 white)
  (tb-line tx0 y5 tx1 y5 white)
  (tb-line mid by0 mid y3 white)   ; vertical split for the 3 lower split rows
  ;; row helpers (label small at top; value autofit below, on ONE line)
  ;; owner 22-Jul: field LABELS (fixed text) get a light-medium 0.25mm pen (370=25) so they read as structure
  ;; above the thin dynamic values (monochrome plot: only lineweight differentiates).  Shared +Hc*0.010 left
  ;; margin so the label and its value LEFT-ALIGN (was 0.008 label vs 0.012 value = a ~119u stagger per cell).
  (defun cov-lab (x ytop s)
    (entmake (list (cons 0 "MTEXT") (cons 100 "AcDbEntity") (cons 8 "0")
                   (cons 62 grey) (cons 370 25) (cons 100 "AcDbMText")
                   (list 10 (+ x (* Hc 0.010)) (- ytop (* Hc 0.0090)) 0.0)
                   (cons 40 (* Hc 0.0084)) (cons 41 0)
                   (cons 71 4) (cons 7 "ROMAND")
                   (cons 1 (strcat "{\\Fromand.shx;" s "}")) (cons 50 0.0))))
  ;; owner STANDING RULE 22-Jul (NO OVERLAP): the value sits on ONE line BELOW the label, inside the cell.
  ;; A short value grows large; a long value SHRINKS to fit the cell width with margin so it NEVER wraps and
  ;; NEVER runs into the label above or the next row below.  h = min(cell value-zone height, one-line width fit).
  ;; boxw = cell width less L/R margin; width divisor 0.95 keeps the text ~10% inside the box so it can't wrap.
  (defun cov-val (x w ytop rhh s / boxw h)
    (setq boxw (- w (* Hc 0.024)))
    (setq h (min (* rhh 0.40)
                 (/ boxw (* (max 1.0 (float (strlen s))) 0.95))))
    (tb-mtext (+ x (* Hc 0.010)) (- ytop (* rhh 0.64)) h boxw 4
              (strcat "{\\Fromand.shx;" s "}") green))
  ;; PROJECT TITLE: a long multi-word title WRAPS to fill its taller cell BELOW the label without overrunning.
  ;; AREA-FILL sizing: h ~ sqrt(cellArea / (chars x advance-x-linespacing)) picks a height that balances the
  ;; text across however many lines fit — so it never blows up to 3 tall lines that spill into the label/next
  ;; row.  Capped at 0.34x the zone so a short title stays one readable line.  romand advance x spacing ~ 1.6.
  (defun cov-val2 (x w ytop rhh s / boxw zoneH h)
    (setq boxw (- w (* Hc 0.024)) zoneH (- rhh (* Hc 0.020)))
    (setq h (min (* zoneH 0.34)
                 (sqrt (/ (* boxw zoneH) (* (max 1.0 (float (strlen s))) 1.6)))))
    (tb-mtext (+ x (* Hc 0.010)) (- ytop (* rhh 0.60)) h boxw 4
              (strcat "{\\Fromand.shx;" s "}") green))
  ;; owner 22/23-Jul: BLIND toggle.  When *PEB-BLIND* is set (the "for estimate" version sent to outside
  ;; fabricators/estimators), the CUSTOMER and PROJECT TITLE (subject) are left blank so the client isn't
  ;; revealed — MAIMAAR's proposal branding stays prominent.  Default (nil) = full customer version.
  (cov-lab tx0 by1 "CUSTOMER :")             (cov-val tx0 (- tx1 tx0) by1 rh (if blind "" cust))
  (cov-lab tx0 y1  "BUILDING NAME :")        (cov-val tx0 (- tx1 tx0) y1  rh bname)
  (cov-lab tx0 y2  "PROJECT TITLE :")        (cov-val2 tx0 (- tx1 tx0) y2  rt (if blind "" proj))
  (cov-lab tx0 y3  "BLDG. NO. :")            (cov-val tx0 (- mid tx0) y3 rh bno)
  (cov-lab mid y3  "NO. OF IDENTICAL BLDGS. :") (cov-val mid (- tx1 mid) y3 rh ident)
  (cov-lab tx0 y4  "PREPARED BY :")          (cov-val tx0 (- mid tx0) y4 rh drn)
  (cov-lab mid y4  "CHECKED BY :")           (cov-val mid (- tx1 mid) y4 rh chk)
  (cov-lab tx0 y5  "DATE :")                 (cov-val tx0 (- mid tx0) y5 rh dat)
  (cov-lab mid y5  "REV :")                  (cov-val mid (- tx1 mid) y5 rh rev)

  ;; ---- bottom-left LIST OF DRAWINGS (compact, balances the title block) ----
  (setq lx0 (* Wc 0.035) lx1 (* Wc 0.385) by0 (* Hc 0.045) by1 (* Hc 0.300))
  (tb-rect lx0 by0 lx1 by1 white)
  (tb-line lx0 (- by1 (* Hc 0.030)) lx1 (- by1 (* Hc 0.030)) white)
  ;; owner 22-Jul: BOLD the header (sub-heading tier), centred in its band (was ~178u low: 0.021 -> 0.015).
  (tb-mtext-bold (/ (+ lx0 lx1) 2.0) (- by1 (* Hc 0.015)) (* Hc 0.014) (- lx1 lx0) 5
            "{\\Fromand.shx;LIST OF DRAWINGS}" white)
  ;; owner 22-Jul: ONE cover page = ONE building.  The list is the DRAWING SHEETS of THIS building's set,
  ;; numbered 00 = cover then 01.. matching the title-block SHEET NO. (PRO-0N) — NOT a list of buildings.
  ;; 28-Jul: the shipped A4 set = Cover + CLP + Cross Section + Side/End Framing + Side/End Sheeting; the
  ;; framing & sheeting split side/end so each elevation prints large on A4.  Number green, title white.
  ;; THE LIST MUST BE THE SHEETS ACTUALLY IN THIS FILE (owner 26-Aug).  Hard-coded, it
  ;; listed SIDE/END WALL sheets for a building whose file holds ONE combined elevation
  ;; sheet, never mentioned the two roof plans, and ignored the extra sheets a multi-area
  ;; building gets.  drawingData now derives *PEB-SHEET-LIST* from the very calls it is
  ;; about to emit, so the index and the file are the same thing by construction.
  ;; The literal below is only the fallback for a hand-run cover with no list set.
  (setq sheets (if (and (boundp '*PEB-SHEET-LIST*) *PEB-SHEET-LIST*)
                 *PEB-SHEET-LIST*
                 (list '("00" "COVER SHEET")
                       '("01" "COLUMN LAYOUT PLAN")
                       '("02" "CROSS SECTION")
                       '("03" "SIDE WALL FRAMING ELEVATIONS")
                       '("04" "END WALL FRAMING ELEVATIONS")
                       '("05" "SIDE WALL SHEETING ELEVATIONS")
                       '("06" "END WALL SHEETING ELEVATIONS"))))
  ;; THE LIST MUST FIT ITS BOX (owner 26-Aug).  The pitch was a fixed 0.030*Hc, which
  ;; holds exactly seven rows - the length of the old hard-coded list.  The moment the
  ;; list became real, a nine-sheet building (the two roof plans) ran rows 07 and 08 out
  ;; through the bottom border and across the footer, and a two-area building would push
  ;; thirteen.  Pitch and text now divide the box by the row count, capped at the old
  ;; values so a short list looks exactly as it did.
  (setq nSh   (length sheets)
        avail (- (- by1 (* Hc 0.052)) by0)
        pitch (min (* Hc 0.030) (/ avail (max 1 nSh)))
        shH   (min (* Hc 0.0120) (* pitch 0.42)))
  (setq yy (- by1 (* Hc 0.052)))
  (foreach sh sheets
    (tb-mtext (+ lx0 (* Hc 0.012)) yy shH 0 4 (car sh) green)
    (tb-mtext (+ lx0 (* Hc 0.075)) yy
              (tb-fith (cadr sh) (- lx1 (+ lx0 (* Hc 0.082))) shH) 0 4
              (cadr sh) white)
    (setq yy (- yy pitch)))

  ;; ---- footer note (in the bottom margin, clear of the boxes + border) ----
  (tb-mtext cx (* Hc 0.031)
            (tb-fith "PROPOSAL DRAWING  -  NOT FOR CONSTRUCTION" (* Wc 0.55) (* Hc 0.0105)) (* Wc 0.9) 5
            "{\\Fromand.shx;PROPOSAL DRAWING  -  NOT FOR CONSTRUCTION}" red)
  (princ))

;; non-interactive entry (mirrors peb-section-from-file)
(defun peb-cover-from-file (path / data)
  (setq data (MSPL-Read-Data path))
  (if data
    (peb-cover-draw data)
    (alert (strcat "Cover: could not read PEB_Data file:\n" path)))
  (princ))

;; interactive entry
(defun C:PEB-COVER ( / path)
  (setq path (getfiled "Select PEB_Data file for the cover sheet" "" "txt" 16))
  (if path (peb-cover-from-file path))
  (princ))

(princ "\nMAIMAAR_PEB_Cover.lsp loaded - run  C:PEB-COVER  or (peb-cover-from-file \"...txt\").")
(princ)
