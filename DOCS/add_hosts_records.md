# Add Hosts Records (Helper Script)

I've added this helper script which will configure our `/etc/hosts` file for us based on services that it finds an external IP for. Please note it does require sudo privileges for some of the steps as it involves modifying a privilege file.

```
./scripts/helper/add-hosts-records.sh
```

This will make a backup copy of our `/etc/hosts` file with a timestamp before actual modification.

When ran it will look like

```
........
There are custom records found!
Clearing custom records with based domain: confluentdemo.io...

Backing up /etc/hosts ...
/etc/hosts is now cleared of custom records!
Adding record for keycloak.confluentdemo.io
Adding record for ldap.confluentdemo.io
Adding record for controlcenter.confluentdemo.io
Adding record for kafkabroker-0.confluentdemo.io
Adding record for kafkabroker-1.confluentdemo.io
Adding record for kafkabroker-2.confluentdemo.io
Adding record for kafkabroker.confluentdemo.io
```

and our `/etc/hosts` will have the following entries appended at the bottom.

```
# keycloak.confluentdemo.io Added by kube-playground
172.69.1.2 keycloak.confluentdemo.io
# ldap.confluentdemo.io Added by kube-playground
172.69.1.1 ldap.confluentdemo.io
# controlcenter.confluentdemo.io Added by kube-playground
172.69.1.7 controlcenter.confluentdemo.io
# kafkabroker-0.confluentdemo.io Added by kube-playground
172.69.1.3 kafkabroker-0.confluentdemo.io
# kafkabroker-1.confluentdemo.io Added by kube-playground
172.69.1.4 kafkabroker-1.confluentdemo.io
# kafkabroker-2.confluentdemo.io Added by kube-playground
172.69.1.5 kafkabroker-2.confluentdemo.io
# kafkabroker.confluentdemo.io Added by kube-playground
172.69.1.6 kafkabroker.confluentdemo.io
```

So with this we can now navigate to `https://controlcenter.confluentdemo.io` in our web browser and be able to access Control Center without having to go the `port-forward` route with a local kubernetes cluster.
