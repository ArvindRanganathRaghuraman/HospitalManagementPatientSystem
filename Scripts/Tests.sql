-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM — Patient Module
-- Test Script
-- Run after: DDL.sql → Triggers.sql → Procedures.sql
--            → Data_Loading.sql → Views.sql
-- =============================================================

SET SERVEROUTPUT ON;

-- Remove any leftover records from prior test runs
BEGIN
    DELETE FROM payment  WHERE bill_id   IN (SELECT bill_id   FROM bill    WHERE patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%'));
    DELETE FROM bill     WHERE patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%');
    DELETE FROM prescription_item WHERE prescription_id IN (SELECT prescription_id FROM prescription WHERE patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%'));
    DELETE FROM prescription WHERE patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%');
    DELETE FROM admission    WHERE patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%');
    DELETE FROM appointment  WHERE patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%');
    DELETE FROM patient  WHERE phone LIKE '9990000%';
    COMMIT;
END;
/


-- =============================================================
-- 1. ROW COUNT VERIFICATION
-- Expected: 15 insurance, 200 patients (25 minors, 175 insured,
--           25 uninsured), 10 appointments, 6 admissions,
--           5 prescriptions, 10 prescription_items, 5 bills, 3 payments
-- =============================================================
SELECT 'insurance'           AS entity,  COUNT(*) AS total FROM insurance
UNION ALL SELECT 'patient',              COUNT(*) FROM patient
UNION ALL SELECT 'patient - minors',     COUNT(*) FROM patient WHERE is_minor = 'Y'
UNION ALL SELECT 'patient - insured',    COUNT(*) FROM patient WHERE insurance_id IS NOT NULL
UNION ALL SELECT 'patient - uninsured',  COUNT(*) FROM patient WHERE insurance_id IS NULL
UNION ALL SELECT 'appointment',          COUNT(*) FROM appointment
UNION ALL SELECT 'admission',            COUNT(*) FROM admission
UNION ALL SELECT 'prescription',         COUNT(*) FROM prescription
UNION ALL SELECT 'prescription_item',    COUNT(*) FROM prescription_item
UNION ALL SELECT 'bill',                 COUNT(*) FROM bill
UNION ALL SELECT 'payment',             COUNT(*) FROM payment
ORDER BY 1;


-- =============================================================
-- 2. TRIGGER: TRG_PATIENT_BI
-- Verifies: auto PK assignment, auto is_minor from DOB,
--           modified_date stamped on insert
-- =============================================================
DECLARE
    v_id     NUMBER;
    v_minor  CHAR(1);
    v_mdate  DATE;
BEGIN
    -- Insert an adult directly (trigger should set is_minor = 'N')
    INSERT INTO patient (first_name, last_name, date_of_birth, gender, phone)
    VALUES ('Trigger', 'TestAdult', DATE '1990-06-15', 'M', '9990000001')
    RETURNING patient_id, is_minor, modified_date INTO v_id, v_minor, v_mdate;

    IF v_id IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_PATIENT_BI] Auto PK assigned: ' || v_id);
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_PATIENT_BI] PK not assigned');
    END IF;

    IF v_minor = 'N' THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_PATIENT_BI] is_minor = N for adult DOB 1990');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_PATIENT_BI] Expected is_minor=N, got: ' || v_minor);
    END IF;

    IF v_mdate IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_PATIENT_BI] modified_date stamped: ' || TO_CHAR(v_mdate, 'YYYY-MM-DD'));
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_PATIENT_BI] modified_date is NULL');
    END IF;

    -- Insert a minor directly (trigger should set is_minor = 'Y')
    INSERT INTO patient (
        first_name, last_name, date_of_birth, gender, phone,
        guardian_first_name, guardian_last_name, guardian_relationship, guardian_phone
    )
    VALUES ('Trigger', 'TestMinor', DATE '2015-01-01', 'F', '9990000002',
            'Guardian', 'TestGuardian', 'PARENT', '9990000003')
    RETURNING is_minor INTO v_minor;

    IF v_minor = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_PATIENT_BI] is_minor = Y for DOB 2015');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_PATIENT_BI] Expected is_minor=Y, got: ' || v_minor);
    END IF;

    ROLLBACK;
