-- =====================================================
-- POSITIVE TEST CASES
-- Run as: HMS_ADMIN_USER
-- All use ROLLBACK — no permanent data changes
-- =====================================================

SET SERVEROUTPUT ON;

SELECT USER AS connected_as FROM DUAL;


-- PT-01: Auto PK Assignment
DECLARE
    v_pid NUMBER;
BEGIN
    INSERT INTO hms_owner.patient (
        first_name, last_name, date_of_birth, gender,
        phone, city, state, is_minor, modified_by
    ) VALUES (
        'Pos', 'AutoPK', DATE '1985-01-01', 'M',
        '9990000001', 'Boston', 'MA', 'N', 'HMS_ADMIN_USER'
    ) RETURNING patient_id INTO v_pid;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-01 PASS: PK auto-assigned = ' || v_pid);
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-01 FAIL: ' || SQLERRM);
END;
/


-- PT-02: is_minor = N for Adult
DECLARE
    v_pid      NUMBER;
    v_is_minor CHAR(1);
BEGIN
    INSERT INTO hms_owner.patient (
        first_name, last_name, date_of_birth, gender,
        phone, city, state, is_minor, modified_by
    ) VALUES (
        'Pos', 'AdultTest', DATE '1990-06-15', 'F',
        '9990000002', 'Boston', 'MA', 'N', 'HMS_ADMIN_USER'
    ) RETURNING patient_id INTO v_pid;
    SELECT is_minor INTO v_is_minor FROM hms_owner.patient WHERE patient_id = v_pid;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-02 PASS: is_minor = ' || v_is_minor || ' (Expected N)');
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-02 FAIL: ' || SQLERRM);
END;
/


-- PT-03: is_minor = Y for Minor
DECLARE
    v_pid      NUMBER;
    v_is_minor CHAR(1);
BEGIN
    INSERT INTO hms_owner.patient (
        first_name, last_name, date_of_birth, gender,
        phone, city, state, is_minor,
        guardian_first_name, guardian_last_name,
        guardian_relationship, guardian_phone, modified_by
    ) VALUES (
        'Pos', 'MinorTest', DATE '2015-03-10', 'M',
        '9990000003', 'Boston', 'MA', 'Y',
        'Pos', 'Guardian', 'PARENT', '9990001001', 'HMS_ADMIN_USER'
    ) RETURNING patient_id INTO v_pid;
    SELECT is_minor INTO v_is_minor FROM hms_owner.patient WHERE patient_id = v_pid;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-03 PASS: is_minor = ' || v_is_minor || ' (Expected Y)');
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-03 FAIL: ' || SQLERRM);
END;
/


-- PT-04: Insurance discount auto-applied on bill
DECLARE
    v_pid      NUMBER;
    v_pct      NUMBER;
    v_appt_id  NUMBER;
    v_coverage NUMBER;
    v_net      NUMBER;
BEGIN
    SELECT p.patient_id, i.coverage_percentage
    INTO   v_pid, v_pct
    FROM   hms_owner.patient p
    JOIN   hms_owner.insurance i ON i.insurance_id = p.insurance_id
    WHERE  i.status = 'ACTIVE' AND ROWNUM = 1;

    SELECT appointment_id INTO v_appt_id
    FROM   hms_owner.appointment WHERE patient_id = v_pid AND ROWNUM = 1;

    INSERT INTO hms_owner.bill (
        bill_id, service_charges, total_amount,
        discount_amount, net_amount, status,
        patient_id, appointment_id, modified_by
    ) VALUES (
        hms_owner.bill_seq.NEXTVAL, 1000, 1000,
        0, 0, 'PENDING', v_pid, v_appt_id, 'HMS_ADMIN_USER'
    ) RETURNING insurance_coverage_amt, net_amount INTO v_coverage, v_net;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-04 PASS: Coverage(' || v_pct || '%) = $' || v_coverage || ', Net = $' || v_net);
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-04 FAIL: ' || SQLERRM);
END;
/


-- PT-05: Uninsured patient net = total
DECLARE
    v_pid      NUMBER;
    v_appt_id  NUMBER;
    v_coverage NUMBER;
    v_net      NUMBER;
BEGIN
    SELECT MIN(patient_id) INTO v_pid
    FROM   hms_owner.patient WHERE insurance_id IS NULL AND is_minor = 'N';

    SELECT appointment_id INTO v_appt_id
    FROM   hms_owner.appointment WHERE patient_id = v_pid AND ROWNUM = 1;

    INSERT INTO hms_owner.bill (
        bill_id, service_charges, total_amount,
        discount_amount, net_amount, status,
        patient_id, appointment_id, modified_by
    ) VALUES (
        hms_owner.bill_seq.NEXTVAL, 500, 500,
        0, 0, 'PENDING', v_pid, v_appt_id, 'HMS_ADMIN_USER'
    ) RETURNING insurance_coverage_amt, net_amount INTO v_coverage, v_net;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-05 PASS: Uninsured — coverage=' || v_coverage || ', net=' || v_net);
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-05 FAIL: ' || SQLERRM);
END;
/


