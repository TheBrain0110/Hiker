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

## UPDATED DESIGN: Unified Schedule View (v2.0)

**Status:** In Development
**Date:** 2025-12-16

### Design Evolution
The original design separated "Today's Schedule" and "Weekly Schedule Manager" into distinct views. Based on UX review, these have been **consolidated into a single unified Schedule view** that provides:

1. **Scrolling Timeline** - Past, present, and future days in one continuous list
2. **Historical Tracking** - Complete record of past hikes with attendance and completion data
3. **Flexible Viewing** - Toggle between list and calendar views
4. **Contextual Actions** - Different capabilities for past/present/future days

### Unified Schedule View Features

**Timeline View (Primary):**
- **Past 30 days**: Shows completed hikes or "No hikes" if none occurred
- **Today**: Highlighted with distinct styling, shows planned schedule + completion status
- **Future 60 days**: Shows computed schedules based on dog regular schedules + overrides
- Auto-scrolls to "today" on launch for quick access
- Tap any day to see full detail view with route map, dog list, etc.

**Calendar View (Alternative):**
- Monthly grid calendar (Mon-Sun)
- Visual indicators: dots for scheduled days, checkmarks for completed
- Month navigation (previous/next buttons)
- Tap date to open day detail sheet

**Day Detail Views (Conditional based on day type):**

*Past Days:*
- Display completed `DailyHike` records with actual attendance (`completedAt` set)
- Show notes, trail used, route taken, completion timestamp
- Allow editing for corrections (e.g., fix attendance errors)
- Read-only route map showing actual pickups

*Today:*
- Show planned schedule from `DailyHikeManager` (lazy-loaded `DailyHike`)
- **"Mark Complete" button** launches completion workflow
- Mark which dogs actually attended (defaults to all)
- Select trail visited, add notes
- Sets `completedAt` on existing `DailyHike` record

*Future Days:*
- Show computed schedule (editable, lazy-created on first view)
- Add/remove dogs via `ScheduleOverride` records
- Visual indicators for overridden schedules ("Added"/"Removed" badges)
- Context-aware staleness: "Recalculate Route" vs "Apply Changes" actions

### Data Models (Implemented)

**DailyHike** (unified model for entire lifecycle):
```swift
@Model
final class DailyHike {
    var date: Date                          // Normalized to startOfDay
    var hikeNumber: Int                     // 1 or 2
    var completedAt: Date?                  // nil = planned, set = completed
    var staleReasonRaw: String?             // Context-aware staleness tracking
    var routeLatitudes: [Double]            // Optimized route coordinates
    var routeLongitudes: [Double]
    var totalDistance: Double
    var selectedTrailId: UUID?
    var trailName: String?                  // Denormalized for history
    var removedDogIds: [UUID]               // Dogs removed via override
    var removedDogNames: [String]
    var notes: String?
    var createdAt: Date
    var lastModifiedAt: Date
    @Relationship(deleteRule: .cascade)
    var participations: [HikeParticipation]
}
```

**HikeParticipation** (per-dog tracking):
```swift
@Model
final class HikeParticipation {
    var dogId: UUID
    var dogName: String                     // Denormalized snapshot
    var pickupOrder: Int                    // 1-8, position in route
    var pickupLatitude: Double?
    var pickupLongitude: Double?
    var pickupAddress: String?              // Snapshot of address at time
    var paymentId: UUID?                    // Link to payment record
    var rate: Decimal                       // Rate at time of hike
    var isConfirmed: Bool                   // True when user confirms attendance
    var wasAddedViaOverride: Bool           // Shows "Added" badge
    var dailyHike: DailyHike?
}
```

### Key Benefits of Unified Design

1. **Single Model Lifecycle**: Same `DailyHike` record transitions from planned → completed
2. **Route Caching**: Expensive routing computed once on first access, then persisted
3. **Customization Persistence**: Manual dog add/remove and trail selection survives between views
4. **Historical Records**: Past hikes permanently recorded with actual attendance and route
5. **Data Integrity**: Denormalized snapshots in `HikeParticipation` preserve historical accuracy
6. **Context-Aware Staleness**: `StaleReason` tracks WHY hike needs attention (.routeNeedsOptimization vs .scheduleChanged)

