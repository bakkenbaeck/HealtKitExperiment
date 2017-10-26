import Teapot
import Foundation

class APIClient {
    let teapot = Teapot(baseURL: URL(string: "https://sync:sync@health-sync.testwerk.org")!)

    func post(data: [String: [[String: Any]]], _ completion: (() -> Void)) {
        let path =  "/"
        let parameters = RequestParameter(["username": "igor", "data": data])

        self.teapot.post(path, parameters: parameters) { result in
            switch result {
            case let .success(params, response):
                print(params)
                print(response)
            case let .failure(params, response, error):
                print(params)
                print(response)
                print(error)
            }
        }
    }
}
