import XCTest
@testable import mZUTCore

final class AttendanceRepositoryTests: XCTestCase {
    func testLoadSubjectsWithStoredValues() {
        let store = InMemoryStore()
        let repository = AttendanceRepository(store: store)

        repository.saveHours(subjectKey: "Algorytmy||lec", hours: 30)
        repository.saveAbsence(subjectKey: "Algorytmy||lec", absenceCount: 2)

        let merged = repository.loadSubjectsWithAbsences(
            subjects: [
                Absence(subjectName: "Algorytmy", subjectType: "Wyklad", subjectKey: "Algorytmy||lec", absenceCount: 0, totalHours: 0)
            ]
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].totalHours, 30)
        XCTAssertEqual(merged[0].absenceCount, 2)
    }

    func testCalculateOverallAttendance() {
        let repository = AttendanceRepository(store: InMemoryStore())
        let value = repository.calculateOverallAttendance(
            [
                Absence(subjectName: "A", subjectType: "W", subjectKey: "a", absenceCount: 2, totalHours: 20),
                Absence(subjectName: "B", subjectType: "L", subjectKey: "b", absenceCount: 3, totalHours: 30)
            ]
        )

        XCTAssertEqual(value, 90.0, accuracy: 0.001)
    }
}

