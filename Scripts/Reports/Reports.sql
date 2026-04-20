-- =============================================================
-- REPORT 1: PATIENT REGISTRATION TREND BY MONTH
-- Purpose : Monthly registration counts split by adults/minors
--           and insured/uninsured
-- Business Value: Tracks hospital growth and patient intake trends
-- Tables  : PATIENT (direct)
-- =============================================================
SELECT
    TO_CHAR(p.registration_date, 'YYYY-MM')              AS registration_month,
    COUNT(*)                                              AS total_patients,
    SUM(CASE WHEN p.is_minor = 'N' THEN 1 ELSE 0 END)   AS adults,
    SUM(CASE WHEN p.is_minor = 'Y' THEN 1 ELSE 0 END)   AS minors,
    SUM(CASE WHEN p.insurance_id IS NOT NULL THEN 1 ELSE 0 END) AS insured,
    SUM(CASE WHEN p.insurance_id IS NULL     THEN 1 ELSE 0 END) AS uninsured
FROM patient p
GROUP BY TO_CHAR(p.registration_date, 'YYYY-MM')
ORDER BY registration_month DESC;


-- =============================================================
-- REPORT 2: INSURANCE COVERAGE DISTRIBUTION
-- Purpose : Patient count and average coverage per provider
-- Business Value: Identifies top insurers and coverage gaps
-- Tables  : PATIENT JOIN INSURANCE
-- =============================================================
SELECT
    NVL(i.provider_name, 'Uninsured')                    AS insurance_provider,
    COUNT(p.patient_id)                                   AS patient_count,
    ROUND(AVG(NVL(i.coverage_percentage, 0)), 1)         AS avg_coverage_pct,
    MIN(i.coverage_percentage)                            AS min_coverage_pct,
    MAX(i.coverage_percentage)                            AS max_coverage_pct,
    ROUND(COUNT(p.patient_id) * 100.0 /
        SUM(COUNT(p.patient_id)) OVER (), 1)             AS pct_of_total_patients
FROM      patient   p
LEFT JOIN insurance i ON i.insurance_id = p.insurance_id
GROUP BY i.provider_name
ORDER BY patient_count DESC;


-- =============================================================
-- REPORT 3: MINOR PATIENTS COMPLIANCE REPORT
-- Purpose : All minors with guardian details — proves business
--           rule enforcement (minors must have guardian info)
-- Business Value: Legal compliance tracking
-- Tables  : PATIENT JOIN INSURANCE (via VW_MINOR_PATIENTS)
-- =============================================================
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name                   AS patient_name,
    TRUNC(MONTHS_BETWEEN(SYSDATE, p.date_of_birth) / 12) AS age,
    p.gender,
    p.phone,
    p.guardian_first_name || ' ' ||
        p.guardian_last_name                             AS guardian_name,
    p.guardian_relationship,
    p.guardian_phone,
    NVL(i.provider_name, 'Uninsured')                    AS insurance_provider,
    NVL(i.coverage_percentage, 0)                        AS coverage_pct,
    CASE
        WHEN p.guardian_first_name IS NULL THEN 'MISSING — ACTION REQUIRED'
        ELSE 'COMPLIANT'
    END                                                  AS compliance_status
FROM      patient   p
LEFT JOIN insurance i ON i.insurance_id = p.insurance_id
WHERE p.is_minor = 'Y'
ORDER BY age DESC;


-- =============================================================
-- REPORT 4: BLOOD TYPE DISTRIBUTION
-- Purpose : Count and percentage of each blood type across all
--           patients — emergency readiness and blood bank planning
-- Business Value: Ensures hospital is prepared for transfusions
-- Tables  : PATIENT (direct)
-- =============================================================
SELECT
    blood_type,
    COUNT(*)                                                  AS total_patients,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (), 2)                            AS pct_of_total,
    SUM(CASE WHEN is_minor = 'Y' THEN 1 ELSE 0 END)         AS minors,
    SUM(CASE WHEN is_minor = 'N' THEN 1 ELSE 0 END)         AS adults
FROM   patient
WHERE  blood_type IS NOT NULL
GROUP  BY blood_type
ORDER  BY total_patients DESC;


-- =============================================================
-- REPORT 5: UNINSURED PATIENTS — REVENUE CYCLE
-- Purpose : All patients with no, expired, or inactive insurance
--           grouped by issue type for billing follow-up
-- Business Value: Revenue cycle — identify patients needing
--                 insurance enrollment or renewal outreach
-- Tables  : VW_UNINSURED_PATIENTS
-- =============================================================

-- Summary by issue type
SELECT
    insurance_issue,
    COUNT(*)                                                  AS total_patients,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (), 2)                            AS pct_of_uninsured
FROM   vw_uninsured_patients
GROUP  BY insurance_issue
ORDER  BY total_patients DESC;

-- Full detail list
SELECT
    patient_id,
    patient_name,
    insurance_issue,
    provider_name,
    policy_number,
    policy_expiry_date,
    insurance_status,
    patient_status
FROM   vw_uninsured_patients
ORDER  BY insurance_issue, patient_name;
