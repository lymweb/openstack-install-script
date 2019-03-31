#!/bin/bash
###mysql password
MYSQL_PASSWD='yourpassword'
KEYSTONE_DB_PASSWD='yourpassword'
CINDER_DB_PASSWD='yourpassword'
NOVA_DB_PASSWD='yourpassword'
NEUTRON_DB_PASSWD='yourpassword'
GLANCE_DB_PASSWD='yourpassword'
HEAT_DB_PASSWD='yourpassword'
CEILOMETER_PASS='yourpassword'
GNOCCHI_DBPASS='yourpassword'
SAHARA_DB_PASSWD='yourpassword'
#user password
ADMIN_PASS='yourpassword'
DEMO_PASSWD='yourpassword'
ADMIN_TOKEN='yourpassword'
NOVA_PLACEMENT_PASS='yourpassword'
BARBICAN_DB_PASSWD='yourpassword'
MISTRAL_DB_PASSWD='yourpassword'
TACKER_DB_PASSWD='yourpassword'
#network
Ext_IP='10.10.27'
Ext_Gateway='10.10.26.1'
Internal_IP='192.168.1'
FLAT_IP_start='10.10.26.33'
FLAT_IP_end='10.10.26.62'
PROVIDER_NETWORK_GATEWAY='10.10.26.1'
PROVIDER_NETWORK_CIDR='10.10.26.0/23'
RABBIT_PASS='yourpassword'
METADATA_SECRET='yourpassword' #/etc/neutron/metadata_agent.ini suitable secret for the metadata proxy.

#qemu or kvm
VIRT_TYPE="kvm"

#检测ip地址
eth0name=$(ifconfig |grep 10.10 -B 1 |head -n 1 |awk '{print $1}')	&& echo eth0name=	$eth0name
eth0ip=$(ifconfig $eth0name | grep "inet addr:" | awk '{print $2}' | cut -c 6-) && echo eth0ip=	$eth0ip
eth0ip_last=${eth0ip##*.}		&& echo eth0ip_last=	$eth0ip_last
eth1ip=192.168.1.$eth0ip_last && echo $eth1ip 
let eth0ip_lastnum=$eth0ip_last
case $eth0ip_lastnum in           #Replace the last number of your ip address here
	231|10|31|21 )role=controller;;
	232 )role=network;role_id=$eth0ip_lastnum;;
	233|234|14|35 )role=objectstorage;role_id=$eth0ip_lastnum;;
	235|236|240|11|12|13|15|16|17|18|19|22|23|24|25|32|33|34|36|37|38|39|40|41|42|43|44|45 )role=compute;role_id=$eth0ip_lastnum;;
	*) echo ip not in range;;
esac
echo role is $role
echo $role_id
echo role is $role$role_id

if [ $(id -u) != "0" ];then
    echo "You must be root to run this script!\n"
    exit 1
fi


base-devel(){    #初始化
echo '
nameserver 180.76.76.76
'>>/etc/resolv.conf
apt update
apt install software-properties-common -y
add-apt-repository cloud-archive:pike -y
apt update && apt dist-upgrade -y
apt install -y aptitude git vim curl sudo apt-show-versions python-openstackclient
if [[ $(cat /etc/network/interfaces |grep 10.10) ]];then echo network already setup; else 
cp /etc/network/interfaces /etc/network/interfaces.bak
echo 'source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
auto '$eth0name'
  iface '$eth0name' inet static
  address '$eth0ip'
  netmask 255.255.254.0
  gateway '$Ext_Gateway'
  dns-nameservers 180.76.76.76
auto eno2
  iface eno2 inet static
  address 192.168.1.'$eth0ip_last'
  netmask 255.255.254.0'>/etc/network/interfaces   #网卡名称需要根据实际情况修改
  /etc/init.d/networking restart                   #重启网络服务
fi
cp /etc/hosts /etc/hosts.bak #修改host
echo	'127.0.0.1 '$role$role_id'
10.10.27.31 controller
10.10.27.32 compute32
10.10.27.33 compute33
10.10.27.34 compute34
10.10.27.35 objectstorage35
10.10.27.36 compute36
10.10.27.37 compute37
10.10.27.38 compute38
10.10.27.39 compute39
10.10.27.40 compute40
10.10.27.41 compute41
10.10.27.42 compute42
10.10.27.43 compute43
10.10.27.44 compute44
10.10.27.45 compute45
# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
' >/etc/hosts                            # 这里是每次安装必改部分
hostname $role$role_id					 #修改主机名
echo $role$role_id >/etc/hostname
}


