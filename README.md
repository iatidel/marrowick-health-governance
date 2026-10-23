# Marrowick Health Analytics: Governance, Security and Compliance for a Multi-Tenant Data Lake

**Course:** CCGC 5506 Mid Term Project (Project 4), Humber, Fall 2026
**Team:** Iatidel Akik, Inderjitsingh Labana, Maha Al-Tuhfi
**Region:** US East (N. Virginia), `us-east-1`
**CloudFormation stack name:** `marrowick-project`
**Template file:** `infra/marrowick-health-merged.yml`

> **Note:** All data in this project is synthetic. No real patient data was used.

---

## 1. What this project is

Marrowick Health Analytics is a fictional company. It receives de-identified encounter and billing data from three clinic partners. It must prove that its data platform is safe before a partner security review.

Our team built the **guardrails** around the data lake. We did not build new analytics. The guardrails are:

1. **Tenant separation:** each clinic has its own S3 bucket.
2. **Encryption at rest:** all tenant buckets use one customer-managed KMS key.
3. **PII gate:** every uploaded file is scanned automatically. Rows with personal information go to quarantine, and an email alert is sent.
4. **Access control:** each analyst role sees only the rows and columns it is allowed to see.
5. **Audit trail:** CloudTrail records who did what, and we search it with Athena.

**Important:** AWS Lake Formation is **not available** in our AWS Academy Learner Lab. We replaced it with Athena views. This is explained honestly in Section 7.

---

## 2. Where to find each deliverable

| Deliverable | Where |
|---|---|
| Architecture diagram | `architecture/Marrowick_architecture_diagram.drawio` and Section 3 |
| Infrastructure as Code | `infra/marrowick-health-merged.yml` |
| SQL (views and audit queries) | `sql/` folder and Section 9 |
| Evidence screenshots | `evidence/` folder |
| Permission matrix | Section 7.3 |
| IAM policy set | Section 10 |
| Compliance mapping | Section 11 |
| Incident response runbook | Section 12 |
| How to reproduce | Section 4 |

---

## 3. Architecture

The diagram is in `architecture/Marrowick_architecture_diagram.drawio`.

```
Clinic CSV upload
      |
      v
S3 tenant bucket (raw/)  --->  EventBridge rule (new .csv in raw/)
                                      |
                                      v
                              Step Functions (PII gate)
                                      |
                                      v
                              Lambda (regex PII scan, every column)
                               /                     \
                       clean rows                  flagged rows
                          |                             |
                   curated/ folder              quarantine/ folder
                          |                             |
                          |              Step Functions --> SNS --> email alert
                          v
              Glue crawlers (read curated/ only) --> Glue Data Catalog
                          |
                          v
              Athena views (one per clinic + one corporate)
                          |
                          v
                   Analysts (query views)

CloudTrail (management + S3 data events) --> logs bucket --> Athena audit queries
```

### Services used

| Service | What we use it for |
|---|---|
| Amazon S3 | 3 tenant buckets, 1 CloudTrail logs bucket, 1 Athena results bucket |
| AWS KMS | One customer-managed key for encryption at rest |
| Amazon EventBridge | Starts the PII gate when a CSV lands in `raw/` |
| AWS Step Functions | Runs the quarantine-and-notify workflow |
| AWS Lambda | Regex PII scanner, and a small helper that creates the folders |
| Amazon SNS | Sends the PII alert email |
| AWS Glue | Database and 3 crawlers (curated data only) |
| Amazon Athena | Views for access control, and CloudTrail audit queries |
| AWS CloudTrail | Audit log of API calls and S3 object access |
| AWS CloudFormation | Deploys everything from one template |
| IAM (LabRole) | The only role the Learner Lab allows |

> **Note:** The Lake Formation box in the diagram is only the original plan. It was blocked in the lab. The real access control in this project is the Athena views.

---

## 4. How to reproduce (from a fresh Learner Lab session)

### Before you start
- Start a new AWS Academy Learner Lab session and open the AWS console in `us-east-1`.
- You need: the **LabRole ARN**, an **email address** for alerts, and the 3 synthetic clinic CSV files.

### Step 1. Create the KMS key (by hand)
1. Go to **KMS > Customer managed keys > Create key** (symmetric, encrypt/decrypt).
2. After it is created, open the key and turn on **Automatic key rotation** (365 days).
3. Copy the **key ARN**.

### Step 2. Deploy the CloudFormation stack
1. Go to **CloudFormation > Create stack > With new resources**.
2. Upload `infra/marrowick-health-merged.yml`.
3. Stack name: `marrowick-project`. **Use only lowercase letters, numbers and hyphens.** Our first attempt failed because the name had capital letters.
4. Fill in the parameters:

| Parameter | What to enter |
|---|---|
| `BucketPrefix` | `marrowickh` (change it if the bucket names are already taken) |
| `KMSKeyArn` | The key ARN from Step 1 |
| `LabRoleArn` | The ARN of `LabRole` |
| `AlertEmail1` | Your email for PII alerts |
| `HealthDatabaseName` | `marrowick_health` (underscores only, no hyphens) |
| `AuditDatabaseName` | `marrowick_audit` |
| `TrailName` | `marrowick-audit-trail` |
| `AuditStartDate` | `2026/10/01` (first day Athena looks at in CloudTrail logs) |

