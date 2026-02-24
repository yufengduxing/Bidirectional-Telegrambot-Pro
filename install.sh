#!/bin/bash
# ============================================
#   TG 转发回复机器人 一键安装脚本
#   适用于宝塔面板 + Supervisor 守护进程
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/www/wwwroot/tg-forward-bot"
SUPERVISOR_CONF="/www/server/panel/plugin/supervisor/profile/tg_forward_bot.ini"
LOG_FILE="$INSTALL_DIR/tg_bot.log"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║        TG 转发回复机器人                  ║"
    echo "║          一键安装脚本                     ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() { echo -e "\n${BLUE}▶ $1${NC}"; }
print_ok()   { echo -e "${GREEN}  ✅ $1${NC}"; }
print_err()  { echo -e "${RED}  ❌ $1${NC}"; }
print_warn() { echo -e "${YELLOW}  ⚠️  $1${NC}"; }

detect_python() {
    for py in python3.13 python3.12 python3.11 python3.10 python3.9 python3 python; do
        path=$(command -v $py 2>/dev/null)
        if [ -n "$path" ]; then
            ver=$($path --version 2>&1 | grep -oP '\d+\.\d+')
            major=$(echo $ver | cut -d. -f1)
            minor=$(echo $ver | cut -d. -f2)
            if [ "$major" -ge 3 ] && [ "$minor" -ge 8 ] 2>/dev/null; then
                echo "$path"
                return
            fi
        fi
    done
    echo ""
}

check_env() {
    print_step "检查系统环境..."

    PYTHON_BIN=$(detect_python)
    if [ -z "$PYTHON_BIN" ]; then
        print_warn "未找到 Python3.8+，尝试安装..."
        apt-get update -qq 2>/dev/null
        apt-get install -y python3 python3-pip -qq 2>/dev/null
        PYTHON_BIN=$(detect_python)
        if [ -z "$PYTHON_BIN" ]; then
            print_err "Python 安装失败，请手动安装 Python3.8+"
            exit 1
        fi
    fi
    print_ok "Python：$PYTHON_BIN（$(${PYTHON_BIN} --version 2>&1)）"

    PIP_BIN=$(command -v pip3 2>/dev/null || command -v pip 2>/dev/null)
    if [ -z "$PIP_BIN" ]; then
        apt-get install -y python3-pip -qq 2>/dev/null
        PIP_BIN=$(command -v pip3 2>/dev/null || command -v pip 2>/dev/null)
    fi
    if [ -z "$PIP_BIN" ]; then
        print_err "pip 安装失败，请手动安装"
        exit 1
    fi
    print_ok "pip：$PIP_BIN"

    if ! command -v supervisorctl &>/dev/null; then
        print_err "Supervisor 未找到，请在宝塔面板软件商店安装 Supervisor 插件后再运行"
        exit 1
    fi
    print_ok "Supervisor 已就绪"
}

collect_config() {
    print_step "填写机器人配置"
    echo ""

    while true; do
        echo -e "${YELLOW}请输入 Bot Token（从 @BotFather 获取）:${NC}"
        read -r BOT_TOKEN
        [ -n "$BOT_TOKEN" ] && break
        print_err "不能为空！"
    done

    while true; do
        echo -e "${YELLOW}请输入你的 Telegram 数字 ID（从 @userinfobot 获取）:${NC}"
        read -r ADMIN_ID
        [[ "$ADMIN_ID" =~ ^[0-9]+$ ]] && break
        print_err "只能输入数字！"
    done

    echo ""
    echo -e "${CYAN}══════════ 配置确认 ══════════${NC}"
    echo -e "Bot Token:  ${GREEN}${BOT_TOKEN:0:20}...${NC}"
    echo -e "管理员ID:   ${GREEN}$ADMIN_ID${NC}"
    echo ""
    echo -n "确认以上信息？(y/n): "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        collect_config
    fi
}

write_config() {
    print_step "写入配置文件..."
    cat > "$INSTALL_DIR/config.py" << CFGEOF
# 配置文件（由安装脚本生成）
BOT_TOKEN = "$BOT_TOKEN"
ADMIN_ID = $ADMIN_ID
CFGEOF
    print_ok "config.py 写入完成"
}

install_deps() {
    print_step "安装 Python 依赖..."
    cd "$INSTALL_DIR" || exit 1

    $PIP_BIN install -r requirements.txt -q --break-system-packages 2>/dev/null || \
    $PIP_BIN install -r requirements.txt -q 2>/dev/null || \
    $PIP_BIN install -r requirements.txt -q -i https://pypi.tuna.tsinghua.edu.cn/simple --break-system-packages 2>/dev/null || \
    $PIP_BIN install -r requirements.txt -q -i https://pypi.tuna.tsinghua.edu.cn/simple 2>/dev/null

    if $PYTHON_BIN -c "import telegram" 2>/dev/null; then
        print_ok "依赖安装完成"
    else
        print_err "依赖安装失败！请手动执行：pip3 install python-telegram-bot==22.6"
        exit 1
    fi
}

