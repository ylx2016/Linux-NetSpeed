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

### XanMod 软件源

菜单 `9`～`12` 使用当前发行版代号配置 XanMod 源，例如 Debian 13 使用 `trixie`，Ubuntu 24.04 使用 `noble`。Ubuntu 衍生版优先使用自己的代号；上游未提供该代号时，尝试 `UBUNTU_CODENAME` 对应的源。

旧版脚本配置的 `deb.xanmod.org releases` 已失效，会出现 `Release 404`。重新运行新版脚本中的 XanMod 安装选项即可迁移旧源，支持 `.list` 和 deb822 `.sources`，并保留文件中的其他仓库。软件源、签名密钥或软件包安装失败时，脚本会停止，不再提示安装完成。

可用内核取决于 XanMod 上游和 CPU 等级：旧稳定版和仅支持 x86-64-v1 的 CPU 可尝试 LTS。上游安装说明：<https://xanmod.org/#apt_repository>。

回归测试使用隔离文件系统和模拟命令，不安装内核：安装 `bubblewrap` 后，在仓库目录运行 `bash tests/xanmod.sh`。

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
- <[https://git.beta.gs/](https://github.com/bin456789/reinstall/)>
- <https://www.cxthhhhh.com/network-reinstall-system-modify>

**系统服务周期**
- Ubuntu：<https://wiki.ubuntu.com/Releases> · <https://zh.wikipedia.org/zh/Ubuntu>
- Debian LTS：<https://wiki.debian.org/LTS>
- CentOS：<https://wiki.centos.org/zh/About/Product>

## 赞助

如果这个项目对你有帮助，可以请作者喝杯咖啡 ☕

**支付宝**

![支付宝赞助](https://vip1.loli.io/2020/03/12/7IJvKaTcrLBDbtz.png)

## 公益AI
- [tabitoken](https://tabitoken.com/sign-up?aff=gPYe)
- [agentrouter](https://agentrouter.org/register?aff=d3mq)

相关工具：[搬瓦工在线库存查询](https://bwg.ylx.me/)

