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



-- =============================================================
-- SECTION 3: 150 ADULT PATIENTS WITH INSURANCE
-- =============================================================
DECLARE
    v_pid  NUMBER;
    v_first VARCHAR2(50);
    v_last  VARCHAR2(50);
    v_dob   DATE;
    v_ins   NUMBER;

    TYPE t_names IS TABLE OF VARCHAR2(50);
    v_fnames t_names := t_names(
        'James','Mary','John','Patricia','Robert','Jennifer','Michael','Linda',
        'David','Barbara','William','Elizabeth','Richard','Susan','Joseph','Jessica',
        'Thomas','Sarah','Charles','Karen','Christopher','Lisa','Daniel','Nancy',
        'Matthew','Betty','Anthony','Margaret','Mark','Sandra','Donald','Ashley',
        'Steven','Dorothy','Paul','Kimberly','Andrew','Emily','Kenneth','Donna',
        'George','Michelle','Joshua','Carol','Kevin','Amanda','Brian','Melissa',
        'Edward','Deborah','Ronald','Stephanie','Timothy','Rebecca','Jason','Sharon',
        'Jeffrey','Laura','Ryan','Cynthia','Jacob','Kathleen','Gary','Amy',
        'Nicholas','Angela','Eric','Shirley','Jonathan','Anna','Stephen','Brenda',
        'Larry','Pamela','Justin','Emma','Scott','Nicole','Brandon','Helen',
        'Benjamin','Samantha','Samuel','Katherine','Raymond','Christine','Gregory',
        'Debra','Frank','Rachel','Alexander','Carolyn','Patrick','Janet','Jack',
        'Catherine','Dennis','Maria','Jerry','Heather','Tyler','Diane','Aaron',
        'Julie','Henry','Joyce','Douglas','Victoria','Peter','Alice','Harold',
        'Megan','Arthur','Theresa','Philip','Gloria','Walter','Doris','Eugene',
        'Marie','Joe','Jean','Irene','Roger','Ann','Keith','Beverly',
        'Terry','Rose','Carl','Lillian','Christian','Andrea','Willie','Alice',
        'Lawrence','Judy','Sean','Judith','Gerald','Frances','Keith','Shirley',
        'Jesse','Hannah','Bryan','Katharine','Billy','Tina','Bruce','Lori'
    );
    v_lnames t_names := t_names(
        'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
        'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson',
        'Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson',
        'White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker',
        'Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill','Flores',
        'Green','Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell',
        'Carter','Roberts','Gomez','Phillips','Evans','Turner','Diaz','Parker',
        'Cruz','Edwards','Collins','Reyes','Stewart','Morris','Morales','Murphy',
        'Cook','Rogers','Gutierrez','Ortiz','Morgan','Cooper','Peterson','Bailey',
        'Reed','Kelly','Howard','Ramos','Kim','Cox','Ward','Richardson','Watson',
        'Brooks','Chavez','Wood','James','Bennett','Gray','Mendoza','Ruiz',
        'Hughes','Price','Alvarez','Castillo','Sanders','Patel','Myers','Long',
        'Ross','Foster','Jimenez','Powell','Jenkins','Perry','Russell','Sullivan',
        'Bell','Coleman','Butler','Henderson','Barnes','Gonzales','Fisher','Vasquez',
        'Simmons','Romero','Jordan','Patterson','Alexander','Hamilton','Graham',
        'Reynolds','Griffin','Wallace','Moreno','West','Cole','Hayes','Bryant',
        'Herrera','Gibson','Ellis','Tran','Medina','Aguilar','Stevens','Murray',
        'Ford','Castro','Marshall','Owens','Harrison','Fernandez','Mcdonald','Woods'
    );
    v_bloods t_names := t_names('A+','A-','B+','B-','AB+','AB-','O+','O-');
    v_cities t_names := t_names('Boston','Cambridge','Somerville','Quincy','Medford',
                                 'Waltham','Newton','Brookline','Malden','Everett',
                                 'Lynn','Salem','Lowell','Worcester','Springfield');
    TYPE t_ids IS TABLE OF NUMBER;
    v_ins_ids t_ids := t_ids(1,2,3,4,5,6,7,8,9,10,11,12);
