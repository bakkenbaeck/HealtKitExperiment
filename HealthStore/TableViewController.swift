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

    fileprivate var samples = GroupedDataSource<Date, HKSample>() {
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
        let sampleQuery = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in
            guard error == nil else { return }

            if let samples = samples {
                let watchSamples = samples //.flatMap({ sample -> HKSample? in return sample.sourceRevision.productType?.hasPrefix("Watch") == true ? sample : nil })

                let grouped = GroupedDataSource<Date, HKSample>()
                watchSamples.reversed().forEach({ sample in
                    let calendar = Calendar.autoupdatingCurrent
                    let components = calendar.dateComponents([.month, .year, .calendar], from: sample.startDate)

                    let date = components.date!

                    let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
                    let predicate = HKQuery.predicateForSamples(withStart: sample.startDate, end: sample.endDate, options: [])
                    let hrQuery = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil, resultsHandler: { query, hrSamples, error in

                        guard let hrSamples = hrSamples as? [HKQuantitySample], let workout = sample as? HKWorkout else { return }

                        workout.heartRateSamples = hrSamples
                    })
                    self.healthStore.execute(hrQuery)

                    grouped[date].append(sample)
                })

                self.samples = grouped
            }
        }

        self.healthStore.execute(sampleQuery)
    }

    @objc private func uploadActivities() {
        let workouts = self.samples.values

        let workoutsJSON = workouts.flatMap({ sample -> [String: Any]? in
            guard let workout = sample as? HKWorkout else { return nil }

            let type = workout.activityTypeString
            let duration = workout.duration
            let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? 0.0
            let energy = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
            let start = workout.startDate
            let end = workout.endDate
            // let metadata = workout.metadata ?? [:]
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
                // "metadata": metadata,
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
        return self.samples.keys.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.samples.count(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(SampleCell.self, for: indexPath)

        let sample = self.samples.item(at: indexPath)

        let label: String
        let dateString: String
        if let workout = (sample as? HKWorkout) {
            label = "\(workout.activityTypeString) (\(self.dateComponentsFormatter.string(from: workout.duration) ?? "0s")) - \(workout.totalEnergyBurned ?? HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 0.0))"
            dateString = self.dateFormatter.string(from: workout.startDate)
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
        label.text = df.string(from: self.samples.reversedSortedKeys[section])
        label.font = .boldSystemFont(ofSize: 24)
        label.textColor = .blue

        return view
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
