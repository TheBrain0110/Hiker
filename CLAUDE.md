# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Happy Hound Hikes** - Multi-platform app (iOS and macOS) for managing a dog-hiking business in Halifax, Nova Scotia. Built with SwiftUI and SwiftData, the app handles scheduling, route optimization, and payment tracking for up to 40 dogs across 2 daily hikes (max 8 dogs per hike).

**Primary Use Case:** Answer "What dogs am I picking up today?" with automatically optimized pickup routes.

## Tech Stack & Requirements

- **Platform:** iOS and macOS (SwiftUI)
- **Data Layer:** SwiftData with iCloud sync (CloudKit automatic sync)
- **Maps:** MapKit for route visualization and distance calculation
- **No External Dependencies:** Native Apple frameworks only

## Build & Test Commands

### Building
```bash
# Build for iOS
xcodebuild -scheme Hiker -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build for macOS
xcodebuild -scheme Hiker -configuration Debug -destination 'platform=macOS' build

# Build for testing (iOS)
xcodebuild -scheme Hiker -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing
```

### Testing
```bash
# Run all tests (iOS)
xcodebuild test -scheme Hiker -destination 'platform=iOS Simulator,name=iPhone 17'

# Run all tests (macOS)
xcodebuild test -scheme Hiker -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme Hiker -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:HikerTests/HikerTests/testExample
```

### Running in Xcode
- Open `Hiker.xcodeproj` in Xcode
- Select a simulator/destination (iOS 17+ or macOS)
- Press Cmd+R to build and run
- Use Cmd+U to run tests

## Core Architecture

### Data Models (SwiftData)

The app uses **SwiftData** with iCloud CloudKit sync. All models are located in `Hiker/Models/`.

**Key Models:**
- **Client** - Dog owner (name, contact info, address with geocoded coordinates)
- **Dog** - Individual dog with regular weekly schedule, payment rate, pickup location
- **ScheduleOverride** - Daily exceptions to regular schedules (`.isPresent` or `.isAbsent`)
- **Payment** - Payment records linked to dogs (now includes `completedHikeId` to link to specific hikes)
- **HikingLocation** - Trail locations with coordinates and region tags
- **CompletedHike** - Historical record of completed hikes with actual attendance and route data
- **DogAttendance** - Per-dog participation tracking for completed hikes (denormalized snapshots)

**Critical Data Model Patterns:**

1. **CLLocationCoordinate2D Storage**
   - SwiftData doesn't support `CLLocationCoordinate2D` directly
   - Store as separate `latitude`/`longitude` Double properties
   - Expose via computed property (see `Dog.location`)

2. **Enum Storage**
   - SwiftData requires enums to be stored as raw values (String/Int)
   - Use private `typeRaw: String` with computed property for type-safe access
   - See `ScheduleOverride.swift` for pattern

3. **Schedule Representation**
   - Regular schedules: Array of `DayOfWeek` enum values (Mon-Fri)
   - Stored as `[Int]` in SwiftData (`regularScheduleDays`)
   - Accessed via computed property `regularSchedule: [DayOfWeek]`

4. **Historical Hike Storage**
   - `CompletedHike` stores actual hike completion data with override tracking
   - `DogAttendance` tracks per-dog participation with denormalized snapshots
   - **Override Persistence:** `DogAttendance.wasAddedViaOverride` tracks dogs added via `.isPresent` override
   - **Removed Dogs:** `CompletedHike.removedDogIds/removedDogNames` tracks dogs with `.isAbsent` overrides
   - Relationships: `CompletedHike` → `[DogAttendance]` (cascade delete)
   - Route storage: Separate `routeLatitudes` and `routeLongitudes` arrays
   - Computed property `route: [CLLocationCoordinate2D]` reconstructs coordinates

### Schedule Logic (`DailyHikeManager.swift`)

The **DailyHikeManager** computes daily schedules by combining:
1. Each dog's `regularSchedule` (their normal Mon-Fri pattern)
2. `ScheduleOverride` records for specific dates (overrides take precedence)

