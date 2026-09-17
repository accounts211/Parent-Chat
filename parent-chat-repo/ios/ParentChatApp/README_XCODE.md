# Xcode project setup

The files in this folder are a minimal iOS wrapper starter for the Parent Chat static web app.

Use this in Xcode:

1. Create a new iOS App in Xcode.
2. Keep the product name as `ParentChat` or similar.
3. Copy the Swift files `AppDelegate.swift`, `SceneDelegate.swift`, `WebViewController.swift` into the app target.
4. Add the `LaunchScreen.storyboard` file.
5. Update the bundle identifier in `Info.plist`.
6. Choose a local launch URL or production URL; the current default is `http://127.0.0.1:8000/index.html`.

Note: On real iOS deployment, prefer HTTPS and a production domain instead of a plain HTTP localhost URL.
