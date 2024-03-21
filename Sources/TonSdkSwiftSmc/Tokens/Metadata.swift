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

public struct MetaDataContent {
    public var uri: String?
    public var name: String?
    public var description: String?
    public var image: String?
    public var imageData: String?
    public var symbol: String?
    public var decimals: String?
    
    public init(uri: String? = nil, name: String? = nil, description: String? = nil, image: String? = nil, imageData: String? = nil, symbol: String? = nil, decimals: String? = nil) {
        self.uri = uri
        self.name = name
        self.description = description
        self.image = image
        self.imageData = imageData
        self.symbol = symbol
        self.decimals = decimals
    }
}

public enum MetaData {
    case offchain(String)
    case onchain(MetaDataContent)
    
    public static func parseTokenMetadata(_ daSlice: CellSlice) throws -> Self {
        let pumPurumTag = try daSlice.loadBigUInt(size: 8)
        
        if pumPurumTag == 0x01 {
            return .offchain(try parseOffChainMetadata(daSlice))
        } else {
            return .onchain(try parseOnChainMetadata(daSlice))
        }
    }
    
    private static func parseOnChainMetadata(_ slice: CellSlice) throws -> MetaDataContent {
        var resultVotDa: MetaDataContent = .init()
        
        let dick = try slice.loadDict(
            keySize: 256,
            options: HashmapOptions<String, Cell>(
                deserializers: (
                    key: { bits in
                        let slice = try CellSlice.parse(cell: CellBuilder().storeBits(bits).cell())
                        let just_value = try slice.loadBytes(size: 32)
                        return just_value.toHexadecimal
                    },
                    value: { cell in
                        return try cell.parse().loadRef()
                    }
                )
            )
        )
        
        try dick.forEach { (key: LazyDeserialize<String>, value: LazyDeserialize<Cell>) in
            for tokenAttributesCase in TokenAttributesSHA256.allCases {
                if tokenAttributesCase.rawValue == (try key.deserialize()) {
                    let cs = try value.deserialize().parse()
                    let daContentTag = try cs.loadBigUInt(size: 8)
                    if daContentTag == 0x00 {
                        switch tokenAttributesCase {
                        case .name:
                            resultVotDa.name = try parseOffChainMetadata(cs)
                        case .decimals:
                            resultVotDa.decimals = try parseOffChainMetadata(cs)
                        case .description:
                            resultVotDa.description = try parseOffChainMetadata(cs)
                        case .image:
                            resultVotDa.image = try parseOffChainMetadata(cs)
                        case .imageData:
                            resultVotDa.imageData = try parseOffChainMetadata(cs)
                        case .symbol:
                            resultVotDa.symbol = try parseOffChainMetadata(cs)
                        case .uri:
                            resultVotDa.uri = try parseOffChainMetadata(cs)
                        }
                    } else{
                        throw ErrorTonSdkSwiftSmc("Chuncked data unsupported")
                    }
                }
            }
        }
        
        return resultVotDa
    }
    
    private static func parseOffChainMetadata(_ slice: CellSlice) throws -> String {
        var string = try slice.loadString(size: slice.bits.count / 8)
        while slice.refs.count > 0 {
            let nextSlice = try slice.loadRef().parse()
            string += try nextSlice.loadString(size: nextSlice.bits.count / 8)
        }
        return string
    }
}

