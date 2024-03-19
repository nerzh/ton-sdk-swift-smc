//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 19.03.2024.
//

import Foundation
import TonSdkSwift
import BigInt

public struct WalletV3Transfer {
    public var destination: Address
    public var bounce: Bool
    public var value: Coins
    public var mode: UInt8
    public var body: Cell?
    public var initValue: StateInit?

    public init(destination: Address, bounce: Bool, value: Coins, mode: UInt8, body: Cell? = nil, initValue: StateInit? = nil) {
        self.destination = destination
        self.bounce = bounce
        self.value = value
        self.mode = mode
        self.body = body
        self.initValue = initValue
    }
}

public struct WalletV3 {
    public static let WALLET_V3_CODE: String = "B5EE9C724101010100710000DEFF0020DD2082014C97BA218201339CBAB19F71B0ED44D0D31FD31F31D70BFFE304E0A4F2608308D71820D31FD31FD31FF82313BBF263ED44D0D31FD31FD3FFD15132BAF2A15144BAF2A204F901541055F910F2A3F8009320D74A96D307D402FB00E8D101A4C8CB1FCB1FCBFFC9ED5410BD6DAD"
    public static let SUB_WALLET_ID: UInt32 = 698983191

    public var code: Cell
    public let pubkey: Data
    public let subWalletId: UInt32
    public var initValue: StateInit
    public var address: Address

    public init(pubkey: Data, wc: Int = 0, subWalletId: UInt32 = WalletV3.SUB_WALLET_ID) throws {
        self.pubkey = pubkey
        self.subWalletId = subWalletId
        guard let code = try Serializer.deserialize(data: Self.WALLET_V3_CODE.hexToBytes()).first else {
            throw ErrorTonSdkSwiftSmc("Bad Wallet_v3 Code")
        }
        self.code = code
        self.initValue = try Self.buildStateInit(code: code, pubkey: pubkey, subWalletId: subWalletId)
        self.address = try Address(address: "\(wc):\(initValue.cell().hash())")
    }
    
    public init(pubkey: String, wc: Int = 0, subWalletId: UInt32 = WalletV3.SUB_WALLET_ID) throws {
        try self.init(pubkey: pubkey.hexToBytes(), wc: wc, subWalletId: subWalletId)
    }

    public static func parseStorage(storageSlice: CellSlice) throws -> (seqno: UInt32, subWalletId: UInt32, pubkey: Data) {
        let seqno = try storageSlice.loadBigUInt(size: 32)
        let subWalletId = try storageSlice.loadBigUInt(size: 32)
        let pubkey = try storageSlice.loadBytes(size: 32)
        
        return (seqno: UInt32(seqno), subWalletId: UInt32(subWalletId), pubkey: pubkey)
    }

    public func buildTransfer(transfers: [WalletV3Transfer], seqno: UInt32, privateKey: Data, isInit: Bool = false, timeout: UInt = 60) throws -> Message {
        if transfers.count > 4 {
            throw ErrorTonSdkSwiftSmc("Wallet v3 can handle only 4 transfers at once")
        }

        let body = try CellBuilder()
            .storeUInt(BigUInt(subWalletId), 32)
            .storeUInt(BigUInt(Date().toSeconds() + timeout), 32)
            .storeUInt(BigUInt(seqno), 32)

        for transfer in transfers {
            let info = CommonMsgInfo.intMsgInfo(CommonMsgInfo.IntMsgInfo(bounce: transfer.bounce, dest: transfer.destination, value: transfer.value))

            let message = try Message(options: MessageOptions(info: info, initOptions: transfer.initValue, body: transfer.body))

            try body.storeUInt(BigUInt(transfer.mode), 8)
            try body.storeRef(message.cell())
        }
        
        let signature = try body.cell().sign(secretKey32byte: privateKey)
        
        let messageBody = try CellBuilder()
            .storeBytes(signature)
            .storeSlice(body.cell().parse())
        
        let info = CommonMsgInfo.extInMsgInfo(CommonMsgInfo.ExtInMsgInfo(dest: address))
        
        let initT = isInit ? initValue : nil
        let bodyCell = try messageBody.cell()

        return try Message(options: MessageOptions(info: info, initOptions: initT, body: bodyCell))
    }
    
    public func buildTransfer(transfers: [WalletV3Transfer], seqno: UInt32, privateKey: String, isInit: Bool = false, timeout: UInt = 60) throws -> Message {
        try buildTransfer(transfers: transfers, seqno: seqno, privateKey: privateKey.hexToBytes(), isInit: isInit, timeout: timeout)
    }

    private static func buildStateInit(code: Cell, pubkey: Data, subWalletId: UInt32) throws -> StateInit {
        let data = try CellBuilder()
            .storeUInt(0, 32)
            .storeUInt(BigUInt(subWalletId), 32)
            .storeBytes(pubkey)

        return try StateInit(stateInitOptions: StateInitOptions(code: code, data: data.cell()))
    }
}
