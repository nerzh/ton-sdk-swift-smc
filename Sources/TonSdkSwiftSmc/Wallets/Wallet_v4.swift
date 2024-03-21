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

public struct WalletV4Transfer {
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

public class WalletV4 {
    /*
    The source code and LICENSE of the "wallet v4 r2" smart contract:
    https://github.com/toncenter/tonweb/blob/master/src/contract/wallet/WalletSources.md
     
    "WALLET_V4_CODE = ..." is a compiled version (byte code) of
    the smart contract "wallet-v4-r2-code.fif" in the bag of cells
    serialization in hexadecimal representation.

    code cell hash(sha256): FEB5FF6820E2FF0D9483E7E0D62C817D846789FB4AE580C878866D959DABD5C0

    Respect the rights of open source software. Thanks! :)
    If you notice copyright violation, please create an issue:
    https://github.com/nerzh/ton-sdk-swift-smc/issues
    */
    public static let WALLET_V4_CODE = "B5EE9C72410214010002D4000114FF00F4A413F4BCF2C80B010201200203020148040504F8F28308D71820D31FD31FD31F02F823BBF264ED44D0D31FD31FD3FFF404D15143BAF2A15151BAF2A205F901541064F910F2A3F80024A4C8CB1F5240CB1F5230CBFF5210F400C9ED54F80F01D30721C0009F6C519320D74A96D307D402FB00E830E021C001E30021C002E30001C0039130E30D03A4C8CB1F12CB1FCBFF1011121302E6D001D0D3032171B0925F04E022D749C120925F04E002D31F218210706C7567BD22821064737472BDB0925F05E003FA403020FA4401C8CA07CBFFC9D0ED44D0810140D721F404305C810108F40A6FA131B3925F07E005D33FC8258210706C7567BA923830E30D03821064737472BA925F06E30D06070201200809007801FA00F40430F8276F2230500AA121BEF2E0508210706C7567831EB17080185004CB0526CF1658FA0219F400CB6917CB1F5260CB3F20C98040FB0006008A5004810108F45930ED44D0810140D720C801CF16F400C9ED540172B08E23821064737472831EB17080185005CB055003CF1623FA0213CB6ACB1FCB3FC98040FB00925F03E20201200A0B0059BD242B6F6A2684080A06B90FA0218470D4080847A4937D29910CE6903E9FF9837812801B7810148987159F31840201580C0D0011B8C97ED44D0D70B1F8003DB29DFB513420405035C87D010C00B23281F2FFF274006040423D029BE84C600201200E0F0019ADCE76A26840206B90EB85FFC00019AF1DF6A26840106B90EB858FC0006ED207FA00D4D422F90005C8CA0715CBFFC9D077748018C8CB05CB0222CF165005FA0214CB6B12CCCCC973FB00C84014810108F451F2A7020070810108D718FA00D33FC8542047810108F451F2A782106E6F746570748018C8CB05CB025006CF165004FA0214CB6A12CB1FCB3FC973FB0002006C810108D718FA00D33F305224810108F459F2A782106473747270748018C8CB05CB025005CF165003FA0213CB6ACB1F12CB3FC973FB00000AF400C9ED54696225E5"
    public static let SUB_WALLET_ID: UInt32 = 698983191

    public let code: Cell
    public let pubkey: Data
    public let initValue: StateInit
    public let address: Address
    public let subWalletId: UInt32

    public init(pubkey: Data, wc: Int = 0, subWalletId: UInt32 = WalletV4.SUB_WALLET_ID) throws {
        self.pubkey = pubkey
        self.subWalletId = subWalletId
        guard let code = try Boc.deserialize(data: WalletV4.WALLET_V4_CODE.hexToBytes()).first else {
            throw ErrorTonSdkSwiftSmc("Bad Wallet_v4 Code")
        }
        self.code = code
        self.initValue = try Self.buildStateInit(code: code, pubkey: pubkey, subWalletId: subWalletId)
        self.address = try Address(address: "\(wc):\(initValue.cell().hash())")
    }

    public static func parseStorage(_ storageSlice: CellSlice) throws -> (seqno: UInt32, subWalletId: UInt32, pubkey: Data, pluginsList: [Address]) {
        var pluginsList: [Address] = []
        
        let seqno: UInt32 = try UInt32(storageSlice.loadBigUInt(size: 32))
        let subWalletId: UInt32 = try UInt32(storageSlice.loadBigUInt(size: 32))
        let pubkey: Data = try storageSlice.loadBytes(size: 32)
        
        let hashmapE: HashmapE<Address,Void> = try storageSlice.loadDict(
            keySize: 8 + 256,
            options: HashmapOptions<Address,Void>(
                deserializers: (
                    key: { bits in
                        let slice = try CellSlice.parse(cell: CellBuilder().storeBits(bits).cell())
                        let wc = try slice.loadBigInt(size: 8)
                        let addr = try slice.loadBytes(size: 32)
                        return try Address(address: "\(wc):\(addr.toHexadecimal)")
                    },
                    value: { _ in }
                )
            )
        )
        
        try hashmapE.forEach { (key: LazyDeserialize<Address>, value: LazyDeserialize<Void>) in
            try pluginsList.append(key.deserialize())
        }
        
        return (
            seqno: seqno,
            subWalletId: subWalletId,
            pubkey: pubkey,
            pluginsList: pluginsList
        )
    }


    public func buildTransfer(transfers: [WalletV4Transfer], seqno: UInt32, privateKey: Data, isInit: Bool = false, timeout: UInt = 60) throws -> Message {
        if transfers.count > 4 {
            throw ErrorTonSdkSwiftSmc("Wallet v4 can handle only 4 transfers at once")
        }

        let body = try CellBuilder()
            .storeUInt(BigUInt(subWalletId), 32)
            .storeUInt(BigUInt(Date().toSeconds() + timeout), 32)
            .storeUInt(BigUInt(seqno), 32)
            .storeUInt(0, 8)

        for transfer in transfers {
            let info = CommonMsgInfo.intMsgInfo(.init(bounce: transfer.bounce, dest: transfer.destination, value: transfer.value))
            let message = try Message(options: MessageOptions(info: info, stateInit: transfer.stateInit, body: transfer.body))
            try body.storeUInt(BigUInt(transfer.mode), 8)
            try body.storeRef(message.cell())
        }

        let signature = try body.cell().sign(secretKey32byte: privateKey)
        let messageBody = try CellBuilder()
            .storeBytes(signature)
            .storeSlice(body.cell().parse())

        let info = CommonMsgInfo.extInMsgInfo(.init(dest: address))
        let stateInit = isInit ? self.initValue : nil

        return try Message(options: MessageOptions(info: info, stateInit: stateInit, body: messageBody.cell()))
    }

    private static func buildStateInit(code: Cell, pubkey: Data, subWalletId: UInt32) throws -> StateInit {
        let data = try CellBuilder()
            .storeUInt(0, 32)
            .storeUInt(BigUInt(subWalletId), 32)
            .storeBytes(pubkey)
            .storeBit(.b0) // Placeholder for some field
        
        return try StateInit(options: try StateInitOptions(code: code, data: data.cell()))
    }
}
