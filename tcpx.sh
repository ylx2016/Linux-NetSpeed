#!/usr/bin/env bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# =================================================
#  全局配置区 (Configuration as Data)
# =================================================
readonly SH_VER="100.0.6.8"
readonly GITHUB_RAW_URL="https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master"
readonly CLOUD_STATE_FILE="/etc/tcpx_cloud_lastver" # installcloud 记忆上次探测到的最高可安装 Cloud 内核

# 自安装：把脚本落地到 /usr/local/bin/tcpx，安装后可直接输入 tcpx 运行。
# 以 bash <(curl -fsSL <URL>) 这类管道方式运行时本地没有文件副本，只能从下面的地址重新下载。
# 默认使用与 Update_Shell 相同的权威地址；也可用环境变量 TCPX_URL 临时覆盖：
#   TCPX_URL=<地址> bash <(curl -fsSL <地址>)
readonly TCPX_URL_DEFAULT="${GITHUB_RAW_URL}/tcpx.sh"
readonly TCPX_SELF_URL="${TCPX_URL:-$TCPX_URL_DEFAULT}"
readonly TCPX_INSTALL_PATH="/usr/local/bin/tcpx"

# 颜色变量定义
readonly GREEN_FONT_PREFIX="\033[32m"
readonly RED_FONT_PREFIX="\033[31m"
readonly YELLOW_FONT_PREFIX="\033[33m"
readonly FONT_COLOR_SUFFIX="\033[0m"
readonly INFO="${GREEN_FONT_PREFIX}[信息]${FONT_COLOR_SUFFIX}"
readonly ERROR="${RED_FONT_PREFIX}[错误]${FONT_COLOR_SUFFIX}"
readonly TIP="${YELLOW_FONT_PREFIX}[注意]${FONT_COLOR_SUFFIX}"

# 系统信息全局变量 (初始化)
OS_TYPE=""
OS_ID=""
OS_VERSION_ID=""
OS_ARCH=""

# 检查当前用户是否为 root
if [ "$EUID" -ne 0 ]; then
	echo -e "${ERROR} 请使用 root 用户身份运行此脚本"
	exit 1
fi

