# Firebase Smoke Test Checklist: Ward-Based Routing (52/53/54)

**Date:** March 11, 2026  
**Purpose:** Verify complaint assignment, reassignment, load tracking, and status normalization across all three wards.  
**Prerequisites:**
- APK built and installed on test device/emulator
- Firebase project configured and accessible
- Test user account (e.g., AE login) ready
- Admin account for verification optional

---

## Phase 1: Worker Seeding Verification

### 1.1: Check Firestore `field_workers` Collection

**Action:**
1. Open Firebase Console → Firestore Database
2. Navigate to `field_workers` collection
3. Verify all 9 workers exist with correct fields

**Expected Result:**

| Ward | Worker Name | Role | Status | activeJobs | maxJobs | Expected Phone |
|------|---|---|---|---|---|---|
| 52 | R. Prakash | Lineman | free | 0 | 3 | 9000000001 |
| 52 | M. Saravanan | Lineman | free | 0 | 3 | 9000000002 |
| 52 | S. Elangovan | Foreman | free | 0 | 3 | 9000000003 |
| 53 | B. Arun Prasad | Lineman | free | 0 | 3 | 9000000004 |
| 53 | V. Nirmal Raj | Lineman | free | 0 | 3 | 9000000005 |
| 53 | Kevin Kumar | Foreman | free | 0 | 3 | 9000000006 |
| 54 | A. Vigneshwaran | Lineman | free | 0 | 3 | 9000000007 |
| 54 | N. Suresh Babu | Lineman | free | 0 | 3 | 9000000008 |
| 54 | K. Ramesh | Foreman | free | 0 | 3 | 9000000009 |

**Checklist:**
- [ ] All 9 workers exist in collection
- [ ] Each worker has `ward` field (52/53/54)
- [ ] Each worker has `status` = 'free'
- [ ] Each worker has `activeJobs` = 0
- [ ] Each worker has `maxJobs` = 3
- [ ] All fields are populated and accessible

---

## Phase 2: Assignment Tests (Single Ward)

### 2.1: Test Assignment - Ward 52

**Action:**
1. Open app, log in as AE
2. Create or fetch a draft complaint in Ward 52
3. Navigate to "Assign Field Staff" screen
4. Verify eligible workers list shows only Ward 52 linemen/foreman
5. Select "S. Elangovan" (Foreman - recommended for high priority if complaint is high)
6. Save assignment

**Expected Result:**

**Complaint Document (complaints collection):**
```
{
  "complaintId": "test-complaint-52-1",
  "ward": "52",
  "assignedTo": "S. Elangovan",
  "assignedWorkerId": "w52_s_elangovan",
  "assignedWorkerName": "S. Elangovan",
  "assignedWorkerRole": "Foreman",
  "assignedWard": "52",
  "assignmentMode": "manual" or "recommended",
  "routingVersion": "v1",
  "status": "under_review"  // Auto-transitioned if was "pending_assignment"
}
```

**Worker Document (field_workers → w52_s_elangovan):**
```
{
  "activeJobs": 1,
  "status": "free",  // Still free since 1 < 3
  "lastAssignedAt": <current timestamp>
}
```

**Checklist:**
- [ ] Complaint shows both new routing fields and legacy `assignedTo`
- [ ] Worker `activeJobs` incremented from 0 to 1
- [ ] Worker `status` remains 'free' (1 < maxJobs)
- [ ] `lastAssignedAt` updated to current time
- [ ] Complaint status transitioned to 'under_review'
- [ ] AE dashboard still filters by legacy `assignedTo` if accessed

### 2.2: Test Assignment - Ward 53

**Action:**
1. Create a new complaint in Ward 53
2. Assign to "B. Arun Prasad" (Lineman)
3. Save assignment

**Expected Result:**
- Worker B. Arun Prasad: `activeJobs` = 1

**Checklist:**
- [ ] Worker exists and is assigned correctly
- [ ] Load counter incremented

### 2.3: Test Assignment - Ward 54

**Action:**
1. Create a new complaint in Ward 54
2. Assign to "K. Ramesh" (Foreman)
3. Save assignment

**Expected Result:**
- Worker K. Ramesh: `activeJobs` = 1

