import XCTest
@testable import mZUTCore

final class UsefulLinksRepositoryTests: XCTestCase {
    func testInformatykaLinksArePrioritized() {
        let repository = UsefulLinksRepository()
        let studies = [Study(przynaleznoscId: "1", label: "Informatyka - stacjonarne")]

        let links = repository.loadSortedLinks(studies: studies)

        XCTAssertFalse(links.isEmpty)
        XCTAssertEqual(links.first?.priorityWeight, 0)
        XCTAssertTrue(links.contains(where: { $0.highlight }))
    }
}

