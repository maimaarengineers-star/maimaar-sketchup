;; ============================================================================
;;  MAIMAAR_PEB_Elevation.lsp  —  WALL ELEVATIONS (NSW / FSW / LEW / REW)
;; ----------------------------------------------------------------------------
;;  Draws the four wall-face elevations of a building, derived from the SAME
;;  data + grid as the Column Layout Plan.  For each wall it shows:
;;    * ground line + brick base (BP_BRICK_HT)
;;    * the COLUMNS as vertical lines at their grid stations
;;        - side walls (NSW/FSW) : bay columns, stations from BP_BAY_SPACING
;;        - end  walls (LEW/REW) : end-wall columns, stations from BP_EW_*_SPACING,
;;                                 each rising to the gable/slope underside
;;    * horizontal GIRTS at ~1800 spacing
;;    * the ROOF-line profile at the top:
;;        - side walls : flat eave line (mono-slope FSW rides the high eave)
;;        - end  walls : gable peak (CS/MS/RC), mono slope (SS/LT/CC),
;;                       butterfly valley (BF) or multi-gable sawtooth (MG)
;;    * WALL OPENINGS (doors/windows) from the PL_* placements on that wall
;;    * X wall-BRACING in the braced bays/panels (peb-braced-bays, plan rule)
;;    * light SHEETING panel lines + the wall CONDITION note (OW_<wall>)
;;    * GRID BUBBLES along the bottom + a "<wall> ELEVATION" title + height dim
;;
;;  Consumes the shared Presentation Standards DB + the Plan's data reader and
;;  helpers (MSPL-Read-Data / MSPL-Get-* / peb-tb-or / peb-parse-mod-expression /
;;  slope-denom / grid-bubble / txt / txt-bold / peb-braced-bays / peb-dim-v-native
;;  / peb-wall-open-p / peb-tile-place).  Load AFTER Standard / Section / Plan.
;;  Entry: (peb-elevation-from-file "<PEB_Data.txt>").
;;
;;  Side walls span the LENGTH; end walls span the WIDTH and carry the gable.
;;  All mm.  The four elevations stack vertically (running cursor, no overlap).
;; ============================================================================

(vl-load-com)

;; ---------------------------------------------------------------------------
;; Cumulative grid stations (mm) from a grouped spacing expr (e.g. "5@6000"),
;; SCALED so the chain closes EXACTLY on `total` (mirrors the Plan's ewStations
;; handling).  Fallback = a single span [0,total].
;; ---------------------------------------------------------------------------
(defun peb-elev-stations (expr total / lst sum sc acc out)
  (setq lst (if (and expr (/= expr "")) (peb-parse-mod-expression expr) nil))
  (if (or (null lst) (= (length lst) 0))
    (list 0.0 total)
    (progn
      (setq sum 0.0) (foreach s lst (setq sum (+ sum s)))
      (setq sc (if (> sum 0.0) (/ total sum) 1.0) acc 0.0 out (list 0.0))
      (foreach s lst (setq acc (+ acc (* s sc))) (setq out (append out (list acc))))
      out)))

