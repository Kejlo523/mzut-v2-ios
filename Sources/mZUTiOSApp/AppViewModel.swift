import Combine
import Foundation
import mZUTCore

@MainActor
final class AppViewModel: ObservableObject {
    enum AppScreen: String {
        case login
        case home
        case plan
        case grades
        case info
        case news
        case attendance
        case links
        case settings
    }

    @Published var login = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published private(set) var isAuthenticated = false
    @Published private(set) var displayName = "Student"
    @Published private(set) var tiles: [Tile] = []
    @Published private(set) var forcedScreen: AppScreen?
    @Published private(set) var forcedPlanSearch: PlanSearchParams?
    @Published private(set) var forcedPlanViewMode: PlanViewMode?

    let dependencies: DependencyContainer
    var isDemoContent: Bool { dependencies.isDemoContent }

    private var cancellables = Set<AnyCancellable>()

    init(dependencies: DependencyContainer? = nil) {
        self.dependencies = dependencies ?? DependencyContainer()
        self.tiles = self.dependencies.homeRepository.loadTiles()
        self.forcedScreen = Self.parseForcedScreen(from: self.dependencies.launchArguments)
        self.forcedPlanSearch = Self.parseForcedPlanSearch(from: self.dependencies.launchArguments)
        self.forcedPlanViewMode = Self.parseForcedPlanViewMode(from: self.dependencies.launchArguments)
        bindSession()
        refreshFromSession()
    }

    func loginUser() {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        let currentLogin = login
        let currentPassword = password

        Task {
            do {
                let result = try await dependencies.authRepository.login(login: currentLogin, password: currentPassword)
                await MainActor.run {
                    displayName = result.username
                    isLoading = false
                    password = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    func logout() {
        dependencies.authRepository.logout()
        password = ""
        errorMessage = nil
    }

    func restoreDefaultTiles() {
        tiles = dependencies.homeRepository.restoreDefaults()
    }

    private func bindSession() {
        dependencies.sessionStore.$userId
            .combineLatest(dependencies.sessionStore.$authKey, dependencies.sessionStore.$username)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userId, authKey, username in
                guard let self else {
                    return
                }
                self.isAuthenticated = !(userId ?? "").isEmpty && !(authKey ?? "").isEmpty
                let cleanUsername = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                self.displayName = cleanUsername.isEmpty ? (userId ?? "Student") : cleanUsername
            }
            .store(in: &cancellables)
    }

    private func refreshFromSession() {
        let session = dependencies.sessionStore
        isAuthenticated = session.isAuthenticated

        let username = session.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !username.isEmpty {
            displayName = username
        } else {
            displayName = session.userId ?? "Student"
        }
    }

    private static func parseForcedScreen(from args: [String]) -> AppScreen? {
        if let arg = args.first(where: { $0.hasPrefix("--screen=") }) {
            let raw = arg.replacingOccurrences(of: "--screen=", with: "").lowercased()
            switch raw {
            case "login": return .login
            case "home": return .home
            case "plan": return .plan
            case "grades": return .grades
            case "info": return .info
            case "news": return .news
            case "attendance": return .attendance
            case "links": return .links
            case "settings": return .settings
            default: break
            }
        }

        if args.contains("--screenshot-home") {
            return .home
        }

        return nil
    }

    private static func parseForcedPlanSearch(from args: [String]) -> PlanSearchParams? {
        guard let queryArg = args.first(where: { $0.hasPrefix("--plan-search-query=") }) else {
            return nil
        }

        let query = queryArg.replacingOccurrences(of: "--plan-search-query=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return nil
        }

        let categoryArg = args.first(where: { $0.hasPrefix("--plan-search-category=") })
        let category = categoryArg?
            .replacingOccurrences(of: "--plan-search-category=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return PlanSearchParams(category: (category?.isEmpty == false ? category! : "number"), query: query)
    }

    private static func parseForcedPlanViewMode(from args: [String]) -> PlanViewMode? {
        guard let arg = args.first(where: { $0.hasPrefix("--plan-view=") }) else {
            return nil
        }

        let raw = arg
            .replacingOccurrences(of: "--plan-view=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch raw {
        case "day", "dzien":
            return .day
        case "week", "tydzien":
            return .week
        case "month", "miesiac":
            return .month
        default:
            return nil
        }
    }
}
