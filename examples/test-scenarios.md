# OpenResty API Gateway Lab
## Test Scenarios

This document describes the manual test scenarios used to verify the
traffic control, reliability, and observability features implemented
in the OpenResty API Gateway Lab.

---

# Environment

Gateway

http://localhost:8080

Backends

backend-a  
backend-b  
backend-echo  
slow-backend

Tools

curl  
hey (optional load testing)  
Prometheus  
Grafana

---

# 1. Basic Routing

Verify that the gateway can route traffic to upstream services.

### Request


curl http://localhost:8080/svc/a


### Expected Result

- Response from backend-a
- HTTP 200

### Verify Headers


X-Gateway-Route
X-Request-Id
X-Correlation-Id


---

# 2. Weighted Routing

Verify that traffic is distributed according to configured weights.

Example configuration

backend-a weight 80  
backend-b weight 20

### Test


for i in {1..20}; do
curl -s http://localhost:8080/svc/weight

done


### Expected Result

Responses should be distributed approximately:

80% backend-a  
20% backend-b

---

# 3. Canary Release

Verify that canary routing works correctly.

## Header-based Canary

### Request


curl -H "x-canary: true" http://localhost:8080/svc/canary


### Expected

Traffic routed to canary upstream.

---

## Percentage-based Canary

Send multiple requests.


for i in {1..50}; do
curl http://localhost:8080/svc/canary

done


Expected

Only a percentage routed to canary backend.

---

# 4. Blue / Green Deployment

Verify switching traffic between environments.

Blue environment  
backend-a

Green environment  
backend-b

### Request


curl http://localhost:8080/svc/bluegreen


### Expected

Traffic goes to the active environment.

Switch environment in configuration and test again.

---

# 5. Shadow Traffic

Verify that production traffic can be mirrored to a shadow service.

### Request


curl http://localhost:8080/svc/shadow


### Expected

Primary response returned to client.

Shadow request sent asynchronously to shadow backend.

---

# 6. Timeout Protection

Verify upstream timeout handling.

### Request


curl http://localhost:8080/svc/slow


### Expected

Gateway timeout triggered.

HTTP 504 or fallback response.

---

# 7. Retry Policy

Verify retry mechanism when upstream fails.

### Scenario

slow-backend times out.

Gateway retries another upstream.

### Request


curl http://localhost:8080/svc/retry


### Expected

Retry executed.

Response returned from secondary backend.

---

# 8. Retry Failover

Verify failover routing.

### Scenario

Primary upstream fails.

Gateway automatically routes to backup.

### Request


curl http://localhost:8080/svc/failover


### Expected

First upstream timeout.

Second upstream returns success.

---

# 9. Circuit Breaker

Verify circuit breaker behavior.

### Scenario

Upstream repeatedly fails.

Circuit breaker opens.

### Request


for i in {1..10}; do
curl http://localhost:8080/svc/circuit

done


### Expected

After threshold reached:

Gateway returns fast failure.

No upstream request executed.

---

# 10. Rate Limiting

Verify rate limiting using Redis.

### Request


for i in {1..20}; do
curl http://localhost:8080/svc/ratelimit

done


### Expected

Some requests return

HTTP 429 Too Many Requests

---

# 11. Observability

Verify metrics exported to Prometheus.

### Request


curl http://localhost:8080/metrics


### Expected Metrics

gateway_http_requests_total

gateway_request_duration_ms_bucket

gateway_upstream_failures_total

---

# 12. Request Tracing

Verify request correlation headers.

### Request


curl -v http://localhost:8080/svc/a


### Expected Headers


X-Request-Id
X-Correlation-Id


These headers allow tracing requests across services.

---

# Summary

This lab demonstrates core API Gateway capabilities:

Traffic control

- weighted routing
- canary release
- blue/green deployment
- shadow traffic

Reliability

- timeout protection
- retry policy
- failover routing
- circuit breaker

Security

- JWT validation
- API key authentication
- IP whitelist
- rate limiting

Observability

- Prometheus metrics
- request tracing
- latency histogram