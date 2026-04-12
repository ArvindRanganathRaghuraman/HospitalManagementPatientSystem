-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM - PATIENT MODULE
-- Package: Patient Management (Specification + Body)
-- Schema: HMS_OWNER
-- Database: Oracle 19c+
-- Author: HMS Development Team
-- Created: 2026-04-11
-- Purpose: Manage patient registration, updates, search, history,
--          insurance linking, and status management with complete
--          business rule validations and exception handling
-- =============================================================
-- DEPENDENCIES:
--   - Tables: patient, insurance, appointment, prescription, prescription_item
--   - Sequences: patient_seq, insurance_seq
--   - Triggers: trg_patient_bi, trg_patient_minor_guardian, 
--               trg_patient_insurance_val, trg_bill_bi, trg_payment_bi
-- =============================================================


-- =============================================================
-- PACKAGE SPECIFICATION
-- =============================================================

CREATE OR REPLACE PACKAGE pkg_patient_mgmt AS
    
    -- =========================================================
    -- PROCEDURE 1: SP_REGISTER_PATIENT
    -- =========================================================
    -- Purpose: Register a new patient with complete validation
    -- Business Rules:
    --   1. Phone number must be unique
    --   2. Date of birth cannot be in future
    --   3. Minor patients (< 18 years) MUST have guardian info
    --   4. Insurance (if provided) must be ACTIVE and not expired
    --   5. Email format validation (if provided)
    -- Error Codes: -20001 to -20005
    -- =========================================================
    PROCEDURE sp_register_patient (
        p_first_name            IN patient.first_name%TYPE,
        p_last_name             IN patient.last_name%TYPE,
        p_dob                   IN patient.date_of_birth%TYPE,
        p_gender                IN patient.gender%TYPE,
        p_phone                 IN patient.phone%TYPE,
        p_email                 IN patient.email%TYPE         DEFAULT NULL,
        p_blood_type            IN patient.blood_type%TYPE    DEFAULT NULL,
        p_city                  IN patient.city%TYPE          DEFAULT NULL,
        p_state                 IN patient.state%TYPE         DEFAULT NULL,
        p_zip_code              IN patient.zip_code%TYPE      DEFAULT NULL,
        p_address               IN patient.address%TYPE       DEFAULT NULL,
        p_insurance_id          IN patient.insurance_id%TYPE  DEFAULT NULL,
        p_guardian_first_name   IN patient.guardian_first_name%TYPE  DEFAULT NULL,
        p_guardian_last_name    IN patient.guardian_last_name%TYPE   DEFAULT NULL,
        p_guardian_relationship IN patient.guardian_relationship%TYPE DEFAULT NULL,
        p_guardian_phone        IN patient.guardian_phone%TYPE       DEFAULT NULL,
        p_guardian_email        IN patient.guardian_email%TYPE       DEFAULT NULL,
        p_patient_id            OUT patient.patient_id%TYPE,
        p_status_code           OUT INTEGER,
        p_error_message         OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 2: SP_UPDATE_PATIENT
    -- =========================================================
    -- Purpose: Update patient details (flexible - only provided fields)
    -- Business Rules:
    --   1. Patient must exist
    --   2. If phone changed, must be unique
    --   3. Insurance (if changed) must be ACTIVE and not expired
    --   4. Status must be valid (ACTIVE, INACTIVE, DISCHARGED, DECEASED)
    -- Error Codes: -20010 to -20014
    -- =========================================================
    PROCEDURE sp_update_patient (
        p_patient_id            IN patient.patient_id%TYPE,
        p_first_name            IN patient.first_name%TYPE     DEFAULT NULL,
        p_last_name             IN patient.last_name%TYPE      DEFAULT NULL,
        p_phone                 IN patient.phone%TYPE          DEFAULT NULL,
        p_email                 IN patient.email%TYPE          DEFAULT NULL,
        p_blood_type            IN patient.blood_type%TYPE     DEFAULT NULL,
        p_city                  IN patient.city%TYPE           DEFAULT NULL,
        p_state                 IN patient.state%TYPE          DEFAULT NULL,
        p_zip_code              IN patient.zip_code%TYPE       DEFAULT NULL,
        p_address               IN patient.address%TYPE        DEFAULT NULL,
        p_insurance_id          IN patient.insurance_id%TYPE   DEFAULT NULL,
        p_status                IN patient.status%TYPE         DEFAULT NULL,
        p_modified_by           IN patient.modified_by%TYPE,
        p_status_code           OUT INTEGER,
        p_error_message         OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 3: SP_GET_PATIENT
    -- =========================================================
    -- Purpose: Retrieve complete patient profile with insurance details
    -- Output: SYS_REFCURSOR with patient and insurance information
    -- Business Rules:
    --   1. Patient must exist
    --   2. Returns calculated age from DOB
    -- Error Codes: -20020, -20021
    -- =========================================================
    PROCEDURE sp_get_patient (
        p_patient_id        IN patient.patient_id%TYPE,
        p_patient_cursor    OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 4: SP_SEARCH_PATIENT
    -- =========================================================
    -- Purpose: Search patients by phone, email, or name
    -- Parameters:
    --   p_search_type: PHONE, EMAIL, NAME (case-insensitive for EMAIL and NAME)
    --   p_search_value: Partial match supported with LIKE wildcard
    -- Output: Cursor with matching patients
    -- Error Codes: -20030 to -20033
    -- =========================================================
    PROCEDURE sp_search_patient (
        p_search_type       IN VARCHAR2,
        p_search_value      IN VARCHAR2,
        p_results_cursor    OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 5: SP_GET_PATIENT_HISTORY
    -- =========================================================
    -- Purpose: Retrieve patient's medical history (appointments + prescriptions)
    -- Business Rules:
    --   1. Patient must exist
    --   2. Returns only COMPLETED and NO_SHOW appointments
    --   3. Includes medication count per appointment
    -- Output: Cursor with appointment and prescription history
    -- Error Codes: -20040 to -20042
    -- =========================================================
    PROCEDURE sp_get_patient_history (
        p_patient_id        IN patient.patient_id%TYPE,
        p_history_cursor    OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 6: SP_LINK_INSURANCE
    -- =========================================================
    -- Purpose: Link or update insurance for patient
    -- Business Rules:
    --   1. Patient must exist
    --   2. Insurance must exist
    --   3. Insurance must be ACTIVE
    --   4. Insurance must not be expired
    -- Error Codes: -20050 to -20053
    -- =========================================================
    PROCEDURE sp_link_insurance (
        p_patient_id        IN patient.patient_id%TYPE,
        p_insurance_id      IN patient.insurance_id%TYPE,
        p_modified_by       IN patient.modified_by%TYPE,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 7: SP_CHANGE_PATIENT_STATUS
    -- =========================================================
    -- Purpose: Change patient status (ACTIVE, INACTIVE, DISCHARGED, DECEASED)
    -- Business Rules:
    --   1. Patient must exist
    --   2. Status must be valid
    --   3. Cannot DISCHARGE if patient has pending/partially paid bills
    --   4. Cannot DISCHARGE if patient has active appointments
    -- Error Codes: -20060 to -20063
    -- =========================================================
    PROCEDURE sp_change_patient_status (
        p_patient_id        IN patient.patient_id%TYPE,
        p_new_status        IN patient.status%TYPE,
        p_modified_by       IN patient.modified_by%TYPE,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 8: SP_DELETE_PATIENT
    -- =========================================================
    -- Purpose: Soft delete patient (mark as INACTIVE)
    --          or hard delete if no dependent records
    -- Business Rules:
    --   1. Patient must exist
    --   2. Cannot hard delete if appointments exist
    --   3. Cannot hard delete if bills exist
    --   4. Can soft delete (mark INACTIVE) anytime
    -- Error Codes: -20070 to -20073
    -- =========================================================
    PROCEDURE sp_delete_patient (
        p_patient_id        IN patient.patient_id%TYPE,
        p_delete_type       IN VARCHAR2 DEFAULT 'SOFT',
        p_modified_by       IN patient.modified_by%TYPE,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 9: SP_GET_PATIENT_BILLS
    -- =========================================================
    -- Purpose: Retrieve patient's billing history
    -- Business Rules:
    --   1. Patient must exist
    --   2. Returns all bills with payment status
    --   3. Calculates outstanding balance per bill
    -- Output: Cursor with bill details and payment status
    -- Error Codes: -20080 to -20082
    -- =========================================================
    PROCEDURE sp_get_patient_bills (
        p_patient_id        IN patient.patient_id%TYPE,
        p_bills_cursor      OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    );

    -- =========================================================
    -- PROCEDURE 10: SP_VALIDATE_PATIENT_FOR_APPOINTMENT
    -- =========================================================
    -- Purpose: Validate patient before appointment scheduling
    -- Business Rules:
    --   1. Patient must exist
    --   2. Patient must be ACTIVE
    --   3. Patient must not be DECEASED
    --   4. Returns patient details if valid
    -- Output: Cursor with patient validation info
    -- Error Codes: -20090 to -20093
    -- =========================================================
    PROCEDURE sp_validate_patient_for_appointment (
        p_patient_id        IN patient.patient_id%TYPE,
        p_validation_cursor OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    );

END pkg_patient_mgmt;
/

-- Show compilation errors
SHOW ERRORS PACKAGE pkg_patient_mgmt;


-- =============================================================
-- PACKAGE BODY IMPLEMENTATION
-- =============================================================

CREATE OR REPLACE PACKAGE BODY pkg_patient_mgmt AS

    -- =========================================================
    -- PROCEDURE 1: SP_REGISTER_PATIENT
    -- =========================================================
    PROCEDURE sp_register_patient (
        p_first_name            IN patient.first_name%TYPE,
        p_last_name             IN patient.last_name%TYPE,
        p_dob                   IN patient.date_of_birth%TYPE,
        p_gender                IN patient.gender%TYPE,
        p_phone                 IN patient.phone%TYPE,
        p_email                 IN patient.email%TYPE         DEFAULT NULL,
        p_blood_type            IN patient.blood_type%TYPE    DEFAULT NULL,
        p_city                  IN patient.city%TYPE          DEFAULT NULL,
        p_state                 IN patient.state%TYPE         DEFAULT NULL,
        p_zip_code              IN patient.zip_code%TYPE      DEFAULT NULL,
        p_address               IN patient.address%TYPE       DEFAULT NULL,
        p_insurance_id          IN patient.insurance_id%TYPE  DEFAULT NULL,
        p_guardian_first_name   IN patient.guardian_first_name%TYPE  DEFAULT NULL,
        p_guardian_last_name    IN patient.guardian_last_name%TYPE   DEFAULT NULL,
        p_guardian_relationship IN patient.guardian_relationship%TYPE DEFAULT NULL,
        p_guardian_phone        IN patient.guardian_phone%TYPE       DEFAULT NULL,
        p_guardian_email        IN patient.guardian_email%TYPE       DEFAULT NULL,
        p_patient_id            OUT patient.patient_id%TYPE,
        p_status_code           OUT INTEGER,
        p_error_message         OUT VARCHAR2
    ) IS
        v_age                NUMBER;
        v_phone_count       INTEGER;
        v_insurance_status  insurance.status%TYPE;
        v_insurance_expiry  insurance.policy_expiry_date%TYPE;
        v_email_valid       BOOLEAN := TRUE;
        
    BEGIN
        -- Initialize output parameters
        p_patient_id := NULL;
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION 1: Phone uniqueness
        -- =====================================================
        BEGIN
            SELECT COUNT(*) INTO v_phone_count FROM patient 
            WHERE phone = p_phone;
            
            IF v_phone_count > 0 THEN
                p_status_code := -20001;
                p_error_message := 'ERR_DUPLICATE_PHONE: Phone number ' || p_phone || 
                                   ' is already registered to another patient.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20001;
                    p_error_message := 'ERR_PHONE_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 2: Date of birth validation
        -- =====================================================
        BEGIN
            IF p_dob > SYSDATE THEN
                p_status_code := -20002;
                p_error_message := 'ERR_INVALID_DOB: Date of birth cannot be in the future.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
            
            v_age := TRUNC(MONTHS_BETWEEN(SYSDATE, p_dob) / 12);
            
            IF v_age < 0 THEN
                p_status_code := -20002;
                p_error_message := 'ERR_INVALID_DOB: Calculated age is negative.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20002;
                    p_error_message := 'ERR_DOB_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 3: Minor must have guardian
        -- =====================================================
        BEGIN
            IF v_age < 18 THEN
                IF p_guardian_first_name IS NULL OR p_guardian_phone IS NULL THEN
                    p_status_code := -20003;
                    p_error_message := 'ERR_MINOR_NO_GUARDIAN: Minor patient (Age: ' || v_age || 
                                       ') must have guardian first name and phone.';
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20003;
                    p_error_message := 'ERR_GUARDIAN_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 4: Email format (if provided)
        -- =====================================================
        BEGIN
            IF p_email IS NOT NULL THEN
                IF NOT (p_email LIKE '%@%' AND p_email LIKE '%.%') THEN
                    p_status_code := -20003;
                    p_error_message := 'ERR_INVALID_EMAIL: Email format is invalid. ' ||
                                       'Must contain @ and .';
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20003;
                    p_error_message := 'ERR_EMAIL_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 5: Insurance validation (if provided)
        -- =====================================================
        BEGIN
            IF p_insurance_id IS NOT NULL THEN
                SELECT status, policy_expiry_date
                INTO v_insurance_status, v_insurance_expiry
                FROM insurance
                WHERE insurance_id = p_insurance_id;

                IF v_insurance_status != 'ACTIVE' THEN
                    p_status_code := -20004;
                    p_error_message := 'ERR_INSURANCE_NOT_ACTIVE: Insurance must be ACTIVE. ' ||
                                       'Current status: ' || v_insurance_status;
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;

                IF v_insurance_expiry < SYSDATE THEN
                    p_status_code := -20004;
                    p_error_message := 'ERR_INSURANCE_EXPIRED: Insurance expired on ' || 
                                       TO_CHAR(v_insurance_expiry, 'DD-MON-YYYY');
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_status_code := -20004;
                p_error_message := 'ERR_INSURANCE_NOT_FOUND: Insurance ID ' || p_insurance_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20004;
                    p_error_message := 'ERR_INSURANCE_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- INSERT PATIENT
        -- =====================================================
        BEGIN
            INSERT INTO patient (
                first_name, last_name, date_of_birth, gender, phone, email,
                blood_type, city, state, zip_code, address, insurance_id,
                guardian_first_name, guardian_last_name, guardian_relationship,
                guardian_phone, guardian_email, status
            ) VALUES (
                p_first_name, p_last_name, p_dob, p_gender, p_phone, p_email,
                p_blood_type, p_city, p_state, p_zip_code, p_address, p_insurance_id,
                p_guardian_first_name, p_guardian_last_name, p_guardian_relationship,
                p_guardian_phone, p_guardian_email, 'ACTIVE'
            );

            -- Retrieve newly created patient ID using sequence
            -- The trigger will auto-assign the ID, so we fetch it back
            SELECT patient_id INTO p_patient_id FROM patient
            WHERE phone = p_phone AND first_name = p_first_name
            AND last_name = p_last_name;

            -- Success message
            p_status_code := 0;
            p_error_message := 'SUCCESS: Patient registered successfully. ' ||
                               'Patient ID: ' || p_patient_id || ', Age: ' || v_age || ', Status: ACTIVE';

            COMMIT;

        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                p_status_code := -20005;
                p_error_message := 'ERR_DUPLICATE_RECORD: Duplicate phone or email detected.';
                ROLLBACK;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            WHEN OTHERS THEN
                p_status_code := -20005;
                p_error_message := 'ERR_PATIENT_INSERT: Patient registration failed: ' || SQLERRM;
                ROLLBACK;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

    EXCEPTION
        WHEN OTHERS THEN
            -- Top-level exception handler
            IF p_status_code = 0 THEN
                p_status_code := -20005;
                p_error_message := 'ERR_REGISTER_PATIENT: Unexpected error: ' || SQLERRM;
            END IF;
            ROLLBACK;
    END sp_register_patient;


    -- =========================================================
    -- PROCEDURE 2: SP_UPDATE_PATIENT
    -- =========================================================
    PROCEDURE sp_update_patient (
        p_patient_id            IN patient.patient_id%TYPE,
        p_first_name            IN patient.first_name%TYPE     DEFAULT NULL,
        p_last_name             IN patient.last_name%TYPE      DEFAULT NULL,
        p_phone                 IN patient.phone%TYPE          DEFAULT NULL,
        p_email                 IN patient.email%TYPE          DEFAULT NULL,
        p_blood_type            IN patient.blood_type%TYPE     DEFAULT NULL,
        p_city                  IN patient.city%TYPE           DEFAULT NULL,
        p_state                 IN patient.state%TYPE          DEFAULT NULL,
        p_zip_code              IN patient.zip_code%TYPE       DEFAULT NULL,
        p_address               IN patient.address%TYPE        DEFAULT NULL,
        p_insurance_id          IN patient.insurance_id%TYPE   DEFAULT NULL,
        p_status                IN patient.status%TYPE         DEFAULT NULL,
        p_modified_by           IN patient.modified_by%TYPE,
        p_status_code           OUT INTEGER,
        p_error_message         OUT VARCHAR2
    ) IS
        v_patient_exists    INTEGER;
        v_current_phone     patient.phone%TYPE;
        v_phone_count       INTEGER;
        v_insurance_status  insurance.status%TYPE;
        v_insurance_expiry  insurance.policy_expiry_date%TYPE;
        v_updated_fields    INTEGER := 0;

    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION 1: Patient exists
        -- =====================================================
        BEGIN
            SELECT COUNT(*) INTO v_patient_exists FROM patient 
            WHERE patient_id = p_patient_id;
            
            IF v_patient_exists = 0 THEN
                p_status_code := -20010;
                p_error_message := 'ERR_PATIENT_NOT_FOUND: Patient ID ' || p_patient_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20010;
                    p_error_message := 'ERR_PATIENT_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 2: Phone uniqueness (if changed)
        -- =====================================================
        BEGIN
            IF p_phone IS NOT NULL THEN
                SELECT phone INTO v_current_phone FROM patient 
                WHERE patient_id = p_patient_id;
                
                IF p_phone != v_current_phone THEN
                    SELECT COUNT(*) INTO v_phone_count FROM patient
                    WHERE phone = p_phone AND patient_id != p_patient_id;
                    
                    IF v_phone_count > 0 THEN
                        p_status_code := -20011;
                        p_error_message := 'ERR_DUPLICATE_PHONE: Phone ' || p_phone || 
                                           ' is already registered to another patient.';
                        RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20011;
                    p_error_message := 'ERR_PHONE_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 3: Status validation (if changed)
        -- =====================================================
        BEGIN
            IF p_status IS NOT NULL THEN
                IF p_status NOT IN ('ACTIVE', 'INACTIVE', 'DISCHARGED', 'DECEASED') THEN
                    p_status_code := -20012;
                    p_error_message := 'ERR_INVALID_STATUS: Status must be ACTIVE, INACTIVE, ' ||
                                       'DISCHARGED, or DECEASED.';
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20012;
                    p_error_message := 'ERR_STATUS_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 4: Insurance validation (if changed)
        -- =====================================================
        BEGIN
            IF p_insurance_id IS NOT NULL THEN
                SELECT status, policy_expiry_date
                INTO v_insurance_status, v_insurance_expiry
                FROM insurance
                WHERE insurance_id = p_insurance_id;

                IF v_insurance_status != 'ACTIVE' THEN
                    p_status_code := -20012;
                    p_error_message := 'ERR_INSURANCE_NOT_ACTIVE: Insurance must be ACTIVE. ' ||
                                       'Current status: ' || v_insurance_status;
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;

                IF v_insurance_expiry < SYSDATE THEN
                    p_status_code := -20012;
                    p_error_message := 'ERR_INSURANCE_EXPIRED: Insurance expired on ' || 
                                       TO_CHAR(v_insurance_expiry, 'DD-MON-YYYY');
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_status_code := -20012;
                p_error_message := 'ERR_INSURANCE_NOT_FOUND: Insurance ID ' || p_insurance_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20012;
                    p_error_message := 'ERR_INSURANCE_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- UPDATE PATIENT
        -- =====================================================
        BEGIN
            UPDATE patient SET
                first_name      = NVL(p_first_name, first_name),
                last_name       = NVL(p_last_name, last_name),
                phone           = NVL(p_phone, phone),
                email           = NVL(p_email, email),
                blood_type      = NVL(p_blood_type, blood_type),
                city            = NVL(p_city, city),
                state           = NVL(p_state, state),
                zip_code        = NVL(p_zip_code, zip_code),
                address         = NVL(p_address, address),
                insurance_id    = NVL(p_insurance_id, insurance_id),
                status          = NVL(p_status, status),
                modified_by     = p_modified_by,
                modified_date   = SYSDATE
            WHERE patient_id = p_patient_id;

            -- Count updated fields
            IF p_first_name IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_last_name IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_phone IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_email IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_blood_type IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_city IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_state IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_zip_code IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_address IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_insurance_id IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;
            IF p_status IS NOT NULL THEN v_updated_fields := v_updated_fields + 1; END IF;

            p_status_code := 0;
            p_error_message := 'SUCCESS: Patient updated successfully. ' ||
                               'Fields updated: ' || v_updated_fields || ', Updated by: ' || p_modified_by;

            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                p_status_code := -20013;
                p_error_message := 'ERR_PATIENT_UPDATE: Update failed: ' || SQLERRM;
                ROLLBACK;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20014;
                p_error_message := 'ERR_UPDATE_PATIENT: Unexpected error: ' || SQLERRM;
            END IF;
            ROLLBACK;
    END sp_update_patient;


    -- =========================================================
    -- PROCEDURE 3: SP_GET_PATIENT
    -- =========================================================
    PROCEDURE sp_get_patient (
        p_patient_id        IN patient.patient_id%TYPE,
        p_patient_cursor    OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    ) IS
        v_patient_exists    INTEGER;

    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION: Patient exists
        -- =====================================================
        BEGIN
            SELECT COUNT(*) INTO v_patient_exists FROM patient 
            WHERE patient_id = p_patient_id;
            
            IF v_patient_exists = 0 THEN
                p_status_code := -20020;
                p_error_message := 'ERR_PATIENT_NOT_FOUND: Patient ID ' || p_patient_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20020;
                    p_error_message := 'ERR_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- OPEN CURSOR with patient and insurance details
        -- =====================================================
        BEGIN
            OPEN p_patient_cursor FOR
                SELECT
                    pat.patient_id,
                    pat.first_name,
                    pat.last_name,
                    pat.date_of_birth,
                    TRUNC(MONTHS_BETWEEN(SYSDATE, pat.date_of_birth) / 12) AS age,
                    pat.gender,
                    pat.phone,
                    pat.email,
                    pat.blood_type,
                    CASE WHEN pat.is_minor = 'Y' THEN 'Minor' ELSE 'Adult' END AS age_status,
                    pat.status,
                    pat.city,
                    pat.state,
                    pat.zip_code,
                    pat.address,
                    pat.insurance_id,
                    ins.provider_name AS insurance_provider,
                    ins.policy_number,
                    ins.coverage_percentage,
                    ins.status AS insurance_status,
                    TO_DATE(ins.policy_expiry_date, 'DD-MON-YYYY') AS insurance_expiry_date,
                    pat.guardian_first_name,
                    pat.guardian_last_name,
                    pat.guardian_relationship,
                    pat.guardian_phone,
                    pat.guardian_email,
                    TO_CHAR(pat.registration_date, 'DD-MON-YYYY HH24:MI:SS') AS registration_date,
                    TO_CHAR(pat.modified_date, 'DD-MON-YYYY HH24:MI:SS') AS last_modified_date,
                    pat.modified_by
                FROM patient pat
                LEFT JOIN insurance ins ON pat.insurance_id = ins.insurance_id
                WHERE pat.patient_id = p_patient_id;

            p_status_code := 0;
            p_error_message := 'SUCCESS: Patient details retrieved.';

        EXCEPTION
            WHEN OTHERS THEN
                p_status_code := -20021;
                p_error_message := 'ERR_CURSOR_OPEN: Error retrieving patient: ' || SQLERRM;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20021;
                p_error_message := 'ERR_GET_PATIENT: Unexpected error: ' || SQLERRM;
            END IF;
    END sp_get_patient;


    -- =========================================================
    -- PROCEDURE 4: SP_SEARCH_PATIENT
    -- =========================================================
    PROCEDURE sp_search_patient (
        p_search_type       IN VARCHAR2,
        p_search_value      IN VARCHAR2,
        p_results_cursor    OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    ) IS
    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- SEARCH BY PHONE
        -- =====================================================
        IF UPPER(p_search_type) = 'PHONE' THEN
            BEGIN
                OPEN p_results_cursor FOR
                    SELECT 
                        patient_id, 
                        first_name, 
                        last_name, 
                        phone, 
                        email, 
                        status,
                        TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth) / 12) AS age
                    FROM patient
                    WHERE phone LIKE '%' || p_search_value || '%'
                    ORDER BY first_name, last_name;

                p_status_code := 0;
                p_error_message := 'SUCCESS: Search by PHONE completed.';

            EXCEPTION
                WHEN OTHERS THEN
                    p_status_code := -20033;
                    p_error_message := 'ERR_PHONE_SEARCH: ' || SQLERRM;
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END;

        -- =====================================================
        -- SEARCH BY EMAIL
        -- =====================================================
        ELSIF UPPER(p_search_type) = 'EMAIL' THEN
            BEGIN
                OPEN p_results_cursor FOR
                    SELECT 
                        patient_id, 
                        first_name, 
                        last_name, 
                        phone, 
                        email, 
                        status,
                        TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth) / 12) AS age
                    FROM patient
                    WHERE LOWER(email) LIKE '%' || LOWER(p_search_value) || '%'
                    ORDER BY first_name, last_name;

                p_status_code := 0;
                p_error_message := 'SUCCESS: Search by EMAIL completed.';

            EXCEPTION
                WHEN OTHERS THEN
                    p_status_code := -20033;
                    p_error_message := 'ERR_EMAIL_SEARCH: ' || SQLERRM;
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END;

        -- =====================================================
        -- SEARCH BY NAME
        -- =====================================================
        ELSIF UPPER(p_search_type) = 'NAME' THEN
            BEGIN
                OPEN p_results_cursor FOR
                    SELECT 
                        patient_id, 
                        first_name, 
                        last_name, 
                        phone, 
                        email, 
                        status,
                        TRUNC(MONTHS_BETWEEN(SYSDATE, date_of_birth) / 12) AS age
                    FROM patient
                    WHERE UPPER(first_name) LIKE '%' || UPPER(p_search_value) || '%'
                       OR UPPER(last_name) LIKE '%' || UPPER(p_search_value) || '%'
                    ORDER BY first_name, last_name;

                p_status_code := 0;
                p_error_message := 'SUCCESS: Search by NAME completed.';

            EXCEPTION
                WHEN OTHERS THEN
                    p_status_code := -20033;
                    p_error_message := 'ERR_NAME_SEARCH: ' || SQLERRM;
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END;

        -- =====================================================
        -- INVALID SEARCH TYPE
        -- =====================================================
        ELSE
            p_status_code := -20030;
            p_error_message := 'ERR_INVALID_SEARCH_TYPE: Search type must be PHONE, EMAIL, or NAME.';
            RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20032;
                p_error_message := 'ERR_SEARCH_PATIENT: Unexpected error: ' || SQLERRM;
            END IF;
    END sp_search_patient;


    -- =========================================================
    -- PROCEDURE 5: SP_GET_PATIENT_HISTORY
    -- =========================================================
    PROCEDURE sp_get_patient_history (
        p_patient_id        IN patient.patient_id%TYPE,
        p_history_cursor    OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    ) IS
        v_patient_exists    INTEGER;

    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION: Patient exists
        -- =====================================================
        BEGIN
            SELECT COUNT(*) INTO v_patient_exists FROM patient 
            WHERE patient_id = p_patient_id;
            
            IF v_patient_exists = 0 THEN
                p_status_code := -20040;
                p_error_message := 'ERR_PATIENT_NOT_FOUND: Patient ID ' || p_patient_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20040;
                    p_error_message := 'ERR_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- OPEN CURSOR with appointment and prescription history
        -- =====================================================
        BEGIN
            OPEN p_history_cursor FOR
                SELECT
                    apt.appointment_id,
                    TO_CHAR(apt.appointment_date, 'DD-MON-YYYY') AS appointment_date,
                    apt.appointment_time,
                    apt.reason,
                    apt.status AS appointment_status,
                    apt.notes,
                    prs.prescription_id,
                    TO_CHAR(prs.prescribed_date, 'DD-MON-YYYY') AS prescribed_date,
                    COUNT(pri.item_id) AS medication_count
                FROM appointment apt
                LEFT JOIN prescription prs ON apt.appointment_id = prs.appointment_id
                LEFT JOIN prescription_item pri ON prs.prescription_id = pri.prescription_id
                WHERE apt.patient_id = p_patient_id
                AND apt.status IN ('COMPLETED', 'NO_SHOW')
                GROUP BY apt.appointment_id, apt.appointment_date, apt.appointment_time,
                         apt.reason, apt.status, apt.notes, prs.prescription_id, prs.prescribed_date
                ORDER BY apt.appointment_date DESC;

            p_status_code := 0;
            p_error_message := 'SUCCESS: Medical history retrieved.';

        EXCEPTION
            WHEN OTHERS THEN
                p_status_code := -20042;
                p_error_message := 'ERR_CURSOR_OPEN: Error retrieving history: ' || SQLERRM;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20042;
                p_error_message := 'ERR_GET_HISTORY: Unexpected error: ' || SQLERRM;
            END IF;
    END sp_get_patient_history;


    -- =========================================================
    -- PROCEDURE 6: SP_LINK_INSURANCE
    -- =========================================================
    PROCEDURE sp_link_insurance (
        p_patient_id        IN patient.patient_id%TYPE,
        p_insurance_id      IN patient.insurance_id%TYPE,
        p_modified_by       IN patient.modified_by%TYPE,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    ) IS
        v_patient_exists    INTEGER;
        v_insurance_status  insurance.status%TYPE;
        v_insurance_expiry  insurance.policy_expiry_date%TYPE;
        v_provider_name     insurance.provider_name%TYPE;

    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION 1: Patient exists
        -- =====================================================
        BEGIN
            SELECT COUNT(*) INTO v_patient_exists FROM patient 
            WHERE patient_id = p_patient_id;
            
            IF v_patient_exists = 0 THEN
                p_status_code := -20050;
                p_error_message := 'ERR_PATIENT_NOT_FOUND: Patient ID ' || p_patient_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20050;
                    p_error_message := 'ERR_PATIENT_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 2: Insurance exists and is valid
        -- =====================================================
        BEGIN
            SELECT status, policy_expiry_date, provider_name
            INTO v_insurance_status, v_insurance_expiry, v_provider_name
            FROM insurance
            WHERE insurance_id = p_insurance_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_status_code := -20051;
                p_error_message := 'ERR_INSURANCE_NOT_FOUND: Insurance ID ' || p_insurance_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            WHEN OTHERS THEN
                p_status_code := -20051;
                p_error_message := 'ERR_INSURANCE_QUERY: ' || SQLERRM;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

        -- =====================================================
        -- VALIDATION 3: Insurance must be ACTIVE
        -- =====================================================
        BEGIN
            IF v_insurance_status != 'ACTIVE' THEN
                p_status_code := -20052;
                p_error_message := 'ERR_INSURANCE_NOT_ACTIVE: Insurance must be ACTIVE. ' ||
                                   'Current status: ' || v_insurance_status;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20052;
                    p_error_message := 'ERR_STATUS_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 4: Insurance must not be expired
        -- =====================================================
        BEGIN
            IF v_insurance_expiry < SYSDATE THEN
                p_status_code := -20052;
                p_error_message := 'ERR_INSURANCE_EXPIRED: Insurance expired on ' || 
                                   TO_CHAR(v_insurance_expiry, 'DD-MON-YYYY');
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20052;
                    p_error_message := 'ERR_EXPIRY_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- LINK INSURANCE TO PATIENT
        -- =====================================================
        BEGIN
            UPDATE patient SET
                insurance_id = p_insurance_id,
                modified_by = p_modified_by,
                modified_date = SYSDATE
            WHERE patient_id = p_patient_id;

            p_status_code := 0;
            p_error_message := 'SUCCESS: Insurance linked successfully. ' ||
                               'Provider: ' || v_provider_name || ', ' ||
                               'Updated by: ' || p_modified_by;

            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                p_status_code := -20053;
                p_error_message := 'ERR_UPDATE_FAILED: Insurance linking failed: ' || SQLERRM;
                ROLLBACK;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20053;
                p_error_message := 'ERR_LINK_INSURANCE: Unexpected error: ' || SQLERRM;
            END IF;
            ROLLBACK;
    END sp_link_insurance;


    -- =========================================================
    -- PROCEDURE 7: SP_CHANGE_PATIENT_STATUS
    -- =========================================================
    PROCEDURE sp_change_patient_status (
        p_patient_id        IN patient.patient_id%TYPE,
        p_new_status        IN patient.status%TYPE,
        p_modified_by       IN patient.modified_by%TYPE,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    ) IS
        v_patient_exists    INTEGER;
        v_pending_bills     INTEGER;
        v_active_appts      INTEGER;
        v_current_name      patient.first_name%TYPE;

    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION 1: Patient exists
        -- =====================================================
        BEGIN
            SELECT COUNT(*), MAX(first_name)
            INTO v_patient_exists, v_current_name
            FROM patient
            WHERE patient_id = p_patient_id;
            
            IF v_patient_exists = 0 THEN
                p_status_code := -20060;
                p_error_message := 'ERR_PATIENT_NOT_FOUND: Patient ID ' || p_patient_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20060;
                    p_error_message := 'ERR_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 2: Status is valid
        -- =====================================================
        BEGIN
            IF p_new_status NOT IN ('ACTIVE', 'INACTIVE', 'DISCHARGED', 'DECEASED') THEN
                p_status_code := -20061;
                p_error_message := 'ERR_INVALID_STATUS: Status must be ACTIVE, INACTIVE, ' ||
                                   'DISCHARGED, or DECEASED. Provided: ' || p_new_status;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20061;
                    p_error_message := 'ERR_STATUS_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 3: Cannot discharge with pending bills
        -- =====================================================
        BEGIN
            IF p_new_status = 'DISCHARGED' THEN
                SELECT COUNT(*) INTO v_pending_bills FROM bill
                WHERE patient_id = p_patient_id
                AND status IN ('PENDING', 'PARTIALLY_PAID');

                IF v_pending_bills > 0 THEN
                    p_status_code := -20062;
                    p_error_message := 'ERR_PENDING_BILLS: Cannot discharge patient ' || v_current_name || 
                                       ' with ' || v_pending_bills || ' pending/partially paid bills.';
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20062;
                    p_error_message := 'ERR_BILL_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 4: Cannot discharge with active appointments
        -- =====================================================
        BEGIN
            IF p_new_status = 'DISCHARGED' THEN
                SELECT COUNT(*) INTO v_active_appts FROM appointment
                WHERE patient_id = p_patient_id
                AND status IN ('SCHEDULED', 'RESCHEDULED');

                IF v_active_appts > 0 THEN
                    p_status_code := -20062;
                    p_error_message := 'ERR_ACTIVE_APPOINTMENTS: Cannot discharge patient with ' || 
                                       v_active_appts || ' active appointments.';
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20062;
                    p_error_message := 'ERR_APPOINTMENT_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- UPDATE PATIENT STATUS
        -- =====================================================
        BEGIN
            UPDATE patient SET
                status = p_new_status,
                modified_by = p_modified_by,
                modified_date = SYSDATE
            WHERE patient_id = p_patient_id;

            p_status_code := 0;
            p_error_message := 'SUCCESS: Patient status changed to ' || p_new_status || 
                               ' for ' || v_current_name || ', Updated by: ' || p_modified_by;

            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                p_status_code := -20063;
                p_error_message := 'ERR_UPDATE_FAILED: Status change failed: ' || SQLERRM;
                ROLLBACK;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20063;
                p_error_message := 'ERR_CHANGE_STATUS: Unexpected error: ' || SQLERRM;
            END IF;
            ROLLBACK;
    END sp_change_patient_status;


    -- =========================================================
    -- PROCEDURE 8: SP_DELETE_PATIENT
    -- =========================================================
    PROCEDURE sp_delete_patient (
        p_patient_id        IN patient.patient_id%TYPE,
        p_delete_type       IN VARCHAR2 DEFAULT 'SOFT',
        p_modified_by       IN patient.modified_by%TYPE,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    ) IS
        v_patient_exists    INTEGER;
        v_appointment_count INTEGER;
        v_bill_count        INTEGER;
        v_patient_name      patient.first_name%TYPE;

    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION 1: Patient exists
        -- =====================================================
        BEGIN
            SELECT COUNT(*), MAX(first_name)
            INTO v_patient_exists, v_patient_name
            FROM patient
            WHERE patient_id = p_patient_id;
            
            IF v_patient_exists = 0 THEN
                p_status_code := -20070;
                p_error_message := 'ERR_PATIENT_NOT_FOUND: Patient ID ' || p_patient_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20070;
                    p_error_message := 'ERR_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION 2: Delete type is valid
        -- =====================================================
        BEGIN
            IF UPPER(p_delete_type) NOT IN ('SOFT', 'HARD') THEN
                p_status_code := -20071;
                p_error_message := 'ERR_INVALID_DELETE_TYPE: Delete type must be SOFT or HARD.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20071;
                    p_error_message := 'ERR_DELETE_TYPE_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- SOFT DELETE: Mark as INACTIVE
        -- =====================================================
        IF UPPER(p_delete_type) = 'SOFT' THEN
            BEGIN
                UPDATE patient SET
                    status = 'INACTIVE',
                    modified_by = p_modified_by,
                    modified_date = SYSDATE
                WHERE patient_id = p_patient_id;

                p_status_code := 0;
                p_error_message := 'SUCCESS: Patient ' || v_patient_name || 
                                   ' marked as INACTIVE (soft delete).';
                COMMIT;

            EXCEPTION
                WHEN OTHERS THEN
                    p_status_code := -20072;
                    p_error_message := 'ERR_SOFT_DELETE: Soft delete failed: ' || SQLERRM;
                    ROLLBACK;
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END;

        -- =====================================================
        -- HARD DELETE: Physical removal from database
        -- =====================================================
        ELSE
            BEGIN
                -- Check for appointments
                SELECT COUNT(*) INTO v_appointment_count FROM appointment
                WHERE patient_id = p_patient_id;

                IF v_appointment_count > 0 THEN
                    p_status_code := -20072;
                    p_error_message := 'ERR_HARD_DELETE_FAILED: Cannot hard delete patient ' || 
                                       v_patient_name || ' with ' || v_appointment_count || 
                                       ' dependent appointments.';
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;

                -- Check for bills
                SELECT COUNT(*) INTO v_bill_count FROM bill
                WHERE patient_id = p_patient_id;

                IF v_bill_count > 0 THEN
                    p_status_code := -20072;
                    p_error_message := 'ERR_HARD_DELETE_FAILED: Cannot hard delete patient ' || 
                                       v_patient_name || ' with ' || v_bill_count || 
                                       ' dependent bills.';
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
                END IF;

                -- Perform hard delete
                DELETE FROM patient WHERE patient_id = p_patient_id;

                p_status_code := 0;
                p_error_message := 'SUCCESS: Patient ' || v_patient_name || 
                                   ' permanently deleted from system (hard delete).';
                COMMIT;

            EXCEPTION
                WHEN OTHERS THEN
                    p_status_code := -20073;
                    p_error_message := 'ERR_HARD_DELETE: Hard delete failed: ' || SQLERRM;
                    ROLLBACK;
                    RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20073;
                p_error_message := 'ERR_DELETE_PATIENT: Unexpected error: ' || SQLERRM;
            END IF;
            ROLLBACK;
    END sp_delete_patient;


    -- =========================================================
    -- PROCEDURE 9: SP_GET_PATIENT_BILLS
    -- =========================================================
    PROCEDURE sp_get_patient_bills (
        p_patient_id        IN patient.patient_id%TYPE,
        p_bills_cursor      OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    ) IS
        v_patient_exists    INTEGER;

    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION: Patient exists
        -- =====================================================
        BEGIN
            SELECT COUNT(*) INTO v_patient_exists FROM patient 
            WHERE patient_id = p_patient_id;
            
            IF v_patient_exists = 0 THEN
                p_status_code := -20080;
                p_error_message := 'ERR_PATIENT_NOT_FOUND: Patient ID ' || p_patient_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20080;
                    p_error_message := 'ERR_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- OPEN CURSOR with bill details and payment status
        -- =====================================================
        BEGIN
            OPEN p_bills_cursor FOR
                SELECT
                    b.bill_id,
                    TO_CHAR(b.bill_date, 'DD-MON-YYYY') AS bill_date,
                    b.service_charges,
                    b.room_charges,
                    b.medication_charges,
                    b.other_charges,
                    b.total_amount,
                    b.insurance_coverage_amt,
                    b.discount_amount,
                    b.net_amount,
                    NVL(SUM(p.amount_paid), 0) AS amount_paid,
                    (b.net_amount - NVL(SUM(p.amount_paid), 0)) AS outstanding_balance,
                    b.status,
                    a.appointment_id,
                    TO_CHAR(a.appointment_date, 'DD-MON-YYYY') AS appointment_date,
                    TO_CHAR(b.modified_date, 'DD-MON-YYYY HH24:MI:SS') AS last_modified
                FROM bill b
                LEFT JOIN payment p ON b.bill_id = p.bill_id
                LEFT JOIN appointment a ON b.appointment_id = a.appointment_id
                WHERE b.patient_id = p_patient_id
                GROUP BY b.bill_id, b.bill_date, b.service_charges, b.room_charges,
                         b.medication_charges, b.other_charges, b.total_amount,
                         b.insurance_coverage_amt, b.discount_amount, b.net_amount,
                         b.status, a.appointment_id, a.appointment_date, b.modified_date
                ORDER BY b.bill_date DESC;

            p_status_code := 0;
            p_error_message := 'SUCCESS: Patient billing history retrieved.';

        EXCEPTION
            WHEN OTHERS THEN
                p_status_code := -20081;
                p_error_message := 'ERR_CURSOR_OPEN: Error retrieving bills: ' || SQLERRM;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20082;
                p_error_message := 'ERR_GET_BILLS: Unexpected error: ' || SQLERRM;
            END IF;
    END sp_get_patient_bills;


    -- =========================================================
    -- PROCEDURE 10: SP_VALIDATE_PATIENT_FOR_APPOINTMENT
    -- =========================================================
    PROCEDURE sp_validate_patient_for_appointment (
        p_patient_id        IN patient.patient_id%TYPE,
        p_validation_cursor OUT SYS_REFCURSOR,
        p_status_code       OUT INTEGER,
        p_error_message     OUT VARCHAR2
    ) IS
        v_patient_exists    INTEGER;
        v_patient_status    patient.status%TYPE;

    BEGIN
        p_status_code := 0;
        p_error_message := NULL;

        -- =====================================================
        -- VALIDATION: Patient exists
        -- =====================================================
        BEGIN
            SELECT COUNT(*), MAX(status)
            INTO v_patient_exists, v_patient_status
            FROM patient
            WHERE patient_id = p_patient_id;
            
            IF v_patient_exists = 0 THEN
                p_status_code := -20090;
                p_error_message := 'ERR_PATIENT_NOT_FOUND: Patient ID ' || p_patient_id || 
                                   ' does not exist.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20090;
                    p_error_message := 'ERR_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION: Patient must be ACTIVE
        -- =====================================================
        BEGIN
            IF v_patient_status != 'ACTIVE' THEN
                p_status_code := -20091;
                p_error_message := 'ERR_PATIENT_NOT_ACTIVE: Patient is ' || v_patient_status || 
                                   '. Appointments can only be scheduled for ACTIVE patients.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20091;
                    p_error_message := 'ERR_STATUS_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- VALIDATION: Patient must not be DECEASED
        -- =====================================================
        BEGIN
            IF v_patient_status = 'DECEASED' THEN
                p_status_code := -20092;
                p_error_message := 'ERR_DECEASED_PATIENT: Patient is deceased. ' ||
                                   'Cannot schedule appointments for deceased patients.';
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                IF p_status_code = 0 THEN
                    p_status_code := -20092;
                    p_error_message := 'ERR_DECEASED_VALIDATION: ' || SQLERRM;
                END IF;
                RAISE;
        END;

        -- =====================================================
        -- OPEN CURSOR with patient validation info
        -- =====================================================
        BEGIN
            OPEN p_validation_cursor FOR
                SELECT
                    pat.patient_id,
                    pat.first_name,
                    pat.last_name,
                    TRUNC(MONTHS_BETWEEN(SYSDATE, pat.date_of_birth) / 12) AS age,
                    pat.status,
                    pat.phone,
                    pat.email,
                    pat.insurance_id,
                    ins.provider_name AS insurance_provider,
                    ins.coverage_percentage,
                    CASE WHEN ins.policy_expiry_date >= SYSDATE THEN 'VALID' 
                         ELSE 'EXPIRED' END AS insurance_status,
                    'ELIGIBLE_FOR_APPOINTMENT' AS validation_result
                FROM patient pat
                LEFT JOIN insurance ins ON pat.insurance_id = ins.insurance_id
                WHERE pat.patient_id = p_patient_id
                AND pat.status = 'ACTIVE';

            p_status_code := 0;
            p_error_message := 'SUCCESS: Patient validation for appointment completed.';

        EXCEPTION
            WHEN OTHERS THEN
                p_status_code := -20093;
                p_error_message := 'ERR_CURSOR_OPEN: Error during patient validation: ' || SQLERRM;
                RAISE_APPLICATION_ERROR(p_status_code, p_error_message);
        END;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_status_code = 0 THEN
                p_status_code := -20093;
                p_error_message := 'ERR_VALIDATE_PATIENT: Unexpected error: ' || SQLERRM;
            END IF;
    END sp_validate_patient_for_appointment;

END pkg_patient_mgmt;
/

-- Show compilation errors
SHOW ERRORS PACKAGE BODY pkg_patient_mgmt;


-- =============================================================
-- VERIFICATION: Package compiled successfully
-- =============================================================

SELECT 
    object_name, 
    object_type, 
    status,
    TO_CHAR(created, 'DD-MON-YYYY HH24:MI:SS') AS created_date
FROM user_objects
WHERE object_name = 'PKG_PATIENT_MGMT'
ORDER BY object_type;


SELECT 
    object_name,
    procedure_name
FROM user_procedures
WHERE object_name = 'PKG_PATIENT_MGMT'
ORDER BY procedure_name;

COMMIT;
/