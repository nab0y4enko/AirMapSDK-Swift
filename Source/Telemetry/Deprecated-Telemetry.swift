//
//  Deprecated-Telemetry.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 9/28/18.
//

import Foundation

extension AirMap {
	@available (*, unavailable, message: "Use AirMap.sendFlightTelemetry)")
	public static func sendTelemetryData(_ flightId: AirMapFlightId, coordinate: Coordinate2D, altitudeAgl: Double?, altitudeMsl: Double?, horizontalAccuracy: Float? = nil) throws {}
}
