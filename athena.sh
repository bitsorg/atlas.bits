package: Athena
description: ATLAS Athena framework, built from  own build.sh on top of the AthenaExternals bits package.
version: "%(tag_basename)s"   # release/25.0.75 -> 25.0.75
tag: "%(athena_release)s"     # defaults-atlas.sh; the same ref as atlasexternals
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

# AthExHelloWorld and what `athena.py HelloWorldConfig.py` loads (python imports,
# CompFactory components, the libraries they link): the build skips the others.
# PersistencySvc: PoolSvc links it in 25.0.71 (gone by 25.0.75).
_afilter="$PWD/athena-package-filters.txt"
cat > "$_afilter" <<'FILTER'
+ AtlasTest/TestTools
+ Control/AthAllocators
+ Control/AthContainers
+ Control/AthContainersInterfaces
+ Control/AthContainersRoot
+ Control/AthenaBaseComps
+ Control/AthenaCommon
+ Control/AthenaConfiguration
+ Control/AthenaExamples/AthExHelloWorld
+ Control/AthenaInterprocess
+ Control/AthenaKernel
+ Control/AthenaMP
+ Control/AthenaMPTools
+ Control/AthenaServices
+ Control/AthLinks
+ Control/AthLinksSA
+ Control/AthToolSupport/AsgMessaging
+ Control/AthToolSupport/AsgTools
+ Control/CLIDComps
+ Control/CxxUtils
+ Control/DataModelRoot
+ Control/GaudiSequencer
+ Control/PerformanceMonitoring/PerfMonComps
+ Control/PerformanceMonitoring/PerfMonGPerfTools
+ Control/PerformanceMonitoring/PerfMonKernel
+ Control/RootUtils
+ Control/SGComps
+ Control/SGCore
+ Control/SGTools
+ Control/StoreGate
+ Control/Valkyrie
+ Control/xAODRootAccessInterfaces
+ Database/APR/PersistencySvc
+ Database/APR/StorageSvc
+ Database/AthenaPOOL/AthenaPoolUtilities
+ Database/AthenaPOOL/PoolSvc
+ Database/AthenaRoot/RootAuxDynIO
+ Database/CoraCool
+ Database/CoralUtilities
+ Database/DBLock
+ Database/IOVDbDataModel
+ Database/IOVDbMetaDataTools
+ Database/IOVDbSvc
+ Database/PersistentDataModel
+ Database/SQLiteDBSvc
+ DetectorDescription/GeoModel/GeoModelInterfaces
+ Event/EventInfo
+ Event/EventInfoMgt
+ Event/EventInfoUtils
+ Event/xAOD/xAODCore
+ Event/xAOD/xAODEventInfo
+ Generators/GeneratorConfig
+ Generators/McEventSelector
+ Tools/Campaigns
+ Tools/PathResolver
+ Tools/PyUtils
+ Trigger/TrigConfiguration/TrigConfBase
+ Trigger/TrigConfiguration/TrigConfData
+ Trigger/TrigConfiguration/TrigConfigSvc
+ Trigger/TrigConfiguration/TrigConfInterfaces
+ Trigger/TrigConfiguration/TrigConfIO
- .*
FILTER

# Athena 25.0.74 and later format a std::pair (C++23 <format>, gcc15 libstdc++);
# stop here, not deep in the build, when this compiler cannot.
_cxx="${CXX:-c++}"
if grep -qsF 'make_pair(procName,procTiName), id' "$SOURCEDIR/Control/CLIDComps/src/ClassIDSvc.cxx" &&
   ! printf '#include <format>\n#include <string>\n#include <utility>\nauto s = std::format("{}", std::pair<std::string, std::string>{});\n' |
     "$_cxx" -std=c++23 -fsyntax-only -x c++ - 2>/dev/null; then
  echo "ERROR: Athena $PKGVERSION needs gcc15 (std::format of std::pair); $_cxx is $("$_cxx" -dumpversion). Use --defaults atlas::gcc15::opt" >&2
  exit 1
fi

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