controller-base(){
pip install sqlalchemy==1.1.15   #mysql 5.7版本后的特殊要求
DEBIAN_FRONTEND=noninteractive aptitude install -q -y mysql-server   #bash安装mysql免交互输密码
mysqladmin -u root password $MYSQL_PASSWD  				  #设置mysql密码
cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.bak
sed -i "s/127.0.0.1/0.0.0.0/g" /etc/mysql/mysql.conf.d/mysqld.cnf
if [ $(cat /etc/mysql/mysql.conf.d/mysqld.cnf|grep collation-server|wc -l) = 0 ]; then first_start=true
sed -i -e "/bind-address/ a\\default-storage-engine = innodb\ninnodb_file_per_table = on\ncollation-server = utf8_general_ci\nmax_connections = 4096\ncharacter-set-server = utf8" /etc/mysql/mysql.conf.d/mysqld.cnf
fi
service mysql restart
apt install rabbitmq-server memcached python-memcache -y 
rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
sed -i "s/127.0.0.1/0.0.0.0/g" /etc/memcached.conf
service memcached restart
fi
}


controller-mysql(){
##create database
mysql -uroot -p$MYSQL_PASSWD << EOF
DROP DATABASE IF EXISTS keystone;CREATE DATABASE keystone;
DROP DATABASE IF EXISTS glance;CREATE DATABASE glance;
DROP DATABASE IF EXISTS nova;CREATE DATABASE nova;
DROP DATABASE IF EXISTS nova_api;CREATE DATABASE nova_api;
DROP DATABASE IF EXISTS nova_cell0;CREATE DATABASE nova_cell0;
DROP DATABASE IF EXISTS placement;CREATE DATABASE placement;
DROP DATABASE IF EXISTS cinder;CREATE DATABASE cinder;
DROP DATABASE IF EXISTS neutron;CREATE DATABASE neutron;
DROP DATABASE IF EXISTS heat;CREATE DATABASE heat;
DROP DATABASE IF EXISTS gnocchi;CREATE DATABASE gnocchi;
DROP DATABASE IF EXISTS sahara;CREATE DATABASE sahara;
DROP DATABASE IF EXISTS saharadb;CREATE DATABASE saharadb;

DROP DATABASE IF EXISTS barbican;CREATE DATABASE barbican;
DROP DATABASE IF EXISTS mistral;CREATE DATABASE mistral;
DROP DATABASE IF EXISTS tacker;CREATE DATABASE tacker;

GRANT ALL ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DB_PASSWD';
GRANT ALL ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DB_PASSWD';
GRANT ALL ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DB_PASSWD';
GRANT ALL ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DB_PASSWD';
GRANT ALL ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DB_PASSWD';
GRANT ALL ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DB_PASSWD';
GRANT ALL ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DB_PASSWD';
GRANT ALL ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DB_PASSWD';
GRANT ALL ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DB_PASSWD';
GRANT ALL ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DB_PASSWD';
GRANT ALL ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$NOVA_DB_PASSWD';
GRANT ALL ON placement.* TO 'placement'@'%' IDENTIFIED BY '$NOVA_DB_PASSWD';
GRANT ALL ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DB_PASSWD';
GRANT ALL ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DB_PASSWD';
GRANT ALL ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DB_PASSWD';
GRANT ALL ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DB_PASSWD';
GRANT ALL ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '$HEAT_DB_PASSWD';
GRANT ALL ON heat.* TO 'heat'@'%' IDENTIFIED BY '$HEAT_DB_PASSWD';
GRANT ALL PRIVILEGES ON gnocchi.* TO 'gnocchi'@'localhost' IDENTIFIED BY '$GNOCCHI_DBPASS';
GRANT ALL PRIVILEGES ON gnocchi.* TO 'gnocchi'@'%' IDENTIFIED BY '$GNOCCHI_DBPASS';

GRANT ALL PRIVILEGES ON sahara.* TO 'sahara'@'localhost' IDENTIFIED BY '$SAHARA_DB_PASSWD';
GRANT ALL PRIVILEGES ON sahara.* TO 'sahara'@'%' IDENTIFIED BY '$SAHARA_DB_PASSWD';
GRANT ALL PRIVILEGES ON saharadb.* TO 'saharadb'@'localhost' IDENTIFIED BY '$SAHARA_DB_PASSWD';
GRANT ALL PRIVILEGES ON saharadb.* TO 'saharadb'@'%' IDENTIFIED BY '$SAHARA_DB_PASSWD';
GRANT ALL PRIVILEGES ON saharadb.* TO 'sahara-common'@'localhost' IDENTIFIED BY '$SAHARA_DB_PASSWD';
GRANT ALL PRIVILEGES ON saharadb.* TO 'sahara-common'@'%' IDENTIFIED BY '$SAHARA_DB_PASSWD';
GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '$MYSQL_PASSWD';
GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'%' IDENTIFIED BY '$MYSQL_PASSWD';

GRANT ALL PRIVILEGES ON barbican.* TO 'barbican'@'localhost' IDENTIFIED BY '$BARBICAN_DB_PASSWD';
GRANT ALL PRIVILEGES ON barbican.* TO 'barbican'@'%' IDENTIFIED BY '$BARBICAN_DB_PASSWD';
GRANT ALL PRIVILEGES ON mistral.* TO 'mistral'@'localhost' IDENTIFIED BY '$MISTRAL_DB_PASSWD';
GRANT ALL PRIVILEGES ON mistral.* TO 'mistral'@'%' IDENTIFIED BY '$MISTRAL_DB_PASSWD';
GRANT ALL PRIVILEGES ON tacker.* TO 'tacker'@'localhost' IDENTIFIED BY '$TACKER_DB_PASSWD';
GRANT ALL PRIVILEGES ON tacker.* TO 'tacker'@'%' IDENTIFIED BY '$TACKER_DB_PASSWD';
FLUSH PRIVILEGES;
EOF
}

