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

public struct PWV2Transfer {
    public var destination: Address
    public var bounce: Bool
    public var value: Coins
    public var mode: UInt8
    public var body: Cell?
    public var initOptions: StateInit?
    
    public init(destination: Address, bounce: Bool, value: Coins, mode: UInt8, body: Cell? = nil, initOptions: StateInit? = nil) {
        self.destination = destination
        self.bounce = bounce
        self.value = value
        self.mode = mode
        self.body = body
        self.initOptions = initOptions
    }
}


public struct PWV2 {
    public var code: Cell
    public var pubkey: Data
    public var initOptions: StateInit
    public var address: Address
    
    public init(pubkey: Data, wc: Int = 0) throws {
        self.pubkey = pubkey
        guard let code = try Serializer.deserialize(data: PWV2_CODE.lowercased().hexToBytes()).first else {
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
        timeout: UInt64 = 60
    ) throws -> Message {
        if !(transfers.count > 0 && !transfers.isEmpty) {
            throw ErrorTonSdkSwiftSmc("Transfers must be an array of PWV2Transfer")
        }
        if !(transfers.count <= 255) {
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
                outMsg: Message(options: MessageOptions(info: info, initOptions: transfer.initOptions, body: transfer.body))
            ))
            
            actions.append(action)
        }
        
        let outList = try OutList(options: OutListOptions(action: actions))
        
        let msgInner = try CellBuilder()
            .storeUInt(BigUInt(UInt64(Date().toSeconds()) + timeout), 64)
            .storeUInt(BigUInt(seqno), 16)
            .storeRef(outList.cell())
            .cell()
        
        let sign = try msgInner.sign(secretKey32byte: secretKey32byte)
        
        let msgBody = try CellBuilder()
            .storeBytes(sign)
            .storeRef(msgInner)
            .cell()
        
        let info = CommonMsgInfo.extInMsgInfo(CommonMsgInfo.ExtInMsgInfo(dest: address))
        
        let initOptions = isInit ? self.initOptions : nil
        
        return try Message(
            options: MessageOptions(
                info: info,
                initOptions: initOptions,
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
        return try StateInit(stateInitOptions: options)
    }
}
