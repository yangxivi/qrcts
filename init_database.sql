-- ============================================================
-- 二维码溯源系统 - 数据库初始化脚本
-- 在 Supabase SQL Editor 中执行此脚本
-- ============================================================

-- 启用扩展
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. 企业信息表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.company_info (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL DEFAULT '',
    address TEXT NOT NULL DEFAULT '',
    contact TEXT NOT NULL DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    logo_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. 产品表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    model TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. 工序表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.processes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4. 物料表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    unit TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 5. 用户档案表（关联 auth.users）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT 'operator', -- admin, operator, material_operator
    allowed_process_ids UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 6. SN 码表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.sn_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sn TEXT NOT NULL UNIQUE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 7. 工序记录表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.process_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sn_code_id UUID NOT NULL REFERENCES public.sn_codes(id) ON DELETE CASCADE,
    process_id UUID NOT NULL REFERENCES public.processes(id) ON DELETE CASCADE,
    operator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    remark TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sn_code_id, process_id)
);

-- ============================================================
-- 8. 原材料记录表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.sn_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sn_code_id UUID NOT NULL REFERENCES public.sn_codes(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES public.materials(id) ON DELETE CASCADE,
    quantity NUMERIC NOT NULL DEFAULT 0,
    remark TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 自动更新 updated_at 的触发器函数
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为所有表创建 updated_at 触发器
DROP TRIGGER IF EXISTS set_company_info_updated_at ON public.company_info;
CREATE TRIGGER set_company_info_updated_at
    BEFORE UPDATE ON public.company_info
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS set_products_updated_at ON public.products;
CREATE TRIGGER set_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS set_processes_updated_at ON public.processes;
CREATE TRIGGER set_processes_updated_at
    BEFORE UPDATE ON public.processes
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS set_materials_updated_at ON public.materials;
CREATE TRIGGER set_materials_updated_at
    BEFORE UPDATE ON public.materials
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS set_sn_codes_updated_at ON public.sn_codes;
CREATE TRIGGER set_sn_codes_updated_at
    BEFORE UPDATE ON public.sn_codes
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS set_process_records_updated_at ON public.process_records;
CREATE TRIGGER set_process_records_updated_at
    BEFORE UPDATE ON public.process_records
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

DROP TRIGGER IF EXISTS set_sn_materials_updated_at ON public.sn_materials;
CREATE TRIGGER set_sn_materials_updated_at
    BEFORE UPDATE ON public.sn_materials
    FOR EACH ROW EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- ============================================================
-- 用户注册后自动创建 profile 的触发器
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name, role)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', ''), 'operator');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- RLS (Row Level Security) 策略
-- ============================================================
ALTER TABLE public.company_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sn_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.process_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sn_materials ENABLE ROW LEVEL SECURITY;

-- 允许所有已认证用户读写基础数据（实际权限在应用层控制）
DROP POLICY IF EXISTS "Allow authenticated read company_info" ON public.company_info;
CREATE POLICY "Allow authenticated read company_info" ON public.company_info
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated write company_info" ON public.company_info;
CREATE POLICY "Allow authenticated write company_info" ON public.company_info
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated read products" ON public.products;
CREATE POLICY "Allow authenticated read products" ON public.products
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated write products" ON public.products;
CREATE POLICY "Allow authenticated write products" ON public.products
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated read processes" ON public.processes;
CREATE POLICY "Allow authenticated read processes" ON public.processes
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated write processes" ON public.processes;
CREATE POLICY "Allow authenticated write processes" ON public.processes
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated read materials" ON public.materials;
CREATE POLICY "Allow authenticated read materials" ON public.materials
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated write materials" ON public.materials;
CREATE POLICY "Allow authenticated write materials" ON public.materials
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated read profiles" ON public.profiles;
CREATE POLICY "Allow authenticated read profiles" ON public.profiles
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated write profiles" ON public.profiles;
CREATE POLICY "Allow authenticated write profiles" ON public.profiles
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated read sn_codes" ON public.sn_codes;
CREATE POLICY "Allow authenticated read sn_codes" ON public.sn_codes
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated write sn_codes" ON public.sn_codes;
CREATE POLICY "Allow authenticated write sn_codes" ON public.sn_codes
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated read process_records" ON public.process_records;
CREATE POLICY "Allow authenticated read process_records" ON public.process_records
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated write process_records" ON public.process_records;
CREATE POLICY "Allow authenticated write process_records" ON public.process_records
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated read sn_materials" ON public.sn_materials;
CREATE POLICY "Allow authenticated read sn_materials" ON public.sn_materials
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated write sn_materials" ON public.sn_materials;
CREATE POLICY "Allow authenticated write sn_materials" ON public.sn_materials
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- ============================================================
-- 初始化一条企业信息（确保至少有一条）
-- ============================================================
INSERT INTO public.company_info (company_name)
SELECT '示例企业' WHERE NOT EXISTS (SELECT 1 FROM public.company_info LIMIT 1);

-- ============================================================
-- 完成提示
-- ============================================================
-- 数据库表结构创建完成！
-- 请在浏览器中访问 https://<your-project>.supabase.co/auth/v1/signup
-- 或使用应用注册页面创建账号 xiviyang@qq.com / 54xiviyang
-- 注册成功后，在 Supabase Dashboard 中将该用户的 role 修改为 admin