END;
/


-- =============================================================
-- 3. TRIGGER: TRG_BILL_BI
-- Verifies: insurance coverage auto-calculated from patient's
--           active policy, net_amount = total - coverage - discount
-- Patient 1  (Emma Smith)  — insurance_id=1, BlueCross 80%
-- Patient 176 (Aaron Pierce) — uninsured, coverage should = 0
-- =============================================================
DECLARE
    v_bill_id  NUMBER;
    v_cov_amt  NUMBER;
    v_net      NUMBER;
    v_appt_1   NUMBER;
    v_appt_176 NUMBER;
BEGIN
    SELECT appointment_id INTO v_appt_1
    FROM appointment WHERE patient_id = 1 AND status = 'COMPLETED' AND ROWNUM = 1;

    SELECT appointment_id INTO v_appt_176
    FROM appointment WHERE patient_id = 176 AND status = 'COMPLETED' AND ROWNUM = 1;

    -- Insured patient: total=500, 80% BlueCross → coverage=400, net=100
    INSERT INTO bill (bill_id, total_amount, discount_amount, net_amount, status, patient_id, appointment_id)
    VALUES (bill_seq.NEXTVAL, 500, 0, 0, 'PENDING', 1, v_appt_1)
    RETURNING bill_id, insurance_coverage_amt, net_amount INTO v_bill_id, v_cov_amt, v_net;

    IF v_cov_amt = 400 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] Insured 80%: coverage_amt = ' || v_cov_amt);
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Expected coverage=400, got: ' || v_cov_amt);
    END IF;

    IF v_net = 100 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] net_amount = total - coverage = ' || v_net);
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Expected net=100, got: ' || v_net);
    END IF;

    -- Uninsured patient: total=300, coverage should = 0, net = 300
    INSERT INTO bill (bill_id, total_amount, discount_amount, net_amount, status, patient_id, appointment_id)
    VALUES (bill_seq.NEXTVAL, 300, 0, 0, 'PENDING', 176, v_appt_176)
    RETURNING bill_id, insurance_coverage_amt, net_amount INTO v_bill_id, v_cov_amt, v_net;

    IF v_cov_amt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] Uninsured: coverage_amt = 0');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Expected coverage=0, got: ' || v_cov_amt);
    END IF;

    IF v_net = 300 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] Uninsured net_amount = total = ' || v_net);
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Expected net=300, got: ' || v_net);
    END IF;

    ROLLBACK;
END;
/


-- =============================================================
-- 4. VIEW: V_PATIENT_MEDICAL_HISTORY
-- One row per medication per visit — includes guardian info
-- for minors, was_admitted flag, insurance details
-- =============================================================

-- 4a. Minor patient with guardian info (Emma Smith)
SELECT patient_name, age, is_minor,
       guardian_name, guardian_relationship,
       insurance_provider, coverage_percentage,
       appointment_date, visit_reason, appointment_status,
       was_admitted, medication_name, dosage, frequency
FROM   v_patient_medical_history
WHERE  patient_id = 1
ORDER  BY appointment_date, medication_name;

-- 4b. Admitted patient — should show admission details
SELECT patient_name, appointment_date, visit_reason,
       was_admitted, admission_date, discharge_date,
       diagnosis, admission_type, admission_status,
       medication_name
FROM   v_patient_medical_history
WHERE  patient_id = 2
ORDER  BY appointment_date;

-- 4c. Uninsured adult (patient 176, Aaron Pierce)
SELECT patient_name, insurance_provider, coverage_percentage,
       appointment_date, visit_reason, was_admitted,
       medication_name, dosage
FROM   v_patient_medical_history
WHERE  patient_id = 176
ORDER  BY appointment_date;


-- =============================================================
-- 5. VIEW: VW_PATIENT_VISIT_SUMMARY
-- One row per visit — all medications collapsed via LISTAGG
-- =============================================================
SELECT patient_name, appointment_date, visit_reason,
       appointment_status, medications
