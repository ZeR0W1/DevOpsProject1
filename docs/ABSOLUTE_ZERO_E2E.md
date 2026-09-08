# Final absolute-zero E2E procedure

This run proves reproducibility from no project infrastructure, including no
Terraform remote-state bucket. It is exceptional evidence preparation, not the
normal destroy lifecycle. Normal destroy retains the state bucket.

## Fixed ownership boundary

- Execution checkout: `/home/geeta/Project1-e2e-clean`
- AWS account: `058264247987`
- AWS region: `us-east-1`
- State bucket: `devops-project1-terraform-state-058264247987-us-east-1`
- Current bootstrap owner before reset:
  `/home/geeta/Project1-e2e-clean/terraform/state-bootstrap/terraform.tfstate`
- Backup directory:
  `/home/geeta/Project1-e2e-clean/terraform/state_backups/`

Do not substitute artifacts from `/home/geeta/Project1`. The historical
`scripts/recreate_state_bucket_boundary.sh` refers to the retired ownership
boundary and must not be rerun.

## Review-only preparation

1. Fast-forward the clean checkout to the explicitly selected pushed checkpoint,
   preserving its ignored artifacts.
2. Verify its tracked tree is clean and its branch is `aws4-jenkins-cicd`.
3. Ensure the current bootstrap state is mode `0600`; do not print it.
4. Run the new helper without arguments:

   ```bash
   bash /home/geeta/Project1/scripts/reset_e2e_state_boundary.sh
   ```

   This is read-only. It verifies the checkout, AWS account and region, empty
   main state, exact bootstrap ownership count and bucket name, and the live
   bucket's versioning and ownership tag. It prints no state or secret content.
5. Reconfirm that no target EKS, RDS, ALB, NAT gateway, application bucket, VPC,
   or certificate remains. Review any name collision before proceeding.

## Destructive reset boundary

The reset requires separate explicit authorization. After approval, invoke only
the exact command printed by the successful preflight. The helper then:

1. copies the current bootstrap state to a timestamped, mode-`0600` backup;
2. removes all versions and delete markers from the dedicated state bucket;
3. verifies the bucket is empty;
4. deletes the bucket and verifies it is absent;
5. removes the active bootstrap state only after bucket absence is confirmed.

It does not run setup, Terraform apply, or the create lifecycle. Those remain a
second mutation boundary requiring review and authorization.

## Recovery matrix

### Reset stops before backing up bootstrap state

Nothing was changed. Correct the failed precondition and rerun read-only
preflight.

### Bootstrap state was backed up, but bucket deletion did not finish

Do not run create. Both the active state and timestamped backup remain available.
Inspect only bucket metadata and remaining version counts, correct the narrow
failure, and resume deletion under explicit authorization. Do not create a
competing bootstrap state.

### Bucket is absent and backup exists

The absolute-zero boundary is established. Preserve the backup as recovery
provenance, then run `bash setup.sh` from the clean checkout. Review the generated
ignored inputs before separately authorizing `playbooks/create.yml`; its fresh
bootstrap path must recreate the bucket and new bootstrap state.

### Create fails after recreating the bucket

Do not restore the retired backup over new ownership. Preserve the new bootstrap
and main-state progress and follow the lifecycle's fail-closed diagnostics. Resume
only after reviewing the smallest failing boundary.

### Recovery requires the retired backup

Stop. Restoring bootstrap state or adopting/recreating the bucket is Terraform
state mutation and requires a dedicated recovery plan and explicit approval.
Never copy state into place or import resources as an ad hoc fix.

## Evidence to retain

Capture only non-secret evidence: selected commit, clean tracked status, successful
preflight categories, bucket-absence result, setup completion, fresh bootstrap
creation, empty-to-populated main-state address counts, and the guarded create
result. Never capture state contents, plan contents, credentials, tokens, private
keys, passwords, or sensitive outputs.