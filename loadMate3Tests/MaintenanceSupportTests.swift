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