FROM   vw_patient_visit_summary
WHERE  patient_id IN (1, 2, 26, 176)
ORDER  BY patient_id, appointment_date;


-- =============================================================
-- 6. VIEW: VW_UNINSURED_PATIENTS
-- Should include: patients with NULL insurance, EXPIRED policy,
--                INACTIVE policy, or lapsed policy date
-- =============================================================
-- Summary by issue type
SELECT insurance_issue,
       COUNT(*) AS total_patients,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM   vw_uninsured_patients
GROUP  BY insurance_issue
ORDER  BY total_patients DESC;

-- Detail: first 10 records
SELECT patient_name, patient_status, insurance_issue,
       provider_name, policy_expiry_date, insurance_status
FROM   vw_uninsured_patients
WHERE  ROWNUM <= 10
ORDER  BY insurance_issue, patient_name;


-- =============================================================
-- 7. VIEW: VW_PATIENT_PROFILE
-- Shows coverage_flag: INSURED / UNINSURED / INVALID INSURANCE
-- =============================================================
-- One insured, one uninsured, one with expired insurance
SELECT patient_id, full_name, age, blood_type,
       insurance_provider, coverage_percentage,
       insurance_status, coverage_flag
FROM   vw_patient_profile
WHERE  patient_id IN (
    1,    -- insured minor
    176,  -- uninsured adult
    (SELECT MIN(p.patient_id) FROM patient p JOIN insurance i ON i.insurance_id = p.insurance_id WHERE i.status = 'EXPIRED')
)
ORDER  BY patient_id;


-- =============================================================
-- 8. VIEW: VW_MINOR_PATIENTS
-- All minors must have guardian info (business rule compliance)
-- =============================================================
-- Compliance check: should return 0 rows (no minor missing guardian)
SELECT patient_name, age, guardian_name, guardian_relationship
FROM   vw_minor_patients
WHERE  guardian_name IS NULL OR guardian_name = ' ';

-- Full minor list with insurance status
SELECT patient_name, age, gender,
       guardian_name, guardian_relationship,
       insurance_provider, coverage_flag
FROM   vw_minor_patients
ORDER  BY age DESC;


-- =============================================================
-- 9. PROCEDURE: SP_REGISTER_PATIENT
-- 9a. Register a new adult (positive)
-- 9b. Register a minor with guardian info (positive)
-- =============================================================
DECLARE
    v_id NUMBER;
BEGIN
    -- 9a: Adult patient
    pkg_patient_mgmt.sp_register_patient(
        p_first_name   => 'Alex',
        p_last_name    => 'Turner',
        p_dob          => DATE '1992-08-21',
        p_gender       => 'M',
        p_phone        => '9990000005',
        p_email        => 'alex.turner@test.com',
        p_blood_type   => 'B+',
        p_city         => 'Boston',
        p_state        => 'MA',
        p_insurance_id => 2,
        p_patient_id   => v_id
    );
    DBMS_OUTPUT.PUT_LINE('PASS [SP_REGISTER_PATIENT] Adult registered. ID = ' || v_id);

    -- 9b: Minor with guardian
    pkg_patient_mgmt.sp_register_patient(
        p_first_name            => 'Taylor',
        p_last_name             => 'Reed',
        p_dob                   => DATE '2012-04-10',
        p_gender                => 'F',
        p_phone                 => '9990000006',
        p_blood_type            => 'A-',
        p_city                  => 'Cambridge',
        p_state                 => 'MA',
        p_insurance_id          => 3,
        p_guardian_first_name   => 'Jordan',
        p_guardian_last_name    => 'Reed',
        p_guardian_relationship => 'PARENT',
        p_guardian_phone        => '9990000004',
        p_patient_id            => v_id
    );
    DBMS_OUTPUT.PUT_LINE('PASS [SP_REGISTER_PATIENT] Minor with guardian registered. ID = ' || v_id);
END;
/

