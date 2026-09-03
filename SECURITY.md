# Repository security baseline

This public repository must not contain production credentials or operational identifiers.

## Rules

- Store tokens, passwords, private keys and environment-specific Terraform values in GitHub Actions secrets.
- Keep `terraform.tfvars`, `users.htpasswd`, `.env` and generated credentials out of Git.
- Use placeholders in documentation for hosts, IP addresses and usernames.
- Run the full-history Gitleaks workflow on every pull request.
- Rotate any credential immediately if it has ever been committed, even after deleting it from the current branch.

## Required secret for infrastructure deployment

Create `TERRAFORM_TFVARS_B64` from the protected production `terraform.tfvars` file:

```bash
base64 < terraform.tfvars | tr -d '\n'
```

Store the output as a GitHub Actions secret. Never paste it into an issue, pull request or workflow log.
