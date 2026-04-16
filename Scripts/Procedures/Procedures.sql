-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM
-- Patient Module - Package Specification + Body
-- Schema: HMS_OWNER
-- File: 03_PROCEDURES.sql
-- Procedures : SP_REGISTER_PATIENT, SP_UPDATE_PATIENT,
--              SP_LINK_INSURANCE, SP_DEACTIVATE_PATIENT
-- Functions  : FN_IS_MINOR, FN_GET_COVERAGE_PCT
-- =============================================================


-- =============================================================
-- PACKAGE SPECIFICATION
-- =============================================================
CREATE OR REPLACE PACKAGE pkg_patient_mgmt AS

    -- ── PROCEDURES ──────────────────────────────────────────

    -- Register a new patient into the system
    PROCEDURE sp_register_patient (
        p_first_name            IN patient.first_name%TYPE,
        p_last_name             IN patient.last_name%TYPE,
        p_dob                   IN patient.date_of_birth%TYPE,
        p_gender                IN patient.gender%TYPE,
        p_phone                 IN patient.phone%TYPE,
        p_email                 IN patient.email%TYPE         DEFAULT NULL,
        p_blood_type            IN patient.blood_type%TYPE    DEFAULT NULL,
        p_address               IN patient.address%TYPE       DEFAULT NULL,
        p_city                  IN patient.city%TYPE          DEFAULT NULL,
        p_state                 IN patient.state%TYPE         DEFAULT NULL,
        p_zip_code              IN patient.zip_code%TYPE      DEFAULT NULL,
        p_insurance_id          IN patient.insurance_id%TYPE  DEFAULT NULL,
        p_guardian_first_name   IN patient.guardian_first_name%TYPE  DEFAULT NULL,
        p_guardian_last_name    IN patient.guardian_last_name%TYPE   DEFAULT NULL,
        p_guardian_relationship IN patient.guardian_relationship%TYPE DEFAULT NULL,
        p_guardian_phone        IN patient.guardian_phone%TYPE       DEFAULT NULL,
        p_guardian_email        IN patient.guardian_email%TYPE       DEFAULT NULL,
        p_patient_id            OUT patient.patient_id%TYPE
    );

    -- Update existing patient contact and medical details
    PROCEDURE sp_update_patient (
        p_patient_id    IN patient.patient_id%TYPE,
        p_phone         IN patient.phone%TYPE          DEFAULT NULL,
        p_email         IN patient.email%TYPE          DEFAULT NULL,
        p_address       IN patient.address%TYPE        DEFAULT NULL,
        p_city          IN patient.city%TYPE           DEFAULT NULL,
        p_state         IN patient.state%TYPE          DEFAULT NULL,
        p_zip_code      IN patient.zip_code%TYPE       DEFAULT NULL,
        p_blood_type    IN patient.blood_type%TYPE     DEFAULT NULL,
        p_status        IN patient.status%TYPE         DEFAULT NULL
    );

    -- Link or update insurance provider for a patient
    PROCEDURE sp_link_insurance (
        p_patient_id   IN patient.patient_id%TYPE,
        p_insurance_id IN patient.insurance_id%TYPE
    );

    -- Deactivate a patient record
    PROCEDURE sp_deactivate_patient (
        p_patient_id IN patient.patient_id%TYPE,
        p_reason     IN VARCHAR2 DEFAULT 'Deactivated by operator'
    );

    -- ── FUNCTIONS ───────────────────────────────────────────

    -- Returns 'Y' if patient is a minor, 'N' if adult
    FUNCTION fn_is_minor (
        p_patient_id IN patient.patient_id%TYPE
    ) RETURN CHAR;

    -- Returns insurance coverage percentage for a patient (0 if uninsured)
    FUNCTION fn_get_coverage_pct (
        p_patient_id IN patient.patient_id%TYPE
    ) RETURN NUMBER;

END pkg_patient_mgmt;
/
SHOW ERRORS PACKAGE pkg_patient_mgmt;