controller-mysql-optimization(){
if [[ -f /lib/systemd/system/mysql.service && $(cat /lib/systemd/system/mysql.service| grep 'LimitNOFILE' | wc -l) = 0 ]]; then echo "mysql is install. Now we are increase conncetion";  
sed -i "/\[Service/a LimitNOFILE=10000\nLimitNPROC=10000" /lib/systemd/system/mysql.service
systemctl --system daemon-reload
systemctl restart mysql
fi
}

controller-keystone(){
apt install -y keystone  apache2 libapache2-mod-wsgi
if [ $(cat /etc/keystone/keystone.conf | grep 'provider = fernet' | wc -l) = 2 ]; then first_start=true
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
sed -i "/connection = sqlite:/c connection = mysql+pymysql://keystone:${KEYSTONE_DB_PASSWD}@controller/keystone" /etc/keystone/keystone.conf
sed -i "2728 i provider = fernet" /etc/keystone/keystone.conf
echo '
ServerName controller'>>/etc/apache2/apache2.conf
fi
su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone  
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone 
keystone-manage bootstrap --bootstrap-password $ADMIN_PASS --bootstrap-admin-url http://controller:35357/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne 
service apache2 restart
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password $DEMO_PASSWD demo
openstack role create user
openstack role add --project demo --user demo user

echo 'export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD='$ADMIN_PASS'
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2'>/root/admin-openrc
echo 'export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD='$DEMO_PASS'
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2'>/root/demo-openrc
}


