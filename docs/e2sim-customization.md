# e2sim Customization

The main e2sim integration is in `ansible/ric-lifecycle/roles/e2sim_docker`.

Default variables live in `ansible/ric-lifecycle/group_vars/all.yml`:

- `e2sim_image`
- `e2sim_container_name`
- `e2sim_network_mode`
- `e2sim_pull`
- `e2sim_container_command`
- `e2sim_env`

The default mode is Docker with host networking. The playbook can run in `e2sim-ready` mode, where the RIC and xApp stack is deployed without starting e2sim, or `fully-functional` mode, where e2sim is started before KPI MON validation.

The current public copy does not include packet captures. Any SCTP troubleshooting capture should stay local unless it has been sanitized and explicitly reviewed.