BEGIN
    FOR i IN 1..150 LOOP
        v_first := v_fnames(MOD(i-1, v_fnames.COUNT) + 1);
        v_last  := v_lnames(MOD(i-1, v_lnames.COUNT) + 1);
        -- Age 18-80: base 18 years back, spread by loop index
        v_dob   := TRUNC(SYSDATE) - (365*18) - MOD(i * 173, 365*62);
        v_ins   := v_ins_ids(MOD(i-1, v_ins_ids.COUNT) + 1);

        BEGIN
            pkg_patient_mgmt.sp_register_patient(
                p_first_name   => v_first,
                p_last_name    => v_last,
                p_dob          => v_dob,
                p_gender       => CASE WHEN MOD(i,2)=0 THEN 'M' ELSE 'F' END,
                p_phone        => '617-300-' || LPAD(i, 4, '0'),
                p_email        => LOWER(v_first) || '.' || LOWER(v_last) || i || '@hms.com',
                p_blood_type   => v_bloods(MOD(i-1, 8) + 1),
                p_address      => i || ' Main St, Boston MA',
                p_city         => v_cities(MOD(i-1, v_cities.COUNT) + 1),
                p_state        => 'MA',
                p_zip_code     => '0' || LPAD(MOD(i, 9000) + 1000, 4, '0'),
                p_insurance_id => v_ins,
                p_patient_id   => v_pid
            );
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('ERROR adult #' || i || ': ' || SQLERRM);
        END;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('--- Section 3 complete: 150 insured adults ---');
END;
/


-- =============================================================
-- SECTION 4: 25 UNINSURED ADULT PATIENTS
-- =============================================================
DECLARE
    v_pid NUMBER;

    PROCEDURE ins_adult (
        p_fname  VARCHAR2, p_lname  VARCHAR2, p_dob  DATE,
        p_gender CHAR,     p_blood  VARCHAR2, p_seq  NUMBER
    ) IS
        v_id NUMBER;
    BEGIN
        pkg_patient_mgmt.sp_register_patient(
            p_first_name   => p_fname,
            p_last_name    => p_lname,
            p_dob          => p_dob,
            p_gender       => p_gender,
            p_phone        => '617-400-' || LPAD(p_seq, 4, '0'),
            p_email        => LOWER(p_fname) || '.' || LOWER(p_lname) || p_seq || '@hms.com',
            p_blood_type   => p_blood,
            p_address      => (p_seq * 5) || ' Elm St, Boston MA',
            p_city         => 'Boston',
            p_state        => 'MA',
            p_zip_code     => NULL,
            p_insurance_id => NULL,
            p_patient_id   => v_id
        );
        DBMS_OUTPUT.PUT_LINE('Uninsured inserted: ' || p_fname || ' ' || p_lname || ' | ID=' || v_id);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR uninsured: ' || p_fname || ' ' || p_lname || ' | ' || SQLERRM);
    END ins_adult;

