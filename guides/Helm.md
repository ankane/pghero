# PgHero Helm Chart

## Overview
This Helm chart provides an easy way to deploy [PgHero](https://github.com/ankane/pghero) on a Kubernetes cluster. 

## Features
- **Easily deploy PgHero** in Kubernetes
- **Customizable PostgreSQL connections** via `values.yaml`
- **Ingress support** for exposing PgHero externally
- **Environment variable configuration** using Kubernetes secrets
- **ConfigMap-based PgHero configuration**
- **Customizable service type and ports**

## Prerequisites
- Helm 3+
- Kubernetes 1.19+
- PostgreSQL database accessible from the cluster

## Installation

### **1. Install the Chart**
```sh
helm install pghero ./helm_deploy --namespace pghero --create-namespace
```

Alternatively, you can customize the installation with a `values.yaml` file:
```sh
helm install pghero ./helm_deploy --namespace pghero --values values.yaml
```

## Configuration
You can override the default values by modifying the `values.yaml` file or using `--set` flags.

### **Example `values.yaml` Configuration:**
```yaml
databases:
  postgres1: postgres://username:password@dbaddress:dbport/postgres
  postgres2: postgres://username:password@dbaddress:dbport/postgres

replicaCount: 1

image:
  repository: ankane/pghero
  pullPolicy: Always

service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  host: pghero.example.com
  path: /
  annotations: {}
```

### **Setting Secrets for Authentication**
To secure PgHero, store the credentials in a Kubernetes secret:
```sh
kubectl create secret generic pghero-secret \
  --from-literal=PGHERO_USERNAME=link \
  --from-literal=PGHERO_PASSWORD=hyrule \
  -n pghero
```

## Exposing PgHero with Ingress
If you want to expose PgHero externally using an **Ingress Controller**, set `ingress.enabled=true` and configure the host in `values.yaml`.

```yaml
ingress:
  enabled: true
  host: pghero.example.com
  path: /
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
```

Ensure that an **Ingress Controller** (e.g., NGINX) is installed in your cluster.

## Upgrading the Chart
To upgrade an existing deployment:
```sh
helm upgrade pghero ./helm_deploy --namespace pghero
```

## Uninstalling
To remove the deployment:
```sh
helm uninstall pghero --namespace pghero
kubectl delete namespace pghero
```