#!/bin/bash

# initial values
specPath=$1
specFile=$(basename $specPath)
name=$( grep "Name:" $specPath | awk '{print $2}' )
version=$( grep "Version:" $specPath | awk '{print $2}' )

fx_cmd () {
  echo ::group::$@
  "$@"
  ERR=$?
  if [ $ERR -gt 0 ]; then
    echo ::error::$@ failed ${ERR}
    exit ${ERR}
  fi
  echo ::endgroup::$@
}

# show env
fx_cmd env

# preinstall packages
if [ "$INPUT_PREINSTALL_PACKAGES" != "" ]; then
  fx_cmd yum --assumeyes install $INPUT_PREINSTALL_PACKAGES
fi

# setup rpmbuild tree
fx_cmd rpmdev-setuptree

# Copy spec file from path specPath to /root/rpmbuild/SPECS/
fx_cmd cp -v /github/workspace/${specPath} rpmbuild/SPECS/
#rpmSpec="rpmbuild/SPECS/${specFile}"

# Rewrite Source: key in spec file
sed -i "s=Source:.*=Source: %{name}-%{version}.tar.gz=" rpmbuild/SPECS/${specFile}

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
fx_cmd mv -v ${name}-${version}.tar.gz rpmbuild/SOURCES/

# install all BuildRequires: listed in specFile
fx_cmd yum-builddep --assumeyes rpmbuild/SPECS/${specFile}

# main operation
fx_cmd rpmbuild -ba rpmbuild/SPECS/${specFile}

# Verify binary output
fx_cmd find rpmbuild/RPMS -type f
fx_cmd find rpmbuild/SRPMS -type f

# setOutput rpm_path to /root/rpmbuild/RPMS , to be consumed by other actions like 
# actions/upload-release-asset 

# Get source rpm name , to provide file name, path as output
SRPM=$(ls -1 rpmbuild/SRPMS/ | grep ${name})

# only contents of workspace can be changed by actions and used by subsequent actions 
# So copy all generated rpms into workspace , and publish output path relative to workspace (/github/workspace)
fx_cmd mkdir -vp /github/workspace/assets/{RPMS,SRPMS}
fx_cmd cp -v $(find rpmbuild/RPMS -type f) /github/workspace/assets/RPMS/
fx_cmd cp -v $(find rpmbuild/SRPMS -type f) /github/workspace/assets/SRPMS/

# diagnostic
fx_cmd find /github/workspace/assets -type f

# output
cd /github/workspace
echo "::set-output name=srpm_dir::assets/SRPMS/"
echo "::set-output name=srpm_path::assets/SRPMS/${SRPM}"
echo "::set-output name=srpm_name::${SRPM}"
echo "::set-output name=rpm_dir::assets/RPMS/"
echo "::set-output name=rpm_path::$(find assets/RPMS -type f)"
echo "::set-output name=content_type::application/octet-stream"
