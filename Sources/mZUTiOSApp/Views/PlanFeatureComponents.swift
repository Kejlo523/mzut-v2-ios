import SwiftUI
import mZUTCore

struct PlanWeekCalendarView: View {
    let dayColumns: [PlanDayColumn]
    let anchorDate: Date
    let showFullWeek: Bool

    private let timelineStartHour = 6
    private let timelineEndHour = 22
    private let hourHeight: CGFloat = 44
    private let hourColumnWidth: CGFloat = 36

    private static let ymdParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let ymdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EE\n dd.MM"
        return formatter
    }()

    private var normalizedColumns: [PlanDayColumn] {
        guard showFullWeek else {
            return dayColumns
        }

        let parsed = dayColumns.compactMap { column -> (String, Date, [PlanEventUi])? in
            guard let date = Self.ymdParser.date(from: column.date) else {
                return nil
            }
            return (column.date, date, column.events)
        }

        let monday = startOfWeekMonday(from: parsed.map { $0.1 }.min() ?? anchorDate)
        let map = Dictionary(uniqueKeysWithValues: dayColumns.map { ($0.date, $0.events) })

        return (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: monday) else {
                return nil
            }
            let key = Self.ymdFormatter.string(from: date)
            return PlanDayColumn(date: key, events: map[key] ?? [])
        }
    }

    var body: some View {
        let columns = normalizedColumns
        if columns.isEmpty {
            Text("Brak zajęć")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        } else {
            GeometryReader { proxy in
                let dayCount = max(columns.count, 1)
                let timelineHeight = CGFloat(timelineEndHour - timelineStartHour) * hourHeight
                let availableWidth = max(120, proxy.size.width - hourColumnWidth)
                let dayColumnWidth = max(36, availableWidth / CGFloat(dayCount))

                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: hourColumnWidth, height: 42)

                        ForEach(columns) { column in
                            Text(headerLabel(for: column.date))
                                .font(dayColumnWidth < 45 ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(width: dayColumnWidth, height: 42)
                        }
                    }

                    ScrollView(.vertical) {
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                ForEach(timelineStartHour...timelineEndHour, id: \.self) { hour in
                                    Text(String(format: "%02d:00", hour))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(
                                            width: hourColumnWidth - 4,
                                            height: hour == timelineEndHour ? 0 : hourHeight,
                                            alignment: .topTrailing
                                        )
                                        .padding(.trailing, 4)
                                }
                            }

                            ForEach(columns) { day in
                                PlanTimelineDayColumn(
                                    day: day,
                                    startHour: timelineStartHour,
                                    endHour: timelineEndHour,
                                    hourHeight: hourHeight
                                )
                                .frame(width: dayColumnWidth, height: timelineHeight)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 560)
        }
    }

    private func headerLabel(for ymd: String) -> String {
        guard let date = Self.ymdParser.date(from: ymd) else {
            return ymd
        }
        return Self.dayHeaderFormatter.string(from: date).capitalized
    }

    private func startOfWeekMonday(from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2

        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
    }
}

private struct PlanTimelineDayColumn: View {
    let day: PlanDayColumn
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(.secondarySystemBackground).opacity(0.35))

            VStack(spacing: 0) {
                ForEach(startHour..<endHour, id: \.self) { _ in
                    Rectangle()
                        .stroke(Color(.separator).opacity(0.22), lineWidth: 0.5)
                        .frame(height: hourHeight)
                }
            }

            ForEach(day.events) { event in
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let top = max(0, min(CGFloat(event.topPx), geo.size.height - 18))
                    let height = max(18, min(CGFloat(event.heightPx), geo.size.height - top))

                    let leftRatio = max(0, min(CGFloat(event.leftPct) / 100, 1))
                    let widthRatio = max(0.1, min(CGFloat(event.widthPct) / 100, 1))
                    let eventLeft = leftRatio * totalWidth
                    let eventWidth = max(16, min(totalWidth - eventLeft, (widthRatio * totalWidth) - 2))
                    let compact = totalWidth < 62

                    PlanTimelineEventView(event: event, compact: compact)
                        .frame(width: eventWidth, height: height)
                        .position(x: eventLeft + (eventWidth / 2), y: top + (height / 2))
                }
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color(.separator).opacity(0.22), lineWidth: 0.6)
        )
    }
}

private struct PlanTimelineEventView: View {
    let event: PlanEventUi
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            Text("\(event.startStr)-\(event.endStr)")
                .font(compact ? .system(size: 7, weight: .semibold) : .caption2.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Text(compact ? compactTitle : event.title)
                .font(compact ? .system(size: 8, weight: .semibold) : .caption.weight(.semibold))
                .lineLimit(compact ? 1 : 2)

            if !compact, !event.room.isEmpty {
                Text(event.room)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 3 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: compact ? 5 : 8, style: .continuous)
                .fill(eventBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 5 : 8, style: .continuous)
                .stroke(eventBorder, lineWidth: 1)
        )
    }

    private var compactTitle: String {
        let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Zajęcia"
        }
        let firstWord = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return String(firstWord.prefix(10))
    }

    private var eventBackground: Color {
        eventAccent.opacity(0.22)
    }

    private var eventBorder: Color {
        eventAccent.opacity(0.56)
    }

    private var eventAccent: Color {
        let value = event.typeClass.lowercased()
        if value.contains("cancelled") { return .red }
        if value.contains("exam") { return .orange }
        if value.contains("lab") { return .green }
        if value.contains("auditory") { return .mint }
        return .blue
    }
}