-- Verify both registrations
SELECT patient_id, first_name || ' ' || last_name AS name,
       is_minor, insurance_id, guardian_first_name, guardian_relationship
FROM   patient
WHERE  phone IN ('9990000005', '9990000006')
ORDER  BY patient_id;


-- =============================================================
-- 10. PROCEDURE: SP_UPDATE_PATIENT
-- Update phone, city, blood_type on the adult registered above
-- =============================================================
DECLARE
    v_id NUMBER;
BEGIN
    SELECT patient_id INTO v_id FROM patient WHERE phone = '9990000005';

    pkg_patient_mgmt.sp_update_patient(
        p_patient_id => v_id,
        p_city       => 'Somerville',
        p_blood_type => 'O+'
    );
    DBMS_OUTPUT.PUT_LINE('PASS [SP_UPDATE_PATIENT] Patient ID ' || v_id || ' updated.');
END;
/

-- Verify updated fields
SELECT patient_id, first_name, city, blood_type, modified_date
FROM   patient
WHERE  phone = '9990000005';


-- =============================================================
-- 11. PROCEDURE: SP_LINK_INSURANCE
-- Link a new active insurance policy to the test adult
-- =============================================================
DECLARE
    v_id NUMBER;
BEGIN
    SELECT patient_id INTO v_id FROM patient WHERE phone = '9990000005';

    pkg_patient_mgmt.sp_link_insurance(
        p_patient_id   => v_id,
        p_insurance_id => 5   -- Humana Insurance, ACTIVE, 75%
    );
    DBMS_OUTPUT.PUT_LINE('PASS [SP_LINK_INSURANCE] Insurance linked.');
END;
/

-- Verify new insurance
SELECT p.patient_id, p.first_name,
       i.provider_name, i.coverage_percentage, i.status AS ins_status
FROM   patient p JOIN insurance i ON i.insurance_id = p.insurance_id
WHERE  p.phone = '9990000005';


-- =============================================================
-- 12. PROCEDURE: SP_DEACTIVATE_PATIENT
-- 12a. Deactivate the test adult (positive)
-- 12b. Deactivate again — should raise ORA-20041 (negative)
-- =============================================================
DECLARE
    v_id NUMBER;
BEGIN
    SELECT patient_id INTO v_id FROM patient WHERE phone = '9990000005';

    -- 12a: First deactivation — should succeed
    pkg_patient_mgmt.sp_deactivate_patient(
        p_patient_id => v_id,
        p_reason     => 'Test deactivation'
    );
    DBMS_OUTPUT.PUT_LINE('PASS [SP_DEACTIVATE_PATIENT] Patient deactivated.');

    -- 12b: Second deactivation — should raise ORA-20041
    BEGIN
        pkg_patient_mgmt.sp_deactivate_patient(p_patient_id => v_id);
        DBMS_OUTPUT.PUT_LINE('FAIL [SP_DEACTIVATE_PATIENT] Should have raised error for already INACTIVE');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20041 THEN
                DBMS_OUTPUT.PUT_LINE('PASS [SP_DEACTIVATE_PATIENT] Correctly rejected already-INACTIVE patient');
            ELSE
                DBMS_OUTPUT.PUT_LINE('FAIL [SP_DEACTIVATE_PATIENT] Wrong error: ' || SQLERRM);
            END IF;
    END;
END;
/

-- Verify status is INACTIVE
SELECT patient_id, first_name, status FROM patient WHERE phone = '9990000005';


-- =============================================================
-- 13. FUNCTION: FN_IS_MINOR
-- Patient 1  (Emma Smith, born 2010) → should return 'Y'
-- Patient 26 (insured adult, born ~1970s) → should return 'N'
-- =============================================================
DECLARE
    v_result CHAR(1);
