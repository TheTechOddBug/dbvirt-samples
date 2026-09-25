# Kubling Samples

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg?style=flat-square)](LICENSE)

Runnable examples for learning Kubling through working code.

Kubling combines several capabilities that solve different problems: provider integration, endpoints, authentication and authorization, JavaScript extensibility, functions, module lifecycle hooks, and synthetic entities. Putting all of them into one large application makes each mechanism harder to identify and understand, so this repository isolates them into small, independent samples.

Start with the Quickstart to see the complete minimal stack, then choose a focused sample for the feature you want to explore. These examples complement the [official Kubling documentation](https://docs.kubling.com), which remains the reference for concepts and configuration.

## Start with the Quickstart

The Quickstart runs Kubling, Kubling Studio, and the official In-memory gRPC provider with Docker Compose.

```bash
cd quickstart
docker compose up --wait
```

Open <http://localhost:8282/console>, or follow the complete [Quickstart guide](quickstart/README.md) to run a deterministic query and mutation.

All samples require only Git, Docker Engine, and Docker Compose v2. They generate their required bundles automatically and do not require a host-language toolchain.

## Explore Kubling features

Each directory answers a specific question:

| Sample | What to explore |
|:--|:--|
| [Quickstart](quickstart/README.md) | How Kubling registers a gRPC provider, imports its schema, queries deterministic data, and executes a mutation |
| [Provider values](provider-values/README.md) | How provider capability negotiation preserves arrays, precision, spatial values, and streamed LOBs |
| [Provider aggregate pushdown](provider-aggregates/README.md) | How grouped SQL is delegated according to provider capabilities and verified at the provider boundary |
| [Endpoints](endpoints/README.md) | How query endpoints and actions expose reusable operations over provider data |
| [RBAC](rbac/README.md) | How authentication sources, external-role mappings, and VDB data roles control access |
| [JavaScript data source](javascript/README.md) | How a JavaScript module defines schema, data, and table handlers |
| [Functions](functions/README.md) | How SQL functions and custom template functions are packaged and invoked |
| [Module initialization and scheduling](initializer/README.md) | How modules run initialization during bootstrap, report success or failure, and schedule recurring work |
| [Bundle-level scheduled scripts](scheduled-scripts/README.md) | How trusted descriptor automation executes privileged SQL through the engine |
| [Synthetic entities](synthetic-entities/README.md) | How nested document arrays become relational tables and how mutations propagate to their parent document |
| [Kubernetes semantics](kubernetes-semantics/README.md) | How a provider publishes source-native semantics and a VDB adds federation-owned terminology without replacing it |

## Run a focused sample

Samples are independent and publish Kubling on port `8282`, so run one at a time:

```bash
cd <sample-directory>
docker compose up --wait
```

The sample README explains what to inspect, which query or operation to run, the expected result, and its automated smoke test.

When finished, remove the complete sample stack and its generated bundles:

```bash
docker compose down --volumes --remove-orphans
```

## Validate locally

The `scripts/check-<sample>.sh` commands validate only the static contract:
required files, Compose syntax, image names, shell syntax, and sample-specific
configuration invariants. They do not start containers or prove runtime
behavior.

Run a real end-to-end test with:

```bash
bash scripts/test-samples.sh quickstart
```

Pass several sample names to test a focused set, or omit them to run the entire
suite sequentially:

```bash
bash scripts/test-samples.sh
```

The runner mirrors the CI lifecycle: it validates the static contract, starts
each stack with `docker compose up --wait`, executes its smoke test, prints
Compose logs after a failure, and removes containers and volumes.

## License

Licensed under the [Apache License 2.0](LICENSE).
