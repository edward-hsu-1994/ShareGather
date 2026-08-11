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

@Test func reminderPromptPreferenceUsesAppGroupSuite() throws {
    // If the App Group suite is unavailable in the test environment (no entitlement),
    // the public API returns defaults but does not crash. We still verify the contract:
    // the public accessors route through `SharedLibraryStore.appGroupIdentifier`.
    let appGroupSuite = UserDefaults(suiteName: SharedLibraryStore.appGroupIdentifier)
    let publicDefaults = UserDefaults(suiteName: SharedLibraryStore.appGroupIdentifier)

    // Set via the App Group API
    SharedGatherLocalization.setReminderPromptEnabled(false)
    if let appGroupSuite {
        #expect(!appGroupSuite.bool(forKey: SharedGatherLocalization.reminderPromptEnabledPreferenceKey))
    }
    #expect(!SharedGatherLocalization.isReminderPromptEnabled)

    SharedGatherLocalization.setReminderPromptEnabled(true)
    if let appGroupSuite {
        #expect(appGroupSuite.bool(forKey: SharedGatherLocalization.reminderPromptEnabledPreferenceKey))
    }
    #expect(SharedGatherLocalization.isReminderPromptEnabled)

    // Cleanup
    publicDefaults?.removePersistentDomain(forName: SharedLibraryStore.appGroupIdentifier)
}