;; ---------------------------------------------------------------------------
;; Roof-underside Y (absolute) at width-position x for an END wall, given the
;; frame stype.  eaveTop = absolute Y of the eave.  slopeD = slope denominator
;; (rise 1 : slopeD).  numGab = number of gables (MG).
;; ---------------------------------------------------------------------------
(defun peb-elev-roof-y (stype x wid eaveTop slopeD numGab / half gW gi within)
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (cond
    ((= stype "FR") eaveTop)                                   ; flat roof
    ((member stype '("SS" "LT" "CC"))                          ; mono slope, low@0 high@wid
      (+ eaveTop (/ x slopeD)))
    ((= stype "BF")                                            ; butterfly: high at eaves, low at centre
      (+ eaveTop (/ (abs (- x (/ wid 2.0))) slopeD)))
    ((= stype "MG")                                            ; multi-gable sawtooth
      (if (< numGab 1) (setq numGab 1))
      (setq gW (/ wid (float numGab)))
      (setq gi (fix (/ x gW)))
      (if (>= gi numGab) (setq gi (1- numGab)))
      (setq within (- x (* gi gW)))                            ; 0..gW inside this gable
      (+ eaveTop (/ (- (/ gW 2.0) (abs (- within (/ gW 2.0)))) slopeD)))
    (T                                                         ; CS / MS / RC — symmetric gable
      (setq half (/ wid 2.0))
      (+ eaveTop (/ (- half (abs (- x half))) slopeD)))))

;; Ridge/peak X-stations that MUST be sampled so the silhouette keeps its peaks.
(defun peb-elev-ridge-xs (stype wid numGab / out gW i)
  (cond
    ((member stype '("CS" "MS" "RC")) (list (/ wid 2.0)))
    ((= stype "BF")                   (list (/ wid 2.0)))
    ((= stype "MG")
      (if (< numGab 1) (setq numGab 1))
      (setq gW (/ wid (float numGab)) out '() i 0)
      (while (< i numGab)
        (setq out (append out (list (+ (* i gW) (/ gW 2.0)))))
        (setq i (1+ i)))
      out)
    (T nil)))

;; Merge a value into a sorted-unique station list (1 mm tolerance).
(defun peb-elev-add-x (x lst)
  (if (vl-some '(lambda (p) (< (abs (- p x)) 1.0)) lst) lst (cons x lst)))

;; Top Y of a SIDE wall (NSW/FSW).  Mono-slope roofs ride the FSW up the high eave.
(defun peb-side-eave (surf stype eaveTop wid slopeD)
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (if (and (member stype '("SS" "LT" "CC")) (= surf "FSW"))
    (+ eaveTop (/ wid slopeD))
    eaveTop))

;; Grid-bubble label: side walls -> numbers 1..n ; end walls -> letters A..
(defun peb-elev-label (idx isEnd)
  (if isEnd (chr (+ 65 idx)) (itoa (1+ idx))))

;; ---------------------------------------------------------------------------
;; Draw ONE wall elevation with its lower-left corner at (ox,oy).
;; Returns the ABSOLUTE top Y consumed (roof apex) so the caller can stack.
;; ---------------------------------------------------------------------------
(defun peb-draw-elevation (surf ox oy data
                           / len wid eaveH slopeD brickH stype numGab isEnd
                             faceLen stations su prev top sideTop yb i g gx
                             sampleXs xs pts p0 p1 wallOpen owncond
                             braced nB b x0 x1 mid
                             cnt pre psurf pat pw ph psill ptyp mark gx0 gx1 oy0
                             lbl idx bubY bubR lenCount widCount gridId)
  (setq su     (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        len    (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid    (atof (peb-tb-or (MSPL-Get-Str data "WIDTH")  "0"))
        eaveH  (atof (peb-tb-or (MSPL-Get-Str data "CLEARHEIGHT") "4000"))
        brickH (atof (peb-tb-or (MSPL-Get-Str data "BRICKHEIGHT") "0"))
        stype  (strcase (peb-tb-or (MSPL-Get-Str data "STYPE") "CS"))
        slopeD (slope-denom (peb-tb-or (MSPL-Get-Str data "SLOPE") "10"))
        numGab (atoi (peb-tb-or (MSPL-Get-Str data "NUMGABLES") "1")))
  (if (<= eaveH  0.0) (setq eaveH  4000.0))
  (if (<= slopeD 0.0) (setq slopeD 10.0))
  (if (< numGab 1)    (setq numGab 1))
  (cond ((= stype "ACS") (setq stype "CS")) ((= stype "AMS") (setq stype "MS")))
  (setq isEnd (and (member surf '("LEW" "REW")) T)
        top   (+ oy eaveH)
        prev  (getvar "CLAYER"))

  ;; wall-condition (OW_<wall>) — drives sheeting on/off + the note
  (setq owncond (peb-tb-or (MSPL-Get-Str data (strcat "OW_" surf)) "")
        wallOpen (if (boundp 'peb-wall-open-p) (peb-wall-open-p owncond)
                   (and (vl-string-search "OPEN" (strcase owncond))
                        (not (vl-string-search "SHEET" (strcase owncond))))))

  ;; face length + column stations
  (if isEnd
    ;; Rule 4B.34 — an END wall runs across the WIDTH, so its chain is written A downward
    ;; and must be reversed; peb-elev-stations stays unreversed for the LENGTH walls below.
    (setq faceLen wid
          stations (peb-width-stations
                     (MSPL-Get-Str data (if (= surf "LEW") "EWLEXPR" "EWREXPR")) wid))
    (setq faceLen len
          stations (peb-elev-stations (MSPL-Get-Str data "BAYEXPR") len)))
  (if (or (null stations) (< (length stations) 2)) (setq stations (list 0.0 faceLen)))

  ;; side-wall eave top (mono-slope FSW rides high)
  (setq sideTop (peb-side-eave surf stype top wid slopeD))

  ;; ── ground line ─────────────────────────────────────────────
  (setvar "CLAYER" "GROUND")
  (command "_.LINE" (list (- ox (* 900 su)) oy) (list (+ ox faceLen (* 900 su)) oy) "")

  ;; ── wall box + roof profile ─────────────────────────────────
  (setvar "CLAYER" "CLADDING")
  (if isEnd
    (progn
      ;; end wall — verticals rise to the profile at each edge; roof = polyline silhouette
      (command "_.LINE" (list ox oy) (list ox (peb-elev-roof-y stype 0.0 wid top slopeD numGab)) "")
      (command "_.LINE" (list (+ ox faceLen) oy)
               (list (+ ox faceLen) (peb-elev-roof-y stype wid wid top slopeD numGab)) "")
      ;; build sample X's = stations + ridge peaks + ends
      (setq sampleXs stations)
      (foreach rx (peb-elev-ridge-xs stype wid numGab)
        (setq sampleXs (peb-elev-add-x rx sampleXs)))
      (setq sampleXs (peb-elev-add-x 0.0 (peb-elev-add-x wid sampleXs)))
      (setq sampleXs (vl-sort sampleXs '<))
      (setvar "CLAYER" "STRUCTURE")
      (setq pts '())
      (foreach g sampleXs
        (setq pts (cons (list (+ ox g) (peb-elev-roof-y stype g wid top slopeD numGab)) pts)))
      (setq pts (reverse pts))
      (setq p0 (car pts))
      (foreach p1 (cdr pts) (command "_.LINE" p0 p1 "") (setq p0 p1)))
    (progn
      ;; side wall — rectangle to the (flat) eave; roof edge = horizontal line
      (command "_.LINE" (list ox oy) (list ox sideTop) "")
      (command "_.LINE" (list (+ ox faceLen) oy) (list (+ ox faceLen) sideTop) "")
      (setvar "CLAYER" "STRUCTURE")
      (command "_.LINE" (list ox sideTop) (list (+ ox faceLen) sideTop) "")))

  ;; ── roof slope tag (Maimaar convention "ROOF SLOPE 1:NN") — on the sloped end-wall face ──
  ;; Reference-verified (real Maimaar approval DXFs) — slope is shown as the 1:NN ratio, not a "FALL" word.
  (if isEnd
    (progn
      (setvar "CLAYER" "TEXT")
      (txt "MC" (list (+ ox (* faceLen 0.28))
                      (+ (peb-elev-roof-y stype (* faceLen 0.28) wid top slopeD numGab) (* 700 su)))
           (* 300 su) 0
           (strcat "ROOF SLOPE 1:" (if (< slopeD 10.0) (strcat "0" (rtos slopeD 2 0)) (rtos slopeD 2 0))))))

  ;; ── columns at grid stations ────────────────────────────────
  (setvar "CLAYER" "COLUMNS")
  (foreach g stations
    (command "_.LINE" (list (+ ox g) oy)
             (list (+ ox g)
                   (if isEnd (peb-elev-roof-y stype g wid top slopeD numGab) sideTop)) ""))

  ;; ── brick base ──────────────────────────────────────────────
  (setq yb (+ oy (max brickH 0.0)))
  (if (> brickH 0.0)
    (progn (setvar "CLAYER" "BRICK-WALL")
           (command "_.RECTANG" (list ox oy) (list (+ ox faceLen) yb))))

  ;; ── girts (horizontal, ~1800 spacing, brick top → eave) ─────
  (setvar "CLAYER" "GIRTS")
  (setq i 1)
  (while (< (+ yb (* i 1800.0)) (+ oy eaveH))
    (command "_.LINE" (list ox (+ yb (* i 1800.0))) (list (+ ox faceLen) (+ yb (* i 1800.0))) "")
    (setq i (1+ i)))

  ;; ── sheeting panel lines (only when the wall is sheeted) ────
  (if (not wallOpen)
    (progn
      (setvar "CLAYER" "SHEETING")
      (setq gx (+ ox 1500.0))
      (while (< gx (+ ox faceLen))
        (command "_.LINE" (list gx yb)
                 (list gx (if isEnd (peb-elev-roof-y stype (- gx ox) wid top slopeD numGab) sideTop)) "")
        (setq gx (+ gx 1500.0)))))

  ;; ── wall X-bracing in braced bays/panels ────────────────────
  (setq braced (if (boundp 'peb-braced-bays) (peb-braced-bays stations) nil)
        nB (1- (length stations)))
  (setvar "CLAYER" "CROSS")
  (foreach b braced
    (if (and (>= b 0) (< (1+ b) (length stations)))
      (progn
        (setq x0 (+ ox (nth b stations)) x1 (+ ox (nth (1+ b) stations)))
        (command "_.LINE" (list x0 yb) (list x1 (+ oy eaveH)) "")
        (command "_.LINE" (list x0 (+ oy eaveH)) (list x1 yb) "")
        (setq mid (/ (+ x0 x1) 2.0))
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list mid (+ oy (* 0.5 eaveH))) (* 220 su) 0 "BRACED")
        (setvar "CLAYER" "CROSS"))))

  ;; ── wall openings (doors / windows) from PL_* on THIS face ──
  (setq cnt (atoi (peb-tb-or (MSPL-Get-Str data "PL_COUNT") "0")) i 1)
  (while (<= i cnt)
    (setq pre   (strcat "PL" (itoa i) "_")
          psurf (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "SURFACE")) ""))
          pat   (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "AT")) "0"))
          pw    (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "WIDTH")) "0"))
          ph    (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "HEIGHT")) "0"))
          psill (atof (peb-tb-or (MSPL-Get-Str data (strcat pre "SILL")) "0"))
          ptyp  (strcase (peb-tb-or (MSPL-Get-Str data (strcat pre "TYPE")) ""))
          mark  (peb-tb-or (MSPL-Get-Str data (strcat pre "MARK")) ""))
    (if (and (= psurf surf) (> pw 0.0))
      (progn
        (if (<= ph 0.0) (setq ph (if (vl-string-search "DOOR" ptyp) 3000.0 1200.0)))
        (if (and (<= psill 0.0) (not (vl-string-search "DOOR" ptyp))) (setq psill 900.0))
        (setq gx0 (+ ox (- pat (/ pw 2.0))) gx1 (+ ox (+ pat (/ pw 2.0))))
        (setvar "CLAYER" "OPEN")
        (command "_.RECTANG" (list gx0 (+ oy psill)) (list gx1 (+ oy psill ph)))
        (if (or (vl-string-search "DOOR" ptyp) (= ptyp ""))
          (progn                              ; personnel/roll door — cross to read as opening
            (command "_.LINE" (list gx0 (+ oy psill)) (list gx1 (+ oy psill ph)) "")
            (command "_.LINE" (list gx0 (+ oy psill ph)) (list gx1 (+ oy psill)) "")))
        (setvar "CLAYER" "TEXT")
        (txt "MC" (list (/ (+ gx0 gx1) 2.0) (+ oy psill (/ ph 2.0))) (* 260 su) 0 mark)))
    (setq i (1+ i)))

  ;; ── overall height dimension (eave) ─────────────────────────
  (if (boundp 'peb-dim-v-native)
    (vl-catch-all-apply
      (function (lambda ()
        (peb-dim-v-native (- ox (* 1400 su)) oy (+ oy eaveH) (rtos eaveH 2 0))))))

  ;; ── grid bubbles + drop lines along the bottom ──────────────
  ;; ASK, DO NOT INHERIT.  This read *PEB-BUBRAD* and set nothing, so the elevation's bubbles
  ;; were whatever size the sheet rendered BEFORE it happened to leave in the global - the same
  ;; job could plot two different sizes depending on render order.
  (setq bubR (peb-bub-r)
        bubY (- oy (* 3200 su))
        idx  0)
  (foreach g stations
    (setvar "CLAYER" "GRID")
    (command "_.LINE" (list (+ ox g) oy) (list (+ ox g) (+ bubY bubR)) "")
    (grid-bubble (+ ox g) bubY (peb-elev-label idx isEnd) "U")
    (setq idx (1+ idx)))

  ;; ── title (blue, full wall name) + condition note — CLEAR BELOW the grid bubbles ──
  ;; owner 7-Jul (presentation audit): was crammed between the wall base and the bubbles at oy-1500/-2100su
  ;; where — at large text scale — the long condition note overran the title.  Now stacked below the bubbles.
  ;; NOTE: txt/txt-bold already multiply height by *PEB-TEXT-SCALE*, so pass RAW heights here (single-scale).
  ;; The rest of this file pre-scales (* N su) = su^2; keeping these two labels single-scaled makes their
  ;; height and their su-scaled Y offsets grow together, so title & note never overlap at large su.
  ;; grid line this elevation is viewed ALONG — reference wording (Maimaar approval sets):
  ;;   "SIDE WALL ELEVATION  ALONG GRID LINE- <letter>" / "END WALL ELEVATION  ALONG GRID LINE- <number>".
  ;;   Side walls (NSW/FSW) sit on a WIDTH letter line (A at FSW top → last at NSW); end walls (LEW/REW)
  ;;   on a LENGTH number line (1 at LEW → last at REW).
  (setq lenCount (length (peb-elev-stations (MSPL-Get-Str data "BAYEXPR") len))
        widCount (length (peb-elev-stations (MSPL-Get-Str data "EWLEXPR") wid)))
  (if (< lenCount 2) (setq lenCount 2))
  (if (< widCount 2) (setq widCount 2))
  (setq gridId (cond ((= surf "LEW") "1")
                     ((= surf "REW") (itoa lenCount))
                     ((= surf "FSW") "A")
                     ((= surf "NSW") (chr (+ 64 widCount)))
                     (T "1")))
  (setvar "CLAYER" "TEXT")
  (setvar "CECOLOR" "5")   ; Mammut blue view title
  (txt-bold "MC" (list (+ ox (/ faceLen 2.0)) (- oy (* 4400 su))) (peb-th 'HEADING) 0
            (strcat (if isEnd "END WALL ELEVATION" "SIDE WALL ELEVATION")
                    "  ALONG GRID LINE- " gridId))
  (setvar "CECOLOR" "BYLAYER")
  (txt "MC" (list (+ ox (/ faceLen 2.0)) (- oy (* 5400 su))) (peb-th 'SMALL) 0
       (if wallOpen "OPEN FOR ACCESS"
         (if (= owncond "") "FULLY SHEETED" (strcase owncond))))

  (setvar "CLAYER" prev)
  ;; apex Y consumed
  (if isEnd
    (apply 'max (mapcar '(lambda (g) (peb-elev-roof-y stype g wid top slopeD numGab))
                        (peb-elev-add-x (/ wid 2.0) stations)))
    sideTop))

;; ---------------------------------------------------------------------------
;; Draw all four wall elevations, stacked vertically with a running cursor so
;; gable peaks never collide with the next wall's title/bubbles.
;; ---------------------------------------------------------------------------
(defun peb-draw-all-elevations (data / su cursor gap below apex len wid maxSize)
  ;; size-driven text/dim scale (parity with the Plan's continuous formula)
  (setq len (atof (peb-tb-or (MSPL-Get-Str data "LENGTH") "0"))
        wid (atof (peb-tb-or (MSPL-Get-Str data "WIDTH")  "0"))
        maxSize (max len wid 1.0))
  (setq *PEB-TEXT-SCALE* (max 0.80 (min 4.00 (/ maxSize 45000.0))))
  (setq *PEB-DIM-SCALE*  *PEB-TEXT-SCALE*)
  (setq su     (if *PEB-TEXT-SCALE* *PEB-TEXT-SCALE* 1.0)
        below  (* 6000 su)      ; grid bubbles (-3200) + title (-4400) + condition note (-5250) live below oy
        gap    (* 3500 su)
        cursor 0.0)
  (foreach surf '("NSW" "FSW" "LEW" "REW")
    (setq apex (peb-draw-elevation surf 0.0 cursor data))
    (setq cursor (+ apex gap below)))
  ;; owner 7-Jul: shared title block + border (portrait stack -> bottom-right corner block).
  (vl-catch-all-apply (function (lambda () (peb-frame-and-titleblock data "WALL ELEVATIONS")))))

(defun C:PEB-ELEVATION ( / data dataFile)
  (vl-load-com)
  (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
  (if (boundp 'peb-std-setup) (vl-catch-all-apply (function (lambda () (peb-std-setup)))))
  (if (boundp 'peb-dim-set-vars) (vl-catch-all-apply (function (lambda () (peb-dim-set-vars)))))
  (setq dataFile (if (and (boundp '*PEB-DATA-FILE*) *PEB-DATA-FILE*) *PEB-DATA-FILE* nil))
  (if dataFile
    (progn
      (setq data (MSPL-Read-Data dataFile))
      (if data (peb-draw-all-elevations data)
        (princ "\nElevation: data file empty / not v3.")))
    (princ "\nNo data file."))
  (princ))

;; Tiled like peb-plan-from-file: each call shifts its new entities right of the
;; existing drawing so cover/plan/section/elevations sit side by side.
(defun peb-elevation-from-file (path / prev-last prev-max-x)
  (if (not *PEB-TEXT-SCALE*) (setq *PEB-TEXT-SCALE* 1.0))
  (if (not *PEB-DIM-SCALE*)  (setq *PEB-DIM-SCALE* 1.0))
  (setq prev-last (entlast))
  ;; the frame must wrap THIS sheet, not every sheet drawn so far (see
  ;; peb-frame-and-titleblock).  Same marker the tiler already uses.
  (setq *PEB-SHEET-MARK* prev-last)
  (if prev-last
    (progn
      (command "_.REGEN")
      (setq prev-max-x (car (getvar "EXTMAX")))
      (if (or (null prev-max-x) (< prev-max-x -1e10)) (setq prev-max-x nil)))
    (setq prev-max-x nil))
  (setq *PEB-DATA-FILE* path)
  (C:PEB-ELEVATION)
  (setq *PEB-DATA-FILE* nil)
  (if (boundp 'peb-tile-place) (peb-tile-place prev-last prev-max-x))
  (princ))

(princ "\nMAIMAAR_PEB_Elevation.lsp loaded — run (peb-elevation-from-file ...).")
(princ)
