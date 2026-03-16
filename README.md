# OpenResty API Gateway Lab

A **production-style API Gateway Lab** built with:

- OpenResty
- Lua
- Docker
- NGINX
- Prometheus Metrics

This project explores how modern API gateways work internally by implementing core gateway features **from scratch**.

It serves as:

- a **hands-on learning project**
- a **backend engineering portfolio project**

Inspired by real gateway systems such as:

- Kong
- Apache APISIX
- Envoy
- NGINX-based API Gateway

---

# Project Goals

Most gateway tutorials only explain concepts.

This project focuses on **building a mini API gateway implementation** to deeply understand:

- plugin architecture
- request lifecycle inside NGINX/OpenResty
- traffic routing strategies
- reliability mechanisms
- observability metrics

The gateway is implemented using **OpenResty + Lua plugin architecture**.

---

# System Architecture
```text
            ┌─────────────────────┐
            │        Client       │
            └──────────┬──────────┘
                       │
                       ▼
            ┌─────────────────────┐
            │   OpenResty Gateway │
            └──────────┬──────────┘
                       │
       ┌───────────────┼───────────────┐
       │               │               │
       ▼               ▼               ▼
  Plugin Runner   Traffic Router     Metrics
       │
       ▼
   Routing Policies
       │
       ├─ Weighted Routing
       ├─ Canary Routing
       ├─ Blue / Green Routing
       └─ Shadow Routing
       │
       ▼
  Shadow Executor
       │
       ▼
      Logger
       │
       ▼
  Upstream Services

```text
---

# Gateway Request Lifecycle

The gateway processes requests through **NGINX/OpenResty phases**.


Client Request
│
▼
NGINX access phase
│
▼
Plugin Runner
│
├─ Authentication Plugins
├─ Security Plugins
├─ Traffic Routing
│
▼
Upstream Request
│
▼
Response Processing
│
├─ Metrics
└─ Logging


---

# Plugin Architecture

The gateway implements a **custom Lua plugin framework**.

Plugins run inside OpenResty request phases.


access phase
header_filter phase
log phase


Core framework files:


plugin_runner.lua
policy_engine.lua
decision_context.lua
route_config.lua
traffic_context.lua


Plugin modules:


traffic_router.lua
weighted_routing.lua
canary_routing.lua
blue_green_routing.lua
shadow_routing.lua
shadow_executor.lua
metrics.lua
logger.lua


This modular architecture allows gateway features to be implemented independently.

---

# Traffic Control Strategies

This lab implements multiple real-world traffic routing patterns.

---

## Weighted Routing

Traffic is distributed across upstream services using configured weights.


Client Request
│
▼
Weighted Router
│
├─ backend-a (70%)
└─ backend-b (30%)


Example test:


curl http://localhost:8080/svc/a-weighted


---

## Canary Release

Supports several canary deployment strategies:

- header-based routing
- percentage-based routing
- hybrid routing

Example:


curl -H "X-Canary: always" http://localhost:8080/svc/a-canary


---

## Blue / Green Deployment

Traffic switches between two environments.

           ┌────────────┐
Request ──►│   Router   │
           └─────┬──────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
   Blue Service      Green Service


Example:


curl http://localhost:8080/svc/a-bluegreen


---

## Shadow Traffic (Traffic Mirroring)

Production traffic can be mirrored asynchronously to a shadow service.


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


Shadow traffic allows testing new services safely without affecting real users.

Example:


curl http://localhost:8080/svc/a-shadow


---

# Reliability Mechanisms

This gateway implements several reliability patterns used in production systems.


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


Supported mechanisms:

- timeout protection
- retry
- upstream failover
- circuit breaker

These patterns help maintain service availability when upstream services become unstable.

---

# Observability

The gateway exposes **Prometheus-compatible metrics**.

Example metrics:


gateway_http_requests_total
gateway_http_status_class_total
gateway_upstream_selected_total
gateway_upstream_response_ms
gateway_canary_requests_total
gateway_blue_green_requests_total
gateway_shadow_mirror_requests_total
gateway_shadow_mirror_latency_ms_sum


Metrics endpoint:


http://localhost:8080/metrics


These metrics can be scraped by **Prometheus** and visualized with **Grafana**.

---

# Decision Context

A shared **Decision Context** object is used across plugins.


ngx.ctx.decision


This context stores:

- routing decisions
- selected upstream
- shadow routing decision
- request metadata

This allows plugins to cooperate without tight coupling.

---

# Project Structure


openresty-api-gateway-lab/
│
├─ backend-a/
├─ backend-b/
│
├─ observability/
│
├─ openresty/
│ ├─ conf/
│ │ └─ nginx.conf
│ │
│ ├─ lua/
│ │ ├─ plugins/
│ │ ├─ decision_context.lua
│ │ ├─ plugin_runner.lua
│ │ ├─ policy_engine.lua
│ │ ├─ route_config.lua
│ │ └─ traffic_context.lua
│ │
│ ├─ third_party/
│ │ └─ resty/
│ │
│ └─ Dockerfile
│
└─ docker-compose.yml


---

# Running the Lab

Start services:


docker compose up -d


Gateway endpoint:


http://localhost:8080


Metrics endpoint:


http://localhost:8080/metrics


---

# Example Test Requests

### Weighted Routing


curl http://localhost:8080/svc/a-weighted


### Canary Routing


curl -H "X-Canary: always" http://localhost:8080/svc/a-canary


### Canary Percentage


curl http://localhost:8080/svc/a-canary-pct


### Blue / Green Deployment


curl http://localhost:8080/svc/a-bluegreen


### Shadow Traffic


curl http://localhost:8080/svc/a-shadow


---

# Design Highlights

This project demonstrates several engineering practices:

- building an API gateway from scratch
- modular Lua plugin architecture
- policy-driven traffic routing
- asynchronous shadow traffic execution
- Prometheus metrics instrumentation
- decision context sharing across plugins

---

# Learning Outcomes

By building this project, I explored:

- OpenResty gateway development
- Lua plugin architecture
- NGINX request lifecycle
- traffic routing strategies
- resilience engineering patterns
- observability design

---

# Future Improvements

Potential future extensions:

- admin API for dynamic routing policy
- JWT / API key improvements
- distributed tracing
- Grafana dashboards
- Kubernetes deployment
- CI/CD pipeline integration

---

# Technologies Used

- OpenResty
- Lua
- NGINX
- Docker
- Prometheus metrics
