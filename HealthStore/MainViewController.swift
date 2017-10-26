import UIKit
import HealthKit
import HealthKitUI
import MapKit
import SweetUIKit
import SweetSwift

class MainViewController: UIViewController {
    let apiClient = APIClient()

    fileprivate lazy var uploadButton: UIButton = {
        let button = UIButton(withAutoLayout: true)

        button.setImage(#imageLiteral(resourceName: "upload"), for: .normal)
        button.addTarget(self, action: #selector(self.uploadActivities), for: .touchUpInside)
        button.set(height: 60)
        button.set(width: 90)

        return button
    }()

    fileprivate lazy var loadingIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)

        view.translatesAutoresizingMaskIntoConstraints = false
        view.color = .blue

        return view
    }()

    fileprivate lazy var explanationLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)

        view.font = .systemFont(ofSize: 18)
        view.numberOfLines = 0
        view.text = "Welcome to HealthStore. After we're finished loading, feel free to hit the big blue button to send all your 🔐 private 🔐 health data to our servers. Just set up a username and hit the button."
        view.setContentHuggingPriority(.required, for: .vertical)

        return view
    }()

    fileprivate lazy var usernameLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)

        view.font = .systemFont(ofSize: 18)
        view.text = "Username"
        view.setContentHuggingPriority(.required, for: .horizontal)

        return view
    }()

    fileprivate lazy var usernameTextField: UITextField = {
        let view = UITextField(withAutoLayout: true)

        view.font = .systemFont(ofSize: 19)
        view.placeholder = "myuser"

        return view
    }()

    fileprivate var dayData = [DayData]() {
        didSet {
            DispatchQueue.main.async {
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

        self.title = "HealthStore"

        self.view.backgroundColor = .white
        self.view.addSubview(self.explanationLabel)
        self.view.addSubview(self.usernameLabel)
        self.view.addSubview(self.usernameTextField)
        self.view.addSubview(self.uploadButton)
        self.view.addSubview(self.loadingIndicator)

        self.uploadButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        self.uploadButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 60).isActive = true

        self.usernameLabel.set(height: 32)
        self.usernameLabel.topAnchor.constraint(equalTo: self.uploadButton.bottomAnchor, constant: 54).isActive = true
        self.usernameLabel.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 24).isActive = true
        self.usernameLabel.rightAnchor.constraint(equalTo: self.usernameTextField.leftAnchor, constant: -8).isActive = true

        self.usernameTextField.set(height: 32)
        self.usernameTextField.topAnchor.constraint(equalTo: self.usernameLabel.topAnchor).isActive = true
        self.usernameTextField.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: 8).isActive = true
        self.usernameTextField.bottomAnchor.constraint(equalTo: self.usernameLabel.bottomAnchor).isActive = true

        self.explanationLabel.topAnchor.constraint(equalTo: self.usernameLabel.bottomAnchor, constant: 44).isActive = true
        self.explanationLabel.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 24).isActive = true
        self.explanationLabel.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -24).isActive = true
        // self.explanationLabel.bottomAnchor.constraint(greaterThanOrEqualTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -60).isActive = true

        self.loadingIndicator.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        self.loadingIndicator.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -60).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.usernameTextField.becomeFirstResponder()
        self.updateActivities()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.loadingIndicator.startAnimating()
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
        var data = [[String: Any]]()
        self.dayData.forEach({ dayData in
            data.append(dayData.asJSON)
        })

        self.apiClient.post(username: self.usernameTextField.text ?? "tester", data: data, {
            print("done")
        })
    }
}

