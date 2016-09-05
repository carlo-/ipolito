# iPoliTO
##### v2.0-beta
![Platforms](https://img.shields.io/badge/platform-iOS-lightgrey.svg) ![Swift Version](https://img.shields.io/badge/swift-3.0-orange.svg) ![License](https://img.shields.io/badge/license-GPL-blue.svg)

iPoliTO is a simple iOS app for the students of Politecnico di Torino. It is currently available on the App Store [here](https://itunes.apple.com/app/id1069740093).

## Setup

In order to build the project, you must download and install the third-party libraries required by iPoliTO (see *Third-party Libraries*).

Also, it is necessary to add a new file with the following lines of code:
```swift
public let kMyUsername = “YOUR_USERNAME_HERE”
public let kMyPassword = “YOUR_PASSWORD_HERE”
public let kMyAccount = PTAccount(matricola: kMyUsername, password: kMyPassword)
```
filling it with your credentials (assuming you’re currently enrolled at PoliTO, otherwise use the demo account explained below).

During debugging, you can choose to use your student account or a demo account (which will load fake data contained in `TestData.json`) by modifying a few lines in `Constants.swift`:
```swift
public let kDebugShouldForceCredentials = true
public let kDebugForcingCredentials: PTAccount = kDemoAccount // or kMyAccount
``` 

## Requirements

* Xcode 8.0
* iOS 9.1 or above

## Contributing

Contributions of any kind are more than welcome! Make a pull request or open an issue. Also, if you appreciate my work, you can buy me a beer through this [link](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=rapisarda%2ecarlo%40gmail%2ecom&lc=IT&item_name=iPoliTO&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted).

## License

iPoliTO is released under the GPL license. See `LICENSE.txt` for more information.

## Third-party Libraries

The following dependencies are bundled with iPoliTO, but are under terms of a separate license:
* [Scrollable-GraphView](https://github.com/philackm/Scrollable-GraphView) by [philackm](https://github.com/philackm)