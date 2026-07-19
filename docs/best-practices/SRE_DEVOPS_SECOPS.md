# Spot Render - SRE, DevOps & SecOps Best Practices

> **PT-BR:** Melhores práticas de SRE, DevOps e SecOps para a plataforma Spot Render
> **EN-US:** SRE, DevOps, and SecOps best practices for the Spot Render platform

## 📋 Overview

This document outlines the best practices for operating the Spot Render platform, following industry standards from Google SRE, DevOps, and SecOps guidelines.

## 🏗️ Architecture Principles

### General Architecture

1. **Design for Failure**
   - Assume components will fail
   - Implement redundancy at all levels
   - Design for graceful degradation

2. **Loose Coupling**
   - Services should be loosely coupled
   - Use asynchronous communication when possible
   - Implement circuit breakers

3. **Observability**
   - Logs, metrics, and traces for everything
   - Implement distributed tracing
   - Use correlation IDs

### Kubernetes Architecture

| Principle | Implementation |
|-----------|----------------|
| Namespace Isolation | Separate namespaces per environment |
| Resource Limits | Always set CPU/memory limits |
| Health Checks | Liveness + Readiness probes |
| Pod Disruption | Use PodDisruptionBudgets |
| Network Policies | Restrict pod-to-pod communication |

## 📊 SRE Best Practices

### Error Budgets

Define error budgets for each service:

| Service | Availability Target | Error Budget (monthly) |
|---------|-------------------|----------------------|
| API | 99.9% | 43.8 min |
| Portal | 99.5% | 3.6 hours |
| Ollama | 99.0% | 7.3 hours |

### SLOs (Service Level Objectives)

```yaml
# Example SLO definitions
slos:
  - name: api-availability
    target: 99.9%
    window: 30d
    metric: http_requests_total{status=~"5.."}

  - name: api-latency
    target: p99 < 500ms
    window: 30d
    metric: http_request_duration_seconds{quantile="0.99"}

  - name: ollama-availability
    target: 99.0%
    window: 30d
    metric: up{job="ollama"}
```

### On-Call Best Practices

1. **Alerting Philosophy**
   - Page only for actionable items
   - Every alert should have a clear owner
   - Use "alert fatigue" prevention

2. **Runbook Requirements**
   - Every alert must have a runbook
   - Runbooks must be tested quarterly
   - Keep runbooks up-to-date

3. **Incident Response**
   - Follow the incident severity matrix
   - Use structured communication
   - Always write postmortems for SEV1/SEV2

### Postmortem Template

```markdown
# Postmortem: [Incident Title]

## Summary
- **Date:** YYYY-MM-DD
- **Duration:** X hours Y minutes
- **Severity:** SEV1/SEV2
- **Impact:** Description of user impact

## Timeline
- HH:MM - Event
- HH:MM - Detection
- HH:MM - Response
- HH:MM - Resolution

## Root Cause
[Detailed explanation of what went wrong]

## Contributing Factors
1. Factor 1
2. Factor 2

## Action Items
| Action | Owner | Due Date |
|--------|-------|----------|
| Action 1 | @owner | YYYY-MM-DD |

## Lessons Learned
[What went well, what didn't, what to improve]
```

## 🔄 DevOps Best Practices

### CI/CD Pipeline

1. **Pipeline Stages**
   ```
   Commit → Build → Test → Security Scan → Deploy → Verify
   ```

2. **GitOps Flow**
   - All infrastructure as code
   - Use ArgoCD for deployment
   - Maintain environment parity

3. **Deployment Strategies**

| Strategy | Use Case | Risk |
|----------|----------|------|
| Blue/Green | Critical services | Medium |
| Canary | Gradual rollouts | Low |
| Rolling | Non-critical | Low |
| Recreate | Development only | High |

### Infrastructure as Code

```yaml
# Example: Kubernetes resource with all best practices
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: api
        version: v1
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: api
                topologyKey: kubernetes.io/hostname
      containers:
        - name: api
          image: api:v1.0.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            readOnlyRootFilesystem: true
```

### Kubernetes Best Practices

1. **Resource Management**
   - Always set resource requests and limits
   - Use LimitRanges to enforce defaults
   - Monitor actual vs requested resources

2. **Security**
   - Run containers as non-root
   - Use read-only root filesystems
   - Implement network policies
   - Use Secrets, not ConfigMaps for sensitive data

3. **High Availability**
   - Deploy across multiple nodes
   - Use PodDisruptionBudgets
   - Implement anti-affinity rules
   - Use appropriate replica counts

