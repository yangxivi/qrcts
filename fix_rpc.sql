-- 修正 create_operator_rpc 的 PL/pgSQL 变量/列歧义 (42702)
-- RETURNS TABLE 的输出列 id/username/display_name/role 与 profiles 表字段同名，
-- 导致 WHERE username=... 和 RETURNING id INTO 解析歧义。
-- 修复：① 给 profiles 加别名 p，所有列引用用 p. 限定；② 去掉 RETURNING，改 INSERT 后单独 SELECT id。
-- 仅保留 plain_password 作为输出名（前端读取 X[0].plain_password）。
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
  v_plain_password := CASE
    WHEN p_password IS NULL OR p_password = '' THEN
      upper(encode(gen_random_bytes(4), 'hex'))
    ELSE
    p_password
  END;

  IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.username = p_username) THEN
    RAISE EXCEPTION '用户名 "%" 已存在', p_username;
  END IF;

  INSERT INTO public.profiles (username, password_hash, display_name, role, allowed_process_ids)
  VALUES (p_username, crypt(v_plain_password, gen_salt('bf')), p_display_name, p_role, COALESCE(p_allowed_process_ids, ARRAY[]::UUID[]));

  SELECT p.id INTO v_id FROM public.profiles p WHERE p.username = p_username;

  RETURN QUERY SELECT v_id, p_username, p_display_name, p_role, v_plain_password;
END;
$$;

NOTIFY pgrst, 'reload schema';
