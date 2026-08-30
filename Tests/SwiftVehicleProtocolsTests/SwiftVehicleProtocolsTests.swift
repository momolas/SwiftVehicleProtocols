import Testing
import Foundation
@testable import SwiftVehicleProtocols

@Suite("SwiftVehicleProtocols Unit Tests")
struct SwiftVehicleProtocolsTests {

    @Test("Hex Parsing & Formatting")
    func testHexParsing() {
        let bytes = HexParsing.bytes("62 01 02 FF")
        #expect(bytes == [0x62, 0x01, 0x02, 0xFF])
        #expect(HexParsing.bytes("123") == nil)
        #expect(HexParsing.hex([0x00, 0x7E, 0x80, 0xFF]) == "007E80FF")
    }

    @Test("Formula Evaluator Fast Paths & JavaScript")
    func testFormulaEvaluator() {
        let evaluator = FormulaEvaluator()
        #expect(evaluator.evaluate(formula: "A", bytes: [0x42]) == 66.0)
        #expect(evaluator.evaluate(formula: "(A*256+B)/4", bytes: [0x0B, 0xB8]) == 750.0)
        #expect(evaluator.evaluate(formula: "A-40", bytes: [0x78]) == 80.0)
        #expect(evaluator.evaluate(formula: "A AND 15", bytes: [0xF3]) == 3.0)
    }

    @Test("UDS NRC Parsing")
    func testUDSNRC() {
        let nrcResult = UDSNRC.parse(from: "7F1022")
        #expect(nrcResult != nil)
        #expect(nrcResult?.nrc == .conditionsNotCorrect)
        #expect(nrcResult?.requestedServiceID == 0x10)
        #expect(nrcResult?.title == "Conditions Non Remplies")
    }

    @Test("SecurityAccess Seed & Key Calculation")
    func testSecurityAccess() {
        let keyXor = SecurityAccessManager.calculateKey(seedHex: "12 34", algorithm: .xorStatique, maskHex: "5A 5A")
        #expect(keyXor == "486E")

        let keyRenault = SecurityAccessManager.calculateKey(seedHex: "12 34", algorithm: .renaultStandard, maskHex: "5A 5A")
        #expect(!keyRenault.isEmpty)
    }

    @Test("ISO-TP Multi-Frame Reassembly")
    func testISOTPReassembly() async {
        let reassembler = ISOTPReassembler()

        // 1. Single frame
        let sf = await reassembler.processFrame(address: 0x7E8, data: Data([0x03, 0x22, 0x01, 0x02, 0xAA, 0xAA, 0xAA, 0xAA]))
        #expect(sf == .completed(Data([0x22, 0x01, 0x02])))

        // 2. First frame
        let ff = await reassembler.processFrame(address: 0x7E8, data: Data([0x10, 0x0C, 0x62, 0x01, 0x02, 0x03, 0x04, 0x05]))
        #expect(ff == .needsFlowControl)

        // 3. Consecutive frame
        let cf = await reassembler.processFrame(address: 0x7E8, data: Data([0x21, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x00]))
        if case .completed(let payload) = cf {
            #expect(payload.count == 12)
        } else {
            Issue.record("Consecutive frame did not complete multi-frame reassembly")
        }
    }

    @Test("Pearson Signal Correlation")
    func testSignalCorrelation() {
        let xs = [1.0, 2.0, 3.0, 4.0, 5.0]
        let ys = [2.0, 4.0, 6.0, 8.0, 10.0]
        let r = SignalCorrelator.pearsonCorrelation(x: xs, y: ys)
        #expect(r != nil)
        #expect(abs((r ?? 0) - 1.0) < 0.001)
    }

    @Test("Freeze Frame KWP Decoding")
    func testFreezeFrameDecoder() {
        let kwpHex = "58 01 02 01 86 A0 0B B8 78 32"
        let decoded = FreezeFrameDecoder.parseKWP(responseHex: kwpHex, dtcCode: "P0102")
        #expect(decoded.timestampKm == 100000)
        #expect(decoded.rpm == 750)
        #expect(decoded.coolantTemp == 80)
        #expect(decoded.vehicleSpeed == 50)
    }

