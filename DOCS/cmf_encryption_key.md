# Creating a CMF Encryption Key

An Encryption Key is needed to properly store sensitive data into CMF's internal databse.
Kube-playground has a helper script to create this for you. `deploy-cmf.sh` currently also calls this helper script during deployment.

## Excuting create-cmf-key.sh

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/ssl/create-cmf-key.sh -n <namespace>
```

This generates the following in `$BASE_DIR/generated/ssl`

```
cmf/
cmf/create-cmf-encryption-secret.sh
files/
files/cmf/cmf.key
```

## Deploying CMF

The `deploy-cmf.sh` will attempt to create a kubernetes secret storing the encryption key used for CMF Helm deployment.
