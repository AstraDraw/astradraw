# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take the security of AstraDraw seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: **security@astradraw.io** (or create a private security advisory on GitHub)

### What to Include

Please include the following information in your report:

- Type of vulnerability (e.g., XSS, SQL injection, authentication bypass)
- Full paths of affected source files
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue and potential attack scenarios

### Response Timeline

- **Initial Response:** Within 48 hours
- **Status Update:** Within 7 days
- **Fix Timeline:** Depends on severity, typically within 30 days for critical issues

### What to Expect

1. We will acknowledge receipt of your vulnerability report
2. We will investigate and validate the issue
3. We will work on a fix and coordinate disclosure timing with you
4. We will credit you in the security advisory (unless you prefer to remain anonymous)

## Security Best Practices for Self-Hosting

When deploying AstraDraw, please follow these security recommendations:

### Authentication

- Use strong, unique passwords for all accounts
- Enable OIDC/SSO when possible for centralized authentication
- Regularly rotate JWT secrets

### Network Security

- Always use HTTPS in production
- Keep Traefik and other components updated
- Restrict network access to necessary ports only

### Docker Security

- Use Docker secrets for sensitive configuration (see `docs/deployment/DOCKER_SECRETS.md`)
- Never commit `.env` files or secrets to version control
- Run containers with minimal privileges

### Data Protection

- Regularly backup your PostgreSQL database
- Enable encryption at rest for S3/MinIO storage
- Review and restrict access to workspace data appropriately

## Acknowledgments

We appreciate the security research community's efforts in helping keep AstraDraw secure. Researchers who report valid vulnerabilities will be acknowledged in our security advisories (with their permission).

