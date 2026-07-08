# Hermes Agent — fnOS 应用包

将 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 打包为 fnOS 标准 `.fpk` 应用包，可通过 fnOS 应用中心一键安装部署。

## 项目结构

```
fnos-app/
├── hermes-agent.fpk.dir/          # fpk 打包源目录
│   ├── app/docker/
│   │   ├── docker-compose.yaml    # 容器编排（host 网络模式）
│   │   └── patches/               # 容器内代码 bind-mount 补丁
│   ├── app/ui/config              # 应用中心配置（端口、代理声明）
│   ├── cmd/                       # 安装/卸载/升级脚本
│   ├── hermes-agent.sc            # 防火墙规则（9119, 8642 入站）
│   ├── manifest                   # 包元数据（版本、架构）
│   └── wizard                     # 安装向导（路径选择、NAS 挂载）
├── patches/dashboard-auth-500-fix/ # Dashboard 500 修复补丁包（可迁移）
├── .gitignore
├── README.md
└── hermes-agent.fpk               # 打包产物（已 gitignore）
```

## 功能

- **host 网络模式** — 容器直接使用 NAS 网络栈，无端口映射
- **Dashboard** — 端口 9119，支持密码登录（Basic Auth）
- **API Server** — 端口 8642，OpenAI 兼容 API
- **IPv6 双栈** — 绑定 `::` 同时支持 IPv4/IPv6
- **FN Connect 兼容** — 通过 fnOS 反向代理远程访问
- **数据持久化** — 安装向导可选数据/配置存储路径
- **NAS 存储挂载** — 安装时可选择挂载 NAS 存储卷

## 打包

```bash
fnpack build -d hermes-agent.fpk.dir
```

构建前自动备份旧包到 `fpk_backup/`。

## 补丁机制

针对 Docker 镜像内部的代码 bug，不用重建镜像：

1. 将修复后的文件放入 `app/docker/patches/<module_path>/`
2. 在 `docker-compose.yaml` 用 bind mount 覆盖容器内原文件
3. 重启容器后生效，重装 fpk 后自动恢复

当前补丁：
- **`dashboard_auth/middleware.py`** — 修复 FN Connect 远程访问 500 错误（排除密码类 provider 触发错误 SSO 跳转）

## 安装

通过 fnOS 应用中心上传 `hermes-agent.fpk` 安装，或使用：

```bash
fnpack install hermes-agent.fpk
```
# GitHub Actions 自动构建
