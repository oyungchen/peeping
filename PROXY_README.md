# Xray 代理使用说明

## 全局命令

```bash
xrayproxy start          # 启动代理 + 开系统代理
xrayproxy stop           # 停止代理 + 关系统代理
xrayproxy restart        # 重启代理
xrayproxy status         # 查看运行状态

xrayproxy global         # 全局模式（全部请求走代理）
xrayproxy smart          # 分流模式（国内直连、国外走代理）
```

## 多账户管理

账户信息独立存在 `~/.V2rayU/accounts/accounts.yml`，与代理逻辑分离。

```bash
xrayproxy account list           # 列出所有账户
xrayproxy account cash2          # 切换到 cash2
xrayproxy account cash9          # 切换到 cash9
```

添加新账户只需编辑 `accounts.yml`，格式参考已有条目。

## 文件结构

```
~/.V2rayU/
  accounts/accounts.yml    # 账户信息（手动编辑）
  cash_proxy.json           # 当前生效的 xray 配置（由 gen_config 生成）
  .current_account          # 当前账户名 + 模式
  bin/gen_config            # 配置生成器（yml → json）
  install.sh                # 一键安装脚本
```

## 代理端口

| 协议 | 地址 |
|------|------|
| SOCKS5 | `127.0.0.1:10808` |
| HTTP | `127.0.0.1:10809` |

## 验证

```bash
curl -x socks5h://127.0.0.1:10808 -s https://httpbin.org/ip
curl -x socks5h://127.0.0.1:10808 -s -o /dev/null -w "%{http_code}" https://www.google.com
```