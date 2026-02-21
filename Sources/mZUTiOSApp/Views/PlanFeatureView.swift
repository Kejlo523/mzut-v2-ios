import SwiftUI
import mZUTCore

struct PlanFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    private let initialSearch: PlanSearchParams?

    @State private var viewMode: PlanViewMode = .week
    @State private var currentDate = Date()
    @State private var result = PlanResult(viewMode: .week)
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var isSearchSheetPresented = false
    @State private var isFilterSheetPresented = false
    @State private var isAddEventSheetPresented = false

    @State private var searchCategory = "number"
    @State private var searchQuery = ""
    @State private var isSearchMode = false
    @State private var didRunInitialLoad = false

    @State private var availableFilters: [SubjectFilterItem] = []
    @State private var excludedFilterKeys = Set<String>()

    init(initialSearch: PlanSearchParams? = nil) {
        self.initialSearch = initialSearch
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(result.headerLabel.isEmpty ? "Plan zajec" : result.headerLabel)
                    .font(.title3.bold())

                Picker("Widok", selection: $viewMode) {
                    Text("Dzien").tag(PlanViewMode.day)
                    Text("Tydzien").tag(PlanViewMode.week)
                    Text("Miesiac").tag(PlanViewMode.month)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    Button {
                        moveToPrevious()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    Button("Dzis") {
                        currentDate = Date()
                        isSearchMode = false
                        Task {
                            await loadPlan(forceScopeRefresh: false)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        moveToNext()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                }

                if isLoading {
                    ProgressView("Ladowanie planu...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if viewMode == .month {
                    MonthGridView(grid: result.monthGrid, onSelect: { date in
                        currentDate = date
                        viewMode = .day
                    })
                } else {
                    ForEach(filteredDayColumns(), id: \.id) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day.date)
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            if day.events.isEmpty {
                                Text("Brak zajec")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 6)
                            } else {
                                ForEach(day.events) { event in
                                    PlanEventCard(event: event)
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isSearchSheetPresented = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }

                Button {
                    Task {
                        await openFilterSheet()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }

                Button {
                    Task {
                        await loadPlan(forceScopeRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }

                Button {
                    isAddEventSheetPresented = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .task {
            guard !didRunInitialLoad else {
                return
            }

            didRunInitialLoad = true

            if let initialSearch,
               !initialSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchCategory = initialSearch.category
                searchQuery = initialSearch.query
                await runSearch()
            } else {
                await loadPlan(forceScopeRefresh: false)
            }
        }
        .onChange(of: viewMode) { _ in
            isSearchMode = false
            Task {
                await loadPlan(forceScopeRefresh: false)
            }
        }
        .sheet(isPresented: $isSearchSheetPresented) {
            NavigationStack {
                PlanSearchSheet(
                    selectedCategory: $searchCategory,
                    query: $searchQuery,
                    onApply: {
                        isSearchSheetPresented = false
                        Task {
                            await runSearch()
                        }
                    },
                    onReset: {
                        isSearchSheetPresented = false
                        isSearchMode = false
                        searchQuery = ""
                        Task {
                            await loadPlan(forceScopeRefresh: false)
                        }
                    }
                )
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            NavigationStack {
                PlanFiltersSheet(
                    filters: availableFilters,
                    excluded: excludedFilterKeys,
                    onApply: { selected in
                        excludedFilterKeys = selected
                        isFilterSheetPresented = false
                    },
                    onReset: {
                        excludedFilterKeys = []
                        isFilterSheetPresented = false
                    }
                )
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isAddEventSheetPresented) {
            AddCustomEventSheet { event in
                appViewModel.dependencies.customPlanEventRepository.addEvent(event)
                Task {
                    await loadPlan(forceScopeRefresh: false)
                }
            }
        }
    }

    private func filteredDayColumns() -> [PlanDayColumn] {
        result.dayColumns.map { day in
            var copy = day
            if excludedFilterKeys.isEmpty {
                return copy
            }
            copy.events = day.events.filter { !excludedFilterKeys.contains($0.subjectKey) }
            return copy
        }
    }

    private func loadPlan(forceScopeRefresh: Bool) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        if appViewModel.isDemoContent {
            result = Self.makeDemoPlan(viewMode: viewMode, currentDate: currentDate)
            isLoading = false
            return
        }

        do {
            result = try await appViewModel.dependencies.planRepository.loadPlan(
                viewMode: viewMode,
                currentDate: currentDate,
                forceFullRefresh: false,
                forceScopeRefresh: forceScopeRefresh
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func runSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSearchMode = false
            await loadPlan(forceScopeRefresh: false)
            return
        }

        isLoading = true
        errorMessage = nil
        isSearchMode = true

        if appViewModel.isDemoContent {
            result = Self.makeDemoPlan(viewMode: viewMode, currentDate: currentDate)
            isLoading = false
            return
        }

        result = await appViewModel.dependencies.planRepository.searchPlan(
            viewMode: viewMode,
            currentDate: currentDate,
            search: PlanSearchParams(category: searchCategory, query: searchQuery)
        )
        isLoading = false
    }

    private func openFilterSheet() async {
        if appViewModel.isDemoContent {
            availableFilters = [
                SubjectFilterItem(label: "Algorytmy", typeKey: "lec", typeLabel: "Wyklad", filterKey: "Algorytmy||lec"),
                SubjectFilterItem(label: "Programowanie iOS", typeKey: "lab", typeLabel: "Laboratorium", filterKey: "Programowanie iOS||lab"),
                SubjectFilterItem(label: "Bazy danych", typeKey: "aud", typeLabel: "Audytoryjne", filterKey: "Bazy danych||aud")
            ]
            isFilterSheetPresented = true
            return
        }

        do {
            availableFilters = try await appViewModel.dependencies.planRepository.loadSubjectsForFilter(forceRefresh: false)
            isFilterSheetPresented = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveToPrevious() {
        switch viewMode {
        case .day:
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        case .week:
            currentDate = Calendar.current.date(byAdding: .day, value: -7, to: currentDate) ?? currentDate
        case .month:
            currentDate = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        }
        Task {
            await loadPlan(forceScopeRefresh: false)
        }
    }

    private func moveToNext() {
        switch viewMode {
        case .day:
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        case .week:
            currentDate = Calendar.current.date(byAdding: .day, value: 7, to: currentDate) ?? currentDate
        case .month:
            currentDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        Task {
            await loadPlan(forceScopeRefresh: false)
        }
    }

    private static func makeDemoPlan(viewMode: PlanViewMode, currentDate: Date) -> PlanResult {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: currentDate)
        let nextDay = formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate)

        let alg = PlanEventUi(
            startMin: 8 * 60,
            endMin: 9 * 60 + 30,
            topPx: 96,
            heightPx: 72,
            leftPct: 0,
            widthPct: 100,
            title: "Algorytmy (W)",
            room: "A-101",
            group: "1A",
            startStr: "08:00",
            endStr: "09:30",
            tooltip: "Algorytmy | 08:00 - 09:30 | sala: A-101",
            typeClass: "week-event-type-lecture",
            typeLabel: "Wyklad",
            subjectKey: "Algorytmy||lec",
            teacher: "dr J. Lewandowski"
        )

        let iosLab = PlanEventUi(
            startMin: 10 * 60,
            endMin: 11 * 60 + 30,
            topPx: 192,
            heightPx: 72,
            leftPct: 0,
            widthPct: 100,
            title: "Programowanie iOS (L)",
            room: "Lab-3",
            group: "2B",
            startStr: "10:00",
            endStr: "11:30",
            tooltip: "Programowanie iOS | 10:00 - 11:30 | sala: Lab-3",
            typeClass: "week-event-type-lab",
            typeLabel: "Laboratorium",
            subjectKey: "Programowanie iOS||lab",
            teacher: "mgr M. Kowalski"
        )

        let columns = [
            PlanDayColumn(date: day, events: [alg, iosLab]),
            PlanDayColumn(date: nextDay, events: [iosLab])
        ]

        var monthRow = Array<PlanMonthCell?>(repeating: nil, count: 7)
        monthRow[2] = PlanMonthCell(date: day, hasPlan: true)
        monthRow[3] = PlanMonthCell(date: nextDay, hasPlan: true)

        return PlanResult(
            viewMode: viewMode,
            currentDate: day,
            rangeStart: day,
            rangeEnd: nextDay,
            dayColumns: viewMode == .month ? [] : columns,
            hasAnyEventsInRange: true,
            monthGrid: viewMode == .month ? [monthRow] : [],
            prevDate: day,
            nextDate: nextDay,
            todayDate: day,
            headerLabel: viewMode == .month ? "Miesiac demo" : "Plan demo",
            debug: PlanDebug()
        )
    }
}

private struct PlanEventCard: View {
    let event: PlanEventUi

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(event.startStr) - \(event.endStr)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(event.typeLabel.isEmpty ? "Zajecia" : event.typeLabel)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(eventBadgeColor.opacity(0.2), in: Capsule())
                    .foregroundStyle(eventBadgeColor)
            }

            Text(event.title)
                .font(.headline)

            if !event.room.isEmpty || !event.group.isEmpty || !event.teacher.isEmpty {
                Text([event.room, event.group, event.teacher].filter { !$0.isEmpty }.joined(separator: " | "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(eventBadgeColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var eventBadgeColor: Color {
        let value = event.typeClass.lowercased()
        if value.contains("cancelled") { return .red }
        if value.contains("exam") { return .orange }
        if value.contains("lab") { return .green }
        if value.contains("auditory") { return .mint }
        return .blue
    }
}
