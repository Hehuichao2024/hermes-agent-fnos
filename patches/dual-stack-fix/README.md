# Dual-Stack 绑定修复

## 问题
Dashboard 绑定到 `::`（IPv6 通配符）时，IPv4 客户端无法连接（如 `192.168.137.66:9119`）。

## 根因
CPython 的 `asyncio.base_events.BaseEventLoop.create_server` 在创建 AF_INET6 socket 时**硬编码设置 `IPV6_V6ONLY=True`**：

```python
# CPython Lib/asyncio/base_events.py
if af == socket.AF_INET6:
    if hasattr(socket, 'IPV6_V6ONLY'):
        sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, True)
```

即使内核参数 `net.ipv6.bindv6only=0`，asyncio 的显式赋值也会覆盖。因此任何通过 `loop.create_server(host="::", ...)` 启动的 uvicorn 服务都只接受 IPv6 连接。

## 解决
在 Dashboard 启动前，monkey-patch `asyncio.BaseEventLoop.create_server`：

1. 当 `host == "::"` 时，预先创建 socket 并设置 `IPV6_V6ONLY=0`
2. 以 `sock=` 参数传入 `create_server`，绕过 asyncio 的 socket 创建逻辑
3. 其他 host 值走原路径（无影响）

## 涉及的补丁文件

| 文件 | 用途 |
|------|------|
| `docker/patches/dual_stack/dual_stack_dashboard.py` | Python 包装脚本，monkey-patch asyncio 并启动 dashboard |
| `docker/patches/dual_stack/run` | s6 启动脚本，调用包装器代替 `hermes dashboard` |

## Compose bind mount（fpk 自带）

```yaml
volumes:
  # Dual-stack 绑定：IPV6_V6ONLY=0 使 :: 同时接受 IPv4 和 IPv6
  - ./patches/dual_stack/dual_stack_dashboard.py:/opt/hermes/dual_stack_dashboard.py
  - ./patches/dual_stack/run:/etc/s6-overlay/s6-rc.d/dashboard/run
```

## 调试记录

```bash
# 检查容器内监听
docker exec hermes-agent cat /proc/net/tcp6 | grep 239F  # port 9119

# 自测 IPv4/IPv6
docker exec hermes-agent python3 -c "
import socket
for af, host in [(socket.AF_INET, '127.0.0.1'), (socket.AF_INET6, '::1')]:
    s = socket.socket(af, socket.SOCK_STREAM)
    s.settimeout(3)
    try:
        s.connect((host, 9119))
        print(f'✅ {host}:9119')
    except Exception as e:
        print(f'❌ {host}:9119 - {e}')
    s.close()
"
```

## 版本史

| 版本 | 方案 | 结果 |
|------|------|------|
| v1.1.2 | `::` 绑定（Uvicorn 默认 IPV6_V6ONLY=1） | ❌ IPv4 不通 |
| v1.1.3 | `0.0.0.0` 绑定（仅 IPv4） | ❌ IPv6 不通 |
| v1.1.4 | 拦截 `uvicorn.Config.bind_socket` | ❌ startup 走 `loop.create_server` 分支，不调 bind_socket |
| v1.1.4 final | 拦截 `asyncio.BaseEventLoop.create_server` | ✅ IPv4 + IPv6 |
