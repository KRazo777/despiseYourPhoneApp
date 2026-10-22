# Entitlements removed for now

Family Controls was taken out so the project builds without a paid Apple Developer account.
Add these back once the account is active.

## Removed

Each of these three files had exactly this entry, which was removed (each file is now an empty `<dict/>`):

- `MonitorExtension/MonitorExtension.entitlements`
- `ShieldConfigurationExtension/ShieldConfigurationExtension.entitlements`
- `ShieldActionExtension/ShieldActionExtension.entitlements`

```xml
<key>com.apple.developer.family-controls</key>
<true/>
```

The app target never had an entitlements file.

## To restore (Xcode > target > Signing & Capabilities, on all 4 targets)

1. Select your paid team.
2. + Capability > **Family Controls** (adds the key above; for the app target this also creates an entitlements file).
3. + Capability > **App Groups** > `group.com.kevinrazo.despiseyourphone` (must match `Shared/AppGroup.swift`). This was never added.
