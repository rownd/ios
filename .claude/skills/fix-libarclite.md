# Fix libarclite Missing Files

Fixes the `libarclite` error that occurs with Xcode 15+ when running `pod lib lint` or building projects with CocoaPods dependencies that have low deployment targets.

## Error

```
clang: error: SDK does not contain 'libarclite' at the path
'/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc/libarclite_iphonesimulator.a';
try increasing the minimum deployment target
```

## Fix

When this error occurs, do NOT try to run sudo commands yourself. Instead, output the following single command for the user to copy and run in their terminal:

```
sudo bash -c 'mkdir -p /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc && git clone https://github.com/kamyarelyasi/Libarclite-Files.git /tmp/libarclite-files && cp /tmp/libarclite-files/*.a /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc/ && rm -rf /tmp/libarclite-files && echo "Done! libarclite files installed."'
```

Tell the user to paste this in their terminal, then let you know when it's done so you can retry the failing command.

**Note:** This must be re-run after each Xcode update since the toolchain directory gets replaced.
