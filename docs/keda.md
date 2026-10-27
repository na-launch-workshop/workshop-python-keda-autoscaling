# KEDA

KEDA scales a deployment from zero to many replicas based on external signals.

In this workshop the signal is HTTP request rate, measured by the
[KEDA HTTP Add-on](https://github.com/kedacore/http-add-on):

- fans hit the scoreboard's Route
- the Route sends traffic to the KEDA **interceptor**, which counts requests and forwards them to your Service
- KEDA compares the request rate to `targetValue` and adds pods
- when traffic stays low for `scaledownPeriod`, pods are removed — down to `min`

## How traffic flows

Before Step 4:

```
browser / surge → Route → Service nba-scoreboard → pod
```

After Step 4:

```
browser / surge → Route → Service keda-interceptor → KEDA interceptor (keda namespace)
                                                      → Service nba-scoreboard → pods
```

A Route can only point at a Service in its own namespace, but the interceptor runs in the
`keda` namespace. `manifests/interceptor-service.yaml` bridges the gap: a local
`keda-interceptor` Service whose Endpoints point at the shared interceptor.
The interceptor uses the request's hostname to find your `HTTPScaledObject` — that is why
`hosts` must match your Route exactly.

## Scale to zero

With `min: 0`, KEDA removes the last pod when there is no traffic. The next request is held
by the interceptor while a pod starts (a cold start), then forwarded.

KEDA HTTP Add-on reference:

https://github.com/kedacore/http-add-on
