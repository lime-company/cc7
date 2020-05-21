# OpenSSL build for cc7

This document describes how's OpenSSL integrated into Wultra's cc7 library.

## Fetch precompiled OpenSSL

### Android

To fetch and prepare OpenSSL for Android, simply run:
```bash
./fetch.sh android
```

The script will prepare a precompiled libraries in `openss/android` folder, with the following content:

- `include` - contains OpenSSL headers. 
- `lib` - contains precompiled static libraries, for all supported architectures on Android.


### Apple

To fetch and prepare OpenSSL for all Apple platforms, simply run:

```bash
./fetch.sh apple
```

The script will prepare a precompiled framework in `openss/apple` folder, with the following content:

- `OpenSSL.xcframework` - contains universal xcframework with precompiled static library, for all currently supported Apple platforms.


## Build OpenSSL

This 


## Upgrade OpenSSL


