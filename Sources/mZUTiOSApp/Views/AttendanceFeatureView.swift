import SwiftUI
import mZUTCore

struct AttendanceFeatureView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var absences: [Absence] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var editingHoursSubject: Absence?
    @State private var editingHoursValue = ""

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lacznie nieobecnosci")
                            .font(.headline)
                        Text(summarySubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(totalAbsences)")
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
            }

            if isLoading {
                Section {
                    ProgressView("Ladowanie listy przedmiotow...")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if !isLoading && absences.isEmpty {
                Section {
                    Text("Brak przedmiotow w planie")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(Array(absences.enumerated()), id: \.element.id) { index, item in
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.subjectName)
                                    .font(.headline)
                                Text(item.subjectType.isEmpty ? "Typ zajec" : item.subjectType)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 10) {
                                Button {
                                    decrementAbsence(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)

                                Text("\(item.absenceCount)")
                                    .font(.title3.bold())
                                    .monospacedDigit()
                                    .frame(minWidth: 34)

                                Button {
                                    incrementAbsence(at: index)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(.blue)
                        }

                        HStack {
                            Text("Godzin: \(item.totalHours)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Edytuj godziny") {
                                editingHoursSubject = item
                                editingHoursValue = "\(item.totalHours)"
                            }
                            .font(.footnote.weight(.medium))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Obecnosci")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await loadSubjects(forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await loadSubjects(forceRefresh: false)
        }
        .sheet(item: $editingHoursSubject) { subject in
            NavigationStack {
                Form {
                    Section("Przedmiot") {
                        Text(subject.subjectName)
                    }

                    Section("Laczna liczba godzin") {
                        TextField("Godziny", text: $editingHoursValue)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("Edytuj godziny")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Anuluj") {
                            editingHoursSubject = nil
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Zapisz") {
                            saveHours(for: subject)
                            editingHoursSubject = nil
                        }
                    }
                }
            }
        }
    }

    private var totalAbsences: Int {
        absences.reduce(0) { $0 + max(0, $1.absenceCount) }
    }

    private var summarySubtitle: String {
        switch totalAbsences {
        case 0:
            return "Brak nieobecnosci"
        case 1:
            return "1 nieobecnosc"
        default:
            return "\(totalAbsences) nieobecnosci"
        }
    }

    private func loadSubjects(forceRefresh: Bool) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        if appViewModel.isDemoContent {
            let demo = [
                Absence(subjectName: "Algorytmy", subjectType: "Wyklad", subjectKey: "Algorytmy||lec", absenceCount: 1, totalHours: 30),
                Absence(subjectName: "Programowanie iOS", subjectType: "Laboratorium", subjectKey: "Programowanie iOS||lab", absenceCount: 0, totalHours: 45),
                Absence(subjectName: "Bazy danych", subjectType: "Audytoryjne", subjectKey: "Bazy danych||aud", absenceCount: 2, totalHours: 30)
            ]
            absences = appViewModel.dependencies.attendanceRepository.loadSubjectsWithAbsences(subjects: demo)
            isLoading = false
            return
        }

        absences = await appViewModel.dependencies.attendanceRepository.loadSubjectsWithAbsences(forceRefresh: forceRefresh)
        isLoading = false
    }

    private func incrementAbsence(at index: Int) {
        guard absences.indices.contains(index) else {
            return
        }

        absences[index].absenceCount += 1
        appViewModel.dependencies.attendanceRepository.saveAbsence(
            subjectKey: absences[index].subjectKey,
            absenceCount: absences[index].absenceCount
        )
    }

    private func decrementAbsence(at index: Int) {
        guard absences.indices.contains(index) else {
            return
        }

        absences[index].absenceCount = max(0, absences[index].absenceCount - 1)
        appViewModel.dependencies.attendanceRepository.saveAbsence(
            subjectKey: absences[index].subjectKey,
            absenceCount: absences[index].absenceCount
        )
    }

    private func saveHours(for subject: Absence) {
        guard let value = Int(editingHoursValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        guard let index = absences.firstIndex(where: { $0.subjectKey == subject.subjectKey }) else {
            return
        }

        absences[index].totalHours = max(0, value)
        appViewModel.dependencies.attendanceRepository.saveHours(
            subjectKey: absences[index].subjectKey,
            hours: absences[index].totalHours
        )
    }
}

