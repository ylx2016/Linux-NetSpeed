#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================
#	System Required: CentOS 7/8,Debian/ubuntu,oraclelinux
#	Description: BBR+BBRplus+Lotserver
#	Version: 100.0.4.2
#	Author: 千影,cx9208,YLX
#	更新内容及反馈:  https://blog.ylx.me/archives/783.html
#=================================================

# RED='\033[0;31m'
# GREEN='\033[0;32m'
# YELLOW='\033[0;33m'
# SKYBLUE='\033[0;36m'
# PLAIN='\033[0m'

sh_ver="100.0.4.2"
github="raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master"

imgurl=""
headurl=""
github_network=1

Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

if [ -f "/etc/sysctl.d/bbr.conf" ]; then
  rm -rf /etc/sysctl.d/bbr.conf
fi

# 检查当前用户是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户身份运行此脚本"
  exit
fi

#优化系统配置
optimizing_system_old() {
  if [ ! -f "/etc/sysctl.d/99-sysctl.conf" ]; then
    touch /etc/sysctl.d/99-sysctl.conf
  fi
  sed -i '/net.ipv4.tcp_retries2/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_slow_start_after_idle/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_fastopen/d' /etc/sysctl.conf
  sed -i '/fs.file-max/d' /etc/sysctl.conf
  sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
  sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
  sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
  sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
  sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
  sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf

  echo "net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_slow_start_after_idle = 0
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
# forward ipv4
#net.ipv4.ip_forward = 1" >>/etc/sysctl.d/99-sysctl.conf
  sysctl -p
  echo "*               soft    nofile           1000000
*               hard    nofile          1000000" >/etc/security/limits.conf
  echo "ulimit -SHn 1000000" >>/etc/profile
  read -p "需要重启VPS后，才能生效系统优化配置，是否现在重启 ? [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo -e "${Info} VPS 重启中..."
    reboot
  fi
}

optimizing_system_johnrosen1() {
  if [ ! -f "/etc/sysctl.d/99-sysctl.conf" ]; then
    touch /etc/sysctl.d/99-sysctl.conf
  fi
  sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_early_retrans/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.neigh.default.unres_qlen/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.netfilter.nf_conntrack_buckets/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/kernel.pid_max/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/vm.nr_hugepages/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.optmem_max/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.all.route_localnet/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.all.forwarding/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.default.forwarding/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.default.forwarding/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.lo.forwarding/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.all.accept_ra/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.default.accept_ra/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.netdev_budget/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.netdev_budget_usecs/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/fs.file-max /d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.rmem_max/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.wmem_max/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.rmem_default/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.wmem_default/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.somaxconn/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.icmp_ignore_bogus_error_responses/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.all.accept_redirects/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.default.accept_redirects/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.all.secure_redirects/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.default.secure_redirects/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.all.send_redirects/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.default.send_redirects/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.default.rp_filter/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.all.rp_filter/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_keepalive_intvl/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_keepalive_probes/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_fastopen/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.all.arp_ignore /d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.default.arp_ignore/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.all.arp_announce/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.conf.default.arp_announce/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_autocorking/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_slow_start_after_idle/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_notsent_lowat/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_ecn_fallback/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.all.accept_redirects/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.default.accept_redirects/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/vm.swappiness/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.ip_unprivileged_port_start/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/vm.overcommit_memory/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.neigh.default.gc_thresh3/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.neigh.default.gc_thresh2/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.neigh.default.gc_thresh1/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.neigh.default.gc_thresh3/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.neigh.default.gc_thresh2/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.neigh.default.gc_thresh1/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.netfilter.nf_conntrack_max/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.nf_conntrack_max/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.netfilter.nf_conntrack_tcp_timeout_fin_wait/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.netfilter.nf_conntrack_tcp_timeout_time_wait/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.netfilter.nf_conntrack_tcp_timeout_close_wait/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.netfilter.nf_conntrack_tcp_timeout_established/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/fs.inotify.max_user_watches/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_low_latency/d' /etc/sysctl.d/99-sysctl.conf

  cat >'/etc/sysctl.d/99-sysctl.conf' <<EOF
net.ipv4.tcp_fack = 1
net.ipv4.tcp_early_retrans = 3
net.ipv4.neigh.default.unres_qlen=10000  
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
#net.ipv6.conf.all.forwarding = 1  #awsipv6问题
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2
net.core.netdev_max_backlog = 100000
net.core.netdev_budget = 50000
net.core.netdev_budget_usecs = 5000
#fs.file-max = 51200
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 67108864
net.core.wmem_default = 67108864
net.core.optmem_max = 65536
net.core.somaxconn = 1000000
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 0
net.ipv4.tcp_fin_timeout = 15
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_syn_backlog = 819200
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_no_metrics_save = 0
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_frto = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.neigh.default.gc_thresh2=4096
net.ipv4.neigh.default.gc_thresh1=2048
net.ipv6.neigh.default.gc_thresh3=8192
net.ipv6.neigh.default.gc_thresh2=4096
net.ipv6.neigh.default.gc_thresh1=2048
net.ipv4.tcp_orphan_retries = 1
net.ipv4.tcp_retries2 = 5
vm.swappiness = 1
vm.overcommit_memory = 1
kernel.pid_max=64000
net.netfilter.nf_conntrack_max = 262144
net.nf_conntrack_max = 262144
## Enable bbr
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_low_latency = 1
EOF
  sysctl -p
  sysctl --system
  echo always >/sys/kernel/mm/transparent_hugepage/enabled

  cat >'/etc/systemd/system.conf' <<EOF
[Manager]
#DefaultTimeoutStartSec=90s
DefaultTimeoutStopSec=30s
#DefaultRestartSec=100ms
DefaultLimitCORE=infinity
DefaultLimitNOFILE=infinity
DefaultLimitNPROC=infinity
DefaultTasksMax=infinity
EOF

  cat >'/etc/security/limits.conf' <<EOF
root     soft   nofile    1000000
root     hard   nofile    1000000
root     soft   nproc     unlimited
root     hard   nproc     unlimited
root     soft   core      unlimited
root     hard   core      unlimited
root     hard   memlock   unlimited
root     soft   memlock   unlimited
*     soft   nofile    1000000
*     hard   nofile    1000000
*     soft   nproc     unlimited
*     hard   nproc     unlimited
*     soft   core      unlimited
*     hard   core      unlimited
*     hard   memlock   unlimited
*     soft   memlock   unlimited
EOF

  sed -i '/ulimit -SHn/d' /etc/profile
  sed -i '/ulimit -SHu/d' /etc/profile
  echo "ulimit -SHn 1000000" >>/etc/profile

  if grep -q "pam_limits.so" /etc/pam.d/common-session; then
    :
  else
    sed -i '/required pam_limits.so/d' /etc/pam.d/common-session
    echo "session required pam_limits.so" >>/etc/pam.d/common-session
  fi
  systemctl daemon-reload
  echo -e "${Info}优化方案2应用结束，可能需要重启！"
}

