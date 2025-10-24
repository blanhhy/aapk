#!/bin/bash

# 名称: aapk
# 功能: 优化 apk 的使用体验

# 检查是否提供了命令
if [ $# -lt 1 ]; then
    echo "Advanced wrapper for apk-tools."
    echo "Usage: $(basename $0) COMMAND [<ARGUMENTS>...]"
    echo ""
    echo "Supported commands:"
    echo ""
    echo "  install     Install specified packages"
    echo "  uninstall   Uninstall specified packages"
    echo "  reinstall   Reinstall specified packages"
    echo ""
    echo "  clean       Clean all cached packages"
    echo "  autoclean   Remove outdated packages from cache"
    echo "  files       Show files installed by packages"
    echo ""
    echo "  also original apk commands (add|del|info|...)"
    echo ""
    exit 1
fi

COMMAND="$1"
shift

# 颜色定义
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
GRAY='\033[2;37m'
NC='\033[0m' # 重置颜色

case "$COMMAND" in
    c*) # clean
        apk cache clean
        rm -rf /var/cache/apk/*
        ;;
    i*) # install
        apk add "$@"
        ;;
    auto*) # autoclean
        apk cache clean
        ;;
    un*) # uninstall
        apk del "$@"
        ;;
    re*) # reinstall
        apk add --force-overwrite --no-cache "$@"
        ;;
    file*) # files
        for pkg in "$@"; do
            apk info -L "$pkg"
        done
        ;;
    search)
        printf "Checking local packages... "
        
        # 一次性获取所有已安装和可升级的包（只获取包名部分）
        installed_pkgs=$(apk list -I 2>/dev/null | awk -F'-' '{print $1}' | sort)
        upgradable_pkgs=$(apk list -u 2>/dev/null | awk -F'-' '{print $1}' | sort)
        
        printf "Done\nSearching and sorting... "

        # 分组显示包
        (
            # 处理搜索结果
            apk search -v "$@" | while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                
                # 提取包全名和描述
                pkg_full=$(echo "$line" | awk -F' - ' '{print $1}')
                description=$(echo "$line" | awk -F' - ' '{print $2}')
                
                # 按照apk命名规范分割：包名-版本-发布号
                pkg_name=$(echo "$pkg_full" | rev | cut -d'-' -f3- | rev)
                version_part=$(echo "$pkg_full" | rev | cut -d'-' -f1-2 | rev)
                
                # 检查安装状态
                status=""
                pkg_base_name=$(echo "$pkg_name" | awk -F'-' '{print $1}')  # 基本包名用于匹配
                
                if echo "$installed_pkgs" | grep -q "^${pkg_base_name}$"; then
                    if echo "$upgradable_pkgs" | grep -q "^${pkg_base_name}$"; then
                        status="[upgradable]"
                    else
                        status="[installed]"
                    fi
                fi
                
                # 识别包类型
                pkg_type="main"
                if [[ "$pkg_name" =~ -doc$ ]]; then pkg_type="-doc"; fi
                if [[ "$pkg_name" =~ -bash-completion$ ]]; then pkg_type="-bash-completion"; fi
                if [[ "$pkg_name" =~ -fish-completion$ ]]; then pkg_type="-fish-completion"; fi
                if [[ "$pkg_name" =~ -zsh-completion$ ]]; then pkg_type="-zsh-completion"; fi
                if [[ "$pkg_name" =~ -openrc$ ]]; then pkg_type="-service"; fi
                if [[ "$pkg_name" =~ -dev$ ]]; then pkg_type="-dev"; fi
                if [[ "$pkg_name" =~ -lang$ ]]; then pkg_type="-lang"; fi
                if [[ "$pkg_name" =~ -static$ ]]; then pkg_type="-static"; fi
                if [[ "$pkg_name" =~ -tools$ ]]; then pkg_type="-tools"; fi
                if [[ "$pkg_name" =~ -dbg$ ]]; then pkg_type="-debug"; fi
                
                # 输出带分组标记
                echo "$pkg_type|$pkg_name|$version_part|$status|$description"
            done
        ) | (
            echo "Done"
            # 分组处理
            current_group_main=""
            while IFS='|' read -r pkg_type pkg_name version_part status description; do
                if [[ "$pkg_type" == "main" ]]; then
                    # 主包处理
                    echo "" # 组间空行
                    current_group_main="$pkg_name"
                    printf "${GREEN}%s${NC}/%s ${YELLOW}%s${NC}\n" "$pkg_name" "$version_part" "$status"
                    printf "  %s\n" "$description"
                else
                    # 附属包处理
                    if [[ "$current_group_main$pkg_type" != "$pkg_name" ]]; then
                        # 如果附属包不属于当前主包，单独成组
                        echo "" # 组间空行
                        current_group_main="$pkg_name"
                        printf "${GREEN}%s${NC}/%s ${YELLOW}%s${NC}\n" "$pkg_name" "$version_part" "$status"
                        printf "  %s\n" "$description"
                    else
                        # 收纳在主包下，缩进显示，不重复打印介绍
                        printf "  ${GRAY}%s/%s %s${NC}\n" "$pkg_name" "$version_part" "$status"
                    fi
                fi
            done
        )
        ;;
    *)
        apk "$COMMAND" "$@"
        ;;
esac
