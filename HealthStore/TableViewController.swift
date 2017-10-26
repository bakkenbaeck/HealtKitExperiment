import UIKit
import HealthKit
import HealthKitUI
import MapKit
import SweetUIKit
import SweetSwift

func printTimeElapsedWhenRunningCode(title:String, operation: () -> ()) {
    let startTime = CFAbsoluteTimeGetCurrent()

    operation()

    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

    print("Time elapsed for \(title): \(timeElapsed) s.")
}

class TableViewController: SweetTableController {
    let apiClient = APIClient()

    fileprivate var workouts = GroupedDataSource<Date, HKWorkout>() {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
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
            DispatchQueue.main.async {
                print("Did update step count")
                self.tableView.reloadData()
            }
        }
    }

    fileprivate var activeEnergy = GroupedDataSource<Date, HKStatistics>() {
        didSet {
            DispatchQueue.main.async {
                self.coalesceData()
                self.tableView.reloadData()
            }
        }
    }

    fileprivate var basalEnergy = GroupedDataSource<Date, HKStatistics>() {
        didSet {
            DispatchQueue.main.async {
                self.coalesceData()
                self.tableView.reloadData()
            }
        }
    }

    fileprivate var coalescedEnergy = GroupedDataSource<Date, Energy>() {
        didSet {
            DispatchQueue.main.async {
                print("Did coalesce energy data.")
                self.tableView.reloadData()
            }
        }
    }


    fileprivate var distanceWalked = GroupedDataSource<Date, HKStatistics>() {
        didSet {
            DispatchQueue.main.async {
                print("Did update running/walking distances.")
                self.tableView.reloadData()
            }
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
        self.updateActiveEnergy()
        self.updateBasalEnergy()
        self.updateSteps()
        self.updateWalkingDistance()

        // self.updateWorkoutsWithHeartRateDate()
    }

    private func coalesceData() {
        let coalescedData = GroupedDataSource<Date, AnyHashable>()
        let calendar = Calendar.autoupdatingCurrent

        // fetch all days with data
        let basalEnergyDates = self.basalEnergy.values.reversed().map({ statistics -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: statistics.startDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })
        let activeEnergyDates = self.activeEnergy.values.reversed().map({ statistics -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: statistics.startDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })
        let sleepDates = self.sleepAnalysis.reversed().map({ analysis -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: analysis.endDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })
        let stepsDates = self.steps.values.reversed().map({ statistics -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: statistics.startDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })
        let distanceDates = self.distanceWalked.values.reversed().map({ statistics -> Date in
            var dateComponents = calendar.dateComponents([.day, .month, .year, .calendar], from: statistics.startDate)
            dateComponents.hour = 0

            return dateComponents.date!
        })

        // Dedupe all dates
        var dateSet = Set<Date>()
        dateSet.formUnion(basalEnergyDates)
        dateSet.formUnion(activeEnergyDates)
        dateSet.formUnion(sleepDates)
        dateSet.formUnion(stepsDates)
        dateSet.formUnion(distanceDates)

        var dayData: [DayData] = []

        printTimeElapsedWhenRunningCode(title: "coalescing") {

            for date in dateSet.sorted().reversed() {
                let basalEnergy = self.basalEnergy.values.filter({ item -> Bool in return calendar.isDate(item.startDate, inSameDayAs: date) }).first
                let activeEnergy = self.activeEnergy.values.filter({ item -> Bool in return calendar.isDate(item.startDate, inSameDayAs: date) }).first
                let steps = self.steps.values.filter({ item -> Bool in return calendar.isDate(item.startDate, inSameDayAs: date) }).first
                let sleep = self.sleepAnalysis.filter({ item -> Bool in return calendar.isDate(item.endDate, inSameDayAs: date) }).first
                let distance = self.distanceWalked.values.filter({ item -> Bool in return calendar.isDate(item.startDate, inSameDayAs: date) }).first

                var energy: Energy? = nil
                if let basalEnergy = basalEnergy {
                    energy = Energy(activeDataPoint: activeEnergy, basalDataPoint: basalEnergy)
                }

                dayData.append(DayData(date: date, sleep: sleep, steps: steps, energy: energy, distance: distance))
            }

            // print(dayData)
        }

        // self.coalescedEnergy = coalescedData
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

    private func updateBasalEnergy() {
        let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!

        self.executeStatistcsQuery(for: basalEnergyType) { results in
            self.basalEnergy = results
        }
    }

    private func updateActiveEnergy() {
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        self.executeStatistcsQuery(for: activeEnergyType) { results in
            self.activeEnergy = results
        }
    }

    private func updateWorkoutsWithHeartRateDate() {
        let workoutsQuery = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in
            guard error == nil else { return }

            if let samples = samples {
                let watchSamples = samples //.flatMap({ sample -> HKSample? in return sample.sourceRevision.productType?.hasPrefix("Watch") == true ? sample : nil })

                let grouped = GroupedDataSource<Date, HKWorkout>()
                watchSamples.reversed().forEach({ watchSample in
                    guard let workout = watchSample as? HKWorkout else { return }

                    self.fetchHeartRateSamples(for: workout)

                    let calendar = Calendar.autoupdatingCurrent
                    let components = calendar.dateComponents([.month, .year, .calendar], from: workout.startDate)
                    let date = components.date!

                    grouped[date].append(workout)
                })

                self.workouts = grouped
            }
        }

        self.healthStore.execute(workoutsQuery)
    }

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

        var data = [String: [[String: Any]]]()

        //        data["energy"] = [[String: Any]]()
        //        for energy in self.coalescedEnergy.values {
        //            let timeinterval = energy.basalDataPoint.startDate.timeIntervalSince1970
        //            let basalKcal = energy.basalDataPoint.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
        //            let activeKcal = energy.activeDataPoint?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
        //
        //            data["energy"]?.append([
        //                "basal_energy_burned": basalKcal,
        //                "active_energy_burned": activeKcal,
        //                "time_interval": timeinterval
        //            ])
        //        }

        self.apiClient.post(data: data, {
            print("done")
        })
    }
}

extension TableViewController: UITableViewDelegate {

}

extension TableViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.coalescedEnergy.keys.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.coalescedEnergy.count(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(SampleCell.self, for: indexPath)

        let sample = self.coalescedEnergy.item(at: indexPath)

        let label: String
        let dateString: String
        if let energy = (sample as? Energy) {
            label = "\(energy.totalEnergy) (basal: \(energy.basalDataPoint.sumQuantity()!), active: \(energy.activeDataPoint?.sumQuantity() ?? HKQuantity(unit: .kilocalorie(), doubleValue: 0.0))"
            dateString = self.dateFormatter.string(from: energy.basalDataPoint.startDate)
        } else {
            label = ""
            dateString = ""
        }

        cell.title = label
        cell.dateString = dateString

        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.8)

        let label = UILabel(withAutoLayout: true)
        view.addSubview(label)
        label.fillSuperview(with: UIEdgeInsets(top: 24, left: 12, bottom: 0, right: 12))

        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        label.text = df.string(from: self.coalescedEnergy.reversedSortedKeys[section])
        label.font = .boldSystemFont(ofSize: 24)
        label.textColor = .blue

        return view
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
