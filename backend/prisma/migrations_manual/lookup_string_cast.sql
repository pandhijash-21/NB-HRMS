-- Convert enum columns to text so dropdown options are fully configurable
ALTER TABLE employee_general_info
  ALTER COLUMN employee_category TYPE TEXT USING employee_category::text;

ALTER TABLE employee_general_info
  ALTER COLUMN appointment_type TYPE TEXT USING appointment_type::text;

ALTER TABLE employee_assignments
  ALTER COLUMN appointment_type TYPE TEXT USING appointment_type::text;

ALTER TABLE employee_personal_info
  ALTER COLUMN gender TYPE TEXT USING gender::text;

ALTER TABLE employee_personal_info
  ALTER COLUMN marital_status TYPE TEXT USING marital_status::text;

ALTER TABLE employee_personal_info
  ALTER COLUMN blood_group TYPE TEXT USING blood_group::text;

ALTER TABLE family_members
  ALTER COLUMN relation TYPE TEXT USING relation::text;

ALTER TABLE academic_qualifications
  ALTER COLUMN degree_type TYPE TEXT USING degree_type::text;

ALTER TABLE academic_qualifications
  ALTER COLUMN medium TYPE TEXT USING medium::text;

ALTER TABLE employee_experience
  ALTER COLUMN type TYPE TEXT USING type::text;
