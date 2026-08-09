import SwiftData
import XCTest
@testable import loadMate3

@MainActor
final class MaintenanceSupportTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try LoadMateModelContainer.makePreview()
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testUpcomingReminderPrefersSoonestDueItem() {
        let vehicleID = UUID()
        let maintenance = MaintenanceRecord(vehicleID: vehicleID)
        maintenance.title = "Habitation service"
        maintenance.category = .annualHabitationService
        maintenance.reminderDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())

        let document = DocumentRecord(vehicleID: vehicleID)
        document.title = "Insurance"
        document.category = .insurance
        document.expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        let upcoming = MaintenanceSupport.upcomingReminder(
            maintenanceRecords: [maintenance],
            documents: [document]
        )

        XCTAssertEqual(upcoming?.title, "Habitation service")
        XCTAssertEqual(upcoming?.kind, .maintenance)
    }

    func testReminderItemsSuppressHabitationWhenWarrantyPlanExists() {
        let vehicleID = UUID()
        let plan = WarrantyPlan(vehicleID: vehicleID)
        plan.isUnderWarranty = true

        let event = WarrantyEvent(vehicleID: vehicleID)
        event.yearNumber = 3
        event.scheduledDate = Calendar.current.date(byAdding: .day, value: 40, to: Date())!
        event.daysBefore = 60
        event.daysAfter = 0
        event.serviceType = .serviceWithBodyCheck
        event.requirementDescription = "Annual habitation service"
        event.plan = plan
        plan.events = [event]

        let habitation = MaintenanceRecord(vehicleID: vehicleID)
        habitation.title = "Annual Habitation Service"
        habitation.category = .annualHabitationService
        habitation.reminderDate = Date()

        let tyre = MaintenanceRecord(vehicleID: vehicleID)
        tyre.title = "Tyre check"
        tyre.category = .tyres
        tyre.reminderDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())

        let items = MaintenanceSupport.reminderItems(
            maintenanceRecords: [habitation, tyre],
            documents: [],
            warrantyPlans: [plan],
            vehicleID: vehicleID,
            warrantyAvailable: true
        )

        XCTAssertFalse(items.contains(where: { $0.kind == .maintenance && $0.title == "Annual Habitation Service" }))
        XCTAssertTrue(items.contains(where: { $0.kind == .maintenance && $0.title == "Tyre check" }))
        XCTAssertTrue(items.contains(where: { $0.kind == .warrantyEvent }))
    }

    func testHistoryEntriesIncludeFaultRaisedAndResolved() {
        let vehicleID = UUID()
        let fault = FaultRecord(vehicleID: vehicleID)
        fault.title = "Fridge fault"
        fault.details = "Ignition stops after lighting"
        fault.severity = .medium
        fault.status = .completed
        fault.discoveredDate = Date(timeIntervalSince1970: 1_000)
        fault.resolvedDate = Date(timeIntervalSince1970: 2_000)

        let entries = MaintenanceSupport.historyEntries(
            maintenanceRecords: [],
            documents: [],
            faults: [fault]
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains(where: { $0.subtitle == "Fault raised" }))
        XCTAssertTrue(entries.contains(where: { $0.subtitle == "Fault repaired" }))
    }

    func testHistoryEntriesIncludeWarrantyPurchaseAndEvents() {
        let vehicleID = UUID()
        let plan = WarrantyPlan(vehicleID: vehicleID)
        plan.manufacturer = "Swift"
        plan.purchaseDate = Date(timeIntervalSince1970: 500)

        let event = WarrantyEvent(vehicleID: vehicleID)
        event.yearNumber = 1
        event.scheduledDate = Date(timeIntervalSince1970: 3_000)
        event.completedDate = Date(timeIntervalSince1970: 2_900)
        event.serviceType = .normalService
        event.requirementDescription = "Annual service"
        event.plan = plan
        plan.events = [event]

        let entries = MaintenanceSupport.historyEntries(
            maintenanceRecords: [],
            documents: [],
            faults: [],
            warrantyPlans: [plan],
            ascending: true
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.kind, .warrantyPurchase)
        XCTAssertEqual(entries.last?.kind, .warranty)
        XCTAssertEqual(entries.last?.title, event.displayTitle)
    }

    func testFilteredHistoryEntriesCanIsolateWarranty() {
        let vehicleID = UUID()
        let maintenance = MaintenanceRecord(vehicleID: vehicleID)
        maintenance.title = "Habitation service"
        maintenance.serviceDate = Date(timeIntervalSince1970: 1_000)

        let plan = WarrantyPlan(vehicleID: vehicleID)
        plan.purchaseDate = Date(timeIntervalSince1970: 500)

        let entries = MaintenanceSupport.filteredHistoryEntries(
            maintenanceRecords: [maintenance],
            documents: [],
            faults: [],
            warrantyPlans: [plan],
            filter: .warranty,
            searchText: ""
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.kind, .warrantyPurchase)
    }
}
