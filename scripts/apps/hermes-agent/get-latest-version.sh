#!/bin/bash
# get-latest-version.sh — 获取 Hermes Agent 最新版本
# 输出: VERSION=x.y.z

# 从 Docker Hub 获取最新 tag
LATEST=$(curl -s "https://hub.docker.com/v2/repositories/nousresearch/hermes-agent/tags?page_size=1&ordering=last_updated" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$LATEST" ] && [ "$LATEST" != "latest" ]; then
  echo "VERSION=${LATEST}"
  if [ -n "$GITHUB_OUTPUT" ]; then
    echo "VERSION=${LATEST}" >> "$GITHUB_OUTPUT"
  fi
else
  echo "VERSION=latest"
  if [ -n "$GITHUB_OUTPUT" ]; then
    echo "VERSION=latest" >> "$GITHUB_OUTPUT"
  fi
fi
