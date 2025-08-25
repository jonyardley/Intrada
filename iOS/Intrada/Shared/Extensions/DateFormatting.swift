//
//  DateFormatting.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import Foundation

// MARK: - Enhanced Date and Time Formatting

extension DateFormatter {
    static let iso8601 = ISO8601DateFormatter()

    static func formatDateAndTime(_ dateString: String) -> String {
        if let date = iso8601.date(from: dateString) {
            let calendar = Calendar.current
            let displayFormatter = DateFormatter()

            if calendar.isDateInToday(date) {
                displayFormatter.dateFormat = "'Today at' h:mm a"
            } else if calendar.isDateInYesterday(date) {
                displayFormatter.dateFormat = "'Yesterday at' h:mm a"
            } else {
                displayFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
            }
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
