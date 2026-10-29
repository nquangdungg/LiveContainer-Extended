#!/bin/sh
set -e

# LiveContainer Extended — pack script
# Produces: LiveContainer.ipa and LiveContainer+SideStore.ipa
# Version stamped from LC_BUILD_VERSION into all Info.plist files.

VERSION="${LC_BUILD_VERSION:-}"
if [ -z "$VERSION" ]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Payload/LiveContainer.app/Info.plist 2>/dev/null || true)
fi
if [ -z "$VERSION" ]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" LiveContainer/Info.plist 2>/dev/null || true)
fi
if [ -z "$VERSION" ]; then VERSION="0.0.0"; fi
echo "==> Packing with version ${VERSION}"

stamp_plist() {
  plist="$1"
  if [ ! -f "$plist" ]; then return 0; fi
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${VERSION}" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :LCVersionInfo ${VERSION}" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :LCVersionInfo string ${VERSION}" "$plist" 2>/dev/null || true
}

wget -q https://github.com/LiveContainer/dylibify/releases/download/1.0/dylibify -O dylibify
chmod +x dylibify
command -v ldid >/dev/null 2>&1 || brew install ldid

rm -rf Payload tmp
mv "$archive_path.xcarchive/Products/Applications" Payload

find Payload -name "Info.plist" | while read -r pl; do
  stamp_plist "$pl"
done

mkdir -p tmp
if [ -d Payload/LiveContainer.app/Frameworks/SideStoreSupport.framework ]; then
  mv Payload/LiveContainer.app/Frameworks/SideStoreSupport.framework ./tmp/
fi

zip -r "$scheme.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"

if [ -d ./tmp/SideStoreSupport.framework ]; then
  mv ./tmp/SideStoreSupport.framework Payload/LiveContainer.app/Frameworks/
fi

/usr/libexec/PlistBuddy -c 'Add :ALTAppGroups array' ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :ALTAppGroups: string group.com.SideStore.SideStore' ./Payload/LiveContainer.app/Info.plist 2>/dev/null || true

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

if [ -f ./Payload/LiveContainer.app/Settings.bundle/Root.plist ]; then
  /usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Type string PSToggleSwitchSpecifier" ./Payload/LiveContainer.app/Settings.bundle/Root.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Title string Open SideStore" ./Payload/LiveContainer.app/Settings.bundle/Root.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Key string LCOpenSideStore" ./Payload/LiveContainer.app/Settings.bundle/Root.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:DefaultValue bool false" ./Payload/LiveContainer.app/Settings.bundle/Root.plist 2>/dev/null || true
fi

cd tmp
rm -rf Payload SideStore.ipa
wget -q --timeout=60 https://github.com/LiveContainer/SideStore/releases/download/nightly/SideStore.ipa -O SideStore.ipa
unzip -qo SideStore.ipa
if [ -f Payload/SideStore.app/Info.plist ]; then
  SSVER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Payload/SideStore.app/Info.plist 2>/dev/null || echo "nightly")
  echo "$SSVER" > ../sidestore_version.txt
else
  echo "nightly" > ../sidestore_version.txt
fi
cd ..

mv ./tmp/Payload/SideStore.app ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework
./dylibify ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore.dylib
rm -f ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore
mv ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore.dylib ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore
ldid -S"" ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore
cp ./.github/sidelc/LCAppInfo.plist ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/

cp ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Intents.intentdefinition ./Payload/LiveContainer.app/ 2>/dev/null || true
cp ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/ViewApp.intentdefinition ./Payload/LiveContainer.app/ 2>/dev/null || true
cp -r ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Metadata.appintents ./Payload/LiveContainer.app/Metadata.appintents 2>/dev/null || true
if [ -f ./Payload/LiveContainer.app/Metadata.appintents/extract.actionsdata ]; then
  sed -i '' 's/9SideStore20RefreshAllAppsIntentV/16SideStoreSupport20RefreshAllAppsIntentV/g' ./Payload/LiveContainer.app/Metadata.appintents/extract.actionsdata
  sed -i '' 's/9SideStore26RefreshAllAppsWidgetIntentV/16SideStoreSupport26RefreshAllAppsWidgetIntentV/g' ./Payload/LiveContainer.app/Metadata.appintents/extract.actionsdata
fi

if [ -d ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/PlugIns/AltWidgetExtension.appex ]; then
  mkdir -p ./Payload/LiveContainer.app/PlugIns
  mv ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/PlugIns/AltWidgetExtension.appex ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.kdt.livecontainer.LiveWidget"  ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable LiveWidgetExtension"  ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist
  if [ -f ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/AltWidgetExtension ]; then
    mv ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/AltWidgetExtension ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension
  fi
  stamp_plist ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist
  rm -rf .zsign_cache
  find Payload -type d -name "_CodeSignature" -exec rm -rf {} + 2>/dev/null || true
  ldid -S.github/sidelc/LiveWidgetExtension_adhoc.xml ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension
fi

find Payload -name "Info.plist" | while read -r pl; do
  stamp_plist "$pl"
done

zip -r "$scheme+SideStore.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"

echo "==> Pack done: ${scheme}.ipa + ${scheme}+SideStore.ipa (v${VERSION})"
ls -lh "${scheme}.ipa" "${scheme}+SideStore.ipa" 2>/dev/null || true
