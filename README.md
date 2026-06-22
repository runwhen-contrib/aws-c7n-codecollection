<p align="center">
  <a href="https://runwhen.slack.com/join/shared_invite/zt-1l7t3tdzl-IzB8gXDsWtHkT8C5nufm2A">
    <img src="https://img.shields.io/badge/Join%20Slack-%23E01563.svg?&style=for-the-badge&logo=slack&logoColor=white" alt="Join Slack" />
  </a>
</p>

# aws-c7ncodecollection

AWS health and governance CodeCollection for RunWhen, powered by Cloud Custodian (c7n) and Robot Framework.

Each codebundle in this repository does two things:

- Produces an SLI score/metric for a class of AWS risks.
- Produces runbook output with issue-level triage details.

## What Is Included

The repository currently includes the following codebundles under `codebundles/`:

- `aws-c7n-acm-health`: expired, pending validation, failed, soon-to-expire, and unused certificates.
- `aws-c7n-ebs-health`: unattached volumes, unencrypted volumes, and unused snapshots.
- `aws-c7n-ec2-health`: stale instances, long-stopped instances, and invalid Auto Scaling Groups.
- `aws-c7n-monitoring-health`: CloudTrail and CloudWatch logging hygiene checks.
- `aws-c7n-network-health`: insecure security-group ingress, unused EIP/ELB, missing VPC flow logs.
- `aws-c7n-rds-health`: backup-disabled, public, and unencrypted RDS instances.
- `aws-c7n-s3-health`: public S3 bucket exposure checks.

## Repository Layout

- `codebundles/`: runnable checks, runbooks, and RunWhen metadata templates.
- `libraries/CloudCustodian/Core/`: shared Python helper keywords used by Robot suites.
- `.github/workflows/score.yaml`: automated scoring/suggestion workflow for codebundles.
- `.github/workflows/release.yaml`: scheduled/manual release workflow.

## How A Bundle Works

Inside each bundle, you will usually see:

- One or more Cloud Custodian policies (`*.yaml`) and/or templates (`*.j2`).
- `sli.robot`: computes and pushes a metric.
- `runbook.robot`: parses findings and raises actionable issues.
- `.runwhen/generation-rules/` and `.runwhen/templates/`: SLX/SLI/Runbook generation for the RunWhen platform.
- `.test/`: optional Terraform and Taskfile-based end-to-end test harness.

## Quickstart (Contributor)

### 1) Clone and open the repository

```bash
git clone https://github.com/Saurabhtbj1201/aws-c7ncodecollection.git
cd aws-c7ncodecollection
```

### 2) Choose your environment

- Recommended: use the dev container configuration in `.devcontainer.json`.
- Alternative: set up a local Python environment and install dependencies:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 3) Provide AWS credentials for read-only checks

Most bundles require at least:

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-west-2"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
```

### 4) Start with one existing check

The easiest first path is to add a new policy/check to an existing bundle (commonly `aws-c7n-s3-health` or `aws-c7n-ec2-health`) before creating a brand-new bundle.

## Contributing

See `CONTRIBUTING.md` for a step-by-step guide, checklist, and PR workflow.

## Notes For Windows Contributors

The `.test/Taskfile.yaml` flows use shell utilities (`source`, `awk`, `jq`, `column`) and are easiest to run in a Linux devcontainer or WSL shell.

## Related Documentation

- RunWhen author docs: https://docs.runwhen.com/public/v/runwhen-authors/codecollection-development/getting-started/running-your-first-codebundle
