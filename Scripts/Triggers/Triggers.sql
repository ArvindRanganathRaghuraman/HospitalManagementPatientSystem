-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM
-- Patient Module - Triggers (2 Essential Only)
-- Schema: HMS_OWNER
-- File: 02_TRIGGERS.sql
-- =============================================================

-- =============================================================
-- TRIGGER 1: TRG_PATIENT_BI
-- Purpose : Auto-assign PK from sequence, auto-set is_minor
--           from date of birth before every insert
-- Business Rule: Patient cannot have duplicate ID
--               is_minor automatically derived from DOB
-- =============================================================
CREATE OR REPLACE TRIGGER trg_patient_bi
BEFORE INSERT ON patient
FOR EACH ROW
DECLARE
    v_age NUMBER;
BEGIN
    -- Auto-assign patient_id from sequence
    IF :NEW.patient_id IS NULL THEN
        :NEW.patient_id := patient_seq.NEXTVAL;
    END IF;

    -- Auto-calculate and set is_minor from date of birth
    v_age := TRUNC(MONTHS_BETWEEN(SYSDATE, :NEW.date_of_birth) / 12);
    IF v_age < 18 THEN
        :NEW.is_minor := 'Y';
    ELSE
        :NEW.is_minor := 'N';
    END IF;

    -- Stamp audit dates
    :NEW.registration_date := NVL(:NEW.registration_date, SYSDATE);
    :NEW.created_date       := NVL(:NEW.created_date, SYSDATE);
    :NEW.modified_date      := SYSDATE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20100,
            'TRG_PATIENT_BI ERROR: ' || SQLERRM);
END trg_patient_bi;
/
SHOW ERRORS TRIGGER trg_patient_bi;


-- =============================================================
-- TRIGGER 2: TRG_BILL_BI
-- Purpose : Auto-assign PK, auto-apply insurance coverage
--           percentage, auto-calculate net_amount on every insert
-- Business Rule: Bills with insurance must apply correct discount
--               Payment cannot result in negative net amount
-- =============================================================
CREATE OR REPLACE TRIGGER trg_bill_bi
BEFORE INSERT ON bill
FOR EACH ROW
DECLARE
    v_coverage_pct NUMBER(5,2) := 0;
BEGIN
    -- Auto-assign bill_id from sequence
    IF :NEW.bill_id IS NULL THEN
        :NEW.bill_id := bill_seq.NEXTVAL;
    END IF;

    -- Auto-fetch and apply insurance coverage if not already provided
    IF NVL(:NEW.insurance_coverage_amt, 0) = 0 THEN
        BEGIN
            SELECT NVL(i.coverage_percentage, 0)
            INTO   v_coverage_pct
            FROM   patient p
            JOIN   insurance i ON p.insurance_id = i.insurance_id
            WHERE  p.patient_id = :NEW.patient_id
            AND    i.status     = 'ACTIVE'
            AND    i.policy_expiry_date >= SYSDATE;

            -- Calculate insurance coverage amount
            :NEW.insurance_coverage_amt :=
                ROUND(:NEW.total_amount * v_coverage_pct / 100, 2);

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Patient has no active insurance, coverage = 0
                :NEW.insurance_coverage_amt := 0;
        END;
    END IF;

    -- Auto-calculate net amount after insurance and discount
    :NEW.net_amount := :NEW.total_amount
                     - NVL(:NEW.insurance_coverage_amt, 0)
                     - NVL(:NEW.discount_amount, 0);

    -- Net amount must never be negative
    IF :NEW.net_amount < 0 THEN
        RAISE_APPLICATION_ERROR(-20140,
            'BILLING ERROR: Net amount cannot be negative. ' ||
            'Total: '             || :NEW.total_amount        ||
            ', Insurance Cover: ' || :NEW.insurance_coverage_amt ||
            ', Discount: '        || NVL(:NEW.discount_amount, 0));
    END IF;

    -- Stamp audit dates
    :NEW.created_date  := NVL(:NEW.created_date, SYSDATE);
    :NEW.modified_date := SYSDATE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END trg_bill_bi;
/
SHOW ERRORS TRIGGER trg_bill_bi;


-- =============================================================
-- VERIFY: Both triggers compiled and enabled
-- =============================================================
SELECT trigger_name, status, triggering_event, table_name
FROM   user_triggers
WHERE  trigger_name IN ('TRG_PATIENT_BI', 'TRG_BILL_BI')
ORDER  BY trigger_name;