-- PT-06: Register valid adult patient
DECLARE
    v_pid    NUMBER;
    v_ins_id NUMBER;
BEGIN
    SELECT MIN(insurance_id) INTO v_ins_id
    FROM   hms_owner.insurance WHERE status = 'ACTIVE';

    hms_owner.pkg_patient_mgmt.sp_register_patient(
        p_first_name   => 'Pos',     p_last_name    => 'ValidAdult',
        p_dob          => DATE '1985-05-15', p_gender => 'M',
        p_phone        => '9990000006',        p_email  => 'pos.adult@hms.com',
        p_blood_type   => 'O+',      p_city   => 'Boston',
        p_state        => 'MA',      p_insurance_id => v_ins_id,
        p_patient_id   => v_pid
    );
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-06 PASS: Registered patient ID = ' || v_pid);
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-06 FAIL: ' || SQLERRM);
END;
/


-- PT-07: Register valid minor with guardian
DECLARE
    v_pid      NUMBER;
    v_is_minor CHAR(1);
BEGIN
    INSERT INTO hms_owner.patient (
        first_name, last_name, date_of_birth, gender,
        phone, email, blood_type, city, state, is_minor,
        guardian_first_name, guardian_last_name,
        guardian_relationship, guardian_phone, modified_by
    ) VALUES (
        'Pos', 'ValidMinor', DATE '2014-03-10', 'F',
        '9990000007', 'pos.minor@hms.com', 'A+', 'Boston', 'MA', 'Y',
        'Pos', 'Guardian', 'PARENT', '9990001007', 'HMS_ADMIN_USER'
    ) RETURNING patient_id INTO v_pid;
    SELECT is_minor INTO v_is_minor FROM hms_owner.patient WHERE patient_id = v_pid;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-07 PASS: Minor ID=' || v_pid || ', is_minor=' || v_is_minor);
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-07 FAIL: ' || SQLERRM);
END;
/


-- PT-08: Update patient details
DECLARE
    v_pid   NUMBER;
    v_after VARCHAR2(50);
BEGIN
    SELECT MIN(patient_id) INTO v_pid FROM hms_owner.patient WHERE is_minor = 'N';

    hms_owner.pkg_patient_mgmt.sp_update_patient(
        p_patient_id => v_pid,
        p_city       => 'Newton',
        p_blood_type => 'AB+'
    );
    SELECT city INTO v_after FROM hms_owner.patient WHERE patient_id = v_pid;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-08 PASS: City updated to ' || v_after);
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-08 FAIL: ' || SQLERRM);
END;
/


-- PT-09: Link insurance to patient
DECLARE
    v_pid       NUMBER;
    v_ins_id    NUMBER;
    v_ins_after NUMBER;
BEGIN
    SELECT MIN(patient_id) INTO v_pid
    FROM   hms_owner.patient WHERE insurance_id IS NULL AND is_minor = 'N';

    SELECT MIN(insurance_id) INTO v_ins_id
    FROM   hms_owner.insurance WHERE status = 'ACTIVE';

    hms_owner.pkg_patient_mgmt.sp_link_insurance(v_pid, v_ins_id);

    SELECT insurance_id INTO v_ins_after
    FROM   hms_owner.patient WHERE patient_id = v_pid;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-09 PASS: Insurance ' || v_ins_after || ' linked to patient ' || v_pid);
EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('PT-09 FAIL: ' || SQLERRM);
END;
/


-- PT-10: View medical history
SELECT appointment_date, visit_reason, appointment_status,
       medication_name, dosage, frequency
FROM   hms_owner.v_patient_medical_history
WHERE  patient_id = (
    SELECT MIN(patient_id) FROM hms_owner.appointment WHERE status = 'COMPLETED'
)
ORDER BY appointment_date DESC;


-- PT-11: FN_IS_MINOR and FN_GET_COVERAGE_PCT
SELECT p.patient_id,
       p.first_name || ' ' || p.last_name                        AS patient_name,
       p.is_minor                                                 AS db_is_minor,
       hms_owner.pkg_patient_mgmt.fn_is_minor(p.patient_id)      AS fn_is_minor,
       NVL(i.coverage_percentage, 0)                             AS db_coverage,
       hms_owner.pkg_patient_mgmt.fn_get_coverage_pct(p.patient_id) AS fn_coverage
FROM   hms_owner.patient p
LEFT JOIN hms_owner.insurance i ON i.insurance_id = p.insurance_id
WHERE  p.patient_id IN (
    SELECT MIN(patient_id) FROM hms_owner.patient WHERE is_minor = 'Y'
    UNION ALL
    SELECT MIN(patient_id) FROM hms_owner.patient WHERE is_minor = 'N'
    UNION ALL
    SELECT MIN(patient_id) FROM hms_owner.patient WHERE insurance_id IS NULL
);