# =================================================
#  系统检测模块
# =================================================
check_sys() {
	# 1. 检测架构 (使用最通用的 uname)
	OS_ARCH=$(uname -m)

	# 2. 现代化系统信息获取
	if [[ -f /etc/os-release ]]; then
		# 直接 source 解析标准的 os-release 文件
		. /etc/os-release
		OS_ID="${ID:-unknown}"
		OS_VERSION_ID="${VERSION_ID:-}"
		OS_ID_LIKE="${ID_LIKE:-}" # 新增：获取上游衍生关系
		# 兼容 Debian testing/sid 没有 VERSION_ID 的情况
		if [[ -z "$OS_VERSION_ID" && "$OS_ID" == "debian" && -f /etc/debian_version ]]; then
			OS_VERSION_ID=$(grep -oE '^[0-9]+' /etc/debian_version | head -n 1)
			[[ -z "$OS_VERSION_ID" ]] && OS_VERSION_ID=$(awk -F'/' '{print $1}' /etc/debian_version)
		fi
		[[ -z "$OS_VERSION_ID" ]] && OS_VERSION_ID="unknown"
	elif [[ -f /etc/redhat-release || -f /etc/centos-release ]]; then
		# 兼容极少数没有 os-release 的老旧 CentOS
		OS_ID="centos"
		OS_VERSION_ID=$(grep -oE '[0-9.]+' /etc/redhat-release | awk -F'.' '{print $1}')
	else
		echo -e "${ERROR} 无法检测到受支持的系统版本。此脚本仅支持现代 Debian/Ubuntu/CentOS/Alma/Rocky 系统。"
		exit 1
	fi

	# 3. 规范化 OS_TYPE (引入 ID_LIKE 增强泛衍生版兼容性)
	if [[ "$OS_ID" =~ ^(centos|rhel|almalinux|rocky|oracle|fedora)$ ]] || [[ "$OS_ID_LIKE" =~ (rhel|centos|fedora) ]]; then
		OS_TYPE="CentOS"
		# 提取主版本号
		OS_VERSION_ID=$(echo "$OS_VERSION_ID" | awk -F'.' '{print $1}')
	elif [[ "$OS_ID" =~ ^(debian|ubuntu|pop|kali|linuxmint|deepin|elementary|zorin|armbian)$ ]] || [[ "$OS_ID_LIKE" =~ (debian|ubuntu) ]]; then
		OS_TYPE="Debian"
	else
		echo -e "${ERROR} 不支持的系统分支: ${OS_ID} (ID_LIKE: ${OS_ID_LIKE})"
		exit 1
	fi

	echo -e "${INFO} 检测到系统: ${OS_TYPE} (${OS_ID} ${OS_VERSION_ID}) - 架构: ${OS_ARCH}"

	# 4. 精简依赖检查 (抛弃笨重的 lsb_release，引入轻量的 jq 用于后续 API 解析)
	local required_cmds=("curl" "wget" "awk" "jq")

	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		for cmd in "${required_cmds[@]}"; do
			if ! command -v "$cmd" >/dev/null 2>&1; then
				echo -e "${INFO} 正在安装缺失依赖: $cmd ..."
				if [[ "$cmd" == "jq" ]] && ! rpm -q epel-release >/dev/null 2>&1; then
					yum install -y epel-release >/dev/null 2>&1
				fi
				yum install -y "$cmd" >/dev/null 2>&1
			fi
		done
		# CA 证书更新
		if ! rpm -q ca-certificates >/dev/null 2>&1; then
			yum install ca-certificates -y >/dev/null 2>&1
			update-ca-trust force-enable
		fi
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		local need_update=0
		for cmd in "${required_cmds[@]}"; do
			if ! command -v "$cmd" >/dev/null 2>&1; then
				if [[ $need_update -eq 0 ]]; then
					apt-get update >/dev/null 2>&1
					need_update=1
				fi
				echo -e "${INFO} 正在安装缺失依赖: $cmd ..."
				apt-get install -y "$cmd" >/dev/null 2>&1
			fi
		done
		# CA 证书更新
		if ! dpkg-query -W ca-certificates >/dev/null 2>&1; then
			[[ $need_update -eq 0 ]] && apt-get update >/dev/null 2>&1
			apt-get install ca-certificates -y >/dev/null 2>&1
			update-ca-certificates >/dev/null 2>&1
		fi
	fi

	# 4.1 依赖复检：上面所有安装命令的输出都被重定向丢弃了，装失败也毫无提示。
	# 若不在此处硬失败，后续 get_github_asset 会因缺少 jq 而静默返回空，
	# 用户只能看到"无法获取资源列表"这种完全误导性的报错。
	local missing_cmds=()
	for cmd in "${required_cmds[@]}"; do
		command -v "$cmd" >/dev/null 2>&1 || missing_cmds+=("$cmd")
	done
	if [[ ${#missing_cmds[@]} -gt 0 ]]; then
		echo -e "${ERROR} 以下必需依赖安装失败，脚本无法继续运行:"
		for cmd in "${missing_cmds[@]}"; do
			echo -e "  - ${RED_FONT_PREFIX}${cmd}${FONT_COLOR_SUFFIX}"
		done
		echo -e "${TIP} 请先手动安装后重试，例如:"
		if [[ "${OS_TYPE}" == "CentOS" ]]; then
			echo -e "  yum install -y epel-release && yum install -y ${missing_cmds[*]}"
		else
			echo -e "  apt-get update && apt-get install -y ${missing_cmds[*]}"
		fi
		exit 1
	fi

	# 5. 补充底层内核模块管理依赖 (应对极简版 LXC/VPS 模板)
	if ! command -v lsmod >/dev/null 2>&1; then
		echo -e "${INFO} 正在补齐系统核心依赖: kmod (提供 lsmod/rmmod 命令) ..."
		if [[ "${OS_TYPE}" == "CentOS" ]]; then
			yum install -y kmod >/dev/null 2>&1
		elif [[ "${OS_TYPE}" == "Debian" ]]; then
			apt-get install -y kmod >/dev/null 2>&1
		fi
	fi
}

# =================================================
#  安装前置守卫 (容器环境 / /boot 空间)
# =================================================

# 检测是否运行在容器中。容器共用宿主机内核，装内核毫无意义且可能破坏容器。
check_container() {
	local virt=""
	if command -v systemd-detect-virt >/dev/null 2>&1; then
		virt=$(systemd-detect-virt 2>/dev/null)
	elif command -v virt-what >/dev/null 2>&1; then
		virt=$(virt-what 2>/dev/null | head -n 1)
	fi

	case "$virt" in
	lxc | lxc-libvirt | openvz | docker | podman | rkt | wsl | systemd-nspawn)
		echo -e "${ERROR} 检测到当前为容器环境 (${virt})，容器共用宿主机内核，无法安装内核！"
		return 1
		;;
	esac

	# 兜底: 部分老旧 OpenVZ/LXC 无 systemd-detect-virt，用特征文件识别
	if [[ -d /proc/vz && ! -d /proc/bc ]]; then
		echo -e "${ERROR} 检测到 OpenVZ 容器环境，无法安装内核！"
		return 1
	fi
	if grep -qaE '(lxc|docker|containerd)' /proc/1/cgroup 2>/dev/null; then
		echo -e "${ERROR} 检测到容器环境 (cgroup 特征)，无法安装内核！"
		return 1
	fi
	return 0
}

# 检查 /boot 剩余空间。小 /boot 在生成 initramfs 阶段中途失败会留下半配置状态，重启即失联。
check_boot_space() {
	local need_mb="${1:-300}"
	local avail_mb
	avail_mb=$(df -Pm /boot 2>/dev/null | awk 'NR==2 {print $4}')

	if [[ -z "$avail_mb" ]]; then
		echo -e "${TIP} 无法获取 /boot 剩余空间，跳过检查。"
		return 0
	fi

	if [[ "$avail_mb" -lt "$need_mb" ]]; then
		echo -e "${ERROR} /boot 剩余空间不足: 当前 ${avail_mb}MB，建议至少 ${need_mb}MB。"
		echo -e "${TIP} 内核安装极可能在生成 initramfs 时中途失败，导致系统无法引导！"
		echo -e "${TIP} 请先使用菜单 [52] 删除不再使用的旧内核后重试。"
		read -rp "确认无视风险并继续？(请输入大写 YES 确认): " force_go
		[[ "$force_go" != "YES" ]] && {
			echo -e "${INFO} 已取消安装。"
			return 1
		}
	else
		echo -e "${INFO} /boot 剩余空间检查通过: ${avail_mb}MB 可用。"
	fi
	return 0
}

# 内核安装统一前置检查
pre_install_check() {
	check_container || return 1
	check_boot_space 300 || return 1
	return 0
}

# =================================================
#  网络通信与下载模块
# =================================================

# 全局变量：是否在中国大陆
IS_CN=0

# 全局最优镜像变量
BEST_MIRROR=""

# 判断 URL 是否为 GitHub 系资源 (只有这些才需要走加速镜像)
# 非 GitHub 域名 (如 deb.debian.org / snapshot.debian.org) 套镜像前缀必然 404，
# 白白消耗 4 次超时，故必须先行识别。
is_github_url() {
	local url="$1"
	[[ "$url" =~ ^https?://(www\.)?(github\.com|raw\.githubusercontent\.com|objects\.githubusercontent\.com|codeload\.github\.com)/ ]]
}

# 统一的镜像 URL 组装规则 (测速与实际下载共用，保证两者行为一致)
build_mirror_url() {
	local prefix="$1"
	local url="$2"
	if [[ -z "$prefix" ]]; then
		echo "$url"
	else
		# 镜像站约定: 前缀后直接接不带协议头的原始地址
		echo "${prefix}$(echo "$url" | sed 's|^https\?://||')"
	fi
}

# 1. 极其稳定且快速的 CN 节点检测 (利用 Cloudflare CDN Trace) 与镜像测速
check_cn_status() {
	# 设置 3 秒超时，获取 Cloudflare 边缘节点看到的 IP 归属地
	local cf_trace=$(curl -sL --max-time 3 https://www.cloudflare.com/cdn-cgi/trace || echo "")
	if echo "$cf_trace" | grep -q "loc=CN"; then
		IS_CN=1
		echo -e "${INFO} 检测到当前节点位于中国大陆，正在为您测速并选择最快的 GitHub 镜像..."

		# 优先测速：只探测 3 个高质量镜像，选最快者作为首选
		local mirrors=(
			"https://gh-proxy.com/"
			"https://ghproxy.net/"
			"https://fastgit.cc/"
		)

		# 使用极小的 releases 校验文件作为测速目标 (不到 100 字节)，完美适配镜像站的 release 代理规则
		local test_url="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64.sha256"
		local best_time=9999
		local failed_mirrors=()

		for prefix in "${mirrors[@]}"; do
			# 与 safe_wget 保持完全一致的 URL 改写规则，确保测速结果能代表实际下载可用性
			local target_url=$(build_mirror_url "$prefix" "$test_url")

			# 测速: 限定最多 2 秒超时，-r 0-512 限制只读取头部数据，防止大文件卡死
			# 同时取回 http_code，避免"快速返回 403/404 错误页"的失效镜像在测速中胜出
			local probe=$(curl -sL -m 2 -r 0-512 -o /dev/null -w "%{http_code} %{time_total}" "$target_url" 2>/dev/null)
			local http_code=$(echo "$probe" | awk '{print $1}')
			local time_cost=$(echo "$probe" | awk '{print $2}')

			# 仅 200/206 视为有效；其余(含连接失败的空输出)一律记为失败节点
			if [[ ! "$http_code" =~ ^(200|206)$ ]] || [[ -z "$time_cost" ]]; then
				failed_mirrors+=("$prefix")
			else
				# 使用 awk 比较浮点数时间，找出延迟最低的
				if awk "BEGIN {exit !($time_cost < $best_time)}"; then
					best_time=$time_cost
					BEST_MIRROR=$prefix
				fi
			fi
		done

		if [[ "$best_time" == "9999" ]]; then
			echo -e "${TIP} 所有镜像测速超时，将使用默认轮询模式。"
			BEST_MIRROR="poll"
		else
			echo -e "${INFO} 测速完成！当前网络最优镜像为: ${GREEN_FONT_PREFIX}${BEST_MIRROR}${FONT_COLOR_SUFFIX} (响应时间: ${best_time}s)"
		fi

		# 集中打印出测速失败的镜像，方便您排查和后续替换
		if [[ ${#failed_mirrors[@]} -gt 0 ]]; then
			echo -e "${TIP} 以下镜像测速超时或失效 (已自动剔除首选):"
			for fail_m in "${failed_mirrors[@]}"; do
				echo -e "  - ${RED_FONT_PREFIX}${fail_m}${FONT_COLOR_SUFFIX}"
			done
		fi
	else
		IS_CN=0
		echo -e "${INFO} 当前节点位于海外，使用 GitHub 直连网络。"
	fi
}

# 2. 安全可靠的下载函数 (自带多镜像轮询 failover，支持动态最优节点)
safe_wget() {
	local url="$1"
	local dest="$2"
	local timeout=15

	# 定义默认的加速镜像前缀池
	# 下载兜底池：3 个高质量镜像在前，其余可用镜像随后
	local mirrors=(
		"https://gh-proxy.com/"
		"https://ghproxy.net/"
		"https://fastgit.cc/"
		"https://githubdog.com/"
		"https://tvv.tw/"
		"https://ghfast.top/"
	)

	# 核心逻辑：根据测速结果重构下载队列
	# 非 GitHub 资源 (Debian 官方源等) 直接直连，套镜像只会白等 4 次超时
	if [[ $IS_CN -eq 0 ]] || ! is_github_url "$url"; then
		mirrors=("") # 海外节点 / 非 GitHub 资源只保留原生空前缀
	else
		# 如果测速成功找到了最优节点，将其提取到数组最前面
		if [[ -n "$BEST_MIRROR" && "$BEST_MIRROR" != "poll" ]]; then
			local new_mirrors=("$BEST_MIRROR")
			for m in "${mirrors[@]}"; do
				[[ "$m" != "$BEST_MIRROR" ]] && new_mirrors+=("$m")
			done
			mirrors=("${new_mirrors[@]}")
		fi
		# 给国内机加上原生链接作为终极保底
		mirrors+=("")
	fi

	for prefix in "${mirrors[@]}"; do
		# 组装最终下载链接 (与测速阶段共用同一套规则)
		local target_url=$(build_mirror_url "$prefix" "$url")

		if [[ -z "$prefix" ]]; then
			echo -e "${INFO} 正在请求: ${dest} (直连网络) ..."
		else
			echo -e "${INFO} 正在请求: ${dest} (镜像: ${prefix}) ..."
		fi

		# 使用 wget 下载，跳过证书校验
		if wget --no-check-certificate -qT "$timeout" -t 2 -O "$dest" "$target_url"; then
			# 防御半截包/错误页: 空文件视为失败，继续切换节点
			if [[ -s "$dest" ]]; then
				echo -e "${INFO} ${dest} 下载成功！"
				return 0
			fi
			echo -e "${TIP} 下载内容为空，判定为无效响应。"
			rm -f "$dest"
		fi

		# 当前节点失败时提示并继续下一个循环
		echo -e "${TIP} 当前节点下载异常，正在无缝切换备用节点..."
	done

	echo -e "${ERROR} 文件 ${dest} 所有下载节点均失效，请检查网络或稍后再试！"
	return 1
}

# 3. 稳健的 GitHub 资源获取函数 (使用 jq 提取 JSON，再通过 grep 多重过滤)
# 用法: get_github_asset <仓库名> <Tag关键词> <文件名关键词>
# 示例: get_github_asset "ylx2016/kernel" "Debian_Kernel" "headers"
get_github_asset() {
	local repo="$1"
	local tag_kw="$2"
	local ast_kw="$3"
	local arch_kw="$4" # 可选的架构关键词
	local api_url="https://api.github.com/repos/${repo}/releases"

	local response=$(curl -sL --max-time 10 "$api_url")
	if echo "$response" | grep -q "API rate limit exceeded"; then
		echo -e "${ERROR} 触发 GitHub API 频率限制！(当前 IP 请求过多)" >&2
		return 1
	fi

	# 提取出该仓库所有的下载直链
	local all_urls=$(echo "$response" | jq -r '.[].assets[]?.browser_download_url' 2>/dev/null)
	if [[ -z "$all_urls" ]]; then
		echo -e "${ERROR} 无法从 ${repo} 获取资源列表，请检查网络或稍后再试！" >&2
		return 1
	fi

	# 利用 grep -iE 进行层层精准过滤
	local result=$(echo "$all_urls" | grep -iE "$tag_kw" | grep -iE "$ast_kw")
	[[ -n "$arch_kw" ]] && result=$(echo "$result" | grep -iE "$arch_kw")

	# 排除调试符号包与未签名包：dbg 包体积可达数百 MB 且完全不可用于安装，
	# 而 grep "image" 会同时命中 linux-image-*-dbg_*.deb，head -n 1 有取错风险
	result=$(echo "$result" | grep -viE 'dbg|debug|unsigned')

	# 终极防呆机制：如果是 x86_64 架构，且关键词中没有声明要找 arm64，则强行排除带 arm64/aarch64 的链接，防止模糊匹配误伤
	if [[ "$arch_kw" != *"arm64"* && "$tag_kw" != *"arm64"* && "$OS_ARCH" != "aarch64" ]]; then
		result=$(echo "$result" | grep -viE "arm64|aarch64")
	fi

	local asset_url=$(echo "$result" | head -n 1)

	if [[ -z "$asset_url" ]]; then
		echo -e "${ERROR} 无法在 ${repo} 中解析到匹配关键字 (${tag_kw} -> ${ast_kw} -> ${arch_kw}) 的文件！" >&2
		return 1
	fi

	echo "$asset_url"
}

# =================================================
#  内核安装核心引擎
# =================================================

# 清理旧的 Headers (精简重构)
remove_old_headers() {
	echo -e "${INFO} 正在清理旧的内核 Headers 防止冲突..."
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		# 找出不是当前正在运行的 kernel-headers 并卸载
		local current_ker=$(uname -r)
		rpm -qa | grep -E 'kernel(-ml|-lt|-uek|-rt|-plus)?-headers' | grep -v "$current_ker" | xargs -r rpm -e --nodeps >/dev/null 2>&1
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		dpkg -l | grep -E '(linux|proxmox|pve|raspberrypi)-headers' | awk '{print $2}' | grep -v "$(uname -r)" | xargs -r apt-get purge -y >/dev/null 2>&1
		apt-get autoremove -y >/dev/null 2>&1
	fi
}

# 终极内核安装函数
# 用法: install_kernel_generic <内核描述名称> <Headers_URL> <Image_URL> <版本号>
install_kernel_generic() {
	local kernel_desc="$1"
	local head_url="$2"
	local img_url="$3"
	local kernel_version="$4" # 新增参数，用于 UI 显示

	echo -e "${INFO} ================================================"
	if [[ -n "$kernel_version" ]]; then
		echo -e "${INFO} 开始安装: ${kernel_desc} (版本: \033[32m${kernel_version}\033[0m)"
	else
		echo -e "${INFO} 开始安装: ${kernel_desc}"
	fi
	echo -e "${INFO} ================================================"

	# 只强制检查 img_url，因为某些内核（如 Cloud）本身可能不强制要求 Headers
	if [[ -z "$img_url" ]]; then
		echo -e "${ERROR} 传入的镜像文件下载链接为空，可能是 API 解析失败或上游移除了文件！"
		return 1
	fi

	# 创建独立的工作目录 (mktemp 避免 /tmp 下可预测目录名被抢先创建)
	local work_dir
	work_dir=$(mktemp -d /tmp/kernel_install.XXXXXX) || {
		echo -e "${ERROR} 无法创建临时目录！"
		return 1
	}
	# apt 会用沙箱用户 _apt 访问此目录；700 权限会触发 "unsandboxed" 警告。
	# 755 仅允许读/遍历，.deb 文件本身仍由 root 拥有，不存在安全问题。
	chmod 755 "$work_dir"
	trap 'cd /tmp; rm -rf "$work_dir"; trap - RETURN' RETURN
	cd "$work_dir" || {
		echo -e "${ERROR} 无法进入临时目录 ${work_dir}！"
		return 1
	}

	# 安装前记录 /boot 中已有的内核镜像数量，用于事后验证是否真的装上了
	local vmlinuz_before=$(ls -1 /boot/vmlinuz-* 2>/dev/null | wc -l)

	# 根据系统执行不同的下载和安装逻辑
	# 关键顺序: 先把所有包下载并校验完成，再清理旧 headers，最后安装。
	# 若先清理后下载，一旦下载失败就会停在"旧 headers 已删、新内核没装"的破损状态。
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		local head_file="kernel-headers.rpm"
		local img_file="kernel-image.rpm"

		[[ -n "$head_url" ]] && { safe_wget "$head_url" "$head_file" || return 1; }
		safe_wget "$img_url" "$img_file" || return 1

		# 下载全部成功后才动系统
		remove_old_headers

		echo -e "${INFO} 正在执行 YUM 安装..."
		if [[ -n "$head_url" ]]; then
			yum install -y "./$img_file" "./$head_file" || {
				echo -e "${ERROR} 内核包安装失败，请检查上方 yum 输出！"
				return 1
			}
		else
			yum install -y "./$img_file" || {
				echo -e "${ERROR} 内核包安装失败，请检查上方 yum 输出！"
				return 1
			}
		fi

	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		local head_file="linux-headers.deb"
		local img_file="linux-image.deb"
		local deb_list=()

		[[ -n "$head_url" ]] && { safe_wget "$head_url" "$head_file" || return 1; }
		safe_wget "$img_url" "$img_file" || return 1

		# 下载全部成功后才动系统
		remove_old_headers

		deb_list+=("./$img_file")
		[[ -n "$head_url" && -s "$head_file" ]] && deb_list+=("./$head_file")

		# 用 apt-get install ./xxx.deb 取代 dpkg -i + apt-get -f。
		# 前者是事务性的: 会自动从源里解析 linux-modules-* 等依赖，失败时干净回滚；
		# 后者在依赖无解时 apt-get -f 可能选择"卸载刚装上的内核"来修复，且返回值常为 0。
		echo -e "${INFO} 正在执行 APT 安装 (自动解析依赖)..."
		if ! DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${deb_list[@]}"; then
			echo -e "${ERROR} 内核包安装失败，依赖无法满足或包不兼容当前系统！"
			echo -e "${TIP} 系统未被改动，可尝试菜单 [4] 中的 'a' 自动探测可安装版本。"
			return 1
		fi
	fi

	# 验证 /boot 中确实新增了内核镜像，避免"装失败却报成功"
	local vmlinuz_after=$(ls -1 /boot/vmlinuz-* 2>/dev/null | wc -l)
	if [[ "$vmlinuz_after" -le "$vmlinuz_before" ]]; then
		echo -e "${ERROR} /boot 中未检测到新增的内核镜像，安装可能未真正生效！"
		echo -e "${TIP} 请勿重启，先用菜单 [51] 确认当前内核状态。"
		return 1
	fi

	echo -e "${INFO} ${kernel_desc} 内核包安装完成，正在更新系统引导..."
	BBR_grub
}

# 安装 BBR 原版内核 (调用引擎)
installbbr() {
	pre_install_check || return 1
	local head_url=""
	local img_url=""
	local tag_kw=""
	local arch_kw=""
	local img_kw=""

	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		# 适配新编译的 CentOS Cloud 内核
		tag_kw="CentOS_Kernel_Cloud"
		arch_kw="x86_64"
		# 【核心修复 1】直接匹配 kernel-加数字，从源头完美避开 headers 和 devel
		img_kw="kernel-[0-9]"
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		# 适配新编译的 Debian Cloud 内核
		tag_kw="Debian_Kernel_Cloud"
		arch_kw="amd64"
		img_kw="image" # Debian dpkg 生成的包名为 linux-image 开头
		if [[ "$OS_ARCH" == "aarch64" ]]; then
			tag_kw="Debian_Kernel_Cloud_arm64"
			arch_kw="arm64"
		fi
	fi

	echo -e "${INFO} 正在向 Github/ylx2016 请求最新 ${tag_kw} 内核数据..."

	# 获取下载链接 (现在抓取到的绝对纯净，无需二次 grep -v)
	head_url=$(get_github_asset "ylx2016/kernel" "${tag_kw}" "headers" "${arch_kw}")
	img_url=$(get_github_asset "ylx2016/kernel" "${tag_kw}" "${img_kw}" "${arch_kw}")

	# 【核心修复 2】利用 -oE 标准正则提取版本号，避免部分系统不支持 -P 导致版本号变空
	local kernel_version=$(echo "$img_url" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

	if [[ -n "$kernel_version" ]]; then
		echo -e "${INFO} 解析成功！获取到的最新云端内核版本为: \033[32m${kernel_version}\033[0m"
	else
		echo -e "${INFO} 解析成功！已获取到下载链接，但未能匹配出纯净版本号。"
	fi

	# 将解析出的版本号作为第四个参数传递给安装函数
	install_kernel_generic "BBR Cloud 优化内核" "$head_url" "$img_url" "$kernel_version"
}

# 安装 BBRplus 新版内核 (调用引擎)
installbbrplusnew() {
	pre_install_check || return 1
	local head_url=""
	local img_url=""
	local tag_kw="bbrplus-6."
	local ext="deb"
	local arch_kw="amd64"
	# Debian 的包名为 linux-image-*，而 RPM 的包名是 kernel-<版本号>，二者必须区分
	local img_kw="image"

	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		ext="rpm"
		arch_kw="x86_64"      # RPM 文件名用 x86_64，沿用 amd64 会过滤为空
		img_kw="kernel-[0-9]" # 直接匹配 kernel-加数字，从源头避开 headers/devel
		[[ "$OS_ARCH" == "aarch64" ]] && arch_kw="aarch64"
	else
		[[ "$OS_ARCH" == "aarch64" ]] && arch_kw="arm64"
	fi

	echo -e "${INFO} 正在向 UJX6N/bbrplus-6.x_stable 请求数据..."
	# 利用精准的参数向下传递
	head_url=$(get_github_asset "UJX6N/bbrplus-6.x_stable" "${tag_kw}" "headers" "${arch_kw}.*${ext}")
	img_url=$(get_github_asset "UJX6N/bbrplus-6.x_stable" "${tag_kw}" "${img_kw}" "${arch_kw}.*${ext}")

	local kernel_version=$(echo "$img_url" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
	install_kernel_generic "BBRplus(UJX6N)新版内核" "$head_url" "$img_url" "$kernel_version"
}

# 安装 BBRplus 内核 4.14.129 (cx9208版)
installbbrplus() {
	pre_install_check || return 1
	local head_url=""
	local img_url=""

	if [[ "${OS_TYPE}" == "CentOS" && "${OS_VERSION_ID}" == "7" ]]; then
		head_url="https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/centos/7/kernel-headers-4.14.129-bbrplus.rpm"
		img_url="https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/centos/7/kernel-4.14.129-bbrplus.rpm"
	elif [[ "${OS_TYPE}" == "Debian" && "${OS_ARCH}" == "x86_64" ]]; then
		head_url="https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/debian-ubuntu/x64/linux-headers-4.14.129-bbrplus.deb"
		img_url="https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/debian-ubuntu/x64/linux-image-4.14.129-bbrplus.deb"
	else
		echo -e "${ERROR} BBRplus 4.14.129 仅支持 CentOS 7 或 Debian x86_64！"
		return 1
	fi

	install_kernel_generic "BBRplus 4.14.129" "$head_url" "$img_url"
}

# =================================================
#  自动探测 Cloud 内核最高可安装版本 (依赖解析)
# =================================================
# 用法: detect_cloud_max <img_url_base> <file1> <file2> ...
# 原理: pool 中混着 stable/testing/sid/experimental 全部内核，版本号最大 ≠ 能装。
#       太新的内核依赖独立的 linux-modules-*-cloud-* 包（只存在于其自身发行版源），
#       并可能要求更新的 linux-base / initramfs-tools / libc6。因此从新到旧逐个
#       下载 image 包交给 `apt-get install -s` 做模拟安装(真实依赖解析器)，第一个
#       “干净解析”的版本即当前系统最高可安装版本。
# 结果写入全局变量 CLOUD_MAX_IDX / CLOUD_MAX_FILE (仍为 -1 / 空 表示无可用版本)
CLOUD_MAX_IDX=-1
CLOUD_MAX_FILE=""
detect_cloud_max() {
	local img_url_base="$1"
	shift
	local versions_array=("$@")
	CLOUD_MAX_IDX=-1
	CLOUD_MAX_FILE=""

	local scan_work
	scan_work=$(mktemp -d /tmp/cloud_kernel_scan.XXXXXX) || return 1
	trap 'cd /tmp; rm -rf "$scan_work"; trap - RETURN' RETURN
	cd "$scan_work" || return 1

	for ((i = ${#versions_array[@]} - 1; i >= 0; i--)); do
		local f="${versions_array[$i]}"
		echo -e "${INFO} 正在探测候选内核: ${f} ..."
		if ! safe_wget "${img_url_base}${f}" "probe.deb" >/dev/null 2>&1; then
			continue
		fi
		# 校验是合法 ar 归档，防止半截包造成误判
		if ! head -c 8 probe.deb | grep -q "!<arch>"; then
			rm -f probe.deb
			continue
		fi

		# 必须强制 LC_ALL=C: 下面全部靠 grep apt 的英文输出判断依赖是否可满足，
		# 在 zh_CN 等非英文 locale 下 apt 输出被翻译，所有 grep 都匹配不到，
		# 会导致每个版本都被误判为"依赖可干净满足"，本函数彻底失效。
		local scan_log=$(LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get install -s --no-install-recommends "./probe.deb" 2>&1)
		rm -f probe.deb

		local ok=1
		# 1) 依赖无法满足 / 包破损
		if echo "$scan_log" | grep -qiE "unmet dependencies|broken packages|E: "; then
			ok=0
		fi
		# 2) 会卸载现有软件包 = 必然冲突
		if echo "$scan_log" | grep -q "will be REMOVED"; then
			ok=0
		fi
		# 3) 会升级到跨发行版核心基础库 (libc6/base-files/dpkg/systemd) = 硬装，跳过。
		#    允许升级 linux-base/initramfs-tools 等内核生态包 (当前源内可正常解决)
		if echo "$scan_log" | grep -q "will be upgraded"; then
			local upgraded=$(echo "$scan_log" | sed -n '/will be upgraded/,/^[^ ]/p' | tail -n +2)
			if echo "$upgraded" | grep -qwE "libc6|base-files|dpkg|systemd|systemd-sysv|bash|login|tzdata"; then
				ok=0
			fi
		fi

		if [[ $ok -eq 1 ]]; then
			CLOUD_MAX_IDX=$i
			CLOUD_MAX_FILE="$f"
			echo -e "${GREEN_FONT_PREFIX}  ✓ 该版本依赖可干净满足${FONT_COLOR_SUFFIX}"
			break
		else
			echo -e "${TIP}  ✗ 该版本依赖冲突，已跳过"
		fi
	done
	# 临时目录由 RETURN trap 统一清理
}

# 由 signed image 包名推导配套的 headers 下载地址
# 例: linux-image-6.1.0-18-cloud-amd64_6.1.76-1_amd64.deb
#     -> linux-headers-6.1.0-18-cloud-amd64_6.1.76-1_amd64.deb (位于 pool/main/l/linux/)
# Headers 缺失会导致后续 brutal / LotSpeed 模块无法编译，故尽量一并安装。
get_cloud_headers_url() {
	local img_file="$1"
	local debarch="$2"
	local hdr_base="https://deb.debian.org/debian/pool/main/l/linux/"

	# 提取 ABI 版本 (如 6.1.0-18-cloud-amd64)
	local abi=$(echo "$img_file" | sed -nE "s/^linux-image-(.*-cloud-${debarch})_.*/\1/p")
	[[ -z "$abi" ]] && return 0

	# 从 pool 目录列表中查找完全匹配该 ABI 的 headers 包
	local hdr_pattern="linux-headers-${abi}_[^\" ]+_${debarch}\.deb"
	local hdr_file=$(curl -sL --max-time 10 "$hdr_base" | grep -oE "$hdr_pattern" | sort -V | uniq | tail -n 1)

	if [[ -z "$hdr_file" ]]; then
		echo -e "${TIP} 未找到与 ${abi} 配套的 Headers，将仅安装内核镜像。" >&2
		return 0
	fi
	echo "${hdr_base}${hdr_file}"
}

# 安装官方 Cloud 内核
installcloud() {
	pre_install_check || return 1

	[[ "${OS_TYPE}" != "Debian" ]] && {
		echo -e "${ERROR} Cloud 内核仅支持 Debian 系系统"
		return 1
	}

	local debarch
	if [[ "$OS_ARCH" == "x86_64" ]]; then
		debarch="amd64"
	elif [[ "$OS_ARCH" == "aarch64" ]]; then
		debarch="arm64"
	else
		echo -e "${ERROR} 不支持的架构：$OS_ARCH"
		return 1
	fi

	local img_url_base="https://deb.debian.org/debian/pool/main/l/linux-signed-${debarch}/"
	local img_pattern='linux-image-[^" ]+cloud-'"${debarch}"'_[^" ]+_'"${debarch}"'\.deb'

	echo -e "${INFO} 正在从 Debian 官方源获取 Cloud 内核列表..."
	local deb_files=$(curl -sL --max-time 10 "$img_url_base" | grep -oE "$img_pattern" | sort -V | uniq)
	if [[ -z "$deb_files" ]]; then
		echo -e "${ERROR} 未找到可用的 Cloud 内核版本，请检查网络！"
		return 1
	fi
	mapfile -t versions_array <<<"$deb_files"

	# ---- 读取上次记录的最高可安装版本 (用于默认选中与高亮提示) ----
	local remembered=""
	[[ -f "$CLOUD_STATE_FILE" ]] && remembered=$(cat "$CLOUD_STATE_FILE" 2>/dev/null)
	local remembered_idx=-1
	if [[ -n "$remembered" ]]; then
		for i in "${!versions_array[@]}"; do
			[[ "${versions_array[$i]}" == "$remembered" ]] && {
				remembered_idx=$i
				break
			}
		done
	fi

	# ---- 展示全部版本 (保持原始行为) ----
	echo -e "${INFO} 检测到以下 Cloud 内核版本 (pool 全部候选)："
	for i in "${!versions_array[@]}"; do
		local v_show=$(echo "${versions_array[$i]}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-[0-9]+')
		if [[ $i -eq $remembered_idx ]]; then
			echo -e "  ${GREEN_FONT_PREFIX}$i) [$v_show]${FONT_COLOR_SUFFIX} ${RED_FONT_PREFIX}← 上次最高可安装版本${FONT_COLOR_SUFFIX} -> ${versions_array[$i]}"
		else
			echo "  $i) [$v_show] -> ${versions_array[$i]}"
		fi
	done
	echo -e "  ${GREEN_FONT_PREFIX}a) 自动逐个探测并判断最高可安装版本${FONT_COLOR_SUFFIX}   ${YELLOW_FONT_PREFIX}h) 使用 apt 安装${FONT_COLOR_SUFFIX}"

	local last_idx=$((${#versions_array[@]} - 1))
	local default_idx=$last_idx
	[[ $remembered_idx -ge 0 ]] && default_idx=$remembered_idx

	local def_label="$default_idx"
	[[ $remembered_idx -ge 0 ]] && def_label="${default_idx} (上次记忆)"
	echo -e "${TIP} 输入 'a' 自动判断最高可安装版本，输入 'h' 使用 apt 安装："
	# 内核安装不可逆，超时一律取消而非自动执行；60 秒留足阅读上面版本列表的时间
	if ! read -t 60 -rp "输入选项 [0-${last_idx} / a / h / q 取消，回车默认 ${def_label}]: " choice; then
		echo ""
		echo -e "${TIP} 等待超时，出于安全考虑已自动取消操作 (未做任何更改)。"
		return 0
	fi

	# ---- q: 显式取消 ----
	if [[ "$choice" =~ ^[qQ]$ ]]; then
		echo -e "${INFO} 已取消操作。"
		return 0
	fi

	# ---- a: 自动逐个尝试判断最高可安装版本 ----
	if [[ "$choice" =~ ^[aA]$ ]]; then
		echo -e "${INFO} 开始自动探测最高可安装的 Cloud 内核版本（从新到旧逐个依赖校验）..."
		detect_cloud_max "$img_url_base" "${versions_array[@]}"
		if [[ $CLOUD_MAX_IDX -lt 0 || -z "$CLOUD_MAX_FILE" ]]; then
			echo -e "${TIP} 未找到可干净安装的 pool 版本，已回退到 apt 官方源安装 (最稳妥)。"
			echo -e "${INFO} 正在使用 apt 安装 Cloud 内核及 Headers..."
			apt-get update >/dev/null 2>&1
			apt-get install -y "linux-image-cloud-${debarch}" "linux-headers-cloud-${debarch}"
			BBR_grub
			return 0
		fi
		# 记忆本次探测结果，下次进入默认选中
		echo "$CLOUD_MAX_FILE" >"$CLOUD_STATE_FILE"
		echo -e "${INFO} 探测完成！当前系统最高可安装版本: ${GREEN_FONT_PREFIX}${CLOUD_MAX_FILE}${FONT_COLOR_SUFFIX}，开始安装..."
		install_kernel_generic "Debian 官方 Cloud" "$(get_cloud_headers_url "$CLOUD_MAX_FILE" "$debarch")" "${img_url_base}${CLOUD_MAX_FILE}"
		return 0
	fi

	# ---- h: 直接使用 apt 安装当前发行版云内核 ----
	if [[ "$choice" =~ ^[hH]$ ]]; then
		echo -e "${INFO} 正在使用 apt 安装 Cloud 内核及 Headers..."
		apt-get update >/dev/null 2>&1
		apt-get install -y "linux-image-cloud-${debarch}" "linux-headers-cloud-${debarch}"
		BBR_grub
		return 0
	fi

	# ---- 数字选择或回车默认 ----
	choice=${choice:-$default_idx}
	if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt "$last_idx" ]; then
		echo -e "${TIP} 无效选项，默认安装 ${default_idx} 号版本..."
		choice=$default_idx
	fi

	local selected_file="${versions_array[$choice]}"
	# 一并抓取配套 Headers，否则装完无法编译 brutal/LotSpeed 模块
	install_kernel_generic "Debian 官方 Cloud" "$(get_cloud_headers_url "$selected_file" "$debarch")" "${img_url_base}${selected_file}"
}

# 安装 Lotserver (锐速) 专属内核
installlot() {
	pre_install_check || return 1

	[[ "$OS_ARCH" != "x86_64" ]] && {
		echo -e "${ERROR} Lotserver 仅支持 x86_64 架构！"
		return 1
	}

	# 上游仅提供 CentOS 6/7 的 Lotserver 内核包，8/9/10 请求的是不存在的路径
	if [[ "${OS_TYPE}" == "CentOS" && "${OS_VERSION_ID}" != "6" && "${OS_VERSION_ID}" != "7" ]]; then
		echo -e "${ERROR} Lotserver 内核仅支持 CentOS 6/7，当前为 CentOS ${OS_VERSION_ID}！"
		return 1
	fi

	local work_dir
	work_dir=$(mktemp -d /tmp/lot_install.XXXXXX) || {
		echo -e "${ERROR} 无法创建临时目录！"
		return 1
	}
	# 无论从哪条路径返回，都保证清理临时目录且回到安全的 CWD
	trap 'cd /tmp; rm -rf "$work_dir"; trap - RETURN' RETURN
	cd "$work_dir" || {
		echo -e "${ERROR} 无法进入临时目录 ${work_dir}！"
		return 1
	}

	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		local lot_ver="4.11.2-1" # CentOS 7 默认
		[[ "${OS_VERSION_ID}" == "6" ]] && lot_ver="2.6.32-504"

		local base_url="${GITHUB_RAW_URL}/lotserver/centos/${OS_VERSION_ID}/x64"

		# 先把 4 个包全部下载并校验成功，再动系统 (避免删了旧包却没装上新包)
		local lot_pkgs=(
			"kernel-firmware-${lot_ver}.rpm|kernel-firmware.rpm"
			"kernel-${lot_ver}.rpm|kernel.rpm"
			"kernel-headers-${lot_ver}.rpm|kernel-headers.rpm"
			"kernel-devel-${lot_ver}.rpm|kernel-devel.rpm"
		)
		local item
		for item in "${lot_pkgs[@]}"; do
			local remote="${item%%|*}"
			local local_f="${item##*|}"
			if ! safe_wget "${base_url}/${remote}" "$local_f"; then
				echo -e "${ERROR} Lotserver 组件 ${remote} 下载失败，已中止 (系统未做任何更改)。"
				return 1
			fi
		done

		rpm --import "${GITHUB_RAW_URL}/lotserver/centos/RPM-GPG-KEY-elrepo.org" >/dev/null 2>&1
		remove_old_headers
		yum remove -y kernel-firmware kernel-headers >/dev/null 2>&1

		echo -e "${INFO} 正在安装 Lotserver 专属内核组件..."
		# 显式列出文件名，避免下载失败时把字面量 *.rpm 传给 yum
		if ! yum install -y ./kernel-firmware.rpm ./kernel.rpm ./kernel-headers.rpm ./kernel-devel.rpm; then
			echo -e "${ERROR} Lotserver 内核安装失败！"
			return 1
		fi

	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		# Debian/Ubuntu 走老旧的 snapshot.debian.org 源
		local base_deb="" img_deb=""
		if [[ "$OS_ID" == "debian" && "$OS_VERSION_ID" == "8" ]]; then
			base_deb="http://snapshot.debian.org/archive/debian/20120304T220938Z/pool/main/l/linux-base/linux-base_3.5_all.deb"
			img_deb="http://snapshot.debian.org/archive/debian/20171008T163152Z/pool/main/l/linux/linux-image-3.16.0-4-amd64_3.16.43-2+deb8u5_amd64.deb"
		elif [[ "$OS_ID" == "debian" && "$OS_VERSION_ID" == "9" ]]; then
			base_deb="http://snapshot.debian.org/archive/debian/20160917T042239Z/pool/main/l/linux-base/linux-base_4.5_all.deb"
			img_deb="http://snapshot.debian.org/archive/debian/20171224T175424Z/pool/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb"
		else
			echo -e "${ERROR} Lotserver 不支持当前系统版本！"
			return 1
		fi

		if ! safe_wget "$base_deb" "linux-base.deb" || ! safe_wget "$img_deb" "linux-image.deb"; then
			echo -e "${ERROR} Lotserver 内核组件下载失败，已中止 (系统未做任何更改)。"
			return 1
		fi

		apt-get autoremove -y >/dev/null 2>&1
		remove_old_headers

		dpkg-query -W -f='${Status}' linux-base 2>/dev/null | grep -q "install ok installed" || dpkg -i linux-base.deb
		if ! apt-get install -y --allow-downgrades ./linux-image.deb; then
			echo -e "${ERROR} Lotserver 内核安装失败！"
			return 1
		fi
	fi

	echo -e "${INFO} Lotserver 内核包安装完成，正在更新系统引导..."
	BBR_grub
}

# 询问本机用途，决定"场景相关"参数(内核转发/合包/conntrack)。其余基座参数三种场景通用。
# 交互提示走 stderr，仅最终结果(web/proxy/forward)走 stdout，便于 $(...) 捕获。
# 10 秒无输入或直接回车 → 默认 proxy(机场代理)。
ask_workload_profile() {
	local ans
	echo -e "${INFO} 请选择本机用途 (影响 合包/conntrack 等场景参数；内核转发默认全开):" >&2
	echo -e "      [1] 网站 / 通用          (Nginx/PHP/DB，主要入站短连接)" >&2
	echo -e "      [2] 代理 / 转发组网      (SS/Xray/Trojan/Hysteria/WireGuard/tun) <-- 默认" >&2
	read -t 10 -rp "      输入 1/2 (10 秒无输入或回车默认 [2] 代理): " ans
	echo >&2
	case "$ans" in
	1) echo "web" ;;
	*) echo "proxy" ;;
	esac
}

# =================================================
#  系统级网络与资源自适应优化 (替换旧版优化)
# =================================================
optimizing_system() {
	# 与 tcpfit 共存时让路：tcpfit 会按实测 BDP/内存推导整套 sysctl，并刻意省略
	# 某些参数 (如 tcp_notsent_lowat)。本函数整文件覆盖会与其重叠、甚至塞回它故意
	# 不设的项，且因 99-tcpfit.conf 加载在后而多半失效。故先警告并要求显式确认。
	if tcpfit_present; then
		echo -e "${TIP} 检测到 tcpfit 正在管理网络 sysctl (/etc/sysctl.d/99-tcpfit.conf)。"
		echo -e "${TIP} tcpx 的整体优化会与其重叠，重叠键最终以 tcpfit 为准，且可能引入"
		echo -e "      tcpfit 有意省略的参数。建议改用菜单 [60] 调起 tcpfit 精调。"
		read -rp "仍要继续执行 tcpx 的系统优化吗？(请输入大写 YES 继续): " _go
		if [[ "$_go" != "YES" ]]; then
			echo -e "${INFO} 已跳过，网络精调交由 tcpfit 负责。"
			return 0
		fi
	fi

	echo -e "${INFO} 开始进行系统级网络优化 (自适应 CPU/内存/内核版本)..."

	# 1. 动态获取系统硬件与内核参数
	local total_mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
	local total_mem_mb=$((total_mem_kb / 1024))
	local cpu_cores=$(nproc)
	local kernel_major=$(uname -r | cut -d. -f1)
	local kernel_minor=$(uname -r | cut -d. -f2)

	# 新增：动态获取当前正在使用的拥塞控制算法，防止覆盖 LotSpeed 或其它自定义算法
	local current_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "bbr")
	local current_qdisc=$(cat /proc/sys/net/core/default_qdisc 2>/dev/null || echo "fq")
	[[ "$current_cc" == "unknown" || -z "$current_cc" ]] && current_cc="bbr"
	[[ "$current_qdisc" == "unknown" || -z "$current_qdisc" ]] && current_qdisc="fq"

	# 同理继承当前 IPv6 开关状态。
	# 否则用户先执行 [35] 禁用 IPv6、再执行 [32] 网络优化时，
	# 本函数会无条件写回 disable_ipv6 = 0，把 IPv6 静默重新打开。
	local current_disable_ipv6=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null || echo "0")
	[[ "$current_disable_ipv6" != "1" ]] && current_disable_ipv6="0"
	if [[ "$current_disable_ipv6" == "1" ]]; then
		echo -e "${TIP} 检测到当前已禁用 IPv6，本次优化将保持该状态 (如需开启请用菜单 [36])。"
	fi

	# 1.5 询问本机用途，决定场景相关参数(合包/conntrack)，其余基座参数通用。
	#     内核转发按用户要求默认全开，不再随用途区分。
	local workload autocork tune_conntrack
	workload=$(ask_workload_profile)
	case "$workload" in
	web)
		autocork=1
		tune_conntrack=0
		echo -e "${INFO} 用途=网站/通用：开启合包(autocorking 提升小响应效率)。"
		;;
	*)
		autocork=0
		tune_conntrack=1
		echo -e "${INFO} 用途=代理/转发：关闭合包(低延迟)、抬高 conntrack 上限。"
		;;
	esac

	# 2. 根据内存大小动态适配 (socket 缓冲上限 / 并发连接 / 文件描述符)
	#    注意: sock_buf_max 只是"每 socket 自动调优的上限"，不是默认值。默认值必须
	#    保持很小 (见下方 rmem_default/wmem_default)，否则每条连接都按上限预留内存，
	#    高并发下极易 OOM —— 这是旧版最严重的负优化 (8G 机器默认缓冲写到了 64MB)。
	local sock_buf_max somaxconn file_max syn_backlog
	if [ "$total_mem_mb" -ge 8192 ]; then
		# 8GB 及以上高配机器: 每 socket 上限 64MB (足够覆盖高 BDP 链路，且不虚高)
		sock_buf_max=67108864
		somaxconn=1048576
		file_max=2097152
		syn_backlog=65535
	elif [ "$total_mem_mb" -ge 2048 ]; then
		# 2GB - 8GB 中等配置: 32MB
		sock_buf_max=33554432
		somaxconn=65535
		file_max=1048576
		syn_backlog=32768
	else
		# 2GB 以下小内存机器: 16MB
		sock_buf_max=16777216
		somaxconn=32768
		file_max=524288
		syn_backlog=16384
	fi

	# 3. 根据 CPU 核心数动态适配网卡队列与积压
	local netdev_max_backlog=$((10000 * cpu_cores))
	[[ $netdev_max_backlog -lt 32768 ]] && netdev_max_backlog=32768
	[[ $netdev_max_backlog -gt 100000 ]] && netdev_max_backlog=100000

	local netdev_budget=$((300 + 20 * cpu_cores))
	[[ $netdev_budget -gt 50000 ]] && netdev_budget=50000

	# 4. 生成统一的 sysctl 配置文件
	local sysctl_conf="/etc/sysctl.d/99-sysctl.conf"

	# 备份并清空原文件（比几十行 sed -i 速度快且更安全）
	[[ -f "$sysctl_conf" ]] && cp "$sysctl_conf" "${sysctl_conf}.bak"
	cat /dev/null >"$sysctl_conf"

	# 写入基础通用优化 (兼容 CentOS 7-9, Debian 9-12, Ubuntu 18-24)
	cat >>"$sysctl_conf" <<EOF
# --- 文件系统与内存基础 ---
fs.file-max = $file_max
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = $file_max
# 现代 64 位内核默认 pid_max 已是 4194304，旧版写死 65535 反而是"降级"，
# 高进程/线程数场景 (大量容器、Go/Java 服务) 会 fork 失败。取现代默认值。
kernel.pid_max = 4194304
vm.swappiness = 1

# --- 网络核心队列与连接数 ---
net.core.somaxconn = $somaxconn
net.core.netdev_max_backlog = $netdev_max_backlog
net.core.netdev_budget = $netdev_budget
net.core.rmem_max = $sock_buf_max
net.core.wmem_max = $sock_buf_max
# 默认收发缓冲保持较小，由内核在 min~max 间自动放大即可；
# 切勿设成上限的一半 (旧版在 8G 机上把默认写到 64MB，空闲连接也吃满，属严重负优化)。
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.optmem_max = 65536

# --- TCP 核心调优 (缓冲区自适应) ---
net.ipv4.tcp_rmem = 4096 131072 $sock_buf_max
net.ipv4.tcp_wmem = 4096 65536 $sock_buf_max
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_autocorking = $autocork
net.ipv4.tcp_slow_start_after_idle = 0
# tcp_max_syn_backlog 单列一个更保守的值 (不再跟 somaxconn 绑死到百万级)，
# 半开连接队列过大意义有限且吃内存；配合 syncookies=1 足以应对 SYN 洪水。
net.ipv4.tcp_max_syn_backlog = $syn_backlog
# tcp_no_metrics_save=1: 不缓存上条连接的 RTT/cwnd 指标，避免一次抖动的坏指标
# 拖累后续新连接的初始拥塞窗口 (旧版设为 0 会保存陈旧指标，属负优化)。
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1

# --- TCP 超时、重传与 KeepAlive 优化 ---
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_fin_timeout = 15
# synack_retries 旧版=1：弱网/丢包客户端收不到 SYN-ACK 就直接连不上(网站可达性、
# 代理手机端连接失败)。取 2，在抗 SYN 洪水与可用性之间折中。
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_orphan_retries = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
# tw_buckets 旧版 5000 过低：繁忙代理/服务器一旦超过就强杀 TIME_WAIT，
# 引发端口复用异常与 RST。配合 tcp_tw_reuse=1，取一个更从容的值。
net.ipv4.tcp_max_tw_buckets = 55000
net.ipv4.tcp_fastopen = 3

# --- 路由转发 (默认全开，兼容 Docker/Tailscale/WireGuard 等；route_localnet 已按安全建议移除) ---
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = $current_disable_ipv6
net.ipv6.conf.default.disable_ipv6 = $current_disable_ipv6

# --- 默认拥塞控制 (动态继承) ---
net.core.default_qdisc = $current_qdisc
net.ipv4.tcp_congestion_control = $current_cc
EOF

	# 4.1 场景相关：繁忙中转/转发节点抬高连接跟踪表上限，避免 conntrack 打满丢连接。
	#     nf_conntrack 模块未加载时该键不存在，sysctl 载入会忽略(告警已抑制)，故无害。
	if [[ "$tune_conntrack" -eq 1 ]]; then
		local ct_max=262144
		local ct_hashsize=$((ct_max / 4))
		# nf_conntrack 的 sysctl 键只在模块加载后才存在；先加载并持久化 (modules-load.d)，
		# 否则重启后该键缺失、nf_conntrack_max 设置会静默丢失。
		modprobe nf_conntrack >/dev/null 2>&1
		echo "nf_conntrack" >/etc/modules-load.d/tcpx-conntrack.conf
		# 只加大 max 不加大 hashsize(桶数) 会让哈希链变长、查表变慢。
		# hashsize 经验取 max/4，用 modprobe 选项持久化 (重启加载模块时生效)，并对当前已加载模块即时生效。
		echo "options nf_conntrack hashsize=${ct_hashsize}" >/etc/modprobe.d/tcpx-conntrack.conf
		[[ -w /sys/module/nf_conntrack/parameters/hashsize ]] &&
			echo "$ct_hashsize" >/sys/module/nf_conntrack/parameters/hashsize 2>/dev/null
		cat >>"$sysctl_conf" <<EOF

# --- 连接跟踪 (用途=代理/转发，繁忙节点防 conntrack 表溢出) ---
net.netfilter.nf_conntrack_max = $ct_max
EOF
	fi

	# 5. 根据内核版本进行高级参数兼容
	# 移除低版本废弃参数: net.ipv4.tcp_tw_recycle (在内核 4.12 中已彻底移除，高版本强制写入会报错)
	if [[ "$kernel_major" -lt 4 || ("$kernel_major" -eq 4 && "$kernel_minor" -lt 12) ]]; then
		echo "net.ipv4.tcp_tw_recycle = 0" >>"$sysctl_conf"
	fi

	# 移除低版本废弃参数: net.ipv4.tcp_fack (在内核 4.11 中已废弃，合并到了通用重传逻辑中)
	if [[ "$kernel_major" -lt 4 || ("$kernel_major" -eq 4 && "$kernel_minor" -lt 11) ]]; then
		echo "net.ipv4.tcp_fack = 1" >>"$sysctl_conf"
	fi

	# 6. 系统资源限制极限优化 (systemd 与 limits.conf)
	echo -e "${INFO} 正在根据内存大小自动优化系统文件描述符限制..."

	# 优化 Systemd 配置
	if [[ -d "/etc/systemd" ]]; then
		# 整文件覆盖前先备份用户原有配置。仅在 .bak 不存在时备份，
		# 避免重复运行本函数时用"已被我们改写过的版本"覆盖掉最初的原始文件。
		[[ -f /etc/systemd/system.conf && ! -f /etc/systemd/system.conf.bak ]] &&
			cp /etc/systemd/system.conf /etc/systemd/system.conf.bak
		cat >/etc/systemd/system.conf <<EOF
[Manager]
DefaultTimeoutStopSec=30s
# core dump 关闭：崩溃 core 可能含 TLS 私钥/代理凭据且会撑爆磁盘，故禁用。
DefaultLimitCORE=0
DefaultLimitNOFILE=$file_max
DefaultLimitNPROC=infinity
DefaultTasksMax=infinity
EOF
		systemctl daemon-reload >/dev/null 2>&1
	fi

	# 优化 limits.conf (同样先备份原始文件，仅首次备份)
	[[ -f /etc/security/limits.conf && ! -f /etc/security/limits.conf.bak ]] &&
		cp /etc/security/limits.conf /etc/security/limits.conf.bak
	cat >/etc/security/limits.conf <<EOF
* soft   nofile    $file_max
* hard   nofile    $file_max
* soft   nproc     unlimited
* hard   nproc     unlimited
* soft   core      0
* hard   core      0
root  soft   nofile    $file_max
root  hard   nofile    $file_max
root  soft   nproc     unlimited
root  hard   nproc     unlimited
root  soft   core      0
root  hard   core      0
EOF

	# 清理旧的 ulimit 注入
	sed -i '/ulimit -SHn/d' /etc/profile
	sed -i '/ulimit -SHu/d' /etc/profile
	echo "ulimit -SHn $file_max" >>/etc/profile

	# 修复 Pam 会话限制
	if [[ -f "/etc/pam.d/common-session" ]] && ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
		echo "session required pam_limits.so" >>/etc/pam.d/common-session
	fi

	# 7. 应用内核与系统参数
	echo -e "${INFO} 正在应用自适应内核配置..."
	# sysctl --system 会按序加载 /etc/sysctl.d/ 下全部文件(含本文件)，
	# 前面单独的 sysctl -p "$sysctl_conf" 属于重复执行，已移除。
	sysctl --system >/dev/null 2>&1

	# 透明大页设为 madvise: 仅对显式 madvise(MADV_HUGEPAGE) 的程序启用大页。
	# 相比 always，可避免 Redis/数据库等延迟敏感服务因大页整理(khugepaged)
	# 产生的卡顿与内存放大；同时不影响真正需要大页的程序主动申请。
	if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
		echo madvise >/sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null
		# 上面的 echo 仅本次运行生效，重启回默认。用一个 oneshot 服务在开机时重设。
		cat >/etc/systemd/system/tcpx-thp.service <<'EOF'
[Unit]
Description=Set Transparent HugePage to madvise (tcpx)
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo madvise > /sys/kernel/mm/transparent_hugepage/enabled'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload >/dev/null 2>&1
		systemctl enable tcpx-thp.service >/dev/null 2>&1
	fi

	echo -e "${INFO} 系统网络与资源限制自适应优化完成！(建议完成后重启服务器以全面生效)"
}

# =================================================
#  网络加速统一切换引擎 (替代原来十几个 startxxx 函数)
# =================================================

# 检测本机是否已被 tcpfit "应用"(真正在管理网络参数)，而非仅仅"装了 tcpfit 这个工具"。
# 关键区别: /usr/local/bin/tcpfit 只代表命令行工具已安装，用户可能从未 apply 过；
# 此时不应弹出"tcpfit 正在管理本机"的警告与 YES 确认。已应用的证据是:
#   - /etc/sysctl.d/99-tcpfit.conf : apply 时写入的 sysctl (最确定的已应用标志)
#   - tcpfit-qdisc.service         : apply 出向整形时创建的 systemd 单元
#   - /var/lib/tcpfit              : 运行后产生的状态目录
# 故此处刻意不再检测裸二进制文件，避免"只装未用"被误判为正在管理。
tcpfit_present() {
	[[ -f /etc/sysctl.d/99-tcpfit.conf ]] && return 0
	[[ -d /var/lib/tcpfit ]] && return 0
	systemctl list-unit-files 2>/dev/null | grep -q '^tcpfit-qdisc\.service' && return 0
	return 1
}

# 返回 cc/qdisc/ecn 应写入的 sysctl 文件。
# sysctl --system 按文件名字典序加载，后者覆盖前者：99-sysctl.conf < 99-tcpfit.conf，
# 故 tcpfit 存在时若仍写 99-sysctl.conf，用户在菜单里选的算法会被 tcpfit 的 bbr 覆盖。
# 改写到 99-zz-tcpx-accel.conf (排序在 99-tcpfit.conf 之后)，让用户的显式选择生效。
readonly TCPX_ACCEL_DROPIN="/etc/sysctl.d/99-zz-tcpx-accel.conf"
# LotSpeed 开机自启服务：保证重启后 lotspeed 模块被加载且算法被重新应用 (详见 setup_lotspeed_boot_service)
readonly LOTSPEED_BOOT_SERVICE="/etc/systemd/system/lotspeed-boot.service"
accel_conf_path() {
	if tcpfit_present; then
		echo "$TCPX_ACCEL_DROPIN"
	else
		echo "/etc/sysctl.d/99-sysctl.conf"
	fi
}

# tcpfit 的出向整形是否正在运行。它对网卡出向限速/整形，会盖过任何拥塞算法
# (LotSpeed / BBR / 锐速) 的实际吞吐——换算法不会自动解除它。
tcpfit_shaper_active() {
	systemctl is-active tcpfit-qdisc.service >/dev/null 2>&1
}

# 开启加速前，若检测到 tcpfit 整形在跑，询问用户是否停用，避免"换了算法却跑不满"。
maybe_offer_disable_tcpfit_shaper() {
	tcpfit_shaper_active || return 0
	echo -e "${TIP} 检测到 tcpfit 出向整形 (tcpfit-qdisc.service) 正在运行。"
	echo -e "${TIP} 它会对网卡出向限速/整形，从而限制本次加速算法的实际吞吐。"
	read -rp "是否停用 tcpfit 整形以便加速全速生效？(y=停用 / 回车=保留): " _shaper_ans
	if [[ "$_shaper_ans" =~ ^[yY]$ ]]; then
		systemctl disable --now tcpfit-qdisc.service >/dev/null 2>&1
		echo -e "${INFO} 已停用 tcpfit 出向整形 (恢复: systemctl enable --now tcpfit-qdisc.service，或重新运行 tcpfit)。"
	else
		echo -e "${INFO} 已保留 tcpfit 整形，加速算法吞吐仍会受其限制。"
	fi
}

# 启用 LotSpeed 时无条件停用 tcpfit 出向整形 (按用户要求不再询问)。
# tcpfit-qdisc.service 对网卡出向限速/整形，会直接盖过 LotSpeed 的实际吞吐。
disable_tcpfit_shaper_force() {
	tcpfit_shaper_active || return 0
	systemctl disable --now tcpfit-qdisc.service >/dev/null 2>&1
	echo -e "${INFO} 已自动停用 tcpfit 出向整形 (tcpfit-qdisc.service)，以便 LotSpeed 全速生效。"
	echo -e "${TIP} 如需恢复: systemctl enable --now tcpfit-qdisc.service，或重新运行 tcpfit。"
}

# 卸载加速器 (清理配置)
remove_bbr_lotserver() {
	echo -e "${INFO} 正在清理旧的拥塞控制与队列算法配置..."
	# 三处都清: 主文件、传统 /etc/sysctl.conf、以及 tcpfit 共存时用的高优先级 drop-in，
	# 避免切换算法后残留旧行 (drop-in 排序最靠后，残留会覆盖新选择)。
	local f
	for f in /etc/sysctl.d/99-sysctl.conf /etc/sysctl.conf "$TCPX_ACCEL_DROPIN"; do
		# tcp_ecn 用 [[:space:]]*= 收尾锚定，避免顺带删掉 net.ipv4.tcp_ecn_fallback
		[[ -f "$f" ]] && sed -i '/net.core.default_qdisc/d; /net.ipv4.tcp_congestion_control/d; /net\.ipv4\.tcp_ecn[[:space:]]*=/d' "$f"
	done

	sysctl --system >/dev/null 2>&1

	# 停用 LotSpeed 开机自启服务：切换到 BBR/锐速 等其它算法时若不取消它，
	# 重启后 lotspeed-boot.service 会重新加载模块并把算法顶回 lotspeed，
	# 造成"切了却又变回来"的幽灵问题。切到 LotSpeed 的路径会在其后重新启用本服务。
	systemctl disable --now lotspeed-boot.service >/dev/null 2>&1

	# 修改：停用并卸载 LotSpeed 模块 (但不物理删除文件，以便随时通过菜单快速切换)
	if command -v lotspeed >/dev/null 2>&1; then
		lotspeed stop >/dev/null 2>&1
		rmmod lotspeed >/dev/null 2>&1
	fi
	# 如果没有 helper 脚本但也加载了模块的兜底清理
	if lsmod | grep -q "lotspeed"; then
		rmmod lotspeed >/dev/null 2>&1
	fi

	if [[ -e /appex/bin/lotServer.sh ]]; then
		local tmp_lot
		tmp_lot=$(mktemp /tmp/lotserver.XXXXXX)
		if fetch_remote_script "https://raw.githubusercontent.com/fei5seven/lotServer/master/lotServerInstall.sh" "$tmp_lot" >/dev/null 2>&1; then
			echo | bash "$tmp_lot" uninstall >/dev/null 2>&1
		fi
		rm -f "$tmp_lot"
	fi
}

# 确保 qdisc 对应的 sch_ 模块已加载并在重启后自动加载。
# 拥塞算法(tcp_congestion_control)写入时内核会按需自动 request_module，
# 但 default_qdisc 不会：cake/fq_pie 等模块若未加载，写 default_qdisc 会静默失败。
ensure_qdisc_module() {
	local q="$1"
	[[ -z "$q" ]] && return 0
	modprobe "sch_${q}" >/dev/null 2>&1
	echo "sch_${q}" >/etc/modules-load.d/tcpx-qdisc.conf
}

# 统一加速开启函数
# 用法: enable_acceleration <队列算法> <拥塞控制算法>
enable_acceleration() {
	local qdisc="$1"
	local cc="$2"

	# remove_bbr_lotserver 会连同 tcp_ecn 行一并删除。先记住当前 ECN 状态，
	# 切换算法后按原样写回，避免用户在菜单 [30] 开启的 ECN 被静默清掉。
	local prev_ecn
	prev_ecn=$(cat /proc/sys/net/ipv4/tcp_ecn 2>/dev/null)
	[[ ! "$prev_ecn" =~ ^[0-2]$ ]] && prev_ecn=""

	remove_bbr_lotserver
	maybe_offer_disable_tcpfit_shaper

	echo -e "${INFO} 正在应用: ${cc} + ${qdisc} ..."
	ensure_qdisc_module "$qdisc"
	local sysctl_conf
	sysctl_conf=$(accel_conf_path)
	if [[ "$sysctl_conf" == "$TCPX_ACCEL_DROPIN" ]]; then
		echo -e "${TIP} 检测到 tcpfit，已将本次选择写入高优先级文件 ${sysctl_conf}"
		echo -e "${TIP} 以覆盖 tcpfit 默认的 bbr/fq (仅覆盖 cc/qdisc，其余精调仍归 tcpfit)。"
	fi
	echo "net.core.default_qdisc=$qdisc" >>"$sysctl_conf"
	echo "net.ipv4.tcp_congestion_control=$cc" >>"$sysctl_conf"
	# 保留切换前的 ECN 设置
	[[ -n "$prev_ecn" ]] && echo "net.ipv4.tcp_ecn=$prev_ecn" >>"$sysctl_conf"

	sysctl --system >/dev/null 2>&1
	echo -e "${INFO} 加速算法修改成功！如果未立即生效，请重启服务器。"
}

# 启用 Lotserver
startlotserver() {
	remove_bbr_lotserver
	maybe_offer_disable_tcpfit_shaper
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		yum install ethtool -y
	else
		apt-get update && apt-get install ethtool -y
	fi

	local tmp_lot
	tmp_lot=$(mktemp /tmp/lotserver.XXXXXX) || return 1
	if ! fetch_remote_script "https://raw.githubusercontent.com/fei5seven/lotServer/master/lotServerInstall.sh" "$tmp_lot"; then
		rm -f "$tmp_lot"
		echo -e "${ERROR} lotServer 安装脚本下载失败！"
		return 1
	fi
	echo | bash "$tmp_lot" install
	rm -f "$tmp_lot"

	if [[ ! -f /appex/etc/config ]]; then
		echo -e "${ERROR} lotServer 安装失败，未生成配置文件 /appex/etc/config！"
		return 1
	fi
	sed -i '/advinacc/d; /maxmode/d' /appex/etc/config
	echo -e "advinacc=\"1\"\nmaxmode=\"1\"" >>/appex/etc/config
	/appex/bin/lotServer.sh restart
}

# 开启/关闭 ECN (显式控制)
set_ecn() {
	local status="$1"
	local sysctl_conf
	sysctl_conf=$(accel_conf_path)
	# 从所有可能位置清掉旧 ecn 行，再写入到当前生效优先级最高的文件
	# 收尾锚定 [[:space:]]*=，只删 tcp_ecn 本身，不误伤 tcp_ecn_fallback
	sed -i '/net\.ipv4\.tcp_ecn[[:space:]]*=/d' /etc/sysctl.d/99-sysctl.conf /etc/sysctl.conf "$TCPX_ACCEL_DROPIN" 2>/dev/null
	echo "net.ipv4.tcp_ecn=$status" >>"$sysctl_conf"
	sysctl --system >/dev/null 2>&1
	[[ "$status" == "1" ]] && echo -e "${INFO} ECN 已开启！" || echo -e "${INFO} ECN 已关闭！"
}

# 彻底卸载全部加速与优化 (抛弃几十个 sed 删除，直接清空文件)
remove_all() {
	echo -e "${INFO} 正在清空网络优化与系统限制..."
	rm -f /etc/sysctl.d/99-sysctl.conf
	rm -f "$TCPX_ACCEL_DROPIN"
	cat /dev/null >/etc/sysctl.conf
	sysctl --system >/dev/null 2>&1

	# 逐个文件加存在性守卫：如 /etc/pam.d/common-session 在 CentOS 上并不存在，
	# 无守卫的 sed -i 会打印 "No such file" 噪声错误。
	[[ -f /etc/systemd/system.conf ]] && sed -i '/DefaultTimeoutStopSec/d; /DefaultLimitCORE/d; /DefaultLimitNOFILE/d; /DefaultLimitNPROC/d' /etc/systemd/system.conf
	[[ -f /etc/security/limits.conf ]] && sed -i '/soft   nofile/d; /hard   nofile/d; /soft   nproc/d; /hard   nproc/d; /soft   core/d; /hard   core/d' /etc/security/limits.conf
	[[ -f /etc/profile ]] && sed -i '/ulimit -SHn/d' /etc/profile
	[[ -f /etc/pam.d/common-session ]] && sed -i '/required pam_limits.so/d' /etc/pam.d/common-session

	systemctl daemon-reload
	remove_bbr_lotserver
	# 新增：彻底卸载时，物理清理 LotSpeed 残留文件
	rm -f /usr/local/bin/lotspeed
	rm -rf /opt/lotspeed
	# remove_bbr_lotserver 已 disable --now 了开机服务，这里再物理删除 unit 文件并重载
	rm -f "$LOTSPEED_BOOT_SERVICE"

	# 清理系统优化持久化产物: THP 服务、qdisc/conntrack 模块自加载与 modprobe 选项
	systemctl disable --now tcpx-thp.service >/dev/null 2>&1
	rm -f /etc/systemd/system/tcpx-thp.service
	rm -f /etc/modules-load.d/tcpx-qdisc.conf
	rm -f /etc/modules-load.d/tcpx-conntrack.conf
	rm -f /etc/modprobe.d/tcpx-conntrack.conf
	systemctl daemon-reload >/dev/null 2>&1
	# tcpfit 是独立工具，其 sysctl/整形/systemd 单元不归本脚本管理，须单独回滚
	if tcpfit_present; then
		echo -e "${TIP} 检测到 tcpfit 仍在管理本机网络参数 (99-tcpfit.conf / tcpfit-qdisc.service 等)。"
		echo -e "${TIP} tcpx 不会替它卸载，如需彻底还原请另外执行: tcpfit rollback"
	fi
	echo -e "${INFO} 系统已恢复原生状态。"
}

# =================================================
#  系统引导与内核管理引擎
# =================================================

# 现代化更新引导 (GRUB)
BBR_grub() {
	echo -e "${INFO} 正在更新系统引导..."
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		if command -v grubby >/dev/null 2>&1; then
			# grubby 在 BLS (RHEL/CentOS 8-10) 和传统 GRUB2 下均可用。
			# 用 gsub 去掉 RHEL 9 输出中可能带的引号，再按版本号排序取最新内核，
			# 避免依赖 index 顺序 (index=0 是当前默认，不一定是版本最新的)。
			local latest_kernel
			latest_kernel=$(grubby --info=ALL |
				awk -F= '/^kernel/{gsub(/"/,"",$2); print $2}' |
				sort -V | tail -n 1)
			if [[ -n "$latest_kernel" ]]; then
				grubby --set-default="$latest_kernel" >/dev/null 2>&1
				echo -e "${INFO} 默认启动内核已更新为: ${latest_kernel##*/}"
			else
				echo -e "${TIP} grubby 未找到内核条目，回退到 grub2-mkconfig..."
				_bbr_grub2_mkconfig
			fi
		else
			_bbr_grub2_mkconfig
		fi
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		# systemd-boot: deb 包的 postinst 钩子 (kernel-install) 已自动更新引导条目，
		# 此处只需将 systemd-boot 加载器二进制本身更新到最新即可，无需操作 GRUB。
		if command -v bootctl >/dev/null 2>&1 && bootctl is-installed 2>/dev/null; then
			echo -e "${INFO} 检测到 systemd-boot，引导条目已由包管理器钩子自动处理。"
			bootctl update >/dev/null 2>&1 || true
		elif command -v update-grub >/dev/null 2>&1; then
			update-grub >/dev/null 2>&1
		else
			apt-get install -y grub2-common >/dev/null 2>&1
			update-grub >/dev/null 2>&1
		fi
	fi
}

# grub2-mkconfig 回退辅助函数 (UEFI 优先，再 BIOS legacy)
_bbr_grub2_mkconfig() {
	local grub_cfg=""
	# UEFI: /boot/efi/EFI/<distro>/grub.cfg
	if [[ -d /boot/efi/EFI ]]; then
		grub_cfg=$(find /boot/efi/EFI -maxdepth 2 -name grub.cfg 2>/dev/null | head -n 1)
	fi
	# BIOS legacy fallback
	[[ -z "$grub_cfg" && -f /boot/grub2/grub.cfg ]] && grub_cfg="/boot/grub2/grub.cfg"
	if [[ -n "$grub_cfg" ]]; then
		grub2-mkconfig -o "$grub_cfg" >/dev/null 2>&1
	fi
	grub2-set-default 0
}

# 查看已安装的内核与排序
show_kernels() {
	clear
	echo -e "${INFO} ==================================================="
	echo -e "${INFO} 当前系统中已安装的内核包："
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		rpm -qa | grep -E "^kernel(-ml|-lt|-uek|-rt|-plus)?(-image|-core|-modules|-devel|-headers)?-[0-9]" | sort -V
		echo -e "${INFO} ==================================================="
		echo -e "${INFO} GRUB 引导项 (通常 index=0 为默认启动项)："
		grubby --info=ALL | grep -E "^kernel|^index"
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		dpkg -l | grep -E "^ii  (linux-(image|headers|modules)|pve-kernel|proxmox-kernel|proxmox-headers|raspberrypi-kernel)" | awk '{print $2, $3}' | column -t | sort -V
		echo -e "${INFO} ==================================================="
		echo -e "${INFO} /boot 目录下的内核镜像："
		ls -1v /boot/vmlinuz-* 2>/dev/null
	fi
	echo -e "${INFO} ==================================================="
	echo -e "${TIP} 当前实际正在运行的内核: ${GREEN_FONT_PREFIX}$(uname -r)${FONT_COLOR_SUFFIX}"
	echo ""
	return 0
}

# 高级交互式内核管理 (精准多选删除，支持删除当前内核)
delete_kernel_custom() {
	clear
	echo -e "${INFO} ==================================================="
	echo -e "${INFO} 正在扫描系统中已安装的内核包..."
	local current_kernel=$(uname -r)
	local kernel_list=()

	# 使用更精准的包查询方式，防止名字过长被截断
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		mapfile -t kernel_list < <(rpm -qa | grep -E "^kernel(-ml|-lt|-uek|-rt|-plus)?(-image|-core|-modules|-devel|-headers)?-[0-9]" | sort -V)
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		mapfile -t kernel_list < <(dpkg-query -W -f='${Package}\n' | grep -E "^(linux-(image|headers|modules)|pve-kernel|proxmox-kernel|proxmox-headers|raspberrypi-kernel)" | sort -V)
	fi

	if [[ ${#kernel_list[@]} -eq 0 ]]; then
		echo -e "${ERROR} 未检测到可管理的内核包。"
		return
	fi

	echo -e "${TIP} 当前正在运行的内核: ${GREEN_FONT_PREFIX}${current_kernel}${FONT_COLOR_SUFFIX}"
	echo -e "${INFO} ==================================================="

	# 打印带编号的内核列表
	for i in "${!kernel_list[@]}"; do
		local pkg="${kernel_list[$i]}"
		if [[ "$pkg" == *"$current_kernel"* ]]; then
			echo -e "  ${GREEN_FONT_PREFIX}[$i] ${pkg} [*当前运行中*]${FONT_COLOR_SUFFIX}"
		else
			echo -e "  [$i] ${pkg}"
		fi
	done
	echo -e "${INFO} ==================================================="
	echo -e "${TIP} 提示: 排序后默认从最高版本内核启动！"
	echo ""
	read -p "请输入要【删除】的内核编号 (多选请用空格分隔，例如 '0 2 3'，直接回车取消): " del_choices

	if [[ -z "$del_choices" ]]; then
		echo -e "${INFO} 已取消操作，返回主菜单。"
		return
	fi

	# 遍历用户输入，提取包名
	local pkgs_to_del=""
	local is_del_current=0
	for idx in $del_choices; do
		if [[ "$idx" =~ ^[0-9]+$ ]] && [[ "$idx" -ge 0 ]] && [[ "$idx" -lt ${#kernel_list[@]} ]]; then
			local selected_pkg="${kernel_list[$idx]}"
			pkgs_to_del="$pkgs_to_del $selected_pkg"
			# 标记是否包含当前内核
			if [[ "$selected_pkg" == *"$current_kernel"* ]]; then
				is_del_current=1
			fi
		else
			echo -e "${TIP} 无效的编号: $idx，已忽略。"
		fi
	done

	if [[ -z "$pkgs_to_del" ]]; then
		echo -e "${INFO} 没有选择有效的内核，操作结束。"
		return
	fi

	# 安全屏障：确保删除后至少还剩一个可引导内核镜像，防止变砖
	local remaining_images=0
	for pkg in "${kernel_list[@]}"; do
		# 仅统计镜像包 (跳过 headers / modules / devel)
		if [[ "${OS_TYPE}" == "Debian" ]]; then
			[[ "$pkg" != linux-image-* ]] && continue
		else
			# CentOS: kernel(-ml|-lt|…)-<版本号> 格式，排除 headers/devel
			[[ ! "$pkg" =~ ^kernel(-ml|-lt|-uek|-rt|-plus)?-[0-9] ]] && continue
		fi
		# 该镜像不在待删除列表中 → 会被保留
		# 用赋值式自增而非 ((remaining_images++))：后者在结果为 0 时返回退出码 1，
		# 将来若启用 set -e 会在此静默中断循环。
		[[ " $pkgs_to_del " != *" $pkg "* ]] && remaining_images=$((remaining_images + 1))
	done
	if [[ $remaining_images -eq 0 ]]; then
		echo -e "${ERROR} 操作已阻止！删除所选包后系统将无任何可引导内核，重启即变砖！"
		echo -e "${TIP} 请至少保留一个可引导内核镜像包。"
		return 1
	fi

	echo -e "${TIP} 即将从系统中彻底卸载以下内核包:"
	echo -e "${RED_FONT_PREFIX}${pkgs_to_del}${FONT_COLOR_SUFFIX}"

	# 强力警告与二次确认机制
	if [[ $is_del_current -eq 1 ]]; then
		echo -e ""
		echo -e "${ERROR} 高危警告！您选择了删除【当前正在运行的内核】！"
		echo -e "${TIP} 卸载当前运行中的内核，可能会导致您的 SSH 连接中断。"
		echo -e "${TIP} 请务必确保系统中还有【至少一个其他已正常安装的内核】，否则重启后机器将变砖失联！"
		read -p "您确定要继续删除选中的内核包吗？(请输入大写的 YES 确认): " confirm_danger
		if [[ "$confirm_danger" != "YES" ]]; then
			echo -e "${INFO} 操作已取消，出于安全考虑未执行删除。"
			return
		fi
	else
		read -p "请确认是否卸载？(Y/n): " confirm
		if [[ "$confirm" =~ ^[nN]$ ]]; then
			echo -e "${INFO} 操作已取消。"
			return
		fi
	fi

	echo -e "${INFO} 正在执行卸载，如果遇到断开连接请不要惊慌，稍等几分钟后尝试重启服务器..."
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		rpm -e --nodeps $pkgs_to_del
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		apt-get purge -y $pkgs_to_del
		apt-get autoremove -y >/dev/null 2>&1
	fi

	BBR_grub
	echo -e "${INFO} 指定内核卸载完毕！引导项已自动更新。"
}

# 编译安装 brutal
startbrutal() {
	# headers_status 由 check_status 填充。在此处主动刷新，
	# 避免依赖菜单循环是否已调用过 check_status 的不确定状态。
	check_status
	if [[ "$headers_status" == "已匹配" ]]; then
		echo -e "${INFO} Headers 已匹配，开始编译 Brutal..."
		# 统一走 fetch_remote_script: 落盘 + 校验 (非空 & 是 shell 脚本) 后再执行，
		# 避免 curl | bash 把 404/劫持页直接喂给 bash 以 root 运行。
		local tmp_brutal
		tmp_brutal=$(mktemp /tmp/brutal.XXXXXX) || return 1
		if ! fetch_remote_script "https://tcp.hy2.sh/" "$tmp_brutal"; then
			rm -f "$tmp_brutal"
			echo -e "${ERROR} Brutal 安装脚本下载失败！"
			return 1
		fi
		bash "$tmp_brutal"
		rm -f "$tmp_brutal"
		if lsmod | grep -q "brutal"; then
			echo -e "${INFO} Brutal 模块已成功加载！"
		else
			echo -e "${ERROR} Brutal 模块未加载，编译可能失败，请查看上方日志。"
		fi
	else
		echo -e "${ERROR} 当前内核 Headers 不匹配或未安装，无法编译 Brutal。"
		echo -e "${TIP} 请先安装对应版本的 Headers (通常随内核包一并安装，也可重新执行安装菜单)。"
	fi
}

# 创建并启用 LotSpeed 开机自启服务。
# 开机时 systemd-sysctl 加载 sysctl.d 时 lotspeed 模块可能尚未 modprobe，
# 那行 tcp_congestion_control=lotspeed 会静默失败并退回 tcpfit 的 bbr。
# 故用一个 oneshot 服务：先 lotspeed start 加载模块，再 sysctl --system 重刷，
# 让 99-zz-tcpx-accel.conf 里的 lotspeed 生效 (排序在 99-tcpfit.conf 之后，稳压其默认)。
setup_lotspeed_boot_service() {
	local lotspeed_bin sysctl_bin
	lotspeed_bin=$(command -v lotspeed 2>/dev/null || echo "/usr/local/bin/lotspeed")
	sysctl_bin=$(command -v sysctl 2>/dev/null || echo "/sbin/sysctl")
	cat >"$LOTSPEED_BOOT_SERVICE" <<EOF
[Unit]
Description=Load LotSpeed and apply congestion control
After=network.target

[Service]
Type=oneshot
ExecStart=${lotspeed_bin} start
ExecStartPost=${sysctl_bin} --system
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload >/dev/null 2>&1
	if systemctl enable --now lotspeed-boot.service >/dev/null 2>&1; then
		echo -e "${INFO} 已启用 LotSpeed 开机自启 (lotspeed-boot.service)，重启后仍为默认算法。"
	else
		echo -e "${TIP} LotSpeed 开机自启服务启用失败 (非 systemd 环境?)，重启后可能需手动 lotspeed start。"
	fi
}

# 安装启用 LotSpeed (uk0开发)
install_lotspeed() {
	echo -e "${INFO} 准备安装并启用 LotSpeed (ml-tcp 分支) ..."
	# 执行官方一键安装脚本 (走 safe_wget 以便国内机可通过镜像获取)
	local tmp_ls
	tmp_ls=$(mktemp /tmp/lotspeed.XXXXXX) || return 1
	if ! fetch_remote_script "https://raw.githubusercontent.com/uk0/lotspeed/ml-tcp/install.sh" "$tmp_ls"; then
		rm -f "$tmp_ls"
		echo -e "${ERROR} LotSpeed 安装脚本下载失败！"
		return 1
	fi
	bash "$tmp_ls"
	rm -f "$tmp_ls"

	if lsmod | grep -q "lotspeed"; then
		echo -e "${INFO} LotSpeed 模块已成功加载！"
		# 将其写入生效优先级最高的文件确保重启后也是默认算法
		local sysctl_conf
		sysctl_conf=$(accel_conf_path)
		sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.d/99-sysctl.conf /etc/sysctl.conf "$TCPX_ACCEL_DROPIN" 2>/dev/null
		echo "net.ipv4.tcp_congestion_control=lotspeed" >>"$sysctl_conf"
		sysctl --system >/dev/null 2>&1
		echo -e "${INFO} LotSpeed 已设置为默认拥塞控制算法！"
		setup_lotspeed_boot_service
		disable_tcpfit_shaper_force
	else
		echo -e "${ERROR} LotSpeed 模块加载失败，请检查上方编译日志（通常是因为内核 Headers 缺失或版本过低）。"
	fi
}

# 单独启用 LotSpeed 加速 (免编译快速切换)
enable_lotspeed_standalone() {
	if ! command -v lotspeed >/dev/null 2>&1; then
		echo -e "${ERROR} 未检测到 LotSpeed，请先执行菜单 [26] 进行编译安装！"
		sleep 3
		return
	fi
	remove_bbr_lotserver
	disable_tcpfit_shaper_force
	echo -e "${INFO} 正在启动 LotSpeed 加速..."
	lotspeed start >/dev/null 2>&1

	# 确保将其写死为默认启动项
	local sysctl_conf
	sysctl_conf=$(accel_conf_path)
	ensure_qdisc_module "fq"
	sed -i '/net.ipv4.tcp_congestion_control/d; /net.core.default_qdisc/d' /etc/sysctl.d/99-sysctl.conf /etc/sysctl.conf "$TCPX_ACCEL_DROPIN" 2>/dev/null
	echo "net.core.default_qdisc=fq" >>"$sysctl_conf"
	echo "net.ipv4.tcp_congestion_control=lotspeed" >>"$sysctl_conf"
	sysctl --system >/dev/null 2>&1

	# remove_bbr_lotserver 已先禁用旧的开机服务，此处按当前 LotSpeed 状态重新启用
	setup_lotspeed_boot_service

	echo -e "${INFO} LotSpeed 加速已成功切换并启用！"
}

# =================================================
#  杂项与附加功能模块 (补齐缺失的函数)
# =================================================

# 通用的远程脚本获取器: 下载到临时文件 -> 校验 -> 交给调用方处理
# 统一走 safe_wget，国内机才能借助镜像拿到 raw.githubusercontent.com 上的内容
fetch_remote_script() {
	local url="$1"
	local dest="$2"

	safe_wget "$url" "$dest" || return 1

	# 校验：非空 + 是 shell 脚本 (防止把 404 页面/运营商劫持页当脚本执行)
	if [[ ! -s "$dest" ]]; then
		echo -e "${ERROR} 下载到的文件为空！"
		return 1
	fi
	if ! head -n 1 "$dest" | grep -qE '^#!.*(bash|sh)'; then
		echo -e "${ERROR} 下载到的内容不是有效的 Shell 脚本 (可能是错误页或被劫持)！"
		return 1
	fi
	return 0
}

# 首次运行自安装：把脚本落地到 /usr/local/bin/tcpx，之后可直接输入 tcpx 运行。
# 兼容两种运行方式：
#   1) 本地文件   (bash tcpx.sh / ./tcpx.sh)        -> 直接复制自身
#   2) 管道/进程替换 (bash <(curl -fsSL <URL>))      -> 本地无副本，需从 TCPX_SELF_URL 重新下载
install_self() {
	local target="$TCPX_INSTALL_PATH"
	local src
	src=$(readlink -f "${BASH_SOURCE[0]:-$0}" 2>/dev/null || echo "${BASH_SOURCE[0]:-$0}")

	# 正在运行的就是安装后的副本，无需再装
	[[ "$src" == "$target" ]] && return 0

	# 目标目录不可写(极少数只读环境)则跳过，不阻断正常使用
	[[ -w "$(dirname "$target")" ]] || return 0

	if [[ -f "$src" && -r "$src" ]]; then
		# 本地文件方式：内容有变化才复制，避免每次运行都写盘
		if [[ ! -f "$target" ]] || ! cmp -s "$src" "$target"; then
			if cp "$src" "$target" 2>/dev/null && chmod +x "$target" 2>/dev/null; then
				echo -e "${INFO} 已安装/更新到 ${target}，之后可直接输入 ${GREEN_FONT_PREFIX}tcpx${FONT_COLOR_SUFFIX} 运行。"
			fi
		fi
		return 0
	fi

	# 管道/进程替换方式：本地没有文件副本，必须从权威地址重新下载
	if [[ -n "$TCPX_SELF_URL" ]]; then
		local tmp
		tmp=$(mktemp /tmp/tcpx_self.XXXXXX) || return 0
		if fetch_remote_script "$TCPX_SELF_URL" "$tmp" >/dev/null 2>&1; then
			if mv -f "$tmp" "$target" 2>/dev/null && chmod +x "$target" 2>/dev/null; then
				echo -e "${INFO} 已安装到 ${target}，之后可直接输入 ${GREEN_FONT_PREFIX}tcpx${FONT_COLOR_SUFFIX} 运行。"
			fi
		else
			rm -f "$tmp"
			echo -e "${TIP} 自安装下载失败(地址不可达或非脚本内容)，本次仍可正常使用菜单。"
		fi
	else
		echo -e "${TIP} 检测到以管道方式运行，但未配置下载地址，无法自安装到 ${target}。"
		echo -e "${TIP} 可用 ${GREEN_FONT_PREFIX}TCPX_URL=<地址> bash <(curl -fsSL <地址>)${FONT_COLOR_SUFFIX} 重新运行以启用自安装。"
	fi
	return 0
}

Update_Shell() {
	echo -e "${INFO} 正在更新脚本..."

	# 关键: 绝不能直接 wget -O 覆盖正在运行的脚本文件。
	# bash 是边读边执行的，覆写自身会导致后续语句从错误的字节偏移继续解析。
	# 正确做法是先下到临时文件、校验通过后再 mv 覆盖，最后 exec 重启。
	local tmp_sh
	tmp_sh=$(mktemp /tmp/tcpx_update.XXXXXX) || {
		echo -e "${ERROR} 无法创建临时文件！"
		return 1
	}

	if ! fetch_remote_script "${GITHUB_RAW_URL}/tcpx.sh" "$tmp_sh"; then
		rm -f "$tmp_sh"
		echo -e "${ERROR} 脚本更新失败，已保留当前版本 (未做任何更改)。"
		return 1
	fi

	# 解析目标位置：优先覆盖当前脚本自身
	local self_path
	self_path=$(readlink -f "$0" 2>/dev/null || echo "$0")
	if [[ ! -w "$(dirname "$self_path")" ]]; then
		echo -e "${TIP} 当前脚本所在目录不可写，将安装到 /root/tcpx.sh"
		self_path="/root/tcpx.sh"
	fi

	local new_ver=$(grep -m1 '^readonly SH_VER=' "$tmp_sh" | cut -d'"' -f2)
	if [[ -n "$new_ver" ]]; then
		if [[ "$new_ver" == "$SH_VER" ]]; then
			echo -e "${INFO} 当前已是最新版本 [v${SH_VER}]，无需更新。"
			rm -f "$tmp_sh"
			return 0
		fi
		echo -e "${INFO} 发现新版本: ${GREEN_FONT_PREFIX}v${new_ver}${FONT_COLOR_SUFFIX} (当前 v${SH_VER})"
	fi

	mv -f "$tmp_sh" "$self_path" || {
		rm -f "$tmp_sh"
		echo -e "${ERROR} 写入 ${self_path} 失败！"
		return 1
	}
	chmod +x "$self_path"

	# 同步安装/刷新到 /usr/local/bin/tcpx，保证升级后可直接输入 tcpx 运行，
	# 不再依赖"旧版本升级后是否会重新执行并触发 install_self"这一不确定链路。
	local reload_path="$self_path"
	if [[ "$self_path" != "$TCPX_INSTALL_PATH" && -w "$(dirname "$TCPX_INSTALL_PATH")" ]]; then
		if cp -f "$self_path" "$TCPX_INSTALL_PATH" 2>/dev/null && chmod +x "$TCPX_INSTALL_PATH" 2>/dev/null; then
			echo -e "${INFO} 已同步安装到 ${GREEN_FONT_PREFIX}${TCPX_INSTALL_PATH}${FONT_COLOR_SUFFIX}，之后可直接输入 ${GREEN_FONT_PREFIX}tcpx${FONT_COLOR_SUFFIX} 运行。"
			# 从安装后的规范路径重载，后续升级即针对 /usr/local/bin/tcpx 生效
			reload_path="$TCPX_INSTALL_PATH"
		fi
	fi

	echo -e "${INFO} 更新完成，正在重新载入脚本..."
	exec bash "$reload_path"
}

gotodd() {
	echo -e "${INFO} 正在切换到一键 DD 系统脚本..."
	local tmp_sh
	tmp_sh=$(mktemp /tmp/reinstall.XXXXXX) || return 1

	if ! fetch_remote_script "https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh" "$tmp_sh"; then
		rm -f "$tmp_sh"
		echo -e "${ERROR} reinstall.sh 下载失败！"
		return 1
	fi
	bash "$tmp_sh"
	rm -f "$tmp_sh"
}

closeipv6() {
	echo -e "${INFO} 正在禁用 IPv6..."
	sed -i '/net.ipv6.conf.all.disable_ipv6/d; /net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf /etc/sysctl.conf 2>/dev/null
	echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.d/99-sysctl.conf
	echo "net.ipv6.conf.default.disable_ipv6 = 1" >>/etc/sysctl.d/99-sysctl.conf
	sysctl --system >/dev/null 2>&1
	echo -e "${INFO} IPv6 已成功禁用！"
}

openipv6() {
	echo -e "${INFO} 正在开启 IPv6..."
	sed -i '/net.ipv6.conf.all.disable_ipv6/d; /net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf /etc/sysctl.conf 2>/dev/null
	echo "net.ipv6.conf.all.disable_ipv6 = 0" >>/etc/sysctl.d/99-sysctl.conf
	echo "net.ipv6.conf.default.disable_ipv6 = 0" >>/etc/sysctl.d/99-sysctl.conf
	sysctl --system >/dev/null 2>&1
	echo -e "${INFO} IPv6 已成功开启！"
}

optimizing_ddcc() {
	echo -e "${INFO} 正在应用防 CC/DDOS 轻量优化..."
	local sysctl_conf="/etc/sysctl.d/99-sysctl.conf"
	sed -i '/net.ipv4.tcp_syncookies/d; /net.ipv4.tcp_max_syn_backlog/d; /net.ipv4.tcp_synack_retries/d' "$sysctl_conf" 2>/dev/null
	cat >>"$sysctl_conf" <<EOF
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024000
net.ipv4.tcp_synack_retries = 1
EOF
	sysctl --system >/dev/null 2>&1
	echo -e "${INFO} 防 CC 基础参数已写入并生效！"
}

# 调起 tcpfit 进行网络精调 (自适应 BDP/内存的独立工具)
# 按要求：菜单 [60] 直接从上游一键运行 tcpfit，不做任何检测或提示。
# 注意: 此处走原生 curl 直连，未使用脚本内的镜像/落盘校验逻辑；
#       国内网络若无法直连 raw.githubusercontent.com 可能失败。
run_tcpfit_tune() {
	echo -e "${INFO} 正在调起 tcpfit 进行网络精调..."
	bash <(curl -fsSL https://raw.githubusercontent.com/Kylin010/tcpfit/main/tcpfit.sh)
}

# =================================================
#  UI 面板与主逻辑
# =================================================

# 获取系统面板信息
get_system_info() {
	opsy="${OS_TYPE} ${OS_VERSION_ID}"
	arch="${OS_ARCH}"
	kern=$(uname -r)

	# 获取虚拟化类型
	if command -v virt-what >/dev/null 2>&1; then
		virtual=$(virt-what | head -n 1)
	elif command -v systemd-detect-virt >/dev/null 2>&1; then
		virtual=$(systemd-detect-virt)
	else
		virtual="Unknown"
	fi
	[[ -z "$virtual" ]] && virtual="Dedicated"
}

# 开始菜单
# 绘制菜单与状态面板 (不含读取输入，便于循环复用)
show_menu_panel() {
	clear
	echo && echo -e " TCP加速 一键安装管理脚本 ${RED_FONT_PREFIX}[v${SH_VER}] 不卸内核${FONT_COLOR_SUFFIX} from blog.ylx.me 母鸡慎用
 ${GREEN_FONT_PREFIX}0.${FONT_COLOR_SUFFIX} 升级脚本
 ———————————————————————————— 内核安装 —————————————————————————————
 ${GREEN_FONT_PREFIX}1.${FONT_COLOR_SUFFIX} 安装 BBR自编编译内核     ${GREEN_FONT_PREFIX}7.${FONT_COLOR_SUFFIX} 安装 官方稳定内核
 ${GREEN_FONT_PREFIX}2.${FONT_COLOR_SUFFIX} 安装 BBRplus版内核       ${GREEN_FONT_PREFIX}8.${FONT_COLOR_SUFFIX} 安装 官方最新内核
 ${GREEN_FONT_PREFIX}3.${FONT_COLOR_SUFFIX} 安装 Lotserver(锐速)内核 ${GREEN_FONT_PREFIX}9.${FONT_COLOR_SUFFIX} 安装 XANMOD(main)
 ${GREEN_FONT_PREFIX}4.${FONT_COLOR_SUFFIX} 安装 官方cloud内核       ${GREEN_FONT_PREFIX}10.${FONT_COLOR_SUFFIX} 安装 XANMOD(LTS)
 ${GREEN_FONT_PREFIX}5.${FONT_COLOR_SUFFIX} 安装 BBRplus新版内核     ${GREEN_FONT_PREFIX}11.${FONT_COLOR_SUFFIX} 安装 XANMOD(EDGE)
 ${GREEN_FONT_PREFIX}6.${FONT_COLOR_SUFFIX} 安装 Zen官方版内核       ${GREEN_FONT_PREFIX}12.${FONT_COLOR_SUFFIX} 安装 XANMOD(RT)
 ———————————————————————————— 加速启用 —————————————————————————————
 ${GREEN_FONT_PREFIX}20.${FONT_COLOR_SUFFIX} 使用BBR+FQ加速          ${GREEN_FONT_PREFIX}21.${FONT_COLOR_SUFFIX} 使用BBR+FQ_PIE加速
 ${GREEN_FONT_PREFIX}22.${FONT_COLOR_SUFFIX} 使用BBR+CAKE加速        ${GREEN_FONT_PREFIX}23.${FONT_COLOR_SUFFIX} 使用BBRplus+FQ版加速
 ${GREEN_FONT_PREFIX}24.${FONT_COLOR_SUFFIX} 使用Lotserver(锐速)加速 ${GREEN_FONT_PREFIX}25.${FONT_COLOR_SUFFIX} 编译安装brutal模块
 ${GREEN_FONT_PREFIX}26.${FONT_COLOR_SUFFIX} 编译安装LotSpeed模块    ${GREEN_FONT_PREFIX}27.${FONT_COLOR_SUFFIX} 使用LotSpeed加速
 ———————————————————————————— 系统配置 —————————————————————————————
 ${GREEN_FONT_PREFIX}30.${FONT_COLOR_SUFFIX} 开启ECN                 ${GREEN_FONT_PREFIX}31.${FONT_COLOR_SUFFIX} 关闭ECN
 ${GREEN_FONT_PREFIX}32.${FONT_COLOR_SUFFIX} 系统网络自适应优化      ${GREEN_FONT_PREFIX}33.${FONT_COLOR_SUFFIX} 防CC/DDOS轻量优化
 ${GREEN_FONT_PREFIX}35.${FONT_COLOR_SUFFIX} 禁用IPv6                ${GREEN_FONT_PREFIX}36.${FONT_COLOR_SUFFIX} 开启IPv6
 ${GREEN_FONT_PREFIX}37.${FONT_COLOR_SUFFIX} 手动提交合并内核参数    ${GREEN_FONT_PREFIX}38.${FONT_COLOR_SUFFIX} 手动编辑内核参数
 ———————————————————————————— 内核管理 —————————————————————————————
 ${GREEN_FONT_PREFIX}51.${FONT_COLOR_SUFFIX} 查看排序内核            ${GREEN_FONT_PREFIX}52.${FONT_COLOR_SUFFIX} 删除保留指定内核
 ${GREEN_FONT_PREFIX}55.${FONT_COLOR_SUFFIX} 卸载全部加速            ${GREEN_FONT_PREFIX}99.${FONT_COLOR_SUFFIX} 退出脚本
 ———————————————————————————— 其它工具 —————————————————————————————
 ${GREEN_FONT_PREFIX}60.${FONT_COLOR_SUFFIX} 网络精调(tcpfit联动)    ${GREEN_FONT_PREFIX}92.${FONT_COLOR_SUFFIX} 一键DD重装系统
————————————————————————————————————————————————————————————————"
	check_status
	get_system_info
	echo -e " 信息： ${FONT_COLOR_SUFFIX}$opsy ${GREEN_FONT_PREFIX}$virtual${FONT_COLOR_SUFFIX} $arch ${GREEN_FONT_PREFIX}$kern${FONT_COLOR_SUFFIX} "
	if [[ ${kernel_status} == "noinstall" ]]; then
		echo -e " 状态: ${GREEN_FONT_PREFIX}未安装${FONT_COLOR_SUFFIX} 加速内核 ${RED_FONT_PREFIX}请先安装内核${FONT_COLOR_SUFFIX}"
	else
		echo -e " 状态: ${GREEN_FONT_PREFIX}已安装${FONT_COLOR_SUFFIX} ${RED_FONT_PREFIX}${kernel_status}${FONT_COLOR_SUFFIX} 加速内核 , ${GREEN_FONT_PREFIX}${run_status}${FONT_COLOR_SUFFIX} ${RED_FONT_PREFIX}${brutal}${FONT_COLOR_SUFFIX} ${RED_FONT_PREFIX}${lotspeed_status}${FONT_COLOR_SUFFIX}"
	fi
	echo -e " 拥塞控制算法: ${GREEN_FONT_PREFIX}${net_congestion_control}${FONT_COLOR_SUFFIX} 队列算法: ${GREEN_FONT_PREFIX}${net_qdisc}${FONT_COLOR_SUFFIX} Headers状态：${GREEN_FONT_PREFIX}${headers_status}${FONT_COLOR_SUFFIX}"
	if tcpfit_present; then
		echo -e " ${YELLOW_FONT_PREFIX}检测到 tcpfit 正在管理网络参数${FONT_COLOR_SUFFIX}: 菜单 [60] 可调起 tcpfit，[32] 会让路，切算法自动抢优先级"
	fi
}

# 开始菜单 (改为循环驱动)
# 原实现里各功能函数末尾靠递归调用 start_menu 回到菜单，存在两个问题:
#   1) 递归会不断累积调用栈，且大多数分支根本没有递归，执行完就直接退出脚本；
#   2) 安装函数里的 exit 会连带杀掉整个交互式脚本。
# 现统一由本循环驱动，功能函数只需 return。
start_menu() {
	while true; do
		show_menu_panel

		# 用 read 的返回值捕获 EOF (Ctrl-D)，否则会陷入空输入死循环
		if ! read -rp " 请输入数字 :" num; then
			echo ""
			echo -e "${INFO} 已退出。"
			exit 0
		fi

		case "$num" in
		0) Update_Shell ;;
		1) installbbr ;;
		2) installbbrplus ;;
		3) installlot ;;
		4) installcloud ;;
		5) installbbrplusnew ;;
		6) check_sys_official_zen ;;
		7) check_sys_official ;;
		8) check_sys_official_bbr ;;
		9) check_sys_official_xanmod_main ;;
		10) check_sys_official_xanmod_lts ;;
		11) check_sys_official_xanmod_edge ;;
		12) check_sys_official_xanmod_rt ;;
		20) enable_acceleration "fq" "bbr" ;;
		21) enable_acceleration "fq_pie" "bbr" ;;
		22) enable_acceleration "cake" "bbr" ;;
		23) enable_acceleration "fq" "bbrplus" ;;
		24) startlotserver ;;
		25) startbrutal ;;
		26) install_lotspeed ;;
		27) enable_lotspeed_standalone ;;
		30) set_ecn "1" ;;
		31) set_ecn "0" ;;
		32) optimizing_system ;;
		33) optimizing_ddcc ;;
		35) closeipv6 ;;
		36) openipv6 ;;
		37) update_sysctl_interactive ;;
		38) edit_sysctl_interactive ;;
		51) show_kernels ;;
		52) delete_kernel_custom ;;
		55) remove_all ;;
		60) run_tcpfit_tune ;;
		92) gotodd ;;
		99)
			echo -e "${INFO} 已退出。"
			exit 0
			;;
		*)
			echo -e "${ERROR}: 请输入正确数字"
			;;
		esac

		# 统一在此暂停，让用户看清上面命令的输出后再刷新菜单
		echo ""
		read -rp "按回车键返回主菜单..." _ || exit 0
	done
}