5. Create the stack and wait for `CREATE_COMPLETE`.

### Step 3. Confirm the SNS email
Open the email from AWS Notifications and click **Confirm subscription**. Without this, no alert emails arrive.

### Step 4. Upload the clinic files
Upload each CSV into the `raw/` folder of its bucket:

| Clinic | Bucket | File |
|---|---|---|
| Clinic A (`clinic-a`) | `marrowickh-tenant1` | `raw/clinic-a_encounters.csv` |
| Clinic B (`clinic-b`) | `marrowickh-tenant2` | `raw/clinic-b_encounters.csv` |
| Clinic C (`clinic-c`) | `marrowickh-tenant3` | `raw/clinic-c_encounters.csv` |

**When you upload in the console, set encryption to SSE-KMS** with our key. The bucket policy rejects uploads that are not KMS-encrypted.

The rest runs by itself: EventBridge starts Step Functions, Lambda scans the file, clean rows go to `curated/`, flagged rows go to `quarantine/`, and an SNS email is sent.

### Step 5. Run the Glue crawlers
Go to **Glue > Crawlers** and run the 3 crawlers (`marrowick-project-tenant1-crawler`, `...tenant2-crawler`, `...tenant3-crawler`). They create the tables `tenant1_curated`, `tenant2_curated` and `tenant3_curated` in the database `marrowick_health`.

### Step 6. Create the Athena views
Open Athena, choose the database `marrowick_health`, and run the 4 files in `sql/`:
- `sql/clinic_a_view.sql`
- `sql/clinic_b_view.sql`
- `sql/clinic_c_view.sql`
- `sql/corporate_view.sql`

### Step 7. Run the audit queries
1. Open Athena, choose the workgroup `marrowickh-audit-wg` and the database `marrowick_audit`.
2. Go to **Saved queries**. Run **00 - Create cloudtrail_logs table** first.
3. Then run 01, 02 and 03.

### Step 8. Clean up before you log off
- Delete the stack (`marrowick-project`). You must **empty the S3 buckets first**, or the delete fails.
- The CloudTrail logs bucket has `DeletionPolicy: Retain`, so it stays after the stack is deleted. Delete it by hand if you do not need the evidence.
- Nothing in this project runs all the time. Everything is serverless and pay-per-use.

---

## 5. Multi-tenant design and encryption

### 5.1 Tenant separation
Each clinic has its **own bucket** (physical separation, not only a prefix).

| Clinic | `tenant_id` value | Bucket | Folders |
|---|---|---|---|
| Clinic A | `clinic-a` | `marrowickh-tenant1` | `raw/`, `curated/`, `quarantine/` |
| Clinic B | `clinic-b` | `marrowickh-tenant2` | `raw/`, `curated/`, `quarantine/` |
| Clinic C | `clinic-c` | `marrowickh-tenant3` | `raw/`, `curated/`, `quarantine/` |

- `raw/` is where a clinic uploads. It is **never** crawled.
- `curated/` holds only rows that passed the PII scan. Only this folder is crawled.
- `quarantine/` holds the rows that were flagged.
- All 3 buckets block public access.

### 5.2 Encryption at rest (KMS)
- We use **one customer-managed KMS key** for the 3 tenant buckets and the Athena results bucket.
- **Automatic key rotation is on (365 days).** We turned it on by hand when we created the key, before deploying the stack.
- The key ARN is passed to the template as the parameter `KMSKeyArn`.
- The buckets use **SSE-KMS** as default encryption, with bucket keys turned on.

**Key policy (what it allows and why):**
The real key policy is saved in `iam/kms-key-policy.json` (account ID replaced by `<ACCOUNT_ID>`). It has two statements:

| Statement | Who | What it allows |
|---|---|---|
| `Enable IAM User Permissions` | The account root (`arn:aws:iam::<ACCOUNT_ID>:root`) | `kms:*`. This is the standard console default. It lets IAM policies in the account grant access to the key, so `LabRole` can use the key for encrypt and decrypt through its own IAM permissions. |
| `Allow access for Key Administrators` | `LabRole` | Manage the key only: create, describe, enable, disable, update, tag, delete, schedule deletion, rotate on demand. It does **not** list `kms:Encrypt`, `kms:Decrypt` or `kms:GenerateDataKey`. |

- **No separate "key users" statement.** Encrypt and decrypt for S3, Lambda and Glue work because of the root statement plus the permissions that `LabRole` already has in IAM.
- **Why a customer-managed key (and not the default S3 key):** we control the key policy, every use of the key is logged in CloudTrail, and we can turn on rotation.

**Honest limits of this key policy:**
- `LabRole` is both the key administrator and the role that uses the key (the lab has only one role). So there is **no separation of duties** between managing the key and using it.
- The root statement is wide (`kms:*`). In production we would remove the broad root access from daily use, make an admin role that cannot decrypt, and add a separate key-user statement for the scanner and analyst roles with `kms:Decrypt` and `kms:GenerateDataKey` and a `kms:ViaService` condition.

