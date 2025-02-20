#!/bin/bash -l
set -e
echo "Building ${1} in ${PWD}"
echo "CommitRef: ${2}"
echo "Subdir: ${3}"
echo "Branch: ${4}"
echo "Articles: ${5}"

# Setup build environment
if [ "${R_LIBS_USER}" ]; then mkdir -p $R_LIBS_USER; fi

# Get the package dir
REPO=$(basename $1)

# Clone, and checkout the revision if any
# Removed --depth 1 because we want to read vignette c/m times
echo "::group::Cloning R package repository"
git clone --recurse-submodules "$1" "${REPO}"
if [ "${2}" ]; then
( cd ${REPO}; git fetch origin "$2"; git reset --hard "$2" )
fi
echo "::endgroup::"

# Subdirectory containing the R package
PKGDIR="${REPO}"
if [ "${3}" ]; then
SUBDIR="$3"
PKGDIR="${PKGDIR}/${SUBDIR}"
fi

DISTRO="$(lsb_release -sc)"
PACKAGE=$(grep '^Package:' "${PKGDIR}/DESCRIPTION" | sed 's/^Package://')
VERSION=$(grep '^Version:' "${PKGDIR}/DESCRIPTION" | sed 's/^Version://')
PACKAGE=$(echo -n "${PACKAGE//[[:space:]]/}")
VERSION=$(echo -n "${VERSION//[[:space:]]/}")
PKG_VERSION="${PACKAGE}_${VERSION}"
SOURCEPKG="${PKG_VERSION}.tar.gz"
BINARYPKG="${PKG_VERSION}_R_x86_64-pc-linux-gnu.tar.gz"

# Export some outputs (even upon failure)
COMMIT_TIMESTAMP="$(git --git-dir=${REPO}/.git log -1 --format=%ct)"
echo ::set-output name=DISTRO::$DISTRO
echo ::set-output name=PACKAGE::$PACKAGE
echo ::set-output name=VERSION::$VERSION
echo ::set-output name=COMMIT_TIMESTAMP::$COMMIT_TIMESTAMP

# Get maintainer details
MAINTAINERINFO=$(Rscript -e "cat(buildtools::maintainer_info_base64('${PKGDIR}'))")
echo ::set-output name=MAINTAINERINFO::$MAINTAINERINFO

# Get commit metadata
COMMITINFO=$(Rscript -e "cat(buildtools::commit_info_base64('$REPO'))")
echo ::set-output name=COMMITINFO::$COMMITINFO

# Get dependencies
echo "::group::Installing R dependencies"
Rscript --no-init-file -e "buildtools::install_dependencies('$PKGDIR')"
echo "::endgroup::"

# Delete latex vignettes for now (latex is to heavy for github actions)
#rm -f ${PKGDIR}/vignettes/*.Rnw

# Do not build articles (vignettes) for remotes
BUILD_ARGS="--no-resave-data"
if [ "${5}" == "false" ]; then
  BUILD_ARGS="${BUILD_ARGS} --no-build-vignettes"
  rm -Rf ${PKGDIR}/vignettes
fi

# Override rmarkdown engine
#if ls ${PKGDIR}/vignettes/*; then
#echo "Found vignettes..."
echo "buildtools::replace_rmarkdown_engine()" > /tmp/vignettehack.R
#fi

# Replace or add "Repository:" in DESCRIPTION
if [ "${MY_UNIVERSE}" ]; then
sed '/^[[:space:]]*$/d' -i "${PKGDIR}/DESCRIPTION" # deletes empty lines at end of DESCRIPTION
sed -n -e '/^Repository:/!p' -e "\$aRepository: ${MY_UNIVERSE}" -i "${PKGDIR}/DESCRIPTION"
echo "RemoteUrl: ${1}" >> "${PKGDIR}/DESCRIPTION"
echo "RemoteRef: ${4:-HEAD}" >> "${PKGDIR}/DESCRIPTION"
echo "RemoteSha: ${2}" >> "${PKGDIR}/DESCRIPTION"
fi

# Build source package. Try vignettes, but build without otherwise.
# R is weird like that, it should be possible to build the package even if there is a documentation bug.
#mv ${REPO}/.git tmpgit
echo "::group::R CMD build"
R_TEXI2DVICMD=emulation PDFLATEX=pdftinytex R_TESTS="/tmp/vignettehack.R" R --no-init-file CMD build ${PKGDIR} --no-manual ${BUILD_ARGS} || VIGNETTE_FAILURE=1
echo "::endgroup::"
if [ "$VIGNETTE_FAILURE" ]; then
echo "::group::R CMD build (trying without vignettes)"
echo "---- ERROR: failed to run: R CMD build -----"
echo "Trying to build source package without vignettes...."
R --no-init-file CMD build ${PKGDIR} --no-manual --no-build-vignettes ${BUILD_ARGS}
echo "::endgroup::"
fi
#mv tmpgit ${REPO}/.git

# Test for filesize enforced by pkg server
test -f "$SOURCEPKG"
FILESIZE=$(stat -c%s "$SOURCEPKG")
if (( FILESIZE >  104857600 )); then
echo "File $SOURCEPKG is more than 100MB. This is currently not allowed."
exit 1
fi

# Confirm that package can be installed on Linux
# For now we don't do a full check to speed up building of subsequent Win/Mac binaries
echo "::group::Test if package can be installed"
R CMD INSTALL "$SOURCEPKG"
echo "::endgroup::"

# Upon successful install, set output value
echo ::set-output name=SOURCEPKG::$SOURCEPKG

# Lookup system dependencies
SYSDEPS=$(Rscript -e "cat(buildtools::package_sysdeps_string('$PACKAGE'))")
echo ::set-output name=SYSDEPS::$SYSDEPS

# Get vignette metadata
VIGNETTES=$(Rscript -e "cat(buildtools::vignettes_base64('$REPO','$PACKAGE','$SUBDIR'))")
echo ::set-output name=VIGNETTES::$VIGNETTES

# Look for a package logo
PKGLOGO=$(Rscript -e "cat(buildtools::find_logo('$PKGDIR', '$1', '$SUBDIR'))")
if [ "$PKGLOGO" ]; then
echo ::set-output name=PKGLOGO::$PKGLOGO
fi

# TODO: can we explicitly set action status/outcome in GHA?
echo "Build complete!"
if [ "$VIGNETTE_FAILURE" ]; then
echo "Installation OK but failed to build vignettes, see 'R CMD build' above."
exit 1
else
exit 0
fi
