#!/bin/bash

# Prompt user for client name
read -p "What is the client name? " clientname

# Prompt user for self-signed certificates
read -p "Do you want to use self-signed certificates? [y/n]: " selfsigned

# Prompt user for tenant name
# read -p "What is the tenant name? " tenantname

# Create directory
directory="client/${clientname}-client"
mkdir -p "$directory"

echo ============================
echo === GENERATE PRIVATE KEY ===
echo ============================

# Generate private key
openssl genrsa -aes256 -out "${directory}/${clientname}-client.key" 2048
echo ===============================================================
echo created key: "${directory}/${clientname}-client.key"
echo ===============================================================

# Generate encrypted private key
openssl rsa -in "${directory}/${clientname}-client.key" -out "${directory}/${clientname}-client.key.pem"

# Generate unencrypted private key
openssl rsa -in "${directory}/${clientname}-client.key.pem" -out "${directory}/${clientname}-client.un-key.pem"

# Generate CSR config file
cat >"${directory}/${clientname}-client.cnf" <<EOF
[ req ]
prompt = no
distinguished_name = client_distinguished_name
req_extensions = v3_req

[ client_distinguished_name ]
commonName = ${clientname}-client

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage= critical, digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage= clientAuth
EOF

# Generate CSR
openssl req -config "${directory}/${clientname}-client.cnf" \
	-key "${directory}/${clientname}-client.key.pem" \
	-new -sha256 -out "${directory}/${clientname}-client.csr.pem"

echo ========= SELF SIGNING THE CERT ==============
# Check if user wants to use self-signed certificates
if [[ "$selfsigned" == [yY] ]]; then
	# Generate client certificate using intermediate CA
	openssl ca -config root/ca/intermediate/intermediate.cnf \
		-extensions usr_cert -days 375 -notext -md sha256 \
		-in "${directory}/${clientname}-client.csr.pem" \
		-out "${directory}/ss-${clientname}-client.cert.pem"

	chmod 444 "${directory}/${clientname}-client.cert.pem"

echo ============== VALIDATE THE CERT ===================
	openssl x509 -noout -text \
		-in "${directory}/ss-${clientname}-client.cert.pem"
fi