#-----------------------------------------------------------------------
# 函数: update_sysctl_interactive (V4 - 增加错误忽略参数)
# 功能: 以交互方式安全地更新 sysctl 配置文件并应用。
#       命令执行失败时，将不会回滚文件更改。
#-----------------------------------------------------------------------
update_sysctl_interactive() {
	# 强制使用C语言环境，确保正则表达式的行为可预测且一致。
	# 注意: 必须 export，否则 sed/grep/sysctl 等子进程根本看不到这个变量，
	# 仅 local 声明等于完全没生效。
	local LC_ALL=C
	export LC_ALL

	# --- 配置与参数解析 ---
	local CONF_FILE="/etc/sysctl.d/99-sysctl.conf"
	local TMP_FILE
	local BACKUP_FILE
	local ignore_apply_error=true

	# --- 帮助函数 (仅本函数内部使用，退出前会 unset 以免污染全局命名空间) ---
	log_info() {
		echo "[INFO] $1"
	}

	log_error() {
		echo "[ERROR] $1" >&2
	}

	log_warn() {
		echo "[WARN] $1" >&2
	}

	# 函数返回时清理这三个临时函数定义
	trap 'unset -f log_info log_error log_warn 2>/dev/null' RETURN

	# --- 主逻辑 ---

	# 1. 权限检查
	if [[ $EUID -ne 0 ]]; then
		log_error "此函数必须以 root 权限运行，请使用 sudo。"
		return 1
	fi

	# 2. 交互式获取用户输入
	log_info "请输入或粘贴您要设置的 sysctl 参数 (格式: key = value)。"
	log_info "可参考TCP迷之调参，https://omnitt.com/"
	log_info "注释行(以 # 或 ; 开头)和空行将被忽略。"
	log_info "最后一行请以空行结束 可手动回车加一行空行"
	log_info "输入完成后，请按 Ctrl+D 结束输入。"

	readarray -t user_input

	if [ ${#user_input[@]} -eq 0 ]; then
		log_info "没有接收到任何输入，操作已取消。"
		return 0
	fi

	# 确保配置文件存在
	touch "$CONF_FILE"

	# 3. 创建临时文件
	TMP_FILE=$(mktemp) || {
		log_error "无法创建临时文件"
		return 1
	}
	# 覆盖上面的 RETURN trap，追加临时文件清理 (bash 每个信号只保留一个 trap)
	trap 'rm -f "$TMP_FILE"; unset -f log_info log_error log_warn 2>/dev/null' RETURN

	cp "$CONF_FILE" "$TMP_FILE"

	local -A params_to_add
	local all_params_valid=true

	# 4. 预处理所有输入，检查合法性
	log_info "正在校验所有输入参数..."
	for line in "${user_input[@]}"; do
		trimmed_line=$(echo "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

		if [[ -z "$trimmed_line" ]] || [[ "$trimmed_line" =~ ^[[:space:]]*[#\;] ]]; then
			continue
		fi

		if ! [[ "$trimmed_line" =~ ^[[:space:]]*([a-zA-Z0-9._-]+)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]]; then
			log_error "格式无效: '$trimmed_line'. 期望格式为 'key = value'."
			all_params_valid=false
			continue
		fi

		local key="${BASH_REMATCH[1]}"
		local value="${BASH_REMATCH[2]}"

		if ! sysctl -N "$key" >/dev/null 2>&1; then
			log_error "参数键名无效: '$key' 不是一个有效的内核参数。"
			all_params_valid=false
			continue
		fi

		local formatted_param="$key = $value"

		if grep -q -E "^[[:space:]]*${key//./\\.}([[:space:]]*)=.*" "$TMP_FILE"; then
			sed -i -E "s|^[[:space:]]*${key//./\\.}([[:space:]]*)=.*|$formatted_param|" "$TMP_FILE"
			log_info "已更新参数: $formatted_param"
		else
			if [[ -z "${params_to_add[$key]}" ]]; then
				params_to_add["$key"]="$formatted_param"
			fi
		fi
	done

	if ! $all_params_valid; then
		log_error "检测到无效参数，操作已中止。配置文件未做任何更改。"
		return 1
	fi

	# 5. 将所有新参数追加到临时文件末尾
	if [ ${#params_to_add[@]} -gt 0 ]; then
		log_info "正在添加新参数..."
		echo "" >>"$TMP_FILE"
		for key in "${!params_to_add[@]}"; do
			echo "${params_to_add[$key]}" >>"$TMP_FILE"
			log_info "已添加新参数: ${params_to_add[$key]}"
		done
	fi

	# 6. 原子替换与应用
	BACKUP_FILE="${CONF_FILE}.bak_$(date +%Y%m%d_%H%M%S)"
	cp "$CONF_FILE" "$BACKUP_FILE"
	log_info "原始文件已备份到 $BACKUP_FILE"

	mv "$TMP_FILE" "$CONF_FILE"
	chown root:root "$CONF_FILE"
	chmod 644 "$CONF_FILE"
	# TMP_FILE 已被 mv 走，无需再清理，但仍需在返回时收回临时函数定义
	trap 'unset -f log_info log_error log_warn 2>/dev/null' RETURN

	# 7. 应用配置并进行错误处理
	log_info "正在应用新的 sysctl 设置..."
	# 与脚本其余部分统一使用 sysctl --system，按 /etc/sysctl.d/ 的优先级顺序
	# 加载全部配置文件，得到与重启后一致的最终合并结果。
	if apply_output=$(sysctl --system 2>&1); then
		log_info "Sysctl 设置已成功应用。"
		echo "--- 应用输出 ---"
		echo "$apply_output"
		echo "------------------"
		rm -f "$BACKUP_FILE"
	else
		# 应用失败时的逻辑
		if [[ "$ignore_apply_error" == "true" ]]; then
			log_warn "应用 sysctl 设置失败，但根据指令已忽略错误。"
			log_warn "配置文件 '${CONF_FILE}' 已被更新，但部分设置可能未生效。"
			log_warn "--- 错误详情 ---"
			echo "$apply_output" >&2
			echo "------------------"
			rm -f "$BACKUP_FILE" # 忽略错误，所以也删除备份
			return 0             # 返回成功状态
		else
			log_error "应用 sysctl 设置失败！正在回滚..."
			log_error "--- 错误详情 ---"
			echo "$apply_output"
			echo "------------------"

			mv "$BACKUP_FILE" "$CONF_FILE"
			log_info "正在恢复到之前的设置..."
			sysctl --system >/dev/null 2>&1

			log_error "回滚完成。配置文件已恢复，问题备份文件保留在 $BACKUP_FILE"
			return 1
		fi
	fi

	return 0
}

edit_sysctl_interactive() {
	local target_file="/etc/sysctl.d/99-sysctl.conf"
	local editor_cmd=""

	# --- 1. 检查文件是否存在 ---
	if [[ ! -f "$target_file" ]]; then
		echo -e "${TIP} 文件 $target_file 不存在。"
		read -r -p "是否立即创建并编辑？ (Y/n): " create_choice
		case "$create_choice" in
		[nN])
			echo -e "${INFO} 操作已取消。"
			return 0
			;;
		*) ;;
		esac
	fi

	# --- 2. 按优先级选择编辑器: $VISUAL → $EDITOR → nano → vi ---
	# 脚本要求 root 运行，此处无需 sudo。
	if [[ -n "${VISUAL:-}" ]] && command -v "$VISUAL" >/dev/null 2>&1; then
		editor_cmd="$VISUAL"
	elif [[ -n "${EDITOR:-}" ]] && command -v "$EDITOR" >/dev/null 2>&1; then
		editor_cmd="$EDITOR"
	elif command -v nano >/dev/null 2>&1; then
		editor_cmd="nano"
	elif command -v vi >/dev/null 2>&1; then
		editor_cmd="vi"
		echo -e "${TIP} 将使用 vi 编辑器。按 'i' 进入插入模式，'Esc' 退出插入模式，':wq' 保存，':q!' 放弃。"
	else
		echo -e "${ERROR} 未找到可用文本编辑器 (nano / vi)，请先安装:"
		if [[ "${OS_TYPE}" == "CentOS" ]]; then
			echo -e "  yum install -y nano"
		else
			echo -e "  apt-get install -y nano"
		fi
		return 1
	fi

	# --- 3. 执行编辑 ---
	echo -e "${INFO} 使用 [${editor_cmd}] 打开 ${target_file}..."
	if ! "$editor_cmd" "$target_file"; then
		echo -e "${ERROR} 编辑器启动失败或异常退出。"
		return 1
	fi

	# --- 4. 应用新配置 ---
	echo ""
	echo -e "${INFO} 正在应用新配置..."
	# sysctl --system 加载 /etc/sysctl.d/ 全部文件，比 sysctl -p 单文件更完整
	sysctl --system >/dev/null 2>&1
	echo -e "${INFO} 内核参数已重载。部分参数需重启后才能生效。"
}

# =================================================
#  官方源内核安装模块 (包含 CentOS 10 战未来支持)
# =================================================

#检查官方稳定内核并安装
check_sys_official() {
	pre_install_check || return 1
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		[[ "${OS_ARCH}" != "x86_64" ]] && {
			echo -e "${ERROR} 不支持x86_64以外的系统 !"
			return 1
		}
		if [[ "${OS_VERSION_ID}" == "7" ]]; then
			yum install kernel kernel-headers -y --skip-broken
		elif [[ "${OS_VERSION_ID}" == "8" || "${OS_VERSION_ID}" == "9" || "${OS_VERSION_ID}" == "10" ]]; then
			# CentOS 8、9、10 都是同样的包结构
			yum install kernel kernel-core kernel-headers -y --skip-broken
		else
			echo -e "${ERROR} 不支持当前系统 CentOS ${OS_VERSION_ID} !" && return 1
		fi
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		apt update
		if [[ "${OS_ID}" == "ubuntu" || "${OS_ID}" == "pop" || "${OS_ID_LIKE}" == *"ubuntu"* ]]; then
			# Ubuntu 及衍生版 (如 Mint) 使用 generic 命名
			apt-get install linux-image-generic linux-headers-generic -y
		else
			# Debian 及衍生版 (如 Kali, Armbian) 使用 amd64/arm64 命名
			if [[ "${OS_ARCH}" == "x86_64" ]]; then
				apt-get install linux-image-amd64 linux-headers-amd64 -y
			elif [[ "${OS_ARCH}" == "aarch64" ]]; then
				apt-get install linux-image-arm64 linux-headers-arm64 -y
			fi
		fi
	fi
	BBR_grub
	echo -e "${TIP} 内核安装完毕。"
}

#检查官方最新内核并安装 (ELRepo / Backports / HWE)
check_sys_official_bbr() {
	pre_install_check || return 1
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		[[ "${OS_ARCH}" != "x86_64" ]] && {
			echo -e "${ERROR} 不支持x86_64以外的系统 !"
			return 1
		}
		rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
		if [[ "${OS_VERSION_ID}" == "7" ]]; then
			yum install https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm -y
			yum --enablerepo=elrepo-kernel install kernel-ml kernel-ml-headers -y --skip-broken
		elif [[ "${OS_VERSION_ID}" == "8" ]]; then
			yum install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm -y
			yum --enablerepo=elrepo-kernel install kernel-ml kernel-ml-headers -y --skip-broken
		elif [[ "${OS_VERSION_ID}" == "9" ]]; then
			yum install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm -y
			yum --enablerepo=elrepo-kernel install kernel-ml kernel-ml-headers -y --skip-broken
		elif [[ "${OS_VERSION_ID}" == "10" ]]; then
			yum install https://www.elrepo.org/elrepo-release-10.el10.elrepo.noarch.rpm -y
			yum --enablerepo=elrepo-kernel install kernel-ml kernel-ml-headers -y --skip-broken
		else
			echo -e "${ERROR} 不支持当前系统 CentOS ${OS_VERSION_ID} !" && return 1
		fi
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		apt update
		if [[ "${OS_ID}" == "ubuntu" || "${OS_ID}" == "pop" || "${OS_ID_LIKE}" == *"ubuntu"* ]]; then
			# Ubuntu 及衍生版安装官方最新内核 (HWE - 硬件使能内核)
			echo -e "${INFO} 正在为 Ubuntu/衍生系 获取官方最新 HWE 内核..."
			if apt-cache show linux-generic-hwe-${OS_VERSION_ID} >/dev/null 2>&1; then
				apt-get install --install-recommends linux-generic-hwe-${OS_VERSION_ID} -y
			else
				echo -e "${TIP} 当前版本 (${OS_VERSION_ID}) 无专属 HWE 包，将自动为您更新至常规最新 generic 内核..."
				apt-get install linux-image-generic linux-headers-generic -y
			fi
		else
			# Debian 及衍生版 (如 Kali, Deepin)
			local apt_args=""
			# 仅为纯净 Debian 添加 Backports 源，避免搞坏 Kali 的滚动源
			if [[ "${OS_ID}" == "debian" ]]; then
				# 原生读取 os-release，彻底摆脱 lsb_release 依赖
				local codename=$(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release | tr -d '"')
				[[ -z "$codename" ]] && codename=$(awk -F= '/^VERSION=/{print $2}' /etc/os-release | grep -oP '(?<=\().*(?=\))')

				[[ -z "$codename" ]] && {
					echo -e "${ERROR} 无法获取 Debian 代号"
					return 1
				}
				echo "deb http://deb.debian.org/debian ${codename}-backports main" >/etc/apt/sources.list.d/${codename}-backports.list
				apt update
				apt_args="-t ${codename}-backports"
			else
				echo -e "${TIP} 检测到 ${OS_ID} (非原生 Debian)，跳过添加 Backports 源，直接从默认源安装最新内核..."
			fi

			if [[ "${OS_ARCH}" == "x86_64" ]]; then
				apt $apt_args install linux-image-amd64 linux-headers-amd64 -y
			elif [[ "${OS_ARCH}" =~ ^(arm|aarch64)$ ]]; then
				apt $apt_args install linux-image-arm64 linux-headers-arm64 -y
			fi
		fi
	fi
	BBR_grub
	echo -e "${TIP} 内核安装完毕。"
}

# 统一 Xanmod 安装引擎
install_xanmod_generic() {
	local edition="$1" # main, lts, edge, rt
	pre_install_check || return 1
	[[ "${OS_ARCH}" != "x86_64" ]] && {
		echo -e "${ERROR} Xanmod 仅支持 x86_64 !"
		return 1
	}
	[[ "${OS_TYPE}" != "Debian" ]] && {
		echo -e "${ERROR} 当前一键 Xanmod 仅支持 Debian/Ubuntu !"
		return 1
	}

	apt update
	apt-get install gnupg gnupg2 gnupg1 wget -y

	# 清除可能存在的旧版或重复源 (兼容 PR 提到的 .sources 与冲突问题)
	rm -f /etc/apt/sources.list.d/xanmod-kernel.list
	rm -f /etc/apt/sources.list.d/xanmod-release.list
	rm -f /etc/apt/sources.list.d/xanmod-kernel.sources
	sed -i '/deb.xanmod.org/d' /etc/apt/sources.list 2>/dev/null

	# 使用现代化的 signed-by 格式写入 GPG 密钥与源，彻底消除 apt 警告
	wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg
	echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-kernel.list

	# 在临时目录下载并运行 CPU 支持等级检测脚本，避免污染调用方 CWD
	local xanmod_work
	xanmod_work=$(mktemp -d /tmp/xanmod_install.XXXXXX) || {
		echo -e "${ERROR} 无法创建临时目录！"
		return 1
	}
	trap 'cd /tmp; rm -rf "$xanmod_work"; trap - RETURN' RETURN
	cd "$xanmod_work" || {
		echo -e "${ERROR} 无法进入临时目录！"
		return 1
	}

	local cpu_level="1"
	if wget -qO check_x86-64_psabi.sh https://dl.xanmod.org/check_x86-64_psabi.sh 2>/dev/null &&
		[[ -s check_x86-64_psabi.sh ]]; then
		chmod +x check_x86-64_psabi.sh
		# 输出示例 "Your CPU supports x86-64-v3"；提取最后出现的 v1-v4 数字
		cpu_level=$(./check_x86-64_psabi.sh 2>/dev/null |
			grep -oE '\bv[1-4]\b' | tail -n 1 | tr -d 'v')
		[[ -z "$cpu_level" ]] && cpu_level="1"
	else
		echo -e "${TIP} CPU 等级检测脚本下载失败，将使用 v1 (最兼容) 版本。"
	fi
	echo -e "${INFO} CPU 支持等级: \033[32mv${cpu_level}\033[0m"

	apt update
	local pkg_name="linux-xanmod"
	[[ "$edition" != "main" ]] && pkg_name="linux-xanmod-${edition}"

	if [[ "$cpu_level" -ge 3 ]]; then
		apt install "${pkg_name}-x64v3" -y
	elif [[ "$cpu_level" -ge 2 ]]; then
		apt install "${pkg_name}-x64v2" -y
	else
		apt install "${pkg_name}-x64v1" -y
	fi

	BBR_grub
	echo -e "${TIP} 内核安装完毕。"
}

check_sys_official_xanmod_main() { install_xanmod_generic "main"; }
check_sys_official_xanmod_lts() { install_xanmod_generic "lts"; }
check_sys_official_xanmod_edge() { install_xanmod_generic "edge"; }
check_sys_official_xanmod_rt() { install_xanmod_generic "rt"; }

#检查Zen官方内核并安装
check_sys_official_zen() {
	pre_install_check || return 1
	[[ "${OS_ARCH}" != "x86_64" ]] && {
		echo -e "${ERROR} Zen内核仅支持x86_64 !"
		return 1
	}
	if [[ "${OS_ID}" == "debian" || "${OS_ID}" == "kali" || "${OS_ID_LIKE}" == *"debian"* ]] && [[ "${OS_ID_LIKE}" != *"ubuntu"* && "${OS_ID}" != "ubuntu" && "${OS_ID}" != "pop" ]]; then
		# 落盘校验后再执行 Liquorix 加源脚本，避免 curl | bash
		local tmp_lqx
		tmp_lqx=$(mktemp /tmp/liquorix.XXXXXX) || return 1
		if ! fetch_remote_script "https://liquorix.net/add-liquorix-repo.sh" "$tmp_lqx"; then
			rm -f "$tmp_lqx"
			echo -e "${ERROR} Liquorix 源脚本下载失败！"
			return 1
		fi
		bash "$tmp_lqx"
		rm -f "$tmp_lqx"
		apt-get install linux-image-liquorix-amd64 linux-headers-liquorix-amd64 -y
	elif [[ "${OS_ID}" == "ubuntu" || "${OS_ID}" == "pop" || "${OS_ID_LIKE}" == *"ubuntu"* ]]; then
		apt-get install software-properties-common -y
		add-apt-repository ppa:damentz/liquorix -y && apt-get update
		apt-get install linux-image-liquorix-amd64 linux-headers-liquorix-amd64 -y
	else
		echo -e "${ERROR} Zen内核当前脚本仅支持 Debian/Ubuntu 及衍生版 !" && return 1
	fi
	BBR_grub
	echo -e "${TIP} 内核安装完毕。"
}

#检查系统当前状态
check_status() {
	# 初始化变量，避免重复读取文件
	kernel_version=$(uname -r | awk -F "-" '{print $1}')
	kernel_version_full=$(uname -r)
	net_congestion_control=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "unknown")
	net_qdisc=$(cat /proc/sys/net/core/default_qdisc 2>/dev/null || echo "unknown")

	# 检测内核类型
	if [[ "$kernel_version_full" == *bbrplus* ]]; then
		kernel_status="BBRplus"
	elif [[ "$kernel_version_full" =~ (4\.9\.0-4|4\.15\.0-30|4\.8\.0-36|3\.16\.0-77|3\.16\.0-4|3\.2\.0-4|4\.11\.2-1|2\.6\.32-504|4\.4\.0-47|3\.13\.0-29) ]]; then
		kernel_status="Lotserver"
	elif read major minor <<<$(echo "$kernel_version" | awk -F'.' '{print $1, $2}') &&
		{ [[ "$major" == "4" && "$minor" -ge 9 ]] || [[ "$major" -ge 5 ]]; }; then
		kernel_status="BBR"
	else
		kernel_status="noinstall"
	fi

	# 运行状态检测
	if [[ "$kernel_status" == "BBR" ]]; then
		case "$net_congestion_control" in
		"bbr")
			run_status="BBR启动成功"
			;;
		"bbr2")
			run_status="BBR2启动成功"
			;;
		"tsunami")
			if lsmod | grep -q "^tcp_tsunami"; then
				run_status="BBR魔改版启动成功"
			else
				run_status="BBR魔改版启动失败"
			fi
			;;
		"nanqinlang")
			if lsmod | grep -q "^tcp_nanqinlang"; then
				run_status="暴力BBR魔改版启动成功"
			else
				run_status="暴力BBR魔改版启动失败"
			fi
			;;
		*)
			run_status="未安装加速模块"
			;;
		esac
	elif [[ "$kernel_status" == "Lotserver" ]]; then
		if [[ -e /appex/bin/lotServer.sh ]]; then
			run_status=$(bash /appex/bin/lotServer.sh status | grep "LotServer" | awk '{print $3}')
			[[ "$run_status" == "running!" ]] && run_status="启动成功" || run_status="启动失败"
		else
			run_status="未安装加速模块"
		fi
	elif [[ "$kernel_status" == "BBRplus" ]]; then
		case "$net_congestion_control" in
		"bbrplus")
			run_status="BBRplus启动成功"
			;;
		"bbr")
			run_status="BBR启动成功"
			;;
		*)
			run_status="未安装加速模块"
			;;
		esac
	else
		run_status="未安装加速模块"
	fi

	# 检查 Headers 状态 (利用全局 OS_TYPE)
	if [[ "${OS_TYPE}" == "CentOS" ]]; then
		installed_headers=$(rpm -qa | grep -E "kernel(-ml|-lt|-uek|-rt|-plus)?-(devel|headers)" | grep -v '^$' || echo "")
		if [[ -z "$installed_headers" ]]; then
			headers_status="未安装"
		else
			if echo "$installed_headers" | grep -q -E "kernel(-ml|-lt|-uek|-rt|-plus)?-(devel|headers)-${kernel_version_full}"; then
				headers_status="已匹配"
			else
				headers_status="未匹配"
			fi
		fi
	elif [[ "${OS_TYPE}" == "Debian" ]]; then
		installed_headers=$(dpkg -l | grep -E "(linux|proxmox|pve|raspberrypi)-(headers|image)" | awk '{print $2}' | grep -v '^$' || echo "")
		if [[ -z "$installed_headers" ]]; then
			headers_status="未安装"
		else
			if echo "$installed_headers" | grep -q -E "(linux|proxmox|pve|raspberrypi)-headers-${kernel_version_full}"; then
				headers_status="已匹配"
			else
				headers_status="未匹配"
			fi
		fi
	else
		headers_status="不支持的操作系统"
	fi

	# Brutal 状态检测
	brutal=""
	if lsmod | grep -q "brutal"; then
		brutal="brutal已加载"
	fi

	# 新增：LotSpeed 状态检测
	lotspeed_status=""
	if lsmod | grep -q "lotspeed"; then
		if [[ "$net_congestion_control" == "lotspeed" ]]; then
			run_status="LotSpeed启动成功" # 直接覆盖掉上面错误的“未安装”提示
		else
			lotspeed_status="LotSpeed已加载(未设为默认)"
		fi
	fi
}

#############系统检测组件#############
# =================================================
#  入口执行逻辑
# =================================================

# 系统检测与镜像测速 (两种入口共用，只跑一次)
check_sys
check_cn_status

# 首次运行时自安装到 /usr/local/bin/tcpx (支持 bash <(curl -fsSL ...) 管道方式)
install_self

# 命令行静默调用参数解析 (免菜单执行)
if [ $# -gt 0 ]; then
	case $1 in
	op0 | op1 | op2)
		# 兼容老指令，重定向到自适应新版优化
		optimizing_system
		exit
		;;
	op3)
		update_sysctl_interactive
		exit
		;;
	op4)
		edit_sysctl_interactive
		exit
		;;
	*)
		echo -e "${ERROR} 未知选项: \"$1\""
		exit 1
		;;
	esac
fi

# 常规交互式启动
start_menu
