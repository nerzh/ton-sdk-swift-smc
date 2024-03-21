// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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

import PackageDescription

let name: String = "TonSdkSwiftSmc"

var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/nerzh/ton-sdk-swift.git", .upToNextMajor(from: "1.0.0")),
    .package(url: "https://github.com/nerzh/swift-extensions-pack.git", .upToNextMajor(from: "1.19.1")),
]

var mainTarget: [Target.Dependency] = [
    .product(name: "TonSdkSwift", package: "ton-sdk-swift"),
    .product(name: "SwiftExtensionsPack", package: "swift-extensions-pack"),
]

var testTarget: [Target.Dependency] = mainTarget + [
    .init(stringLiteral: name)
]

let package = Package(
    name: name,
    platforms: [
        .macOS(.v13),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: name,
            targets: [name]),
    ],
    dependencies: packageDependencies,
    targets: [
        .target(
            name: name,
            dependencies: mainTarget
        ),
        .testTarget(
            name: "\(name)Tests",
            dependencies: testTarget
        ),
    ]
)