**Key rotation and old files:**
- Automatic rotation is on (every 365 days). AWS keeps the **old key material**, so files that were already encrypted can still be decrypted. Nothing has to be re-encrypted.
- New encryption uses the new key material. The key ID and ARN stay the same, so the buckets, Lambda and the CloudFormation parameter do not need to change.
- Because the project only ran for a few weeks, no automatic rotation has happened yet. We turned the setting on and checked it, but we could not see a real rotation event.

### 5.3 Bucket policies (guardrails)
Each tenant bucket has the same 3 **Deny** rules:

| Rule | What it does |
|---|---|
| `DenyNonTLSAccess` | Blocks any access that is not HTTPS |
| `DenyUnencryptedUploads` | Blocks uploads with no encryption header |
| `DenyIncorrectEncryption` | Blocks uploads that are not encrypted with KMS |

We saw these rules working. In the CloudTrail results, an upload to `raw/clinic-c_encounters.csv` was refused with `AccessDenied` before we uploaded it with the right encryption setting (see Section 9, Audit question 3).

We tested this rule ourselves. When we uploaded `clinic-c_encounters.csv` to `marrowickh-tenant3/raw/` without turning on KMS encryption, S3 refused it with "Access denied". The upload only worked after we chose SSE-KMS with our key.

Evidence: `evidence/08-upload-data-file-to-raw-without-activating-KMS-encryption.png`


### 5.4 Honest note about the logs bucket
The CloudTrail logs bucket uses **AES256 (SSE-S3)**, not our KMS key. CloudTrail needs extra edits in the key policy to write with a customer-managed key, and we did not do this. All 3 tenant buckets and the Athena results bucket do use our KMS key.

---

## 6. PII/PHI detection gate

### 6.1 How it works
1. A clinic uploads a `.csv` into `raw/`.
2. An **EventBridge rule** sees the "Object Created" event for `raw/*.csv` and starts the Step Functions workflow.
3. **Step Functions** runs the Lambda scanner (`ScanClinicData`).
4. The **Lambda** reads every row and checks **every column** against regex patterns.
5. Clean rows are saved to `curated/<file>_clean.csv`. Flagged rows are saved to `quarantine/<file>_flagged.csv`. Both files are saved with SSE-KMS.
6. A **Choice state** (`CheckFlaggedRecords`) checks if `flagged_count > 0`. If yes, Step Functions publishes an **SNS email**.
7. If the Lambda crashes, a second alert (`PIPELINE FAILURE`) is sent and the workflow ends in a `Fail` state.

### 6.2 Patterns the scanner looks for

| Type | What it matches |
|---|---|
| Name | `Contact:`, `Patient:` or `Name:` followed by a first and last name |
| Street address | Number + street name + Ave, St, Rd, Blvd, etc. |
| City and province | City name, then a Canadian province code (ON, QC, BC, ...) |
| Email | `something@domain.com` |
| Health card | `1234-567-890` (optional 2 letters at the end) |
| SIN-like number | `123-456-789` |
| Phone | `(416) 555-1234`, `416-555-1234`, `416.555.1234` |

The regex code is inside the Lambda function in `infra/marrowick-health-merged.yml` (resource `PIIScannerFunction`).

### 6.3 Results with the seeded PII
We seeded fake PII values in the synthetic data. The scanner and the alert worked for all 3 clinics:

| Clinic | Bucket | Total rows | Flagged rows | Clean rows (to `curated/`) |
|---|---|---|---|---|
| Clinic A | `marrowickh-tenant1` | 191 | 4 | 187 |
| Clinic B | `marrowickh-tenant2` | 243 | 6 | 237 |
| Clinic C | `marrowickh-tenant3` | 181 | 4 | 177 |

Evidence (the alert emails):
- `evidence/06-email_alert_tenant1.png`
- `evidence/06-email_alert_tenant2.png`
- `evidence/06-email_alert_tenant3.png`

Example alert text:
> PII/PHI scan alert. Bucket: marrowickh-tenant1. Source: raw/clinic-a_encounters.csv. Total rows: 191. Flagged rows: 4. Quarantine file: quarantine/clinic-a_encounters_flagged.csv.

The curated table only contains clean rows. Evidence: `evidence/11-tenant1-curated-schema.png` (Glue table `tenant1_curated`, 9 columns).

### 6.4 Design choice and limits (honest)
- **We scan row by row.** Clean rows continue to `curated/` and only the flagged rows go to `quarantine/`. The rubric says "any batch containing PII must be quarantined". Our choice means a bad row never reaches `curated/`, but the good rows of the same file do. We chose this so a few bad rows do not block a whole clinic file.
- The original file stays in `raw/` (with the PII inside). `raw/` is not crawled and is not given to analysts.
- Regex only finds known formats. It can miss PII written in an unusual way, and it can flag something that is not PII. Amazon Macie was not used.

---

## 7. Access control

### 7.1 The plan: Lake Formation
The rubric asks for Lake Formation permissions with two roles:

