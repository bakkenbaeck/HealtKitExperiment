import UIKit
import HealthKit
import HealthKitUI
import MapKit
import SweetUIKit
import SweetSwift

private var AssociatedObjectHandle: UInt8 = 0

extension HKWorkout {

    var heartRateSamples: [HKQuantitySample] {
        get {
            if let samples = objc_getAssociatedObject(self, &AssociatedObjectHandle) as? [HKQuantitySample] {
                return samples
            }

            self.heartRateSamples = []

            return []
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObjectHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
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

    fileprivate var steps = GroupedDataSource<Date, HKStatistics>() {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    fileprivate var activeEnergy = GroupedDataSource<Date, HKStatistics>() {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    fileprivate var basalEnergy = GroupedDataSource<Date, HKStatistics>() {
        didSet {
            DispatchQueue.main.async {
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

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .redo, target: self, action: #selector(self.uploadActivities))

        self.title = "Workouts"

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
        self.updateActiveEnergy()
        self.updateBasalEnergy()
        self.updateSteps()
        self.updateWorkoutsWithHeartRateDate()
    }

    func updateBasalEnergy() {
        let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!

        self.executeStatistcsQuery(for: basalEnergyType) { results in
            self.basalEnergy = results
        }
    }

    func updateActiveEnergy() {
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        self.executeStatistcsQuery(for: activeEnergyType) { results in
            self.activeEnergy = results
        }
    }

    func updateWorkoutsWithHeartRateDate() {
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

        var anchorComponents = calendar.dateComponents([.day, .month, .year], from: Date())
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
        let workouts = self.workouts.values

        let workoutsJSON = workouts.flatMap({ workout -> [String: Any]? in
            let type = workout.activityTypeString
            let duration = workout.duration
            let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0.0
            let energy = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
            let start = workout.startDate
            let end = workout.endDate
            let device = workout.device?.name ?? ""
            let source = workout.sourceRevision.source.name

            let hrSamples = workout.heartRateSamples.flatMap({ hrSample -> [String: Any]? in
                let dictionary = [
                    HKQuantityTypeIdentifier.heartRate.rawValue: hrSample.quantity.doubleValue(for: HKUnit(from: "count/min")),
                    "date_time_interval": hrSample.startDate.timeIntervalSince1970,
                    ]

                return dictionary
            })

            return [
                "type": type,
                "duration": duration,
                "distance": distance,
                "energy": energy,
                "start_date_time_interval": start.timeIntervalSince1970,
                "end_date_time_interval": end.timeIntervalSince1970,
                "device_name": device,
                "source_name": source,
                "heart_rate_samples": hrSamples
            ]
        })

        self.apiClient.post(workouts: workoutsJSON, {
            print("done")
        })
    }
}

extension TableViewController: UITableViewDelegate {

}

extension TableViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.activeEnergy.keys.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.activeEnergy.count(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(SampleCell.self, for: indexPath)

        let sample = self.activeEnergy.item(at: indexPath)

        let label: String
        let dateString: String
        if let stepsStatistics = (sample as? HKStatistics), let sum = stepsStatistics.sumQuantity() {
            label = String(describing: sum)
            dateString = self.dateFormatter.string(from: stepsStatistics.startDate)
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
        label.text = df.string(from: self.workouts.reversedSortedKeys[section])
        label.font = .boldSystemFont(ofSize: 24)
        label.textColor = .blue

        return view
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}
