# AWS Learner Lab Limitations

**Project:** Marrowick Health Analytics  

## 1. Overview

Our team used AWS Academy Learner Lab and AWS Sandbox to develop and test the Marrowick Health Analytics security architecture.

We successfully configured several AWS services, but encountered IAM permission restrictions that prevented us from completing some operations.

## 2. Permission Limitations

| AWS Service | Issue | Impact |
|---|---|---|
| AWS Lake Formation | AccessDenied for `lakeformation:RegisterResource` | Unable to register the required S3 data locations |
| AWS Lake Formation | AccessDenied for `lakeformation:CreateDataCellsFilter` | Unable to create the planned row-level and column-level data filters |
| IAM Access Analyzer | AccessDenied for `access-analyzer:ValidatePolicy` | Unable to use AWS policy validation in the S3 policy editor |

## 3. Actions Taken

- Checked Lake Formation administrator settings.
- Attempted Lake Formation operations in AWS Academy Learner Lab.
- Tested the Lake Formation setup in the Sandbox environment.
- Captured permission errors as evidence.
- Prepared proposed IAM least-privilege policies as JSON documents.
- Continued implementing CloudTrail and Athena auditing independently.

## 4. Alternative Approach

If Lake Formation permissions remain unavailable, the team proposes using S3 bucket policies, IAM permissions, or approved Athena views to demonstrate selected access restrictions.

These alternatives are not equivalent to Lake Formation's fine-grained row-level and column-level enforcement.

Any alternative implementation will require instructor approval and additional testing.

## 5. Successfully Demonstrated Controls

- AWS KMS customer-managed key configuration
- CloudFormation deployment of encrypted clinic S3 buckets
- CloudTrail management and S3 object data-event logging
- Delivery of CloudTrail logs to S3
- Athena queries identifying Clinic 3 object activity
- Athena queries identifying S3 bucket policy changes
- Athena queries identifying permission-denied events


## 6. Conclusion

AWS Academy permission restrictions affected our ability to implement certain Lake Formation capabilities.

We documented these limitations and developed alternative security designs while continuing to test the available AWS security and auditing services.
