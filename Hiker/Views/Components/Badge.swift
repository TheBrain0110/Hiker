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
    HStack {
        Badge(text: "Inactive", color: .gray)
        Badge(text: "Warning", color: .orange)
        Badge(text: "Active", color: .green)
    }
}
