//
//  AirMapTelemetry.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 12/5/16.
//  Copyright 2018 AirMap, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Swift
import RxSwift
import RxSwiftExt

class TelemetryClient {

	func sendTelemetry(flight: AirMapFlightId, report: AirMapTelemetry.Report) {
		reports.onNext((flight, report))
	}

	private typealias FlightReport = (flightId: AirMapFlightId, report: AirMapTelemetry.Report)

	private let reports = PublishSubject<FlightReport>()
	private let disposeBag = DisposeBag()

	private static let scheduler = ConcurrentDispatchQueueScheduler(qos: .background)
	private static let connectRetry = RepeatBehavior.delayed(maxCount: .max, time: 1)
	private static let transceiveRetry = RepeatBehavior.exponentialDelayed(maxCount: 3, initial: 1, multiplier: 2)

	init() {
		let client = AirMapTelemetryProviderServiceClient(address: "udp.telemetry.k8s.airmap.io:7090")
		try! client.metadata.add(key: "x-api-key", value: AirMap.configuration.airMapApiKey)
		try! client.metadata.add(key: "x-bundle-identifier", value: Bundle.main.bundleIdentifier ?? "AirMapSDK-Swift")

		let telemetry = Observable
			.merge(
				reports
					.filter(TelemetryClient.isSpatialReport)
					.throttle(Constants.AirMapTelemetry.SampleRate.position, scheduler: TelemetryClient.scheduler),
				reports
					.filter(TelemetryClient.isAtmosphericReport)
					.throttle(Constants.AirMapTelemetry.SampleRate.atmospheric, scheduler: TelemetryClient.scheduler)
			)
			.map({ (next) -> AirMapTelemetry.Update.FromClient in
				.with({ (update) in
					update.submitted = .init(date: Date())
					update.flight = AirMapFlightId2.with({ $0.asString = next.flightId.rawValue })
					update.reports = [next.report]
				})
			})

		client
			.connectUpdates()
			.flatMap({ (connection) -> Observable<Void> in
				.merge(
					telemetry
						.flatMap(connection.send)
						.retry(TelemetryClient.transceiveRetry),
					connection
						.receive()
						.retry(TelemetryClient.transceiveRetry)
						.mapToVoid()
				)
			})
			.retry(TelemetryClient.connectRetry)
			.subscribe()
			.disposed(by: disposeBag)
	}

	private static func isSpatialReport(flightReport: FlightReport) -> Bool {
		if let details = flightReport.report.details, case .spatial = details { return true } else { return false }
	}

	private static func isAtmosphericReport(flightReport: FlightReport) -> Bool {
		if let details = flightReport.report.details, case .atmospheric = details { return true } else { return false }
	}
}
