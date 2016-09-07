# iPoliTO
##### v2.0-beta
![Platforms](https://img.shields.io/badge/platform-iOS-lightgrey.svg) ![Swift Version](https://img.shields.io/badge/swift-3.0-orange.svg) ![License](https://img.shields.io/badge/license-GPL-blue.svg)

iPoliTO is a simple iOS app for the students of Politecnico di Torino. It is currently available on the App Store [here](https://itunes.apple.com/app/id1069740093).

## Setup

In order to build the project, you must download and install the third-party libraries required by iPoliTO (see [below](#third-party-libraries)).

During debugging, you can choose to use your own student account (assuming you’re currently enrolled at PoliTO) or a demo account (which will load fake data contained in `TestData.json`) by modifying a few lines in `Constants.swift`:
```swift
public let kDebugShouldForceCredentials = true
public let kDebugForcingCredentials = PTAccount(matricola: "YOUR_USERNAME_HERE", password: "YOUR_PASSWORD_HERE")
// or use the demo account:
// public let kDebugForcingCredentials = kDemoAccount
``` 

## Requirements

* Xcode 8.0
* iOS 9.1 or above

## Contributing

Contributions of any kind are more than welcome! Make a pull request or open an issue. Also, if you appreciate my work, you can buy me a coffee through [this link](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=rapisarda%2ecarlo%40gmail%2ecom&lc=IT&item_name=iPoliTO&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted).

## License

iPoliTO is released under the GPL license. See `LICENSE.txt` for more information.

## Third-party Libraries

The following dependencies are bundled with iPoliTO, but are under terms of a separate license:
* [Scrollable-GraphView](https://github.com/philackm/Scrollable-GraphView) by [philackm](https://github.com/philackm)
* [KeychainWrapper](http://www.raywenderlich.com/wp-content/uploads/2014/12/KeychainWrapper.zip) modified version by Tim Mitra, originally from [Apple](https://developer.apple.com/library/ios/samplecode/GenericKeychain/Listings/Classes_KeychainItemWrapper_m.html#//apple_ref/doc/uid/DTS40007797-Classes_KeychainItemWrapper_m-DontLinkElementID_10)
