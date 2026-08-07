-- ============================================================
-- 二维码溯源系统 · 安全加固
--
-- 【已验证的风险】anon 角色（key 明文写在 https://qr.xiviai.cn/env-config.js，
--   任何访客按 F12 即可获取）当前拥有全库读写删权限，实测可以：
--     1. 读取全部账号的 password_hash（bcrypt cost=6，强度偏低，易离线爆破）
--     2. 直接 INSERT / UPDATE / DELETE profiles，可自建 admin 账号、可给自己提权
--     3. 直接 DELETE 全部 products / sn_codes / processes / process_records（可清库）
--
-- 【重要前提】认证类 RPC（login_user / register_user / get_user_by_id /
--   create_operator_rpc / reset_operator_password_rpc）均为 SECURITY DEFINER，
--   以定义者权限运行，不受本脚本的 anon 权限收紧影响 —— 登录功能不会被影响。
--
-- 【执行方式】Supabase 控制台 -> SQL Editor -> 粘贴运行
-- ============================================================


-- ============================================================
-- 第 1 级：堵住密码哈希泄露（低风险，强烈建议立即执行）
--
-- 注意：需配合前端改动 —— 前端原本用 profiles.select("*")，
-- 列级 REVOKE 后会报 42501。已在 commit 中将其改为显式列，
-- 请确认站点已部署到 v=35 之后再执行本段。
-- ============================================================

REVOKE SELECT ON public.profiles FROM anon;

GRANT SELECT (
    id,
    username,
    display_name,
    role,
    allowed_process_ids,
    created_at,
    updated_at
) ON public.profiles TO anon;

-- 验证：下面第一句应成功，第二句应报 42501 permission denied
--   SELECT id, username, role FROM public.profiles;
--   SELECT password_hash FROM public.profiles;


-- ============================================================
-- 第 2 级：禁止匿名直接改账号表（低风险，建议执行）
--
-- 账号的增删改本就都通过 SECURITY DEFINER RPC 完成
-- （create_operator_rpc / reset_operator_password_rpc），
-- 前端唯一的直接写操作是删除操作工，改走 RPC 更安全。
-- 若暂时保留前端直接删除功能，可注释掉 DELETE 那行。
-- ============================================================

REVOKE INSERT, UPDATE ON public.profiles FROM anon;
-- REVOKE DELETE ON public.profiles FROM anon;   -- 需先把「删除操作工」改为 RPC 再放开此行


-- ============================================================
-- 第 3 级：提升密码哈希强度（建议）
--
-- 当前为 bcrypt cost=6（$2a$06$），现代 GPU 每秒可尝试数十万次。
-- 建议升到 cost=10。注意：已有账号的哈希不会自动升级，
-- 需要用户下次改密码时才会用新强度，或由管理员重置密码。
-- 下面语句修改注册/建号函数里的 gen_salt 参数。
-- ============================================================

-- 查看当前各账号的 cost（第 2 段数字即 cost）：
--   SELECT username, substring(password_hash, 1, 7) AS bcrypt_prefix FROM public.profiles;
--
-- 修改方式：在 switch_to_simple_auth.sql / fix_missing_columns.sql 中
-- 把 crypt(p_password, gen_salt('bf', 6)) 改为 gen_salt('bf', 10) 后重新执行对应函数定义。


-- ============================================================
-- 第 4 级：业务表写权限（需要架构改造，本脚本不执行，仅说明）
--
-- 现状：products / processes / sn_codes / process_records / sn_materials
-- 对 anon 完全开放增删改。因为本系统没有走 Supabase Auth，
-- 数据库侧拿不到 JWT 身份，RLS 无法按「谁在操作」来判定，
-- 所以无法简单地用 RLS 策略解决。
--
-- 可选方案（按投入从小到大）：
--   A. 接受现状：系统仅内网/可信人员使用，靠 URL 不公开来降低暴露面。
--      风险：只要有人访问过站点，key 就已泄露，可被清库。建议至少做定期自动备份。
--   B. 把所有写操作收敛为 SECURITY DEFINER RPC，RPC 内校验前端传入的
--      会话令牌（登录时下发、存 profiles 或独立 sessions 表），
--      然后 REVOKE anon 对业务表的 INSERT/UPDATE/DELETE。改造量中等，最推荐。
--   C. 迁移回 Supabase Auth，用标准 JWT + RLS。最规范，但改造量最大。
-- ============================================================