struct MonthGridView: View {
    let grid: [[PlanMonthCell?]]
    let onSelect: (Date) -> Void

    private let dayHeaders = ["Pon", "Wt", "Śr", "Czw", "Pt", "Sob", "Nd"]
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(dayHeaders, id: \.self) { header in
                    Text(header)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(grid.enumerated()), id: \.offset) { _, row in
                HStack {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        if let cell {
                            if cell.hasPlan {
                                Button {
                                    if let date = dateFormatter.date(from: cell.date) {
                                        onSelect(date)
                                    }
                                } label: {
                                    monthCell(for: cell)
                                }
                                .buttonStyle(.plain)
                            } else {
                                monthCell(for: cell)
                            }
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                    }
                }
            }
        }
    }

    private func dayNumber(from ymd: String) -> String {
        guard let date = dateFormatter.date(from: ymd) else {
            return "-"
        }
        let day = Calendar.current.component(.day, from: date)
        return String(day)
    }

    @ViewBuilder
    private func monthCell(for cell: PlanMonthCell) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dayNumber(from: cell.date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if cell.hasPlan {
                Text("Zajęcia")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cell.hasPlan ? Color.blue.opacity(0.16) : Color(.secondarySystemBackground))
        )
    }
}

struct PlanSearchSheet: View {
    @Binding var selectedCategory: String
    @Binding var query: String
    let onApply: () -> Void
    let onReset: () -> Void

    private let categories: [(key: String, label: String)] = [
        ("number", "Numer albumu"),
        ("teacher", "Wykładowca"),
        ("room", "Sala"),
        ("subject", "Przedmiot"),
        ("group", "Grupa")
    ]

    var body: some View {
        Form {
            Section("Kategoria") {
                Picker("Kategoria", selection: $selectedCategory) {
                    ForEach(categories, id: \.key) { item in
                        Text(item.label).tag(item.key)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Fraza") {
                TextField("Wpisz szukaną frazę", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button("Szukaj") {
                    onApply()
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Reset") {
                    onReset()
                }
            }
        }
        .navigationTitle("Wyszukaj")
    }
}

struct PlanFiltersSheet: View {
    let filters: [SubjectFilterItem]
    let excluded: Set<String>
    let onApply: (Set<String>) -> Void
    let onReset: () -> Void

    @State private var workingSelection = Set<String>()

    var body: some View {
        List {
            if filters.isEmpty {
                Text("Brak przedmiotów do filtrowania")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filters, id: \.id) { item in
                    Toggle(isOn: binding(for: item.filterKey)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                            Text(item.typeLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
            }
        }
        .navigationTitle("Filtr przedmiotów")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Reset") {
                    onReset()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Zastosuj") {
                    onApply(workingSelection)
                }
            }
        }
        .onAppear {
            workingSelection = excluded
        }
    }

    private func binding(for key: String) -> Binding<Bool> {
        Binding(
            get: { workingSelection.contains(key) },
            set: { isExcluded in
                if isExcluded {
                    workingSelection.insert(key)
                } else {
                    workingSelection.remove(key)
                }
            }
        )
    }
}

struct AddCustomEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var subjectName = ""
    @State private var eventType: CustomPlanEvent.EventType = .test
    @State private var date = Date()
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .minute, value: 90, to: Date()) ?? Date()
    @State private var notes = ""

    let onSave: (CustomPlanEvent) -> Void

    private let ymdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let hmFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Przedmiot") {
                    TextField("Nazwa przedmiotu", text: $subjectName)
                }

                Section("Typ") {
                    Picker("Typ wydarzenia", selection: $eventType) {
                        Text("Egzamin").tag(CustomPlanEvent.EventType.exam)
                        Text("Zaliczenie").tag(CustomPlanEvent.EventType.pass)
                        Text("Kolokwium").tag(CustomPlanEvent.EventType.test)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Termin") {
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Koniec", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section("Notatki") {
                    TextField("Dodatkowe informacje", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Dodaj wydarzenie")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zapisz") {
                        onSave(
                            CustomPlanEvent(
                                subjectName: subjectName.trimmingCharacters(in: .whitespacesAndNewlines),
                                eventType: eventType,
                                date: ymdFormatter.string(from: date),
                                startTime: hmFormatter.string(from: startTime),
                                endTime: hmFormatter.string(from: endTime),
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                isAutoTime: false
                            )
                        )
                        dismiss()
                    }
                    .disabled(subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}