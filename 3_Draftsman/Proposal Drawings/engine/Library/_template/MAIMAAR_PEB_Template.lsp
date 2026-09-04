;;; ============================================================================
;;;  MAIMAAR_PEB_<Name>.lsp — <COMPONENT>
;;;  Copy of Library/_template. Read Library/GOLDEN_RULES.md before editing.
;;; ============================================================================
;;;
;;;  A DRAWER IS PURE GEOMETRY (rule 2). Everything in as arguments, geometry out.
;;;  It must NOT: read the BSF, draw a sheet or title block, hard-code a surface-dependent
;;;  name, or hand-drive LAYER / STYLE / TEXT with `command`.
;;;
;;;  REUSE, DO NOT RE-AUTHOR (rule 3). If the engine already draws this profile, call that
;;;  function and give it a layer override - do not copy its numbers.
;;;
;;;  THE PDF IS MONOCHROME (rule 4). Colour is for the DWG only. Put the pen on the entity
;;;  with (cons 370 N) AND the layer in PEB_LAYERS.csv.
;;; ============================================================================

;; ---- the component's fixed numbers, each with its source ------------------
;; (defun peb-xx-width () 1000.0)   ; from <reference>

;; ---- the drawer ------------------------------------------------------------
;; (defun peb-xx-elev (x0 y0 w h surf / ...) ... (princ))

;; ---- the sample sheet ------------------------------------------------------
;; ONE view, ONE scale (rule 15), annotation scaled to the COMPONENT not the building
;; (rule 14), GENERAL information only - never one job's numbers (rule 18).
;; (defun peb-draw-xx-sample (data ox oy / ...) ... (princ))

;; ---- entry points ----------------------------------------------------------
;; (defun C:PEB-XX-SAMPLE ( / data)
;;   (vl-load-com) (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
;;   (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
;;   (setq *PEB-TEXT-SCALE* 0.10 *PEB-DIM-SCALE* 0.10)
;;   ...)

(princ "
MAIMAAR_PEB_Template.lsp - copy me, do not load me.")
(princ)
