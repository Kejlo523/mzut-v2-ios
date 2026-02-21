import SwiftUI
import mZUTCore

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
