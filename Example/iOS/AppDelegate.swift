//
//  AppDelegate.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 06/27/2016.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import UIKit
import AirMap
import RxSwift
import RxSwiftExt

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	let disposeBag = DisposeBag()

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

		AirMap.rx
			.performAnonymousLogin(userId: "adolfo").mapToVoid()
			.flatMapLatest(AirMap.rx.getCurrentAuthenticatedPilotFlight)
			.flatMapLatest { (active) -> Observable<AirMapFlight> in
				if let active = active {
					return Observable.of(active)
				} else {
					let flight = AirMapFlight()
					flight.coordinate = Coordinate2D(latitude: 34, longitude: -118)
					flight.buffer = 100
					return AirMap.rx.createFlight(flight)
				}
			}
			.flatMapLatest { (flight) -> Observable<AirMapFlight> in
				Observable<Int>
					.timer(0, period: 1, scheduler: MainScheduler.instance)
					.mapTo(flight)
			}
			.subscribe(onNext: { (flight) in
				flight.coordinate.latitude += 0.001
				flight.coordinate.longitude += 0.001
				try! AirMap.sendPositionalTelemetry(
					flight.id!,
					coordinate: flight.coordinate,
					altitude: AirMap.Altitude(height: 10, reference: .ground),
					velocity: nil,
					orientation: nil
				)
			}, onError: { (error) in
				print(error.localizedDescription)
			})
			.disposed(by: disposeBag)

		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

}
