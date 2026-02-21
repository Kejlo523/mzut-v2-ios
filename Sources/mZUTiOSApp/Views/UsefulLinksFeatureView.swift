import SwiftUI
import mZUTCore

struct UsefulLinksFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var links: [UsefulLink] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView("Ładowanie linków...")
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if links.isEmpty && !isLoading {
                Text("Brak zdefiniowanych linków")
                    .foregroundStyle(.secondary)
            }

            ForEach(links) { link in
                Link(destination: URL(string: link.url) ?? URL(string: "https://www.zut.edu.pl")!) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(domain(for: link.url))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if link.highlight {
                                Text("Polecane")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2), in: Capsule())
                                    .foregroundStyle(.blue)
                            }
                        }

                        Text(link.title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(link.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Przydatne strony")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await loadLinks(forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await loadLinks(forceRefresh: false)
        }
    }

    private func loadLinks(forceRefresh: Bool) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let studies = try await appViewModel.dependencies.gradesRepository.loadStudies(forceRefresh: forceRefresh)
            links = appViewModel.dependencies.usefulLinksRepository.loadSortedLinks(studies: studies)
        } catch {
            errorMessage = error.localizedDescription
            links = appViewModel.dependencies.usefulLinksRepository.loadSortedLinks(studies: [])
        }

        isLoading = false
    }

    private func domain(for raw: String) -> String {
        guard let host = URL(string: raw)?.host else {
            return raw
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
