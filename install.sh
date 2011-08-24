#!/bin/sh
#
# Program:
#	执行完成安装
#
# History:
#	2011/08/23	ruohan.chen	First release
#	2011/08/24	ruohan.chen	complete
#
PATH="/sbin:/bin:/usr/sbin:/usr/bin"

XEN_PREFIX="/tmp/xen_install"
XEN_CONFIG="/etc/xen/auto"
PART_TABLE="$XEN_PREFIX/part-table"

BASE_SYSTEM="http://10.253.75.1/xen/baserhsys-48-32.tar"
BASE_SYSTEM_FILE="$XEN_PREFIX/${BASE_SYSTEM##*/}"

function check_base_system_tar()
{
	[ -d $XEN_PREFIX ] || mkdir -p $XEN_PREFIX
	for i in $BASE_SYSTEM ;do
		local file=${i##*/}
		[ -f $XEN_PREFIX/$file ] || wget -O $XEN_PREFIX/$file $i
		wget -O $XEN_PREFIX/${file}.MD5 ${i}.MD5
	done

	for md5 in $XEN_PREFIX/*.MD5; do
		cd $XEN_PREFIX
		# md5 check
		if ! md5sum -c $md5; then
			rm ${md5%%.MD5}
			check_base_system_tar
		fi
	done
}

function guest_xen()
{
	local HOST=`hostname`
	local DMIDECODECMD=`which dmidecode`
	local os_servicetag=`$DMIDECODECMD | grep "Serial Number" | head -1 | awk '{print $3}'`

	wget -q -O /tmp/xen_guest  "http://10.253.33.2/xen_connect_xyx.php?&action=search_install&phyhost=$os_servicetag"

	for line in `cat /tmp/xen_guest`
	do
		xen_host=`echo "$line" | awk -F ';' '{print $1}'`
		xen_mac_1=`echo "$line" | awk -F ';' '{print $2}'`
		xen_mac_2=`echo "$line" | awk -F ';' '{print $3}'`
		xen_cpu=`echo "$line" | awk -F ';' '{print $4}'`
		xen_mem=`echo "$line" | awk -F ';' '{print $5}'`
		xen_disk=`echo "$line" | awk -F ';' '{print $6}'`

		cat << EOF > /etc/xen/auto/$xen_host
name = "$xen_host"
memory = "$xen_mem"
maxmem = "$xen_mem"
disk = [ 'phy:$xen_disk,xvda,w' ]
bootloader = "/usr/bin/pygrub"
vif = [ 'mac=$xen_mac_1,bridge=eth0', 'mac=${xen_mac_2},bridge=eth1']
vcpus = $xen_cpu
on_reboot = 'restart'
on_crash = 'restart'
EOF
	done
}

[ -d $XEN_PREFIX ] || mkdir -p $XEN_PREFIX
[ -d $XEN_PREFIX/log ] || mkdir -p $XEN_PREFIX/log

cat <<EOF > $PART_TABLE 
o
n
p
1

+250M
a
1
n
p
2

+15G
n
p
3

+2G
t
3
82
n
e
4


n
l


p
w
EOF

check_base_system_tar

guest_xen

for VM in $XEN_CONFIG/*;do
	# if current VM is running, skip it
	xm list > /tmp/xm_list
	grep "${VM##*/}" /tmp/xm_list && continue

	echo "	Installing ${VM##*/}"

	# get the disk info
	DISK=`grep -e "\bdisk\b" $VM`
	DISK=`echo $DISK |cut -d':' -f2|cut -d',' -f1`

	# get the MAC info
	MAC=`cat $VM|grep -e '\bvif\b'|cut -d"=" -f3|cut -d"," -f1`

	# make and mount lv's partition
	DISK_GROUP="${DISK%%/*}"
	DISK_NAME="${DISK##*/}"
	DISK_PATH="/dev/${DISK_GROUP}/${DISK_NAME}"
	VM_INSTALL_PATH="$XEN_PREFIX/${VM##*/}"

	# create partition table for lv
	cat $PART_TABLE| fdisk $DISK_PATH >> $XEN_PREFIX/log/fdisk

	# create device maps for partition table
	kpartx -a $DISK_PATH

	# format and label the partition
	mkfs.ext3 /dev/mapper/${DISK_NAME}p1 > $XEN_PREFIX/log/mkfs.${DISK_NAME}
	mkfs.ext3 /dev/mapper/${DISK_NAME}p2 > $XEN_PREFIX/log/mkfs.${DISK_NAME}
	mkfs.ext3 /dev/mapper/${DISK_NAME}p5 > $XEN_PREFIX/log/mkfs.${DISK_NAME}
	mkswap -L SWAP /dev/mapper/${DISK_NAME}p3
	e2label /dev/mapper/${DISK_NAME}p1 "/boot"
	e2label /dev/mapper/${DISK_NAME}p2 "/"
	e2label /dev/mapper/${DISK_NAME}p5 "/home"

	# mount
	mkdir -p ${VM_INSTALL_PATH}
	mount /dev/mapper/${DISK_NAME}p2 ${VM_INSTALL_PATH}
	mkdir ${VM_INSTALL_PATH}/boot
	mkdir ${VM_INSTALL_PATH}/home
	mount /dev/mapper/${DISK_NAME}p1 ${VM_INSTALL_PATH}/boot
	mount /dev/mapper/${DISK_NAME}p5 ${VM_INSTALL_PATH}/home
	echo "	Format and Mount complete"

	# untar the base system
	echo "	Untaring system"
	tar xf $BASE_SYSTEM_FILE -C ${VM_INSTALL_PATH}
	
	# config ip for new system
    wget -q -O /tmp/host_info  "http://10.253.33.2/xen_connect_xyx.php?action=search_host&mac=${MAC}"
    HOST_NAME=`head -n 1 /tmp/host_info |awk -F: '{print $1}'`
    IP_ADDR=`head -n 1 /tmp/host_info |awk -F: '{print $2}'`
    FISRT_THREE_NUM=`echo $IP_ADDR | awk -F. '{print $1"."$2"."$3}'`
    IP_D4=`echo $IP_ADDR | awk -F. '{print $4}'`

   if [ $IP_D4 -le 120 ];then
    cat <<EOF > ${VM_INSTALL_PATH}/etc/sysconfig/network
NETWORKING=yes
HOSTNAME=${HOST_NAME}
GATEWAY=${FISRT_THREE_NUM}.126
EOF
    cat << EOF > ${VM_INSTALL_PATH}/etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE=eth1
BOOTPROTO=none
IPADDR=${IP_ADDR}
NETMASK=255.255.255.128
NETWORK=${FISRT_THREE_NUM}.0
BROADCAST=${FISRT_THREE_NUM}.127
ONBOOT=yes
USERCTL=no
GATEWAY=${FISRT_THREE_NUM}.126
EOF
   cat << EOF > ${VM_INSTALL_PATH}/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
EOF
  else
    cat <<EOF > ${VM_INSTALL_PATH}/etc/sysconfig/network
NETWORKING=yes
HOSTNAME=${HOST_NAME}
GATEWAY=${FISRT_THREE_NUM}.254
EOF
    cat << EOF > ${VM_INSTALL_PATH}/etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE=eth1
BOOTPROTO=none
IPADDR=${IP_ADDR}
NETMASK=255.255.255.128
NETWORK=${FISRT_THREE_NUM}.128
BROADCAST=${FISRT_THREE_NUM}.255
ONBOOT=yes
USERCTL=no
GATEWAY=${FISRT_THREE_NUM}.254
EOF
   cat << EOF > ${VM_INSTALL_PATH}/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
EOF
  fi

	echo "	Configuring network complete"

	umount -lf ${VM_INSTALL_PATH}/{boot,home,}
	kpartx -d $DISK_PATH
	xm create $VM
	echo "Install ${VM##*/} complete"
done
