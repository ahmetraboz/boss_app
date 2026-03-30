import CoreGraphics
import Foundation

extension BossConfig {
	/**
	Type-erased wrapper for `BossConfig.Serializable` values.

	It can be useful when you need to create an `Any` value that conforms to `BossConfig.Serializable`.

	It will have an internal property `value` which should always be a `UserDefaults` natively supported type.

	`get` will deserialize the internal value to the type that user specify in the function parameter.

	```swift
	let any = BossConfig.Key<BossConfig.AnySerializable>("independentAnyKey", default: 121_314)

	print(BossConfig[any].get(Int.self))
	//=> 121_314
	```

	- Note: The only way to assign a non-serializable value is using `ExpressibleByArrayLiteral` or `ExpressibleByDictionaryLiteral` to assign a type that is not a `UserDefaults` natively supported type.

	```swift
	private enum mime: String, BossConfig.Serializable {
		case JSON = "application/json"
	}

	// Failed: Attempt to insert non-property list object
	let any = BossConfig.Key<BossConfig.AnySerializable>("independentAnyKey", default: [mime.JSON])
	```
	*/
	public struct AnySerializable: Serializable {
		var value: Any
		public static let bridge = AnyBridge()

		init(value: (some Any)?) {
			self.value = value ?? ()
		}

		public init<Value: Serializable>(_ value: Value) {
			self.value = Value.toSerializable(value) ?? ()
		}

		public func get<Value: Serializable>() -> Value? { Value.toValue(value) }

		public func get<Value: Serializable>(_: Value.Type) -> Value? { Value.toValue(value) }

		public mutating func set<Value: Serializable>(_ newValue: Value) {
			value = Value.toSerializable(newValue) ?? ()
		}

		public mutating func set<Value: Serializable>(_ newValue: Value, type: Value.Type) {
			value = Value.toSerializable(newValue) ?? ()
		}
	}
}

extension BossConfig.AnySerializable: Hashable {
	public func hash(into hasher: inout Hasher) {
		switch value {
		case let value as Data:
			hasher.combine(value)
		case let value as Date:
			hasher.combine(value)
		case let value as Bool:
			hasher.combine(value)
		case let value as UInt8:
			hasher.combine(value)
		case let value as Int8:
			hasher.combine(value)
		case let value as UInt16:
			hasher.combine(value)
		case let value as Int16:
			hasher.combine(value)
		case let value as UInt32:
			hasher.combine(value)
		case let value as Int32:
			hasher.combine(value)
		case let value as UInt64:
			hasher.combine(value)
		case let value as Int64:
			hasher.combine(value)
		case let value as UInt:
			hasher.combine(value)
		case let value as Int:
			hasher.combine(value)
		case let value as Float:
			hasher.combine(value)
		case let value as Double:
			hasher.combine(value)
		case let value as CGFloat: // swiftlint:disable:this no_cgfloat
			hasher.combine(value)
		case let value as String:
			hasher.combine(value)
		case let value as [AnyHashable: AnyHashable]:
			hasher.combine(value)
		case let value as [AnyHashable]:
			hasher.combine(value)
		default:
			break
		}
	}
}

extension BossConfig.AnySerializable: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		switch (lhs.value, rhs.value) {
		case (let lhs as Data, let rhs as Data):
			lhs == rhs
		case (let lhs as Date, let rhs as Date):
			lhs == rhs
		case (let lhs as Bool, let rhs as Bool):
			lhs == rhs
		case (let lhs as UInt8, let rhs as UInt8):
			lhs == rhs
		case (let lhs as Int8, let rhs as Int8):
			lhs == rhs
		case (let lhs as UInt16, let rhs as UInt16):
			lhs == rhs
		case (let lhs as Int16, let rhs as Int16):
			lhs == rhs
		case (let lhs as UInt32, let rhs as UInt32):
			lhs == rhs
		case (let lhs as Int32, let rhs as Int32):
			lhs == rhs
		case (let lhs as UInt64, let rhs as UInt64):
			lhs == rhs
		case (let lhs as Int64, let rhs as Int64):
			lhs == rhs
		case (let lhs as UInt, let rhs as UInt):
			lhs == rhs
		case (let lhs as Int, let rhs as Int):
			lhs == rhs
		case (let lhs as Float, let rhs as Float):
			lhs == rhs
		case (let lhs as Double, let rhs as Double):
			lhs == rhs
		case (let lhs as CGFloat, let rhs as CGFloat): // swiftlint:disable:this no_cgfloat
			lhs == rhs
		case (let lhs as String, let rhs as String):
			lhs == rhs
		case (let lhs as [AnyHashable: Any], let rhs as [AnyHashable: Any]):
			lhs.toDictionary() == rhs.toDictionary()
		case (let lhs as [Any], let rhs as [Any]):
			lhs.toSequence() == rhs.toSequence()
		default:
			false
		}
	}
}

extension BossConfig.AnySerializable: ExpressibleByStringLiteral {
	public init(stringLiteral value: String) {
		self.init(value: value)
	}
}

extension BossConfig.AnySerializable: ExpressibleByNilLiteral {
	public init(nilLiteral _: ()) {
		self.init(value: nil as Any?)
	}
}

extension BossConfig.AnySerializable: ExpressibleByBooleanLiteral {
	public init(booleanLiteral value: Bool) {
		self.init(value: value)
	}
}

extension BossConfig.AnySerializable: ExpressibleByIntegerLiteral {
	public init(integerLiteral value: Int) {
		self.init(value: value)
	}
}

extension BossConfig.AnySerializable: ExpressibleByFloatLiteral {
	public init(floatLiteral value: Double) {
		self.init(value: value)
	}
}

extension BossConfig.AnySerializable: ExpressibleByArrayLiteral {
	public init(arrayLiteral elements: Any...) {
		self.init(value: elements)
	}
}

extension BossConfig.AnySerializable: ExpressibleByDictionaryLiteral {
	public init(dictionaryLiteral elements: (AnyHashable, Any)...) {
		self.init(value: [AnyHashable: Any](uniqueKeysWithValues: elements))
	}
}

extension BossConfig.AnySerializable: _BossConfigOptionalProtocol {
	// Since `nil` cannot be assigned to `Any`, we use `Void` instead of `nil`.
	public var _defaults_isNil: Bool { value is Void }
}

extension Sequence {
	fileprivate func toSequence() -> [BossConfig.AnySerializable] {
		map { BossConfig.AnySerializable(value: $0) }
	}
}

extension Dictionary {
	fileprivate func toDictionary() -> [AnyHashable: BossConfig.AnySerializable] {
		reduce(into: [AnyHashable: BossConfig.AnySerializable]()) { memo, tuple in memo[tuple.key] = BossConfig.AnySerializable(value: tuple.value) }
	}
}
