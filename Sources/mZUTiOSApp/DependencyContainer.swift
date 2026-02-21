import Foundation
import mZUTCore

@MainActor
final class DependencyContainer {
    let launchArguments: [String]
    let isDemoContent: Bool

    let sessionStore: MzutSessionStore
    let apiClient: MzutAPIClient
    let authRepository: AuthRepository
    let homeRepository: HomeRepository
    let gradesRepository: GradesRepository
    let studiesInfoRepository: StudiesInfoRepository
    let newsRepository: NewsRepository
    let customPlanEventRepository: CustomPlanEventRepository
    let planRepository: PlanRepository
    let attendanceRepository: AttendanceRepository
    let usefulLinksRepository: UsefulLinksRepository
    let settingsRepository: SettingsRepository

    init() {
        let sessionStore = MzutSessionStore()
        let launchArguments = CommandLine.arguments
        let isDemoContent = launchArguments.contains("--ui-demo") || launchArguments.contains("--screenshot-home")
        let forcedScreen = launchArguments.first(where: { $0.hasPrefix("--screen=") })?.replacingOccurrences(of: "--screen=", with: "")
        let shouldSeedDemoUser = isDemoContent || (forcedScreen != nil && forcedScreen != "login")

        if shouldSeedDemoUser {
            sessionStore.updateUser(
                userId: "st123456",
                username: "Student Demo",
                authKey: "Student_TOKEN",
                imageUrl: nil
            )
            sessionStore.saveToStorage()
        }
        let apiClient = MzutAPIClient(sessionStore: sessionStore)
        let gradesRepository = GradesRepository(apiClient: apiClient, sessionStore: sessionStore)
        let customPlanEventRepository = CustomPlanEventRepository()
        let planRepository = PlanRepository(
            apiClient: apiClient,
            sessionStore: sessionStore,
            gradesRepository: gradesRepository,
            customPlanEventRepository: customPlanEventRepository
        )

        self.launchArguments = launchArguments
        self.isDemoContent = isDemoContent
        self.sessionStore = sessionStore
        self.apiClient = apiClient
        self.authRepository = AuthRepository(apiClient: apiClient, sessionStore: sessionStore)
        self.homeRepository = HomeRepository()
        self.gradesRepository = gradesRepository
        self.studiesInfoRepository = StudiesInfoRepository(
            apiClient: apiClient,
            sessionStore: sessionStore,
            gradesRepository: gradesRepository
        )
        self.newsRepository = NewsRepository()
        self.customPlanEventRepository = customPlanEventRepository
        self.planRepository = planRepository
        self.attendanceRepository = AttendanceRepository(planRepository: planRepository)
        self.usefulLinksRepository = UsefulLinksRepository()
        self.settingsRepository = SettingsRepository()
    }
}