BEGIN
    ins_adult('Aaron',    'Pierce',   DATE '1985-04-10', 'M', 'O+',  1);
    ins_adult('Diana',    'Fletcher', DATE '1992-08-23', 'F', 'A+',  2);
    ins_adult('Marcus',   'Stone',    DATE '1978-01-15', 'M', 'B-',  3);
    ins_adult('Natalie',  'Fox',      DATE '1999-06-07', 'F', 'AB+', 4);
    ins_adult('Derek',    'Hunt',     DATE '1965-11-30', 'M', 'O-',  5);
    ins_adult('Tiffany',  'Warren',   DATE '1990-03-19', 'F', 'A-',  6);
    ins_adult('Calvin',   'Moss',     DATE '1982-09-28', 'M', 'B+',  7);
    ins_adult('Amber',    'Cole',     DATE '2000-05-14', 'F', 'O+',  8);
    ins_adult('Travis',   'Simmons',  DATE '1975-12-03', 'M', 'AB-', 9);
    ins_adult('Crystal',  'Norman',   DATE '1988-07-22', 'F', 'A+',  10);
    ins_adult('Brett',    'Owen',     DATE '1970-02-11', 'M', 'B+',  11);
    ins_adult('Melanie',  'Cross',    DATE '1995-10-05', 'F', 'O-',  12);
    ins_adult('Randall',  'Barker',   DATE '1961-04-27', 'M', 'A-',  13);
    ins_adult('Vanessa',  'Hicks',    DATE '2001-08-16', 'F', 'B-',  14);
    ins_adult('Clifford', 'Sparks',   DATE '1979-01-09', 'M', 'AB+', 15);
    ins_adult('Leah',     'Padilla',  DATE '1993-05-31', 'F', 'O+',  16);
    ins_adult('Wendell',  'Walters',  DATE '1968-09-20', 'M', 'A+',  17);
    ins_adult('Candace',  'Bradley',  DATE '1986-03-13', 'F', 'B+',  18);
    ins_adult('Ruben',    'Chambers', DATE '2003-07-04', 'M', 'O+',  19);
    ins_adult('Stacy',    'Obrien',   DATE '1977-11-25', 'F', 'A-',  20);
    ins_adult('Evan',     'Larson',   DATE '1991-06-18', 'M', 'AB-', 21);
    ins_adult('Tricia',   'Ingram',   DATE '1984-02-07', 'F', 'B-',  22);
    ins_adult('Byron',    'Bridges',  DATE '1959-10-15', 'M', 'O-',  23);
    ins_adult('Felicia',  'Nunez',    DATE '1996-04-02', 'F', 'A+',  24);
    ins_adult('Grant',    'Vega',     DATE '1972-08-29', 'M', 'B+',  25);

    DBMS_OUTPUT.PUT_LINE('--- Section 4 complete: 25 uninsured adults ---');
END;
/


-- =============================================================
-- SECTION 5: APPOINTMENTS (10 records)
-- Mix of COMPLETED, SCHEDULED, CANCELLED across insured,
-- uninsured, and minor patients — to support medical history view
-- doctor_id is a manual integer (no FK, doctor table is separate module)
-- =============================================================
BEGIN
    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2025-12-10', '09:00 AM', 'COMPLETED', 'Annual checkup', 'Patient doing well, all vitals normal', 1, 3, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-01-15', '10:30 AM', 'COMPLETED', 'Fever and cold', 'Temperature 101F, prescribed antibiotics and antihistamine', 2, 5, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-05-20', '11:00 AM', 'SCHEDULED', 'Follow-up visit', NULL, 5, 3, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-01-08', '02:00 PM', 'COMPLETED', 'Hypertension checkup', 'BP 145/90, adjusted medication dosage', 26, 7, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-02-03', '09:30 AM', 'COMPLETED', 'Diabetes management', 'Blood sugar well controlled, continue current plan', 27, 7, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-02-20', '03:00 PM', 'COMPLETED', 'Back pain', 'Muscle strain, physical therapy recommended', 28, 9, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, cancelled_date, cancellation_reason, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-03-05', '10:00 AM', 'CANCELLED', 'General checkup', DATE '2026-03-03', 'Patient unavailable', 29, 3, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-05-25', '01:00 PM', 'SCHEDULED', 'Blood test review', NULL, 30, 7, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-01-22', '11:30 AM', 'COMPLETED', 'Chest pain evaluation', 'ECG normal, stress test ordered', 176, 12, 'HMS_OWNER');

    INSERT INTO appointment (appointment_id, appointment_date, appointment_time, status, reason, notes, patient_id, doctor_id, modified_by)
    VALUES (appointment_seq.NEXTVAL, DATE '2026-03-10', '04:00 PM', 'COMPLETED', 'Skin rash', 'Allergic reaction, antihistamine prescribed', 177, 5, 'HMS_OWNER');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: 10 appointments inserted.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR inserting appointments: ' || SQLERRM);
