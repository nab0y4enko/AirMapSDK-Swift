//
//  AirMapStatusAdvisoryPowerPlantProperties.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 7/11/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper

open class AirMapStatusAdvisoryPowerPlantProperties: AdvisoryProperties {

	open var technology: String?
	open var generatorType: String?
	open var output: Int?

	public required init?(map: Map) {}
}

extension AirMapStatusAdvisoryPowerPlantProperties: Mappable {

	public func mapping(map: Map) {
		technology          <- map["tech"]
		generatorType		<- map["generator_type"]
		output				<- map["output"]
	}
}
