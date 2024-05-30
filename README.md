# MongoDB

# About

The Percona Operator for MongoDB automates the creation, modification, or deletion of items in your Percona Server for MongoDB environment. The Operator contains the necessary Kubernetes settings to maintain a consistent Percona Server for MongoDB instance.

We use helm charts provided by Percona for setup of MongoDB.
https://github.com/percona/percona-helm-charts/blob/main/charts/psmdb-db/README.md

## Design overview

![Percona MongoDB Architecure](https://docs.percona.com/percona-operator-for-mongodb/assets/images/replication.svg)
You can get to know more about it by refering to link given below:
https://docs.percona.com/percona-operator-for-mongodb/architecture.html

# Installation

1. MongoDB Operator
2. MongoDB Cluster

#### MongoDB Operator Helm chart installation

1. Install mongodb operator chart

```
helm install realease-name charts-location -n namespace
helm install mongodb-operator psmdb-operator -n mongodb-db
```

#### Uinstallation

2. Uninstall mongodb operator

```
helm uninstall mongodb-operator -n -n mongodb-db
```

## MongoDB Cluster Helm chart installation

1. Install mongodb cluster chart

```
helm install mongodb-db psmdb-db -n mongodb-db
```

## MongoDB Cluster Helm chart Un-installation

5. Uninstall mongodb cluster chart

```
helm uninstall mongodb-db -n mongodb-db
```

Backup configuration in values.yaml

```
backup:
  enabled: true
  image:
    repository: percona/percona-backup-mongodb
    tag: 1.8.1
  serviceAccountName: percona-server-mongodb-operator
  storages:
     storage-name:
       type: s3
       s3:
         bucket: bucket
         credentialsSecret: storage-secret
         region: region-name
         prefix: data/pbm
         endpointUrl: endpoint-url
         insecureSkipTLSVerify: true
  pitr:
    enabled: false
  tasks:
   - name: daily-twice
     enabled: true
     schedule: "0 */12 * * *"
     keep: 14
     storageName: storage-name
     compressionType: gzip
```

`Note: Create the Secrets file with these base64-encoded keys using following command: `

```
$ echo -n 'plain-text-string' | base64 --wrap=0
```

### Backup secret

```

apiVersion: v1
kind: Secret
metadata:
  name: my-cluster-name-backup-s3
type: Opaque
data:
  AWS_ACCESS_KEY_ID: base64-encoded-access-key-id
  AWS_SECRET_ACCESS_KEY: base64-encoded-secret-access-key
```

Sample yamls to restore from backup within same & different cluster are present as restoreSame.yaml & restoreDiff.yaml.

##### Below are following steps to debug the backup & restore process.

#

```
Restore in same cluster
apiVersion: psmdb.percona.com/v1
kind: PerconaServerMongoDBRestore
metadata:
  name: restore-mongodb-4
spec:
  clusterName: mongodb-db
  storageName: storage-name
  backupName: 2024-03-07T18:00:21Z
  insecureSkipTLSVerify: true
```

#

---

```
# Restore in different cluster
apiVersion: psmdb.percona.com/v1
kind: PerconaServerMongoDBRestore
metadata:
  name: restore-mongodb-diff-cluster-1
spec:
  clusterName: mongodb-db
  storageName: storage-name
  backupSource:
    destination: s3://mongo-backup/2024-03-11T14:08:23Z
    s3:
      region: us-west-2
      bucket: mongo-backup
      prefix: data/pbm/backup
      endpointUrl: endpoint-url
      credentialsSecret: storage-backup-s3
      insecureSkipTLSVerify: true
```

##### Backup Debugging

#

```
oc -n mongodb get psmdb-backup               # get list of backups
oc -n mongodb get psmdb-restore              # get list of restores
oc logs pod/mongodb-db-rs0-0 -c backup-agent    # log of the backup agent running [ 2/2 ] in pod/mongodb-db-rs0-0 { Important }
oc -n mongodb get psmdb-backup cron-mongodb-db-20240307081000-krx8p -o yaml    # get details of backup cron yaml
oc -n mongodb  create -f file.yaml   # create backup/restore
oc -n mongodb describe perconaservermongodbrestore.psmdb.percona.com/restore-mongodb  # describe any particular backup
oc -n mongodb delete perconaservermongodbrestore.psmdb.percona.com/restore-mongodb  # describe any particular backup
```

-- inside the backup agent

```pbm list
pbm status
pbm help
```

Use aws-cli
First configure aws with accesss key and secrets

```
aws configure
aws --endpoint endpoint_url --no-verify-ssl s3api  list-objects --bucket bucket-name
```

Total size of bucket

```
aws --endpoint endpoint_url --no-verify-ssl s3api list-objects  --bucket bucket-name  --output json --query "[sum(Contents[].Size), length(Contents[])]" | awk  'NR!=2 {print $0;next}  NR==2 {print $0/1024/1024/1024" GB"}'
```

https://docs.percona.com/percona-operator-for-mongodb/backups.html

# Monitoring

To enable MongoDB database monitoring,

- Setup sidecar container for MongoDB exporter
- Setup service for MongoDB container
- Setup service monitors for MongoDB

Monitors installation:

```
cd mongodb-monitoring-configs
oc create -f . -n values.yaml
```

MongoDB Exporter sidecar configuration

```
sidecars:
  - image: >-
      percona/mongodb_exporter:0.38
    env:
      - name: EXPORTER_USER
        valueFrom:
          secretKeyRef:
            name: mongodb-db-secrets
            key: MONGODB_CLUSTER_ADMIN_USER
      - name: EXPORTER_PASS
        valueFrom:
          secretKeyRef:
            name: mongodb-db-secrets
            key: MONGODB_CLUSTER_ADMIN_PASSWORD
      - name: POD_NAME
        valueFrom:
          fieldRef:
            apiVersion: v1
            fieldPath: metadata.name
      - name: MONGODB_URI
        value: "mongodb://$(EXPORTER_USER):$(EXPORTER_PASS)@$(POD_NAME)"
    args:
      - '--discovering-mode'
      - '--compatgtible-mode'
      - '--collect-all'
      - '--log.level=debug'
      - '--mongodb.uri=$(MONGODB_URI)'
    name: metrics

```

More documentation of Debugging can be found here:
`https://docs.percona.com/percona-operator-for-mongodb/debug.html`

---