END;
/


-- =============================================================
-- SECTION 6: ADMISSIONS (6 records)
-- 5 linked to appointments (planned), 1 emergency (no appointment)
-- doctor_id and bed_id are manual integers (no FK)
-- =============================================================
BEGIN
    -- Admission 1: Liam Johnson (patient 2) — from appointment 2 (fever)
    -- Planned, now DISCHARGED
    INSERT INTO admission (admission_id, admission_date, discharge_date, diagnosis,
                           admission_type, status, doctor_id, bed_id,
                           patient_id, appointment_id, modified_by)
    VALUES (admission_seq.NEXTVAL, DATE '2026-01-15', DATE '2026-01-20',
            'Acute Respiratory Infection', 'PLANNED', 'DISCHARGED',
            5, 101, 2, 2, 'HMS_OWNER');

    -- Admission 2: Adult patient 26 — from appointment 4 (hypertension)
    -- Planned, DISCHARGED
    INSERT INTO admission (admission_id, admission_date, discharge_date, diagnosis,
                           admission_type, status, doctor_id, bed_id,
                           patient_id, appointment_id, modified_by)
    VALUES (admission_seq.NEXTVAL, DATE '2026-01-08', DATE '2026-01-12',
            'Hypertensive Crisis — BP 180/110', 'PLANNED', 'DISCHARGED',
            7, 204, 26, 4, 'HMS_OWNER');

    -- Admission 3: Adult patient 27 — from appointment 5 (diabetes)
    -- Planned, still ACTIVE (currently admitted)
    INSERT INTO admission (admission_id, admission_date, discharge_date, diagnosis,
                           admission_type, status, doctor_id, bed_id,
                           patient_id, appointment_id, modified_by)
    VALUES (admission_seq.NEXTVAL, DATE '2026-02-03', NULL,
            'Diabetic Ketoacidosis', 'PLANNED', 'ACTIVE',
            7, 205, 27, 5, 'HMS_OWNER');

    -- Admission 4: Uninsured patient 176 — from appointment 9 (chest pain)
    -- Emergency, DISCHARGED
    INSERT INTO admission (admission_id, admission_date, discharge_date, diagnosis,
                           admission_type, status, doctor_id, bed_id,
                           patient_id, appointment_id, modified_by)
    VALUES (admission_seq.NEXTVAL, DATE '2026-01-22', DATE '2026-01-25',
            'Chest Pain — Cardiac Evaluation, ECG Normal', 'EMERGENCY', 'DISCHARGED',
            12, 310, 176, 9, 'HMS_OWNER');

    -- Admission 5: Adult patient 28 — from appointment 6 (back pain)
    -- Planned, DISCHARGED
    INSERT INTO admission (admission_id, admission_date, discharge_date, diagnosis,
                           admission_type, status, doctor_id, bed_id,
                           patient_id, appointment_id, modified_by)
    VALUES (admission_seq.NEXTVAL, DATE '2026-02-20', DATE '2026-02-23',
            'Severe Lumbar Strain — Physical Therapy Required', 'PLANNED', 'DISCHARGED',
            9, 108, 28, 6, 'HMS_OWNER');

    -- Admission 6: Emma Smith (patient 1, minor) — EMERGENCY, no prior appointment
    -- Came directly to ER, appointment_id = NULL
    INSERT INTO admission (admission_id, admission_date, discharge_date, diagnosis,
                           admission_type, status, doctor_id, bed_id,
                           patient_id, appointment_id, modified_by)
    VALUES (admission_seq.NEXTVAL, DATE '2026-03-15', DATE '2026-03-17',
            'Acute Appendicitis — Emergency Surgery', 'EMERGENCY', 'DISCHARGED',
            3, 402, 1, NULL, 'HMS_OWNER');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: 6 admissions inserted (5 from appointments, 1 emergency).');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR inserting admissions: ' || SQLERRM);
