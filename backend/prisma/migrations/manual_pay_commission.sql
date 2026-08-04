-- Migrate pay_commissions from enum commission_type to string code
ALTER TABLE pay_commissions ADD COLUMN IF NOT EXISTS code TEXT;
UPDATE pay_commissions SET code = commission_type::text WHERE code IS NULL;
ALTER TABLE pay_commissions ALTER COLUMN code SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS pay_commissions_code_key ON pay_commissions(code);

ALTER TABLE pay_commissions ADD COLUMN IF NOT EXISTS rule_editor_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE pay_commissions ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0;
ALTER TABLE pay_commissions ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE pay_commissions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

UPDATE pay_commissions SET sort_order = 10 WHERE code = 'FIFTH';
UPDATE pay_commissions SET sort_order = 20 WHERE code = 'SIXTH';

ALTER TABLE pay_commissions DROP CONSTRAINT IF EXISTS pay_commissions_commission_type_key;
ALTER TABLE pay_commissions DROP COLUMN IF EXISTS commission_type;

-- employee_salary_info: pay_commission_id FK
ALTER TABLE employee_salary_info ADD COLUMN IF NOT EXISTS pay_commission_id TEXT;
UPDATE employee_salary_info esi
SET pay_commission_id = pc.id
FROM pay_commissions pc
WHERE esi.pay_commission_type::text = pc.code
  AND esi.pay_commission_id IS NULL;

ALTER TABLE employee_salary_info DROP COLUMN IF EXISTS pay_commission_type;

-- employee_salary_records: pay_commission_code
ALTER TABLE employee_salary_records ADD COLUMN IF NOT EXISTS pay_commission_code TEXT;
UPDATE employee_salary_records esr
SET pay_commission_code = esr.pay_commission_type::text
WHERE pay_commission_code IS NULL;
ALTER TABLE employee_salary_records ALTER COLUMN pay_commission_code SET NOT NULL;
ALTER TABLE employee_salary_records DROP COLUMN IF EXISTS pay_commission_type;

DROP TYPE IF EXISTS "PayCommissionType";
