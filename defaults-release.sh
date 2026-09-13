package: defaults-release
version: v1
system:
  prefix:                     "/cvmfs/bits.cern.ch/atlas"
  cvmfs_user_prefix:          "{prefix}/user"
  cvmfs_releases_template:    "{prefix}/{release}/{family}{pkg}/{tag}/{platform}"
  cvmfs_modules_template:     "{prefix}/{release}/{platform}/Modules/modulefiles/{pkg}"
  cvmfs_shared_path_template: "{prefix}/{release}/noarch/{pkg}/{tag}"

env:
  CXXFLAGS: "-fPIC -g -O2"
  CFLAGS: "-fPIC -g -O2"
  CMAKE_BUILD_TYPE: "RELWITHDEBINFO"
  MACOSX_DEPLOYMENT_TARGET: '14.0'
  ENABLE_IPO: 'OFF'

---
