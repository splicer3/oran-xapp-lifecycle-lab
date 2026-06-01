# Security

Do not commit:

- kubeconfigs
- Ansible Vault files or vault passwords
- tokens or credentials
- SSH keys
- real inventories with private hosts or usernames
- packet captures
- large logs
- personal documents

Use the `*.example` inventory files as templates and keep real lab values local.

For public issues, avoid posting secrets, packet captures, or host-specific configuration. Open a minimal issue with sanitized configuration and the command that failed.
