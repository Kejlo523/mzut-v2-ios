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
                    headerCard

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
                        Text("Dodatkowe moduły")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.92))

                        NavigationLink {
                            AttendanceFeatureView()
                        } label: {
                            quickLinkRow(
                                icon: "person.3.fill",
                                title: "Obecności",
                                subtitle: "Licznik nieobecności i godzin"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            UsefulLinksFeatureView()
                        } label: {
                            quickLinkRow(
                                icon: "link.circle.fill",
                                title: "Przydatne strony",
                                subtitle: "Wybrane linki pod kierunek"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SettingsFeatureView()
                        } label: {
                            quickLinkRow(
                                icon: "gearshape.fill",
                                title: "Ustawienia",
                                subtitle: "Motyw, język, powiadomienia"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(backgroundLayer)
            .navigationTitle("mzutv2")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appViewModel.restoreDefaultTiles()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("mzutv2")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))

            Text("Cześć, \(firstName(from: appViewModel.displayName))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Szybki dostęp do planu, ocen i informacji o studiach.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            if let studyLabel = activeStudyLabel {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap.fill")
                        .font(.footnote)
                    Text(studyLabel)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12), in: Capsule())
                .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.2, blue: 0.35),
                            Color(red: 0.06, green: 0.1, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.04, green: 0.08, blue: 0.14)],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 130, y: -200)

            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: -140, y: 340)
        }
        .ignoresSafeArea()
    }

    private var activeStudyLabel: String? {
        let active = appViewModel.dependencies.sessionStore.activeStudy
        let label = active?.displayLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? nil : label
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

    private func quickLinkRow(icon: String, title: String, subtitle: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
