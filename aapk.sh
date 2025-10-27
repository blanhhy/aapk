#!/bin/bash

# 名称: aapk
# 功能: 优化 apk 的使用体验

# 检查是否提供了命令
if (( $# == 0 )); then
	echo "Advanced wrapper for apk-tools."
	echo "Usage: $(basename $0) COMMAND [<ARGUMENTS>...]"
	echo ""
	echo "Supported commands:"
	echo ""
	echo "  install	 Install specified packages"
	echo "  uninstall   Uninstall specified packages"
	echo "  reinstall   Reinstall specified packages"
	echo ""
	echo "  clean	   Clean all cached packages"
	echo "  autoclean   Remove outdated packages from cache"
	echo "  files	   Show files installed by packages"
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

function search_sort() {
	# 获取所有已安装和可升级的包
	installed_pkgs=$(apk list -I 2>/dev/null | awk '{print $1}')
	upgradable_pkgs=$(apk list -u 2>/dev/null | awk '{print $1}')

	apk search -v "$@" | while IFS= read -r line; do
		[[ -z $line ]] && continue # 跳过空行

		# 提取包全名和描述
		pkg_full=$(echo "$line" | awk -F' - ' '{print $1}')
		description=$(echo "$line" | awk -F' - ' '{print $2}')

		# 检查安装状态
		status=""
		if grep -qFx "$pkg_full" <<< "$installed_pkgs"; then
			grep -qFx "$pkg_full" <<< "$upgradable_pkgs" && status="[upgradable]" || status="[installed]"
		fi

		# 按照apk命名规范分割：包名-版本-发布号
		pkg_name="${pkg_full%-*-*}"
		version_part="${pkg_full#$pkg_name-}"

		# 前缀标识符
		name_prefix=$(echo $pkg_name | awk -F'-' '{print $1}' | sed 's/[0-9.]*$//')
		prefix="$name_prefix$version_part"

		# 输出带分组标记
		echo "$prefix|$pkg_name|$version_part|$description|$status"
	done | sort -t'|' -k1,1 -k2,2
}

function group_show() {
	current_main=""
	current_main_desc=""

	while IFS='|' read -r prefix pkg_name version_part description status; do
		# 识别包类型
		if [[ -z $current_main # 第一个包是主包
		|| $prefix != "$current_main" # 不属于主包的包是主包
		]]; then
			current_main=$prefix # 刷新主包记录
					
			# 主包处理
			echo "" # 组间空行
			printf "${GREEN}%s${NC}/%s ${YELLOW}%s${NC}\n  %s\n" "$pkg_name" "$version_part" "$status" "$description"
			current_main_desc=$description
		else
			# 附属包处理
			# 收纳在主包下，缩进显示，不打印重复的介绍和版本号
			[[ $description = "$current_main_desc"* ]] && description="${description#$current_main_desc}" || description=""
			printf "  ${GRAY}%s%s ${YELLOW}%s${NC}\n" "$pkg_name" "$description" "$status"
		fi
	done
}

function search_non_sort() {
	# 获取所有已安装和可升级的包
	installed_pkgs=$(apk list -I 2>/dev/null | awk '{print $1}')
	upgradable_pkgs=$(apk list -u 2>/dev/null | awk '{print $1}')

	apk search -v "$@" | while IFS= read -r line; do
		[[ -z $line ]] && continue # 跳过空行

		# 提取包全名和描述
		pkg_full=$(echo "$line" | awk -F' - ' '{print $1}')
		description=$(echo "$line" | awk -F' - ' '{print $2}')

		# 检查安装状态
		status=""
		if grep -qFx "$pkg_full" <<< "$installed_pkgs"; then
			grep -qFx "$pkg_full" <<< "$upgradable_pkgs" && status="[upgradable]" || status="[installed]"
		fi
				
		# 按照apk命名规范分割：包名-版本-发布号
		pkg_name="${pkg_full%-*-*}"
		version_part="${pkg_full#$pkg_name-}"
		
		printf "${GREEN}%s${NC}/%s ${YELLOW}%s${NC}\n  %s\n" "$pkg_name" "$version_part" "$status" "$description"
	done
}


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
		if [[ $1 = "-n" ]]; then
			shift
			search_non_sort "$@"
		else
			printf "Searching and sorting... "
			search_sort "$@" | (
				echo "Done"
				group_show
			)
		fi
		;;
	*)
		apk "$COMMAND" "$@"
		;;
esac
