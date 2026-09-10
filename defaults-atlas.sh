package: defaults-atlas
version: v1

# ATLAS group overlay — compose with:  --defaults atlas[::gcc15]
#
# defaults-release.sh already declares the ATLAS CVMFS layout and the lcg.bits
# provider (overrides: lcg.bits: tag: "%(release)s"). This overlay adds only the
# ATLAS-specific policy: the LCG line to build against, the platform/postfix the
# AthenaExternals find_package(LCG 110 EXACT) keys off, and the LCG_110 "_ATLAS_5"
# flavour deltas (lcgcmake heptools-110_ATLAS_5.cmake) applied on top of the base
# LCG_110 branch of lcg.bits.
variables:
  # Selects the lcg.bits recipe branch. Must exist in lcg.bits and match what
  # athena/Projects/Athena/build_externals.sh pins (LCG_VERSION_NUMBER=110).
  release: "LCG_110"

env:
  # The manifest the lcg-view package emits is named LCG_externals_<platform>.txt;
  # this must equal ATLAS's BINARY_TAG. TODO(verify): derive from the bits arch.
  LCG_PLATFORM: "x86_64-el9-gcc15-opt"
  # find_package(LCG 110 EXACT) looks for dir LCG_110<postfix> under
  # $LCG_RELEASE_BASE. build_externals.sh also passes this as -DLCG_VERSION_POSTFIX.
  LCG_VERSION_POSTFIX: "_ATLAS_5"

# ===== LCG_110 _ATLAS_5 externals deltas (base lcg.bits LCG_110 + these) =====
overrides:
  # Straight version pins (recipe present, no patch coupling):
  compilebox:
    version: "08.14"
    tag: "08.14"
  herwig3:
    version: "7.3.0p1"
  sherpa:
    version: "3.0.4"
  sherpa-openmpi:
    version: "3.0.4.openmpi3"
    tag: "3.0.4.openmpi3"
  thep8i:
    version: "2.0.6"
  xrootd:
    version: "6.1.1"          # ATLAS pins 6.1.1 over base-110 6.0.3

  # Already at the ATLAS value on the LCG_110 branch — pinned here to record intent
  # (holds if the shared base later drifts):
  cppcheck:
    version: "2.20.0"
  rivet:
    version: "4.1.2"
  thepeg:
    version: "2.3.0"
  vbfnlo:
    version: "3.0"

  # CUDA stack — ATLAS gcc15 target (gcc14 uses cuda 12.8.1, not expressible in a
  # flat overrides block). FLAG: lcg.bits recipes are older, need build support.
  cuda:
    version: "13.3.1"         # recipe currently 12.4
  cudnn:
    version: "9.20.0.48"      # recipe currently 8.2.4.15 (major bump)
    tag: "9.20.0.48"

  # ATLAS author-patched generators. The lcg.bits recipes now carry the matching
  # patches (version-gated), copied from lcgcmake LCG_110, so epos4/hijing build
  # at the ATLAS label. madgraph is the exception — see its note.
  epos4:
    version: "4.0.3.atlas3"   # epos4-4.0.3.atlas3.patch present (version-gated)
    tag: "4.0.3.atlas3"
  hijing:
    version: "1.383bs.2.atlas20260625"   # hijing-1.383bs.2.atlas20260625.patch present (gated)
    tag: "1.383bs.2.atlas20260625"
  # madgraph: aligned to base 3.6.4.atlas2. _ATLAS_5 wants 3.5.11.atlas16, but that
  # needs source MG5_aMC_v3.5.11.tar.gz and an overlay overrides only version/tag,
  # not sources — so the older ATLAS line can't be selected here.
  madgraph5amc:
    version: "3.6.4.atlas2"
    tag: "3.6.4.atlas2"

  # tauola++: ATLAS pins atlas1 (the base), NOT the _ATLAS_5 atlas2 — the atlas2
  # patch is not in lcgcmake LCG_110. Override key is the bits package name.
  tauolacpp:
    version: "1.1.9.atlas1"

  # In heptools-110_ATLAS_5 but NO recipe in lcg.bits yet — add before use:
  #   jax_cuda12_plugin / jax_cuda12_pjrt  (= ${jax_native_version})

disable:
  - R
  - rpy2
  - DD4hep          # AthenaExternals builds GeoModel itself; ATLAS drops LCG DD4hep
  - acts            # AthenaExternals builds its own ACTS (v47.6.1)
  - onnxruntime
  - tf2onnx

---
