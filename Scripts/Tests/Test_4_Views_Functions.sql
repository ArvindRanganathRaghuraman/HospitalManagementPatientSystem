-- ============================================================
-- TEST 4: VIEWS AND FUNCTIONS
-- All 5 views + FN_IS_MINOR + FN_GET_COVERAGE_PCT
-- Connect as: HMS_ADMIN_USER  (password: AdminUser#2026)
-- ============================================================

SET SERVEROUTPUT ON;
ALTER SESSION SET CURRENT_SCHEMA = hms_owner;


-- ============================================================
-- VIEW 1: V_PATIENT_MEDICAL_HISTORY
-- One row per medication per visit
-- Shows: guardian info for minors, insurance, admission details
-- ============================================================

-- Minor patient (Emma Smith, patient 1) — guardian + insurance + medications
SELECT patient_name, age, is_minor,
       guardian_name, guardian_relationship,
       insurance_provider, coverage_percentage,
       appointment_date, visit_reason, appointment_status,
       was_admitted, medication_name, dosage, frequency
FROM   v_patient_medical_history
WHERE  patient_id = 1
ORDER  BY appointment_date, medication_name;

-- Patient with admission (Liam Johnson, patient 2)
SELECT patient_name, appointment_date, visit_reason,
       was_admitted, admission_date, discharge_date,
       diagnosis, admission_type, medication_name
FROM   v_patient_medical_history
WHERE  patient_id = 2
ORDER  BY appointment_date;

-- Uninsured adult (Aaron Pierce, patient 176)
SELECT patient_name, insurance_provider, coverage_percentage,
       appointment_date, visit_reason, was_admitted, medication_name
FROM   v_patient_medical_history
WHERE  patient_id = 176
ORDER  BY appointment_date;


-- ============================================================
-- VIEW 2: VW_PATIENT_VISIT_SUMMARY
-- One row per visit — all medications collapsed into one column
-- ============================================================

SELECT patient_name, appointment_date, visit_reason,
       appointment_status, medications
FROM   vw_patient_visit_summary
WHERE  patient_id IN (1, 2, 26, 176)
ORDER  BY patient_id, appointment_date;


-- ============================================================
-- VIEW 3: VW_UNINSURED_PATIENTS
-- Patients with no insurance, expired, or inactive policy
-- ============================================================

-- Summary count by issue type
SELECT insurance_issue,
       COUNT(*) AS total_patients
FROM   vw_uninsured_patients
GROUP  BY insurance_issue
ORDER  BY total_patients DESC;

-- Detailed list
SELECT patient_name, insurance_issue,
       provider_name, policy_expiry_date, insurance_status
FROM   vw_uninsured_patients
WHERE  ROWNUM <= 10
ORDER  BY insurance_issue, patient_name;


-- ============================================================
-- VIEW 4: VW_PATIENT_PROFILE
-- coverage_flag: INSURED / UNINSURED / INVALID INSURANCE
-- ============================================================

SELECT patient_id, full_name, age, blood_type,
       insurance_provider, coverage_percentage,
       insurance_status, coverage_flag
FROM   vw_patient_profile
WHERE  patient_id IN (
    1,    -- insured minor (BlueCross 80%)
    176,  -- uninsured adult
    (SELECT MIN(p.patient_id)
     FROM   patient p
     JOIN   insurance i ON i.insurance_id = p.insurance_id
     WHERE  i.status = 'EXPIRED')
)
ORDER  BY patient_id;


-- ============================================================
-- VIEW 5: VW_MINOR_PATIENTS
-- All minors with guardian info
-- Business rule check: no minor should be missing a guardian
-- ============================================================

-- Compliance check — must return 0 rows
SELECT patient_name, age, guardian_name
FROM   vw_minor_patients
WHERE  guardian_name IS NULL OR TRIM(guardian_name) = ' ';

-- Full list
SELECT patient_name, age, gender,
       guardian_name, guardian_relationship,
       insurance_provider, coverage_flag
FROM   vw_minor_patients
ORDER  BY age DESC;


-- ============================================================
-- FUNCTION 1: FN_IS_MINOR
-- Returns Y if patient is under 18, N if adult
-- ============================================================

DECLARE
    v_result CHAR(1);
BEGIN
    -- Minor patient (Emma Smith, born 2010)
    v_result := pkg_patient_mgmt.fn_is_minor(1);
    IF v_result = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('PASS [FN_IS_MINOR] Patient 1 = Y (minor)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [FN_IS_MINOR] Expected Y, got: ' || v_result);
    END IF;

    -- Adult patient (patient 26)
    v_result := pkg_patient_mgmt.fn_is_minor(26);
    IF v_result = 'N' THEN
        DBMS_OUTPUT.PUT_LINE('PASS [FN_IS_MINOR] Patient 26 = N (adult)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [FN_IS_MINOR] Expected N, got: ' || v_result);
    END IF;
END;
/


-- ============================================================
-- FUNCTION 2: FN_GET_COVERAGE_PCT
-- Returns insurance coverage % for a patient (0 if uninsured)
-- ============================================================

DECLARE
    v_pct NUMBER;
BEGIN
    -- Patient 1: BlueCross 80%
    v_pct := pkg_patient_mgmt.fn_get_coverage_pct(1);
    IF v_pct = 80 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [FN_GET_COVERAGE_PCT] Patient 1 = 80%');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [FN_GET_COVERAGE_PCT] Expected 80, got: ' || v_pct);
    END IF;

    -- Patient 176: uninsured → 0%
    v_pct := pkg_patient_mgmt.fn_get_coverage_pct(176);
    IF v_pct = 0 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [FN_GET_COVERAGE_PCT] Patient 176 = 0% (uninsured)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [FN_GET_COVERAGE_PCT] Expected 0, got: ' || v_pct);
    END IF;
END;
/

-- Side-by-side: stored column vs function output (must match on every row)
SELECT p.patient_id,
       p.first_name || ' ' || p.last_name                    AS name,
       p.is_minor                                             AS db_is_minor,
       pkg_patient_mgmt.fn_is_minor(p.patient_id)            AS fn_is_minor,
       NVL(i.coverage_percentage, 0)                         AS db_coverage_pct,
       pkg_patient_mgmt.fn_get_coverage_pct(p.patient_id)    AS fn_coverage_pct
FROM   patient p
LEFT JOIN insurance i ON i.insurance_id = p.insurance_id
WHERE  p.patient_id IN (1, 26, 176)
ORDER  BY p.patient_id;
