import Teapot
import Foundation

class APIClient {
    let teapot = Teapot(baseURL: URL(string: "https://sync:sync@health-sync.testwerk.org")!)

    func post(username: String, data: [[String: Any]], _ completion: @escaping((_ success: Bool) -> Void)) {
        let path =  "/"

        // replace username to yours for now manually from code.
        let parameters = RequestParameter(["username": username, "data": data])

        self.teapot.post(path, parameters: parameters) { result in
            switch result {
            case let .success(params, response):
                completion(true)
            case let .failure(params, response, error):
                completion(false)
            }
        }
    }
}
