# Happy Hound Hikes - iOS App Design & Requirements

## Project Overview

**App Purpose:** Dog-hiking business management for a solo operator in Halifax, Nova Scotia.  
**Primary Goal:** Answer "What dogs am I picking up today?" with automatic route optimization and easy weekly schedule management.  
**Target User:** Heather (operator of Happy Hound Hikes, running for 24 years)  
**Current State:** Manual spreadsheet tracking; transitioning to digital workflow.

**Tech Stack:**
- SwiftUI (all UI)
- SwiftData (local persistence + iCloud sync)
- MapKit (route visualization & distance calculation)
- Native iOS frameworks only (no external dependencies)

---

## Background Context

### Business Model
- **Service:** Off-lead dog hikes in groups of max 8 dogs per hike
- **Capacity:** 2 hikes per day maximum
- **Pricing:** $25-$30 per dog per hike (varies by season, HST 14-15%)
- **Payment Model:** Clients pay 2 weeks in advance; payment must be received before scheduling
- **Service Area:** Bedford, Sackville, Beaver Bank (Nova Scotia)
- **Client Base:** ~40 active dogs (~25-30 owners, some with multiple dogs)

### Current Workflow (Spreadsheet-Based)
- Weekly spreadsheet with dogs listed vertically, days horizontally (Mon-Fri)
- Cell values indicate payment status ($25/$30 = paid, blank = unpaid)
- Notes column tracks exceptions: "Away," "Injured," "Interview hike," etc.
- Manual pickup order planning (no optimization)
- Manual payment tracking
- No route optimization or location-based grouping