controller-glance(){
. /root/admin-openrc
openstack user create --domain default --password $GLANCE_DB_PASSWD glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292
apt install -y glance

if [ $(cat /etc/glance/glance-api.conf | grep 'connection = mysql+pymysql' | wc -l) = 0 ]; then first_start=true
cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak
cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.bak
sed -i "/\[database/a connection = mysql+pymysql://glance:${GLANCE_DB_PASSWD}@controller/glance" /etc/glance/glance-api.conf
sed -i "/From keystonemiddleware.auth_token/a auth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = $GLANCE_DB_PASSWD" /etc/glance/glance-api.conf
sed -i "/\[paste_deploy/a flavor = keystone" /etc/glance/glance-api.conf
sed -i "/From glance.store/a stores = file,http\ndefault_store = file\nfilesystem_store_datadir = /var/lib/glance/images/" /etc/glance/glance-api.conf
sed -i "/\[database/a connection = mysql+pymysql://glance:${GLANCE_DB_PASSWD}@controller/glance" /etc/glance/glance-registry.conf
sed -i "/From keystonemiddleware.auth_token/a auth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = $GLANCE_DB_PASSWD" /etc/glance/glance-registry.conf
sed -i "/\[paste_deploy/a flavor = keystone" /etc/glance/glance-registry.conf
fi

su -s /bin/sh -c "glance-manage db_sync" glance
service glance-registry restart
service glance-api restart

. admin-openrc
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
openstack image create "cirros" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --public
glance image-list
}



controller-nova(){
. /root/admin-openrc
openstack user create --domain default --password $NOVA_DB_PASSWD nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
openstack user create --domain default --password $NOVA_PLACEMENT_PASS placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://controller:8778
openstack endpoint create --region RegionOne placement internal http://controller:8778
openstack endpoint create --region RegionOne placement admin http://controller:8778
apt install -y nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler nova-placement-api

if [ $(cat /etc/nova/nova.conf | grep 'connection = mysql+pymysql' | wc -l) = 0 ]; then first_start=true
cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
sed -i "/nova_api.sqlite$/c connection = mysql+pymysql:\/\/nova:${NOVA_DB_PASSWD}@controller\/nova_api" /etc/nova/nova.conf
sed -i "/nova.sqlite$/c connection = mysql+pymysql:\/\/nova:${NOVA_DB_PASSWD}@controller\/nova" /etc/nova/nova.conf
sed -i "4 a transport_url = rabbit://openstack:${RABBIT_PASS}@controller" /etc/nova/nova.conf
sed -i "/Options under this group are used to define Nova API/a auth_strategy = keystone" /etc/nova/nova.conf
sed -i "/From keystonemiddleware.auth_token/a auth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = nova\npassword = ${NOVA_DB_PASSWD}" /etc/nova/nova.conf
sed -i "5 a my_ip = ${eth0ip}" /etc/nova/nova.conf
sed -i "6 a use_neutron = True" /etc/nova/nova.conf
sed -i "7 a firewall_driver = nova.virt.firewall.NoopFirewallDriver" /etc/nova/nova.conf
sed -i "/Enable VNC related features/a enabled = true\nvncserver_listen = \$my_ip\nvncserver_proxyclient_address = \$my_ip" /etc/nova/nova.conf
sed -i "/\[glance/a api_servers = http://controller:9292" /etc/nova/nova.conf
sed -i "/\[oslo_concurrency/a lock_path = /var/lib/nova/tmp" /etc/nova/nova.conf
sed -i "s/os_region_name = openstack/#os_region_name = openstack/g" /etc/nova/nova.conf
sed -i "/os_region_name = openstack/a os_region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://controller:35357/v3\nusername = placement\npassword = ${NOVA_PLACEMENT_PASS}" /etc/nova/nova.conf
fi
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
nova-manage cell_v2 list_cells   #不行可以用这个nova-manage cell_v2 simple_cell_setup
service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
. admin-openrc
openstack compute service list
openstack catalog list
openstack image list
nova-status upgrade check 

su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova        #新的compute节点起来之后 要运行这个
}



