# Kubernetes Manifests

## Deploy
```bash
kubectl apply -f k8s/
```

## Verify
```bash
kubectl get all -n devops-microservice
```

## Manifests
- `01-namespace.yaml` - Namespace
- `02-secret.yaml` - JWT secret
- `03-configmap.yaml` - App config
- `04-deployment.yaml` - 2 replicas
- `05-service.yaml` - LoadBalancer
- `06-hpa.yaml` - Auto-scaling