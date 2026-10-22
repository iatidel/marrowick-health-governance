CREATE OR REPLACE VIEW marrowick_health.clinic_b_view AS
SELECT encounter_id, tenant_id, encounter_date, encounter_type,
       diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant2_curated
WHERE tenant_id = 'clinic-b';