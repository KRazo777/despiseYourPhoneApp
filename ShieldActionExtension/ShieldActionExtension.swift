import Foundation
import ManagedSettings

/// Handles taps on the block screen's buttons.
/// Close leaves the app. Unlock lets just that app through for a few minutes (see TempUnlock),
/// after the group's open delay if it has one. During the delay, "Cancel Unlock" or Close
/// gives the open back.
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
        let alreadyUnlocked = TempUnlock.activeUnlocks(group.id)[target.key] != nil
        DebugLog.add("tap \(action.rawValue) \(target.key.prefix(10)) delay=\(group.openDelay) state=\(TempUnlock.request(group, target)) unlocked=\(alreadyUnlocked)")
        // The delay ended and the app is unlocked, but iOS left the shield up (seen after
        // Close during the wait). Any tap lets the app through without using another open.
        if alreadyUnlocked {
            GroupStore.refresh(group)
            completionHandler(.none)
            return
        }
        // Checked before canUnlock: a waiting request may have used the last open.
        switch TempUnlock.request(group, target) {
        case .waiting, .ready:
            // Close gives the open back too, and the waiting timer then does nothing.
            guard action == .secondaryButtonPressed else {
                TempUnlock.cancelUnlock(group, target)
                completionHandler(.close)
                return
            }
            if case .waiting = TempUnlock.request(group, target) {
                // "Cancel Unlock" gives the open back and leaves the app, the same as Close.
                TempUnlock.cancelUnlock(group, target)
                completionHandler(.close)
            } else {
                // "Open now": the timer didn't get to run, and the open is already paid for.
                completionHandler(TempUnlock.unlock(group, target) ? .none : .defer)
            }
            return
        case .none:
            guard isUnlockRequest(action) else { break }
            startUnlock(group, target, completionHandler: completionHandler)
            return
        }
        completionHandler(.close)
    }

    private func startUnlock(_ group: BlockGroup, _ target: ShieldTarget, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard TempUnlock.canUnlock(group, target) else {
            // .defer redraws the shield, which hides the button.
            completionHandler(.defer)
            return
        }
        let requestedAt = TempUnlock.beginUnlock(group, target)
        guard group.openDelay > 0 else {
            completionHandler(TempUnlock.unlock(group, target) ? .none : .defer)
            return
        }
        // Redraw now so the shield shows the new count and "Cancel Unlock", then lift it once
        // the delay is over, unless the open was cancelled. iOS may stop the extension
        // before then; the shield offers "Open now" in that case.
        completionHandler(.defer)
        DebugLog.add("confirmed, answered defer")
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(group.openDelay)) {
            let opened = TempUnlock.unlock(group, target, requestedAt: requestedAt)
            DebugLog.add("timer fired, shield lifted=\(opened)")
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