### Key Pain Points
1. **"What am I picking up today?"** takes manual lookups
2. **Route optimization is manual** (no system for optimal pickup order)
3. **Payment tracking is visual** (relies on cell values, hard to see what's overdue)
4. **Schedule changes are frequent** (dogs rescheduled week-to-week due to injuries, owner travel, etc.)
5. **No location-based grouping** (doesn't leverage the fact that dogs cluster in regions)

---

## Core Use Cases (MVP Priority)

### 1. Today's Schedule (PRIMARY FEATURE)
**Goal:** Answer "Who am I picking up today and in what order?"

**Workflow:**
- App loads today's date
- Automatically populates all dogs scheduled for today (from their regular weekly schedules)
- Groups dogs into Hike 1 and Hike 2 (max 8 per hike)
- Auto-optimizes pickup order using route optimization (see algorithm section)
- Displays in list form with key info per dog:
  - Dog name, owner name
  - Pickup location (address or coordinates)
  - Payment status (paid/unpaid/overdue)
  - Quick action buttons (mark paid, etc.)
- Shows optimized route on MapKit (visual order of pickups)
- Suggests a hiking trail location (auto-selected based on last pickup's region)
- Allows manual drag-to-reorder if needed
- Morning notification: "You're picking up 8 dogs today in 2 groups: Hike 1: [names], Hike 2: [names]"

**Key Detail:** Payment status is "overdue" if the dog hasn't been paid for in >14 days (2-week advance payment policy).

---

### 2. Weekly Schedule Manager
**Goal:** Easily adjust which dogs are scheduled for which days each week.

**Workflow:**
- Calendar view showing Mon-Fri with dog count per day
- Tap a day to see all dogs scheduled for that day
- Quick-action panel to override the regular schedule for that week:
  - Add dog to this day (select from roster)
  - Remove dog from this day
  - Reschedule dog to different day in same week
  - Mark dog as "Away" for entire week (or duration)
  - Mark dog as "Injured/Off" for duration
  - Swap two dogs' days
- All changes stored as "weekly exceptions" (don't modify the dog's permanent schedule)
- Visual feedback: show which days have exceptions (e.g., "Modified" badge)

**Key Detail:** Regular schedules stay intact; this only modifies the current week's schedule.

---

### 3. Client & Dog Management
**Goal:** Maintain roster of clients and their dogs with location and schedule info.

**Workflow:**
- **View all clients/dogs:** List with sorting/filtering options
- **Add new client:**
  - Enter owner name, phone, email, address
  - Address gets geocoded to coordinates (for routing)
- **Add dog to client:**
  - Dog name
  - Pickup location (can differ from owner's address)
  - Regular weekly schedule (checkboxes: Mon/Tue/Wed/Thu/Fri)
  - Payment rate ($25 or $30)
  - Health/behavior notes (e.g., "reactive with other dogs," "needs short breaks," "anxiety issues")
  - Active/inactive toggle
- **Edit existing dog:**
  - Any of above fields
  - View last payment date
  - View total balance owed
- **Quick reference:**
  - See payment status at a glance
  - See next scheduled hike
  - Quick-view payment history

**No System Contacts Integration:** Use custom Client/Dog data model instead (cleaner, more flexible for future extensions).

---

### 4. Payment Tracking
**Goal:** Track which clients have paid, when, and flag overdue payments.

**Workflow:**
- **Quick payment log:**
  - Tap dog in today's view → mark as paid (date stamps to today)
  - Specify payment amount (defaults to dog's rate)
  - Optionally note payment method (e-transfer, cash, etc.)
- **Payment history view:**
  - See all payments for a dog (date, amount, method)
  - See total owed vs. paid
- **Overdue alerts:**
  - Flag any dog whose last payment was >14 days ago
  - Show on today's view (visual indicator)
- **Weekly/monthly totals:**
  - Calculate revenue for reference (not detailed analytics, just totals)
  - Useful for quick tax reference

---

### 5. Location & Route Optimization
**Goal:** Group pickups efficiently and visualize optimal routes.

**Workflow:**
- **Dog locations:**
  - Store pickup address + coordinates for each dog
  - Use for route optimization and mapping
- **Hiking trail locations:**
  - Maintain list of trail spots used (e.g., "Blue Mountain Trail," "Shubenacadie Canal")
  - Each trail tagged with region (Bedford, Sackville, Beaver Bank)
  - Auto-suggest trail based on last pickup's region
- **Route optimization:**
  - For each hike, calculate optimal pickup order
  - Algorithm: Nearest-neighbor greedy or brute-force (8! permutations is fast enough)
  - Display on map with numbered pins (1, 2, 3... showing pickup order)
  - Add trail location as final destination
  - Allow user to manually drag-to-reorder if they want to override

---

## Data Model

### Client
Represents a dog owner/client.

```
@Model final class Client {
    @Attribute(.unique) var id: UUID = UUID()
    var ownerName: String
    var phone: String?
    var email: String?
    var address: String                          // Owner's address
    var coordinate: CLLocationCoordinate2D?      // Geocoded from address
    @Relationship(deleteRule: .cascade) var dogs: [Dog] = []
    var createdDate: Date = Date()
    var isActive: Bool = true
}
```

### Dog
Represents a dog and its schedule/payment info.

```
@Model final class Dog {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var client: Client?                          // Link to owner
    var location: CLLocationCoordinate2D?        // Pickup location (may differ from owner)
    var locationAddress: String?                 // Human-readable address for pickup
    var regularSchedule: [DayOfWeek] = []        // [.monday, .wednesday, .friday], etc.
    var paymentRate: Decimal = 25.00
    var notes: String = ""                       // Health, behavior, special instructions
    var color: String?                           // For UI tagging (optional)
    var isActive: Bool = true
    @Relationship(deleteRule: .cascade) var payments: [Payment] = []
}

enum DayOfWeek: Int, Codable {
    case monday = 1, tuesday, wednesday, thursday, friday
}
```

### ScheduleException
Stores week-specific overrides to a dog's regular schedule.

```
@Model final class ScheduleException {
    @Attribute(.unique) var id: UUID = UUID()
    var dogId: UUID
    var weekStartDate: Date                      // Monday of the week
    var dayOverrides: [Int: ScheduleStatus] = []  // [DayOfWeek.rawValue: status]
    var createdDate: Date = Date()
}

enum ScheduleStatus: String, Codable {
    case scheduled      // Dog is scheduled
    case away          // Dog is away/unavailable
    case injured       // Dog is injured/off
    case cancelled     // Hike was cancelled
    case rescheduled   // Would need `rescheduledTo` field if tracking reassignment
}
```

### Payment
Tracks payment for a specific dog on a specific date.

```
@Model final class Payment {
    @Attribute(.unique) var id: UUID = UUID()
    var dogId: UUID
    var date: Date
    var amount: Decimal
    var paid: Bool = false
    var method: String?                          // "e-transfer", "cash", etc.
    var notes: String?
}
```

### HikingLocation
Represents a trail used for hikes.

```
@Model final class HikingLocation {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D
    var region: String                           // "Bedford", "Sackville", "Beaver Bank"
    var notes: String?
    var isActive: Bool = true
}
```

### DailyHike (Computed View Model, NOT persistent)
Represents today's hike schedule (computed from Dog + ScheduleException data).

```
struct DailyHike {
    let date: Date
    let hike1: [Dog]                             // Ordered by route optimization
    let hike2: [Dog]
    let route1: [CLLocationCoordinate2D]         // Pickup order + trail
    let route2: [CLLocationCoordinate2D]
    let suggestedTrail: HikingLocation?
}
```

---

## Feature Priority & Scope

### Tier 1 (MVP - Must Have)
1. **Today's Schedule view** - Auto-populated, route-optimized, payment status visible
2. **Weekly Schedule Manager** - Add/remove/reschedule dogs per week
3. **Client/Dog roster management** - CRUD operations
4. **Location storage** - Pickup addresses + coordinates
5. **Route optimization** - Nearest-neighbor or brute-force (8 dogs max)
6. **Basic payment tracking** - Log payments, mark paid/unpaid, flag overdue (>14 days)
7. **Morning notification** - Daily summary of today's pickups

### Tier 2 (Post-MVP Polish)
8. Detailed payment history UI per dog
9. Weekly/monthly revenue dashboard
10. Hiking trail location management UI
11. Payment overdue alerts (in-app)
12. Map view improvements (street names, better visualization)

### Tier 3 (Nice-to-Have, Lower Priority)
13. Trip logging/history (which dogs hiked, weather, notes)
14. Advanced analytics (busiest days, revenue trends)
15. Photo uploads or dog profiles
16. Data export/backup
17. Multi-user support (unlikely for this use case)

---

## Technical Architecture

### Data Persistence & Sync
- **SwiftData** for local persistence (all models above)
- **iCloud sync** via SwiftData's built-in CloudKit support (automatic, no manual setup)
- **Offline mode:** App fully functional without internet; syncs when online
- **Local caching:** Recent data fetched and cached for instant access on cold start

### Navigation & UI
```
TabView (5 tabs):
├── Home (Today's Schedule)
│   ├── Hike 1 list + route map
│   ├── Hike 2 list + route map
│   ├── Quick actions (mark paid, start hike)
│   └── Suggested trail info
│
├── Weekly
│   ├── Calendar Mon-Fri
│   ├── Tap day → edit dogs for that day
│   └── Add/remove/reschedule UI
│
├── Clients
│   ├── All dogs/clients list
│   ├── Tap → detail view (edit, notes, payment)
│   ├── Add new client
│   └── Filter/search
│
├── Payments (optional MVP, can be in Settings initially)
│   ├── Overdue alerts
│   ├── Recent payments
│   └── Monthly total
│
└── Settings
    ├── Hiking trail locations (CRUD)
    ├── Business settings (HST rate, default payment rate)
    ├── Notification settings
    ├── iCloud sync status
    └── About
```

### Route Optimization Algorithm
**Goal:** Order pickups to minimize total distance.

**Algorithm (Brute-Force + Nearest-Neighbor Fallback):**
1. Load all dogs scheduled for today
2. Split into two groups (Hike 1, Hike 2), balanced, max 8 each
3. For each group:
   - If ≤2 dogs, no optimization needed
   - Calculate straight-line or MapKit distance between all dog pairs
   - **Option A (Greedy):** Nearest-neighbor heuristic (85% optimal, instant)
     - Start at home/first dog
     - Always go to nearest unvisited dog
     - Fast but not globally optimal
   - **Option B (Brute-Force):** Try all permutations (40k for 8 dogs, <100ms)
     - Generate all orderings
     - Calculate total distance for each
     - Return shortest
   - (Recommend Option B for MVP; it's still fast enough)
4. Add hiking trail location at end (based on last pickup's region)
5. Allow user to drag-to-reorder if needed

**MapKit Usage:**
- `CLLocationDistance` for straight-line distance (fastest)
- `MKDirectionsRequest` + `MKDirections` for actual driving distance (more accurate, network call)
- For MVP, straight-line is fine; can upgrade later if needed

---

## Performance & Constraints

- **Route optimization:** <100ms for 8 dogs (brute-force acceptable)
- **App launch:** Instant from cache (<500ms)
- **iCloud sync:** Background, non-blocking
- **MapKit calls:** Batch-calculate distances, cache results
- **Notifications:** Scheduled daily at 7 AM

---

## Out of Scope (for MVP)

- Detailed trip/hike logging or history
- Photo uploads or dog media galleries
- Multi-user / admin features
- Expense tracking integration
- Payment processing (payment gateway)
- Advanced analytics or reporting
- AI-powered recommendations
- Social features

---

## Success Criteria for MVP

✅ Open app → today's schedule auto-populates with dogs in optimized pickup order  
✅ Modify weekly schedule (add/remove/reschedule dogs for a specific day)  
✅ Add/edit clients and dogs with locations and schedules  
✅ Store and update payment status per dog  
✅ Flag overdue payments (>14 days since last payment)  
✅ Route displays on map showing pickup order  
✅ Use app fully offline; changes sync when online  
✅ Morning notification with today's pickup summary  
✅ Manual drag-to-reorder of pickup order  
✅ All data persists via iCloud  

---

## Development Plan (Suggested Order)

1. **Data Models & SwiftData Setup**
   - Define all models (Client, Dog, ScheduleException, Payment, HikingLocation)
   - Set up SwiftData with iCloud sync
   - Create sample data for testing

2. **Core Data Managers**
   - DailyHikeManager (computes today's schedule from Dog + ScheduleException)
   - RouteOptimizer (nearest-neighbor or brute-force)
   - PaymentManager (payment tracking, overdue logic)

3. **Today's Schedule UI (Home Tab)**
   - Most important screen; build this first
   - Display Hike 1 and Hike 2 lists
   - Show payment status per dog
   - Quick mark-paid actions

4. **MapKit Integration**
   - Display pickup route on map
   - Show locations, order, and trail destination
   - Drag-to-reorder (optional for MVP but nice to have)

5. **Weekly Manager UI**
   - Calendar view Mon-Fri
   - Add/remove/reschedule panel
   - ScheduleException logic

6. **Client/Dog Management**
   - CRUD views for clients and dogs
   - Location entry and geocoding
   - Schedule configuration

7. **Payment Tracking**
   - Log payment UI
   - Payment history view
   - Overdue alerts

8. **Notifications**
   - Morning summary notification (UNUserNotificationCenter)
   - Schedule daily at 7 AM

9. **Settings & Polish**
   - Trail location management
   - Business settings (rates, HST)
   - iCloud sync status display

---

## Known Decisions & Rationale

### Why No System Contacts Integration?
- **Problem:** Contacts is one-contact-per-owner; dogs are in nickname field (fragile hack)
- **Solution:** Custom Client/Dog model in SwiftData (cleaner, more flexible)
- **Benefit:** App data stays independent; easier to add dog-specific fields later

### Why SwiftData + iCloud Over Core Data?
- SwiftData is simpler, modern API (iOS 17+)
- Built-in iCloud sync is easier to manage
- Less boilerplate code
- Still full query capabilities

### Why Not Full TSP Solver?
- Only 8 dogs per hike (max permutations = 40k, <100ms brute-force)
- Geographic clustering (Bedford/Sackville/Beaver Bank) means most solutions similar
- Simple greedy or brute-force is 85%+ optimal
- User can manually reorder if needed

### Why MapKit Over Google Maps?
- Native, no external dependencies
- Free tier covers MVP use case
- Built-in distance calculation
- Route visualization is sufficient (don't need turn-by-turn directions)

---

## Reference Context: Original Spreadsheet Structure

The current spreadsheet structure (for reference):
- Rows: Dog names (40+)
- Columns: Days of week (Mon-Fri) per week
- Cells: Payment amounts ($25/$30) or empty (unpaid)
- Notes column: Exceptions ("Away," "Injured," "Interview hike," etc.)
- Weekly sections grouped by month and week number

The app should make this workflow obsolete by automating scheduling, payment tracking, and route optimization.

---

## Questions for Clarification

If any requirements seem unclear during development, refer back to this brief or ask the following:
- "What should happen when a payment is overdue?"
- "How should the app handle dogs with multiple owners?"
- "Should route optimization account for time windows (e.g., client not home before 2pm)?"
- "Should the app support recurring payments (e.g., bi-weekly standing payments)?"

---

## Appendix: Business Rules

1. **Payment Policy:** 2-week advance payment required before scheduling
2. **Overdue Definition:** Last payment >14 days old
3. **Hike Capacity:** Max 2 hikes per day, max 8 dogs per hike
4. **Pricing:** $25-$30 per dog per hike (varies by season, HST 14-15%)
5. **Service Area:** Bedford, Sackville, Beaver Bank only
6. **Schedule Exceptions:** Common reasons include: vacation (owner away), injury, grooming appointment, interview hike (new client trial)

---

**Document Version:** 1.0  
**Created:** 2025-11-07  
**Last Updated:** 2025-11-07  
**Status:** Ready for Development
