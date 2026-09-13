package: Athena
description: ATLAS Athena framework, built from athena's own build.sh on top of the AthenaExternals bits package.
version: "25.0.72"      # athena/Projects/Athena/version.txt
                        # TODO(scoped option 3): read from version.txt to avoid drift.
tag: "release/%(version)s"   # TODO: confirm the athena tag naming for this release.
source: https://gitlab.cern.ch/atlas/athena
requires:
  - atlasexternals      # pulls lcg-view + lcg.bits transitively
build_requires:
  - bits-recipe-tools
  - CMake
  - ninja
  - Python
  - "GCC-Toolchain:(?!osx)"
system:
  # off = network ALLOWED (default on blocks it). build.sh may fetch during
  # configure. Same reproducibility caveat as atlasexternals.sh.
  sandbox_network: "off"
---
#!/bin/bash -e
##############################
MODULE_OPTIONS="--bin --lib --cmake --python"
##############################
# Build Athena exactly as an ATLAS developer would: run athena's own
# Projects/Athena/build.sh, UNCHANGED, against the AthenaExternals bits built.
function Build() {
  export LCG_RELEASE_BASE="${LCG_RELEASE_BASE:?}"
  export LCG_PLATFORM="${LCG_PLATFORM:-x86_64-el9-gcc15-opt}"
  # Point the build at the AthenaExternals install. TODO: confirm the variable
  # AthenaExternals' find_package uses (ATLAS_EXT_DIR / CMAKE_PREFIX_PATH) and
  # set it from $ATLASEXTERNALS_ROOT (bits root var for the atlasexternals pkg).
  export ATLAS_EXT_DIR="${ATLASEXTERNALS_ROOT}"
  "$SOURCEDIR/Projects/Athena/build.sh" -acmi
}