**Checklist:**
- [ ] Worker exists and is assigned correctly
- [ ] Load counter incremented

---

## Phase 3: Cross-Ward Block Test

### 3.1: Verify Ward 52 Complaint Cannot Be Assigned to Ward 53/54 Worker

**Action:**
1. Fetch Ward 52 complaint from earlier test
2. Attempt to manually modify `assignedWorkerId` in Firestore to a Ward 53 worker ID (e.g., "w53_b_arun_prasad")
3. Try to call the `assignFieldStaff` API with mismatched ward
4. Observe error handling

**Expected Result:**
- API rejects assignment with error: "Worker ward mismatch."
- Complaint remains unassigned or keeps previous assignment

**Checklist:**
- [ ] Cross-ward assignment is blocked at transaction layer
- [ ] Error message is clear
- [ ] Complaint data remains consistent

---

## Phase 4: Reassignment Tests

### 4.1: Reassign Ward 52 Complaint from One Worker to Another

**Action:**
1. Fetch the Ward 52 complaint assigned to S. Elangovan earlier
2. Open "Assign Field Staff" for that complaint
3. Select a different Ward 52 worker (e.g., M. Saravanan)
4. Save reassignment

**Expected Result:**

**Old Worker (S. Elangovan):**
```
{
  "activeJobs": 0,  // Decremented from 1
  "status": "free"
}
```

**New Worker (M. Saravanan):**
```
{
  "activeJobs": 1,  // Incremented from 0
  "status": "free",
  "lastAssignedAt": <new timestamp>
}
```

**Complaint Document:**
```
{
  "assignedWorkerId": "w52_m_saravanan",
  "assignedWorkerName": "M. Saravanan",
  "assignedWorkerRole": "Lineman",
  "assignedTo": "M. Saravanan",  // Also updated for compatibility
  "lastUpdated": <current timestamp>
}
```

**Checklist:**
- [ ] Old worker load decremented correctly
- [ ] New worker load incremented correctly
- [ ] Both new and legacy fields updated atomically
- [ ] `lastAssignedAt` timestamp reflects new assignment
- [ ] Complaint maintains ward during reassignment

### 4.2: Reassign Ward 53 Complaint

**Action:**
1. Reassign the Ward 53 complaint from B. Arun Prasad to V. Nirmal Raj
2. Verify load counters flip correctly

**Expected Result:**
- B. Arun Prasad: `activeJobs` = 0
- V. Nirmal Raj: `activeJobs` = 1

**Checklist:**
- [ ] Reassignment transaction executed cleanly
- [ ] Load transfer is atomic and correct

---

## Phase 5: Capacity and Status Tests

### 5.1: Max Job Capacity Block

**Action:**
1. Assign 2 more complaints to S. Elangovan (Ward 52) to reach max capacity (3)
2. Attempt to assign a 4th complaint to S. Elangovan
3. Observe the assign screen behavior

**Expected Result:**
- S. Elangovan shows up to activeJobs=3 in Firestore
- Assignment UI either:
  - Removes S. Elangovan from eligible list (preferred)
  - Shows error message: "Selected worker has reached maximum active jobs."
- Complaint remains unassigned or AE is forced to select another worker

**Checklist:**
- [ ] Worker at max capacity (3) is blocked from receiving new assignments
- [ ] UI/UX clearly indicates capacity status
- [ ] Complaint does not get assigned to over-capacity worker

### 5.2: Offline Worker Block

**Action:**
1. Manually set one worker (e.g., R. Prakash) to `status: "offline"` in Firestore
2. Create a new Ward 52 complaint
3. Open assign screen and verify R. Prakash is missing from eligible list
4. Assign to another available Ward 52 worker

**Expected Result:**
- R. Prakash does not appear in eligible workers dropdown
- Assignment succeeds for non-offline worker

**Checklist:**
- [ ] Offline status is respected during eligibility filtering
- [ ] Other workers in same ward are still available

---

## Phase 6: Pending Assignment Flow

### 6.1: Manual Mark Pending Assignment

**Action:**
1. Create a new Ward 52 complaint
2. Suppose all linemen are at max capacity and only offline foreman exists
3. Click "Mark Pending Assignment" button on assign screen
4. Verify complaint transitions to `status: "pending_assignment"`

