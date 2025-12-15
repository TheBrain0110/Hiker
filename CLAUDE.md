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
- **Payment** - Payment records linked to dogs
- **HikingLocation** - Trail locations with coordinates and region tags

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

### Schedule Logic (`DailyHikeManager.swift`)

The **DailyHikeManager** computes daily schedules by combining:
1. Each dog's `regularSchedule` (their normal Mon-Fri pattern)
2. `ScheduleOverride` records for specific dates (overrides take precedence)

**Override Logic:**
- If a `ScheduleOverride` exists for a dog on a date, it **overrides** the regular schedule
- `OverrideType.isPresent` = dog is scheduled (even if not in regular schedule)
- `OverrideType.isAbsent` = dog is NOT scheduled (even if in regular schedule)
- No override = follow regular schedule

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

**TabView Structure (4 tabs):**
1. **Today** (`TodayView.swift`) - Daily schedule with hike cards, payment status
2. **Weekly** (`WeeklyScheduleView.swift`) - Week calendar for schedule management
3. **Clients** (`ClientsView.swift`) - Client/dog roster with detail views
4. **Settings** - Sample data loading, data management

**Detail Views:**
- `ClientDetailView.swift` - Edit client info, manage their dogs
- `DogDetailView.swift` - Edit dog details, schedule, payments

**Component Views:**
- `HikeCard.swift` - Displays single hike with dog list, route map, distance

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

### Sample Data

Use `SampleData.createSampleData(in:)` to populate test data:
- Creates clients with dogs in Bedford/Sackville/Beaver Bank
- Adds hiking locations for each region
- Sets up realistic schedules (Mon/Wed/Fri patterns)

Load via Settings tab → "Load Sample Data"

### iCloud Sync

- Configured in `HikerApp.swift` via `ModelConfiguration(cloudKitDatabase: .automatic)`
- Requires iCloud entitlement (already set in `Hiker.entitlements`)
- Syncs automatically in background
- Test with multiple devices logged into same iCloud account

## Common Patterns

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
```
Located in `Hiker/Extensions/Date+Extensions.swift`

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
├── ContentView.swift        # Main TabView
├── Models/
│   ├── Client.swift
│   ├── Dog.swift
│   ├── Payment.swift
│   ├── ScheduleOverride.swift
│   ├── ScheduleStatus.swift
│   ├── DayOfWeek.swift
│   ├── HikingLocation.swift
│   └── DailyHike.swift      # View model (not persisted)
├── Managers/
│   └── DailyHikeManager.swift
├── Utilities/
│   ├── RouteOptimizer.swift
│   └── SampleData.swift
├── Views/
│   ├── TodayView.swift
│   ├── WeeklyScheduleView.swift
│   ├── ClientsView.swift
│   ├── ClientDetailView.swift
│   ├── DogDetailView.swift
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