-- =============================================================
-- PACKAGE BODY
-- =============================================================
CREATE OR REPLACE PACKAGE BODY pkg_patient_mgmt AS

    -- ==========================================================
    -- PROCEDURE: SP_REGISTER_PATIENT
    -- Purpose  : Registers a new patient with full validation
    -- Business Rules Enforced:
    --   1. Duplicate phone check (patient cannot have duplicate ID)
    --   2. Minor must have guardian information
    --   3. Insurance validated before linking (active + not expired)
    -- ==========================================================
    PROCEDURE sp_register_patient (
        p_first_name            IN patient.first_name%TYPE,
        p_last_name             IN patient.last_name%TYPE,
        p_dob                   IN patient.date_of_birth%TYPE,
        p_gender                IN patient.gender%TYPE,
        p_phone                 IN patient.phone%TYPE,
        p_email                 IN patient.email%TYPE         DEFAULT NULL,
        p_blood_type            IN patient.blood_type%TYPE    DEFAULT NULL,
        p_address               IN patient.address%TYPE       DEFAULT NULL,
        p_city                  IN patient.city%TYPE          DEFAULT NULL,
        p_state                 IN patient.state%TYPE         DEFAULT NULL,
        p_zip_code              IN patient.zip_code%TYPE      DEFAULT NULL,
        p_insurance_id          IN patient.insurance_id%TYPE  DEFAULT NULL,
        p_guardian_first_name   IN patient.guardian_first_name%TYPE  DEFAULT NULL,
        p_guardian_last_name    IN patient.guardian_last_name%TYPE   DEFAULT NULL,
        p_guardian_relationship IN patient.guardian_relationship%TYPE DEFAULT NULL,
        p_guardian_phone        IN patient.guardian_phone%TYPE       DEFAULT NULL,
        p_guardian_email        IN patient.guardian_email%TYPE       DEFAULT NULL,
        p_patient_id            OUT patient.patient_id%TYPE
    ) IS
        v_age          NUMBER;
        v_count        NUMBER;
        v_ins_status   insurance.status%TYPE;
        v_ins_expiry   insurance.policy_expiry_date%TYPE;

        -- User-defined exceptions
        e_duplicate_phone    EXCEPTION;
        e_minor_no_guardian  EXCEPTION;
        e_invalid_insurance  EXCEPTION;
        e_ins_expired        EXCEPTION;
        e_ins_not_found      EXCEPTION;
        e_future_dob         EXCEPTION;

    BEGIN
        -- ── VALIDATION 1: DOB cannot be in future ─────────────
        IF p_dob > SYSDATE THEN
            RAISE e_future_dob;
        END IF;

        -- ── VALIDATION 2: Duplicate phone check ───────────────
        SELECT COUNT(*) INTO v_count
        FROM patient WHERE phone = p_phone;

        IF v_count > 0 THEN
            RAISE e_duplicate_phone;
        END IF;

        -- ── VALIDATION 3: Minor must have guardian ────────────
        -- Note: trg_patient_bi sets is_minor automatically,
        -- but we validate guardian here before the insert fires
        v_age := TRUNC(MONTHS_BETWEEN(SYSDATE, p_dob) / 12);

        IF v_age < 18 AND p_guardian_first_name IS NULL THEN
            RAISE e_minor_no_guardian;
        END IF;

        -- ── VALIDATION 4: Insurance must be active ────────────
        -- Note: We validate here; trg_patient_insurance_val
        -- is removed so this procedure is the sole enforcer
        IF p_insurance_id IS NOT NULL THEN
            BEGIN
                SELECT status, policy_expiry_date
                INTO   v_ins_status, v_ins_expiry
                FROM   insurance
                WHERE  insurance_id = p_insurance_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE e_ins_not_found;
            END;

            IF v_ins_status != 'ACTIVE' THEN
                RAISE e_invalid_insurance;
            END IF;

            IF v_ins_expiry < SYSDATE THEN
                RAISE e_ins_expired;
            END IF;
        END IF;

        -- ── INSERT PATIENT ────────────────────────────────────
        -- trg_patient_bi auto-assigns patient_id and is_minor
        INSERT INTO patient (
            first_name, last_name, date_of_birth, gender,
            phone, email, blood_type, address, city, state, zip_code,
            insurance_id,
            guardian_first_name, guardian_last_name,
            guardian_relationship, guardian_phone, guardian_email
        ) VALUES (
            p_first_name, p_last_name, p_dob, p_gender,
            p_phone, p_email, p_blood_type, p_address, p_city, p_state, p_zip_code,
            p_insurance_id,
            p_guardian_first_name, p_guardian_last_name,
            p_guardian_relationship, p_guardian_phone, p_guardian_email
        ) RETURNING patient_id INTO p_patient_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Patient registered. ID = ' || p_patient_id
            || ', Age = ' || v_age
            || ', Is_Minor = ' || CASE WHEN v_age < 18 THEN 'Y' ELSE 'N' END);

    -- ── EXCEPTION HANDLING ────────────────────────────────────
    EXCEPTION
        WHEN e_future_dob THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20009,
                'ERROR: Date of birth cannot be in the future.');

        WHEN e_duplicate_phone THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20010,
                'ERROR: Phone ' || p_phone ||
                ' is already registered to another patient.');

        WHEN e_minor_no_guardian THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20011,
                'ERROR: Patient is a minor (Age: ' || v_age || '). ' ||
                'Guardian first name is mandatory.');

        WHEN e_ins_not_found THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20012,
                'ERROR: Insurance ID ' || p_insurance_id || ' does not exist.');

        WHEN e_invalid_insurance THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20013,
                'ERROR: Insurance ID ' || p_insurance_id ||
                ' is not ACTIVE. Current status: ' || v_ins_status);

        WHEN e_ins_expired THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20014,
                'ERROR: Insurance ID ' || p_insurance_id ||
                ' expired on ' || TO_CHAR(v_ins_expiry, 'DD-MON-YYYY'));

        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20099,
                'ERROR in SP_REGISTER_PATIENT: ' || SQLERRM);
    END sp_register_patient;


    -- ==========================================================
    -- PROCEDURE: SP_UPDATE_PATIENT
    -- Purpose  : Updates patient contact and medical details
    --            Only updates fields that are passed in (NVL logic)
    -- Business Rules Enforced:
    --   - Patient must exist
    --   - Status must be a valid value
    -- ==========================================================
    PROCEDURE sp_update_patient (
        p_patient_id    IN patient.patient_id%TYPE,
        p_phone         IN patient.phone%TYPE       DEFAULT NULL,
        p_email         IN patient.email%TYPE       DEFAULT NULL,
        p_address       IN patient.address%TYPE     DEFAULT NULL,
        p_city          IN patient.city%TYPE        DEFAULT NULL,
        p_state         IN patient.state%TYPE       DEFAULT NULL,
        p_zip_code      IN patient.zip_code%TYPE    DEFAULT NULL,
        p_blood_type    IN patient.blood_type%TYPE  DEFAULT NULL,
        p_status        IN patient.status%TYPE      DEFAULT NULL
    ) IS
        v_count        NUMBER;
        e_not_found    EXCEPTION;
        e_dup_phone    EXCEPTION;

    BEGIN
        -- ── Validate patient exists ───────────────────────────
        SELECT COUNT(*) INTO v_count
        FROM patient
        WHERE patient_id = p_patient_id;

        IF v_count = 0 THEN
            RAISE e_not_found;
        END IF;

        -- ── Validate new phone is not duplicate ───────────────
        IF p_phone IS NOT NULL THEN
            SELECT COUNT(*) INTO v_count
            FROM patient
            WHERE phone = p_phone
            AND   patient_id != p_patient_id;

            IF v_count > 0 THEN
                RAISE e_dup_phone;
            END IF;
        END IF;

        -- ── Update only provided fields using NVL ─────────────
        UPDATE patient SET
            phone      = NVL(p_phone,      phone),
            email      = NVL(p_email,      email),
            address    = NVL(p_address,    address),
            city       = NVL(p_city,       city),
            state      = NVL(p_state,      state),
            zip_code   = NVL(p_zip_code,   zip_code),
            blood_type = NVL(p_blood_type, blood_type),
            status     = NVL(p_status,     status)
        WHERE patient_id = p_patient_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Patient ID ' || p_patient_id || ' updated.');

    EXCEPTION
        WHEN e_not_found THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20020,
                'ERROR: Patient ID ' || p_patient_id || ' not found.');

        WHEN e_dup_phone THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20021,
                'ERROR: Phone number ' || p_phone ||
                ' is already used by another patient.');

        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20099,
                'ERROR in SP_UPDATE_PATIENT: ' || SQLERRM);
    END sp_update_patient;


    -- ==========================================================
    -- PROCEDURE: SP_LINK_INSURANCE
    -- Purpose  : Links or updates insurance for a patient
    -- Business Rules Enforced:
    --   - Patient must exist
    --   - Insurance must exist, be ACTIVE, and not expired
    -- ==========================================================
    PROCEDURE sp_link_insurance (
        p_patient_id   IN patient.patient_id%TYPE,
        p_insurance_id IN patient.insurance_id%TYPE
    ) IS
        v_count        NUMBER;
        v_ins_status   insurance.status%TYPE;
        v_ins_expiry   insurance.policy_expiry_date%TYPE;

        e_pat_not_found EXCEPTION;
        e_ins_not_found EXCEPTION;
        e_ins_inactive  EXCEPTION;
        e_ins_expired   EXCEPTION;

    BEGIN
        -- ── Validate patient exists ───────────────────────────
        SELECT COUNT(*) INTO v_count
        FROM patient WHERE patient_id = p_patient_id;

        IF v_count = 0 THEN
            RAISE e_pat_not_found;
        END IF;

        -- ── Validate insurance ────────────────────────────────
        BEGIN
            SELECT status, policy_expiry_date
            INTO   v_ins_status, v_ins_expiry
            FROM   insurance
            WHERE  insurance_id = p_insurance_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE e_ins_not_found;
        END;

        IF v_ins_status != 'ACTIVE' THEN
            RAISE e_ins_inactive;
        END IF;

        IF v_ins_expiry < SYSDATE THEN
            RAISE e_ins_expired;
        END IF;

        -- ── Link insurance to patient ─────────────────────────
        UPDATE patient
        SET    insurance_id = p_insurance_id
        WHERE  patient_id   = p_patient_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Insurance ID ' || p_insurance_id ||
                             ' linked to Patient ID ' || p_patient_id);

    EXCEPTION
        WHEN e_pat_not_found THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20030,
                'ERROR: Patient ID ' || p_patient_id || ' not found.');

        WHEN e_ins_not_found THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20031,
                'ERROR: Insurance ID ' || p_insurance_id || ' not found.');

        WHEN e_ins_inactive THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20032,
                'ERROR: Insurance ID ' || p_insurance_id ||
                ' is not ACTIVE. Status: ' || v_ins_status);

        WHEN e_ins_expired THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20033,
                'ERROR: Insurance ID ' || p_insurance_id ||
                ' expired on ' || TO_CHAR(v_ins_expiry, 'DD-MON-YYYY'));

        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20099,
                'ERROR in SP_LINK_INSURANCE: ' || SQLERRM);
    END sp_link_insurance;


    -- ==========================================================
    -- PROCEDURE: SP_DEACTIVATE_PATIENT
    -- Purpose  : Marks a patient as INACTIVE
    -- Business Rules Enforced:
    --   - Patient must exist
    --   - Cannot deactivate an already inactive patient
    -- ==========================================================
    PROCEDURE sp_deactivate_patient (
        p_patient_id IN patient.patient_id%TYPE,
        p_reason     IN VARCHAR2 DEFAULT 'Deactivated by operator'
    ) IS
        v_status       patient.status%TYPE;
        e_not_found    EXCEPTION;
        e_already_inactive EXCEPTION;

    BEGIN
        -- ── Fetch current status ──────────────────────────────
        BEGIN
            SELECT status INTO v_status
            FROM   patient
            WHERE  patient_id = p_patient_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE e_not_found;
        END;

        IF v_status = 'INACTIVE' THEN
            RAISE e_already_inactive;
        END IF;

        -- ── Deactivate ────────────────────────────────────────
        UPDATE patient
        SET    status      = 'INACTIVE',
               modified_by = USER
        WHERE  patient_id  = p_patient_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Patient ID ' || p_patient_id ||
                             ' deactivated. Reason: ' || p_reason);

    EXCEPTION
        WHEN e_not_found THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20040,
                'ERROR: Patient ID ' || p_patient_id || ' not found.');

        WHEN e_already_inactive THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20041,
                'ERROR: Patient ID ' || p_patient_id ||
                ' is already INACTIVE.');

        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20099,
                'ERROR in SP_DEACTIVATE_PATIENT: ' || SQLERRM);
    END sp_deactivate_patient;


    -- ==========================================================
    -- FUNCTION: FN_IS_MINOR
    -- Purpose : Returns 'Y' if patient is under 18, else 'N'
    -- ==========================================================
    FUNCTION fn_is_minor (
        p_patient_id IN patient.patient_id%TYPE
    ) RETURN CHAR IS
        v_dob DATE;
        v_age NUMBER;
    BEGIN
        SELECT date_of_birth INTO v_dob
        FROM   patient
        WHERE  patient_id = p_patient_id;

        v_age := TRUNC(MONTHS_BETWEEN(SYSDATE, v_dob) / 12);

        IF v_age < 18 THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20050,
                'ERROR: Patient ID ' || p_patient_id || ' not found.');
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20099,
                'ERROR in FN_IS_MINOR: ' || SQLERRM);
    END fn_is_minor;


    -- ==========================================================
    -- FUNCTION: FN_GET_COVERAGE_PCT
    -- Purpose : Returns insurance coverage % for a patient
    --           Returns 0 if patient has no active insurance
    -- ==========================================================
    FUNCTION fn_get_coverage_pct (
        p_patient_id IN patient.patient_id%TYPE
    ) RETURN NUMBER IS
        v_pct NUMBER := 0;
    BEGIN
        SELECT NVL(i.coverage_percentage, 0)
        INTO   v_pct
        FROM   patient p
        JOIN   insurance i ON p.insurance_id = i.insurance_id
        WHERE  p.patient_id = p_patient_id
        AND    i.status = 'ACTIVE'
        AND    i.policy_expiry_date >= SYSDATE;

        RETURN v_pct;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0; -- No active insurance = 0% coverage
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20099,
                'ERROR in FN_GET_COVERAGE_PCT: ' || SQLERRM);
    END fn_get_coverage_pct;


END pkg_patient_mgmt;
/
SHOW ERRORS PACKAGE BODY pkg_patient_mgmt;


-- =============================================================
-- VERIFY: Package compiled successfully
-- =============================================================
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name = 'PKG_PATIENT_MGMT'
ORDER  BY object_type;