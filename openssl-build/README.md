# OpenSSL build for cc7

This document describes how's OpenSSL integrated into Wultra's cc7 library.

## Common notes

- Our precompiled OpenSSL library doesn't contain "SSL" part of the suite. Only `libcrypto` is embedded in the precompiled packages.
- The final `libcrypto` contains only cipher suites that are required for our [PowerAuth mobile SDK](https://github.com/wultra/powerauth-mobile-sdk). For example, AES, ECDH, ECDSA, SHA and similar schemes are enabled for the build.

## Download precompiled OpenSSL

### Android

To fetch and prepare OpenSSL for Android, simply run:
```bash
./fetch.sh android
```

The script will prepare a precompiled libraries in `openssl-lib/android` folder, with the following content:

- `include` - contains OpenSSL headers. 
- `lib` - contains precompiled static libraries, for all supported architectures on Android.

The `fetch.sh` step is a part of build script `proj-android/cc7/build-library.sh`. Unfortunately, such script is only for testing purposes, so it's recommended to add this preparation step into your gradle build script.

### Apple

To fetch and prepare OpenSSL for all Apple platforms, simply run:

```bash
./fetch.sh apple
```

The script will prepare a precompiled framework in `openssl-lib/apple` folder, with the following content:

- `openssl.xcframework` - contains universal xcframework with precompiled static library, for all currently supported Apple platforms.

The `fetch.sh` step is a part of Xcode project, so it's not necessary to do any additional operations if the project is used as submodule dependency and referenced directly.

## Build OpenSSL

To prepare a precompiled libraries, use the following command:

```bash
./build.sh all [--publish version]
```

The script will compile all platforms and flavors at once, in the same folder hierarchy as for [download](#download-precompiled-openssl). If you use also `--publish` switch, then the script automatically update configuration for `fetch.sh` and publish binaries into github. 

