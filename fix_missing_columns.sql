-- ============================================================
-- 二维码溯源系统 - 修复缺失字段（匹配前端代码）
-- 在 Supabase SQL Editor 中执行此脚本
-- ============================================================

-- 1. 给 products 表添加 is_active 字段
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 2. 给 processes 表添加 is_active 字段
ALTER TABLE public.processes
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 3. 给 materials 表添加缺失字段（匹配前端代码）
ALTER TABLE public.materials
ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS model TEXT NOT NULL DEFAULT '',
ADD COLUMN IF NOT EXISTS batch_no TEXT NOT NULL DEFAULT '',
ADD COLUMN IF NOT EXISTS remark TEXT NOT NULL DEFAULT '',
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 4. 给 sn_codes 表添加 is_active 字段（如果前端也用）
ALTER TABLE public.sn_codes
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 完成提示
-- 执行后刷新页面，新增产品/工序/物料功能即可正常使用
