import UIKit
import HealthKit
import HealthKitUI
import MapKit
import SweetUIKit
import SweetSwift

class TableViewController: SweetTableController {
    let apiClient = APIClient()

//    fileprivate var workouts = GroupedDataSource<Date, HKWorkout>() {
//        didSet {
//            DispatchQueue.main.async {
//                self.tableView.reloadData()
//            }
//        }
//    }

    fileprivate lazy var loadingIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)

        view.translatesAutoresizingMaskIntoConstraints = false
        view.hidesWhenStopped = true
        view.tintColor = .blue
        view.startAnimating()

        return view
    }()

    fileprivate var dayData = [DayData]() {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()

                self.loadingIndicator.stopAnimating()
            }
        }
    }

    fileprivate var sleepAnalysis = [SleepAnalysis]() {
        didSet {
            print("Did update sleep analysis.")
        }
    }

    fileprivate var steps = GroupedDataSource<Date, HKStatistics>() {
        didSet {
//            DispatchQueue.main.async {
//                print("Did update step count")
//                self.tableView.reloadData()
//            }
        }
    }

    fileprivate var coalescedEnergy = GroupedDataSource<Date, Energy>() {
        didSet {
            DispatchQueue.main.async {
                self.coalesceData()
            }
        }
    }

    fileprivate var distanceWalked = GroupedDataSource<Date, HKStatistics>() {
        didSet {
//            DispatchQueue.main.async {
//                print("Did update running/walking distances.")
//                self.tableView.reloadData()
//            }
        }
    }

    lazy var dateComponentsFormatter: DateComponentsFormatter = {
        let dcf = DateComponentsFormatter()

        dcf.unitsStyle = .abbreviated
        dcf.allowedUnits = [.hour, .minute, .second]
        dcf.zeroFormattingBehavior = .dropLeading

        return dcf
    }()

    lazy var dateFormatter: DateFormatter = {
        let df = DateFormatter()

        df.dateStyle = .short
        df.timeStyle = .short

        return df
    }()

    let healthStore = HKHealthStore()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.uploadActivities))

        self.title = "HealthStore"

        self.view.addSubview(self.tableView)
        self.view.addSubview(self.loadingIndicator)

        self.loadingIndicator.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        self.loadingIndicator.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true

        self.tableView.fillSuperview()

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(SampleCell.self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.updateActivities()
    }

    private func updateActivities() {
        self.updateSleepAnalysis()
        self.updateEnergy()
        self.updateSteps()
        self.updateWalkingDistance()

        // self.updateWorkoutsWithHeartRateDate()
    }

    private func coalesceData() {
        let calendar = Calendar.autoupdatingCurrent

        // fetch all days with data
        let energyDates = self.coalescedEnergy.values.map({ statistics -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: statistics.basalDataPoint.startDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })

        let sleepDates = self.sleepAnalysis.map({ analysis -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: analysis.endDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })
        let stepsDates = self.steps.values.map({ statistics -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: statistics.startDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })
        let distanceDates = self.distanceWalked.values.map({ statistics -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: statistics.startDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })

        // Dedupe all dates
        var dateSet = Set<Date>()
        dateSet.formUnion(energyDates)
        dateSet.formUnion(sleepDates)
        dateSet.formUnion(stepsDates)
        dateSet.formUnion(distanceDates)

        var dayData: [DayData] = []
        // By storing the data we have to sort through in var arrays
        // we can remove the items as we find them, significantly reducing time necessary
        // to handle all this data.

        var energyArray = self.coalescedEnergy.values
        var stepsArray = self.steps.values
        var sleepArray = self.sleepAnalysis
        var distanceWalkedArray = self.distanceWalked.values

        for date in dateSet.sorted().reversed() {
            let dateData = DayData(date: date)

            for (index, energy) in energyArray.enumerated() {
                if calendar.isDate(energy.basalDataPoint.startDate, inSameDayAs: date) {
                    dateData.energy = energy
                    energyArray.remove(at: index)
                    break
                }
            }


            for (index, steps) in stepsArray.enumerated() {
                if calendar.isDate(steps.startDate, inSameDayAs: date) {
                    dateData.steps = steps
                    stepsArray.remove(at: index)
                    break
                }
            }

            for (index, sleep) in sleepArray.enumerated() {
                if calendar.isDate(sleep.endDate, inSameDayAs: date) {
                    dateData.sleep = sleep
                    sleepArray.remove(at: index)
                    break
                }
            }

            for (index, distance) in distanceWalkedArray.enumerated() {
                if calendar.isDate(distance.startDate, inSameDayAs: date) {
                    dateData.distance = distance
                    distanceWalkedArray.remove(at: index)
                    break
                }
            }

            dayData.append(dateData)
        }

        self.dayData = dayData
    }

    private func updateSleepAnalysis() {
        let sleepAnalysisType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        let sleepAnalysisQuery = HKSampleQuery(sampleType: sleepAnalysisType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in

            guard let samples = samples else { return }

            self.sleepAnalysis = samples.flatMap { sample -> SleepAnalysis? in
                guard let sample = sample as? HKCategorySample else { return nil }

                return SleepAnalysis(state: HKCategoryValueSleepAnalysis(rawValue: sample.value)!, startDate: sample.startDate, endDate: sample.endDate)
            }
        }

        self.healthStore.execute(sleepAnalysisQuery)
    }

    private func updateWalkingDistance() {
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!

        self.executeStatistcsQuery(for: distanceType) { results in
            self.distanceWalked = results
        }
    }

    private func updateEnergy() {
        let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!

        self.executeStatistcsQuery(for: basalEnergyType) { basalEnergy in
            let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

            self.executeStatistcsQuery(for: activeEnergyType) { activeEnergy in
                self.coalesceEnergy(basalEnergy: basalEnergy, activeEnergy: activeEnergy)
            }
        }
    }

    private func coalesceEnergy(basalEnergy: GroupedDataSource<Date, HKStatistics>, activeEnergy: GroupedDataSource<Date, HKStatistics>) {
        let calendar = Calendar.autoupdatingCurrent
        let coalescedEnergy = GroupedDataSource<Date, Energy>()

        // We have days where there's basal energy but no active energy.
        // But there's no way to have active and not basal.
        // Go through every basal energy entry. Get each month:
        for month in basalEnergy.keys {
            // then each individual day with data
            for basalDataPoint in basalEnergy[month] {
                // Skip days where we have no basal data.
                guard basalDataPoint.sumQuantity() != nil else { continue }

                // Look for the active data point in the same day as the basal data.
                let activeDataPoints = activeEnergy[month].filter({ statistics -> Bool in
                    return calendar.isDate(statistics.startDate, inSameDayAs: basalDataPoint.startDate)
                })

                // If we find more then one, something went wrong in our statistics query.
                if activeDataPoints.count > 1 {
                    fatalError("Something went wrong. Statistics should be broken down by the same day.")
                }

                // If there's no active data, set Energy with basal only.
                // Still grouped by months
                if activeDataPoints.isEmpty {
                    coalescedEnergy[month].insert(Energy(basalDataPoint: basalDataPoint), at: 0)
                } else if let activeDataPoint = activeDataPoints.first  {
                    // If there is active energy data, add them both up.
                    coalescedEnergy[month].insert(Energy(activeDataPoint: activeDataPoint, basalDataPoint: basalDataPoint), at: 0)
                }
            }
        }

        self.coalescedEnergy = coalescedEnergy
    }

