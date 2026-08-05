import Foundation
import Testing
@testable import ShareGatherStorage

@Test func reminderPromptPreferenceDefaultsToEnabled() {
    let defaults = makeDefaults()

    #expect(SharedGatherLocalization.isReminderPromptEnabled(in: defaults))
}

@Test func reminderPromptPreferenceCanBeDisabledAndReenabled() {
    let defaults = makeDefaults()

    SharedGatherLocalization.setReminderPromptEnabled(false, in: defaults)
    #expect(!SharedGatherLocalization.isReminderPromptEnabled(in: defaults))

    SharedGatherLocalization.setReminderPromptEnabled(true, in: defaults)
    #expect(SharedGatherLocalization.isReminderPromptEnabled(in: defaults))
}

private func makeDefaults() -> UserDefaults {
    let suiteName = "ShareGatherTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
