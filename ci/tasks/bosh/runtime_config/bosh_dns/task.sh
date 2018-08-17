#!/bin/bash

set -euo pipefail


bosh_admin_password=$(bosh int bosh-vars-s3/bosh-variables.yml --path /admin_password)
bosh int bosh-vars-s3/bosh-variables.yml --path /default_ca/ca > bosh_ca.pem
bosh_ip=$(bosh int --path '/cloud_provider/ssh_tunnel/host' bosh-manifest-s3/bosh.yml)

export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET="${bosh_admin_password}"
export BOSH_ENVIRONMENT="https://${bosh_ip}:25555"
export BOSH_CA_CERT=$(cat bosh_ca.pem)

RUNTIME_CONFIG=cf-deployment-git/runtime-configs/dns.yml

cp bosh-vars-s3/bosh-dns-variables.yml bosh-vars/bosh-dns-variables.yml

bosh interpolate "$RUNTIME_CONFIG" \
  --vars-store=bosh-vars/bosh-dns-variables.yml \
  > bosh-vars/bosh-dns.yml

bosh update-runtime-config --name bosh-dns --non-interactive bosh-vars/bosh-dns.yml