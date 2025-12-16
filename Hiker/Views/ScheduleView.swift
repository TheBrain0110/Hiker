//
//  ScheduleView.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

enum ScheduleViewMode {
    case list
    case calendar
}

struct ScheduleView: View {
    @State private var viewMode: ScheduleViewMode = .list

    var body: some View {
        NavigationStack {
            Group {
                switch viewMode {
                case .list:
                    ScheduleListView()
                case .calendar:
                    ScheduleCalendarView()
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            viewMode = viewMode == .list ? .calendar : .list
                        }
                    } label: {
                        Image(systemName: viewMode == .list ? "calendar" : "list.bullet")
                    }
                }
            }
        }
    }
}

#Preview {
    let schema = Schema([Client.self, Dog.self, Payment.self, ScheduleOverride.self, HikingLocation.self, CompletedHike.self, DogAttendance.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.createSampleData(in: container.mainContext)

    return ScheduleView()
        .modelContainer(container)
}
