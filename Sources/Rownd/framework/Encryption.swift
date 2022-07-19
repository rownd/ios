//
//  Encryption.swift
//  framework
//
//  Created by Matt Hamann on 7/7/22.
//

import Foundation
import SwiftKeychainWrapper
import Sodium

class RowndEncryption {
    private static let sodium = Sodium()
    static func generateKey() -> SecretBox.Key {
        let key = sodium.secretBox.key()
        return key
    }

    static func storeKey(key: SecretBox.Key, keyId: String?) -> Void {
        KeychainWrapper.standard.set(key.asData(), forKey: keyName(keyId))
    }

    static func loadKey(keyId: String?) -> SecretBox.Key? {
        let keyData = KeychainWrapper.standard.data(forKey: keyName(keyId))

        guard let keyData = keyData else {
            return nil
        }

        return Array(keyData) as SecretBox.Key
    }

    static func deleteKey(keyId: String?) -> Void {
        KeychainWrapper.standard.removeObject(forKey: keyName(keyId))
    }

    static private func keyName(_ keyId: String?) -> String {
        return "io.rownd.key.\(keyId ?? "default")"
    }
}

extension RowndEncryption {
    // MARK: Encrypt data methods
    public static func encrypt(plaintext: String, withKey key: SecretBox.Key) throws -> Data {
        let encrypted: Bytes? = sodium.secretBox.seal(message: plaintext.bytes, secretKey: key)

        guard let encrypted = encrypted else {
            throw EncryptionError("The specified value failed to encrypt (returned nil)")
        }

        return encrypted.withUnsafeBytes { body in
            Data(body)
        }
    }

    public static func encrypt(plaintext: String, withKey key: SecretBox.Key) throws -> String {
        let encrypted: Data = try encrypt(plaintext: plaintext, withKey: key)

        return encrypted.base64EncodedString()
    }

    public static func encrypt(plaintext: String, withKeyId keyId: String) throws -> Data {
        let key: SecretBox.Key? = try loadKey(keyId: keyId)

        guard let key = key else {
            throw KeyStoreError("The requested key '\(keyId)' could not be found")
        }

        return try encrypt(plaintext: plaintext, withKey: key)
    }

    public static func encrypt(plaintext: String, withKeyId keyId: String) throws -> String {
        let encrypted: Data = try encrypt(plaintext: plaintext, withKeyId: keyId)

        return encrypted.base64EncodedString()
    }

    // MARK: Decrypt data methods
    public static func decrypt(ciphertext: String, withKey key: SecretBox.Key) throws -> Data {


        // Decode the string data back to Bytes
        let encrypted = Data(base64Encoded: ciphertext)

        guard let encrypted = encrypted else {
            throw EncryptionError("Failed to read ciphertext. Not encoded as base64.")
        }

        let decrypted = sodium.secretBox.open(nonceAndAuthenticatedCipherText: Array(encrypted), secretKey: key)

        guard let decrypted = decrypted else {
            throw EncryptionError("Failed to decrypt the provided ciphertext. It may not be an encrypted string or the key may not match.")
        }

        return decrypted.withUnsafeBytes { body in
            Data(body)
        }
    }

    public static func decrypt(ciphertext: String, withKey key: SecretBox.Key) throws -> String {
        return String(decoding: try decrypt(ciphertext: ciphertext, withKey: key), as: UTF8.self)
    }

    public static func decrypt(ciphertext: String, withKeyId keyId: String) throws -> Data {
        let key: SecretBox.Key? = loadKey(keyId: keyId)

        guard let key = key else {
            throw KeyStoreError("The requested key '\(keyId)' could not be found")
        }

        return try decrypt(ciphertext: ciphertext, withKey: key)
    }

    public static func decrypt(ciphertext: String, withKeyId keyId: String) throws -> String {
        return String(decoding: try decrypt(ciphertext: ciphertext, withKeyId: keyId), as: UTF8.self)
    }
}

extension SecretBox.Key {
    func asData() -> Data {
        return self.withUnsafeBytes { body in
            Data(body)
        }
    }
}

protocol GenericPasswordConvertible: CustomStringConvertible {
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes
    var rawRepresentation: Data { get }
}

struct KeyStoreError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}

struct EncryptionError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}
