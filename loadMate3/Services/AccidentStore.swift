import Foundation
import SwiftData

enum AccidentStore {
    @discardableResult
    static func createRecord(
        for vehicleID: UUID,
        jurisdiction: AccidentJurisdiction = .unitedKingdom,
        occurredAt: Date = Date(),
        profile: VehicleProfile? = nil,
        in context: ModelContext
    ) -> AccidentRecord {
        let record = AccidentRecord(vehicleID: vehicleID, occurredAt: occurredAt)
        record.jurisdiction = jurisdiction
        if let profile {
            prefillOwnVehicle(on: record, from: profile)
            record.wasTowing = profile.kind == .caravan
        }
        context.insert(record)
        try? context.save()
        return record
    }

    /// Copies profile registration and insurance onto a new incident. Does not overwrite fields already set.
    static func prefillOwnVehicle(on record: AccidentRecord, from profile: VehicleProfile) {
        if record.ownRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            record.ownRegistration = profile.registrationMark
        }
        if record.ownInsurerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            record.ownInsurerName = profile.insuranceProviderName
        }
        if record.ownInsurancePolicyNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            record.ownInsurancePolicyNumber = profile.insurancePolicyNumber
        }
        if record.ownInsuranceClaimsPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            record.ownInsuranceClaimsPhone = profile.insuranceClaimsPhone
        }
    }

    /// Legacy incidents created before own-vehicle snapshot fields existed. Skipped once any own-vehicle detail is present.
    static func backfillLegacyOwnVehicleIfNeeded(on record: AccidentRecord, from profile: VehicleProfile) {
        let noOwnVehicleDetails =
            record.ownRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && record.ownInsurerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && record.ownInsurancePolicyNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && record.ownInsuranceClaimsPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !record.hasOwnLookupSnapshot
        guard noOwnVehicleDetails else { return }
        prefillOwnVehicle(on: record, from: profile)
    }

    /// Profile values used only when this incident never snapshotted own-vehicle details (legacy records).
    static func resolvedOwnRegistration(on record: AccidentRecord, profile: VehicleProfile) -> String {
        let own = record.ownRegistration.trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? profile.registrationMark : record.ownRegistration
    }

    static func resolvedOwnInsurerName(on record: AccidentRecord, profile: VehicleProfile) -> String {
        let own = record.ownInsurerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? profile.insuranceProviderName : record.ownInsurerName
    }

    static func resolvedOwnInsurancePolicyNumber(on record: AccidentRecord, profile: VehicleProfile) -> String {
        let own = record.ownInsurancePolicyNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? profile.insurancePolicyNumber : record.ownInsurancePolicyNumber
    }

    static func resolvedOwnInsuranceClaimsPhone(on record: AccidentRecord, profile: VehicleProfile) -> String {
        let own = record.ownInsuranceClaimsPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? profile.insuranceClaimsPhone : record.ownInsuranceClaimsPhone
    }

    static func filingIdentityLine(for profile: VehicleProfile) -> String {
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? profile.kind.displayName : name
        if profile.kind == .caravan {
            let vin = profile.vinChassisNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if vin.isEmpty { return "\(title) (caravan)" }
            return "\(title) (caravan) · CRiS / VIN \(vin)"
        }
        return "\(title) (\(profile.kind.displayName.lowercased()))"
    }

    static func save(_ record: AccidentRecord, in context: ModelContext) {
        record.updatedAt = Date()
        try? context.save()
    }

    static func delete(_ record: AccidentRecord, in context: ModelContext) {
        for photo in record.photosList {
            AccidentPhotoStore.delete(photo: photo, vehicleID: record.vehicleID, in: context, saveContext: false)
        }
        context.delete(record)
        try? context.save()
    }

    static func records(for vehicleID: UUID, from all: [AccidentRecord]) -> [AccidentRecord] {
        all.filter { $0.vehicleID == vehicleID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    @discardableResult
    static func addOtherVehicle(to record: AccidentRecord, in context: ModelContext) -> AccidentOtherVehicle {
        record.noOtherVehicle = false
        let vehicle = AccidentOtherVehicle(record: record)
        context.insert(vehicle)
        record.updatedAt = Date()
        try? context.save()
        return vehicle
    }

    static func deleteOtherVehicle(_ vehicle: AccidentOtherVehicle, in context: ModelContext) {
        if let record = vehicle.record {
            record.updatedAt = Date()
        }
        context.delete(vehicle)
        try? context.save()
    }

    @discardableResult
    static func addWitness(to record: AccidentRecord, in context: ModelContext) -> AccidentWitness {
        let witness = AccidentWitness(record: record)
        context.insert(witness)
        record.updatedAt = Date()
        try? context.save()
        return witness
    }

    static func deleteWitness(_ witness: AccidentWitness, in context: ModelContext) {
        if let record = witness.record {
            record.updatedAt = Date()
        }
        context.delete(witness)
        try? context.save()
    }

    static func applyLookup(
        _ result: VehicleLookupResult,
        to vehicle: AccidentOtherVehicle,
        now: Date = Date()
    ) {
        vehicle.registration = result.displayRegistration
        vehicle.lookupMake = result.make ?? ""
        vehicle.lookupModel = result.model ?? ""
        vehicle.lookupColour = result.colour ?? ""
        vehicle.lookupTaxStatus = result.taxStatus ?? ""
        vehicle.lookupMotStatus = result.motStatus ?? ""
        vehicle.lookupMotExpiryDate = result.motExpiryDate
        vehicle.lookupMarkedForExport = result.markedForExport ?? false
        vehicle.lookupCheckedAt = result.checkedAt
        vehicle.lookupPending = false
        vehicle.lookupErrorMessage = ""
        vehicle.lookupRegistration = UKRegistration.normalizeForLookup(result.displayRegistration)
        vehicle.isForeignRegistration = false
        refreshRedFlags(for: vehicle, now: now)
        vehicle.updatedAt = now
    }

    static func applyOwnLookup(
        _ result: VehicleLookupResult,
        to record: AccidentRecord,
        now: Date = Date()
    ) {
        record.ownRegistration = result.displayRegistration
        record.ownLookupMake = result.make ?? ""
        record.ownLookupModel = result.model ?? ""
        record.ownLookupColour = result.colour ?? ""
        record.ownLookupTaxStatus = result.taxStatus ?? ""
        record.ownLookupMotStatus = result.motStatus ?? ""
        record.ownLookupMotExpiryDate = result.motExpiryDate
        record.ownLookupMarkedForExport = result.markedForExport ?? false
        record.ownLookupCheckedAt = result.checkedAt
        record.ownLookupPending = false
        record.ownLookupErrorMessage = ""
        record.ownLookupRegistration = UKRegistration.normalizeForLookup(result.displayRegistration)
        record.updatedAt = now
    }

    static func clearOwnLookupSnapshot(for record: AccidentRecord, now: Date = Date()) {
        record.ownLookupMake = ""
        record.ownLookupModel = ""
        record.ownLookupColour = ""
        record.ownLookupTaxStatus = ""
        record.ownLookupMotStatus = ""
        record.ownLookupMotExpiryDate = nil
        record.ownLookupMarkedForExport = false
        record.ownLookupCheckedAt = nil
        record.ownLookupRegistration = ""
        record.ownLookupPending = false
        record.updatedAt = now
    }

    @discardableResult
    static func clearOwnLookupSnapshotIfStale(for record: AccidentRecord, now: Date = Date()) -> Bool {
        guard record.ownLookupSnapshotIsStale else { return false }
        clearOwnLookupSnapshot(for: record, now: now)
        record.ownLookupErrorMessage = ""
        return true
    }

    /// Drops MOT, tax, make and colour taken from a previous plate so they cannot be read as belonging to the new one.
    static func clearLookupSnapshot(for vehicle: AccidentOtherVehicle, now: Date = Date()) {
        vehicle.lookupMake = ""
        vehicle.lookupModel = ""
        vehicle.lookupColour = ""
        vehicle.lookupTaxStatus = ""
        vehicle.lookupMotStatus = ""
        vehicle.lookupMotExpiryDate = nil
        vehicle.lookupMarkedForExport = false
        vehicle.lookupCheckedAt = nil
        vehicle.lookupRegistration = ""
        vehicle.lookupPending = false
        refreshRedFlags(for: vehicle, now: now)
        vehicle.updatedAt = now
    }

    @discardableResult
    static func clearLookupSnapshotIfStale(for vehicle: AccidentOtherVehicle, now: Date = Date()) -> Bool {
        guard vehicle.lookupSnapshotIsStale else { return false }
        clearLookupSnapshot(for: vehicle, now: now)
        vehicle.lookupErrorMessage = ""
        return true
    }

    static func refreshRedFlags(for vehicle: AccidentOtherVehicle, now: Date = Date()) {
        if vehicle.isForeignRegistration {
            var flags: [AccidentRedFlag] = [.foreignPlate]
            if vehicle.redFlags.contains(.suspectedUninsured) {
                flags.append(.suspectedUninsured)
            }
            vehicle.redFlags = flags
            return
        }

        var flags = AccidentLookupFlags.flags(
            motStatus: nonEmpty(vehicle.lookupMotStatus),
            motExpiryDate: vehicle.lookupMotExpiryDate,
            taxStatus: nonEmpty(vehicle.lookupTaxStatus),
            markedForExport: vehicle.lookupMarkedForExport,
            lookupMake: nonEmpty(vehicle.lookupMake),
            lookupColour: nonEmpty(vehicle.lookupColour),
            expectedMake: nonEmpty(vehicle.userConfirmedMake),
            expectedColour: nonEmpty(vehicle.userConfirmedColour),
            now: now
        )
        if vehicle.redFlags.contains(.suspectedUninsured) {
            flags.insert(.suspectedUninsured)
        }
        vehicle.redFlags = Array(flags).sorted { $0.rawValue < $1.rawValue }
    }

    static func combinedRedFlags(on record: AccidentRecord) -> Set<AccidentRedFlag> {
        var flags = Set<AccidentRedFlag>()
        if record.hitAndRun {
            flags.insert(.hitAndRun)
        }
        for vehicle in record.otherVehiclesList {
            flags.formUnion(vehicle.redFlags)
            if vehicle.isForeignRegistration {
                flags.insert(.foreignPlate)
            }
        }
        return flags
    }

    static func guidanceInput(
        for record: AccidentRecord,
        profile: VehicleProfile?
    ) -> AccidentGuidanceInput {
        let flags = combinedRedFlags(on: record)
        let foreign = record.otherVehiclesList.contains(where: \.isForeignRegistration) || flags.contains(.foreignPlate)
        let hasTow = record.wasTowing
        return AccidentGuidanceInput(
            jurisdiction: record.jurisdiction,
            anyoneInjured: record.anyoneInjured,
            sceneUnsafeOrBlocked: record.sceneUnsafeOrBlocked,
            suspectedImpairmentOrViolence: record.suspectedImpairmentOrViolence,
            hitAndRun: record.hitAndRun,
            detailsExchanged: record.detailsExchanged,
            insuranceCertificateSeen: record.insuranceCertificateSeen,
            otherDriverRefused: record.otherDriverRefused,
            vehicleKind: profile?.kind ?? .caravan,
            hasTowOrTrailer: hasTow,
            redFlags: flags,
            otherVehicleIsForeign: foreign,
            noOtherVehicle: record.noOtherVehicle,
            hasOtherVehicles: !record.otherVehiclesList.isEmpty
        )
    }

    static func refreshProcessBranch(
        for record: AccidentRecord,
        profile: VehicleProfile?
    ) {
        let input = guidanceInput(for: record, profile: profile)
        record.processBranch = AccidentGuidance.processBranch(for: input)
        record.updatedAt = Date()
    }

    @discardableResult
    static func lookupUKPlate(
        _ raw: String,
        on vehicle: AccidentOtherVehicle,
        using lookup: any VehicleLookupProviding,
        in context: ModelContext
    ) async -> Result<VehicleLookupResult, VehicleLookupError> {
        let requested = UKRegistration.normalizeForLookup(raw)
        do {
            let result = try await lookup.lookup(registration: raw, forceRefresh: true)
            applyLookup(result, to: vehicle)
            if let record = vehicle.record {
                save(record, in: context)
            }
            return .success(result)
        } catch let error as VehicleLookupError {
            discardSnapshotFromOtherPlate(on: vehicle, requested: requested)
            vehicle.lookupPending = error == .noNetwork
            vehicle.lookupErrorMessage = error.errorDescription ?? "Lookup failed."
            vehicle.updatedAt = Date()
            if let record = vehicle.record {
                save(record, in: context)
            }
            return .failure(error)
        } catch {
            discardSnapshotFromOtherPlate(on: vehicle, requested: requested)
            vehicle.lookupPending = false
            vehicle.lookupErrorMessage = "Lookup failed."
            vehicle.updatedAt = Date()
            if let record = vehicle.record {
                save(record, in: context)
            }
            return .failure(.unexpectedResponse)
        }
    }

    @discardableResult
    static func lookupOwnUKPlate(
        _ raw: String,
        on record: AccidentRecord,
        using lookup: any VehicleLookupProviding,
        in context: ModelContext
    ) async -> Result<VehicleLookupResult, VehicleLookupError> {
        let requested = UKRegistration.normalizeForLookup(raw)
        do {
            let result = try await lookup.lookup(registration: raw, forceRefresh: true)
            applyOwnLookup(result, to: record)
            save(record, in: context)
            return .success(result)
        } catch let error as VehicleLookupError {
            discardOwnSnapshotFromOtherPlate(on: record, requested: requested)
            record.ownLookupPending = error == .noNetwork
            record.ownLookupErrorMessage = error.errorDescription ?? "Lookup failed."
            record.updatedAt = Date()
            save(record, in: context)
            return .failure(error)
        } catch {
            discardOwnSnapshotFromOtherPlate(on: record, requested: requested)
            record.ownLookupPending = false
            record.ownLookupErrorMessage = "Lookup failed."
            record.updatedAt = Date()
            save(record, in: context)
            return .failure(.unexpectedResponse)
        }
    }

    static func retryPendingLookups(
        on record: AccidentRecord,
        using lookup: any VehicleLookupProviding,
        in context: ModelContext
    ) async {
        if record.ownLookupPending, !record.ownRegistration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = await lookupOwnUKPlate(record.ownRegistration, on: record, using: lookup, in: context)
        }
        let pending = record.otherVehiclesList.filter { $0.lookupPending && !$0.isForeignRegistration && !$0.registration.isEmpty }
        for vehicle in pending {
            _ = await lookupUKPlate(vehicle.registration, on: vehicle, using: lookup, in: context)
        }
    }

    /// A failed lookup must not leave the previous plate's details on screen next to the new registration.
    private static func discardSnapshotFromOtherPlate(on vehicle: AccidentOtherVehicle, requested: String) {
        guard vehicle.hasLookupSnapshot, vehicle.lookupRegistration != requested else { return }
        clearLookupSnapshot(for: vehicle)
    }

    private static func discardOwnSnapshotFromOtherPlate(on record: AccidentRecord, requested: String) {
        guard record.hasOwnLookupSnapshot, record.ownLookupRegistration != requested else { return }
        clearOwnLookupSnapshot(for: record)
    }

    private static func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
