# kube-playground

## Goal
Create a quick and easy local kubernetes deployment for use with deploying and testing various Operator/CFK configurations.
Focus will be using k3d for the local kubernetes deployment.

> [!NOTE]
> This has only been tested on MacOS. So your mileage may vary.

## Prerequisites
- k3d
- docker
- kubectl
- helm
- [docker-mac-net-connect](https://github.com/chipmk/docker-mac-net-connect) *For MacOS based deployments

## TODO
- [x] Create initial k3d deployment helper
- [x] Create automated openldap deployment
- [x] Create automated keycloak deployment
- [x] Create automated CFK deployment
- [x] Add auto generated ssl helper scripts
- [ ] Add auto generated credential helper scripts

## Install k3d
This assumes you already have k3d installed.
Follow the installation instruction on [k3d.io](https://k3d.io)

For Mac (Using Homebrew)
```
brew install k3d
```

## Install the docker-mac-net-connect
This is used to provide a networking path to docker containers in MacOS by creating a `utun` network interface and then adds a route automatically.
```
sudo brew install chipmk/tap/docker-mac-net-connect
```

Start|Stop|Restart
```
sudo brew services start|stop|restart chipmk/tap/docker-mac-net-connect
```

## Usage
You can deploy base k3s environment using the following command
```
export BASE_DIR=$(pwd)
./start.sh 
```

You can automate deployment of LDAP or IDP

You can also automate CFK deployment by providing either the CFK Helm version or CFK Operator Image Version
```
export BASE_DIR=$(pwd)
CFK_HELM_VERSION=2.11.1 ./start.sh
```
or
```
export BASE_DIR=$(pwd)
CFK_IMAGE_VERSION=0.1193.34 ./start.sh
```

