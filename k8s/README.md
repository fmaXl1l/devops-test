# Kubernetes Manifests

Manifests para desplegar el microservicio DevOps en AKS.

## Manifests Incluidos

1. **01-namespace.yaml** - Namespace `devops-microservice`
2. **02-secret.yaml** - Secret para `JWT_SECRET_KEY`
3. **03-configmap.yaml** - ConfigMap con configuraciones
4. **04-deployment.yaml** - Deployment con 2 réplicas
5. **05-service.yaml** - Service LoadBalancer (puerto 80→8000)
6. **06-hpa.yaml** - HPA con CPU 70% threshold (2-5 réplicas)

## Despliegue

```bash
# Aplicar todos los manifests
kubectl apply -f k8s/

# O aplicar en orden
kubectl apply -f k8s/01-namespace.yaml
kubectl apply -f k8s/02-secret.yaml
kubectl apply -f k8s/03-configmap.yaml
kubectl apply -f k8s/04-deployment.yaml
kubectl apply -f k8s/05-service.yaml
kubectl apply -f k8s/06-hpa.yaml
```

## Verificación

```bash
# Ver estado del deployment
kubectl get all -n devops-microservice

# Ver HPA
kubectl get hpa -n devops-microservice

# Ver logs
kubectl logs -f deployment/devops-microservice -n devops-microservice
```