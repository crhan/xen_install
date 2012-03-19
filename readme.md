2011年暑假在支付宝实习时候写的快速部署 XEN 测试虚拟机系统的脚本

---

大概流程是这样, 先在虚拟机里安装好一个目标操作系统, 然后整体用 `tar`
打包, 放在内网服务器上. 接着新建虚拟机, 准备虚拟硬盘, 用 `fdisk`
给虚拟硬盘分区, 然后用 `kpartx` 将这个虚拟硬盘映射到 */dev/mapper* 下,
因为目录结构是固定的, 所以就 hard code 了这部分内容. 最后就是将下载来的
tar 包解包. 最后根据安装服务器提供的配置信息, 更新 IP 等等后续操作,
就可以使用了.

相比在采用这个方案之前的 [anaconda][1] + [kickstart][2] 方案,
省下了网络流量, 也减轻了安装服务器的压力, 在每个母鸡上下载一次 tar
包就能安装任意次虚拟机.

[1]: http://fedoraproject.org/wiki/Anaconda
[2]: http://fedoraproject.org/wiki/Anaconda/Kickstart

最最后因为架构组的 SASS 平台上线,
虚拟机的安装和管理不再需要使用这个脚本, 所以才将其放出,
一来纪念下我*年轻*时候写的脚本, 二来其中使用的在 `bash-script`
中做日志的方法还是挺有参考价值的.

**PS**: 这个脚本不能独立运行,
因为需要调用内部服务器信息管理服务器的设置. 虚拟机的数量, 硬盘的大小,
分区的方案均来自内部信息服务器的接口. 因为这个管理平台也要被替换,
所以脚本里的接口也没有做任何改动, 希望不会被怪罪.

----

运行效果图:

<a href="http://www.flickr.com/photos/cncrhan/6995527797/" title="Screen
Shot 2012-03-19 at 11.51.05 AM by Crhan, on Flickr"><img
src="http://farm8.staticflickr.com/7121/6995527797_b43e30402b_z.jpg"
width="541" height="367" alt="Screen Shot 2012-03-19 at 11.51.05
AM"></a>

<a href="http://www.flickr.com/photos/cncrhan/6849480668/" title="Screen
Shot 2012-03-19 at 12.22.41 PM by Crhan, on Flickr"><img
src="http://farm8.staticflickr.com/7134/6849480668_3d7f5b896d_b.jpg"
width="573" height="964" alt="Screen Shot 2012-03-19 at 12.22.41
PM"></a>
