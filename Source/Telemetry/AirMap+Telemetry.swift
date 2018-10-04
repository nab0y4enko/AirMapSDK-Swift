//
//  AirMap+Telemetry.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 6/28/16.
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
import SwiftProtobuf

extension AirMap {

	// MARK: - Telemetry

	public enum TelemetryError: Error {
		case invalidCredentials
		case invalidData
		case failedToConnectToService
		case failedToReceiveAcknowledgements
		case failedToSendUpdates
	}

	public typealias Altitude = (height: Meters, reference: AltitudeReference)
	public typealias Velocity = (x: Float, y: Float, z: Float)
	public typealias Orientation = (yaw: Float, pitch: Float, roll: Float)

	public enum AltitudeReference {
		case Ground
		case GPS
		case MeanSeaLevel
	}

	/// Send positional telemetry to AirMap
	///
	/// - Parameters:
	///   - id: The identifier for the `AirMapFlight` to report telemetry data for
	///   - coordinate: The latitude & longitude of the aircraft
	///   - altitude: The height and reference of the aircraft in meters
	///   - velocity: A tuple of axis velocities (X,Y,Z) using the N-E-D (North-East-Down) coordinate system
	///   - orientation: The yaw, pitch, roll of the aircraft.
	///     Yaw: angle in degrees measured from True North (0 <= x < 360).
	///     Pitch: The angle (up-down tilt) in degrees up or down relative to the forward horizon (-180 < x <= 180)
	///     Roll: The angle (left-right tilt) in degrees (-180 < x <= 180)
	/// - Throws: TelemetryError.invalidCredentials if the user is unable to send telemtry
	public static func sendPositionalTelemetry(_ id: AirMapFlightId, coordinate: Coordinate2D, altitude: Altitude, velocity: Velocity?, orientation: Orientation?) throws {
		
		try canSendTelemetry()

		telemetryClient.sendTelemetry(flight: id, report: AirMapTelemetry.Report.with { (report) in
			report.observed = .init(date: Date())
			report.details = .spatial(AirMapTelemetry.Report.Spatial.with { (spatial) in
				spatial.position = AirMapPosition.with({ (pos) in
					pos.coordinate = AirMapCoordinate2D.with({ (coord) in
						coord.latitude = AirMapDegrees.with({ $0.value = coordinate.latitude })
						coord.longitude = AirMapDegrees.with({ $0.value = coordinate.longitude })
					})
					pos.altitude = AirMapAltitude.with { (alt) in
						alt.height = AirMapMeters.with ({ $0.value = altitude.height })
						switch altitude.reference {
						case .Ground:
							alt.reference = .surface
						case .GPS:
							alt.reference = .ellipsoid
						case .MeanSeaLevel:
							alt.reference = .geoid
						}
					}
				})
				if let velocity = velocity {
					spatial.velocity = AirMapVelocity.with({ (v) in
						v.x = AirMapMetersPerSecond.with({ $0.value = Double(velocity.x) })
						v.y = AirMapMetersPerSecond.with({ $0.value = Double(velocity.y) })
						v.z = AirMapMetersPerSecond.with({ $0.value = Double(velocity.z) })
					})
				}
				if let orientation = orientation {
					spatial.orientation = AirMapOrientation.with({ (orien) in
						orien.yaw   = AirMapDegrees.with{ $0.value = Double(orientation.yaw)}
						orien.pitch = AirMapDegrees.with{ $0.value = Double(orientation.pitch)}
						orien.roll  = AirMapDegrees.with{ $0.value = Double(orientation.roll)}
					})
				}
			})
		})
	}

	/// Send atmospheric telemetry to AirMap
	///
	/// - Parameters:
	///   - id: The identifier for the `AirMapFlight` to report telemetry data for
	///   - coordinate: The latitude & longitude of the aircraft
	///   - altitude: The height and reference of the aircraft in meters
	///   - baro: The barometric pressure in Pascals (~100,000 Pa)
	///   - temperature: The ambient temperature in degrees Celsius (C°)
	/// - Throws: TelemetryError.invalidCredentials if the user is unable to send telemtry
	public static func sendAtmosphericTelemetry(_ id: AirMapFlightId, coordinate: Coordinate2D, altitude: Altitude?, baro: Double?, temperature: Double?) throws {
		
		try canSendTelemetry()

		guard baro != nil || temperature != nil else {
			throw TelemetryError.invalidData
		}

		telemetryClient.sendTelemetry(flight: id, report: AirMapTelemetry.Report.with { (report) in
			report.observed = .init(date: Date())
			report.details = AirMapTelemetry.Report.OneOf_Details.atmospheric(AirMapTelemetry.Report.Atmospheric.with({ (atmos) in
				atmos.position = AirMapPosition.with({ (pos) in
					pos.coordinate = AirMapCoordinate2D.with({ (coord) in
						coord.latitude = AirMapDegrees.with({ $0.value = coordinate.latitude })
						coord.longitude = AirMapDegrees.with({ $0.value = coordinate.longitude })
					})
				})
				if let altitude = altitude {
					atmos.position.altitude = AirMapAltitude.with { (alt) in
						alt.height = AirMapMeters.with ({ $0.value = altitude.height })
						switch altitude.reference {
						case .Ground:
							alt.reference = .surface
						case .GPS:
							alt.reference = .ellipsoid
						case .MeanSeaLevel:
							alt.reference = .geoid
						}
					}
				}
				if let baro = baro {
					atmos.pressure = AirMapPressure.with({ (press) in
						press.units = AirMapPascal.with({ $0.value = baro })
					})
				}
				if let temperature = temperature {
					atmos.temperature = AirMapTemperature.with({ (temp) in
						temp.degrees = AirMapCelsius.with({ $0.value = temperature})
					})
				}
			}))
		})
	}
	
	/// Verify the user can send telemetry data
	///
	/// - Throws: TelemetryError.invalidCredentials if the user is unable to send telemtry
	fileprivate static func canSendTelemetry() throws {
		guard AirMap.hasValidCredentials() else {
			logger.error(self, "Please login before sending telemetry data.")
			throw TelemetryError.invalidCredentials
		}
	}
	
}
