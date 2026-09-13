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
build_requires:
  - bits-recipe-tools
  - CMake
  - ninja
  - Python
  - "GCC-Toolchain:(?!osx)"
env:
  # build_externals.sh reads LCG_PLATFORM and passes -DLCG_VERSION_POSTFIX. Kept
  # on this ATLAS-only recipe, not in shared defaults, so the reusable LCG
  # externals keep stacks-identical hashes.
  LCG_PLATFORM: "x86_64-ubuntu2510-gcc15-opt"
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
export LCG_PLATFORM="${LCG_PLATFORM:-x86_64-ubuntu2510-gcc15-opt}"
# -c disables RPM packaging.
"$SOURCEDIR/Projects/Athena/build_externals.sh" -c
# Route the produced InstallArea platform subtree into $INSTALLROOT so bits
# captures it as this package. build_project.sh installs to
# <builddir>/install/<proj>/<ver>/InstallArea/<platform>.
# TODO(verify on build host): confirm the build dir + that flattening the
# platform subtree (vs preserving InstallArea/) is what athena expects.
_ia=$(find "$SOURCEDIR/.." -maxdepth 7 -type d -name InstallArea 2>/dev/null | head -1)
[ -n "$_ia" ] || { echo "ERROR: AthenaExternals InstallArea not found after build_externals.sh" >&2; exit 1; }
rsync -a "$_ia"/*/ "$INSTALLROOT"/
# Carry the AthenaExternals env down to athena's find_package(AthenaExternals).
# TODO(verify): the exact var athena reads (ATLAS_EXT_DIR vs CMAKE_PREFIX_PATH).
MakeModule
cat >> "$MODULEFILE" <<EOF
setenv ATLAS_EXT_DIR  \$PKG_ROOT
EOF
