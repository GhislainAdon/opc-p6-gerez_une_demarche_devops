// Build helper: extract ```mermaid``` blocks from the livrable-2 markdown,
// render each to captures/l2diagN.png, and emit a working copy of the md with
// the mermaid blocks replaced by image links. Run pandoc afterwards.
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const SRC = path.join(__dirname, "livrable-2-documentation-cicd.md");
const OUT_MD = path.join(__dirname, "_l2-docx-src.md");
const CAP = path.join(__dirname, "captures");
fs.mkdirSync(CAP, { recursive: true });

let md = fs.readFileSync(SRC, "utf8");
const re = /```mermaid\r?\n([\s\S]*?)```/g;
let i = 0, m, out = "", last = 0;
while ((m = re.exec(md)) !== null) {
  i++;
  const mmd = path.join(CAP, `l2diag${i}.mmd`);
  const png = path.join(CAP, `l2diag${i}.png`);
  fs.writeFileSync(mmd, m[1]);
  console.log(`rendering diagram ${i} ...`);
  execSync(
    `npx -y @mermaid-js/mermaid-cli@11 -i "${mmd}" -o "${png}" -b white -s 2`,
    { stdio: "inherit" }
  );
  out += md.slice(last, m.index) + `![Schéma ${i}](captures/l2diag${i}.png)`;
  last = re.lastIndex;
}
out += md.slice(last);
fs.writeFileSync(OUT_MD, out);
console.log(`\n${i} diagram(s) rendered. Working md -> ${OUT_MD}`);
