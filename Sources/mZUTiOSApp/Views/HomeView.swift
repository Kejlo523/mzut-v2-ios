import SwiftUI
import mZUTCore

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Czesc, \(firstName(from: appViewModel.displayName))")
                            .font(.title.bold())
                            .foregroundStyle(.white)

                        Text("Port iOS mZUT v2 - warstwa core i glowne moduły")
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(appViewModel.tiles, id: \.id) { tile in
                            NavigationLink {
                                destination(for: tile)
                            } label: {
                                TileCardView(tile: tile)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dodatkowe moduly")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.92))

                        NavigationLink {
                            AttendanceFeatureView()
                        } label: {
                            quickLinkRow(title: "Obecnosci", subtitle: "Licznik nieobecnosci i godziny")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            UsefulLinksFeatureView()
                        } label: {
                            quickLinkRow(title: "Przydatne strony", subtitle: "Wybrane linki pod kierunek")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SettingsFeatureView()
                        } label: {
                            quickLinkRow(title: "Ustawienia", subtitle: "Motyw, jezyk, powiadomienia")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color.black, Color(red: 0.06, green: 0.09, blue: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("mZUT")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        appViewModel.restoreDefaultTiles()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Wyloguj") {
                        appViewModel.logout()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for tile: Tile) -> some View {
        switch tile.actionType {
        case .plan:
            PlanFeatureView()
        case .planSearch:
            PlanFeatureView(initialSearch: parsePlanSearch(tile.actionData))
        case .grades:
            GradesFeatureView()
        case .info:
            StudiesInfoFeatureView()
        case .news, .newsLatest:
            NewsFeatureView()
        case .url:
            URLFeatureView(urlString: tile.actionData ?? "")
        case .activity:
            activityDestination(for: tile)
        }
    }

    @ViewBuilder
    private func activityDestination(for tile: Tile) -> some View {
        let activityName = (tile.actionData ?? "").lowercased()
        if activityName.contains("attendanceactivity") {
            AttendanceFeatureView()
        } else if activityName.contains("usefullinksactivity") {
            UsefulLinksFeatureView()
        } else if activityName.contains("settingsactivity") {
            SettingsFeatureView()
        } else {
            GenericActivityPlaceholderView(title: tile.title)
        }
    }

    private func firstName(from raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        guard !clean.isEmpty else {
            return "Student"
        }

        return clean.components(separatedBy: " ").first ?? clean
    }

    private func quickLinkRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func parsePlanSearch(_ raw: String?) -> PlanSearchParams? {
        guard let raw,
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let category = (json["ck"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "number"
        let query = (json["q"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else {
            return nil
        }

        return PlanSearchParams(category: category, query: query)
    }
}
