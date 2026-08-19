# Week 1 Checklist

## D1 — Account & Tooling
- [x] IAM admin / Identity Center login working
- [x] Budget $10 with 85% alert
- [ ] CloudWatch billing alarm (blocked — linked account, use Cost Anomaly Detection instead)
- [x] AWS CLI v2 installed
- [x] Terraform installed
- [x] Git installed
- [ ] Build S3 + CloudFront by hand in console, load URL, then delete it all

## D2 — Git & Terraform basics
- [x] Git: branch, commit, merge, conflict resolved, .gitignore
- [x] Wrote `versions.tf` (required_version, provider, default_tags)
- [x] Wrote `s3.tf` — Terraform S3 bucket created (`p250825-static-site`)
- [x] `terraform init` / `plan` / `apply` — understand what each does
- [x] Read terraform.tfstate and understand what it records
- [x] Tested moving the state file away and saw what breaks
- [ ] Not done yet: WSL/Ubuntu (blocked by GlobalProtect VPN — working in PowerShell instead)

## D3 — CloudFront + OAC in Terraform
- [x] Upload index.html to the bucket
- [x] Create CloudFront Origin Access Control (OAC)
- [x] Create CloudFront distribution pointing at the bucket
- [x] Write bucket policy granting CloudFront access
- [x] Debug 403 errors — got none, but tested removing the SourceArn condition and learned why
- [x] Site loads at the CloudFront URL ("It works!")
- [ ] Run `terraform apply` to restore the SourceArn condition (removed while testing)
- [ ] Test `/nonexistent.html` and explain the error S3 returns

## D4 — Remote state & GitHub OIDC
- [x] Bootstrap state bucket created (`p250825-tf-state`, versioned, encrypted)
- [x] State migrated to S3 backend with `use_lockfile`
- [ ] Create GitHub OIDC provider in Terraform
- [ ] Create deploy role scoped to one branch
- [ ] Verify role trust policy has both `aud` and `sub` conditions

## D5 — GitHub Actions pipeline
- [ ] Create `.github/workflows/deploy.yml`
- [ ] Workflow: sync site files to S3
- [ ] Workflow: invalidate CloudFront cache
- [ ] Push to main → Actions green → change is live

## D6 — Linux day
- [ ] Permissions: chmod, chown, umask
- [ ] systemd: start/stop/status a service, read journalctl
- [ ] Processes: ps, top, kill signals (TERM vs KILL)
- [ ] Pipes: grep, awk, sed on real data

## D7 — Documentation
- [ ] README with architecture diagram (mermaid), monthly cost, one rejected tradeoff
- [ ] Start failures.md with every error from this week

## End-of-session cost check (run every time)
- [ ] `aws ec2 describe-nat-gateways --filter Name=state,Values=available --query "NatGateways[].NatGatewayId" --output text`
- [ ] `aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerName" --output text`
- [ ] `aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query "Reservations[].Instances[].InstanceId" --output text`

All three should be empty. This is the billing alarm substitute, since costs
are not visible in this linked account.

## Gate check (all without notes)
- [ ] Push a commit → see it live at CloudFront URL
- [ ] Name every resource and say why it exists
- [ ] Trace a request: browser → DNS → CloudFront → OAC → S3 → response
- [ ] Explain what happens if state file is lost
- [ ] Have 8-10 entries in failures.md
- [ ] `terraform destroy` — nothing left except state bucket

---

## Session log

### 2026-08-18
Built the whole static site stack in Terraform.

Done:
- Terraform + AWS CLI installed on Windows (WSL blocked by GlobalProtect VPN)
- `aws configure sso` working against company Identity Center
- `versions.tf`, `s3.tf` — first bucket created and verified in AWS
- Read `terraform.tfstate`, tested what happens when it goes missing
- `bootstrap/main.tf` — state bucket with versioning, encryption, public access block, prevent_destroy
- `backend.tf` + `terraform init -migrate-state` — state now lives in S3
- `cloudfront.tf` — OAC, distribution, bucket policy, output
- Site live at the CloudFront URL, bucket still fully private

Blocked / deferred:
- WSL Ubuntu has no internet (GlobalProtect). D6 Linux day needs this fixed or a personal machine.
- CloudWatch billing alarm impossible in a linked account (`EstimatedCharges` only publishes in the payer account).

Notes: see `terraform-notes.md` for the full line-by-line explanation of every file.

Next session: restore the SourceArn condition, then GitHub OIDC provider + deploy role, then the Actions workflow.
