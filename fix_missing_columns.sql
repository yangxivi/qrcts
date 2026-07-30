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

-- ============================================================
-- 5. 修复 company_info 表（字段名不匹配 + 缺失字段）
--    前端使用: id, name, business, description, website, address
--    数据库原有: id, company_name, address, contact, phone, logo_url
-- ============================================================
ALTER TABLE public.company_info
ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT '',
ADD COLUMN IF NOT EXISTS business TEXT NOT NULL DEFAULT '',
ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
ADD COLUMN IF NOT EXISTS website TEXT NOT NULL DEFAULT '';

-- 将旧 company_name 迁移到新 name 字段（仅当 name 为空时）
UPDATE public.company_info SET name = company_name WHERE name = '' AND company_name != '';

-- ============================================================
-- 6. 修改 company_info.id 类型（核心修复）
--    前端硬编码 id:1（upsert({id:1}) + select().eq("id",1)），
--    但原 id 是 UUID 类型，无法接受整数 1 → 保存失败(400)。
--    改为 bigint 使 id=1 可用。company_info 无外键依赖，安全。
-- ============================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='company_info' AND column_name='id' AND data_type='uuid'
  ) THEN
    -- 先删除旧的 UUID 默认值（gen_random_uuid 无法自动转 bigint）
    ALTER TABLE public.company_info ALTER COLUMN id DROP DEFAULT;
    -- 再改类型
    ALTER TABLE public.company_info ALTER COLUMN id TYPE bigint USING 1;
    -- 最后设新默认值
    ALTER TABLE public.company_info ALTER COLUMN id SET DEFAULT 1;
  END IF;
END $$;

-- 完成提示
-- 执行后刷新页面，新增产品/工序/物料/企业信息功能即可正常使用
