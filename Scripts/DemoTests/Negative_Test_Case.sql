-- =====================================================
-- HOSPITAL MANAGEMENT SYSTEM
-- Negative Test Cases — Patient Module
-- Run as: HMS_ADMIN_USER
-- All tests should output PASS (correctly BLOCKED)
-- =====================================================

SET SERVEROUTPUT ON;
SELECT USER AS connected_as FROM DUAL;

-- NT-01: CONSTRAINT VIOLATION — Invalid gender (X not in M/F/O)
DECLARE v_pid NUMBER;
BEGIN
    INSERT INTO hms_owner.patient (first_name, last_name, date_of_birth, gender, phone, city, state, is_minor, modified_by)
    VALUES ('Neg','BadGender', DATE '1990-01-01','X','999-NEG-001','Boston','MA','N','HMS_ADMIN_USER') RETURNING patient_id INTO v_pid;
    ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-01 FAIL: Should have blocked');
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-01 PASS: Blocked — '||SQLERRM);
END;
/

-- NT-02: CONSTRAINT VIOLATION — Invalid blood type (XX+ not in allowed list)
DECLARE v_pid NUMBER;
BEGIN
    INSERT INTO hms_owner.patient (first_name, last_name, date_of_birth, gender, phone, blood_type, city, state, is_minor, modified_by)
    VALUES ('Neg','BadBlood', DATE '1990-01-01','M','999-NEG-002','XX+','Boston','MA','N','HMS_ADMIN_USER') RETURNING patient_id INTO v_pid;
    ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-02 FAIL: Should have blocked');
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-02 PASS: Blocked — '||SQLERRM);
END;
/

-- NT-03: MINOR/GUARDIAN — Minor registered without guardian info
DECLARE v_pid NUMBER;
BEGIN
    hms_owner.pkg_patient_mgmt.sp_register_patient(
        p_first_name=>'Neg', p_last_name=>'MinorNoGuard', p_dob=>DATE '2014-03-10',
        p_gender=>'F', p_phone=>'999-NEG-003', p_city=>'Boston', p_state=>'MA', p_patient_id=>v_pid);
    ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-03 FAIL: Should have blocked');
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-03 PASS: Blocked — '||SQLERRM);
END;
/

-- NT-04: DUPLICATE CHECK — Register patient with an already-used phone number
DECLARE v_pid NUMBER; v_phone hms_owner.patient.phone%TYPE;
BEGIN
    SELECT MIN(phone) INTO v_phone FROM hms_owner.patient;
    hms_owner.pkg_patient_mgmt.sp_register_patient(
        p_first_name=>'Neg', p_last_name=>'DupPhone', p_dob=>DATE '1990-01-01',
        p_gender=>'M', p_phone=>v_phone, p_city=>'Boston', p_state=>'MA', p_patient_id=>v_pid);
    ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-04 FAIL: Should have blocked');
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-04 PASS: Blocked — '||SQLERRM);
END;
/

-- NT-05: INSURANCE VALIDATION — Link expired insurance to a patient
DECLARE v_pid NUMBER; v_ins_id NUMBER;
BEGIN
    SELECT MIN(patient_id) INTO v_pid FROM hms_owner.patient;
    SELECT MIN(insurance_id) INTO v_ins_id FROM hms_owner.insurance WHERE status='EXPIRED';
    hms_owner.pkg_patient_mgmt.sp_link_insurance(v_pid, v_ins_id);
    ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-05 FAIL: Should have blocked');
EXCEPTION WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('NT-05 PASS: Blocked — '||SQLERRM);
END;
/