# 函数：生成并写入 Linux 内核网络优化配置
# 参数（可选，按顺序）：
#   $1: 延迟 (ms，默认 100)
#   $2: 本地带宽 (Mbps，默认 1000)
#   $3: VPS 带宽 (Mbps，默认 1000)
#   $4: VPS 内存 (MB，默认自动获取)
optimizing_system_radicalizate() {
  # 设置默认值
  local latency_default=100
  local local_bw_default=1000
  local vps_bw_default=1000
  local vps_mem_default=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)

  # 提示用户输入参数
  echo -e "请输入参数（用空格隔开）：延迟(ms) 本地带宽(Mbps) VPS带宽(Mbps) VPS内存(MB)"
  echo -e "可以输入单个或多个参数，未提供的参数将使用默认值"
  echo -e "示例1（完整参数）：180 500 500 1024"
  echo -e "示例2（单个参数）：200  # 结果：延迟=200ms, 本地带宽=1000Mbps, VPS带宽=1000Mbps, 内存=自动获取"
  echo -e "默认参数：延迟=$latency_default ms, 本地带宽=$local_bw_default Mbps, VPS带宽=$vps_bw_default Mbps, 内存=自动获取($vps_mem_default MB)"
  echo -e "将在 12 秒后使用默认参数，请输入参数并按回车提交（留空使用默认值）："

  # 设置 12 秒倒计时，静默等待输入
  local input
  if ! read -t 12 -r input; then
    echo -e "\n未输入参数或超时，使用默认参数..."
    local latency=$latency_default
    local local_bw=$local_bw_default
    local vps_bw=$vps_bw_default
    local vps_mem=$vps_mem_default
  else
    # 分割用户输入
    read -r latency local_bw vps_bw vps_mem <<<"$input"
    # 使用默认值补齐未提供的参数
    latency=${latency:-$latency_default}
    local_bw=${local_bw:-$local_bw_default}
    vps_bw=${vps_bw:-$vps_bw_default}
    vps_mem=${vps_mem:-$vps_mem_default}
  fi

  # 显示最终提交的参数信息
  echo -e "最终提交参数：延迟=$latency ms, 本地带宽=$local_bw Mbps, VPS带宽=$vps_bw Mbps, 内存=$vps_mem MB"
  sleep 1 # 延迟 1 秒

  # 检查输入参数是否有效
  if ! [[ "$latency" =~ ^[0-9]+$ ]] || ! [[ "$local_bw" =~ ^[0-9]+$ ]] ||
    ! [[ "$vps_bw" =~ ^[0-9]+$ ]] || ! [[ "$vps_mem" =~ ^[0-9]+$ ]]; then
    echo -e "Error: All parameters must be positive integers."
    return 1
  fi

  # 检查是否有 root 权限
  if [ "$EUID" -ne 0 ]; then
    echo -e "Error: This script requires root privileges to write to /etc/sysctl.d/99-sysctl.conf."
    return 1
  fi

  # 计算带宽延迟积 (BDP, 字节)：min(local_bw, vps_bw) * latency / 8
  local min_bw=$((local_bw < vps_bw ? local_bw : vps_bw))
  local bdp=$((min_bw * 1000000 * latency / 8 / 1000))

  # 根据内存和 BDP 设置缓冲区大小 (上限不超过内存的 50%)，使用整数运算
  local rmem_max=$((bdp * 2))     # 2 倍 BDP
  local wmem_max=$((bdp * 3 / 2)) # 1.5 倍 BDP
  local max_mem_bytes=$((vps_mem * 1024 * 1024 * 50 / 100))
  [[ $rmem_max -gt $max_mem_bytes ]] && rmem_max=$max_mem_bytes
  [[ $wmem_max -gt $max_mem_bytes ]] && wmem_max=$max_mem_bytes
  [[ $rmem_max -lt 1048576 ]] && rmem_max=1048576 # 最小 1MB
  [[ $wmem_max -lt 1048576 ]] && wmem_max=1048576 # 最小 1MB

  # 根据带宽和内存设置队列长度
  local netdev_max_backlog=$((min_bw * 10))
  [[ $netdev_max_backlog -gt 10000 ]] && netdev_max_backlog=10000
  [[ $netdev_max_backlog -lt 1000 ]] && netdev_max_backlog=1000
  local somaxconn=$((vps_mem * 20))
  [[ $somaxconn -gt 16384 ]] && somaxconn=16384
  [[ $somaxconn -lt 512 ]] && somaxconn=512
  local tcp_max_syn_backlog=$((somaxconn * 4))
  [[ $tcp_max_syn_backlog -gt 65536 ]] && tcp_max_syn_backlog=65536

  # 根据延迟设置初始拥塞窗口
  local tcp_init_cwnd=$((latency / 20 + 10))
  [[ $tcp_init_cwnd -gt 32 ]] && tcp_init_cwnd=32
  [[ $tcp_init_cwnd -lt 10 ]] && tcp_init_cwnd=10

  # 根据内存设置最小空闲内存 (约 10-15% 内存)
  local min_free_kbytes=$((vps_mem * 1024 * 12 / 100))
  [[ $min_free_kbytes -gt 524288 ]] && min_free_kbytes=524288 # 最大 512MB
  [[ $min_free_kbytes -lt 65536 ]] && min_free_kbytes=65536   # 最小 64MB

  # 目标配置文件
  local config_file="/etc/sysctl.d/99-sysctl.conf"
  local temp_file=$(mktemp)

  # 定义所有参数和值（包含测试中发现的额外参数）
  declare -A sysctl_params=(
    ["kernel.pid_max"]="65535"
    ["kernel.panic"]="1"
    ["kernel.sysrq"]="1"
    ["kernel.core_pattern"]="core_%e"
    ["kernel.printk"]="3 4 1 3"
    ["kernel.numa_balancing"]="0"
    ["kernel.sched_autogroup_enabled"]="0"
    ["vm.swappiness"]="5"
    ["vm.dirty_ratio"]="5"
    ["vm.dirty_background_ratio"]="2"
    ["vm.panic_on_oom"]="1"
    ["vm.overcommit_memory"]="1"
    ["vm.min_free_kbytes"]="$min_free_kbytes"
    ["net.core.netdev_max_backlog"]="$netdev_max_backlog"
    ["net.core.rmem_max"]="$rmem_max"
    ["net.core.wmem_max"]="$wmem_max"
    ["net.core.rmem_default"]="262144"
    ["net.core.wmem_default"]="262144"
    ["net.core.somaxconn"]="$somaxconn"
    ["net.core.optmem_max"]="262144"
    ["net.netfilter.nf_conntrack_max"]="262144"
    ["net.nf_conntrack_max"]="262144"
    ["net.ipv4.tcp_fastopen"]="3"
    ["net.ipv4.tcp_timestamps"]="1"
    ["net.ipv4.tcp_tw_reuse"]="1"
    ["net.ipv4.tcp_fin_timeout"]="10"
    ["net.ipv4.tcp_slow_start_after_idle"]="0"
    ["net.ipv4.tcp_max_tw_buckets"]="32768"
    ["net.ipv4.tcp_sack"]="1"
    ["net.ipv4.tcp_fack"]="1"
    ["net.ipv4.tcp_rmem"]="32768 262144 $rmem_max"
    ["net.ipv4.tcp_wmem"]="32768 262144 $wmem_max"
    ["net.ipv4.tcp_mtu_probing"]="1"
    ["net.ipv4.tcp_notsent_lowat"]="16384"
    ["net.ipv4.tcp_window_scaling"]="1"
    ["net.ipv4.tcp_adv_win_scale"]="2"
    ["net.ipv4.tcp_moderate_rcvbuf"]="1"
    ["net.ipv4.tcp_no_metrics_save"]="1"
    ["net.ipv4.tcp_init_cwnd"]="$tcp_init_cwnd"
    ["net.ipv4.tcp_max_syn_backlog"]="$tcp_max_syn_backlog"
    ["net.ipv4.tcp_max_orphans"]="32768"
    ["net.ipv4.tcp_synack_retries"]="2"
    ["net.ipv4.tcp_syn_retries"]="2"
    ["net.ipv4.tcp_abort_on_overflow"]="0"
    ["net.ipv4.tcp_stdurg"]="0"
    ["net.ipv4.tcp_rfc1337"]="0"
    ["net.ipv4.tcp_syncookies"]="1"
    ["net.ipv4.tcp_low_latency"]="1"
    ["net.ipv4.ip_local_port_range"]="1024 65535"
    ["net.ipv4.ip_no_pmtu_disc"]="0"
    ["net.ipv4.route.gc_timeout"]="100"
    ["net.ipv4.neigh.default.gc_stale_time"]="120"
    ["net.ipv4.neigh.default.gc_thresh3"]="4096"
    ["net.ipv4.neigh.default.gc_thresh2"]="2048"
    ["net.ipv4.neigh.default.gc_thresh1"]="512"
    ["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
    ["net.ipv4.icmp_ignore_bogus_error_responses"]="1"
    ["net.ipv4.conf.all.rp_filter"]="1"
    ["net.ipv4.conf.default.rp_filter"]="1"
    ["net.ipv4.conf.all.arp_announce"]="2"
    ["net.ipv4.conf.default.arp_announce"]="2"
    ["net.ipv4.conf.all.arp_ignore"]="1"
    ["net.ipv4.conf.default.arp_ignore"]="1"
  )

  # 添加文件头部注释
  echo "# Generated sysctl configuration" >"$temp_file"
  echo "# Latency: $latency ms" >>"$temp_file"
  echo "# Local Bandwidth: $local_bw Mbps" >>"$temp_file"
  echo "# VPS Bandwidth: $vps_bw Mbps" >>"$temp_file"
  echo "# VPS Memory: $vps_mem MB" >>"$temp_file"
  echo "" >>"$temp_file"

  # 如果配置文件不存在，直接写入所有参数
  if [ ! -f "$config_file" ]; then
    for key in "${!sysctl_params[@]}"; do
      echo "$key=${sysctl_params[$key]}" >>"$temp_file"
    done
  else
    # 读取现有配置文件内容，去除多余空格
    cp "$config_file" "$temp_file.bak"
    while IFS='=' read -r key value; do
      key=$(echo "$key" | xargs)     # 去除首尾空格
      value=$(echo "$value" | xargs) # 去除值中的多余空格
      if [ -n "$key" ] && [[ ! "$key" =~ ^# ]]; then
        if [[ -n "${sysctl_params[$key]}" ]]; then
          echo "$key=${sysctl_params[$key]}" >>"$temp_file.new"
          unset sysctl_params["$key"]
        else
          echo "$key=$value" >>"$temp_file.new"
        fi
      fi
    done <"$config_file"

    # 将新参数追加到临时文件
    for key in "${!sysctl_params[@]}"; do
      echo "$key=${sysctl_params[$key]}" >>"$temp_file.new"
    done

    # 合并并替换临时文件
    cat "$temp_file" >"$temp_file.final"
    cat "$temp_file.new" >>"$temp_file.final"
    mv "$temp_file.final" "$temp_file"
    rm -f "$temp_file.new" "$temp_file.bak"
  fi

  # 写入目标文件并应用配置
  mv "$temp_file" "$config_file"
  chmod 644 "$config_file"
  sysctl -p "$config_file" >/dev/null 2>&1
  sysctl --system >/dev/null 2>&1
  echo -e "${Info}激进方案应用完毕，有些设置可能需要重启生效！"
}

#处理传进来的参数 直接优化
err() {
  echo "错误: $1"
  exit 1
}

while [ $# -gt 0 ]; do
  case $1 in
  op)
    optimizing_system_old # 调用函数
    exit
    ;;
  op2)
    optimizing_system_johnrosen1 # 调用函数
    exit
    ;;
  op3)
    optimizing_system_radicalizate # 调用函数
    exit
    ;;
  *)
    err "未知选项: \"$1\""
    ;;
  esac
  shift # 移动到下一个参数
done

# 检查github网络
check_github() {
  # 检测域名的可访问性函数
  check_domain() {
    local domain="$1"
    if ! curl --max-time 5 --head --silent --fail "$domain" >/dev/null; then
      echo -e "${Error}无法访问 $domain，请检查网络或者本地DNS 或者访问频率过快而受限"
      github_network=0
    fi
  }

  # 检测所有域名的可访问性
  check_domain "https://raw.githubusercontent.com"
  check_domain "https://api.github.com"
  check_domain "https://github.com"

  if [ "$github_network" -eq 0 ]; then
    echo -e "${Error}github网络访问受限，将影响内核的安装以及脚本的检查更新，1秒后继续运行脚本"
    sleep 1
  else
    # 所有域名均可访问，打印成功提示
    echo -e "${Green_font_prefix}github可访问${Font_color_suffix}，继续执行脚本..."
  fi
}

#检查连接
checkurl() {
  local url="$1"
  local maxRetries=3
  local retryDelay=2

  if [[ -z "$url" ]]; then
    echo "错误：缺少URL参数！"
    exit 1
  fi

  local retries=0
  local responseCode=""

  while [[ -z "$responseCode" && $retries -lt $maxRetries ]]; do
    responseCode=$(curl --max-time 6 -s -L -m 10 --connect-timeout 5 -o /dev/null -w "%{http_code}" "$url")

    if [[ -z "$responseCode" ]]; then
      ((retries++))
      sleep $retryDelay
    fi
  done

  if [[ -n "$responseCode" && ("$responseCode" == "200" || "$responseCode" =~ ^3[0-9]{2}$) ]]; then
    echo "下载地址检查OK，继续！"
  else
    echo "下载地址检查出错，退出！"
    exit 1
  fi
}

