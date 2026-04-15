# CFK Version Extractor

This is a helper script to generate a JSON file mapping the CFK Helm version -> Operator Image versions and combining it with the local `$BASE_DIR/configs/cfk/version_mapping.json` contents.
This script requires internet access in order to pull this public information from [Confluent Documentation](https://docs.confluent.io/operator/current/co-plan.html#co-long-image-tags).
This can be useful when you are passing in Operator versions for CFK deployment on start. Otherwise this JSON file will be updated periodically.

## Run cfk-version-extractor.sh

```
cd kube-playground
export BASE_DIR=$(pwd)
./scripts/helper/cfk-version-extractor.sh
```

This will generate the `version_mapping.json` file in the `$BASE_DIR/generated/cfk` directory. The script will also try and advise if the local version needs to be replaced.
