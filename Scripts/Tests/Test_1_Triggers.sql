-- ============================================================
-- TEST 1: TRIGGERS
-- TRG_PATIENT_BI — auto PK, auto is_minor from DOB, audit stamp
-- TRG_BILL_BI    — auto total from charges, auto insurance coverage,
--                  auto net_amount, block negative net
-- Connect as: HMS_OWNER
-- Run Test_Cleanup.sql first
-- ============================================================

SET SERVEROUTPUT ON;

-- ── TRG_PATIENT_BI ──────────────────────────────────────────

DECLARE
    v_id    NUMBER;
    v_minor CHAR(1);
    v_mdate DATE;
BEGIN
    -- Adult: trigger should assign PK, set is_minor = N, stamp modified_date
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
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_PATIENT_BI] Expected N, got: ' || v_minor);
    END IF;

    IF v_mdate IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_PATIENT_BI] modified_date stamped: ' || TO_CHAR(v_mdate, 'YYYY-MM-DD'));
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_PATIENT_BI] modified_date is NULL');
    END IF;

    -- Minor: trigger should set is_minor = Y regardless of what caller passes
    INSERT INTO patient (
        first_name, last_name, date_of_birth, gender, phone,
        guardian_first_name, guardian_last_name, guardian_relationship, guardian_phone
    ) VALUES (
        'Trigger', 'TestMinor', DATE '2015-01-01', 'F', '9990000002',
        'Guardian', 'TestGuardian', 'PARENT', '9990000003'
    ) RETURNING is_minor INTO v_minor;

    IF v_minor = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_PATIENT_BI] is_minor = Y for minor DOB 2015');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_PATIENT_BI] Expected Y, got: ' || v_minor);
    END IF;

    ROLLBACK;
END;
/


-- ── TRG_BILL_BI ─────────────────────────────────────────────

DECLARE
    v_cov NUMBER;
    v_net NUMBER;
    v_appt_1   NUMBER;
    v_appt_176 NUMBER;
BEGIN
    SELECT appointment_id INTO v_appt_1
    FROM   appointment WHERE patient_id = 1 AND status = 'COMPLETED' AND ROWNUM = 1;

    SELECT appointment_id INTO v_appt_176
    FROM   appointment WHERE patient_id = 176 AND status = 'COMPLETED' AND ROWNUM = 1;

    -- Insured patient 1 (BlueCross 80%): total=500 → coverage=400, net=100
    INSERT INTO bill (bill_id, total_amount, discount_amount, net_amount, status, patient_id, appointment_id)
    VALUES (bill_seq.NEXTVAL, 500, 0, 0, 'PENDING', 1, v_appt_1)
    RETURNING insurance_coverage_amt, net_amount INTO v_cov, v_net;

    IF v_cov = 400 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] Insured 80%: coverage_amt = ' || v_cov);
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Expected coverage=400, got: ' || v_cov);
    END IF;

    IF v_net = 100 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] net_amount = total - coverage = ' || v_net);
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Expected net=100, got: ' || v_net);
    END IF;

    -- Uninsured patient 176: total=300 → coverage=0, net=300
    INSERT INTO bill (bill_id, total_amount, discount_amount, net_amount, status, patient_id, appointment_id)
    VALUES (bill_seq.NEXTVAL, 300, 0, 0, 'PENDING', 176, v_appt_176)
    RETURNING insurance_coverage_amt, net_amount INTO v_cov, v_net;

    IF v_cov = 0 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] Uninsured: coverage_amt = 0');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Expected 0, got: ' || v_cov);
    END IF;

    IF v_net = 300 THEN
        DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] Uninsured net_amount = total = ' || v_net);
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Expected 300, got: ' || v_net);
    END IF;

    ROLLBACK;
END;
/

-- Negative: discount larger than total → trigger must block (net would go negative)
DECLARE
    v_appt NUMBER;
BEGIN
    SELECT appointment_id INTO v_appt
    FROM   appointment WHERE patient_id = 1 AND ROWNUM = 1;

    INSERT INTO bill (bill_id, total_amount, discount_amount, net_amount, status, patient_id, appointment_id)
    VALUES (bill_seq.NEXTVAL, 100, 5000, 0, 'PENDING', 1, v_appt);

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Should have blocked negative net');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -20140 THEN
            DBMS_OUTPUT.PUT_LINE('PASS [TRG_BILL_BI] Negative net blocked: ORA-20140');
        ELSE
            DBMS_OUTPUT.PUT_LINE('FAIL [TRG_BILL_BI] Wrong error: ' || SQLERRM);
        END IF;
END;
/
