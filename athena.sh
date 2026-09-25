package: Athena
description: ATLAS Athena framework, built from  own build.sh on top of the AthenaExternals bits package.
version: "25.0.70"    # AthenaExternalsVersion 2.1.86; builds on our 2.1.90 externals.
tag: "release/%(version)s" 
source: https://gitlab.cern.ch/atlas/athena
requires:
  - atlasexternals   
  - HepPDT           
  - gperftools       
build_requires:
  - bits-recipe-tools
  - CMake
  - ninja
  - Python
  - "GCC-Toolchain:(?!osx)"
system:
  sandbox_network: "off"   # network allowed: build.sh may fetch during configure
---
#!/bin/bash -e
##############################
. $(bits-include ModuleRecipe)
##############################
MODULE_OPTIONS="--bin --lib --cmake --python"
##############################

export LCG_RELEASE_BASE="${LCG_RELEASE_BASE:?}"
export LCG_PLATFORM="${LCG_PLATFORM:-${EFFECTIVE_ARCHITECTURE:?}}"   # from lcg-view
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export ATLAS_EXT_DIR="${ATLASEXTERNALS_ROOT}"

unset PIP_ROOT

# AthExHelloWorld example: its dependency-closed package set (the project build
# skips unselected packages, so the whitelist must include every dependency).
_afilter="$PWD/athena-package-filters.txt"
cat > "$_afilter" <<'FILTER'
+ AtlasTest/TestTools
+ Control/CxxUtils
+ Control/AthContainersInterfaces
+ Control/AthContainers
+ Control/AthAllocators
+ Control/AthLinks
+ Control/AthenaKernel
+ Control/DataModelRoot
+ Control/RootUtils
+ Control/xAODRootAccessInterfaces
+ Control/SGTools
+ Control/SGCore
+ Control/StoreGate
+ Control/AthenaBaseComps
+ Control/CLIDComps
+ Database/PersistentDataModel
+ Event/xAOD/xAODCore
+ Event/xAOD/xAODEventInfo
+ Control/AthenaExamples/AthExHelloWorld
- .*
FILTER

_bdir="$PWD/build"

"$SOURCEDIR/Projects/Athena/build.sh" -acmi -b "$_bdir" \
				      -x "-G Ninja -Wno-dev \
                                      -DCMAKE_CXX_STANDARD=23 \
                                      -DATLAS_PACKAGE_FILTER_FILE=$_afilter" \
				      -k "-j${JOBS:-$(nproc)}"

# Route the produced InstallArea platform subtree into $INSTALLROOT

_ia=$(find "$_bdir/install" -maxdepth 7 -type d -name InstallArea 2>/dev/null | head -1)

[ -n "$_ia" ] || { echo "ERROR: Athena InstallArea not found after build.sh" >&2; exit 1; }

rsync -a "$_ia"/*/ "$INSTALLROOT"/

MakeModule
