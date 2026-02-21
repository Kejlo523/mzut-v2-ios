import XCTest
@testable import mZUTCore

final class SettingsRepositoryTests: XCTestCase {
    func testDefaultsAndPersistence() {
        let store = InMemoryStore()
        let repository = SettingsRepository(store: store)

        XCTAssertEqual(repository.appLanguage(), SettingsPrefs.defaultAppLanguage)
        XCTAssertEqual(repository.widgetRefreshInterval(), SettingsPrefs.defaultWidgetRefreshInterval)
        XCTAssertTrue(repository.notificationsMasterEnabled())

        repository.setAppLanguage("en")
        repository.setWidgetRefreshInterval("60")
        repository.setNotificationsMasterEnabled(false)

        XCTAssertEqual(repository.appLanguage(), "en")
        XCTAssertEqual(repository.widgetRefreshInterval(), "60")
        XCTAssertFalse(repository.notificationsMasterEnabled())
    }
}

