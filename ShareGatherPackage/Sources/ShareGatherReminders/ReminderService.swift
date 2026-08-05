import EventKit
import Foundation

public struct ReminderDraft: Equatable, Sendable {
    public let title: String
    public let notes: String?
    public let deepLinkURL: URL
    public let scheduledAt: Date

    public init(
        title: String,
        notes: String? = nil,
        deepLinkURL: URL,
        scheduledAt: Date
    ) {
        self.title = title
        self.notes = notes
        self.deepLinkURL = deepLinkURL
        self.scheduledAt = scheduledAt
    }
}

public enum ReminderAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case fullAccess
}

public enum ReminderCreationError: Error, Equatable, Sendable {
    case invalidTitle
    case accessRestricted
    case accessDenied
    case noDefaultCalendar
    case authorizationFailed
    case saveFailed
}

@MainActor
public final class ReminderService {
    private let eventStore: any ReminderEventStore
    private let calendar: Calendar

    public convenience init() {
        self.init(
            eventStore: EventKitReminderEventStore(),
            calendar: .autoupdatingCurrent
        )
    }

    init(eventStore: any ReminderEventStore, calendar: Calendar) {
        self.eventStore = eventStore
        self.calendar = calendar
    }

    public var authorizationStatus: ReminderAuthorizationStatus {
        eventStore.authorizationStatus
    }

    public func createReminder(from draft: ReminderDraft) async throws {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw ReminderCreationError.invalidTitle
        }

        try await ensureWriteAccess()

        let payload = ReminderPayload(
            title: title,
            notes: visibleNotes(draft.notes, deepLinkURL: draft.deepLinkURL),
            deepLinkURL: draft.deepLinkURL,
            scheduledDateComponents: dateComponents(for: draft.scheduledAt),
            alarmDate: draft.scheduledAt
        )

        do {
            try eventStore.save(payload)
        } catch ReminderEventStoreError.noDefaultCalendar {
            throw ReminderCreationError.noDefaultCalendar
        } catch {
            throw ReminderCreationError.saveFailed
        }
    }

    public func requestAccess() async throws {
        try await ensureWriteAccess()
    }

    private func ensureWriteAccess() async throws {
        switch eventStore.authorizationStatus {
        case .fullAccess:
            return
        case .restricted:
            throw ReminderCreationError.accessRestricted
        case .denied:
            throw ReminderCreationError.accessDenied
        case .notDetermined:
            do {
                guard try await eventStore.requestFullAccess() else {
                    throw ReminderCreationError.accessDenied
                }
            } catch let error as ReminderCreationError {
                throw error
            } catch {
                throw ReminderCreationError.authorizationFailed
            }
        }
    }

    private func visibleNotes(_ notes: String?, deepLinkURL: URL) -> String {
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if let trimmedNotes, !trimmedNotes.isEmpty {
            parts.append(trimmedNotes)
        }
        parts.append(deepLinkURL.absoluteString)

        return parts.joined(separator: "\n\n")
    }

    private func dateComponents(for date: Date) -> DateComponents {
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return components
    }
}

@MainActor
protocol ReminderEventStore: AnyObject {
    var authorizationStatus: ReminderAuthorizationStatus { get }

    func requestFullAccess() async throws -> Bool
    func save(_ payload: ReminderPayload) throws
}

struct ReminderPayload: Equatable {
    let title: String
    let notes: String?
    let deepLinkURL: URL
    let scheduledDateComponents: DateComponents
    let alarmDate: Date
}

enum ReminderEventStoreError: Error {
    case noDefaultCalendar
    case fullAccessAPIUnavailable
}

@MainActor
private final class EventKitReminderEventStore: ReminderEventStore {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    var authorizationStatus: ReminderAuthorizationStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .fullAccess, .writeOnly:
            return .fullAccess
        @unknown default:
            return .denied
        }
    }

    func requestFullAccess() async throws -> Bool {
#if os(macOS)
        guard #available(macOS 14.0, *) else {
            throw ReminderEventStoreError.fullAccessAPIUnavailable
        }
#endif
        return try await eventStore.requestFullAccessToReminders()
    }

    func save(_ payload: ReminderPayload) throws {
        guard let defaultCalendar = eventStore.defaultCalendarForNewReminders() else {
            throw ReminderEventStoreError.noDefaultCalendar
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = payload.title
        reminder.notes = payload.notes
        reminder.url = payload.deepLinkURL
        reminder.calendar = defaultCalendar
        reminder.startDateComponents = payload.scheduledDateComponents
        reminder.dueDateComponents = payload.scheduledDateComponents
        reminder.addAlarm(EKAlarm(absoluteDate: payload.alarmDate))

        try eventStore.save(reminder, commit: true)
    }
}
