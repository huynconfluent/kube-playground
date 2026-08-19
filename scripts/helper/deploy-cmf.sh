#!/bin/sh

# ./deploy-cmf.sh -v "CMF_VERSION" -n "CMF_NAMESPACE" -a basic|sso|mtls -m -v VALUES.YAML

OPTIND=1
GEN_DIR="$BASE_DIR/generated"
REQUIRED_PKG="kubectl helm yq"
ENCRYPTED_DEPLOYMENT="true"
CMF_HELM_NAME="cmf"
CMF_HELM_REPO="confluentinc/confluent-manager-for-apache-flink"
CMF_VALUES_FILE=""
CMF_REST_AUTH=""
CMF_EMBEDDED_MDS="false"
CMF_REMOTE_MDS="false"
CMF_REMOTE_MDS_TYPE=""
# authz options will be cmf, cp-mds, or ""
CMF_AUTHZ=""
CMF_USERSTORE="NONE"
CMF_VOLUME_POSITION=0
CMF_VOLUMEMOUNT_POSITION=0
CMF_DRY_RUN="false"
# default to no options
CMF_HELM_INSTALL_OPTS=""
OPENSHIFT=false
set -o allexport; source .env; set +o allexport

# check for prerequisites
for PKG in $REQUIRED_PKG; do
    if [ -z "$(which ${PKG})" ]; then
        printf "REQUIRED: %s" "${PKG}"
        printf "\nPlease install %s" "${PKG}"
        printf "\nUsing Brew:"
        printf "\n\tbrew install %s" "${PKG}"
        exit 1
    fi
done

usage() {
    printf "Usage: $0 [-v] [CMF_VERSION] [-n] [CMF_NAMESPACE] [-o] [-m] [-f] [VALUES_FILE]\n"
    printf "\t-v [string]           (required) Specifies CMF Version to deploy\n"
    printf "\t-f [string]           (optional) Specifies values.yaml to use for deployment\n"
    printf "\t-a [string]           (optional) Specifies authentication method basic|sso|mtls\n"
    printf "\t-m                    (optional) Enables Embedded MDS (will ignore remote flag if set)\n"
    printf "\t-z                    (optional when Embedded MDS is true) enable AuthZ\n"
    printf "\t-u [string]           (optional) Embedded MDS Userstore file|ldap_with_oauth|oauth|ldap|none\n"
    printf "\t-r                    (optional) Enables Remote MDS (is ignored if Embedded MDS is set)\n"
    printf "\t-d                    (optional) Dry Run, just create values file\n"
    printf "\t-o                    (optional) Deploy in Openshift\n"
    printf "\t-n namespace          (required) Specifies namespace to deploy in\n"
    exit 1
}

while getopts "v:f:a:mzru:dn:o" opt; do
    case $opt in
        v)
            CMF_IMAGE_VERSION=$OPTARG
            ;;
        f)
            CMF_VALUES_FILE=$OPTARG
            ;;
        a)
            CMF_REST_AUTH=$OPTARG
            # validate CMF_REST_AUTH
            if [ "$CMF_REST_AUTH" != "mtls" ] && [ "$CMF_REST_AUTH" != "sso" ] && [ "$CMF_REST_AUTH" != "basic" ]; then
                printf "Authentication method not recognized: %s\nMust be of basic|sso|mtls, exiting...\n"
                exit 1
            fi
            ;;
        m)
            CMF_EMBEDDED_MDS="true"
            ;;
        z)
            CMF_AUTHZ="cmf"
            ;;
        r)
            CMF_EMBEDDED_MDS="false"
            CMF_REMOTE_MDS="true"
            ;;
        u)
            case "$OPTARG" in
                "file")
                    CMF_USERSTORE="FILE"
                    ;;
                "ldap_with_oauth")
                    CMF_USERSTORE="LDAP_WITH_OAUTH"
                    ;;
                "oauth")
                    CMF_USERSTORE="OAUTH"
                    ;;
                "ldap")
                    CMF_USERSTORE="LDAP"
                    ;;
                "none")
                    CMF_USERSTORE="NONE"
                    ;;
                *)
                    printf "Userstore value not recognized: %s !\n" "$OPTARG"
                    usage
                    ;;
            esac
            ;;
        d)
            CMF_DRY_RUN="true"
            ;;
        n)
            CMF_NAMESPACE=$OPTARG
            ;;
        o)
            OPENSHIFT=true
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$CMF_IMAGE_VERSION" ] || [ -z "$CMF_NAMESPACE" ]; then
    printf "\nMust provide arguments with command!"
    usage
