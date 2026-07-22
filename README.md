# ShareGather

ShareGather is an iOS app for collecting information shared from social media apps and reviewing it later.

The app is designed to work completely offline and does not require an account or sign-in. Users can share interesting links, text, images, or files directly to ShareGather, save them locally, and return to them when they have time.

## Product Goals

- Receive content through the iOS Share Sheet.
- Save content locally for later review.
- Keep saved content available offline.
- Avoid accounts, sign-in, servers, and unnecessary data collection.
- Provide a focused, personal, and privacy-conscious experience.

## Localization

The planned supported languages are:

- English
- Traditional Chinese (`zh-Hant`)

## Project Structure

- `ShareGather/` contains the iOS app shell.
- `ShareGatherPackage/` contains the feature module and unit tests.
- `ShareGatherUITests/` contains UI automation tests.
- `Config/` contains shared build settings and entitlements.

## Development

Open `ShareGather.xcworkspace` in Xcode. The project currently provides a SwiftUI iPhone app shell and will be extended with local persistence and a Share Extension.
