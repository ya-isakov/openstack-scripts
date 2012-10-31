#!/bin/bash

. $(dirname $(readlink -f $0))/00-lib.sh

check_root

NOVA_CONFIG=/etc/nova/nova.conf
NOVA_API_PASTE=/etc/nova/api-paste.ini

apt-get install -y nova-api nova-cert nova-consoleauth nova-scheduler nova-network

service nova-network stop

nova-manage db sync
nova-manage network create private --fixed_range_v4=$FIXED_IP_RANGE --num_networks=1 --bridge_interface=$DATA_IFACE_NAME --vlan=$FIRST_VLAN_ID --network_size=$NETWORK_SIZE

nova-manage floating create --ip_range=$FLOATING_IP_RANGE --interface=$PUB_IFACE_NAME

# NOTE(aandreev): not backing up nova.conf file, already done in nova-common-install.sh

cat >>$NOVA_CONFIG <<NOVA_CONFIG
# NOTE: the configuration below was appended by installation script
connection_type=libvirt
public_interface=$PUBLIC_IFACE
multi_host=True
NOVA_CONFIG


backup_file $NOVA_API_PASTE

sed "/^admin_/s/^/# /g" $NOVA_API_PASTE
sed "/^auth_host/s/^/# /g" $NOVA_API_PASTE

cat >>$NOVA_API_PASTE <<NOVA_API_PASTE
# NOTE: the configuration below was appended by installation script
service_host = $KEYSTONE_HOST
service_port = 5000

auth_host = $KEYSTONE_HOST
auth_uri = http://$KEYSTONE_HOST:5000/

admin_tenant_name = $SERVICE_TENANT_NAME
admin_user = nova
admin_password = $SERVICE_PASSWORD
NOVA_API_PASTE

for i in nova-api nova-cert nova-consoleauth nova-scheduler; do
	service $i restart
done
