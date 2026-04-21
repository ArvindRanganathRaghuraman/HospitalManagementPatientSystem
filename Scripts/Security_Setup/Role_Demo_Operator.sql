-- =============================================================
-- HMS_OPERATOR_ROLE DEMO
-- Connect as: hms_op_user / OperatorUser#2026
-- HMS_OPERATOR_ROLE: NO direct table access
--                   EXECUTE package + SELECT views only
-- =============================================================

SET SERVEROUTPUT ON;
ALTER SESSION SET CURRENT_SCHEMA = hms_owner;


-- ── 1. SELECT directly from base table — SHOULD FAIL ────────
-- Expected: ORA-01031 insufficient privileges
SELECT patient_id, first_name, last_name
FROM   patient
WHERE  ROWNUM <= 5;


-- ── 2. INSERT directly into table — SHOULD FAIL ─────────────
-- Expected: ORA-01031 insufficient privileges
INSERT INTO patient (
    patient_id, first_name, last_name, date_of_birth,
    gender, phone, city, state
)
VALUES (
    patient_seq.NEXTVAL, 'Op', 'DirectInsert',
    DATE '1990-01-01', 'M', '6177000001', 'Boston', 'MA'
);


-- ── 3. EXECUTE package procedure — SHOULD SUCCEED ───────────
-- Operator can register patients only through the procedure
DECLARE
    v_id NUMBER;
BEGIN
    pkg_patient_mgmt.sp_register_patient(
        p_first_name => 'Operator',
        p_last_name  => 'ProcInsert',
        p_dob        => DATE '1995-03-10',
        p_gender     => 'M',
        p_phone      => '6177000002',
        p_city       => 'Boston',
        p_state      => 'MA',
        p_patient_id => v_id
    );
    DBMS_OUTPUT.PUT_LINE('PASS: Procedure succeeded. Patient ID = ' || v_id);
END;
/


-- ── 4. SELECT from views — SHOULD SUCCEED ───────────────────
-- Operator can read data only through views, not base tables
SELECT patient_id, full_name, coverage_flag
FROM   vw_patient_profile
WHERE  ROWNUM <= 5;

SELECT patient_name, insurance_issue
FROM   vw_uninsured_patients
WHERE  ROWNUM <= 5;

SELECT patient_name, guardian_name, guardian_relationship
FROM   vw_minor_patients
WHERE  ROWNUM <= 5;
