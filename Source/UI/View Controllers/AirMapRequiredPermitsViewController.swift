//
//  AirMapRequiredPermitsViewController.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 7/18/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import RxSwift
import RxCocoa
import RxDataSources

/// Displays a list of organizations that require a permit and selected permits for each, if any.
class AirMapRequiredPermitsViewController: UIViewController {
	
	@IBOutlet weak var permitComplianceStatus: UILabel!
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var nextButton: UIButton!
	
	private var permittableAdvisories = Variable([AirMapStatusAdvisory]())
	
	override var navigationController: AirMapFlightPlanNavigationController? {
		return super.navigationController as? AirMapFlightPlanNavigationController
	}
	/// The permits that are collectively required by all organizations in the flight area
	private var requiredPermits: Variable<[AirMapAvailablePermit]> {
		return navigationController!.requiredPermits
	}
	/// The valid permits the user already holds
	private var existingPermits: Variable<[AirMapPilotPermit]> {
		return navigationController!.existingPermits
	}
	/// Any new permits that the user is creating that they don't already hold
	private var draftPermits: Variable<[AirMapPilotPermit]> {
		return navigationController!.draftPermits
	}
	/// The permits that user has selected in order to advance to the next step of the flow
	private var selectedPermits: Variable<[(advisory: AirMapStatusAdvisory, permit: AirMapAvailablePermit, pilotPermit: AirMapPilotPermit)]> {
		return navigationController!.selectedPermits
	}

	private typealias RowData = (advisory: AirMapStatusAdvisory, availablePermit: AirMapAvailablePermit?, pilotPermit: AirMapPilotPermit?)
	private let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<AirMapStatusAdvisory, RowData>>()
	private let activityIndicator = ActivityIndicator()
	private let disposeBag = DisposeBag()
	
	// MARK: - View Lifecycle

	override func viewDidLoad() {
		super.viewDidLoad()
		
		loadData()
		setupBindings()
		setupTableView()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
//		tableView.indexPathsForSelectedRows?.forEach { indexPath in
//			if let row = try? tableView.rx_modelAtIndexPath(indexPath) as RowData
//				where row.pilotPermit == nil {
//				tableView.deselectRowAtIndexPath(indexPath, animated: true)
//			}
//		}
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		guard let identifier = segue.identifier else { return }
		
		switch identifier {
			
		case "modalPermitSelection":
			break
		default:
			break
		}
	}

	@IBAction func unwindToRequiredPermits(segue: UIStoryboardSegue) { /* Hook for Interface Builder; keep. */ }
	
	// MARK: - Setup
	
	private func setupTableView() {
		
		tableView.rx_setDelegate(self)
		
		dataSource.configureCell = { dataSource, tableView, indexPath, rowData in
			
			if let availablePermit = rowData.availablePermit, let pilotPermit = rowData.pilotPermit {
				return tableView.cellWith((availablePermit, pilotPermit), at: indexPath) as AirMapPilotPermitCell
			} else {
				let cell = tableView.dequeueReusableCellWithIdentifier("selectADifferencePermit", forIndexPath: indexPath)
				cell.textLabel?.text = indexPath.row == 0 ? "Select Permit" : "Select a different Permit"
				return cell
			}
		}
		
		dataSource.titleForHeaderInSection = { dataSource, section in
			return dataSource.sectionAtIndex(section).model.name
		}
	}
	
	private func setupBindings() {
		
		Observable.combineLatest(requiredPermits.asObservable(), existingPermits.asObservable(), draftPermits.asObservable(), permittableAdvisories.asObservable()) { ($0, $1, $2, $3) }
			.observeOn(MainScheduler.instance)
			.map(unowned(self, AirMapRequiredPermitsViewController.sectionModels))
			.bindTo(tableView.rx_itemsWithDataSource(dataSource))
			.addDisposableTo(disposeBag)
		
		Observable.combineLatest(selectedPermits.asObservable(), permittableAdvisories.asObservable()) { ($0, $1) }
			.observeOn(MainScheduler.instance)
			.doOnNext { [weak self] selected, advisories in
				self?.permitComplianceStatus.text = "You have selected \(selected.count) of \(advisories.count) permits required for this flight"
			}
			.map { $0.count == $1.count }
			.bindTo(nextButton.rx_enabled)
			.addDisposableTo(disposeBag)
		
		activityIndicator.asObservable()
			.throttle(0.25, scheduler: MainScheduler.instance)
			.distinctUntilChanged()
			.bindTo(rx_loading)
			.addDisposableTo(disposeBag)
	}
	
	private func loadData() {
		
//		AirMap
//			.rx_listPilotPermits()
//			.trackActivity(activityIndicator)
//			.map(unowned(self, AirMapRequiredPermitsViewController.filterOutInvalidPermits))
//			.bindTo(existingPermits)
//			.addDisposableTo(disposeBag)

		permittableAdvisories.value = navigationController!.status.value!.advisories.filter { advisory in
			advisory.requirements?.permitsAvailable.count > 0
		}
		
		requiredPermits.value = permittableAdvisories.value
			.flatMap { $0.requirements!.permitsAvailable }
	}
	
	private func filterOutInvalidPermits(permits: [AirMapPilotPermit]) -> [AirMapPilotPermit] {
		
		return permits
			.filter { $0.permitDetails.singleUse != true }
			.filter { $0.status != .Rejected }
	}
	