**Override Logic:**
- If a `ScheduleOverride` exists for a dog on a date, it **overrides** the regular schedule
- `OverrideType.isPresent` = dog is scheduled (even if not in regular schedule)
- `OverrideType.isAbsent` = dog is NOT scheduled (even if in regular schedule)
- No override = follow regular schedule

**Override State Machine (Adding/Removing Dogs):**
- **Adding a dog:**
  - If override exists → Delete it (revert to regular schedule)
  - If no override and NOT in regular schedule → Create `.isPresent` override
  - If no override and in regular schedule → Do nothing (already scheduled)
- **Removing a dog:**
  - If `.isPresent` override exists → Delete it (revert to not scheduled)
  - If `.isAbsent` override exists → Do nothing (already absent)
  - If no override → Create `.isAbsent` override (block regular schedule)

**Badge System:**
- **"Added" badge (green)** - Shown when dog has `.isPresent` override (exception to regular schedule)
- **"Removed" badge (red)** - Shown when dog has `.isAbsent` override (blocked from regular schedule)
- **No badge** - Dog following their regular weekly pattern (default state)

**Date Handling:**
- Use `Calendar.current.startOfDay(for:)` to normalize dates (time component stripped)
- Fetch overrides with date range predicate: `date >= startOfDay && date < nextDay`
- Weekend handling: Current implementation returns empty schedule for weekends (no `DayOfWeek` enum for Sat/Sun)

### Route Optimization (`RouteOptimizer.swift`)

**Algorithm:** Brute-force TSP solver (optimal for ≤8 dogs per hike)
- Generates all permutations (8! = 40,320) and finds shortest route
- Falls back to nearest-neighbor for >10 dogs (safety fallback)
- Uses straight-line distance via `CLLocation.distance(from:)`
- Returns `OptimizedRoute` with ordered pickups and total distance

**Usage:**
```swift
let optimizedRoute = RouteOptimizer.optimizeRoute(for: dogs)
let orderedDogs = optimizedRoute.pickups.map { /* reorder dogs */ }
```

### View Architecture

**TabView Structure (3 tabs):**
1. **Schedule** (`ScheduleView.swift`) - **UNIFIED VIEW** replacing Today + Weekly tabs
   - Scrolling timeline (past/present/future days)
   - Toggle between list and calendar views
   - Conditional UI based on day type (past/today/future)
2. **Clients** (`ClientsView.swift`) - Client/dog roster with detail views
3. **Settings** - Sample data loading, data management

**Schedule View Components:**
- `ScheduleListView.swift` - Scrolling day timeline (30 days past, 60 days future)
- `ScheduleCalendarView.swift` - Monthly grid calendar with indicators
- `DayRow.swift` - List item showing day summary
- `DayDetailView.swift` - Full day view with conditional UI and edit mode
  - **Unified Day Content:** Single `dayContent` view handles past/today/future with temporal conditionals
  - **Retroactive Completion:** Past dates show uncompleted planned hikes with "Mark Complete" option
  - **Edit Mode:** Toggle between view/edit modes (only shows when pending hikes exist)
  - **iOS Swipe Actions:** Swipe-to-delete dogs from hikes (iOS only)
  - **Badge System:** Visual indicators for schedule overrides (Added/Removed in both planned and completed hikes)
  - **Navigation:** Tap dog rows to navigate to DogDetailView
- `CompleteHikeSheet.swift` - Modal workflow for marking hikes complete with override persistence
- `CompletedHikeCard.swift` - Display component for historical hikes with "Added" badges and removed dogs section
- `MonthNavigationHeader.swift` - Reusable month navigation controls
- `WeekdayHeader.swift` - Reusable weekday column headers

