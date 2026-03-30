import Foundation

extension BossConfig {
	/**
	Reset the given string keys back to their default values.

	Prefer using the strongly-typed keys instead whenever possible. This method can be useful if you need to store some keys in a collection, as it's not possible to store `BossConfig.Key` in a collection because it's generic.

	- Parameter keys: String keys to reset.
	- Parameter suite: `UserDefaults` suite.

	```swift
	extension BossConfig.Keys {
		static let isUnicornMode = Key<Bool>("isUnicornMode", default: false)
	}

	BossConfig[.isUnicornMode] = true
	//=> true

	BossConfig.reset(BossConfig.Keys.isUnicornMode.name)
	// Or `BossConfig.reset("isUnicornMode")`

	BossConfig[.isUnicornMode]
	//=> false
	```
	*/
	public static func reset(_ keys: String..., suite: UserDefaults = .standard) {
		reset(keys, suite: suite)
	}

	/**
	Reset the given string keys back to their default values.

	Prefer using the strongly-typed keys instead whenever possible. This method can be useful if you need to store some keys in a collection, as it's not possible to store `BossConfig.Key` in a collection because it's generic.

	- Parameter keys: String keys to reset.
	- Parameter suite: `UserDefaults` suite.

	```swift
	extension BossConfig.Keys {
		static let isUnicornMode = Key<Bool>("isUnicornMode", default: false)
	}

	BossConfig[.isUnicornMode] = true
	//=> true

	BossConfig.reset([BossConfig.Keys.isUnicornMode.name])
	// Or `BossConfig.reset(["isUnicornMode"])`

	BossConfig[.isUnicornMode]
	//=> false
	```
	*/
	public static func reset(_ keys: [String], suite: UserDefaults = .standard) {
		for key in keys {
			suite.removeObject(forKey: key)
		}
	}
}

extension BossConfig {
	// TODO: Add this to the main docs page.
	/**
	Reset the given keys back to their default values.

	```swift
	extension BossConfig.Keys {
		static let isUnicornMode = Key<Bool>("isUnicornMode", default: false)
	}

	BossConfig[.isUnicornMode] = true
	//=> true

	BossConfig.reset(.isUnicornMode)

	BossConfig[.isUnicornMode]
	//=> false
	```
	*/
	public static func reset<each Value>(
		_ keys: repeat Key<each Value>,
		suite: UserDefaults = .standard
	) {
		for key in repeat (each keys) {
			key.reset()
		}
	}

	// TODO: Remove this when the variadic generics version works with DocC.
	/**
	Reset the given keys back to their default values.

	```swift
	extension BossConfig.Keys {
		static let isUnicornMode = Key<Bool>("isUnicornMode", default: false)
	}

	BossConfig[.isUnicornMode] = true
	//=> true

	BossConfig.reset(.isUnicornMode)

	BossConfig[.isUnicornMode]
	//=> false
	```
	*/
	@_disfavoredOverload
	public static func reset(_ keys: _AnyKey...) {
		reset(keys)
	}

	// We still keep this as it can be useful to pass a dynamic array of keys.
	/**
	Reset the given keys back to their default values.

	```swift
	extension BossConfig.Keys {
		static let isUnicornMode = Key<Bool>("isUnicornMode", default: false)
	}

	BossConfig[.isUnicornMode] = true
	//=> true

	BossConfig.reset(.isUnicornMode)

	BossConfig[.isUnicornMode]
	//=> false
	```
	*/
	public static func reset(_ keys: [_AnyKey]) {
		for key in keys {
			key.reset()
		}
	}
}
