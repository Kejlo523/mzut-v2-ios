import SwiftUI
import mZUTCore

struct GradesFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var studies: [Study] = []
    @State private var selectedStudyId = ""

    @State private var semesters: [Semester] = []
    @State private var selectedSemesterId: String = ""
    @State private var grades: [Grade] = []

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didRunInitialLoad = false
    @State private var expandedGroups = Set<String>()

    @State private var suppressStudyChange = false
    @State private var suppressSemesterChange = false

    private struct GradeGroup: Identifiable {
        let id: String
        let subject: String
        let finalGrade: Grade?
        let finalMissing: Bool
        let others: [Grade]
    }

    private struct GradeGroupBuilder {
        let subject: String
        var finalGrade: Grade?
        var others: [Grade]
    }

    var body: some View {
        List {
            if !studies.isEmpty {
                Section("Kierunek") {
                    Picker("Kierunek", selection: $selectedStudyId) {
                        ForEach(studies, id: \.id) { study in
                            Text(study.displayLabel).tag(Study.normalizeId(study.przynaleznoscId) ?? "")
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

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
                    ForEach(groupedGrades) { group in
                        gradeGroupRow(group)
                    }
                }
            }
        }
        .navigationTitle("Oceny")
        .task {
            guard !didRunInitialLoad else {
                return
            }
            didRunInitialLoad = true
            await loadInitialData()
        }
        .onChange(of: selectedStudyId) { _ in
            guard !suppressStudyChange else {
                return
            }
            Task {
                await loadForSelectedStudy()
            }
        }
        .onChange(of: selectedSemesterId) { _ in
            guard !suppressSemesterChange else {
                return
            }
            Task {
                await loadGradesForSelectedSemester()
            }
        }
    }

    private var groupedGrades: [GradeGroup] {
        buildGradeGroups(from: grades)
    }

    private func loadInitialData() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        suppressStudyChange = true
        suppressSemesterChange = true

        do {
            studies = try await appViewModel.dependencies.gradesRepository.loadStudies(forceRefresh: false)

            let initialStudyId = resolveInitialStudyId()
            selectedStudyId = initialStudyId
            setActiveStudyId(initialStudyId)

            semesters = try await appViewModel.dependencies.gradesRepository.loadSemesters(forceRefresh: false)
            let initialSemesterId = resolveInitialSemesterId()
            selectedSemesterId = initialSemesterId

            grades = try await loadGradesFor(semesterId: initialSemesterId)
            expandedGroups.removeAll()
            isLoading = false
            suppressStudyChange = false
            suppressSemesterChange = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            suppressStudyChange = false
            suppressSemesterChange = false
        }
    }

    private func loadForSelectedStudy() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        suppressSemesterChange = true

        do {
            setActiveStudyId(selectedStudyId)
            semesters = try await appViewModel.dependencies.gradesRepository.loadSemesters(forceRefresh: false)
            let nextSemesterId = resolveInitialSemesterId()
            selectedSemesterId = nextSemesterId
            grades = try await loadGradesFor(semesterId: nextSemesterId)
            expandedGroups.removeAll()
            isLoading = false
            suppressSemesterChange = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            suppressSemesterChange = false
        }
    }

    private func loadGradesForSelectedSemester() async {
        guard !selectedSemesterId.isEmpty else {
            grades = []
            expandedGroups.removeAll()
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            grades = try await loadGradesFor(semesterId: selectedSemesterId)
            expandedGroups.removeAll()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadGradesFor(semesterId: String) async throws -> [Grade] {
        guard let semester = semesters.first(where: { $0.id == semesterId }) else {
            return []
        }
        return try await appViewModel.dependencies.gradesRepository.loadGrades(for: semester)
    }

    private func resolveInitialStudyId() -> String {
        let activeFromSession = Study.normalizeId(appViewModel.dependencies.sessionStore.activeStudy?.przynaleznoscId) ?? ""
        if !activeFromSession.isEmpty,
           studies.contains(where: { Study.normalizeId($0.przynaleznoscId) == activeFromSession }) {
            return activeFromSession
        }
        return Study.normalizeId(studies.first?.przynaleznoscId) ?? ""
    }

    private func resolveInitialSemesterId() -> String {
        if semesters.contains(where: { $0.id == selectedSemesterId }) {
            return selectedSemesterId
        }
        return semesters.first?.id ?? ""
    }

    private func setActiveStudyId(_ studyId: String) {
        guard !studyId.isEmpty else {
            return
        }
        appViewModel.dependencies.sessionStore.setActiveStudyId(studyId)
        appViewModel.dependencies.sessionStore.saveToStorage()
    }

    private func buildGradeGroups(from source: [Grade]) -> [GradeGroup] {
        guard !source.isEmpty else {
            return []
        }

        var order: [String] = []
        var map: [String: GradeGroupBuilder] = [:]

        for grade in source {
            let subject = extractBaseSubject(grade.subjectName)
            guard !subject.isEmpty else {
                continue
            }

            if map[subject] == nil {
                order.append(subject)
                map[subject] = GradeGroupBuilder(subject: subject, finalGrade: nil, others: [])
            }

            if isFinalGrade(grade), map[subject]?.finalGrade == nil {
                map[subject]?.finalGrade = grade
            } else {
                map[subject]?.others.append(grade)
            }
        }

        return order.compactMap { key in
            guard let grouped = map[key] else {
                return nil
            }

            let finalValue = grouped.finalGrade?.grade.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let finalMissing = finalValue.isEmpty

            guard grouped.finalGrade != nil || !grouped.others.isEmpty else {
                return nil
            }

            return GradeGroup(
                id: key,
                subject: grouped.subject,
                finalGrade: grouped.finalGrade,
                finalMissing: finalMissing,
                others: grouped.others
            )
        }
    }

    private func gradeGroupRow(_ group: GradeGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                toggleGroup(group.id)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.subject)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(finalGradeSubtitle(for: group))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 10) {
                        Text(finalGradeValue(for: group))
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(gradeBadgeColor(for: finalGradeValue(for: group)), in: Capsule())
                            .foregroundStyle(gradeBadgeTextColor(for: finalGradeValue(for: group)))

                        Image(systemName: expandedGroups.contains(group.id) ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !group.others.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(group.others.prefix(4), id: \.id) { grade in
                            Text(displayGradeValue(grade.grade))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(gradeBadgeColor(for: grade.grade), in: Capsule())
                                .foregroundStyle(gradeBadgeTextColor(for: grade.grade))
                        }

                        if group.others.count > 4 {
                            Text("+\(group.others.count - 4)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if expandedGroups.contains(group.id) && !group.others.isEmpty {
                ForEach(group.others, id: \.id) { grade in
                    gradeDetailRow(grade)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func gradeDetailRow(_ grade: Grade) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(displayGradeValue(grade.grade))
                .font(.caption.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(gradeBadgeColor(for: grade.grade), in: Capsule())
                .foregroundStyle(gradeBadgeTextColor(for: grade.grade))

            VStack(alignment: .leading, spacing: 2) {
                if !displayGradeType(for: grade).isEmpty {
                    Text(displayGradeType(for: grade))
                        .font(.subheadline.weight(.semibold))
                }

                if !grade.date.isEmpty {
                    Text(grade.date)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !grade.teacher.isEmpty {
                    Text(grade.teacher)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func toggleGroup(_ id: String) {
        if expandedGroups.contains(id) {
            expandedGroups.remove(id)
        } else {
            expandedGroups.insert(id)
        }
    }

    private func finalGradeValue(for group: GradeGroup) -> String {
        guard !group.finalMissing, let final = group.finalGrade else {
            return "—"
        }
        return displayGradeValue(final.grade)
    }

    private func finalGradeSubtitle(for group: GradeGroup) -> String {
        var line = group.finalMissing ? "Brak oceny końcowej" : "Ocena końcowa"

        let ects = resolveGroupEcts(group)
        if ects > 0 {
            line += " • ECTS: \(String(format: "%.1f", ects))"
        }
        return line
    }

    private func resolveGroupEcts(_ group: GradeGroup) -> Double {
        var best = 0.0
        if let final = group.finalGrade {
            best = max(best, final.weight)
        }
        for grade in group.others {
            best = max(best, grade.weight)
        }
        return best
    }

    private func displayGradeValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func gradeBadgeColor(for raw: String) -> Color {
        switch gradeStyle(for: raw) {
        case .missing:
            return Color.secondary.opacity(0.18)
        case .fail:
            return Color.red.opacity(0.2)
        case .pass:
            return Color.green.opacity(0.22)
        case .neutral:
            return Color.blue.opacity(0.18)
        }
    }

    private func gradeBadgeTextColor(for raw: String) -> Color {
        switch gradeStyle(for: raw) {
        case .missing:
            return .secondary
        case .fail:
            return .red
        case .pass:
            return .green
        case .neutral:
            return .primary
        }
    }

    private enum GradeStyle {
        case missing
        case fail
        case pass
        case neutral
    }

    private func gradeStyle(for raw: String) -> GradeStyle {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .missing
        }

        let lower = trimmed.lowercased()
        if ["2", "2.0", "2,0", "nk", "nzal"].contains(lower) {
            return .fail
        }

        if lower == "zal" || lower == "z" {
            return .pass
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized) {
            if value <= 2.0 {
                return .fail
            }
            if value > 2.0 {
                return .pass
            }
        }

        return .neutral
    }

    private func displayGradeType(for grade: Grade) -> String {
        let raw = grade.type.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            return formatGradeType(raw)
        }

        let fromSubject = extractTypeFromSubject(grade.subjectName)
        if !fromSubject.isEmpty {
            return formatGradeType(fromSubject)
        }

        return ""
    }

    private func formatGradeType(_ value: String) -> String {
        let normalized = normalizeKey(value)
        if normalized.contains("wyklad") {
            return "Wykład"
        }
        if normalized.contains("laboratorium") {
            return "Laboratorium"
        }
        if normalized.contains("audytoryjne") {
            return "Audytoryjne"
        }
        if normalized.contains("egzamin") {
            return "Egzamin"
        }
        if normalized.contains("zaliczen") {
            return "Zaliczenie"
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isFinalGrade(_ grade: Grade) -> Bool {
        let type = normalizeKey(grade.type)
        if type.contains("ocena koncowa")
            || type.contains("koncowa")
            || type.contains("final")
            || type.contains("abschluss") {
            return true
        }

        if type.isEmpty {
            let subject = normalizeKey(grade.subjectName)
            return subject.contains("ocena koncowa")
                || subject.contains("koncowa")
                || subject.contains("final")
                || subject.contains("abschluss")
        }

        return false
    }

    private func extractBaseSubject(_ label: String) -> String {
        var name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return ""
        }

        if let range = name.range(of: " (", options: .backwards),
           name.hasSuffix(")") {
            name = String(name[..<range.lowerBound])
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTypeFromSubject(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: " (", options: .backwards),
              trimmed.hasSuffix(")") else {
            return ""
        }
        let value = String(trimmed[range.upperBound..<trimmed.index(before: trimmed.endIndex)])
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
    }
}

struct StudiesInfoFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var studies: [Study] = []
    @State private var selectedStudyId = ""
    @State private var details: StudyDetails?
    @State private var history: [StudyHistoryItem] = []

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didRunInitialLoad = false
    @State private var suppressStudyChange = false

    var body: some View {
        List {
            if !studies.isEmpty {
                Section("Kierunek") {
                    Picker("Kierunek", selection: $selectedStudyId) {
                        ForEach(studies, id: \.id) { study in
                            Text(study.displayLabel).tag(Study.normalizeId(study.przynaleznoscId) ?? "")
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

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
                    row("Wydział", details.wydzial)
                    row("Kierunek", details.kierunek)
                    row("Forma", details.forma)
                    row("Poziom", details.poziom)
                    row("Specjalność", details.specjalnosc)
                    row("Specjalizacja", details.specjalizacja)
                    row("Status", details.status)
                    row("Rok", details.rokAkademicki)
                    row("Semestr", details.semestrLabel)
                }
            }

            Section("Przebieg studiów") {
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
            guard !didRunInitialLoad else {
                return
            }
            didRunInitialLoad = true
            await loadInitialData()
        }
        .onChange(of: selectedStudyId) { _ in
            guard !suppressStudyChange else {
                return
            }
            Task {
                await loadForSelectedStudy()
            }
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

    private func loadInitialData() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        suppressStudyChange = true

        do {
            studies = try await appViewModel.dependencies.gradesRepository.loadStudies(forceRefresh: false)
            let initialStudyId = resolveInitialStudyId()
            selectedStudyId = initialStudyId
            setActiveStudyId(initialStudyId)

            async let detailsTask = appViewModel.dependencies.studiesInfoRepository.loadCurrentStudyDetails()
            async let historyTask = appViewModel.dependencies.studiesInfoRepository.loadStudyHistory()
            details = try await detailsTask
            history = try await historyTask
            isLoading = false
            suppressStudyChange = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            suppressStudyChange = false
        }
    }

    private func loadForSelectedStudy() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        setActiveStudyId(selectedStudyId)

        do {
            async let detailsTask = appViewModel.dependencies.studiesInfoRepository.loadCurrentStudyDetails()
            async let historyTask = appViewModel.dependencies.studiesInfoRepository.loadStudyHistory()
            details = try await detailsTask
            history = try await historyTask
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func resolveInitialStudyId() -> String {
        let activeFromSession = Study.normalizeId(appViewModel.dependencies.sessionStore.activeStudy?.przynaleznoscId) ?? ""
        if !activeFromSession.isEmpty,
           studies.contains(where: { Study.normalizeId($0.przynaleznoscId) == activeFromSession }) {
            return activeFromSession
        }
        return Study.normalizeId(studies.first?.przynaleznoscId) ?? ""
    }

    private func setActiveStudyId(_ studyId: String) {
        guard !studyId.isEmpty else {
            return
        }
        appViewModel.dependencies.sessionStore.setActiveStudyId(studyId)
        appViewModel.dependencies.sessionStore.saveToStorage()
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
            Text("Plan zajęć")
                .font(.title3.bold())
            Text("Port logiki planu z Androida jest w kolejce. Ten moduł jest gotowy na podpięcie repozytorium planu.")
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
                Text("Brak poprawnego adresu URL")
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
            Text("Docelowy ekran zostanie podpięty po migracji tego modułu.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .navigationTitle(title)
    }
}
