// 清除 qrcts 构建产物中残留的 /qrcts 子路径前缀
// 背景：站点已从 yangxivi.github.io/qrcts/ 迁移到自定义域名 qr.xiviai.cn 根路径
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, '..', 'assets', 'index-muZMgV9K.js');
let code = fs.readFileSync(FILE, 'utf8');
const before = code.length;

const patches = [
  {
    name: '登录/注册成功后跳转（去掉 /qrcts 前缀）',
    from: 'window.location.href="/qrcts"+g',
    to: 'window.location.href=g',
    all: true,
  },
  {
    name: '流转表格里的追溯页链接',
    from: 'href:`/qrcts/t/${x.sn_code.sn}`',
    to: 'href:`/t/${x.sn_code.sn}`',
    all: false,
  },
  {
    name: '二维码内容 URL 前缀（关键：影响所有已生成二维码）',
    from: 'const Tt=(window.location.origin+"/qrcts")',
    to: 'const Tt=window.location.origin',
    all: false,
  },
];

let ok = 0;
for (const p of patches) {
  const count = code.split(p.from).length - 1;
  if (count === 0) {
    console.log(`  [跳过] ${p.name} —— 未找到目标串（可能已修复）`);
    continue;
  }
  code = p.all ? code.split(p.from).join(p.to) : code.replace(p.from, p.to);
  console.log(`  [已修] ${p.name} —— 替换 ${p.all ? count : 1} 处`);
  ok++;
}

fs.writeFileSync(FILE, code);
console.log(`\n文件大小: ${before} -> ${code.length}`);

// 复查残留
const left = code.split('/qrcts').length - 1;
console.log(`残留 "/qrcts" 出现次数: ${left}`);
const bm = code.match(/basename:"[^"]*"/g);
console.log(`basename: ${bm ? bm.join(', ') : '未找到'}`);
console.log(ok > 0 ? '\n补丁应用完成。' : '\n无改动。');
