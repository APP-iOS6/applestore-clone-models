// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "applestore-clone-models",
    platforms: [.iOS(.v17)],
    products: [
        
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "applestore-clone-models",
            targets: ["applestore-clone-models"]
        ),
        
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.3.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0")
        
    ],
    
    targets: [
        .target(
            name: "applestore-clone-models",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS"),
                .product(name: "FirebaseAuthCombine-Community", package: "firebase-ios-sdk"),
            ] ),
        .testTarget(
            name: "applestore-clone-modelsTests",
            dependencies: ["applestore-clone-models"]
        ),
    ]
)
