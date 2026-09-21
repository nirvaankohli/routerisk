import SwiftUI
import UIKit

extension ExposureLevel {
    var color: Color {
        switch self {
        case .lower: return Color(uiColor: rrTeal)
        case .moderate: return Color(uiColor: rrAmber).opacity(0.82)
        case .elevated: return Color(uiColor: rrOrange)
        case .high: return Color(uiColor: rrRed)
        }
    }
}

struct ExposureBadge: View {
    let level: ExposureLevel
    var compact = false

    var body: some View {
        Label(level.title, systemImage: level.symbol)
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(level.color)
            .accessibilityLabel("Historical exposure: \(level.title)")
    }
}

let rrTeal = UIColor(red: 0.106, green: 0.55, blue: 0.49, alpha: 1)
let rrAmber = UIColor(red: 0.82, green: 0.49, blue: 0.09, alpha: 1)
let rrOrange = UIColor(red: 0.80, green: 0.30, blue: 0.12, alpha: 1)
let rrRed = UIColor(red: 0.72, green: 0.18, blue: 0.20, alpha: 1)