compute-nova(){
apt install -y nova-compute

if [ $(cat /etc/nova/nova.conf | grep 'transport_url = rabbit:' | wc -l) = 0 ]; then first_start=true
cp /etc/nova/nova.conf /etc/nova/nova.conf.bak
sed -i "4 a transport_url = rabbit://openstack:${RABBIT_PASS}@controller" /etc/nova/nova.conf
sed -i "/Options under this group are used to define Nova API/a auth_strategy = keystone" /etc/nova/nova.conf
sed -i "/From keystonemiddleware.auth_token/a auth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = nova\npassword = ${NOVA_DB_PASSWD}" /etc/nova/nova.conf
sed -i "5 a my_ip = ${eth0ip}" /etc/nova/nova.conf
sed -i "6 a use_neutron = True" /etc/nova/nova.conf
sed -i "7 a firewall_driver = nova.virt.firewall.NoopFirewallDriver" /etc/nova/nova.conf
controller_ip=$(cat /etc/hosts |grep controller |awk '// {print $1}') && echo controller_ip is $controller_ip
sed -i "/Enable VNC related features/a enabled = true\nvncserver_listen = 0.0.0.0\nvncserver_proxyclient_address = \$my_ip\nnovncproxy_base_url = http://${controller_ip}:6080/vnc_auto.html" /etc/nova/nova.conf
sed -i "/\[glance/a api_servers = http://controller:9292" /etc/nova/nova.conf
sed -i "/From oslo.concurrency/a lock_path = /var/lib/nova/tmp" /etc/nova/nova.conf
sed -i "s/os_region_name = openstack/#os_region_name = openstack/g" /etc/nova/nova.conf
sed -i "/os_region_name = openstack/a os_region_name = RegionOne\nproject_domain_name = Default\nproject_name = service\nauth_type = password\nuser_domain_name = Default\nauth_url = http://controller:35357/v3\nusername = placement\npassword = ${NOVA_PLACEMENT_PASS}" /etc/nova/nova.conf
sed -i "s/log_dir = \/var\/log\/nova/#log_dir = \/var\/log\/nova/g" /etc/nova/nova.conf
service nova-compute restart
fi
}




