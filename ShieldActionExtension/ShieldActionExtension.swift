import Foundation
import ManagedSettings

/// Handles taps on the block screen's buttons.
/// Close leaves the app. Unlock lets just that app through for a few minutes (see TempUnlock),
/// after the group's open delay if it has one.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, target: .app(application), group: GroupStore.group(application: application), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, target: .web(webDomain), group: GroupStore.group(webDomain: webDomain), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // iOS only says which category, so unlock the whole group.
        respond(to: action, target: .group, group: GroupStore.group(category: category), completionHandler: completionHandler)
    }

    private func respond(to action: ShieldAction, target: ShieldTarget, group: BlockGroup?, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard isUnlockRequest(action), let group else {
            completionHandler(.close)
            return
        }
        // Checked first: the waiting tap may have used the last open.
        guard !TempUnlock.isWaiting(group, target) else {
            completionHandler(.none)
            return
        }
        guard TempUnlock.canUnlock(group, target) else {
            // .defer redraws the shield, which hides the button.
            completionHandler(.defer)
            return
        }
        TempUnlock.beginUnlock(group, target)
        guard group.openDelay > 0 else {
            completionHandler(TempUnlock.unlock(group, target) ? .none : .defer)
            return
        }
        // The shield can't show a countdown, so hold the answer until the delay is over,
        // then lift the shield and let the app through.
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(group.openDelay)) {
            completionHandler(TempUnlock.unlock(group, target) ? .none : .defer)
        }
    }

    /// From iOS 26.4, Unlock opens a menu and only "Yes, unlock" (the first item) counts;
    /// "Never mind" falls through to Close. Earlier versions unlock on the button itself.
    private func isUnlockRequest(_ action: ShieldAction) -> Bool {
        if #available(iOS 26.4, *) {
            return action == .firstSecondarySubmenuItemPressed
        }
        return action == .secondaryButtonPressed
    }
}
