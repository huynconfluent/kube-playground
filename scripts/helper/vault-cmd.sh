#!/bin/sh

# Treat Kubernetes as trusted identity provider
vault auth enable kubernetes

# configure vault to connect to kubernetes host
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# create app policy
cat <<EOF > /tmp/app-policy.hcl
path "secret*" {
capabilities = ["read"]
}
EOF

# apply app policy
vault write sys/policy/app policy=@/tmp/app-policy.hcl

# grant confluent-sa Service Account to access all secrets in /secret
vault write auth/kubernetes/role/confluent-operator \
    bound_service_account_names=confluent-sa \
    bound_service_account_namespaces=confluent \
    policies=app \
    audience=confluent-sa \
    ttl=24h
