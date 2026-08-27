import SwiftData
import XCTest
@testable import loadMate3

@MainActor
final class LoadMateChecklistSeedTemplateTests: XCTestCase {
    func testCaravanTemplateHasFiveSectionsAndSixtyEightItems() {
        XCTAssertEqual(LoadMateChecklistSeedTemplate.caravanSections.count, 5)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.totalItemCount, 68)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[0].title, "Before leaving home")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[1].title, "Towing setup")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[2].title, "Pitching")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[3].title, "Departure")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[4].title, "EU / Overseas travel checklist")
    }

    func testMotorhomeTemplateOmitsTowingAndPitching() {
        let titles = LoadMateChecklistSeedTemplate.sections(for: .motorhome).map(\.title)
        XCTAssertEqual(titles, [
            "Before leaving home",
            "On site",
            "Departure",
            "EU / Overseas travel checklist",
        ])
        XCTAssertFalse(titles.contains("Towing setup"))
        XCTAssertFalse(titles.contains("Pitching"))
        XCTAssertEqual(LoadMateChecklistSeedTemplate.motorhomeItemCount, 19 + 8 + 10 + 23)
    }

    func testMotorhomeTemplateUsesVehicleChecksInsteadOfTrailerGear() {
        let items = LoadMateChecklistSeedTemplate.itemTitles(for: .motorhome)
        XCTAssertTrue(items.contains("Engine oil level"))
        XCTAssertTrue(items.contains("Coolant level"))
        XCTAssertTrue(items.contains("Tyre pressures checked"))
        XCTAssertTrue(items.contains("Fuel and AdBlue levels"))
        XCTAssertFalse(items.contains("Jockey wheel raised and clamped"))
        XCTAssertFalse(items.contains("Corner steadies fully raised"))
        XCTAssertFalse(items.contains("Engage motor mover"))
        XCTAssertFalse(items.contains("Hitch security checks complete"))

        let caravanItems = LoadMateChecklistSeedTemplate.itemTitles(for: .caravan)
        XCTAssertTrue(caravanItems.contains("Jockey wheel raised and clamped"))
        XCTAssertFalse(caravanItems.contains("Engine oil level"))
    }

    func testInsertSectionCreatesGroupBackedItemsAndSkipsDuplicatesOnThatVehicle() throws {
        let context = try makeContext()
        let caravan = VehicleProfile(name: "Van", kind: .caravan, sortOrder: 0)
        context.insert(caravan)

        let first = LoadMateChecklistSeedTemplate.insertSection(at: 0, onto: caravan, in: context)
        XCTAssertEqual(
            first,
            .inserted(title: "Before leaving home", groups: 4, items: 14)
        )

        let sections = try context.fetch(FetchDescriptor<ChecklistSection>())
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.profile?.id, caravan.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistGroup>()).count, 4)
        let items = try context.fetch(FetchDescriptor<ChecklistItem>())
        XCTAssertEqual(items.count, 14)
        XCTAssertTrue(items.allSatisfy { $0.group != nil })
        XCTAssertTrue(items.allSatisfy { $0.section == nil })
        XCTAssertTrue(items.allSatisfy { $0.isChecked == false })

        let skipped = LoadMateChecklistSeedTemplate.insertSection(at: 0, onto: caravan, in: context)
        XCTAssertEqual(skipped, .skippedAlreadyExists(title: "Before leaving home"))
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistSection>()).count, 1)
    }

    func testInsertSectionAllowsSameTitleOnADifferentVehicle() throws {
        let context = try makeContext()
        let caravan = VehicleProfile(name: "Van", kind: .caravan, sortOrder: 0)
        let other = VehicleProfile(name: "Van 2", kind: .caravan, sortOrder: 1)
        context.insert(caravan)
        context.insert(other)

        _ = LoadMateChecklistSeedTemplate.insertSection(at: 0, onto: caravan, in: context)
        let second = LoadMateChecklistSeedTemplate.insertSection(at: 0, onto: other, in: context)

        XCTAssertEqual(second, .inserted(title: "Before leaving home", groups: 4, items: 14))
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistSection>()).count, 2)
    }

    func testInsertSectionDoesNotSetDidSeedDefaultChecklist() throws {
        let context = try makeContext()
        let state = AppState()
        context.insert(state)
        let caravan = VehicleProfile(name: "Van", kind: .caravan, sortOrder: 0)
        context.insert(caravan)

        _ = LoadMateChecklistSeedTemplate.insertSection(at: 1, onto: caravan, in: context)

        XCTAssertFalse(state.didSeedDefaultChecklist)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistSection>()).first?.title, "Towing setup")
    }

    func testAddCaravanProfileSeedsFiveSections() throws {
        let context = try makeContext()
        let state = AppState()
        context.insert(state)

        let profile = VehicleProfileStore.addProfile(
            name: "New van",
            kind: .caravan,
            profiles: [],
            appState: state,
            in: context
        )

        let sections = profile.checklistSectionsList
        XCTAssertEqual(sections.count, 5)
        XCTAssertTrue(sections.allSatisfy { $0.profile?.id == profile.id })
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistItem>()).count, 68)
        XCTAssertTrue((try context.fetch(FetchDescriptor<ChecklistItem>())).allSatisfy { $0.group != nil })
    }

    func testAddMotorhomeProfileSeedsFourSections() throws {
        let context = try makeContext()
        let state = AppState()
        context.insert(state)

        let profile = VehicleProfileStore.addProfile(
            name: "New MH",
            kind: .motorhome,
            profiles: [],
            appState: state,
            in: context
        )

        let titles = Set(profile.checklistSectionsList.map(\.title))
        XCTAssertEqual(profile.checklistSectionsList.count, 4)
        XCTAssertEqual(titles, [
            "Before leaving home",
            "On site",
            "Departure",
            "EU / Overseas travel checklist",
        ])
        XCTAssertFalse(titles.contains("Towing setup"))
        XCTAssertFalse(titles.contains("Pitching"))
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistItem>()).count, 60)
        XCTAssertTrue((try context.fetch(FetchDescriptor<ChecklistItem>())).contains { $0.title == "Engine oil level" })
        XCTAssertFalse((try context.fetch(FetchDescriptor<ChecklistItem>())).contains { $0.title == "Jockey wheel raised and clamped" })
    }

    func testPatchRemovesTrailerItemsAndAddsVehicleChecksOnExistingMotorhome() throws {
        let context = try makeContext()
        let motorhome = VehicleProfile(name: "My Motorhome", kind: .motorhome, sortOrder: 0)
        let caravan = VehicleProfile(name: "My Caravan", kind: .caravan, sortOrder: 1)
        context.insert(motorhome)
        context.insert(caravan)

        let section = ChecklistSection(title: "Before leaving home", sortOrder: 0, profile: motorhome)
        context.insert(section)
        let exterior = ChecklistGroup(title: "Exterior & chassis", sortOrder: 0, section: section)
        context.insert(exterior)
        context.insert(ChecklistItem(title: "Jockey wheel raised and clamped", isChecked: true, sortOrder: 0, group: exterior))
        context.insert(ChecklistItem(title: "Steps folded and secured", isChecked: false, sortOrder: 1, group: exterior))

        let caravanSection = ChecklistSection(title: "Before leaving home", sortOrder: 0, profile: caravan)
        context.insert(caravanSection)
        let caravanExterior = ChecklistGroup(title: "Exterior & chassis", sortOrder: 0, section: caravanSection)
        context.insert(caravanExterior)
        context.insert(ChecklistItem(title: "Jockey wheel raised and clamped", isChecked: false, sortOrder: 0, group: caravanExterior))

        ChecklistVehicleMigration.patchMotorhomeFactoryItemsIfNeeded(in: context, profiles: [motorhome, caravan])

        let motorhomeTitles = Set(motorhome.checklistSectionsList.flatMap(\.groupsList).flatMap(\.itemsList).map(\.title))
        XCTAssertFalse(motorhomeTitles.contains("Jockey wheel raised and clamped"))
        XCTAssertTrue(motorhomeTitles.contains("Steps folded and secured"))
        XCTAssertTrue(motorhomeTitles.contains("Engine oil level"))
        XCTAssertTrue(motorhomeTitles.contains("Coolant level"))

        let caravanTitles = Set(caravan.checklistSectionsList.flatMap(\.groupsList).flatMap(\.itemsList).map(\.title))
        XCTAssertEqual(caravanTitles, ["Jockey wheel raised and clamped"])

        XCTAssertFalse(ChecklistVehicleMigration.patchMotorhomeFactoryItems(on: motorhome, in: context))
    }

    func testDeleteProfileRemovesOnlyThatVehicleChecklist() throws {
        let context = try makeContext()
        let state = AppState()
        context.insert(state)

        let keep = VehicleProfileStore.addProfile(
            name: "Keep",
            kind: .caravan,
            profiles: [],
            appState: state,
            in: context
        )
        let remove = VehicleProfileStore.addProfile(
            name: "Remove",
            kind: .motorhome,
            profiles: [keep],
            appState: state,
            in: context
        )

        VehicleProfileStore.deleteProfile(remove, profiles: [keep, remove], appState: state, in: context)

        let remaining = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(Set(remaining.map(\.id)), [keep.id])
        XCTAssertEqual(keep.checklistSectionsList.count, 5)
        let allSections = try context.fetch(FetchDescriptor<ChecklistSection>())
        XCTAssertTrue(allSections.allSatisfy { $0.profile?.id == keep.id })
    }

    func testMigrationCopiesUnscopedChecklistOntoEveryVehicle() throws {
        let context = try makeContext()
        let state = AppState()
        context.insert(state)

        let unscoped = ChecklistSection(title: "Section 1", sortOrder: 0)
        context.insert(unscoped)
        let group = ChecklistGroup(title: "Sub 1", sortOrder: 0, section: unscoped)
        context.insert(group)
        context.insert(ChecklistItem(title: "Item 1", isChecked: true, sortOrder: 0, group: group))
        context.insert(ChecklistItem(title: "Item 2", isChecked: false, sortOrder: 1, group: group))

        let caravan = VehicleProfile(name: "My Caravan", kind: .caravan, sortOrder: 0)
        let motorhome = VehicleProfile(name: "My Motorhome", kind: .motorhome, sortOrder: 1)
        context.insert(caravan)
        context.insert(motorhome)

        ChecklistVehicleMigration.migrateIfNeeded(
            in: context,
            appState: state,
            profiles: [caravan, motorhome]
        )

        XCTAssertTrue(state.didMigrateChecklistsToVehicles)
        XCTAssertEqual(caravan.checklistSectionsList.count, 1)
        XCTAssertEqual(motorhome.checklistSectionsList.count, 1)
        XCTAssertEqual(caravan.checklistSectionsList.first?.title, "Section 1")
        XCTAssertNotEqual(caravan.checklistSectionsList.first?.id, motorhome.checklistSectionsList.first?.id)

        let caravanItems = caravan.checklistSectionsList.first?.groupsList.first?.itemsList ?? []
        XCTAssertEqual(Set(caravanItems.map(\.title)), ["Item 1", "Item 2"])
        XCTAssertEqual(caravanItems.first { $0.title == "Item 1" }?.isChecked, true)

        let leftoverUnscoped = try context.fetch(FetchDescriptor<ChecklistSection>()).filter { $0.profile == nil }
        XCTAssertTrue(leftoverUnscoped.isEmpty)
    }

    func testMigrationDoesNotCopyOntoVehicleThatAlreadyHasSections() throws {
        let context = try makeContext()
        let state = AppState()
        context.insert(state)

        let unscoped = ChecklistSection(title: "Shared", sortOrder: 0)
        context.insert(unscoped)

        let caravan = VehicleProfile(name: "Van", kind: .caravan, sortOrder: 0)
        context.insert(caravan)
        _ = LoadMateChecklistSeedTemplate.insertAll(onto: caravan, in: context)

        ChecklistVehicleMigration.migrateIfNeeded(in: context, appState: state, profiles: [caravan])

        XCTAssertEqual(caravan.checklistSectionsList.count, 5)
        XCTAssertFalse(caravan.checklistSectionsList.contains { $0.title == "Shared" })
        XCTAssertTrue(try context.fetch(FetchDescriptor<ChecklistSection>()).filter { $0.profile == nil }.isEmpty)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            VehicleProfile.self,
            Trip.self,
            LoadedItem.self,
            LibraryItem.self,
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
