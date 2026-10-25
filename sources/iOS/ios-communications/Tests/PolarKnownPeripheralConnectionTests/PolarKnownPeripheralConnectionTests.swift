// Copyright © 2026 Polar Electro Oy. All rights reserved.

import XCTest
import CoreBluetooth
@testable import PolarBleSdk

final class PolarKnownPeripheralConnectionTests: XCTestCase {
    private let expectedDeviceIdentifier = "1DD13F39"

    func testRetrievedExpectedPeripheralOpensDirectWithoutFallback() {
        let peripheralIdentifier = UUID()
        let session = makeSession(address: peripheralIdentifier, deviceIdentifier: expectedDeviceIdentifier)
        var opened: [BleDeviceSession] = []
        var fallbackCount = 0
        var events: [PolarKnownPeripheralConnectionEventKind] = []

        let outcome = PolarKnownPeripheralConnectionRouter.route(
            retrieved: BleKnownPeripheralSession(session: session, peripheralState: .disconnected, sdkSessionCreated: true),
            expectedDeviceIdentifier: expectedDeviceIdentifier,
            requestedPeripheralIdentifier: peripheralIdentifier,
            emit: { events.append($0.kind) },
            openDirect: { opened.append($0) },
            startFallback: { fallbackCount += 1 }
        )

        XCTAssertEqual(outcome, .directOpenRequested)
        XCTAssertEqual(opened.count, 1)
        XCTAssertEqual(fallbackCount, 0)
        XCTAssertEqual(events, [.knownPeripheralRetrieved, .sdkSessionCreatedOrRecovered, .openSessionDirectRequested])
    }

    func testUnavailableKnownPeripheralPreservesFallback() {
        var openedCount = 0
        var fallbackCount = 0
        var events: [PolarKnownPeripheralConnectionEventKind] = []

        let outcome = PolarKnownPeripheralConnectionRouter.route(
            retrieved: nil,
            expectedDeviceIdentifier: expectedDeviceIdentifier,
            requestedPeripheralIdentifier: UUID(),
            emit: { events.append($0.kind) },
            openDirect: { _ in openedCount += 1 },
            startFallback: { fallbackCount += 1 }
        )

        XCTAssertEqual(outcome, .fallbackStarted)
        XCTAssertEqual(openedCount, 0)
        XCTAssertEqual(fallbackCount, 1)
        XCTAssertEqual(events, [.knownPeripheralUnavailable, .scanFallbackStarted])
    }

    func testWrongPolarIdentityIsRejected() {
        let peripheralIdentifier = UUID()
        let session = makeSession(address: peripheralIdentifier, deviceIdentifier: "DEADBEEF")
        var openedCount = 0
        var fallbackCount = 0
        var events: [PolarKnownPeripheralConnectionEventKind] = []

        let outcome = PolarKnownPeripheralConnectionRouter.route(
            retrieved: BleKnownPeripheralSession(session: session, peripheralState: .disconnected, sdkSessionCreated: true),
            expectedDeviceIdentifier: expectedDeviceIdentifier,
            requestedPeripheralIdentifier: peripheralIdentifier,
            emit: { events.append($0.kind) },
            openDirect: { _ in openedCount += 1 },
            startFallback: { fallbackCount += 1 }
        )

        XCTAssertEqual(outcome, .identityRejected)
        XCTAssertEqual(openedCount, 0)
        XCTAssertEqual(fallbackCount, 0)
        XCTAssertEqual(events, [.knownPeripheralRetrieved, .identityMismatch])
    }

    func testAlreadyOpenSessionDoesNotCreateDuplicateOpen() {
        let peripheralIdentifier = UUID()
        let session = makeSession(address: peripheralIdentifier, deviceIdentifier: expectedDeviceIdentifier)
        session.state = .sessionOpen
        var openedCount = 0
        var fallbackCount = 0
        var events: [PolarKnownPeripheralConnectionEventKind] = []

        let outcome = PolarKnownPeripheralConnectionRouter.route(
            retrieved: BleKnownPeripheralSession(session: session, peripheralState: .connected, sdkSessionCreated: false),
            expectedDeviceIdentifier: expectedDeviceIdentifier,
            requestedPeripheralIdentifier: peripheralIdentifier,
            emit: { events.append($0.kind) },
            openDirect: { _ in openedCount += 1 },
            startFallback: { fallbackCount += 1 }
        )

        XCTAssertEqual(outcome, .existingSessionAlreadyActive)
        XCTAssertEqual(openedCount, 0)
        XCTAssertEqual(fallbackCount, 0)
        XCTAssertEqual(events, [.knownPeripheralRetrieved, .sdkSessionCreatedOrRecovered, .existingSessionAlreadyActive])
    }

    func testRouterDoesNotFabricateSDKConnectionCallbacks() {
        let peripheralIdentifier = UUID()
        let session = makeSession(address: peripheralIdentifier, deviceIdentifier: expectedDeviceIdentifier)
        var events: [PolarKnownPeripheralConnectionEventKind] = []

        _ = PolarKnownPeripheralConnectionRouter.route(
            retrieved: BleKnownPeripheralSession(session: session, peripheralState: .disconnected, sdkSessionCreated: true),
            expectedDeviceIdentifier: expectedDeviceIdentifier,
            requestedPeripheralIdentifier: peripheralIdentifier,
            emit: { events.append($0.kind) },
            openDirect: { _ in },
            startFallback: {}
        )

        XCTAssertFalse(events.map(\.rawValue).contains("deviceConnecting"))
        XCTAssertFalse(events.map(\.rawValue).contains("deviceConnected"))
    }

    private func makeSession(address: UUID, deviceIdentifier: String) -> BleDeviceSession {
        let advertisement = BleAdvertisementContent()
        advertisement.processAdvertisementData(
            -20,
            advertisementData: [CBAdvertisementDataLocalNameKey: "Polar H10 \(deviceIdentifier)"]
        )
        return BleDeviceSession(address, advertisementContent: advertisement)
    }
}