BEGIN
    v_result := pkg_patient_mgmt.fn_is_minor(1);
    IF v_result = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('PASS [FN_IS_MINOR] Patient 1 (minor) = Y');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [FN_IS_MINOR] Expected Y, got: ' || v_result);
    END IF;

    v_result := pkg_patient_mgmt.fn_is_minor(26);
    IF v_result = 'N' THEN
        DBMS_OUTPUT.PUT_LINE('PASS [FN_IS_MINOR] Patient 26 (adult) = N');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [FN_IS_MINOR] Expected N, got: ' || v_result);
    END IF;
END;
/


-- =============================================================
-- 14. FUNCTION: FN_GET_COVERAGE_PCT
-- Patient 1  (BlueCross 80%)  → should return 80
-- Patient 176 (uninsured)     → should return 0
-- =============================================================
DECLARE
    v_pct NUMBER;
BEGIN
    v_pct := pkg_patient_mgmt.fn_get_coverage_pct(1);
    IF v_pct = 80 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [FN_GET_COVERAGE_PCT] Patient 1 = 80%');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [FN_GET_COVERAGE_PCT] Expected 80, got: ' || v_pct);
    END IF;

    v_pct := pkg_patient_mgmt.fn_get_coverage_pct(176);
    IF v_pct = 0 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [FN_GET_COVERAGE_PCT] Patient 176 (uninsured) = 0');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [FN_GET_COVERAGE_PCT] Expected 0, got: ' || v_pct);
    END IF;
END;
/


-- =============================================================
-- 15. NEGATIVE TESTS — all expected to raise errors
-- =============================================================
DECLARE
    v_id NUMBER;

    PROCEDURE expect_error (p_label VARCHAR2, p_code NUMBER) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('FAIL [' || p_label || '] No error raised — expected ORA-' || p_code);
    END;

BEGIN
    -- 15a: Duplicate phone
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'Dup', p_last_name => 'Phone',
            p_dob        => DATE '1985-01-01', p_gender => 'M',
            p_phone      => '617-200-0001',  -- already belongs to Emma Smith
            p_patient_id => v_id
        );
        expect_error('DUPLICATE PHONE', 20010);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20010 THEN DBMS_OUTPUT.PUT_LINE('PASS [DUPLICATE PHONE] ORA-20010 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [DUPLICATE PHONE] Wrong error: ' || SQLERRM); END IF;
    END;

    -- 15b: Minor without guardian
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'NoGuardian', p_last_name => 'Minor',
            p_dob        => DATE '2015-05-05', p_gender => 'F',
            p_phone      => '9990000011',
            p_patient_id => v_id
        );
        expect_error('MINOR NO GUARDIAN', 20011);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20011 THEN DBMS_OUTPUT.PUT_LINE('PASS [MINOR NO GUARDIAN] ORA-20011 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [MINOR NO GUARDIAN] Wrong error: ' || SQLERRM); END IF;
    END;

    -- 15c: Non-existent insurance ID
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name   => 'Bad', p_last_name => 'Insurance',
            p_dob          => DATE '1980-01-01', p_gender => 'M',
            p_phone        => '9990000012',
            p_insurance_id => 9999,
            p_patient_id   => v_id
        );
        expect_error('INSURANCE NOT FOUND', 20012);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20012 THEN DBMS_OUTPUT.PUT_LINE('PASS [INSURANCE NOT FOUND] ORA-20012 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [INSURANCE NOT FOUND] Wrong error: ' || SQLERRM); END IF;
    END;

    -- 15d: INACTIVE insurance (insurance_id=15, COBRA INACTIVE)
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name   => 'Inactive', p_last_name => 'Ins',
            p_dob          => DATE '1975-03-10', p_gender => 'M',
            p_phone        => '9990000013',
            p_insurance_id => 15,
            p_patient_id   => v_id
        );
        expect_error('INACTIVE INSURANCE', 20013);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20013 THEN DBMS_OUTPUT.PUT_LINE('PASS [INACTIVE INSURANCE] ORA-20013 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [INACTIVE INSURANCE] Wrong error: ' || SQLERRM); END IF;
    END;

    -- 15e: EXPIRED insurance (insurance_id=13, Centene EXPIRED)
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name   => 'Expired', p_last_name => 'Ins',
            p_dob          => DATE '1988-07-20', p_gender => 'F',
            p_phone        => '9990000014',
            p_insurance_id => 13,
            p_patient_id   => v_id
        );
        expect_error('EXPIRED INSURANCE', 20014);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20014 THEN DBMS_OUTPUT.PUT_LINE('PASS [EXPIRED INSURANCE] ORA-20014 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [EXPIRED INSURANCE] Wrong error: ' || SQLERRM); END IF;
    END;

    -- 15f: Future date of birth
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'Future', p_last_name => 'DOB',
            p_dob        => SYSDATE + 30, p_gender => 'M',
            p_phone      => '9990000015',
            p_patient_id => v_id
        );
        expect_error('FUTURE DOB', 20009);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20009 THEN DBMS_OUTPUT.PUT_LINE('PASS [FUTURE DOB] ORA-20009 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [FUTURE DOB] Wrong error: ' || SQLERRM); END IF;
    END;

    -- 15g: sp_link_insurance with expired policy
    BEGIN
        pkg_patient_mgmt.sp_link_insurance(p_patient_id => 176, p_insurance_id => 13);
        expect_error('LINK EXPIRED INSURANCE', 20033);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20033 THEN DBMS_OUTPUT.PUT_LINE('PASS [LINK EXPIRED INSURANCE] ORA-20033 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [LINK EXPIRED INSURANCE] Wrong error: ' || SQLERRM); END IF;
    END;

    -- 15h: sp_update_patient with a non-existent patient ID
    BEGIN
        pkg_patient_mgmt.sp_update_patient(p_patient_id => 99999, p_city => 'Nowhere');
        expect_error('UPDATE PATIENT NOT FOUND', 20020);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20020 THEN DBMS_OUTPUT.PUT_LINE('PASS [UPDATE NOT FOUND] ORA-20020 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [UPDATE NOT FOUND] Wrong error: ' || SQLERRM); END IF;
    END;
