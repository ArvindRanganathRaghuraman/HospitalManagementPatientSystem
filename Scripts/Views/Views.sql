-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM
-- Patient Module - Views
-- Schema: HMS_OWNER
-- File: Views.sql
-- Run after: DDL.sql, Data_Loading.sql
-- =============================================================

-- DROP existing views before recreating
BEGIN EXECUTE IMMEDIATE 'DROP VIEW v_patient_medical_history'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW vw_patient_visit_summary';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP VIEW vw_uninsured_patients';     EXCEPTION WHEN OTHERS THEN NULL; END;
/


-- =============================================================
-- VIEW 1: V_PATIENT_MEDICAL_HISTORY
-- Purpose : Full detail — one row per medication per visit
--           Use this when filtering/searching by medication name
-- Usage   : SELECT * FROM v_patient_medical_history
--           WHERE patient_id = :id;
-- =============================================================
CREATE OR REPLACE VIEW v_patient_medical_history AS
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name  AS patient_name,
    p.date_of_birth,
    p.blood_type,
    p.is_minor,
    a.appointment_id,
    a.appointment_date,
    a.appointment_time,
    a.reason                             AS visit_reason,
    a.status                             AS appointment_status,
    a.notes                              AS visit_notes,
    a.doctor_id,
    pr.prescription_id,
    pr.prescribed_date,
    pr.notes                             AS prescription_notes,
    pi.medication_name,
    pi.dosage,
    pi.frequency,
    pi.duration_days,
    pi.instructions
FROM       patient           p
LEFT JOIN  appointment       a  ON a.patient_id       = p.patient_id
LEFT JOIN  prescription      pr ON pr.appointment_id  = a.appointment_id
LEFT JOIN  prescription_item pi ON pi.prescription_id = pr.prescription_id;


-- =============================================================
-- VIEW 2: VW_PATIENT_VISIT_SUMMARY
-- Purpose : One row per visit — all medications collapsed into
--           a single pipe-separated column via LISTAGG
-- Usage   : SELECT * FROM vw_patient_visit_summary
--           WHERE patient_id = :id;
-- =============================================================
CREATE OR REPLACE VIEW vw_patient_visit_summary AS
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name   AS patient_name,
    p.date_of_birth,
    p.blood_type,
    p.is_minor,
    a.appointment_id,
    a.appointment_date,
    a.appointment_time,
    a.reason                              AS visit_reason,
    a.status                              AS appointment_status,
    a.notes                               AS visit_notes,
    a.doctor_id,
    pr.prescription_id,
    pr.prescribed_date,
    LISTAGG(pi.medication_name || ' ' || pi.dosage, ' | ')
        WITHIN GROUP (ORDER BY pi.item_id) AS medications
FROM       patient           p
LEFT JOIN  appointment       a  ON a.patient_id       = p.patient_id
LEFT JOIN  prescription      pr ON pr.appointment_id  = a.appointment_id
LEFT JOIN  prescription_item pi ON pi.prescription_id = pr.prescription_id
GROUP BY
    p.patient_id, p.first_name, p.last_name,
    p.date_of_birth, p.blood_type, p.is_minor,
    a.appointment_id, a.appointment_date, a.appointment_time,
    a.reason, a.status, a.notes, a.doctor_id,
    pr.prescription_id, pr.prescribed_date;


-- =============================================================
-- VIEW 3: VW_UNINSURED_PATIENTS
-- Purpose : All patients with no insurance, expired policy,
--           or inactive insurance — for billing follow-up
-- Usage   : SELECT * FROM vw_uninsured_patients;
--           SELECT * FROM vw_uninsured_patients
--           WHERE insurance_issue = 'NO INSURANCE';
-- =============================================================
CREATE OR REPLACE VIEW vw_uninsured_patients AS
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name  AS patient_name,
    p.date_of_birth,
    p.phone,
    p.email,
    p.status                             AS patient_status,
    p.is_minor,
    CASE
        WHEN p.insurance_id IS NULL         THEN 'NO INSURANCE'
        WHEN i.status = 'EXPIRED'           THEN 'EXPIRED INSURANCE'
        WHEN i.status = 'INACTIVE'          THEN 'INACTIVE INSURANCE'
        WHEN i.policy_expiry_date < SYSDATE THEN 'POLICY LAPSED'
    END                                  AS insurance_issue,
    i.provider_name,
    i.policy_number,
    i.policy_expiry_date,
    i.status                             AS insurance_status
FROM      patient   p
LEFT JOIN insurance i ON i.insurance_id = p.insurance_id
WHERE p.insurance_id IS NULL
   OR i.status         IN ('EXPIRED', 'INACTIVE')
   OR i.policy_expiry_date < SYSDATE;


COMMIT;
