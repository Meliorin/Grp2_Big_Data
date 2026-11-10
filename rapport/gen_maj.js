// Livrable 2 - Groupe 2 - spécification de mise à jour du livrable rendu avec la chaîne complète (J0 à J8)
// Entrées : ../resultats/qualite_*.tsv, ../benchmark/resultats_complet.json, textes_maj.json (paragraphes)
// Sortie : maj_complete.json pour maj_chaine_complete.ps1
const fs = require('fs');
const path = require('path');
const D = (...p) => path.join(__dirname, '..', ...p);
const T = JSON.parse(fs.readFileSync(path.join(__dirname, 'textes_maj.json'), 'utf8'));
const ins = (s) => String(s).replace(/(\d)[  ](?=\d{3}\b)/g, '$1 ').replace(/(\d) %/g, '$1 %');
const nb = (v) => (v === '' || v == null || v === 'NULL' ? '-' : ins(Number(v).toLocaleString('fr-FR').replace(/ /g, ' ')));
const pct = (a, b) => (+b ? ins((100 * a / b).toLocaleString('fr-FR', { maximumFractionDigits: 1, minimumFractionDigits: 1 }) + ' %') : '-');
const acc = (t) => String(t).replace(/rattachee a/g, 'rattachée à').replace(/etablissement de sante/g, 'établissement de santé').replace(/rattache a/g, 'rattaché à').replace(/referentiel/g, 'référentiel').replace(/retrouve /g, 'retrouvé ')
  .replace(/^Deces/, 'Décès').replace(/departement/g, 'département').replace(/deces a l etranger/, "décès à l'étranger").replace(/region/g, 'région')
  .replace(/date de deces/, 'date de décès').replace(/SANS correction/, 'sans correction').replace(/AVEC correction/, 'avec correction')
  .replace(/activite_/, 'activite_').replace(/date d entree/, "date d'entrée").replace(/duree/, 'durée').replace(/heures invalides/, 'heures invalides')
  .replace(/^Hospitalisation :/, 'Hospitalisation :').replace(/hors -1/, 'hors -1');
function tsv(nom) {
  const f = D('resultats', `qualite_${nom}.tsv`);
  const l = fs.readFileSync(f, 'utf8').split(/\r?\n/).filter((x) => x.trim() && !/^(WARN|SLF4J|Logging)/.test(x));
  const ent = l[0].split('\t').map((h) => h.replace(/^.*\./, ''));
  return l.slice(1).map((x) => Object.fromEntries(x.split('\t').map((v, i) => [ent[i], v])));
}
// journal : dernière ligne par job (J4 a tourné deux fois)
const jr = {};
for (const j of tsv('journal')) if (!jr[j.job] || j.horodatage > jr[j.job].horodatage) jr[j.job] = j;
const journal = Object.values(jr).sort((a, b) => a.job.localeCompare(b.job));
const compl = tsv('completude').filter((c) => +c.renseignees < +c.lignes);
const coh = tsv('coherence');
const rej = tsv('rejets').sort((a, b) => a.job.localeCompare(b.job) || +b.lignes - +a.lignes);
for (const j of ['J5_Consultations', 'J6_Hospitalisations']) if (!rej.some((r) => r.job === j)) rej.push({ job: j, motif: 'aucun rejet', lignes: '0' });
rej.sort((a, b) => a.job.localeCompare(b.job));
const orph = tsv('orphelins');

const R = JSON.parse(fs.readFileSync(D('benchmark', 'resultats_complet.json'), 'utf8'));
const ordre = (a, b) => parseInt(a.slice(1)) - parseInt(b.slice(1)) || a.localeCompare(b);
const req = [...new Set(R.mesures.map((m) => m.requete))].sort(ordre);
const m = (s, q) => R.mesures.find((x) => x.scenario === s && x.requete === q) || {};
const SC = ['avant', 'stats', 'partition', 'partition_stats'];

const spec = {
  tables: [
    { cle: ['J7_Deces', 'Lignes Bronze'], lignes: journal.map((j) => [j.job, nb(j.lignes_bronze), nb(j.lignes_silver), nb(j.lignes_rejetees), nb(j.lignes_gold), j.statut]) },
    { cle: ['finess_site', 'Renseignées', 'Taux'], lignes: compl.map((c) => [c.table_nom, c.colonne, nb(c.lignes), nb(c.renseignees), pct(c.renseignees, c.lignes)]) },
    { cle: ['(RPPS)', 'finess_geo dans le r'], lignes: coh.map((c) => [acc(c.controle), nb(c.lignes), nb(c.conformes), pct(c.conformes, c.lignes)]) },
    { cle: ['J8_Satisfaction', 'non calculable'], lignes: rej.map((r) => [r.job, acc(r.motif), nb(r.lignes)]) },
    { cle: ['Orphelines', 'fait_deces'], lignes: orph.map((o) => [o.fait, o.cle, nb(o.lignes), nb(o.orphelines)]) },
    { cle: ['Indicateur calculé'], lignes: req.map((q) => [q, m('avant', q).titre.replace(/^Q\w+ - /, '')]) },
    { cle: ['cart part'], lignes: req.map((q) => { const a = m('avant', q).mediane_ms, f = m('partition_stats', q).mediane_ms;
      return [q, ...SC.map((s) => nb(m(s, q).mediane_ms)), (m('partition_stats', q).partitions_lues || []).join(', ') || '-',
        a && f ? ins((f <= a ? '-' : '+') + Math.abs(Math.round(100 * (a - f) / a)) + ' %') : '-']; }) },
  ],
  paragraphes: T.paragraphes.map((p) => ({ debut: p.debut, nouveau: ins(p.nouveau) })),
  ajouts: (T.ajouts || []).map((a) => ({ apres: a.apres, texte: ins(a.texte) })),
  remplacements: T.remplacements || [],
  images: [
    { legende: 'Temps de réponse relatif sur la Gold du groupe', chemin: D('benchmark', 'graphiques_complet', '1_temps_relatif.png') },
    { legende: "Données à lire selon le plan d'exécution, Gold du groupe", chemin: D('benchmark', 'graphiques_complet', '3_donnees_lues.png') },
  ],
};
fs.writeFileSync(path.join(__dirname, 'maj_complete.json'), JSON.stringify(spec, null, 1));
console.log(spec.tables.map((t) => `${t.cle[0]}: ${t.lignes.length}`).join(' | '));
