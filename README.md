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
```

Traffic Control Flow
Weighted Routing

Traffic is distributed across multiple upstreams using weight-based selection.

Canary Release

Supports:

header-based canary

percentage-based canary

hybrid canary routing

Blue/Green Deployment

Traffic can be switched between blue and green upstream targets.

Shadow Traffic

Production traffic can be mirrored asynchronously to a shadow upstream for safe testing.

Reliability Flow

This lab includes reliability patterns commonly used in production systems:

timeout protection

retry policy

failover routing

circuit breaker

These features help simulate resilient gateway behavior under unstable upstream conditions.

Project Structure
openresty-gateway-lab/
├─ backend-a/
├─ backend-b/
├─ observability/
├─ openresty/
│  ├─ conf/
│  │  └─ nginx.conf
│  ├─ lua/
│  │  ├─ plugins/
│  │  ├─ decision_context.lua
│  │  ├─ plugin_runner.lua
│  │  ├─ policy_engine.lua
│  │  ├─ route_config.lua
│  │  └─ traffic_context.lua
│  ├─ third_party/
│  │  └─ resty/
│  └─ Dockerfile
└─ docker-compose.yml
How to Run
Start services
docker compose up -d
Gateway endpoint
http://localhost:8080
Metrics endpoint
http://localhost:8080/metrics
Example Test Commands
Weighted routing
curl http://localhost:8080/svc/a-weighted
Canary routing
curl -H "X-Canary: always" http://localhost:8080/svc/a-canary
Canary percentage
curl http://localhost:8080/svc/a-canary-pct
Blue/Green deployment
curl http://localhost:8080/svc/a-bluegreen
Shadow traffic
curl http://localhost:8080/svc/a-shadow
Example Metrics

This project exposes metrics such as:

gateway_http_requests_total

gateway_http_status_class_total

gateway_upstream_selected_total

gateway_upstream_response_ms

gateway_canary_requests_total

gateway_canary_reason_total

gateway_blue_green_requests_total

gateway_shadow_mirror_requests_total

gateway_shadow_mirror_status_total

gateway_shadow_mirror_latency_ms_sum

Design Highlights

This project demonstrates several important engineering ideas:

building an API gateway from scratch

modular plugin execution

policy-driven traffic management

async shadow traffic execution

production-style observability

decision context sharing across plugins

Learning Outcomes

By building this project, I explored:

OpenResty and Lua plugin design

NGINX gateway request lifecycle

gateway traffic control patterns

resilience engineering patterns

metrics-driven observability

system design inspired by real gateway products

Future Improvements

Possible next steps:

admin API for dynamic policy updates

JWT / API key integration refinement

distributed tracing

Grafana dashboard polishing

Kubernetes deployment

CI/CD pipeline for the lab

Technologies Used

OpenResty

Lua

NGINX

Docker

Prometheus metrics format




