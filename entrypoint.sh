#!/bin/bash

fx_cmd () {
  echo ::group::$@
  #echo Command: $@
  "$@"
  ERR=$?
  echo ::endgroup::$@
  if [ $ERR -gt 0 ]; then
    echo ::error::$@ failed ${ERR}
    exit ${ERR}
  fi
}

fx_sed_i () {
  echo ::group::sed -i "$1" "$2"
  tmpFn=/tmp/$(basename $2)
  cp $2 $tmpFn
  /bin/sed --in-place "$1" "$2"
  ERR=$?
  [ ! $ERR -gt 0 ] && diff -u $tmpFn $2
  echo ::endgroup::sed -i "$1" "$2"
  if [ $ERR -gt 0 ]; then
    echo ::error::sed -i "$1" "$2" failed ${ERR}
    exit ${ERR}
  fi
}

# sanity
[ ! -r $INPUT_SPEC_PATH ] && echo "::error::file is not readable $INPUT_SPEC_PATH" && exit 1

# initial values
RESULT_DEST=${GITHUB_WORKSPACE}/rpmbuild
specPath=$INPUT_SPEC_PATH
specFile=$(basename $specPath)

### start prep
echo Prepare for build...

# show env
#fx_cmd env

# preinstall packages
if [ "$INPUT_PREINSTALL_PACKAGES" != "" ]; then
  fx_cmd yum --assumeyes install $INPUT_PREINSTALL_PACKAGES
fi

# setup rpmbuild tree
fx_cmd rpmdev-setuptree

# if not spec file exist
if [ ! -r ${HOME}/rpmbuild/SPECS/${specFile} ]; then
  # Copy spec file from path INPUT_SPEC_PATH to $HOME/rpmbuild/SPECS/
  fx_cmd cp -v $GITHUB_WORKSPACE/${INPUT_SPEC_PATH} $HOME/rpmbuild/SPECS/

  # update specPath
  specPath=$HOME/rpmbuild/SPECS/$specFile

  # Rewrite Source: key in spec file
  fx_sed_i "s=Source:.*=Source: %{name}-%{version}.tar.gz=" $specPath
fi

# rewrite Name: if requested
if [ "$INPUT_SPEC_NAME" != "" ]; then
  fx_sed_i "s=Name:.*=Name: $INPUT_SPEC_NAME=" $specPath
fi
name=$( grep "Name:" $specPath | awk '{print $2}' )

# rewrite Version: if requested
if [ "$INPUT_SPEC_VERSION" != "" ]; then
  fx_sed_i "s=Version:.*=Version: $INPUT_SPEC_VERSION=" $specPath
fi
version=$( grep "Version:" $specPath | awk '{print $2}' )

nameVersion="${name}-${version}"

# if not source exists
if [ ! -r ${HOME}/rpmbuild/SOURCES/${nameVersion}.tar.gz ]; then
  #
  tmpNameVerTarGz=/tmp/${nameVersion}.tar.gz

  # create directory to match source file - %{name}-{version}.tar.gz of spec file
  fx_cmd mkdir -v /tmp/${nameVersion}

  if [ "$INPUT_REDOWNLOAD_SOURCE" == "true" ]; then
    # Dowload tar.gz file of source code,  Reference : https://developer.github.com/v3/repos/contents/#get-archive-link
    fx_cmd curl --location --output /tmp/tmp.tar.gz https://api.github.com/repos/${GITHUB_REPOSITORY}/tarball/${GITHUB_REF}

    # Extract source code
    fx_cmd tar xvf /tmp/tmp.tar.gz -C /tmp/${nameVersion} --strip-components 1
  else
    # Copy source code
    fx_cmd cp -r $GITHUB_WORKSPACE/. /tmp/${nameVersion}
  fi

  # Create Source tar.gz file
  fx_cmd tar czvf $tmpNameVerTarGz -C /tmp $nameVersion

  # Copy tar.gz file to source path
  fx_cmd mv -v $tmpNameVerTarGz $HOME/rpmbuild/SOURCES/
fi

# install all BuildRequires: listed in specFile
RPM_BUILD_REQS=$(grep --count "BuildRequires:" $specPath)
if [ "$RPM_BUILD_REQS" != "" ]; then
  fx_cmd yum-builddep --assumeyes $specPath
fi

# main operation
echo Starting rpmbuild...
fx_cmd rpmbuild -ba $specPath

### start after action report
echo Publish results to workspace...

# delete debuginfo package
DEBUGINFO_RPM=$(find $HOME/rpmbuild/RPMS -type f | grep --count debuginfo)
if [ "$INPUT_KEEP_DEBUGINFO" != "true" -a "$DEBUGINFO_RPM" != "" ]; then
  fx_cmd rm -v $(find $HOME/rpmbuild/RPMS -type f | grep debuginfo)
fi

# Verify binary output
fx_cmd ls -aFl $HOME/rpmbuild/{RPMS,SRPMS}

# setOutput rpm_path to /root/rpmbuild/RPMS , to be consumed by other actions like 
# actions/upload-release-asset 

# Get source rpm name , to provide file name, path as output
SRPM=$(ls -1 $HOME/rpmbuild/SRPMS/ | grep ${name})

# only contents of workspace can be changed by actions and used by subsequent actions 
# So copy all generated rpms into workspace , and publish output path relative to workspace (/github/workspace)
fx_cmd mkdir -vp $RESULT_DEST/{RPMS,SRPMS}
fx_cmd cp -v "$HOME/rpmbuild/RPMS/${name}*rpm" $RESULT_DEST/RPMS/
fx_cmd cp -v "$HOME/rpmbuild/SRPMS/${name}*rpm" $RESULT_DEST/SRPMS/

# diagnostic
fx_cmd find $RESULT_DEST -type f

# output
cd $GITHUB_WORKSPACE
echo "::set-output name=srpm_dir::rpmbuild/SRPMS/"
echo "::set-output name=srpm_path::rpmbuild/SRPMS/${SRPM}"
echo "::set-output name=srpm_name::${SRPM}"
echo "::set-output name=rpm_dir::rpmbuild/RPMS/"
echo "::set-output name=rpm_path::$(find rpmbuild/RPMS -type f)"
echo "::set-output name=content_type::application/octet-stream"
