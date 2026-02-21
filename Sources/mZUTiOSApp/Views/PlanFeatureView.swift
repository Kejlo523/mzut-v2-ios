import SwiftUI
import mZUTCore

struct PlanFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    private let initialSearch: PlanSearchParams?

    @State private var viewMode: PlanViewMode
    @State private var currentDate: Date
    @State private var result: PlanResult
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

    init(initialSearch: PlanSearchParams? = nil, initialViewMode: PlanViewMode? = nil) {
        self.initialSearch = initialSearch

        let selectedMode = initialViewMode ?? .week
        let today = Date()
        _viewMode = State(initialValue: selectedMode)
        _currentDate = State(initialValue: today)
        _result = State(initialValue: PlanResult(viewMode: selectedMode))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(result.headerLabel.isEmpty ? "Plan zajęć" : result.headerLabel)
                    .font(.title3.bold())

                if let searchStatusLabel {
                    Text(searchStatusLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker("Widok", selection: $viewMode) {
                    Text("Dzień").tag(PlanViewMode.day)
                    Text("Tydzień").tag(PlanViewMode.week)
                    Text("Miesiąc").tag(PlanViewMode.month)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    Button {
                        moveToPrevious()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    Button("Dziś") {
                        goToToday()
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
                    ProgressView("Ładowanie planu...")
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
                    PlanWeekCalendarView(dayColumns: filteredDayColumns())
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
                    refreshPlan()
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
            currentDate = initialDateForCurrentMode()

            if let initialSearch,
               !initialSearch.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchCategory = initialSearch.category
                searchQuery = initialSearch.query
                isSearchMode = true
            }

            await loadCurrentResult(forceScopeRefresh: false)
        }
        .onChange(of: viewMode) { _ in
            currentDate = alignedDateForCurrentMode(currentDate)
            Task {
                await loadCurrentResult(forceScopeRefresh: false)
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
                            await applySearch()
                        }
                    },
                    onReset: {
                        isSearchSheetPresented = false
                        Task {
                            await resetSearchAndReload()
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
                    await loadCurrentResult(forceScopeRefresh: false)
                }
            }
        }
    }

    private var searchStatusLabel: String? {
        guard let activeSearch else {
            return nil
        }
        return "Wyszukiwanie: \(searchCategoryLabel(activeSearch.category)) \(activeSearch.query)"
    }

    private var activeSearch: PlanSearchParams? {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearchMode, !query.isEmpty else {
            return nil
        }
        return PlanSearchParams(category: searchCategory, query: query)
    }

    private func loadCurrentResult(forceScopeRefresh: Bool) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        if let activeSearch {
            result = await appViewModel.dependencies.planRepository.searchPlan(
                viewMode: viewMode,
                currentDate: currentDate,
                search: activeSearch
            )
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
    }

    private func applySearch() async {
        let normalized = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            await resetSearchAndReload()
            return
        }

        searchQuery = normalized
        isSearchMode = true
        await loadCurrentResult(forceScopeRefresh: false)
    }

    private func resetSearchAndReload() async {
        searchQuery = ""
        isSearchMode = false
        await loadCurrentResult(forceScopeRefresh: false)
    }

    private func refreshPlan() {
        if isSearchMode {
            searchQuery = ""
            isSearchMode = false
        }

        Task {
            await loadCurrentResult(forceScopeRefresh: true)
        }
    }

    private func openFilterSheet() async {
        do {
            availableFilters = try await appViewModel.dependencies.planRepository.loadSubjectsForFilter(forceRefresh: false)
            isFilterSheetPresented = true
        } catch {
            errorMessage = error.localizedDescription
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
            await loadCurrentResult(forceScopeRefresh: false)
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
            await loadCurrentResult(forceScopeRefresh: false)
        }
    }

    private func goToToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if viewMode == .week,
           calendar.component(.weekday, from: today) == 1,
           let monday = calendar.date(byAdding: .day, value: 1, to: today) {
            currentDate = monday
        } else {
            currentDate = today
        }

        if viewMode == .month {
            currentDate = alignedDateForCurrentMode(currentDate)
        }

        Task {
            await loadCurrentResult(forceScopeRefresh: false)
        }
    }

    private func initialDateForCurrentMode() -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        if viewMode == .week,
           Calendar.current.component(.weekday, from: start) == 1,
           let monday = Calendar.current.date(byAdding: .day, value: 1, to: start) {
            return monday
        }

        return alignedDateForCurrentMode(start)
    }

    private func alignedDateForCurrentMode(_ date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)

        switch viewMode {
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: start)
            return calendar.date(from: comps).map { calendar.startOfDay(for: $0) } ?? start
        case .day, .week:
            return start
        }
    }

    private func searchCategoryLabel(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("teacher") || normalized.contains("wyk") {
            return "Wykładowca"
        }
        if normalized.contains("room") || normalized.contains("sal") {
            return "Sala"
        }
        if normalized.contains("group") || normalized.contains("grup") {
            return "Grupa"
        }
        if normalized.contains("subject") || normalized.contains("przedm") {
            return "Przedmiot"
        }
        return "Numer albumu"
    }
}
