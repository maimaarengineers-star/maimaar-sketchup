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
                            bx0 bx1 by0 by1 tx0 tx1 lx0 lx1 mid rh yy
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

  ;; ---- triple border (Mammut) ----
  (tb-rect 0 0 Wc Hc white)
  (tb-rect (* Hc 0.010) (* Hc 0.010) (- Wc (* Hc 0.010)) (- Hc (* Hc 0.010)) white)
  (tb-rect (* Hc 0.017) (* Hc 0.017) (- Wc (* Hc 0.017)) (- Hc (* Hc 0.017)) white)

  ;; ---- logo + company + contact (top, centred) ----
  (peb-tb-place-logo (- cx (* Hc 0.30)) (* Hc 0.775) (+ cx (* Hc 0.30)) (* Hc 0.948))
  (tb-mtext cx (* Hc 0.748) (* Hc 0.030) (* Wc 0.9) 5
            "{\\fArial|b1;MAIMAAR STEEL (PVT) LTD}" blue)
  (tb-mtext cx (* Hc 0.719) (* Hc 0.015) (* Wc 0.9) 5
            "{\\fArial|b1;PRE-ENGINEERED STEEL BUILDINGS}" green)
  (tb-mtext cx (* Hc 0.690) (* Hc 0.0105) (* Wc 0.9) 5
    (strcat "238, First Floor, Lalazar Commercial Area, Raiwind Road, Lahore, Pakistan\\P"
            "Web: www.maimaargroup.com      E-mail: maimaar.engineers@gmail.com      Cell: +(92-300) 807 4007")
    white)

  ;; ---- PROPOSAL DRAWING banner (double box, big) ----
  (setq bx0 (- cx (* Hc 0.46)) bx1 (+ cx (* Hc 0.46)) by0 (* Hc 0.468) by1 (* Hc 0.606))
  (tb-rect bx0 by0 bx1 by1 white)
  (tb-rect (+ bx0 (* Hc 0.010)) (+ by0 (* Hc 0.010))
           (- bx1 (* Hc 0.010)) (- by1 (* Hc 0.010)) white)
  (tb-mtext cx (* Hc 0.510) (* Hc 0.066) (* Hc 1.7) 5 "{\\fArial|b1;PROPOSAL DRAWING}" white)

  ;; ---- PROPOSAL / QUOTE NO. box ----
  (setq bx0 (- cx (* Hc 0.31)) bx1 (+ cx (* Hc 0.31)) by0 (* Hc 0.392) by1 (* Hc 0.442))
  (tb-rect bx0 by0 bx1 by1 white)
  (tb-mtext cx (* Hc 0.410)
            (tb-fith (strcat "PROPOSAL / QUOTE NO. :   " quote) (* (- bx1 bx0) 0.92) (* Hc 0.020))
            (- bx1 bx0) 5 (strcat "{\\fArial|b1;PROPOSAL / QUOTE NO. :   " quote "}") green)

  ;; ---- bottom-right TITLE BLOCK (Mammut) ----
  (setq tx0 (* Wc 0.40) tx1 (* Wc 0.965) by0 (* Hc 0.045) by1 (* Hc 0.300)
        mid (/ (+ tx0 tx1) 2.0) rh (/ (- (* Hc 0.300) (* Hc 0.045)) 5.0))
  (tb-rect tx0 by0 tx1 by1 white)
  (tb-line tx0 (- by1 rh)         tx1 (- by1 rh) white)         ; under CUSTOMER
  (tb-line tx0 (- by1 (* rh 2.0)) tx1 (- by1 (* rh 2.0)) white) ; under BUILDING NAME
  (tb-line tx0 (- by1 (* rh 3.0)) tx1 (- by1 (* rh 3.0)) white) ; under PROJECT TITLE
  (tb-line tx0 (- by1 (* rh 4.0)) tx1 (- by1 (* rh 4.0)) white) ; under PREPARED/CHECKED
  (tb-line mid (+ by0 (* rh 0.0)) mid (- by1 (* rh 3.0)) white) ; vertical split (last 2 rows)
  ;; row helper values
  (defun cov-lab (x ytop s) (tb-mtext (+ x (* Hc 0.008)) (- ytop (* Hc 0.010)) (* Hc 0.0090) 0 4 s grey))
  (defun cov-val (x w ytop s)
    (tb-mtext (+ x (* Hc 0.010)) (- ytop (* rh 0.64))
              (tb-fith s (* w 0.92) (* Hc 0.0150)) (* w 0.92) 4
              (strcat "{\\fArial|b1;" s "}") green))
  ;; CUSTOMER
  (cov-lab tx0 by1 "CUSTOMER :")            (cov-val tx0 (- tx1 tx0) by1 cust)
  ;; BUILDING NAME
  (cov-lab tx0 (- by1 rh) "BUILDING NAME :")(cov-val tx0 (- tx1 tx0) (- by1 rh) bname)
  ;; PROJECT TITLE
  (cov-lab tx0 (- by1 (* rh 2.0)) "PROJECT TITLE :")
  (cov-val tx0 (- tx1 tx0) (- by1 (* rh 2.0)) proj)
  ;; PREPARED BY | CHECKED BY
  (cov-lab tx0 (- by1 (* rh 3.0)) "PREPARED BY :") (cov-val tx0 (- mid tx0) (- by1 (* rh 3.0)) drn)
  (cov-lab mid (- by1 (* rh 3.0)) "CHECKED BY :")  (cov-val mid (- tx1 mid) (- by1 (* rh 3.0)) chk)
  ;; DATE | REV
  (cov-lab tx0 (- by1 (* rh 4.0)) "DATE :") (cov-val tx0 (- mid tx0) (- by1 (* rh 4.0)) dat)
  (cov-lab mid (- by1 (* rh 4.0)) "REV :")  (cov-val mid (- tx1 mid) (- by1 (* rh 4.0)) rev)

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
    (tb-mtext (+ lx0 (* Hc 0.082)) yy (* Hc 0.0125) 0 4 (cadr d) white)
    (setq yy (- yy (* Hc 0.030))))

  ;; ---- footer note (in the bottom margin, clear of the boxes + border) ----
  (tb-mtext cx (* Hc 0.031) (* Hc 0.0105) (* Wc 0.9) 5
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
