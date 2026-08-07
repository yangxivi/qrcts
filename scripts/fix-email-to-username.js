/**
 * 修复：前端遗留的 Supabase Auth `.email` 字段引用
 *
 * 背景：项目已从 Supabase Auth 迁移到「纯数据库账号密码认证」，
 *       profiles 表用 username 列，不存在 email 列（查询报 42703）。
 *       但打包产物里仍残留 4 处 `.email`，导致：
 *         - 重置操作工密码：p_username 传 undefined -> HTTP 404 PGRST202，必然失败
 *         - 操作工列表「账号」列：渲染 undefined -> 显示空白
 *         - 侧边栏当前用户标识：显示空白
 *         - 物料填报 filled_by 兜底失效
 *
 * 用法：node scripts/fix-email-to-username.js
 */
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, '..', 'assets', 'index-muZMgV9K.js');

// [唯一定位串, 替换后, 说明]
const PATCHES = [
  ['p_username:O.email',
   'p_username:O.username',
   '重置操作工密码 —— 传参从 undefined 修正为真实账号'],

  ['children:O.email}',
   'children:O.username}',
   '操作工列表「账号」列 —— 修复空白'],

  ['children:e==null?void 0:e.email}',
   'children:e==null?void 0:e.username}',
   '侧边栏当前登录用户标识 —— 修复空白'],

  ['(t==null?void 0:t.email)||"unknown"',
   '(t==null?void 0:t.username)||"unknown"',
   '物料填报 filled_by 兜底'],

  // 为「撤销 anon 读取 password_hash 权限」做前置准备：
  // 列级 REVOKE 后 select("*") 会 42501 报错，必须改成显式列
  ['from("profiles").select("*")',
   'from("profiles").select("id,username,display_name,role,allowed_process_ids,created_at,updated_at")',
   '操作工列表不再拉取 password_hash（安全加固前置）'],
];

let src = fs.readFileSync(FILE, 'utf8');
const before = src.length;
let applied = 0, skipped = 0;

console.log('修补文件: assets/index-muZMgV9K.js (' + before + ' chars)\n');

for (const [from, to, desc] of PATCHES) {
  const hits = src.split(from).length - 1;
  if (hits === 0) {
    const already = src.split(to).length - 1;
    console.log((already > 0 ? '  [已修复] ' : '  [未命中] ') + desc);
    skipped++;
    continue;
  }
  if (hits > 1) {
    console.log('  [跳过-不唯一] ' + desc + '  (命中 ' + hits + ' 处，需人工确认)');
    skipped++;
    continue;
  }
  src = src.split(from).join(to);
  console.log('  [已修补] ' + desc);
  applied++;
}

fs.writeFileSync(FILE, src);

console.log('\n修补 ' + applied + ' 处，跳过 ' + skipped + ' 处');
console.log('文件大小: ' + before + ' -> ' + src.length);

// 回归校验
const leftEmail = (src.match(/[A-Za-z_$][A-Za-z0-9_$]*\.email\b/g) || [])
  .filter(x => !/rpOrigins|webauthn/i.test(x));
console.log('\n=== 回归校验 ===');
console.log('  残留 /qrcts 前缀      : ' + (src.split('/qrcts').length - 1));
console.log('  basename              : ' + (src.match(/basename:"[^"]*"/g) || []).join(','));
console.log('  残留 .email 引用      : ' + leftEmail.length + (leftEmail.length ? ' -> ' + leftEmail.join(',') : ''));
console.log('  password_hash 请求    : ' + (src.includes('from("profiles").select("*")') ? '仍在拉取 !!' : '已收敛为显式列'));