### Migration from Original Design

- **Today tab** → Integrated into unified timeline (today's row)
- **Weekly tab** → Integrated into timeline (future days are editable)
- Maintains all original functionality while adding historical tracking
- Lazy persistence: Hikes created on first view, not pre-computed
- "Reset to Schedule" button clears overrides and regenerates from weekly pattern

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

### DailyHike (Planned: Unified Persistent Model)
**Current:** Computed view model (ephemeral, regenerated on each view)
**Future:** Unified persistent model supporting full lifecycle (planned → customized → completed)

```
@Model
final class DailyHike {
    var date: Date                               // Day hike occurs (normalized to startOfDay)
    var hikeNumber: Int                          // 1 or 2
    var completedAt: Date?                       // nil = planned, set = completed
    var staleReasonRaw: String?                  // .routeNeedsOptimization or .scheduleChanged
    var routeLatitudes: [Double]                 // Cached optimized route
    var routeLongitudes: [Double]
    var totalDistance: Double
    var selectedTrailId: UUID?                   // User-selected or auto-suggested
    var trailName: String?                       // Denormalized
    var removedDogIds: [UUID]                    // Dogs removed via .isAbsent override
    var removedDogNames: [String]
    var notes: String?
    @Relationship(deleteRule: .cascade)
    var participations: [HikeParticipation]      // Planned or actual attendance
}
```

**Lifecycle:**
1. **Created on first access** - When user views a date, computed from Dog schedules + ScheduleOverrides, then persisted
2. **Customized** - User can manually add/remove dogs; staleness tracked via `staleReason`
3. **Completed** - Mark as complete sets `completedAt`, preserves actual attendance and route

**Staleness Tracking:**
- `staleReason = nil` - Hike is up-to-date
- `staleReason = .routeNeedsOptimization` - Dogs manually added/removed, just re-optimize route
- `staleReason = .scheduleChanged` - Dog schedule changed, need to sync dog list

**Benefits:**
- Expensive routing (future: real roads) computed once and cached
- User customizations persist between views
- Single model for entire hike lifecycle
- Context-aware actions based on WHY hike is stale
- "Reset to Schedule" clears all overrides and regenerates from weekly pattern

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
13. Widgets - Home screen widget showing today's schedule at a glance
14. Siri support - Voice commands for checking schedule, updating dogs' schedule status, marking hikes complete

### Tier 3 (Nice-to-Have, Lower Priority)
15. Trip logging/history (which dogs hiked, weather, notes)
16. Advanced analytics (busiest days, revenue trends)
17. Photo uploads or dog profiles
18. Data export/backup
19. Multi-user support (unlikely for this use case)

---

## Future Roadmap: Enhanced Integrations & Automation

**Status:** Planning / Design Phase
**Last Updated:** 2025-12-25

### System Integrations (Planned)

**1. Contacts Integration (Hybrid Approach)**
- Add `contactIdentifier: String?` to Client model to link with system Contacts
- Pull phone numbers and addresses from linked contacts (avoid duplication)
- Embedded call/text buttons using contact data
- Fallback to manual entry for clients without linked contacts
- Preserve custom business data (dogs, schedules, payments) in app models
- Benefits: Auto-updates when contact info changes, native communication patterns

**2. Maps Integration (Research)**
- Investigate API access to iOS Maps app saved locations/guides
- Goal: Select a Maps guide folder to use as hiking locations list
- Status: No known public API currently available
- Would eliminate manual location management if feasible

**3. HealthKit/Fitness Integration**
- Match completed hikes to Apple Health workouts (`.walking`/`.hiking` activity type)
- Pull workout data: GPS route (`HKWorkoutRoute`), duration, distance, elevation, heart rate
- Display workout stats overlay in completed hike cards
- Compare planned route vs actual walked route
- Benefits: Richer historical data without manual tracking

**4. Photos Integration**
- Query Photos library by creation date + location (PhotoKit)
- Match photos taken during hike timeframe and near hiking location
- Display thumbnail gallery in completed hike cards
- Auto-suggest photos when marking hike complete
- Benefits: Visual documentation with context

### End-to-End Workflow Automation (Planned)

**Full Day Lifecycle:**

**Morning (Pre-Hike):**
- Home screen widget showing today's hikes overview
- Morning notification: "Time to start pickups - 8 dogs today"
- Tap notification → Opens app to today's schedule

**Pickup Phase:**
- Live Activity: Real-time progress ("Picking up 3/8 - Next: Buddy at 123 Main St")
- CoreLocation geofencing: Auto-detect arrivals at each pickup address
- Auto-advance to next pickup when location detected
- Manual check-off fallback if location detection fails
- "Navigate to next pickup" button (opens Maps with directions)

**At Trailhead:**
- Auto-detect arrival at hiking location
- Prompt: "Start Workout?" → Launch Apple Fitness workout tracking
- Live Activity updates: "Hiking at Hemlock Ravine"

**Drop-off Phase:**
- Auto-generate reverse route (pickup order reversed)
- Same Live Activity + geofencing as pickup phase
- Progress tracking: "Dropping off 7/8 - Next: Buddy"

**Completion:**
- Arrive home or last drop-off complete
- Prompt: "Mark hike complete?"
- Auto-pull matched workout data and photos
- Save as completed hike with actual attendance and route

**Key Technologies:**
- WidgetKit (home screen widget)
- ActivityKit (Live Activity, iOS 16.1+)
- CoreLocation (geofencing, region monitoring)
- UserNotifications (morning reminders, arrival notifications)
- HealthKit (workout matching)
- PhotoKit (photo matching)

### Advanced Routing (Planned)

**Current:** Straight-line distance, brute-force TSP
**Future:** Real road routing with travel time

**Planned Enhancements:**
- MapKit Directions API for actual driving routes and time estimates
- Cache computed routes (expensive calculations)
- "Reset Route" button to regenerate from current addresses
- Manual drag-to-reorder pickup sequence (override optimization)
- Time window support (e.g., "Don't arrive before 2pm")

**Implementation Notes:**
- Route caching requires unified DailyHike persistent model
- Reset functionality deletes cached route and triggers re-optimization
- Manual reordering saves customized sequence to DailyHike

### Open Design Questions

1. **DailyHike Invalidation Strategy**
   - Question: When Dog.regularSchedule changes, invalidate existing future DailyHikes?
   - Option A: Invalidate all → Data consistency, respects schedule changes
   - Option B: Keep existing → Preserves user customizations (manual routes, trail selection)
   - Option C: Flag as "stale" with warning, let user choose to regenerate or keep
   - Decision: TBD during implementation

2. **Contact Address Selection**
   - Question: What if linked contact has multiple addresses?
   - Approach: Prompt user to select primary pickup address during contact linking

3. **Workout Matching Logic**
   - Question: How to match hikes to workouts when multiple workouts exist same day?
   - Approach: Match by time range (hike start ± tolerance) and activity type

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

### Why Hybrid Contacts Integration (Not Full Reliance)?
- **Problem:** System Contacts designed for individual people, not business clients with multiple dogs
- **Original Decision:** Use custom Client/Dog models entirely (cleaner, more flexible)
- **Revised Approach:** Hybrid integration (planned)
  - Link to Contacts for standard info (phone, address) via `contactIdentifier`
  - Keep custom models for dog-specific business data (schedules, rates, payments)
  - Pull contact data when needed, don't duplicate
  - Fallback to manual entry if no contact linked
- **Benefits:** Avoid data duplication, native call/text UI, auto-updates from Contacts, while maintaining business data flexibility

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

**Document Version:** 2.1
**Created:** 2025-11-07
**Last Updated:** 2025-12-25
**Status:** In Development - Planning Future Integrations & Automation
