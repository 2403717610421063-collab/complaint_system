# Project Presentation / Report Guide — Civic Connect

Use this as a **ready-to-fill template** for:
- Project presentation (PPT/Slides)
- Project report (PDF/Word)
- Viva/demo script

It is written to match this repository’s implementation: Flutter + Firebase + role-based dashboards + TNEB polygon routing.

---

## 1) Title Page (Copy/Paste)

**Project Title:** Civic Connect — Complaint Management System (Multi-Role)

**Domain:** Civic Services / Utility Complaint Management (TNEB-style hierarchy)

**Technology:** Flutter, Firebase Auth, Cloud Firestore, Geo routing (point-in-polygon)

**Prepared By:** <Name(s)>

**Institution/Department:** <...>

**Guide/Faculty:** <...>

**Date:** <...>

---

## 2) Abstract (150–250 words)

Write 1 short paragraph covering:
- Problem: complaints are delayed / manual routing / poor visibility
- Proposed solution: mobile-first multi-role workflow with auto-routing + escalation
- Implementation: Flutter app + Firebase backend + geo-based AE/AEE/EE tagging
- Outcome: faster assignment, accountability, role dashboards, reporting

**Abstract (Draft Placeholder):**
> This project implements a role-based civic complaint platform that enables citizens to register issues with location and evidence, while officials and field staff manage triage, assignment, interventions, and resolution tracking. The system uses Firebase Authentication for identity and Cloud Firestore as a real-time data store to synchronize status and workflow across multiple roles. A polygon-based geo-routing pipeline maps complaint coordinates to a TNEB-style administrative hierarchy (AE section / AEE subdivision / EE division) to support automatic ownership and escalation. Executive dashboards provide analytics, heatmaps, and report export to improve operational visibility. The solution reduces manual routing effort, strengthens accountability through SLA-aware escalation, and improves transparency for both citizens and administrators.

**Keywords:** Flutter, Firebase, Cloud Firestore, Geo Routing, Complaint Workflow, SLA, Escalation, Dashboard Analytics

---

## 3) Problem Statement

Describe:
- Current issues in complaint handling (manual calls, no SLA, no routing)
- Impact (delays, no accountability, repeat complaints)
- Need for system (tracking + analytics + assigned responsibility)

**Problem Statement (Fill):**
- <Point 1>
- <Point 2>
- <Point 3>

---

## 4) Objectives

Example objectives (edit as needed):
- Enable citizens to register complaints with photo and GPS location
- Provide role-based dashboards for AE/AEE/EE and field workers
- Auto-route complaints to the correct section/subdivision/division using polygons
- Track lifecycle status with escalation based on SLA deadlines
- Generate executive summary reports (PDF) and analytics/heatmaps

---

## 5) Scope

### In Scope
- Complaint creation, list, status tracking
- Role routing via `Users/{uid}` fields
- Geo-routing using TNEB polygon data
- Assignment to workers and workload-based selection
- Email notification support (non-web)
- Localization (English/Tamil)

### Out of Scope (Optional)
- Payment gateway
- Full ML-based complaint classification (not implemented in this repo)
- On-device offline mode

---

## 6) Users & Roles (System Actors)

**Citizen**
- Creates complaint (title, description, category, image, location, EB service number)
- Views status updates

**AE (Assistant Engineer)**
- Triage and assign field staff
- Monitors active workload

**AEE (Assistant Executive Engineer)**
- Intervention workflow
- Captures operational details (estimated cost, budget source, work order info, etc.)

**EE (Executive Engineer)**
- Executive dashboard + analytics
- Reviews escalations and overall status
- Generates reports

**Field Worker (Lineman/Foreman)**
- Receives assigned jobs
- Uploads resolution evidence

**Admin**
- Manages official accounts and admin views

---

## 7) System Architecture

### High-Level
- Flutter client app (multi-platform)
- Firebase Auth for login
- Cloud Firestore for real-time data
- Optional Cloud Functions (client hooks present)

### Architecture Diagram (Mermaid)

Paste into slides (or render using Mermaid tools):

```mermaid
flowchart LR
  Citizen[Citizen App UI] -->|Firebase Auth| Auth[(Firebase Auth)]
  Citizen -->|Create/Update Complaint| FS[(Cloud Firestore)]

  Official[Official Dashboards
AE/AEE/EE] -->|Realtime Streams| FS
  Worker[Field Worker UI] -->|Assignments/Updates| FS
  Admin[Admin UI] --> FS

  Geo[TNEB Polygon Routing
(point-in-polygon)] --> FS
  Reports[PDF Reports
Charts/Heatmap] --> Official

  Email[SMTP Email Service
(non-web)] --> Official
```

### Where to Reference in Repo
- App entry: lib/main.dart
- Role routing: lib/Auth_Wrapper.dart
- Routing details: ../ROUTING_ARCHITECTURE.md
- Field audit: ../FIREBASE_FIELDS_AUDIT.md

---

## 8) Workflow / Use Case Flow

