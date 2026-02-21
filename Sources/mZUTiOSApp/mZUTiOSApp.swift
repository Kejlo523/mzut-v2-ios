import SwiftUI

@main
struct MzutIOSApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if let forced = viewModel.forcedScreen {
                    forcedRoot(for: forced)
                } else if viewModel.isAuthenticated {
                    HomeView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(viewModel)
        }
    }

    @ViewBuilder
    private func forcedRoot(for screen: AppViewModel.AppScreen) -> some View {
        switch screen {
        case .login:
            LoginView()
        case .home:
            HomeView()
        case .plan:
            NavigationStack { PlanFeatureView(initialSearch: viewModel.forcedPlanSearch) }
        case .grades:
            NavigationStack { GradesFeatureView() }
        case .info:
            NavigationStack { StudiesInfoFeatureView() }
        case .news:
            NavigationStack { NewsFeatureView() }
        case .attendance:
            NavigationStack { AttendanceFeatureView() }
        case .links:
            NavigationStack { UsefulLinksFeatureView() }
        case .settings:
            NavigationStack { SettingsFeatureView() }
        }
    }
}
