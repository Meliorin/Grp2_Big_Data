// Livrable 2 - Groupe 2 (Datavengers) - graphiques du benchmark Impala de la chaîne du groupe - v1.0
// SVG puis PNG (Chrome headless) à partir de resultats_impala.json. Usage : node graphiques.js
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const R = JSON.parse(fs.readFileSync(path.join(__dirname, process.env.BENCH_SORTIE || 'resultats_impala.json'), 'utf8'));
const OUT = path.join(__dirname, process.env.BENCH_GRAPH || 'graphiques');
fs.mkdirSync(OUT, { recursive: true });
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';

// Palette catégorielle validée (ordre fixe : une couleur suit toujours le même scénario)
const SC = [
  { id: 'avant', nom: 'Avant (sans partition ni stats)', c: '#2a78d6' },
  { id: 'stats', nom: 'Statistiques seules', c: '#eb6834' },
  { id: 'partition', nom: 'Partitions seules', c: '#1baf7a' },
  { id: 'partition_stats', nom: 'Partitions + stats', c: '#eda100' },
  { id: 'buckets', nom: 'Partitions + buckets + stats', c: '#8a5cc6' },
].filter((x) => R.mesures.some((m) => m.scenario === x.id));
const INK = '#0b0b0b', INK2 = '#52514e', GRID = '#e4e3df', SURF = '#ffffff';
const FONT = "'Gill Sans MT', 'Gill Sans', Calibri, sans-serif";
const LIB = {
  Q1: 'Q1 Établissement X / période', Q2: 'Q2 Diagnostic X / période', Q3: 'Q3 Hospitalisation globale',
  Q4: 'Q4 Hospitalisation / diagnostic', Q5: 'Q5 Hospitalisation sexe / âge', Q6: 'Q6 Consultation / professionnel',
  Q7: 'Q7 Décès / région 2019', Q7b: 'Q7b Décès 2019 (filtre via Temps)', Q8: 'Q8 Satisfaction / région 2020', Q9: 'Q9 Décès mensuels (toutes années)', Q10: 'Q10 Top 10 départements 2020-21', Q11: 'Q11 Satisfaction par critère',
};
const val = (sc, q, champ) => (R.mesures.find((m) => m.scenario === sc && m.requete === q) || {})[champ];
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');
const fmt = (v, d = 1) => v.toLocaleString('fr-FR', { maximumFractionDigits: d, minimumFractionDigits: 0 });