#cn处理github加速
check_cn() {
  # 检查是否安装了jq命令，如果没有安装则进行安装
  if ! command -v jq >/dev/null 2>&1; then
    if command -v yum >/dev/null 2>&1; then
      sudo yum install epel-release -y
      sudo yum install -y jq
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y jq
    else
      echo "无法安装jq命令。请手动安装jq后再试。"
      exit 1
    fi
  fi

  # 获取当前IP地址，设置超时为3秒
  current_ip=$(curl -s --max-time 3 https://api.ipify.org)

  # 使用ip-api.com查询IP所在国家，设置超时为3秒
  response=$(curl -s --max-time 3 "http://ip-api.com/json/$current_ip")

  # 检查国家是否为中国
  country=$(echo "$response" | jq -r '.countryCode')
  if [[ "$country" == "CN" ]]; then
    local suffixes=(
      "https://gh.con.sh/"
      "https://gh-proxy.com/"
      "https://ghp.ci/"
      "https://gh.m-l.cc/"
      "https://down.npee.cn/?"
      "https://mirror.ghproxy.com/"
      "https://ghps.cc/"
      "https://gh.api.99988866.xyz/"
      "https://git.886.be/"
      "https://hub.gitmirror.com/"
      "https://pd.zwc365.com/"
      "https://gh.ddlc.top/"
      "https://slink.ltd/"
      "https://github.moeyy.xyz/"
      "https://ghproxy.crazypeace.workers.dev/"
      "https://gh.h233.eu.org/"
    )

    # 循环遍历每个后缀并测试组合的链接
    for suffix in "${suffixes[@]}"; do
      # 组合后缀和原始链接
      combined_url="$suffix$1"

      # 使用 curl -I 获取头部信息，提取状态码
      local response_code=$(curl --max-time 2 -sL -w "%{http_code}" -I "$combined_url" | head -n 1 | awk '{print $2}')

      # 检查响应码是否表示成功 (2xx)
      if [[ $response_code -ge 200 && $response_code -lt 300 ]]; then
        echo "$combined_url"
        return 0 # 返回可用链接，结束函数
      fi
    done

  # 如果没有找到有效链接，返回原始链接
  else
    echo "$1"
    return 1

  fi
}

#下载
download_file() {
  url="$1"
  filename="$2"

  wget "$url" -O "$filename"
  status=$?

  if [ $status -eq 0 ]; then
    echo -e "\e[32m文件下载成功或已经是最新。\e[0m"
  else
    echo -e "\e[31m文件下载失败，退出状态码: $status\e[0m"
    exit 1
  fi
}

#檢查賦值
check_empty() {
  local var_value=$1

  if [[ -z $var_value ]]; then
    echo "$var_value 是空值，退出！"
    exit 1
  fi
}

#安装BBR内核
installbbr() {
  kernel_version="5.9.6"
  bit=$(uname -m)
  rm -rf bbr
  mkdir bbr && cd bbr || exit

  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "7" ]]; then
      if [[ ${bit} == "x86_64" ]]; then
        echo -e "如果下载地址出错，可能当前正在更新，超过半天还是出错请反馈，大陆自行解决污染问题"
        #github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}' | awk -F '[_]' '{print $3}')
        #github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Centos_Kernel' | grep '_latest_bbr_' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
        #github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}')
        #check_empty $github_ver
        #echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
        #kernel_version=$github_ver
        #detele_kernel_head
        #headurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep 'headers' | awk -F '"' '{print $4}')
        #imgurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep -v 'headers' | grep -v 'devel' | awk -F '"' '{print $4}')
        #headurl=https://github.com/ylx2016/kernel/releases/download/$github_tag/kernel-headers-${github_ver}-1.x86_64.rpm
        #imgurl=https://github.com/ylx2016/kernel/releases/download/$github_tag/kernel-${github_ver}-1.x86_64.rpm

        headurl=https://github.com/ylx2016/kernel/releases/download/Centos_Kernel_6.1.35_latest_bbr_2023.06.22-0855/kernel-headers-6.1.35-1.x86_64.rpm
        imgurl=https://github.com/ylx2016/kernel/releases/download/Centos_Kernel_6.1.35_latest_bbr_2023.06.22-0855/kernel-6.1.35-1.x86_64.rpm

        check_empty $imgurl
        headurl=$(check_cn $headurl)
        imgurl=$(check_cn $imgurl)

        download_file $headurl kernel-headers-c7.rpm
        download_file $imgurl kernel-c7.rpm
        yum install -y kernel-c7.rpm
        yum install -y kernel-headers-c7.rpm
      else
        echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
      fi
    fi

  elif [[ "${OS_type}" == "Debian" ]]; then
    if [[ ${bit} == "x86_64" ]]; then
      echo -e "如果下载地址出错，可能当前正在更新，超过半天还是出错请反馈，大陆自行解决污染问题"
      github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Debian_Kernel' | grep '_latest_bbr_' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
      github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}' | awk -F '[_]' '{print $1}')
      check_empty $github_ver
      echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
      kernel_version=$github_ver
      detele_kernel_head
      headurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep 'headers' | awk -F '"' '{print $4}')
      imgurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep -v 'headers' | grep -v 'devel' | awk -F '"' '{print $4}')
      #headurl=https://github.com/ylx2016/kernel/releases/download/$github_tag/linux-headers-${github_ver}_${github_ver}-1_amd64.deb
      #imgurl=https://github.com/ylx2016/kernel/releases/download/$github_tag/linux-image-${github_ver}_${github_ver}-1_amd64.deb

      headurl=$(check_cn $headurl)
      imgurl=$(check_cn $imgurl)

      download_file $headurl linux-headers-d10.deb
      download_file $imgurl linux-image-d10.deb
      dpkg -i linux-image-d10.deb
      dpkg -i linux-headers-d10.deb
    elif [[ ${bit} == "aarch64" ]]; then
      echo -e "如果下载地址出错，可能当前正在更新，超过半天还是出错请反馈，大陆自行解决污染问题"
      github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Debian_Kernel' | grep '_arm64_' | grep '_bbr_' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
      github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}' | awk -F '[_]' '{print $1}')
      echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
      kernel_version=$github_ver
      detele_kernel_head
      headurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep 'headers' | awk -F '"' '{print $4}')
      imgurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep -v 'headers' | grep -v 'devel' | awk -F '"' '{print $4}')
      #headurl=https://github.com/ylx2016/kernel/releases/download/$github_tag/linux-headers-${github_ver}_${github_ver}-1_amd64.deb
      #imgurl=https://github.com/ylx2016/kernel/releases/download/$github_tag/linux-image-${github_ver}_${github_ver}-1_amd64.deb

      check_empty $imgurl
      headurl=$(check_cn $headurl)
      imgurl=$(check_cn $imgurl)

      download_file $headurl linux-headers-d10.deb
      download_file $imgurl linux-image-d10.deb
      dpkg -i linux-image-d10.deb
      dpkg -i linux-headers-d10.deb
    else
      echo -e "${Error} 不支持x86_64及arm64/aarch64以外的系统 !" && exit 1
    fi
  fi

  cd .. && rm -rf bbr

  detele_kernel
  BBR_grub
  echo -e "${Tip} ${Red_font_prefix}请检查上面是否有内核信息，无内核千万别重启${Font_color_suffix}"
  echo -e "${Tip} ${Red_font_prefix}rescue不是正常内核，要排除这个${Font_color_suffix}"
  echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}BBR${Font_color_suffix}"
  check_kernel
  stty erase '^H' && read -p "需要重启VPS后，才能开启BBR，是否现在重启 ? [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo -e "${Info} VPS 重启中..."
    reboot
  fi
  #echo -e "${Tip} 内核安装完毕，请参考上面的信息检查是否安装成功及手动调整内核启动顺序"
}

#安装BBRplus内核 4.14.129
installbbrplus() {
  kernel_version="4.14.160-bbrplus"
  bit=$(uname -m)
  rm -rf bbrplus
  mkdir bbrplus && cd bbrplus || exit
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "7" ]]; then
      if [[ ${bit} == "x86_64" ]]; then
        kernel_version="4.14.129_bbrplus"
        detele_kernel_head
        headurl=https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/centos/7/kernel-headers-4.14.129-bbrplus.rpm
        imgurl=https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/centos/7/kernel-4.14.129-bbrplus.rpm

        headurl=$(check_cn $headurl)
        imgurl=$(check_cn $imgurl)

        download_file $headurl kernel-headers-c7.rpm
        download_file $imgurl kernel-c7.rpm
        yum install -y kernel-c7.rpm
        yum install -y kernel-headers-c7.rpm
      else
        echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
      fi
    fi

  elif [[ "${OS_type}" == "Debian" ]]; then
    if [[ ${bit} == "x86_64" ]]; then
      kernel_version="4.14.129-bbrplus"
      detele_kernel_head
      headurl=https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/debian-ubuntu/x64/linux-headers-4.14.129-bbrplus.deb
      imgurl=https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/debian-ubuntu/x64/linux-image-4.14.129-bbrplus.deb

      headurl=$(check_cn $headurl)
      imgurl=$(check_cn $imgurl)

      wget -O linux-headers.deb $headurl
      wget -O linux-image.deb $imgurl

      dpkg -i linux-image.deb
      dpkg -i linux-headers.deb
    else
      echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
    fi
  fi

  cd .. && rm -rf bbrplus
  detele_kernel
  BBR_grub
  echo -e "${Tip} ${Red_font_prefix}请检查上面是否有内核信息，无内核千万别重启${Font_color_suffix}"
  echo -e "${Tip} ${Red_font_prefix}rescue不是正常内核，要排除这个${Font_color_suffix}"
  echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}BBRplus${Font_color_suffix}"
  check_kernel
  stty erase '^H' && read -p "需要重启VPS后，才能开启BBRplus，是否现在重启 ? [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo -e "${Info} VPS 重启中..."
    reboot
  fi
  #echo -e "${Tip} 内核安装完毕，请参考上面的信息检查是否安装成功及手动调整内核启动顺序"
}

