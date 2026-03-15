## Hospital Management System (HMS)

A fully normalized Oracle database system designed to manage hospital operations including patient care, doctor scheduling, admissions, billing, and security.


### Project Overview

The Hospital Management System (HMS) is a relational database application built on Oracle SQL. It automates core hospital operations across six functional modules: Patient Management, Doctor Management, Appointment Management, Admission & Bed Management, Billing & Payments, and Staff Administration.

The system enforces business rules through triggers, stored procedures, and packages, and implements role-based access control to ensure data security.


### System Modules
1. Patient Management
Handles patient registration, profile updates, medical history, and insurance linkage.

    Register new patients with duplicate ID prevention
    Minor patients require a guardian record
    Insurance validation before any billing discount is applied

2. Doctor Management
Manages doctor profiles, department assignments, working schedules, and vacation dates.

    Each doctor belongs to exactly one department
    Schedule overlap is prevented via trigger
    Vacation periods stored directly in DOCTOR_SCHEDULE with schedule_type = Vacation; appointments blocked via trigger during these date ranges
    is_available flag allows instant blocking of a doctor from new bookings

3. Appointment Management
Covers booking, cancellation, rescheduling, and status tracking of appointments.

    Duplicate booking prevention via unique constraint
    Cancellations permitted only 24 hours before the appointment
    Rescheduling preserves full history in APPOINTMENT_HISTORY
    Maximum 5 appointments per doctor per day enforced

4. Admission & Bed Management
Manages patient admissions, bed assignments, room transfers, and discharges.

    One bed can hold only one active admission at a time
    ICU admissions require explicit doctor approval
    Bed status automatically updated to Available on discharge
    Transfer history maintained in ADMISSION_HISTORY

5. Billing & Payments
Generates bills from appointments and admissions, applies insurance coverage, and records payments.

    Bill auto-generated on patient discharge
    Insurance coverage percentage applied automatically
    Payment cannot exceed outstanding net balance
    Charges broken down: service, room, medication, and others

6. Staff Administration & Security
Manages staff records, application users, role-based access, and full audit logging.

    Admin role: full access
    Operator role: execute access only
    All user actions tracked via APP_USER role enforcement


