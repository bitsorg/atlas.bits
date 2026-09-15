package: Athena
description: ATLAS Athena framework, built from athena's own build.sh on top of the AthenaExternals bits package.
version: "25.0.70"      # newest tagged athena release predating the chai/CrestApi
                        # dependency (entered at 25.0.71, Sep 2026). 25.0.70 pins
                        # AthenaExternalsVersion 2.1.86; builds on our 2.1.90 externals.
tag: "release/%(version)s"   # -> release/25.0.70 (confirmed tag).
source: https://gitlab.cern.ch/atlas/athena
requires:
  - atlasexternals      # pulls lcg-view + lcg.bits transitively
  - HepPDT              # HepPDT: VP1 graphics find_package(HepPDT)
  - gperftools          # tcmalloc/profiler: find_package(gperftools)
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
# Ninja generator + bounded -j: build.sh otherwise defaults to serial Make (no -j).
# ninja is in build_requires; -x/-k pass through $@ to build_project.sh (-- to tool).
# Drop PIP_ROOT: the bits pip pkg exports it (<PKG>_ROOT convention), but pip reads
# PIP_ROOT as its --root option, redirecting any `pip install --user` into pip's own
# tree. Findpip uses PIP_LCGROOT, so this is safe. (Same fix as atlasexternals.sh.)
unset PIP_ROOT
# -Wno-dev silences ~1900 CMP0144 developer warnings (bits sets <PKG>_ROOT env
# vars; CMake 3.30 warns it ignores the upper-case form). Pure noise, not errors.
# Minimal DEMONSTRATION build: the dependency closure of the AthExHelloWorld
# example -- 12 framework-core packages that prove athena.sh builds real Athena
# code on an lcg.bits externals base, without the online/tdaq/detector/conditions
# stack (tdaq-common is a separate pre-built TDAQ release we deliberately avoid).
# The project build has NO auto-dependency-inclusion (unselected packages are
# skipped), so the set must be dependency-CLOSED: this whitelist + "- .*" is the
# closure computed from the package LINK_LIBRARIES graph. Widen it to build a
# larger slice.
_afilter="$PWD/athena-package-filters.txt"
cat > "$_afilter" <<'FILTER'
+ AtlasTest/TestTools
+ Control/CxxUtils
+ Control/AthContainersInterfaces
+ Control/AthContainers
+ Control/AthAllocators
+ Control/AthenaKernel
+ Control/SGTools
+ Control/SGCore
+ Control/StoreGate
+ Control/AthenaBaseComps
+ Control/CLIDComps
+ Database/PersistentDataModel
+ Control/AthenaExamples/AthExHelloWorld
- .*
FILTER
"$SOURCEDIR/Projects/Athena/build.sh" -acmi -b "$_bdir" -x "-G Ninja -Wno-dev -DATLAS_PACKAGE_FILTER_FILE=$_afilter" -k "-j${JOBS:-$(nproc)}"
# Route the produced InstallArea platform subtree into $INSTALLROOT so bits
# captures it and `bits enter Athena/latest` works like any other package.
# TODO(verify on build host): build dir + platform subdir + flatten-vs-preserve.
_ia=$(find "$_bdir/install" -maxdepth 7 -type d -name InstallArea 2>/dev/null | head -1)
[ -n "$_ia" ] || { echo "ERROR: Athena InstallArea not found after build.sh" >&2; exit 1; }
rsync -a "$_ia"/*/ "$INSTALLROOT"/
MakeModule