## 🔒 SecOps Best Practices

### Container Security

| Stage | Practice |
|-------|----------|
| Build | Use minimal base images, scan for vulnerabilities |
| Store | Store images in private registry, sign images |
| Deploy | Use ImagePolicyWebhook, enforce tag not digest |
| Runtime | Enable security context, use AppArmor/Seccomp |

### Security Checklist

- [ ] Containers run as non-root
- [ ] Root filesystem is read-only
- [ ] Privileged containers are forbidden
- [ ] Security capabilities are dropped
- [ ] Network policies are in place
- [ ] Secrets are encrypted at rest
- [ ] RBAC is properly configured
- [ ] Audit logging is enabled
- [ ] Container images are scanned
- [ ] No default credentials are used

### Network Policies

```yaml
# Example: Restrictive network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-network-policy
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              role: database
      ports:
        - port: 5432
    - to:
        - namespaceSelector: {}
      ports:
        - port: 53  # DNS
        - port: 443 # HTTPS
        - port: 80  # HTTP
```

### RBAC Best Practices

1. **Principle of Least Privilege**
   - Grant only necessary permissions
   - Use ServiceAccounts per application
   - Avoid cluster-admin where possible

2. **ServiceAccount Configuration**
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: api
     namespace: spot-render
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: api
   rules:
     - apiGroups: [""]
       resources: ["pods"]
       verbs: ["get", "list", "watch"]
     - apiGroups: [""]
       resources: ["services"]
       verbs: ["get", "list"]
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: RoleBinding
   metadata:
     name: api
   subjects:
     - kind: ServiceAccount
       name: api
       namespace: spot-render
   roleRef:
     kind: Role
     name: api
     apiGroup: rbac.authorization.k8s.io
   ```

## 📈 Monitoring Best Practices

### The Four Golden Signals

Always monitor these for every service:

| Signal | Description | Metrics |
|--------|-------------|---------|
| **Latency** | Time to process requests | p50, p95, p99 |
| **Traffic** | Requests per second | rps, requests/min |
| **Errors** | Failed request rate | error_rate, 5xx_rate |
| **Saturation** | Resource utilization | CPU%, memory%, disk% |

### Alerting Best Practices

1. **Alert Quality**
   - Every alert must be actionable
   - Include context in alert messages
   - Set appropriate severity levels
   - Define clear alert fatigue rules

2. **Alert Naming Convention**
   ```
   {service}_{component}_{condition}_{duration}
   Example: api_backend_high_error_rate_5m
   ```

3. **Alert Thresholds**
   - Use SLOs as basis for alerts
   - Set thresholds based on history
   - Use percentages, not absolute values
   - Consider seasonal variations

### Dashboards

Create dashboards following the USE method:

```
Utilization:    % time resource was in use
Saturation:    degree to which resource has extra work
Errors:        count of error events
```

## 📝 Documentation Standards

### Required Documentation

| Document | Audience | Update Frequency |
|----------|----------|------------------|
| Architecture Decision Records (ADRs) | Engineers | On change |
| Runbooks | On-call | Quarterly |
| Postmortems | Team | After incidents |
| API Documentation | Developers | On change |
| Runbooks | On-call | Quarterly |

### Document Storage

- Use Git for all documentation
- Include in code review process
- Tag releases with documentation changes
- Use Markdown for portability

## 🔧 Operational Excellence

### Change Management

1. **Change Approval Process**
   - All changes go through code review
   - Production changes require approval
   - Document all change rationale

2. **Deployment Process**
   ```
   1. Build passes CI
   2. Security scan passes
   3. Deploy to staging
   4. Integration tests pass
   5. Deploy to production (canary)
   6. Monitor for 30 minutes
   7. Full rollout
   ```

### Backup and Recovery

| Component | Backup Frequency | Recovery RTO | Recovery RPO |
|-----------|-----------------|--------------|--------------|
| Database | Hourly | 1 hour | 1 hour |
| Config | On change | 15 min | On change |
| Models | Weekly | 4 hours | 1 week |
| User Data | Daily | 4 hours | 24 hours |

### Disaster Recovery

1. **Recovery Time Objective (RTO)**: 4 hours
2. **Recovery Point Objective (RPO)**: 1 hour

Test DR quarterly with chaos engineering.

## 📚 References

- [Google SRE Book](https://sre.google/sre-book/table-of-contents/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [The Twelve-Factor App](https://12factor.net/)

---

**Document Version:** 1.0.0
**Last Updated:** 2026-07-19
**Maintained by:** Spot Render Platform Team
