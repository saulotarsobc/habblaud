// Reutiliza o instalador oficial, com caminhos aceitos pelo shell do Windows.
// Mantém backups, posições dos hooks e a revisão de confiança pelo usuário.
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { HOOK_SCRIPT, parseArgs, run } from './codex-install';

if (process.platform !== 'win32') throw new Error('Use npm run codex:install neste sistema.');
// `node` sem aspas executa tanto em PowerShell quanto em cmd; o instalador
// Unix usa um executável entre aspas sem o operador & do PowerShell.
execFileSync('node', ['--version'], { windowsHide: true });
const opts = parseArgs(process.argv.slice(2));
if (opts === 'help') throw new Error('Uso: npx tsx scripts/codex-windows.ts install|status|uninstall');
if (opts.node) throw new Error('Este adaptador usa o Node do PATH do Windows.');
process.exitCode = await run(opts, {
  env: process.env,
  home: process.env.HOME || homedir(),
  now: new Date(),
  hookPath: HOOK_SCRIPT.replaceAll('\\', '/'),
  out: console.log,
});
