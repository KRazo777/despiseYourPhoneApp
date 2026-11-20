import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Controls what the block screen looks like when a blocked app is opened.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shield(named: application.localizedDisplayName, target: application.token.map(ShieldTarget.app) ?? .group,
               group: GroupStore.group(application: application.token))
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shield(named: application.localizedDisplayName, target: application.token.map(ShieldTarget.app) ?? .group,
               group: GroupStore.group(application: application.token, category: category.token))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shield(named: webDomain.domain, target: webDomain.token.map(ShieldTarget.web) ?? .group,
               group: GroupStore.group(webDomain: webDomain.token))
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shield(named: webDomain.domain, target: webDomain.token.map(ShieldTarget.web) ?? .group,
               group: GroupStore.group(webDomain: webDomain.token, category: category.token))
    }

    /// Drawn white up front; as a template image iOS tints it too dark for this background.
    private static let icon = UIImage(
        systemName: ShieldCopy.iconName,
        withConfiguration: UIImage.SymbolConfiguration(pointSize: ShieldCopy.iconPointSize, weight: .bold)
    )?.withTintColor(.white, renderingMode: .alwaysOriginal)

    private func shield(named name: String?, target: ShieldTarget, group: BlockGroup?) -> ShieldConfiguration {
        let opensLeft = group.flatMap { TempUnlock.opensLeft($0, target) }
        let request = group.map { TempUnlock.request($0, target) } ?? .none
        let unlockLabel = ShieldCopy.unlockButton(for: group, opensLeft: opensLeft, request: request).map {
            ShieldConfiguration.Label(text: $0, color: UIColor(white: ShieldCopy.unlockWhite, alpha: 1))
        }
        guard #available(iOS 26.4, *) else {
            return shield(named: name, opensLeft: opensLeft, request: request, group: group, unlockLabel: unlockLabel)
        }
        // Close is the bright, inviting choice; Unlock is dim and opens an
        // "Are you sure?" menu instead of unlocking straight away. "Cancel Unlock" and
        // "Open now" act on the first tap.
        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor(white: ShieldCopy.backgroundWhite, alpha: 1),
            icon: Self.icon,
            title: .init(text: ShieldCopy.title(for: name), color: .white),
            subtitle: ShieldCopy.subtitle(for: group, opensLeft: opensLeft, request: request).map { .init(text: $0, color: .lightGray) },
            primaryButtonLabel: .init(text: ShieldCopy.closeButton, color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: unlockLabel,
            secondaryButtonSubmenuItems: unlockLabel == nil || request != .none ? nil : ShieldCopy.unlockMenu
        )
    }

    /// Before iOS 26.4 there's no menu, so Unlock works with one tap.
    private func shield(named name: String?, opensLeft: Int?, request: TempUnlock.Request, group: BlockGroup?, unlockLabel: ShieldConfiguration.Label?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor(white: ShieldCopy.backgroundWhite, alpha: 1),
            icon: Self.icon,
            title: .init(text: ShieldCopy.title(for: name), color: .white),
            subtitle: ShieldCopy.subtitle(for: group, opensLeft: opensLeft, request: request).map { .init(text: $0, color: .lightGray) },
            primaryButtonLabel: .init(text: ShieldCopy.closeButton, color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: unlockLabel
        )
    }
}
