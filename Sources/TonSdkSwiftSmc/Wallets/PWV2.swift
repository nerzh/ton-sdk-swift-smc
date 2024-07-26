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

public struct PWV2Transfer {
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


public struct PWV2 {
    /*
     The source code and LICENSE of the "ton-preprocessed-wallet-v2":
     https://github.com/pyAndr3w/ton-preprocessed-wallet-v2

    "PWV2_CODE = ..." is a compiled version (byte code) of
    the "ton-preprocessed-wallet-v2" in the bag of cells
    serialization in hexadecimal representation.

    code cell hash(sha256): 45EBBCE9B5D235886CB6BFE1C3AD93B708DE058244892365C9EE0DFE439CB7B5

    Respect the rights of open source software. Thanks!
    If you notice copyright violation, please create an issue.
    https://github.com/nerzh/ton-sdk-swift-smc/issues
    */
    public let PWV2_CODE: String = "B5EE9C7241010101003D000076FF00DDD40120F90001D0D33FD30FD74CED44D0D3FFD70B0F20A4830FA90822C8CBFFCB0FC9ED5444301046BAF2A1F823BEF2A2F910F2A3F800ED552E766412"

    public let code: Cell
    public let pubkey: Data
    public let initOptions: StateInit
    public let address: Address
    
    public init(pubkey: Data, wc: Int = 0) throws {
        self.pubkey = pubkey
        guard let code = try Boc.deserialize(data: PWV2_CODE.lowercased().hexToBytes()).first else {
            throw ErrorTonSdkSwiftSmc("Code must be valid")
        }
        self.code = code
        self.initOptions = try Self.buildStateInit(pubkey: pubkey, code: code)
        let initCellHash = try self.initOptions.cell().hash()
        self.address = try Address(address: "\(wc):\(initCellHash)")
    }
    
    public static func parseStorage(storageSlice: CellSlice) throws -> (pubkey: Data, seqno: UInt16) {
        let pubkey = try storageSlice.loadBytes(size: 32)
        let seqno = try storageSlice.loadBigUInt(size: 16)
        return (pubkey: pubkey, seqno: UInt16(seqno))
    }
    
    public func buildTransfer(
        transfers: [PWV2Transfer],
        seqno: UInt16,
        secretKey32byte: Data,
        isInit: Bool = false,
        validUntil: UInt64 = UInt64(Date().toSeconds()) + 60
    ) throws -> Message {
        if transfers.isEmpty {
            throw ErrorTonSdkSwiftSmc("Transfers must be not empty array of PWV2Transfer")
        }
        if transfers.count > 255 {
            throw ErrorTonSdkSwiftSmc("PWV2 can handle only 255 transfers at once")
        }
        
        var actions = [OutAction]()
        for transfer in transfers {
            let info = CommonMsgInfo.intMsgInfo(CommonMsgInfo.IntMsgInfo(
                bounce: transfer.bounce,
                dest: transfer.destination,
                value: transfer.value
            ))
            let action = try OutAction.actionSendMsg(OutAction.ActionSendMsg(
                mode: transfer.mode,
                outMsg: Message(options: MessageOptions(info: info, stateInit: transfer.stateInit, body: transfer.body))
            ))
            
            actions.append(action)
        }
        
        let outList = try OutList(options: OutListOptions(action: actions))
        
        let msgInner = try CellBuilder()
            .storeUInt(BigUInt(validUntil), 64)
            .storeUInt(BigUInt(seqno), 16)
            .storeRef(outList.cell())
            .cell()
        
        let sign = try msgInner.sign(secretKey32byte: secretKey32byte)
        
        let msgBody = try CellBuilder()
            .storeBytes(sign)
            .storeRef(msgInner)
            .cell()
        
        let info = CommonMsgInfo.extInMsgInfo(CommonMsgInfo.ExtInMsgInfo(dest: address))
        
        let stateInit = isInit ? self.initOptions : nil
        
        return try Message(
            options: MessageOptions(
                info: info,
                stateInit: stateInit,
                body: msgBody
            )
        )
    }
    
    private static func buildStateInit(pubkey: Data, code: Cell?) throws -> StateInit {
        let data = try CellBuilder()
            .storeBytes(pubkey)
            .storeUInt(0, 16)
            .cell()
        
        let options = StateInitOptions(code: code, data: data)
        return try StateInit(options: options)
    }
}
