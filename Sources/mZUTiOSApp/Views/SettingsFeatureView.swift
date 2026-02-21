import SwiftUI
import mZUTCore

struct SettingsFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var language = SettingsPrefs.defaultAppLanguage
    @State private var theme = "default"
    @State private var widgetRefresh = SettingsPrefs.defaultWidgetRefreshInterval

    @State private var notifMaster = SettingsPrefs.defaultNotificationsMasterEnabled
    @State private var notifGrades = SettingsPrefs.defaultNotificationsGradesEnabled
    @State private var notifPlan = SettingsPrefs.defaultNotificationsPlanEnabled
    @State private var notifPlanMoved = SettingsPrefs.defaultNotificationsPlanMovedEnabled
    @State private var notifPlanCancelled = SettingsPrefs.defaultNotificationsPlanCancelledEnabled
    @State private var notifPlanAdded = SettingsPrefs.defaultNotificationsPlanAddedEnabled
    @State private var notifPlanRemoved = SettingsPrefs.defaultNotificationsPlanRemovedEnabled

    private let languages = [
        ("pl", "Polski"),
        ("en", "English"),
        ("uk", "Ukraiński"),
        ("de", "Deutsch"),
        ("eo", "Polski (Piracki)")
    ]

    private let themes = [
        ("default", "Domyślny"),
        ("deep_blue", "Deep Blue"),
        ("lime", "Limonka"),
        ("high_contrast", "Wysoki kontrast")
    ]

    private let refreshIntervals = [
        ("15", "15 min"),
        ("30", "30 min (domyślnie)"),
        ("45", "45 min"),
        ("60", "1 godz."),
        ("120", "2 godz."),
        ("180", "3 godz."),
        ("240", "4 godz."),
        ("0", "Nigdy (ręcznie)")
    ]

    var body: some View {
        Form {
            Section("Wygląd i język") {
                Picker("Motyw", selection: $theme) {
                    ForEach(themes, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .onChange(of: theme) { newValue in
                    appViewModel.dependencies.settingsRepository.setAppTheme(newValue)
                }

                Picker("Jezyk", selection: $language) {
                    ForEach(languages, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .onChange(of: language) { newValue in
                    appViewModel.dependencies.settingsRepository.setAppLanguage(newValue)
                }
            }

            Section("Widget") {
                Picker("Odświeżanie", selection: $widgetRefresh) {
                    ForEach(refreshIntervals, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .onChange(of: widgetRefresh) { newValue in
                    appViewModel.dependencies.settingsRepository.setWidgetRefreshInterval(newValue)
                }
            }

            Section("Powiadomienia") {
                Toggle("Włącz powiadomienia", isOn: $notifMaster)
                    .onChange(of: notifMaster) { newValue in
                        appViewModel.dependencies.settingsRepository.setNotificationsMasterEnabled(newValue)
                        if !newValue {
                            notifGrades = false
                            notifPlan = false
                            appViewModel.dependencies.settingsRepository.setNotificationsGradesEnabled(false)
                            appViewModel.dependencies.settingsRepository.setNotificationsPlanEnabled(false)
                        }
                    }

                Toggle("Powiadomienia o ocenach", isOn: $notifGrades)
                    .disabled(!notifMaster)
                    .onChange(of: notifGrades) { newValue in
                        appViewModel.dependencies.settingsRepository.setNotificationsGradesEnabled(newValue)
                    }

                Toggle("Powiadomienia o zmianach planu", isOn: $notifPlan)
                    .disabled(!notifMaster)
                    .onChange(of: notifPlan) { newValue in
                        appViewModel.dependencies.settingsRepository.setNotificationsPlanEnabled(newValue)
                        if !newValue {
                            notifPlanMoved = false
                            notifPlanCancelled = false
                            notifPlanAdded = false
                            notifPlanRemoved = false
                            appViewModel.dependencies.settingsRepository.setNotificationsPlanMovedEnabled(false)
                            appViewModel.dependencies.settingsRepository.setNotificationsPlanCancelledEnabled(false)
                            appViewModel.dependencies.settingsRepository.setNotificationsPlanAddedEnabled(false)
                            appViewModel.dependencies.settingsRepository.setNotificationsPlanRemovedEnabled(false)
                        }
                    }

                Toggle("Przeniesienie zajęć", isOn: $notifPlanMoved)
                    .disabled(!notifMaster || !notifPlan)
                    .onChange(of: notifPlanMoved) { newValue in
                        appViewModel.dependencies.settingsRepository.setNotificationsPlanMovedEnabled(newValue)
                    }

                Toggle("Odwołanie zajęć", isOn: $notifPlanCancelled)
                    .disabled(!notifMaster || !notifPlan)
                    .onChange(of: notifPlanCancelled) { newValue in
                        appViewModel.dependencies.settingsRepository.setNotificationsPlanCancelledEnabled(newValue)
                    }

                Toggle("Nowe zajęcia", isOn: $notifPlanAdded)
                    .disabled(!notifMaster || !notifPlan)
                    .onChange(of: notifPlanAdded) { newValue in
                        appViewModel.dependencies.settingsRepository.setNotificationsPlanAddedEnabled(newValue)
                    }

                Toggle("Usunięcie zajęć", isOn: $notifPlanRemoved)
                    .disabled(!notifMaster || !notifPlan)
                    .onChange(of: notifPlanRemoved) { newValue in
                        appViewModel.dependencies.settingsRepository.setNotificationsPlanRemovedEnabled(newValue)
                    }
            }
        }
        .navigationTitle("Ustawienia")
        .task {
            loadSettings()
        }
    }

    private func loadSettings() {
        let repo = appViewModel.dependencies.settingsRepository
        language = repo.appLanguage()
        theme = repo.appTheme()
        widgetRefresh = repo.widgetRefreshInterval()
        notifMaster = repo.notificationsMasterEnabled()
        notifGrades = repo.notificationsGradesEnabled()
        notifPlan = repo.notificationsPlanEnabled()
        notifPlanMoved = repo.notificationsPlanMovedEnabled()
        notifPlanCancelled = repo.notificationsPlanCancelledEnabled()
        notifPlanAdded = repo.notificationsPlanAddedEnabled()
        notifPlanRemoved = repo.notificationsPlanRemovedEnabled()
    }
}