    @Test("Simulator Engine Responses")
    func testSimulatorEngine() async throws {
        let sim = SimulatorEngine()
        let sessionResp = try await sim.sendDiagnosticRequest("1085")
        #expect(sessionResp.hasPrefix("5085"))

        let lidResp = try await sim.sendDiagnosticRequest("2100")
        #expect(lidResp.contains("61"))
    }

    @Test("SAE J1939 PGN & Signal Decoding")
    func testJ1939Decoding() {
        // Test PGN 61444 (0xF004 - EEC1)
        let canID: UInt32 = 0x0CF00400 // Priority 3, PGN 61444, SA 0
        let header = J1939Header(canID: canID)
        #expect(header.pgn == 61444)
        #expect(header.priority == 3)
        #expect(header.sourceAddress == 0)
        #expect(header.isBroadcast == true)

        let payload = Data([0xFF, 0x00, 0x7D, 0x00, 0x20, 0xFF, 0xFF, 0xFF]) // Torque: 125-125=0%, RPM: 8192*0.125 = 1024 rpm
        let signals = J1939Decoder.decode(pgn: header.pgn, data: payload)
        #expect(!signals.isEmpty)
        if let rpmSignal = signals.first(where: { $0.spn == 190 }) {
            #expect(rpmSignal.value == 1024.0)
        }
    }

    @Test("CAN Protocol Auto-Detection")
    func testProtocolDetection() {
        // 1. J1939 detection (29-bit ID)
        let j1939Class = CANProtocolDetector.detect(canID: 0x18FEEE00)
        #expect(j1939Class.protocolType == .j1939)
        #expect(j1939Class.is29BitExtended == true)

        // 2. OBD-II Broadcast
        let obdClass = CANProtocolDetector.detect(canID: 0x7DF)
        #expect(obdClass.protocolType == .obd2)

        // 3. OBD-II Physical Response
        let respClass = CANProtocolDetector.detect(canID: 0x7E8)
        #expect(respClass.protocolType == .obd2)

        // 4. KWP2000 Legacy Diag
        let kwpClass = CANProtocolDetector.detect(canID: 0x640)
        #expect(kwpClass.protocolType == .kwp2000)

        // 5. Generic CAN
        let genericClass = CANProtocolDetector.detect(canID: 0x120)
        #expect(genericClass.protocolType == .generic)
    }

