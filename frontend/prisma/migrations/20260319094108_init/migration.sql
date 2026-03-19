-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('MALE', 'FEMALE', 'OTHER');

-- CreateEnum
CREATE TYPE "MaritalStatus" AS ENUM ('SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED');

-- CreateEnum
CREATE TYPE "BloodGroup" AS ENUM ('A_POS', 'A_NEG', 'B_POS', 'B_NEG', 'O_POS', 'O_NEG', 'AB_POS', 'AB_NEG');

-- CreateEnum
CREATE TYPE "EmployeeCategory" AS ENUM ('TEACHING', 'NON_TEACHING', 'CONTRACT', 'VISITING');

-- CreateEnum
CREATE TYPE "AppointmentType" AS ENUM ('FULL_TIME_REGULAR', 'FULL_TIME_CONTRACT', 'PART_TIME', 'VISITING', 'DEPUTATION');

-- CreateEnum
CREATE TYPE "FamilyRelation" AS ENUM ('FATHER', 'MOTHER', 'SPOUSE', 'SON', 'DAUGHTER', 'BROTHER', 'SISTER', 'GUARDIAN', 'OTHER');

-- CreateEnum
CREATE TYPE "DegreeType" AS ENUM ('SSC', 'HSC', 'DIPLOMA', 'BACHELOR', 'MASTER', 'PHD');

-- CreateEnum
CREATE TYPE "AcademicMedium" AS ENUM ('GUJARATI', 'HINDI', 'ENGLISH', 'MARATHI', 'OTHER');

-- CreateEnum
CREATE TYPE "EmployeeStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'ON_LEAVE', 'RESIGNED', 'RETIRED', 'TERMINATED');

-- CreateEnum
CREATE TYPE "AddressType" AS ENUM ('LOCAL', 'PERMANENT');

