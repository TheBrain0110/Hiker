//
//  Badge.swift
//  Hiker
//
//  Created by Claude on 12/16/25.
//

import SwiftUI

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

#Preview {
    HStack(spacing: 8) {
        Badge(text: "Inactive", color: .gray)
        Badge(text: "Overdue", color: .red)
        Badge(text: "Added", color: .green)
        Badge(text: "Removed", color: .red)
    }
    .padding()
}
