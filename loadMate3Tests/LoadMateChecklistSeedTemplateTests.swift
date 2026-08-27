import SwiftData
import XCTest
@testable import loadMate3

@MainActor
final class LoadMateChecklistSeedTemplateTests: XCTestCase {
    func testTemplateHasFiveSectionsAndSixtyEightItems() {
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections.count, 5)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.totalItemCount, 68)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[0].title, "Before leaving home")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[0].itemCount, 14)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[1].title, "Towing setup")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[1].itemCount, 9)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[2].title, "Pitching")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[2].itemCount, 10)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[3].title, "Departure")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[3].itemCount, 12)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[4].title, "EU / Overseas travel checklist")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections[4].itemCount, 23)
    }

    func testInsertSectionCreatesGroupBackedItemsAndSkipsDuplicates() throws {
        let context = try makeContext()

        let first = LoadMateChecklistSeedTemplate.insertSection(at: 0, in: context)
        XCTAssertEqual(
            first,
            .inserted(title: "Before leaving home", groups: 4, items: 14)
        )

        let sections = try context.fetch(FetchDescriptor<ChecklistSection>())
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistGroup>()).count, 4)
        let items = try context.fetch(FetchDescriptor<ChecklistItem>())
        XCTAssertEqual(items.count, 14)
        XCTAssertTrue(items.allSatisfy { $0.group != nil })
        XCTAssertTrue(items.allSatisfy { $0.section == nil })
        XCTAssertTrue(items.allSatisfy { $0.isChecked == false })

        let skipped = LoadMateChecklistSeedTemplate.insertSection(at: 0, in: context)
        XCTAssertEqual(skipped, .skippedAlreadyExists(title: "Before leaving home"))
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistSection>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistItem>()).count, 14)
    }

    func testInsertSectionDoesNotSetDidSeedDefaultChecklist() throws {
        let context = try makeContext()
        let state = AppState()
        context.insert(state)

        _ = LoadMateChecklistSeedTemplate.insertSection(at: 1, in: context)

        XCTAssertFalse(state.didSeedDefaultChecklist)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistSection>()).first?.title, "Towing setup")
    }

    func testInsertAllCreatesEveryFactorySection() throws {
        let context = try makeContext()
        let created = LoadMateChecklistSeedTemplate.insertAll(in: context)

        XCTAssertEqual(created.sections, 5)
        XCTAssertEqual(created.items, 68)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistSection>()).count, 5)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistItem>()).count, 68)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            ChecklistSection.self,
            ChecklistGroup.self,
            ChecklistItem.self,
            AppState.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
}
