import UIKit
import HealthKit
import HealthKitUI
import MapKit
import SweetUIKit
import SweetSwift

extension UIColor {
    static var random: UIColor {
        let colours = [UIColor.blue, .red, .green, .cyan, .yellow, .brown, .black, .orange, .magenta, .purple]

        return colours[Int(arc4random()) % colours.count]
    }
}

class TableViewController: SweetTableController {
    fileprivate var samples = [Date: [HKSample]]() {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    let healthStore = HKHealthStore()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.tableView)
        self.tableView.fillSuperview()

        self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 80))
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
                let watchSamples = samples.flatMap({ sample -> HKSample? in return sample.sourceRevision.productType?.hasPrefix("Watch") == true ? sample : nil })

                var grouped = [Date: [HKSample]]()
                watchSamples.forEach({ sample in
                    let calendar = Calendar.autoupdatingCurrent
                    let components = calendar.dateComponents([.month, .year, .calendar], from: sample.startDate)

                    let date = components.date!

                    if grouped[date] == nil {
                        grouped[date] = [HKSample]()
                    }

                    grouped[date]?.append(sample)
                })

                self.samples = grouped
            }
        }

        self.healthStore.execute(sampleQuery)
    }
}

extension TableViewController: UITableViewDelegate {

}

extension TableViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.samples.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let key = Array(self.samples.keys.sorted().reversed())[section]
        return self.samples[key]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(SampleCell.self, for: indexPath)

        let key = Array(self.samples.keys.sorted().reversed())[indexPath.section]
        let sample = self.samples[key]?[indexPath.row]

        let label: String
        if let workout = (sample as? HKWorkout) {
            label = "\(workout.activityTypeString) - \(workout.totalEnergyBurned ?? HKQuantity.init(unit: HKUnit.kilocalorie(), doubleValue: 0))"
        } else {
            label = ""
        }

        cell.title = label

        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.8)

        let label = UILabel(withAutoLayout: true)
        view.addSubview(label)
        label.fillSuperview(with: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0))

        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        label.text = df.string(from: Array(self.samples.keys.sorted().reversed())[section])
        label.font = .boldSystemFont(ofSize: 30)
        label.textColor = .blue

        return view
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
