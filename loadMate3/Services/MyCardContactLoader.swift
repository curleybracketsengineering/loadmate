import Contacts
import Foundation

struct MyCardDetails: Equatable, Sendable {
    var name: String = ""
    var address: String = ""
    var phone: String = ""

    var isEmpty: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum MyCardContactError: Error, Equatable, LocalizedError, Sendable {
    case emptyMeCard

    var errorDescription: String? {
        switch self {
        case .emptyMeCard:
            return "That card has no name, address or phone. Enter them here, or edit the card in Contacts."
        }
    }
}

enum MyCardContactMapper {
    static func details(from contact: CNContact) -> MyCardDetails {
        let name = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallbackName = [contact.givenName, contact.middleName, contact.familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let addressValue = preferredPostalAddress(on: contact)
        let address: String
        if let addressValue {
            address = CNPostalAddressFormatter().string(from: addressValue)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            address = ""
        }

        let phone = preferredPhone(on: contact)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return MyCardDetails(
            name: name.isEmpty ? fallbackName : name,
            address: address,
            phone: phone
        )
    }

    private static func preferredPostalAddress(on contact: CNContact) -> CNPostalAddress? {
        let labeled = contact.postalAddresses
        if let home = labeled.first(where: { $0.label == CNLabelHome }) {
            return home.value
        }
        return labeled.first?.value
    }

    private static func preferredPhone(on contact: CNContact) -> String {
        let labeled = contact.phoneNumbers
        let preferred = labeled.first(where: {
            $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone
        }) ?? labeled.first
        return preferred?.value.stringValue ?? ""
    }
}