**Detail Views:**
- `ClientDetailView.swift` - Edit client info, manage their dogs
- `DogDetailView.swift` - Edit dog details, schedule, payments, calendar view
  - **Segmented Control:** Switch between weekly pattern editor and calendar view
  - `DogScheduleCalendarView.swift` - Per-dog monthly calendar with interactive override editing
    - **Reactive Updates:** Green dots appear immediately when hikes marked complete (today or retroactive)
    - **Non-Editable Completed:** Dates with completed hikes cannot be edited via tapping
    - **Override Toggle:** Tap future dates to create/remove schedule overrides
  - `EditableWeeklySchedule.swift` - Weekly pattern toggle buttons

**Component Views:**
- `HikeCard.swift` - Displays single hike with dog list, route map, distance
- `Badge.swift` - Reusable pill-shaped badge for status indicators (inactive, overdue, Added, Removed)

### Business Rules

1. **Payment Policy:** 2-week advance payment required
2. **Overdue Definition:** Last payment >14 days old
3. **Hike Capacity:** Max 2 hikes/day, max 8 dogs/hike
4. **Pricing:** $25-$30 per dog per hike (Nova Scotia HST 14-15%)
5. **Service Area:** Bedford, Sackville, Beaver Bank regions
6. **Operating Days:** Monday-Friday only (no weekend hikes in regular schedule)

## Development Workflow

### Adding New Features

1. **Models First:** Define SwiftData models with proper persistence patterns
   - Use raw value storage for enums and coordinates
   - Set up relationships with `@Relationship(deleteRule:)`
   - Add models to schema in `HikerApp.swift`

2. **Manager Layer:** Create or extend managers for business logic
   - Keep managers `@MainActor` for SwiftData context access
   - Inject `ModelContext` via initializer

3. **Views:** Build SwiftUI views with `@Query` for reactive data
   - Use `@Environment(\.modelContext)` for mutations
   - Follow existing view patterns (NavigationStack, List-based UIs)

### Working with SwiftData

**Queries:**
```swift
@Query(sort: \Dog.name) private var dogs: [Dog]
@Query(filter: #Predicate<Dog> { $0.isActive }) private var activeDogs: [Dog]
```

**Mutations:**
```swift
@Environment(\.modelContext) private var modelContext

// Insert
modelContext.insert(newDog)

// Delete
modelContext.delete(dog)

// Batch delete
try? modelContext.delete(model: Dog.self)
```

### Unit Testing

The project uses Swift Testing framework (`@Test`, `#expect`) for unit tests in `HikerTests/`.

**Test Files:**
- `ModelTests.swift` - SwiftData model computed properties (28 tests)
- `DateExtensionTests.swift` - Date utility functions (25 tests)
- `RouteOptimizerTests.swift` - Route optimization algorithms (12 tests)
- `DayOfWeekTests.swift` - DayOfWeek enum (6 tests)
- `DailyHikeManagerTests.swift` - Schedule computation (15 tests, **disabled**)
- `ScheduleOverrideTests.swift` - Override logic (9 tests, **disabled**)

**Running Tests:**
```bash
# Run all unit tests
xcodebuild test -scheme Hiker -destination 'platform=macOS' -only-testing:HikerTests

# Run specific test suite
xcodebuild test -scheme Hiker -destination 'platform=macOS' -only-testing:HikerTests/ModelTests
```

### SwiftData Unit Testing Limitation

**⚠️ IMPORTANT:** SwiftData models cannot be fully tested in unit tests due to a cross-module type metadata issue.

**The Problem:**
When the test target creates a `ModelContainer` with `@Model` types defined in the main app target, SwiftData cannot resolve the model type metadata at runtime. This causes:
- `EXC_BREAKPOINT (SIGTRAP)` crash at `context.insert()`
- Objects appear as `Hiker.Client._SwiftDataNoType` in debugger
- Happens even though `@testable import Hiker` provides compile-time access

**Root Cause:**
The `@Model` macro generates runtime type metadata that lives in the main app binary. The test target's `ModelContainer` looks for this metadata but can't find it across the module boundary.

