# keycloak

Keycloak deployment, pre-populated with the following accounts for testing

## Service Accounts Credentials

| clientId        | clientSecret           |
| --------------- | ---------------------- |
| zookeeper       | zookeeper-secret       |
| kafkacontroller | kafkacontroller-secret |
| kafkabroker     | kafkabroker-secret     |
| mds             | mds-secret             |
| metricsreporter | metricsreporter-secret |
| auditlogger     | auditlogger-secret     |
| kafkarestclass  | kafkarestclass-secret  |
| kafkacli        | kafkacli-secret        |
| kafkarestproxy  | kafkarestproxy-secret  |
| krpconsumer     | krpconsumer-secret     |
| krpproducer     | krpproducer-secret     |
| krpadmin        | krpadmin-secret        |
| krpdeveloper    | krpdeveloper-secret    |
| connect         | connect-secret         |
| connectconsumer | connectconsumer-secret |
| connectproducer | connectproducer-secret |
| connectadmin    | connectadmin-secret    |
| replicator      | replicator-secret      |
| schemaregistry  | schemaregistry-secret  |
| srconsumer      | srconsumer-secret      |
| srproducer      | srproducer-secret      |
| sradmin         | sradmin-secret         |
| srexporter      | srexporter-secret      |
| ksqldb          | ksqldb-secret          |
| ksqlcli         | ksqlcli-secret         |
| ksqlconsumer    | ksqlconsumer-secret    |
| ksqlproducer    | ksqlproducer-secret    |
| ksqladmin       | ksqladmin-secret       |
| ksqldeveloper   | ksqldeveloper-secret   |
| controlcenter   | controlcenter-secret   |
| flink           | flink-secret           |
| flinkconsumer   | flinkconsumer-secret   |
| flinkproducer   | flinkproducer-secret   |
| flinkadmin      | flinkadmin-secret      |
| cmf             | cmf-secret             |
| cpc             | cpc-secret             |

## User Account Credentials

| uuid                                 | username                           | password                 |
| ------------------------------------ | ---------------------------------- | ------------------------ |
| 96555a11-010d-48e8-80dc-5115a9745429 | superuser@confluentdemo.io         | superuser-secret         |
| a5969cda-64fb-4849-a76a-1c2ee121d2ca | baduser@confluentdemo.io           | baduser-secret           |
| 69e208d7-57d2-435a-a74a-c9f06cee1ff7 | barnierubble@confluentdemo.io      | barnierubble-secret      |
| 8af4ccbe-6cb5-483c-90c9-be1db8dcde7a | charliesheen@confluentdemo.io      | charliesheen-secret      |
| c1ca2532-8cfe-47f9-b89e-3a2c9e7a76e0 | donnatroy@confluentdemo.io         | donnatroy-secret         |
| 57dfd9bd-a451-43a9-b7a8-fe9995b0e2cf | ororomunroe@confluentdemo.io       | ororomunroe-secret       |
| 9db8b704-2f15-4187-a43d-d101be605836 | sambridges@confluentdemo.io        | sambridges-secret        |
| d5db95e2-a025-48e5-95a3-4e7893130926 | alicelookingglass@confluentdemo.io | alicelookingglass-secret |

## Groups

