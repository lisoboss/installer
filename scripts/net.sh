#!/usr/bin/env bash

set -e

# Generated from AI
default_interface() {
    local default_if=""
    local os_type=""
    local error_msg=""

    # 检查系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_type=$ID
    elif [ -f /etc/redhat-release ]; then
        os_type="rhel"
    fi

    # 检查必要命令是否存在
    check_command() {
        command -v "$1" >/dev/null 2>&1
    }

    # 方法1: 使用ip命令 (推荐方法，适用于现代Linux系统)
    if check_command ip; then
        default_if=$(ip -4 route list 0/0 2>/dev/null | awk '{print $5}' | head -n1)
        [ -n "$default_if" ] && echo "$default_if" && return 0
    fi

    # 方法2: 使用route命令 (适用于较旧的系统)
    if check_command route; then
        # 针对不同发行版适配route命令的输出格式
        case "$os_type" in
            "rhel"|"centos"|"fedora")
                default_if=$(route -n 2>/dev/null | grep '^0.0.0.0' | awk '{print $8}' | head -n1)
                ;;
            *)
                default_if=$(route -n 2>/dev/null | grep '^0.0.0.0' | awk '{print $NF}' | head -n1)
                ;;
        esac
        [ -n "$default_if" ] && echo "$default_if" && return 0
    fi

    # 方法3: 通过/proc/net/route读取 (最基础的方法，大多数Linux系统都支持)
    if [ -f /proc/net/route ]; then
        default_if=$(awk '$2 == "00000000" {print $1}' /proc/net/route 2>/dev/null | head -n1)
        [ -n "$default_if" ] && echo "$default_if" && return 0
    fi

    # 方法4: 使用netstat命令 (用于特别老的系统)
    if check_command netstat; then
        default_if=$(netstat -rn 2>/dev/null | grep '^0.0.0.0' | awk '{print $NF}' | head -n1)
        [ -n "$default_if" ] && echo "$default_if" && return 0
    fi

    # 方法5: 查找活跃的网络接口（作为最后的备选方案）
    for interface in $(ls /sys/class/net/ 2>/dev/null); do
        if [ "$interface" != "lo" ] && [ -d "/sys/class/net/$interface" ]; then
            if [ -f "/sys/class/net/$interface/operstate" ]; then
                state=$(cat "/sys/class/net/$interface/operstate" 2>/dev/null)
                if [ "$state" = "up" ] || [ "$state" = "unknown" ]; then
                    default_if=$interface
                    break
                fi
            fi
        fi
    done
    [ -n "$default_if" ] && echo "$default_if" && return 0

    # 如果所有方法都失败了
    echo "Error: Could not determine default interface" >&2
    return 1
}


show_helps() {
    echo -e "${GREEN}""\033[1;4mUsage:\033[0m""${RESET}"
    echo "  $0 [command]"
    echo ' '
    echo -e "${GREEN}""\033[1;4mAvailable commands:\033[0m""${RESET}"
    echo "  default-interface       get default waln interface"
    echo "  help                    show this help message"
}


# Main
if [ "$1" = "" ]; then
    show_helps
    exit 1
fi
while [ $# != 0 ]; do
    case "$1" in
    default-interface)
        default_interface='yes'
        shift
        ;;
    help)
        show_help='yes'
        shift
        ;;
    *)
        error_help='yes'
        echo "${RED}error: Unknown command: $1${RESET}"
        shift
        ;;
    esac
done
if [ "$show_help" = 'yes' ]; then
    show_helps
    exit 0
fi
if [ "$error_help" = 'yes' ]; then
    show_helps
    exit 1
fi
if [ "$default_interface" = 'yes' ]; then
    default_interface
fi