| Role | Rows | Columns |
|---|---|---|
| Clinic analyst | Only their own clinic (`tenant_id` = `clinic-a`, `clinic-b` or `clinic-c`) | Restricted columns hidden |
| Corporate analyst | All 3 clinics | Restricted columns hidden |

The plan was: make the role a Lake Formation admin, register the `curated/` locations, create row filters and a column exclusion, grant the filters to the analysts, and test in Athena.

### 7.2 What went wrong: Lake Formation is blocked
Every Lake Formation write action failed with this type of error:
`not authorized to perform lakeformation:<action> because no identity-based policy allows the action`

| What we tried | Permission denied |
|---|---|
| Open the Data lake administrators page | `lakeformation:GetDataLakeSettings` |
| Register an S3 location | `lakeformation:RegisterResource` |
| Create a data filter | `lakeformation:CreateDataCellsFilter` |
| Open the Grant permissions page | `lakeformation:DescribeLakeFormationIdentityCenterConfiguration` |

What else we checked:
- `LabRole` does not appear in the Register location role list. Only the service-linked role, `vocareum` and `voclabs` appear.
- We tested with `voclabs`, with `LabRole`, and in a second (Sandbox) account. It failed the same way.
- The team playbook says the admin page and data filters worked on October 8. The lab permissions changed after that.
- We contacted our professor. The professor asked the AWS Academy team, and the reply said:

> "Unfortunately, since Lake Formation is not available in the Learner Lab..."

So this is a lab restriction and **we could not fix it**. Screenshots of each error are in `evidence/`.


### 7.3 What we built instead: Athena views
We made 4 Athena views in the database `marrowick_health`:

| View | Rows it returns | Columns it hides |
|---|---|---|
| `clinic_a_view` | Only `tenant_id = 'clinic-a'` | `patient_ref`, `notes_field` |
| `clinic_b_view` | Only `tenant_id = 'clinic-b'` | `patient_ref`, `notes_field` |
| `clinic_c_view` | Only `tenant_id = 'clinic-c'` | `patient_ref`, `notes_field` |
| `corporate_view` | All 3 clinics (UNION ALL of the 3 tables) | `patient_ref`, `notes_field` |

**Permission matrix (what each role should see):**

| Role | Clinic A rows | Clinic B rows | Clinic C rows | `patient_ref` | `notes_field` | Other 7 columns |
|---|---|---|---|---|---|---|
| Clinic A analyst | Yes | No | No | Hidden | Hidden | Yes |
| Clinic B analyst | No | Yes | No | Hidden | Hidden | Yes |
| Clinic C analyst | No | No | Yes | Hidden | Hidden | Yes |
| Corporate analyst | Yes | Yes | Yes | Hidden | Hidden | Yes |

The 7 visible columns are: `encounter_id`, `tenant_id`, `encounter_date`, `encounter_type`, `diagnosis_code`, `clinician_id`, `billing_amount`.

**Example view definition (clinic A):**

```sql
CREATE OR REPLACE VIEW marrowick_health.clinic_a_view AS
SELECT encounter_id, tenant_id, encounter_date, encounter_type,
       diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant1_curated
WHERE tenant_id = 'clinic-a';
```

**Example view definition (Corporate):**

```sql
CREATE OR REPLACE VIEW marrowick_health.corporate_view AS
SELECT encounter_id, tenant_id, encounter_date, encounter_type, diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant1_curated
UNION ALL
SELECT encounter_id, tenant_id, encounter_date, encounter_type, diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant2_curated
UNION ALL
SELECT encounter_id, tenant_id, encounter_date, encounter_type, diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant3_curated;
```

### 7.4 Evidence that the restriction works
- `evidence/13-evidence_access_01_clinic_a_view_rows_no_pii_columns.png`: `clinic_a_view` returns 10 rows, all `clinic-a`, and no `patient_ref` or `notes_field` column.
- `evidence/13-evidence_access_02_clinic_b_view_rows_no_pii_columns.png`: `clinic_b_view` returns 10 rows, all `clinic-b`, and no `patient_ref` or `notes_field` column.
- `evidence/13-evidence_access_03_clinic_c_view_rows_no_pii_columns.png`: `clinic_c_view` returns 10 rows, all `clinic-c`, and no `patient_ref` or `notes_field` column.
- Restricted query test: querying `patient_ref` through a view **fails**, because the view does not have that column.

### 7.5 Limit of this solution (very important)
A view hides data **only if the analyst is allowed to query the view and is NOT allowed to query the base tables or the S3 buckets**. The Learner Lab gives us **one usable role**, so we cannot make separate analyst roles. This means:

- The views show the **intended result**, but AWS does **not enforce** it like Lake Formation would.
- Anyone who uses `LabRole` can still query the base tables.

**In a real production account we would:**
1. Create separate IAM roles for each clinic analyst and for the corporate analyst.
2. Give them **no** direct S3 access and **no** access to the base tables.
3. Use Lake Formation to enforce row filters and column exclusion.

---

## 8. Learner Lab limits and how we handled them (honesty section)

