CREATE USER hms_owner IDENTIFIED BY Team4patient;
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO hms_owner;
GRANT CREATE VIEW TO hms_owner;

-- Create roles (empty for now)
CREATE ROLE hms_admin_role;
CREATE ROLE hms_operator_role;

-- Create users and assign roles
CREATE USER hms_admin_user IDENTIFIED BY "AdminUser#2026";
GRANT CREATE SESSION TO hms_admin_user;
GRANT hms_admin_role TO hms_admin_user;

CREATE USER hms_op_user IDENTIFIED BY "OperatorUser#2026";
GRANT CREATE SESSION TO hms_op_user;
GRANT hms_operator_role TO hms_op_user;