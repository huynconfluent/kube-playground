#!/bin/sh

# check for our network in netstat
checkForRoute="netstat -rnf inet | grep 172.69"

printf "\nChecking for docker-mac-net-connect route...\n"

if [ "$(eval $checkForRoute | wc -l)" -ge 1 ]; then
    printf "\nRoute Exists!\n"
    eval $checkForRoute
    printf "\n"
else
    printf "\nRoute doesn't exist!"
    printf "\nRecommend stopping docker-mac-net-connect and running it manually to troubleshoot"
    printf "\n\n\tsudo brew services stop chipmk/tap/docker-mac-net-connect\n"
    printf "\n\tsudo docker-mac-net-connect\n\n"
fi
