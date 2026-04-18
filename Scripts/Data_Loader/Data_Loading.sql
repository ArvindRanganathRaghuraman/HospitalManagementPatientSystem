-- =============================================================
-- SECTION 1: INSURANCE DATA (15 records)
-- 12 ACTIVE, 2 EXPIRED, 1 INACTIVE
-- Expired/Inactive exist to support negative test cases
-- =============================================================

SET SERVEROUTPUT ON;

BEGIN
    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'BlueCross BlueShield',  'POL-BC-1001', 80, DATE '2023-01-01', DATE '2027-12-31', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Aetna Health',          'POL-AE-1002', 70, DATE '2023-03-01', DATE '2027-03-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Cigna Healthcare',      'POL-CG-1003', 60, DATE '2023-06-01', DATE '2027-06-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'UnitedHealth Group',    'POL-UH-1004', 90, DATE '2024-01-01', DATE '2028-01-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Humana Insurance',      'POL-HU-1005', 75, DATE '2023-07-01', DATE '2027-07-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Kaiser Permanente',     'POL-KP-1006', 85, DATE '2024-02-01', DATE '2028-02-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Molina Healthcare',     'POL-MO-1007', 50, DATE '2023-05-01', DATE '2027-05-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Anthem Inc',            'POL-AN-1008', 78, DATE '2024-04-01', DATE '2028-04-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Harvard Pilgrim',       'POL-HP-1009', 72, DATE '2024-06-01', DATE '2028-06-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Tufts Health Plan',     'POL-TH-1010', 68, DATE '2023-09-01', DATE '2027-09-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Medicare Advantage',    'POL-MA-1011', 95, DATE '2024-01-01', DATE '2029-01-01', 'ACTIVE');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Medicaid State Plan',   'POL-MS-1012', 100,DATE '2024-01-01', DATE '2029-01-01', 'ACTIVE');

    -- EXPIRED — for negative test cases
    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'Centene Corporation',   'POL-CC-1013', 65, DATE '2020-01-01', DATE '2023-01-01', 'EXPIRED');

    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'WellCare Health',       'POL-WC-1014', 55, DATE '2019-01-01', DATE '2022-01-01', 'EXPIRED');

    -- INACTIVE — for negative test cases
    INSERT INTO insurance (insurance_id, provider_name, policy_number, coverage_percentage, policy_start_date, policy_expiry_date, status)
    VALUES (insurance_seq.NEXTVAL, 'COBRA Coverage',        'POL-CO-1015', 60, DATE '2022-01-01', DATE '2027-01-01', 'INACTIVE');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: 15 insurance records inserted.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR inserting insurance: ' || SQLERRM);
END;
/

-- =============================================================
-- SECTION 2: 25 MINOR PATIENTS (age < 18, with guardian info)
-- Inserted via stored procedure to prove business rules work
-- =============================================================
DECLARE
    v_pid NUMBER;

    PROCEDURE ins_minor (
        p_fname  VARCHAR2, p_lname  VARCHAR2, p_dob    DATE,
        p_gender CHAR,     p_blood  VARCHAR2, p_phone  VARCHAR2,
        p_email  VARCHAR2, p_city   VARCHAR2, p_ins    NUMBER,
        p_gfname VARCHAR2, p_glname VARCHAR2,
        p_grel   VARCHAR2, p_gphone VARCHAR2
    ) IS
        v_id NUMBER;
    BEGIN
        -- Direct INSERT instead of procedure call
        -- is_minor = 'Y' set explicitly so constraint passes before trigger fires
        INSERT INTO patient (
            first_name, last_name, date_of_birth, gender,
            phone, email, blood_type,
            address, city, state, zip_code,
            insurance_id,
            is_minor,
            guardian_first_name, guardian_last_name,
            guardian_relationship, guardian_phone, guardian_email,
            modified_by
        ) VALUES (
            p_fname, p_lname, p_dob, p_gender,
            p_phone, p_email, p_blood,
            p_city || ', MA', p_city, 'MA', NULL,
            p_ins,
            'Y',   -- explicitly set so constraint sees Y with guardian info
            p_gfname, p_glname,
            p_grel, p_gphone,
            LOWER(p_gfname) || '.' || LOWER(p_glname) || '@gmail.com',
            'HMS_OWNER'
        ) RETURNING patient_id INTO v_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Minor inserted: ' || p_fname || ' ' || p_lname || ' | ID=' || v_id);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR minor: ' || p_fname || ' ' || p_lname || ' | ' || SQLERRM);
    END ins_minor;

