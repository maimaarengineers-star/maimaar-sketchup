# Title Case the component-library folders (PD_RULEBOOK S12b).
# Idempotent: run it as often as you like. It renames ONLY folders under engine\Library,
# and it NEVER touches AutoCAD - if a folder is locked it says so and moves on.
#
# Why a folder can be locked: AutoCAD parks its working directory on the last folder it
# opened a drawing from, and an open Explorer window does the same. Close the DRAWING (or
# the Explorer window), never AutoCAD itself, then re-run this.
#
# AFTER a rename that changes "_" to a space, the load paths must match. They live in:
#   2_Sales CRM\services\drawingRender.ts   - buildPdfScr, buildDwgScr, buildReuseScr
#   2_Sales CRM\services\drawingData.ts     - loadLines
# A case-only rename cannot break a path on Windows; an underscore-to-space one will,
# silently, and the sheet plots as an empty A4 with a perfect title block.

$L = Split-Path -Parent $MyInvocation.MyCommand.Path
$map = @{ 'louver' = 'Louver'; 'ridge_ventilator' = 'Ridge Ventilator' }
$husks = @('sliding_door')     # emptied by an earlier rename

foreach ($from in $map.Keys) {
  $to  = $map[$from]
  $src = Join-Path $L $from
  $dst = Join-Path $L $to
  if (-not (Test-Path -LiteralPath $src)) { "skip    $from (already done)"; continue }
  if ((Get-Item -LiteralPath $src).Name -ceq $to) { "skip    $from (already $to)"; continue }
  try {
    if ($from.ToLower() -eq $to.ToLower()) {          # case-only: needs two steps on NTFS
      $tmp = Join-Path $L ('__tmp_' + [guid]::NewGuid().ToString('N').Substring(0,6))
      [System.IO.Directory]::Move($src, $tmp)
      [System.IO.Directory]::Move($tmp, $dst)
    } else {
      [System.IO.Directory]::Move($src, $dst)
    }
    "OK      $from -> $to"
  } catch { "LOCKED  $from  (close the drawing / Explorer window, then re-run)" }
}

foreach ($h in $husks) {
  $p = Join-Path $L $h
  if (-not (Test-Path -LiteralPath $p)) { "skip    $h (already gone)"; continue }
  if ((Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue).Count -gt 0) {
    "KEPT    $h is NOT empty - not removing"; continue
  }
  try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop; "OK      removed empty husk $h" }
  catch { "LOCKED  $h husk (close the Explorer window, then re-run)" }
}

''
'Library now:'
Get-ChildItem -LiteralPath $L -Directory | Select-Object -ExpandProperty Name
