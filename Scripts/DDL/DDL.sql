


BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE payment';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE bill';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE prescription_item';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE prescription';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE appointment';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE patient';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE insurance';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/


BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE insurance_seq';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE patient_seq';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE appointment_seq';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE prescription_seq';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE prescription_item_seq';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE bill_seq';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE payment_seq';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/


-- SEQUENCE FOR INSURANCE TABLE

CREATE SEQUENCE insurance_seq
    START WITH 1
    INCREMENT BY 1
    NOCYCLE;


--  SEQUENCE FOR  PATIENT IDs
CREATE SEQUENCE patient_seq
    START WITH 1
    INCREMENT BY 1
    NOCYCLE;
    

--   SEQUENCE FOR  APPOINTMENT IDs
CREATE SEQUENCE appointment_seq
    START WITH 1
    INCREMENT BY 1
    NOCYCLE;
    

-- SEQUENCE FOR  PRESCRIPTION IDs
CREATE SEQUENCE prescription_seq
    START WITH 1
    INCREMENT BY 1
    NOCYCLE;
    
-- sequence for prescription items
CREATE SEQUENCE prescription_item_seq
    START WITH 1
    INCREMENT BY 1
    NOCYCLE;
    

-- SEQUENCE FOR  BILL IDs
CREATE SEQUENCE bill_seq
    START WITH 1
    INCREMENT BY 1
    NOCYCLE;


-- sequence for payement id
CREATE SEQUENCE payment_seq
    START WITH 1
    INCREMENT BY 1
    NOCYCLE;
    
CREATE TABLE insurance (
    insurance_id        INTEGER PRIMARY KEY,
    provider_name       VARCHAR2(100) NOT NULL,
    policy_number       VARCHAR2(50) NOT NULL UNIQUE,
    coverage_percentage NUMBER(5,2) NOT NULL CHECK (coverage_percentage >= 0 AND coverage_percentage <= 100),
    policy_start_date   DATE NOT NULL,
    policy_expiry_date  DATE NOT NULL,
    status              VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL CHECK (status IN ('ACTIVE', 'INACTIVE', 'EXPIRED')),
    created_date        DATE DEFAULT SYSDATE NOT NULL,
    modified_date       DATE DEFAULT SYSDATE NOT NULL,
    
   
    CONSTRAINT insurance_date_check CHECK (policy_start_date < policy_expiry_date)
);
    


CREATE TABLE patient (
    patient_id              INTEGER PRIMARY KEY,
    first_name              VARCHAR2(50) NOT NULL,
    last_name               VARCHAR2(50) NOT NULL,
    date_of_birth           DATE NOT NULL,
    gender                  CHAR(1) NOT NULL,
    phone                   VARCHAR2(15) NOT NULL UNIQUE,
    email                   VARCHAR2(100),
    blood_type              VARCHAR2(5),
    registration_date       DATE DEFAULT SYSDATE NOT NULL,
    is_minor                CHAR(1) DEFAULT 'N' NOT NULL,
    status                  VARCHAR2(20) DEFAULT 'ACTIVE' NOT NULL,
    city                    VARCHAR2(50),
    state                   VARCHAR2(50),
    zip_code                VARCHAR2(10),
    address                 VARCHAR2(255),
    insurance_id            INTEGER,
    guardian_first_name     VARCHAR2(50),
    guardian_last_name      VARCHAR2(50),
    guardian_relationship   VARCHAR2(30),
    guardian_phone          VARCHAR2(15),
    guardian_email          VARCHAR2(100),
    created_date            DATE DEFAULT SYSDATE NOT NULL,
    modified_date           DATE DEFAULT SYSDATE NOT NULL,
    modified_by             VARCHAR2(30),
    
    -- COLUMN-LEVEL CONSTRAINTS
    CONSTRAINT patient_gender_check CHECK (gender IN ('M', 'F', 'O')),
    CONSTRAINT patient_blood_type_check CHECK (blood_type IN ('O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-')),
    CONSTRAINT patient_is_minor_check CHECK (is_minor IN ('Y', 'N')),
    CONSTRAINT patient_status_check CHECK (status IN ('ACTIVE', 'INACTIVE', 'DISCHARGED', 'DECEASED')),
    
    -- TABLE-LEVEL CONSTRAINTS
    -- Email format validation (must contain @ and .)
    CONSTRAINT patient_email_check CHECK (email IS NULL OR email LIKE '%@%'),
    
    -- Guardian validation: Minor patients must have guardian info, adults should not
    CONSTRAINT patient_guardian_check CHECK (
        (is_minor = 'N' AND guardian_first_name IS NULL) OR
        (is_minor = 'Y' AND guardian_first_name IS NOT NULL)
    ),
    
    -- FOREIGN KEY: Link patient to insurance table
    CONSTRAINT patient_insurance_fk FOREIGN KEY (insurance_id) 
        REFERENCES insurance(insurance_id)
);


