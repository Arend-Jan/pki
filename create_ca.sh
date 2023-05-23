#!/bin/bash

# 3.1 prepare the root directory

prepare_root_dir() {
	cwd=$(pwd)
    sudo mkdir -p $cwd/root/ca/{certs,crl,newcerts,private}
    sudo chmod 700 $cwd/root/ca/private
    sudo touch $cwd/root/ca/index.txt
    echo 1000 | sudo tee $cwd/root/ca/serial >/dev/null
}

# prepare_root_dir
#
# 3.1.2 root config file
prepare_root_config() {
    sudo cp ./config/root.cnf ./root/ca/root.cnf
}
# 3.2 Create the root key
create_root_key() {
  sudo openssl genrsa -aes256 -out ./root/ca/private/ca.key.pem 4096
  sudo chmod 444 ./root/ca/private/ca.key.pem
}

#
# # 3.3 Create the root certificate
create_root_cert() {
  sudo openssl req -config ./root/ca/root.cnf \
    -key ./root/ca/private/ca.key.pem \
    -new -x509 -days 7300 -sha256 -extensions v3_ca \
    -out ./root/ca/certs/ca.cert.pem
}

#
# # 3.4 Verify the root certificate
verify_root_cert() {
  openssl x509 -noout -text -in ./root/ca/certs/ca.cert.pem
  [[ $(openssl x509 -noout -text -in ./root/ca/certs/ca.cert.pem) ]] && echo "Root certificate verified successfully." || { echo "Failed to verify root certificate."; exit 1; }
}
#
# # 3.5 prepare the intermediate directory
prepare_intermediate_dir() {
  sudo mkdir -p ./root/ca/intermediate/{certs,crl,csr,newcerts,private,cnf}
  sudo chmod 700 ./root/ca/intermediate/private
  sudo touch ./root/ca/intermediate/index.txt
  echo 1000 > ./root/ca/intermediate/serial
  echo 1000 > ./root/ca/intermediate/crlnumber
}
#
# # 3.5.1 intermediate config file
prepare_intermediate_config() {
  sudo cp ./config/intermediate.cnf ./root/ca/intermediate/intermediate.cnf
}
#
# # 3.6 Create the intermediate key
create_intermediate_key() {
  openssl genrsa -aes256 \
    -out ./root/ca/intermediate/private/intermediate.key.pem 4096
  chmod 400 ./root/ca/intermediate/private/intermediate.key.pem
}
#
# # 3.7 Create the intermediate csr
create_intermediate_csr() {
  openssl req -config ./root/ca/intermediate/intermediate.cnf -new -sha256 \
    -key ./root/ca/intermediate/private/intermediate.key.pem \
    -out ./root/ca/intermediate/csr/intermediate.csr.pem
}
#
# # 3.8 Create the intermediate certificate & Sign intermediate certificate with the root CA
sign_intermediate_cert() {
  echo ============================================================
  echo ======== SIGNING THE INTERMEDIATE CERT WITH ROOT CA ========
  echo ============================================================


  sudo openssl ca -config ./root/ca/root.cnf -extensions v3_intermediate_ca \
    -days 3650 -notext -md sha256 \
    -in ./root/ca/intermediate/csr/intermediate.csr.pem \
    -out ./root/ca/intermediate/certs/intermediate.cert.pem
  sudo chmod 444 ./root/ca/intermediate/certs/intermediate.cert.pem
}
#
# # 3.9 Verify the intermediate certificate
verify_intermediate_cert() {
  openssl x509 -noout -text -in ./root/ca/intermediate/certs/intermediate.cert.pem
  [[ $(openssl x509 -noout -text -in ./root/ca/intermediate/certs/intermediate.cert.pem) ]] && echo "Intermediate certificate verified successfully." || { echo "Failed to verify intermediate certificate."; exit 1; }

  openssl verify -CAfile ./root/ca/certs/ca.cert.pem \
    ./root/ca/intermediate/certs/intermediate.cert.pem
}
#
# # 3.10 Create the certificate chain file
create_chain_file() {
    cat ./root/ca/intermediate/certs/intermediate.cert.pem \
      ./root/ca/certs/ca.cert.pem > ./root/ca/intermediate/certs/ca-chain.cert.pem

    chmod 444 ./root/ca/intermediate/certs/ca-chain.cert.pem
    echo | cat ./root/ca/intermediate/certs/ca-chain.cert.pem

  echo ============================================================
  echo ============== ABOVE CA-CHAIN HAS BEEN CREATED =============
  echo ============================================================

}
main() {
prepare_root_dir
prepare_root_config
create_root_key
create_root_cert
verify_root_cert
prepare_intermediate_dir
prepare_intermediate_config
create_intermediate_key
create_intermediate_csr
sign_intermediate_cert
verify_intermediate_cert
create_chain_file
}

main

