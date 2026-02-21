import SwiftUI
import mZUTCore

struct MonthGridView: View {
    let grid: [[PlanMonthCell?]]
    let onSelect: (Date) -> Void

    private let dayHeaders = ["Pon", "Wt", "Sr", "Czw", "Pt", "Sob", "Nd"]
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
                            Button {
                                if let date = dateFormatter.date(from: cell.date) {
                                    onSelect(date)
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(dayNumber(from: cell.date))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Circle()
                                        .fill(cell.hasPlan ? Color.blue : Color.clear)
                                        .frame(width: 6, height: 6)
                                }
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
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
}

struct PlanSearchSheet: View {
    @Binding var selectedCategory: String
    @Binding var query: String
    let onApply: () -> Void
    let onReset: () -> Void

    private let categories: [(key: String, label: String)] = [
        ("number", "Numer albumu"),
        ("teacher", "Wykladowca"),
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
                TextField("Wpisz szukana fraze", text: $query)
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
                Text("Brak przedmiotow do filtrowania")
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
        .navigationTitle("Filtr przedmiotow")
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

