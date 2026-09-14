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
. $(bits-include ModuleRecipe)
##############################
MODULE_OPTIONS="--bin --lib --cmake --python"
##############################
# Build Athena exactly as an ATLAS developer would: run athena's own
# Projects/Athena/build.sh, UNCHANGED, against the AthenaExternals bits built.
# Plain top-level statements (bits sources the recipe; no Run() indirection),
# ending with MakeModule so Athena is a normal bits package (bits enter Athena/latest).
export LCG_RELEASE_BASE="${LCG_RELEASE_BASE:?}"
export LCG_PLATFORM="${LCG_PLATFORM:-x86_64-el9-gcc14-opt}"
# el9 build image ships only C.UTF-8; ATLAS build_project_externals.sh otherwise
# forces en_US.UTF-8 (unset/"C"), and every /bin/sh warns. Pin C.UTF-8 as CI does.
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
# athena's find_package(AthenaExternals). TODO(verify): exact var name.
export ATLAS_EXT_DIR="${ATLASEXTERNALS_ROOT}"
# Build in a writable dir — bits mounts SOURCES read-only, so ATLAS's
# default ../build (under SOURCES) fails. -b redirects checkout/build/
# install here; the InstallArea search below follows it.
_bdir="$PWD/build"
"$SOURCEDIR/Projects/Athena/build.sh" -acmi -b "$_bdir"
# Route the produced InstallArea platform subtree into $INSTALLROOT so bits
# captures it and `bits enter Athena/latest` works like any other package.
# TODO(verify on build host): build dir + platform subdir + flatten-vs-preserve.
_ia=$(find "$_bdir/install" -maxdepth 7 -type d -name InstallArea 2>/dev/null | head -1)
[ -n "$_ia" ] || { echo "ERROR: Athena InstallArea not found after build.sh" >&2; exit 1; }
rsync -a "$_ia"/*/ "$INSTALLROOT"/
MakeModule