// Graphique en barres horizontales groupées, un seul axe (valeurs >= 0)
function barres({ titre, sousTitre, groupes, series, valeur, unite, etiquette, ligneRef, max: maxForce }) {
  const W = 1000, gauche = 250, droite = 70, haut = 96, barH = 13, gap = 2, gapGroupe = 16;
  const hGroupe = series.length * (barH + gap) - gap;
  const H = haut + groupes.length * (hGroupe + gapGroupe) + 40;
  const vals = groupes.flatMap((g) => series.map((s) => valeur(s.id, g) || 0));
  const max = maxForce || Math.max(...vals, ligneRef || 0) * 1.08;
  const x = (v) => gauche + (v / max) * (W - gauche - droite);
  const pas = [1, 2, 2.5, 5, 10].map((m) => m * 10 ** Math.floor(Math.log10(max / 5))).find((p) => max / p <= 6);
  let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="${FONT}">`;
  svg += `<rect width="${W}" height="${H}" fill="${SURF}"/>`;
  svg += `<text x="20" y="30" font-size="20" font-weight="600" fill="${INK}">${esc(titre)}</text>`;
  svg += `<text x="20" y="52" font-size="14" fill="${INK2}">${esc(sousTitre)}</text>`;
  // légende (toujours présente pour >= 2 séries)
  let lx = 20;
  for (const s of series) {
    svg += `<rect x="${lx}" y="66" width="12" height="12" rx="2" fill="${s.c}"/><text x="${lx + 18}" y="77" font-size="13" fill="${INK}">${esc(s.nom)}</text>`;
    lx += 30 + s.nom.length * 7.2;
  }
  // grille verticale discrète
  for (let v = 0; v <= max; v += pas) {
    svg += `<line x1="${x(v)}" x2="${x(v)}" y1="${haut - 6}" y2="${H - 34}" stroke="${GRID}" stroke-width="1"/>`;
    svg += `<text x="${x(v)}" y="${H - 16}" font-size="12" fill="${INK2}" text-anchor="middle">${fmt(v)}${unite}</text>`;
  }
  if (ligneRef) svg += `<line x1="${x(ligneRef)}" x2="${x(ligneRef)}" y1="${haut - 6}" y2="${H - 34}" stroke="${INK2}" stroke-width="1.5" stroke-dasharray="4 3"/>`;
  groupes.forEach((g, i) => {
    const y0 = haut + i * (hGroupe + gapGroupe);
    svg += `<text x="${gauche - 10}" y="${y0 + hGroupe / 2 + 5}" font-size="14" fill="${INK}" text-anchor="end">${esc(LIB[g] || g)}</text>`;
    series.forEach((s, j) => {
      const v = valeur(s.id, g);
      if (v === undefined) return;
      const y = y0 + j * (barH + gap);
      const w = Math.max(x(v) - gauche, 1.5);
      // extrémité arrondie côté valeur, ancrée sur la ligne de base
      svg += `<path d="M${gauche},${y} h${Math.max(w - 4, 0)} a4,4 0 0 1 4,4 v${barH - 8} a4,4 0 0 1 -4,4 h${-Math.max(w - 4, 0)} z" fill="${s.c}"/>`;
      if (etiquette) svg += `<text x="${gauche + w + 6}" y="${y + barH - 2}" font-size="12" fill="${INK2}">${esc(etiquette(v, s.id, g))}</text>`;
    });
  });
  svg += `<line x1="${gauche}" x2="${gauche}" y1="${haut - 6}" y2="${H - 34}" stroke="${INK2}" stroke-width="1"/>`;
  return svg + '</svg>';
}

function png(nom, svg) {
  const svgFile = path.join(OUT, nom + '.svg');
  fs.writeFileSync(svgFile, svg);
  const [, w, h] = svg.match(/width="(\d+)" height="(\d+)"/);
  const html = path.join(OUT, nom + '.html');
  fs.writeFileSync(html, `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#fff}</style></head><body>${svg}</body></html>`);
  const r = spawnSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--window-size=${w},${h}`,
    '--force-device-scale-factor=2', `--screenshot=${path.join(OUT, nom + '.png')}`, 'file:///' + html.replace(/\\/g, '/')], { encoding: 'utf8' });
  fs.rmSync(html);
  if (r.status !== 0) console.error(r.stderr);
  console.log('graphique', nom + '.png');
}

const requetes = [...new Set(R.mesures.map((m) => m.requete))].sort((a, b) => parseInt(a.slice(1)) - parseInt(b.slice(1)) || a.localeCompare(b));
const N = R.essais || 3;

// 1. Temps relatif : 100 % = temps avant optimisation
png('1_temps_relatif', barres({
  titre: 'Temps de réponse relatif, par requête et par optimisation (Impala)',
  sousTitre: `Médiane de ${N} exécutions, 100 % = temps avant optimisation (plus court = plus rapide)`,
  groupes: requetes, series: SC, unite: ' %', ligneRef: 100,
  valeur: (sc, q) => { const a = val('avant', q, 'mediane_ms'), v = val(sc, q, 'mediane_ms'); return v === undefined ? undefined : (100 * v) / a; },
  etiquette: (v) => fmt(v, 0) + ' %',
}));

// 2. Temps absolus : avant / version retenue (partitions + statistiques) / buckets
png('2_temps_avant_apres', barres({
  titre: 'Temps de réponse avant et après optimisation (ms)',
  sousTitre: `Médiane de ${N} exécutions, temps mesuré par impala-shell, Gold en Parquet`,
  groupes: requetes, series: SC.filter((x) => ["avant", "partition_stats", "buckets"].includes(x.id)), unite: ' ms',
  valeur: (sc, q) => val(sc, q, 'mediane_ms'),
  etiquette: (v) => fmt(v, 0) + ' ms',
}));

// 3. Volume de données planifié : le partitionnement réduit ce qui est lu
png('3_donnees_lues', barres({
  titre: "Données à lire selon le plan d'exécution (Mo)",
  sousTitre: "Somme des tailles annoncées par EXPLAIN : le filtre sur l'année n'ouvre que les partitions utiles",
  groupes: requetes, series: SC.filter((x) => ["avant", "partition", "buckets"].includes(x.id)), unite: ' Mo',
  valeur: (sc, q) => { const v = val(sc, q, 'octets_planifies'); return v === undefined ? undefined : v / 1e6; },
  etiquette: (v) => fmt(v, v < 1 ? 2 : 1) + ' Mo',
}));
