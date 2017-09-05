# iPoliTO
##### v2.4-beta
![Platforms](https://img.shields.io/badge/platform-iOS-lightgrey.svg) ![Swift Version](https://img.shields.io/badge/swift-3.0-orange.svg) ![License](https://img.shields.io/badge/license-GPL-blue.svg)

iPoliTO is an [unofficial](#disclaimer) iOS app for the students of Politecnico di Torino. It is currently available on the App Store [here](https://itunes.apple.com/app/id1069740093).

**\*\*please read the following section\*\***

## End of the project

Since my journey at Politecnico di Torino has come to an end, I decided to dedicate my efforts to new projects and —unfortunately — this means terminating the development of iPoliTO.

As of September 5th 2017, the app has been downloaded by a total of about 4070 students of Politecnico since its first release, exceeding by far all of my initial expectations. This success has pushed me to continue the development through these two years, but as I leave PoliTO it's time for me to move on.

That said, the app *will remain available* in the App Store for as long as it will work, although it won't receive any further updates, not for new features nor for bug fixes and maintenance, at least not until someone takes over the project. If that *someone* could be you, please get in touch with me! See also [Contributing](#contributing) below.

## Setup

In order to build the project, you must download and install the third-party libraries required by iPoliTO (see [below](#third-party-libraries)).

During debugging, you can choose to use a valid student account or a special "demo" account (which will load fake data contained in `DemoData.json`) by modifying a few lines in `Constants.swift`:
```swift
static let shouldForceDebugAccount = true
static let debugAccount = PTAccount(rawStudentID: "YOUR_USERNAME_HERE", password: "YOUR_PASSWORD_HERE")
// or use the demo account:
// static let debugAccount = demoAccount
``` 

## Requirements

* Xcode 8.0
* iOS 9.1 or above

## Contributing

~~Contributions of any kind are more than welcome! Make a pull request or open an issue.~~ Since I decided to stop working on this project, contributions are the only thing that will keep it alive, now more than ever. If you wish to take over the development, fork the repository and drop me a line via email. Also, if you appreciate my work, you can (still) buy me a coffee through [this link](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=rapisarda%2ecarlo%40gmail%2ecom&lc=IT&item_name=iPoliTO&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted).

## License

iPoliTO is released under the GPL license. See `LICENSE.txt` for more information.

## Third-party Libraries

The following dependencies are bundled with iPoliTO, but are under terms of a separate license:
* [Charts](https://github.com/danielgindi/Charts) by [danielgindi](https://github.com/danielgindi)
* [KeychainWrapper](http://www.raywenderlich.com/wp-content/uploads/2014/12/KeychainWrapper.zip) modified version by Tim Mitra, originally from [Apple](https://developer.apple.com/library/ios/samplecode/GenericKeychain/Listings/Classes_KeychainItemWrapper_m.html#//apple_ref/doc/uid/DTS40007797-Classes_KeychainItemWrapper_m-DontLinkElementID_10)
* [XMLDictionary](https://github.com/nicklockwood/XMLDictionary) by [Nick Lockwood](https://github.com/nicklockwood)

## Disclaimer

iPoliTO is an **independent** project. The app was first published on Jan. 6th 2016 to address the lack of an iOS app for the students of Politecnico di Torino; however, since April 7th 2016, the official app has been available and can be downloaded from the [App Store](https://itunes.apple.com/app/id1087287751).

As the developer of iPoliTO, I'm not affiliated with Politecnico di Torino nor with those who manage the content of the students' personal pages. While care has been taken to ensure accuracy, **no guarantee** is given that the material displayed by the app is free from error or omission.
