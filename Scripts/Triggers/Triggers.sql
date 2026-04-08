-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM
-- Patient Module - Essential Triggers (6 Only)
-- Schema: HMS_OWNER
-- File: 02_TRIGGERS.sql
-- =============================================================


-- =============================================================
-- TRIGGER 1: TRG_INSURANCE_BI
-- Purpose : Auto-assign PK from sequence before insert
-- =============================================================
CREATE OR REPLACE TRIGGER trg_insurance_bi
BEFORE INSERT ON insurance
FOR EACH ROW
BEGIN
    IF :NEW.insurance_id IS NULL THEN
        :NEW.insurance_id := insurance_seq.NEXTVAL;
    END IF;
    :NEW.created_date  := NVL(:NEW.created_date, SYSDATE);
    :NEW.modified_date := SYSDATE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20100, 'TRG_INSURANCE_BI ERROR: ' || SQLERRM);
END trg_insurance_bi;
/
SHOW ERRORS TRIGGER trg_insurance_bi;


-- =============================================================
-- TRIGGER 2: TRG_PATIENT_BI
-- Purpose : Auto-assign PK, auto-set is_minor from DOB
-- Business Rule: Patient cannot have duplicate ID
--               is_minor automatically derived from age
-- =============================================================
CREATE OR REPLACE TRIGGER trg_patient_bi
BEFORE INSERT ON patient
FOR EACH ROW
DECLARE
    v_age NUMBER;
BEGIN
    -- Auto-assign PK
    IF :NEW.patient_id IS NULL THEN
        :NEW.patient_id := patient_seq.NEXTVAL;
    END IF;

    -- Auto-calculate is_minor from date of birth
    v_age := TRUNC(MONTHS_BETWEEN(SYSDATE, :NEW.date_of_birth) / 12);
    IF v_age < 18 THEN
        :NEW.is_minor := 'Y';
    ELSE
        :NEW.is_minor := 'N';
    END IF;

    :NEW.registration_date := NVL(:NEW.registration_date, SYSDATE);
    :NEW.created_date       := NVL(:NEW.created_date, SYSDATE);
    :NEW.modified_date      := SYSDATE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20102, 'TRG_PATIENT_BI ERROR: ' || SQLERRM);
END trg_patient_bi;
/
SHOW ERRORS TRIGGER trg_patient_bi;


-- =============================================================
-- TRIGGER 3: TRG_PATIENT_MINOR_GUARDIAN
-- Purpose : Block insert/update if minor has no guardian info
-- Business Rule: Minor patients must have guardian information
-- Error Code: -20110
-- =============================================================
CREATE OR REPLACE TRIGGER trg_patient_minor_guardian
BEFORE INSERT OR UPDATE ON patient
FOR EACH ROW
DECLARE
    v_age NUMBER;
BEGIN
    v_age := TRUNC(MONTHS_BETWEEN(SYSDATE, :NEW.date_of_birth) / 12);

    IF v_age < 18 AND :NEW.guardian_first_name IS NULL THEN
        RAISE_APPLICATION_ERROR(-20110,
            'BUSINESS RULE VIOLATION: Patient ' ||
            :NEW.first_name || ' ' || :NEW.last_name ||
            ' is a minor (Age: ' || v_age || '). ' ||
            'Guardian first name is mandatory for patients under 18.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END trg_patient_minor_guardian;
/
SHOW ERRORS TRIGGER trg_patient_minor_guardian;


-- =============================================================
-- TRIGGER 4: TRG_PATIENT_INSURANCE_VAL
-- Purpose : Block linking expired or inactive insurance to patient
-- Business Rule: Insurance must be validated before billing discount
-- Error Codes: -20120, -20121, -20122
-- =============================================================
CREATE OR REPLACE TRIGGER trg_patient_insurance_val
BEFORE INSERT OR UPDATE OF insurance_id ON patient
FOR EACH ROW
DECLARE
    v_status      insurance.status%TYPE;
    v_expiry_date insurance.policy_expiry_date%TYPE;
BEGIN
    IF :NEW.insurance_id IS NOT NULL THEN

        BEGIN
            SELECT status, policy_expiry_date
            INTO   v_status, v_expiry_date
            FROM   insurance
            WHERE  insurance_id = :NEW.insurance_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20120,
                    'VALIDATION ERROR: Insurance ID ' ||
                    :NEW.insurance_id || ' does not exist.');
        END;

        IF v_status != 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(-20121,
                'VALIDATION ERROR: Insurance ID ' || :NEW.insurance_id ||
                ' is not ACTIVE. Current status: ' || v_status);
        END IF;

        IF v_expiry_date < SYSDATE THEN
            RAISE_APPLICATION_ERROR(-20122,
                'VALIDATION ERROR: Insurance ID ' || :NEW.insurance_id ||
                ' expired on ' || TO_CHAR(v_expiry_date, 'DD-MON-YYYY'));
        END IF;

    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END trg_patient_insurance_val;