    @Test("Unified ECU Profile & DDT2000 Conversion")
    func testUnifiedProfileConversion() throws {
        let sampleDDTJSON = """
        {
            "ecuname": "INJECTION_EDC16",
            "obd": {
                "protocol": "CAN",
                "send_id": "7E0",
                "recv_id": "7E8",
                "baudrate": 500000
            },
            "data": {
                "Regime_Moteur": {
                    "bitscount": 16,
                    "step": 0.125,
                    "offset": 0.0,
                    "unit": "tr/min"
                },
                "Relais_Pompe": {
                    "bitscount": 1,
                    "step": 1.0,
                    "offset": 0.0,
                    "unit": ""
                }
            },
            "requests": [
                {
                    "name": "Lecture Télémétrie Moteur",
                    "sentbytes": "2101",
                    "receivebyte_dataitems": {
                        "Regime_Moteur": { "firstbyte": 2, "bitoffset": 0 }
                    }
                },
                {
                    "name": "Test Actionneur Relais",
                    "sentbytes": "300101",
                    "receivebyte_dataitems": {
                        "Relais_Pompe": { "firstbyte": 1, "bitoffset": 0 }
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let profile = try DDT2UnifiedConverter.convert(jsonData: sampleDDTJSON)
        #expect(profile.name == "INJECTION_EDC16")
        #expect(profile.connections.count == 1)
        #expect(profile.connections.first?.txId == "0x7E0")
        #expect(profile.variants.count == 1)

        let variant = try #require(profile.variants.first)
        #expect(variant.downloads.count == 1)
        #expect(variant.actuations.count == 1)

        let jsonExport = try DDT2UnifiedConverter.exportToJSON(profile: profile)
        #expect(jsonExport.contains("INJECTION_EDC16"))
        #expect(jsonExport.contains("Linear"))
    }

    @Test("DTC Decoder (SAE J1979 & KWP2000)")
    func testDTCDecoder() {
        #expect(DTCDecoder.decodeSingleDTC("0102") == "P0102")
        #expect(DTCDecoder.decodeSingleDTC("C100") == "U0100")
        #expect(DTCDecoder.decodeSingleDTC("4101") == "C0101")
        #expect(DTCDecoder.decodeSingleDTC("8100") == "B0100")

        let dtcs = DTCDecoder.decodeDTCList(from: "43 02 01 02 03 00")
        #expect(dtcs == ["P0102", "P0300"])

        let statusPresent = DTCDecoder.decodeKwpDtcStatus(0x80)
        #expect(statusPresent.contains("Présent"))
    }

    @Test("KWP2000 Client Session & Services")
    func testKWP2000Client() async throws {
        let sim = SimulatorEngine()
        let client = await KWP2000Client(interface: sim)

        let sessionResp = try await client.startSession(mode: 0x85)
        #expect(sessionResp.hasPrefix("5085"))

        let lidData = try await client.readLocalIdentifier(lid: 0x00)
        #expect(!lidData.isEmpty)

        await client.stop()
    }

    @Test("VIN Reader & Decoders (OBD2, UDS, KWP2000)")
    func testVINReader() {
        // 1. OBD-II Mode 09 PID 02 (ASCII: VF1JM0G0D12345678)
        let hexOBD2 = "4902015646314A4D304730443132333435363738"
        let obdVIN = VINReader.parseOBD2VIN(hexOBD2)
        #expect(obdVIN == "VF1JM0G0D12345678")

        // 2. UDS DID F190
        let hexUDS = "62F1905646314A4D304730443132333435363738"
        let udsVIN = VINReader.parseUDSVIN(hexUDS)
        #expect(udsVIN == "VF1JM0G0D12345678")

        // 3. KWP2000 LID 81
        let hexKWP = "61815646314A4D304730443132333435363738"
        let kwpVIN = VINReader.parseKWP2000VIN(hexKWP)
        #expect(kwpVIN == "VF1JM0G0D12345678")
    }

    @Test("Standard PIDs Catalog & ECU Liveness")
    func testStandardPidsAndLiveness() async throws {
        #expect(StandardPids.all.count > 40)
        #expect(StandardPids.byPid["0C"]?.displayName == "Engine RPM")

        let sim = SimulatorEngine()
        let isAlive = try await ECULiveness.check(driver: sim)
        #expect(isAlive == true)
    }

    @Test("Profile & Bidirectional Unified Converter")
    func testBidirectionalProfileConverter() {
        let sampleProfile = Profile(
            profileId: "test_profile",
            profileVersion: "1.0",
            displayName: "Test Profile",
            description: "A test profile",
            vehicleMatch: nil,
            ecus: ["main": EcuDef(requestHeader: "7E0", responseHeader: "7E8")],
            pids: [
                PidDef(id: "rpm", displayName: "Engine RPM", ecu: "main", mode: "01", pid: "0C", unit: "rpm", formula: "(A*256+B)/4", category: .rpm)
            ]
        )

        let unified = UnifiedProfileConverter.convert(legacyProfile: sampleProfile)
        #expect(unified.name == "Test Profile")
        #expect(unified.variants.first?.downloads.count == 1)

        let restoredLegacy = UnifiedProfileConverter.toLegacyProfile(unified: unified)
        #expect(restoredLegacy.displayName == "Test Profile")
        #expect(restoredLegacy.pids.count == 1)
    }
}