-- CreateTable
CREATE TABLE "employees" (
    "id" SERIAL NOT NULL,
    "abbreviation" VARCHAR(10),
    "user_id" TEXT NOT NULL,
    "status" "EmployeeStatus" NOT NULL DEFAULT 'ACTIVE',
    "photo_url" TEXT,
    "signature_url" TEXT,
    "last_updated_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_by" TEXT,

    CONSTRAINT "employees_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employee_general_info" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "full_name" TEXT NOT NULL,
    "original_joining_date" TIMESTAMP(3) NOT NULL,
    "joining_date" TIMESTAMP(3) NOT NULL,
    "increment_month" TEXT,
    "organization" TEXT NOT NULL,
    "sub_organization" TEXT,
    "department" TEXT NOT NULL,
    "functional_department" TEXT,
    "first_reporting" TEXT,
    "second_reporting" TEXT,
    "employee_category" "EmployeeCategory" NOT NULL,
    "designation" TEXT NOT NULL,
    "shift" TEXT,
    "appointment_type" "AppointmentType",
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "employee_general_info_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employee_personal_info" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "birth_date" TIMESTAMP(3) NOT NULL,
    "birth_place" TEXT,
    "home_town" TEXT,
    "gender" "Gender" NOT NULL,
    "marital_status" "MaritalStatus" NOT NULL,
    "nationality" TEXT NOT NULL DEFAULT 'INDIAN',
    "mother_tongue" TEXT,
    "blood_group" "BloodGroup",
    "cast_category" TEXT,
    "sub_caste" TEXT,
    "nominee_name" TEXT,
    "nominee_relation" TEXT,
    "aadhaar_no" TEXT,
    "pan_no" TEXT,
    "aadhaar_card_url" TEXT,
    "pan_card_url" TEXT,
    "passport_no" TEXT,
    "passport_issue_place" TEXT,
    "passport_issue_date" TIMESTAMP(3),
    "passport_expiry_date" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "employee_personal_info_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employee_addresses" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "address_type" "AddressType" NOT NULL,
    "flat_block_no" TEXT,
    "building_society" TEXT,
    "area" TEXT,
    "city" TEXT,
    "state" TEXT,
    "country" TEXT DEFAULT 'INDIA',
    "zip_postal_code" TEXT,
    "phone_no" TEXT,
    "mobile_no" TEXT,
    "intercom_no" TEXT,
    "personal_email" TEXT,
    "institute_email" TEXT,
    "url" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "employee_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employee_other_info" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "skill_set" TEXT,
    "hobbies" TEXT,
    "strength" TEXT,
    "weakness" TEXT,
    "is_handicapped" BOOLEAN NOT NULL DEFAULT false,
    "handicap_details" TEXT,
    "height_in_feet" DECIMAL(5,2),
    "weight_in_kg" DECIMAL(5,2),
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "employee_other_info_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_members" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "relation" "FamilyRelation" NOT NULL,
    "name" TEXT NOT NULL,
    "city" TEXT,
    "mobile_no" TEXT,
    "personal_email" TEXT,
    "date_of_birth" TIMESTAMP(3),
    "aadhaar_no" TEXT,
    "is_nominee" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "family_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "academic_qualifications" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "degree_type" "DegreeType" NOT NULL,
    "degree_name" TEXT,
    "medium" "AcademicMedium",
    "board_university" TEXT NOT NULL,
    "school_college" TEXT NOT NULL,
    "passing_year" INTEGER NOT NULL,
    "percentage" DECIMAL(5,2),
    "grade" TEXT,
    "specialization" TEXT,
    "duration_years" INTEGER,
    "total_semesters" INTEGER,
    "certificate_url" TEXT,
    "sem1_marksheet_url" TEXT,
    "sem2_marksheet_url" TEXT,
    "sem3_marksheet_url" TEXT,
    "sem4_marksheet_url" TEXT,
    "sem5_marksheet_url" TEXT,
    "sem6_marksheet_url" TEXT,
    "sem7_marksheet_url" TEXT,
    "sem8_marksheet_url" TEXT,
    "is_verified" BOOLEAN NOT NULL DEFAULT false,
    "verified_by" TEXT,
    "verified_at" TIMESTAMP(3),
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "academic_qualifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_log" (
    "id" TEXT NOT NULL,
    "table_name" TEXT NOT NULL,
    "record_id" TEXT NOT NULL,
    "employee_id" INTEGER,
    "field_name" TEXT NOT NULL,
    "old_value" TEXT,
    "new_value" TEXT,
    "changed_by" TEXT NOT NULL,
    "changed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "change_reason" TEXT,
    "ip_address" TEXT,
    "user_agent" TEXT,

    CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "employees_user_id_key" ON "employees"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "employee_general_info_employee_id_key" ON "employee_general_info"("employee_id");

-- CreateIndex
CREATE UNIQUE INDEX "employee_personal_info_employee_id_key" ON "employee_personal_info"("employee_id");

-- CreateIndex
CREATE UNIQUE INDEX "employee_addresses_employee_id_address_type_key" ON "employee_addresses"("employee_id", "address_type");

-- CreateIndex
CREATE UNIQUE INDEX "employee_other_info_employee_id_key" ON "employee_other_info"("employee_id");

-- CreateIndex
CREATE UNIQUE INDEX "academic_qualifications_employee_id_degree_type_key" ON "academic_qualifications"("employee_id", "degree_type");

-- CreateIndex
CREATE INDEX "audit_log_table_name_record_id_idx" ON "audit_log"("table_name", "record_id");

-- CreateIndex
CREATE INDEX "audit_log_employee_id_idx" ON "audit_log"("employee_id");

-- CreateIndex
CREATE INDEX "audit_log_changed_at_idx" ON "audit_log"("changed_at");

-- AddForeignKey
ALTER TABLE "employee_general_info" ADD CONSTRAINT "employee_general_info_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employee_personal_info" ADD CONSTRAINT "employee_personal_info_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employee_addresses" ADD CONSTRAINT "employee_addresses_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employee_other_info" ADD CONSTRAINT "employee_other_info_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_members" ADD CONSTRAINT "family_members_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "academic_qualifications" ADD CONSTRAINT "academic_qualifications_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
