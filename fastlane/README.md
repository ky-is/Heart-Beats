fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run unit and UI tests on the simulator

### ios device

```sh
[bundle exec] fastlane ios device
```

Build Release and install on the iPhone (DEVICE in .env)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Screenshots for the required App Store sizes (iPhone 6.3", iPad 13") and iPhone Duo into fastlane/screenshots

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload the iOS screenshots that changed to the editable version on App Store Connect (dry_run:true only reports)

### ios submit

```sh
[bundle exec] fastlane ios submit
```

Upload fastlane/metadata and the screenshots, attach the latest build of this version, and submit it for review (uploads:false skips the uploads)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to App Store Connect (does not submit for review)

----


## Mac

### mac beta

```sh
[bundle exec] fastlane mac beta
```

Build the Mac Catalyst app and upload it to TestFlight (adds macOS to the same App Store record)

### mac release

```sh
[bundle exec] fastlane mac release
```

Build the Mac Catalyst app and upload it to App Store Connect (does not submit for review)

### mac upload_screenshots

```sh
[bundle exec] fastlane mac upload_screenshots
```

Upload the Mac screenshots that changed to the editable version on App Store Connect (dry_run:true only reports)

### mac submit

```sh
[bundle exec] fastlane mac submit
```

The same as ios submit, for the Mac version (no release notes on its first version; MAC_FIRST_VERSION=no adds them)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
