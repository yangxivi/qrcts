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

-- ============================================================
-- 7. 修复 process_records 表（匹配前端"工序流转"功能）
--    前端 insert/update 使用: sn_code_id, process_id, operator_name, shift, production_date
--    前端查询排序使用: .order("production_date")
--    原表只有 operator_id（NOT NULL），前端并不传 operator_id，而是传 operator_name，
--    且缺少 operator_name/shift/production_date 字段
--    → 工序流转保存失败、追溯页(/t/:sn)加载因 order by production_date 报错。
-- ============================================================
ALTER TABLE public.process_records
  ALTER COLUMN operator_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS operator_name TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS shift TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS production_date TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ============================================================
-- 8. 修复 sn_materials 表（匹配前端"物料填报"功能）
--    前端 insert 使用: sn_code_id, name, roll_no, batch_no, filled_by, sort_order
--    前端查询排序使用: .order("sort_order")
--    原表只有 material_id（NOT NULL），前端并不传 material_id，而是传 name，
--    且缺少 name/roll_no/batch_no/filled_by/sort_order 字段
--    → 物料填报保存失败、追溯页物料加载因 order by sort_order 报错。
-- ============================================================
ALTER TABLE public.sn_materials
  ALTER COLUMN material_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS roll_no TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS batch_no TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS filled_by TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;

-- 完成提示
-- 执行后刷新页面，新增产品/工序/物料/企业信息、工序流转、物料填报、二维码追溯功能即可正常使用

-- ============================================================
-- 9. 创建操作工/重置密码 RPC 函数（替代未部署的 Edge Function）
--    前端原调用 Oe.functions.invoke("create-operator", ...) Edge Function，
--    但仓库中无此函数源码且未部署 → 新建/重置密码全部失败。
--    改用 PostgreSQL RPC 函数，直接操作 profiles 表 + bcrypt 密码哈希。
-- ============================================================

-- 9a. 创建操作工 RPC
-- 注意：RETURNS TABLE 的输出列名(id/username/display_name/role)与 profiles 表字段同名，
-- 必须在函数体内用表别名 p 限定列引用，且 allowed_process_ids 为 NOT NULL，
-- 故传参为 NULL 时用 COALESCE 转成空数组，否则会报 42702 歧义 / 23502 非空约束。
CREATE OR REPLACE FUNCTION public.create_operator_rpc(
  p_username TEXT,
  p_password TEXT,
  p_display_name TEXT,
  p_role TEXT DEFAULT 'operator',
  p_allowed_process_ids UUID[] DEFAULT NULL
)
RETURNS TABLE(id UUID, username TEXT, display_name TEXT, role TEXT, plain_password TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id UUID;
  v_plain_password TEXT;
BEGIN
  -- 如果未提供密码，自动生成 8 位随机密码
  v_plain_password := CASE
    WHEN p_password IS NULL OR p_password = '' THEN
      upper(encode(gen_random_bytes(4), 'hex'))
    ELSE
    p_password
  END;

  -- 检查用户名是否已存在（用别名 p 限定列，避免与输出变量歧义）
  IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.username = p_username) THEN
    RAISE EXCEPTION '用户名 "%" 已存在', p_username;
  END IF;

  INSERT INTO public.profiles (username, password_hash, display_name, role, allowed_process_ids)
  VALUES (p_username, crypt(v_plain_password, gen_salt('bf')), p_display_name, p_role, COALESCE(p_allowed_process_ids, ARRAY[]::UUID[]));

  SELECT p.id INTO v_id FROM public.profiles p WHERE p.username = p_username;

  RETURN QUERY SELECT v_id, p_username, p_display_name, p_role, v_plain_password;
END;
$$;

-- 9b. 重置操作工密码 RPC
CREATE OR REPLACE FUNCTION public.reset_operator_password_rpc(
  p_username TEXT,
  p_new_password TEXT DEFAULT NULL
)
RETURNS TABLE(plain_password TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plain_password TEXT;
BEGIN
  -- 检查用户是否存在
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = p_username) THEN
    RAISE EXCEPTION '操作工 "%" 不存在', p_username;
  END IF;

  -- 如果未提供新密码，自动生成 8 位随机密码
  v_plain_password := CASE
    WHEN p_new_password IS NULL OR p_new_password = '' THEN
      upper(encode(gen_random_bytes(4), 'hex'))
    ELSE
    p_new_password
  END;

  UPDATE public.profiles
  SET password_hash = crypt(v_plain_password, gen_salt('bf'))
  WHERE username = p_username;

  RETURN QUERY SELECT v_plain_password;
END;
$$;

-- 刷新 PostgREST 架构缓存（使新 RPC 立点可用）
NOTIFY pgrst, 'reload schema';
