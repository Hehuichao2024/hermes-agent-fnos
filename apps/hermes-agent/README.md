# Hermes Agent for fnOS

[![Release](https://img.shields.io/badge/release-latest-blue)](https://github.com/conversun/fnos-apps/releases?q=hermes-agent)

[Hermes Agent](https://hermes-agent.nousresearch.com) 是 Nous Research 开发的开源 AI 智能体，支持多模型、多工具、自定义技能与多渠道消息接入。

## 功能特点

- **多模型支持** — 接入 OpenAI、Anthropic、Ollama、vLLM 等主流 LLM
- **内置工具** — 文件搜索、网络搜索、代码执行、终端、图像生成等
- **自定义技能** — 可编写 SKILL.md 定义专属工作流
- **Web Dashboard** — 图形化管理界面，端口 `9119`
- **OpenAI 兼容 API** — 端口 `8642`，可作为其他应用的后端
- **多渠道** — 支持 Telegram、Discord、飞书、企业微信等

## 安装

1. 在 fnOS 应用中心安装 Hermes Agent
2. 安装过程中设置 Dashboard 登录凭据
3. 打开浏览器访问 `http://NAS-IP:9119` 进入 Dashboard
4. 在 Settings 中配置你的 API Key

## 端口

| 端口 | 说明 |
|------|------|
| 9119 | Web Dashboard |
| 8642 | OpenAI 兼容 API Server |

## 数据目录

应用数据存储在安装时选择的存储空间，包含：

- `data/` — 会话记录、记忆、技能文件
- `config/` — 配置文件（config.yaml）

## 本地构建

```bash
cd apps/hermes-agent
chmod +x update_hermes-agent.sh
./update_hermes-agent.sh
```
