-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM
-- Security Setup Part 2 — Run as SYSTEM after DDL
-- File: 00_SECURITY_PART2.sql
-- Purpose: Grant table, view, and execute privileges to roles
-- Run Order: AFTER 01_DDL, 02_TRIGGERS, 03_PROCEDURES, 04_VIEWS
-- =============================================================

-- =============================================================
-- STEP 1: Grant HMS_ADMIN_ROLE — full DML on all tables
-- Admin can read, insert, update, delete directly on tables
-- =============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.insurance         TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.patient           TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.appointment       TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.prescription      TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.prescription_item TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.bill              TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.payment           TO hms_admin_role;

-- Grant sequence usage so admin can insert with NEXTVAL
GRANT SELECT ON hms_owner.insurance_seq         TO hms_admin_role;
GRANT SELECT ON hms_owner.patient_seq           TO hms_admin_role;
GRANT SELECT ON hms_owner.appointment_seq       TO hms_admin_role;
GRANT SELECT ON hms_owner.prescription_seq      TO hms_admin_role;
GRANT SELECT ON hms_owner.prescription_item_seq TO hms_admin_role;
GRANT SELECT ON hms_owner.bill_seq              TO hms_admin_role;
GRANT SELECT ON hms_owner.payment_seq           TO hms_admin_role;

-- Execute on package
GRANT EXECUTE ON hms_owner.pkg_patient_mgmt TO hms_admin_role;

-- Select on all views
GRANT SELECT ON hms_owner.vw_patient_profile        TO hms_admin_role;
GRANT SELECT ON hms_owner.vw_minor_patients         TO hms_admin_role;
GRANT SELECT ON hms_owner.vw_uninsured_patients     TO hms_admin_role;
GRANT SELECT ON hms_owner.vw_patient_medical_history TO hms_admin_role;
GRANT SELECT ON hms_owner.vw_patient_visit_summary  TO hms_admin_role;



-- =============================================================
-- STEP 2: Grant HMS_OPERATOR_ROLE — execute + view only
-- Operator CANNOT touch base tables directly
-- All data changes must go through the package procedures
-- =============================================================

-- Execute on package only — no direct table access
GRANT EXECUTE ON hms_owner.pkg_patient_mgmt TO hms_operator_role;

-- Read only on views — cannot query base tables
GRANT SELECT ON hms_owner.vw_patient_profile         TO hms_operator_role;
GRANT SELECT ON hms_owner.vw_minor_patients          TO hms_operator_role;
GRANT SELECT ON hms_owner.vw_uninsured_patients      TO hms_operator_role;
GRANT SELECT ON hms_owner.vw_patient_medical_history TO hms_operator_role;
GRANT SELECT ON hms_owner.vw_patient_visit_summary   TO hms_operator_role;



-- =============================================================
-- VERIFY: Confirm role assignments
-- =============================================================

-- Show roles assigned to each user
SELECT grantee, granted_role
FROM   dba_role_privs
WHERE  grantee IN ('HMS_ADMIN_USER', 'HMS_OP_USER')
ORDER  BY grantee;

-- Show what admin role has access to
SELECT grantee, privilege, table_name
FROM   dba_tab_privs
WHERE  grantee = 'HMS_ADMIN_ROLE'
ORDER  BY table_name;

-- Show what operator role has access to
SELECT grantee, privilege, table_name
FROM   dba_tab_privs
WHERE  grantee = 'HMS_OPERATOR_ROLE'
ORDER  BY table_name;