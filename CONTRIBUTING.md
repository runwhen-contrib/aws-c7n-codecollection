# Contributing

Thanks for contributing to this AWS CodeCollection.

This repository packages Cloud Custodian checks as RunWhen codebundles. A high-quality contribution should improve one of these areas:

- Detection coverage (new AWS health/security check)
- Signal quality (better thresholds, less noise)
- Triage quality (clear runbook issues and next steps)
- Reliability (test improvements, parsing robustness, docs)

## Prerequisites

- Python 3.10+
- Cloud Custodian (`c7n`), Robot Framework, and dependencies from `requirements.txt`
- AWS CLI configured with credentials for the target account/region
- Optional but recommended for end-to-end tests:
  - Docker
  - Terraform
  - Task (`task` command)
  - jq

## Development Environment

### Option A (recommended): Dev Container

Open this repository in VS Code Dev Containers using `.devcontainer.json`.

### Option B: Local environment

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Recommended First Contribution

Start by adding one new check to an existing bundle (for example in `codebundles/aws-c7n-s3-health`), instead of creating a new bundle from scratch.

### Add A New Check To An Existing Bundle

1. Add a policy file

Create a new Cloud Custodian policy file (`*.yaml`) or template (`*.j2`) in the bundle directory.

2. Update SLI logic

Edit the bundle `sli.robot` to:

- run the new policy
- read its `ResourceCount`
- incorporate it into the score or metric output

3. Update runbook logic

Edit `runbook.robot` to:

- parse and summarize the new check results
- raise issues with clear title, expected/actual, severity, and next steps

4. Update bundle documentation

Update the bundle `README.md` with:

- what the new check detects
- any new config variables and defaults
- expected operational impact

5. Validate locally

At minimum, run the policy directly and ensure it returns expected output.

For full validation, use the bundle `.test` workflow (if present).

## Creating A New Bundle (Second Contribution)

When you are ready, copy a similar bundle and update all four areas consistently:

- policy files (`*.yaml` / `*.j2`)
- `sli.robot`
- `runbook.robot`
- `.runwhen/generation-rules` and `.runwhen/templates`

Ensure `baseName`, template names, and `pathToRobot` values align.

## Branch And PR Workflow

1. Fork this repository and create a feature branch.
2. Keep PRs focused on one bundle or one logical change.
3. Add tests or validation notes in the PR description.
4. Open a PR using the included template.

## Quality Checklist

Before opening a PR, confirm:

- No secrets or credentials are committed.
- New policy names are unique and descriptive.
- Runbook issues include actionable remediation steps.
- Bundle README reflects new behavior and config.
- Generation templates still resolve correctly.
- Existing checks in the touched bundle continue to work.

## Security And Credentials

- Never commit AWS keys, tokens, or workspace secrets.
- Use local secret files only under ignored paths.
- Use least-privilege AWS IAM permissions for testing.

## Need Help?

- Open a draft PR early and describe your intended check.
- Include sample policy output and expected issue text for faster feedback.
