;; ============================================================================
;;  MAIMAAR_PEB_Cover.lsp  —  Cover sheet (PRO-00) of the Proposal Drawing set
;; ----------------------------------------------------------------------------
;;  Mammut-grade, fully IF-linked cover.  It re-uses the SAME Mammut right-edge
;;  title strip (peb-titleblock-mammut) that the Plan & Section draw, fed from
;;  the SAME PEB_Data file — so the cover's title block (project, customer,
;;  revision, date, design loads, design code …) is identical to every sheet's.
;;  Edit the IF (or the title data) and regenerate -> cover AND all sheets update
;;  together: one source of truth, exactly like the Mammut set.
;;
;;  Pure entmake (batch-safe under acad /b).  Load AFTER the engine:
;;     (load ".../engine/MAIMAAR_PEB_Section.lsp")
;;     (load ".../engine/MAIMAAR_PEB_Plan.lsp")
;;     (load ".../engine/MAIMAAR_PEB_Cover.lsp")
;;     (peb-cover-from-file "...PEB_Data_B1_A1.txt")   ; or  C:PEB-COVER
;;
;;  Depends on engine helpers: MSPL-Read-Data, MSPL-Get-Str, peb-titleblock-mammut,
;;  tb-line/tb-rect/tb-mtext/tb-fith, peb-tb-place-logo, peb-tb-or/snow/zone,
;;  peb-num-only, peb-pretty-date, format-date.
;; ============================================================================

;; Build the SAME title-block data alist the sheets use (single source of truth).
(defun peb-cover-tbdata (data drg sheetno
                         / propinput propno tbQuote bno revno dat drn chk)
  (setq propinput (MSPL-Get-Str data "PROPOSAL"))
  (if (= propinput "") (setq propinput "000"))
  (setq propno (strcat "MSPL-26-" propinput))
  (setq tbQuote (MSPL-Get-Str data "PROPOSAL_FULL"))
  (if (= tbQuote "")
    (cond ((and (= (strlen propinput) 5) (wcmatch propinput "#####"))
           (setq tbQuote (strcat "MSPL-" (substr propinput 1 2) "-" (substr propinput 3))))
          (T (setq tbQuote propno))))
  (setq bno (MSPL-Get-Str data "BLDGNO"))
  (if (= bno "") (setq bno "01"))
  (if (= (strlen bno) 1) (setq bno (strcat "0" bno)))
  (setq revno (MSPL-Get-Str data "REVNO"))
  (if (or (= revno "0") (= revno "")) (setq revno "00"))
  (setq drn (MSPL-Get-Str data "TBDRN")) (if (= drn "") (setq drn "M.H"))
  (setq chk (MSPL-Get-Str data "TBCHK")) (if (= chk "") (setq chk "YEA"))
  (setq dat (MSPL-Get-Str data "TBDATE"))
  (if (= dat "") (setq dat (format-date (getvar "CDATE"))) (setq dat (peb-pretty-date dat)))
  (list
    (cons "REV" revno) (cons "DATE" dat) (cons "DRN" drn) (cons "CHK" chk)
    (cons "LL_ROOF"  (peb-tb-or (MSPL-Get-Str data "LIVEROOF")  "0.57"))
    (cons "LL_FRAME" (peb-tb-or (MSPL-Get-Str data "LIVEFRAME") "0.57"))
    (cons "WIND"     (peb-tb-or (peb-num-only (MSPL-Get-Str data "WINDSPEED")) "AS PER CODE"))
    (cons "COLL"     (peb-tb-or (peb-num-only (MSPL-Get-Str data "COLLATERAL")) "0.0"))
    (cons "SNOW"     (peb-tb-snow (MSPL-Get-Str data "SNOW")))
    (cons "SEISMIC"  (peb-tb-zone (MSPL-Get-Str data "SEISMIC")))
    (cons "TEMP"     (peb-tb-snow (MSPL-Get-Str data "TEMP")))
    (cons "RAIN"     (peb-tb-or (MSPL-Get-Str data "RAIN") "-"))
    (cons "CODE"     (peb-tb-or (MSPL-Get-Str data "DESIGNCODE") "MBMA 2006"))
    (cons "PROJECT"  (MSPL-Get-Str data "PROJECT"))
    (cons "CUSTOMER" (MSPL-Get-Str data "CLIENT"))
    (cons "ADDR" (strcat "Lahore Office\\P"
                         "238, First Floor, Lalazar Commercial Area,\\P"
                         "Raiwind Road, Lahore, Pakistan\\P"
                         "Web: www.maimaargroup.com\\P"
                         "Cell : +(92-300) 807 4007"))
    (cons "QUOTE" tbQuote) (cons "BLDGNO" bno)
    (cons "BLDGNAME" (MSPL-Get-Str data "TBBLDGNAME"))
    (cons "IDENTICAL" "ONE")
    (cons "DRGTITLE" drg) (cons "SCALE" "N.T.S.") (cons "SHEETSIZE" "A1")
    (cons "SHEETNO" sheetno)))