| Limit | What happened | What we did |
|---|---|---|
| Lake Formation is not available | All write actions denied (Section 7.2) | Athena views + documented design |
| Only one role (`LabRole`) and no IAM role creation | Cannot create separate analyst roles | IAM policies written as design-only files (Section 10) |
| Logs bucket cannot use our KMS key easily | CloudTrail needs key policy edits | Logs bucket uses AES256 (Section 5.4) |
| Session time and budget | Sessions stop automatically | Serverless services only, nothing runs all the time |
| No real data allowed | | All data is synthetic |
| Macie not used | Optional service | Regex scanner only |

---

## 9. Audit trail (CloudTrail + Athena)

### 9.1 How it works
1. **CloudTrail** (`marrowick-audit-trail`) records all management API calls and S3 object-level events (read, write, delete) on the 3 tenant buckets. Log file validation is on.
2. The logs go to the **CloudTrail logs bucket**.
3. **Athena** reads the logs through the table `cloudtrail_logs` (created by saved query 00, using partition projection so no crawler is needed).
4. We use the workgroup `marrowickh-audit-wg`. It forces the results into the KMS-encrypted Athena results bucket.

Saved queries (in the template, and also in the `sql/` folder):

| # | Name | Question it answers |
|---|---|---|
| 00 | Create cloudtrail_logs table | Run first. Creates the table. |
| 01 | Who accessed tenant-3 data? | Who read, wrote or deleted objects in the tenant 3 bucket? |
| 02 | What API calls modified bucket policies / encryption? | Who changed a bucket policy, encryption, ACL or public access setting? |
| 03 | Anomaly: denied access attempts on tenant buckets | Which requests were denied (`AccessDenied`)? |

Evidence: `evidence/14-audit-saved-queries.png` and `evidence/15-evidence_audit_01_table_created.png`.

### 9.2 Audit question 1: Who accessed the tenant-3 bucket?

```sql
SELECT eventtime,
       useridentity.arn AS who,
       eventname AS action,
       sourceipaddress,
       json_extract_scalar(requestparameters, '$.key') AS object_key,
       errorcode
FROM cloudtrail_logs
WHERE eventsource = 's3.amazonaws.com'
  AND eventname IN ('GetObject','PutObject','DeleteObject')
  AND json_extract_scalar(requestparameters, '$.bucketName') = 'marrowickh-tenant3'
  AND "timestamp" >= '2026/10/01'
ORDER BY eventtime DESC
LIMIT 100
```

**Result (9 rows)**, evidence: `evidence/15-evidence_audit_02_who_accessed_tenant3.png`

| Who | Action | File | Meaning |
|---|---|---|---|
| `voclabs/user5093906=iatidel` (our user) | `PutObject` | `raw/clinic-c_encounters.csv` | The clinic file was uploaded. One earlier attempt shows an `AccessDenied` error. |
| `LabRole/marrowick-project-pii-scanner` | `GetObject` | `raw/clinic-c_encounters.csv` | The PII scanner read the file. |
| `LabRole/marrowick-project-pii-scanner` | `PutObject` | `quarantine/clinic-c_encounters_flagged.csv` | The scanner wrote the flagged rows. |
| `LabRole/marrowick-project-pii-scanner` | `PutObject` | `curated/clinic-c_encounters_clean.csv` | The scanner wrote the clean rows. |
| `LabRole/AWS-Crawler` (glue.amazonaws.com) | `GetObject` | `curated/clinic-c_encounters_clean.csv` | The crawler read only `curated/`. |
| `voclabs/user5093906=iatidel` (athena.amazonaws.com) | `GetObject` | `curated/clinic-c_encounters_clean.csv` | Three Athena queries read the curated file. |

**What this tells us:** the trail shows the whole life of a file (upload, scan, split, crawl, query). Only the scanner role wrote to `curated/` and `quarantine/`, and the crawler read only `curated/`. This proves the pipeline works as designed.

### 9.3 Audit question 2: Who changed bucket policies?

```sql
SELECT eventtime,
       useridentity.arn AS who,
       eventname AS action,
       json_extract_scalar(requestparameters, '$.bucketName') AS bucket,
       sourceipaddress,
       errorcode
FROM cloudtrail_logs
WHERE eventsource = 's3.amazonaws.com'
  AND eventname IN ('PutBucketPolicy','DeleteBucketPolicy','PutBucketEncryption',
                    'DeleteBucketEncryption','PutBucketAcl',
                    'PutBucketPublicAccessBlock','DeletePublicAccessBlock')
  AND "timestamp" >= '2026/10/01'
ORDER BY eventtime DESC
LIMIT 100
```

**Result (1 row)**, evidence: `evidence/15-evidence_audit_03_policy_changes.png`

| Time | Who | Action | Bucket | Source |
|---|---|---|---|---|
| 2026-10-21 00:36:33Z | `voclabs/user5093906=iatidel` | `PutBucketPolicy` | `marrowickh-tenant1` | `cloudformation.amazonaws.com` |

**What this tells us:** the only bucket policy change was made by our own user, through CloudFormation, when the stack was deployed. There was no manual or unknown change. If someone changed a policy by hand, a new row would appear.



### 9.4 Audit question 3 (anomaly): Denied access attempts

