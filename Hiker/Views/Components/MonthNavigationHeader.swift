//
//  MonthNavigationHeader.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI

struct MonthNavigationHeader: View {
    @Binding var currentMonth: Date
    let onPrevious: () -> Void
    let onNext: () -> Void

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthFormatter.string(from: currentMonth))
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}