CREATE TABLE appointment (
    appointment_id        INTEGER PRIMARY KEY,
    appointment_date      DATE NOT NULL,
    appointment_time      VARCHAR2(20) NOT NULL,
    status                VARCHAR2(20) DEFAULT 'SCHEDULED' NOT NULL,
    reason                VARCHAR2(255),
    notes                 VARCHAR2(500),
    created_date          DATE DEFAULT SYSDATE NOT NULL,
    cancelled_date        DATE,
    cancellation_reason   VARCHAR2(255),
    parent_appointment_id INTEGER,
    patient_id            INTEGER NOT NULL,
    doctor_id             INTEGER,
    modified_date         DATE DEFAULT SYSDATE NOT NULL,
    modified_by           VARCHAR2(30),
    
    -- COLUMN-LEVEL CONSTRAINTS
    CONSTRAINT appointment_status_check CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'RESCHEDULED')),
    
    
    -- FOREIGN KEY: Link appointment to patient
    CONSTRAINT appointment_patient_fk FOREIGN KEY (patient_id) 
        REFERENCES patient(patient_id)
);




CREATE TABLE prescription (
    prescription_id INTEGER PRIMARY KEY,
    prescribed_date DATE DEFAULT SYSDATE NOT NULL,
    notes           VARCHAR2(500),
    patient_id      INTEGER NOT NULL,
    doctor_id       INTEGER,
    appointment_id  INTEGER NOT NULL,
    created_date    DATE DEFAULT SYSDATE NOT NULL,
    modified_date   DATE DEFAULT SYSDATE NOT NULL,
    modified_by     VARCHAR2(30),
    
    -- FOREIGN KEY: Link prescription to patient
    CONSTRAINT prescription_patient_fk FOREIGN KEY (patient_id) 
        REFERENCES patient(patient_id),
    
    -- FOREIGN KEY: Link prescription to appointment
    CONSTRAINT prescription_appointment_fk FOREIGN KEY (appointment_id) 
        REFERENCES appointment(appointment_id)
);



CREATE TABLE prescription_item (
    item_id         INTEGER PRIMARY KEY,
    medication_name VARCHAR2(100) NOT NULL,
    dosage          VARCHAR2(50) NOT NULL,
    frequency       VARCHAR2(50) NOT NULL,
    duration_days   INTEGER NOT NULL,
    instructions    VARCHAR2(255),
    prescription_id INTEGER NOT NULL,
    created_date    DATE DEFAULT SYSDATE NOT NULL,
    modified_date   DATE DEFAULT SYSDATE NOT NULL,
    
    -- COLUMN-LEVEL CONSTRAINTS
    CONSTRAINT prescription_item_duration_check CHECK (duration_days > 0),
    
    -- FOREIGN KEY: Link prescription_item to prescription
    CONSTRAINT prescription_item_fk FOREIGN KEY (prescription_id) 
        REFERENCES prescription(prescription_id)
);




CREATE TABLE bill (
    bill_id                INTEGER PRIMARY KEY,
    bill_date              DATE DEFAULT SYSDATE NOT NULL,
    service_charges        NUMBER(10,2),
    room_charges           NUMBER(10,2),
    medication_charges     NUMBER(10,2),
    other_charges          NUMBER(10,2),
    total_amount           NUMBER(10,2) NOT NULL,
    insurance_coverage_amt NUMBER(10,2) DEFAULT 0,
    discount_amount        NUMBER(10,2) DEFAULT 0,
    net_amount             NUMBER(10,2) NOT NULL,
    status                 VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    patient_id             INTEGER NOT NULL,
    appointment_id         INTEGER,
    created_date           DATE DEFAULT SYSDATE NOT NULL,
    modified_date          DATE DEFAULT SYSDATE NOT NULL,
    modified_by            VARCHAR2(30),
    
    -- COLUMN-LEVEL CONSTRAINTS
    CONSTRAINT bill_status_check CHECK (status IN ('PENDING', 'PAID', 'PARTIALLY_PAID', 'CANCELLED')),
    
    -- TABLE-LEVEL CONSTRAINTS
    CONSTRAINT bill_amount_check CHECK (total_amount >= 0 AND net_amount >= 0 AND insurance_coverage_amt >= 0),
    
    -- FOREIGN KEY: Link bill to patient
    CONSTRAINT bill_patient_fk FOREIGN KEY (patient_id) 
        REFERENCES patient(patient_id),
    
    -- FOREIGN KEY: Link bill to appointment
    CONSTRAINT bill_appointment_fk FOREIGN KEY (appointment_id) 
        REFERENCES appointment(appointment_id)
);



CREATE TABLE payment (
    payment_id            INTEGER PRIMARY KEY,
    payment_date          DATE DEFAULT SYSDATE NOT NULL,
    amount_paid           NUMBER(10,2) NOT NULL,
    payment_method        VARCHAR2(30) NOT NULL,
    transaction_reference VARCHAR2(100),
    bill_id               INTEGER NOT NULL,
    created_date          DATE DEFAULT SYSDATE NOT NULL,
    modified_date         DATE DEFAULT SYSDATE NOT NULL,
    modified_by           VARCHAR2(30),
    
    -- COLUMN-LEVEL CONSTRAINTS
    CONSTRAINT payment_method_check CHECK (payment_method IN ('CASH', 'CREDIT_CARD', 'DEBIT_CARD', 'CHEQUE', 'INSURANCE')),
    CONSTRAINT payment_amount_check CHECK (amount_paid > 0),
    
    -- FOREIGN KEY: Link payment to bill
    CONSTRAINT payment_bill_fk FOREIGN KEY (bill_id) 
        REFERENCES bill(bill_id)
);

commit;

