#!/bin/bash
# xrayproxy - Xray 代理一键控制
# 用法: xrayproxy {start|stop|restart|status|global|smart|account <name>|sysproxy-on|sysproxy-off}

CONFIG=~/.V2rayU/cash_proxy.json
LOG=~/.V2rayU/xray_cash.log
BIN=/usr/local/v2rayu/bin/xray-core/xray-arm64
BIN_DIR=/usr/local/v2rayu/bin/xray-core
GEN=~/.V2rayU/bin/gen_config
CUR=~/.V2rayU/.current_account
IFACE=Wi-Fi
DEFAULT_ACC=cash2

xray_pid() { pgrep -f xray-arm64 | head -1; }
current_acc() { head -1 "$CUR" 2>/dev/null | awk '{print $1}'; }
current_mode_name() { awk '{print $2}' "$CUR" 2>/dev/null; }

start_xray() {
  cd "$BIN_DIR"
  $BIN run -c "$CONFIG" &> "$LOG" &
  cd - > /dev/null
}

sysproxy_on() {
  networksetup -setsocksfirewallproxy $IFACE 127.0.0.1 10808
  networksetup -setsocksfirewallproxystate $IFACE on
  networksetup -setwebproxy $IFACE 127.0.0.1 10809
  networksetup -setwebproxystate $IFACE on
  networksetup -setsecurewebproxy $IFACE 127.0.0.1 10809
  networksetup -setsecurewebproxystate $IFACE on
}

sysproxy_off() {
  networksetup -setsocksfirewallproxystate $IFACE off
  networksetup -setwebproxystate $IFACE off
  networksetup -setsecurewebproxystate $IFACE off
}

# 重新生成配置（不重启）
regenerate() {
  local acc="${1:-$(current_acc)}"
  local mode="${2:-$(current_mode_name)}"
  $GEN "${acc:-$DEFAULT_ACC}" "${mode:-global}" > /dev/null
}

case "$1" in
  start)
    if [ ! -f "$CONFIG" ]; then
      $GEN $DEFAULT_ACC global > /dev/null
    fi
    if [ -n "$(xray_pid)" ]; then
      echo "xray 已在运行 (PID: $(xray_pid))"
    else
      start_xray; sleep 1
      echo "xray 已启动 (PID: $(xray_pid))"
    fi
    cur=$(current_acc); mode=$(current_mode_name)
    echo "账户: ${cur:-$DEFAULT_ACC} | 模式: ${mode:-global}"
    sysproxy_on
    echo "系统代理已开启"
    ;;
  stop)
    pkill -f xray-arm64 2>/dev/null && echo "xray 已停止" || echo "xray 未在运行"
    sysproxy_off
    echo "系统代理已关闭"
    ;;
  restart)
    pkill -f xray-arm64 2>/dev/null; sleep 1
    start_xray; sleep 1
    echo "xray 已重启 (PID: $(xray_pid))"
    cur=$(current_acc); mode=$(current_mode_name)
    echo "账户: ${cur:-$DEFAULT_ACC} | 模式: ${mode:-global}"
    sysproxy_on
    echo "系统代理已开启"
    ;;
  status)
    if [ -n "$(xray_pid)" ]; then
      echo "xray 运行中 (PID: $(xray_pid))"
    else
      echo "xray 未运行"
    fi
    cur=$(current_acc); mode=$(current_mode_name)
    echo "账户: ${cur:-$DEFAULT_ACC}"
    echo "模式: ${mode:-global}"
    echo "---"
    echo "SOCKS: $(networksetup -getsocksfirewallproxy $IFACE | grep '^Enabled')"
    echo "HTTP:  $(networksetup -getwebproxy $IFACE | grep '^Enabled')"
    echo "HTTPS: $(networksetup -getsecurewebproxy $IFACE | grep '^Enabled')"
    ;;
  sysproxy-on)
    sysproxy_on; echo "系统代理已开启"
    ;;
  sysproxy-off)
    sysproxy_off; echo "系统代理已关闭"
    ;;
  account)
    case "$2" in
      list|"")
        python3 -c "
import os
p = os.path.expanduser('~/.V2rayU/accounts/accounts.yml')
with open(p) as f:
    for line in f:
        line = line.rstrip()
        if line.lstrip().startswith('- name:'):
            print('  ' + line.split(':',1)[1].strip())
"
        ;;
      *)
        acc="$2"
        mode=$(current_mode_name)
        $GEN "$acc" "${mode:-global}" > /dev/null
        if [ $? -eq 0 ]; then
          if [ -n "$(xray_pid)" ]; then
            pkill -f xray-arm64; sleep 1; start_xray; sleep 1
          else
            start_xray; sleep 1
          fi
          echo "已切换 → $($GEN "$acc" "${mode:-global}")"
          echo "xray 已启动 (PID: $(xray_pid))"
        fi
        ;;
    esac
    ;;
  test)
    shift
    python3 ~/.V2rayU/bin/test_account "$@"
    ;;
  global)
    regenerate "$(current_acc)" "global"
    if [ -n "$(xray_pid)" ]; then
      pkill -f xray-arm64; sleep 1; start_xray; sleep 1
      echo "已切换 global 模式 (全部走代理) | PID: $(xray_pid)"
    fi
    ;;
  smart)
    regenerate "$(current_acc)" "smart"
    if [ -n "$(xray_pid)" ]; then
      pkill -f xray-arm64; sleep 1; start_xray; sleep 1
      echo "已切换 smart 模式 (国内直连/国外代理) | PID: $(xray_pid)"
    fi
    ;;
  help|-h|--help|"")
    echo "xrayproxy - Xray 代理控制"
    echo ""
    echo "  用法: xrayproxy <命令>"
    echo ""
    echo "  启停:"
    echo "    start               启动代理 + 开系统代理"
    echo "    stop                停止代理 + 关系统代理"
    echo "    restart             重启代理"
    echo "    status              查看运行状态"
    echo ""
    echo "  模式:"
    echo "    global              全局模式（全部请求走代理）"
    echo "    smart               分流模式（国内直连，国外走代理）"
    echo ""
    echo "  账户:"
    echo "    account             列出可用账户"
    echo "    account <name>      切换到指定账户"
    echo "    test [name...]      测试账户延迟/连通/速度"
    echo ""
    echo "  系统代理:"
    echo "    sysproxy-on         开启系统代理"
    echo "    sysproxy-off        关闭系统代理"
    echo ""
    echo "  终端代理:"
    echo "    shell on            当前 shell 开启代理 (curl/git/npm)"
    echo "    shell off           当前 shell 关闭代理"
    echo "    shell status        查看 shell 代理状态"
    ;;
  *)
    echo "未知命令: $1"
    echo "运行 xrayproxy help 查看用法"
    ;;
esac