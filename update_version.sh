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
# Actual version update logic, return 0 on success and 1 on error
if sed -i -e "s/<code.*id=\"app-version\">.*<\/code>/<code id=\"app-version\">$BUILD_IMAGE_VERSION<\/code>/g" ./src/lib/Sidebar.svelte; then
  echo " - version updated in ./src/lib/Sidebar.svelte"
else
  echo " - error: failed to update version in ./src/lib/Sidebar.svelte"
  exit 1
fi
# Reports success and close
exit 0