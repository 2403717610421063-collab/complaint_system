# TNEB-Aware Routing Architecture (End to End)

This document describes the end-to-end routing flow implemented in this project: from citizen complaint creation to AE/AEE/EE ownership and field-worker assignment, using TNEB spatial data.

---

## 1. Data Sources & Collections

### 1.1 TNEB Spatial Data

- File: `assets/TNEB_Master_Data.json`
- Type: GeoJSON `FeatureCollection` of TNEB sections.
- Used properties of each feature:
  - `section_name` / `section_na`  → AE section name
  - `subdivision_name` / `subdivisio` → AEE subdivision name
  - `division_name` / `division_n` → EE division name
  - `ssmaecode` → AE code
  - `division_name` / `division_n` = `URBAN` → considered part of *Coimbatore Urban* (current routing scope).

### 1.2 Firestore Collections

- `complaints`
   - All citizen complaints.
   - Stores complaint details, GPS, routing state and TNEB metadata.

- `Users`
   - Single source of identity for **all** people:
      - Citizens, admins.
      - AE / AEE / EE officials.
      - Field officers (linemen / foremen).
   - Key fields (by convention):
      - `role` – coarse role (e.g. `CITIZEN`, `ADMIN`, `FIELD_WORKER`, `OFFICIAL`).
      - `officialRole` – fine‑grained designation (e.g. `AE`, `AEE`, `EE`, `Lineman`, `Foreman`).
      - `latitude`, `longitude` – required for AE/AEE/EE so we can map each official to their TNEB section/subdivision/division using `TNEBLocationService`.
      - Identity fields such as `email`, `name`, `phoneNumber`.

   - For field workers, we also store routing/load fields on the same
      user documents (e.g. `section`, `status`, `activeJobs`, `maxJobs`,
      `lastAssignedAt`, contact info, etc.).

---

## 2. Complaint Creation Flow

Relevant code: `lib/screens/add_complaint_screen.dart`, `lib/location/TNEBLocationService.dart`.

### 2.1 Collect Complaint & Location

1. User fills the complaint form (category, description, photos, etc.).
2. App attempts to fetch GPS (`latitude`, `longitude`) using `geolocator`.
3. A new document is created in `complaints/{id}` with all user details and GPS.

### 2.2 TNEB Lookup (Coimbatore URBAN Only)

1. After the complaint is created, the app calls:
   - `TNEBLocationService.getHierarchyForPoint(latitude, longitude)`.
2. Inside `TNEBLocationService.findBoundary`:
   - Load `assets/TNEB_Master_Data.json` as a `FeatureCollection`.
   - For each feature:
     - Read `division_name` or `division_n`.
     - Normalize and require `divisionName == 'URBAN'` (Coimbatore Urban only).
     - Use `turf.booleanPointInPolygon` to test if the complaint GPS lies within the polygon.
   - The first URBAN feature containing the point is considered the match.
3. If a match is found, its `properties` map is passed to `extractHierarchy`.

### 2.3 Extract AE / AEE / EE Hierarchy

`extractHierarchy(properties)` produces a small hierarchy map:

- `aeSection` = `section_name` or `section_na`
- `aeeSubdivision` = `subdivision_name` or `subdivisio`
- `eeDivision` = `division_name` or `division_n`
- `aeCode` = `ssmaecode`

If at least one of these is non-empty, the function returns this map.

### 2.4 Persist TNEB Metadata in Complaint

The complaint document is updated with:

- `tnebAeSection` = `aeSection`
- `tnebAeeSubdivision` = `aeeSubdivision`
- `tnebEeDivision` = `eeDivision`
- `tnebAeCode` = `aeCode`
- `tnebRoutingVersion` = version string (e.g. `"urban_v1"`).

If GPS is missing or no polygon is found, these fields are not set and routing falls back to existing behaviours.

---

## 3. Automatic AE Assignment

Relevant code: `lib/screens/add_complaint_screen.dart` (`_assignInitialAeOwner`).

