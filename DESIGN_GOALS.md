# Design Goals & Future Enhancement Planning

**Date:** 2025-12-25
**Status:** Planning / Design Phase
**Purpose:** Document architectural decisions and planned enhancements from brainstorming session

---

## Overview

This document captures the design thinking and planned enhancements for Happy Hound Hikes app, following a comprehensive review of the current architecture and future needs.

---

## 1. Unified DailyHike Lifecycle

### Current State
- **DailyHike** - Ephemeral view model, computed on-the-fly from Dog schedules + ScheduleOverrides
- **CompletedHike** - Separate persistent model for historical hikes
- Route optimization runs every time a day is viewed

### The Problem
- Future advanced routing (real roads, travel time) will be expensive to compute
- Can't cache routes or preserve user customizations between views
- Two separate models for what's conceptually one entity at different lifecycle stages

### Proposed Solution: Unified Persistent Model

**Lifecycle:**
```
DailyHike States:
1. PLANNED (completedAt = nil)
   - Created on first access (lazy persistence)
   - Computed from Dog.regularSchedule + ScheduleOverride rules
   - Route optimized and cached
   - User can customize (reorder, select trail)

2. CUSTOMIZED (completedAt = nil)
   - User modifications persist:
     - Manual route reordering
     - Trail selection
     - Dogs added/removed
   - "Reset" button deletes instance → regenerates from rules

3. COMPLETED (completedAt = Date)
   - Marked complete with actual attendance
   - Historical record preserved
   - Replaces current CompletedHike model
```

**Key Fields:**
- `date: Date` - Day of hike (normalized to startOfDay)
- `hikeNumber: Int` - 1 or 2
- `completedAt: Date?` - nil = planned, set = completed
- `routeLatitudes/Longitudes: [Double]` - Cached route
- `selectedTrailId: UUID?` - User-selected or auto-suggested trail
- `dogAttendances: [DogAttendance]` - Planned or actual attendance
- `notes: String?`

### Benefits
1. **Performance** - Expensive route calculations cached, not recomputed
2. **Persistence** - User customizations preserved between views
3. **Simplicity** - Single model for entire lifecycle, simpler mental model
4. **Flexibility** - Reset capability maintains connection to source rules

### Open Question: Invalidation Strategy

**Scenario:** User changes a dog's regularSchedule. What happens to existing future DailyHikes?

**Options:**

**A. Invalidate All**
- Delete all future DailyHikes for that dog
- Regenerate on next access
- ✅ Ensures data consistency
- ✅ Respects schedule changes
- ❌ Loses user customizations (manual routes, trail selections)

**B. Keep Existing**
- Don't invalidate; keep cached DailyHikes
- ✅ Preserves customizations
- ❌ May not reflect current schedule reality
- ❌ User confusion if schedule changed but hikes don't update

**C. Flag as Stale (Recommended)**
- Mark affected DailyHikes as "stale" when source data changes
- Show warning indicator in UI: "Schedule changed - review this hike"
- User can choose: "Keep customizations" or "Regenerate from new schedule"
- ✅ User control and awareness
- ✅ Preserves customizations if desired
- ✅ Allows regeneration if needed
- ⚠️ More complex implementation

**Decision:** TBD during implementation (recommend Option C)

---

## 2. System Integrations

### Philosophy: Hybrid Approach
Leverage native system services for standard functionality while maintaining custom business models for domain-specific needs.

### 2.1 Contacts Integration

**Original Decision:** No Contacts integration - too limiting for business use case

**Revised Approach:** Hybrid integration

**Implementation:**
- Add `contactIdentifier: String?` field to Client model
- Use CNContactPickerViewController for linking
- Pull data from Contacts when identifier exists:
  - Phone numbers → `tel:` URL for call button
  - Phone numbers → `sms:` URL for text button
  - Addresses → Geocode for pickup location
  - Photo, email, other standard fields
- Fallback to manual entry when no contact linked

**Benefits:**
- No duplicate phone/address data maintenance
- Native contact card UI for viewing/editing
- Auto-updates when user changes contact info in Contacts app
- Familiar communication patterns (tap-to-call/text)
- Preserves custom business data (dogs, schedules, payments)

