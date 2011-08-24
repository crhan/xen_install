#!/bin/bash

MAC=`ifconfig | grep eth0 | awk '{print $5}'`

get_host_info() {
    wget -q -O /tmp/host_info  "http://10.253.33.2/xen_connect_xyx.php?action=search_host&mac=${MAC}"

}

config_ip() {
    HOST_NAME=`head -n 1 /tmp/host_info |awk -F: '{print $1}'`
    IP_ADDR=`head -n 1 /tmp/host_info |awk -F: '{print $2}'`
    FISRT_THREE_NUM=`echo $IP_ADDR | awk -F. '{print $1"."$2"."$3}'`
    IP_D4=`echo $IP_ADDR | awk -F. '{print $4}'`
    hostname $HOST_NAME

   if [ $IP_D4 -le 120 ];then
    cat <<EOF > $XEN_PREFIX/etc/sysconfig/network
NETWORKING=yes
HOSTNAME=${HOST_NAME}
GATEWAY=${FISRT_THREE_NUM}.126
EOF
    cat << EOF > $XEN_PREFIX/etc/sysconfig/network-scripts/ifcfg-eth1
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
   cat << EOF > $XEN_PREFIX/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
EOF
  else
    cat <<EOF > $XEN_PREFIX/etc/sysconfig/network
NETWORKING=yes
HOSTNAME=${HOST_NAME}
GATEWAY=${FISRT_THREE_NUM}.254
EOF
    cat << EOF > $XEN_PREFIX/etc/sysconfig/network-scripts/ifcfg-eth1
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
   cat << EOF > $XEN_PREFIX/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
EOF
  fi

 }

get_host_info
config_ip
