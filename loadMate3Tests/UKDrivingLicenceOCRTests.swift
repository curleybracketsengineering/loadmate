import XCTest
@testable import loadMate3

final class UKDrivingLicenceOCRTests: XCTestCase {
    func testParsesSplitFieldLabelsLikeVisionOutput() {
        let suggestions = DrivingLicenceOCR.suggestions(from: [
            "UK DRIVING LICENCE",
            "SMITH",
            "1.",
            "MR JOHN PAUL",
            "2.",
            "01.02.1980 LONDON",
            "3",
            "4a. 16.09.2022 4c. DVLA",
            "4b. 08.10.2028",
            "5. SMITH010280JP9AB 72",
            "8. 10 HIGH STREET, ANYTOWN",
            "SOMEWHERE, AB1 2CD",
            "OCT28",
            "9. AM/A/B1/B/C1/D1/BE/C1E/D1E/f/k/l/n/p/q"
        ])

        XCTAssertEqual(suggestions.surname, "SMITH")
        XCTAssertEqual(suggestions.forenames, "JOHN PAUL")
        XCTAssertEqual(suggestions.fullName, "JOHN PAUL SMITH")
        XCTAssertEqual(suggestions.dateOfBirth, "01.02.1980")
        XCTAssertEqual(suggestions.driverNumber, "SMITH010280JP9AB")
        XCTAssertEqual(suggestions.expiryDate, "08.10.2028")
        XCTAssertEqual(suggestions.address, "10 HIGH STREET, ANYTOWN, SOMEWHERE, AB1 2CD")
        XCTAssertTrue(suggestions.hasUsefulFields)
    }

    func testParsesInlineNumberedFields() {
        let suggestions = DrivingLicenceOCR.suggestions(from: [
            "UK DRIVING LICENCE",
            "1. JONES",
            "2. MS EMILY ROSE",
            "3. 12.03.1991 CARDIFF",
            "4b. 01.01.2030",
            "5. JONES120391ER9CD",
            "8. 22 STATION ROAD, BRISTOL, BS1 4AA",
            "9. AM/A/B1/B"
        ])

        XCTAssertEqual(suggestions.surname, "JONES")
        XCTAssertEqual(suggestions.forenames, "EMILY ROSE")
        XCTAssertEqual(suggestions.fullName, "EMILY ROSE JONES")
        XCTAssertEqual(suggestions.dateOfBirth, "12.03.1991")
        XCTAssertEqual(suggestions.driverNumber, "JONES120391ER9CD")
        XCTAssertEqual(suggestions.address, "22 STATION ROAD, BRISTOL, BS1 4AA")
    }

    func testParsesFrenchEULicence() {
        let suggestions = DrivingLicenceOCR.suggestions(from: [
            "PERMIS DE CONDUIRE",
            "F",
            "1. DUPONT",
            "2. JEAN PIERRE",
            "3. 15.03.1985 PARIS",
            "4a. 01.01.2020",
            "4b. 01.01.2035",
            "4c. PREFECTURE DE POLICE",
            "5. 12AB34567",
            "8. 10 RUE DE LA PAIX",
            "75002 PARIS",
            "9. AM B"
        ])

        XCTAssertEqual(suggestions.surname, "DUPONT")
        XCTAssertEqual(suggestions.forenames, "JEAN PIERRE")
        XCTAssertEqual(suggestions.fullName, "JEAN PIERRE DUPONT")
        XCTAssertEqual(suggestions.dateOfBirth, "15.03.1985")
        XCTAssertEqual(suggestions.driverNumber, "12AB34567")
        XCTAssertEqual(suggestions.expiryDate, "01.01.2035")
        XCTAssertEqual(suggestions.address, "10 RUE DE LA PAIX, 75002 PARIS")
    }

    func testParsesGermanEULicenceWithSlashDates() {
        let suggestions = DrivingLicenceOCR.suggestions(from: [
            "FÜHRERSCHEIN",
            "DEUTSCHLAND",
            "1. MUELLER",
            "2. ANNA MARIA",
            "3. 20/04/1978 BERLIN",
            "4a. 10/10/2019 4b. 10/10/2034",
            "4c. STADT BERLIN",
            "5. B072RRE2I3",
            "9. A B BE"
        ])

        XCTAssertEqual(suggestions.surname, "MUELLER")
        XCTAssertEqual(suggestions.forenames, "ANNA MARIA")
        XCTAssertEqual(suggestions.fullName, "ANNA MARIA MUELLER")
        XCTAssertEqual(suggestions.dateOfBirth, "20/04/1978")
        XCTAssertEqual(suggestions.driverNumber, "B072RRE2I3")
        XCTAssertEqual(suggestions.expiryDate, "10/10/2034")
        // Address is optional on many EU cards.
        XCTAssertTrue(suggestions.address.isEmpty)
    }

    func testParsesSpanishEULicenceWithoutTitles() {
        let suggestions = DrivingLicenceOCR.suggestions(from: [
            "PERMISO DE CONDUCCIÓN",
            "ESPANA",
            "1. GARCIA LOPEZ",
            "2. CARLOS",
            "3. 03-07-1990 MADRID",
            "4a. 05-05-2018",
            "4b. 05-05-2028",
            "5. 12345678Z",
            "8. CALLE MAYOR 1",
            "28013 MADRID",
            "9. B"
        ])

        XCTAssertEqual(suggestions.surname, "GARCIA LOPEZ")
        XCTAssertEqual(suggestions.forenames, "CARLOS")
        XCTAssertEqual(suggestions.fullName, "CARLOS GARCIA LOPEZ")
        XCTAssertEqual(suggestions.dateOfBirth, "03-07-1990")
        XCTAssertEqual(suggestions.driverNumber, "12345678Z")
        XCTAssertTrue(suggestions.address.contains("CALLE MAYOR 1"))
    }

    func testIgnoresEmptyNoise() {
        let suggestions = DrivingLicenceOCR.suggestions(from: [
            "HELLO",
            "RANDOM TEXT",
            "123"
        ])
        XCTAssertFalse(suggestions.hasUsefulFields)
    }

    func testUKTypealiasStillWorks() {
        let suggestions = UKDrivingLicenceOCR.suggestions(from: [
            "UK DRIVING LICENCE",
            "1. BROWN",
            "2. SAM",
            "5. BROWN010203SB9XX"
        ])
        XCTAssertEqual(suggestions.surname, "BROWN")
        XCTAssertEqual(suggestions.forenames, "SAM")
    }
}