#安装Lotserver内核
installlot() {
  bit=$(uname -m)
  if [[ ${bit} != "x86_64" ]]; then
    echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
  fi
  if [[ ${bit} == "x86_64" ]]; then
    bit='x64'
  fi
  if [[ ${bit} == "i386" ]]; then
    bit='x32'
  fi
  if [[ "${OS_type}" == "CentOS" ]]; then
    rpm --import http://${github}/lotserver/${release}/RPM-GPG-KEY-elrepo.org
    yum remove -y kernel-firmware
    yum install -y http://${github}/lotserver/${release}/${version}/${bit}/kernel-firmware-${kernel_version}.rpm
    yum install -y http://${github}/lotserver/${release}/${version}/${bit}/kernel-${kernel_version}.rpm
    yum remove -y kernel-headers
    yum install -y http://${github}/lotserver/${release}/${version}/${bit}/kernel-headers-${kernel_version}.rpm
    yum install -y http://${github}/lotserver/${release}/${version}/${bit}/kernel-devel-${kernel_version}.rpm
  fi

  if [[ "${OS_type}" == "Debian" ]]; then
    deb_issue="$(cat /etc/issue)"
    deb_relese="$(echo $deb_issue | grep -io 'Ubuntu\|Debian' | sed -r 's/(.*)/\L\1/')"
    os_ver="$(dpkg --print-architecture)"
    [ -n "$os_ver" ] || exit 1
    if [ "$deb_relese" == 'ubuntu' ]; then
      deb_ver="$(echo $deb_issue | grep -o '[0-9]*\.[0-9]*' | head -n1)"
      if [ "$deb_ver" == "14.04" ]; then
        kernel_version="3.16.0-77-generic" && item="3.16.0-77-generic" && ver='trusty'
      elif [ "$deb_ver" == "16.04" ]; then
        kernel_version="4.8.0-36-generic" && item="4.8.0-36-generic" && ver='xenial'
      elif [ "$deb_ver" == "18.04" ]; then
        kernel_version="4.15.0-30-generic" && item="4.15.0-30-generic" && ver='bionic'
      else
        exit 1
      fi
      url='archive.ubuntu.com'
      urls='security.ubuntu.com'
    elif [ "$deb_relese" == 'debian' ]; then
      deb_ver="$(echo $deb_issue | grep -o '[0-9]*' | head -n1)"
      if [ "$deb_ver" == "7" ]; then
        kernel_version="3.2.0-4-${os_ver}" && item="3.2.0-4-${os_ver}" && ver='wheezy' && url='archive.debian.org' && urls='archive.debian.org'
      elif [ "$deb_ver" == "8" ]; then
        kernel_version="3.16.0-4-${os_ver}" && item="3.16.0-4-${os_ver}" && ver='jessie' && url='archive.debian.org' && urls='archive.debian.org'
      elif [ "$deb_ver" == "9" ]; then
        kernel_version="4.9.0-4-${os_ver}" && item="4.9.0-4-${os_ver}" && ver='stretch' && url='archive.debian.org' && urls='archive.debian.org'
      else
        exit 1
      fi
    fi
    [ -n "$item" ] && [ -n "$urls" ] && [ -n "$url" ] && [ -n "$ver" ] || exit 1
    if [ "$deb_relese" == 'ubuntu' ]; then
      echo "deb http://${url}/${deb_relese} ${ver} main restricted universe multiverse" >/etc/apt/sources.list
      echo "deb http://${url}/${deb_relese} ${ver}-updates main restricted universe multiverse" >>/etc/apt/sources.list
      echo "deb http://${url}/${deb_relese} ${ver}-backports main restricted universe multiverse" >>/etc/apt/sources.list
      echo "deb http://${urls}/${deb_relese} ${ver}-security main restricted universe multiverse" >>/etc/apt/sources.list

      apt-get update || apt-get --allow-releaseinfo-change update
      apt-get install --no-install-recommends -y linux-image-${item}
    elif [ "$deb_relese" == 'debian' ]; then
      echo "deb http://${url}/${deb_relese} ${ver} main" >/etc/apt/sources.list
      echo "deb-src http://${url}/${deb_relese} ${ver} main" >>/etc/apt/sources.list
      echo "deb http://${urls}/${deb_relese}-security ${ver}/updates main" >>/etc/apt/sources.list
      echo "deb-src http://${urls}/${deb_relese}-security ${ver}/updates main" >>/etc/apt/sources.list

      if [ "$deb_ver" == "8" ]; then
        dpkg -l | grep -q 'linux-base' || {
          wget --no-check-certificate -qO '/tmp/linux-base_3.5_all.deb' 'http://snapshot.debian.org/archive/debian/20120304T220938Z/pool/main/l/linux-base/linux-base_3.5_all.deb'
          dpkg -i '/tmp/linux-base_3.5_all.deb'
        }
        wget --no-check-certificate -qO '/tmp/linux-image-3.16.0-4-amd64_3.16.43-2+deb8u5_amd64.deb' 'http://snapshot.debian.org/archive/debian/20171008T163152Z/pool/main/l/linux/linux-image-3.16.0-4-amd64_3.16.43-2+deb8u5_amd64.deb'
        dpkg -i '/tmp/linux-image-3.16.0-4-amd64_3.16.43-2+deb8u5_amd64.deb'

        if [ $? -ne 0 ]; then
          exit 1
        fi
      elif [ "$deb_ver" == "9" ]; then
        dpkg -l | grep -q 'linux-base' || {
          wget --no-check-certificate -qO '/tmp/linux-base_4.5_all.deb' 'http://snapshot.debian.org/archive/debian/20160917T042239Z/pool/main/l/linux-base/linux-base_4.5_all.deb'
          dpkg -i '/tmp/linux-base_4.5_all.deb'
        }
        wget --no-check-certificate -qO '/tmp/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb' 'http://snapshot.debian.org/archive/debian/20171224T175424Z/pool/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb'
        dpkg -i '/tmp/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb'
        ##备选
        #https://sys.if.ci/download/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb
        #http://mirror.cs.uchicago.edu/debian-security/pool/updates/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb
        #https://debian.sipwise.com/debian-security/pool/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb
        #http://srv24.dsidata.sk/security.debian.org/pool/updates/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb
        #https://pubmirror.plutex.de/debian-security/pool/updates/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb
        #https://packages.mendix.com/debian/pool/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3_amd64.deb
        #http://snapshot.debian.org/archive/debian/20171224T175424Z/pool/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3+deb9u1_amd64.deb
        #http://snapshot.debian.org/archive/debian/20171231T180144Z/pool/main/l/linux/linux-image-4.9.0-4-amd64_4.9.65-3_amd64.deb
        if [ $? -ne 0 ]; then
          exit 1
        fi
      else
        exit 1
      fi
    fi
    apt-get autoremove -y
    [ -d '/var/lib/apt/lists' ] && find /var/lib/apt/lists -type f -delete
  fi

  detele_kernel
  BBR_grub
  echo -e "${Tip} ${Red_font_prefix}请检查上面是否有内核信息，无内核千万别重启${Font_color_suffix}"
  echo -e "${Tip} ${Red_font_prefix}rescue不是正常内核，要排除这个${Font_color_suffix}"
  echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}Lotserver${Font_color_suffix}"
  check_kernel
  stty erase '^H' && read -p "需要重启VPS后，才能开启Lotserver，是否现在重启 ? [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo -e "${Info} VPS 重启中..."
    reboot
  fi
  #echo -e "${Tip} 内核安装完毕，请参考上面的信息检查是否安装成功及手动调整内核启动顺序"
}

#安装xanmod内核  from xanmod.org
installxanmod() {
  kernel_version="5.5.1-xanmod1"
  bit=$(uname -m)
  if [[ ${bit} != "x86_64" ]]; then
    echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
  fi
  rm -rf xanmod
  mkdir xanmod && cd xanmod || exit
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "7" ]]; then
      if [[ ${bit} == "x86_64" ]]; then
        echo -e "如果下载地址出错，可能当前正在更新，超过半天还是出错请反馈，大陆自行解决污染问题"
        #github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Centos_Kernel' | grep '_lts_latest_' | grep 'xanmod' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
        #github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}')
        #echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
        #kernel_version=$github_ver
        #detele_kernel_head
        #headurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep 'headers' | awk -F '"' '{print $4}')
        #imgurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep -v 'headers' | grep -v 'devel' | awk -F '"' '{print $4}')

        headurl=https://github.com/ylx2016/kernel/releases/download/Centos_Kernel_5.15.95-xanmod1_lts_latest_2023.02.24-2159/kernel-headers-5.15.95_xanmod1-1.x86_64.rpm
        imgurl=https://github.com/ylx2016/kernel/releases/download/Centos_Kernel_5.15.95-xanmod1_lts_latest_2023.02.24-2159/kernel-5.15.95_xanmod1-1.x86_64.rpm

        check_empty $imgurl
        headurl=$(check_cn $headurl)
        imgurl=$(check_cn $imgurl)

        download_file $headurl kernel-headers-c7.rpm
        download_file $imgurl kernel-c7.rpm
        yum install -y kernel-c7.rpm
        yum install -y kernel-headers-c7.rpm
      else
        echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
      fi
    elif [[ ${version} == "8" ]]; then
      echo -e "如果下载地址出错，可能当前正在更新，超过半天还是出错请反馈，大陆自行解决污染问题"
      #github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Centos_Kernel' | grep '_lts_C8_latest_' | grep 'xanmod' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
      #github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}')
      #echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
      #kernel_version=$github_ver
      #detele_kernel_head
      #headurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep 'headers' | awk -F '"' '{print $4}')
      #imgurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep -v 'headers' | grep -v 'devel' | awk -F '"' '{print $4}')

      headurl=https://github.com/ylx2016/kernel/releases/download/Centos_Kernel_5.15.81-xanmod1_lts_C8_latest_2022.12.06-1614/kernel-headers-5.15.81_xanmod1-1.x86_64.rpm
      imgurl=https://github.com/ylx2016/kernel/releases/download/Centos_Kernel_5.15.81-xanmod1_lts_C8_latest_2022.12.06-1614/kernel-5.15.81_xanmod1-1.x86_64.rpm

      check_empty $imgurl
      headurl=$(check_cn $headurl)
      imgurl=$(check_cn $imgurl)

      wget -O kernel-headers-c8.rpm $headurl
      wget -O kernel-c8.rpm $imgurl
      yum install -y kernel-c8.rpm
      yum install -y kernel-headers-c8.rpm
    fi

  elif [[ "${OS_type}" == "Debian" ]]; then

    if [[ ${bit} == "x86_64" ]]; then
      echo -e "如果下载地址出错，可能当前正在更新，超过半天还是出错请反馈，大陆自行解决污染问题"
      #github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Debian_Kernel' | grep '_lts_latest_' | grep 'xanmod' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
      #github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}')

      #check_empty $github_ver
      #echo -e "获取的xanmod lts版本号为:${github_ver}"

      #kernel_version=$github_ver

      #detele_kernel_head
      #headurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep 'headers' | awk -F '"' '{print $4}')
      #imgurl=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep -v 'headers' | grep -v 'devel' | awk -F '"' '{print $4}')

      headurl=https://github.com/ylx2016/kernel/releases/download/Debian_Kernel_5.15.95-xanmod1_lts_latest_2023.02.24-2210/linux-headers-5.15.95-xanmod1_5.15.95-xanmod1-1_amd64.deb
      imgurl=https://github.com/ylx2016/kernel/releases/download/Debian_Kernel_5.15.95-xanmod1_lts_latest_2023.02.24-2210/linux-image-5.15.95-xanmod1_5.15.95-xanmod1-1_amd64.deb

      check_empty $imgurl
      headurl=$(check_cn $headurl)
      imgurl=$(check_cn $imgurl)

      download_file $headurl linux-headers-d10.deb
      download_file $imgurl linux-image-d10.deb
      dpkg -i linux-image-d10.deb
      dpkg -i linux-headers-d10.deb
    else
      echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
    fi
  fi

  cd .. && rm -rf xanmod
  detele_kernel
  BBR_grub
  echo -e "${Tip} ${Red_font_prefix}请检查上面是否有内核信息，无内核千万别重启${Font_color_suffix}"
  echo -e "${Tip} ${Red_font_prefix}rescue不是正常内核，要排除这个${Font_color_suffix}"
  echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}BBR${Font_color_suffix}"
  check_kernel
  stty erase '^H' && read -p "需要重启VPS后，才能开启BBR，是否现在重启 ? [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo -e "${Info} VPS 重启中..."
    reboot
  fi
  #echo -e "${Tip} 内核安装完毕，请参考上面的信息检查是否安装成功及手动调整内核启动顺序"
}

#安装bbr2内核 集成到xanmod内核了
#安装bbrplus 新内核
#2021.3.15 开始由https://github.com/UJX6N/bbrplus-5.19 替换bbrplusnew
#2021.4.12 地址更新为https://github.com/ylx2016/kernel/releases
#2021.9.2 再次改为https://github.com/UJX6N/bbrplus
#2022.9.6 改为https://github.com/UJX6N/bbrplus-5.19
#2022.11.24 改为https://github.com/UJX6N/bbrplus-6.x_stable

