-- ============================================================
-- 二维码溯源系统 · 修复「工序填报完全不可用」
--
-- 【问题】前端提交工序记录时写入 confirmed 字段：
--     { sn_code_id, process_id, confirmed, operator_name, shift, production_date }
--   但 process_records 表从未创建 confirmed 列，导致每次提交都返回：
--     PGRST204  Could not find the 'confirmed' column of 'process_records'
--   现象：任何操作工填报工序都失败，process_records 表至今 0 条记录，
--         追溯页永远显示「未填写」，整个流转追溯链路形同虚设。
--
-- 【confirmed 的业务含义】（取自前端渲染逻辑）
--     true  -> 绿色对勾 + 文字「已完成」
--     false -> 红色叉号 + 文字「异常」
--     无记录 -> 灰色 + 文字「未填写」
--   追溯页整体合格判定：该产品所有工序的 confirmed 均为 true 才算全部合格。
--   前端表单默认值为 true。
--
-- 【执行方式】Supabase 控制台 -> SQL Editor -> 粘贴运行
-- ============================================================

-- 1. 补上缺失的 confirmed 列（默认 true，与前端表单默认值一致）
ALTER TABLE public.process_records
ADD COLUMN IF NOT EXISTS confirmed BOOLEAN NOT NULL DEFAULT true;

-- 2. 顺带补齐前端用到、但建表脚本里没有的其余字段（幂等，已存在则跳过）
ALTER TABLE public.process_records
ADD COLUMN IF NOT EXISTS operator_name   TEXT NOT NULL DEFAULT '',
ADD COLUMN IF NOT EXISTS shift           TEXT NOT NULL DEFAULT '',
ADD COLUMN IF NOT EXISTS production_date DATE;

-- 3. 让 PostgREST 立刻重载 schema 缓存（否则可能要等几分钟才生效）
NOTIFY pgrst, 'reload schema';

-- ============================================================
-- 验证：执行后应看到 confirmed / operator_name / shift / production_date 四行
-- ============================================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'process_records'
ORDER BY ordinal_position;
