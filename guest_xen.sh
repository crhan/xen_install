#!/bin/bash
HOST=`hostname`
DMIDECODECMD=`which dmidecode`
os_servicetag=`$DMIDECODECMD | grep "Serial Number" | head -1 | awk '{print $3}'`


if [ ! -d /etc/xen/preinstall ]
then
   mkdir -p /etc/xen/preinstall

fi

#wget -q -O /tmp/xen_guest  "http://10.253.33.2/xen_connect.php?&action=search_install&tag=$os_servicetag"
wget -q -O /tmp/xen_guest  "http://10.253.33.2/xen_connect_xyx.php?&action=search_install&phyhost=$os_servicetag"

for line in `cat /tmp/xen_guest`
do
  #TAG=`echo "$line" | grep -c 10`
  #if [ $TAG -gt 0 ] ;then
   xen_host=`echo "$line" | awk -F ';' '{print $1}'`
   xen_mac_1=`echo "$line" | awk -F ';' '{print $2}'`
   xen_mac_2=`echo "$line" | awk -F ';' '{print $3}'`
   xen_cpu=`echo "$line" | awk -F ';' '{print $4}'`
   xen_mem=`echo "$line" | awk -F ';' '{print $5}'`
   xen_disk=`echo "$line" | awk -F ';' '{print $6}'`
   
cat << EOF > /etc/xen/preinstall/$xen_host
kernel = "/boot/xen/vmlinuz"
ramdisk = "/boot/xen/initrd.img"
extra = "text ksdevice=eth0 ks=nfs:10.253.32.2:/home/iso/rh48-32/rh48.xen.new.cfg"
name = "$xen_host"
memory = "$xen_mem"
maxmem = "$xen_mem"
disk = [ 'phy:$xen_disk,xvda,w' ]
vif = [ 'mac=${xen_mac_1},bridge=eth0', 'mac=${xen_mac_2},bridge=eth1']
vcpus = $xen_cpu
on_reboot = 'destroy'
on_crash = 'destroy'
EOF
# cat << EOF > /etc/xen/preinstall/$xen_host
#kernel = "/boot/xen/rh55-64/vmlinuz"
#ramdisk = "/boot/xen/rh55-64/initrd.img"
#extra = "text ksdevice=eth0 ks=nfs:10.253.32.2:/home/iso/rh55-64/rh55-64.xen.new.cfg"
#name = "$xen_host"
#memory = "$xen_mem"
#maxmem = "$xen_mem"
#disk = [ 'phy:$xen_disk,xvda,w' ]
#vif = [ 'mac=${xen_mac_1},bridge=eth0', 'mac=${xen_mac_2},bridge=eth1']
#vcpus = $xen_cpu
#on_reboot = 'destroy'
#on_crash = 'destroy'
#EOF
#fi
done 

for line in `cat /tmp/xen_guest`
do
  #TAG=`echo "$line" | grep -c 10`
  #if [ $TAG -gt 0 ] ;then
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
  #fi
done  

