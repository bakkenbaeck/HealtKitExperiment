import UIKit
import HealthKit
import HealthKitUI
import MapKit
import SweetUIKit
import SweetSwift

public extension DispatchQueue {

    private static var _onceTracker = [String]()

    /**
     Executes a block of code, associated with a unique token, only once.  The code is thread safe and will
     only execute the code once even in the presence of multithreaded calls.

     - parameter token: A unique reverse DNS style name such as com.vectorform.<name> or a GUID
     - parameter block: Block to execute once
     */
    public func once(token: String, block: (() -> Void)) {
        objc_sync_enter(self);
        defer { objc_sync_exit(self) }

        if DispatchQueue._onceTracker.contains(token) {
            return
        }

        DispatchQueue._onceTracker.append(token)

        block()
    }
}

class LocationGeodesicPolyline: MKGeodesicPolyline {
    var locations: [CLLocation] = []

    override init() {
        super.init()
    }

    convenience init(locations: [CLLocation]) {
        let coordinates = locations.map { location -> CLLocationCoordinate2D in return location.coordinate }

        self.init(coordinates: UnsafePointer<CLLocationCoordinate2D>(coordinates), count: coordinates.count)

        self.locations = locations
    }
}

let token = "12312312321"

class ViewController: UIViewController {
    var cyclingActivitySamples: Set<HKWorkout> = [] {
        didSet {
            for workout in self.cyclingActivitySamples {

                let query = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: workout), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in

                    guard let samples = samples as? [HKWorkoutRoute], !samples.isEmpty else { return }

                    if let route = samples.last {
                        let query = HKWorkoutRouteQuery(route: route) { (routeQuery, locations, done, error) in
                            guard let locations = locations else { return }

                            DispatchQueue.main.once(token: token) {
                                let line = LocationGeodesicPolyline(locations: locations)
                                self.mapView.add(line)

                                if let coordinate = locations.last?.coordinate {
                                    let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                                    let region = MKCoordinateRegion(center: coordinate, span: span)

                                    self.mapView.setRegion(region, animated: true)
                                }
                            }
                        }

                        self.healthStore.execute(query)
                    }
                }

                self.healthStore.execute(query)
            }
        }
    }

    lazy var mapView: MKMapView = {
        let view = MKMapView(withAutoLayout: true)
        view.delegate = self

        return view
    }()

    let healthStore = HKHealthStore()

    let cyclingPredicate = HKQuery.predicateForWorkouts(with: .cycling)

    lazy var observerQuery: HKObserverQuery = {
        let query = HKObserverQuery(sampleType: HKWorkoutType.workoutType(), predicate: self.cyclingPredicate) { query, completion, error in
            guard error == nil else { return }

            self.updateActivities()

            completion()
        }

        return query
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.mapView)
        self.mapView.fillSuperview()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.requestHealthAccessAuthorisationIfNeeded()
        self.updateActivities()

        self.healthStore.execute(self.observerQuery)
    }

    private func requestHealthAccessAuthorisationIfNeeded() {
        let readSet = Set([HKWorkoutType.workoutType(),
                           HKSeriesType.workoutRoute(),
                           HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                           HKObjectType.quantityType(forIdentifier: .distanceCycling)!
                           ])
        self.healthStore.requestAuthorization(toShare: nil, read: readSet) { success, error in
            if let error = error {
                print(error)

                return;
            }

            print(success)
        }
    }

    private func updateActivities() {
        let sampleQuery = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: self.cyclingPredicate, limit: 50, sortDescriptors: nil) { query, samples, error in
            guard error == nil else { return }

            if let samples = samples {
                self.cyclingActivitySamples.formUnion(samples as! [HKWorkout])
            }
        }

        self.healthStore.execute(sampleQuery)
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKGeodesicPolyline else {
            return MKOverlayRenderer()
        }

        let renderer = MKPolylineRenderer(overlay: polyline)
        renderer.lineWidth = 3.0
        renderer.strokeColor = .blue

        return renderer
    }
}

