# Run CFK Version Extractor

While kube-playground stores a manual copy of CFK Version to Image Tag mapping, it may not always be up to date. You can use the following script to manually generate a new mapping combining default mapping with what we pull from [Confluent Documentation](https://docs.confluent.io/operator/current/co-plan.html#co-long-image-tags) thus creating a brand new mapping.

```
export BASE_DIR=$(pwd)
./scripts/helper/cfk-version-extractor.sh
```

If the version differs, it would be advised to replace the old mapping at `$BASE_DIR/configs/cfk/version_mapping.json` with the new file from `$BASE_DIR/generated/cfk/version_mapping.json` until kube-playground is updated with this new copy.
