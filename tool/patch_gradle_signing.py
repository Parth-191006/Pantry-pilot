#!/usr/bin/env python3
"""Point the generated Android release build at key.properties signing.

`flutter create` emits an app-level Gradle file whose release build signs with
the debug key. On CI that debug key is regenerated every run, so each APK gets
a DIFFERENT signature — and Android refuses to install a new build over an old
one ("App not installed", data lost). This script swaps in a signingConfig that
reads android/key.properties (written by the CI workflow from a stable, cached
keystore), so every release shares one signature and upgrades install in place.

Handles BOTH template flavours:
  • Groovy DSL  — android/app/build.gradle
  • Kotlin DSL  — android/app/build.gradle.kts   (current Flutter templates)

Idempotent: running it twice leaves the file unchanged.

Usage:  python tool/patch_gradle_signing.py   # run after `flutter create`
"""

import os
import re
import sys

GROOVY_FILE = os.path.join("android", "app", "build.gradle")
KOTLIN_FILE = os.path.join("android", "app", "build.gradle.kts")

GROOVY_SIGNING = """\
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

KOTLIN_SIGNING = """\
        // Release signing from android/key.properties (see
        // tool/patch_gradle_signing.py). Falls back to the debug key when the
        // properties file is absent so local `flutter run --release` works.
        signingConfigs {
            create("release") {
                val keystoreProperties = java.util.Properties()
                val keystorePropertiesFile = rootProject.file("key.properties")
                if (keystorePropertiesFile.exists()) {
                    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                }
            }
        }
"""


def patch(path: str, signing_block: str, is_kotlin: bool) -> int:
    with open(path, "r", encoding="utf-8") as fh:
        src = fh.read()

    if "signingConfig signingConfigs.release" in src or \
            "signingConfig = signingConfigs.release" in src or \
            'signingConfig = signingConfigs.getByName("release")' in src:
        print(f"{path}: already patched — nothing to do")
        return 0

    if "signingConfigs {" not in src:
        # Insert the signingConfigs block just before buildTypes.
        marker = "buildTypes {"
        if marker not in src:
            print(f"error: could not locate buildTypes {{ in {path}")
            return 1
        src = src.replace(marker, signing_block + "\n    " + marker, 1)

    # Template releases sign with the debug config; repoint at release.
    # Kotlin templates write signingConfigs.getByName("debug") — newer ones
    # even use signingConfigs.debug — so match both spellings.
    if is_kotlin:
        patterns = (
            (r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
             'signingConfig = signingConfigs.getByName("release")'),
            (r"signingConfig\s*=\s*signingConfigs\.debug",
             'signingConfig = signingConfigs.getByName("release")'),
        )
    else:
        patterns = (
            (r"signingConfig\s*=?\s*signingConfigs\.debug",
             "signingConfig signingConfigs.release"),
        )

    n = 0
    for pattern, replacement in patterns:
        src, k = re.subn(pattern, replacement, src)
        n += k
    if n == 0:
        print(f"error: could not locate the debug signingConfig assignment in {path}")
        return 1

    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(src)
    print(f"patched {path} for release signing")
    return 0


def main() -> int:
    if os.path.exists(KOTLIN_FILE):
        return patch(KOTLIN_FILE, KOTLIN_SIGNING, is_kotlin=True)
    if os.path.exists(GROOVY_FILE):
        return patch(GROOVY_FILE, GROOVY_SIGNING, is_kotlin=False)
    print("error: no android/app/build.gradle(.kts) found — run after `flutter create`")
    return 1


if __name__ == "__main__":
    sys.exit(main())
