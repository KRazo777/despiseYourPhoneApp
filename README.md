# despiseYourPhone

An iOS app that blocks distracting apps, built on Apple's Screen Time APIs.

## Features

- Pick apps, categories, and websites to block with Apple's privacy-preserving picker
- Block instantly, or on a repeating daily schedule that runs even when the app is closed
- Custom block screen

## How it works

| Target | Framework | Job |
|---|---|---|
| App | FamilyControls, SwiftUI | Asks for Screen Time access, shows the picker, and saves the selection to an App Group |
| MonitorExtension | DeviceActivity | iOS wakes it at the start and end of each scheduled window to apply or clear the shield |
| ShieldConfigurationExtension | ManagedSettingsUI | Draws the custom block screen |
| ShieldActionExtension | ManagedSettings | Handles taps on the block screen |

All targets share state through an App Group and a named `ManagedSettingsStore`. The app never sees which apps you chose, only opaque tokens.

## Requirements

iOS 17+, Xcode 15+, and the Family Controls entitlement.
