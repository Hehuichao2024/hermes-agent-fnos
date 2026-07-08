#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_NAME="hermes-agent"
APP_DISPLAY_NAME="Hermes Agent"
APP_VERSION="${HERMES_AGENT_VERSION:-latest}"
APP_FPK_PREFIX="hermes-agent"
APP_DEPS=(curl tar)

PKG_DIR="$SCRIPT_DIR/fnos"

# 获取最新版本
app_get_latest_version() {
  local latest
  latest=$("$REPO_ROOT/scripts/apps/hermes-agent/get-latest-version.sh" | grep "^VERSION=" | cut -d= -f2)
  if [ -n "$latest" ]; then
    APP_VERSION="$latest"
  fi
}

# 下载并准备 Docker compose
app_download() {
  mkdir -p "$WORK_DIR/docker"
  cp "$PKG_DIR/docker/docker-compose.yaml" "$WORK_DIR/docker/"
  sed -i "s/\${VERSION}/${APP_VERSION}/g" "$WORK_DIR/docker/docker-compose.yaml"
  cp -a "$PKG_DIR/ui" "$WORK_DIR/ui"
}

# 打包 app.tgz
app_build_app_tgz() {
  cd "$WORK_DIR"
  tar czf "$REPO_ROOT/app.tgz" docker/ ui/
  echo "app.tgz created for ${APP_DISPLAY_NAME} ${APP_VERSION}"
}

# 架构变量（Docker 应用不需要特殊处理）
app_set_arch_vars() {
  return 0
}

source "$REPO_ROOT/scripts/lib/update-common.sh"
main_flow "$@"
