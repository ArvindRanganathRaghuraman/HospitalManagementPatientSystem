-- ============================================================
-- TEST 5: REPORTS
-- Patient counts, billing summary, admission summary,
-- insurance distribution, minor compliance check
-- Connect as: HMS_ADMIN_USER  (password: AdminUser#2026)
-- ============================================================

ALTER SESSION SET CURRENT_SCHEMA = hms_owner;

-- ============================================================
-- REPORT 1: PATIENT COUNTS BY TYPE
-- ============================================================

SELECT
    COUNT(*)                                                    AS total_patients,
    SUM(CASE WHEN is_minor = 'N' THEN 1 ELSE 0 END)           AS adults,
    SUM(CASE WHEN is_minor = 'Y' THEN 1 ELSE 0 END)           AS minors,
    SUM(CASE WHEN insurance_id IS NOT NULL THEN 1 ELSE 0 END) AS insured,
    SUM(CASE WHEN insurance_id IS NULL     THEN 1 ELSE 0 END) AS uninsured
FROM patient;


-- ============================================================
-- REPORT 2: INSURANCE PROVIDER DISTRIBUTION
-- ============================================================

SELECT NVL(i.provider_name, 'Uninsured')         AS provider,
       COUNT(p.patient_id)                         AS patient_count,
       ROUND(AVG(NVL(i.coverage_percentage, 0)),1) AS avg_coverage_pct
FROM   patient   p
LEFT JOIN insurance i ON i.insurance_id = p.insurance_id
GROUP  BY i.provider_name
ORDER  BY patient_count DESC;


-- ============================================================
-- REPORT 3: BILLING SUMMARY
-- Shows how much insurance absorbed vs patient owes
-- ============================================================

SELECT b.bill_id,
       p.first_name || ' ' || p.last_name   AS patient_name,
       NVL(i.provider_name, 'Uninsured')    AS insurer,
       NVL(i.coverage_percentage, 0)        AS coverage_pct,
       b.total_amount,
       b.insurance_coverage_amt,
       b.discount_amount,
       b.net_amount,
       b.status
FROM   bill      b
JOIN   patient   p  ON p.patient_id   = b.patient_id
LEFT JOIN insurance i ON i.insurance_id = p.insurance_id
ORDER  BY b.bill_id;

-- Aggregate billing totals
SELECT
    COUNT(*)                        AS total_bills,
    SUM(total_amount)               AS total_billed,
    SUM(insurance_coverage_amt)     AS covered_by_insurance,
    SUM(net_amount)                 AS owed_by_patients,
    ROUND(SUM(insurance_coverage_amt) /
          NULLIF(SUM(total_amount), 0) * 100, 1) AS pct_covered
FROM bill;


-- ============================================================
-- REPORT 4: PAYMENT SUMMARY
-- ============================================================

SELECT py.payment_id,
       p.first_name || ' ' || p.last_name AS patient_name,
       py.amount_paid,
       py.payment_method,
       py.transaction_reference,
       b.net_amount,
       b.status AS bill_status
FROM   payment py
JOIN   bill    b  ON b.bill_id    = py.bill_id
JOIN   patient p  ON p.patient_id = b.patient_id
ORDER  BY py.payment_id;


-- ============================================================
-- REPORT 5: ADMISSION SUMMARY
-- Shows planned vs emergency, outpatient vs inpatient
-- ============================================================

SELECT p.first_name || ' ' || p.last_name  AS patient_name,
       adm.admission_type,
       adm.status,
       adm.admission_date,
       adm.discharge_date,
       adm.diagnosis,
       CASE WHEN adm.appointment_id IS NULL
            THEN 'Emergency — no prior appointment'
            ELSE 'Planned — from appointment #' || adm.appointment_id
       END AS admission_source
FROM   admission adm
JOIN   patient   p ON p.patient_id = adm.patient_id
ORDER  BY adm.admission_date;


-- ============================================================
-- REPORT 6: MINOR PATIENTS COMPLIANCE
-- Every minor must have guardian info — 0 rows expected below
-- ============================================================

SELECT
    COUNT(*)                                                               AS total_minors,
    SUM(CASE WHEN guardian_first_name IS NOT NULL THEN 1 ELSE 0 END)     AS with_guardian,
    SUM(CASE WHEN guardian_first_name IS NULL     THEN 1 ELSE 0 END)     AS missing_guardian
FROM patient WHERE is_minor = 'Y';


-- ============================================================
-- REPORT 7: BLOOD TYPE DISTRIBUTION
-- ============================================================

SELECT blood_type,
       COUNT(*) AS total,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM   patient
WHERE  blood_type IS NOT NULL
GROUP  BY blood_type
ORDER  BY total DESC;


-- ============================================================
-- REPORT 8: ROW COUNTS ACROSS ALL TABLES
-- ============================================================

SELECT 'insurance'         AS entity, COUNT(*) AS rows FROM insurance        UNION ALL
SELECT 'patient'           AS entity, COUNT(*) AS rows FROM patient          UNION ALL
SELECT 'appointment'       AS entity, COUNT(*) AS rows FROM appointment      UNION ALL
SELECT 'admission'         AS entity, COUNT(*) AS rows FROM admission        UNION ALL
SELECT 'prescription'      AS entity, COUNT(*) AS rows FROM prescription     UNION ALL
SELECT 'prescription_item' AS entity, COUNT(*) AS rows FROM prescription_item UNION ALL
SELECT 'bill'              AS entity, COUNT(*) AS rows FROM bill             UNION ALL
SELECT 'payment'           AS entity, COUNT(*) AS rows FROM payment
ORDER  BY entity;
