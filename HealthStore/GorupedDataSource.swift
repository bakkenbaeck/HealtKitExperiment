import Foundation

class GroupedDataSource<Key: Comparable & Hashable, Item: Hashable> {

    typealias KeyToItemsDictionary = [Key: [Item]]

    fileprivate var dictionary: KeyToItemsDictionary = KeyToItemsDictionary()

    var reversedSortedKeys: [Key] {
        return Array(self.keys.sorted().reversed())
    }

    var keys: KeyToItemsDictionary.Keys {
        return self.dictionary.keys
    }

    func item(at indexPath: IndexPath) -> AnyHashable? {
        let key = self.reversedSortedKeys[indexPath.section]

        return self[key][indexPath.row]
    }

    func count(for section: Int) -> Int {
        let key = self.reversedSortedKeys[section]

        return self[key].count
    }

    subscript(key: Key) -> [Item] {
        get {
            if self.dictionary[key] == nil {
                self.dictionary[key] = []
            }

            return self.dictionary[key]!
        }
        set {
            self.dictionary[key] = newValue
        }
    }
}
