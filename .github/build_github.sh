#!/bin/bash
set -euo pipefail

echo "==> LiveContainer IPA packager"
echo "    scheme=${scheme:-LiveContainer}"
echo "    archive_path=${archive_path:-archive}"

SCHEME="${scheme:-LiveContainer}"
ARCHIVE_PATH="${archive_path:-archive}"
APP_PATH="${ARCHIVE_PATH}.xcarchive/Products/Applications"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Archive products not found at $APP_PATH"
  find "${ARCHIVE_PATH}.xcarchive" -maxdepth 4 -type d 2>/dev/null || true
  exit 1
fi

echo "==> Installing tools"
command -v wget >/dev/null 2>&1 || brew install wget
command -v ldid >/dev/null 2>&1 || brew install ldid

if [ ! -x ./dylibify ]; then
  wget -q -O dylibify https://github.com/LiveContainer/dylibify/releases/download/1.0/dylibify
  chmod +x dylibify
fi

rm -rf Payload tmp
mkdir -p Payload tmp

echo "==> Copying app from archive"
cp -R "$APP_PATH/." Payload/

if [ ! -d "Payload/LiveContainer.app" ]; then
  echo "ERROR: LiveContainer.app not found in Payload/"
  ls -la Payload/ || true
  exit 1
fi

# ---------- Stamp marketing version from CI (single source of truth) ----------
# Prefer LC_BUILD_VERSION (workflow), then VERSION file, then existing plist.
stamp_app_version() {
  local ver="${LC_BUILD_VERSION:-}"
  if [ -z "$ver" ] && [ -f VERSION ]; then
    ver=$(tr -d '[:space:]' < VERSION)
  fi
  if [ -z "$ver" ]; then
    ver=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Payload/LiveContainer.app/Info.plist 2>/dev/null || true)
  fi
  if [ -z "$ver" ]; then
    echo "WARNING: No version to stamp"
    return 0
  fi
  echo "==> Stamping app version: $ver"
  local plist="Payload/LiveContainer.app/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $ver" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $ver" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $ver" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $ver" "$plist"
  # Used by getVersionInfo — always matches release tag
  /usr/libexec/PlistBuddy -c "Set :LCVersionInfo $ver" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :LCVersionInfo string $ver" "$plist"
  # Stamp embedded appex Info.plists so Settings / about stay consistent
  find Payload/LiveContainer.app -name Info.plist | while read -r ip; do
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $ver" "$ip" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $ver" "$ip" 2>/dev/null || true
  done
  echo "$ver" > build_version_stamped.txt
}

stamp_app_version

# ---------- Standalone IPA (always) ----------
echo "==> Building standalone ${SCHEME}.ipa"

STANDALONE_HAD_SS=0
if [ -d "Payload/LiveContainer.app/Frameworks/SideStoreSupport.framework" ]; then
  STANDALONE_HAD_SS=1
  mv "Payload/LiveContainer.app/Frameworks/SideStoreSupport.framework" ./tmp/
fi

rm -f "${SCHEME}.ipa"
zip -r "${SCHEME}.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
echo "    Created $(pwd)/${SCHEME}.ipa ($(du -h "${SCHEME}.ipa" | cut -f1))"

if [ "$STANDALONE_HAD_SS" = "1" ]; then
  mv ./tmp/SideStoreSupport.framework "Payload/LiveContainer.app/Frameworks/"
fi

