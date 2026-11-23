-- Database engine used: SQLite (compatible with standard SQL / MySQL with minor type adjustments)

DROP TABLE IF EXISTS exam_wise_report;

CREATE TABLE exam_wise_report (
    sr_no INTEGER,
    exam_session TEXT,
    academic_year TEXT,
    branch TEXT,
    department TEXT,
    class_name TEXT,
    semester TEXT,
    batch TEXT,
    admno TEXT,
    rollno TEXT,
    student TEXT,
    division TEXT,
    course TEXT,
    code TEXT,
    type TEXT,
    alloted_emp_id TEXT,
    exam_name TEXT,
    marks_entry_status TEXT,
    marks_obtained REAL,
    max_marks REAL,
    freeze_unfreeze_status TEXT,
    scaled_marks REAL,
    scaled_max_marks REAL,
    register_status TEXT,
    result_process TEXT,
    result_publish TEXT
);

-- 1. Number of rows for each exam_name and marks_entry_status combination
-- Returned row count: 5
SELECT
    exam_name,
    marks_entry_status,
    COUNT(*) AS row_count
FROM exam_wise_report
GROUP BY exam_name, marks_entry_status
ORDER BY row_count DESC;

-- 2. Students whose result is Published but marks for that course are Not Done or missing
-- Returned row count: 1849
SELECT
    admno,
    student,
    code,
    course,
    exam_name
FROM exam_wise_report
WHERE result_publish = 'Published'
  AND (
      marks_entry_status = 'Not Done'
      OR marks_entry_status IS NULL
      OR marks_obtained IS NULL
  );

-- 3. Duplicate records: same admno + code + exam_name appearing more than once
-- Returned row count: 356
SELECT
    admno,
    code,
    exam_name,
    COUNT(*) AS occurrence_count
FROM exam_wise_report
GROUP BY admno, code, exam_name
HAVING COUNT(*) > 1
ORDER BY occurrence_count DESC, admno;

-- 4. Rows with impossible marks: negative, > max_marks, or scaled_marks != marks_obtained when max marks are equal
-- Returned row count: 10
SELECT
    sr_no,
    admno,
    student,
    code,
    exam_name,
    marks_obtained,
    max_marks,
    scaled_marks,
    scaled_max_marks
FROM exam_wise_report
WHERE marks_obtained < 0
   OR (max_marks IS NOT NULL AND marks_obtained > max_marks)
   OR (
       max_marks IS NOT NULL
       AND scaled_max_marks IS NOT NULL
       AND max_marks = scaled_max_marks
       AND scaled_marks != marks_obtained
   );

-- 5a. SELECT showing original semester values next to cleaned values
-- Returned row count: 17
SELECT
    semester AS original_semester,
    CASE UPPER(TRIM(semester))
        WHEN 'SEM I' THEN 'Sem I'
        WHEN 'SEM II' THEN 'Sem II'
        WHEN 'SEM III' THEN 'Sem III'
        WHEN 'SEM IV' THEN 'Sem IV'
        WHEN 'SEM V' THEN 'Sem V'
        WHEN 'SEM VI' THEN 'Sem VI'
        WHEN 'SEM VII' THEN 'Sem VII'
        WHEN 'SEM VIII' THEN 'Sem VIII'
        WHEN 'SEM IX' THEN 'Sem IX'
        WHEN 'SEM 9' THEN 'Sem IX'
        ELSE TRIM(semester)
    END AS cleaned_semester,
    COUNT(*) AS affected_rows
FROM exam_wise_report
GROUP BY semester
ORDER BY original_semester;

-- 5b. Safe UPDATE with backup table and explicit WHERE clause
-- Protect data first by creating a backup copy before running any UPDATE:
CREATE TABLE IF NOT EXISTS exam_wise_report_bak_20261123 AS
SELECT * FROM exam_wise_report;

BEGIN TRANSACTION;

UPDATE exam_wise_report
SET semester = CASE UPPER(TRIM(semester))
    WHEN 'SEM I' THEN 'Sem I'
    WHEN 'SEM II' THEN 'Sem II'
    WHEN 'SEM III' THEN 'Sem III'
    WHEN 'SEM IV' THEN 'Sem IV'
    WHEN 'SEM V' THEN 'Sem V'
    WHEN 'SEM VI' THEN 'Sem VI'
    WHEN 'SEM VII' THEN 'Sem VII'
    WHEN 'SEM VIII' THEN 'Sem VIII'
    WHEN 'SEM IX' THEN 'Sem IX'
    WHEN 'SEM 9' THEN 'Sem IX'
    ELSE TRIM(semester)
END
WHERE semester IS NOT NULL
  AND semester != CASE UPPER(TRIM(semester))
      WHEN 'SEM I' THEN 'Sem I'
      WHEN 'SEM II' THEN 'Sem II'
      WHEN 'SEM III' THEN 'Sem III'
      WHEN 'SEM IV' THEN 'Sem IV'
      WHEN 'SEM V' THEN 'Sem V'
      WHEN 'SEM VI' THEN 'Sem VI'
      WHEN 'SEM VII' THEN 'Sem VII'
      WHEN 'SEM VIII' THEN 'Sem VIII'
      WHEN 'SEM IX' THEN 'Sem IX'
      WHEN 'SEM 9' THEN 'Sem IX'
      ELSE TRIM(semester)
  END;

-- Verify changes before committing (ROLLBACK if unexpected):
COMMIT;

-- 6. Distinct department, semester, code, course with Scheme Not Found, highest affected students first
-- Returned row count: 273
SELECT
    department,
    semester,
    code,
    course,
    COUNT(DISTINCT admno) AS students_affected,
    COUNT(*) AS scheme_not_found_rows
FROM exam_wise_report
WHERE exam_name = 'Scheme Not Found'
GROUP BY department, semester, code, course
ORDER BY students_affected DESC, scheme_not_found_rows DESC;

-- Bonus (+3): Morning health-check query during exam season
-- Returned row count: 1
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN exam_name = 'Scheme Not Found' THEN 1 ELSE 0 END) AS missing_scheme_rows,
    SUM(CASE WHEN marks_entry_status = 'Not Done' THEN 1 ELSE 0 END) AS marks_not_done_rows,
    SUM(CASE WHEN marks_obtained IS NOT NULL THEN 1 ELSE 0 END) AS marks_present_rows,
    SUM(CASE WHEN result_publish = 'Published' AND marks_obtained IS NULL THEN 1 ELSE 0 END) AS published_without_marks
FROM exam_wise_report;