**What CAN Be Tested (without ModelContext):**
```swift
// ✅ Create model instances without inserting into context
let dog = Dog(name: "Buddy", client: nil, regularSchedule: [.monday, .friday])

// ✅ Test computed properties
#expect(dog.isScheduledOn(.monday) == true)
#expect(dog.location == nil)

// ✅ Test setters
dog.regularSchedule = [.tuesday]
#expect(dog.regularScheduleDays == [2])
```

**What CANNOT Be Tested (requires ModelContext):**
- Relationship navigation (`client.dogs`, `dog.payments`)
- Queries and fetches
- `DailyHikeManager` (queries dogs and overrides)
- Integration tests that persist and retrieve data

**Workarounds:**
1. **Test model logic without context** - Current approach in `ModelTests.swift`
2. **UI Tests** - Run in app's process with access to type metadata
3. **Shared Framework** - Move models to framework linked by both targets
4. **Wait for Apple fix** - May be resolved in future Xcode versions

See detailed documentation in test file headers, especially `DailyHikeManagerTests.swift`.

### Sample Data

Use `SampleData.createSampleData(in:)` to populate test data:
- Creates clients with dogs in Bedford/Sackville/Beaver Bank
- Adds hiking locations for each region
- Sets up realistic schedules (Mon/Wed/Fri patterns)
- Generates **completed hikes for past 5 weekdays** with attendance records
  - Automatically determines scheduled dogs based on their regular schedules
  - Creates sample route coordinates and assigns random trails
  - Includes DogAttendance records with denormalized data (dogName, address, rates)
  - Adds notes to most recent hike for testing

Load via Settings tab → "Load Sample Data"

### iCloud Sync

- Configured in `HikerApp.swift` via `ModelConfiguration(cloudKitDatabase: .automatic)`
- Requires iCloud entitlement (already set in `Hiker.entitlements`)
- Syncs automatically in background
- Test with multiple devices logged into same iCloud account

## Common Patterns

### Edit Mode Pattern
DayDetailView implements a toggle-based edit mode for schedule management:

```swift
@State private var isEditing = false

// Toolbar button (only for days with pending hikes)
if hasPendingHikes {
    Button(isEditing ? "Done" : "Edit") {
        withAnimation {
            isEditing.toggle()
        }
    }
}

// Conditional UI
if isEditing && hasPendingHikes {
    // Show edit controls (remove buttons, "Available to Add" section)
}
```

**Edit Mode Features:**
- **State-Driven Visibility:** Edit button only appears when there are uncompleted hikes (not just based on date)
- **iOS Swipe Actions:** Use `#if os(iOS)` for swipe-to-delete gestures
- **Explicit Buttons:** Remove buttons visible only in edit mode
- **Progressive Disclosure:** Hide "Available to Add" section until edit mode activated

### Navigation from List Items
Dog rows in hike cards are wrapped in NavigationLinks for direct navigation:

```swift
NavigationLink {
    DogDetailView(dog: dog)
} label: {
    // Row content
}
```

**For historical data (CompletedHikeDogRow):**
- Look up dog by UUID using FetchDescriptor
- Show NavigationLink only if dog still exists
- Gracefully handle deleted dogs (show historical data without navigation)

### Platform-Specific Code
**CRITICAL:** Always wrap platform-specific modifiers in conditional compilation to support both iOS and macOS:

```swift
TextField("Phone", text: $phone)
    .textContentType(.telephoneNumber)
    #if os(iOS)
    .keyboardType(.phonePad)  // iOS-only modifier
    #endif
```

**Platform-Specific Modifiers:**
- `.keyboardType()` - iOS/iPadOS only (not available on macOS)
- `.autocapitalization()` - iOS/iPadOS only (not available on macOS)
- `.navigationBarTitleDisplayMode()` - iOS/iPadOS only (not available on macOS)
- Touch-based gestures - Use with `#if os(iOS)`
- Any UIKit-specific features

**Best Practice:** Design views to work gracefully on both platforms. Test builds for both iOS and macOS regularly.

