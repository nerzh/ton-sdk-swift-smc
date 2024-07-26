/*
    ton-sdk-swift-smc – commonly used tvm contracts swift package

    Copyright (C) 2023 Oleh Hudeichuk

    This file is part of ton-sdk-swift-smc.

    ton-sdk-swift-smc is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as
published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

  ton-sdk-swift-smc is distributed in the hope that it will be useful,
                                                              but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
                                    along with ton-sdk-swift-smc. If not, see <https://www.gnu.org/licenses/>.
*/

import Foundation
import TonSdkSwift
import BigInt
import SwiftExtensionsPack

public struct HighloadWalletTransfer {
    public var destination: Address
    public var bounce: Bool
    public var value: Coins
    public var mode: UInt8
    public var body: Cell?
    public var stateInit: StateInit?

    public init(destination: Address, bounce: Bool, value: Coins, mode: UInt8, body: Cell? = nil, stateInit: StateInit? = nil) {
        self.destination = destination
        self.bounce = bounce
        self.value = value
        self.mode = mode
        self.body = body
        self.stateInit = stateInit
    }
}


public struct HighloadWalletV2 {
    
    /*
     The source code and LICENSE of the "HighloadWalletV2":
     https://github.com/ton-blockchain/ton

    "HighloadWalletV2_CODE = ..." is a compiled version (byte code) of
    the "HighloadWalletV2" in the bag of cells
    serialization in hexadecimal representation.

    code cell hash(sha256): 9494d1cc8edf12f05671a1a9ba09921096eb50811e1924ec65c3c629fbb80812

    Respect the rights of open source software. Thanks!
    If you notice copyright violation, please create an issue.
    https://github.com/nerzh/ton-sdk-swift-smc/issues
    */
    public let HighloadWalletV2_CODE: String = "B5EE9C724101090100E5000114FF00F4A413F4BCF2C80B010201200203020148040501EAF28308D71820D31FD33FF823AA1F5320B9F263ED44D0D31FD33FD3FFF404D153608040F40E6FA131F2605173BAF2A207F901541087F910F2A302F404D1F8007F8E16218010F4786FA5209802D307D43001FB009132E201B3E65B8325A1C840348040F4438AE63101C8CB1F13CB3FCBFFF400C9ED54080004D03002012006070017BD9CE76A26869AF98EB85FFC0041BE5F976A268698F98E99FE9FF98FA0268A91040207A0737D098C92DBFC95DD1F140034208040F4966FA56C122094305303B9DE2093333601926C21E2B39F9E545A"
    
    public let code: Cell
    public let pubkey: Data
    public let subWalletId: UInt32
    public let stateInit: StateInit
    public let address: Address

    public init(workchain: Int8 = 0, publicKey: Data, subWalletId: UInt32 = 0) throws {
        guard let code = try Boc.deserialize(data: HighloadWalletV2_CODE.lowercased().hexToBytes()).first else {
            throw ErrorTonSdkSwiftSmc("Bad Wallet_v3 Code")
        }
        self.code = code
        self.pubkey = publicKey
        self.subWalletId = subWalletId
        self.stateInit = try Self.buildStateInit(code: code, subWalletId: subWalletId, publicKey: pubkey)
        self.address = try Address(address: "\(workchain):\(stateInit.cell().hash())")
    }

    private static func generateQueryId(validUntil: UInt32, randomId: UInt32? = nil) -> UInt64 {
        let random = randomId ?? UInt32(randomUInt(min: 0, max: UInt((2 ** 32) - 1)))
        return UInt64(validUntil) << 32 | UInt64(random)
    }

    public func buildTransfer(
        transfers: [HighloadWalletTransfer],
        secret32Byte: Data,
        isInit: Bool = false,
        validUntil: UInt32 = UInt32(Date().toSeconds()) + 60,
        queryId: UInt64? = nil
    ) throws -> Message {
        if transfers.isEmpty || transfers.count > 254 {
            throw ErrorTonSdkSwiftSmc("ContractHighloadWalletV2: can make only 1 to 254 transfers per operation.")
        }

        let queryId = queryId ?? HighloadWalletV2.generateQueryId(validUntil: validUntil)
        let body = try CellBuilder()
            .storeUInt(BigUInt(subWalletId), 32)
            .storeUInt(BigUInt(queryId), 64)
        
        let dict = try HashmapE<BigInt, HighloadWalletTransfer>(
            keySize: 16,
            options: HashmapOptions<BigInt, HighloadWalletTransfer>(
                serializers: (
                    key: { number in
                        let bits = try CellBuilder().storeInt(number, 16).bits
                        return bits
                    },
                    value: { transfer in
                        let internalMessage = try Message(options: MessageOptions(
                            info: .intMsgInfo(.init(bounce: transfer.bounce, dest: transfer.destination, value: transfer.value)),
                            stateInit: transfer.stateInit,
                            body: transfer.body))
                        return try CellBuilder()
                            .storeUInt(BigUInt(transfer.mode), 8)
                            .storeRef(internalMessage.cell())
                            .cell()
                    }
                )
            )
        )
        
        for (index, transfer) in transfers.enumerated() {
            try dict.set(BigInt(index), transfer)
        }
        
        try body.storeDict(dict)
        let signature = try body.cell().sign(secretKey32byte: secret32Byte)
        
        let messageBody = try CellBuilder()
            .storeBytes(signature)
            .storeSlice(body.cell().parse())
        
        let stateInit = isInit ? self.stateInit : nil

        return try Message(options: .init(info: .extInMsgInfo(.init(dest: address)), stateInit: stateInit, body: messageBody.cell()))
    }
    
    private static func buildStateInit(code: Cell, subWalletId: UInt32, publicKey: Data) throws -> StateInit {
        let data = try CellBuilder()
            .storeUInt(BigUInt(subWalletId), 32)
            .storeUInt(0, 64)
            .storeBytes(publicKey)
            .storeDict(HashmapE<Void, Void>(keySize: 16))
        
        return try StateInit(options: StateInitOptions(code: code, data: data.cell()))
    }
}
