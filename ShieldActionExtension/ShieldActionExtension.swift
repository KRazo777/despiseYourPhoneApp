import Foundation
import ManagedSettings

/// Handles taps on the block screen's buttons.
/// Close leaves the app. Unlock lets just that app through for a few minutes (see TempUnlock),
/// after the group's open delay if it has one. During the delay, "Cancel open" or Close
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
                // "Cancel open" gives the open back and redraws the normal shield.
                TempUnlock.cancelUnlock(group, target)
                completionHandler(.defer)
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
        // Redraw now so the shield shows the new count and "Cancel open", then lift it once
        // the delay is over, unless the open was cancelled. iOS may stop the extension
        // before then; the shield offers "Open now" in that case.
        completionHandler(.defer)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(group.openDelay)) {
            _ = TempUnlock.unlock(group, target, requestedAt: requestedAt)
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
