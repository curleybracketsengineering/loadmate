import SwiftData
import XCTest
@testable import loadMate3

@MainActor
final class LoadMateChecklistSeedTemplateTests: XCTestCase {
    func testCaravanTemplateHasFiveSectionsAndSeventyFiveItems() {
        XCTAssertEqual(LoadMateChecklistSeedTemplate.caravanSections.count, 5)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.totalItemCount, 75)
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[0].title, "Before leaving home")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[1].title, "Towing setup")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[2].title, "Pitching")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[3].title, "Departure")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[4].title, "EU / Overseas travel checklist")
        XCTAssertEqual(LoadMateChecklistSeedTemplate.sections(for: .caravan)[0].groups.last?.title, "Tow car")
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
        XCTAssertEqual(LoadMateChecklistSeedTemplate.motorhomeItemCount, 20 + 9 + 10 + 23)
    }

    func testMotorhomeTemplateUsesVehicleChecksInsteadOfTrailerGear() {
        let items = LoadMateChecklistSeedTemplate.itemTitles(for: .motorhome)
        XCTAssertTrue(items.contains("Engine oil level"))
        XCTAssertTrue(items.contains("Coolant / water level"))
        XCTAssertTrue(items.contains("Brake fluid level"))
        XCTAssertTrue(items.contains("Tyre pressures checked"))
        XCTAssertTrue(items.contains("Fuel and AdBlue levels"))
        XCTAssertTrue(items.contains("Wheels chocked"))
        XCTAssertFalse(items.contains("Jockey wheel raised and clamped"))
        XCTAssertFalse(items.contains("Corner steadies fully raised"))
        XCTAssertFalse(items.contains("Engage motor mover"))
        XCTAssertFalse(items.contains("Hitch security checks complete"))

        let caravanItems = LoadMateChecklistSeedTemplate.itemTitles(for: .caravan)
        XCTAssertTrue(caravanItems.contains("Jockey wheel raised and clamped"))
        XCTAssertTrue(caravanItems.contains("Engine oil level"))
        XCTAssertTrue(caravanItems.contains("Brake fluid level"))
        XCTAssertFalse(caravanItems.contains("External lockers locked"))
        XCTAssertFalse(caravanItems.contains("Engine off"))
        XCTAssertFalse(caravanItems.contains("Awning and aerial retracted"))
    }

    func testInsertSectionCreatesGroupBackedItemsAndSkipsDuplicatesOnThatVehicle() throws {
        let context = try makeContext()
        let caravan = VehicleProfile(name: "Van", kind: .caravan, sortOrder: 0)
        context.insert(caravan)

        let first = LoadMateChecklistSeedTemplate.insertSection(at: 0, onto: caravan, in: context)
        XCTAssertEqual(
            first,
            .inserted(title: "Before leaving home", groups: 5, items: 21)
        )

        let sections = try context.fetch(FetchDescriptor<ChecklistSection>())
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.profile?.id, caravan.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistGroup>()).count, 5)
        let items = try context.fetch(FetchDescriptor<ChecklistItem>())
        XCTAssertEqual(items.count, 21)
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

        XCTAssertEqual(second, .inserted(title: "Before leaving home", groups: 5, items: 21))
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
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistItem>()).count, 75)
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
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistItem>()).count, 62)
        XCTAssertTrue((try context.fetch(FetchDescriptor<ChecklistItem>())).contains { $0.title == "Engine oil level" })
        XCTAssertTrue((try context.fetch(FetchDescriptor<ChecklistItem>())).contains { $0.title == "Brake fluid level" })
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
        let vehicle = ChecklistGroup(title: "Vehicle", sortOrder: 1, section: section)
        context.insert(vehicle)
        context.insert(ChecklistItem(title: "Coolant level", isChecked: true, sortOrder: 0, group: vehicle))
        context.insert(ChecklistItem(title: "Engine oil level", isChecked: false, sortOrder: 1, group: vehicle))

        let towing = ChecklistSection(title: "Towing setup", sortOrder: 1, profile: motorhome)
        context.insert(towing)
        let hitch = ChecklistGroup(title: "Hitch & safety", sortOrder: 0, section: towing)
        context.insert(hitch)
        context.insert(ChecklistItem(title: "Coupling locked on tow ball", isChecked: false, sortOrder: 0, group: hitch))

        let pitching = ChecklistSection(title: "Pitching", sortOrder: 2, profile: motorhome)
        context.insert(pitching)
        let onSite = ChecklistGroup(title: "On site", sortOrder: 0, section: pitching)
        context.insert(onSite)
        context.insert(ChecklistItem(title: "Handbrake applied", isChecked: false, sortOrder: 0, group: onSite))

        let caravanSection = ChecklistSection(title: "Before leaving home", sortOrder: 0, profile: caravan)
        context.insert(caravanSection)
        let caravanExterior = ChecklistGroup(title: "Exterior & chassis", sortOrder: 0, section: caravanSection)
        context.insert(caravanExterior)
        context.insert(ChecklistItem(title: "Jockey wheel raised and clamped", isChecked: false, sortOrder: 0, group: caravanExterior))

        ChecklistVehicleMigration.patchMotorhomeFactoryItemsIfNeeded(in: context, profiles: [motorhome, caravan])

        let motorhomeSectionTitles = Set(motorhome.checklistSectionsList.map(\.title))
        XCTAssertFalse(motorhomeSectionTitles.contains("Towing setup"))
        XCTAssertFalse(motorhomeSectionTitles.contains("Pitching"))
        XCTAssertTrue(motorhomeSectionTitles.contains("On site"))

        let motorhomeGroupTitles = Set(motorhome.checklistSectionsList.flatMap(\.groupsList).map(\.title))
        XCTAssertTrue(motorhomeGroupTitles.contains("Exterior"))
        XCTAssertFalse(motorhomeGroupTitles.contains("Exterior & chassis"))
        XCTAssertFalse(motorhomeGroupTitles.contains("Hitch & safety"))

        let motorhomeTitles = Set(motorhome.checklistSectionsList.flatMap(\.groupsList).flatMap(\.itemsList).map(\.title))
        XCTAssertFalse(motorhomeTitles.contains("Jockey wheel raised and clamped"))
        XCTAssertFalse(motorhomeTitles.contains("Coupling locked on tow ball"))
        XCTAssertTrue(motorhomeTitles.contains("Steps folded and secured"))
        XCTAssertTrue(motorhomeTitles.contains("Engine oil level"))
        XCTAssertTrue(motorhomeTitles.contains("Coolant / water level"))
        XCTAssertFalse(motorhomeTitles.contains("Coolant level"))
        XCTAssertTrue(motorhomeTitles.contains("Brake fluid level"))
        XCTAssertEqual(
            motorhome.checklistSectionsList
                .flatMap(\.groupsList)
                .flatMap(\.itemsList)
                .first { $0.title == "Coolant / water level" }?
                .isChecked,
            true
        )

        let caravanTitles = Set(caravan.checklistSectionsList.flatMap(\.groupsList).flatMap(\.itemsList).map(\.title))
        XCTAssertEqual(caravanTitles, ["Jockey wheel raised and clamped"])

        XCTAssertFalse(ChecklistVehicleMigration.patchMotorhomeFactoryItems(on: motorhome, in: context))
    }

    func testPatchAddsTowCarChecksAndRemovesMotorhomeItemsOnExistingCaravan() throws {
        let context = try makeContext()
        let caravan = VehicleProfile(name: "My Caravan", kind: .caravan, sortOrder: 0)
        let motorhome = VehicleProfile(name: "My Motorhome", kind: .motorhome, sortOrder: 1)
        context.insert(caravan)
        context.insert(motorhome)

        let section = ChecklistSection(title: "Before leaving home", sortOrder: 0, profile: caravan)
        context.insert(section)
        let exterior = ChecklistGroup(title: "Exterior & chassis", sortOrder: 0, section: section)
        context.insert(exterior)
        context.insert(ChecklistItem(title: "Jockey wheel raised and clamped", isChecked: false, sortOrder: 0, group: exterior))
        context.insert(ChecklistItem(title: "External lockers locked", isChecked: false, sortOrder: 1, group: exterior))
        context.insert(ChecklistItem(title: "Engine off", isChecked: false, sortOrder: 2, group: exterior))

        let motorhomeSection = ChecklistSection(title: "Before leaving home", sortOrder: 0, profile: motorhome)
        context.insert(motorhomeSection)
        let motorhomeExterior = ChecklistGroup(title: "Exterior", sortOrder: 0, section: motorhomeSection)
        context.insert(motorhomeExterior)
        context.insert(ChecklistItem(title: "External lockers locked", isChecked: false, sortOrder: 0, group: motorhomeExterior))
        context.insert(ChecklistItem(title: "Engine off", isChecked: false, sortOrder: 1, group: motorhomeExterior))

        ChecklistVehicleMigration.patchCaravanFactoryItemsIfNeeded(in: context, profiles: [caravan, motorhome])

        let caravanGroupTitles = Set(caravan.checklistSectionsList.flatMap(\.groupsList).map(\.title))
        XCTAssertTrue(caravanGroupTitles.contains("Tow car"))
        XCTAssertTrue(caravanGroupTitles.contains("Exterior & chassis"))
        XCTAssertFalse(caravanGroupTitles.contains("Vehicle"))

        let caravanTitles = Set(caravan.checklistSectionsList.flatMap(\.groupsList).flatMap(\.itemsList).map(\.title))
        XCTAssertTrue(caravanTitles.contains("Jockey wheel raised and clamped"))
        XCTAssertTrue(caravanTitles.contains("Engine oil level"))
        XCTAssertTrue(caravanTitles.contains("Coolant / water level"))
        XCTAssertTrue(caravanTitles.contains("Brake fluid level"))
        XCTAssertFalse(caravanTitles.contains("External lockers locked"))
        XCTAssertFalse(caravanTitles.contains("Engine off"))

        let motorhomeTitles = Set(motorhome.checklistSectionsList.flatMap(\.groupsList).flatMap(\.itemsList).map(\.title))
        XCTAssertEqual(motorhomeTitles, ["External lockers locked", "Engine off"])

        XCTAssertFalse(ChecklistVehicleMigration.patchCaravanFactoryItems(on: caravan, in: context))
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