//    private func updateWorkoutsWithHeartRateDate() {
//        let workoutsQuery = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in
//            guard error == nil else { return }
//
//            if let samples = samples {
//                let watchSamples = samples //.flatMap({ sample -> HKSample? in return sample.sourceRevision.productType?.hasPrefix("Watch") == true ? sample : nil })
//
//                let grouped = GroupedDataSource<Date, HKWorkout>()
//                watchSamples.reversed().forEach({ watchSample in
//                    guard let workout = watchSample as? HKWorkout else { return }
//
//                    self.fetchHeartRateSamples(for: workout)
//
//                    let calendar = Calendar.autoupdatingCurrent
//                    let components = calendar.dateComponents([.month, .year, .calendar], from: workout.startDate)
//                    let date = components.date!
//
//                    grouped[date].append(workout)
//                })
//
//                self.workouts = grouped
//            }
//        }
//
//        self.healthStore.execute(workoutsQuery)
//    }

    private func updateSteps() {
        let stepsCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        self.executeStatistcsQuery(for: stepsCountType) { results in
            self.steps = results
        }
    }

    private func executeStatistcsQuery(for quantityType: HKQuantityType, completion: @escaping ((GroupedDataSource<Date, HKStatistics>) -> Void)) {
        let results = GroupedDataSource<Date, HKStatistics>()

        let calendar = Calendar.autoupdatingCurrent

        var anchorComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: Date())
        anchorComponents.hour = 0
        anchorComponents.year! -= 1

        let anchorDate = calendar.date(from: anchorComponents)!

        let intervalComponents = DateComponents(day: 1)

        let statisticsCollectionQuery = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: nil, options: [.cumulativeSum], anchorDate: anchorDate, intervalComponents: intervalComponents)

        statisticsCollectionQuery.initialResultsHandler = { query, statisticsCollection, error in
            guard let statisticsCollection = statisticsCollection else { return }

            let endDate = Date()
            let startDate = anchorDate

            statisticsCollection.enumerateStatistics(from: startDate, to: endDate, with: { statistics, stop in
                let month = calendar.dateComponents([.month, .year, .calendar], from: statistics.startDate).date!
                results[month].insert(statistics, at: 0)
            })

            completion(results)
        }

        self.healthStore.execute(statisticsCollectionQuery)
    }

    private func fetchHeartRateSamples(for workout: HKWorkout) {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [])
        let hrQuery = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil, resultsHandler: { query, hrSamples, error in

            guard let hrSamples = hrSamples as? [HKQuantitySample] else { return }

            workout.heartRateSamples = hrSamples
        })

        self.healthStore.execute(hrQuery)
    }

    @objc private func uploadActivities() {
        //        let workouts = self.workouts.values
        //
        //        let workoutsJSON = workouts.flatMap({ workout -> [String: Any]? in
        //            let type = workout.activityTypeString
        //            let duration = workout.duration
        //            let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0.0
        //            let energy = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
        //            let start = workout.startDate
        //            let end = workout.endDate
        //            let device = workout.device?.name ?? ""
        //            let source = workout.sourceRevision.source.name
        //
        //            let hrSamples = workout.heartRateSamples.flatMap({ hrSample -> [String: Any]? in
        //                let dictionary = [
        //                    HKQuantityTypeIdentifier.heartRate.rawValue: hrSample.quantity.doubleValue(for: HKUnit(from: "count/min")),
        //                    "date_time_interval": hrSample.startDate.timeIntervalSince1970,
        //                    ]
        //
        //                return dictionary
        //            })
        //
        //            return [
        //                "type": type,
        //                "duration": duration,
        //                "distance": distance,
        //                "energy": energy,
        //                "start_date_time_interval": start.timeIntervalSince1970,
        //                "end_date_time_interval": end.timeIntervalSince1970,
        //                "device_name": device,
        //                "source_name": source,
        //                "heart_rate_samples": hrSamples
        //            ]
        //        })

        var data = [[String: Any]]()
        self.dayData.forEach({ dayData in
            data.append(dayData.asJSON)
        })

        self.apiClient.post(data: data, {
            print("done")
        })
    }
}

extension TableViewController: UITableViewDelegate {

}

extension TableViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dayData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(SampleCell.self, for: indexPath)

        let dayData = self.dayData[indexPath.row]
        cell.title = dayData.asString

        return cell
    }

//    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let view = UIView()
//        view.backgroundColor = UIColor.white.withAlphaComponent(0.8)
//
//        let label = UILabel(withAutoLayout: true)
//        view.addSubview(label)
//        label.fillSuperview(with: UIEdgeInsets(top: 24, left: 12, bottom: 0, right: 12))
//
//        let df = DateFormatter()
//        df.dateFormat = "MMMM yyyy"
//        label.text = df.string(from: self.coaledascedEnergy.reversedSortedKeys[section])
//        label.font = .boldSystemFont(ofSize: 24)
//        label.textColor = .blue
//
//        return view
//    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
