# Development and Verification

## Workspace and Targets

Open `ShareGather.xcworkspace` and use the `ShareGather` scheme. Build with XcodeBuildMCP rather than raw `xcodebuild` commands.

```sh
xcodebuildmcp simulator build-and-run \
  --workspace-path ./ShareGather.xcworkspace \
  --scheme ShareGather \
  --simulator-name 'iPhone 17'
```

Physical-device installation requires a registered device, Apple Developer signing for the app and both extension targets, and Developer Mode.

## Localization

All user-facing strings require English, Traditional Chinese, and Simplified Chinese updates. English and Traditional Chinese are in `Localizable.xcstrings`; Simplified Chinese is in `Localization.swift`. Verify the main app and Share Extension after changing shared language behavior.

When adding an EventKit capability to an extension, localize the applicable `InfoPlist.strings` purpose descriptions as well as the shared UI strings.

## Privacy Manifests

`ShareGather/PrivacyInfo.xcprivacy` and `ShareGatherShareExtension/PrivacyInfo.xcprivacy` declare the required-reason use of App Group `UserDefaults` for the shared language preference. Update the applicable target manifests whenever code adds a privacy manifest data type or a Required Reason API. The Action Extension currently has no `UserDefaults` implementation.

## Dependencies

New third-party dependencies require explicit user approval. Prefer Apple frameworks where possible. When a dependency changes, commit the relevant Swift Package lockfiles.

## Verification

- Run `git diff --check` before committing.
- Build after code changes; install and launch on the connected iPhone after user-visible UI changes unless the user says not to.
- Update or add tests for storage, import, export, and backup changes.
- Test backup export to Files or a cloud-drive app, then test both merge and replace import behavior.
- Verify category visibility in the Share Extension after storage changes.
- For Reminders changes, test on a physical device with first-time allow, deny, no default list, and successful reminder creation. Verify the resulting deep link from both a cold and warm app launch.
