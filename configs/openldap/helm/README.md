# openldap

OpenLDAP deployment, pre-populated with the following accounts for testing

## Service Accounts Credentials

| username        | password               |
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

| username          | password                 |
| ----------------- | ------------------------ |
| superuser         | superuser-secret         |
| baduser           | baduser-secret           |
| barnierubble      | barnierubble-secret      |
| charliesheen      | charliesheen-secret      |
| donnatroy         | donnatroy-secret         |
| ororomunroe       | ororomunroe-secret       |
| sambridges        | sambridges-secret        |
| alicelookingglass | alicelookingglass-secret |

## Ldap Groups

| groups        | members                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| service       | zookeeper, kafkacontroller, kafkabroker, mds, metricsreporter, auditlogger, kafkarestclass, kafkacli, kafkarestproxy, krpconsumer, krpproducer, krpadmin, krpdeveloper, connect, connectconsumer, connectproducer, connectadmin, replicator, schemaregistry, srconsumer, srproducer, sradmin, srexporter, ksqldb, ksqlcli, ksqlconsumer, ksqlproducer, ksqladmin, ksqldeveloper, controlcenter, cpc, cmf, flink, flinkconsumer, flinkproducer, flinkadmin |
| developers    | kafkacli, krpdeveloper, ksqlcli, ksqladmin, ksqldeveloper                                                                                                                                                                                                                                                                                                                                                                                                 |
| c3users       | barnierubble, charliesheen, donnatroy, ororomunroe, sambridges, alicelookingglass, devuser, superuser                                                                                                                                                                                                                                                                                                                                                     |
| readonlyusers | barnierubble, charliesheen, devuser                                                                                                                                                                                                                                                                                                                                                                                                                       |
| krpusers      | kafkarestproxy, krpconsumer, krpproducer, krpadmin, krpdeveloper                                                                                                                                                                                                                                                                                                                                                                                          |
| connectusers  | connect, connectconsumer, connectproducer, connectadmin, replicator                                                                                                                                                                                                                                                                                                                                                                                       |
| srusers       | schemaregistry, srconsumer, srproducer, sradmin, srexporter                                                                                                                                                                                                                                                                                                                                                                                               |
| ksqlusers     | ksqldb, ksqlcli, ksqlconsumer, ksqlproducer, ksqladmin, ksqldeveloper                                                                                                                                                                                                                                                                                                                                                                                     |
| adminusers    | superuser, mds, sambridges, ororomunroe                                                                                                                                                                                                                                                                                                                                                                                                                   |
| flinkusers    | flink, flinkconsumer, flinkproducer, flinkadmin                                                                                                                                                                                                                                                                                                                                                                                                           |
