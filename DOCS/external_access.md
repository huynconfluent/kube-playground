# External Access

One of the challenges of testing deployments in a local kubernetes on macOS is the separation of networking that makes it difficult to test any external access.

This includes GUI web applications and any type of kubernetes LoadBalancer configurations.

Kube Playground deploys with a MetalLB load Balancer, which can be utilized to provide an "external" ip as our entry way into the Kubernetes Cluster.

We can deploy CRs with `externalAccess` of type LoadBalancer configuration and be able to access them from the host machine by mapping a hostname to the IPs assigned by MetalLB. For example when you deploy ldap/keycloak, it will deploy with an external IP, which you can map to a hostname for access from your local machine.

## Prequisites

If you're on a Mac. You will need `docker-mac-net-connect` this is used to provide a networking path to docker containers in MacOS by creating a `utun` network interface and then adds a route automatically.

> [!NOTE]
> This is not used when working with Openshift Local

```
brew install chipmk/tap/docker-mac-net-connect
```

Start|Stop|Restart

```
sudo brew services start|stop|restart chipmk/tap/docker-mac-net-connect
```

> [!IMPORTANT]
> There's an issue I encountered with newer versions of Docker Desktop as noted in this [Github Issue](https://github.com/chipmk/docker-mac-net-connect/issues/62)
> so it'd be best to start docker-mac-net-connect with using the environment variable `DOCKER_API_VERSION=1.44`

```
sudo env DOCKER_API_VERSION=1.44 docker-mac-net-connect
```

## Adding records to /etc/hosts for externalAccess

We can deploy CRs with `externalAccess` of type `LoadBalancer` configuration and be able to access them from the host machine by mapping a hostname to the IPs assigned by MetalLB.
For example when you deploy ldap/keycloak, it will deploy with an external IP, which you can map to a hostname for access from your local machine.

```
kubectl -n identity get svc
NAME          TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                       AGE
keycloak      ClusterIP      10.43.86.169    <none>        80/TCP,443/TCP,9000/TCP       7m33s
keycloak-lb   LoadBalancer   10.43.167.91    172.69.1.2    80/TCP,443/TCP,9000/TCP       7m33s
ldap          ClusterIP      None            <none>        389/TCP,636/TCP               7m43s
ldap-lb       LoadBalancer   10.43.100.247   172.69.1.1    389:31421/TCP,636:30160/TCP   7m43s
```

In this above example, I have keycloak (IdP) and ldap with an external IP of `172.69.1.2` and `172.69.1.1` respectively. While I can directly access this via the IP, we can also map a hostname for easier access, by adding a record to our `/etc/hosts` file

```
172.69.1.2 keycloak.confluentdemo.io
172.69.1.1 ldap.confluentdemo.io
```

When we deploy a CR that has `externalAccess` configuration such as for Kafka and Control Center.

```
# Kafka
spec:
  listeners:
    external:
      ..........
      externalAccess:
        type: loadBalancer
        loadBalancer:
          domain: confluentdemo.io
          brokerPrefix: "kafkabroker-"
```

or

```
# Control Center
spec:
  externalAccess:
    type: loadBalancer
    loadBalancer:
      domain: confluentdemo.io
      port: 443
```

This will result in the following

```
kubectl -n confluent get svc
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                                                     AGE
confluent-operator           ClusterIP      10.43.47.228    <none>        7778/TCP                                                                                    11m
controlcenter                ClusterIP      None            <none>        9021/TCP,7203/TCP,7777/TCP,7778/TCP,9090/TCP,9093/TCP                                       8m7s
controlcenter-0-internal     ClusterIP      10.43.119.237   <none>        9021/TCP,7203/TCP,7777/TCP,7778/TCP,9090/TCP,9093/TCP                                       8m7s
controlcenter-bootstrap-lb   LoadBalancer   10.43.3.184     172.69.1.7    443:30250/TCP                                                                               8m7s
kafkabroker                  ClusterIP      None            <none>        9074/TCP,9092/TCP,8090/TCP,9071/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP,9073/TCP,9075/TCP   9m24s
kafkabroker-0-internal       ClusterIP      10.43.14.26     <none>        9074/TCP,9092/TCP,8090/TCP,9071/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP,9073/TCP,9075/TCP   9m24s
kafkabroker-0-lb             LoadBalancer   10.43.25.32     172.69.1.3    9092:30714/TCP                                                                              9m24s
kafkabroker-1-internal       ClusterIP      10.43.93.178    <none>        9074/TCP,9092/TCP,8090/TCP,9071/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP,9073/TCP,9075/TCP   9m24s
kafkabroker-1-lb             LoadBalancer   10.43.140.185   172.69.1.4    9092:32478/TCP                                                                              9m24s
kafkabroker-2-internal       ClusterIP      10.43.148.212   <none>        9074/TCP,9092/TCP,8090/TCP,9071/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP,9073/TCP,9075/TCP   9m24s
kafkabroker-2-lb             LoadBalancer   10.43.244.93    172.69.1.5    9092:32541/TCP                                                                              9m24s
kafkabroker-bootstrap-lb     LoadBalancer   10.43.126.164   172.69.1.6    9092:32435/TCP                                                                              9m24s
kafkacontroller              ClusterIP      None            <none>        9074/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP                                                10m
kafkacontroller-0-internal   ClusterIP      10.43.5.178     <none>        9074/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP                                                10m
kafkacontroller-1-internal   ClusterIP      10.43.242.90    <none>        9074/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP                                                10m
kafkacontroller-2-internal   ClusterIP      10.43.198.215   <none>        9074/TCP,7203/TCP,7777/TCP,7778/TCP,9072/TCP                                                10m
```

So now we have external IPs that we can use to access those components from our host machine.

### Use the script!

I've also added a helper script to do this automatically for you.

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/add-hosts-records.sh
```

Please refer to the [add_hosts_records.md](./add_hosts_records.md)