**Expected Result:**

**Complaint Document:**
```
{
  "status": "pending_assignment",
  "assignmentMode": "manual",
  "assignmentReason": "No eligible same-ward worker available",
  "assignedWorkerId": null,
  "assignedWorkerName": "Unassigned"
}
```

**Checklist:**
- [ ] Complaint transitions to `pending_assignment` status
- [ ] Reason is logged for audit trail
- [ ] Later reassignment auto-transitions to `under_review`

### 6.2: Reassign from Pending Assignment

**Action:**
1. Set one worker (e.g., offline R. Prakash) back to `status: "free"`
2. Return to the pending-assignment complaint
3. Reopen assign screen and select R. Prakash
4. Save reassignment

**Expected Result:**
- Complaint transitions to `under_review`
- R. Prakash activeJobs incremented to 1

**Checklist:**
- [ ] Pending complaint can be assigned after eligible worker becomes available
- [ ] Status auto-transitions to `under_review`
- [ ] Load counter is incremented correctly

---

## Phase 7: Resolution and Load Decrement

### 7.1: Mark Complaint Resolved

**Action:**
1. Login as field worker (or switch to Worker Dashboard if simulated)
2. Find assigned complaint (e.g., the one assigned to M. Saravanan in Ward 52)
3. Navigate to JobDetailsScreen and select "Mark In Progress"
4. Then select "Submit Work & Resolve"
5. Fill resolution details and submit

**Expected Result:**

**Complaint Document:**
```
{
  "status": "resolved",
  "resolutionNote": "<your feedback>",
  "proofImage": "<image path>",
  "lastUpdated": <current timestamp>
}
```

**Worker Document (M. Saravanan):**
```
{
  "activeJobs": 0,  // Decremented from 1
  "status": "free"
}
```

**Checklist:**
- [ ] Complaint status transitioned to `resolved`
- [ ] Worker load counter decremented to 0
- [ ] Worker status remains appropriate (free/busy based on load)
- [ ] `lastUpdated` timestamp reflects resolution time

### 7.2: Resolve Multiple Complaints

**Action:**
1. Resolve the remaining 2 complaints assigned to S. Elangovan (now at Ward 52 after reassignment)
2. Verify each resolution decrements S. Elangovan's load

**Expected Result:**
- S. Elangovan: `activeJobs` goes from 3 → 2 → 1 → 0
- After 3rd resolution, status returns to `free`

**Checklist:**
- [ ] Each resolution correctly decrements load
- [ ] Load counter remains non-negative
- [ ] Status reflects current capacity state

---

## Phase 8: Status Normalization Verification

### 8.1: Check Status Display in AE Dashboard

**Action:**
1. Open AE Dashboard (Complaint Details)
2. Verify complaint status displays correctly regardless of internal format

**Expected Cases:**
- Internal: `under_review` → Display: "Under Review"
- Internal: `in_progress` → Display: "In Progress"
- Internal: `pending_assignment` → Display: "Pending Assignment"
- Internal: `resolved` → Display: "Resolved"

**Checklist:**
- [ ] All normalized statuses display correctly
- [ ] Status badges use correct colors
- [ ] No broken status strings appear in UI

### 8.2: Check Status Consistency in Filters

**Action:**
1. Open complaint list and filter by status
2. Verify complaints appear correctly regardless of legacy vs. normalized status

**Checklist:**
- [ ] Status filters work with snake_case internal format
- [ ] Display values are human-readable
- [ ] No duplicates or missing complaints due to normalization

---

## Phase 9: Users/Users Collection Bridge

### 9.1: Verify Feedback Points Assignment

**Action:**
1. On resolved complaint, submit feedback with points (e.g., 80 points)
2. Check Firebase `users` or `Users` collection for the official's record
3. Verify `averageRating` and `totalReviews` updated

**Expected Result:**

**Users/users collection → official document:**
```
{
  "email": "official@example.com",
  "averageRating": <updated average>,
  "totalReviews": <incremented count>
}
```