END;
/


-- =============================================================
-- SECTION 7: PRESCRIPTIONS + PRESCRIPTION ITEMS
-- appointment IDs 1,2,4,5,9 are COMPLETED
-- patient IDs updated to match actual DB
-- =============================================================
DECLARE
    v_appt_1   NUMBER;  -- Emma Smith (patient 1)
    v_appt_2   NUMBER;  -- Liam Johnson (patient 2)
    v_appt_26  NUMBER;  -- insured adult 26
    v_appt_27  NUMBER;  -- insured adult 27
    v_appt_176 NUMBER;  -- uninsured 176
    v_prx1     NUMBER;
    v_prx2     NUMBER;
    v_prx3     NUMBER;
    v_prx4     NUMBER;
    v_prx5     NUMBER;
BEGIN
    -- Fetch completed appointment IDs dynamically by patient
    SELECT appointment_id INTO v_appt_1
    FROM appointment WHERE patient_id = 1 AND status = 'COMPLETED' AND ROWNUM = 1;

    SELECT appointment_id INTO v_appt_2
    FROM appointment WHERE patient_id = 2 AND status = 'COMPLETED' AND ROWNUM = 1;

    SELECT appointment_id INTO v_appt_26
    FROM appointment WHERE patient_id = 26 AND status = 'COMPLETED' AND ROWNUM = 1;

    SELECT appointment_id INTO v_appt_27
    FROM appointment WHERE patient_id = 27 AND status = 'COMPLETED' AND ROWNUM = 1;

    SELECT appointment_id INTO v_appt_176
    FROM appointment WHERE patient_id = 176 AND status = 'COMPLETED' AND ROWNUM = 1;

    -- Prescription 1: Emma Smith
    INSERT INTO prescription (prescription_id, prescribed_date, notes, patient_id, doctor_id, appointment_id)
    VALUES (prescription_seq.NEXTVAL, DATE '2025-12-10', 'Routine checkup prescription', 1, 3, v_appt_1)
    RETURNING prescription_id INTO v_prx1;

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Amoxicillin', '500mg', 'Twice daily', 7, 'Take with food', v_prx1);

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Ibuprofen', '200mg', 'As needed', 5, 'Do not exceed 3 tablets per day', v_prx1);

    -- Prescription 2: Liam Johnson
    INSERT INTO prescription (prescription_id, prescribed_date, notes, patient_id, doctor_id, appointment_id)
    VALUES (prescription_seq.NEXTVAL, DATE '2026-01-15', 'Fever treatment course', 2, 5, v_appt_2)
    RETURNING prescription_id INTO v_prx2;

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Cetirizine', '10mg', 'Once daily', 10, 'Take at bedtime', v_prx2);

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Paracetamol', '500mg', 'Three times daily', 5, 'Take after meals', v_prx2);

    -- Prescription 3: Patient 26 (hypertension)
    INSERT INTO prescription (prescription_id, prescribed_date, notes, patient_id, doctor_id, appointment_id)
    VALUES (prescription_seq.NEXTVAL, DATE '2026-01-08', 'Hypertension medication adjusted', 26, 7, v_appt_26)
    RETURNING prescription_id INTO v_prx3;

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Lisinopril', '10mg', 'Once daily', 30, 'Take in the morning', v_prx3);

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Amlodipine', '5mg', 'Once daily', 30, 'Monitor blood pressure daily', v_prx3);

    -- Prescription 4: Patient 27 (diabetes)
    INSERT INTO prescription (prescription_id, prescribed_date, notes, patient_id, doctor_id, appointment_id)
    VALUES (prescription_seq.NEXTVAL, DATE '2026-02-03', 'Diabetes long-term management', 27, 7, v_appt_27)
    RETURNING prescription_id INTO v_prx4;

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Metformin', '1000mg', 'Twice daily', 90, 'Take with meals', v_prx4);

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Glipizide', '5mg', 'Once daily', 90, 'Take 30 min before breakfast', v_prx4);

    -- Prescription 5: Patient 176 (chest pain)
    INSERT INTO prescription (prescription_id, prescribed_date, notes, patient_id, doctor_id, appointment_id)
    VALUES (prescription_seq.NEXTVAL, DATE '2026-01-22', 'Cardiac monitoring and preventive care', 176, 12, v_appt_176)
    RETURNING prescription_id INTO v_prx5;

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Aspirin', '81mg', 'Once daily', 30, 'Take with water', v_prx5);

    INSERT INTO prescription_item (item_id, medication_name, dosage, frequency, duration_days, instructions, prescription_id)
    VALUES (prescription_item_seq.NEXTVAL, 'Atorvastatin', '20mg', 'Once daily at night', 30, 'Avoid grapefruit juice', v_prx5);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: 5 prescriptions with 10 items inserted.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR inserting prescriptions: ' || SQLERRM);
