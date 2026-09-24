#!/usr/bin/env python3
"""Point the generated Android release build at key.properties signing.

`flutter create` emits a build.gradle whose release build signs with the debug
key. On CI that debug key is regenerated every run, so each APK gets a
DIFFERENT signature — and Android refuses to install a new build over an old
one (\"App not installed\", data lost). This script swaps in a signingConfig
that reads android/key.properties (written by the CI workflow from a stable,
cached keystore), so every release shares one signature and upgrades install
in place.

Idempotent: running it twice leaves the file unchanged.

Usage:  python tool/patch_gradle_signing.py   # run after `flutter create`
"""

import os
import re
import sys

GRADLE = os.path.join("android", "app", "build.gradle")

SIGNING_BLOCK = """
        // Release signing from android/key.properties (see
        // tool/patch_gradle_signing.py). Falls back to the debug key when the
        // properties file is absent so local `flutter run --release` works.
        signingConfigs {
            release {
                def keystoreProperties = new Properties()
                def keystorePropertiesFile = rootProject.file('key.properties')
                if (keystorePropertiesFile.exists()) {
                    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
                    keyAlias keystoreProperties['keyAlias']
                    keyPassword keystoreProperties['keyPassword']
                    storeFile file(keystoreProperties['storeFile'])
                    storePassword keystoreProperties['storePassword']
                }
            }
        }
"""


def main() -> int:
    if not os.path.exists(GRADLE):
        print(f"error: {GRADLE} not found — run after `flutter create`")
        return 1

    with open(GRADLE, "r", encoding="utf-8") as fh:
        src = fh.read()

    if "signingConfigs.release" in src or "signingConfig signingConfigs.release" in src:
        print("already patched — nothing to do")
        return 0

    if "signingConfigs {" not in src:
        # Insert the signingConfigs block just before buildTypes.
        marker = "buildTypes {"
        if marker not in src:
            print("error: could not locate buildTypes { in build.gradle")
            return 1
        src = src.replace(marker, SIGNING_BLOCK + "\n    " + marker, 1)

    # Template uses `signingConfig = signingConfigs.debug` (Groovy DSL with
    # assignment) or `signingConfig signingConfigs.debug` (Kotlin-style call).
    patched, n = re.subn(
        r"signingConfig\s*=?\s*signingConfigs\.debug",
        "signingConfig signingConfigs.release",
        src,
    )
    if n == 0:
        print("error: could not locate the debug signingConfig assignment")
        return 1

    with open(GRADLE, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(patched)
    print("patched android/app/build.gradle for release signing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
