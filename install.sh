#!/bin/bash
set -e

echo "=== Xray 代理一键安装 ==="

# 1. 检查 xray-core
BIN=/usr/local/v2rayu/bin/xray-core/xray-arm64
BIN_DIR=/usr/local/v2rayu/bin/xray-core
if [ ! -f "$BIN" ]; then
  echo "未找到 xray-core，请先安装 V2rayU (https://github.com/yanue/V2rayU)"
  exit 1
fi
echo "xray-core: $($BIN version 2>&1 | head -1)"

SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.V2rayU/{accounts,bin} ~/.local/bin

# 2. 复制工具脚本
# 安全拷贝：同文件则跳过，避免清空
safe_copy() { [ "$1" -ef "$2" ] || cat "$1" > "$2"; }
safe_copy "$SRC/bin/gen_config"         ~/.V2rayU/bin/gen_config
safe_copy "$SRC/bin/test_account"       ~/.V2rayU/bin/test_account
chmod +x ~/.V2rayU/bin/{gen_config,test_account}

# 账户配置: 真实文件优先, 否则复制模板
if [ -f "$SRC/accounts/accounts.yml" ] && [ -s "$SRC/accounts/accounts.yml" ]; then
  safe_copy "$SRC/accounts/accounts.yml" ~/.V2rayU/accounts/accounts.yml
  echo "账户配置已安装"
elif [ ! -f ~/.V2rayU/accounts/accounts.yml ]; then
  safe_copy "$SRC/accounts/accounts.example.yml" ~/.V2rayU/accounts/accounts.example.yml
  echo "⚠ 请编辑 ~/.V2rayU/accounts/accounts.yml 填入真实账户信息"
fi

# 3. 安装 xrayproxy 控制脚本
safe_copy "$SRC/proxy.sh" ~/.local/bin/xrayproxy
chmod +x ~/.local/bin/xrayproxy

# 4. 生成初始配置 (默认 cash2 global)
~/.V2rayU/bin/gen_config cash2 global > /dev/null
echo "初始配置: cash2 (global 模式)"

# 5. 添加 PATH
if ! grep -q '.local/bin' ~/.zshrc 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
  echo "PATH 已添加 ~/.local/bin"
fi

# 6. 添加 xrayproxy shell 包装函数 (支持 shell on/off)
if ! grep -q '# xrayproxy shell 代理包装' ~/.zshrc 2>/dev/null; then
  cat >> ~/.zshrc << 'ZEOF'

# xrayproxy shell 代理包装 (shell on/off → 函数处理; rest → 转发二进制)
function xrayproxy {
  case "$1" in
    shell)
      case "$2" in
        on)
          export HTTP_PROXY=http://127.0.0.1:10809
          export HTTPS_PROXY=http://127.0.0.1:10809
          export ALL_PROXY=socks5://127.0.0.1:10808
          export http_proxy=http://127.0.0.1:10809
          export https_proxy=http://127.0.0.1:10809
          export all_proxy=socks5://127.0.0.1:10808
          export NO_PROXY=localhost,127.0.0.1,.local,.cn
          export no_proxy=localhost,127.0.0.1,.local,.cn
          echo "shell 代理已开启"
          ;;
        off)
          unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy NO_PROXY no_proxy
          echo "shell 代理已关闭"
          ;;
        status)
          echo "HTTP_PROXY=$HTTP_PROXY"
          echo "HTTPS_PROXY=$HTTPS_PROXY"
          echo "ALL_PROXY=$ALL_PROXY"
          ;;
        *)
          echo "用法: xrayproxy shell {on|off|status}"
          ;;
      esac
      ;;
    *)
      command xrayproxy "$@"
      ;;
  esac
}
ZEOF
  echo "shell 函数已添加到 ~/.zshrc"
fi

echo ""
echo "=== 安装完成 ==="
echo "  source ~/.zshrc          # 使 PATH 和 shell 函数生效"
echo "  xrayproxy start          # 启动代理 + 开系统代理"
echo "  xrayproxy shell on       # 当前终端开启代理"
echo ""
echo "  管理:"
echo "  xrayproxy account list   # 列出账户"
echo "  xrayproxy test           # 测试所有账户"
echo "  xrayproxy global/smart   # 切换模式"
echo "  xrayproxy status         # 查看状态"