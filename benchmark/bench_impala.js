// Livrable 2 - Groupe 2 (Datavengers) - benchmark Impala de la chaîne du groupe (tables dim_* / fait_*) - v1.0
// Scénarios : avant (gold_brut_grp sans statistiques), stats, partition (gold sans statistiques), partition_stats,
// buckets (gold_opt du PDF du groupe). 1 exécution de chauffe + 3 mesurées, médiane de « Fetched ... in X s ».
// Variables : VM_SSH = commande ssh vers la VM.
const { spawnSync } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const FAITS_TOUS = ['fait_consultation_etablissement', 'fait_consultation_diagnostic', 'fait_consultation_professionnel',
  'fait_hospitalisation_globale', 'fait_hospitalisation_diagnostic', 'fait_hospitalisation_patient',
  'fait_hospitalisation_etablissement', 'fait_deces', 'fait_satisfaction', 'fait_population_patient'];
const FAITS = process.env.BENCH_FAITS ? process.env.BENCH_FAITS.split(',') : FAITS_TOUS;
const DIMS_TOUS = ['dim_temps', 'dim_localisation', 'dim_etablissement', 'dim_professionnel', 'dim_patient', 'dim_diagnostic', 'dim_type_satisfaction'];
const DIMS = process.env.BENCH_DIMS ? process.env.BENCH_DIMS.split(",") : DIMS_TOUS;
// faits partitionnés par année dans gold (version du groupe) et dans gold_opt (PDF du groupe)
const PARTITIONNEES = { gold: FAITS.filter((t) => !['fait_population_patient'].includes(t)),
  gold_opt: FAITS.filter((t) => !['fait_population_patient', 'fait_consultation_professionnel'].includes(t)), gold_brut_grp: [] };
const drop = (db) => [...FAITS, ...DIMS].map((t) => `DROP STATS ${db}.${t};`);
const compute = (db) => [...FAITS, ...DIMS].map((t) =>
  (PARTITIONNEES[db].includes(t) ? 'COMPUTE INCREMENTAL STATS ' : 'COMPUTE STATS ') + `${db}.${t};`);
const SCENARIOS = {
  avant: { db: 'gold_brut_grp', nom: 'Avant (Parquet non partitionné, sans statistiques)', prep: drop('gold_brut_grp') },
  stats: { db: 'gold_brut_grp', nom: 'Statistiques (COMPUTE STATS)', prep: compute('gold_brut_grp') },
  partition: { db: 'gold', nom: 'Partitionnement par année (gold du groupe)', prep: drop('gold') },
  partition_stats: { db: 'gold', nom: 'Partitionnement + statistiques', prep: compute('gold') },
  buckets: { db: 'gold_opt', nom: 'Partitions + buckets (gold_opt du groupe) + statistiques', prep: compute('gold_opt') },
};
const scenario = process.argv[2];
if (!SCENARIOS[scenario]) { console.error('Usage : node bench_impala.js ' + Object.keys(SCENARIOS).join('|')); process.exit(2); }
const { db, nom, prep } = SCENARIOS[scenario];
const RUNS = 3;
const SSH = (process.env.VM_SSH || '').split(' ').filter(Boolean);
if (!SSH.length) { console.error('Définir VM_SSH'); process.exit(2); }

// envoie un script SQL à impala-shell sur la VM (via un fichier temporaire distant)
function impala(sql, base = db) {
  const r = spawnSync(SSH[0], [...SSH.slice(1),
    `export PYTHONIOENCODING=utf-8 LC_ALL=en_US.UTF-8; cat > /tmp/bench_q.sql && impala-shell -d ${base} -B --output_delimiter='|' -f /tmp/bench_q.sql`],
  { input: sql, encoding: 'utf8', maxBuffer: 1 << 26 });
  if (r.status !== 0) throw new Error(r.stderr.split('\n').filter((l) => /ERROR|Error|AnalysisException/.test(l)).join('\n') || r.stderr.slice(-2000));
  return { out: r.stdout, err: r.stderr };
}

