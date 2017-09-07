//
//  AirMapTelemetry.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 12/5/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import ProtocolBuffers
import CryptoSwift
import RxSwift

struct AirMapTelemetry {
	
	class Client {
		
		func sendTelemetry(_ flight: AirMapFlight, message: ProtoBufMessage) {
			telemetry.onNext((flight, message))
		}
		
		private let telemetry = PublishSubject<(flight: AirMapFlight, message: ProtoBufMessage)>()
		private let disposeBag = DisposeBag()

		private let bgScheduler = ConcurrentDispatchQueueScheduler(qos: .background)
		private let serialScheduler = SerialDispatchQueueScheduler(internalSerialQueueName: "com.airmap.telemetry.client.serialqueue")
		
		init() {
			setupBindings()
		}
		
		private func setupBindings() {
			
			let latestFlight = telemetry.map { $0.flight }.distinctUntilChanged()
			
			let session = latestFlight
				.flatMap { flight in
					AirMap.flightClient.getCommKey(for: flight)
						.catchError({ (error) -> Observable<CommKey> in
							AirMap.logger.error("Failed to acquire encryption key for flight telemetry", error)
							return .empty()
						})
						.map { Session(flight: flight, commKey: $0) }
				}
				.observeOn(serialScheduler)

			let flightMessages = Observable
				.combineLatest(session, telemetry) { $0 }
				.observeOn(bgScheduler)
				.filter { flightSession, telemetry in
					telemetry.flight == flightSession.flight
				}
				.map { (session: Session, telemetry: (flight: AirMapFlight, message: ProtoBufMessage)) in
					(session: session, message: telemetry.message)
				}
				.share()

			let rate = Constants.AirMapTelemetry.SampleRate.self
			
			let position = flightMessages
				.filter { $0.1 is Airmap.Telemetry.Position }
				.throttle(rate.position, scheduler: bgScheduler)
			
			let attitude = flightMessages
				.filter { $0.1 is Airmap.Telemetry.Attitude }
				.throttle(rate.attitude, scheduler: bgScheduler)

			let speed = flightMessages
				.filter { $0.1 is Airmap.Telemetry.Speed }
				.throttle(rate.speed, scheduler: bgScheduler)
			
			let barometer = flightMessages
				.filter { $0.1 is Airmap.Telemetry.Barometer }
				.throttle(rate.barometer, scheduler: bgScheduler)
			
			Observable.from([position, attitude, speed, barometer]).merge()
				.buffer(timeSpan: 1, count: 20, scheduler: bgScheduler)
				.observeOn(serialScheduler)
				.subscribe(onNext: Client.sendMessages)
				.disposed(by: disposeBag)
		}
		
		private static func sendMessages(_ telemetry: [(session: Session, message: ProtoBufMessage)]) {
            
            guard let session = telemetry.first?.session else { return }
            
			let messages = telemetry.map { $0.message }
			session.send(messages)
		}
	}
	
	class Session {
		
		let flight: AirMapFlight
		let commKey: CommKey

		private static let serialQueue = DispatchQueue(label: "com.airmap.telemetry.session.serialqueue")

		private static var socket = Socket(socketQueue: serialQueue)
		
		private let encryption = Packet.EncryptionType.aes256cbc
		private var serialNumber: UInt32 = 0
				
		init(flight: AirMapFlight, commKey: CommKey) {
			self.flight = flight
			self.commKey = commKey
		}
		
		func send(_ messages: [ProtoBufMessage]) {

			let payload = messages.flatMap { msg in msg.telemetryBytes() }
			let packet: Packet
			let serial = nextPacketId()
			guard let flightId = flight.id else { return }
			
			switch encryption {
			case .aes256cbc:
				let iv = AirMapTelemetry.generateIV()
				let key = commKey.bytes()
				let encryptedPayload = try! AES(key: key, iv: iv, blockMode: .CBC).encrypt(payload)

				packet = Packet(
					serial: serial, flightId: flightId, payload: encryptedPayload,
					encryption: encryption, iv: iv
				)
			case .none:
				packet = Packet(
					serial: serial, flightId: flightId, payload: payload,
					encryption: encryption, iv: []
				)
			}

			let data = Data(bytes: packet.bytes())
			Session.socket.sendData(data)
		}
		
		private func nextPacketId() -> UInt32 {
			Session.serialQueue.sync {
				serialNumber += 1
			}
			return serialNumber
		}
	}

	class Socket: GCDAsyncUdpSocket {
		
		var host = Constants.AirMapTelemetry.host
		var port = Constants.AirMapTelemetry.port

		func sendData(_ data: Data) {
			send(data, toHost: host, port: port, withTimeout: 15, tag: 0)
		}
	}
	
	struct Packet {
		
		enum EncryptionType: UInt8 {
			case none = 0 // Unsupported by backend; for local testing only
			case aes256cbc = 1
		}

		let serial: UInt32
		let flightId: String
		let payload: [UInt8]
		let encryption: EncryptionType
		let iv: [UInt8]
		
		func bytes() -> [UInt8] {
			
			let id = flightId.data(using: .utf8)!.bytes
			var header = [UInt8]()
			header += serial.bigEndian.bytes
			header += UInt8(id.count).bytes
			header += id
			header += encryption.rawValue.bytes
			
			switch encryption {
			case .aes256cbc:
				assert(iv.count == 16)
				header += iv
			case .none:
				break
			}
			
			return header + payload
		}
	}
	
	static func generateIV() -> [UInt8] {
		
		return AES.randomIV(AES.blockSize)
	}
	
}
