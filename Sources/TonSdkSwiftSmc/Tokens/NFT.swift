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

public struct NFT {
    
    /*
     transfer#5fcc3d14 query_id:uint64 new_owner:MsgAddress response_destination:MsgAddress
                       custom_payload:(Maybe ^Cell) forward_amount:(VarUInteger 16)
                       forward_payload:(Either Cell ^Cell) = InternalMsgBody;
    */
    static func buildTransfer(
        queryId: UInt64,
        newOwner: Address,
        responseDestination: Address,
        forwardAmount: Coins,
        forwardPayload: Cell,
        customPayload: Cell? = nil
    ) throws -> Cell {
        let body = try CellBuilder()
            .storeUInt(0x5fcc3d14, 32)
            .storeUInt(BigUInt(queryId), 64)
            .storeAddress(newOwner)
            .storeAddress(responseDestination)
            .storeMaybeRef(customPayload)
            .storeCoins(forwardAmount)

        if body.bits.count + forwardPayload.bits.count > 1023 || body.refs.count + forwardPayload.refs.count > 4 {
            try body.storeBit(.b1)
            try body.storeRef(forwardPayload)
        } else {
            try body.storeBit(.b0)
            try body.storeSlice(forwardPayload.parse())
        }
        return try body.cell()
    }
}