fi

if [ ! -z "$CMF_VALUES_FILE" ]; then
    # if values file is set, null out
    CMF_REST_AUTH=""
fi

update_helm_repo () {
    # helm update
    printf "\nUpdating helm repos......\n"
    operator_update_cmd="helm repo update"
    eval $operator_update_cmd
}

create_namespace () {

    source $BASE_DIR/scripts/system/header.sh -t "Creating CMF Namespace"

    if [ ! -z "$CMF_NAMESPACE" ]; then
        if [ "$(kubectl get namespace --ignore-not-found=true | grep -ic $CMF_NAMESPACE)" -le 0 ]; then
            printf "\nCreating Namespace %s for CMF Deployment....\n" "${CMF_NAMESPACE}"
            kubectl create namespace $CMF_NAMESPACE
        else
            printf "\nNamespace exists, skipping creation....\n"
        fi
    fi
}

deploy_kube_resources () {

    # check for k8s cmf_namespace
    if [ "$(kubectl get namespace --ignore-not-found=true | grep -ic $CMF_NAMESPACE)" -le 0 ]; then
        kubectl create namespace $CMF_NAMESPACE || { printf "Error creating Namespace, exiting..."; exit 1; }
    fi

    # Create JKS secret and configmap
    if [ -f "$GEN_DIR/ssl/files/cmf.keystore.jks" ] && [ -f "$GEN_DIR/ssl/files/cmf.truststore.jks" ] && [ -f "$GEN_DIR/ssl/files/cmf.keystore.jksPassword.txt" ] && [ -f "$GEN_DIR/ssl/cmd/cmf/create-jks-cmf-secret.sh" ]; then
        # create secret
        if [ "$(kubectl -n $CMF_NAMESPACE get secret --ignore-not-found=true | grep -ic jks-cmf)" -le 0 ]; then
            source "$GEN_DIR/ssl/cmd/cmf/create-jks-cmf-secret.sh" || exit 1
        else
            printf "jks-cmf Secret already exists, skipping...\n"
        fi
        # create configmap only if CMF_VERSION < 2.4
        if [ $(echo $CMF_IMAGE_VERSION | sed -E "s/^([0-9]+)\.([0-9]+).*/\1\2/") -lt 24 ]; then
            if [ -f "$GEN_DIR/ssl/cmd/cmf/create-cmf-ssl-configmap.sh" ]; then
                if [ "$(kubectl -n $CMF_NAMESPACE get configmap --ignore-not-found=true | grep -ic cmf-server)" -le 0 ]; then
                    source "$GEN_DIR/ssl/cmd/cmf/create-cmf-ssl-configmap.sh"
                else
                    printf "cmf-server-keystore/cmf-server-truststore Configmap exists, skipping...\n"
                fi
            else
                printf "ssl configmap are missing, exiting...\n"
                exit 1
            fi
        fi
    else
        printf "CMF SSL file(s) missing, exiting...\n"
        exit 1
    fi

    # create MDS keyapir secret, we use the same file name for both CP and CMF
    if [ -f "$GEN_DIR/ssl/files/keypair/mds-keypair-private.pem" ] && [ -f "$GEN_DIR/ssl/files/keypair/mds-keypair-public.pem" ] && [ -f "$GEN_DIR/ssl/cmd/keypair/create-cmf-keypair.sh" ]; then
        # create CMF MDS Keypair
        if [ "$(kubectl -n $CMF_NAMESPACE get secret --ignore-not-found=true | grep -ic cmf-keypair)" -le 0 ]; then
            source "$GEN_DIR/ssl/cmd/keypair/create-cmf-keypair.sh" || exit 1
        else
            printf "cmf-keypair Secret exists, skipping...\n"
        fi
    else
        printf "CMF Keypair file(s) missing, exiting...\n"
        exit 1
    fi

    # create mds file user store
    if [ -f "$GEN_DIR/userstore/files/cleartext-userstore.txt" ] && [ -f "$GEN_DIR/userstore/cmd/create-cleartext-userstore-secret.sh" ]; then
        # create Userstore
        if [ "$(kubectl -n $CMF_NAMESPACE get secret --ignore-not-found=true | grep -ic cleartext-userstore)" -le 0 ]; then
            source "$GEN_DIR/userstore/cmd/create-cleartext-userstore-secret.sh" || exit 1
        else
            printf "cleartext-userstore Secret exists, skipping...\n"
        fi
    fi

}

