// vectors:check — regenerates the golden vectors to a temp dir and diffs them
// against the committed parity/vectors/. A mismatch means either:
//   (a) the exporter is non-deterministic (a bug — fixtures must be reproducible), or
//   (b) a gameplay rule changed on the Expo side without the vectors being
//       regenerated (intentional? then run `npm run vectors:export` and commit,
//       and re-run the Godot parity pass).
//
// Run:  npm run vectors:check

import { execFileSync } from 'child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

const COMMITTED = join(__dirname, '..', 'parity', 'vectors');
const exporter = join(__dirname, 'export-parity-vectors.ts');

// Mirror the forced-CommonJS ts-node options used by the npm scripts so the
// re-export runs under the same Node/module config as the original.
const TS_NODE_CJS_OPTS = JSON.stringify({
  module: 'commonjs', moduleResolution: 'node',
  esModuleInterop: true, resolveJsonModule: true, target: 'ES2019',
});

const tmp = mkdtempSync(join(tmpdir(), 'parity-vectors-'));
try {
  execFileSync(
    process.execPath,
    [require.resolve('ts-node/dist/bin.js'), '--skip-project', '-O', TS_NODE_CJS_OPTS, exporter],
    { env: { ...process.env, VECTORS_OUT_DIR: tmp }, stdio: 'inherit' },
  );

  const committedFiles = readdirSync(COMMITTED).filter(f => f.endsWith('.json')).sort();
  const freshFiles = readdirSync(tmp).filter(f => f.endsWith('.json')).sort();

  const problems: string[] = [];
  if (committedFiles.join(',') !== freshFiles.join(',')) {
    problems.push(`File set differs.\n  committed: ${committedFiles.join(', ')}\n  fresh:     ${freshFiles.join(', ')}`);
  }
  for (const f of freshFiles) {
    if (!committedFiles.includes(f)) continue;
    const a = readFileSync(join(COMMITTED, f), 'utf8');
    const b = readFileSync(join(tmp, f), 'utf8');
    if (a !== b) problems.push(`Vector drift in ${f} — regenerate with \`npm run vectors:export\` and commit.`);
  }

  if (problems.length > 0) {
    // eslint-disable-next-line no-console
    console.error('\n✗ Parity vectors are stale or non-deterministic:\n' + problems.map(p => '  - ' + p).join('\n') + '\n');
    process.exit(1);
  }
  // eslint-disable-next-line no-console
  console.log(`✓ Parity vectors match (${committedFiles.length} files, deterministic).`);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
