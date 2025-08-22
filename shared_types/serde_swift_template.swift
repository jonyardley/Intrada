import Foundation

// MARK: - Property Wrappers

@propertyWrapper
public struct Indirect<T> {
    public var wrappedValue: T
    
    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

extension Indirect: Hashable where T: Hashable {}
extension Indirect: Equatable where T: Equatable {}

// MARK: - Serialization Errors

public enum SerializationError: Error {
    case invalidInput(issue: String)
    case containerDepthLimitExceeded
}

public enum DeserializationError: Error {
    case invalidInput(issue: String)
    case invalidLength(expected: UInt64, actual: UInt64)
    case invalidValue(expected: String, actual: String)
    case missingContent
    case remainingInput
    case containerDepthLimitExceeded
}

// MARK: - Serialization Protocols

public protocol Serializer {
    func serialize_bool(value: Bool) throws
    func serialize_i8(value: Int8) throws
    func serialize_i16(value: Int16) throws
    func serialize_i32(value: Int32) throws
    func serialize_i64(value: Int64) throws
    func serialize_u8(value: UInt8) throws
    func serialize_u16(value: UInt16) throws
    func serialize_u32(value: UInt32) throws
    func serialize_u64(value: UInt64) throws
    func serialize_f32(value: Float) throws
    func serialize_f64(value: Double) throws
    func serialize_str(value: String) throws
    func serialize_bytes(value: [UInt8]) throws
    func serialize_len(value: UInt64) throws
    func serialize_len(value: Int) throws
    func serialize_variant_index(value: UInt32) throws
    func serialize_option_tag(value: Bool) throws
    func get_buffer_offset() -> UInt64
    func increase_container_depth() throws
    func decrease_container_depth() throws
}

public protocol Deserializer {
    func deserialize_bool() throws -> Bool
    func deserialize_i8() throws -> Int8
    func deserialize_i16() throws -> Int16
    func deserialize_i32() throws -> Int32
    func deserialize_i64() throws -> Int64
    func deserialize_u8() throws -> UInt8
    func deserialize_u16() throws -> UInt16
    func deserialize_u32() throws -> UInt32
    func deserialize_u64() throws -> UInt64
    func deserialize_f32() throws -> Float
    func deserialize_f64() throws -> Double
    func deserialize_str() throws -> String
    func deserialize_bytes() throws -> [UInt8]
    func deserialize_len() throws -> UInt64
    func deserialize_variant_index() throws -> UInt32
    func deserialize_option_tag() throws -> Bool
    func get_buffer_offset() -> UInt64
    func increase_container_depth() throws
    func decrease_container_depth() throws
    func check_that_key_slices_are_increasing(key1: [UInt32], key2: [UInt32]) throws -> Bool
}

// MARK: - Bincode Serializer

public class BincodeSerializer: Serializer {
    private var output: [UInt8]
    private var containerDepthBudget: UInt64
    
    public init() {
        self.output = []
        self.containerDepthBudget = 500  // Default container depth limit
    }
    
    public func get_bytes() -> [UInt8] {
        return output
    }
    
    public func get_buffer_offset() -> UInt64 {
        return UInt64(output.count)
    }
    
    public func increase_container_depth() throws {
        if containerDepthBudget == 0 {
            throw SerializationError.containerDepthLimitExceeded
        }
        containerDepthBudget -= 1
    }
    
    public func decrease_container_depth() throws {
        containerDepthBudget += 1
    }
    
    public func serialize_bool(value: Bool) throws {
        output.append(value ? 1 : 0)
    }
    
    public func serialize_i8(value: Int8) throws {
        output.append(UInt8(bitPattern: value))
    }
    
    public func serialize_i16(value: Int16) throws {
        let bytes = withUnsafeBytes(of: value.littleEndian) { Array($0) }
        output.append(contentsOf: bytes)
    }
    
    public func serialize_i32(value: Int32) throws {
        let bytes = withUnsafeBytes(of: value.littleEndian) { Array($0) }
        output.append(contentsOf: bytes)
    }
    
    public func serialize_i64(value: Int64) throws {
        let bytes = withUnsafeBytes(of: value.littleEndian) { Array($0) }
        output.append(contentsOf: bytes)
    }
    
    public func serialize_u8(value: UInt8) throws {
        output.append(value)
    }
    
    public func serialize_u16(value: UInt16) throws {
        let bytes = withUnsafeBytes(of: value.littleEndian) { Array($0) }
        output.append(contentsOf: bytes)
    }
    
    public func serialize_u32(value: UInt32) throws {
        let bytes = withUnsafeBytes(of: value.littleEndian) { Array($0) }
        output.append(contentsOf: bytes)
    }
    
    public func serialize_u64(value: UInt64) throws {
        let bytes = withUnsafeBytes(of: value.littleEndian) { Array($0) }
        output.append(contentsOf: bytes)
    }
    
