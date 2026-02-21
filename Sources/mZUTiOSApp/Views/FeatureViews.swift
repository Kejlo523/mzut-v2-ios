import SwiftUI
import mZUTCore

struct GradesFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var semesters: [Semester] = []
    @State private var selectedSemesterId: String = ""
    @State private var grades: [Grade] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if !semesters.isEmpty {
                Section("Semestr") {
                    Picker("Semestr", selection: $selectedSemesterId) {
                        ForEach(semesters, id: \.id) { semester in
                            Text(semester.label).tag(semester.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if isLoading {
                Section {
                    ProgressView("Pobieranie ocen...")
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            } else if grades.isEmpty {
                Section {
                    Text("Brak ocen dla wybranego semestru")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Oceny") {
                    ForEach(grades, id: \.id) { grade in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(grade.subjectName)
                                .font(.headline)

                            Text("Ocena: \(grade.grade)")
                                .font(.subheadline)

                            Text("ECTS: \(grade.weight, specifier: "%.1f") | \(grade.date)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Oceny")
        .task {
            await loadSemestersAndGrades()
        }
        .onChange(of: selectedSemesterId) { _ in
            Task {
                await loadGradesForSelectedSemester()
            }
        }
    }

    private func loadSemestersAndGrades() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedSemesters = try await appViewModel.dependencies.gradesRepository.loadSemesters()
            semesters = fetchedSemesters
            selectedSemesterId = fetchedSemesters.first?.id ?? ""
            isLoading = false
            await loadGradesForSelectedSemester()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadGradesForSelectedSemester() async {
        guard !selectedSemesterId.isEmpty else {
            grades = []
            return
        }

        guard let semester = semesters.first(where: { $0.id == selectedSemesterId }) else {
            grades = []
            return
        }

        isLoading = true
        do {
            grades = try await appViewModel.dependencies.gradesRepository.loadGrades(for: semester)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct StudiesInfoFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var details: StudyDetails?
    @State private var history: [StudyHistoryItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView("Pobieranie danych o studiach...")
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if let details {
                Section("Aktualne studia") {
                    row("Album", details.album)
                    row("Wydzial", details.wydzial)
                    row("Kierunek", details.kierunek)
                    row("Forma", details.forma)
                    row("Poziom", details.poziom)
                    row("Specjalnosc", details.specjalnosc)
                    row("Specjalizacja", details.specjalizacja)
                    row("Status", details.status)
                    row("Rok", details.rokAkademicki)
                    row("Semestr", details.semestrLabel)
                }
            }

            Section("Przebieg studiow") {
                if history.isEmpty {
                    Text("Brak danych")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label)
                                .font(.headline)
                            Text(item.status)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Informacje")
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func loadData() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            details = try await appViewModel.dependencies.studiesInfoRepository.loadCurrentStudyDetails()
            history = try await appViewModel.dependencies.studiesInfoRepository.loadStudyHistory()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct NewsFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var items: [NewsItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sourceInfo = "Źródło RSS: studenci ZUT"

    var body: some View {
        List {
            if isLoading {
                ProgressView("Pobieranie aktualności...")
            }

            if let errorMessage {
                Text("Błąd pobierania RSS: \(errorMessage)")
                    .foregroundStyle(.red)
            }

            Section {
                Text(sourceInfo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty && !isLoading {
                Text("Brak aktualności lub problem z pobraniem kanału RSS.")
                    .foregroundStyle(.secondary)
            }

            ForEach(items) { item in
                NavigationLink {
                    NewsDetailView(item: item)
                } label: {
                    NewsRowView(item: item)
                }
            }
        }
        .navigationTitle("Aktualności")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Odśwież") {
                    Task {
                        await loadNews(forceRefresh: true)
                    }
                }
            }
        }
        .task {
            await loadNews(forceRefresh: false)
        }
    }

    private func loadNews(forceRefresh: Bool) async {
        guard !isLoading else {
            return
        }

        let repository = appViewModel.dependencies.newsRepository
        if !forceRefresh {
            let cached = repository.cachedNews()
            if !cached.isEmpty {
                items = cached
            }
            refreshSourceInfo()
            if !repository.shouldFetchFromNetwork() {
                return
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            items = try await repository.loadNews(forceRefresh: forceRefresh)
            refreshSourceInfo()
            isLoading = false
        } catch {
            refreshSourceInfo()
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func refreshSourceInfo() {
        let base = "Źródło RSS: studenci ZUT"
        guard let timestamp = appViewModel.dependencies.newsRepository.cacheTimestamp() else {
            sourceInfo = base
            return
        }
        sourceInfo = "\(base) • \(relativeTime(from: timestamp))"
    }

    private func relativeTime(from date: Date) -> String {
        if abs(Date().timeIntervalSince(date)) < 60 {
            return "przed chwilą"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct NewsDetailView: View {
    let item: NewsItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.title3.bold())
                Text(item.date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(newsBodyText)
                    .font(.body)
                if let url = URL(string: item.link), !item.link.isEmpty {
                    Link("Otwórz artykuł", destination: url)
                }
            }
            .padding(16)
        }
        .navigationTitle("Wpis")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var newsBodyText: String {
        if let content = htmlToText(item.contentHtml), !content.isEmpty {
            return content
        }
        return item.descriptionText.isEmpty ? item.snippet : item.descriptionText
    }

    private func htmlToText(_ html: String) -> String? {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return nil
        }

        guard let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) else {
            return nil
        }

        let text = attributed.string
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

private struct NewsRowView: View {
    let item: NewsItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(3)
                Text(item.date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(item.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let imageURL = imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
                .frame(width: 90, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.vertical, 4)
    }

    private var imageURL: URL? {
        guard !item.thumbUrl.isEmpty else {
            return nil
        }
        return URL(string: item.thumbUrl)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                Image(systemName: "newspaper")
                    .foregroundStyle(.secondary)
            )
    }
}

struct PlanPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 44))
                .foregroundStyle(.cyan)
            Text("Plan zajec")
                .font(.title3.bold())
            Text("Port logiki planu z Androida jest w kolejce. Ten moduł jest gotowy na podpiecie repozytorium planu.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .navigationTitle("Plan")
    }
}

struct URLFeatureView: View {
    let urlString: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Link z kafelka")
                .font(.headline)

            if let url = URL(string: urlString), !urlString.isEmpty {
                Link(url.absoluteString, destination: url)
                    .multilineTextAlignment(.center)
            } else {
                Text("Brak poprawnego URL")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .navigationTitle("Link")
    }
}

struct GenericActivityPlaceholderView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title3.bold())
            Text("Docelowy ekran zostanie podpiety po migracji tego modułu.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .navigationTitle(title)
    }
}
