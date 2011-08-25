#!/bin/sh
#
# Program:
#	执行完成安装
#
# Author:
#	ruohan.chen		crhan123@gmail.com
#
# History:
#	2011/08/23	ruohan.chen	First release
#	2011/08/24	ruohan.chen	complete
#
version="v1.1"
PATH="/sbin:/bin:/usr/sbin:/usr/bin"

XEN_PREFIX="/tmp/xen_install"
XEN_CONFIG="/etc/xen/auto"
LOG="$XEN_PREFIX/log/install.log"
PART_TABLE="$XEN_PREFIX/part-table"

SYSTEM_55_64="http://10.253.75.1/xen/baserhsys-55-64.tar"
SYSTEM_48_32="http://10.253.75.1/xen/baserhsys-48-32.tar"
BASE_SYSTEM=$SYSTEM_48_32
BASE_SYSTEM_FILE="$XEN_PREFIX/${BASE_SYSTEM##*/}"
STDOUT=6
STDERR=7
# backup STDOUT and STDERR
exec 6>&1
exec 7>&2

quietopt=false
color=true
unset myaction

BLUE="[34;01m"
CYAN="[36;01m"
CYANN="[36m"
GREEN="[32;01m"
RED="[31;01m"
PURP="[35;01m"
OFF="[0m"

# synopsis: qprint "message"
qprint() {
    $quietopt || echo "$*" >&$STDERR
}

# synopsis: mesg "message"
# Prettily print something to stderr, honors quietopt
mesg() {
    qprint " ${GREEN}*${OFF} $*"
    echo "`date "+%h %d %H:%M:%S"` `hostname`: $*" >> $LOG
}

# synopsis: warn "message"
# Prettily print a warning to stderr
warn() {
    echo " ${RED}* Warning${OFF}: $*" >&$STDERR
}

# synopsis: error "message"
# Prettily print an error
error() {
    echo " ${RED}* Error${OFF}: $*" >&$STDERR
}

# synopsis: die "message"
# Prettily print an error, then abort
die() {
    [ -n "$1" ] && error "$*"
    qprint
    exit 1
}

# synopsis: versinfo
# Display the version information
versinfo() {
    qprint
    qprint "   Copyright ${CYANN}2011${OFF} Alipay, Inc;"
    qprint
}

# synopsis: helpinfo
# Display the help infomation.
helpinfo() {
	cat >&$STDOUT <<EOHELP
SYNOPSIS
    $(basename $0) [ ${GREEN}-hVr${OFF} ] [ ${GREEN}--version --help --nocolor --quite
    --reinstall${OFF} ] 
    < ${GREEN}--system${OFF} ${CYAN}mark${OFF} >

    ${GREEN}--reinstall${OFF} ${CYAN}hostfile${OFF}
        Reinstall VMs in given hostfile

    ${GREEN}--nocolor${OFF}
        Disable color hilighting for non ANSI-compatible terms.

    ${GREEN}-h${OFF} ${GREEN}--help${OFF}
        Show help that looks remarkably like this man-page. As of 2.6.10,
        help is sent to stdout so it can be easily piped to a pager.

    ${GREEN}-V${OFF} ${GREEN}--version${OFF}
        Show version information.

EOHELP
}

# synopsis: setaction
# Sets $myaction or dies if $myaction is already set
setaction() {
    if [ -n "$myaction" ]; then
        die "you can't specify --$myaction and --$1 at the same time"
    else
        myaction="$1"
    fi
}

# synopsis: prepare_disk
# pre_condition: gather_info() is run before it
# use var defined in gather_info() to format label and mount disks
prepare_disk() {
	# create partition table for lv
	cat $PART_TABLE| fdisk $DISK_PATH

	# create device maps for partition table
	kpartx -a $DISK_PATH

	# format and label the partition
	mkfs.ext3 /dev/mapper/${DISK_NAME}p1
	mkfs.ext3 /dev/mapper/${DISK_NAME}p2
	mkfs.ext3 /dev/mapper/${DISK_NAME}p5
	mkswap -L SWAP /dev/mapper/${DISK_NAME}p3
	e2label /dev/mapper/${DISK_NAME}p1 "/boot"
	e2label /dev/mapper/${DISK_NAME}p2 "/"
	e2label /dev/mapper/${DISK_NAME}p5 "/home"

	# mount
	[ -d ${VM_INSTALL_PATH} ] || mkdir -p ${VM_INSTALL_PATH}
	mount /dev/mapper/${DISK_NAME}p2 ${VM_INSTALL_PATH}
	[ -d ${VM_INSTALL_PATH}/boot ] || mkdir ${VM_INSTALL_PATH}/boot
	[ -d ${VM_INSTALL_PATH}/home ] || mkdir ${VM_INSTALL_PATH}/home
	mount /dev/mapper/${DISK_NAME}p1 ${VM_INSTALL_PATH}/boot
	mount /dev/mapper/${DISK_NAME}p5 ${VM_INSTALL_PATH}/home
	mesg "Format and Mount complete"
}

