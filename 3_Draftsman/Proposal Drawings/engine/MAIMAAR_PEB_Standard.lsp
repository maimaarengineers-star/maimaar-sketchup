;; ============================================================================
;;  MAIMAAR_PEB_Standard.lsp  —  Mammut-grade drawing STANDARD foundation
;; ----------------------------------------------------------------------------
;;  Extracted FAITHFULLY from real Mammut (MBS) proposal drawings:
;;    D:\Misc\Miscellaneous\Personnel\MBS Data\A_Pakistan\Proposals\...\*.DXF
;;    (e.g. 047-PK-12 Agri Autos\B1-A1\Plan.DXF = an Anchor-Bolt Plan)
;;
;;  This module sets up the LAYER / COLOR / LINETYPE / TEXT-STYLE standard that
;;  the Mammut sheets use, so the Maimaar engine output matches that look. It is
;;  ADDITIVE — load it and call (peb-std-setup) at the start of a drawing; it
;;  does not modify the existing Plan/Section engine.
;;
;;  Mammut layer convention (numbered layers, each a fixed ACI colour + linetype):
;;    0:white  1:red  2:yellow  3:white  4:cyan/CENTER  5:cyan/DASHED  6:magenta
;;    7:red  8:cyan/CENTER  9:green/DASHED  10:cyan 11:white 12-13:grey(8)
;;    14:white 15:green 16:cyan 17:blue 18:magenta 19:red 20:yellow 21-22:white
;;    23:white/DASHED 24-26:white 27:red/CENTER
;;  Grids/centre-lines = layer 4/8 (cyan, CENTER); hidden/future = DASHED layers.
;;  Text styles: ROMAND (romand.shx) and OPEN (romand.shx) — the ROMANS family.
;;  Symbol blocks seen: CIRCLE (grid bubble), ARROW/ARROWP/TICK (dims),
;;    WCOL/PCOL/ZCOL/TCOL/SCCOL/GCOL/UCOL/DCCOL (column types),
;;    BOLT_0..BOLT_7 + ANCHOR (anchor bolts), BRACE.
;; ============================================================================

;; (name color linetype) — faithful to the MBS DXF layer table.
(setq *MBS-LAYERS*
  '(("0" 7 "Continuous")  ("1" 1 "Continuous")  ("2" 2 "Continuous")
    ("3" 7 "Continuous")  ("4" 4 "CENTER")      ("5" 4 "DASHED")
    ("6" 6 "Continuous")  ("7" 1 "Continuous")  ("8" 4 "CENTER")
    ("9" 3 "DASHED")      ("10" 4 "Continuous") ("11" 7 "Continuous")
    ("12" 8 "Continuous") ("13" 8 "Continuous") ("14" 7 "Continuous")
    ("15" 3 "Continuous") ("16" 4 "Continuous") ("17" 5 "Continuous")
    ("18" 6 "Continuous") ("19" 1 "Continuous") ("20" 2 "Continuous")
    ("21" 7 "Continuous") ("22" 7 "Continuous") ("23" 7 "DASHED")
    ("24" 7 "Continuous") ("25" 7 "Continuous") ("26" 7 "Continuous")
    ("27" 1 "CENTER")))

;; Load a linetype from the standard acad.lin (quietly, if not already loaded).
(defun peb-std-ltype (lt)
  (if (and lt (/= (strcase lt) "CONTINUOUS") (not (tblsearch "LTYPE" lt)))
    (vl-catch-all-apply '(lambda () (command "_.-LINETYPE" "_Load" lt "acad.lin" "")))))

;; Create one layer (idempotent — updates colour/linetype if it already exists).
(defun peb-std-layer (name color ltype)
  (peb-std-ltype ltype)
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord") (cons 2 name) (cons 70 0)
                   (cons 62 color) (cons 6 (if ltype ltype "Continuous"))))
    (command "_.-LAYER" "_Color" (itoa color) name "_Ltype" (if ltype ltype "Continuous") name "")))

;; Create a SHX text style (font = romand.shx; falls back silently if missing).
(defun peb-std-textstyle (name font)
  (vl-catch-all-apply
    '(lambda () (command "_.-STYLE" name font "0" "1" "0" "_N" "_N"))))

;; One call to lay the full MBS standard into the current drawing.
(defun peb-std-setup ( / )
  (foreach L *MBS-LAYERS* (apply 'peb-std-layer L))
  (peb-std-textstyle "ROMAND" "romand.shx")
  (peb-std-textstyle "OPEN"   "romand.shx")
  (princ "\nMAIMAAR PEB standard (MBS layers + ROMAND styles) ready.")
  (princ))

(princ "\nMAIMAAR_PEB_Standard.lsp loaded — run (peb-std-setup).")
(princ)