**Open Questions:**
1. **Multiple Addresses** - If contact has home + work address, which to use?
   - **Approach:** Prompt user to select primary pickup address during linking
2. **Deleted Contacts** - What if linked contact gets deleted?
   - **Approach:** Keep Client with last-known data, show warning, allow re-link or manual entry
3. **Privacy Permissions** - How to request Contacts access?
   - **Approach:** Request permission on-demand when user taps "Link Contact" button

### 2.2 HealthKit/Fitness Integration

**Goal:** Link completed hikes to Apple Health workouts for richer historical data

**Implementation:**
- Query `HKWorkout` objects filtered by date range and activity type (`.walking` or `.hiking`)
- Match workouts to completed hikes by:
  - Date overlap (hike date matches workout start date)
  - Time range tolerance (workout start within ±2 hours of hike start)
  - Activity type
- Pull workout data:
  - `HKWorkoutRoute` - GPS track (series of CLLocations)
  - Duration (actual vs planned)
  - Distance (actual vs route-optimized)
  - Elevation gain, heart rate, calories
- Display in CompletedHikeCard:
  - Workout route overlay on map (vs planned route)
  - Stats comparison table
  - Health app deep link

**Benefits:**
- No duplicate tracking (user already uses Fitness/Apple Watch)
- Validation of route optimization (compare planned vs actual)
- Richer historical context
- Workout motivation (see actual stats)

**Open Questions:**
1. **Multiple Workouts** - What if user logged multiple workouts same day?
   - **Approach:** Match by time range, prefer longest duration, allow manual selection
2. **Split Workouts** - What if user paused/resumed workout?
   - **Approach:** Query all workouts in time range, combine routes if needed

### 2.3 Photos Integration

**Goal:** Automatically match photos taken during hikes for visual documentation

**Implementation:**
- Query Photos library using PhotoKit:
  - `PHAsset` filtered by `creationDate` and `location`
- Match photos to completed hikes:
  - Creation date between hike start and end (estimate 2-3 hour window)
  - Location within radius of hiking location (e.g., 1km)
- Display in CompletedHikeCard:
  - Thumbnail gallery (horizontal scroll)
  - Tap thumbnail → Full screen view with Photos app integration
- Suggest during completion:
  - When marking hike complete, show "12 photos found - Add to hike?"

**Benefits:**
- Visual memory/documentation
- No manual photo upload needed
- Context preserved (which hike, which dogs)

**Privacy:**
- Photos library permission required
- Show clear permission prompt: "Match photos to hikes for automatic documentation"

### 2.4 Maps Integration (Research)

**Goal:** Use iOS Maps saved locations/guides as hiking locations

**Status:** No known public API for accessing Maps app saved data

