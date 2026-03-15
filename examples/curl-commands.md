
# Test Commands

## Weighted Routing
curl http://localhost:8080/svc/a-weighted

## Canary Routing
curl -H "X-Canary: always" http://localhost:8080/svc/a-canary

## Canary Percentage
curl http://localhost:8080/svc/a-canary-pct

## Blue/Green
curl http://localhost:8080/svc/a-bluegreen

## Shadow Traffic
curl http://localhost:8080/svc/a-shadow

## Metrics
curl http://localhost:8080/metrics


