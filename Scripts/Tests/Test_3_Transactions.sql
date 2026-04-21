-- ============================================================
-- TEST 3: TRANSACTIONS — Full Patient Flow
-- INSERT: patient → appointment → admission → bill → payment
-- UPDATE: bill status after payment
-- DELETE: clean removal in reverse dependency order
-- Connect as: HMS_ADMIN_USER  (password: AdminUser#2026)
-- ============================================================

SET SERVEROUTPUT ON;
ALTER SESSION SET CURRENT_SCHEMA = hms_owner;

-- ============================================================
-- STEP 1: Register patient via procedure
-- (Admin can call the package)
-- ============================================================

DECLARE
    v_pid NUMBER;
BEGIN
    pkg_patient_mgmt.sp_register_patient(
        p_first_name   => 'Ryan',
        p_last_name    => 'Carter',
        p_dob          => DATE '1985-07-20',
        p_gender       => 'M',
        p_phone        => '9990000030',
        p_email        => 'ryan.carter@hms.com',
        p_blood_type   => 'B+',
        p_city         => 'Boston',
        p_state        => 'MA',
        p_insurance_id => 4,   -- UnitedHealth 90%
        p_patient_id   => v_pid
    );
    DBMS_OUTPUT.PUT_LINE('Patient registered: ID = ' || v_pid);
END;
/

-- Verify patient
SELECT patient_id, first_name, last_name, is_minor, insurance_id
FROM   patient WHERE phone = '9990000030';


-- ============================================================
-- STEP 2: Insert appointment (direct DML — admin privilege)
-- ============================================================

INSERT INTO appointment (
    appointment_id, appointment_date, appointment_time,
    status, reason, patient_id, doctor_id, modified_by
) VALUES (
    appointment_seq.NEXTVAL, DATE '2026-05-01', '09:00 AM',
    'COMPLETED', 'Back pain evaluation',
    (SELECT patient_id FROM patient WHERE phone = '9990000030'),
    7, 'HMS_ADMIN_USER'
);
COMMIT;

-- Verify appointment
SELECT appointment_id, appointment_date, status, reason
FROM   appointment
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');


-- ============================================================
-- STEP 3: Insert admission
-- ============================================================

INSERT INTO admission (
    admission_id, admission_date, discharge_date,
    diagnosis, admission_type, status,
    doctor_id, bed_id, patient_id, appointment_id, modified_by
) VALUES (
    admission_seq.NEXTVAL, DATE '2026-05-01', DATE '2026-05-04',
    'Lumbar disc herniation — physiotherapy required',
    'PLANNED', 'DISCHARGED',
    7, 305,
    (SELECT patient_id FROM patient WHERE phone = '9990000030'),
    (SELECT appointment_id FROM appointment
     WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030')
     AND    ROWNUM = 1),
    'HMS_ADMIN_USER'
);
COMMIT;

-- Verify admission
SELECT admission_id, admission_date, discharge_date, diagnosis, status
FROM   admission
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');


-- ============================================================
-- STEP 4: Insert bill
-- Trigger TRG_BILL_BI auto-calculates:
--   total_amount  = service + room + meds
--   insurance_coverage_amt = total * 90% (UnitedHealth)
--   net_amount    = total - coverage
-- ============================================================

INSERT INTO bill (
    bill_id,
    service_charges, room_charges, medication_charges,
    total_amount, discount_amount, net_amount,
    status, patient_id, appointment_id, admission_id, modified_by
) VALUES (
    bill_seq.NEXTVAL,
    400, 900, 150,
    0, 0, 0,   -- all three auto-filled by trigger
    'PENDING',
    (SELECT patient_id    FROM patient     WHERE phone = '9990000030'),
    (SELECT appointment_id FROM appointment WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030') AND ROWNUM = 1),
    (SELECT admission_id   FROM admission   WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030') AND ROWNUM = 1),
    'HMS_ADMIN_USER'
);
COMMIT;

-- Verify bill — trigger should have filled in total, coverage, net
SELECT bill_id, total_amount, insurance_coverage_amt, discount_amount, net_amount, status
FROM   bill
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');


-- ============================================================
-- STEP 5: Insert payment + update bill to PAID
-- ============================================================

INSERT INTO payment (
    payment_id, amount_paid, payment_method,
    transaction_reference, bill_id
) VALUES (
    payment_seq.NEXTVAL,
    (SELECT net_amount FROM bill
     WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030')
     AND    ROWNUM = 1),
    'DEBIT_CARD',
    'TXN-2026-DEMO-001',
    (SELECT bill_id FROM bill
     WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030')
     AND    ROWNUM = 1)
);

UPDATE bill
SET    status = 'PAID', modified_date = SYSDATE
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');

COMMIT;

-- Verify payment and bill status
SELECT py.payment_id, py.amount_paid, py.payment_method,
       b.total_amount, b.insurance_coverage_amt, b.net_amount, b.status AS bill_status
FROM   payment py
JOIN   bill    b  ON b.bill_id = py.bill_id
WHERE  b.patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');


-- ============================================================
-- STEP 6: Full summary — one view of the entire flow
-- ============================================================

SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name   AS patient_name,
    i.provider_name                        AS insurer,
    i.coverage_percentage                  AS coverage_pct,
    a.appointment_date,
    a.reason                               AS visit_reason,
    adm.diagnosis,
    adm.status                             AS admission_status,
    b.total_amount,
    b.insurance_coverage_amt,
    b.net_amount,
    b.status                               AS bill_status,
    py.payment_method
FROM       patient     p
JOIN       insurance   i   ON i.insurance_id    = p.insurance_id
JOIN       appointment a   ON a.patient_id      = p.patient_id
JOIN       admission   adm ON adm.appointment_id = a.appointment_id
JOIN       bill        b   ON b.patient_id       = p.patient_id
JOIN       payment     py  ON py.bill_id         = b.bill_id
WHERE      p.phone = '9990000030';


-- ============================================================
-- STEP 7: DELETE — clean removal in reverse dependency order
-- (shows admin can delete directly; also shows FK dependency order)
-- ============================================================

-- Payment first (depends on bill)
DELETE FROM payment
WHERE  bill_id = (
    SELECT bill_id FROM bill
    WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030')
    AND    ROWNUM = 1
);

-- Bill (depends on appointment and admission)
DELETE FROM bill
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');

-- Prescription items and prescriptions if any
DELETE FROM prescription_item
WHERE  prescription_id IN (
    SELECT prescription_id FROM prescription
    WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030')
);
DELETE FROM prescription
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');

-- Admission (depends on appointment)
DELETE FROM admission
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');

-- Appointment (depends on patient)
DELETE FROM appointment
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '9990000030');

-- Patient last
DELETE FROM patient WHERE phone = '9990000030';

COMMIT;

-- Confirm all rows removed
SELECT COUNT(*) AS remaining
FROM   patient WHERE phone = '9990000030';
-- Expected: 0