**Investigation Needed:**
- MapKit documentation review for new APIs
- Shared data containers (unlikely)
- URL scheme capabilities (can launch, can't read)
- Export/import workflows (Maps doesn't support)

**Workaround:**
- Keep current HikingLocationsView for CRUD
- Potential: "Quick add from coordinates" feature
- Potential: Import from GPX/KML if user exports elsewhere

---

## 3. End-to-End Workflow Automation

### Vision: Guided Daily Experience

Transform app from "reference tool" to "active assistant" throughout the day's workflow.

### 3.1 Morning (Pre-Hike)

**Home Screen Widget**
- WidgetKit widget showing today's overview
- Display: Dog count, first pickup time, hike locations
- Tap widget → Open app to today's schedule
- Update frequency: Timeline with hourly entries

**Morning Notification**
- Local notification scheduled for 7 AM (configurable)
- Content: "Time to start pickups - 8 dogs in 2 hikes today"
- Tap → Open app to today's schedule
- Smart: Only notify on days with scheduled hikes

### 3.2 Pickup Phase

**Live Activity (iOS 16.1+)**
- Always-visible progress on lock screen and Dynamic Island
- Display:
  - Current progress: "Picking up 3/8"
  - Next pickup: "Next: Buddy"
  - Address: "123 Main St"
  - Distance: "2 min away" (estimated)
- Actions:
  - "Navigate" → Open Maps with directions
  - "Check Off" → Manual advance (fallback)

**CoreLocation Geofencing**
- Set up region monitoring for each pickup address
- Radius: 50-100 meters (tunable)
- On region entry:
  - Auto-check-off current pickup
  - Advance to next
  - Update Live Activity
  - Notification: "Picked up Buddy ✓ - Next: Luna at 456 Oak St"
- Fallback: Manual check-off if location detection fails

**Navigation Integration**
- "Navigate to Next" button in Live Activity and app
- Opens Maps app with destination pre-filled
- Returns to app when navigation complete

### 3.3 At Trailhead

**Arrival Detection**
- Geofence at hiking location
- On arrival:
  - Notification: "Start workout tracking?"
  - Tap → Launch Fitness app with hiking workout
  - Alternative: Deep link to Workout start screen

**Live Activity Update**
- Status changes to "Hiking at Hemlock Ravine"
- Timer shows elapsed hike time

### 3.4 Drop-off Phase

**Reverse Route Generation**
- Automatically generate drop-off sequence:
  - Pickup route reversed
  - OR: Re-optimize from trail to all addresses
- Same Live Activity UI as pickup phase
- Same geofencing auto-advance

**Progress Tracking**
- "Dropping off 7/8 - Next: Buddy"
- Check-off as each drop-off completes

### 3.5 Completion

**Auto-Completion Trigger**
- Last drop-off geofence exit OR manual "Mark Complete"
- Sheet appears: "Mark hike complete?"

**Auto-Pull Integrations**
- Match HealthKit workout (if exists)
- Match Photos (show thumbnail preview)
- Pre-fill with matched data

**Complete Flow**
- Confirm actual attendance (defaults to all planned)
- Select trail (pre-filled from plan)
- Add notes
- Save as completed hike

### Technical Stack

| Feature | Framework | Permission Required |
|---------|-----------|---------------------|
| Widget | WidgetKit | None |
| Live Activity | ActivityKit | None |
| Notifications | UserNotifications | Notifications |
| Geofencing | CoreLocation | Location Always |
| Workout matching | HealthKit | Health data read |
| Photo matching | PhotoKit | Photo library |

### Privacy Considerations

**Location "Always" Permission:**
- Required for geofencing (region monitoring)
- Sensitive permission - clear user communication needed
- Prompt text: "Enable precise location to auto-advance pickups as you arrive at each address"
- Show value: "No need to manually check off each pickup - the app knows when you arrive"

**Alternative:**
- Location "When In Use" with manual check-off
- Less automated but more privacy-friendly

---

## 4. Advanced Routing

### Current: Straight-Line TSP

**Algorithm:**
- Brute-force tries all permutations (8! = 40,320)
- Uses `CLLocation.distance(from:)` straight-line distance
- Fast (~100ms) and optimal for small problem size

**Limitations:**
- Doesn't account for actual roads
- No travel time estimates
- Can suggest routes that cross water, go wrong way on one-way streets, etc.

### Future: Real Road Routing

**MapKit Directions API:**
- `MKDirectionsRequest` + `MKDirections`
- Returns actual driving routes with turn-by-turn
- Provides:
  - Polyline route (not straight line)
  - Distance in meters (road distance)
  - Expected travel time in seconds
  - Route shape for visualization

**Implementation:**
```swift
// Async route calculation
func calculateRealRoute(from: CLLocation, to: CLLocation) async -> RouteSegment {
    let request = MKDirectionsRequest()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
    request.transportType = .automobile

    let directions = MKDirections(request: request)
    let response = try? await directions.calculate()

    return RouteSegment(
        distance: response?.routes.first?.distance ?? 0,
        travelTime: response?.routes.first?.expectedTravelTime ?? 0,
        polyline: response?.routes.first?.polyline
    )
}
```

**Performance Considerations:**
- Network requests required (not offline)
- Rate limits (need to cache results)
- 8! = 40,320 permutations × ~8 segments each = ~322k API calls
- **Solution:** Cached route segments between all pairs
  - Only N×(N-1)/2 = 28 API calls for 8 locations
  - Cache in DailyHike model
  - Invalidate cache when addresses change

**This is WHY we need unified persistent DailyHike:**
- Can't re-compute 28 API calls every time user views the schedule
- Must cache results in persistent model
- "Reset Route" button re-fetches and re-optimizes

### Manual Reordering

**Drag-to-Reorder UI:**
- Long-press dog row in pickup list
- Drag to new position
- Save customized order to DailyHike model
- Override optimization (user knows best)

**Reset Button:**
- "Reset Route" in edit mode toolbar
- Confirms: "Regenerate route from current addresses?"
- Deletes DailyHike instance
- Triggers fresh optimization on next load

---

## Implementation Priority

### Phase 1: Core Architecture (Foundation)
**Goal:** Unified model and basic caching

1. Document unified DailyHike model architecture design
2. Resolve invalidation strategy decision
3. Refactor DailyHike from view model to persisted SwiftData model
4. Implement lazy-load logic (check for existing before computing)
5. Add completedAt, selectedTrailId, cached route storage
6. Migrate CompletedHike data to unified model
7. Remove CompletedHike model
8. Add Reset Route button in edit mode
9. Implement hiking location selector at end of pickup list
10. Sort location selector by distance from last pickup

**Success Criteria:**
- Future schedules persist between views
- Route stays consistent unless reset
- Trail selection persists
- Migration completes without data loss

---

### Phase 2: System Integration (Enrichment)
**Goal:** Leverage native iOS services for richer data

**Contacts:**
11. Add contactIdentifier field to Client model
12. Implement Contact picker integration
13. Add call/text buttons using linked contact phone
14. Pull address from linked Contact for geocoding
15. Add fallback UI for clients without linked contacts

**HealthKit:**
16. Implement HealthKit workout matching for completed hikes
17. Display workout route/stats overlay in CompletedHikeCard

**Photos:**
18. Implement PhotoKit integration to match photos by time+location
19. Add photo thumbnail gallery to CompletedHikeCard

**Success Criteria:**
- Can link clients to Contacts, call/text buttons work
- Completed hikes show matched workout data when available
- Photos from hike appear in completed hike cards

---

### Phase 3: Workflow Automation (Active Assistance)
**Goal:** Guide user through entire day with minimal friction

**Morning:**
20. Design and implement home screen widget
21. Add morning notification reminder

**Active Hike:**
22. Implement Live Activity for pickup/drop-off progress
23. Add CoreLocation geofencing for auto-detecting arrivals
24. Implement auto-advance to next pickup on location detection
25. Add prompt to start Fitness workout at trailhead
26. Auto-generate reverse route for drop-off phase
27. Add auto-completion flow with workout/photo matching

**Success Criteria:**
- Widget shows today's schedule at a glance
- Live Activity updates as pickups progress
- Geofencing auto-advances without manual input
- Full day workflow feels guided and automated

---

### Phase 4: Advanced Features (Polish)
**Goal:** Research and nice-to-have enhancements

28. Research: Investigate Maps app saved locations API access
29. Implement real road routing using MapKit Directions
30. Add drag-to-reorder manual pickup sequence customization
31. Time window support ("Don't arrive before 2pm")

**Success Criteria:**
- Routes use real roads instead of straight lines
- Manual reordering available for user overrides
- Maps integration if API discovered

---

## Success Metrics

**User Experience:**
- Fewer taps to view tomorrow's schedule (0 taps if widget)
- Auto-advance eliminates manual check-offs (80%+ automated)
- Richer historical context (workouts + photos)

**Technical:**
- Route computation time <500ms with caching (vs current ~100ms uncached)
- Widget loads in <100ms (from cached DailyHike)
- Geofencing battery impact <2% per day

**Data Quality:**
- Contact info stays in sync with system Contacts
- Historical hikes preserve workout validation data
- Photos provide visual documentation

---

## Architectural Principles

1. **Lazy Persistence** - Compute once, cache, reuse
2. **Hybrid Integration** - Leverage system services where appropriate, maintain custom models where needed
3. **User Control** - Automation with manual override capability
4. **Privacy First** - Clear permission prompts, explain value proposition
5. **Offline Capable** - Degrade gracefully when network unavailable
6. **Single Source of Truth** - Rules (Dog schedules + overrides) remain authoritative, DailyHike is cache

---

## References

- **HAPPY_HOUND_HIKES_BRIEF.md** - Full product requirements and feature specifications
- **CLAUDE.md** - Development guide and implementation patterns
- **Todo List** - 31 actionable implementation tasks

---

**Document Status:** Living document, updated as design evolves
**Next Review:** After Phase 1 completion