# synopsis: unmount_volumn
# umount current volumn
umount_volumn(){
	sleep 1
	umount -lf ${VM_INSTALL_PATH}/{boot,home,} 2>/dev/null
	kpartx -d $DISK_PATH 2>/dev/null
}

check_base_system_tar() {
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

guest_xen() {
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

# synopsis: gather_info
# pre_condition: $VM is set to a config file for xen
# update the vars to be used and REDIRECT stdout and stderr
gather_info() {
  VM_NAME=${VM##*/}

	# get the disk info
	DISK=`grep -e "\bdisk\b" $VM`
	DISK=`echo $DISK |cut -d':' -f2|cut -d',' -f1`
	DISK_GROUP="${DISK%%/*}"
	DISK_NAME="${DISK##*/}"
	DISK_PATH="/dev/${DISK_GROUP}/${DISK_NAME}"
	VM_INSTALL_PATH="$XEN_PREFIX/${VM_NAME}"

	# get mac info
	MAC=`cat $VM|grep -e '\bvif\b'|cut -d"=" -f3|cut -d"," -f1`

  # redirect STDOUT and STDERR
	VM_LOG="$XEN_PREFIX/log/${VM_NAME}.log"
	VM_ERROR_LOG="$XEN_PREFIX/log/${VM_NAME}.error"
  exec 1>>$VM_LOG
  exec 2>>$VM_ERROR_LOG

	mesg "Installing ${VM_NAME}"
}

# synopsis: untar_system
# untar tar archive to install path
untar_system() {
	mesg "Untaring system"
	tar xf $BASE_SYSTEM_FILE -C ${VM_INSTALL_PATH}
}

# synopsis: config_ip
# configure new IP and hostname
config_ip() {
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
	mesg "Configuring network complete"
}

# synopsis: start_vm
# nothing to say
start_vm() {
	xm create $VM
	echo "Install ${VM_NAME} complete"
}

###################################
#                                 #
#            Main Part            #
#                                 #
###################################


# Parse the command-line
while [ -n "$1" ]; do
	case "$1" in
		--help|-h)
			setaction help
			;;
		--reinstall)
			shift
			setaction reinstall
			if [ -n "$1" ]; then
				REINSTALL_FILE=$1;
				[ -f "$REINSTALL_FILE" ] || die "Reinstall file $REINSTALL_FILE does not exist."
			else
				die "--reinstall requires a file with hostname in each line."
			fi
			;;
		--version|-V)
			setaction version
			;;
		--nocolor)
			color=false
			;;
	esac
	shift
done

# default action is install all none active vm
myaction=${myaction-install}

# disable color if necessary
$color || unset BLUE CYAN CYANN GREEN PURP OFF RED

qprint
mesg "${PURP}XEN_VM_Auto_Install ${OFF}${CYANN}${version}${OFF} ~ ${GREEN}http://www.alipay.com${OFF}"
[ "$myaction" = version ] && { versinfo; exit 0; }
[ "$myaction" = help ] && { versinfo; helpinfo; exit 0; }

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

# redirect all STDOUT and STDERR
exec 1>$XEN_PREFIX/log/pre.log
exec 2>$XEN_PREFIX/log/pre.error

check_base_system_tar
guest_xen

# Set up traps
# umount volumn when catching signal 1 9 15
trap 'umount_volumn; exit 1' 1 9 15

case "$myaction" in
    install)
        XEN_CONFIG_FILES=`ls $XEN_CONFIG`
        ;;
    reinstall)
        XEN_CONFIG_FILES=`cat $REINSTALL_FILE`
        ;;
    *)
        die "Unknown action by $myaction."
esac

for VM in $XEN_CONFIG_FILES ;do
    xm list > /tmp/xm_list
    case "$myaction" in
        install)
            # if current VM is running, skip it
            grep "${VM_NAME}" /tmp/xm_list && continue
            ;;
        reinstall)
            if grep "${VM_NAME}" /tmp/xm_list; then
                xm destory ${VM_NAME} || die "destory ${VM_NAME} failed"
            fi
            ;;
    esac

  # gather_info befor each install stage
  gather_info
  prepare_disk
  untar_system
	config_ip
	umount_volumn
	start_vm

	exec 1>>$XEN_PREFIX/log/unexpected.log
	exec 2>>$XEN_PREFIX/log/unexpected.error
done

