-- =============================================================
-- HMS_ADMIN_ROLE DEMO
-- Connect as: hms_admin_user / AdminUser#2026
-- HMS_ADMIN_ROLE: full SELECT/INSERT/UPDATE/DELETE on all tables
--                + EXECUTE package + SELECT views
-- =============================================================

SET SERVEROUTPUT ON;
ALTER SESSION SET CURRENT_SCHEMA = hms_owner;


-- ── 1. SELECT directly from base table ──────────────────────
SELECT patient_id, first_name, last_name, status
FROM   patient
WHERE  ROWNUM <= 5;


-- ── 2. INSERT directly into a table ─────────────────────────
INSERT INTO patient (
    patient_id, first_name, last_name, date_of_birth,
    gender, phone, city, state
)
VALUES (
    patient_seq.NEXTVAL, 'Admin', 'DirectInsert',
    DATE '1990-01-01', 'M', '6176000001', 'Boston', 'MA'
);
COMMIT;

SELECT patient_id, first_name, last_name, city
FROM   patient
WHERE  phone = '6176000001';


-- ── 3. UPDATE directly ──────────────────────────────────────
UPDATE patient
SET    city = 'Cambridge'
WHERE  phone = '6176000001';
COMMIT;

SELECT patient_id, first_name, city
FROM   patient
WHERE  phone = '6176000001';


-- ── 4. DELETE directly ──────────────────────────────────────
DELETE FROM patient
WHERE  phone = '6176000001';
COMMIT;

SELECT COUNT(*) AS should_be_zero
FROM   patient
WHERE  phone = '6176000001';


-- ── 5. EXECUTE package procedure ────────────────────────────
DECLARE
    v_id NUMBER;
BEGIN
    pkg_patient_mgmt.sp_register_patient(
        p_first_name => 'Admin',
        p_last_name  => 'ProcInsert',
        p_dob        => DATE '1988-06-15',
        p_gender     => 'F',
        p_phone      => '6176000002',
        p_city       => 'Boston',
        p_state      => 'MA',
        p_patient_id => v_id
    );
    DBMS_OUTPUT.PUT_LINE('PASS: Procedure succeeded. Patient ID = ' || v_id);

    DELETE FROM patient WHERE patient_id = v_id;
    COMMIT;
END;
/


-- ── 6. SELECT from views ─────────────────────────────────────
SELECT patient_id, full_name, coverage_flag
FROM   vw_patient_profile
WHERE  ROWNUM <= 5;

SELECT patient_name, insurance_issue
FROM   vw_uninsured_patients
WHERE  ROWNUM <= 5;

SELECT patient_name, guardian_name, guardian_relationship
FROM   vw_minor_patients
WHERE  ROWNUM <= 5;