**Checklist:**
- [ ] Feedback correctly updates either `Users` or `users` collection (bridge finds it)
- [ ] Rating calculation is correct: (oldAvg × oldCount + newRating) / (oldCount + 1)
- [ ] Both collections fallback logic works if needed

### 9.2: Verify Gamification Points Award

**Action:**
1. From resolved complaint, backend awards points to citizen
2. Check Firebase `users` or `Users` → citizen document
3. Verify `points` field incremented by 50

**Expected Result:**

**Citizens document:**
```
{
  "userId": "citizen-uid",
  "points": <previous + 50>
}
```

**Checklist:**
- [ ] Points awarded correctly via bridge lookup
- [ ] Points can be queried for leaderboard
- [ ] No errors if collection varies

---

## Phase 10: Admin Dashboard Visibility

### 10.1: Check Routing Capacity Section

**Action:**
1. Open Admin Portal → "Routing Capacity" section
2. Verify counts display correctly after all assignments/resolutions

**Expected Display:**
- Free: <count of free workers>
- Busy: <count of workers with activeJobs >= maxJobs>
- Offline: <count of offline workers>
- Active Jobs: <total activeJobs> / <total maxJobs capacity>

**Example After Phase 7:**
```
Free: 7
Busy: 0
Offline: 1 (R. Prakash set offline earlier)
Active Jobs: 2 / 27  (2 jobs assigned across 9 workers, 3 jobs max each = 27 total)
```

**Checklist:**
- [ ] Worker counts sum to 9 (free + busy + offline)
- [ ] Active jobs reflect current assignments
- [ ] Capacity indicator is accurate
- [ ] Real-time updates as assignments change

---

## Phase 11: Regression Checks

### 11.1: Verify Legacy Screens Still Work

**Action:**
1. Open Official Dashboard (legacy name for worker dashboard)
2. Filter complaints by `assignedTo`
3. Verify old assignments still appear (both new and legacy fields)

**Checklist:**
- [ ] Legacy filters continue to work
- [ ] New routing fields do not break existing UI
- [ ] No missing complaints due to assignment field changes

### 11.2: Verify Email Notifications

**Action:**
1. Trigger resolution with citizen email configured
2. Check email log or Firebase Functions log for send attempt
3. Verify no errors in console

**Checklist:**
- [ ] Email service finds user via Users/users bridge
- [ ] No "user not found" errors
- [ ] Email content includes resolved complaint details

### 11.3: Verify APK Stability

**Action:**
1. Perform all above actions on installed APK (not just dev run)
2. No app crashes observed
3. No unhandled exceptions in Logcat/console

**Checklist:**
- [ ] App remains stable through full workflow
- [ ] Transitions are smooth (no UI hangs)
- [ ] Navigation back/forward works correctly

---

## Summary & Sign-Off

| Test Phase | Status | Notes |
|---|---|---|
| Phase 1: Worker Seeding | ☐ PASS ☐ FAIL | |
| Phase 2: Assignment | ☐ PASS ☐ FAIL | |
| Phase 3: Cross-Ward Block | ☐ PASS ☐ FAIL | |
| Phase 4: Reassignment | ☐ PASS ☐ FAIL | |
| Phase 5: Capacity & Status | ☐ PASS ☐ FAIL | |
| Phase 6: Pending Assignment | ☐ PASS ☐ FAIL | |
| Phase 7: Resolution & Decrement | ☐ PASS ☐ FAIL | |
| Phase 8: Status Normalization | ☐ PASS ☐ FAIL | |
| Phase 9: Users/Users Bridge | ☐ PASS ☐ FAIL | |
| Phase 10: Admin Visibility | ☐ PASS ☐ FAIL | |
| Phase 11: Regression Checks | ☐ PASS ☐ FAIL | |

**Overall Result:** ☐ ALL PASS ☐ SOME FAILURES

**Tester Name:** ________________  
**Date Tested:** ________________  
**Issues Logged:** ________________

---

## Issue Tracking Template

If any test fails, log here:

```
**Issue #1**
- Phase: [Phase #]
- Test: [Test Name]
- Expected: [What should happen]
- Actual: [What happened]
- Reproduction: [Steps to reproduce]
- Severity: [Critical / Major / Minor]
- Status: [Open / In Review / Fixed]
```

---

**End of Checklist**
