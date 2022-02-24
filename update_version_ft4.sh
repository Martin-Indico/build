#!/usr/bin/env bash

# Loads the .build.env file
if [ -f ".build.env" ]; then
  source .build.env
fi
# Iterates arguments and sets the last one to $next_version
for arg in "$@"; do
  case "$arg" in
  *)
    next_version=$arg
    ;;
  esac
done
# Safety for checking that the version has acualy been sat.
if [ -z "$next_version" ]; then
  echo " - error: You need specify a version to update it..."
  exit 1
fi
# Actual version update logic
echo " - Stripping version flags"
next_version=(${next_version//-/" "})
next_version="${next_version[0]}"
flags=${next_version[1]}
if [ -n "$flags" ];then
  echo " - Removed: \"$flags\""
fi

# Only matches the current version system, will stripp everythng after a "-"
if ! [[ "$next_version" =~ ^[0-9]\.[0-9]\.[0-9]$ ]]; then
  echo " - error: Invalid version format \"$next_version, should be \"0.1.0\""
fi

if [ ! -f "$FT4_INFO_PATH" ]; then
  echo " - error: no FT4 info can be found at $FT4_INFO_PATH ..."
  exit 1
fi

vs_seg=(${next_version//./" "})

echo " - Updating $FT4_INFO_PATH to version $next_version"

function update_vs() {
  jq \
    --arg major "${vs_seg[0]}" \
    --arg minor "${vs_seg[1]}" \
    --arg patch "${vs_seg[2]}" \
    --arg date "$(date +%F)" \
    '.version.major = ($major | tonumber) | .version.minor = ($minor | tonumber) | .version.patch = ($patch | tonumber) | .version.date = $date' \
    "$FT4_INFO_PATH"
}

vs=$(update_vs)
echo "$vs" > "$FT4_INFO_PATH"

echo " - Version updated to $next_version"
exit 0
