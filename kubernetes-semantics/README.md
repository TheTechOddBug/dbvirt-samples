# Kubernetes Semantics Sample

This sample shows the two places where Kubling semantics can be configured: the provider describes its source domain, and the VDB describes how that domain is understood in a particular federation.

The Kubernetes provider owns the definitions for `k8s:Deployment`, `k8s:ReplicaSet`, and `k8s:Pod`, including their controller relationships. Kubling acquires that fragment through `GetSemanticFragment`; the VDB does not copy it.

The VDB then adds the federation-owned concept `platform:Workload`. Its alignment says that a Workload is represented by, and takes its authority from, the provider's Deployment entity:

```yaml
concepts:
  - id: Workload
    representations:
      - kube:Deployment
    authority: kube:Deployment
```

This is additive rather than a destructive rename. The compiled package retains the canonical `k8s:Deployment` identity and its provider provenance while also publishing `platform:Workload` as the vocabulary chosen by this VDB.

During bootstrap, Kubling imports the Kubernetes catalog, obtains and normalizes the provider fragment, loads the VDB composition and alignment, validates both surfaces together, and publishes one compiled package through the semantic admin API.

## Source map

- `compose.yaml` runs a private k3s cluster, the official Kubernetes provider, Kubling, and their readiness checks.
- `fixture.yaml` creates one namespace and one zero-replica Deployment; no workload image is pulled.
- `provider-config.yaml` retains the three Kubernetes resources required by the provider fragment.
- `descriptor/vdb/KubernetesSemanticVDB.yaml` registers the provider and activates the VDB-owned composition.
- `descriptor/vdb/semantic/kubernetes-platform.composition.yaml` selects the alignment and exports the federation vocabulary; it deliberately imports no copy of the provider fragment.
- `descriptor/vdb/semantic/kubernetes-platform.alignment.yaml` maps `platform:Workload` to the provider contribution through the logical schema alias `kube`.
- `scripts/smoke-test.sh` verifies both semantic surfaces and queries the discovered Deployment table.

## Prerequisites

- Git
- Docker Engine with support for privileged containers
- Docker Compose v2

This is intentionally heavier than the other samples because it runs a real Kubernetes API server. It does not require Go, `kubectl`, a host Kubernetes installation, cloud credentials, or an external cluster.

## Start

```bash
cd kubernetes-semantics
docker compose up --wait --wait-timeout 300
```

Compose generates the descriptor bundle with the official Kubling CLI image. Generated ZIP files and the disposable k3s state live only in named volumes.

When the stack is ready:

- Kubling Studio: <http://localhost:8282/console>
- Health endpoint: <http://localhost:8282/observe/health>
- semantic state: <http://localhost:8282/api/v1/admin/semantic/vdbs/KubernetesSemanticVDB/versions/1>
- compiled semantic package: <http://localhost:8282/api/v1/admin/semantic/vdbs/KubernetesSemanticVDB/versions/1/package>
- VDB: `KubernetesSemanticVDB`
- schema/data source: `kube`

The semantic state should report `active`, `failStartup`, an available package, and zero errors. The compiled package contains:

- provider-owned entities `k8s:Deployment`, `k8s:ReplicaSet`, and `k8s:Pod`;
- provider-owned controller relationships;
- the federation-owned concept `platform:Workload`;
- `k8s:Deployment` as the representation and authority of that concept.

## Query provider data

Open Kubling Studio and run:

```sql
SELECT metadata__namespace, metadata__name
FROM kube.DEPLOYMENT
WHERE metadata__namespace = 'kubling-sample'
  AND metadata__name = 'provider-sample';
```

Expected row:

| metadata__namespace | metadata__name |
|:--|:--|
| `kubling-sample` | `provider-sample` |

The SQL query reads the provider-backed catalog. The semantic package explains the two vocabularies associated with it: Kubernetes calls the entity a Deployment, while this VDB exposes the organizational concept Workload. The original provider term remains available for traceability and source-specific reasoning.

## Automated verification

Run the same provider-fragment, federation-alignment, activation, and query assertions used by CI:

```bash
docker compose --profile test run --rm --no-deps smoke-test
```

Static checks are available from the repository root:

```bash
bash scripts/check-kubernetes-semantics.sh
```

## Cleanup

```bash
docker compose down --volumes --remove-orphans
```
