import ManagedSettings

/// Handles taps on the block screen's buttons.
/// Close leaves the app. Unlock lifts the app's group for a few minutes (see TempUnlock).
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(to: action, group: GroupStore.group(application: application)))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(to: action, group: GroupStore.group(webDomain: webDomain)))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(to: action, group: GroupStore.group(category: category)))
    }

    private func response(to action: ShieldAction, group: BlockGroup?) -> ShieldActionResponse {
        switch action {
        case .secondaryButtonPressed:
            guard let group else { return .close }
            // .defer redraws the shield so the button shows the next step.
            return TempUnlock.unlockTapped(group) ? .none : .defer
        default:
            return .close
        }
    }
}
