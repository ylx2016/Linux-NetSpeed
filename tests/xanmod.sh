#!/usr/bin/env bash
set -eu

# 只允许在只读宿主文件系统、独立 APT/keyring/tmp 和断网环境中运行安装流程。
test_script=$(readlink -f "${BASH_SOURCE[0]}")
if [[ "${1:-}" != "--sandbox" ]]; then
	command -v bwrap >/dev/null || { echo '测试需要 bubblewrap'; exit 1; }
	exec bwrap --ro-bind / / --dev /dev --tmpfs /tmp --tmpfs /etc/apt \
		--tmpfs /usr/share/keyrings --unshare-net --die-with-parent \
		bash "$test_script" --sandbox
fi

source "$(dirname "$test_script")/../tcpx.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
mkdir -p /etc/apt/sources.list.d

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { grep -qF -- "$2" "$1" || fail "$1 缺少 $2"; }
assert_absent() { if grep -qF -- "$2" "$1"; then fail "$1 不应包含 $2"; fi; }

test_suite() (
	local fixture="$test_dir/os-release" actual
	printf '%s\n' "$1" >"$fixture"
	printf '%s\n' "${4:-13.0}" >"$test_dir/debian_version"
	local supported="$3"
	curl() { [[ "${*: -1}" == "https://deb.xanmod.org/dists/${supported}/Release" ]]; }
	actual=$(resolve_xanmod_suite "$fixture" "$test_dir/debian_version") || fail 'suite 解析失败'
	[[ "$actual" == "$2" ]] || fail "suite=$actual，预期 $2"
)

test_suite $'ID=debian\nVERSION_ID=13\nVERSION_CODENAME=trixie' trixie trixie
test_suite $'ID=debian\nVERSION_ID=12\nVERSION_CODENAME=bookworm' bookworm bookworm
test_suite $'ID=ubuntu\nVERSION_ID=24.04\nVERSION_CODENAME=noble' noble noble
test_suite $'ID=linuxmint\nVERSION_CODENAME=zara\nUBUNTU_CODENAME=noble' zara zara
test_suite $'ID=elementary\nVERSION_CODENAME=unsupported\nUBUNTU_CODENAME=noble' noble noble
test_suite $'ID=debian' sid sid sid
test_suite $'ID=debian' forky forky forky/sid
(
	printf '%s\n' 'ID=debian' 'VERSION_CODENAME=unsupported' >"$test_dir/unsupported"
	curl() { return 22; }
	if resolve_xanmod_suite "$test_dir/unsupported" /nonexistent >/dev/null 2>&1; then
		fail '不受支持的 suite 被接受'
	fi
)
echo 'PASS: Debian 12/13、Ubuntu、Mint、衍生版回退和 sid/testing suite'

test_migration() (
	local apt_dir="$test_dir/apt"
	mkdir -p "$apt_dir/sources.list.d"
	printf '%s\n' 'deb https://deb.debian.org/debian trixie main' \
		'deb [signed-by=/old.gpg] http://deb.xanmod.org releases main' >"$apt_dir/sources.list"
	cat >"$apt_dir/sources.list.d/mixed.sources" <<'EOF'
Types: deb
URIs: http://deb.xanmod.org
Suites: releases
Components: main
Signed-By: /old.gpg

Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie
Components: main

Types: deb
URIs: https://deb.xanmod.org https://example.org/repo
Suites: trixie
Components: main

Types: deb
URIs:
 http://deb.xanmod.org
 https://example.org/folded
Suites: trixie
Components: main
EOF
	printf '%s\n' 'deb https://deb.xanmod.org releases main' >"$apt_dir/sources.list.d/custom.list"
	remove_xanmod_sources "$apt_dir"
	assert_contains "$apt_dir/sources.list" 'deb.debian.org'
	assert_absent "$apt_dir/sources.list" 'deb.xanmod.org'
	assert_contains "$apt_dir/sources.list.d/mixed.sources" 'URIs: https://deb.debian.org/debian'
	assert_contains "$apt_dir/sources.list.d/mixed.sources" 'URIs: https://example.org/repo'
	assert_contains "$apt_dir/sources.list.d/mixed.sources" 'URIs: https://example.org/folded'
	assert_absent "$apt_dir/sources.list.d/mixed.sources" 'deb.xanmod.org'
	[[ ! -s "$apt_dir/sources.list.d/custom.list" ]] || fail '自定义文件中的旧源未移除'
)
test_migration
echo 'PASS: .list/deb822 迁移保留其他仓库'

test_install() (
	local failure="$1" edition="${2:-main}" level="${3:-3}"
	local output="$test_dir/$1-$edition-$level.log" log="$test_dir/$1-$edition-$level.calls"
	local package="linux-xanmod" pkg_level="$level"
	[[ "$edition" == main ]] || package="${package}-${edition}"
	[[ "$pkg_level" -le 3 ]] || pkg_level=3
	package="${package}-x64v${pkg_level}"
	local updates=0
	# shellcheck disable=SC2034
	OS_TYPE=Debian OS_ARCH=x86_64
	pre_install_check() { return 0; }
	resolve_xanmod_suite() { echo trixie; }
	remove_xanmod_sources() { echo cleanup >>"$log"; }
	apt-get() {
		printf 'apt-get %s\n' "$*" >>"$log"
		if [[ "$1" == update ]]; then
			updates=$((updates+1))
			[[ "$failure" != "update$updates" ]] || return 100
		elif [[ "$*" == *linux-xanmod* && "$failure" == install ]]; then
			return 100
		elif [[ "$*" == *gnupg* && "$failure" == dependencies ]]; then
			return 100
		fi
	}
	wget() {
		if [[ "$*" == *archive.key* ]]; then
			[[ "$failure" != key ]] || return 1
			echo key >"$2"
		else
			printf '#!/bin/bash\necho "Your CPU supports x86-64-v%s"\n' "$level" >"$2"
		fi
	}
	gpg() { [[ "$failure" != gpg ]] || return 1; echo keyring >"$4"; }
	apt-cache() {
		[[ "${LC_ALL:-}" == C ]] || fail 'APT candidate 未使用固定语言'
		if [[ "$failure" == candidate ]]; then echo '  Candidate: (none)'; else echo '  Candidate: 7.2.0'; fi
	}
	BBR_grub() { echo grub >>"$log"; }
	if install_xanmod_generic "$edition" >"$output" 2>&1; then
		[[ "$failure" == success ]] || fail "$failure 被误报成功"
		assert_contains "$output" '内核安装完毕'
		assert_contains "$log" "apt-get install -y $package"
		assert_contains /etc/apt/sources.list.d/xanmod-kernel.list 'https://deb.xanmod.org trixie main'
		assert_contains "$log" grub
	else
		[[ "$failure" != success ]] || { cat "$output"; fail '安装流程未成功'; }
		assert_absent "$output" '内核安装完毕'
		assert_absent "$log" grub
		if [[ "$failure" != install ]]; then
			assert_absent "$log" "apt-get install -y $package"
		fi
	fi
	assert_absent "$log" gnupg1
)
for case_name in update1 dependencies key gpg update2 candidate install success; do
	test_install "$case_name"
done
test_install success main 4
test_install success edge 2
test_install success lts 1
test_install success rt 3
echo 'PASS: 更新/密钥/候选/安装失败均中止；成功后才更新引导'
