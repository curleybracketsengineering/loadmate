import Testing
@testable import loadMate3

@Suite("LoadZone mapping and resolution")
struct LoadZoneTests {
    @Test("Legacy caravan zones resolve to motorhome equivalents")
    func resolvedMapsLegacyCaravanZonesToMotorhome() {
        #expect(LoadZone.resolved(rawValue: "frontLocker", for: .motorhome) == .driver)
        #expect(LoadZone.resolved(rawValue: "front", for: .motorhome) == .central)
        #expect(LoadZone.resolved(rawValue: "middle", for: .motorhome) == .central)
        #expect(LoadZone.resolved(rawValue: "rear", for: .motorhome) == .back)
        // Native motorhome zones are unchanged.
        #expect(LoadZone.resolved(rawValue: "garage", for: .motorhome) == .garage)
        // Caravan keeps its own zones.
        #expect(LoadZone.resolved(rawValue: "frontLocker", for: .caravan) == .frontLocker)
        // Unknown raw values fall back to unassigned.
        #expect(LoadZone.resolved(rawValue: "bogus", for: .caravan) == .unassigned)
    }

    @Test("Unassigned items use the axle/central zone for calculations")
    func calculationZoneForUnassigned() {
        #expect(LoadZone.unassigned.calculationZone(for: .caravan) == .middle)
        #expect(LoadZone.unassigned.calculationZone(for: .motorhome) == .central)
        // Assigned zones keep their resolved identity.
        #expect(LoadZone.rear.calculationZone(for: .motorhome) == .back)
    }

    @Test("Default-for-loading remaps shared caravan defaults onto motorhomes")
    func defaultForLoading() {
        #expect(LoadZone.frontLocker.defaultForLoading(on: .motorhome) == .driver)
        #expect(LoadZone.rear.defaultForLoading(on: .motorhome) == .back)
        // Caravan keeps the default unchanged.
        #expect(LoadZone.frontLocker.defaultForLoading(on: .caravan) == .frontLocker)
    }

    @Test("Picker zones depend on kind and bike-rack fitment")
    func pickerZones() {
        #expect(LoadZone.pickerZones(for: .caravan) == [.frontLocker, .front, .middle, .rear, .bikeRack])
        #expect(LoadZone.pickerZones(for: .motorhome) == [.driver, .central, .back, .garage, .bikeRack])

        let noRack = VehicleProfile(kind: .motorhome)
        noRack.hasBikeRack = false
        #expect(!LoadZone.pickerZones(for: .motorhome, profile: noRack).contains(.bikeRack))

        let withRack = VehicleProfile(kind: .motorhome)
        withRack.hasBikeRack = true
        #expect(LoadZone.pickerZones(for: .motorhome, profile: withRack).contains(.bikeRack))
    }
}
