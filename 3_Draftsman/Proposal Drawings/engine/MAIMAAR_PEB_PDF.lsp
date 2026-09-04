;; ============================================================================
;;  MAIMAAR_PEB_PDF.lsp  -  MSPLPDF / MPDF  (one-click multi-page PDF, inside AutoCAD)
;;  ----------------------------------------------------------------------------
;;  Owner, 27-Aug-2026: "i have a Autocad Drawings & there is option or button on
;;  Autocad File that generate the pdf" - i.e. WITHOUT going to the BSF page.
;;  Open the drawing, press the button (or type MPDF), get the merged PDF.
;;
;;  WHAT IT PRINTS:  the drawing EXACTLY AS IT STANDS ON SCREEN.  Nothing is
;;  regenerated from the BSF, so every correction the draftsman made by hand is
;;  what lands in the PDF.  That is the whole point of printing from inside
;;  AutoCAD rather than from the web page.
;;
;;  ------------------------------------------------------------------------
;;  TWO KINDS OF DRAWING, AND WHY BOTH PATHS ARE STILL HERE
;;  ------------------------------------------------------------------------
;;  * LAYOUT TABS (how the engine builds drawings since the A4 Layout system).
;;    peb-add-layout makes one named A4 tab per sheet and already stamps each one
;;    with DWG To PDF.pc3 / monochrome.ctb / A4 landscape.  Those tabs ARE the
;;    sheets, so we plot them in TAB ORDER - the order they sit along the bottom
;;    of the AutoCAD window, which is the order the draftsman arranged them in.
;;  * MODEL-SPACE TILES (older drawings, and anything drawn before that system).
;;    Sheets are tiled side by side in model space, each wrapped in a rectangle
;;    on layer BORDER, and plotted A1.
;;
;;  It uses layouts when the drawing HAS them and falls back to BORDER when it
;;  does not.  ** DO NOT DELETE THE FALLBACK. **  Every drawing produced before
;;  the A4 layout system is model-space tiled, and those are exactly the older
;;  jobs somebody re-opens years later.  A command that only handles today's
;;  drawings quietly fails on the archive.
;;
;;  ------------------------------------------------------------------------
;;  BUILD ONE PDF ACROSS SEVERAL OPTION DRAWINGS
;;  ------------------------------------------------------------------------
;;     1)  MSPLPDFNEW                        (once, to start a fresh set)
;;     2)  MPDF  in Option 01's drawing      -> PDF has Option 01's sheets
;;     3)  MPDF  in Option 02's drawing      -> PDF now has BOTH options
;;  Each run adds the CURRENT drawing's sheets and re-merges the whole set.  It
;;  works this way because AutoCAD will not let a command switch documents
;;  mid-run, so the set is accumulated on disk in %TEMP%\mspl_pdf instead.
;;
;;  Load once:  APPLOAD -> this file -> "Add to Startup Suite"   (or see
;;  MAIMAAR_ACAD_SETUP.md for the auto-load + toolbar button, which is better).
;;  Then type:  MPDF   (or MSPLPDF - same command)   /   MSPLPDFNEW to reset.
;; ============================================================================
(vl-load-com)

(setq *MSPL-PDF-MERGE* "D:\\maimaar-os\\3_Draftsman\\Proposal Drawings\\engine\\merge_pdfs.js")

(defun mspl-tmp ()
  (strcat (getenv "TEMP") "\\mspl_pdf"))

(defun mspl-area (b)   ; b = ((minx miny)(maxx maxy))
  (* (- (car (cadr b)) (car (car b))) (- (cadr (cadr b)) (cadr (car b)))))

;; ---------------------------------------------------------------------------
;;  PATH 1 - LAYOUT TABS
;; ---------------------------------------------------------------------------

;; Every layout tab except Model, in TAB ORDER.
;;
;; TAB ORDER, NOT NAME ORDER.  Sorting by name would put "SEC-01 SECTION" before
;; "PLn-01 PLAN" and hand the customer a shuffled document that looks deliberate.
;; TabOrder is the order the tabs sit along the bottom of the screen, which is
;; the order the sheets were made in and the order he sees.
;;
;; MODEL IS NOT A SHEET.  Model space is the workspace; plotting it would add a
;; stray first page of raw tiled geometry to every set.
(defun mspl-layouts ( / doc lst)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)) lst nil)
  (vlax-for l (vla-get-Layouts doc)
    (if (/= (strcase (vla-get-Name l)) "MODEL")
      (setq lst (cons (cons (vla-get-TabOrder l) l) lst))))
  (mapcar 'cdr (vl-sort lst '(lambda (a b) (< (car a) (car b))))))

