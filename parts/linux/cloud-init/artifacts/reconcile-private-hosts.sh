#!/usr/bin/env bash

set -o nounset
set -o pipefail
SLEEP_SECONDS=15
clusterFQDN="{{FQDN}}"
echo "clusterFQDN: $clusterFQDN"
clusterFQDN1="{{kubernetesEndpoint}}"
echo "clusterFQDN1: $clusterFQDN1"

if [[ $clusterFQDN != *.privatelink.* ]]; then
  echo "skip reconcile hosts for $clusterFQDN since it's not AKS private cluster"
  exit 0
fi
echo "clusterFQDN: $clusterFQDN"
function get-apiserver-ip-from-tags() {
  tags=$(curl -sSL -H "Metadata: true" "http://169.254.169.254/metadata/instance/compute/tags?api-version=2019-03-11&format=text")
  if [ "$?" == "0" ]; then
    IFS=";" read -ra tagList <<< "$tags"
    for i in "${tagList[@]}"; do
      tagKey=$(cut -d":" -f1 <<<$i)
      tagValue=$(cut -d":" -f2 <<<$i)
      if echo $tagKey | grep -iq "^aksAPIServerIPAddress$"; then
        echo -n "$tagValue"
        returb
      fi
    done
  fi
  echo -n ""
}

while true; do
  clusterIP=$(get-apiserver-ip-from-tags)
  if [ -z $clusterIP ]; then
    sleep "${SLEEP_SECONDS}"
    continue
  fi
  if grep "$clusterIP $clusterFQDN" /etc/hosts; then
    echo "$clusterFQDN has already been set to $clusterIP"
  else
    sudo sed -i "/$clusterFQDN/d" /etc/hosts
    sudo sed -i "\$a$clusterIP $clusterFQDN" /etc/hosts
    echo "Updated $clusterFQDN to $clusterIP"
  fi
  sleep "${SLEEP_SECONDS}"
done

#EOF