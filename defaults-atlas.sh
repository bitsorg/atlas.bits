package: defaults-atlas
version: v1

# ATLAS group overlay — compose with:  --defaults atlas[::gcc15]
#
# Adds only ATLAS-specific policy on top of the shared stacks.bits defaults: the
# LCG line to build against, the lcg.bits branch selection, and the LCG_110
# "_ATLAS_5" flavour deltas (lcgcmake heptools-110_ATLAS_5.cmake). The
# platform/postfix that find_package(LCG 110 EXACT) keys off are NOT set here —
# they live on the lcg-view / atlasexternals recipes that consume them, so they
# never enter the shared defaults-release hash and every unpinned LCG external
# stays reusable across stacks and ATLAS builds.
  
requires:
  - stacks.bits

variables:
  # Selects the lcg.bits recipe branch. Must exist in lcg.bits and match what
  # athena/Projects/Athena/build_externals.sh pins (LCG_VERSION_NUMBER=110).
  release: "LCG_110"

# ATLAS CVMFS namespace + layout (system: is NOT hashed, so it never affects
# artifact reuse). Kept here so atlas.bits can drop its own defaults-release.sh
# and inherit the shared build env + package_family from stacks.bits, while
# still publishing into the ATLAS tree with ATLAS's path templates.
system:
  prefix:                     "/cvmfs/bits.cern.ch/atlas"
  cvmfs_user_prefix:          "{prefix}/user"
  cvmfs_releases_template:    "{prefix}/{release}/{family}{pkg}/{tag}/{platform}"
  cvmfs_modules_template:     "{prefix}/{release}/{platform}/Modules/modulefiles/{pkg}"
  cvmfs_shared_path_template: "{prefix}/{release}/noarch/{pkg}/{tag}"

# ===== LCG_110 _ATLAS_5 externals deltas (base lcg.bits LCG_110 + these) =====
overrides:
  # Build lcg.bits at the LCG_110 branch (via the release variable above).
  lcg.bits:
    tag: "%(release)s"

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

  # pythia6: LCG_110 label 429.2 == author source 6.4.28 (pythia-6.4.28.f.gz),
  # which the recipe already downloads; only the label differs. (Body compiles
  # bare pythia6.f; if ATLAS needs hepevt=200000, that is a lcg.bits body change.)
  pythia6:
    version: "429.2"
    tag: "429.2"

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
  # patches (version-gated), copied from lcgcmake LCG_110, so epos4/hijing/madgraph
  # build at the ATLAS label. tauola++ is the exception — see its note.
  epos4:
    version: "4.0.3.atlas3"   # epos4-4.0.3.atlas3.patch present (version-gated)
    tag: "4.0.3.atlas3"
  hijing:
    version: "1.383bs.2.atlas20260625"   # hijing-1.383bs.2.atlas20260625.patch present (gated)
    tag: "1.383bs.2.atlas20260625"
  # madgraph5amc: LCG_110_ATLAS_5 pins 3.5.11.atlas16. Overrides do a plain
  # spec.update(), so they set sources too — point at the 3.5.11 tarball and the
  # recipe's version-gated 3.5.11.atlas16 patch activates automatically.
  madgraph5amc:
    version: "3.5.11.atlas16"
    tag: "3.5.11.atlas16"
    sources:
      - https://lcgpackages.web.cern.ch/tarFiles/sources/MCGeneratorsTarFiles/MG5_aMC_v3.5.11.tar.gz

  # tauola++: _ATLAS_5 lists atlas2, but no atlas2 patch exists in lcg.bits or
  # lcgcmake, so atlas1 is the newest buildable line. An overlay CAN carry a
  # source/patch (see madgraph) — add them here if an atlas2 patch appears.
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
