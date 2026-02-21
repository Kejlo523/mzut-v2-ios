import Foundation

public final class SettingsRepository {
    private let store: KeyValueStore

    public init(store: KeyValueStore = UserDefaultsStore(suiteName: SettingsPrefs.prefsSettings)) {
        self.store = store
    }

    public func appLanguage() -> String {
        store.string(forKey: SettingsPrefs.appLanguage) ?? SettingsPrefs.defaultAppLanguage
    }

    public func setAppLanguage(_ value: String) {
        store.set(value, forKey: SettingsPrefs.appLanguage)
    }

    public func appTheme() -> String {
        store.string(forKey: SettingsPrefs.appTheme) ?? "dark"
    }

    public func setAppTheme(_ value: String) {
        store.set(value, forKey: SettingsPrefs.appTheme)
    }

    public func widgetRefreshInterval() -> String {
        store.string(forKey: SettingsPrefs.widgetRefreshInterval) ?? SettingsPrefs.defaultWidgetRefreshInterval
    }

    public func setWidgetRefreshInterval(_ value: String) {
        store.set(value, forKey: SettingsPrefs.widgetRefreshInterval)
    }

    public func notificationsMasterEnabled() -> Bool {
        if !store.boolExists(forKey: SettingsPrefs.notificationsMasterEnabled) {
            return SettingsPrefs.defaultNotificationsMasterEnabled
        }
        return store.bool(forKey: SettingsPrefs.notificationsMasterEnabled)
    }

    public func setNotificationsMasterEnabled(_ enabled: Bool) {
        store.set(enabled, forKey: SettingsPrefs.notificationsMasterEnabled)
    }

    public func notificationsGradesEnabled() -> Bool {
        if !store.boolExists(forKey: SettingsPrefs.notificationsGradesEnabled) {
            return SettingsPrefs.defaultNotificationsGradesEnabled
        }
        return store.bool(forKey: SettingsPrefs.notificationsGradesEnabled)
    }

    public func setNotificationsGradesEnabled(_ enabled: Bool) {
        store.set(enabled, forKey: SettingsPrefs.notificationsGradesEnabled)
    }

    public func notificationsPlanEnabled() -> Bool {
        if !store.boolExists(forKey: SettingsPrefs.notificationsPlanEnabled) {
            return SettingsPrefs.defaultNotificationsPlanEnabled
        }
        return store.bool(forKey: SettingsPrefs.notificationsPlanEnabled)
    }

    public func setNotificationsPlanEnabled(_ enabled: Bool) {
        store.set(enabled, forKey: SettingsPrefs.notificationsPlanEnabled)
    }

    public func notificationsPlanMovedEnabled() -> Bool {
        if !store.boolExists(forKey: SettingsPrefs.notificationsPlanMovedEnabled) {
            return SettingsPrefs.defaultNotificationsPlanMovedEnabled
        }
        return store.bool(forKey: SettingsPrefs.notificationsPlanMovedEnabled)
    }

    public func setNotificationsPlanMovedEnabled(_ enabled: Bool) {
        store.set(enabled, forKey: SettingsPrefs.notificationsPlanMovedEnabled)
    }

    public func notificationsPlanCancelledEnabled() -> Bool {
        if !store.boolExists(forKey: SettingsPrefs.notificationsPlanCancelledEnabled) {
            return SettingsPrefs.defaultNotificationsPlanCancelledEnabled
        }
        return store.bool(forKey: SettingsPrefs.notificationsPlanCancelledEnabled)
    }

    public func setNotificationsPlanCancelledEnabled(_ enabled: Bool) {
        store.set(enabled, forKey: SettingsPrefs.notificationsPlanCancelledEnabled)
    }

    public func notificationsPlanAddedEnabled() -> Bool {
        if !store.boolExists(forKey: SettingsPrefs.notificationsPlanAddedEnabled) {
            return SettingsPrefs.defaultNotificationsPlanAddedEnabled
        }
        return store.bool(forKey: SettingsPrefs.notificationsPlanAddedEnabled)
    }

    public func setNotificationsPlanAddedEnabled(_ enabled: Bool) {
        store.set(enabled, forKey: SettingsPrefs.notificationsPlanAddedEnabled)
    }

    public func notificationsPlanRemovedEnabled() -> Bool {
        if !store.boolExists(forKey: SettingsPrefs.notificationsPlanRemovedEnabled) {
            return SettingsPrefs.defaultNotificationsPlanRemovedEnabled
        }
        return store.bool(forKey: SettingsPrefs.notificationsPlanRemovedEnabled)
    }

    public func setNotificationsPlanRemovedEnabled(_ enabled: Bool) {
        store.set(enabled, forKey: SettingsPrefs.notificationsPlanRemovedEnabled)
    }
}
