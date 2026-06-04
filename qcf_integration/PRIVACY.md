# QCF Data & Privacy Notes

- Purpose: capture ideas, create tasks, and surface workload transparency.
- Data minimization: store only title, description, source, timestamps, and minimal audit metadata.
- Retention: default retention is configurable by database rotation; consider purge after X years per policy.
- Consent: collect explicit consent via `/consent` before storing PII or client-sensitive details.
- Access: admin UI protected via basic auth; integrate with SSO for production.
- Audit: all create/notify actions recorded in `audit_logs` for transparency.
