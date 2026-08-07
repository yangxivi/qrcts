/**
 * 修复工序填报日期验证：同一天不同时分秒的记录被误判为"早于上道工序"
 *
 * 根因：
 *   y() 函数返回上一道工序的 production_date，该值从数据库读出时是完整 ISO datetime
 *   （如 "2026-08-07T00:00:00+00:00"），但当前表单 <input type="date"> 只产出
 *   "YYYY-MM-DD"（10 字符）。字符串比较时 "2026-08-07" < "2026-08-07T..." 为 true
 *  （相同前缀下短字符串更"小"），导致同一天填写也被拦截。
 *
 * 修复：
 *   在 y() 函数返回值处统一 .slice(0,10) 截断到日期部分，所有下游消费者
 *   （比较运算 <、min 属性、提示文字 ${H}、错误信息 ${C}）一次性修复。
 *
 * 用法：node scripts/fix-date-comparison.js
 */
const fs = require("fs");
const path = require("path");

const FILE = path.join(__dirname, "..", "assets", "index-muZMgV9K.js");

let src = fs.readFileSync(FILE, "utf8");
const before = src.length;

// y() 函数返回上一道工序日期 —— 唯一匹配点
const from = 'return((S=E==null?void 0:E.record)==null?void 0:S.production_date)??null';
const to   = 'return(((S=E==null?void 0:E.record)==null?void 0:S.production_date)?.slice(0,10))??null';

const n = src.split(from).length - 1;
if (n === 0) {
  // 可能已打过补丁
  const done = src.indexOf(to) > -1;
  console.log((done ? "[跳过] 已是目标状态" : "[警告] 未匹配到目标，可能已被其他方式修复"));
  process.exit(done ? 0 : 1);
}
if (n > 1) {
  console.log("[中止] 匹配到 " + n + " 处，不唯一，拒绝替换");
  process.exit(1);
}

src = src.replace(from, to);
fs.writeFileSync(FILE, src);

console.log("[OK] y() 返回值已加 .slice(0,10) 截断到日期部分");
console.log("字符数 " + before + " -> " + src.length);

// 校验
console.log('校验 patch 生效: ' + (src.indexOf(to) > -1 ? "已注入" : "缺失(异常)"));
console.log('校验旧代码残留: ' + (src.indexOf(from) > -1 ? "仍存在(异常)" : "已消除"));
