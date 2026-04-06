# HRMS — Day 2 Requirements & Implementation Roadmap

You are a senior full-stack architect and UI/UX expert.
This document tracks the core requirements and their current implementation status in the HRMS application.

---

## 🧩 CORE REQUIREMENTS

### 1. Employee Section (Required)
- [x] **Personal Email**: Required Gmail validation. (Implemented with optional OTP)
- [x] **Institutional Email**: Optional (format: `firstname.lastname@gandhinagaruni.ac.in`)
- [x] **Organization**:
  - Main: GU / Platinum Foundation
  - Sub-org: 15 institutes (GU Institute of Technology, Management, Commerce, etc.)
- [x] **Auto-Generation**:
  - [x] **Abbreviation**: Auto-generated from name (e.g., Ishaan Ray → IR)
  - [x] **Employee Code**: Auto-generated, unique system identifier.

---

### 2. General Section (Required)
- [x] **Full Name**: Required (text)
- [x] **Designation**: Required (text)
- [x] **Department**: Required (text)
- [x] **Functional Department**: Optional (text) {Implemented in UI display}
- [x] **Sub-organization**: Optional (text) {Implemented in UI display}
- [x] **Joining Date**: Required (date)
- [x] **Original Joining Date**: Required (date)
- [x] **Employee Category**: Required (dropdown)
- [x] **Organization**: Required (dropdown)
- [x] **Employee Code**: Required (text)
- [x] **Appointment Type**: Implemented in UI display (4 types)
---

### 3. Personal Section (Required)
- [x] **Core Identity**: Date of Birth, Gender, Marital Status, Nationality, Blood Group.
- [x] **Upload Photo** (required)
- [x] **Upload Signature** (required)

---

### 3. Address Section (Required)
- [x] **Emails**: Personal & Institutional email capture. (Personal Email added to Form UI)
- [x] **Fields**: Flat/Block, Building/Society, Area, City, State, Country, Zip, Mobile, Institutional Email.

---

### 4. Other Details (Required)
- [x] **Identity**: Aadhar Number, PAN Number.
- [x] **Physical**: Height, Weight.
- [ ] **BMI**: Auto-calculate (weight / height^2) implemented in UI. (Not visible in UI)
- [x] **Uploads**: Aadhar, PAN (required), Passport (optional) 🚨 *PLACEHOLDERS ONLY*

---

### 5. Family Members (At least 1 required)
- [x] **Relationship**: Dropdown (Father, Mother, Spouse, etc.) + "Other".
- [x] **Contact**: City, Phone Number, Personal Email. 
- [x] **Status**: Nominee toggle implemented in creation dialog.
- [x] **Identity**: Aadhar Number + Upload (UI present in dialog).

---

### 6. Education Section (Required)
- [x] **Common Fields**: Medium, School/College, Percentage/CGPA.
- [x] **SSC**: Marksheet upload (Placeholder implemented).
  - [x] UI labels refined for Indian context (Board/School Name).
- [x] **HSC / Diploma**:
  - [x] If HSC → Stream dropdown (Science, Commerce, Arts).
  - [x] If Diploma → Degree certificate.
- [x] **Advanced Degrees**:
  - [x] **UG**: 8 marksheet slots provided (min 6 required).
  - [x] **PG**: 4 marksheet slots provided.
  - [x] **PhD**: Degree certificate.
- [x] **Other**: Custom certificates.

---

### 7. Experience Section (Dynamic, repeatable)
- [ ] **Experience Type**: Teaching/Industry. 🚨 *MISSING TAB*
- [ ] **History**: Designation, Organization, From–To Dates, JD, Last Salary. 🚨 *MISSING TAB*
- [ ] **Uploads**: Experience Letter, Last Paycheck, Recommendation Letters. 🚨 *MISSING TAB*

---

## 🎨 UI/UX EXPECTATIONS

- [x] **Dynamic form rendering**: Config-driven tabbed UI implemented.
- [x] **Conditional fields**: HSC vs Diploma logic supported in backend/schema.
- [x] **Repeatable sections**: Family member management implemented.
- [x] **File upload with validation**: Supported in Education section placeholders.
- [x] **Email verification via OTP**: Implemented and configurable as optional.
- [x] **Auto-calculations (BMI)**: Implemented in Other Details tab.
- [x] **Auto-generated fields**: Employee code and abbreviation implemented.
- [x] **Modern UX**: Clean, stepper-like tabbed navigation.

---

## 🎨 UI/UX EXPECTATIONS

- [x] Modern, minimal, professional design.
- [x] Section-based layout (Tabs).
- [x] Smooth transitions & interactions.
- [x] Clear validation messages (Zod-driven).
- [x] Mobile responsive layout.

---

## 🚀 CURRENT PROJECT STATUS SUMMARY

> [!WARNING]
> **Priority Gaps Identified:**
> 1. **Experience Module**: No UI/Frontend tab exists for work experience.
> 2. **Media Uploads**: Personal Photo/Signature and Identity Document (Aadhar/PAN/Family Aadhar) uploads are missing from the profile tabs.
> 3. **Calculations**: BMI auto-calculation is not yet implemented in the UI.

---

## 🧠 OUTPUT ARCHITECTURE

1. **Frontend**: Next.js + Tailwind + Radix UI (Shadcn).
2. **State Management**: React Hook Form + Zod + TanStack Query.
3. **Backend**: Node.js/Express + Prisma ORM + PostgreSQL.
4. **Auth**: JWT + Redis + Role-Based Access Control (RBAC).
5. **Storage**: Cloudinary for file/image uploads.