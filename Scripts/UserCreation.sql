CREATE USER hms_owner IDENTIFIED BY Team4patient;
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO hms_owner;

DROP USER hms_admin_user CASCADE;
DROP USER hms_op_user CASCADE;
DROP ROLE hms_admin_role;
DROP ROLE hms_operator_role;


