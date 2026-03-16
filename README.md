A **production-style API Gateway Lab** built with:

- OpenResty
- Lua
- Docker
- NGINX
- Prometheus Metrics

This project explores how modern API gateways work internally by implementing key gateway features **from scratch**.

It is designed as both:

- a **hands-on learning project**
- a **technical portfolio project**

Inspired by real gateway systems such as:

- Kong
- Apache APISIX
- Envoy
- NGINX Gateway

---

# Project Goals

Instead of only reading documentation, this project was created to deeply understand:

- how API gateways process requests
- how plugin systems work
- how traffic control strategies are implemented
- how reliability mechanisms are designed
- how observability metrics are exposed

The gateway is implemented using **OpenResty + Lua plugin architecture**.

---

# System Overview


Client
│
▼
OpenResty Gateway
│
├─ Plugin Runner
│
├─ Traffic Router
│
├─ Canary Routing
│
├─ Blue/Green Routing
│
├─ Shadow Traffic Executor
│
├─ Metrics Collector
│
└─ Logger
│
▼
Upstream Services


---

# Core Gateway Concepts Implemented

This lab demonstrates several important gateway engineering concepts.

## Plugin Architecture

A modular plugin execution system built using Lua.

Gateway execution phases:


access phase
header_filter phase
log phase


Core components:


plugin_runner.lua
policy_engine.lua
decision_context.lua
route_config.lua


Plugins implemented:


traffic_router.lua
weighted_routing.lua
canary_routing.lua
blue_green_routing.lua
shadow_routing.lua
shadow_executor.lua
metrics.lua
logger.lua


The plugin system allows flexible extension of gateway behaviors.

---

# Traffic Control Flow

This gateway implements several traffic management strategies.

## Weighted Routing

Traffic is distributed across multiple upstream services based on configured weights.

This allows simple load balancing and gradual rollout.

---

## Canary Release

Supports multiple canary strategies:

- Header-based canary routing
- Percentage-based canary routing
- Hybrid routing

Example:


curl -H "X-Canary: always" http://localhost:8080/svc/a-canary


---

## Blue / Green Deployment

Traffic can switch between **blue** and **green** environments.

This deployment strategy enables:

- safe release switching
- instant rollback capability

---

## Shadow Traffic (Traffic Mirroring)

Production traffic can be mirrored asynchronously to a **shadow upstream**.


Client Request
│
▼
Primary Upstream
│
├── Response returned to client
│
└── Async mirror request
│
▼
Shadow Service


Shadow traffic allows testing new services **without affecting real users**.

---

# Reliability Mechanisms

This lab includes reliability patterns commonly used in production gateways.

Supported mechanisms:

- Timeout protection
- Retry policy
- Failover routing
- Circuit breaker

These features simulate resilient gateway behavior when upstream services become unstable.

---

# Observability

The gateway exposes **Prometheus-style metrics**.

Example metrics:


gateway_http_requests_total
gateway_http_status_class_total
gateway_upstream_selected_total
gateway_upstream_response_ms
gateway_canary_requests_total
gateway_blue_green_requests_total
gateway_shadow_mirror_requests_total


Metrics endpoint:


http://localhost:8080/metrics


These metrics can be scraped by **Prometheus** and visualized using **Grafana**.

---

# Decision Context

A shared **Decision Context** object is used across plugins.


ngx.ctx.decision


This context stores:

- routing decisions
- selected upstream
- shadow routing decisions
- request metadata

This design allows plugins to collaborate without tight coupling.

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

## Start Services


docker compose up -d


---

## Gateway Endpoint


http://localhost:8080


---

## Metrics Endpoint


http://localhost:8080/metrics


---

# Example Test Requests

### Weighted Routing


curl http://localhost:8080/svc/a-weighted


---

### Canary Routing


curl -H "X-Canary: always" http://localhost:8080/svc/a-canary


---

### Canary Percentage


curl http://localhost:8080/svc/a-canary-pct


---

### Blue / Green Deployment


curl http://localhost:8080/svc/a-bluegreen


---

### Shadow Traffic


curl http://localhost:8080/svc/a-shadow


---

# Design Highlights

This project demonstrates several engineering practices:

- building an API gateway from scratch
- modular plugin execution
- policy-driven traffic routing
- asynchronous shadow traffic execution
- Prometheus-compatible metrics
- shared decision context across plugins

---

# Learning Outcomes

By building this project, I explored:

- OpenResty gateway development
- Lua plugin architecture
- NGINX request lifecycle
- traffic routing strategies
- reliability engineering patterns
- metrics-driven observability

---

# Future Improvements

Possible future extensions:

- Admin API for dynamic policy configuration
- JWT / API key management improvements
- Distributed tracing
- Grafana dashboard improvements
- Kubernetes deployment
- CI/CD pipeline integration

---

# Technologies Used

- OpenResty
- Lua
- NGINX
- Docker
- Prometheus Metrics