    public func serialize_f32(value: Float) throws {
        let bytes = withUnsafeBytes(of: value.bitPattern.littleEndian) { Array($0) }
        output.append(contentsOf: bytes)
    }
    
    public func serialize_f64(value: Double) throws {
        let bytes = withUnsafeBytes(of: value.bitPattern.littleEndian) { Array($0) }
        output.append(contentsOf: bytes)
    }
    
    public func serialize_str(value: String) throws {
        let bytes = Array(value.utf8)
        try serialize_len(value: UInt64(bytes.count))
        output.append(contentsOf: bytes)
    }
    
    public func serialize_bytes(value: [UInt8]) throws {
        try serialize_len(value: UInt64(value.count))
        output.append(contentsOf: value)
    }
    
    public func serialize_len(value: UInt64) throws {
        try serialize_u64(value: value)
    }
    
    public func serialize_len(value: Int) throws {
        try serialize_u64(value: UInt64(value))
    }
    
    public func serialize_variant_index(value: UInt32) throws {
        try serialize_u32(value: value)
    }
    
    public func serialize_option_tag(value: Bool) throws {
        try serialize_bool(value: value)
    }
}

// MARK: - Bincode Deserializer

public class BincodeDeserializer: Deserializer {
    private var input: [UInt8]
    private var position: Int
    private var containerDepthBudget: UInt64
    
    public init(input: [UInt8]) {
        self.input = input
        self.position = 0
        self.containerDepthBudget = 500  // Default container depth limit
    }
    
    public func get_buffer_offset() -> UInt64 {
        return UInt64(position)
    }
    
    public func increase_container_depth() throws {
        if containerDepthBudget == 0 {
            throw DeserializationError.containerDepthLimitExceeded
        }
        containerDepthBudget -= 1
    }
    
    public func decrease_container_depth() throws {
        containerDepthBudget += 1
    }
    
    private func consume_bytes(_ count: Int) throws -> [UInt8] {
        guard position + count <= input.count else {
            throw DeserializationError.invalidInput(issue: "Unexpected end of input")
        }
        let bytes = Array(input[position..<position + count])
        position += count
        return bytes
    }
    
    public func deserialize_bool() throws -> Bool {
        let bytes = try consume_bytes(1)
        return bytes[0] != 0
    }
    
    public func deserialize_i8() throws -> Int8 {
        let bytes = try consume_bytes(1)
        return Int8(bitPattern: bytes[0])
    }
    
    public func deserialize_i16() throws -> Int16 {
        let bytes = try consume_bytes(2)
        return bytes.withUnsafeBytes { $0.load(as: Int16.self) }.littleEndian
    }
    
    public func deserialize_i32() throws -> Int32 {
        let bytes = try consume_bytes(4)
        return bytes.withUnsafeBytes { $0.load(as: Int32.self) }.littleEndian
    }
    
    public func deserialize_i64() throws -> Int64 {
        let bytes = try consume_bytes(8)
        return bytes.withUnsafeBytes { $0.load(as: Int64.self) }.littleEndian
    }
    
    public func deserialize_u8() throws -> UInt8 {
        let bytes = try consume_bytes(1)
        return bytes[0]
    }
    
    public func deserialize_u16() throws -> UInt16 {
        let bytes = try consume_bytes(2)
        return bytes.withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
    }
    
    public func deserialize_u32() throws -> UInt32 {
        let bytes = try consume_bytes(4)
        return bytes.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
    }
    
    public func deserialize_u64() throws -> UInt64 {
        let bytes = try consume_bytes(8)
        return bytes.withUnsafeBytes { $0.load(as: UInt64.self) }.littleEndian
    }
    
    public func deserialize_f32() throws -> Float {
        let bytes = try consume_bytes(4)
        let bits = bytes.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
        return Float(bitPattern: bits)
    }
    
    public func deserialize_f64() throws -> Double {
        let bytes = try consume_bytes(8)
        let bits = bytes.withUnsafeBytes { $0.load(as: UInt64.self) }.littleEndian
        return Double(bitPattern: bits)
    }
    
    public func deserialize_str() throws -> String {
        let len = try deserialize_len()
        let bytes = try consume_bytes(Int(len))
        guard let string = String(bytes: bytes, encoding: .utf8) else {
            throw DeserializationError.invalidInput(issue: "Invalid UTF-8 string")
        }
        return string
    }
    
    public func deserialize_bytes() throws -> [UInt8] {
        let len = try deserialize_len()
        return try consume_bytes(Int(len))
    }
    
    public func deserialize_len() throws -> UInt64 {
        return try deserialize_u64()
    }
    
    public func deserialize_variant_index() throws -> UInt32 {
        return try deserialize_u32()
    }
    
    public func deserialize_option_tag() throws -> Bool {
        return try deserialize_bool()
    }
    
    public func check_that_key_slices_are_increasing(key1: [UInt32], key2: [UInt32]) throws -> Bool {
        return key1.lexicographicallyPrecedes(key2)
    }
}

