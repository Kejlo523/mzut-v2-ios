import SwiftUI
import mZUTCore

struct PlanWeekCalendarView: View {
    let dayColumns: [PlanDayColumn]

    private let timelineStartHour = 6
    private let timelineEndHour = 22
    private let hourHeight: CGFloat = 48
    private let hourColumnWidth: CGFloat = 56
    private let dayColumnWidth: CGFloat = 160

    private static let ymdParser: DateFormatter = {
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

    var body: some View {
        if dayColumns.isEmpty {
            Text("Brak zajęć")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        } else {
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: hourColumnWidth, height: 44)

                        ForEach(dayColumns) { column in
                            Text(headerLabel(for: column.date))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(width: dayColumnWidth, height: 44)
                        }
                    }

                    ScrollView(.vertical) {
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                ForEach(timelineStartHour...timelineEndHour, id: \.self) { hour in
                                    Text(String(format: "%02d:00", hour))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: hourColumnWidth - 8, height: hour == timelineEndHour ? 0 : hourHeight, alignment: .topTrailing)
                                        .padding(.trailing, 8)
                                }
                            }

                            ForEach(dayColumns) { day in
                                PlanTimelineDayColumn(
                                    day: day,
                                    startHour: timelineStartHour,
                                    endHour: timelineEndHour,
                                    hourHeight: hourHeight
                                )
                                .frame(width: dayColumnWidth, height: CGFloat(timelineEndHour - timelineStartHour) * hourHeight)
                            }
                        }
                    }
                    .frame(height: 520)
                }
            }
        }
    }

    private func headerLabel(for ymd: String) -> String {
        guard let date = Self.ymdParser.date(from: ymd) else {
            return ymd
        }
        return Self.dayHeaderFormatter.string(from: date).capitalized
    }
}

private struct PlanTimelineDayColumn: View {
    let day: PlanDayColumn
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(.secondarySystemBackground).opacity(0.35))

            VStack(spacing: 0) {
                ForEach(startHour..<endHour, id: \.self) { _ in
                    Rectangle()
                        .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
                        .frame(height: hourHeight)
                }
            }

            ForEach(day.events) { event in
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let top = max(0, min(CGFloat(event.topPx), geo.size.height - 22))
                    let height = max(22, min(CGFloat(event.heightPx), geo.size.height - top))

                    let leftRatio = max(0, min(CGFloat(event.leftPct) / 100, 1))
                    let widthRatio = max(0.1, min(CGFloat(event.widthPct) / 100, 1))
                    let eventLeft = leftRatio * totalWidth
                    let eventWidth = max(28, min(totalWidth - eventLeft, (widthRatio * totalWidth) - 4))

                    PlanTimelineEventView(event: event)
                        .frame(width: eventWidth, height: height)
                        .position(x: eventLeft + (eventWidth / 2), y: top + (height / 2))
                }
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color(.separator).opacity(0.25), lineWidth: 0.7)
        )
    }
}

private struct PlanTimelineEventView: View {
    let event: PlanEventUi

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(event.startStr)-\(event.endStr)")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Text(event.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)

            if !event.room.isEmpty {
                Text(event.room)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(eventBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(eventBorder, lineWidth: 1)
        )
    }

    private var eventBackground: Color {
        eventAccent.opacity(0.2)
    }

    private var eventBorder: Color {
        eventAccent.opacity(0.55)
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
