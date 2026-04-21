-- ============================================================
-- TEST CLEANUP
-- Run before any test file to remove leftover rows from prior runs
-- Connect as: HMS_OWNER
-- ============================================================

SET SERVEROUTPUT ON;

BEGIN
    DELETE FROM payment
    WHERE  bill_id IN (
        SELECT bill_id FROM bill
        WHERE  patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%')
    );
    DELETE FROM bill
    WHERE  patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%');

    DELETE FROM prescription_item
    WHERE  prescription_id IN (
        SELECT prescription_id FROM prescription
        WHERE  patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%')
    );
    DELETE FROM prescription
    WHERE  patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%');

    DELETE FROM admission
    WHERE  patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%');

    DELETE FROM appointment
    WHERE  patient_id IN (SELECT patient_id FROM patient WHERE phone LIKE '9990000%');

    DELETE FROM patient WHERE phone LIKE '9990000%';

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Cleanup done.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Cleanup error: ' || SQLERRM);
END;
/
