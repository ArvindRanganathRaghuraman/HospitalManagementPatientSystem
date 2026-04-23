-- ============================================================
-- TEST 7: HMS_OPERATOR_ROLE RESTRICTIONS
-- Shows what an operator CANNOT do (direct table access blocked)
-- and what they CAN do (package + views only)
--
-- Scope: pkg_patient_mgmt covers patient management only.
-- Operators can register/update/deactivate patients and link
-- insurance through the package. Appointment, admission, and
-- billing operations are outside operator scope — those require
-- HMS_ADMIN_USER (direct DML) or additional packages if needed.
--
-- Connect as: HMS_OP_USER  (password: OperatorUser#2026)
-- ============================================================

SET SERVEROUTPUT ON;
ALTER SESSION SET CURRENT_SCHEMA = hms_owner;


-- ── WHAT FAILS — Direct table access is blocked ──────────────

-- SELECT on base table → Error
SELECT patient_id, first_name, last_name
FROM   patient WHERE ROWNUM <= 5;


-- INSERT on base table → Error
INSERT INTO patient (
    patient_id, first_name, last_name, date_of_birth,
    gender, phone, city, state, is_minor
) VALUES (
    patient_seq.NEXTVAL, 'Op', 'DirectInsert',
    DATE '1990-01-01', 'M', '6177000001', 'Boston', 'MA', 'N'
);


-- ── WHAT WORKS — Package execution is allowed ────────────────

-- Register a patient through the procedure
DECLARE
    v_id NUMBER;
BEGIN
    pkg_patient_mgmt.sp_register_patient(
        p_first_name => 'Operator',
        p_last_name  => 'UserTest',
        p_dob        => DATE '1995-03-10',
        p_gender     => 'M',
        p_phone      => '6177000005',
        p_city       => 'Boston',
        p_state      => 'MA',
        p_patient_id => v_id
    );
    DBMS_OUTPUT.PUT_LINE('PASS: Procedure executed. Patient ID = ' || v_id);
END;
/

-- Update patient through procedure
DECLARE
    v_id NUMBER;
BEGIN
    SELECT patient_id INTO v_id
    FROM hms_owner.vw_patient_profile 
    WHERE phone = '6177000005';

    pkg_patient_mgmt.sp_update_patient(
        p_patient_id => v_id,
        p_city       => 'Cambridge'
    );
    DBMS_OUTPUT.PUT_LINE('PASS: Update procedure executed for patient ' || v_id);
END;
/


-- ── WHAT WORKS — Views are accessible ────────────────────────

SELECT patient_id, full_name, age, coverage_flag
FROM   vw_patient_profile WHERE ROWNUM <= 5;

SELECT patient_name, insurance_issue
FROM   vw_uninsured_patients WHERE ROWNUM <= 5;

SELECT patient_name, age, guardian_name, guardian_relationship
FROM   vw_minor_patients WHERE ROWNUM <= 5;

SELECT patient_name, appointment_date, visit_reason, medications
FROM   vw_patient_visit_summary
WHERE  medications IS NOT NULL AND ROWNUM <= 5;


-- ── CLEANUP — must be done as HMS_OWNER or HMS_ADMIN_USER ────
-- Operator cannot DELETE directly, so switch connection to clean up:
--   conn hms_owner/HmsOwner
--   DELETE FROM patient WHERE phone = '6177000002';
--   COMMIT;
