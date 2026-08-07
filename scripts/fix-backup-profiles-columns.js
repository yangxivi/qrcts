/**
 * 修补备份/恢复模块，使其适配 profiles 表的列级权限收紧。
 *
 * 背景：数据库已对 anon 撤销 profiles 全表 SELECT，仅授予安全列
 * （id/username/display_name/role/allowed_process_ids/created_at/updated_at），
 * password_hash 不再下发到浏览器。
 *
 * 但备份模块对每张表统一执行 .select("*")，对 profiles 会返回 401
 * permission denied，导致「用户档案」这一项备份失败。
 *
 * 本脚本做三件事：
 *   1. 给 profiles 的备份配置加上显式列 zzCols，导出时按安全列查询
 *   2. 给 profiles 加 zzSkip 标记，恢复(导入)时跳过
 *      —— 备份包内已无 password_hash，本就无法还原账号；
 *         且 anon 已被撤销 profiles 的 INSERT 权限
 *   3. 导出/恢复循环分别读取上述两个标记
 *
 * 用法：node scripts/fix-backup-profiles-columns.js
 */
const fs = require("fs");
const path = require("path");

const FILE = path.join(__dirname, "..", "assets", "index-muZMgV9K.js");
const SAFE_COLS = "id,username,display_name,role,allowed_process_ids,created_at,updated_at";

let src = fs.readFileSync(FILE, "utf8");
const before = src.length;
let applied = 0;

const patches = [
  {
    name: "备份表清单：profiles 增加安全列与跳过恢复标记",
    from: '{table:"profiles",label:"用户档案"}',
    to: '{table:"profiles",label:"用户档案（不含密码）",zzCols:"' + SAFE_COLS + '",zzSkip:!0}',
  },
  {
    name: "导出循环：解构 zzCols",
    from: 'const{table:E,label:S}=ui[k];',
    to: 'const{table:E,label:S,zzCols:zzC}=ui[k];',
  },
  {
    name: "导出循环：按安全列查询",
    from: 'await Oe.from(E).select("*");',
    to: 'await Oe.from(E).select(zzC||"*");',
  },
  {
    name: "恢复循环：解构 zzSkip 并跳过账号表",
    from: 'const{table:N,label:P}=ui[R];c(C=>C.map((U,T)=>T===R?{...U,status:"loading"}:U));',
    to: 'const{table:N,label:P,zzSkip:zzS}=ui[R];if(zzS){c(C=>C.map((U,T)=>T===R?{...U,count:0,status:"done"}:U));E++;continue}c(C=>C.map((U,T)=>T===R?{...U,status:"loading"}:U));',
  },
];

for (const p of patches) {
  const n = src.split(p.from).length - 1;
  if (n === 0) {
    // 已打过补丁则跳过
    const done = src.indexOf(p.to) > -1;
    console.log((done ? "[跳过] 已是目标状态: " : "[警告] 未匹配到: ") + p.name);
    continue;
  }
  if (n > 1) {
    console.log("[中止] 匹配到 " + n + " 处，不唯一，拒绝替换: " + p.name);
    process.exit(1);
  }
  src = src.replace(p.from, p.to);
  applied++;
  console.log("[OK  ] " + p.name);
}

fs.writeFileSync(FILE, src);
console.log("\n字符数 " + before + " -> " + src.length + "，应用补丁 " + applied + " 处");
console.log('校验 select("*") 剩余 from(E) 动态调用: ' + (src.indexOf('Oe.from(E).select("*")') > -1 ? "仍存在(异常)" : "已消除"));
console.log("校验 zzCols 注入: " + (src.indexOf("zzCols:") > -1 ? "已注入" : "缺失(异常)"));
