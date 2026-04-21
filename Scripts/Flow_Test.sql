-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM — Patient Module
-- End-to-End Flow: Register → Appointment → Admission → Bill
-- =============================================================

SET SERVEROUTPUT ON;

-- CLEANUP: Remove any leftover data from prior runs of this script
DELETE FROM payment   WHERE bill_id IN (SELECT bill_id FROM bill WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001'));
COMMIT;
DELETE FROM bill      WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001');
COMMIT;
DELETE FROM admission WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001');
COMMIT;
DELETE FROM appointment WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001');
COMMIT;
DELETE FROM patient   WHERE phone = '6175000001';
COMMIT;

-- STEP 1: Insert Patient
INSERT INTO patient (
    patient_id, first_name, last_name, date_of_birth,
    gender, phone, email, blood_type,
    city, state, insurance_id
)
VALUES (
    patient_seq.NEXTVAL, 'John', 'Carter', DATE '1985-03-22',
    'M', '6175000001', 'john.carter@hms.com', 'O+',
    'Boston', 'MA', 1
);

-- Verify patient was inserted with is_minor auto-set by trigger
SELECT patient_id, first_name, last_name, is_minor, insurance_id
FROM   patient
WHERE  phone = '6175000001';


-- STEP 2: Link / Change Insurance
UPDATE patient
SET    insurance_id = 4   -- UnitedHealth Group, 90%
WHERE  phone = '6175000001';

-- Verify insurance update
SELECT p.patient_id, p.first_name, i.provider_name, i.coverage_percentage
FROM   patient p JOIN insurance i ON i.insurance_id = p.insurance_id
WHERE  p.phone = '6175000001';


-- STEP 3: Schedule Appointment
INSERT INTO appointment (
    appointment_id, appointment_date, appointment_time,
    status, reason, patient_id, doctor_id
)
VALUES (
    appointment_seq.NEXTVAL, SYSDATE, '10:00 AM',
    'COMPLETED', 'Chest pain evaluation',
    (SELECT patient_id FROM patient WHERE phone = '6175000001'), 7
);

-- Verify appointment
SELECT appointment_id, appointment_date, status, reason, patient_id
FROM   appointment
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001');


-- STEP 4: Admit Patient
INSERT INTO admission (
    admission_id, admission_date, discharge_date,
    diagnosis, admission_type, status,
    doctor_id, bed_id, patient_id, appointment_id
)
VALUES (
    admission_seq.NEXTVAL, SYSDATE, SYSDATE + 3,
    'Acute chest pain — observation required', 'PLANNED', 'DISCHARGED',
    7, 201,
    (SELECT patient_id FROM patient WHERE phone = '6175000001'),
    (SELECT appointment_id FROM appointment WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001') AND ROWNUM = 1)
);

-- Verify admission
SELECT admission_id, diagnosis, admission_type, status, admission_date, discharge_date
FROM   admission
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001');


-- STEP 5: Generate Bill
-- trigger trg_bill_bi auto-calculates insurance_coverage_amt and net_amount
INSERT INTO bill (
    bill_id, service_charges, room_charges, medication_charges,
    total_amount, discount_amount, net_amount,
    status, patient_id, appointment_id, admission_id
)
VALUES (
    bill_seq.NEXTVAL, 300, 600, 100,
    1000, 0, 0,
    'PENDING',
    (SELECT patient_id   FROM patient    WHERE phone = '6175000001'),
    (SELECT appointment_id FROM appointment WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001') AND ROWNUM = 1),
    (SELECT admission_id   FROM admission   WHERE patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001') AND ROWNUM = 1)
);

-- Verify bill — insurance_coverage_amt and net_amount set by trigger
SELECT bill_id, total_amount, insurance_coverage_amt, net_amount, status
FROM   bill
WHERE  patient_id = (SELECT patient_id FROM patient WHERE phone = '6175000001');


-- STEP 6: Full Flow Summary
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name  AS patient_name,
    i.provider_name                      AS insurer,
    i.coverage_percentage,
    a.appointment_date,
    a.reason                             AS visit_reason,
    adm.diagnosis,
    adm.status                           AS admission_status,
    b.total_amount,
    b.insurance_coverage_amt,
    b.net_amount,
    b.status                             AS bill_status
FROM       patient     p
JOIN       insurance   i   ON i.insurance_id     = p.insurance_id
JOIN       appointment a   ON a.patient_id        = p.patient_id
JOIN       admission   adm ON adm.appointment_id  = a.appointment_id
JOIN       bill        b   ON b.patient_id         = p.patient_id
WHERE      p.phone = '6175000001';

COMMIT;