create_value_file () {

    # create values
    gen_file="$GEN_DIR/cmf/values.yaml"
    keystore_password="topsecret"
    truststore_password="topsecret"
    keystore_secret_name="cmf-server-keystore"
    truststore_secret_name="cmf-server-truststore"
    remote_mds_endpoint="https://kafkabroker.confluent.svc.cluster.local:8090"
    cmf_mds_port="8090"
    cmf_mds_endpoint="https://cmf-service.${CMF_NAMESPACE}.svc.cluster.local:${cmf_mds_port}"
    idp_jwks_endpoint_url="https://keycloak.confluentdemo.io/realms/confluentdemo/protocol/openid-connect/certs"
    idp_token_endpoint="https://keycloak.confluentdemo.io/realms/confluentdemo/protocol/openid-connect/token"
    idp_authorization_endpoint="https://keycloak.confluentdemo.io/realms/confluentdemo/protocol/openid-connect/auth"
    idp_expected_issuer="https://keycloak.confluentdemo.io/realms/confluentdemo"
    ldap_endpoint="ldaps://ldap.identity.svc.cluster.local:636"
    cmf_super_user="cmf"
    cmf_super_user_password="cmf-secret"
    mds_private_key="/mnt/secrets/mds/mdsTokenKeyPair.pem"
    mds_public_key="/mnt/secrets/mds/mdsPublicKey.pem"
    keystore_location="/mnt/secrets/certs/keystore.jks"
    truststore_location="/mnt/secrets/certs/truststore.jks"
    cmf_cert_secretname="jks-cmf"

    if [ ! -d "$GEN_DIR/cmf" ]; then
        mkdir -p "$GEN_DIR/cmf"
    fi

    printf "Generating values.yaml...\n"
    # start
    printf "cmf:\n" > "$gen_file"

    # Adding logging verbosity line
    yq -i ".cmf.logging.level.\"root\" = \"INFO\"" -o yaml "$gen_file"
    yq -i ".cmf.logging.level.\"io.confluent.cmf.security\" = \"INFO\"" -o yaml "$gen_file"

    # Configuring AuthZ
    if [ "$CMF_EMBEDDED_MDS" == "true" ] && [ "$CMF_AUTHZ" == "true" ]; then
        yq -i '.cmf.authorization.authority = "cmf"' -o yaml "$gen_file"
    fi

    # Configuring Remote AuthZ
    if [ "$CMF_EMBEDDED_MDS" == "false" ] && [ "$CMF_REMOTE_MDS" == "true" ]; then
        yq -i '.cmf.authorization.authority = "cp-mds"' -o yaml "$gen_file"
        # populate remote mds configs
        yq -i '.cmf.authorization.mdsRestConfig.endpoint = "${remote_mds_endpoint}"' -o yaml "$gen_file"
       
        # if mds endpoint is https
        yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.ssl.truststore.location\" = \"${truststore_location}\"" -o yaml "$gen_file"
        yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.ssl.truststore.password\" = \"${truststore_password}\"" -o yaml "$gen_file"

        # authenticationt to CP MDS
        if [ "$CMF_REMOTE_MDS_TYPE" == "mtls" ]; then
            yq -i '.cmf.authorization.mdsRestConfig.authentication.type = "mtls"' -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.ssl.keystore.location\" = \"${keystore_location}\"" -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.ssl.keystore.password\" = \"${keystore_password}\"" -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.ssl.key.password\" = \"${keystore_password}\"" -o yaml "$gen_file"
        fi

        if [ "$CMF_REMOTE_MDS_TYPE" == "oauth" ]; then
            yq -i '.cmf.authorization.mdsRestConfig.authentication.type = "oauth"' -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.http.auth.credentials.provider\" = \"OAUTHBEARER\"" -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.oauthbearer.token.endpoint.url\" = \"${idp_token_endpoint}\"" -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.oauthbearer.login.client.id\" = \"${cmf_super_user}\"" -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.authentication.config.\"confluent.metadata.oauthbearer.login.client.secret\" = \"${cmf_super_user_password}\"" -o yaml "$gen_file"
        fi

        if [ "$CMF_REMOTE_MDS_TYPE" == "basic" ]; then
            yq -i '.cmf.authorization.mdsRestConfig.authentication.type = "basic"' -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.config.\"confluent.metadata.http.auth.credentials.provider\" = \"BASIC\"" -o yaml "$gen_file"
            yq -i ".cmf.authorization.mdsRestConfig.config.\"confluent.metadata.basic.auth.user.info\" = \"${cmf_super_user}:${cmf_super_user_password}\"" -o yaml "$gen_file"
        fi
    fi

    # if embedded mds, configure additional items
    if [ "$CMF_EMBEDDED_MDS" == "true" ]; then
        
        yq -i '.cmf.mds.enabled = true' -o yaml "$gen_file"
        yq -i ".cmf.mds.port = ${cmf_mds_port}" -o yaml "$gen_file"
        yq -i ".cmf.mds.advertised-listeners = \"${cmf_mds_endpoint}\"" -o yaml "$gen_file"

        # must configure PEM-encodded RSA key, file must be mounted
        yq -i ".cmf.mds.token-key-path = \"${mds_private_key}\"" -o yaml "$gen_file"
        # required when user-store = FILE or LDAP
        if [ "$CMF_USERSTORE" == "FILE" ] || [ "$CMF_USERSTORE" == "LDAP" ]; then
            yq -i ".cmf.mds.public-key-path = \"${mds_public_key}\"" -o yaml "$gen_file"
        fi

        # mounted volumes
        yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].name = \"cmf-keypair\"" -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].secret.secretName = \"cmf-keypair\"" -o yaml "$gen_file"
        ((CMF_VOLUME_POSITION++))

        yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].name = \"cmf-keypair\"" -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].mountPath = \"/mnt/secrets/mds\"" -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].readOnly = true" -o yaml "$gen_file"
        ((CMF_VOLUMEMOUNT_POSITION++))

        # ssl config
        yq -i ".cmf.ssl.keystore = \"${keystore_location}\"" -o yaml "$gen_file"
        yq -i ".cmf.ssl.keystore-password = \"${keystore_password}\"" -o yaml "$gen_file"
        yq -i ".cmf.ssl.truststore = \"${truststore_location}\"" -o yaml "$gen_file"
        yq -i ".cmf.ssl.truststore-password = \"${truststore_password}\"" -o yaml "$gen_file"
        if [ "$CMF_REST_AUTH" == "mtls" ]; then
            yq -i '.cmf.ssl.client-auth = "need"' -o yaml "$gen_file"
        fi

        # mounted volumes
        if [ $(echo $CMF_IMAGE_VERSION | sed -E "s/^([0-9]+)\.([0-9]+).*/\1\2/") -ge 24 ]; then
            # CMF 2.4.x+
            yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].name = \"certs\"" -o yaml "$gen_file"
            yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].secret.secretName = \"${cmf_cert_secretname}\"" -o yaml "$gen_file"
            ((CMF_VOLUME_POSITION++))

            yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].name = \"certs\"" -o yaml "$gen_file"
            yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].mountPath = \"/mnt/secrets/certs\"" -o yaml "$gen_file"
            yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].readOnly = true" -o yaml "$gen_file"
            ((CMF_VOLUMEMOUNT_POSITION++))
        else
            # CMF < 2.4.x, mount via configmap
            yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].name = \"keystore\"" -o yaml "$gen_file"
            yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].configMap.name = \"${keystore_secret_name}\"" -o yaml "$gen_file"
            ((CMF_VOLUME_POSITION++))

            yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].name = \"truststore\"" -o yaml "$gen_file"
            yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].configMap.name = \"${truststore_secret_name}\"" -o yaml "$gen_file"
            ((CMF_VOLUME_POSITION++))

            yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].name = \"truststore\"" -o yaml "$gen_file"
            yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].mountPath = \"/mnt/secrets/certs\"" -o yaml "$gen_file"
            ((CMF_VOLUMEMOUNT_POSITION++))

            yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].name = \"keystore\"" -o yaml "$gen_file"
            yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].mountPath = \"/mnt/secrets/certs\"" -o yaml "$gen_file"
            ((CMF_VOLUMEMOUNT_POSITION++))
        fi

        # config based on user-store
        # user-store = OAUTH or LDAP_WITH_OAUTH
        if [ "$CMF_USERSTORE" == "OAUTH" ] || [ "$CMF_USERSTORE" == "LDAP_WITH_OAUTH" ]; then
            yq -i '.cmf.mds.authentication-method = "BEARER"' -o yaml "$gen_file"

            # IDP
            yq -i ".cmf.mds.jwks-endpoint-url = \"${idp_jwks_endpoint_url}\"" -o yaml "$gen_file"
            yq -i ".cmf.mds.expected-issuer = \"${idp_expected_issuer}\"" -o yaml "$gen_file"

            yq -i ".cmf.mds.super-users = \"User:${cmf_super_user}\"" -o yaml "$gen_file"

            # SSO UI
            yq -i ".cmf.mds.extra-configs.\"confluent.metadata.server.sso.mode\" = \"oidc\"" -o yaml "$gen_file"
            yq -i ".cmf.mds.extra-configs.\"confluent.oidc.idp.client.id\" = \"${cmf_super_user}\"" -o yaml "$gen_file"
            yq -i ".cmf.mds.extra-configs.\"confluent.oidc.idp.client.secret\" = \"${cmf_super_user_password}\"" -o yaml "$gen_file"
            yq -i ".cmf.mds.extra-configs.\"confluent.oidc.idp.issuer\" = \"${idp_expected_issuer}\"" -o yaml "$gen_file"
            yq -i ".cmf.mds.extra-configs.\"confluent.oidc.idp.jwks.endpoint.uri\" = \"${idp_jwks_endpoint_url}\"" -o yaml "$gen_file"
            yq -i ".cmf.mds.extra-configs.\"confluent.oidc.idp.authorize.base.endpoint.uri\" = \"${idp_authorization_endpoint}\"" -o yaml "$gen_file"
            yq -i ".cmf.mds.extra-configs.\"confluent.oidc.idp.token.base.endpoint.uri\" = \"${idp_token_endpoint}\"" -o yaml "$gen_file"

            # Configure REST API to accept OAUTH
            yq -i '.cmf.authentication.type = "oauth"' -o yaml "$gen_file"
            yq -i ".cmf.authentication.config.\"oauthbearer.jwks.endpoint.uri\" = \"${idp_jwks_endpoint_url}\"" -o yaml "$gen_file"
            yq -i ".cmf.authentication.config.\"oauthbearer.expected.issuer\" = \"${idp_expected_issuer}\"" -o yaml "$gen_file"
            yq -i ".cmf.authentication.config.\"oauthbearer.sub.claim.name\" = \"sub\"" -o yaml "$gen_file"

            yq -i ".cmf.authentication.config.\"public.key.path\" = \"${mds_public_key}\"" -o yaml "$gen_file"
            yq -i ".cmf.authentication.config.\"confluent.metadata.bootstrap.server.urls\" = \"${cmf_mds_endpoint}\"" -o yaml "$gen_file"

            yq -i ".cmf.authentication.config.\"confluent.metadata.http.auth.credentials.provider\" = \"OAUTHBEARER\"" -o yaml "$gen_file"
            yq -i ".cmf.authentication.config.\"confluent.metadata.oauthbearer.token.endpoint.url\" = \"${idp_token_endpoint}\"" -o yaml "$gen_file"
            yq -i ".cmf.authentication.config.\"confluent.metadata.oauthbearer.login.client.id\" = \"${cmf_super_user}\"" -o yaml "$gen_file"
            yq -i ".cmf.authentication.config.\"confluent.metadata.oauthbearer.login.client.secret\" = \"${cmf_super_user_password}\"" -o yaml "$gen_file"

            yq -i '.cmf.kafka.oauthbearerAllowedUrls = "*"' -o yaml "$gen_file"

            # ui
            yq -i '.cmf.ui.auth.basicAuthEnabled = false' -o yaml "$gen_file"
            yq -i '.cmf.ui.auth.ssoEnabled = true' -o yaml "$gen_file"

            # jvmArgs
            yq -i ".jvmArgs = \"-Djavax.net.ssl.trustStore=${truststore_location} -Djavax.net.ssl.trustStorePassword=${truststore_password}\"" -o yaml "$gen_file"
        fi
    fi

    if [ "$CMF_USERSTORE" == "LDAP" ]; then

        yq -i '.cmf.mds.user-store = "LDAP"' -o yaml "$gen_file"

        # bearer or basic?
        yq -i '.cmf.mds.authentication-method = "BEARER"' -o yaml "$gen_file"

        yq -i '.cmf.mds.callback-handler-class = "io.confluent.security.auth.provider.ldap.LdapAuthenticateCallbackHandler"' -o yaml "$gen_file"
        yq -i '.cmf.mds.sasl-mechanism = "PLAIN"' -o yaml "$gen_file"
        
        # LDAP connection
        yq -i ".cmf.mds.extra-configs.\"ldap.java.naming.provider.url\" = \"${ldap_endpoint}\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.java.naming.security.principal\" = \"cn=admin,dc=confluentdemo,dc=io\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.java.naming.security.credentials\" = \"ldapadmin-topsecret!\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.java.naming.security.authentication\" = \"simple\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.user.search.base\" = \"ou=users,dc=confluentdemo,dc=io\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.user.name.attribute\" = \"cn\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.user.object.class\" = \"posixAccount\"" -o yaml "$gen_file"
        # optional group search mode
        yq -i ".cmf.mds.extra-configs.\"ldap.search.mode\" = \"GROUPS\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.group.search.base\" = \"ou=groups,dc=confluentdemo,dc=io\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.group.object.class\" = \"posixGroup\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.group.name.attribute\" = \"cn\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.group.member.attribute\" = \"memberUid\"" -o yaml "$gen_file"
        yq -i ".cmf.mds.extra-configs.\"ldap.group.member.attribute.pattern\" = \"cn=(.*),ou=users,dc=confluentdemo,dc=io\"" -o yaml "$gen_file"

        # mds config
        yq -i '.cmf.authentication.type = "oauth"' -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"public.key.path\" = \"${mds_public_key}\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.bootstrap.server.urls\" = \"${cmf_mds_endpoint}\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.enable.server.urls.refresh\" = \"false\"" -o yaml "$gen_file"

        yq -i '.cmf.kafka.oauthbearerAllowedUrls = "*"' -o yaml "$gen_file"

        # ui
        yq -i '.cmf.ui.auth.basicAuthEnabled = true' -o yaml "$gen_file"
        yq -i '.cmf.ui.auth.ssoEnabled = false' -o yaml "$gen_file"
    fi

    # File Based Userstore
    if [ "$CMF_USERSTORE" == "FILE" ]; then

        yq -i '.cmf.mds.user-store = "FILE"' -o yaml "$gen_file"
        yq -i '.cmf.mds.user-store-file-path = "/mnt/secrets/mds/mds-users/userstore.txt"' -o yaml "$gen_file"

        yq -i '.cmf.mds.authentication-method = "BEARER"' -o yaml "$gen_file"
        
        yq -i ".cmf.mds.super-users = \"User:${cmf_super_user}\"" -o yaml "$gen_file"

        # mds config
        yq -i '.cmf.authentication.type = "oauth"' -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"public.key.path\" = \"/mnt/secrets/mds/mdsPublicKey.pem\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.bootstrap.server.urls\" = \"${cmf_mds_endpoint}\"" -o yaml "$gen_file"

        yq -i '.cmf.kafka.oauthbearerAllowedUrls = "*"' -o yaml "$gen_file"

         # ui
        yq -i '.cmf.ui.auth.basicAuthEnabled = true' -o yaml "$gen_file"
        yq -i '.cmf.ui.auth.ssoEnabled = false' -o yaml "$gen_file"

        yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].name = \"cleartext-userstore\"" -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].secret.secretName = \"cleartext-userstore\"" -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumes[${CMF_VOLUME_POSITION}].secret.defaultMode = 0600" -o yaml "$gen_file"
        ((CMF_VOLUME_POSITION++))

        yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].name = \"cleartext-userstore\"" -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].mountPath = \"/mnt/secrets/mds/mds-users\"" -o yaml "$gen_file"
        yq -i ".mountedVolumes.volumeMounts[${CMF_VOLUMEMOUNT_POSITION}].readOnly = true" -o yaml "$gen_file"
        ((CMF_VOLUMEMOUNT_POSITION++))
    fi

    # Configure CMF REST Basic
    if [ "$CMF_REST_AUTH" == "basic" ]; then
        #yq -i '.cmf.authentication.type = "basic"' -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"rest.servlet.initializor.classes\" = \"io.confluent.common.security.jetty.initializer.AuthenticationHandler\"" -o yaml "$gen_file"
    fi

    # Configure CMF REST SSO
    if [ "$CMF_REST_AUTH" == "sso" ]; then
        
        yq -i '.cmf.authentication.type = "oauth"' -o yaml "$gen_file"

        yq -i ".cmf.authentication.config.\"rest.servlet.initializor.classes\" = \"io.confluent.common.security.jetty.initializer.AuthenticationHandler\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"oauthbearer.jwks.endpoint.url\" = \"${idp_jwks_endpoint_url}\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"oauthbearer.expected.issuer\" = \"${idp_expected_issuer}\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"oauthbearer.sub.claim.name\" = \"sub\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"oauthbearer.groups.claim.name\" = \"groups\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.bootstrap.server.urls\" = \"${cmf_mds_endpoint}\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.enable.serverurls.refresh\" = \"false\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.http.auth.credentials.provider\" = \"OAUTHBEARER\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.oauthbearer.token.endpoint.url\" = \"${idp_token_endpoint}\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.oauthbearer.login.client.id\" = \"${cmf_super_user}\"" -o yaml "$gen_file"
        yq -i ".cmf.authentication.config.\"confluent.metadata.oauthbearer.login.client.secret\" = \"${cmf_super_user_password}\"" -o yaml "$gen_file"
    fi

    # mtls
    # when mtls is configured, no UI is configured
    if [ "$CMF_REST_AUTH" == "mtls" ]; then

        yq -i '.cmf.authentication.type = "mtls"' -o yaml "$gen_file"
        
        # ssl principal mapping rules
        yq -i ".cmf.authentication.config.\"auth.ssl.principal.mapping.rules\" = \"RULE:^CN=(.*?),.*/$1/,DEFAULT\"" -o yaml "$gen_file"

        yq -i '.cmf.ssl.client-auth = "need"' -o yaml "$gen_file"
    fi

    printf "CMF Values File Generated!\n"
}