END;
/


-- =============================================================
-- 16. BILLING SUMMARY — insurance discount applied correctly
-- =============================================================
SELECT b.bill_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       NVL(i.provider_name, 'Uninsured')  AS insurer,
       NVL(i.coverage_percentage, 0)      AS coverage_pct,
       b.total_amount,
       b.insurance_coverage_amt,
       b.discount_amount,
       b.net_amount,
       b.status
FROM   bill      b
JOIN   patient   p  ON p.patient_id   = b.patient_id
LEFT JOIN insurance i ON i.insurance_id = p.insurance_id
ORDER  BY b.bill_id;

-- Payments vs bills
SELECT py.payment_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       py.amount_paid, py.payment_method,
       b.net_amount, b.status AS bill_status
FROM   payment py
JOIN   bill    b  ON b.bill_id    = py.bill_id
JOIN   patient p  ON p.patient_id = b.patient_id
ORDER  BY py.payment_id;


-- =============================================================
-- 17. ADMISSION SUMMARY — outpatient vs inpatient
-- =============================================================
SELECT p.first_name || ' ' || p.last_name AS patient_name,
       adm.admission_type, adm.status,
       adm.admission_date, adm.discharge_date,
       adm.diagnosis,
       CASE WHEN adm.appointment_id IS NULL THEN 'Emergency (no appt)'
            ELSE 'Planned (appt #' || adm.appointment_id || ')'
       END AS admission_source
FROM   admission adm
JOIN   patient   p ON p.patient_id = adm.patient_id
ORDER  BY adm.admission_date;


-- =============================================================
-- 18. FINAL STATE — row counts after all tests
-- =============================================================
SELECT 'patient'          AS entity, COUNT(*) AS total FROM patient
UNION ALL SELECT 'appointment',      COUNT(*) FROM appointment
UNION ALL SELECT 'admission',        COUNT(*) FROM admission
UNION ALL SELECT 'prescription',     COUNT(*) FROM prescription
UNION ALL SELECT 'bill',             COUNT(*) FROM bill
UNION ALL SELECT 'payment',         COUNT(*) FROM payment
ORDER BY 1;
