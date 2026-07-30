# 二维码溯源系统（QRCTS）

生产数字化追溯管理平台，支持产品全生命周期的工序流转与物料追溯。前端直连 Supabase，部署在 GitHub Pages。

## 功能特性

- **SN 码管理**：批量导入、管理产品序列号
- **产品配置**：管理产品名称与型号
- **工序配置**：管理工序列表与排序
- **物料配置**：管理产品物料信息
- **流转状态**：查看 SN 码工序完成情况
- **二维码生成**：批量生成、下载产品追溯二维码
- **操作工管理**：创建、管理操作工账号（含初始密码设置、密码重置）
- **企业信息**：配置追溯页展示的企业信息
- **数据备份**：系统数据备份与恢复

## 角色权限

| 角色 | 说明 |
|------|------|
| admin | 管理员，拥有所有功能权限 |
| operator | 工序操作工，负责工序流转操作 |
| material_operator | 物料操作工，负责物料相关操作 |

## 在线访问

系统已部署到 GitHub Pages：

👉 **https://yangxivi.github.io/qrcts/**

> 首次使用请联系系统管理员创建账号。管理员可在「操作工管理」中创建账号并直接设置初始密码，也可随时重置密码。

## 技术栈

- **前端**：React + React Router（构建产物部署，无独立源码仓库）
- **后端**：Supabase（PostgreSQL + RPC 函数）
- **认证**：纯数据库账号密码系统（pgcrypto `crypt` / `gen_salt` 加密）
- **部署**：GitHub Pages + GitHub Actions

## 目录结构

```
├── assets/                  # 前端构建产物（JS/CSS）
├── .github/workflows/       # GitHub Actions 自动部署配置
├── index.html               # 应用入口
├── 404.html                 # SPA 路由回退页面
├── _redirects               # 静态托管重定向规则
├── env-config.js            # Supabase 运行时配置（URL + 公钥）
├── init_database.sql        # 数据库初始化（建表 + 基础数据）
├── switch_to_simple_auth.sql# 账号密码认证系统初始化（profiles 表 + 登录 RPC）
├── fix_missing_columns.sql  # 表结构补丁（补全字段 + 创建业务 RPC）
└── fix_rpc.sql              # 操作工创建/重置密码 RPC 补丁
```

## 数据库配置

将本项目连接到你自己的 Supabase 实例时，请在 Supabase SQL Editor 中按以下顺序执行脚本（全部 `IF NOT EXISTS` / `CREATE OR REPLACE` 幂等，可重复执行）：

1. `init_database.sql` —— 创建基础数据表
2. `switch_to_simple_auth.sql` —— 创建 `profiles` 表与登录 RPC（`login_user`）
3. `fix_missing_columns.sql` —— 补全各表缺失字段，并创建业务 RPC（`create_operator_rpc`、`reset_operator_password_rpc` 等）
4. `fix_rpc.sql` —— 修正操作工创建 RPC 的字段歧义与约束问题

随后在 `env-config.js` 中填写你的 Supabase 项目 URL 与公钥即可。

## 部署说明

推送到 `main` 分支后，GitHub Actions 会自动构建并部署到 GitHub Pages 子路径 `/qrcts/`。部署完成后建议强制刷新（Ctrl + Shift + R）以清除 CDN 缓存。

> 站点部署在项目子路径下，所有资源与路由均已配置 `/qrcts` 前缀；自定义路由经由 `404.html` / `_redirects` 回退到 SPA 入口。

## 许可证

MIT License
