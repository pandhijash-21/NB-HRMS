-- Migration: Seed distinct roles, designations, and departments
-- Safe idempotent inserts so on deploy (prisma migrate deploy) they are added automatically

-- 1. Insert Roles
INSERT INTO "roles" ("id", "name", "description", "is_system", "is_active", "created_at", "updated_at")
VALUES
  (gen_random_uuid(), 'Accountant', 'Accountant company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Admin Sales', 'Admin Sales company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'BDM', 'BDM company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'CEO', 'CEO company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Closing Manager', 'Closing Manager company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Data Analytics', 'Data Analytics company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Digital Marketing', 'Digital Marketing company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Director', 'Director company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Driver', 'Driver company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'HR & Admin', 'HR & Admin company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Housekeeping', 'Housekeeping company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'IT Intern', 'IT Intern company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Land Co-ordinator', 'Land Co-ordinator company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Legal Co-ordinator', 'Legal Co-ordinator company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Loan Executive', 'Loan Executive company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Loan Manager', 'Loan Manager company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Marketing & Operation', 'Marketing & Operation company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Marketing Consultant', 'Marketing Consultant company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Marketing Manager', 'Marketing Manager company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'PA to Chairman', 'PA to Chairman company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Pantry', 'Pantry company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Pantry & Field', 'Pantry & Field company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Project Co-ordinator', 'Project Co-ordinator company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Purchase', 'Purchase company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Reception', 'Reception company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Rental Executive', 'Rental Executive company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Sales Associate', 'Sales Associate company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Sales Co-ordinator', 'Sales Co-ordinator company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Sales Executive', 'Sales Executive company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Sales Manager', 'Sales Manager company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Sales Operations', 'Sales Operations company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Site Supervision', 'Site Supervision company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Social Media Marketing Executive', 'Social Media Marketing Executive company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Store', 'Store company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Tax & Finance Executive', 'Tax & Finance Executive company role', false, true, NOW(), NOW()),
  (gen_random_uuid(), 'Telecalling', 'Telecalling company role', false, true, NOW(), NOW())
ON CONFLICT ("name") DO UPDATE SET "is_active" = true;

-- 2. Insert Default Permissions for Roles
INSERT INTO "role_permissions" ("id", "role_id", "module_key", "can_read", "can_write", "can_approve", "can_delete", "can_export", "employee_view_scope", "updated_at")
SELECT
  gen_random_uuid(),
  r.id,
  m.key,
  CASE WHEN m.key IN ('ATTENDANCE', 'PROJECTS', 'WORK_ORDERS') THEN false ELSE true END,
  CASE WHEN m.key IN ('ATTENDANCE', 'PROJECTS', 'WORK_ORDERS') THEN false ELSE true END,
  false,
  false,
  false,
  'NONE'::"EmployeeViewScope",
  NOW()
FROM "roles" r
CROSS JOIN "system_modules" m
WHERE r."is_system" = false
ON CONFLICT ("role_id", "module_key") DO NOTHING;

-- 3. Insert Designations linked to Roles
INSERT INTO "designations" ("id", "name", "slug", "is_alias", "linked_role_id", "is_active", "sort_order", "created_at", "updated_at")
VALUES
  (gen_random_uuid(), 'Accountant', 'accountant', false, (SELECT id FROM "roles" WHERE name = 'Accountant' LIMIT 1), true, 1, NOW(), NOW()),
  (gen_random_uuid(), 'Admin Executive', 'admin_executive', false, (SELECT id FROM "roles" WHERE name = 'Admin Sales' LIMIT 1), true, 2, NOW(), NOW()),
  (gen_random_uuid(), 'Asst. Purchase Manager', 'asst_purchase_manager', false, (SELECT id FROM "roles" WHERE name = 'Purchase' LIMIT 1), true, 3, NOW(), NOW()),
  (gen_random_uuid(), 'Billing Engineer', 'billing_engineer', false, (SELECT id FROM "roles" WHERE name = 'Project Co-ordinator' LIMIT 1), true, 4, NOW(), NOW()),
  (gen_random_uuid(), 'CEO', 'ceo', false, (SELECT id FROM "roles" WHERE name = 'CEO' LIMIT 1), true, 5, NOW(), NOW()),
  (gen_random_uuid(), 'Closing Manager', 'closing_manager', false, (SELECT id FROM "roles" WHERE name = 'Closing Manager' LIMIT 1), true, 6, NOW(), NOW()),
  (gen_random_uuid(), 'Data Analytics', 'data_analytics', false, (SELECT id FROM "roles" WHERE name = 'Data Analytics' LIMIT 1), true, 7, NOW(), NOW()),
  (gen_random_uuid(), 'Digital Marketing Executive', 'digital_marketing_executive', false, (SELECT id FROM "roles" WHERE name = 'Digital Marketing' LIMIT 1), true, 8, NOW(), NOW()),
  (gen_random_uuid(), 'Director', 'director', false, (SELECT id FROM "roles" WHERE name = 'Director' LIMIT 1), true, 9, NOW(), NOW()),
  (gen_random_uuid(), 'Driver', 'driver', false, (SELECT id FROM "roles" WHERE name = 'Driver' LIMIT 1), true, 10, NOW(), NOW()),
  (gen_random_uuid(), 'Field Executive', 'field_executive', false, (SELECT id FROM "roles" WHERE name = 'Pantry & Field' LIMIT 1), true, 11, NOW(), NOW()),
  (gen_random_uuid(), 'HK Boy', 'hk_boy', false, (SELECT id FROM "roles" WHERE name = 'Housekeeping' LIMIT 1), true, 12, NOW(), NOW()),
  (gen_random_uuid(), 'HOD - BDM', 'hod_bdm', false, (SELECT id FROM "roles" WHERE name = 'BDM' LIMIT 1), true, 13, NOW(), NOW()),
  (gen_random_uuid(), 'HR Head', 'hr_head', false, (SELECT id FROM "roles" WHERE name = 'HR & Admin' LIMIT 1), true, 14, NOW(), NOW()),
  (gen_random_uuid(), 'IT Intern', 'it_intern', false, (SELECT id FROM "roles" WHERE name = 'IT Intern' LIMIT 1), true, 15, NOW(), NOW()),
  (gen_random_uuid(), 'Legal Co-ordinator', 'legal_coordinator', false, (SELECT id FROM "roles" WHERE name = 'Legal Co-ordinator' LIMIT 1), true, 16, NOW(), NOW()),
  (gen_random_uuid(), 'Loan Executive', 'loan_executive', false, (SELECT id FROM "roles" WHERE name = 'Loan Executive' LIMIT 1), true, 17, NOW(), NOW()),
  (gen_random_uuid(), 'Loan Manager', 'loan_manager', false, (SELECT id FROM "roles" WHERE name = 'Loan Manager' LIMIT 1), true, 18, NOW(), NOW()),
  (gen_random_uuid(), 'Marketing & Operation Head', 'marketing_operation_head', false, (SELECT id FROM "roles" WHERE name = 'Marketing & Operation' LIMIT 1), true, 19, NOW(), NOW()),
  (gen_random_uuid(), 'Marketing Consultant', 'marketing_consultant', false, (SELECT id FROM "roles" WHERE name = 'Marketing Consultant' LIMIT 1), true, 20, NOW(), NOW()),
  (gen_random_uuid(), 'Marketing Manager', 'marketing_manager', false, (SELECT id FROM "roles" WHERE name = 'Marketing Manager' LIMIT 1), true, 21, NOW(), NOW()),
  (gen_random_uuid(), 'PA to Chairman', 'pa_to_chairman', false, (SELECT id FROM "roles" WHERE name = 'PA to Chairman' LIMIT 1), true, 22, NOW(), NOW()),
  (gen_random_uuid(), 'Pantry Boy', 'pantry_boy', false, (SELECT id FROM "roles" WHERE name = 'Pantry' LIMIT 1), true, 23, NOW(), NOW()),
  (gen_random_uuid(), 'Project Head', 'project_head', false, (SELECT id FROM "roles" WHERE name = 'Sales Operations' LIMIT 1), true, 24, NOW(), NOW()),
  (gen_random_uuid(), 'Receptionist', 'receptionist', false, (SELECT id FROM "roles" WHERE name = 'Reception' LIMIT 1), true, 25, NOW(), NOW()),
  (gen_random_uuid(), 'Rental Executive', 'rental_executive', false, (SELECT id FROM "roles" WHERE name = 'Rental Executive' LIMIT 1), true, 26, NOW(), NOW()),
  (gen_random_uuid(), 'Sales Associate', 'sales_associate', false, (SELECT id FROM "roles" WHERE name = 'Sales Associate' LIMIT 1), true, 27, NOW(), NOW()),
  (gen_random_uuid(), 'Sales Executive', 'sales_executive', false, (SELECT id FROM "roles" WHERE name = 'Sales Executive' LIMIT 1), true, 28, NOW(), NOW()),
  (gen_random_uuid(), 'Site Engineer', 'site_engineer', false, (SELECT id FROM "roles" WHERE name = 'Site Supervision' LIMIT 1), true, 29, NOW(), NOW()),
  (gen_random_uuid(), 'Social Media Marketing Executive', 'social_media_marketing_executive', false, (SELECT id FROM "roles" WHERE name = 'Social Media Marketing Executive' LIMIT 1), true, 30, NOW(), NOW()),
  (gen_random_uuid(), 'Store Executive', 'store_executive', false, (SELECT id FROM "roles" WHERE name = 'Store' LIMIT 1), true, 31, NOW(), NOW()),
  (gen_random_uuid(), 'Tax & Finance Executive', 'tax_finance_executive', false, (SELECT id FROM "roles" WHERE name = 'Tax & Finance Executive' LIMIT 1), true, 32, NOW(), NOW()),
  (gen_random_uuid(), 'Telecaller', 'telecaller', false, (SELECT id FROM "roles" WHERE name = 'Telecalling' LIMIT 1), true, 33, NOW(), NOW())
ON CONFLICT ("name") DO UPDATE SET
  "slug" = EXCLUDED."slug",
  "linked_role_id" = EXCLUDED."linked_role_id",
  "is_active" = true;

-- 4. Insert Departments in system_lookups
INSERT INTO "system_lookups" ("id", "category", "code", "label", "is_active", "sort_order", "created_at", "updated_at")
VALUES
  (gen_random_uuid(), 'DEPARTMENT', 'ACCOUNT', 'Account', true, 1, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'BDM', 'BDM', true, 2, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'DIGITAL_MARKETING', 'Digital Marketing', true, 3, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'DRIVER', 'Driver', true, 4, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'ENGINEER', 'Engineer', true, 5, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'FIELD', 'Field', true, 6, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'FINANCE', 'Finance', true, 7, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'HOUSEKEEPING', 'Housekeeping', true, 8, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'HR', 'HR', true, 9, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'IT', 'IT', true, 10, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'LEGAL', 'Legal', true, 11, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'LOAN', 'Loan', true, 12, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'MANAGEMENT', 'Management', true, 13, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'MARKETING', 'Marketing', true, 14, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'MARKETING_OPERATION', 'Marketing & Operation', true, 15, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'MIS', 'MIS', true, 16, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'PANTRY', 'Pantry', true, 17, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'PERSONAL_ASSISTANT', 'Personal Assistant', true, 18, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'PURCHASE', 'Purchase', true, 19, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'RECEPTION', 'Reception', true, 20, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'SALES', 'Sales', true, 21, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'SOCIAL_MEDIA_MARKETING', 'Social Media Marketing', true, 22, NOW(), NOW()),
  (gen_random_uuid(), 'DEPARTMENT', 'STORE', 'Store', true, 23, NOW(), NOW())
ON CONFLICT ("category", "code") DO UPDATE SET
  "label" = EXCLUDED."label",
  "is_active" = true,
  "sort_order" = EXCLUDED."sort_order";
