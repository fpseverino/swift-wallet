# Create a Personalizable Pass

Create and sign personalized passes for the Apple Wallet app.

## Overview

> Warning: This section is a work in progress. Testing is hard without access to the certificates required to develop this feature. If you have access to the entitlements, please help us implement this feature.

Pass Personalization lets you create passes, referred to as personalizable passes, that prompt the user to provide personal information during signup that will be sent to your server.

> Important: Making a pass personalizable, just like adding NFC to a pass, requires a special entitlement issued by Apple. Although accessing such entitlements is hard if you're not a big company, you can learn more in [Getting Started with Apple Wallet](https://developer.apple.com/wallet/get-started/).

Personalizable passes can be distributed like any other pass, but you'll need to setup a web server to handle the personalization.

For information on personalizable passes, see the [Wallet Developer Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/PassPersonalization.html#//apple_ref/doc/uid/TP40012195-CH12-SW2) and [Return a Personalized Pass](https://developer.apple.com/documentation/walletpasses/return_a_personalized_pass).

### Getting Started

A personalizable pass is just a standard pass package with the following additional files:

- A `personalization.json` file.
- A `personalizationLogo@XX.png` file.

To make a pass personalizable, you need to pass a ``PersonalizationJSON`` object to ``PassBuilder/build(pass:sourceFilesDirectoryPath:personalization:)``, and the source files directory must contain the `personalizationLogo@XX.png` file.

Once you've built the pass, you can distribute it like any other pass.
The user will be prompted to provide the required personal information when they add the pass.
Wallet will then send the user personal information to your server.
Immediately after that, the Wallet app will request the updated pass.

> Important: The updated and personalized pass **must not** contain the `personalization.json` file.

## Topics

- ``PersonalizationJSON``
