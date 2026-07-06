const fs = require('fs');
const path = require('path');
const inFile = path.join(__dirname, '..', 'supabase', 'apply_player_club_updates.sql');
const outDir = path.join(__dirname, '..', 'supabase', 'updates_chunks');
if (!fs.existsSync(inFile)) { console.error('input not found', inFile); process.exit(1); }
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
const txt = fs.readFileSync(inFile, 'utf8');
// extract the UPDATE lines between BEGIN; and COMMIT;
const begin = txt.indexOf('BEGIN;');
const commit = txt.lastIndexOf('COMMIT;');
if (begin === -1 || commit === -1) { console.error('BEGIN or COMMIT not found'); process.exit(1); }
const body = txt.slice(begin + 'BEGIN;'.length, commit).trim();
const lines = body.split(/\r?\n/).filter(l => l.trim().length>0);
// count only UPDATE lines
const updates = lines.filter(l => l.trim().toUpperCase().startsWith('UPDATE '));
const total = updates.length;
const chunks = 10;
const per = Math.ceil(total/chunks);
for (let i=0;i<chunks;i++){
  const start = i*per;
  const part = updates.slice(start, start+per);
  if (part.length===0) continue;
  const fname = path.join(outDir, `chunk_${String(i+1).padStart(2,'0')}.sql`);
  const content = ['-- chunk', `-- part ${i+1} of ${chunks}`, 'BEGIN;']
    .concat(part)
    .concat(['COMMIT;',''])
    .join('\n');
  fs.writeFileSync(fname, content);
  console.log('wrote', fname, part.length, 'updates');
}
console.log('total updates', total, 'chunks', chunks);