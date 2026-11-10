param([string]$Doc, [string]$Spec)
# Remplace dans le livrable rendu (retouché à la main) le contenu des tableaux / paragraphes / images
# de la chaîne du groupe par les résultats de la chaîne complète (J5 et J6 compris).
$S = Get-Content $Spec -Raw -Encoding UTF8 | ConvertFrom-Json
$w = New-Object -ComObject Word.Application
$w.Visible = $false; $w.DisplayAlerts = 0
$d = $w.Documents.Open($Doc)
$norm = { param($t) ($t -replace [char]160, ' ') }

# 1. Tableaux : on garde la ligne d'en-tête et on réécrit toutes les lignes de données
foreach ($ts in $S.tables) {
  $cible = $null
  foreach ($tb in $d.Tables) {
    $txt = & $norm $tb.Range.Text
    $ok = $true; foreach ($c in $ts.cle) { if (-not $txt.Contains($c)) { $ok = $false } }
    if ($ok) { $cible = $tb; break }
  }
  if (-not $cible) { "TABLEAU INTROUVABLE : $($ts.cle -join ' + ')"; continue }
  $n = $ts.lignes.Count
  while ($cible.Rows.Count -gt $n + 1) { $cible.Rows($cible.Rows.Count).Delete() }
  while ($cible.Rows.Count -lt $n + 1) { $cible.Rows.Add() | Out-Null }
  for ($i = 0; $i -lt $n; $i++) {
    $l = $ts.lignes[$i]
    for ($j = 0; $j -lt $l.Count; $j++) { $cible.Cell($i + 2, $j + 1).Range.Text = [string]$l[$j] }
  }
  "tableau réécrit ($n lignes) : $($ts.cle -join ' + ')"
}

# 2. Paragraphes : remplacement complet d'un paragraphe repéré par son début
foreach ($p in $d.Paragraphs) {
  if ($p.Range.Information(12)) { continue }
  $t = & $norm $p.Range.Text
  foreach ($r in $S.paragraphes) {
    if ($t.StartsWith($r.debut)) { $rg = $p.Range; $rg.MoveEnd(1, -1) | Out-Null; $rg.Text = $r.nouveau; "paragraphe : $($r.debut)" }
  }
}

# 3. Paragraphes ajoutés après un paragraphe repéré
foreach ($a in $S.ajouts) {
  foreach ($p in $d.Paragraphs) {
    if ($p.Range.Information(12)) { continue }
    if ((& $norm $p.Range.Text).StartsWith($a.apres)) {
      $p.Range.InsertParagraphAfter(); $nv = $p.Next(); $rg = $nv.Range; $rg.MoveEnd(1, -1) | Out-Null; $rg.Text = $a.texte
      "ajout après : $($a.apres)"; break
    }
  }
}

# 4. Images : remplacées à la même place (repérées par le début de leur légende)
foreach ($im in $S.images) {
  foreach ($sh in @($d.InlineShapes)) {
    $leg = & $norm ($sh.Range.Paragraphs(1).Next().Range.Text)
    if ($leg.Contains($im.legende)) {
      $rg = $sh.Range; $largeur = $sh.Width
      $sh.Delete()
      $nv = $d.InlineShapes.AddPicture($im.chemin, $false, $true, $rg)
      $ratio = $nv.Height / $nv.Width; $nv.Width = $largeur; $nv.Height = $largeur * $ratio
      "image remplacée : $($im.legende)"; break
    }
  }
}
# 5. Petits remplacements de texte (légendes, conclusion)
foreach ($rp in $S.remplacements) {
  $r = $d.Content
  if ($r.Find.Execute($rp.cherche, $true, $false, $false, $false, $false, $true, 0, $false, $rp.remplace, 2)) { "remplacé : $($rp.cherche)" } else { "NON TROUVÉ : $($rp.cherche)" }
}
foreach ($t in $d.TablesOfContents) { $t.Update() }
foreach ($t in $d.TablesOfFigures) { $t.Update() }
$d.Save(); "pages : " + $d.ComputeStatistics(2); $d.Close(); $w.Quit()
