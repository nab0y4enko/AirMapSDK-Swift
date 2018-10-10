//
//  Telemetry+Rx.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 10/4/18.
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

extension Airmap_TelemetryProviderServiceClient {

	func connectUpdates() -> Observable<Airmap_TelemetryProviderConnectUpdatesCall> {
		return Observable<Airmap_TelemetryProviderConnectUpdatesCall>.create { (observer) -> Disposable in
			do {
				var call: Airmap_TelemetryProviderConnectUpdatesCall?
				call = try self.connectUpdates() { (result) in
					switch result.statusCode {
					case .ok:
						observer.onNext(call!)
					default:
						AirMap.logger.error(result.statusCode)
						observer.onError(AirMap.TelemetryError.failedToConnectToService)
					}
				}
			} catch {
				observer.onError(error)
			}
			return Disposables.create()
		}
	}
}

extension Airmap_TelemetryProviderConnectUpdatesCall {

	func send(message: Airmap_Telemetry.Update.FromClient) -> Observable<Void> {
		return Observable<Void>
			.create({ (observer) -> Disposable in
				do {
					try self.send(message, timeout: DispatchTime.now() + 10)
					observer.onNext(())
				}
				catch {
					observer.onError(error)
				}
				return Disposables.create {
					self.cancel()
				}
			})
	}

	func receive() -> Observable<Airmap_Telemetry.Update.FromService> {
		return Observable<Airmap_Telemetry.Update.FromService>
			.create({ (observer) -> Disposable in
				var work: DispatchWorkItem?
				work = DispatchWorkItem(qos: .utility, flags: []) {
					while true {
						do {
							try self.receive(completion: { (result) in
								switch result {
								case let .error(error):
									observer.onError(error)
									break
								case let .result(element):
									if let element = element {
										observer.onNext(element)
									}
								}
							})
						}
						catch {
							observer.onError(AirMap.TelemetryError.failedToReceiveAcknowledgements)
							break
						}
					}
				}
				return Disposables.create {
					work?.cancel()
				}
			})
	}
}
