CREATE OR REPLACE VIEW marrowick_health.corporate_view AS
SELECT encounter_id, tenant_id, encounter_date, encounter_type, diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant1_curated
UNION ALL
SELECT encounter_id, tenant_id, encounter_date, encounter_type, diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant2_curated
UNION ALL
SELECT encounter_id, tenant_id, encounter_date, encounter_type, diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant3_curated;