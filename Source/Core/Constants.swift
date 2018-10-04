//
//  Config.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 6/24/16.
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

#if os(iOS) || os(tvOS)
    import UIKit.UIDevice
#endif

import ObjectMapper

struct Constants {

	struct AirMapApi {

		static var advisoryUrl: String {
			return urlForResource("advisory", v: 1)
		}
		static var aircraftUrl: String {
            return urlForResource("aircraft", v: 2)
		}
		static var airspaceUrl: String {
			return urlForResource("airspace", v: 2)
		}
		static var authUrl: String {
			return urlForResource("auth", v: 1)
		}
		static var flightUrl: String {
            return urlForResource("flight", v: 2)
		}
		static var tileDataUrl: String {
			return urlForResource("tiledata", v: 1)
		}
		static var pilotUrl: String {
			return urlForResource("pilot", v: 2)
		}
		static var rulesUrl: String {
			return urlForResource("rules", v: 1)
		}
		
		private static func urlForResource(_ named: String, v version: Int) -> String {
			if let override = AirMap.configuration.airMapApiOverrides?[named] {
				return override
			} else {
				let host = "https://\(AirMap.configuration.airMapApiDomain)"
				let path = "/\(named)/\(AirMap.configuration.airMapEnvironment ?? "v\(version)")"
				return host + path
			}
		}
		
		struct Auth {
			static let scope = AirMap.configuration.auth0Scope
			static let grantType = "urn:ietf:params:oauth:grant-type:jwt-bearer"
			static let keychainKeyRefreshToken = "com.airmap.airmapsdk.refresh_token"
			static let termsOfServiceUrl = "https://www.\(AirMap.configuration.airMapDomain)/terms"
			static let privacyPolicyUrl = "https://www.\(AirMap.configuration.airMapDomain)/privacy"
		}
		
		// Used only for API date formatting
		static let dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ" // Ex: 2016-06-30T16:54:17.606Z
		static let dateTransform = CustomDateFormatTransform(formatString: dateFormat)

		static let smsCodeLength = 6
	}

	struct AirMapTelemetry {
		static var host: String {
			if let override = AirMap.configuration.airMapApiOverrides?["telemetry_host"] {
				return override
			}
            if let env = AirMap.configuration.airMapEnvironment {
                return "api-udp-telemetry.\(env).\(AirMap.configuration.airMapDomain)"
			} else {
				return "api-udp-telemetry.\(AirMap.configuration.airMapDomain)"
			}
		}
		
		static var port: UInt16 {
			if let override = AirMap.configuration.airMapApiOverrides?["telemetry_port"], let port = UInt16(override) {
				return port
			}
			return 16060
		}
		
		struct SampleRate {
			static let position: TimeInterval = 1/5
			static let atmospheric: TimeInterval = 5
		}
	}

	struct AirMapTraffic {
		static var host: String {
			let env = AirMap.configuration.airMapEnvironment ?? "prod"
			return "mqtt-\(env).airmap.io"
		}
		static let port = UInt16(8883)
		static let keepAlive = UInt16(15)
		static let expirationInterval = TimeInterval(30)
		static let trafficAlertChannel = "uav/traffic/alert/"
		static let trafficSituationalAwarenessChannel = "uav/traffic/sa/"
		#if os(OSX)
		static let clientId = UUID().uuidString
		#else
		static let clientId = UIDevice.current.identifierForVendor!.uuidString
		#endif
	}

	struct Maps {
		static let jurisdictionsTileSourceId = "jurisdictions"
		static let jurisdictionsStyleLayerId = "jurisdictions"
		static let jurisdictionFeatureAttributesKey = "jurisdiction"
		static let airmapLayerPrefix = "airmap"
        static let rulesetSourcePrefix = "air_ruleset_"
        static let tileMinimumZoomLevel = 7
        static let tileMaximumZoomLevel = 12
        static let temporalLayerRefreshInterval: TimeInterval = 20
        static let futureTemporalWindow: TimeInterval = 4*60*60 // 4 hours
		
		static var styleUrl: URL {
			return AirMap.configuration.airMapMapStyle ?? URL(string: "https://cdn.airmap.com/static/map-styles/0.8.6/")!
		}
	}
}
