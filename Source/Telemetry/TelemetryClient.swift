//
//  Airmap_Telemetry.swift
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
import SwiftGRPC

class TelemetryClient {

	func sendTelemetry(flight: AirMapFlightId, report: Airmap_Telemetry.Report) {
		reports.onNext((flight, report))
	}

	private typealias FlightReport = (flightId: AirMapFlightId, report: Airmap_Telemetry.Report)

	private let reports = PublishSubject<FlightReport>()
	private let disposeBag = DisposeBag()
	private let scheduler = MainScheduler.instance

	init() {

		let channel = Channel(
			address: "localhost:7090",
			secure: false,
			arguments: []
		)
		let client = Airmap_TelemetryProviderServiceClient(channel: channel)
		let call = try! client.connectUpdates(completion: nil)

		let channelState = Observable<Channel.ConnectivityState>.create { (observer) -> Disposable in
			channel.subscribe { (state) in
				observer.onNext(state)
			}
			return Disposables.create()
		}

		let spatial = reports
			.filter(TelemetryClient.isSpatialReport)
			.throttle(Constants.Airmap_Telemetry.SampleRate.spatial, scheduler: scheduler)

		let atmospheric = reports
			.filter(TelemetryClient.isAtmosphericReport)
			.throttle(Constants.Airmap_Telemetry.SampleRate.atmospheric, scheduler: scheduler)

		let updates = Observable
			.merge(spatial, atmospheric)
			.map(TelemetryClient.trafficUpdate)

		let channelReady = channelState
			.debug("Channel State")
			.filter(.ready)

		channelReady
			.flatMapLatest { (_) -> Observable<Void> in
				updates
					.flatMap(call.send)
					.debug("send")
					.ignoreErrors()
					.takeUntil(channelState)
			}
			.subscribe()
			.disposed(by: disposeBag)
	}
}

extension TelemetryClient {

	private static func isSpatialReport(flightReport: FlightReport) -> Bool {
		if let details = flightReport.report.details, case .spatial = details { return true } else { return false }
	}

	private static func isAtmosphericReport(flightReport: FlightReport) -> Bool {
		if let details = flightReport.report.details, case .atmospheric = details { return true } else { return false }
	}

	private static func trafficUpdate(from next: FlightReport) -> Airmap_Telemetry.Update.FromClient {
		return .with({ (update) in
			update.submitted = .init(date: Date())
			update.flight = Airmap_FlightId.with({ $0.asString = next.flightId.rawValue })
			update.reports = [next.report]
		})
	}
}
