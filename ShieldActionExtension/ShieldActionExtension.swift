import Foundation
import ManagedSettings

/// Handles taps on the block screen's buttons.
/// Close leaves the app. Unlock uses an open and lets just that app through for a few minutes
/// (see TempUnlock) once the group's open delay is over. Close during the delay gives the open back.
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
        DebugLog.add("action \(action.rawValue) \(target.key.prefix(10)) waiting=\(TempUnlock.isWaiting(group, target)) delay=\(group.openDelay)")
        if TempUnlock.isWaiting(group, target) {
            // Close gives the open back and leaves; the held answer then does nothing.
            // Other taps are ignored.
            guard action == .primaryButtonPressed else {
                completionHandler(.none)
                return
            }
            TempUnlock.cancelUnlock(group, target)
            completionHandler(.close)
            return
        }
        TempUnlock.dropStaleRequest(group, target)
        guard isUnlockRequest(action) else {
            completionHandler(.close)
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
        // EXPERIMENT: rewrite the shield store while holding the answer, to see whether
        // iOS asks for the shield's look again and redraws it with the new count.
        GroupStore.applyShield(group)
        DebugLog.add("nudge1 same shield re-applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            GroupStore.nudgeShield(group)
            DebugLog.add("nudge2 categories toggled")
        }
        for tick in stride(from: 5, to: group.openDelay, by: 5) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(tick)) { DebugLog.add("alive \(tick)s") }
        }
        // Holding the answer keeps the extension running through the delay. Answering then
        // is what makes iOS take the shield down, so the app opens the moment it's over.
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(group.openDelay)) {
            let opened = TempUnlock.unlock(group, target, onlyIfRequested: true)
            DebugLog.add("answer opened=\(opened)")
            completionHandler(opened ? .none : .defer)
        }
    }

    /// From iOS 26.4, Unlock opens a menu and only its first item ("Unlock in Ns") counts;
    /// "Nevermind" falls through to Close. Earlier versions unlock on the button itself.
    private func isUnlockRequest(_ action: ShieldAction) -> Bool {
        if #available(iOS 26.4, *) {
            return action == .firstSecondarySubmenuItemPressed
        }
        return action == .secondaryButtonPressed
    }
}
