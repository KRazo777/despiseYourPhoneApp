import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Controls what the block screen looks like when a blocked app is opened.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shield(named: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shield(named: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shield(named: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shield(named: webDomain.domain)
    }

    private func shield(named name: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            icon: UIImage(systemName: "hourglass"),
            title: .init(text: "\(name ?? "This app") is blocked", color: .white),
            subtitle: .init(text: "Take a breath. Is this what you meant to do?", color: .lightGray),
            primaryButtonLabel: .init(text: "Close", color: .black),
            primaryButtonBackgroundColor: .white
        )
    }
}
