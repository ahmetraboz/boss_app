import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension BossConfig.Serializable {
	public static var isNativelySupportedType: Bool { false }
}

extension Data: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Date: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Bool: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Int: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension UInt: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Double: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Float: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension String: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

// swiftlint:disable:next no_cgfloat
extension CGFloat: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Int8: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension UInt8: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Int16: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension UInt16: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Int32: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension UInt32: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension Int64: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension UInt64: BossConfig.Serializable {
	public static let isNativelySupportedType = true
}

extension URL: BossConfig.Serializable {
	public static let bridge = BossConfig.URLBridge()
}

extension BossConfig.Serializable where Self: Codable {
	public static var bridge: BossConfig.TopLevelCodableBridge<Self> { BossConfig.TopLevelCodableBridge() }
}

extension BossConfig.Serializable where Self: Codable & NSSecureCoding & NSObject {
	public static var bridge: BossConfig.CodableNSSecureCodingBridge<Self> { BossConfig.CodableNSSecureCodingBridge() }
}

extension BossConfig.Serializable where Self: Codable & NSSecureCoding & NSObject & BossConfig.PreferNSSecureCoding {
	public static var bridge: BossConfig.NSSecureCodingBridge<Self> { BossConfig.NSSecureCodingBridge() }
}

extension BossConfig.Serializable where Self: Codable & RawRepresentable {
	public static var bridge: BossConfig.RawRepresentableCodableBridge<Self> { BossConfig.RawRepresentableCodableBridge() }
}

extension BossConfig.Serializable where Self: Codable & RawRepresentable & BossConfig.PreferRawRepresentable {
	public static var bridge: BossConfig.RawRepresentableBridge<Self> { BossConfig.RawRepresentableBridge() }
}

extension BossConfig.Serializable where Self: RawRepresentable {
	public static var bridge: BossConfig.RawRepresentableBridge<Self> { BossConfig.RawRepresentableBridge() }
}

extension BossConfig.Serializable where Self: NSSecureCoding & NSObject {
	public static var bridge: BossConfig.NSSecureCodingBridge<Self> { BossConfig.NSSecureCodingBridge() }
}

extension Optional: BossConfig.Serializable where Wrapped: BossConfig.Serializable {
	public static var isNativelySupportedType: Bool { Wrapped.isNativelySupportedType }
	public static var bridge: BossConfig.OptionalBridge<Wrapped> { BossConfig.OptionalBridge() }
}

extension BossConfig.CollectionSerializable where Element: BossConfig.Serializable {
	public static var bridge: BossConfig.CollectionBridge<Self> { BossConfig.CollectionBridge() }
}

extension BossConfig.SetAlgebraSerializable where Element: BossConfig.Serializable & Hashable {
	public static var bridge: BossConfig.SetAlgebraBridge<Self> { BossConfig.SetAlgebraBridge() }
}

extension Set: BossConfig.Serializable where Element: BossConfig.Serializable {
	public static var bridge: BossConfig.SetBridge<Element> { BossConfig.SetBridge() }
}

extension Array: BossConfig.Serializable where Element: BossConfig.Serializable {
	public static var isNativelySupportedType: Bool { Element.isNativelySupportedType }
	public static var bridge: BossConfig.ArrayBridge<Element> { BossConfig.ArrayBridge() }
}

extension Dictionary: BossConfig.Serializable where Key: LosslessStringConvertible & Hashable, Value: BossConfig.Serializable {
	public static var isNativelySupportedType: Bool { (Key.self is String.Type) && Value.isNativelySupportedType }
	public static var bridge: BossConfig.DictionaryBridge<Key, Value> { BossConfig.DictionaryBridge() }
}

extension UUID: BossConfig.Serializable {
	public static let bridge = BossConfig.UUIDBridge()
}

extension Color: BossConfig.Serializable {
	public static let bridge = BossConfig.ColorBridge()
}

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
extension Color.Resolved: BossConfig.Serializable {}

extension Range: BossConfig.RangeSerializable where Bound: BossConfig.Serializable {
	public static var bridge: BossConfig.RangeBridge<Range> { BossConfig.RangeBridge() }
}

extension ClosedRange: BossConfig.RangeSerializable where Bound: BossConfig.Serializable {
	public static var bridge: BossConfig.RangeBridge<ClosedRange> { BossConfig.RangeBridge() }
}

#if os(macOS)
/**
`NSColor` conforms to `NSSecureCoding`, so it goes to `NSSecureCodingBridge`.
*/
extension NSColor: BossConfig.Serializable {}
#else
/**
`UIColor` conforms to `NSSecureCoding`, so it goes to `NSSecureCodingBridge`.
*/
extension UIColor: BossConfig.Serializable {}
#endif

#if os(macOS)
extension NSFontDescriptor: BossConfig.Serializable {}
#else
extension UIFontDescriptor: BossConfig.Serializable {}
#endif

extension NSUbiquitousKeyValueStore: BossConfigKeyValueStore {}
extension UserDefaults: BossConfigKeyValueStore {}

extension BossConfigLockProtocol {
	@discardableResult
	func with<R, E>(_ body: @Sendable () throws(E) -> R) throws(E) -> R where R: Sendable {
		lock()

		defer {
			unlock()
		}

		return try body()
	}
}
