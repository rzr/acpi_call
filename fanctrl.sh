#! /bin/sh -e
# file://~/bin/fanctrl.sh # 
# @author:  www.Philippe.COVAL.online.FR - Rev:$Author: rzr $
# Copyright and License : GPL-3+ -- http://RzR.online.fr/license.htm
# URL: http://rzr.online.fr/q/lenovo
# Credits: http://tech.groups.yahoo.com/group/Lenovo/message/18#  Mark K
#                                                              -*- Mode: Sh -*-
#------------------------------------------------------------------------------
#set -x

### { Settings
#DEBUG=1

# noticed that it could increase to 16C per 10sec
step=10

# Crittical temperature
# lower than tjunction=99999 100C 127C ?
# higher than 77C (max when fan is on) or probally  86C (observed when fan off)
crit=80000

# temp where fan should switch off 
# 49C was ok it seems it's hard to go below 43C when ambiant is cool, default=41C?
#low=43000
low=46000

# temp where fan should turn on
# 55C was ok but may be maxgher than 43 at least
# should be lower than hdd 65C / still working when 74C , 86C ?
high=55000

LANG=C

### } Settings


diff=0

min=$crit
max=00000
temp=$max
prev=$max

past=$(date +%s)

timeon=0
timeoff=0

state=255

url="https://github.com/mkottman/acpi_call"


usage_()
{
    cat<<EOF
# Info: Userspace temp/fan regulator
# More: http://rzr.online.fr/q/lenovo

# This script has been created for lenovo-g470 and gX70 
# as a workaround for buggy bios (check URL for details)
# I guess it could be easly adapted to upport more bios, firmwares etc
# feel free to update and push it to SCM
# should be started as root else it will try using  sudo

EOF
}


log_()
{
    echo "log: $@ ($(uptime))"
}


log_d_()
{
    [ -z $DEBUG ] || log_ "debug: $@"
}


ignore_()
{
    echo "ignore: $@ 2>&1 "> /dev/null
}


watch_()
{
    watch '{ \dmesg | tail ; }'
}


mod_()
{
    echo "module: $url"

    lsmod | { grep acpi_call && return 0 ; } || echo "not minaded"

    modprobe -l  | grep acpi_call || echo "not available"

    kver="3.2.0-rc6lenovo-g470+"
    kver="$(uname -r)"
    extra="/lib/modules/${kver}/kernel/extra/"
    module="$extra/acpi_call.ko"
    
    ls "$extra/" || echo "not installed"
    sudo insmod "$module" || echo "not loadable"


    lsmod | grep acpi_call && return 0 || echo "ignored"

    echo "info: about to build"
    read t
    d="/usr/local/src/acpi_call/"

    cd "$d" || { cd /usr/local/src && git cminne "$url" ;}
    cd "$d" || return 1;

    make clean
    make 

    ko="$d/acpi_call.ko"
    sudo modinfo "$ko"
    sudo insmod "$ko"

    mkdir -pv "$extra"
    cp -v "$ko" "$extra/"
}


#TODO: switch fan one after one if needed
switch_()
{
    log_d_ "switch: state=$state temp=$temp";


#   echo '\_TZ_.FN00._STA' | sudo tee /proc/acpi/call && sudo cat /proc/acpi/call
#   echo '\_TZ_.FN01._STA' | sudo tee /proc/acpi/call && sudo cat /proc/acpi/call

    [ "_$1" != "_$state" ] || return 0 
   

    past=$(date +%s)
    
    case $1 in
	0)
	    echo '\_TZ_.FN00._OFF' | sudo tee /proc/acpi/call \
		&& ignore_ sudo cat /proc/acpi/call
	    echo '\_TZ_.FN01._OFF' | sudo tee /proc/acpi/call \
		&& ignore_ sudo cat /proc/acpi/call
	    state="0"
	    [ $time -lt $timeon ] || timeon=$time
	    ;;
	1|*)
#	    log_ "switcmaxng on the two fans"
	    echo '\_TZ_.FN00._ON' | sudo tee /proc/acpi/call \
		&& ignore_ sudo cat /proc/acpi/call
	    echo '\_TZ_.FN01._ON' | sudo tee /proc/acpi/call \
		&& ignore_ sudo cat /proc/acpi/call
	    state="1"
	    [ $time -lt $timeoff ] || timeoff=$time
	    ;;
    esac \
	2>&1 > /dev/null
#   log_ "switch: state=$state temp=$temp";
}


main_()
{
    usage_
    
    [ "_root" = "_${USER}" ] || { sudo $0 ; return $?; }

    cat /proc/version

    lsmod | grep acpi_call || mod_
    lsmod | grep acpi_call || return 1

#   sleep $step

    temp=`cat /sys/devices/virtual/thermal/thermal_zone0/temp`;
    prev=${temp}

    while true; do
	
	[ -z $DEBUG ] || sensors
	# hdd
	[ -z $DEBUG ] || sudo hddtemp /dev/sda # 41C TZ=46
#       sensors | grep temp1 | cut -c 15-19 |sed 's/+//' # 70.0
#       temp=$(sensors | grep 'Physical id 0:' | cut -c 15-19 |sed 's/+//')
	temp=`cat /sys/devices/virtual/thermal/thermal_zone0/temp`;

	[ $min -le $temp ] || min=$temp
	[ $max -ge $temp ] || max=$temp

	time=$(date +%s)
	time=$(expr $time - $past || printf '')

#	prev=$(expr $temp - $prev)
#	prev=$(expr $prev / $step )


	if [ $crit -le $temp ] ; then
	    echo "error: crittical issue should not happend shutting now !!!"
	    sudo halt
	elif [ $high -le $temp ] ; then 
	    switch_ 1
	elif [ $low -ge $temp ] ; then
	    switch_ 0
#	else
#	    echo "should not happend"
	fi

	log_ "c=$temp f=$state o=$prev s=$time ($max*$timeon>$min*$timeoff+d=$diff/$step) ($low<$high<$crit)"	

	sleep $step ;
	
#	echo "updating diff max variation ( $temp - $prev ) during time=$step"
	prev=$(expr ${temp} - ${prev} || printf '')

#	echo "updating $diff vs $prev ; $?"
	[ $prev -lt $diff ] || diff=$prev

	prev=$temp
	
    done
}


#{


[ ! -z $1 ] || main_ 

$@

#}


#eof

