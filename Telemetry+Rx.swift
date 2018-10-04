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

extension AirMapTelemetryProviderServiceClient {

	func connectUpdates() -> Observable<AirMapTelemetryProviderConnectUpdatesCall> {
		var call: AirMapTelemetryProviderConnectUpdatesCall?
		return Observable<AirMapTelemetryProviderConnectUpdatesCall>.create { (observer) -> Disposable in
			do {
				call = try self.connectUpdates() { (result) in
					if let call = call, result.success {
						observer.onNext(call)
					} else {
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

extension AirMapTelemetryProviderConnectUpdatesCall {

	func send(message: AirMapTelemetry.Update.FromClient) -> Observable<Void> {
		return Observable<Void>
			.create({ (observer) -> Disposable in
				do {
					try self.send(message) { (error) in
						if let error = error {
							observer.onError(error)
						} else {
							observer.onNext(())
							observer.onCompleted()
						}
					}
				}
				catch {
					observer.onError(error)
				}
				return Disposables.create()
			})
	}

	func receive() -> Observable<AirMapTelemetry.Update.FromService> {
		return Observable<AirMapTelemetry.Update.FromService>
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
