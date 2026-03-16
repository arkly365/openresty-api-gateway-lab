# OpenResty API Gateway Lab
## Architecture Overview

This document describes the internal architecture of the **OpenResty API Gateway Lab**.

The goal of this project is to explore how modern API gateways operate internally by implementing core gateway components using **OpenResty + Lua plugins**.

The system is designed as a **modular request processing pipeline**, where each request passes through a series of gateway components responsible for routing, policy enforcement, and observability.

---

# System Overview

The gateway acts as the entry point for client requests and forwards traffic to upstream services after applying routing policies and reliability mechanisms.

```text
Client
│
▼
OpenResty Gateway
│
├─ Plugin Runner
│
├─ Policy Engine
│
├─ Traffic Router
│
└─ Observability
│
▼
Upstream Services
```

The gateway is implemented using **OpenResty**, which extends NGINX with Lua scripting capabilities.

Lua plugins allow implementing programmable gateway behaviors such as:

- traffic routing
- resilience patterns
- authentication
- observability

---

# Gateway Request Processing Flow

Incoming requests pass through the NGINX/OpenResty request lifecycle.

```text
Client Request
│
▼
NGINX Access Phase
│
▼
Plugin Runner
│
├─ Authentication Plugins
├─ Security Plugins
├─ Traffic Routing Plugins
│
▼
Traffic Router
│
▼
Upstream Service
│
▼
Response Processing
│
├─ Metrics
└─ Logging
```

Each stage in the pipeline is responsible for a specific aspect of request handling.

This architecture enables the gateway to apply policies before forwarding traffic to backend services.

---

# Core Gateway Components

The gateway is composed of several core modules.

## Route Configuration

Defines routing rules that map incoming requests to upstream services.

Examples:

- `/svc/a`
- `/svc/canary`
- `/svc/bluegreen`

Route configuration determines which traffic policies should be applied.

---

## Plugin Runner

The **Plugin Runner** is responsible for executing gateway plugins during request processing.

Plugins are executed in sequence according to the current request phase.

Responsibilities:

- executing Lua plugins
- coordinating request processing
- sharing context between plugins

---

## Policy Engine

The **Policy Engine** evaluates routing strategies and reliability rules.

It determines how traffic should be handled based on route configuration.

Examples of evaluated policies:

- weighted routing
- canary routing
- blue/green deployment
- shadow traffic

---

## Decision Context

Plugins share state using a **Decision Context** object.

This context is stored in:


ngx.ctx.decision


The decision context stores information such as:

- selected upstream service
- routing decisions
- shadow routing status
- request metadata

This allows plugins to collaborate without tight coupling.

---

## Observability

The gateway exposes **Prometheus-compatible metrics**.

Metrics are collected during request processing and exported via the `/metrics` endpoint.

Observability data includes:

- request counters
- upstream latency
- routing decisions
- shadow traffic metrics

---

# Plugin Execution Model

The gateway uses OpenResty request phases to control plugin execution.

Plugins are executed in the following phases:

## Access Phase

The **access phase** is responsible for request validation and routing decisions.

Typical tasks:

- authentication
- rate limiting
- traffic routing
- policy evaluation

---

## Header Filter Phase

The **header_filter phase** processes response headers before they are returned to the client.

Typical tasks:

- response header modification
- response metrics collection

---

## Log Phase

The **log phase** executes after the response is sent to the client.

Typical tasks:

- request logging
- metrics aggregation
- shadow execution tracking

---

# Traffic Decision Architecture

The gateway implements several traffic routing strategies used in production systems.

Traffic decisions follow this pipeline:

```text
Request
│
▼
Route Match
│
▼
Policy Engine
│
▼
Traffic Router
│
├─ Weighted Routing
├─ Canary Routing
├─ Blue / Green Routing
└─ Shadow Routing
│
▼
Upstream Selection
```

These routing strategies allow the gateway to control traffic distribution across services.

---

# Supported Traffic Strategies

## Weighted Routing

Distributes traffic across multiple upstream services based on configured weights.

Example:


backend-a → 80%
backend-b → 20%


---

## Canary Routing

Allows gradual deployment of new service versions.

Supported strategies include:

- header-based routing
- percentage-based routing
- hybrid canary routing

---

## Blue / Green Deployment

Routes traffic between two service environments.

```text
Client
│
▼
Router
│
├─ Blue Environment
└─ Green Environment
```

This strategy enables safe production deployments.

---

## Shadow Traffic

Shadow routing mirrors production traffic to a secondary upstream service asynchronously.

```text
Client Request
│
▼
Primary Upstream
│
├─ Response → Client
│
└─ Async Mirror
│
▼
Shadow Service
```

Shadow traffic allows testing new services without affecting users.

---

# Reliability Architecture

The gateway implements several resilience patterns.

```text
Request
│
▼
Timeout Protection
│
▼
Retry Policy
│
▼
Failover Routing
│
▼
Circuit Breaker
```

These mechanisms protect the system from unstable upstream services.

---

## Timeout Protection

Prevents requests from hanging indefinitely when upstream services are slow.

---

## Retry Policy

Retries failed requests when upstream services temporarily fail.

---

## Failover Routing

Automatically routes traffic to backup upstream services when the primary upstream fails.

---

## Circuit Breaker

Stops sending requests to unstable upstream services after repeated failures.

This prevents cascading failures across the system.

---

# Observability Architecture

The gateway exports metrics compatible with Prometheus.

```text
Request
│
▼
Gateway Processing
│
├─ request counter
├─ upstream latency
├─ routing decision metrics
└─ shadow traffic metrics
│
▼
Prometheus Metrics Endpoint
```      

Metrics endpoint:


/metrics


These metrics can be scraped by Prometheus and visualized using Grafana.

---

# Design Philosophy

This project focuses on understanding API gateway architecture by implementing core gateway components from scratch.

Instead of configuring an existing gateway product, the lab builds a simplified gateway architecture including:

- plugin execution pipeline
- traffic routing strategies
- resilience patterns
- observability metrics

The goal is to gain deeper insight into how production-grade API gateways such as:

- Kong
- Apache APISIX
- Envoy

are designed internally.

---

# Summary

The OpenResty API Gateway Lab demonstrates how a gateway can be implemented using OpenResty and Lua plugins.

Key architectural elements include:

- modular plugin framework
- policy-driven traffic routing
- resilience mechanisms
- observability integration

This project serves both as a learning platform and as a backend engineering portfolio project demonstrating gateway architecture design.
