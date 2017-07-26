#!/bin/sh

TARGET_RESOURCE_GROUP=user0000-webapp-tmpl-rg
NUMBER_OF_WEB_SERVERS=3
WEBSV_IMAGE="/subscriptions/450f731f-ced6-417a-bfa1-3e69686598dc/resourceGroups/user0000-webapp-images-rg/providers/Microsoft.Compute/images/webapp-websv-image"
SSH_USER=webapusr
SSH_PKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDAJcX2uqUfYqb87ujpa38lD5sPesqvcpER8Zyx7Hl+Es5c9F34eJ3dP1+llJJ+3MlDThWcvTOzxJf9Bz9dN3K6NQHOoF6LuOPOD4QMjpMjJZJfio/zf1wrO49n/Wzfc4JsoxGzdiXdwIEjJmKmY7NQMsxejVR7QhNGARTYViMFl5kzFK/C3GJYn9O3ZgcWu9oWowIBnYR4S7Q6PylwNcQa+Uq4qOtdEaWAJbcEOsczviAsl098jqA7LXMxjGNgrqZQiB/aO1ZxajnAn7mkmRjWqUafqc4LgAk54t3WKmGXfesM26315i5AVkAiYq3lezk4cKDWNO1E1UEPT/lNTEpx devops"

az configure --defaults group=${TARGET_RESOURCE_GROUP}
az network nsg create \
    -n webapp-websv-nsg
az network nsg rule create \
    --nsg-name webapp-websv-nsg \
    -n webapp-websv-nsg-http \
    --priority 1001 \
    --protocol Tcp \
    --destination-port-range 80
az network public-ip create \
    -n webapp-pip
az network vnet create \
    -n webapp-vnet \
    --address-prefixes 192.168.1.0/24 \
    --subnet-name webapp-vnet-sub \
    --subnet-prefix 192.168.1.0/24
az network lb create \
    -n webapp-websv-lb \
    --public-ip-address webapp-pip \
    --frontend-ip-name webapp-websv-lb-front \
    --backend-pool-name webapp-websv-lb-backpool
az network lb probe create \
    --lb-name webapp-websv-lb \
    -n webapp-websv-lb-probe \
    --port 80 \
    --protocol Http \
    --path '/?lbprobe=1'
az network lb rule create \
    --lb-name webapp-websv-lb \
    -n webapp-websv-lb-rule \
    --frontend-ip-name webapp-websv-lb-front \
    --frontend-port 80 \
    --backend-pool-name webapp-websv-lb-backpool \
    --backend-port 80 \
    --protocol tcp \
    --probe-name webapp-websv-lb-probe
az vm availability-set create \
    -n webapp-websv-as \
    --platform-update-domain-count 5 \
    --platform-fault-domain-count 2
for i in $(seq 1 ${NUMBER_OF_WEB_SERVERS}); do
(
az network nic create \
    -n webapp-websv${i}-nic \
    --private-ip-address 192.168.1.$((10 + ${i})) \
    --vnet-name webapp-vnet \
    --subnet webapp-vnet-sub \
    --network-security-group webapp-websv-nsg \
    --lb-name webapp-websv-lb \
    --lb-address-pools webapp-websv-lb-backpool
az vm create \
    -n websv${i} \
    --nics webapp-websv${i}-nic \
    --availability-set webapp-websv-as \
    --size Standard_F1 \
    --storage-sku Standard_LRS \
    --os-disk-name websv${i}-osdisk \
    --image ${WEBSV_IMAGE} \
    --admin-username "${SSH_USER}" \
    --ssh-key-value "${SSH_PKEY}"
)&
done
wait
echo http://$(az network public-ip show -n webapp-pip -o tsv --query ipAddress)/

