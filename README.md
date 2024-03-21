# ton-sdk-swift-smc

Swift library for interaction with TON (The Open Network) smart contract

| OS | Result |
| ----------- | ----------- |
| MacOS | ✅ |
| Linux | ✅ |
| iOS | ✅ |
| Windows | ✅ |

## Installation

Install ton-sdk-swift-smc:

- `.package(url: "https://github.com/nerzh/ton-sdk-swift-smc", .upToNextMajor(from: "1.0.0")),`

## Example

```swift
import TonSdkSwiftSmc
import BigInt
import SwiftExtensionsPack
import XCTest

final class TTests: XCTestCase {
    
    let seed: String = "..."
    let publicKey: String = "..."
    let secretKey: String = "..."
    let apiKey: String = "..."



    /// HighloadWalletV2
    func testHighloadWalletV2() async throws {
        let api = ToncenterApi(apiKey: apiKey, protocol: .https)
        let wallet = try HighloadWalletV2(publicKey: publicKey.hexToBytes())
        print("hash", try wallet.code.hash())
        let address = wallet.address.toString(type: .base64)
        print(address)
        print("transfer > 0.1 TON to this address:", address)
        print("awaiting deposit ...")
        let isInit = try await api.jsonRpc().getAddressInformation(address: address).result?.state.lowercased() != "active"
        while true {
            if !isInit { break }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let balance = BigInt((try await api.jsonRpc().getAddressBalance(address: address).result?.toJSON().replace(#"\""#, "") ?? "0")) ?? 0
            let coins = Coins(nanoValue: balance)
            print("balance: \(balance)", coins.coinsValue)
            if coins.coinsValue >= 0.05 {
                break
            }
        }
        print("got deposit, initializing transfer to itself...")
        let comment = try CellBuilder().storeUInt(0, 32).storeString("My first transaction").cell()
        let comment2 = try CellBuilder().storeUInt(0, 32).storeString("My first transaction 2").cell()
        let transfers = [
            HighloadWalletTransfer(destination: wallet.address, bounce: false, value: Coins(0.0001), mode: 3, body: comment),
            HighloadWalletTransfer(destination: wallet.address, bounce: false, value: Coins(0.000101), mode: 3, body: comment2),
        ]
        let transfer = try wallet.buildTransfer(transfers: transfers, secret32Byte: secretKey.hexToBytes(), isInit: isInit)
        let boc = try Boc.serialize(root: [transfer.cell()]).toBase64()
        let out = try await api.jsonRpc().send(boc: boc)
        print("result:", out.result?.toJSON() ?? "", "error:", out.error ?? "")
    }



    /// WalletV3    
    func testWalletV3() async throws {
        let api = ToncenterApi(apiKey: apiKey, protocol: .https)
        let wallet = try WalletV3(pubkey: publicKey.hexToBytes())
        print("hash", try wallet.code.hash())
        let address = wallet.address.toString(type: .base64)
        print(address)
        print("transfer > 0.1 TON to this address:", address)
        print("awaiting deposit ...")
        let isInit = try await api.jsonRpc().getAddressInformation(address: address).result?.state.lowercased() != "active"
        while true {
            if !isInit { break }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let balance = BigInt((try await api.jsonRpc().getAddressBalance(address: address).result?.toJSON().replace(#"\""#, "") ?? "0")) ?? 0
            let coins = Coins(nanoValue: balance)
            print("balance: \(balance)", coins.coinsValue)
            if coins.coinsValue >= 0.05 {
                break
            }
        }
        print("got deposit, initializing transfer to itself...")
        let comment = try CellBuilder().storeUInt(0, 32).storeString("My first transaction").cell()
        let comment2 = try CellBuilder().storeUInt(0, 32).storeString("My first transaction 2").cell()
        let transfers = [
            WalletV3Transfer(destination: wallet.address, bounce: false, value: Coins(0.0001), mode: 3, body: comment),
            WalletV3Transfer(destination: wallet.address, bounce: false, value: Coins(0.000101), mode: 3, body: comment2),
        ]
        
        var seqno: UInt32 = 0
        let wallet_info = try await api.jsonRpc().runGetMethod(address: address, method: "seqno", stack: []).result?.toDictionary() ?? [:]
        if
            ((wallet_info["exit_code"] as? Int) ?? -1) == 0,
            let seqnoStr = (wallet_info["stack"] as? [[String]])?.first?.last,
            let currentSeqno = UInt32(seqnoStr.delete0x, radix: 16)
        {
            seqno = currentSeqno
        }
        
        let transfer = try wallet.buildTransfer(transfers: transfers, seqno: seqno, privateKey: secretKey.hexToBytes(), isInit: isInit)
        let boc = try Boc.serialize(root: [transfer.cell()]).toBase64()
        let out = try await api.jsonRpc().send(boc: boc)
        print("result:", out.result?.toJSON() ?? "", "error:", out.error ?? "")
    }



    /// WalletV4
    func testWalletV4() async throws {
        let api = ToncenterApi(apiKey: apiKey, protocol: .https)
        let wallet = try WalletV4(pubkey: publicKey.hexToBytes())
        print("hash", try wallet.code.hash())
        let address = wallet.address.toString(type: .base64)
        print(address)
        print("transfer > 0.1 TON to this address:", address)
        print("awaiting deposit ...")
        let isInit = try await api.jsonRpc().getAddressInformation(address: address).result?.state.lowercased() != "active"
        while true {
            if !isInit { break }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let balance = BigInt((try await api.jsonRpc().getAddressBalance(address: address).result?.toJSON().replace(#"\""#, "") ?? "0")) ?? 0
            let coins = Coins(nanoValue: balance)
            print("balance: \(balance)", coins.coinsValue)
            if coins.coinsValue >= 0.05 {
                break
            }
        }
        print("got deposit, initializing transfer to itself...")
        let comment = try CellBuilder().storeUInt(0, 32).storeString("My first transaction").cell()
        let comment2 = try CellBuilder().storeUInt(0, 32).storeString("My first transaction 2").cell()
        let transfers = [
            WalletV4Transfer(destination: wallet.address, bounce: false, value: Coins(0.0001), mode: 3, body: comment),
            WalletV4Transfer(destination: wallet.address, bounce: false, value: Coins(0.000101), mode: 3, body: comment2),
        ]
        
        var seqno: UInt32 = 0
        let wallet_info = try await api.jsonRpc().runGetMethod(address: address, method: "seqno", stack: []).result?.toDictionary() ?? [:]
        if
            ((wallet_info["exit_code"] as? Int) ?? -1) == 0,
            let seqnoStr = (wallet_info["stack"] as? [[String]])?.first?.last,
            let currentSeqno = UInt32(seqnoStr.delete0x, radix: 16)
        {
            seqno = currentSeqno
        }
        
        let transfer = try wallet.buildTransfer(transfers: transfers, seqno: seqno, privateKey: secretKey.hexToBytes(), isInit: isInit)
        let boc = try Boc.serialize(root: [transfer.cell()]).toBase64()
        let out = try await api.jsonRpc().send(boc: boc)
        print("result:", out.result?.toJSON() ?? "", "error:", out.error ?? "")
    }
}
```

## License

LGPL-3.0

## Mentions

I would like to thank [cryshado](https://github.com/cryshado) for their valuable advice and help in developing this library.
