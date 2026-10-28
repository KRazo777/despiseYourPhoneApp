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

    private func shield(named name: String?, target: ShieldTarget, group: BlockGroup?) -> ShieldConfiguration {
        let opensLeft = group.flatMap { TempUnlock.opensLeft($0, target) }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(systemName: "hourglass"),
            title: .init(text: ShieldCopy.title(for: name), color: .white),
            subtitle: ShieldCopy.subtitle(for: group, opensLeft: opensLeft).map { .init(text: $0, color: .lightGray) },
            // Close should be the easy, inviting choice; Unlock should look like an afterthought.
            primaryButtonLabel: .init(text: ShieldCopy.closeButton, color: .white),
            primaryButtonBackgroundColor: .systemIndigo,
            secondaryButtonLabel: ShieldCopy.unlockButton(for: group, opensLeft: opensLeft).map { .init(text: $0, color: UIColor(white: 0.4, alpha: 1)) }
        )
    }
}