# ---------- Optional: +SideStore ----------
build_sidestore() {
  echo "==> Building ${SCHEME}+SideStore.ipa"

  /usr/libexec/PlistBuddy -c 'Add :ALTAppGroups array' ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c 'Add :ALTAppGroups:0 string group.com.SideStore.SideStore' ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true

  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1 dict" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLName string com.kdt.livecontainer.sidestoreurlscheme" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes array" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes:0 string sidestore" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2 dict" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLName string com.kdt.livecontainer.sidestorebackupurlscheme" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLSchemes array" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLSchemes:0 string sidestore-com.kdt.livecontainer" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true

  /usr/libexec/PlistBuddy -c "Add :INIntentsSupported array" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :INIntentsSupported:0 string RefreshAllIntent" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :INIntentsSupported:1 string ViewAppIntent" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes array" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes:0 string RefreshAllIntent" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes:1 string ViewAppIntent" ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true

  echo "    Downloading SideStore IPA..."
  rm -rf tmp/Payload tmp/SideStore.ipa
  mkdir -p tmp
  # Timeouts so CI cannot hang forever on a bad GitHub download
  wget --timeout=30 --tries=2 -q -O tmp/SideStore.ipa \
    "https://github.com/LiveContainer/SideStore/releases/download/nightly/SideStore.ipa" \
    || wget --timeout=30 --tries=2 -q -O tmp/SideStore.ipa \
    "https://github.com/SideStore/SideStore/releases/latest/download/SideStore.ipa" \
    || true

  if [ ! -f tmp/SideStore.ipa ]; then
    echo "WARNING: Could not download SideStore.ipa — skipping +SideStore"
    return 1
  fi

  (cd tmp && unzip -qo SideStore.ipa)

  if [ ! -d tmp/Payload/SideStore.app ]; then
    echo "WARNING: SideStore.app missing — skipping +SideStore"
    return 1
  fi

  mkdir -p Payload/LiveContainer.app/Frameworks
  rm -rf Payload/LiveContainer.app/Frameworks/SideStoreApp.framework
  mv tmp/Payload/SideStore.app Payload/LiveContainer.app/Frameworks/SideStoreApp.framework

  # Record embedded SideStore version for release notes
  SS_PLIST="Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Info.plist"
  SS_VER=""
  SS_BUILD=""
  if [ -f "$SS_PLIST" ]; then
    SS_VER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SS_PLIST" 2>/dev/null || true)
    SS_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SS_PLIST" 2>/dev/null || true)
  fi
  if [ -z "$SS_VER" ]; then SS_VER="unknown"; fi
  if [ -n "$SS_BUILD" ] && [ "$SS_BUILD" != "$SS_VER" ]; then
    echo "${SS_VER} (${SS_BUILD})" > sidestore_version.txt
  else
    echo "${SS_VER}" > sidestore_version.txt
  fi
  echo "    Embedded SideStore version: $(cat sidestore_version.txt)"
  # Also expose to GitHub Actions if available
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "sidestore_version=$(cat sidestore_version.txt)" >> "$GITHUB_OUTPUT"
  fi


  SS_BIN="Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore"
  if [ -f "$SS_BIN" ]; then
    ./dylibify "$SS_BIN" "${SS_BIN}.dylib"
    rm -f "$SS_BIN"
    mv "${SS_BIN}.dylib" "$SS_BIN"
    ldid -S"" "$SS_BIN" || true
  fi

  if [ -f .github/sidelc/LCAppInfo.plist ]; then
    cp .github/sidelc/LCAppInfo.plist Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/
  fi

  if [ -f Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Intents.intentdefinition ]; then
    cp Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Intents.intentdefinition Payload/LiveContainer.app/ || true
  fi
  if [ -f Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/ViewApp.intentdefinition ]; then
    cp Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/ViewApp.intentdefinition Payload/LiveContainer.app/ || true
  fi
  if [ -d Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Metadata.appintents ]; then
    cp -R Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Metadata.appintents Payload/LiveContainer.app/Metadata.appintents || true
    if [ -f Payload/LiveContainer.app/Metadata.appintents/extract.actionsdata ]; then
      sed -i '' 's/9SideStore20RefreshAllAppsIntentV/16SideStoreSupport20RefreshAllAppsIntentV/g' \
        Payload/LiveContainer.app/Metadata.appintents/extract.actionsdata || true
      sed -i '' 's/9SideStore26RefreshAllAppsWidgetIntentV/16SideStoreSupport26RefreshAllAppsWidgetIntentV/g' \
        Payload/LiveContainer.app/Metadata.appintents/extract.actionsdata || true
    fi
  fi

  if [ -d Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/PlugIns/AltWidgetExtension.appex ]; then
    mkdir -p Payload/LiveContainer.app/PlugIns
    rm -rf Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex
    mv Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/PlugIns/AltWidgetExtension.appex \
       Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.kdt.livecontainer.LiveWidget" \
      Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable LiveWidgetExtension" \
      Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist 2>/dev/null || true
    if [ -f Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/AltWidgetExtension ]; then
      mv Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/AltWidgetExtension \
         Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension
    fi
    if [ -f .github/sidelc/LiveWidgetExtension_adhoc.xml ]; then
      ldid -S.github/sidelc/LiveWidgetExtension_adhoc.xml \
        Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension || true
    fi
  fi

  find Payload -type d -name "_CodeSignature" -exec rm -rf {} + 2>/dev/null || true

  rm -f "${SCHEME}+SideStore.ipa"
  zip -r "${SCHEME}+SideStore.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
  echo "    Created $(pwd)/${SCHEME}+SideStore.ipa ($(du -h "${SCHEME}+SideStore.ipa" | cut -f1))"
}

set +e
build_sidestore
SS_RC=$?
set -e

echo "==> Summary"
ls -lh "${SCHEME}.ipa" 2>/dev/null || echo "MISSING ${SCHEME}.ipa"
ls -lh "${SCHEME}+SideStore.ipa" 2>/dev/null || echo "MISSING ${SCHEME}+SideStore.ipa (optional)"

if [ ! -f "${SCHEME}.ipa" ]; then
  echo "ERROR: standalone IPA was not produced"
  exit 1
fi

if [ $SS_RC -ne 0 ]; then
  echo "WARNING: +SideStore packaging failed (rc=$SS_RC) — standalone IPA is still available"
fi

echo "==> Done"


