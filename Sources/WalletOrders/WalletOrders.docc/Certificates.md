# Generating the Certificates

Generate the certificates you need to sign your order.

## Overview

To instanciate a ``OrderBuilder`` you need to provide the following elements:
- WWDR (Apple WorldWide Developer Relations) G4 Certificate
- Order Type ID Certificate
- Order Type ID Certificate Private Key

The following steps will guide you through the process of generating these certificates on macOS.

You'll need to have OpenSSL installed on your machine.
Check if you have it installed by running the following command in your terminal:

```shell
openssl --version
```

> Important: To obtain the certificates you have to be a member of the Apple Developer Program.

### Create an Order Type Identifier

See [Create an order type identifier](https://developer.apple.com/documentation/walletorders/building-a-distributable-order-package#Create-an-order-type-identifier) in the Apple Developer Documentation.

### Download the WWDR G4 Certificate

Download the [WWDR G4 certificate](https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer), open it (or import it) in Keychain Access, filter for "Certificates" and identify your imported certificate.
Right-click on it and select Export AppleWWDRCAG4.
Choose the `.pem` file format and save it.

### Generate a Signing Certificate

Now follow Apple's guide on how to [Generate a signing certificate](https://developer.apple.com/documentation/walletorders/building-a-distributable-order-package#Generate-a-signing-certificate) in the Apple Developer Documentation.
After following the guide, you should have a `.cer` file.

Now open (or import) the Signing Certificate in Keychain Access.
Filter for "Certificates" and identify your imported certificate.
Right-click on it and select Export "CertificateName".
Choose the `.p12` file format and save it.
You'll be asked to set a password for the exported certificate.
You can leave it empty if you don't want to encrypt the certificate, but if you do, remember the password.

Next, open the Terminal and navigate to the directory where you saved the exported `.p12` file.
Run the following command to extract the certificate from the `.p12` file.
Change `<SigningCertificate>` to the name of your exported `.p12` certificate and `<p12Password>` to the password you set when exporting the certificate.
If you didn't set a password, remove `-passin pass:<p12Password>` from the command.

```shell
openssl pkcs12 -in <SigningCertificate>.p12 -clcerts -nokeys -out certificate.pem -passin pass:<p12Password> -legacy
```

Now run the following command to extract the private key from the `.p12` file.
Again, change `<SigningCertificate>` to the name of your exported `.p12` certificate and `<p12Password>` to the password you set when exporting the certificate, if you set one.
If you want to encrypt the private key with a password, change `<pemPrivateKeyPassword>` to the password you want to set.
Remember this password, you'll have to provide it when creating the ``OrderBuilder``.
If you don't want to encrypt the private key, remove `-passout pass:<pemPrivateKeyPassword>` from the command.

```shell
openssl pkcs12 -in <cert-name>.p12 -nocerts -out privateKey.pem -passin pass:<p12Password> -passout pass:<pemPrivateKeyPassword> -legacy
```

### Wrapping Up

You now have the WWDR G4 Certificate, the Order Type ID Certificate, and the Order Type ID Certificate Private Key, all in `.pem` format, and optionally a password for the private key.
Open the `.pem` files in a text editor and copy the content.
You'll need to provide this content as Swift `String`s when creating the ``OrderBuilder``.
It's highly recommended to provide the content and the password as environment variables to avoid hardcoding sensitive information in your code.

You can look at [this guide](https://github.com/alexandercerutti/passkit-generator/wiki/Generating-Certificates) and [this video](https://www.youtube.com/watch?v=rJZdPoXHtzI) if you need more help. Those guides are for Wallet passes, but the process is similar for Wallet orders.
