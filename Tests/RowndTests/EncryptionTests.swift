//
//  EncryptionTests.swift
//  RowndTests
//
//  Created by Matt Hamann on 7/15/22.
//

import XCTest
@testable import Rownd

class EncryptionTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        RowndEncryption.deleteKey(keyId: "my-test-account")
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        RowndEncryption.deleteKey(keyId: "my-test-account")
        try super.tearDownWithError()
    }

    func testGenerateSymmetricKey() throws {
        let key = RowndEncryption.generateKey()
        print("base64 key:", String(decoding: key.asData().base64EncodedData(), as: UTF8.self))
        XCTAssertNotNil(key, "Generated encryption key was nil")
    }

    func testStoreSymmetricKey() throws {
        let key = RowndEncryption.generateKey()
        try RowndEncryption.storeKey(key: key, keyId: "my-test-account")
        print("base64 key:", String(decoding: key.asData().base64EncodedData(), as: UTF8.self))
        let atch = XCTAttachment(data: key.asData().base64EncodedData())
        self.add(atch)
    }

    func testRetrieveSymmetricKey() throws {
        let origKey = RowndEncryption.generateKey()
        try RowndEncryption.storeKey(key: origKey, keyId: "my-test-account")
        print("stored key:", String(decoding: origKey.asData().base64EncodedData(), as: UTF8.self))
        let retKey = try RowndEncryption.loadKey(keyId: "my-test-account")
        XCTAssertNotNil(retKey, "Failed to retrieve a key that should exist")
        XCTAssertEqual(String(decoding: origKey.asData().base64EncodedData(), as: UTF8.self), String(decoding: retKey?.asData().base64EncodedData() ?? Data(), as: UTF8.self), "Stored and retrieved keys are not equal")

        guard let key = retKey else {
            return
        }

        print("retrieved key:", String(decoding: key.asData().base64EncodedData(), as: UTF8.self))
//        print(key.asData().base64EncodedData())
        let atch = XCTAttachment(data: key.asData().base64EncodedData())
        self.add(atch)
    }

    func testEncryptingData() throws {
        let keyId = "test-key"
        let key = Array(Data(base64Encoded: "4f4a6IInDuSga0wyQQQpMSrDHIZ/ryoc9w6s5xVF/VQ=")!)
        RowndEncryption.storeKey(key: key, keyId: keyId)

        let plainText = "This super secret string will never be known."
        let cipherText: String = try RowndEncryption.encrypt(plaintext: plainText, withKeyId: keyId)

        print(cipherText)

        XCTAssertNotNil(cipherText, "Failed to encrypt plaintext into ciphertext")
    }

    func testDecryptingData() throws {
        let keyId = "test-key"
        let key = Array(Data(base64Encoded: "4f4a6IInDuSga0wyQQQpMSrDHIZ/ryoc9w6s5xVF/VQ=")!)
        RowndEncryption.storeKey(key: key, keyId: keyId)

        let expectedPlainText = "This super secret string will never be known."
        let cipherText = "Di0IyYbC141WIPKzFnlsQc0BIi1AWKSpLf6Th9TcDDJiidPfkVazXtFibnsqJyKFaQf7SaF68yihnqJXidodfKqKzjM2MnbHbh+O8wpxFO3gO6OhVg=="

        let computedPlainText: String = try RowndEncryption.decrypt(ciphertext: cipherText, withKeyId: keyId)

        print(computedPlainText)

        XCTAssertEqual(expectedPlainText, computedPlainText, "The computed plaintext did not match the expected")
    }

    func testEncryptThenDecrypt() throws {
        let keyId = "test-key"
        let key = RowndEncryption.generateKey()
        try RowndEncryption.storeKey(key: key, keyId: keyId)

        let plainText = "This super secret string will never be known."
        let cipherText: String = try RowndEncryption.encrypt(plaintext: plainText, withKeyId: keyId)

        print(cipherText)

        let computedPlainText: String = try RowndEncryption.decrypt(ciphertext: cipherText, withKeyId: keyId)

        print(computedPlainText)

        XCTAssertEqual(plainText, computedPlainText, "The original and computed plaintexts do not match even though the key matched")
    }
}