| groups              | members                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| administrators      | superuser@confluentdemo.io                                                                                                                                                                                                                                                                                                                                                                                                                                |
| adminusers          | connectadmin, flinkadmin, ksqladmin, sradmin                                                                                                                                                                                                                                                                                                                                                                                                              |
| auditors            | alicelookingglass@confluentdemo.io, auditlogger                                                                                                                                                                                                                                                                                                                                                                                                           |
| c3users             | alicelookingglass@confluentdemo.io, baduser@confluentdemo.io, barnierubble@confluentdemo.io, charliesheen@confluentdemo.io, donnatroy@confluentdemo.io, ororomunroe@confluentdemo.io, sambridges@confluentdemo.io, superuser@confluentdemo.io                                                                                                                                                                                                             |
| connectusers        | barnierubble@confluentdemo.io, charliesheen@confluentdemo.io, connect, connectadmin, connectconsumer, connectproducer, replicator                                                                                                                                                                                                                                                                                                                         |
| cp_components       | controlcenter, flink, kafkabroker, kafkacontroller, kafkarestproxy, ksqldb, mds, metricsreporter, replicator, schemaregistry, zookeeper                                                                                                                                                                                                                                                                                                                   |
| broker_apps         | auditlogger, kafkabroker, mds, metricsreporter                                                                                                                                                                                                                                                                                                                                                                                                            |
| connect_apps        | connect, connectadmin, connectconsumer, connectproducer, replicator                                                                                                                                                                                                                                                                                                                                                                                       |
| controlcenter_apps  | controlcenter                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| controller_apps     | auditlogger, kafkacontroller, mds, metricsreporter                                                                                                                                                                                                                                                                                                                                                                                                        |
| flink_apps          | flink, flinkadmin, flinkconsumer, flinkproducer                                                                                                                                                                                                                                                                                                                                                                                                           |
| ksql_apps           | ksqladmin, ksqlcli, ksqlconsumer, ksqlproducer, ksqldb, ksqldeveloper                                                                                                                                                                                                                                                                                                                                                                                     |
| restproxy_apps      | kafkarestproxy, krpadmin, krpconsumer, krpproducer, krpdeveloper                                                                                                                                                                                                                                                                                                                                                                                          |
| schameregistry_apps | schemaregistry, sradmin, srconsumer, srexporter, srproducer                                                                                                                                                                                                                                                                                                                                                                                               |
| developers          | charliesheen@confluentdemo.io, donnatroy@confluentdemo.io, ororomunroe@confluentdemo.io, sambridges@confluentdemo.io                                                                                                                                                                                                                                                                                                                                      |
| billing             | charliesheen@confluentdemo.io                                                                                                                                                                                                                                                                                                                                                                                                                             |
| iot                 | donnatroy@confluentdemo.io                                                                                                                                                                                                                                                                                                                                                                                                                                |
| notifications       | ororomunroe@confluentdemo.io                                                                                                                                                                                                                                                                                                                                                                                                                              |
| purchasing          | sambridges@confluentdemo.io                                                                                                                                                                                                                                                                                                                                                                                                                               |
| employees           | alicelookingglass@confluentdemo.io, barnierubble@confluentdemo.io, charliesheen@confluentdemo.io, donnatroy@confluentdemo.io, ororomunroe@confluentdemo.io, sambridges@confluentdemo.io                                                                                                                                                                                                                                                                   |
| flinkusers          | charliesheen@confluentdemo.io, donnatroy@confluentdemo.io, flink, flinkadmin, flinkconsumer, flinkproducer                                                                                                                                                                                                                                                                                                                                                |
| krpusers            | alicelookingglass@confluentdemo.io, sambridges@confluentdemo.io, kafkarestproxy, krpadmin, krpconsumer, krpdeveloper, krpproducer                                                                                                                                                                                                                                                                                                                         |
| ksqlusers           | charliesheen@confluentdemo.io, sambridges@confluentdemo.io, ksqladmin, ksqlcli, ksqlconsumer, ksqldb, ksqldeveloper, ksqlproducer                                                                                                                                                                                                                                                                                                                         |
| operators           | barnierubble@confluentdemo.io                                                                                                                                                                                                                                                                                                                                                                                                                             |
| readonlyusers       | donnatroy@confluentdemo.io, ororomunroe@confluentdemo.io                                                                                                                                                                                                                                                                                                                                                                                                  |
| service             | auditlogger, cmf, connect, connectadmin, connectconsumer, connectproducer, controlcenter, cpc, flink, flinkadmin, flinkconsumer, flinkproducer, kafkabroker, kafkacli, kafkacontroller, kafkarestclass, kafkarestproxy, krpadmin, krpconsumer, krpdeveloper, krpproducer, ksqladmin, ksqlcli, ksqlconsumer, ksqldb, ksqldeveloper, ksqlproducer, mds, metricsreporter, replicator, schemaregistry, sradmin, srconsumer, srexporter, srproducer, zookeeper |
| srusers             | donnatroy@confluentdemo.io, sambridges@confluentdemo.io, schemaregistry, sradmin, srconsumer, srexporter, srproducer                                                                                                                                                                                                                                                                                                                                      |
