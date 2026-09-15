#!/bin/bash
# setupATLAS.sh - drop-in replacement for the standard ATLAS `setupATLAS` that
# makes the *bits* backend the provider of externals and the LCG stack.
#
# Usage (source it, exactly like the real setupATLAS):
#     source setupATLAS.sh
#     asetup ...        # asetup/find_package now resolve externals + LCG from bits
#
# --- where the bits install lives (override BITS_SW for your checkout) -----------
: "${BITS_SW:=sw}"
: "${BITS_ARCH:=x86_64-el9}"
_bits_base="${BITS_SW}/${BITS_ARCH}"

# --- 1) LCG stack from bits ------------------------------------------------------
# The lcg-view package installs LCG_<n>_ATLAS_<r>/LCG_externals_<platform>.txt under
# its own prefix; that prefix IS LCG_RELEASE_BASE. AtlasLCG's find_package(LCG)
# keys off it and sets <PKG>_LCGROOT from the manifest's dir field.
if [ -d "${_bits_base}/lcg-view/latest" ]; then
    export LCG_RELEASE_BASE="${LCG_RELEASE_BASE:-${_bits_base}/lcg-view/latest}"
    echo "setupATLAS.sh: LCG_RELEASE_BASE -> ${LCG_RELEASE_BASE} (bits)"
fi

# --- 2) bits-built externals + Athena release ------------------------------------
# Each bits-built ATLAS project installs a relocatable setup.sh that sets
# CMAKE_PREFIX_PATH / PATH / LD_LIBRARY_PATH ...; sourcing Athena pulls
# AthenaExternals transitively.
for _p in atlasexternals Athena; do
    if [ -f "${_bits_base}/${_p}/latest/setup.sh" ]; then
        source "${_bits_base}/${_p}/latest/setup.sh"
        echo "setupATLAS.sh: sourced ${_p} (bits)"
    fi
done

# --- 3) stock ALRB setupATLAS (UNCHANGED) ----------------------------------------
# Provides asetup/lsetup exactly as usual; it honours the variables set above.
export ATLAS_LOCAL_ROOT_BASE="${ATLAS_LOCAL_ROOT_BASE:-/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase}"
if [ -f "${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh" ]; then
    source "${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh" "$@"
else
    echo "setupATLAS.sh: ALRB not found at ${ATLAS_LOCAL_ROOT_BASE};" >&2
    echo "               bits externals/LCG env is set, but asetup/lsetup are unavailable." >&2
fi

unset _bits_base _p
