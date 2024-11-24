赞助
<br>
支付宝
<br>
![20200312144201.png](https://vip1.loli.io/2020/03/12/7IJvKaTcrLBDbtz.png)

[搬瓦工在线库存查询](https://bwg.ylx.me/)


预先准备
```
centos：yum install ca-certificates wget -y && update-ca-trust force-enable
```
```
debian/ubuntu：apt-get install ca-certificates wget -y && update-ca-certificates
```
不卸载内核版本

```
wget -O tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" && chmod +x tcpx.sh && ./tcpx.sh
```

卸载内核版本
```
wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
```
关联action自动编译内核

[https://github.com/ylx2016/kernel/](https://github.com/ylx2016/kernel/)

尝试加入参数直接调用优化 ./tcpx.sh op或者./tcpx.sh op2  (不会判断系统)

ip质检
bash <(curl -Ls IP.Check.Place)

双持bbr+锐速
<br>
bbr 添加
```
echo "net.core.default_qdisc=fq" >> /etc/sysctl.d/99-sysctl.conf
```
```
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-sysctl.conf
```
```
sysctl -p
```
编辑锐速文件
```
nano /appex/etc/config
```
检测代码有BUG，如果锐速正常 运行查看
```
bash /appex/bin/lotServer.sh status | grep "LotServer"
```
检查bbr 内核默认bbr算法不会有输出
```
lsmod | grep bbr
```
检查centos安装内核
```
grubby --info=ALL|awk -F= '$1=="kernel" {print i++ " : " $2}'
```
查看当前支持TCP算法
```
cat /proc/sys/net/ipv4/tcp_allowed_congestion_control
```
查看当前运行的算法
```
cat /proc/sys/net/ipv4/tcp_congestion_control
```
查看当前队列算法
```
sysctl net.core.default_qdisc
```
命令： `uname -a`
<br>
作用： 查看系统内核版本号及系统名称

命令： `cat /proc/version`
<br>
作用： 查看目录"/proc"下version的信息，也可以得到当前系统的内核版本号及系统名称

真实队列查看？ 更改队列算法可能需要重启生效
<br>
`tc -s qdisc show`

`/etc/sysctl.d/99-sysctl.conf`
<br>
`sysctl --system`

ylx2016与chiakge、cx9208无任何关系
<br>
bbsplus算法原作者
<br>
https://blog.csdn.net/dog250/article/details/80629551
<br>
bbrplus首用名 ？
<br>
https://github.com/cx9208/bbrplus
<br>
新版bbrplus
<br>
https://github.com/UJX6N/bbrplus-5.10
<br>
xanmod官网
<br>
https://xanmod.org
<br>
Zen官网
<br>
https://liquorix.net/
<br>
锐速
<br>
https://moeclub.org/2017/03/09/14/
<br>
其他内核
<br>
https://github.com/alibaba/cloud-kernel
<br>
https://github.com/Tencent/TencentOS-kernel
<br>
官方编译好的内核
<br>
https://sourceforge.net/projects/xanmod/files/releases/current
<br>
https://elrepo.org/linux/kernel/el7/x86_64/RPMS/
<br>
https://elrepo.org/linux/kernel/el8/x86_64/RPMS/
<br>
https://kernel.ubuntu.com/~kernel-ppa/mainline/
<br>
http://mirrors.aliyun.com/alinux/2.1903/plus/x86_64/Packages/
<br>
https://mirrors.tencent.com/tlinux/2.4/tlinux/x86_64/RPMS/
<br>
https://bintray.com/multipath-tcp/mptcp_rpm/mptcp/v0.95.1#files
<br>
https://bintray.com/multipath-tcp/mptcp_deb/mptcp/v0.95.1#files

DD脚本
<br>
https://git.beta.gs/
<br>
https://www.cxthhhhh.com/network-reinstall-system-modify


服务周期
<br>
https://zh.wikipedia.org/zh/Ubuntu
<br>
https://wiki.ubuntu.com/Releases
<br>
https://wiki.debian.org/LTS
<br>
https://wiki.centos.org/zh/About/Product