setup_supervisor() {
    print_step "配置 Supervisor 守护进程..."

    mkdir -p "$INSTALL_DIR"
    touch "$LOG_FILE"

    cat > "$SUPERVISOR_CONF" << SUPEOF
[program:tg_forward_bot]
command=$PYTHON_BIN $INSTALL_DIR/tg_bot.py
directory=$INSTALL_DIR
autostart=true
autorestart=true
startretries=10
startsecs=5
user=root
redirect_stderr=true
stdout_logfile=$LOG_FILE
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=3
environment=PYTHONUNBUFFERED="1"
SUPEOF

    print_ok "配置写入：$SUPERVISOR_CONF"

    systemctl enable supervisor -q 2>/dev/null || true
    systemctl start supervisor -q 2>/dev/null || true
    supervisorctl reread > /dev/null 2>&1
    supervisorctl update > /dev/null 2>&1
    supervisorctl start tg_forward_bot > /dev/null 2>&1

    for i in 1 2 3; do
        sleep 4
        STATUS=$(supervisorctl status tg_forward_bot 2>&1)
        if echo "$STATUS" | grep -q "RUNNING"; then
            print_ok "机器人启动成功！"
            return
        fi
    done

    print_err "启动异常！最近日志："
    echo ""
    tail -20 "$LOG_FILE" 2>/dev/null
    echo ""
}

manage_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}╔══════════════════════════════╗${NC}"
        echo -e "${CYAN}║       机器人管理菜单          ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════╝${NC}"
        echo -e "  ${GREEN}1${NC}. 查看运行状态"
        echo -e "  ${GREEN}2${NC}. 启动机器人"
        echo -e "  ${GREEN}3${NC}. 停止机器人"
        echo -e "  ${GREEN}4${NC}. 重启机器人"
        echo -e "  ${GREEN}5${NC}. 查看实时日志（Ctrl+C 退出）"
        echo -e "  ${GREEN}6${NC}. 修改配置后重启"
        echo -e "  ${GREEN}7${NC}. 卸载机器人"
        echo -e "  ${GREEN}0${NC}. 退出"
        echo ""
        echo -n "请选择操作: "
        read choice
        case $choice in
            1)
                supervisorctl status tg_forward_bot
                ;;
            2)
                supervisorctl start tg_forward_bot
                sleep 2
                supervisorctl status tg_forward_bot
                ;;
            3)
                supervisorctl stop tg_forward_bot
                print_ok "已停止"
                ;;
            4)
                supervisorctl restart tg_forward_bot
                sleep 2
                supervisorctl status tg_forward_bot
                ;;
            5)
                echo -e "${YELLOW}按 Ctrl+C 退出日志${NC}"
                tail -f "$LOG_FILE"
                ;;
            6)
                nano "$INSTALL_DIR/config.py"
                echo -n "保存完毕，是否立即重启？(y/n): "
                read -r confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    supervisorctl restart tg_forward_bot
                    sleep 2
                    supervisorctl status tg_forward_bot
                fi
                ;;
            7)
                echo -n "⚠️ 确认卸载？(y/n): "
                read c
                if [ "$c" = "y" ]; then
                    supervisorctl stop tg_forward_bot > /dev/null 2>&1
                    rm -f "$SUPERVISOR_CONF"
                    supervisorctl reread > /dev/null 2>&1
                    supervisorctl update > /dev/null 2>&1
                    rm -rf "$INSTALL_DIR"
                    sed -i '/alias bot=/d' ~/.bashrc 2>/dev/null
                    print_ok "卸载完成"
                    exit 0
                fi
                ;;
            0) exit 0 ;;
            *) print_err "无效选项" ;;
        esac
    done
}

main() {
    print_banner

    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/tg_bot.py" ]; then
        echo -e "${YELLOW}检测到已安装，进入管理菜单...${NC}"
        PYTHON_BIN=$(detect_python)
        PIP_BIN=$(command -v pip3 2>/dev/null || command -v pip 2>/dev/null)
        manage_menu
        exit 0
    fi

    echo -e "${YELLOW}开始全新安装...${NC}"
    check_env
    collect_config

    print_step "部署源码文件..."
    mkdir -p "$INSTALL_DIR"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cp "$SCRIPT_DIR/tg_bot.py" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
    print_ok "文件部署完成 -> $INSTALL_DIR"

    write_config
    install_deps
    setup_supervisor

    # 设置 bot 快捷命令
    SCRIPT_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    if ! grep -q "alias bot=" ~/.bashrc 2>/dev/null; then
        echo "alias bot='bash $SCRIPT_ABS'" >> ~/.bashrc
        source ~/.bashrc 2>/dev/null || true
    fi

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 安装完成！                ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  给机器人发 /start  开始使用          ║${NC}"
    echo -e "${GREEN}║  输入 bot   唤出管理菜单              ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -n "进入管理菜单？(y/n): "
    read go
    [ "$go" = "y" ] || [ "$go" = "Y" ] && manage_menu
}

main
