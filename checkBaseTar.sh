#!/bin/sh
#
# Program:
#	检测基本系统包是否存在，不存在就下载
# 
# History:
#	2011/08/23	ruohan.chen	First release
#
PATH="/sbin:/bin:/usr/sbin:/usr/bin"

BASE_TAR="http://10.253.75.1/xen/install.ks
http://10.253.75.1/xen/clean.ks"
TAR_CACHE="/tmp/base_system_tar"


function check(){
	[ -d $TAR_CACHE ] || mkdir -p $TAR_CACHE
	for i in $BASE_TAR ;do
		local file=${i##*/}
		[ -f $TAR_CACHE/$file ] || wget -O $TAR_CACHE/$file $i
	done
}

check
