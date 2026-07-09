#!/opt/hermes/.venv/bin/python
"""DashBoard wrapper: true dual-stack (IPv4+IPv6) via IPV6_V6ONLY=0.

Monkey-patches asyncio.BaseEventLoop.create_server so that when host is "::",
we pre-create the socket with IPV6_V6ONLY=0 and pass it as `sock=` to
asyncio, bypassing asyncio's default IPV6_V6ONLY=True behaviour.

Root cause: CPython's base_events.py create_server explicitly sets
  sock.setsockopt(IPPROTO_IPV6, IPV6_V6ONLY, True)
for every AF_INET6 socket created via host="::", overriding the kernel
default and our previous bind_socket monkey-patch.
"""
import asyncio
import os
import socket
import sys

_orig_create_server = asyncio.BaseEventLoop.create_server


async def _dualstack_create_server(self, protocol_factory, host=None,
                                   port=None, **kwargs):
    if host == "::":
        # Pre-create the socket with IPv6_V6ONLY=0 BEFORE passing it to
        # asyncio (which would otherwise set it to 1 and reject IPv4).
        s = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        s.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("::", port))
        s.listen(2048)
        # Hand the pre-created socket to asyncio; host/port are ignored
        # when sock= is provided.
        return await _orig_create_server(
            self, protocol_factory, sock=s,
            ssl=kwargs.get("ssl"), backlog=kwargs.get("backlog", 2048),
        )

    return await _orig_create_server(
        self, protocol_factory, host=host, port=port, **kwargs
    )


asyncio.BaseEventLoop.create_server = _dualstack_create_server

# ── Run the dashboard ──
from hermes_cli.main import main

sys.argv = ["hermes", "dashboard", "--host", "::",
            "--port", os.environ.get("HERMES_DASHBOARD_PORT", "9119"),
            "--no-open"]
main()