installbbrplusnew() {
  github_ver_plus=$(curl -s https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases | grep /bbrplus-6.x_stable/releases/tag/ | head -1 | awk -F "[/]" '{print $8}' | awk -F "[\"]" '{print $1}')
  github_ver_plus_num=$(curl -s https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases | grep /bbrplus-6.x_stable/releases/tag/ | head -1 | awk -F "[/]" '{print $8}' | awk -F "[\"]" '{print $1}' | awk -F "[-]" '{print $1}')
  echo -e "获取的UJX6N的bbrplus-6.x_stable版本号为:${Green_font_prefix}${github_ver_plus}${Font_color_suffix}"
  echo -e "如果下载地址出错，可能当前正在更新，超过半天还是出错请反馈，大陆自行解决污染问题"
  echo -e "${Green_font_prefix}安装失败这边反馈，内核问题给UJX6N反馈${Font_color_suffix}"
  # kernel_version=$github_ver_plus

  bit=$(uname -m)
  #if [[ ${bit} != "x86_64" ]]; then
  #  echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
  #fi
  rm -rf bbrplusnew
  mkdir bbrplusnew && cd bbrplusnew || exit
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "7" ]]; then
      if [[ ${bit} == "x86_64" ]]; then
        #github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Centos_Kernel' | grep '_latest_bbrplus_' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
        #github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}' | awk -F '[_]' '{print $1}')
        #echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
        kernel_version=${github_ver_plus_num}-bbrplus
        detele_kernel_head
        headurl=$(curl -s 'https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases' | grep ${github_ver_plus} | grep 'rpm' | grep 'headers' | grep 'el7' | awk -F '"' '{print $4}' | grep 'http')
        imgurl=$(curl -s 'https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases' | grep ${github_ver_plus} | grep 'rpm' | grep -v 'devel' | grep -v 'headers' | grep -v 'Source' | grep 'el7' | awk -F '"' '{print $4}' | grep 'http')

        headurl=$(check_cn $headurl)
        imgurl=$(check_cn $imgurl)

        wget -O kernel-c7.rpm $headurl
        wget -O kernel-headers-c7.rpm $imgurl
        yum install -y kernel-c7.rpm
        yum install -y kernel-headers-c7.rpm
      else
        echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
      fi
    fi
    if [[ ${version} == "8" ]]; then
      if [[ ${bit} == "x86_64" ]]; then
        #github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Centos_Kernel' | grep '_latest_bbrplus_' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
        #github_ver=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'rpm' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}' | awk -F '[_]' '{print $1}')
        #echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
        kernel_version=${github_ver_plus_num}-bbrplus
        detele_kernel_head
        headurl=$(curl -s 'https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases' | grep ${github_ver_plus} | grep 'rpm' | grep 'headers' | grep 'el8.x86_64' | grep 'https' | awk -F '"' '{print $4}' | grep 'http')
        imgurl=$(curl -s 'https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases' | grep ${github_ver_plus} | grep 'rpm' | grep -v 'devel' | grep -v 'headers' | grep -v 'Source' | grep 'el8.x86_64' | grep 'https' | awk -F '"' '{print $4}' | grep 'http')

        headurl=$(check_cn $headurl)
        imgurl=$(check_cn $imgurl)

        wget -O kernel-c8.rpm $headurl
        wget -O kernel-headers-c8.rpm $imgurl
        yum install -y kernel-c8.rpm
        yum install -y kernel-headers-c8.rpm
      else
        echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
      fi
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    if [[ ${bit} == "x86_64" ]]; then
      #github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Ubuntu_Kernel' | grep '_latest_bbrplus_' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
      #github_ver=$(curl -s 'http s://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}' | awk -F '[_]' '{print $1}')
      #echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
      kernel_version=${github_ver_plus_num}-bbrplus
      detele_kernel_head
      headurl=$(curl -s 'https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases' | grep ${github_ver_plus} | grep 'https' | grep 'amd64.deb' | grep 'headers' | awk -F '"' '{print $4}' | grep 'http')
      imgurl=$(curl -s 'https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases' | grep ${github_ver_plus} | grep 'https' | grep 'amd64.deb' | grep 'image' | awk -F '"' '{print $4}' | grep 'http')

      headurl=$(check_cn $headurl)
      imgurl=$(check_cn $imgurl)

      download_file $headurl linux-headers-d10.deb
      download_file $imgurl linux-image-d10.deb
      dpkg -i linux-image-d10.deb
      dpkg -i linux-headers-d10.deb
    elif [[ ${bit} == "aarch64" ]]; then
      #github_tag=$(curl -s 'https://api.github.com/repos/ylx2016/kernel/releases' | grep 'Ubuntu_Kernel' | grep '_latest_bbrplus_' | head -n 1 | awk -F '"' '{print $4}' | awk -F '[/]' '{print $8}')
      #github_ver=$(curl -s 'http s://api.github.com/repos/ylx2016/kernel/releases' | grep ${github_tag} | grep 'deb' | grep 'headers' | awk -F '"' '{print $4}' | awk -F '[/]' '{print $9}' | awk -F '[-]' '{print $3}' | awk -F '[_]' '{print $1}')
      #echo -e "获取的版本号为:${Green_font_prefix}${github_ver}${Font_color_suffix}"
      kernel_version=${github_ver_plus_num}-bbrplus
      detele_kernel_head
      headurl=$(curl -s 'https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases' | grep ${github_ver_plus} | grep 'https' | grep 'arm64.deb' | grep 'headers' | awk -F '"' '{print $4}')
      imgurl=$(curl -s 'https://api.github.com/repos/UJX6N/bbrplus-6.x_stable/releases' | grep ${github_ver_plus} | grep 'https' | grep 'arm64.deb' | grep 'image' | awk -F '"' '{print $4}')

      headurl=$(check_cn $headurl)
      imgurl=$(check_cn $imgurl)

      download_file $headurl linux-headers-d10.deb
      download_file $imgurl linux-image-d10.deb
      dpkg -i linux-image-d10.deb
      dpkg -i linux-headers-d10.deb
    else
      echo -e "${Error} 不支持x86_64及arm64/aarch64以外的系统 !" && exit 1
    fi
  fi

  cd .. && rm -rf bbrplusnew
  detele_kernel
  BBR_grub
  echo -e "${Tip} ${Red_font_prefix}请检查上面是否有内核信息，无内核千万别重启${Font_color_suffix}"
  echo -e "${Tip} ${Red_font_prefix}rescue不是正常内核，要排除这个${Font_color_suffix}"
  echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}BBRplus${Font_color_suffix}"
  check_kernel
  stty erase '^H' && read -p "需要重启VPS后，才能开启BBRplus，是否现在重启 ? [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo -e "${Info} VPS 重启中..."
    reboot
  fi
  #echo -e "${Tip} 内核安装完毕，请参考上面的信息检查是否安装成功及手动调整内核启动顺序"

}

