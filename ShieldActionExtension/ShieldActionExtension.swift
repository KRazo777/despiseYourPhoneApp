import Foundation
import ManagedSettings

/// Handles taps on the block screen's buttons.
/// Close leaves the app. Unlock uses an open and, for a group with an open delay, turns into
/// an "Open" menu: Open lets just that app through for a few minutes (see TempUnlock) once
/// the delay is over, and "Cancel open" or Close gives the open back.
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
        guard let group else {
            completionHandler(.close)
            return
        }
        // Checked before canUnlock: a waiting request may have used the last open.
        switch TempUnlock.request(group, target) {
        case .waiting(let until):
            respondWhileWaiting(to: action, group, target, opensAt: until, completionHandler: completionHandler)
        case .ready:
            respondWhileWaiting(to: action, group, target, opensAt: .now, completionHandler: completionHandler)
        case .none:
            guard isUnlockRequest(action) else {
                completionHandler(.close)
                return
            }
            startUnlock(group, target, completionHandler: completionHandler)
        }
    }

    /// Confirming uses the open and redraws the shield with the new count and an "Open" menu.
    /// The app only gets through on a later tap, because iOS takes the shield down when it
    /// gets the answer to a tap, not when the shield store changes on its own.
    private func startUnlock(_ group: BlockGroup, _ target: ShieldTarget, completionHandler: @escaping (ShieldActionResponse) -> Void) {
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
        completionHandler(.defer)
    }

    /// "Open" holds the answer until the open delay is over, then lets the app through.
    /// "Cancel open" and Close give the open back and leave the app.
    private func respondWhileWaiting(to action: ShieldAction, _ group: BlockGroup, _ target: ShieldTarget, opensAt: Date, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard isOpenRequest(action) else {
            TempUnlock.cancelUnlock(group, target)
            completionHandler(.close)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, opensAt.timeIntervalSinceNow)) {
            // A Cancel open tapped meanwhile removed the request, so this does nothing.
            completionHandler(TempUnlock.unlock(group, target, onlyIfRequested: true) ? .none : .defer)
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

    /// From iOS 26.4, "Open" is the first item in the Open menu. Earlier versions have
    /// no menu, so the button itself opens and Close cancels.
    private func isOpenRequest(_ action: ShieldAction) -> Bool {
        if #available(iOS 26.4, *) {
            return action == .firstSecondarySubmenuItemPressed
        }
        return action == .secondaryButtonPressed
    }
}
