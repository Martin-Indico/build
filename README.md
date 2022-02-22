# Build
This repository aims to streamline how every docker based Indico project is buildt. The repository comprises a script
(build.sh)[./build.sh] which kan be added to all Indico projects, as well as clear guides and best practices for structuring,
versioning, and working on Indico projects using Git.

## Versioning
As a general rule every project should try to follow the standard versioning approach for the language chosen for the project.
How a project is versioned is usually determined by the package-manger or framework used by the project. As we try to 
mitigate the need for custom logic in each project, we try to follow the best practises for versioning the individual
projects determined by the package-manager or framework. As of `22.02.22` Indico has 3 projects that targets a container-based
environment:
 - __FT4__: _Ferdig til 4_, is the main backend API written in PHP and JavaScript.
 - __WM4__: _Worker Manager for FT4_, is the file-processing and queue handler for FT4 written in PHP and Python.
 - __Vault__: _Evidence Vault_, is the frontend for FT4 written in TypeScript with Svelte.
 
For __Vault__ this is pretty straight forward as it uses [NPM](https://www.npmjs.com/) as its package-manager which also
handles versioning through its `package.json`. The `package.json` also contains relevant metadata such as a last updated
date, name, and description. These are all useful fields when looking at the project from the outside in, when the final
product is a _docker-image_ it becomes especially useful as we cannot see the actual content of the image before running it.
Metadata on the other hand will be exposed if configured correctly and is in many cases need for the `devops` to be able
to differentiate between the images without having to run them. 

As of `22.02.22` any project that does not utilize a framework or package-manager that handles versioning, defaults to
the _NPM_ format and uses a simplified `package.json`. This is the case for both __WM4__ and __FT4__.

> When updating the version for a project you should start by first committing and pushing all code changes, then
> perform the version update, commit and push the affected files, and finally tag this commit with new version.

For all projects the version format is written as `Major.Minor.Patch-Tag.Number`:
 - _Major_: The major version of the project, should only be updated on completion of breaking changes.
 - _Minor_: Updated with each new feature, this could introduce breaking changes.
 - _Path_: Updated with each fix, minor changes to documentation etc., and should never introduce breaking changes.
 - _Tag.Number_: These two should always be combined when used, and is to be appended when testing code introduced under  
                 one of the above version changes. It can also be used to identify a version containing code that differs
                 from the main code base. As an example here vi have the latest __Database__ image used by _PIT_, this has  
                 some customer specific _SQL_ witch in turn is reflected in the version _Tag_ (`1.1.0-pit`). Notice that
                 we never write the _Tag_._Number_ as `00`, we just leave it blank. If the code specific to _PIT_ in the 
                 __Database__ image is updated the next version would be `1.1.0-pit.1`, if the main codebase is _patched_
                 the next version would be `1.1.1-pit`.

In many cases where it is necessary to perform continuous tests of build pipelines or deployment logic we might
have to update the version number rapidly in order to trigger a new build. As this does not relate to changes in
the main code-base, we just update the _Tag.Number_ for  the project, this tells the _DevOps_ that the code itself 
has not changed but some part of the pipeline or other build-logic has. Some keywords used in tag such as `alpha` or 
`beta` tells us that the current version is at a testing stage. The current version of the __FT4__ image for example 
is now at `0.9.8-beta.50`, this is interpreted as the main code-base being at version `0.9.7` while the version `0.9.8`
is at `beta` testing stage on its 50th build. Tag names should always be lower-case.

A good rule of thumb is here to write out some documentation per repo defining possible keywords to be used as a _Tag_
and what these tags mean. This makes it easy for any _DevOps_ to determine what to name test images and how to interpret
existing image versions. 

Some commonly used tag names are:
 - _alpha_: An early test build with high probability of failure.
 - _beta_ : A step-up from _alpha_ when the build has matured and has a lower probability of failure.
 - _pipe_ : Marks the testing of a pipeline and does not affect the main code base.

### Update Version
For each container-based project there should be a `update_version.sh` script in the root. This script can be called directly
to update the version of the individual projects without triggering anything else, and is also called from `build.sh` when
updating the version. This script may differ in functionality based on how versioning is done for the project.

As an example is the included `update_version.sh` for __FT4__ which follows the rules for versioning mentioned above,
as well as performing some custom logic for updating a version file within the project. This example outlines how a 
version and when update should be performed:

```shell
#!/bin/bash
# The first line in any script should be a `shebang` which tells the interpreter what runner to use.
# All Indico images as of 22.02.22 includes Bash and should match the line above for all scripts.

if [ -f ".build.env" ]; then #Checks for the local .build.env file
  source .build.env #Loads the local .build.env file values if it exists.
fi

for arg in "$@"; do #Itterates arguments passed to the script
  case "$arg" in
  *) # Interprets any argument as next_version, passing multiple arguments to the
    next_version=$arg
    ;;
  esac
done

if [ -z "$next_version" ]; then
  echo " - error: You need specify a version to update it..."
  exit 1
fi

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
```

## build.sh
build.sh is a simple bash-script that is to be added into the root of any container-based Indico-project. 