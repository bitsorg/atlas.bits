package: atlasexternals
description: ATLAS AthenaExternals project, built from athena's own build_externals.sh on an lcg.bits LCG base.
version: "2.1.90"       # AthenaExternalsVersion, athena/Projects/Athena/externals.txt
                        # TODO(scoped option 3): read from externals.txt to avoid drift.
tag: "main"             # athena branch carrying build_externals.sh + externals.txt;
                        # main's externals.txt currently sets AthenaExternalsVersion = 2.1.90,
                        # which build_externals.sh uses to clone atlasexternals (tracks main; re-sync when it moves).
source: https://gitlab.cern.ch/atlas/athena   # carries Projects/Athena/build_externals.sh
requires:
  - lcg-view            # provides $LCG_RELEASE_BASE + the LCG_110_ATLAS_5 manifest
  - Python              # runtime dep: AthenaExternals links libpython (Gaudi, GaudiPython,
                        # confdb2 merge). Must be in the runtime closure so its lib is on
                        # LD_LIBRARY_PATH and the interpreter binds bits libpython, not host.
build_requires:
  - bits-recipe-tools
  - CMake
  - ninja
  - "GCC-Toolchain:(?!osx)"
env:
  # build_externals.sh reads LCG_PLATFORM and passes -DLCG_VERSION_POSTFIX. Kept
  # on this ATLAS-only recipe, not in shared defaults, so the reusable LCG
  # externals keep stacks-identical hashes.
  LCG_PLATFORM: "x86_64-el9-gcc14-opt"
  LCG_VERSION_POSTFIX: "_ATLAS_5"
system:
  # off = network ALLOWED (sandbox_network is "is the restriction on?"; default
  # on blocks network). build_externals.sh clones atlasexternals and downloads
  # Gaudi/acts/GeoModel/vecmem tarballs, so it needs network. NB this is against
  # bits' reproducible default; cleaner end state is to prefetch those and keep
  # the sandbox closed (follow-up).
  sandbox_network: "off"
---
#!/bin/bash -e
##############################
. $(bits-include ModuleRecipe)
##############################
MODULE_OPTIONS="--lib --cmake"   # expose AthenaExternals libs + CMake config to athena
##############################
# Build AthenaExternals exactly as an ATLAS developer would: run athena's own
# Projects/Athena/build_externals.sh, UNCHANGED. bits supplies the LCG base
# (via lcg-view -> LCG_RELEASE_BASE) and the toolchain; ATLAS's script pins
# atlasexternals (externals.txt) + Gaudi/acts/GeoModel/vecmem + LCG 110.
export LCG_RELEASE_BASE="${LCG_RELEASE_BASE:?lcg-view must export LCG_RELEASE_BASE}"
export LCG_PLATFORM="${LCG_PLATFORM:-x86_64-el9-gcc14-opt}"
# el9 build image ships only C.UTF-8; ATLAS build_project_externals.sh otherwise
# forces en_US.UTF-8 (unset/"C"), and every /bin/sh warns. Pin C.UTF-8 as CI does.
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
# -c disables RPM packaging.
# Build in a writable dir — bits mounts SOURCES read-only, so ATLAS's
# default ../build (under SOURCES) fails. -b redirects checkout/build/
# install here; the InstallArea search below follows it.
_bdir="$PWD/build"
# Keep Ninja, but drive the SUPERBUILD serially (-j1): each ExternalProject's install
# runs `cmake -E copy_directory <pkg> <shared platform dir>`, which is NOT concurrency-
# safe — flake8_atlas/PyModules race under -j. Each external's own compile still
# self-parallelizes (its own ninja, all cores), so the compile speedup is kept.
# The bits pip package exports PIP_ROOT (bits' generic <PKG>_ROOT convention).
# pip also reads PIP_ROOT as its own --root install option (PIP_<OPT> env mapping),
# so PyModules' `pip install --user` gets --root=<pip pkg prefix>; change_root then
# prepends that prefix to PYTHONUSERBASE and the wheels land in pip's own tree
# instead of PyModulesBuild, leaving copy_directory's source empty. Findpip uses
# PIP_LCGROOT (not PIP_ROOT), so dropping PIP_ROOT is safe for pip discovery.
unset PIP_ROOT
"$SOURCEDIR/Projects/Athena/build_externals.sh" -c -b "$_bdir" -x "-G Ninja" -k "-j1"
# Route the produced InstallArea platform subtree into $INSTALLROOT so bits
# captures it as this package. build_project.sh installs to
# <builddir>/install/<proj>/<ver>/InstallArea/<platform>.
# TODO(verify on build host): confirm the build dir + that flattening the
# platform subtree (vs preserving InstallArea/) is what athena expects.
_ia=$(find "$_bdir/install" -maxdepth 7 -type d -name InstallArea 2>/dev/null | head -1)
[ -n "$_ia" ] || { echo "ERROR: AthenaExternals InstallArea not found after build_externals.sh" >&2; exit 1; }
rsync -a "$_ia"/*/ "$INSTALLROOT"/
# Carry the AthenaExternals env down to athena's find_package(AthenaExternals).
# TODO(verify): the exact var athena reads (ATLAS_EXT_DIR vs CMAKE_PREFIX_PATH).
MakeModule
cat >> "$MODULEFILE" <<EOF
setenv ATLAS_EXT_DIR  \$PKG_ROOT
EOF
