## Usage/Examples

You can test the cluster using this link: http://35.238.39.113:8000/

Make sure you have gcloud setup correctly with an admin service account, then run the following commands.
Make sure Terraform is also installed.

```terraform
terraform init
terraform apply --auto-approve
```

Run the previous commands in the given order while inside the K8s directory.

```yaml
kubectl -f redis.yml apply
kubectl -f redis-svc.yml apply
kubectl -f configMap.yml apply
kubectl -f app.yml apply
kubectl -f LoadBalancer.yml apply
```

## Notes:

1. Make sure you edit the gcr image name in `app.yml`

2. Use `kubectl get svc` to get the IP of your `LoadBalancer` once it's created

3. Insure that CloudResourceManager API is enabled on your console, this is so you can manipulate resources from your management plane / instance.