```sql
SELECT eventtime,
       useridentity.arn AS who,
       eventname AS action,
       json_extract_scalar(requestparameters, '$.bucketName') AS bucket,
       errorcode,
       sourceipaddress
FROM cloudtrail_logs
WHERE eventsource = 's3.amazonaws.com'
  AND errorcode IN ('AccessDenied','Client.AccessDenied','AccessDeniedException')
  AND json_extract_scalar(requestparameters, '$.bucketName')
      IN ('marrowickh-tenant1','marrowickh-tenant2','marrowickh-tenant3')
  AND "timestamp" >= '2026/10/01'
ORDER BY eventtime DESC
LIMIT 100
```

**Result (17 rows)**, evidence: `evidence/15-evidence_audit_04_access_denied.png`

The rows show `AccessDenied` on `marrowickh-tenant3`. Examples:
- `GetBucketObjectLockConfiguration`, repeated, by our user from IP `205.178.x.x`. This is the S3 console asking for a setting that `LabRole` is not allowed to read.
- `PutObject` on `raw/clinic-c_encounters.csv`, refused once at 2026-10-21 01:14:10Z (same time as the first upload attempt in Q1).

**What this tells us:** denied requests are easy to find. In a real production account, many denied requests from one unknown identity would be a warning sign of someone testing access.

The first `PutObject` on `raw/clinic-c_encounters.csv` (2026-10-21 01:14:10Z) was denied on purpose. We tested uploading a file to the tenant 3 bucket **without SSE-KMS encryption**. The bucket policy rule `DenyUnencryptedUploads` blocked it with `AccessDenied`. A few minutes later (01:17:22Z) the upload worked after we turned on SSE-KMS with our key. This proves the encryption guardrail is really enforced, and CloudTrail recorded the blocked attempt.

Evidence: `evidence/08-upload-data-file-to-raw-without-activating-KMS-encryption.png`

### 9.5 Extra finding
The Lake Formation calls that were denied in Section 7.2 are also API calls. They should appear in CloudTrail as events from `lakeformation.amazonaws.com` with an error code.

---

## 10. IAM least-privilege policy set

The Learner Lab does not let us create IAM roles or policies. Everything runs as `LabRole`. The rubric asks us to **design** least-privilege policies as JSON files and mark which statements could be deployed and which are design-only.

### 10.1 The policy files

All files are in the `iam/` folder. They are JSON documents written as **design artifacts**. We could not attach them to new roles, because the Learner Lab does not allow creating IAM roles or policies.

| File | Role it is written for | What it allows |
|---|---|---|
| `iam/clinic-a-analyst-policy.json` | Clinic A analyst | Run Athena queries, read only `tenant1_curated` and `clinic_a_view` in Glue |
| `iam/clinic-b-analyst-policy.json` | Clinic B analyst | Same pattern for `tenant2_curated` and `clinic_b_view` |
| `iam/clinic-c-analyst-policy.json` | Clinic C analyst | Same pattern for `tenant3_curated` and `clinic_c_view` |
| `iam/corporate-analyst-policy.json` | Corporate analyst | Read all 3 curated tables and `corporate_view`. No access to the clinic views |
| `iam/pii-scanner-lambda-policy.json` | PII scanner Lambda | Read `raw/`, write `curated/` and `quarantine/` with KMS only, write its own logs |
| `iam/kms-key-policy.json` | KMS key (resource-based policy) | The **real, deployed** key policy. Account ID replaced by a placeholder |
| `iam/lakeformation-data-filters-design-only.json` | Lake Formation filters | 3 row filters (one per clinic) and 3 corporate filters. Both hide `patient_ref` and `notes_field` |

The `<ACCOUNT_ID>`, `<KMS_KEY_ID>` and `<ANALYST_WORKGROUP>` values are placeholders. We did not put the real account ID in the repository.

### 10.2 How the statements are labeled
JSON policies cannot hold comments, so the label is the start of each `Sid` (statement name):

| Sid starts with | Meaning |
|---|---|
| `Deployed...` | The same rule **is deployed** in our stack, but as a **resource-based policy** (bucket policy). (`kms-key-policy.json` is a real key policy and keeps its original statement names.) It is repeated in the identity policy so the file shows the full design. |
| `DesignOnly...` | **Not deployed.** It is an identity-based statement. It needs a separate IAM role, and the Learner Lab does not let us create one. |

### 10.3 Main design rules (least privilege)

| Rule | Statement |
|---|---|
| Analysts never read S3 data directly | `DesignOnlyDenyDirectTenantBucketAccess` denies `s3:*` on all 3 tenant buckets. They reach data only through Athena and Lake Formation (`lakeformation:GetDataAccess`). |
| A clinic analyst sees only their own clinic | Glue read is allowed only on their own table and view. `DesignOnlyDenyOtherClinicsAndCorporateObjects` denies the other clinics and `corporate_view`. |
| Corporate analyst has no clinic views | `DesignOnlyDenyClinicViews`. |
| Nobody weakens the controls | `DesignOnlyDenyChangingSecurityControls` denies changing bucket policies, KMS rotation, CloudTrail and Lake Formation settings. |
| Scanner cannot edit original files | `DesignOnlyDenyChangingRawFiles` denies write and delete in `raw/`. |
| Scanner must use KMS | `DeployedAsBucketPolicyRequireKmsOnWrite` (deployed as the bucket policy rule `DenyIncorrectEncryption`). |
| HTTPS only | `DeployedAsBucketPolicyDenyNonTLS` (deployed as the bucket policy rule `DenyNonTLSAccess`). |

