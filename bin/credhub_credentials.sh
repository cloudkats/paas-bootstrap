#!/bin/bash
#
# This script will set up a connection to a UAA/Credhub environment for you:
#
# - downloads from S3 the environment state files
# - sets up an SSH socks5 proxy (listening on BOSH_PROXY_PORT)
# - runs `bosh alias-env <env>`
# - exports the CREDHUB_PROXY and HTTPS_PROXY environment variables
#
# You can either run it in the foreground (-f), or source the script. In the first case, 
# you will run in a subshell and everything will be cleaned up when you exit that shell.
# In the second, you are responsible for killing the SSH proxy.

usage() {
    echo "Usage: [source] $(basename $0) -e <env> [-p ssh_port] [-f] [command]"
    echo
    echo "Options:"
    echo "          -e  Connect to this environment, e.g. eng2 (ENVIRONMENT)"
    echo "          -p  Have SSH proxy listen on this port (PROXY_PORT)"
    echo "          -f  Run this session in a shell, when you exit, the SSH proxy will be killed"
    echo
    echo "              If you specify a command, it will run, then detach the proxy"
    exit 1
}

: ${PROXY_PORT:=30124}
FOREGROUND=false

while getopts 'e:p:f' option; do
  case $option in
    e) ENVIRONMENT="$OPTARG";;
    p) PROXY_PORT="$OPTARG";;
    f) FOREGROUND=true;;
    *) usage;;
  esac
done

shift $((OPTIND-1))
COMMAND=$*

VARS=/var/tmp/tmp$$
mkdir -p "$VARS"
trap 'rm -rf "$VARS"' EXIT

aws s3 cp "s3://ons-paas-${ENVIRONMENT}-states/vpc/tfstate.json" "$VARS/"
aws s3 cp "s3://ons-paas-${ENVIRONMENT}-states/jumpbox/jumpbox-variables.yml" "$VARS/"
aws s3 cp "s3://ons-paas-${ENVIRONMENT}-states/bosh/bosh-variables.yml" "$VARS/"
aws s3 cp "s3://ons-paas-${ENVIRONMENT}-states/bosh/bosh.yml" "$VARS/"
bosh int --path /jumpbox_ssh/private_key "$VARS/jumpbox-variables.yml" > "$VARS/jumpbox.key"
jq '.modules[0].outputs | with_entries(.value = .value.value)' < "$VARS/tfstate.json" > "$VARS/vars.json"

ZONE=$(jq -r '.dns_zone' < "$VARS/vars.json" | sed 's/\.$//')
JUMPBOX_TARGET="jumpbox.${ZONE}"
chmod 600 "$VARS/jumpbox.key"
DIRECTOR_IP=$(bosh int --path '/cloud_provider/ssh_tunnel/host' "$VARS/bosh.yml")

if ! netstat -na | grep -q "127.0.0.1.${PROXY_PORT}.*LISTEN"; then
  ssh -4 -D $PROXY_PORT -fNC jumpbox@${JUMPBOX_TARGET} -i "${VARS}/jumpbox.key" && STARTED_SSH=true
fi

bosh int --path /credhub_tls/ca "$VARS/bosh-variables.yml" > "${VARS}/credhub_ca.pem"
bosh int --path /uaa_ssl/ca "$VARS/bosh-variables.yml" > "${VARS}/uaa_ca.pem"

export UAA_CA_CERT="${VARS}/uaa_ca.pem"
export CREDHUB_CA_CERT="${VARS}/credhub_ca.pem"
export CREDHUB_SERVER="https://${DIRECTOR_IP}:8844"
export CREDHUB_CLIENT=credhub-admin
export CREDHUB_SECRET=$(bosh int --path /credhub_admin_client_secret "$VARS/bosh-variables.yml")
export HTTPS_PROXY="socks5://localhost:$PROXY_PORT"

kill_tunnel() {
  if [ -n "$STARTED_SSH" ]; then
    echo "Killing the SSH proxy on $PROXY_PORT"
    kill $(ps -ef | awk "/ssh -4 -D $PROXY_PORT/ && ! /awk/ { print \$2 }")
  fi
}

if [ "$FOREGROUND" = true -o -n "$COMMAND" ]; then
  trap 'kill_tunnel' EXIT
fi

if [ "$FOREGROUND" = true ]; then
  credhub login --ca-cert="$CREDHUB_CA_CERT" --ca-cert="$UAA_CA_CERT" --skip-tls-validation
  echo "OK, you are set up"
  export PS1="CREDHUB<$ENVIRONMENT>:\W \u\$ "
  bash
elif [ -n "$COMMAND" ]; then
  ""$COMMAND""
fi