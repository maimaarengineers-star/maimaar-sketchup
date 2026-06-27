;; ============================================================================
;;  MAIMAAR_PEB_Cover.lsp  —  Cover sheet (page 1) of the Proposal Drawing set
;; ----------------------------------------------------------------------------
;;  Maimaar-branded cover, laid out like the Mammut (MBS) proposal-drawing cover:
;;    outer/inner border · vertical "PROPOSAL DRAWING" banner · logo block ·
;;    company contact block · bottom-right TITLE BLOCK filled from the PEB_Data
;;    HD_* header fields (the SAME data file the Section/Plan engine reads).
;;
;;  Commands:
;;    (peb-cover-from-file "<path to PEB_Data_B1_A1.txt>")   non-interactive
;;    C:PEB-COVER                                            prompts for the file
;;
;;  Self-contained: it includes its own tiny KEY=value reader, so it loads and
;;  runs WITHOUT the Section/Plan engine. Drawn in an A3-landscape layout
;;  (420 x 297 "paper mm") multiplied by *PEB-COVER-SCALE* so it sits at the
;;  same drawing-unit scale as the other sheets. Edit the branding constants
;;  below to correct any company detail.
;; ============================================================================

;; ---- EDITABLE BRANDING (correct these to taste) ----------------------------
(setq *MAIMAAR-NAME*  "MAIMAAR")
(setq *MAIMAAR-TAG*   "STEEL  (PVT)  LTD")
(setq *MAIMAAR-SUB*   "a Maimaar Group company")
(setq *MAIMAAR-ADDR*  (list "Lalazar Commercial Area, Raiwind Road,"
                            "Thokar Niaz Baig, Lahore, Pakistan"))
(setq *MAIMAAR-PHONE* "Ph: +92-42-XXXXXXXX   Mob: +92-300-XXXXXXX")
(setq *MAIMAAR-EMAIL* "maimaar.engineers@gmail.com")
(setq *MAIMAAR-WEB*   "www.maimaargroup.com")
(setq *PEB-COVER-SCALE* 100.0)   ; paper-mm -> drawing-units multiplier

