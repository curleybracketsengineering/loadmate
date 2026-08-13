import XCTest
@testable import loadMate3

final class VehiclePlateOCRTests: XCTestCase {
    func testSuggestionsParseCaravanPlateFields() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "BAILEY OF BRISTOL",
                "VIN SGA12345BY8123456",
                "MTPLM 1500 kg",
                "MIRO 1294 kg",
                "NOSE WEIGHT 100 kg"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "SGA12345BY8123456")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 1500)
        XCTAssertEqual(suggestions.miroOrMroKg, 1294)
        XCTAssertEqual(suggestions.hitchOrNoseKg, 100)
        XCTAssertTrue(suggestions.hasAnySuggestion)
    }

    func testSuggestionsParseMotorhomePlateWithSplitLines() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "MAXIMUM AUTHORISED MASS",
                "3500",
                "MASS IN RUNNING ORDER",
                "2850",
                "FRONT AXLE",
                "1850",
                "REAR AXLE",
                "2000",
                "VIN WX1ZZZVFZMN123456"
            ]
        )

        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
        XCTAssertEqual(suggestions.miroOrMroKg, 2850)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 1850)
        XCTAssertEqual(suggestions.maxRearAxleKg, 2000)
        XCTAssertEqual(suggestions.vinChassisNumber, "WX1ZZZVFZMN123456")
    }

    func testSuggestionsRecogniseMTOAliasForMaximumMass() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "MTO 1800",
                "MIRO 1450"
            ]
        )

        XCTAssertEqual(suggestions.mtplmOrMamKg, 1800)
        XCTAssertEqual(suggestions.miroOrMroKg, 1450)
    }

    func testSuggestionsIgnoreNoiseWhenEmpty() {
        let suggestions = VehiclePlateOCR.suggestions(from: ["ABC", "HELLO", "XYZ"])

        XCTAssertFalse(suggestions.hasAnySuggestion)
        XCTAssertFalse(suggestions.confidenceNotes.isEmpty)
    }

    func testSuggestionsPreferLabeledVINOverNoise() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "SERIAL 12345678",
                "CHASSIS NO SGBT001SW9123456",
                "MTPLM 1700"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "SGBT001SW9123456")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 1700)
    }

    func testSuggestionsParseTyreSizePressureAndSteelTorque() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "MTPLM 1500",
                "MIRO 1290",
                "TYRE SIZE 185 R14C",
                "TYRE PRESSURE 4.5 BAR",
                "WHEEL NUT TORQUE STEEL 110 NM",
                "ALLOY 130 NM"
            ]
        )

        XCTAssertEqual(suggestions.tyreSize, "185 R14C")
        XCTAssertEqual(suggestions.tyrePressureDisplayUnit, .bar)
        XCTAssertEqual(suggestions.tyrePressurePSI ?? 0, 65, accuracy: 1.0)
        XCTAssertEqual(suggestions.wheelNutTorqueSteelNm, 110)
        XCTAssertEqual(suggestions.wheelNutTorqueAlloyNm, 130)
    }

    func testSuggestionsParsePSIPressureAndGenericTorqueAsSteel() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "225/75 R16C",
                "PRESSURE 65 PSI",
                "WHEEL NUT TORQUE 120 NM"
            ]
        )

        XCTAssertEqual(suggestions.tyreSize, "225/75 R16C")
        XCTAssertEqual(suggestions.tyrePressurePSI, 65)
        XCTAssertEqual(suggestions.tyrePressureDisplayUnit, .psi)
        XCTAssertEqual(suggestions.wheelNutTorqueSteelNm, 120)
        XCTAssertNil(suggestions.wheelNutTorqueAlloyNm)
    }

    func testSuggestionsParseSwiftManufacturerAndConquerorModel() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "SWIFT GROUP LIMITED",
                "CONQUEROR 645",
                "VIN SGA12345SW8123456",
                "MTPLM 1700",
                "MIRO 1450"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Swift")
        XCTAssertEqual(suggestions.modelName, "Conqueror 645")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 1700)
    }

    func testSuggestionsParseLabeledMakeAndModel() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "MAKE BAILEY",
                "MODEL UNICORN CADIZ",
                "MTPLM 1492"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Bailey")
        XCTAssertEqual(suggestions.modelName, "Unicorn Cadiz")
    }

    func testSuggestionsInferManufacturerFromCaravanVINCode() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "VIN SGBT001SW9123456",
                "MTPLM 1600"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Swift")
        XCTAssertEqual(suggestions.vinChassisNumber, "SGBT001SW9123456")
    }

    func testSuggestionsParseEUStatutoryPilotePlate() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "G P SAS",
                "e13*2007/46*0212",
                "ETAPE 2",
                "ZFA250001RMA26231",
                "3500 kg",
                "5500 kg",
                "1- 1960 kg",
                "2- 2000 kg",
                "3- kg"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA250001RMA26231")
        XCTAssertEqual(suggestions.manufacturer, "Pilote")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
        XCTAssertEqual(suggestions.gtwKg, 5500)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 1960)
        XCTAssertEqual(suggestions.maxRearAxleKg, 2000)
        XCTAssertNil(suggestions.bodyCellNumber)
        XCTAssertNil(suggestions.modelName)
    }

    func testSuggestionsParseUKEngineeringPlateWithGTW() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "S&T LLP VEHICLE WEIGHT ENGINEERING",
                "MAKE/MODEL SWIFT AUTOCRUISE SELECT 144",
                "VIN ZFA25000002B64689",
                "YEAR 2017",
                "MAM 3500 Kg",
                "GTW 5800 Kg",
                "AXLE 1 1750 Kg",
                "AXLE 2 1900 Kg",
                "AXLE 3 Kg"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Swift")
        XCTAssertEqual(suggestions.modelName, "Autocruise Select 144")
        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA25000002B64689")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
        XCTAssertEqual(suggestions.gtwKg, 5800)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 1750)
        XCTAssertEqual(suggestions.maxRearAxleKg, 1900)
    }

    func testSuggestionsParseEUStatutoryRapidoPlateWithCellNumber() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "RAPIDO",
                "e2*2007/46*0085*09",
                "ETAPE 2",
                "ZFA25000002950575",
                "3500 kg",
                "6000 kg",
                "1- 1850 kg",
                "2- 2000 kg",
                "3- kg",
                "N° de cellule 16-0792-1592616"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Rapido")
        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA25000002950575")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
        XCTAssertEqual(suggestions.gtwKg, 6000)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 1850)
        XCTAssertEqual(suggestions.maxRearAxleKg, 2000)
        XCTAssertEqual(suggestions.bodyCellNumber, "16-0792-1592616")
        XCTAssertNil(suggestions.modelName)
    }

    func testSuggestionsParseSvTechGVMPlateWithoutGTW() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "MAXIMUM WEIGHTS AT WHICH THIS VEHICLE IS FIT FOR USE",
                "VEHICLE MAKE FIAT DUCATO",
                "MODEL 35 - 250D",
                "AXLES 2",
                "ENGINE TYPE 3.0 HDi",
                "POWER OUTPUT 115 kW @ 3500 rpm",
                "GVM 3900 kg",
                "GTM - kg",
                "AXLE 1 2100 kg",
                "AXLE 2 2400 kg"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Fiat")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3900)
        XCTAssertNil(suggestions.gtwKg)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 2100)
        XCTAssertEqual(suggestions.maxRearAxleKg, 2400)
        XCTAssertEqual(suggestions.modelName?.uppercased().contains("250"), true)
    }

    func testSuggestionsReadSpacedAndOCRConfusedVIN() {
        let spaced = VehiclePlateOCR.suggestions(from: ["ZFA 2500000 2B64689", "MAM 3500"])
        XCTAssertEqual(spaced.vinChassisNumber, "ZFA25000002B64689")

        let confused = VehiclePlateOCR.suggestions(from: ["ZFA25OOOOO2B64689", "AXLE 1 1750"])
        XCTAssertEqual(confused.vinChassisNumber, "ZFA25000002B64689")
    }

    func testSuggestionsReadVINOnLineAfterIdentificationLabel() {
        let english = VehiclePlateOCR.suggestions(
            from: [
                "VEHICLE IDENTIFICATION NUMBER",
                "ZFA25000002950575",
                "RAPIDO",
                "N° DE CELLULE 98765432"
            ]
        )
        XCTAssertEqual(english.vinChassisNumber, "ZFA25000002950575")

        let french = VehiclePlateOCR.suggestions(
            from: [
                "RAPIDO",
                "N° D'IDENTIFICATION",
                "ZFA25000002950575",
                "N° DE CELLULE 12345678"
            ]
        )
        XCTAssertEqual(french.vinChassisNumber, "ZFA25000002950575")
    }

    func testSuggestionsJoinVINSplitAcrossLines() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "SWIFT",
                "ZFA25000",
                "002B64689",
                "MAM 3500"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA25000002B64689")
    }

    func testSuggestionsIgnoreTypeApprovalAndCellNumber() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "e2*2007/46*0044*10",
                "N° DE CELLULE 12345678",
                "3500"
            ]
        )

        XCTAssertNil(suggestions.vinChassisNumber)
        XCTAssertEqual(suggestions.bodyCellNumber, "12345678")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
    }

    func testSuggestionsParseNoisyRapidoPlateWithOCRConfusedVINAndAxles() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "RAPIDO",
                "e2*2007/46*0085*09 ETAPE 2 ZFA250000002950575 3500kg 6000kg I- 1850kg 2- 2000kg",
                "N° de cellule 15-2792-1592616"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Rapido")
        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA25000002950575")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
        XCTAssertEqual(suggestions.gtwKg, 6000)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 1850)
        XCTAssertEqual(suggestions.maxRearAxleKg, 2000)
        XCTAssertEqual(suggestions.bodyCellNumber, "15-2792-1592616")
    }

    func testSuggestionsParseRapidoMassesWithoutVIN() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "RAPIDO",
                "ETAPE 2",
                "3500 kg",
                "6000 kg",
                "1- 1850 kg",
                "2- 2000 kg",
                "N° de cellule 15-2792-1592616"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Rapido")
        XCTAssertNil(suggestions.vinChassisNumber)
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
        XCTAssertEqual(suggestions.gtwKg, 6000)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 1850)
        XCTAssertEqual(suggestions.maxRearAxleKg, 2000)
        XCTAssertEqual(suggestions.bodyCellNumber, "15-2792-1592616")
    }

    func testISOCheckDigitRecognisesKnownVIN() {
        XCTAssertTrue(VehicleVINParsing.isoCheckDigitValid("1HGCM82633A004352"))
        XCTAssertFalse(VehicleVINParsing.isoCheckDigitValid("1HGCM82633A004353"))
    }

    func testSuggestionsCoerceFiatVINWithExtraZero() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "ZFA250000002950575",
                "MAM 3500"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA25000002950575")
    }

    func testSuggestionsReadChassisLabelOnFollowingLine() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "CHASSIS NO",
                "SGBT001SW9123456",
                "MTPLM 1700"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "SGBT001SW9123456")
    }

    func testSuggestionsParseEUTrailerPlateWithCouplingAsAxleZero() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "HOBBY",
                "e1*2018/858*0123",
                "WHB12345HYA123456",
                "1500 kg",
                "0- 100 kg",
                "1- 900 kg",
                "2- 900 kg"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Hobby")
        XCTAssertEqual(suggestions.vinChassisNumber, "WHB12345HYA123456")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 1500)
        XCTAssertNil(suggestions.gtwKg)
        XCTAssertEqual(suggestions.hitchOrNoseKg, 100)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 900)
        XCTAssertEqual(suggestions.maxRearAxleKg, 900)
    }

    func testSuggestionsParseGermanTrailerLabelsIncludingStutzlast() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "HERSTELLER FENDT",
                "FIN WXF00000AB6123456",
                "ZULÄSSIGE GESAMTMASSE 1600",
                "STÜTZLAST 75",
                "ACHSE 1 850",
                "ACHSE 2 850"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Fendt")
        XCTAssertEqual(suggestions.vinChassisNumber, "WXF00000AB6123456")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 1600)
        XCTAssertEqual(suggestions.hitchOrNoseKg, 75)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 850)
        XCTAssertEqual(suggestions.maxRearAxleKg, 850)
    }

    func testSuggestionsParseItalianAndFrenchMassAliases() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "TELAIO ZFA250001RMA26231",
                "MMA 3500",
                "PTRA 5500",
                "MASSE EN ORDRE DE MARCHE 2800"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA250001RMA26231")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
        XCTAssertEqual(suggestions.gtwKg, 5500)
        XCTAssertEqual(suggestions.miroOrMroKg, 2800)
        XCTAssertEqual(suggestions.manufacturer, "Fiat")
    }

    func testSuggestionsParseSpanishBastidorLabel() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "BASTIDOR ZY112345AD8123456",
                "MMA 1500",
                "CARGA VERTICAL SOBRE EL ENGANCHE 100"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "ZY112345AD8123456")
        XCTAssertEqual(suggestions.manufacturer, "Adria")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 1500)
        XCTAssertEqual(suggestions.hitchOrNoseKg, 100)
    }

    func testSuggestionsIgnoreGBTypeApprovalNumber() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "g11*2018/858*00861*00",
                "ZFA250001RMA26231",
                "3500 kg",
                "5500 kg",
                "1- 1960 kg",
                "2- 2000 kg"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA250001RMA26231")
        XCTAssertEqual(suggestions.mtplmOrMamKg, 3500)
        XCTAssertEqual(suggestions.gtwKg, 5500)
        XCTAssertEqual(suggestions.maxFrontAxleKg, 1960)
        XCTAssertEqual(suggestions.maxRearAxleKg, 2000)
        XCTAssertEqual(suggestions.manufacturer, "Fiat")
    }

    func testSuggestionsInferAvondaleFromCRiSCode() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "VIN SGAT001AV9123456",
                "MTPLM 1450"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Avondale")
        XCTAssertEqual(suggestions.vinChassisNumber, "SGAT001AV9123456")
    }

    func testSuggestionsPreferConverterBrandOverChassisWMI() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "RAPIDO",
                "e2*2018/858*0085*09",
                "ETAPE 2",
                "ZFA25000002950575",
                "3500 kg",
                "6000 kg",
                "1- 1850 kg",
                "2- 2000 kg"
            ]
        )

        XCTAssertEqual(suggestions.manufacturer, "Rapido")
        XCTAssertEqual(suggestions.vinChassisNumber, "ZFA25000002950575")
        XCTAssertEqual(suggestions.gtwKg, 6000)
    }

    func testSuggestionsReadFINLabelOnFollowingLine() {
        let suggestions = VehiclePlateOCR.suggestions(
            from: [
                "FIN",
                "WHB12345HYA123456",
                "STUTZLAST 80"
            ]
        )

        XCTAssertEqual(suggestions.vinChassisNumber, "WHB12345HYA123456")
        XCTAssertEqual(suggestions.manufacturer, "Hobby")
        XCTAssertEqual(suggestions.hitchOrNoseKg, 80)
    }
}
