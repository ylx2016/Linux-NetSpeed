# Linux-NetSpeed（BBR / 锐速 一键脚本）

一键管理 Linux 下的 TCP 加速方案：BBR、BBRplus、魔改 BBR、锐速（LotServer）、XanMod / Zen 等内核，以及系统网络参数优化。

## 快速开始

不卸载现有内核，直接运行菜单：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh)
```

安装后可直接输入 `tcpx` 再次调起菜单。

### 使用提示

- **加速算法与系统优化已拆分，需要各跑一遍**：菜单 `20`（设置 BBR 等算法）和 `32`（系统优化）都要运行，不分先后。
- 支持带参数直接调用（不检测系统）：
  - `./tcpx.sh op1` → 对应菜单 `32`（系统优化）
  - `./tcpx.sh op3` → 对应菜单 `38`
- 关联 GitHub Actions 自动编译内核：<https://github.com/ylx2016/kernel/>

### IP 质量检测

```bash
bash <(curl -Ls IP.Check.Place)
```

## BBR + 锐速 双开

先添加 BBR：

```bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.d/99-sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-sysctl.conf
sysctl -p
```

再编辑锐速配置：

```bash
nano /appex/etc/config
```

查看锐速运行状态（内置检测偶有误报，可用下面命令手动确认）：

```bash
bash /appex/bin/lotServer.sh status | grep "LotServer"
```

## 常用查看命令

```bash
# 检查 BBR（内核默认 bbr 算法时 lsmod 可能无输出，属正常）
lsmod | grep bbr

# CentOS 查看已安装内核
grubby --info=ALL | awk -F= '$1=="kernel" {print i++ " : " $2}'

# 当前系统支持的 TCP 算法
cat /proc/sys/net/ipv4/tcp_allowed_congestion_control

# 当前生效的拥塞控制算法
cat /proc/sys/net/ipv4/tcp_congestion_control

# 当前队列算法（qdisc）
sysctl net.core.default_qdisc

# 真实队列查看（更改队列算法可能需重启生效）
tc -s qdisc show

# 内核版本与系统信息
uname -a
cat /proc/version

# 重新加载 sysctl 配置（主配置：/etc/sysctl.d/99-sysctl.conf）
sysctl --system
```

## 声明

ylx2016 与 chiakge、cx9208 无任何关系。

## 参考与内核来源

**BBRplus / 魔改算法**
- 原作者文章：<https://blog.csdn.net/dog250/article/details/80629551>
- bbrplus 首用：<https://github.com/cx9208/bbrplus>
- 新版 bbrplus：<https://github.com/UJX6N/bbrplus-5.10>

**内核发行版**
- XanMod 官网：<https://xanmod.org>
- Zen / Liquorix：<https://liquorix.net/>
- 锐速说明：<https://moeclub.org/2017/03/09/14/>
- 阿里 Cloud Kernel：<https://github.com/alibaba/cloud-kernel>
- TencentOS Kernel：<https://github.com/Tencent/TencentOS-kernel>

**预编译内核下载**
- XanMod：<https://sourceforge.net/projects/xanmod/files/releases/current>
- ELRepo el7：<https://elrepo.org/linux/kernel/el7/x86_64/RPMS/>
- ELRepo el8：<https://elrepo.org/linux/kernel/el8/x86_64/RPMS/>
- Ubuntu mainline：<https://kernel.ubuntu.com/~kernel-ppa/mainline/>
- 阿里云 alinux：<http://mirrors.aliyun.com/alinux/2.1903/plus/x86_64/Packages/>
- 腾讯 tlinux：<https://mirrors.tencent.com/tlinux/2.4/tlinux/x86_64/RPMS/>

**系统重装（DD）脚本**
- <https://git.beta.gs/>
- <https://www.cxthhhhh.com/network-reinstall-system-modify>

**系统服务周期**
- Ubuntu：<https://wiki.ubuntu.com/Releases> · <https://zh.wikipedia.org/zh/Ubuntu>
- Debian LTS：<https://wiki.debian.org/LTS>
- CentOS：<https://wiki.centos.org/zh/About/Product>

## 赞助

如果这个项目对你有帮助，可以请作者喝杯咖啡 ☕

**支付宝**

![支付宝赞助](https://vip1.loli.io/2020/03/12/7IJvKaTcrLBDbtz.png)

相关工具：[搬瓦工在线库存查询](https://bwg.ylx.me/)