END;
/

-- =============================================================
-- SECTION 7: BILLS (5 records)
-- Patient IDs updated to match actual DB
-- Trigger trg_bill_bi auto-calculates insurance coverage
-- =============================================================
DECLARE
    v_appt_1   NUMBER;
    v_appt_2   NUMBER;
    v_appt_26  NUMBER;
    v_appt_27  NUMBER;
    v_appt_176 NUMBER;
    v_adm_2    NUMBER;
    v_adm_26   NUMBER;
    v_adm_27   NUMBER;
    v_adm_176  NUMBER;
BEGIN
    -- Fetch appointment IDs
    SELECT appointment_id INTO v_appt_1   FROM appointment WHERE patient_id = 1   AND status = 'COMPLETED' AND ROWNUM = 1;
    SELECT appointment_id INTO v_appt_2   FROM appointment WHERE patient_id = 2   AND status = 'COMPLETED' AND ROWNUM = 1;
    SELECT appointment_id INTO v_appt_26  FROM appointment WHERE patient_id = 26  AND status = 'COMPLETED' AND ROWNUM = 1;
    SELECT appointment_id INTO v_appt_27  FROM appointment WHERE patient_id = 27  AND status = 'COMPLETED' AND ROWNUM = 1;
    SELECT appointment_id INTO v_appt_176 FROM appointment WHERE patient_id = 176 AND status = 'COMPLETED' AND ROWNUM = 1;

    -- Fetch admission IDs for admitted patients (NULL if no admission exists)
    BEGIN SELECT admission_id INTO v_adm_2   FROM admission WHERE patient_id = 2   AND ROWNUM = 1; EXCEPTION WHEN NO_DATA_FOUND THEN v_adm_2   := NULL; END;
    BEGIN SELECT admission_id INTO v_adm_26  FROM admission WHERE patient_id = 26  AND ROWNUM = 1; EXCEPTION WHEN NO_DATA_FOUND THEN v_adm_26  := NULL; END;
    BEGIN SELECT admission_id INTO v_adm_27  FROM admission WHERE patient_id = 27  AND ROWNUM = 1; EXCEPTION WHEN NO_DATA_FOUND THEN v_adm_27  := NULL; END;
    BEGIN SELECT admission_id INTO v_adm_176 FROM admission WHERE patient_id = 176 AND ROWNUM = 1; EXCEPTION WHEN NO_DATA_FOUND THEN v_adm_176 := NULL; END;

    -- Bill 1: Patient 1 (Emma Smith) — outpatient only, no admission from this appointment
    INSERT INTO bill (bill_id, service_charges, medication_charges, total_amount, discount_amount, net_amount, status, patient_id, appointment_id, admission_id, modified_by)
    VALUES (bill_seq.NEXTVAL, 200, 50, 250, 0, 0, 'PENDING', 1, v_appt_1, NULL, 'HMS_OWNER');

    -- Bill 2: Patient 2 (Liam Johnson) — appointment + admission (room charges included)
    INSERT INTO bill (bill_id, service_charges, room_charges, medication_charges, total_amount, discount_amount, net_amount, status, patient_id, appointment_id, admission_id, modified_by)
    VALUES (bill_seq.NEXTVAL, 150, 500, 30, 680, 0, 0, 'PENDING', 2, v_appt_2, v_adm_2, 'HMS_OWNER');

    -- Bill 3: Patient 26 (insured adult) — appointment + admission
    INSERT INTO bill (bill_id, service_charges, room_charges, medication_charges, other_charges, total_amount, discount_amount, net_amount, status, patient_id, appointment_id, admission_id, modified_by)
    VALUES (bill_seq.NEXTVAL, 300, 800, 80, 20, 1200, 0, 0, 'PENDING', 26, v_appt_26, v_adm_26, 'HMS_OWNER');

    -- Bill 4: Patient 27 (insured adult) — appointment + admission
    INSERT INTO bill (bill_id, service_charges, room_charges, medication_charges, total_amount, discount_amount, net_amount, status, patient_id, appointment_id, admission_id, modified_by)
    VALUES (bill_seq.NEXTVAL, 250, 600, 80, 930, 0, 0, 'PENDING', 27, v_appt_27, v_adm_27, 'HMS_OWNER');

    -- Bill 5: Patient 176 (uninsured) — appointment + admission, full amount owed
    INSERT INTO bill (bill_id, service_charges, room_charges, other_charges, total_amount, discount_amount, net_amount, status, patient_id, appointment_id, admission_id, modified_by)
    VALUES (bill_seq.NEXTVAL, 400, 900, 50, 1350, 0, 0, 'PENDING', 176, v_appt_176, v_adm_176, 'HMS_OWNER');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: 5 bills inserted.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR inserting bills: ' || SQLERRM);
