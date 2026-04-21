-- ============================================================
-- TEST 2: STORED PROCEDURES — POSITIVE AND NEGATIVE CASES
-- SP_REGISTER_PATIENT, SP_UPDATE_PATIENT,
-- SP_LINK_INSURANCE, SP_DEACTIVATE_PATIENT
-- Connect as: HMS_OWNER
-- Run Test_Cleanup.sql first
-- ============================================================

SET SERVEROUTPUT ON;

-- ============================================================
-- POSITIVE CASES
-- ============================================================

-- Register a valid adult with active insurance
DECLARE
    v_id NUMBER;
BEGIN
    pkg_patient_mgmt.sp_register_patient(
        p_first_name   => 'Alex',
        p_last_name    => 'Turner',
        p_dob          => DATE '1992-08-21',
        p_gender       => 'M',
        p_phone        => '9990000005',
        p_email        => 'alex.turner@hms.com',
        p_blood_type   => 'B+',
        p_city         => 'Boston',
        p_state        => 'MA',
        p_insurance_id => 2,
        p_patient_id   => v_id
    );
    DBMS_OUTPUT.PUT_LINE('PASS [SP_REGISTER_PATIENT] Adult registered. ID = ' || v_id);
END;
/

-- Register a valid minor with guardian info
DECLARE
    v_id NUMBER;
BEGIN
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

-- Verify both patients
SELECT patient_id, first_name || ' ' || last_name AS name,
       is_minor, insurance_id, guardian_first_name, guardian_relationship
FROM   patient WHERE phone IN ('9990000005', '9990000006')
ORDER  BY patient_id;

-- Update city and blood type for adult
DECLARE
    v_id NUMBER;
BEGIN
    SELECT patient_id INTO v_id FROM patient WHERE phone = '9990000005';
    pkg_patient_mgmt.sp_update_patient(
        p_patient_id => v_id,
        p_city       => 'Somerville',
        p_blood_type => 'O+'
    );
    DBMS_OUTPUT.PUT_LINE('PASS [SP_UPDATE_PATIENT] Patient ' || v_id || ' updated.');
END;
/

SELECT patient_id, first_name, city, blood_type FROM patient WHERE phone = '9990000005';

-- Link a different active insurance to adult
DECLARE
    v_id NUMBER;
BEGIN
    SELECT patient_id INTO v_id FROM patient WHERE phone = '9990000005';
    pkg_patient_mgmt.sp_link_insurance(
        p_patient_id   => v_id,
        p_insurance_id => 5   -- Humana Insurance, ACTIVE, 75%
    );
    DBMS_OUTPUT.PUT_LINE('PASS [SP_LINK_INSURANCE] Insurance 5 linked to patient ' || v_id);
END;
/

SELECT p.first_name, i.provider_name, i.coverage_percentage
FROM   patient p JOIN insurance i ON i.insurance_id = p.insurance_id
WHERE  p.phone = '9990000005';

-- Deactivate adult patient
DECLARE
    v_id NUMBER;
BEGIN
    SELECT patient_id INTO v_id FROM patient WHERE phone = '9990000005';
    pkg_patient_mgmt.sp_deactivate_patient(p_patient_id => v_id, p_reason => 'Test deactivation');
    DBMS_OUTPUT.PUT_LINE('PASS [SP_DEACTIVATE_PATIENT] Patient ' || v_id || ' deactivated.');
END;
/

SELECT patient_id, first_name, status FROM patient WHERE phone = '9990000005';


-- ============================================================
-- NEGATIVE CASES — all expected to raise specific errors
-- ============================================================

DECLARE
    v_id NUMBER;

    PROCEDURE expect_error (p_label VARCHAR2, p_code NUMBER) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('FAIL [' || p_label || '] No error raised — expected ORA-' || p_code);
    END;

