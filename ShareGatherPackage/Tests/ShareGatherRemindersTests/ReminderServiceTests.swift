import Foundation
import Testing
@testable import ShareGatherReminders

@MainActor
@Test func creatingReminderRequestsAccessAndBuildsScheduledPayload() async throws {
    let eventStore = TestReminderEventStore(authorizationStatus: .notDetermined)
    let calendar = Calendar(identifier: .gregorian)
    let service = ReminderService(eventStore: eventStore, calendar: calendar)
    let scheduledAt = Date(timeIntervalSince1970: 1_800_000_000)
    let deepLinkURL = try #require(URL(string: "sharegather://bookmark/123"))

    try await service.createReminder(
        from: ReminderDraft(
            title: "  Read: iOS Development Guide  ",
            notes: "From ShareGather",
            deepLinkURL: deepLinkURL,
            scheduledAt: scheduledAt
        )
    )

    #expect(eventStore.requestCount == 1)
    let payload = try #require(eventStore.savedPayload)
    #expect(payload.title == "Read: iOS Development Guide")
    #expect(payload.notes == "From ShareGather")
    #expect(payload.deepLinkURL == deepLinkURL)
    #expect(payload.alarmDate == scheduledAt)
    #expect(payload.scheduledDateComponents.calendar == calendar)
    #expect(payload.scheduledDateComponents.timeZone == calendar.timeZone)
    #expect(payload.scheduledDateComponents.date == scheduledAt)
}

@MainActor
@Test func existingFullAccessSkipsAuthorizationRequest() async throws {
    let eventStore = TestReminderEventStore(authorizationStatus: .fullAccess)
    let service = ReminderService(eventStore: eventStore, calendar: .current)

    try await service.createReminder(from: makeDraft())

    #expect(eventStore.requestCount == 0)
    #expect(eventStore.savedPayload != nil)
}

@MainActor
@Test(arguments: [
    (ReminderAuthorizationStatus.denied, ReminderCreationError.accessDenied),
    (ReminderAuthorizationStatus.restricted, ReminderCreationError.accessRestricted),
])
func unavailableAuthorizationDoesNotAttemptToSave(
    status: ReminderAuthorizationStatus,
    expectedError: ReminderCreationError
) async throws {
    let eventStore = TestReminderEventStore(authorizationStatus: status)
    let service = ReminderService(eventStore: eventStore, calendar: .current)

    await #expect(throws: expectedError) {
        try await service.createReminder(from: makeDraft())
    }
    #expect(eventStore.requestCount == 0)
    #expect(eventStore.savedPayload == nil)
}

@MainActor
@Test func declinedAuthorizationDoesNotAttemptToSave() async throws {
    let eventStore = TestReminderEventStore(
        authorizationStatus: .notDetermined,
        requestResult: false
    )
    let service = ReminderService(eventStore: eventStore, calendar: .current)

    await #expect(throws: ReminderCreationError.accessDenied) {
        try await service.createReminder(from: makeDraft())
    }
    #expect(eventStore.requestCount == 1)
    #expect(eventStore.savedPayload == nil)
}

@MainActor
@Test func authorizationFailureIsMappedWithoutAttemptingToSave() async throws {
    let eventStore = TestReminderEventStore(
        authorizationStatus: .notDetermined,
        requestError: TestError.failure
    )
    let service = ReminderService(eventStore: eventStore, calendar: .current)

    await #expect(throws: ReminderCreationError.authorizationFailed) {
        try await service.createReminder(from: makeDraft())
    }
    #expect(eventStore.savedPayload == nil)
}

@MainActor
@Test func missingDefaultCalendarIsMapped() async throws {
    let eventStore = TestReminderEventStore(
        authorizationStatus: .fullAccess,
        saveError: ReminderEventStoreError.noDefaultCalendar
    )
    let service = ReminderService(eventStore: eventStore, calendar: .current)

    await #expect(throws: ReminderCreationError.noDefaultCalendar) {
        try await service.createReminder(from: makeDraft())
    }
}

@MainActor
@Test func otherEventStoreFailureIsMapped() async throws {
    let eventStore = TestReminderEventStore(
        authorizationStatus: .fullAccess,
        saveError: TestError.failure
    )
    let service = ReminderService(eventStore: eventStore, calendar: .current)

    await #expect(throws: ReminderCreationError.saveFailed) {
        try await service.createReminder(from: makeDraft())
    }
}

@MainActor
@Test func blankTitleFailsBeforeRequestingAuthorization() async throws {
    let eventStore = TestReminderEventStore(authorizationStatus: .notDetermined)
    let service = ReminderService(eventStore: eventStore, calendar: .current)
    let deepLinkURL = try #require(URL(string: "sharegather://bookmark/123"))
    let draft = ReminderDraft(
        title: " \n ",
        deepLinkURL: deepLinkURL,
        scheduledAt: .now
    )

    await #expect(throws: ReminderCreationError.invalidTitle) {
        try await service.createReminder(from: draft)
    }
    #expect(eventStore.requestCount == 0)
    #expect(eventStore.savedPayload == nil)
}

@MainActor
private final class TestReminderEventStore: ReminderEventStore {
    var authorizationStatus: ReminderAuthorizationStatus
    var requestCount = 0
    var savedPayload: ReminderPayload?

    private let requestResult: Bool
    private let requestError: (any Error)?
    private let saveError: (any Error)?

    init(
        authorizationStatus: ReminderAuthorizationStatus,
        requestResult: Bool = true,
        requestError: (any Error)? = nil,
        saveError: (any Error)? = nil
    ) {
        self.authorizationStatus = authorizationStatus
        self.requestResult = requestResult
        self.requestError = requestError
        self.saveError = saveError
    }

    func requestFullAccess() async throws -> Bool {
        requestCount += 1
        if let requestError {
            throw requestError
        }
        return requestResult
    }

    func save(_ payload: ReminderPayload) throws {
        if let saveError {
            throw saveError
        }
        savedPayload = payload
    }
}

private enum TestError: Error {
    case failure
}

private func makeDraft() throws -> ReminderDraft {
    ReminderDraft(
        title: "Read saved item",
        deepLinkURL: try #require(URL(string: "sharegather://bookmark/123")),
        scheduledAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}
