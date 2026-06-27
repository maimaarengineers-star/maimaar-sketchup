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
;; ============================================================================

(defun peb-cover-draw (data / white grey green blue red cx Hc Wc get
                            bx0 bx1 by0 by1 tx0 tx1 lx0 lx1 mid rh rt y1 y2 y3 y4 yy
                            proj cust bname loc quote rev dat drn chk propinput propno)
  (setq white 7 grey 8 green 3 blue 5 red 1)
  (defun get (k) (MSPL-Get-Str data k))
  (setq Hc 29700.0 Wc 42000.0 cx (/ Wc 2.0))
  ;; ---- values (IF-linked) ----
  (setq proj (get "PROJECT"))  (if (= proj "") (setq proj "UNNAMED PROJECT"))
  (setq cust (get "CLIENT"))   (if (= cust "") (setq cust "UNNAMED CLIENT"))
  (setq bname (get "TBBLDGNAME"))
  (setq loc  (get "LOCATION"))
  (setq propinput (get "PROPOSAL")) (if (= propinput "") (setq propinput "000"))
  (setq propno (strcat "MSPL-26-" propinput))
  (setq quote (get "PROPOSAL_FULL"))
  (if (= quote "")
    (cond ((and (= (strlen propinput) 5) (wcmatch propinput "#####"))
           (setq quote (strcat "MSPL-" (substr propinput 1 2) "-" (substr propinput 3))))
          (T (setq quote propno))))
  (setq rev (get "REVNO")) (if (or (= rev "0") (= rev "")) (setq rev "00"))
  (setq drn (get "TBDRN")) (if (= drn "") (setq drn "M.H"))
  (setq chk (get "TBCHK")) (if (= chk "") (setq chk "YEA"))
  (setq dat (get "TBDATE"))
  (if (= dat "") (setq dat (format-date (getvar "CDATE"))) (setq dat (peb-pretty-date dat)))
  (if (= bname "") (setq bname (strcat "BUILDING " (get "BLDGNO"))))
  (if (= bname "BUILDING ") (setq bname "BUILDING 01"))
  ;; ALL text CAPITAL
  (setq proj (strcase proj) cust (strcase cust) bname (strcase bname)
        loc (strcase loc) quote (strcase quote) dat (strcase dat)
        drn (strcase drn) chk (strcase chk))

  ;; ---- triple border (Mammut) ----
  (tb-rect 0 0 Wc Hc white)
  (tb-rect (* Hc 0.010) (* Hc 0.010) (- Wc (* Hc 0.010)) (- Hc (* Hc 0.010)) white)
  (tb-rect (* Hc 0.017) (* Hc 0.017) (- Wc (* Hc 0.017)) (- Hc (* Hc 0.017)) white)

  ;; ---- logo + company + contact (top, centred) ----
  (peb-tb-place-logo (- cx (* Hc 0.30)) (* Hc 0.775) (+ cx (* Hc 0.30)) (* Hc 0.948))
  (tb-mtext cx (* Hc 0.748)
            (tb-fith "MAIMAAR STEEL (PVT) LTD" (* Wc 0.50) (* Hc 0.030)) (* Wc 0.9) 5
            "{\\fArial|b1;MAIMAAR STEEL (PVT) LTD}" blue)
  (tb-mtext cx (* Hc 0.719)
            (tb-fith "PRE-ENGINEERED STEEL BUILDINGS" (* Wc 0.45) (* Hc 0.015)) (* Wc 0.9) 5
            "{\\fArial|b1;PRE-ENGINEERED STEEL BUILDINGS}" green)
  (tb-mtext cx (* Hc 0.690)
    (tb-fith "WEB: WWW.MAIMAARGROUP.COM      E-MAIL: MAIMAAR.ENGINEERS@GMAIL.COM      CELL: +(92-300) 807 4007"
             (* Wc 0.90) (* Hc 0.0105)) (* Wc 0.9) 5
    (strcat "238, FIRST FLOOR, LALAZAR COMMERCIAL AREA, RAIWIND ROAD, LAHORE, PAKISTAN\\P"
            "WEB: WWW.MAIMAARGROUP.COM      E-MAIL: MAIMAAR.ENGINEERS@GMAIL.COM      CELL: +(92-300) 807 4007")
    white)

  ;; ---- PROPOSAL DRAWING banner (double box, big) ----
  (setq bx0 (- cx (* Hc 0.46)) bx1 (+ cx (* Hc 0.46)) by0 (* Hc 0.468) by1 (* Hc 0.606))
  (tb-rect bx0 by0 bx1 by1 white)
  (tb-rect (+ bx0 (* Hc 0.010)) (+ by0 (* Hc 0.010))
           (- bx1 (* Hc 0.010)) (- by1 (* Hc 0.010)) white)
  (tb-mtext cx (* Hc 0.510)
            (tb-fith "PROPOSAL DRAWING" (* (- bx1 bx0) 0.88) (* Hc 0.066)) (* Hc 1.7) 5
            "{\\fArial|b1;PROPOSAL DRAWING}" white)

  ;; ---- PROPOSAL / QUOTE NO. box ----
  (setq bx0 (- cx (* Hc 0.31)) bx1 (+ cx (* Hc 0.31)) by0 (* Hc 0.392) by1 (* Hc 0.442))
  (tb-rect bx0 by0 bx1 by1 white)
  (tb-mtext cx (* Hc 0.410)
            (tb-fith (strcat "PROPOSAL / QUOTE NO. :   " quote) (* (- bx1 bx0) 0.92) (* Hc 0.020))
            (- bx1 bx0) 5 (strcat "{\\fArial|b1;PROPOSAL / QUOTE NO. :   " quote "}") green)

  ;; ---- bottom-right TITLE BLOCK (Mammut) : non-uniform rows, PROJECT row taller ----
  (setq tx0 (* Wc 0.40) tx1 (* Wc 0.965) by0 (* Hc 0.045) by1 (* Hc 0.300)
        mid (/ (+ tx0 tx1) 2.0))
  (setq rh (* (- by1 by0) 0.185)   ; standard row height
        rt (* (- by1 by0) 0.260))  ; taller PROJECT TITLE row (2-line wrap)
  (tb-rect tx0 by0 tx1 by1 white)
  (setq y1 (- by1 rh)        ; under CUSTOMER
        y2 (- y1 rh)         ; under BUILDING NAME
        y3 (- y2 rt)         ; under PROJECT TITLE
        y4 (- y3 rh))        ; under PREPARED/CHECKED  (DATE/REV ends at by0)
  (tb-line tx0 y1 tx1 y1 white)
  (tb-line tx0 y2 tx1 y2 white)
  (tb-line tx0 y3 tx1 y3 white)
  (tb-line tx0 y4 tx1 y4 white)
  (tb-line mid by0 mid y3 white)   ; vertical split for the last 2 rows
  ;; row helpers (label small grey at top; value bold green, autofit, wraps in tall rows)
  (defun cov-lab (x ytop s)
    (tb-mtext (+ x (* Hc 0.008)) (- ytop (* Hc 0.010)) (* Hc 0.0090) 0 4 s grey))
  (defun cov-val (x w ytop rhh s)
    (tb-mtext (+ x (* Hc 0.010)) (- ytop (* rhh 0.60))
              (tb-fith s (* w 0.92) (* Hc 0.0150)) (* w 0.92) 4
              (strcat "{\\fArial|b1;" s "}") green))
  (cov-lab tx0 by1 "CUSTOMER :")        (cov-val tx0 (- tx1 tx0) by1 rh cust)
  (cov-lab tx0 y1  "BUILDING NAME :")   (cov-val tx0 (- tx1 tx0) y1  rh bname)
  (cov-lab tx0 y2  "PROJECT TITLE :")   (cov-val tx0 (- tx1 tx0) y2  rt proj)
  (cov-lab tx0 y3  "PREPARED BY :")     (cov-val tx0 (- mid tx0) y3 rh drn)
  (cov-lab mid y3  "CHECKED BY :")      (cov-val mid (- tx1 mid) y3 rh chk)
  (cov-lab tx0 y4  "DATE :")            (cov-val tx0 (- mid tx0) y4 rh dat)
  (cov-lab mid y4  "REV :")             (cov-val mid (- tx1 mid) y4 rh rev)

  ;; ---- bottom-left LIST OF DRAWINGS (compact, balances the title block) ----
  (setq lx0 (* Wc 0.035) lx1 (* Wc 0.385) by0 (* Hc 0.045) by1 (* Hc 0.300))
  (tb-rect lx0 by0 lx1 by1 white)
  (tb-line lx0 (- by1 (* Hc 0.030)) lx1 (- by1 (* Hc 0.030)) white)
  (tb-mtext (/ (+ lx0 lx1) 2.0) (- by1 (* Hc 0.021)) (* Hc 0.014) (- lx1 lx0) 5
            "{\\fArial|b1;LIST OF DRAWINGS}" white)
  (setq yy (- by1 (* Hc 0.054)))
  (foreach d (list (list "PRO-00" "COVER SHEET")
                   (list "PRO-01" "COLUMN LAY-OUT PLAN")
                   (list "PRO-02" "CROSS SECTION"))
    (tb-mtext (+ lx0 (* Hc 0.012)) yy (* Hc 0.0125) 0 4 (car d) green)
    (tb-mtext (+ lx0 (* Hc 0.082)) yy
              (tb-fith (cadr d) (- lx1 (+ lx0 (* Hc 0.090))) (* Hc 0.0125)) 0 4 (cadr d) white)
    (setq yy (- yy (* Hc 0.030))))

  ;; ---- footer note (in the bottom margin, clear of the boxes + border) ----
  (tb-mtext cx (* Hc 0.031)
            (tb-fith "PROPOSAL DRAWING  -  NOT FOR CONSTRUCTION" (* Wc 0.55) (* Hc 0.0105)) (* Wc 0.9) 5
            "{\\fArial|b1;PROPOSAL DRAWING  -  NOT FOR CONSTRUCTION}" red)
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
