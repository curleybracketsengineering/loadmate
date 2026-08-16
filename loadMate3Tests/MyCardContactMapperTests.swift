import Contacts
import SwiftData
import XCTest
@testable import loadMate3

final class MyCardContactMapperTests: XCTestCase {
    func testMapsNameAddressAndMobilePhone() {
        let contact = CNMutableContact()
        contact.givenName = "Ada"
        contact.familyName = "Lovelace"

        let address = CNMutablePostalAddress()
        address.street = "12 Acacia Avenue"
        address.city = "Bristol"
        address.postalCode = "BS1 1AA"
        address.country = "United Kingdom"
        contact.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: address)]
        contact.phoneNumbers = [
            CNLabeledValue(
                label: CNLabelPhoneNumberMobile,
                value: CNPhoneNumber(stringValue: "07700 900123")
            )
        ]

        let details = MyCardContactMapper.details(from: contact)
        XCTAssertEqual(details.name, "Ada Lovelace")
        XCTAssertTrue(details.address.contains("12 Acacia Avenue"))
        XCTAssertTrue(details.address.contains("Bristol"))
        XCTAssertTrue(details.address.contains("BS1 1AA"))
        XCTAssertEqual(details.phone, "07700 900123")
        XCTAssertFalse(details.isEmpty)
    }

    func testPrefersMobileOverOtherPhoneNumbers() {
        let contact = CNMutableContact()
        contact.givenName = "Test"
        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: "0117 000000")),
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "07700 900999"))
        ]

        let details = MyCardContactMapper.details(from: contact)
        XCTAssertEqual(details.phone, "07700 900999")
    }

    func testEmptyContactIsEmpty() {
        let details = MyCardContactMapper.details(from: CNMutableContact())
        XCTAssertTrue(details.isEmpty)
    }
}

@MainActor
final class AccidentOwnDetailsTests: XCTestCase {
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

    func testNewIncidentHasEmptyOwnDetails() {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        XCTAssertEqual(record.ownName, "")
        XCTAssertEqual(record.ownAddress, "")
        XCTAssertEqual(record.ownPhone, "")
    }

    func testOwnDetailsPersistOnIncidentOnly() throws {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        record.ownName = "Ada Lovelace"
        record.ownAddress = "12 Acacia Avenue\nBristol\nBS1 1AA"
        record.ownPhone = "07700 900123"
        AccidentStore.save(record, in: context)

        let fetched = try context.fetch(FetchDescriptor<AccidentRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.ownName, "Ada Lovelace")
        XCTAssertEqual(fetched.first?.ownPhone, "07700 900123")
        XCTAssertTrue(fetched.first?.ownAddress.contains("Bristol") == true)
    }

    func testSharePackIncludesIncidentOwnDetails() {
        let record = AccidentStore.createRecord(for: UUID(), in: context)
        record.ownName = "Ada Lovelace"
        record.ownAddress = "12 Acacia Avenue, Bristol, BS1 1AA"
        record.ownPhone = "07700 900123"

        XCTAssertEqual(
            AccidentEvidencePackBuilder.ownDetailLines(from: record),
            [
                "Name: Ada Lovelace",
                "Phone: 07700 900123",
                "Address: 12 Acacia Avenue, Bristol, BS1 1AA"
            ]
        )
    }
}