const params = JSON.parse(fs.readFileSync(path.join(__dirname, 'parametres.json'), 'utf8'));
const dossier = path.join(__dirname, process.env.BENCH_REQ || 'requetes');
const requetes = fs.readdirSync(dossier).filter((f) => f.endsWith('.sql')).sort().map((f) => {
  let sql = fs.readFileSync(path.join(dossier, f), 'utf8');
  for (const [k, v] of Object.entries(params)) sql = sql.split(`{{${k}}}`).join(v);
  return { id: f.split('_')[0], titre: sql.split('\n')[0].replace(/^--\s*/, ''), sql: sql.trim().replace(/;\s*$/, '') };
});

const t0 = Date.now();
impala('INVALIDATE METADATA;\n' + prep.join('\n'), 'default');
const prepS = (Date.now() - t0) / 1000;
console.log(`${scenario} : préparation (${prep[0].split(' ')[0]} ${prep[0].split(' ')[1]}...) en ${prepS.toFixed(1)} s`);

const fichier = path.join(__dirname, process.env.BENCH_SORTIE || 'resultats_impala.json');
const tous = fs.existsSync(fichier) ? JSON.parse(fs.readFileSync(fichier, 'utf8')) : { mesures: [], preparations: {} };
tous.mesures = tous.mesures.filter((m) => m.scenario !== scenario);
tous.preparations[scenario] = +prepS.toFixed(1);

for (const q of requetes) {
  const { out, err } = impala(Array(RUNS + 1).fill(q.sql + ';').join('\n'));
  const fetched = [...err.matchAll(/Fetched (\d+) row\(s\) in ([\d.]+)s/g)].map((m) => ({ n: +m[1], s: +m[2] }));
  if (fetched.length !== RUNS + 1) throw new Error(`${q.id} : ${fetched.length} mesures lues\n${err.slice(-1500)}`);
  const lignes = out.split('\n').filter(Boolean).slice(0, fetched[0].n);
  const temps = fetched.slice(1).map((f) => f.s * 1000).sort((a, b) => a - b);
  const plan = impala(`EXPLAIN ${q.sql};`).out;
  const partitions = [...plan.matchAll(/partitions=(\d+)\/(\d+)/g)].map((m) => `${m[1]}/${m[2]}`);
  const octets = [...plan.matchAll(/size=([\d.]+)(KB|MB|GB|B)/g)].reduce((a, m) => a + +m[1] * { B: 1, KB: 1e3, MB: 1e6, GB: 1e9 }[m[2]], 0);
  tous.mesures.push({ scenario, nom_scenario: nom, base: db, requete: q.id, titre: q.titre,
    mediane_ms: Math.round(temps[Math.floor(RUNS / 2)]), essais_ms: temps.map(Math.round),
    partitions_lues: partitions, octets_planifies: Math.round(octets), lignes_resultat: lignes.length,
    empreinte: crypto.createHash('md5').update(lignes.join('\n')).digest('hex') });
  console.log(`${scenario.padEnd(16)} ${q.id.padEnd(4)} ${String(Math.round(temps[2])).padStart(7)} ms  partitions ${partitions.join(' ') || '-'}  ${(octets / 1e6).toFixed(1)} Mo`);
}

const ref = Object.fromEntries(tous.mesures.filter((m) => m.scenario === 'avant').map((m) => [m.requete, m.empreinte]));
for (const m of tous.mesures) m.identique_avant = ref[m.requete] ? m.empreinte === ref[m.requete] : null;
tous.date = new Date().toISOString();
tous.essais = RUNS;
fs.writeFileSync(fichier, JSON.stringify(tous, null, 2));
const diff = tous.mesures.filter((m) => m.identique_avant === false);
console.log(diff.length ? `ATTENTION : résultats différents pour ${diff.map((d) => d.scenario + '/' + d.requete)}` : 'Résultats identiques à l\'étape « avant » : OK');
