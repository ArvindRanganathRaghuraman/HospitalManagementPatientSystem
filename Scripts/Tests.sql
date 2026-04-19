-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM — Patient Module
-- Test Script
-- Run after: DDL.sql → Triggers.sql → Procedures.sql
--            → Data_Loading.sql → Views.sql
-- =============================================================

SET SERVEROUTPUT ON;


-- =============================================================
-- 1. ROW COUNT VERIFICATION
-- =============================================================
SELECT 'insurance'        AS tbl, COUNT(*) AS total FROM insurance
UNION ALL
SELECT 'patient',                  COUNT(*)          FROM patient
UNION ALL
SELECT 'patient - minors',         COUNT(*)          FROM patient WHERE is_minor = 'Y'
UNION ALL
SELECT 'patient - insured',        COUNT(*)          FROM patient WHERE insurance_id IS NOT NULL
UNION ALL
SELECT 'patient - uninsured',      COUNT(*)          FROM patient WHERE insurance_id IS NULL
UNION ALL
SELECT 'appointment',              COUNT(*)          FROM appointment
UNION ALL
SELECT 'prescription',             COUNT(*)          FROM prescription
UNION ALL
SELECT 'prescription_item',        COUNT(*)          FROM prescription_item
UNION ALL
SELECT 'bill',                     COUNT(*)          FROM bill
UNION ALL
SELECT 'payment',                  COUNT(*)          FROM payment;


-- =============================================================
-- 2. VIEW: v_patient_medical_history
-- Full detail — one row per medication per visit
-- =============================================================

-- Minor patient (Emma Smith, patient_id=1)
SELECT patient_name, appointment_date, visit_reason,
       appointment_status, medication_name, dosage, frequency
FROM   v_patient_medical_history
WHERE  patient_id = 1;

-- Uninsured adult patient (patient_id=176)
SELECT patient_name, appointment_date, visit_reason,
       appointment_status, medication_name, dosage
FROM   v_patient_medical_history
WHERE  patient_id = 176;


-- =============================================================
-- 3. VIEW: vw_patient_visit_summary
-- One row per visit — medications collapsed
-- =============================================================
SELECT patient_name, appointment_date, visit_reason,
       appointment_status, medications
FROM   vw_patient_visit_summary
ORDER  BY patient_id, appointment_date;


-- =============================================================
-- 4. VIEW: vw_uninsured_patients
-- =============================================================
SELECT patient_name, insurance_issue, provider_name,
       policy_expiry_date, insurance_status
FROM   vw_uninsured_patients
ORDER  BY insurance_issue;

SELECT insurance_issue, COUNT(*) AS total
FROM   vw_uninsured_patients
GROUP  BY insurance_issue;


-- =============================================================
-- 5. BILLING — verify insurance discount applied correctly
-- =============================================================
SELECT b.bill_id,
       p.first_name || ' ' || p.last_name     AS patient_name,
       i.coverage_percentage                   AS coverage_pct,
       b.total_amount,
       b.insurance_coverage_amt,
       b.net_amount,
       b.status
FROM   bill      b
JOIN   patient   p  ON p.patient_id   = b.patient_id
LEFT JOIN insurance i ON i.insurance_id = p.insurance_id
ORDER  BY b.bill_id;

-- Payments against bills
SELECT py.payment_id, py.amount_paid, py.payment_method,
       b.net_amount, b.status AS bill_status
FROM   payment py
JOIN   bill    b  ON b.bill_id = py.bill_id
ORDER  BY py.payment_id;


-- =============================================================
-- 6. ADD MORE DATA — register a new patient via procedure
-- =============================================================
DECLARE
    v_id NUMBER;
BEGIN
    pkg_patient_mgmt.sp_register_patient(
        p_first_name   => 'Alex',
        p_last_name    => 'Turner',
        p_dob          => DATE '1992-08-21',
        p_gender       => 'M',
        p_phone        => '999-NEW-0001',
        p_email        => 'alex.turner@hms.com',
        p_blood_type   => 'B+',
        p_city         => 'Boston',
        p_state        => 'MA',
        p_insurance_id => 2,
        p_patient_id   => v_id
    );
    DBMS_OUTPUT.PUT_LINE('New patient registered. ID = ' || v_id);
END;
/

-- Verify new patient
SELECT patient_id, first_name, last_name, blood_type, insurance_id
FROM   patient
WHERE  phone = '999-NEW-0001';