### Complaint Lifecycle (Typical)
1. Citizen logs in
2. Citizen submits complaint (GPS + photo)
3. System tags complaint with AE/AEE/EE region via polygon routing
4. AE assigns a worker
5. Worker completes job and uploads proof
6. AEE adds intervention details (estimated cost, budget source, etc.)
7. EE monitors escalations and generates reports
8. Complaint closes

### Status Handling
Describe the key statuses used in your deployment (examples):
- Submitted → Assigned → In Progress → Resolved → Closed
- Escalation levels based on SLA

---

## 9) Database Design (Firestore)

### Collections
- Users
- complaints
- field_workers (legacy)

### Key Fields (Mention in Report)
For the report, do not list every field—only the important ones:

**Users/{uid}**
- role (ADMIN/CITIZEN/OFFICIAL/FIELD_WORKER)
- officialRole (AE/AEE/EE/Lineman/Foreman/...)
- contact + basic profile fields

**complaints/{complaintId}**
- title, description, category, priority
- latitude, longitude
- status, assignedRole/currentOwnerRole
- assignedWorkerId/Name/Role
- SLA + escalation fields
- operational fields: estimatedCost, budgetSource, workOrderNumber, contractorName, etc.

---

## 10) Key Implementation Highlights (What to Explain in Viva)

### A) TNEB Polygon-Based Auto Routing
- Asset: assets/TNEB_Master_Data.json
- Logic: point-in-polygon check (turf)
- Output tags: AE section, AEE subdivision, EE division

Explain:
- Why polygon routing (precise boundaries vs nearest-distance)
- How complaint coordinates are mapped

### B) Worker Routing / Load Balancing
- Seeds default workers per AE section
- Selects eligible workers by role + load + online status

### C) SLA & Escalation
- SLA deadline set on assignment
- Escalates ownership AE → AEE → EE if overdue

### D) Reports & Analytics
- Dashboard charts (fl_chart)
- Heatmap visualization
- PDF export (pdf + printing)

---

## 11) UI Screens to Capture (For Slides)

Add screenshots for each role:

**Citizen**
- Login
- Add Complaint
- Complaint List / Tracking

**AE**
- Complaint triage list
- Assign worker screen

**AEE**
- Intervention screen (show estimated cost, budget source)

**EE**
- Dashboard overview (analytics + heatmap)
- Complaints list with search/sort/status tabs
- Profile
- Report export

**Field Worker**
- Assigned jobs
- Proof upload

**Admin**
- Admin dashboard
- Create official user

---

## 12) Testing & Validation

Mention what you validated:
- Flutter analyze + flutter test
- Manual UAT checks: login flows, complaint create/update, assignment, escalation, reporting

Suggested checklist:
- Auth: create/login/logout
- Firestore: read/write permission rules (if used)
- Routing: same coordinate maps to expected region
- Workflow: status transitions consistent across roles
- Web preview limitations acknowledged (email)

---

## 13) Deployment / Demo Setup

### Demo Data Requirements
- Create users in Users collection:
  - 1 Citizen
  - 1 AE
  - 1 AEE
  - 1 EE
  - 1 Lineman + 1 Foreman (FIELD_WORKER)

### Demo Script (5–7 minutes)
1. Citizen submits complaint with location + photo
2. Show complaint appears in AE dashboard (auto-tagged area)
3. AE assigns a lineman
4. Worker updates job/proof
5. AEE fills intervention details (estimated cost, budget source)
6. EE views analytics and generates PDF report

---

## 14) Limitations (Be Honest)

Examples:
- SMTP email not supported on web preview
- Field naming inconsistencies can happen if legacy keys exist (EB service number)
- Offline-first not implemented

---

## 15) Future Enhancements

Examples:
- ML-based category prediction / duplicate detection
- Backend-triggered email/SMS notifications via Cloud Functions
- Role-based Firestore Security Rules hardening + audit logs
- Offline caching + sync
- Admin analytics portal

---

## 16) Conclusion

Summarize:
- What problem was solved
- What is implemented and working
- Why this solution improves tracking, routing, and accountability

---

## 17) References (Project Docs)

Use these files as sources:
- ../README.md
- ../ROUTING_ARCHITECTURE.md
- ../FIREBASE_FIELDS_AUDIT.md
- ../FIREBASE_SMOKE_TEST_CHECKLIST.md
- ../walkthrough.md

---

## Appendix A — Slide Outline (Quick)

1. Title
2. Problem Statement
3. Objectives
4. Scope
5. Tech Stack
6. Architecture Diagram
7. Data Model
8. Workflow / Use Case
9. Key Feature: Polygon Routing
10. Key Feature: SLA/Escalation
11. Role Dashboards (Screenshots)
12. Reports/Analytics
13. Testing
14. Limitations
15. Future Scope
16. Conclusion

---

## Appendix B — Notes for Report Formatting

- Use consistent headings and figure numbering
- Include 8–12 screenshots total (2–3 per major role)
- Add a short “Implementation Details” section per major subsystem (routing, assignment, escalation)
- Keep code out of the main body; move code snippets to appendix if required