	func availablePermit(from permit: AirMapPilotPermit) -> AirMapAvailablePermit? {
		return requiredPermits.value.filter { $0.id == permit.permitId }.first
	}
	
	// MARK: - Instance Methods
	
	private func sectionModels(requiredPermits: [AirMapAvailablePermit], existingPermits: [AirMapPilotPermit], draftPermits: [AirMapPilotPermit], advisories: [AirMapStatusAdvisory]) -> [SectionModel<AirMapStatusAdvisory, RowData>] {
		
		return advisories.map { advisory in
			
			// Existing permits from the user's permit wallet
			let existingPermitRows: [RowData] = existingPermits
				.filter { requiredPermits.map{ $0.id }.contains($0.permitId) }
				.map { (advisory: advisory, availablePermit: availablePermit(from: $0), pilotPermit: $0) }
			
			// All new permits that have been drafted during this flow
			let draftPermitRows: [RowData] = draftPermits
				.filter { requiredPermits.map{ $0.id }.contains($0.permitId) }
				.map { (advisory: advisory, availablePermit: availablePermit(from: $0), pilotPermit: $0) }
			
			// A new row for selecting a permit not perviously drafted or acquired
			let newPermitRow: RowData = (advisory: advisory, availablePermit: nil, pilotPermit: nil)
			
			return SectionModel(model: advisory, items: existingPermitRows + draftPermitRows + [newPermitRow])
		}
	}
	
	private func uncheckRowsInSection(section: Int) {
		for index in 0..<dataSource.sectionAtIndex(section).items.count-1 {
			let ip = NSIndexPath(forRow: index, inSection: section)
			tableView.cellForRowAtIndexPath(ip)?.accessoryType = .None
		}
	}
	
}

extension AirMapRequiredPermitsViewController: AirMapPermitDecisionFlowDelegate {
	
	func decisionFlowDidSelectPermit(permit: AirMapAvailablePermit, requiredBy advisory: AirMapStatusAdvisory, with customProperties: [AirMapPilotPermitCustomProperty]) {
		
		let draftPermit = AirMapPilotPermit()
		draftPermit.permitId = permit.id
		draftPermit.customProperties = customProperties

		let matchingDraftPermits = draftPermits.value
			.filter { $0.permitId == draftPermit.permitId }
		
		let matchingExistingPermits = existingPermits.value
			.filter { $0.permitId == draftPermit.permitId }

		let matchingSelectedAdvisoryPermits = selectedPermits.value
			.filter { $0.advisory.id == advisory.id }
		
		if matchingDraftPermits.count == 0 && matchingExistingPermits.count == 0 {
			draftPermits.value.append(draftPermit)
		}

		selectedPermits.value = selectedPermits.value.filter {
			let permitIds = matchingSelectedAdvisoryPermits.map { $0.permit.id }
			return !permitIds.contains($0.permit.id)
		}
		selectedPermits.value.append((advisory: advisory, permit: permit, pilotPermit: draftPermit))
		tableView.reloadData()
	}
}

extension AirMapRequiredPermitsViewController: UITableViewDelegate {
	
	func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let header = TableHeader(dataSource.sectionAtIndex(section).model.name)!
		header.textLabel.textAlignment = .Center
		header.textLabel.font = UIFont.boldSystemFontOfSize(17)
		return header
	}
	
	func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 45
	}
	
	func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
		
		guard
			let row = try? dataSource.modelAtIndexPath(indexPath) as? RowData,
			let rowAdvisory = row?.advisory,
			let availablePermit = row?.availablePermit,
			let pilotPermit = row?.pilotPermit else { return }
		
		if selectedPermits.value.filter ({$0.permit.id == pilotPermit.permitId && $0.advisory.id == rowAdvisory.id }).first != nil {
			cell.accessoryType = .Checkmark
		} else {
			cell.accessoryType = .None
		}
	}
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
				
		tableView.deselectRowAtIndexPath(indexPath, animated: false)
		
		if let row = try? dataSource.modelAtIndexPath(indexPath) as? RowData,
			let rowAdvisory = row?.advisory,
			let availablePermit = row?.availablePermit,
			let pilotPermit = row?.pilotPermit {
			
			if let alreadySelectedPermit = selectedPermits.value.filter({$0.permit.id == pilotPermit.permitId && $0.advisory.id == rowAdvisory.id}).first {
				selectedPermits.value = selectedPermits.value.filter { $0 != alreadySelectedPermit }
				tableView.cellForRowAtIndexPath(indexPath)?.accessoryType = .None
			} else {
				uncheckRowsInSection(indexPath.section)
				if let previousSelectedAdvisoryPermit = selectedPermits.value.filter({$0.advisory.id == rowAdvisory.id}).first {
					selectedPermits.value = selectedPermits.value.filter { $0 != previousSelectedAdvisoryPermit }
				}
				
				let availablePermit = requiredPermits.value.filter {$0.id == pilotPermit.permitId }.first!
				selectedPermits.value.append((advisory: rowAdvisory, permit: availablePermit, pilotPermit: pilotPermit))
				tableView.cellForRowAtIndexPath(indexPath)?.accessoryType = .Checkmark
			}
		}
	}
	
}
