helm repo add localstack-repo https://helm.localstack.cloud
helm upgrade --install localstack localstack-repo/localstack -n s3

######################

kubectl port-forward pods/<pod-name> 4566:4566
aws s3 mb s3://mybucket --region us-west-1 --endpoint-url=http://localhost:4566 # create bucket for mongodb-backup 
aws s3 ls --region us-west-1 --endpoint-url=http://localhost:4566 # list buckets 