### 10.4 Honest limit: IAM alone cannot hide rows or columns
IAM policies control **which objects and tables** a role can touch. They cannot filter **rows** or hide **columns** inside a table. Also, with IAM only, a user who queries a view in Athena still needs permission to read the base table and its S3 data. That is why the views in Section 7 are not real enforcement.

Row and column control needs **Lake Formation**. The file `lakeformation-data-filters-design-only.json` shows what we would deploy. It was not deployed because Lake Formation is blocked.

### 10.5 What we checked
We checked that every JSON file is valid. We did **not** deploy them or test them with IAM Access Analyzer, because the lab blocks IAM changes.

### 10.6 What we really deployed under the lab limits
These controls are really deployed: the S3 bucket policies (Section 5.3), the KMS key, the Athena workgroup that forces encrypted results, and public access block on all buckets.

---

## 11. Compliance mapping (simplified PIPEDA-style)

We mapped our controls to the 10 fair information principles of PIPEDA (Canada's private-sector privacy law). This is a **simplified student mapping**. It is not legal advice and it is not a certification. All data in this project is synthetic.

### 11.1 Controls mapped to principles

| Control we built | PIPEDA principle | How it supports the principle | Evidence | Status |
|---|---|---|---|---|
| KMS customer-managed key, SSE-KMS on tenant buckets, rotation on | 4.7 Safeguards | Data is encrypted at rest. We control the key and its use. | Section 5.2 | Implemented |
| Bucket policies (HTTPS only, KMS only) and public access block | 4.7 Safeguards | Blocks unencrypted uploads and unsafe access. | Section 5.3, `evidence/08-...png` | Implemented and tested |
| One bucket per clinic | 4.5 Limiting use, disclosure and retention; 4.7 Safeguards | Clinic data is kept apart (physical separation). | Section 5.1 | Implemented |
| Regex PII gate with quarantine | 4.4 Limiting collection; 4.7 Safeguards | Personal information is kept out of the curated zone. | Section 6, alert emails | Implemented and tested |
| SNS alert when PII is found | 4.1 Accountability; 4.7 Safeguards | The team is told right away when the gate catches something. | `evidence/06-email_alert_*.png` | Implemented and tested |
| Athena views hide `patient_ref`, `notes_field` and other clinics' rows | 4.5 Limiting use and disclosure | Shows the intended access rules. | Section 7.3, 7.4 | **Partial.** Not enforced by AWS (single role) |
| IAM policy design | 4.7 Safeguards; 4.5 Limiting use and disclosure | Documents least privilege for each role. | Section 10 | **Design only** |
| CloudTrail + Athena audit queries | 4.1 Accountability | Shows who accessed or changed what. | Section 9 | Implemented and tested |
| Incident response runbook | 4.1 Accountability; 4.7 Safeguards | Defines how we respond if a control fails. | Section 12 | Documented, not exercised |
| Synthetic, de-identified data | 4.4 Limiting collection | No real personal data is collected. | Section 1 | Implemented |

### 11.2 Not covered / out of scope

| Not covered | Why |
|---|---|
| 4.2 Identifying purposes and 4.3 Consent | Needs real patients and clinic agreements. We use synthetic data. |
| 4.6 Accuracy | We do not check if the data is correct. We only check for PII. |
| 4.5 Retention and deletion | No S3 lifecycle rules and no retention schedule. |
| 4.8 Openness | No privacy policy or public statement. |
| 4.9 Individual access | No process for a person to ask for their data. |
| 4.10 Challenging compliance | No complaint process. |
| Breach notification to the Privacy Commissioner and to people | Our runbook covers technical steps only. |
| Real enforcement of access control | Lake Formation is blocked and the lab has one role (Sections 7 and 8). |
| Complete PII detection | Regex only. Amazon Macie was not used. A pattern can miss PII. |
| CMK encryption of the CloudTrail logs bucket | It uses AES256 (Section 5.4). |
| Monitoring and alarms | No CloudWatch dashboard or alarms for failed access. |
| Legal or regulatory certification | This is a learning project. We do **not** claim PIPEDA compliance. |

---

## 12. Incident response runbook

### 12.1 Purpose

This runbook describes how our team responds when a security control fails in the Marrowick Health Analytics platform.

We cover two scenarios:
1. PII gate failure: Personal information reaches `curated/`, or an expected SNS alert is not sent.
2. Access control failure: An analyst sees another clinic's records or a restricted column.

For both scenarios, we follow: Detect → Contain → Investigate → Fix → Report.

### 12.2 Team Responsibilities

| Member | Responsibility |
|---|---|
| Inder | Investigate Lambda, Step Functions, S3 processing, and SNS |
| Iatidel | Investigate Athena views and access controls |
| Maha | Investigate CloudTrail logs with Athena and collect evidence |
| All members | Document findings and verify corrective actions |

### 12.3 Scenario 1 — PII Gate Failure

**Example:** Sensitive information reaches `curated/` instead of `quarantine/`, or an expected SNS notification is missing.

**Step 1 — Detect**
- Check Step Functions execution history.
- Review Lambda execution results and CloudWatch logs.
- Inspect the `curated/` and `quarantine/` folders.
- Check whether SNS sent the expected alert.

**Step 2 — Contain**
- Temporarily stop the affected workflow or new uploads, with team approval.
- Restrict access to affected curated files.
- Preserve the original files, logs, and screenshots.

**Step 3 — Investigate**
- Identify the affected clinic bucket and CSV file.
- Review the Lambda scanner and Step Functions execution.
- Search CloudTrail logs using Athena for `PutObject` and `GetObject` events.
- Record the AWS identity, timestamp, object name, and outcome.

**Step 4 — Fix**
- Correct the Lambda scanner, workflow, or SNS configuration.
- Isolate any incorrectly published files after preserving evidence.
- Reprocess the synthetic CSV.
- Verify clean rows reach `curated/` and flagged rows reach `quarantine/`.
- Confirm the SNS notification works.

**Step 5 — Report**
- Record the incident, root cause, actions taken, and results.
- Save S3, Step Functions, Lambda, SNS, and Athena screenshots.
- Inform the team and instructor.

### 12.4 Scenario 2 — Access Control Failure

**Example:** A Clinic A analyst sees Clinic B records or restricted columns such as `patient_ref` or `notes_field`.

**Step 1 — Detect**
- Run the relevant Athena view.
- Check the tenant IDs and visible columns.
- Compare the results with the expected access-control matrix.

**Step 2 — Contain**
- Stop using the affected query or view.
- Restrict access where AWS permissions allow.
- Save the original query and results as evidence.

**Step 3 — Investigate**
- Review the Athena view's SQL filters and columns.
- Check whether the underlying Glue tables are directly accessible.
- Review IAM and S3 access permissions.
- Search CloudTrail logs using Athena for relevant AWS activities.

**Step 4 — Fix**
- Correct the Athena view definition or permissions.
- Re-run clinic and corporate view tests.
- Confirm the views return only the intended rows and columns.
- Document any restrictions that cannot be enforced in Learner Lab.

**Step 5 — Report**
- Record the affected view, findings, and root cause.
- Preserve query results and screenshots.
- Inform the team and instructor about the outcome.

### 12.5 Evidence and Limitations

For each incident, preserve:
- Date and time
- Affected AWS resources
- AWS identity, if available
- CloudTrail and Athena evidence
- Relevant Lambda and Step Functions logs
- Corrective actions and verification results

The project uses synthetic data. Lake Formation restrictions prevented full fine-grained access controls. Athena views demonstrate filtering, but the shared `LabRole` does not enforce complete tenant isolation.

This runbook documents proposed procedures and does not claim that a full incident-response exercise has been performed.

---

## 13. Cost and performance

- Everything is **serverless and pay-per-use**: S3, KMS, Lambda, Step Functions, EventBridge, SNS, Glue crawlers, Athena and CloudTrail.
- No always-on services (no EMR, no OpenSearch, no SageMaker endpoint).
- Athena audit queries scan only a few hundred KB (about 350 to 365 KB in our runs), so the cost is very small. We also limit the scan with `AuditStartDate` and a date partition.
- Lambda has a 120 second timeout and 256 MB of memory. This is enough for our small files (under 250 rows each). For very large files we would use a Glue job.
- The Athena results are stored in a KMS-encrypted bucket, so audit results are protected too.

---

## 14. Lessons learned

- A cloud service can be missing or blocked in the lab. We should check service availability in the **first session** and keep a fallback plan ready.
- A view is not real security if everyone can still read the base tables. Real enforcement needs separate roles plus Lake Formation.
- CloudFormation stack names and Glue database names have rules (lowercase, no hyphens in database names). Our first deploy failed because of this.
- Bucket policies that require KMS encryption work well, but they also block our own uploads if we forget the encryption setting.
- CloudTrail is useful for proving what happened, but only if the trail and Athena table are set up **before** the events happen.

---

## 15. Repository structure

```
.
├── README.md
├── architecture/
│   └── Marrowick_architecture_diagram.png
├── infra/
│   └── marrowick-health-merged.yml
├── sql/
│   ├── clinic_a_view.sql
│   ├── clinic_b_view.sql
│   ├── clinic_c_view.sql
│   ├── corporate_view.sql
│   └── audit_queries.sql        (queries 00 to 03)
├── iam/
│   ├── clinic-a-analyst-policy.json
│   ├── clinic-b-analyst-policy.json
│   ├── clinic-c-analyst-policy.json
│   ├── corporate-analyst-policy.json
│   ├── pii-scanner-lambda-policy.json
│   ├── kms-key-policy.json
│   └── lakeformation-data-filters-design-only.json
└── evidence/                    (all screenshots)
```


---

## 16. Team

Iatidel Akik, Inderjitsingh Labana, Maha Al-Tuhfi
