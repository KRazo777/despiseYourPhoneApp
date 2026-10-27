import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Controls what the block screen looks like when a blocked app is opened.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shield(named: application.localizedDisplayName, group: GroupStore.group(application: application.token))
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shield(named: application.localizedDisplayName, group: GroupStore.group(application: application.token, category: category.token))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shield(named: webDomain.domain, group: GroupStore.group(webDomain: webDomain.token))
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shield(named: webDomain.domain, group: GroupStore.group(webDomain: webDomain.token, category: category.token))
    }

    private func shield(named name: String?, group: BlockGroup?) -> ShieldConfiguration {
        let stage = group.map { TempUnlock.currentStage(for: $0.id) } ?? .idle
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(systemName: "hourglass"),
            title: .init(text: ShieldCopy.title(for: name), color: .white),
            subtitle: .init(text: ShieldCopy.subtitle(for: group), color: .lightGray),
            primaryButtonLabel: .init(text: ShieldCopy.closeButton, color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldCopy.secondaryButton(for: group, stage: stage).map { .init(text: $0, color: .lightGray) }
        )
    }
}