### Date Extensions
```swift
// Get DayOfWeek from Date
if let dayOfWeek = date.dayOfWeek {
    // Returns DayOfWeek enum (.monday through .friday)
}

// Start of week (always Monday, regardless of locale)
let monday = date.startOfWeek

// Get specific day in same week
let friday = date.date(for: .friday)
```
Located in `Hiker/Extensions/Date+Extensions.swift`

**Week Start Convention:**
The app explicitly sets `calendar.firstWeekday = 2` (Monday) in `startOfWeek` and `isSameWeek` to ensure consistent Monday-based weeks regardless of user locale. This is a business requirement since the dog hiking service operates Monday-Friday only.

Without this override, US locales would use Sunday as first day of week, causing `startOfWeek` to return the wrong date and breaking schedule calculations.

### Navigation
```swift
NavigationStack {
    List { /* content */ }
        .navigationTitle("Title")
        .toolbar {
            // Toolbar items
        }
}
```

### Color System
- Use semantic colors: `.background.secondary` for cards
- System colors for status: `.green` (paid), `.red` (overdue), `.orange` (warning)

## Known Design Decisions

### Why ScheduleOverride instead of ScheduleException?
- Originally designed as "ScheduleException" (per HAPPY_HOUND_HIKES_BRIEF.md)
- Renamed to "ScheduleOverride" in implementation for clarity
- Simpler model: just `dogId`, `date`, and `type` (present/absent)
- No week-level grouping - each override is date-specific

### Why Brute-Force Route Optimization?
- Only 8 dogs max per hike = 40k permutations (~100ms)
- Guarantees optimal route (vs. 85% optimal with greedy nearest-neighbor)
- Geographic clustering in service area means most routes similar
- User can manually reorder if desired (drag-to-reorder capability exists)

### Why No System Contacts Integration?
- System Contacts designed for individual people, not business clients with multiple dogs
- Custom Client/Dog models provide flexibility for dog-specific fields
- Cleaner separation of app data from personal contacts

## Project Structure
```
Hiker/
├── HikerApp.swift           # App entry, SwiftData setup
├── ContentView.swift        # Main TabView (3 tabs: Schedule, Clients, Settings)
├── Models/
│   ├── Client.swift
│   ├── Dog.swift
│   ├── Payment.swift        # Extended with completedHikeId
│   ├── ScheduleOverride.swift
│   ├── DayOfWeek.swift
│   ├── HikingLocation.swift
│   ├── DailyHike.swift      # View model (not persisted)
│   ├── CompletedHike.swift  # NEW: Historical hike records
│   └── DogAttendance.swift  # NEW: Per-dog participation tracking
├── Managers/
│   └── DailyHikeManager.swift
├── Utilities/
│   ├── RouteOptimizer.swift
│   └── SampleData.swift
├── Views/
│   ├── ScheduleView.swift   # Main schedule tab (replaces former Today + Weekly tabs)
│   ├── Schedule/            # Schedule view components
│   │   ├── ScheduleListView.swift
│   │   ├── ScheduleCalendarView.swift
│   │   ├── DayRow.swift
│   │   ├── DayDetailView.swift  # With edit mode, badges, navigation
│   │   ├── CompleteHikeSheet.swift
│   │   └── CompletedHikeCard.swift
│   ├── Clients/             # Client management views
│   │   ├── ClientsView.swift
│   │   ├── ClientDetailView.swift
│   │   ├── DogDetailView.swift
│   │   └── DogScheduleCalendarView.swift  # Per-dog calendar with override editing
│   ├── Components/          # Shared UI components
│   │   ├── Badge.swift
│   │   ├── MonthNavigationHeader.swift
│   │   └── WeekdayHeader.swift
│   └── HikeCard.swift
└── Extensions/
    └── Date+Extensions.swift
```

## Reference Documentation

Full product requirements in `HAPPY_HOUND_HIKES_BRIEF.md` including:
- Detailed feature specifications
- Data model schemas with field definitions
- Route optimization algorithm details
- Business workflow context
- Future roadmap (Tier 1/2/3 features)