After TNEB tagging, the app tries to auto-assign the complaint to the responsible AE.

1. Read `aeSection` from the hierarchy (`tnebAeSection`).
2. Query `Users` to find AE officials:
   - `where('officialRole', isEqualTo: 'AE')`.
3. For each AE user candidate:
   - Read their `latitude` and `longitude`.
   - Call `TNEBLocationService.getHierarchyForPoint(lat, lng)` to determine **that official's** TNEB AE section.
   - If the official's `aeSection` (case‑insensitive) matches the complaint's `tnebAeSection`, treat this user as the responsible AE.
4. Once a matching AE user is found, choose an identifier in this order:
   1. `email` (if present and non-empty)
   2. `name`
   3. Firebase Auth UID / user document ID
5. Update the complaint document:
   - `assignedTo` = chosen identifier
   - `assignedRole` = `"ae"`
   - `currentOwnerRole` = `"AE"`

If no AE official with matching section can be derived from `Users`, the complaint remains unassigned but still exists in the system.

---

## 4. Field-Worker Routing (Under Each AE)

Relevant code: `lib/services/worker_routing_service.dart`, `lib/ae_dashboard/assign_staff_screen.dart`, `lib/ae_dashboard/add_worker_screen.dart`.

### 4.1 Default Workers Per AE Section

`WorkerRoutingService.ensureDefaultWorkersForSection(String aeSection)`:

1. Trim and validate `aeSection`; return early if empty.
2. Query `Users` where `section == aeSection` and `role == 'FIELD_WORKER'`.
3. If any worker exists, assume seeding already done and return.
4. Otherwise, build a normalized key from the section name (lowercase, non-alphanumerics replaced with `_`, consecutive `_` collapsed, and leading/trailing `_` removed).
5. Create four default **worker users** with IDs:
   - `fw_${normalizedKey}_1`, `fw_${normalizedKey}_2`, `fw_${normalizedKey}_3`, `fw_${normalizedKey}_4`.
6. For each worker:
    - If a `Users/{id}` doc already exists, skip.
    - Otherwise, create a `FieldWorkerModel` and write it into `Users/{id}` with:
       - `role` = `FIELD_WORKER`
       - `officialRole` = `Lineman` for first three, `Foreman` for last.
       - `section` = AE section
       - `ward` = empty string (wards are no longer used for routing)
       - `status` = `free`, `activeJobs` = 0, `maxJobs` = 3

There is also an admin helper `ensureSeedWorkers()` used from the admin dashboard:

- It scans the `complaints` collection for distinct non-empty `tnebAeSection` values.
- For each section found, it calls `ensureDefaultWorkersForSection(section)`.

### 4.2 Finding Eligible Workers for a Complaint

`WorkerRoutingService.getEligibleWorkersForSection(String aeSection)`:

1. Query all worker users with `section == aeSection` and `role == 'FIELD_WORKER'` from `Users`.
2. Map them using `FieldWorkerModel.fromDocument`.
3. Filter out workers that:
   - Have `status.toLowerCase() == 'offline'`, or
   - Are at or above capacity: `activeJobs >= maxJobs`.
4. Sort remaining workers by:
   1. `activeJobs` ascending (least loaded first).
   2. `lastAssignedAt` (earliest assignment first, with nulls treated as oldest).

### 4.3 Picking a Recommended Worker

`WorkerRoutingService.recommendWorker({ eligibleWorkers, complaintPriority, complaintStatus })`:

1. If no `eligibleWorkers`, return `null`.
2. Normalize `complaintPriority` and `complaintStatus` to lowercase.
3. Choose `preferredRole`:
   - If priority is `high` **or** status is `reopened` → prefer `"foreman"`.
   - Otherwise → prefer `"lineman"`.
4. Return the first worker whose `officialRole` contains the preferred role (case-insensitive).
5. If none match, fall back to the first worker in the list.

### 4.4 AE Assign-Staff Flow

In `assign_staff_screen.dart` (AE dashboard):