deploy_cmf () {

    l_deployment_name="confluent-manager-for-apache-flink"

    # check if CMF already deployed
    if [ ! -z "$(kubectl -n $CMF_NAMESPACE get deployment --ignore-not-found=true | grep -ic confluent-operator)" ]; then

        # create encryption key
        if [ "$ENCRYPTED_DEPLOYMENT" == "true" ]; then
            if [ "$(kubectl -n $CMF_NAMESPACE get secret --ignore-not-found=true | grep -ic cmf-encryption-key)" -le 0 ]; then
                printf "\nCreating necessary encryption key for CMF deployment...\n"
                source $BASE_DIR/scripts/ssl/create-cmf-key.sh -n $CMF_NAMESPACE
                # actually deploy the secret
                if [ -f "$BASE_DIR/generated/ssl/cmd/cmf/create-cmf-encryption-secret.sh" ]; then
                    source $BASE_DIR/generated/ssl/cmd/cmf/create-cmf-encryption-secret.sh
                else
                    printf "Bash script for cmf secret not found, exiting...\n"
                    exit 1
                fi
            fi

            # validation
            if [ "$(kubectl -n $CMF_NAMESPACE get secrets --ignore-not-found=true | grep -ic cmf-encryption-key)" -eq 1 ]; then
                printf "cmf-encryption-key k8s secret deployed!\n"
            else
                printf "cmf-encryption-key secret not found, exiting...\n"
                exit 1
            fi

            CMF_HELM_INSTALL_OPTS="--set encryption.key.kubernetesSecretName=cmf-encryption-key --set encryption.key.kubernetesSecretProperty=encryption-key --set cmf.sql.production=true"
        else
            # set encryption to false, default is false, but just in case
            CMF_HELM_INSTALL_OPTS="--set cmf.sql.production=false"
        fi

        # for opneshift
        if [ "$OPENSHIFT" == "true" ]; then
            CMF_HELM_INSTALL_OPTS=" --set podSecurity.securityContext.fsGroup=null --set podSecurity.securityContext.runAsUser=null"
        fi

        # creating helm install command
        if [ ! -z "$CMF_VALUES_FILE" ] && [ -f "$CMF_VALUES_FILE" ]; then
            CMF_HELM_INSTALL_OPTS+=" --values $CMF_VALUES_FILE"
        else
        #elif [ ! -z "$CMF_REST_AUTH" ]; then
            CMF_HELM_INSTALL_OPTS+=" --values $BASE_DIR/generated/cmf/values.yaml"
        #else
        #    printf "No custom values file, skipping....\n"
        fi

        install_cmd="helm upgrade --install $CMF_HELM_NAME -n $CMF_NAMESPACE $CMF_HELM_INSTALL_OPTS"
        
        # add version
        if [ ! -z "$CMF_VERSION" ]; then
            install_cmd="$install_cmd --version=$CMF_VERSION"
        fi

        # finalizing helm install command
        install_cmd="$install_cmd $CMF_HELM_REPO"
        
        # execute installing Confluent Operator
        printf "\n\nHelm Install Command: %s\n" "${install_cmd}"
        # Execute helm install
        eval "$install_cmd"
       
        # wait for CMF Operator to be ready
        timeout=180
        sleep_in_seconds=5

        printf "Command: %s %s\n" "$CMF_NAMESPACE" "$l_deployment_name"
        while [ "$(kubectl -n $CMF_NAMESPACE get pod | grep $l_deployment_name |  grep -c '1/1')" -lt 1 ]; do
            if [ $timeout -le 0 ]; then
                printf "\nTimed out waiting on CMF deployment, %s seconds\n" "$timeout"
                exit 1
            fi
            printf "\nWaiting for CMF deployment to be ready..."
            sleep $sleep_in_seconds
            timeout=$((timeout-sleep_in_seconds))
        done
        
        printf "\n"

        if [ -f "$BASE_DIR/configs/cmf/cmf-loadbalancer.yaml" ]; then
            # copy to generated
            cp "$BASE_DIR/configs/cmf/cmf-loadbalancer.yaml" "$BASE_DIR/generated/cmf/cmf-loadbalancer.yaml"
            # modify namespace
            yq -i ".metadata.namespace = \"${CMF_NAMESPACE}\"" -o yaml "$BASE_DIR/generated/cmf/cmf-loadbalancer.yaml"
            # TODO: port set for 80 or 443
            #yq -i ".spec.ports[].port = 80" -o yaml "$GEN_DIR/cmf/cmf-loadbalancer.yaml"

            # apply yaml
            printf "Creating CMF Loadbalancer...\n"
            kubectl apply -f "$BASE_DIR/generated/cmf/cmf-loadbalancer.yaml"
        else
            printf "CMF Loadbalancer yaml file missing! Skipping!\n"
        fi
        
        printf "\nConfluent Manager for Apache Flink Ready!\n"
    else
        printf "\nCMF already deployed, skipping....\n"
    fi
    
}