END;
/

-- =============================================================
-- SECTION 8: PAYMENTS (3 records)
-- Bill IDs 1,2,5 match the bills inserted above
-- =============================================================
DECLARE
    v_bill_1   NUMBER;
    v_bill_2   NUMBER;
    v_bill_176 NUMBER;
    v_net_1    NUMBER;
    v_net_2    NUMBER;
BEGIN
    -- Fetch bill IDs and net amounts dynamically
    SELECT bill_id, net_amount INTO v_bill_1, v_net_1
    FROM bill WHERE patient_id = 1 AND ROWNUM = 1;

    SELECT bill_id, net_amount INTO v_bill_2, v_net_2
    FROM bill WHERE patient_id = 2 AND ROWNUM = 1;

    SELECT bill_id INTO v_bill_176
    FROM bill WHERE patient_id = 176 AND ROWNUM = 1;

    -- Payment 1: Patient 1 — fully paid (exact net amount)
    INSERT INTO payment (payment_id, amount_paid, payment_method, transaction_reference, bill_id)
    VALUES (payment_seq.NEXTVAL, v_net_1, 'CASH', 'TXN-2025-1201', v_bill_1);
    UPDATE bill SET status = 'PAID', modified_date = SYSDATE WHERE bill_id = v_bill_1;

    -- Payment 2: Patient 2 — fully paid (exact net amount)
    INSERT INTO payment (payment_id, amount_paid, payment_method, transaction_reference, bill_id)
    VALUES (payment_seq.NEXTVAL, v_net_2, 'INSURANCE', 'TXN-2026-0115', v_bill_2);
    UPDATE bill SET status = 'PAID', modified_date = SYSDATE WHERE bill_id = v_bill_2;

    -- Payment 3: Patient 176 — partial payment
    INSERT INTO payment (payment_id, amount_paid, payment_method, transaction_reference, bill_id)
    VALUES (payment_seq.NEXTVAL, 200, 'DEBIT_CARD', 'TXN-2026-0122', v_bill_176);
    UPDATE bill SET status = 'PARTIALLY_PAID', modified_date = SYSDATE WHERE bill_id = v_bill_176;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: 3 payments inserted.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR inserting payments: ' || SQLERRM);
END;
/

