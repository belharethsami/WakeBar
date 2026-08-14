import Foundation

public enum SessionSchedule {
    public static func nextOccurrence(
        of selectedTime: Date,
        after now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let selectedComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        let startOfToday = calendar.startOfDay(for: now)

        guard
            let hour = selectedComponents.hour,
            let minute = selectedComponents.minute,
            let today = calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: startOfToday
            )
        else {
            return now.addingTimeInterval(60)
        }

        if today > now {
            return today
        }

        return calendar.date(byAdding: .day, value: 1, to: today)
            ?? now.addingTimeInterval(24 * 60 * 60)
    }
}
