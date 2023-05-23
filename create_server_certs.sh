#!/bin/bash

# Prompt user for tenant name
read -p "What is the tenant name? " tenantname

# Prompt user to select environment
PS3="Select the tenant environment: "
options=("prod" "poc" "prod-lz" "np-lz")
select environment in "${options[@]}"; do
    case $environment in
        "prod")
            url="kpn-dsh.com"
            break
            ;;
        "poc")
            url="poc.kpn-dsh.com"
            break
            ;;
        "prod-lz")
            url="dsh-prod.dsh.prod.aws.kpn.com"
            break
            ;;
        "np-lz")
            url="dsh-dev.dsh.np.aws.kpn.com"
            break
            ;;
        *) 
            echo "Invalid option. Please select a valid environment."
            ;;
    esac
done

# Prompt user for number of brokers
read -p "How many brokers do you want? (default: 12) " num_brokers
num_brokers=${num_brokers:-12}

read -p "What do you want to name the broker prefix? (default: 'broker') " broker_name
broker_name=${broker_name:-broker}

# Prompt user for self-signed certificates
read -p "Do you want to use self-signed certificates? [y/n]: " selfsigned

# Create directory
directory="server/${tenantname}-${environment}-server"
mkdir -p "$directory"

# Generate private key
openssl genrsa -aes256 -out "${directory}/${tenantname}-${environment}-server.key" 4096
openssl rsa -in "${directory}/${tenantname}-${environment}-server.key" -out "${directory}/${tenantname}-${environment}-server.key.pem"

# Generate CSR config file
cat >"${directory}/${tenantname}-${environment}-server.cnf" <<EOF
[ req ]
prompt = no
distinguished_name = server_distinguished_name
req_extensions = v3_req

[ server_distinguished_name ]
organizationName = Koninklijke KPN N.V.
localityName = Rotterdam
stateOrProvinceName = Zuid-Holland
countryName = NL
commonName = ${broker_name}.kafka.${tenantname}.${url}

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage= digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage= critical, serverAuth
subjectAltName = @alt_names

[ alt_names ]
EOF

# Add DNS entries to CSR config file
for ((i = 0; i < num_brokers; i++)); do
    echo "DNS.$i = ${broker_name}-$i.kafka.${tenantname}.${url}" >>"${directory}/${tenantname}-${environment}-server.cnf"
done

# Generate CSR
openssl req -config "${directory}/${tenantname}-${environment}-server.cnf" \
-key "${directory}/${tenantname}-${environment}-server.key.pem" \
-new -sha256 -out "${directory}/${tenantname}-${environment}-server.csr.pem"

# Check if user wants to use self-signed certificates
if [[ "$selfsigned" == [yY] ]]; then
# Generate client certificate using intermediate CA
openssl ca -config root/ca/intermediate/intermediate.cnf \
-extensions server_cert -days 375 -notext -md sha256 \
-in "${directory}/${tenantname}-${environment}-server.csr.pem" \
-out "${directory}/ss-${tenantname}-${environment}-server.cert.pem"
chmod 444 "${directory}/${tenantname}-${environment}-server.cert.pem"

openssl x509 -noout -text \
-in "${directory}/ss-${tenantname}-${environment}-server.cert.pem"

sudo openssl verify -CAfile ./root/ca/certs/ca.cert.pem \
"${directory}/ss-${tenantname}-${environment}-server.key.pem"
fi

