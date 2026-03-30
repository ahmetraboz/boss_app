import Foundation

extension BossConfig {
	/**
	Types that conform to this protocol can be used with `BossConfig`.

	The type should have a static variable `bridge` which should reference an instance of a type that conforms to `BossConfig.Bridge`.

	```swift
	struct User {
		username: String
		password: String
	}

	extension User: BossConfig.Serializable {
		static let bridge = UserBridge()
	}
	```
	*/
	public protocol Serializable {
		typealias Value = Bridge.Value
		typealias Serializable = Bridge.Serializable
		associatedtype Bridge: BossConfig.Bridge

		/**
		Static bridge for the `Value` which cannot be stored natively.
		*/
		static var bridge: Bridge { get }

		/**
		A flag to determine whether `Value` can be stored natively or not.
		*/
		static var isNativelySupportedType: Bool { get }
	}
}

extension BossConfig {
	public protocol Bridge {
		associatedtype Value
		associatedtype Serializable

		func serialize(_ value: Value?) -> Serializable?
		func deserialize(_ object: Serializable?) -> Value?
	}
}

extension BossConfig {
	/**
	Ambiguous bridge selector protocol that lets you select your preferred bridge when there are multiple possibilities.

	```swift
	enum Interval: Int, Codable, BossConfig.Serializable, BossConfig.PreferRawRepresentable {
		case tenMinutes = 10
		case halfHour = 30
		case oneHour = 60
	}
	```

	By default, if an `enum` conforms to `Codable` and `BossConfig.Serializable`, it will use the `CodableBridge`, but by conforming to `BossConfig.PreferRawRepresentable`, we can switch the bridge back to `RawRepresentableBridge`.
	*/
	public protocol PreferRawRepresentable: RawRepresentable {}

	/**
	Ambiguous bridge selector protocol that lets you select your preferred bridge when there are multiple possibilities.
	*/
	public protocol PreferNSSecureCoding: NSObject, NSSecureCoding {}
}

extension BossConfig {
	public protocol CollectionSerializable: Collection, Serializable {
		/**
		`Collection` does not have a initializer, but we need a initializer to convert an array into the `Value`.
		*/
		init(_ elements: [Element])
	}

	public protocol SetAlgebraSerializable: SetAlgebra, Serializable {
		/**
		Since `SetAlgebra` protocol does not conform to `Sequence`, we cannot convert a `SetAlgebra` to an `Array` directly.
		*/
		func toArray() -> [Element]
	}

	public protocol CodableBridge: Bridge where Serializable == String, Value: Codable {}

	// Essential properties for serializing and deserializing `ClosedRange` and `Range`.
	public protocol Range {
		associatedtype Bound: Comparable, BossConfig.Serializable

		var lowerBound: Bound { get }
		var upperBound: Bound { get }

		init(uncheckedBounds: (lower: Bound, upper: Bound))
	}

	/**
	A `Bridge` is responsible for serialization and deserialization.

	It has two associated types `Value` and `Serializable`.

	- `Value`: The type you want to use.
	- `Serializable`: The type stored in `UserDefaults`.
	- `serialize`: Executed before storing to the `UserDefaults` .
	- `deserialize`: Executed after retrieving its value from the `UserDefaults`.

	```swift
	struct User {
		username: String
		password: String
	}

	extension User {
		static let bridge = UserBridge()
	}

	struct UserBridge: BossConfig.Bridge {
		typealias Value = User
		typealias Serializable = [String: String]

		func serialize(_ value: Value?) -> Serializable? {
			guard let value else {
				return nil
			}

			return [
				"username": value.username,
				"password": value.password
			]
		}

		func deserialize(_ object: Serializable?) -> Value? {
			guard
				let object,
				let username = object["username"],
				let password = object["password"]
			else {
				return nil
			}

			return User(
				username: username,
				password: password
			)
		}
	}
	```
	*/
	public typealias RangeSerializable = BossConfig.Range & Serializable
}

/**
Essential properties for synchronizing a key value store.
*/
protocol BossConfigKeyValueStore {
	func object(forKey aKey: String) -> Any?

	func set(_ anObject: Any?, forKey aKey: String)

	func removeObject(forKey aKey: String)

	@discardableResult
	func synchronize() -> Bool
}

protocol BossConfigLockProtocol {
	static func make() -> Self

	func lock()

	func unlock()

	func with<R, E>(_ body: @Sendable () throws(E) -> R) throws(E) -> R where R: Sendable
}