1. Determine the AE section from the complaint: `tnebAeSection`.
2. Call `ensureDefaultWorkersForSection(section)` to ensure the four defaults exist.
3. Fetch eligible workers with `getEligibleWorkersForSection(section)`.
4. Compute `recommendedWorker` using `recommendWorker`.
5. Display the list of workers to AE, highlighting the recommended one.
6. When AE confirms an assignment, a service call (e.g. `ComplaintService.assignFieldStaff`) updates:
   - Complaint with worker info.
   - Worker’s `activeJobs` and `lastAssignedAt` as appropriate.

Ward fields are still present for backward compatibility but are no longer used for routing decisions.

---

## 5. Time-Based Escalation (AE → AEE → EE)

Relevant code: `lib/services/complaint_service.dart`, `lib/services/escalation_service.dart`.

### 5.1 Preloading Officials

At the start of `ComplaintService.checkAndProcessEscalations()`:

1. Query `Users` where `officialRole` ∈ {`AE`, `AEE`, `EE`}.
2. For each user:
   - Read `latitude` and `longitude`.
   - Call `TNEBLocationService.getHierarchyForPoint(lat, lng)`.
   - Based on `officialRole`, place the user into one of three lookup maps, keyed by their own TNEB area (keys stored lowercased):
     - `aeBySection[aeSection] = AE user`.
     - `aeeBySubdivision[aeeSubdivision] = AEE user`.
     - `eeByDivision[eeDivision] = EE user`.
3. These maps are used during escalation to find the correct official for each level, using the complaint's `tnebAeSection` / `tnebAeeSubdivision` / `tnebEeDivision` as keys.

If this preload fails (e.g. officials missing GPS), the method can still update escalation levels and statuses but may leave `assignedTo` unchanged.

### 5.2 Selecting Complaints to Escalate

For each complaint candidate:

1. Check its status, `escalationLevel`, `currentOwnerRole`, and `slaDeadline`.
2. If complaint is resolved/closed or `now < slaDeadline`, skip.
3. Determine the **next role**:
   - If currently with AE / level 0 → next role = AEE.
   - If currently with AEE / level 1 → next role = EE.
   - If already at EE (max level) → no further escalation (configurable).

### 5.3 Finding the Next Official from TNEB Fields

Using the complaint’s TNEB metadata:

- If next role is **AEE**:
  - Key: `complaint.tnebAeeSubdivision`.
  - Lookup: `aeeBySubdivision[key]`.

- If next role is **EE**:
  - Key: `complaint.tnebEeDivision`.
  - Lookup: `eeByDivision[key]`.

If an official user is found:

1. Construct an identifier from the user (email → name → user ID).
2. This identifier is used as the new `assignedTo` value.

If no matching official is found:

- Escalation still occurs (levels and statuses change), but `assignedTo` remains unchanged.

### 5.4 Transactional Update Per Complaint

Each escalation is performed inside a Firestore transaction:

1. Re-read the complaint within the transaction to avoid race conditions.
2. Re-check escalation conditions (SLA, status, current owner).
3. Build `updateData` with:
   - `escalationLevel` incremented.
   - `assignedRole` / `currentOwnerRole` updated to AEE/EE.
   - Status changed to reflect the new owner (e.g. `Pending AEE`, `Pending EE`).
   - New entry appended to `escalationHistory`.
   - If a target official is found, set `assignedTo` to their identifier.
4. Commit transaction.

---

## 6. Behaviour Summary & Extensibility

- **Scope of TNEB routing**: Any complaint whose GPS lies inside a polygon with `division_name/division_n == 'URBAN'` is tagged with a TNEB hierarchy.
- **Activation of full routing** (auto AE/AEE/EE assignment) depends on:
   - Presence of correctly configured AE/AEE/EE users in `Users` with valid GPS so they can be mapped to the right TNEB areas.
- **Field workers** are automatically seeded per AE section on demand and balanced by load.
- **Wards** are no longer used for routing; sections (TNEB AE sections) are the primary unit.
- **Citizens, officials and field officers**:
   - `Users` holds **all** identities (citizens, admins, AE/AEE/EE, field officers) with `role` / `officialRole`, GPS (for officials), and routing/load fields (for field workers).

