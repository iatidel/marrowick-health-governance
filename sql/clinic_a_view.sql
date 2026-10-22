CREATE OR REPLACE VIEW marrowick_health.clinic_a_view AS
SELECT encounter_id, tenant_id, encounter_date, encounter_type,
       diagnosis_code, clinician_id, billing_amount
FROM marrowick_health.tenant1_curated
WHERE tenant_id = 'clinic-a';