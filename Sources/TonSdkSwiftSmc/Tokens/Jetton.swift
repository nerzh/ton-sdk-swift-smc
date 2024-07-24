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

public struct Jetton {
    
    /*
     transfer#0f8a7ea5 query_id:uint64 amount:(VarUInteger 16) destination:MsgAddress
                      response_destination:MsgAddress custom_payload:(Maybe ^Cell)
                      forward_ton_amount:(VarUInteger 16) forward_payload:(Either Cell ^Cell)
                      = InternalMsgBody;
    */
    public static func buildTransfer(
        queryId: UInt64,
        amount: Coins,
        destination: Address,
        responseDestination: Address,
        forwardTonAmount: Coins,
        forwardPayload: Cell,
        customPayload: Cell? = nil
    ) throws -> Cell {
        
        let body = try CellBuilder()
            .storeUInt(0x0f8a7ea5, 32)
            .storeUInt(BigUInt(queryId), 64)
            .storeCoins(amount)
            .storeAddress(destination)
            .storeAddress(responseDestination)
            .storeMaybeRef(customPayload)
            .storeCoins(forwardTonAmount)
        
        if body.bits.count + forwardPayload.bits.count > 1023 || body.refs.count + forwardPayload.refs.count > 4 {
            try body.storeBit(.b1)
            try body.storeRef(forwardPayload)
        } else {
            try body.storeBit(.b0)
            try body.storeSlice(forwardPayload.parse())
        }
        return try body.cell()
    }
    
    /*
     burn#595f07bc query_id:uint64 amount:(VarUInteger 16)
                   response_destination:MsgAddress custom_payload:(Maybe ^Cell)
                   = InternalMsgBody;
    */
    public static func buildBurn(queryId: UInt64, amount: Coins, responseDestination: Address, customPayload: Cell? = nil) throws -> Cell {
        let body = try CellBuilder()
            .storeUInt(0x595f07bc, 32)
            .storeUInt(BigUInt(queryId), 64)
            .storeCoins(amount)
            .storeAddress(responseDestination)
            .storeMaybeRef(customPayload)
        return try body.cell()
    }
}

