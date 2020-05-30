#!/bin/bash

# initial values
specPath=$1
specFile=$(basename $specPath)
name=$( grep "Name:" $specPath | awk '{print $2}' )
version=$( grep "Version:" $specPath | awk '{print $2}' )

fx_cmd () {
  echo Command: "$@"
  "$@"
}

# show env
fx_cmd env

# preinstall packages
if [ "$GITHUB_PREINSTALL_PACKAGES" != "" ]; then
  fx_cmd yum -y install $GITHUB_PREINSTALL_PACKAGES
fi

# setup rpmbuild tree
fx_cmd rpmdev-setuptree

# Copy spec file from path specPath to /root/rpmbuild/SPECS/
fx_cmd cp /github/workspace/${specPath} /github/home/rpmbuild/SPECS/

# Dowload tar.gz file of source code,  Reference : https://developer.github.com/v3/repos/contents/#get-archive-link
fx_cmd curl --location --output tmp.tar.gz https://api.github.com/repos/${GITHUB_REPOSITORY}/tarball/${GITHUB_REF}

# create directory to match source file - %{name}-{version}.tar.gz of spec file
fx_cmd mkdir ${name}-${version}

# Extract source code 
fx_cmd tar xf tmp.tar.gz -C ${name}-${version} --strip-components 1

# Create Source tar.gz file 
fx_cmd tar -czf ${name}-${version}.tar.gz ${name}-${version}

# list files in current directory /github/workspace/
# await gha_exec('ls -la ');

# Copy tar.gz file to source path
fx_cmd cp ${name}-${version}.tar.gz /github/home/rpmbuild/SOURCES/

# install all BuildRequires: listed in specFile
fx_cmd yum-builddep /github/home/rpmbuild/SPECS/${specFile}

# main operation
fx_cmd rpmbuild -ba /github/home/rpmbuild/SPECS/${specFile}

# Verify RPM is created
fx_cmd ls /github/home/rpmbuild/RPMS

# setOutput rpm_path to /root/rpmbuild/RPMS , to be consumed by other actions like 
# actions/upload-release-asset 

# Get source rpm name , to provide file name, path as output
myOutput=''
fx_cmd ls /github/home/rpmbuild/SRPMS/

# only contents of workspace can be changed by actions and used by subsequent actions 
# So copy all generated rpms into workspace , and publish output path relative to workspace (/github/workspace)
fx_cmd mkdir -p rpmbuild/SRPMS
fx_cmd mkdir -p rpmbuild/RPMS

fx_cmd cp /github/home/rpmbuild/SRPMS/${myOutput} rpmbuild/SRPMS
fx_cmd cp -R /github/home/rpmbuild/RPMS/. rpmbuild/RPMS/

fx_cmd ls -la rpmbuild/SRPMS
fx_cmd ls -la rpmbuild/RPMS

echo "::set-output source_rpm_dir_path=rpmbuild/SRPMS/"
echo "::set-output source_rpm_path=rpmbuild/SRPMS/${myOutput}"
echo "::set-output source_rpm_name=${myOutput}"
echo "::set-output rpm_dir_path=rpmbuild/RPMS/"
echo "::set-output rpm_content_type=application/octet-stream"
