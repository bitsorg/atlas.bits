package: atlasexternals
description: ATLAS AthenaExternals project, built from athena's own build_externals.sh on an lcg.bits LCG base.
version: "%(tag_basename)s"   # the Athena release; ATHENAEXTERNALS_VERSION has the externals'
tag: "%(athena_release)s"     # athena ref: externals.txt picks atlasexternals, build_externals.sh the rest
source: https://gitlab.cern.ch/atlas/athena
requires:
  - lcg-view            # LCG_RELEASE_BASE and the LCG_110_ATLAS_5 manifest
  - Python              # AthenaExternals links libpython: it must be bits' at run time
build_requires:
  - bits-recipe-tools
  - CMake
  - ninja
  - "GCC-Toolchain:(?!osx)"
env:
  # Here, not in the shared defaults, so the LCG externals keep stacks' hashes.
  LCG_VERSION_POSTFIX: "_ATLAS_5"
system:
  # Network on: build_externals.sh clones atlasexternals and downloads Gaudi,
  # ACTS, GeoModel and VecMem (prefetching them would let the sandbox stay closed).
  sandbox_network: "off"
---
#!/bin/bash -e
##############################
. $(bits-include ModuleRecipe)
##############################
MODULE_OPTIONS="--lib --cmake"
##############################
# athena's own Projects/Athena/build_externals.sh, unchanged; bits supplies the
# LCG base (lcg-view) and the toolchain.
export LCG_RELEASE_BASE="${LCG_RELEASE_BASE:?lcg-view must export LCG_RELEASE_BASE}"
export LCG_PLATFORM="${LCG_PLATFORM:-${EFFECTIVE_ARCHITECTURE:?}}"   # lcg-view's platform
# The el9 image has only C.UTF-8; ATLAS's scripts would otherwise force en_US.UTF-8.
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
# SOURCES is read-only, so checkout, build and install go here (-b).
_bdir="$PWD/build"
# pip reads PIP_ROOT (bits' <PKG>_ROOT) as --root and would install PyModules'
# wheels into the pip package; Findpip uses PIP_LCGROOT, so drop it.
unset PIP_ROOT
# The package filter of the atlasexternals this Athena pins (build_externals.sh
# clones it again to build), plus CrestApi, which has no ATLAS_BUILD_* flag.
_ext=$(sed -n 's/^AthenaExternalsVersion *= *//p' "$SOURCEDIR/Projects/Athena/externals.txt" | tr -d ' \r')
_ext=${_ext#origin/}
[ -n "$_ext" ] || { echo "ERROR: no AthenaExternalsVersion in Projects/Athena/externals.txt" >&2; exit 1; }
_lcg=$(sed -n 's/.*-DLCG_VERSION_NUMBER=\([0-9]*\).*/\1/p; s/.*-DLCG_VERSION_POSTFIX="\([^"]*\)".*/\1/p' \
         "$SOURCEDIR/Projects/Athena/build_externals.sh" | tr -d '\n')
[ -d "$LCG_RELEASE_BASE/LCG_$_lcg" ] || { echo "ERROR: this Athena wants LCG_$_lcg; lcg-view provides $(ls "$LCG_RELEASE_BASE")" >&2; exit 1; }
_src="$PWD/atlasexternals-filter"
rm -rf "$_src"
_url=https://gitlab.cern.ch/atlas/atlasexternals.git
git clone -q --depth 1 --branch "$_ext" "$_url" "$_src" 2>/dev/null ||
  { git clone -q "$_url" "$_src" && git -C "$_src" checkout -q "$_ext"; }   # a commit
_filter="$PWD/athena-package-filters.txt"
sed '/^- \.\*$/i + External/CrestApi' "$_src/Projects/AthenaExternals/package_filters.txt" > "$_filter"
grep -qx '+ External/CrestApi' "$_filter" || { echo "ERROR: no '- .*' line in atlasexternals $_ext package_filters.txt" >&2; exit 1; }
# CORAL/COOL built here (LCG 110 has none); athena uses only RelationalAccess with
# SQLite/Frontier, so OracleAccess and CORAL_SERVER (Sun RPC) go. -x stays space-free.
# -c: no RPMs. -j1: the superbuild's installs race; each external builds in parallel.
"$SOURCEDIR/Projects/Athena/build_externals.sh" -c -b "$_bdir" -x "-G Ninja -DATLAS_BUILD_CORAL=ON -DATLAS_BUILD_COOL=ON -DATLAS_CORAL_PATCH=PATCH_COMMAND;sed;-i;-e;s/OracleAccess//g;-e;\#CORAL_SERVER/#d;CMakeLists.txt -DATLAS_PACKAGE_FILTER_FILE=$_filter" -k "-j1"
# The package is the InstallArea's platform subtree (TODO: confirm athena wants it flat).
_ia=$(find "$_bdir/install" -maxdepth 7 -type d -name InstallArea 2>/dev/null | head -1)
[ -n "$_ia" ] || { echo "ERROR: AthenaExternals InstallArea not found after build_externals.sh" >&2; exit 1; }
rsync -a "$_ia"/*/ "$INSTALLROOT"/
MakeModule
# TODO: confirm athena reads ATLAS_EXT_DIR (not only CMAKE_PREFIX_PATH).
cat >> "$MODULEFILE" <<EOF
setenv ATLAS_EXT_DIR  \$PKG_ROOT
setenv ATHENAEXTERNALS_VERSION $_ext
EOF
