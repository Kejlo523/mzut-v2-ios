import XCTest
@testable import mZUTCore

final class UsefulLinksRepositoryTests: XCTestCase {
    func testInformatykaLinksArePrioritized() {
        let repository = UsefulLinksRepository()
        let studies = [Study(przynaleznoscId: "1", label: "Informatyka - stacjonarne")]

        let links = repository.loadSortedLinks(studies: studies)

        XCTAssertFalse(links.isEmpty)
        let minWeight = links.map(\.priorityWeight).min()
        XCTAssertNotNil(minWeight)
        XCTAssertEqual(links.first?.priorityWeight, minWeight)
        XCTAssertLessThanOrEqual(minWeight ?? 99, 1)
        XCTAssertTrue(links.contains(where: { $0.priorityWeight <= 1 && $0.highlight }))
    }
}