#安装cloud内核
installcloud() {

  # 检查当前系统发行版
  local DISTRO=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
  local ARCH=$(uname -m)
  local VERSIONS=()
  local VERSION_MAP_FILE="/tmp/version_map.txt"

  # 检查架构并设置 IMAGE_URL 和 IMAGE_PATTERN
  local IMAGE_URL
  local IMAGE_PATTERN
  if [ "$ARCH" == "x86_64" ]; then
    IMAGE_URL="https://deb.debian.org/debian/pool/main/l/linux-signed-amd64/"
    IMAGE_PATTERN='linux-image-[^"]+cloud-amd64_[^"]+_amd64\.deb'
  elif [ "$ARCH" == "aarch64" ]; then
    IMAGE_URL="https://deb.debian.org/debian/pool/main/l/linux-signed-arm64/"
    IMAGE_PATTERN='linux-image-[^"]+cloud-arm64_[^"]+_arm64\.deb'
  else
    echo "不支持的架构：$ARCH，仅支持 x86_64 和 aarch64"
    exit 1
  fi

  echo "检测到架构 $ARCH，正在从官方源获取cloud内核版本..."

  # 获取 cloud 内核 .deb 文件列表
  local DEB_FILES_RAW=$(curl -s "$IMAGE_URL" | grep -oP "$IMAGE_PATTERN")

  # 清空临时映射文件
  >"$VERSION_MAP_FILE"

  # 提取 image 版本号并写入映射文件
  while IFS= read -r file; do
    if [[ "$file" =~ linux-image-([0-9]+\.[0-9]+(\.[0-9]+)?(-[0-9]+)?) ]]; then
      local ver="${BASH_REMATCH[1]}"
      echo "$ver:$file" >>"$VERSION_MAP_FILE"
    fi
  done <<<"$DEB_FILES_RAW"

  # 读取排序并去重后的版本号
  mapfile -t VERSIONS < <(cut -d':' -f1 "$VERSION_MAP_FILE" | sort -V -u)

  # 确保有可用版本
  if [ ${#VERSIONS[@]} -eq 0 ]; then
    echo "未找到可用的cloud内核版本，请检查网络或反馈。"
    exit 1
  fi

  echo "检测到 $DISTRO 系统（架构 $ARCH），以下是从 Debian 签名cloud内核列表中获取的版本（按从小到大排序，已去重）："
  for i in "${!VERSIONS[@]}"; do
    echo "  $i) [${VERSIONS[$i]}]"
  done

  # 默认选择最新版本
  local DEFAULT_INDEX=$((${#VERSIONS[@]} - 1))
  echo "请选择要安装的cloud内核版本（10秒后默认选择最新版本回车加速 ${VERSIONS[$DEFAULT_INDEX]}，输入'h'则使用apt安装非最新cloud及headers）："
  read -t 10 -p "输入选项编号或'h': " CHOICE

  # 检查是否使用 apt 安装 cloud 及 headers
  local USE_APT=false
  if [[ "$CHOICE" =~ ^[hH]$ ]]; then
    USE_APT=true
    if [ "$DISTRO" != "debian" ]; then
      echo "错误：使用 'h' 安装 headers 仅支持 Debian 系统，当前系统为 $DISTRO"
      exit 1
    fi
    CHOICE=$DEFAULT_INDEX
  else
    CHOICE=${CHOICE:-$DEFAULT_INDEX}
  fi

  # 验证输入
  if [[ ! "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 0 ] || [ "$CHOICE" -ge "${#VERSIONS[@]}" ]; then
    echo "无效选项，默认安装最新版本 ${VERSIONS[$DEFAULT_INDEX]}..."
    CHOICE=$DEFAULT_INDEX
  fi

  local SELECTED_VERSION="${VERSIONS[$CHOICE]}"
  local IMAGE_DEB_FILE=$(grep "^$SELECTED_VERSION:" "$VERSION_MAP_FILE" | tail -n 1 | cut -d':' -f2)

  kernel_version=$SELECTED_VERSION

  # 如果选择 'h'，使用 apt 安装 cloud 内核及 headers
  if [ "$USE_APT" = true ]; then
    echo "正在使用 apt 安装 linux-image-cloud-${ARCH} 及 headers..."
    sudo apt update
    if [ "$ARCH" == "x86_64" ]; then
      sudo apt install -y "linux-image-cloud-amd64" "linux-headers-cloud-amd64"
    elif [ "$ARCH" == "aarch64" ]; then
      sudo apt install -y "linux-image-cloud-arm64" "linux-headers-cloud-arm64"
    fi
  else
    # 下载并安装 image
    echo "正在下载 $IMAGE_URL$IMAGE_DEB_FILE ..."
    curl -O "$IMAGE_URL$IMAGE_DEB_FILE"
    echo "正在安装 $IMAGE_DEB_FILE ..."
    sudo dpkg -i "$IMAGE_DEB_FILE"
    sudo apt-get install -f -y # 解决可能的依赖问题
  fi

  # 清理下载的文件
  rm -f "$IMAGE_DEB_FILE" "$VERSION_MAP_FILE"

  detele_kernel
  BBR_grub
  echo -e "${Tip} ${Red_font_prefix}请检查上面是否有内核信息，无内核千万别重启${Font_color_suffix}"
  echo -e "${Tip} ${Red_font_prefix}rescue不是正常内核，要排除这个${Font_color_suffix}"
  echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}BBRplus${Font_color_suffix}"
  check_kernel
  stty erase '^H' && read -p "需要重启VPS后，才能开启BBRplus，是否现在重启 ? [Y/n] :" yn
  [ -z "${yn}" ] && yn="y"
  if [[ $yn == [Yy] ]]; then
    echo -e "${Info} VPS 重启中..."
    reboot
  fi

}

#启用BBR+fq
startbbrfq() {
  remove_bbr_lotserver
  echo "net.core.default_qdisc=fq" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}BBR+FQ修改成功，重启生效！"
}

#启用BBR+fq_pie
startbbrfqpie() {
  remove_bbr_lotserver
  echo "net.core.default_qdisc=fq_pie" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}BBR+FQ_PIE修改成功，重启生效！"
}

#启用BBR+cake
startbbrcake() {
  remove_bbr_lotserver
  echo "net.core.default_qdisc=cake" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}BBR+cake修改成功，重启生效！"
}

#启用BBRplus
startbbrplus() {
  remove_bbr_lotserver
  echo "net.core.default_qdisc=fq" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbrplus" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}BBRplus修改成功，重启生效！"
}

#启用Lotserver
startlotserver() {
  remove_bbr_lotserver
  if [[ "${OS_type}" == "CentOS" ]]; then
    yum install ethtool -y
  else
    apt-get update || apt-get --allow-releaseinfo-change update
    apt-get install ethtool -y
  fi
  #bash <(wget -qO- https://git.io/lotServerInstall.sh) install
  #echo | bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/1265578519/lotServer/main/lotServerInstall.sh) install
  echo | bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fei5seven/lotServer/master/lotServerInstall.sh) install
  sed -i '/advinacc/d' /appex/etc/config
  sed -i '/maxmode/d' /appex/etc/config
  echo -e "advinacc=\"1\"
maxmode=\"1\"" >>/appex/etc/config
  /appex/bin/lotServer.sh restart
  start_menu
}

#启用BBR2+FQ
startbbr2fq() {
  remove_bbr_lotserver
  echo "net.core.default_qdisc=fq" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr2" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}BBR2修改成功，重启生效！"
}

#启用BBR2+FQ_PIE
startbbr2fqpie() {
  remove_bbr_lotserver
  echo "net.core.default_qdisc=fq_pie" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr2" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}BBR2修改成功，重启生效！"
}

#启用BBR2+CAKE
startbbr2cake() {
  remove_bbr_lotserver
  echo "net.core.default_qdisc=cake" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr2" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}BBR2修改成功，重启生效！"
}

#开启ecn
startecn() {
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf

  echo "net.ipv4.tcp_ecn=1" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}开启ecn结束！"
}

#关闭ecn
closeecn() {
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf

  echo "net.ipv4.tcp_ecn=0" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}关闭ecn结束！"
}

#卸载bbr+锐速
remove_bbr_lotserver() {
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
  sysctl --system

  rm -rf bbrmod

  if [[ -e /appex/bin/lotServer.sh ]]; then
    echo | bash <(wget -qO- https://raw.githubusercontent.com/fei5seven/lotServer/master/lotServerInstall.sh) uninstall
  fi
  clear
  # echo -e "${Info}:清除bbr/lotserver加速完成。"
  # sleep 1s
}

#卸载全部加速
remove_all() {
  rm -rf /etc/sysctl.d/*.conf
  #rm -rf /etc/sysctl.conf
  #touch /etc/sysctl.conf
  if [ ! -f "/etc/sysctl.conf" ]; then
    touch /etc/sysctl.conf
  else
    cat /dev/null >/etc/sysctl.conf
  fi
  sysctl --system
  sed -i '/DefaultTimeoutStartSec/d' /etc/systemd/system.conf
  sed -i '/DefaultTimeoutStopSec/d' /etc/systemd/system.conf
  sed -i '/DefaultRestartSec/d' /etc/systemd/system.conf
  sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
  sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
  sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf

  sed -i '/soft nofile/d' /etc/security/limits.conf
  sed -i '/hard nofile/d' /etc/security/limits.conf
  sed -i '/soft nproc/d' /etc/security/limits.conf
  sed -i '/hard nproc/d' /etc/security/limits.conf

  sed -i '/ulimit -SHn/d' /etc/profile
  sed -i '/ulimit -SHn/d' /etc/profile
  sed -i '/required pam_limits.so/d' /etc/pam.d/common-session

  systemctl daemon-reload

  rm -rf bbrmod
  sed -i '/net.ipv4.tcp_retries2/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_slow_start_after_idle/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_fastopen/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
  sed -i '/fs.file-max/d' /etc/sysctl.conf
  sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
  sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
  sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
  sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
  sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
  sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_tw_recycle/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
  sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
  sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
  sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
  sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
  sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
  sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
  sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
  if [[ -e /appex/bin/lotServer.sh ]]; then
    bash <(wget -qO- https://raw.githubusercontent.com/fei5seven/lotServer/master/lotServerInstall.sh) uninstall
  fi
  clear
  echo -e "${Info}:清除加速完成。"
  sleep 1s
}

optimizing_ddcc() {
  sed -i '/net.ipv4.conf.all.rp_filter/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.d/99-sysctl.conf

  echo "net.ipv4.conf.all.rp_filter = 1" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_syncookies = 1" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_max_syn_backlog = 1024" >>/etc/sysctl.d/99-sysctl.conf
  sysctl -p
  sysctl --system
}

#更新脚本
Update_Shell() {
  local shell_file
  shell_file="$(readlink -f "$0")"
  local shell_url="https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"

  # 下载最新版本的脚本
  wget -O "/tmp/tcp.sh" "$shell_url" &>/dev/null

  # 比较本地和远程脚本的 md5 值
  local md5_local
  local md5_remote
  md5_local="$(md5sum "$shell_file" | awk '{print $1}')"
  md5_remote="$(md5sum /tmp/tcp.sh | awk '{print $1}')"

  if [ "$md5_local" != "$md5_remote" ]; then
    # 替换本地脚本文件
    cp "/tmp/tcp.sh" "$shell_file"
    chmod +x "$shell_file"

    echo "脚本已更新，请重新运行。"
    exit 0
  else
    echo "脚本是最新版本，无需更新。"
  fi
}

#切换到不卸载内核版本
gototcpx() {
  clear
  #wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
  bash <(wget -qO- https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh)
}

#切换到秋水逸冰BBR安装脚本
gototeddysun_bbr() {
  clear
  #wget https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh
  bash <(wget -qO- https://github.com/teddysun/across/raw/master/bbr.sh)
}

#切换到一键DD安装系统脚本 新手勿入
gotodd() {
  clear
  echo DD使用git.beta.gs的脚本，知悉
  sleep 1.5
  #wget -O NewReinstall.sh https://github.com/fcurrk/reinstall/raw/master/NewReinstall.sh && chmod a+x NewReinstall.sh && bash NewReinstall.sh
  bash <(wget -qO- https://github.com/fcurrk/reinstall/raw/master/NewReinstall.sh)
  #wget -qO ~/Network-Reinstall-System-Modify.sh 'https://github.com/ylx2016/reinstall/raw/master/Network-Reinstall-System-Modify.sh' && chmod a+x ~/Network-Reinstall-System-Modify.sh && bash ~/Network-Reinstall-System-Modify.sh -UI_Options
}

#切换到检查当前IP质量/媒体解锁/邮箱通信脚本
gotoipcheck() {
  clear
  sleep 1.5
  bash <(wget -qO- https://raw.githubusercontent.com/xykt/IPQuality/main/ip.sh)
  #bash <(wget -qO- https://IP.Check.Place)
}

#禁用IPv6
closeipv6() {
  clear
  sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
  sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
  sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.conf

  echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}禁用IPv6结束，可能需要重启！"
}

#开启IPv6
openipv6() {
  clear
  sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.d/99-sysctl.conf
  sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
  sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
  sed -i '/net.ipv6.conf.lo.disable_ipv6/d' /etc/sysctl.conf
  sed -i '/net.ipv6.conf.all.accept_ra/d' /etc/sysctl.conf
  sed -i '/net.ipv6.conf.default.accept_ra/d' /etc/sysctl.conf

  echo "net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}开启IPv6结束，可能需要重启！"
}

#开始菜单
start_menu() {
  clear
  echo && echo -e " TCP加速 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix} from blog.ylx.me 母鸡慎用
 ${Green_font_prefix}0.${Font_color_suffix} 升级脚本
 ${Green_font_prefix}9.${Font_color_suffix} 切换到不卸载内核版本	${Green_font_prefix}10.${Font_color_suffix} 切换到一键DD系统脚本
 ${Green_font_prefix}60.${Font_color_suffix} 切换到检查当前IP质量/媒体解锁/邮箱通信脚本
 ${Green_font_prefix}1.${Font_color_suffix} 安装 BBR原版内核
 ${Green_font_prefix}2.${Font_color_suffix} 安装 BBRplus版内核		${Green_font_prefix}5.${Font_color_suffix} 安装 BBRplus新版内核
 ${Green_font_prefix}3.${Font_color_suffix} 安装 Lotserver(锐速)内核
 ${Green_font_prefix}8.${Font_color_suffix} 安装 官方cloud内核 (支持debian系列)
 ${Green_font_prefix}11.${Font_color_suffix} 使用BBR+FQ加速		${Green_font_prefix}12.${Font_color_suffix} 使用BBR+FQ_PIE加速
 ${Green_font_prefix}13.${Font_color_suffix} 使用BBR+CAKE加速		${Green_font_prefix}14.${Font_color_suffix} 使用BBR2+FQ加速
 ${Green_font_prefix}15.${Font_color_suffix} 使用BBR2+FQ_PIE加速	${Green_font_prefix}16.${Font_color_suffix} 使用BBR2+CAKE加速
 ${Green_font_prefix}17.${Font_color_suffix} 开启ECN	 		${Green_font_prefix}18.${Font_color_suffix} 关闭ECN
 ${Green_font_prefix}19.${Font_color_suffix} 使用BBRplus+FQ版加速 
 ${Green_font_prefix}20.${Font_color_suffix} 使用Lotserver(锐速)加速 
 ${Green_font_prefix}21.${Font_color_suffix} 系统配置优化旧		${Green_font_prefix}22.${Font_color_suffix} 系统配置优化新
 ${Green_font_prefix}27.${Font_color_suffix} 系统配置优化激进方案
 ${Green_font_prefix}23.${Font_color_suffix} 禁用IPv6	 		${Green_font_prefix}24.${Font_color_suffix} 开启IPv6
 ${Green_font_prefix}25.${Font_color_suffix} 卸载全部加速	 	${Green_font_prefix}99.${Font_color_suffix} 退出脚本 
————————————————————————————————————————————————————————————————" &&
    check_status
  get_system_info
  echo -e " 系统信息: ${Font_color_suffix}$opsy ${Green_font_prefix}$virtual${Font_color_suffix} $arch ${Green_font_prefix}$kern${Font_color_suffix} "
  if [[ ${kernel_status} == "noinstall" ]]; then
    echo -e " 当前状态: ${Green_font_prefix}未安装${Font_color_suffix} 加速内核 ${Red_font_prefix}请先安装内核${Font_color_suffix}"
  else
    echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} ${Red_font_prefix}${kernel_status}${Font_color_suffix} 加速内核 , ${Green_font_prefix}${run_status}${Font_color_suffix}"

  fi
  echo -e " 当前拥塞控制算法为: ${Green_font_prefix}${net_congestion_control}${Font_color_suffix} 当前队列算法为: ${Green_font_prefix}${net_qdisc}${Font_color_suffix} "

  read -p " 请输入数字 :" num
  case "$num" in
  0)
    Update_Shell
    ;;
  1)
    check_sys_bbr
    ;;
  2)
    check_sys_bbrplus
    ;;
  3)
    check_sys_Lotsever
    ;;
  5)
    check_sys_bbrplusnew
    ;;
  8)
    check_sys_cloud
    ;;
  9)
    gototcpx
    ;;
  10)
    gotodd
    ;;
  60)
    gotoipcheck
    ;;
  11)
    startbbrfq
    ;;
  12)
    startbbrfqpie
    ;;
  13)
    startbbrcake
    ;;
  14)
    startbbr2fq
    ;;
  15)
    startbbr2fqpie
    ;;
  16)
    startbbr2cake
    ;;
  17)
    startecn
    ;;
  18)
    closeecn
    ;;
  19)
    startbbrplus
    ;;
  20)
    startlotserver
    ;;
  21)
    optimizing_system
    ;;
  22)
    optimizing_system_johnrosen1
    ;;
  23)
    closeipv6
    ;;
  24)
    openipv6
    ;;
  25)
    remove_all
    ;;
  26)
    optimizing_ddcc
    ;;
  27)
    optimizing_system_radicalizate
    ;;
  99)
    exit 1
    ;;
  *)
    clear
    echo -e "${Error}:请输入正确数字 [0-99]"
    sleep 5s
    start_menu
    ;;
  esac
}
#############内核管理组件#############

#删除多余内核
detele_kernel() {
  if [[ "${OS_type}" == "CentOS" ]]; then
    rpm_total=$(rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | wc -l)
    if [ "${rpm_total}" ] >"1"; then
      echo -e "检测到 ${rpm_total} 个其余内核，开始卸载..."
      for ((integer = 1; integer <= ${rpm_total}; integer++)); do
        rpm_del=$(rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | head -${integer})
        echo -e "开始卸载 ${rpm_del} 内核..."
        rpm --nodeps -e ${rpm_del}
        echo -e "卸载 ${rpm_del} 内核卸载完成，继续..."
      done
      echo --nodeps -e "内核卸载完毕，继续..."
    else
      echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    deb_total=$(dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | wc -l)
    if [ "${deb_total}" ] >"1"; then
      echo -e "检测到 ${deb_total} 个其余内核，开始卸载..."
      for ((integer = 1; integer <= ${deb_total}; integer++)); do
        deb_del=$(dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | head -${integer})
        echo -e "开始卸载 ${deb_del} 内核..."
        apt-get purge -y ${deb_del}
        apt-get autoremove -y
        echo -e "卸载 ${deb_del} 内核卸载完成，继续..."
      done
      echo -e "内核卸载完毕，继续..."
    else
      echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
    fi
  fi
}

detele_kernel_head() {
  if [[ "${OS_type}" == "CentOS" ]]; then
    rpm_total=$(rpm -qa | grep kernel-headers | grep -v "${kernel_version}" | grep -v "noarch" | wc -l)
    if [ "${rpm_total}" ] >"1"; then
      echo -e "检测到 ${rpm_total} 个其余head内核，开始卸载..."
      for ((integer = 1; integer <= ${rpm_total}; integer++)); do
        rpm_del=$(rpm -qa | grep kernel-headers | grep -v "${kernel_version}" | grep -v "noarch" | head -${integer})
        echo -e "开始卸载 ${rpm_del} headers内核..."
        rpm --nodeps -e ${rpm_del}
        echo -e "卸载 ${rpm_del} 内核卸载完成，继续..."
      done
      echo --nodeps -e "内核卸载完毕，继续..."
    else
      echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    deb_total=$(dpkg -l | grep linux-headers | awk '{print $2}' | grep -v "${kernel_version}" | wc -l)
    if [ "${deb_total}" ] >"1"; then
      echo -e "检测到 ${deb_total} 个其余head内核，开始卸载..."
      for ((integer = 1; integer <= ${deb_total}; integer++)); do
        deb_del=$(dpkg -l | grep linux-headers | awk '{print $2}' | grep -v "${kernel_version}" | head -${integer})
        echo -e "开始卸载 ${deb_del} headers内核..."
        apt-get purge -y ${deb_del}
        apt-get autoremove -y
        echo -e "卸载 ${deb_del} 内核卸载完成，继续..."
      done
      echo -e "内核卸载完毕，继续..."
    else
      echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
    fi
  fi
}

#更新引导
BBR_grub() {
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "6" ]]; then
      if [ -f "/boot/grub/grub.conf" ]; then
        sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
      elif [ -f "/boot/grub/grub.cfg" ]; then
        grub-mkconfig -o /boot/grub/grub.cfg
        grub-set-default 0
      elif [ -f "/boot/efi/EFI/centos/grub.cfg" ]; then
        grub-mkconfig -o /boot/efi/EFI/centos/grub.cfg
        grub-set-default 0
      elif [ -f "/boot/efi/EFI/redhat/grub.cfg" ]; then
        grub-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
        grub-set-default 0
      else
        echo -e "${Error} grub.conf/grub.cfg 找不到，请检查."
        exit
      fi
    elif [[ ${version} == "7" ]]; then
      if [ -f "/boot/grub2/grub.cfg" ]; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
        grub2-set-default 0
      elif [ -f "/boot/efi/EFI/centos/grub.cfg" ]; then
        grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
        grub2-set-default 0
      elif [ -f "/boot/efi/EFI/redhat/grub.cfg" ]; then
        grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
        grub2-set-default 0
      else
        echo -e "${Error} grub.cfg 找不到，请检查."
        exit
      fi
    elif [[ ${version} == "8" ]]; then
      if [ -f "/boot/grub2/grub.cfg" ]; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
        grub2-set-default 0
      elif [ -f "/boot/efi/EFI/centos/grub.cfg" ]; then
        grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
        grub2-set-default 0
      elif [ -f "/boot/efi/EFI/redhat/grub.cfg" ]; then
        grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
        grub2-set-default 0
      else
        echo -e "${Error} grub.cfg 找不到，请检查."
        exit
      fi
      grubby --info=ALL | awk -F= '$1=="kernel" {print i++ " : " $2}'
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    if _exists "update-grub"; then
      update-grub
    elif [ -f "/usr/sbin/update-grub" ]; then
      /usr/sbin/update-grub
    else
      apt install grub2-common -y
      update-grub
    fi
    #exit 1
  fi
}

#简单的检查内核
check_kernel() {
  if [[ -z "$(find /boot -type f -name 'vmlinuz-*' ! -name 'vmlinuz-*rescue*')" ]]; then
    echo -e "\033[0;31m警告: 未发现内核文件，请勿重启系统，不卸载内核版本选择30安装默认内核救急！\033[0m"
  else
    echo -e "\033[0;32m发现内核文件，看起来可以重启。\033[0m"
  fi
}

#############内核管理组件#############

#############系统检测组件#############

#检查系统
check_sys() {
  if [[ -f /etc/redhat-release ]]; then
    release="centos"
  elif grep -qi "debian" /etc/issue; then
    release="debian"
  elif grep -qi "ubuntu" /etc/issue; then
    release="ubuntu"
  elif grep -qi -E "centos|red hat|redhat" /etc/issue || grep -qi -E "centos|red hat|redhat" /proc/version; then
    release="centos"
  fi

  if [[ -f /etc/debian_version ]]; then
    OS_type="Debian"
    echo "检测为Debian通用系统，判断有误请反馈"
  elif [[ -f /etc/redhat-release || -f /etc/centos-release || -f /etc/fedora-release ]]; then
    OS_type="CentOS"
    echo "检测为CentOS通用系统，判断有误请反馈"
  else
    echo "Unknown"
  fi

  #from https://github.com/oooldking

  _exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
      eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
      command -v "$cmd" >/dev/null 2>&1
    else
      which "$cmd" >/dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
  }

  get_opsy() {
    if [ -f /etc/os-release ]; then
      awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release
    elif [ -f /etc/lsb-release ]; then
      awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release
    elif [ -f /etc/system-release ]; then
      cat /etc/system-release | awk '{print $1,$2}'
    fi
  }

  get_system_info() {
    opsy=$(get_opsy)
    arch=$(uname -m)
    kern=$(uname -r)
    virt_check
  }
  # from LemonBench
  virt_check() {
    if [ -f "/usr/bin/systemd-detect-virt" ]; then
      Var_VirtType="$(/usr/bin/systemd-detect-virt)"
      # 虚拟机检测
      if [ "${Var_VirtType}" = "qemu" ]; then
        virtual="QEMU"
      elif [ "${Var_VirtType}" = "kvm" ]; then
        virtual="KVM"
      elif [ "${Var_VirtType}" = "zvm" ]; then
        virtual="S390 Z/VM"
      elif [ "${Var_VirtType}" = "vmware" ]; then
        virtual="VMware"
      elif [ "${Var_VirtType}" = "microsoft" ]; then
        virtual="Microsoft Hyper-V"
      elif [ "${Var_VirtType}" = "xen" ]; then
        virtual="Xen Hypervisor"
      elif [ "${Var_VirtType}" = "bochs" ]; then
        virtual="BOCHS"
      elif [ "${Var_VirtType}" = "uml" ]; then
        virtual="User-mode Linux"
      elif [ "${Var_VirtType}" = "parallels" ]; then
        virtual="Parallels"
      elif [ "${Var_VirtType}" = "bhyve" ]; then
        virtual="FreeBSD Hypervisor"
      # 容器虚拟化检测
      elif [ "${Var_VirtType}" = "openvz" ]; then
        virtual="OpenVZ"
      elif [ "${Var_VirtType}" = "lxc" ]; then
        virtual="LXC"
      elif [ "${Var_VirtType}" = "lxc-libvirt" ]; then
        virtual="LXC (libvirt)"
      elif [ "${Var_VirtType}" = "systemd-nspawn" ]; then
        virtual="Systemd nspawn"
      elif [ "${Var_VirtType}" = "docker" ]; then
        virtual="Docker"
      elif [ "${Var_VirtType}" = "rkt" ]; then
        virtual="RKT"
      # 特殊处理
      elif [ -c "/dev/lxss" ]; then # 处理WSL虚拟化
        Var_VirtType="wsl"
        virtual="Windows Subsystem for Linux (WSL)"
      # 未匹配到任何结果, 或者非虚拟机
      elif [ "${Var_VirtType}" = "none" ]; then
        Var_VirtType="dedicated"
        virtual="None"
        local Var_BIOSVendor
        Var_BIOSVendor="$(dmidecode -s bios-vendor)"
        if [ "${Var_BIOSVendor}" = "SeaBIOS" ]; then
          Var_VirtType="Unknown"
          virtual="Unknown with SeaBIOS BIOS"
        else
          Var_VirtType="dedicated"
          virtual="Dedicated with ${Var_BIOSVendor} BIOS"
        fi
      fi
    elif [ ! -f "/usr/sbin/virt-what" ]; then
      Var_VirtType="Unknown"
      virtual="[Error: virt-what not found !]"
    elif [ -f "/.dockerenv" ]; then # 处理Docker虚拟化
      Var_VirtType="docker"
      virtual="Docker"
    elif [ -c "/dev/lxss" ]; then # 处理WSL虚拟化
      Var_VirtType="wsl"
      virtual="Windows Subsystem for Linux (WSL)"
    else # 正常判断流程
      Var_VirtType="$(virt-what | xargs)"
      local Var_VirtTypeCount
      Var_VirtTypeCount="$(echo $Var_VirtTypeCount | wc -l)"
      if [ "${Var_VirtTypeCount}" -gt "1" ]; then # 处理嵌套虚拟化
        virtual="echo ${Var_VirtType}"
        Var_VirtType="$(echo ${Var_VirtType} | head -n1)"                          # 使用检测到的第一种虚拟化继续做判断
      elif [ "${Var_VirtTypeCount}" -eq "1" ] && [ "${Var_VirtType}" != "" ]; then # 只有一种虚拟化
        virtual="${Var_VirtType}"
      else
        local Var_BIOSVendor
        Var_BIOSVendor="$(dmidecode -s bios-vendor)"
        if [ "${Var_BIOSVendor}" = "SeaBIOS" ]; then
          Var_VirtType="Unknown"
          virtual="Unknown with SeaBIOS BIOS"
        else
          Var_VirtType="dedicated"
          virtual="Dedicated with ${Var_BIOSVendor} BIOS"
        fi
      fi
    fi
  }

  #检查依赖
  if [[ "${OS_type}" == "CentOS" ]]; then
    # 检查是否安装了 ca-certificates 包，如果未安装则安装
    if ! rpm -q ca-certificates >/dev/null; then
      echo '正在安装 ca-certificates 包...'
      yum install ca-certificates -y
      update-ca-trust force-enable
    fi
    echo 'CA证书检查OK'

    # 检查并安装 curl、wget 和 dmidecode 包
    for pkg in curl wget dmidecode redhat-lsb-core; do
      if ! type $pkg >/dev/null 2>&1; then
        echo "未安装 $pkg，正在安装..."
        yum install $pkg -y
      else
        echo "$pkg 已安装。"
      fi
    done

    if [ -x "$(command -v lsb_release)" ]; then
      echo "lsb_release 已安装"
    else
      echo "lsb_release 未安装，现在开始安装..."
      yum install epel-release -y
      yum install redhat-lsb-core -y
    fi

  elif [[ "${OS_type}" == "Debian" ]]; then
    # 检查是否安装了 ca-certificates 包，如果未安装则安装
    if ! dpkg-query -W ca-certificates >/dev/null; then
      echo '正在安装 ca-certificates 包...'
      apt-get update || apt-get --allow-releaseinfo-change update && apt-get install ca-certificates -y
      update-ca-certificates
    fi
    echo 'CA证书检查OK'

    # 检查并安装 curl、wget 和 dmidecode 包
    for pkg in curl wget dmidecode; do
      if ! type $pkg >/dev/null 2>&1; then
        echo "未安装 $pkg，正在安装..."
        apt-get update || apt-get --allow-releaseinfo-change update && apt-get install $pkg -y
      else
        echo "$pkg 已安装。"
      fi
    done

    if [ -x "$(command -v lsb_release)" ]; then
      echo "lsb_release 已安装"
    else
      echo "lsb_release 未安装，现在开始安装..."
      apt-get install lsb-release -y
    fi

  else
    echo "不支持的操作系统发行版：${release}"
    exit 1
  fi
}

#检查Linux版本
check_version() {
  if [[ -s /etc/redhat-release ]]; then
    version=$(grep -oE "[0-9.]+" /etc/redhat-release | cut -d . -f 1)
  else
    version=$(grep -oE "[0-9.]+" /etc/issue | cut -d . -f 1)
  fi
  bit=$(uname -m)
  check_github
}

#检查安装bbr的系统要求
check_sys_bbr() {
  check_version
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "7" ]]; then
      installbbr
    else
      echo -e "${Error} BBR内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    apt-get --fix-broken install -y && apt-get autoremove -y
    installbbr
  else
    echo -e "${Error} BBR内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
  fi
}

check_sys_bbrplus() {
  check_version
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "7" ]]; then
      installbbrplus
    else
      echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    apt-get --fix-broken install -y && apt-get autoremove -y
    installbbrplus
  else
    echo -e "${Error} BBRplus内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
  fi
}

check_sys_bbrplusnew() {
  check_version
  if [[ "${OS_type}" == "CentOS" ]]; then
    #if [[ ${version} == "7" ]]; then
    if [[ ${version} == "7" || ${version} == "8" ]]; then
      installbbrplusnew
    else
      echo -e "${Error} BBRplusNew内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    apt-get --fix-broken install -y && apt-get autoremove -y
    installbbrplusnew
  else
    echo -e "${Error} BBRplusNew内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
  fi
}

check_sys_xanmod() {
  check_version
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "7" || ${version} == "8" ]]; then
      installxanmod
    else
      echo -e "${Error} xanmod内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    apt-get --fix-broken install -y && apt-get autoremove -y
    installxanmod
  else
    echo -e "${Error} xanmod内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
  fi
}

check_sys_cloud() {
  check_version
  if [[ "${OS_type}" == "Debian" ]]; then
    apt-get --fix-broken install -y && apt-get autoremove -y
    installcloud
  else
    echo -e "${Error} cloud内核不支持当前系统 ${release} ${version} ${bit} !" && exit 1
  fi
}

#检查安装Lotsever的系统要求
check_sys_Lotsever() {
  check_version
  bit=$(uname -m)
  if [[ ${bit} != "x86_64" ]]; then
    echo -e "${Error} 不支持x86_64以外的系统 !" && exit 1
  fi
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "6" ]]; then
      kernel_version="2.6.32-504"
      installlot
    elif [[ ${version} == "7" ]]; then
      yum -y install net-tools
      kernel_version="4.11.2-1"
      installlot
    else
      echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
    fi
  elif [[ "${release}" == "debian" ]]; then
    if [[ ${version} == "7" || ${version} == "8" ]]; then
      if [[ ${bit} == "x86_64" ]]; then
        kernel_version="3.16.0-4"
        installlot
      elif [[ ${bit} == "i386" ]]; then
        kernel_version="3.2.0-4"
        installlot
      fi
    elif [[ ${version} == "9" ]]; then
      if [[ ${bit} == "x86_64" ]]; then
        kernel_version="4.9.0-4"
        installlot
      fi
    else
      echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
    fi
  elif [[ "${release}" == "ubuntu" ]]; then
    if [[ ${version} -ge "12" ]]; then
      if [[ ${bit} == "x86_64" ]]; then
        kernel_version="4.4.0-47"
        installlot
      elif [[ ${bit} == "i386" ]]; then
        kernel_version="3.13.0-29"
        installlot
      fi
    else
      echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
    fi
  else
    echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
  fi
}

#检查系统当前状态
check_status() {
  kernel_version=$(uname -r | awk -F "-" '{print $1}')
  kernel_version_full=$(uname -r)
  net_congestion_control=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
  net_qdisc=$(cat /proc/sys/net/core/default_qdisc | awk '{print $1}')
  if [[ ${kernel_version_full} == *bbrplus* ]]; then
    kernel_status="BBRplus"
  elif [[ ${kernel_version_full} == *4.9.0-4* || ${kernel_version_full} == *4.15.0-30* || ${kernel_version_full} == *4.8.0-36* || ${kernel_version_full} == *3.16.0-77* || ${kernel_version_full} == *3.16.0-4* || ${kernel_version_full} == *3.2.0-4* || ${kernel_version_full} == *4.11.2-1* || ${kernel_version_full} == *2.6.32-504* || ${kernel_version_full} == *4.4.0-47* || ${kernel_version_full} == *3.13.0-29 || ${kernel_version_full} == *4.4.0-47* ]]; then
    kernel_status="Lotserver"
  elif [[ $(echo ${kernel_version} | awk -F'.' '{print $1}') == "4" ]] && [[ $(echo ${kernel_version} | awk -F'.' '{print $2}') -ge 9 ]] || [[ $(echo ${kernel_version} | awk -F'.' '{print $1}') == "5" ]] || [[ $(echo ${kernel_version} | awk -F'.' '{print $1}') == "6" ]]; then
    kernel_status="BBR"
  else
    kernel_status="noinstall"
  fi

  if [[ ${kernel_status} == "BBR" ]]; then
    run_status=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
    if [[ ${run_status} == "bbr" ]]; then
      run_status=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
      if [[ ${run_status} == "bbr" ]]; then
        run_status="BBR启动成功"
      else
        run_status="BBR启动失败"
      fi
    elif [[ ${run_status} == "bbr2" ]]; then
      run_status=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
      if [[ ${run_status} == "bbr2" ]]; then
        run_status="BBR2启动成功"
      else
        run_status="BBR2启动失败"
      fi
    elif [[ ${run_status} == "tsunami" ]]; then
      run_status=$(lsmod | grep "tsunami" | awk '{print $1}')
      if [[ ${run_status} == "tcp_tsunami" ]]; then
        run_status="BBR魔改版启动成功"
      else
        run_status="BBR魔改版启动失败"
      fi
    elif [[ ${run_status} == "nanqinlang" ]]; then
      run_status=$(lsmod | grep "nanqinlang" | awk '{print $1}')
      if [[ ${run_status} == "tcp_nanqinlang" ]]; then
        run_status="暴力BBR魔改版启动成功"
      else
        run_status="暴力BBR魔改版启动失败"
      fi
    else
      run_status="未安装加速模块"
    fi

  elif [[ ${kernel_status} == "Lotserver" ]]; then
    if [[ -e /appex/bin/lotServer.sh ]]; then
      run_status=$(bash /appex/bin/lotServer.sh status | grep "LotServer" | awk '{print $3}')
      if [[ ${run_status} == "running!" ]]; then
        run_status="启动成功"
      else
        run_status="启动失败"
      fi
    else
      run_status="未安装加速模块"
    fi
  elif [[ ${kernel_status} == "BBRplus" ]]; then
    run_status=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
    if [[ ${run_status} == "bbrplus" ]]; then
      run_status=$(cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}')
      if [[ ${run_status} == "bbrplus" ]]; then
        run_status="BBRplus启动成功"
      else
        run_status="BBRplus启动失败"
      fi
    elif [[ ${run_status} == "bbr" ]]; then
      run_status="BBR启动成功"
    else
      run_status="未安装加速模块"
    fi
  fi
}

#############系统检测组件#############
check_sys
check_version
[[ "${OS_type}" == "Debian" ]] && [[ "${OS_type}" == "CentOS" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
check_github
start_menu
