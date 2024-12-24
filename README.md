# Swift Wallet

🎟️ 📦 Create passes and orders for the Apple Wallet app.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ffpseverino%2Fswift-wallet%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/fpseverino/swift-wallet)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ffpseverino%2Fswift-wallet%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/fpseverino/swift-wallet)

[![](https://img.shields.io/github/actions/workflow/status/fpseverino/swift-wallet/test.yml?event=push&style=plastic&logo=github&label=tests&logoColor=%23ccc)](https://github.com/fpseverino/swift-wallet/actions/workflows/test.yml)
[![](https://img.shields.io/codecov/c/github/fpseverino/swift-wallet?style=plastic&logo=codecov&label=codecov)](https://codecov.io/github/fpseverino/swift-wallet)

## Overview

This package provides tools to create passes and orders for the Apple Wallet app.

### Getting Started

Use the SPM string to easily include the dependendency in your `Package.swift` file

```swift
.package(url: "https://github.com/fpseverino/swift-wallet.git", branch: "main")
```

and add the product you want to use to your target's dependencies:

```swift
.product(name: "Passes", package: "swift-wallet")
```

```swift
.product(name: "Orders", package: "swift-wallet")
```
