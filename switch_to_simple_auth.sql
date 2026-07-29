-- ============================================================
-- 二维码溯源系统 - 改为纯账号密码系统（无需 Supabase Auth）
-- 在 Supabase SQL Editor 中执行此脚本
-- ============================================================

-- 启用扩展
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. 重建 profiles 表（不再依赖 auth.users）
-- ============================================================
-- 先删除外键引用（process_records.operator_id）
ALTER TABLE public.process_records
    DROP CONSTRAINT IF EXISTS process_records_operator_id_fkey;

-- 删除旧表
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 新建 profiles 表（独立的账号系统）
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'operator', -- admin, operator, material_operator
    allowed_process_ids UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 重新加回外键
ALTER TABLE public.process_records
    ADD CONSTRAINT process_records_operator_id_fkey
    FOREIGN KEY (operator_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ============================================================
-- 2. 注册函数
-- ============================================================
CREATE OR REPLACE FUNCTION public.register_user(
    p_username TEXT,
    p_password TEXT,
    p_display_name TEXT DEFAULT ''
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    display_name TEXT,
    role TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- 检查用户名是否已存在
    IF EXISTS (SELECT 1 FROM public.profiles WHERE username = p_username) THEN
        RAISE EXCEPTION '用户名已存在';
    END IF;

    -- 检查密码长度
    IF length(p_password) < 6 THEN
        RAISE EXCEPTION '密码至少需要 6 位';
    END IF;

    -- 插入用户
    INSERT INTO public.profiles (username, password_hash, display_name, role)
    VALUES (
        p_username,
        crypt(p_password, gen_salt('bf')),
        p_display_name,
        'operator'
    )
    RETURNING id INTO v_user_id;

    -- 返回用户信息
    RETURN QUERY
    SELECT p.id, p.username, p.display_name, p.role
    FROM public.profiles p
    WHERE p.id = v_user_id;
END;
$$;

-- ============================================================
-- 3. 登录函数
-- ============================================================
CREATE OR REPLACE FUNCTION public.login_user(
    p_username TEXT,
    p_password TEXT
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    display_name TEXT,
    role TEXT,
    allowed_process_ids UUID[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.username,
        p.display_name,
        p.role,
        p.allowed_process_ids
    FROM public.profiles p
    WHERE p.username = p_username
      AND p.password_hash = crypt(p_password, p.password_hash);

    IF NOT FOUND THEN
        RAISE EXCEPTION '账号或密码错误';
    END IF;
END;
$$;

-- ============================================================
-- 4. 获取用户信息函数（根据 ID）
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_by_id(p_id UUID)
RETURNS TABLE (
    id UUID,
    username TEXT,
    display_name TEXT,
    role TEXT,
    allowed_process_ids UUID[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.username, p.display_name, p.role, p.allowed_process_ids
    FROM public.profiles p
    WHERE p.id = p_id;
END;
$$;

-- ============================================================
-- 5. 关闭 RLS（因为我们用函数做鉴权）
-- ============================================================
ALTER TABLE public.company_info DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.processes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.sn_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.process_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.sn_materials DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- 6. 创建管理员账号（可选）
-- ============================================================
-- 执行此脚本后，管理员账号会自动创建
-- 账号: xiviyang  密码: 54xiviyang
INSERT INTO public.profiles (username, password_hash, display_name, role)
SELECT 'xiviyang', crypt('54xiviyang', gen_salt('bf')), '管理员', 'admin'
WHERE NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = 'xiviyang');