;; the cover  (clean, world-class technical cover: brand header, PROPOSAL DRAWING
;; banner, project/client, INTERNATIONAL CODES strip, list of drawings, design
;; criteria, tasteful tool-credit + design-basis note, and the linked title strip)
(defun peb-cover-draw (data / white grey green cyan red blue
                            Hc Wc stripW stripX gap hx0 hx1 hcx
                            bx0 bx1 by0 by1 yy proj cust loc get
                            lcx0 lcx1 rcx0 rcx1 cbx0 cbx1)
  (setq white 7 grey 8 green 3 cyan 4 red 1 blue 5)
  (defun get (k) (MSPL-Get-Str data k))
  ;; ---- canvas (drawing units; landscape, ~A-series ratio) ----
  (setq Hc 29700.0 Wc 42000.0)
  (setq stripW (* Hc 0.46) gap (* Hc 0.028) stripX (- Wc stripW))
  (tb-rect 0 0 Wc Hc white)
  (tb-rect (* Hc 0.012) (* Hc 0.012) (- Wc (* Hc 0.012)) (- Hc (* Hc 0.012)) white)
  ;; ---- right title strip : identical to every sheet (IF-linked) ----
  (peb-titleblock-mammut stripX 0.0 stripW Hc (peb-cover-tbdata data "COVER SHEET" "PRO-00"))
  ;; ---- hero area ----
  (setq hx0 (* Hc 0.05) hx1 (- stripX gap) hcx (/ (+ hx0 hx1) 2.0))
  ;; ---- brand header : real logo + company name + tagline + accent rule ----
  (peb-tb-place-logo (- hcx (* Hc 0.24)) (* Hc 0.862) (+ hcx (* Hc 0.24)) (* Hc 0.966))
  (tb-mtext hcx (* Hc 0.843) (* Hc 0.021) (* Hc 1.4) 5
            "{\\fArial|b1;MAIMAAR STEEL (PVT) LTD}" blue)
  (tb-mtext hcx (* Hc 0.820) (* Hc 0.0125) (* Hc 1.4) 5
            "{\\fArial|b1;PRE-ENGINEERED STEEL BUILDINGS   -   DESIGN | MANUFACTURE | ERECT}" green)
  (tb-line hx0 (* Hc 0.806) hx1 (* Hc 0.806) green)
  ;; ---- PROPOSAL DRAWING banner (double box) ----
  (setq bx0 (- hcx (* Hc 0.40)) bx1 (+ hcx (* Hc 0.40))
        by0 (* Hc 0.660) by1 (* Hc 0.770))
  (tb-rect bx0 by0 bx1 by1 white)
  (tb-rect (+ bx0 (* Hc 0.009)) (+ by0 (* Hc 0.009))
           (- bx1 (* Hc 0.009)) (- by1 (* Hc 0.009)) white)
  (tb-mtext hcx (* Hc 0.697) (* Hc 0.054) (* Hc 1.6) 5
            "{\\fArial|b1;PROPOSAL DRAWING}" white)
  ;; ---- PROJECT / CLIENT / LOCATION ----
  (setq proj (get "PROJECT") cust (get "CLIENT") loc (get "LOCATION"))
  (if (= proj "") (setq proj "UNNAMED PROJECT"))
  (if (= cust "") (setq cust "UNNAMED CLIENT"))
  (tb-mtext hcx (* Hc 0.615) (* Hc 0.013) (* Hc 1.2) 5 "{\\fArial|b1;PROJECT}" grey)
  (tb-mtext hcx (* Hc 0.575) (tb-fith proj (* 1.9 (- hx1 hx0)) (* Hc 0.026))
            (- hx1 hx0) 5 (strcat "{\\fArial|b1;" proj "}") green)
  (tb-mtext hcx (* Hc 0.520) (* Hc 0.012) (* Hc 1.2) 5 "{\\fArial|b1;CLIENT}" grey)
  (tb-mtext hcx (* Hc 0.488) (tb-fith cust (* 1.4 (- hx1 hx0)) (* Hc 0.019))
            (- hx1 hx0) 5 (strcat "{\\fArial|b1;" cust "}") green)
  (if (/= loc "")
    (tb-mtext hcx (* Hc 0.458) (* Hc 0.012) (- hx1 hx0) 5 loc white))
  ;; ---- INTERNATIONAL DESIGN-CODES strip (credibility, not advertising) ----
  (setq cbx0 hx0 cbx1 hx1 by1 (* Hc 0.448) by0 (* Hc 0.382))
  (tb-rect cbx0 by0 cbx1 by1 white)
  (tb-line cbx0 (- by1 (* Hc 0.024)) cbx1 (- by1 (* Hc 0.024)) white)
  (tb-mtext hcx (- by1 (* Hc 0.015)) (* Hc 0.0098) (- cbx1 cbx0) 5
            "{\\fArial|b1;DESIGNED & DETAILED TO INTERNATIONAL STANDARDS}" grey)
  (tb-mtext hcx (+ by0 (* Hc 0.0165))
            (tb-fith "AISC 360   |   AISI S100   |   MBMA 2018   |   ASCE 7   |   IBC   |   AWS D1.1"
                     (* (- cbx1 cbx0) 0.92) (* Hc 0.0150))
            (- cbx1 cbx0) 5
            "{\\fArial|b1;AISC 360   |   AISI S100   |   MBMA 2018   |   ASCE 7   |   IBC   |   AWS D1.1}" green)
  ;; ---- bottom panels : LIST OF DRAWINGS (left) + DESIGN CRITERIA (right) ----
  (setq lcx0 hx0 lcx1 (- hcx (* Hc 0.015))
        rcx0 (+ hcx (* Hc 0.015)) rcx1 hx1
        by1 (* Hc 0.362) by0 (* Hc 0.118))
  ;; LIST OF DRAWINGS
  (tb-rect lcx0 by0 lcx1 by1 white)
  (tb-line lcx0 (- by1 (* Hc 0.028)) lcx1 (- by1 (* Hc 0.028)) white)
  (tb-mtext (/ (+ lcx0 lcx1) 2.0) (- by1 (* Hc 0.020)) (* Hc 0.014) (- lcx1 lcx0) 5
            "{\\fArial|b1;LIST OF DRAWINGS}" white)
  (setq yy (- by1 (* Hc 0.050)))
  (foreach d (list (list "PRO-00" "COVER SHEET")
                   (list "PRO-01" "COLUMN LAY-OUT PLAN")
                   (list "PRO-02" "CROSS SECTION"))
    (tb-mtext (+ lcx0 (* Hc 0.015)) yy (* Hc 0.0130) 0 4 (car d) green)
    (tb-mtext (+ lcx0 (* Hc 0.090)) yy (* Hc 0.0130) 0 4 (cadr d) white)
    (setq yy (- yy (* Hc 0.028))))
  ;; DESIGN CRITERIA
  (tb-rect rcx0 by0 rcx1 by1 white)
  (tb-line rcx0 (- by1 (* Hc 0.028)) rcx1 (- by1 (* Hc 0.028)) white)
  (tb-mtext (/ (+ rcx0 rcx1) 2.0) (- by1 (* Hc 0.020)) (* Hc 0.014) (- rcx1 rcx0) 5
            "{\\fArial|b1;DESIGN CRITERIA}" white)
  (setq yy (- by1 (* Hc 0.050)))
  (foreach c (list
       (list "DESIGN CODE" (peb-tb-or (get "DESIGNCODE") "MBMA 2006"))
       (list "WIND SPEED"  (strcat (peb-tb-or (peb-num-only (get "WINDSPEED")) "AS PER CODE") " KPH"))
       (list "LIVE LOAD"   (strcat (peb-tb-or (get "LIVEROOF") "0.57") " KN/SQ.M."))
       (list "SEISMIC"     (peb-tb-zone (get "SEISMIC")))
       (list "STEEL"       "ASTM A572 Gr.50 / A36")
       (list "BOLTS"       "ASTM A325 / A490")
       (list "WELD"        "AWS D1.1"))
    (tb-mtext (+ rcx0 (* Hc 0.015)) yy (* Hc 0.0120) 0 4 (car c) grey)
    (tb-mtext (+ rcx0 (* Hc 0.110)) yy
              (tb-fith (cadr c) (* (- rcx1 rcx0) 0.55) (* Hc 0.0120)) 0 4 (cadr c) green)
    (setq yy (- yy (* Hc 0.028))))
  ;; ---- tasteful engineering-tools credit + design-basis note ----
  (tb-mtext hcx (* Hc 0.092)
            (tb-fith "Engineered with  STAAD.Pro   -   SAP2000   -   Tekla Structures   -   AutoCAD"
                     (* (- hx1 hx0) 0.92) (* Hc 0.0105)) (- hx1 hx0) 5
            "{\\fArial|i1;Engineered with  STAAD.Pro   -   SAP2000   -   Tekla Structures   -   AutoCAD}" grey)
  (tb-mtext hcx (* Hc 0.072)
            (tb-fith "Design Basis:  LRFD   -   Built-up tapered I-section primary frames   -   Cold-formed secondary members"
                     (* (- hx1 hx0) 0.92) (* Hc 0.0095)) (- hx1 hx0) 5
            "{\\fArial|i1;Design Basis:  LRFD   -   Built-up tapered I-section primary frames   -   Cold-formed secondary members}" grey)
  ;; ---- NOT FOR CONSTRUCTION footer ----
  (tb-mtext hcx (* Hc 0.042) (* Hc 0.015) (- hx1 hx0) 5
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
