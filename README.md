# 二维码溯源系统

生产数字化追溯管理平台，支持产品全生命周期工序流转追溯。

## 功能特性

- **SN 码管理**：批量导入、管理产品序列号
- **产品配置**：管理产品名称与型号
- **工序配置**：管理工序列表与排序
- **物料配置**：管理产品物料信息
- **流转状态**：查看 SN 码工序完成情况
- **二维码生成**：批量生成、下载产品追溯二维码
- **操作工管理**：创建、管理操作工账号
- **企业信息**：配置追溯页企业信息
- **数据备份**：系统数据备份与恢复

## 角色权限

| 角色 | 说明 |
|------|------|
| admin | 管理员，拥有所有功能权限 |
| operator | 工序操作工，负责工序流转操作 |
| material_operator | 物料操作工，负责物料相关操作 |

## 快速开始

### 在线访问

系统已部署到 GitHub Pages：
👉 **https://yangxivi.github.io/qrcts/**

### 默认账号

| 账号 | 密码 | 角色 |
|------|------|------|
| xiviyang | 54xiviyang | admin |

> 可通过登录页「立即注册」创建新账号。

## 技术栈

- **前端**：React + React Router
- **后端**：Supabase (PostgreSQL + RPC)
- **部署**：GitHub Pages + GitHub Actions
- **认证**：纯数据库账号密码系统（pgcrypto 加密）

## 目录结构

```
├── assets/              # 前端构建产物
├── .github/workflows/   # GitHub Actions 自动部署
├── index.html           # 应用入口
├── 404.html             # SPA 路由回退页面
├── _redirects           # 重定向规则
├── env-config.js        # Supabase 环境配置
├── init_database.sql    # 数据库初始化脚本
└── switch_to_simple_auth.sql  # 账号密码系统切换脚本
```

## 部署说明

推送到 `main` 分支后，GitHub Actions 会自动构建并部署到 GitHub Pages。

## 许可证

MIT License
