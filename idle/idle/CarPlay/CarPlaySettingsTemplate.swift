import CarPlay

enum CarPlaySettingsTemplate {

    static func build() -> CPListTemplate {
        let versionItem = CPListItem(
            text: "idle",
            detailText: "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
        )
        versionItem.handler = { _, completion in completion() }

        let aboutItem = CPListItem(
            text: "About",
            detailText: "CarPlay video player"
        )
        aboutItem.handler = { _, completion in completion() }

        let section = CPListSection(items: [versionItem, aboutItem], header: "Settings", sectionIndexTitle: nil)
        let template = CPListTemplate(title: "Settings", sections: [section])
        template.tabTitle = "Settings"
        template.tabImage = UIImage(systemName: "gearshape")
        return template
    }
}
