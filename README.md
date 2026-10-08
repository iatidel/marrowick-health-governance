# Marrowick Health Analytics: Data Governance on AWS

CCGC 5506 Mid Term Project (Project 4). Due October 23, 2026.
Synthetic data only. No real PII or PHI is used anywhere.

## Team
- iatidel (Lead): Lake Formation, architecture diagram, README
- Inder: tenant S3 layout, KMS, synthetic data, PII gate
- Maha: CloudTrail audit, IAM policies, compliance mapping, runbook

## Architecture
(diagram link goes here: docs/architecture.png)

## Repo Structure
| Folder | Contents |
|---|---|
| infra/ | KMS key policy, bucket policies, Step Functions definition |
| lambda/ | PII scanner code |
| data/ | Synthetic data generator |
| sql/ | Athena, CloudTrail and Lake Formation test queries |
| iam/ | Least-privilege policy JSON (Deployed vs Design-only) |
| docs/ | Diagram, compliance table, runbook, report |
| evidence/ | Screenshots and recordings (videos linked, not stored) |

## Rebuild From a Fresh Learner Lab Session
(fill in as we build)

## Learner Lab Limitations
- Only LabRole is available, so no custom IAM roles can be created.
- LF-Tags are blocked. We use named-resource grants and data filters.
- Macie is not authorized. We use a regex-based PII gate only.

## Team Rules
- Never commit AWS credentials or real data.
- Work in your own folder to avoid merge conflicts.
- Commit after every session, because lab resources get wiped.