To enable routing for a new area:

1. Ensure its polygon is in `TNEB_Master_Data.json` with `division_name/division_n == 'URBAN'`.
2. Create three **Users** documents (or mark existing users) for:
    - AE: `officialRole = 'AE'`, and set `latitude`/`longitude` inside the target TNEB section.
    - AEE: `officialRole = 'AEE'`, and set `latitude`/`longitude` inside the target TNEB subdivision.
    - EE: `officialRole = 'EE'`, and set `latitude`/`longitude` inside the target TNEB division.
3. Once complaints start arriving from that area, workers will be auto-seeded for that section, and escalations will route ownership AE → AEE → EE according to the configured Users.

---

## 7. Login, Dashboards & End-to-End Flow

This section ties together how users log in, how dashboards are chosen, and how a complaint moves end-to-end through the system.

### 7.1 Login & Role Resolution

Relevant code: `lib/screens/login_screen.dart`.

1. User signs in via Firebase Auth (email/password).
2. After sign-in, the app loads `Users/{uid}`.
3. From that document it reads:
   - `role` – high-level role.
   - `officialRole` – detailed designation where needed.
4. Based on these, the app navigates to the correct dashboard:
   - `role == 'ADMIN'` → Admin dashboard.
   - `role == 'CITIZEN'` → Citizen dashboard.
   - `role == 'AE'` or `officialRole == 'AE'` → AE dashboard.
   - `role == 'AEE'` or `officialRole == 'AEE'` → AEE dashboard.
   - `role == 'EE'` or `officialRole == 'EE'` → EE dashboard.
   - `role == 'FIELD_WORKER'` or `officialRole in {'Lineman','Foreman'}` → Field Worker dashboard.

### 7.2 Field Worker Dashboard & Job List

Relevant code: `lib/screens/official_dashboard_screen.dart`.

1. The field worker dashboard loads the current user:
   - Fetches `Users/{uid}` and treats that as the worker profile.
2. It then queries complaints by `assignedWorkerId == uid` and appropriate statuses to build:
   - Stats: counts of open, in-progress, resolved jobs, etc.
   - Job list: complaints currently assigned to this worker.
3. When the worker opens a job (Job Details screen), they can:
   - View complaint details and location.
   - Start work (status becomes `in_progress`).
   - Complete work by submitting a resolution note and proof image.

### 7.3 Resolution & Load Updates

Relevant code: `lib/services/complaint_service.dart` (`markResolved`, `reopenComplaint`).

1. When a field worker (or AE via resolution entry) marks a complaint as resolved:
   - `ComplaintService.markResolved` updates the complaint:
     - `status = 'resolved'`.
     - Stores `resolutionNote` and `proofImage`.
     - Updates `lastUpdated`.
   - If `assignedWorkerId` is set, it also updates the corresponding worker user:
     - Decrements `activeJobs` (with a floor at 0).
     - Recomputes `status` (`busy` vs `free`) based on `activeJobs` vs `maxJobs`.
2. If an AE or higher official decides to reopen a resolved complaint:
   - `ComplaintService.reopenComplaint`:
     - Sets complaint `status` back to `classified`.
     - Clears worker assignment (`assignedWorkerId`, `assignedWorkerName`, etc.).
     - Resets resolution fields and SLA timers.
     - Decrements `activeJobs` for the previously assigned worker user.
3. After reopening, the complaint once again appears in AE queues for re-assignment, and the field worker’s capacity is freed for new jobs.

Overall, this creates a closed loop:

1. Citizen files complaint with GPS → TNEB assigns AE/AEE/EE hierarchy.
2. AE is auto-assigned based on AE users’ GPS.
3. AE assigns a field worker using section-based, load-aware routing.
4. Field worker sees jobs on their dashboard and resolves them.
5. Resolution updates complaint status and worker load; escalations run in the background if SLAs are breached.