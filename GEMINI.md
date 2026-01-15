# Happy Hound Hikes - Project Context for Gemini

## Project Overview

**Happy Hound Hikes** is a multi-platform (iOS and macOS) SwiftUI application designed to manage a dog-hiking business. It utilizes **SwiftData** for local persistence with automatic **CloudKit** sync. The core value proposition is automating the "Who am I picking up today?" question via intelligent scheduling and route optimization.

### Tech Stack
*   **Language:** Swift 5+
*   **UI Framework:** SwiftUI
*   **Data Persistence:** SwiftData (Core Data under the hood)
*   **Cloud Sync:** CloudKit (via SwiftData `cloudKitDatabase: .automatic`)
*   **Mapping:** MapKit (Route visualization, distance calculations)
*   **Testing:** XCTest (Unit & UI Tests), Swift Testing

## Key Documentation

*   **`CLAUDE.md`**: Contains build commands, coding conventions, and architectural summaries. **Read this first for task-specific instructions.**
*   **`HAPPY_HOUND_HIKES_BRIEF.md`**: Detailed product requirements, business rules, and MVP scope.
*   **`DESIGN_GOALS.md`**: Roadmap, future architectural plans (system integrations, advanced routing), and design decisions.

## Build and Run Instructions

### Building
```bash
# Build for iOS Simulator (iPhone 17)
xcodebuild -scheme Hiker -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build for macOS
xcodebuild -scheme Hiker -configuration Debug -destination 'platform=macOS' build
```

### Testing
**Note:** Unit tests (`HikerTests`) involving SwiftData models often fail due to cross-module context issues. Prefer UI Tests (`HikerUITests`) for data layer validation.

```bash
# Run all UI tests (iOS)
xcodebuild test -scheme Hiker -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:HikerUITests

# Run specific drag-and-drop tests
xcodebuild test -scheme Hiker -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:HikerUITests/DragAndDropUITests
```

## Architecture & Code Structure

### Directory Map
*   **`Hiker/Models/`**: SwiftData entities.
    *   `DailyHike.swift`: Unified model for planned & completed hikes.
    *   `Dog.swift`, `Client.swift`: Core business entities.
    *   `ScheduleOverride.swift`: Exceptions to weekly schedules.
*   **`Hiker/Managers/`**: Business logic layer (Keep `@MainActor`).
    *   `DailyHikeManager.swift`: Hike lifecycle (creation, lazy loading, persistence).
    *   `DayScheduleManager.swift`: Daily operations (add/remove dogs, reorder, split hikes).
*   **`Hiker/Utilities/`**: Algorithms.
    *   `RouteOptimizer.swift`: TSP solver (Brute-force ≤8 dogs, Nearest Neighbor >8).
    *   `HikeClusterer.swift`: K-Means clustering for grouping dogs.
*   **`Hiker/Views/`**: SwiftUI Views.
    *   `ScheduleView.swift`: Main timeline interface.
    *   `Schedule/DayDetailView.swift`: Day orchestrator view.
    *   `Schedule/DayDetailComponents/`: Refactored subcomponents (Planned/Completed cards).

### Core Concepts

1.  **Unified DailyHike Lifecycle:**
    *   A single `DailyHike` model persists both planned and completed states.
    *   `completedAt` is `nil` for planned, set to `Date()` for completed.
    *   Hikes are **lazy-loaded**: generated from `Dog.regularSchedule` + `ScheduleOverride` only when a day is viewed.

2.  **Schedule Management:**
    *   **Regular Schedule:** `Dog.regularSchedule` (Mon-Fri).
    *   **Overrides:** `ScheduleOverride` (linked by `dogId` + `date`) takes precedence. `.isPresent` adds a dog; `.isAbsent` removes them.
    *   **Ephemeral Previews:** Future dates without `DailyHike` instances use lightweight calculation (`getExpectedDogs`) for the infinite scroll list to perform well.

3.  **Route Optimization:**
    *   Routes are optimized automatically when creating a hike.
    *   Users can manually reorder (drag & drop), which sets `hasManualRouteOrder = true` to prevent overwrite.
    *   Routes include a final destination (Hiking Trail).

4.  **Platform Compatibility:**
    *   Code must support both iOS and macOS.
    *   Use `#if os(iOS)` for platform-specific modifiers (e.g., `.keyboardType`, swipe actions).

## Development Conventions

*   **SwiftData Models:** Store enums as RawValues (Strings/Ints). Store Coordinates as separate Lat/Lon Doubles.
*   **Context:** Use `@Environment(\.modelContext)` in views. Pass context to Managers via init.
*   **UI Components:** Break down large views into components in subdirectories (e.g., `DayDetailComponents`).
*   **Safety:** Always check if a dog/client still exists before navigation (handle deletions gracefully).
