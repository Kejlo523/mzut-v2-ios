import Foundation

public final class AttendanceRepository {
    private enum Keys {
        static let absencesData = "absences_json"
        static let hoursData = "hours_json"
    }

    private let store: KeyValueStore
    private let planRepository: PlanRepository?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        planRepository: PlanRepository? = nil,
        store: KeyValueStore = UserDefaultsStore(suiteName: "attendance_prefs")
    ) {
        self.planRepository = planRepository
        self.store = store
    }

    public func loadSubjectsWithAbsences(forceRefresh: Bool = false) async -> [Absence] {
        guard let planRepository else {
            return loadSubjectsWithAbsences(subjects: [])
        }

        let subjectFilters: [SubjectFilterItem]
        do {
            subjectFilters = try await planRepository.loadSubjectsForFilter(forceRefresh: forceRefresh)
        } catch {
            subjectFilters = []
        }

        let baseSubjects = subjectFilters.map { item in
            Absence(
                subjectName: item.label,
                subjectType: item.typeLabel,
                subjectKey: item.filterKey,
                absenceCount: 0,
                totalHours: 0
            )
        }
        return loadSubjectsWithAbsences(subjects: baseSubjects)
    }

    public func loadSavedHours() -> [String: Int] {
        guard let data = store.data(forKey: Keys.hoursData),
              let decoded = try? decoder.decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }

    public func saveHours(subjectKey: String, hours: Int) {
        var hoursMap = loadSavedHours()
        hoursMap[subjectKey] = max(0, hours)
        store.set(try? encoder.encode(hoursMap), forKey: Keys.hoursData)
    }

    public func loadSavedAbsences() -> [String: Int] {
        guard let data = store.data(forKey: Keys.absencesData),
              let decoded = try? decoder.decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }

    public func saveAbsence(subjectKey: String, absenceCount: Int) {
        var absences = loadSavedAbsences()
        absences[subjectKey] = max(0, absenceCount)
        store.set(try? encoder.encode(absences), forKey: Keys.absencesData)
    }

    public func loadSubjectsWithAbsences(subjects: [Absence]) -> [Absence] {
        let hours = loadSavedHours()
        let absences = loadSavedAbsences()

        return subjects.map { subject in
            var merged = subject
            merged.totalHours = hours[subject.subjectKey] ?? subject.totalHours
            merged.absenceCount = absences[subject.subjectKey] ?? subject.absenceCount
            return merged
        }
    }

    public func calculateOverallAttendance(_ absences: [Absence]) -> Double {
        let totalHours = absences.reduce(0) { $0 + max(0, $1.totalHours) }
        let totalAbsences = absences.reduce(0) { $0 + max(0, $1.absenceCount) }

        guard totalHours > 0 else {
            return 100
        }

        let attended = max(0, totalHours - totalAbsences)
        return (Double(attended) / Double(totalHours)) * 100
    }
}
