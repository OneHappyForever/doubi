#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

installSocat() {
yum update -y
yum install socat wget iptables-services -y
systemctl disable firewalld
systemctl enable iptables
iptables -F
service iptables save
chmod +x /etc/rc.local

read -p "Starting port:" Socatport
[[ -z "$Socatport" ]] && Socatport="10000"
echo $[${Socatport}+0] &>/dev/null
read -p "Ending port:" Socatportend
[[ -z "$Socatportend" ]] && Socatportend="20000"
echo $[${Socatportend}+0] &>/dev/null
read -p "The destination server (NOT this one):" socatip
[[ -z "${socatip}" ]] && echo "取消..." && exit 1

echo "请输入数字 来选择 Socat 转发类型:"
	echo "1. TCP"
	echo "2. UDP"
	echo "3. TCP+UDP"
	echo
	stty erase '^H' && read -p "(默认: TCP+UDP):" socattype_num
	[[ -z "${socattype_num}" ]] && socattype_num="3"
	if [[ ${socattype_num} = "1" ]]; then
		socattype="TCP"
	elif [[ ${socattype_num} = "2" ]]; then
		socattype="UDP"
	elif [[ ${socattype_num} = "3" ]]; then
		socattype="TCP+UDP"
	else
		socattype="TCP+UDP"
	fi
startSocat
ip=`wget -qO- -t1 -T2 ipinfo.io/ip`
[[ -z $ip ]] && ip="ip"

}
startSocat(){
	if [[ ${socattype} = "TCP" ]]; then
		runSocat "TCP4"
		sleep 2s
		PID=`ps -ef | grep "socat TCP4-LISTEN:${Socatport}" | grep -v grep | awk '{print $2}'`
		[[ -z $PID ]] && echo -e "${Error} Socat TCP 启动失败 !" && exit 1
		addLocal "TCP4"
		iptables -I INPUT -p tcp --dport ${Socatport} -j ACCEPT
	elif [[ ${socattype} = "UDP" ]]; then
		runSocat "UDP4"
		sleep 2s
		PID=`ps -ef | grep "socat UDP4-LISTEN:${Socatport}" | grep -v grep | awk '{print $2}'`
		[[ -z $PID ]] && echo -e "${Error} Socat UDP 启动失败 !" && exit 1
		addLocal "UDP4"
		iptables -I INPUT -p udp --dport ${Socatport} -j ACCEPT
	elif [[ ${socattype} = "TCP+UDP" ]]; then
		runSocat "TCP4"
		runSocat "UDP4"
		sleep 2s
		PID=`ps -ef | grep "socat TCP4-LISTEN:${Socatport}" | grep -v grep | awk '{print $2}'`
		PID1=`ps -ef | grep "socat UDP4-LISTEN:${Socatport}" | grep -v grep | awk '{print $2}'`
		if [[ -z $PID ]]; then
			echo -e "${Error} Socat TCP 启动失败 !" && exit 1
		else
			[[ -z $PID1 ]] && echo -e "${Error} Socat TCP 启动成功，但 UDP 启动失败 !"
			addLocal "TCP4"
			addLocal "UDP4"
			iptables -I INPUT -p tcp --dport ${Socatport} -j ACCEPT
			iptables -I INPUT -p udp --dport ${Socatport} -j ACCEPT
		fi
	fi
	Save_iptables
}

runSocat(){
	while [ ${Socatport} -le ${Socatportend} ]; do
	nohup socat $1-LISTEN:${Socatport},reuseaddr,fork $1:${socatip}:${Socatport} >> ${socat_log_file} 2>&1 &
	${Socatport}=$[${Socatport}+1]
	done
}
addLocal(){
	while [ ${Socatport} -le ${Socatportend} ]; do
	sed -i '/exit 0/d' /etc/rc.local
	echo -e "nohup socat $1-LISTEN:${Socatport},reuseaddr,fork $1:${socatip}:${Socatport} >> ${socat_log_file} 2>&1 &" >> /etc/rc.local
	[[ ${release}  == "debian" ]] && echo -e "exit 0" >> /etc/rc.local
	${Socatport}=$[${Socatport}+1]
	done
}
Save_iptables(){
	service iptables save
}

installSocat
