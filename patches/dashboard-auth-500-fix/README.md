# Dashboard Auth 500 Fix

## 问题
FN Connect 远程访问 Hermes Agent Dashboard 时返回 **500 Internal Server Error**。本地局域网访问正常。

## 根因
`BasicAuthProvider`（密码表单）被自动 SSO 逻辑错误地当成 OAuth provider 重定向到 `/auth/login?provider=basic`，但该 provider 没有实现 `start_login()`（密码方式走的是 `POST /auth/password-login`），抛出 `NotImplementedError` → 500。

详见 `references/fn-connect-debugging.md`（Hermes fpk 打包技能）。

## 文件说明

| 文件 | 用途 |
|------|------|
| `middleware.py` | 已修复的 `middleware.py` 完整文件（`_auto_sso_response` 函数过滤 password-only provider） |
| `apply.sh` | 一键热修复脚本（适用于任何运行中的 hermes-agent Docker 容器） |

## 方式一：热修复（临时，容器重启后丢失）

在新设备上如果已部署 Hermes Agent Docker 容器：

```bash
chmod +x /path/to/apply.sh
./apply.sh                    # 默认容器名 hermes-agent
./apply.sh my-container       # 自定义容器名
```

脚本会：
1. 在容器内 patch `middleware.py`
2. 重启容器
3. 验证修复是否生效（检查 `/` → `/login` 重定向）

## 方式二：Compose bind mount（持久，fpk 安装自带）

在 `docker-compose.yaml` 的 `volumes:` 中添加：

```yaml
volumes:
  - ./patches/dashboard_auth/middleware.py:/opt/hermes/hermes_cli/dashboard_auth/middleware.py
```

这样每次容器启动都会挂载已修复的文件。需要将 `middleware.py` 放到 compose 文件的 `patches/dashboard_auth/` 子目录下。

## 方式三：源码级别（永久修复）

如果从源码构建镜像，修改 `hermes_cli/dashboard_auth/middleware.py` 中的 `_auto_sso_response` 函数：

```python
# 改动前：
providers = list_session_providers()
if len(providers) != 1:
    return None
provider = providers[0]

# 改动后：
providers = list_session_providers()
sso_candidates = [p for p in providers if not getattr(p, "supports_password", False)]
if len(sso_candidates) != 1:
    return None
provider = sso_candidates[0]
```

## 验证

```bash
# 正常 → 应重定向到 /login
curl -sv http://127.0.0.1:9119/ 2>&1 | grep -i location
# 期望：location: /login?next=%2F
```

## IPv6 支持

Dashboard 默认绑定 `0.0.0.0`（仅 IPv4）。如需 IPv6 双栈支持，在 `docker-compose.yaml` 中设置：

```yaml
environment:
  - HERMES_DASHBOARD_HOST=::
```

`::` 在 Linux 上默认启用 dual-stack sockets，同时接受 IPv4 和 IPv6 连接。

## 迁移

将此 `patches/` 目录整个复制到新设备的 Hermes 项目根目录即可：

```bash
scp -r patches/ user@new-device:/vol1/1000/Hermes-Agent/
```