/
SHOW ERRORS TRIGGER trg_patient_insurance_val;


-- =============================================================
-- TRIGGER 5: TRG_BILL_BI
-- Purpose : Auto-assign PK, auto-apply insurance coverage,
--           auto-calculate net_amount
-- Business Rule: Bills with insurance must apply correct discount
-- Error Code: -20140
-- =============================================================
CREATE OR REPLACE TRIGGER trg_bill_bi
BEFORE INSERT ON bill
FOR EACH ROW
DECLARE
    v_coverage_pct NUMBER(5,2) := 0;
BEGIN
    -- Auto-assign PK
    IF :NEW.bill_id IS NULL THEN
        :NEW.bill_id := bill_seq.NEXTVAL;
    END IF;

    -- Auto-apply insurance coverage if not already set
    IF NVL(:NEW.insurance_coverage_amt, 0) = 0 THEN
        BEGIN
            SELECT NVL(i.coverage_percentage, 0)
            INTO   v_coverage_pct
            FROM   patient p
            JOIN   insurance i ON p.insurance_id = i.insurance_id
            WHERE  p.patient_id = :NEW.patient_id
            AND    i.status = 'ACTIVE'
            AND    i.policy_expiry_date >= SYSDATE;

            :NEW.insurance_coverage_amt :=
                ROUND(:NEW.total_amount * v_coverage_pct / 100, 2);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                :NEW.insurance_coverage_amt := 0;
        END;
    END IF;

    -- Auto-calculate net amount
    :NEW.net_amount := :NEW.total_amount
                     - NVL(:NEW.insurance_coverage_amt, 0)
                     - NVL(:NEW.discount_amount, 0);

    -- Net amount cannot be negative
    IF :NEW.net_amount < 0 THEN
        RAISE_APPLICATION_ERROR(-20140,
            'BILLING ERROR: Net amount cannot be negative. ' ||
            'Total: ' || :NEW.total_amount ||
            ', Insurance Coverage: ' || :NEW.insurance_coverage_amt ||
            ', Discount: ' || NVL(:NEW.discount_amount, 0));
    END IF;

    :NEW.created_date  := NVL(:NEW.created_date, SYSDATE);
    :NEW.modified_date := SYSDATE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END trg_bill_bi;
/
SHOW ERRORS TRIGGER trg_bill_bi;


-- =============================================================
-- TRIGGER 6: TRG_PAYMENT_BI
-- Purpose : Auto-assign PK, block payment exceeding
--           outstanding bill balance
-- Business Rule: Payment cannot exceed outstanding balance
-- Error Codes: -20150, -20151
-- =============================================================
CREATE OR REPLACE TRIGGER trg_payment_bi
BEFORE INSERT ON payment
FOR EACH ROW
DECLARE
    v_net_amount  NUMBER(10,2);
    v_paid_so_far NUMBER(10,2);
    v_outstanding NUMBER(10,2);
BEGIN
    -- Auto-assign PK
    IF :NEW.payment_id IS NULL THEN
        :NEW.payment_id := payment_seq.NEXTVAL;
    END IF;

    -- Get bill total and amount already paid
    SELECT b.net_amount,
           NVL(SUM(p.amount_paid), 0)
    INTO   v_net_amount, v_paid_so_far
    FROM   bill b
    LEFT JOIN payment p ON p.bill_id = b.bill_id
    WHERE  b.bill_id = :NEW.bill_id
    GROUP  BY b.net_amount;

    v_outstanding := v_net_amount - v_paid_so_far;

    -- Block if payment exceeds outstanding balance
    IF :NEW.amount_paid > v_outstanding THEN
        RAISE_APPLICATION_ERROR(-20150,
            'PAYMENT ERROR: Payment of $' || :NEW.amount_paid ||
            ' exceeds outstanding balance of $' || v_outstanding ||
            ' for Bill ID ' || :NEW.bill_id);
    END IF;

    :NEW.created_date  := NVL(:NEW.created_date, SYSDATE);
    :NEW.modified_date := SYSDATE;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20151,
            'PAYMENT ERROR: Bill ID ' || :NEW.bill_id || ' not found.');
    WHEN OTHERS THEN
        RAISE;
END trg_payment_bi;
/
SHOW ERRORS TRIGGER trg_payment_bi;


-- =============================================================
-- VERIFY: All 6 triggers compiled successfully
-- =============================================================
SELECT trigger_name, status, triggering_event
FROM   user_triggers
WHERE  table_name IN ('INSURANCE','PATIENT','BILL','PAYMENT')
ORDER  BY table_name, trigger_name;