;; Plot ONE layout tab to its own PDF page.
;;
;; The layout already carries its page setup (peb-add-layout stamps A4 +
;; DWG To PDF.pc3 + monochrome.ctb when it builds the tab), so those are only
;; re-asserted here - cheap, and it makes the command work on a tab somebody
;; created by hand that never got one.
;;
;; Plot area is EXTENTS + fit-and-centre rather than the layout's own paper
;; size, matching what the CRM's server-side re-print does.  Both buttons must
;; produce the same document, and extents is the forgiving choice: if a hand
;; edit nudged something past the paper edge, extents still prints all of it
;; instead of silently cropping the customer's drawing.
(defun mspl-plot-layout (doc lay fn / plt)
  (vl-catch-all-apply '(lambda () (vla-put-ActiveLayout doc lay)))
  (vl-catch-all-apply '(lambda () (vla-put-ConfigName lay "DWG To PDF.pc3")))
  (vl-catch-all-apply '(lambda () (vla-put-StyleSheet lay "monochrome.ctb")))
  (vl-catch-all-apply '(lambda () (vla-put-PlotWithPlotStyles lay :vlax-true)))
  (vl-catch-all-apply '(lambda () (vla-put-PlotType lay 1)))          ; 1 = acExtents
  (vl-catch-all-apply '(lambda () (vla-put-UseStandardScale lay :vlax-true)))
  (vl-catch-all-apply '(lambda () (vla-put-StandardScale lay 0)))     ; 0 = acScaleToFit
  (vl-catch-all-apply '(lambda () (vla-put-CenterPlot lay :vlax-true)))
  (vl-catch-all-apply '(lambda () (vla-put-PlotRotation lay 0)))
  (setq plt (vla-get-Plot doc))
  (vl-catch-all-apply '(lambda () (vla-put-QuietErrorMode plt :vlax-true)))
  ;; A sheet that fails is swallowed on purpose: the merge below simply finds one
  ;; fewer page.  A partial set he can look at beats an error he cannot act on.
  (vl-catch-all-apply '(lambda () (vla-PlotToFile plt fn))))

;; ---------------------------------------------------------------------------
;;  PATH 2 - MODEL-SPACE TILES ON LAYER BORDER  (older drawings)
;; ---------------------------------------------------------------------------

;; every entity on layer BORDER -> its bounding box, as ((minx miny)(maxx maxy))
(defun mspl-boxes ( / ss i en obj lo hi boxes)
  (setq ss (ssget "_X" '((8 . "BORDER"))) boxes '() i 0)
  (if ss
    (repeat (sslength ss)
      (setq en (ssname ss i) i (1+ i) obj (vlax-ename->vla-object en))
      (if (not (vl-catch-all-error-p
                 (vl-catch-all-apply '(lambda () (vla-getboundingbox obj 'lo 'hi)))))
        (setq boxes (cons (list (vlax-safearray->list lo) (vlax-safearray->list hi)) boxes)))))
  boxes)

;; drop the inner of each concentric pair: sort big->small, skip any rect whose
;; CENTRE falls inside an already-kept rect (that is the inner border of a kept
;; sheet); different sheets are tiled apart so their centres never overlap.
(defun mspl-sheets ( / boxes kept b cx cy keep a)
  (setq boxes (vl-sort (mspl-boxes) '(lambda (p q) (> (mspl-area p) (mspl-area q))))
        kept '())
  (foreach b boxes
    (setq cx (/ (+ (car (car b)) (car (cadr b))) 2.0)
          cy (/ (+ (cadr (car b)) (cadr (cadr b))) 2.0)
          keep t)
    (foreach a kept
      (if (and (>= cx (car (car a))) (<= cx (car (cadr a)))
               (>= cy (cadr (car a))) (<= cy (cadr (cadr a))))
        (setq keep nil)))
    (if keep (setq kept (cons b kept))))
  ;; left-to-right = Cover, Plan, Section... (the tiling order)
  (vl-sort kept '(lambda (a b) (< (car (car a)) (car (car b))))))

;; plot one model-space WINDOW (lo hi = WCS corners) to a PDF page (mirrors the CRM's plotpdf)
(defun mspl-plot-window (doc lo hi fn / lay plt)
  (setq lay (vla-get-ActiveLayout doc))
  (vl-catch-all-apply '(lambda () (vla-put-ConfigName lay "DWG To PDF.pc3")))
  (vl-catch-all-apply '(lambda () (vla-put-StyleSheet lay "monochrome.ctb")))
  (vl-catch-all-apply '(lambda () (vla-put-PlotWithPlotStyles lay :vlax-true)))
  (vl-catch-all-apply '(lambda () (vla-SetWindowToPlot lay
                                     (vlax-3d-point (car lo) (cadr lo) 0.0)
                                     (vlax-3d-point (car hi) (cadr hi) 0.0))))
  (vl-catch-all-apply '(lambda () (vla-put-PlotType lay 4)))          ; 4 = acWindow
  (vl-catch-all-apply '(lambda () (vla-put-UseStandardScale lay :vlax-true)))
  (vl-catch-all-apply '(lambda () (vla-put-StandardScale lay 0)))     ; 0 = acScaleToFit
  (vl-catch-all-apply '(lambda () (vla-put-CenterPlot lay :vlax-true)))
  (vl-catch-all-apply '(lambda () (vla-put-CanonicalMediaName lay "ISO_A1_(841.00_x_594.00_MM)")))
  (vl-catch-all-apply '(lambda () (vla-put-PlotRotation lay 0)))      ; upright landscape
  (setq plt (vla-get-Plot doc))
  (vl-catch-all-apply '(lambda () (vla-put-QuietErrorMode plt :vlax-true)))
  (vla-PlotToFile plt fn))

;; ---------------------------------------------------------------------------
;;  MERGE
;; ---------------------------------------------------------------------------

(defun mspl-node ()   ; prefer a known Node, else rely on PATH
  (cond ((findfile "C:/Program Files/nodejs/node.exe") "\"C:\\Program Files\\nodejs\\node.exe\"")
        ((findfile "C:/Program Files (x86)/nodejs/node.exe") "\"C:\\Program Files (x86)\\nodejs\\node.exe\"")
        (t "node")))

(defun mspl-merge ( / tmp base out sh)
  (setq tmp  (mspl-tmp)
        base (getvar "DWGPREFIX"))
  (if (or (null base) (= base "")) (setq base (strcat (getenv "USERPROFILE") "\\Desktop\\")))
  (setq out (strcat base "MSPL-Proposal-Drawings.pdf"))
  (vl-catch-all-apply '(lambda () (vl-file-delete out)))          ; overwrite the previous merge
  (setq sh (vlax-create-object "WScript.Shell"))
  (vl-catch-all-apply
    '(lambda () (vlax-invoke sh 'Run
       (strcat "cmd /c " (mspl-node) " \"" *MSPL-PDF-MERGE* "\" \"" tmp "\" \"" out "\"")
       0 :vlax-true)))                                            ; 0 = hidden window, :vlax-true = wait
  (vlax-release-object sh)
  (if (findfile out)
    (progn (startapp "explorer" (strcat "\"" out "\""))
           (princ (strcat "\nMerged PDF (open): " out)))
    (princ (strcat "\nCould not merge - is Node.js installed / on PATH? Per-sheet pages are in " tmp))))

;; ---------------------------------------------------------------------------
;;  THE COMMAND
;; ---------------------------------------------------------------------------

(defun C:MSPLPDF ( / doc tmp lays sheets dn n bx lay ctab tile)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setvar "BACKGROUNDPLOT" 0)                                     ; foreground = synchronous, so the merge sees the pages
  ;; Remember where he was, and put him back at the end.  Printing must not
  ;; leave his drawing sitting on a different tab than the one he was working on.
  (setq ctab (getvar "CTAB") tile (getvar "TILEMODE"))
  (setq tmp (mspl-tmp))
  (if (not (vl-file-directory-p tmp)) (vl-mkdir tmp))
  (setq dn (vl-filename-base (getvar "DWGNAME")) n 0)             ; drawing name = stable sort prefix across drawings
  (setq lays (mspl-layouts))
  (cond
    ;; --- the normal case: the drawing has A4 sheet tabs ---
    (lays
      (princ (strcat "\n" (itoa (length lays)) " sheet tab(s) found. Plotting..."))
      (foreach lay lays
        (setq n (1+ n))
        (princ (strcat "\n  sheet " (itoa n) " - " (vla-get-Name lay)))
        (mspl-plot-layout doc lay
          (strcat tmp "\\" dn "__" (if (< n 10) "0" "") (itoa n) ".pdf"))))
    ;; --- older drawing: sheets tiled in model space, wrapped on layer BORDER ---
    (t
      (vl-catch-all-apply '(lambda () (vla-put-ActiveSpace doc 1)))
      (setq sheets (mspl-sheets))
      (if (null sheets)
        (progn
          (alert (strcat "Nothing to print in this drawing.\n\n"
                         "It has no sheet tabs, and no sheet borders on layer BORDER.\n"
                         "Open a generated proposal drawing, then run MPDF."))
          (setvar "CTAB" ctab) (setvar "TILEMODE" tile)
          (exit)))
      (princ (strcat "\nNo sheet tabs - using the " (itoa (length sheets))
                     " model-space sheet(s) on layer BORDER."))
      (foreach bx sheets
        (setq n (1+ n))
        (princ (strcat "\n  sheet " (itoa n)))
        (mspl-plot-window doc (car bx) (cadr bx)
          (strcat tmp "\\" dn "__" (if (< n 10) "0" "") (itoa n) ".pdf")))))
  ;; back to the tab he was on
  (vl-catch-all-apply '(lambda () (setvar "TILEMODE" tile)))
  (vl-catch-all-apply '(lambda () (setvar "CTAB" ctab)))
  (princ (strcat "\n" (itoa n) " sheet(s) plotted from " dn ". Merging..."))
  (mspl-merge)
  (princ))

;; Short alias - this is the one to put on the toolbar button.
(defun C:MPDF () (C:MSPLPDF))

(defun C:MSPLPDFNEW ( / tmp f)
  (setq tmp (mspl-tmp))
  (if (vl-file-directory-p tmp)
    (foreach f (vl-directory-files tmp "*.pdf" 1) (vl-file-delete (strcat tmp "\\" f))))
  (princ "\nStarted a fresh set. Run MPDF in each option's drawing to build the combined PDF."))

(princ "\nMAIMAAR PEB PDF loaded.  Commands:  MPDF / MSPLPDF  (build/append)   MSPLPDFNEW  (reset)\n")
(princ)
