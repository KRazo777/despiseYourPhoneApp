import ManagedSettings

/// Handles taps on the block screen's buttons.
/// Close leaves the app. The second button unlocks the app's group for a few minutes
/// after a short wait (see TempUnlock).
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
            return TempUnlock.letMeIn(group) ? .none : .defer
        default:
            return .close
        }
    }
}
