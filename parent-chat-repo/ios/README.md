# iOS Xcode platform wrapper

This repository now includes a lightweight iOS wrapper folder that can be used as a starting point for an Xcode project. It loads the static Parent Chat site inside a `WKWebView` so the same HTML, CSS, and JavaScript files can be reused on iOS.

## Usage

1. Open Xcode.
2. Create a new iOS App project named `ParentChat`.
3. Copy the Swift files from this folder into the new app target.
4. Update the App bundle identifier and the URL to the app server or local file path.

The default URL points to the local HTTP server launched by `npm start`.

## Production note

For production iOS delivery, use HTTPS and a deployed website domain instead of the local plain HTTP URL. The Stripe payment link and native webview can open inside the app using the same `WKWebView` flow, but you must add the correct secure transport and remote-site permissions in the Xcode project.