source $BASE_DIR/scripts/system/header.sh -t "Deploying Confluent Manager for Apache Flink"

printf "\nAttempting to install CMF\n"
printf "\n\tHelm Version: %s\n\tNamespace: %s\n" "$CMF_VERSION" "$CMF_NAMESPACE"
if [ ! -z "$CMF_REST_AUTH" ]; then
    printf "Authentication Method: %s\n" "$CMF_REST_AUTH"
else
    printf "Authentication Method: None\n"
fi
if [ ! -z "$CMF_VALUES_FILE" ]; then
    printf "Custom Values File: %s\n" "$CMF_VALUES_FILE"
fi

if [ "$CMF_DRY_RUN" == "false" ]; then
    # call to update helm repo
    update_helm_repo
    
    # create namespace
    create_namespace

    # create assets
    deploy_kube_resources
fi

# create values file if one is not provided
if [ -z "$CMF_VALUES_FILE" ]; then
    create_value_file
fi

if [ "$CMF_DRY_RUN" == "false" ]; then
    # deploy CFK
    deploy_cmf
    
    CHECKED_CMF_VERSION=$(kubectl -n $CMF_NAMESPACE get deployment confluent-manager-for-apache-flink -o jsonpath='{.metadata.labels}' | jq -r '.["helm.sh/chart"]')
    if [ "$CHECKED_CMF_VERSION" ]; then
        printf "\nCMF Deployed Version: %s\n" "$CHECKED_CMF_VERSION"
    else
        printf "\nCould not determine CMF version deployed version, deployment failed...\n"
        exit 1
    fi
fi