;; ---- minimal self-contained PEB_Data (v3) reader ---------------------------
(defun peb-cov-read (path / f line s alist pos k v)
  (setq alist '())
  (if (setq f (open path "r"))
    (progn
      (while (setq line (read-line f))
        (setq s (vl-string-trim " \t\r" line))
        (cond
          ((= s "") nil)
          ((= (substr s 1 1) ";") nil)
          ((and (= (substr s 1 1) "[") (= (substr s (strlen s) 1) "]")) nil)
          (T (setq pos (vl-string-search "=" s))
             (if pos
               (progn
                 (setq k (substr s 1 pos))
                 (setq v (substr s (+ pos 2)))
                 (setq alist (cons (cons k v) alist)))))))
      (close f)))
  (reverse alist))

(defun peb-cov-get (data key / p) (if (setq p (assoc key data)) (cdr p) ""))

;; ---- drawing helpers (paper coords -> drawing units) -----------------------
;; *cov-ox* *cov-oy* *cov-s* are set by peb-cover-draw before any primitive.
(defun cov-pt (x y) (list (+ *cov-ox* (* x *cov-s*)) (+ *cov-oy* (* y *cov-s*)) 0.0))

(defun cov-line (x1 y1 x2 y2)
  (entmakex (list '(0 . "LINE") (cons 10 (cov-pt x1 y1)) (cons 11 (cov-pt x2 y2)))))

(defun cov-rect (x1 y1 x2 y2)
  (cov-line x1 y1 x2 y1) (cov-line x2 y1 x2 y2)
  (cov-line x2 y2 x1 y2) (cov-line x1 y2 x1 y1))

;; just = TEXT 2-letter code (BL ML MC MR TL ...). h in paper-mm. rot in degrees.
(defun cov-text (x y h just rot str)
  (if (or (null str) (= str "")) (setq str " "))
  (command "_.TEXT" "_J" just (cov-pt x y) (* h *cov-s*) rot str))

;; label/value pair on one row (label small, value larger) for the title block.
(defun cov-field (x y labh valh lab val)
  (cov-text x (+ y (* valh 1.05)) labh "BL" 0 lab)
  (cov-text x y valh "BL" 0 (strcase val)))

;; ---- the cover ------------------------------------------------------------
(defun peb-cover-draw (data ox oy s / B A propno rev cust proj loc dat drn chk yL)
  (setq *cov-ox* ox  *cov-oy* oy  *cov-s* s)

  ;; ensure a clean text style + a layer for the cover linework
  (if (not (tblsearch "STYLE" "PEB-COVER"))
    (vl-catch-all-apply '(lambda () (command "_.-STYLE" "PEB-COVER" "romans.shx" "0" "1" "0" "_N" "_N"))))
  (setvar "TEXTSTYLE" "PEB-COVER")
  (if (not (tblsearch "LAYER" "COVER"))
    (vl-catch-all-apply '(lambda () (command "_.-LAYER" "_Make" "COVER" "_Color" "7" "COVER" ""))))
  (setvar "CLAYER" "COVER")

  ;; header values from the PEB_Data HD_* fields
  (setq B      (peb-cov-get data "BUILDING_NUM")
        A      (peb-cov-get data "AREA_NUM")
        propno (peb-cov-get data "HD_PROPOSAL_NO")
        rev    (peb-cov-get data "HD_REVISION")
        cust   (peb-cov-get data "HD_CUSTOMER")
        proj   (peb-cov-get data "HD_PROJECT")
        loc    (peb-cov-get data "HD_LOCATION")
        dat    (peb-cov-get data "HD_DATE")
        drn    (peb-cov-get data "HD_DRN_BY")
        chk    (peb-cov-get data "HD_CHK_BY"))
  (if (= B "") (setq B "1")) (if (= A "") (setq A "1"))
  (if (= rev "") (setq rev "0"))

  ;; ---- sheet borders (A3 landscape 420 x 297) ----
  (cov-rect 5 5 415 292)
  (cov-rect 10 10 410 287)

  ;; ---- vertical "PROPOSAL DRAWING" banner (center-left) ----
  (cov-rect 92 48 122 252)
  (cov-rect 96 52 118 248)
  (cov-text 107 150 11 "MC" 90 "PROPOSAL  DRAWING")

  ;; ---- left strip: proposal / quote no. ----
  (cov-text 24 48 5 "BL" 90 (strcat "PROPOSAL / QUOTE NO. :   " propno))

  ;; ---- LOGO block (top-right) ----
  ;; Vector wordmark placeholder — drop the real Maimaar logo here later via
  ;; IMAGEATTACH or a logo BLOCK insert (see header note).
  (cov-rect 300 232 405 282)
  (cov-text 352 262 14 "MC" 0 *MAIMAAR-NAME*)
  (cov-text 352 248 5  "MC" 0 *MAIMAAR-TAG*)
  (cov-text 352 240 3  "MC" 0 *MAIMAAR-SUB*)

  ;; ---- company CONTACT block (right, under logo) ----
  (setq yL 220)
  (cov-text 302 yL 3 "BL" 0 (car *MAIMAAR-ADDR*))   (setq yL (- yL 6))
  (cov-text 302 yL 3 "BL" 0 (cadr *MAIMAAR-ADDR*))  (setq yL (- yL 6))
  (cov-text 302 yL 3 "BL" 0 *MAIMAAR-PHONE*)        (setq yL (- yL 6))
  (cov-text 302 yL 3 "BL" 0 (strcat "E: " *MAIMAAR-EMAIL*)) (setq yL (- yL 6))
  (cov-text 302 yL 3 "BL" 0 (strcat "W: " *MAIMAAR-WEB*))

  ;; ---- "Preliminary - Not For Construction" note ----
  (cov-text 210 40 4 "MC" 0 "PRELIMINARY  -  NOT  FOR  CONSTRUCTION")

  ;; ---- TITLE BLOCK (bottom-right) ----
  (cov-rect 255 12 408 95)
  (cov-line 255 80 408 80)            ; under CUSTOMER
  (cov-line 255 66 408 66)            ; under BUILDING NAME
  (cov-line 255 52 408 52)            ; under PROJECT TITLE
  (cov-line 255 38 408 38)            ; under LOCATION
  (cov-line 331 12 331 38)            ; vertical split (left/right cells)
  (cov-line 255 25 408 25)            ; mid-row split
  (cov-field 258 82 2.6 4.0 "CUSTOMER:"        cust)
  (cov-field 258 68 2.6 4.0 "BUILDING:"        (strcat "BUILDING " B " - AREA " A))
  (cov-field 258 54 2.6 4.0 "PROJECT TITLE:"   proj)
  (cov-field 258 40 2.6 4.0 "LOCATION:"        loc)
  (cov-field 258 27 2.4 3.4 "PREPARED BY:" drn)
  (cov-field 334 27 2.4 3.4 "DATE:"        dat)
  (cov-field 258 14 2.4 3.4 "CHECKED BY:" chk)
  (cov-field 334 14 2.4 3.4 "REV:"        rev)
  (princ))

;; non-interactive entry (mirrors peb-section-from-file): reads + draws at origin.
(defun peb-cover-from-file (path / data)
  (setq data (peb-cov-read path))
  (if data
    (progn (peb-cover-draw data 0.0 0.0 *PEB-COVER-SCALE*)
           (command "_.ZOOM" "_E"))
    (alert (strcat "Cover: could not read PEB_Data file:\n" path)))
  (princ))

;; interactive entry — prompts for the data file.
(defun C:PEB-COVER ( / path)
  (setq path (getfiled "Select PEB_Data file for the cover sheet" "" "txt" 16))
  (if path (peb-cover-from-file path))
  (princ))

(princ "\nMAIMAAR_PEB_Cover.lsp loaded — run  C:PEB-COVER  or (peb-cover-from-file \"...txt\").")
(princ)