controller-neutron(){
. /root/admin-openrc
openstack user create --domain default --password $NEUTRON_DB_PASSWD neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://controller:9696
openstack endpoint create --region RegionOne network internal http://controller:9696
openstack endpoint create --region RegionOne network admin http://controller:9696  
apt install -y neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent

if [ $(cat /etc/neutron/neutron.conf | grep 'connection = mysql+pymysql' | wc -l) = 0 ]; then first_start=true
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
sed -i "/neutron.sqlite$/c connection = mysql+pymysql:\/\/neutron:${NEUTRON_DB_PASSWD}@controller\/neutron" /etc/neutron/neutron.conf
sed -i "3 a service_plugins = router" /etc/neutron/neutron.conf
sed -i "4 a allow_overlapping_ips = true" /etc/neutron/neutron.conf
sed -i "5 a transport_url = rabbit://openstack:${RABBIT_PASS}@controller" /etc/neutron/neutron.conf
sed -i "6 a auth_strategy = keystone" /etc/neutron/neutron.conf
sed -i "/From keystonemiddleware.auth_toke/a auth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = ${NEUTRON_DB_PASSWD}" /etc/neutron/neutron.conf
sed -i "7 a notify_nova_on_port_status_changes = true" /etc/neutron/neutron.conf
sed -i "8 a notify_nova_on_port_data_changes = true" /etc/neutron/neutron.conf
sed -i "/From nova.auth/a auth_url = http://controller:35357\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = nova\npassword = ${NOVA_DB_PASSWD}" /etc/neutron/neutron.conf

cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.bak
sed -i "/type_drivers = local,flat,vlan,gre,vxlan,geneve/a type_drivers = flat,vlan,vxlan\ntenant_network_types = vxlan\nmechanism_drivers = linuxbridge,l2population\nextension_drivers = port_security" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/\[ml2_type_flat/a flat_networks = provider" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/\[ml2_type_vxlan/a vni_ranges = 1:1000" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/\[securitygroup/a enable_ipset = true" /etc/neutron/plugins/ml2/ml2_conf.ini

cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
sed -i "/\[linux_bridge/a physical_interface_mappings = provider:${eth0name}" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/\[vxlan/a enable_vxlan = true\nlocal_ip = ${eth0ip}\nl2_population = true" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/\[securitygroup/a enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

cp /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.bak
sed -i "2 a interface_driver = linuxbridge" /etc/neutron/l3_agent.ini

cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.bak
sed -i "2 a interface_driver = linuxbridge\ndhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\nenable_isolated_metadata = true" /etc/neutron/dhcp_agent.ini

cp /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.bak
sed -i "2 a nova_metadata_host = controller\nmetadata_proxy_shared_secret = ${METADATA_SECRET}" /etc/neutron/metadata_agent.ini

cp /etc/nova/nova.conf /etc/nova/nova.conf.bak2
sed -i "/Configuration options for neutron (network connectivity as a service)./a url = http://controller:9696\nauth_url = http://controller:35357\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = ${NEUTRON_DB_PASSWD}\nservice_metadata_proxy = true\nmetadata_proxy_shared_secret = ${METADATA_SECRET}" /etc/nova/nova.conf
fi
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
service nova-api restart
service neutron-server restart
service neutron-linuxbridge-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
service neutron-l3-agent restart
openstack network agent list
}


compute-neutron(){
apt install -y neutron-linuxbridge-agent
if [ $(cat /etc/neutron/neutron.conf | grep 'transport_url = rabbit' | wc -l) = 0 ]; then first_start=true
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
sed -i "3 a transport_url = rabbit://openstack:${RABBIT_PASS}@controller" /etc/neutron/neutron.conf
sed -i "4 a auth_strategy = keystone" /etc/neutron/neutron.conf
sed -i "/From keystonemiddleware.auth_toke/a auth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = neutron\npassword = ${NEUTRON_DB_PASSWD}" /etc/neutron/neutron.conf

cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
sed -i "/\[linux_bridge/a physical_interface_mappings = provider:${eth0name}" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/\[vxlan/a enable_vxlan = true\nlocal_ip = ${eth0ip}\nl2_population = true" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/\[securitygroup/a enable_security_group = true\nfirewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

cp /etc/nova/nova.conf /etc/nova/nova.conf.bak2
sed -i "/Configuration options for neutron (network connectivity as a service)./a url = http://controller:9696\nauth_url = http://controller:35357\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = ${NEUTRON_DB_PASSWD}" /etc/nova/nova.conf
fi
service nova-compute restart
service neutron-linuxbridge-agent restart
}



controller-horizon(){
apt install -y openstack-dashboard
if [ $(cat /etc/openstack-dashboard/local_settings.py | grep 'controller' | wc -l) = 0 ]; then first_start=true
cp /etc/openstack-dashboard/local_settings.py /etc/openstack-dashboard/local_settings.py.bak
sed -i "/^OPENSTACK_HOST =/c OPENSTACK_HOST = \"controller\"" /etc/openstack-dashboard/local_settings.py
sed -i "/memcached set CACHES to something like/a SESSION_ENGINE = 'django.contrib.sessions.backends.cache'" /etc/openstack-dashboard/local_settings.py
sed -i "s/'LOCATION': '127.0.0.1:11211',/'LOCATION': 'controller:11211',/g" /etc/openstack-dashboard/local_settings.py
sed -i "s/5000\/v2.0\" % OPENSTACK_HOST/5000\/v3\" % OPENSTACK_HOST/g" /etc/openstack-dashboard/local_settings.py
sed -i "/OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT/a OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" /etc/openstack-dashboard/local_settings.py
sed -i "/OPENSTACK_API_VERSIONS =/i OPENSTACK_API_VERSIONS = {\n    \"identity\": 3,\n    \"image\": 2,\n    \"volume\": 2,\n}" /etc/openstack-dashboard/local_settings.py
sed -i "/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN =/a OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = \"Default\"" /etc/openstack-dashboard/local_settings.py
sed -i "/OPENSTACK_KEYSTONE_DEFAULT_ROLE =/c OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"" /etc/openstack-dashboard/local_settings.py
sed -i "s/TIME_ZONE = \"UTC\"/TIME_ZONE = \"Asia\/Shanghai\"/g" /etc/openstack-dashboard/local_settings.py

cp /etc/apache2/conf-available/openstack-dashboard.conf /etc/apache2/conf-available/openstack-dashboard.conf.bak
sed -i "3 a WSGIApplicationGroup %\{GLOBAL\}" /etc/apache2/conf-available/openstack-dashboard.conf
fi
service apache2 reload
}


controller-heat(){
. /root/admin-openrc
openstack user create --domain default --password $HEAT_DB_PASSWD heat
openstack role add --project service --user heat admin
openstack service create --name heat --description "Orchestration" orchestration
openstack service create --name heat-cfn --description "Orchestration"  cloudformation
openstack endpoint create --region RegionOne \
  orchestration public http://controller:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  orchestration internal http://controller:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  orchestration admin http://controller:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne \
  cloudformation public http://controller:8000/v1
openstack endpoint create --region RegionOne \
  cloudformation internal http://controller:8000/v1  
openstack endpoint create --region RegionOne \
  cloudformation admin http://controller:8000/v1  
openstack domain create --description "Stack projects and users" heat  
openstack user create --domain heat --password $HEAT_DB_PASSWD heat_domain_admin  
openstack role add --domain heat --user-domain heat --user heat_domain_admin admin  
openstack role create heat_stack_owner
openstack role add --project demo --user demo heat_stack_owner
openstack role create heat_stack_user
apt-get install heat-api heat-api-cfn heat-engine -y
if [ $(cat /etc/heat/heat.conf | grep 'mysql+pymysql' | wc -l) = 0 ]; then first_start=true
cp /etc/heat/heat.conf /etc/heat/heat.conf.bak
sed -i "/\[database/a connection = mysql+pymysql://heat:${HEAT_DB_PASSWD}@controller/heat" /etc/heat/heat.conf
sed -i "2 a transport_url = rabbit://openstack:${RABBIT_PASS}@controller" /etc/heat/heat.conf
sed -i "/From keystonemiddleware.auth_token/a auth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = default\nuser_domain_name = default\nproject_name = service\nusername = heat\npassword = ${HEAT_DB_PASSWD}" /etc/heat/heat.conf
sed -i "/From heat.common.context/a auth_type = password\nauth_url = http://controller:35357\nusername = heat\npassword = ${HEAT_DB_PASSWD}\nuser_domain_name = default" /etc/heat/heat.conf
sed -i "/\[clients_keystone/a auth_uri = http://controller:35357" /etc/heat/heat.conf
sed -i "/\[ec2authtoken/a auth_uri = http://controller:5000/v3" /etc/heat/heat.conf
sed -i "3 a heat_metadata_server_url = http://controller:8000\nheat_waitcondition_server_url = http://controller:8000/v1/waitcondition\nstack_domain_admin = heat_domain_admin\nstack_domain_admin_password = ${HEAT_DB_PASSWD}\nstack_user_domain_name = heat" /etc/heat/heat.conf
fi
su -s /bin/sh -c "heat-manage db_sync" heat
service heat-api restart
service heat-api-cfn restart
service heat-engine restart
openstack orchestration service list
}

disable-ipv6(){
echo "net.ipv6.conf.all.disable_ipv6 =1">>/etc/sysctl.conf         #若有ipv6网络会导致创建虚拟机的时候，网络崩溃
sysctl -p
}


controller-create-flavor(){
openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano
openstack flavor create --id 1 --vcpus 1 --ram 512 --disk 10 m1.tiny
openstack flavor create --id 2 --vcpus 1 --ram 2048 --disk 20 m1.small
openstack flavor create --id 3 --vcpus 2 --ram 4096 --disk 40 m1.medium
openstack flavor create --id 4 --vcpus 4 --ram 8192 --disk 80 m1.large
openstack flavor create --id 5 --vcpus 8 --ram 16384 --disk 160 m1.xlarge
openstack flavor create --id 6 --vcpus 2 --ram 4096 --disk 40 l1.medium

openstack flavor create --id f.1.1.20 --vcpus 1 --ram 1024 --disk 20 flavor-1-1-20
openstack flavor create --id f.1.2.20 --vcpus 1 --ram 2048 --disk 20 flavor-1-2-20
openstack flavor create --id f.1.4.20 --vcpus 1 --ram 4096 --disk 20 flavor-1-4-20
openstack flavor create --id f.2.2.20 --vcpus 2 --ram 2048 --disk 20 flavor-2-2-20
openstack flavor create --id f.2.4.20 --vcpus 2 --ram 4096 --disk 20 flavor-2-4-20
openstack flavor create --id f.2.8.20 --vcpus 2 --ram 8192 --disk 20 flavor-2-8-20
if [ ! -f /root/.ssh/id_rsa ]; then
ssh-keygen -q -N "" -f /root/.ssh/id_rsa
fi
openstack keypair create --public-key /root/.ssh/id_rsa.pub mykey
openstack keypair create --public-key /root/.ssh/id_rsa.pub demokey
openstack keypair list
}

controller-create-provider-network(){
openstack network list
openstack network create  --share --external --provider-physical-network provider --provider-network-type flat provider
openstack subnet create --network provider --allocation-pool start=$FLAT_IP_start,end=$FLAT_IP_end --dns-nameserver 180.76.76.76 --gateway $PROVIDER_NETWORK_GATEWAY --subnet-range $PROVIDER_NETWORK_CIDR provider
}
controller-create-Self-service-network(){
openstack network create selfservice
openstack subnet create --network selfservice --dns-nameserver 180.76.76.76 --gateway 172.16.1.1 --subnet-range 172.16.1.0/24 selfservice
openstack router create router     
neutron router-interface-add router selfservice
neutron router-gateway-set router provider
neutron router-port-list router
}
controller-security-group(){  
/root/demo-openrc
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp default
}

controller-createinstance(){  
openstack flavor list
openstack image list
openstack network list
openstack security group list
openstack server create --flavor m1.nano --image cirros --nic net-id=feac9441-1b20-429e-b5da-b45b5875c73f --security-group default --key-name controllerkey provider-instance
openstack server list
openstack console url show selfservice-instance
}


base-devel
case $role in
	controller ) 
				controller-base
				controller-mysql
				controller-mysql-optimization
				controller-keystone
				 controller-glance
				 controller-nova
				 controller-neutron
				 controller-heat
				 controller-horizon
				 controller-create-flavor
				 disable-ipv6
				 controller-create-provider-network
				 controller-create-Self-service-network
				 ;;
	network );;
	objectstorage )
					compute-neutron
					disable-ipv6
					;;
	compute )
				compute-nova
				compute-neutron
				disable-ipv6
				;;
	*) echo ip not in range;;
esac