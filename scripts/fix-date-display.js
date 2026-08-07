/**
 * 工序流转记录中"记录日期"只显示到年月日（截断时分秒）
 *
 * 背景：
 *   数据库 production_date 存的是完整 ISO datetime（如 2026-08-07T00:00:00+00:00），
 *   前端在渲染时直接输出整个值，导致列表/详情里显示一长串时间戳。
 *   用户要求只显示 YYYY-MM-DD。
 *
 * 修复：在 2 处渲染位置对 production_date 加 .slice(0,10)，并先用 ||"" 兜底空值。
 *   1) 流转记录列表视图：children:["记录日期：",C.production_date]
 *   2) 表单预览/编辑视图：children:["记录日期：",E.production_date]
 *
 * 用法：node scripts/fix-date-display.js
 */
const fs = require("fs");
const path = require("path");

const FILE = path.join(__dirname, "..", "assets", "index-muZMgV9K.js");
let src = fs.readFileSync(FILE, "utf8");
const before = src.length;

const patches = [
  {
    name: "流转记录列表视图 children:[\"记录日期：\",C.production_date]",
    from: 'children:["记录日期：",C.production_date]',
    to: 'children:["记录日期：",(C.production_date||"").slice(0,10)]',
  },
  {
    name: "表单预览/编辑视图 children:[\"记录日期：\",E.production_date]",
    from: 'children:["记录日期：",E.production_date]',
    to: 'children:["记录日期：",(E.production_date||"").slice(0,10)]',
  },
];

let applied = 0;
for (const p of patches) {
  const n = src.split(p.from).length - 1;
  if (n === 0) {
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
console.log('校验 .slice(0,10) 注入次数: ' + (src.split(".slice(0,10)").length - 1) + " (期望含此前 y() 的 1 处 + 本次 2 处)");
