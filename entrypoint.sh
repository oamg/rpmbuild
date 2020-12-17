#!/bin/bash

# sanity
[ ! -r $INPUT_SPEC_PATH ] && echo "::error::file is not readable $INPUT_SPEC_PATH" && exit 1

# initial values
#HOME=/github/home
#GITHUB_WORKSPACE=/github/workspace
RESULT_DEST=${GITHUB_WORKSPACE}/rpmbuild
specFile=$(basename $INPUT_SPEC_PATH)
name=$( grep "Name:" $INPUT_SPEC_PATH | awk '{print $2}' )
version=$( grep "Version:" $INPUT_SPEC_PATH | awk '{print $2}' )

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

### start prep
echo Prepare for build...

# show env
fx_cmd env

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

  # Rewrite Source: key in spec file
  sed -i "s=Source:.*=Source: %{name}-%{version}.tar.gz=" $HOME/rpmbuild/SPECS/${specFile}
fi

# if not source exists
if [ ! -r ${HOME}/rpmbuild/SOURCES/${name}-${version}.tar.gz ]; then
  # Dowload tar.gz file of source code,  Reference : https://developer.github.com/v3/repos/contents/#get-archive-link
  fx_cmd curl --location --output tmp.tar.gz https://api.github.com/repos/${GITHUB_REPOSITORY}/tarball/${GITHUB_REF}

  # create directory to match source file - %{name}-{version}.tar.gz of spec file
  fx_cmd mkdir -v ${name}-${version}

  # Extract source code
  fx_cmd tar xf tmp.tar.gz -C ${name}-${version} --strip-components 1

  # Create Source tar.gz file
  fx_cmd tar czf ${name}-${version}.tar.gz ${name}-${version}

  # list files in current directory /github/workspace/
  # await gha_exec('ls -la ');

  # Copy tar.gz file to source path
  fx_cmd mv -v ${name}-${version}.tar.gz $HOME/rpmbuild/SOURCES/
fi

# install all BuildRequires: listed in specFile
grep "BuildRequires:" $HOME/rpmbuild/SPECS/${specFile} && \
  fx_cmd yum-builddep --assumeyes $HOME/rpmbuild/SPECS/${specFile}

# main operation
echo Starting rpmbuild...
fx_cmd rpmbuild -ba $HOME/rpmbuild/SPECS/${specFile}

### start after action report
echo Publish results to workspace...

# delete debuginfo package
DEBUGINFO_RPM=$(find $HOME/rpmbuild/RPMS -type f | grep debuginfo)
[ "$INPUT_KEEP_DEBUGINFO" != "true" ] && [ "$DEBUGINFO_RPM" != "" ] && \
  fx_cmd rm -v $DEBUGINFO_RPM

# Verify binary output
fx_cmd find $HOME/rpmbuild/RPMS -type f
fx_cmd find $HOME/rpmbuild/SRPMS -type f

# setOutput rpm_path to /root/rpmbuild/RPMS , to be consumed by other actions like 
# actions/upload-release-asset 


# only contents of workspace can be changed by actions and used by subsequent actions 
# So copy all generated rpms into workspace , and publish output path relative to workspace (/github/workspace)
fx_cmd mkdir -vp $RESULT_DEST/{RPMS,SRPMS}
fx_cmd cp -v $(find $HOME/rpmbuild/RPMS -type f -name ${name}\*rpm) $RESULT_DEST/RPMS/
fx_cmd cp -v $(find $HOME/rpmbuild/SRPMS -type f -name ${name}\*rpm) $RESULT_DEST/SRPMS/

# Get source rpm name , to provide file name, path as output
SRPM=$(ls -1 $RESULT_DEST/SRPMS/ | grep ${name})

# Get rpm name
RPM=$(ls -1 $RESULT_DEST/RPMS/ | grep ${name})

# diagnostic
fx_cmd find $RESULT_DEST -type f

# output
cd $GITHUB_WORKSPACE
echo "::set-output name=srpm_dir::rpmbuild/SRPMS/"
echo "::set-output name=srpm_path::rpmbuild/SRPMS/${SRPM}"
echo "::set-output name=srpm_name::${SRPM}"
echo "::set-output name=rpm_dir::rpmbuild/RPMS/"
echo "::set-output name=rpm_path::rpmbuild/RPMS/${RPM}"
echo "::set-output name=rpm_name::${RPM}"
echo "::set-output name=content_type::application/octet-stream"