BEGIN
    -- Future date of birth
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'Future', p_last_name => 'DOB',
            p_dob => SYSDATE + 30, p_gender => 'M',
            p_phone => '9990000010', p_patient_id => v_id
        );
        expect_error('FUTURE DOB', 20009);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20009 THEN DBMS_OUTPUT.PUT_LINE('PASS [FUTURE DOB] ORA-20009 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [FUTURE DOB] Wrong error: ' || SQLERRM); END IF;
    END;

    -- Duplicate phone (Emma Smith is 6172000001)
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'Dup', p_last_name => 'Phone',
            p_dob => DATE '1985-01-01', p_gender => 'M',
            p_phone => '6172000001',
            p_patient_id => v_id
        );
        expect_error('DUPLICATE PHONE', 20010);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20010 THEN DBMS_OUTPUT.PUT_LINE('PASS [DUPLICATE PHONE] ORA-20010 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [DUPLICATE PHONE] Wrong error: ' || SQLERRM); END IF;
    END;

    -- Minor with no guardian
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'Minor', p_last_name => 'NoGuardian',
            p_dob => DATE '2015-05-05', p_gender => 'F',
            p_phone => '9990000011', p_patient_id => v_id
        );
        expect_error('MINOR NO GUARDIAN', 20011);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20011 THEN DBMS_OUTPUT.PUT_LINE('PASS [MINOR NO GUARDIAN] ORA-20011 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [MINOR NO GUARDIAN] Wrong error: ' || SQLERRM); END IF;
    END;

    -- Insurance ID does not exist
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'Bad', p_last_name => 'Insurance',
            p_dob => DATE '1980-01-01', p_gender => 'M',
            p_phone => '9990000012', p_insurance_id => 9999,
            p_patient_id => v_id
        );
        expect_error('INSURANCE NOT FOUND', 20012);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20012 THEN DBMS_OUTPUT.PUT_LINE('PASS [INSURANCE NOT FOUND] ORA-20012 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [INSURANCE NOT FOUND] Wrong error: ' || SQLERRM); END IF;
    END;

    -- Insurance is INACTIVE (ID 15 = COBRA)
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'Inactive', p_last_name => 'Ins',
            p_dob => DATE '1975-03-10', p_gender => 'M',
            p_phone => '9990000013', p_insurance_id => 15,
            p_patient_id => v_id
        );
        expect_error('INACTIVE INSURANCE', 20013);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20013 THEN DBMS_OUTPUT.PUT_LINE('PASS [INACTIVE INSURANCE] ORA-20013 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [INACTIVE INSURANCE] Wrong error: ' || SQLERRM); END IF;
    END;

    -- Insurance is EXPIRED (ID 13 = Centene)
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name => 'Expired', p_last_name => 'Ins',
            p_dob => DATE '1988-07-20', p_gender => 'F',
            p_phone => '9990000014', p_insurance_id => 13,
            p_patient_id => v_id
        );
        expect_error('EXPIRED INSURANCE', 20014);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20014 THEN DBMS_OUTPUT.PUT_LINE('PASS [EXPIRED INSURANCE] ORA-20014 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [EXPIRED INSURANCE] Wrong error: ' || SQLERRM); END IF;
    END;

    -- SP_LINK_INSURANCE with expired policy
    BEGIN
        pkg_patient_mgmt.sp_link_insurance(p_patient_id => 176, p_insurance_id => 13);
        expect_error('LINK EXPIRED INSURANCE', 20033);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20033 THEN DBMS_OUTPUT.PUT_LINE('PASS [LINK EXPIRED INSURANCE] ORA-20033 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [LINK EXPIRED INSURANCE] Wrong error: ' || SQLERRM); END IF;
    END;

    -- SP_UPDATE_PATIENT with non-existent patient ID
    BEGIN
        pkg_patient_mgmt.sp_update_patient(p_patient_id => 99999, p_city => 'Nowhere');
        expect_error('UPDATE NOT FOUND', 20020);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20020 THEN DBMS_OUTPUT.PUT_LINE('PASS [UPDATE NOT FOUND] ORA-20020 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [UPDATE NOT FOUND] Wrong error: ' || SQLERRM); END IF;
    END;

    -- SP_DEACTIVATE_PATIENT — patient 27 has an active admission
    BEGIN
        pkg_patient_mgmt.sp_deactivate_patient(p_patient_id => 27);
        expect_error('DEACTIVATE WITH ACTIVE ADMISSION', 20042);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20042 THEN DBMS_OUTPUT.PUT_LINE('PASS [ACTIVE ADMISSION BLOCK] ORA-20042 raised correctly');
            ELSE DBMS_OUTPUT.PUT_LINE('FAIL [ACTIVE ADMISSION BLOCK] Wrong error: ' || SQLERRM); END IF;
    END;

END;
/


-- ============================================================
-- DDL CONSTRAINT VIOLATIONS — direct INSERT blocked by CHECK
-- ============================================================

-- NT-01: Invalid gender value (X not in M/F/O)
DECLARE
    v_id NUMBER;
BEGIN
    INSERT INTO patient (
        patient_id, first_name, last_name, date_of_birth,
        gender, phone, city, state, is_minor, modified_by
    ) VALUES (
        patient_seq.NEXTVAL, 'Neg', 'BadGender',
        DATE '1990-01-01', 'X', '9990000020', 'Boston', 'MA', 'N', 'HMS_OWNER'
    ) RETURNING patient_id INTO v_id;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('FAIL [NT-01 GENDER CHECK] Should have been blocked');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('PASS [NT-01 GENDER CHECK] Blocked — ' || SQLERRM);
END;
/

-- NT-02: Invalid blood type (XX+ not in allowed list)
DECLARE
    v_id NUMBER;
BEGIN
    INSERT INTO patient (
        patient_id, first_name, last_name, date_of_birth,
        gender, phone, blood_type, city, state, is_minor, modified_by
    ) VALUES (
        patient_seq.NEXTVAL, 'Neg', 'BadBlood',
        DATE '1990-01-01', 'M', '9990000021', 'XX+', 'Boston', 'MA', 'N', 'HMS_OWNER'
    ) RETURNING patient_id INTO v_id;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('FAIL [NT-02 BLOOD TYPE CHECK] Should have been blocked');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('PASS [NT-02 BLOOD TYPE CHECK] Blocked — ' || SQLERRM);
END;
/
