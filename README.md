# OpenResty API Gateway Lab

A production-style API Gateway Lab built with **OpenResty + Lua + Docker**.

This project is a hands-on lab for learning how modern API gateways work internally, including:

- plugin architecture
- traffic routing strategies
- reliability mechanisms
- observability
- async shadow traffic

The goal of this project is to understand the internal design ideas behind systems such as:

- Kong
- Apache APISIX
- Envoy
- NGINX-based API Gateway

---

## Why I built this project

Instead of only learning gateway concepts from documentation, I wanted to build a mini gateway from scratch and understand:

- how plugins are executed in request lifecycle phases
- how weighted routing / canary / blue-green / shadow traffic work
- how retry / failover / circuit breaker are implemented
- how observability is exposed using Prometheus-style metrics
- how decision context can be shared across plugins

This lab is designed as a technical exploration project and also serves as a portfolio project.

---

## Key Features

### 1. Plugin Architecture

The gateway uses a custom Lua plugin framework.

Execution phases include:

- access phase
- header_filter phase
- log phase

Core files:

- `plugin_runner.lua`
- `route_config.lua`
- `policy_engine.lua`
- `decision_context.lua`

---

### 2. Traffic Routing

Supported routing strategies:

- Direct routing
- Weighted routing
- Canary release
- Blue/Green deployment
- Shadow traffic (async mirror)

---

### 3. Reliability Features

Supported reliability mechanisms:

- timeout handling
- retry
- failover
- circuit breaker

---

### 4. Observability

Prometheus-style metrics are exposed for:

- request count
- status class
- request latency
- upstream selection
- upstream latency
- canary routing
- blue/green routing
- shadow traffic execution

---

### 5. Decision Context

A shared decision context is used across plugins:

- routing decision
- selected upstream
- shadow decision
- request metadata

This makes the gateway more modular and closer to production-grade gateway design.

---

## Architecture Overview

```text
Client
  │
  ▼
OpenResty Gateway
  │
  ├─ plugin_runner
  │
  ├─ traffic_router
  ├─ shadow_routing
  ├─ shadow_executor
  ├─ metrics
  └─ logger
  │
  ▼
Upstream services


# OpenResty API Gateway Lab

A production-style API Gateway Lab built with **OpenResty + Lua + Docker**.

This project is a hands-on lab for learning how modern API gateways work internally, including:

- plugin architecture
- traffic routing strategies
- reliability mechanisms
- observability
- async shadow traffic

The goal of this project is to understand the internal design ideas behind systems such as:

- Kong
- Apache APISIX
- Envoy
- NGINX-based API Gateway

---

## Why I built this project

Instead of only learning gateway concepts from documentation, I wanted to build a mini gateway from scratch and understand:

- how plugins are executed in request lifecycle phases
- how weighted routing / canary / blue-green / shadow traffic work
- how retry / failover / circuit breaker are implemented
- how observability is exposed using Prometheus-style metrics
- how decision context can be shared across plugins

This lab is designed as a technical exploration project and also serves as a portfolio project.

---

## Key Features

### 1. Plugin Architecture

The gateway uses a custom Lua plugin framework.

Execution phases include:

- access phase
- header_filter phase
- log phase

Core files:

- `plugin_runner.lua`
- `route_config.lua`
- `policy_engine.lua`
- `decision_context.lua`

---

### 2. Traffic Routing

Supported routing strategies:

- Direct routing
- Weighted routing
- Canary release
- Blue/Green deployment
- Shadow traffic (async mirror)

---

### 3. Reliability Features

Supported reliability mechanisms:

- timeout handling
- retry
- failover
- circuit breaker

---

### 4. Observability

Prometheus-style metrics are exposed for:

- request count
- status class
- request latency
- upstream selection
- upstream latency
- canary routing
- blue/green routing
- shadow traffic execution

---

### 5. Decision Context

A shared decision context is used across plugins:

- routing decision
- selected upstream
- shadow decision
- request metadata

This makes the gateway more modular and closer to production-grade gateway design.

---

## Architecture Overview

```text
Client
  │
  ▼
OpenResty Gateway
  │
  ├─ plugin_runner
  │
  ├─ traffic_router
  ├─ shadow_routing
  ├─ shadow_executor
  ├─ metrics
  └─ logger
  │
  ▼
Upstream services