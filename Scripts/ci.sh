#!/bin/bash -l
set -ex

if [ $ACTION == "swift-package" ]; then
  swift package generate-xcodeproj --output generated/
  if [ -n "$DESTINATION" ]; then
    xcodebuild \
      -project generated/CacheAdvance.xcodeproj \
      -scheme "CacheAdvance-Package" \
      -sdk $SDK \
      -destination "$DESTINATION" \
      -configuration Release \
      -PBXBuildsContinueAfterErrors=0 \
      $BUILD
  else
    xcodebuild \
      -project generated/CacheAdvance.xcodeproj \
      -scheme "CacheAdvance-Package" \
      -sdk $SDK \
      -configuration Release \
      -PBXBuildsContinueAfterErrors=0 \
      $BUILD
  fi
fi

if [ $ACTION == "pod-lint" ]; then
  swift package generate-xcodeproj --output generated/
  pushd generated/
  bundle exec pod lib lint --verbose --fail-fast --swift-version=$SWIFT_VERSION
  popd
fi

if [ $ACTION == "carthage" ]; then
  swift package generate-xcodeproj --output generated/
  carthage build --project-directory generated/ --verbose --no-skip-current
fi
