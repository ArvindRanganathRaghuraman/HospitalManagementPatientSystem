-- =============================================================
-- HOSPITAL MANAGEMENT SYSTEM
-- Security Setup — Run ONCE as SYSTEM user
-- File: 00_SECURITY_SETUP.sql
-- NOTE: This is the ONLY script that runs as SYSTEM
--       All other scripts run as HMS_OWNER
-- =============================================================


-- =============================================================
-- STEP 1: Create HMS_OWNER application schema
-- =============================================================
CREATE USER hms_owner IDENTIFIED BY "HmsOwner";

-- Grant only what HMS_OWNER needs — no DBA, no SYSDBA
GRANT CREATE SESSION       TO hms_owner;
GRANT CREATE TABLE         TO hms_owner;
GRANT CREATE VIEW          TO hms_owner;
GRANT CREATE PROCEDURE     TO hms_owner;
GRANT CREATE TRIGGER       TO hms_owner;
GRANT CREATE SEQUENCE      TO hms_owner;
GRANT UNLIMITED TABLESPACE TO hms_owner;


-- =============================================================
-- STEP 2: Create HMS_ADMIN_ROLE — full access to all tables
-- =============================================================
CREATE ROLE hms_admin_role;

-- Full DML on all patient module tables
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.insurance         TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.patient           TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.appointment       TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.admission         TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.prescription      TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.prescription_item TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.bill              TO hms_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON hms_owner.payment           TO hms_admin_role;

-- Execute on package
GRANT EXECUTE ON hms_owner.pkg_patient_mgmt TO hms_admin_role;

-- Access to all views
GRANT SELECT ON hms_owner.vw_patient_profile        TO hms_admin_role;
GRANT SELECT ON hms_owner.vw_minor_patients         TO hms_admin_role;
GRANT SELECT ON hms_owner.vw_uninsured_patients     TO hms_admin_role;
GRANT SELECT ON hms_owner.v_patient_medical_history TO hms_admin_role;
GRANT SELECT ON hms_owner.vw_patient_visit_summary  TO hms_admin_role;


-- =============================================================
-- STEP 3: Create HMS_OPERATOR_ROLE — execute + read only
-- Cannot INSERT/UPDATE/DELETE tables directly
-- =============================================================
CREATE ROLE hms_operator_role;

-- Execute package only — cannot touch tables directly
GRANT EXECUTE ON hms_owner.pkg_patient_mgmt TO hms_operator_role;

-- Read only on views — cannot read base tables directly
GRANT SELECT ON hms_owner.vw_patient_profile        TO hms_operator_role;
GRANT SELECT ON hms_owner.vw_minor_patients         TO hms_operator_role;
GRANT SELECT ON hms_owner.vw_uninsured_patients     TO hms_operator_role;
GRANT SELECT ON hms_owner.v_patient_medical_history TO hms_operator_role;
GRANT SELECT ON hms_owner.vw_patient_visit_summary  TO hms_operator_role;


-- =============================================================
-- STEP 4: Create application users and assign roles
-- =============================================================

-- Admin user
CREATE USER hms_admin_user IDENTIFIED BY "AdminUser#2026";
GRANT CREATE SESSION TO hms_admin_user;
GRANT hms_admin_role TO hms_admin_user;

-- Operator user
CREATE USER hms_op_user IDENTIFIED BY "OperatorUser#2026";
GRANT CREATE SESSION    TO hms_op_user;
GRANT hms_operator_role TO hms_op_user;


-- =============================================================
-- STEP 5: Verify — run these SELECT queries to confirm setup
-- =============================================================

-- Show all HMS users
SELECT username, account_status, created
FROM   dba_users
WHERE  username IN ('HMS_OWNER','HMS_ADMIN_USER','HMS_OP_USER')
ORDER  BY username;

-- Show role assignments per user
SELECT grantee, granted_role
FROM   dba_role_privs
WHERE  grantee IN ('HMS_ADMIN_USER','HMS_OP_USER')
ORDER  BY grantee;

-- Show what admin role can access
SELECT grantee, privilege, table_name
FROM   dba_tab_privs
WHERE  grantee = 'HMS_ADMIN_ROLE'
ORDER  BY table_name;

-- Show what operator role can access
SELECT grantee, privilege, table_name
FROM   dba_tab_privs
WHERE  grantee = 'HMS_OPERATOR_ROLE'
ORDER  BY table_name;