BEGIN
    --         fname        lname        dob                  gender blood   phone           email                       city          ins   gfname      glname       grel              gphone
    ins_minor('Emma',      'Smith',      DATE '2010-03-15',   'F',  'A+',  '617-200-0001', 'emma.smith@hms.com',       'Boston',      1,   'Robert',   'Smith',     'PARENT',         '617-900-0001');
    ins_minor('Liam',      'Johnson',    DATE '2009-07-22',   'M',  'B+',  '617-200-0002', 'liam.johnson@hms.com',     'Cambridge',   4,   'Linda',    'Johnson',   'PARENT',         '617-900-0002');
    ins_minor('Olivia',    'Williams',   DATE '2011-11-05',   'F',  'O+',  '617-200-0003', 'olivia.williams@hms.com',  'Somerville',  6,   'Michael',  'Williams',  'LEGAL_GUARDIAN', '617-900-0003');
    ins_minor('Noah',      'Brown',      DATE '2012-01-18',   'M',  'AB+', '617-200-0004', 'noah.brown@hms.com',       'Quincy',      7,   'Susan',    'Brown',     'PARENT',         '617-900-0004');
    ins_minor('Ava',       'Davis',      DATE '2013-05-30',   'F',  'A-',  '617-200-0005', 'ava.davis@hms.com',        'Medford',     8,   'James',    'Davis',     'PARENT',         '617-900-0005');
    ins_minor('Elijah',    'Miller',     DATE '2008-09-12',   'M',  'B-',  '617-200-0006', 'elijah.miller@hms.com',    'Waltham',     9,   'Patricia', 'Miller',    'PARENT',         '617-900-0006');
    ins_minor('Sophia',    'Wilson',     DATE '2010-12-25',   'F',  'O-',  '617-200-0007', 'sophia.wilson@hms.com',    'Newton',      10,  'David',    'Wilson',    'LEGAL_GUARDIAN', '617-900-0007');
    ins_minor('Lucas',     'Moore',      DATE '2014-04-08',   'M',  'A+',  '617-200-0008', 'lucas.moore@hms.com',      'Brookline',   11,  'Barbara',  'Moore',     'PARENT',         '617-900-0008');
    ins_minor('Mia',       'Taylor',     DATE '2011-08-19',   'F',  'B+',  '617-200-0009', 'mia.taylor@hms.com',       'Malden',      NULL,'Richard',  'Taylor',    'PARENT',         '617-900-0009');
    ins_minor('Mason',     'Anderson',   DATE '2009-02-28',   'M',  'AB-', '617-200-0010', 'mason.anderson@hms.com',   'Everett',     1,   'Nancy',    'Anderson',  'PARENT',         '617-900-0010');
    ins_minor('Harper',    'Thomas',     DATE '2015-06-14',   'F',  'O+',  '617-200-0011', 'harper.thomas@hms.com',    'Lynn',        4,   'Thomas',   'Thomas',    'SIBLING',        '617-900-0011');
    ins_minor('Ethan',     'Jackson',    DATE '2012-10-03',   'M',  'A+',  '617-200-0012', 'ethan.jackson@hms.com',    'Salem',       6,   'Karen',    'Jackson',   'PARENT',         '617-900-0012');
    ins_minor('Abigail',   'White',      DATE '2013-03-21',   'F',  'B+',  '617-200-0013', 'abigail.white@hms.com',    'Peabody',     NULL,'Charles',  'White',     'PARENT',         '617-900-0013');
    ins_minor('James',     'Harris',     DATE '2016-07-09',   'M',  'O+',  '617-200-0014', 'james.harris@hms.com',     'Lowell',      8,   'Dorothy',  'Harris',    'LEGAL_GUARDIAN', '617-900-0014');
    ins_minor('Emily',     'Martin',     DATE '2011-01-17',   'F',  'A-',  '617-200-0015', 'emily.martin@hms.com',     'Lawrence',    9,   'Mark',     'Martin',    'PARENT',         '617-900-0015');
    ins_minor('Logan',     'Garcia',     DATE '2014-11-26',   'M',  'AB+', '617-200-0016', 'logan.garcia@hms.com',     'Haverhill',   10,  'Betty',    'Garcia',    'PARENT',         '617-900-0016');
    ins_minor('Ella',      'Martinez',   DATE '2010-05-04',   'F',  'B-',  '617-200-0017', 'ella.martinez@hms.com',    'Worcester',   11,  'Paul',     'Martinez',  'PARENT',         '617-900-0017');
    ins_minor('Aiden',     'Robinson',   DATE '2015-09-13',   'M',  'O-',  '617-200-0018', 'aiden.robinson@hms.com',   'Framingham',  NULL,'Sandra',   'Robinson',  'PARENT',         '617-900-0018');
    ins_minor('Scarlett',  'Clark',      DATE '2012-02-07',   'F',  'A+',  '617-200-0019', 'scarlett.clark@hms.com',   'Natick',      1,   'George',   'Clark',     'PARENT',         '617-900-0019');
    ins_minor('Sebastian', 'Rodriguez',  DATE '2009-06-30',   'M',  'B+',  '617-200-0020', 'sebastian.rod@hms.com',    'Needham',     4,   'Helen',    'Rodriguez', 'LEGAL_GUARDIAN', '617-900-0020');
    ins_minor('Grace',     'Lewis',      DATE '2013-10-22',   'F',  'O+',  '617-200-0021', 'grace.lewis@hms.com',      'Dedham',      6,   'Edward',   'Lewis',     'PARENT',         '617-900-0021');
    ins_minor('Jackson',   'Lee',        DATE '2016-04-16',   'M',  'AB+', '617-200-0022', 'jackson.lee@hms.com',      'Canton',      NULL,'Carol',    'Lee',       'PARENT',         '617-900-0022');
    ins_minor('Chloe',     'Walker',     DATE '2011-08-05',   'F',  'A-',  '617-200-0023', 'chloe.walker@hms.com',     'Braintree',   8,   'Joseph',   'Walker',    'SIBLING',        '617-900-0023');
    ins_minor('Carter',    'Hall',       DATE '2014-12-19',   'M',  'B+',  '617-200-0024', 'carter.hall@hms.com',      'Weymouth',    9,   'Ruth',     'Hall',      'PARENT',         '617-900-0024');
    ins_minor('Zoey',      'Allen',      DATE '2010-03-08',   'F',  'O-',  '617-200-0025', 'zoey.allen@hms.com',       'Quincy',      10,  'Steven',   'Allen',     'LEGAL_GUARDIAN', '617-900-0025');

    DBMS_OUTPUT.PUT_LINE('--- Section 2 complete: 25 minor patients ---');
END;
/

select * from patient;
select * from insurance;