#!/bin/bash

# initial values
specPath=$1
specFile=$(basename $specPath)
name=$( grep "Name:" $specPath | awk '{print $2}' )
version=$( grep "Version:" $specPath | awk '{print $2}' )

# show env
env

# setup rpmbuild tree
rpmdev-setuptree

# Copy spec file from path specPath to /root/rpmbuild/SPECS/
cp /github/workspace/${specPath} /github/home/rpmbuild/SPECS/

# Dowload tar.gz file of source code,  Reference : https://developer.github.com/v3/repos/contents/#get-archive-link
curl --location --output tmp.tar.gz https://api.github.com/repos/${owner}/${repo}/tarball/${ref}

# create directory to match source file - %{name}-{version}.tar.gz of spec file
mkdir ${name}-${version}

# Extract source code 
tar xf tmp.tar.gz -C ${name}-${version} --strip-components 1

# Create Source tar.gz file 
tar -czf ${name}-${version}.tar.gz ${name}-${version}

# list files in current directory /github/workspace/
# await gha_exec('ls -la ');

# Copy tar.gz file to source path
cp ${name}-${version}.tar.gz /github/home/rpmbuild/SOURCES/

# install all BuildRequires: listed in specFile
yum-builddep /github/home/rpmbuild/SPECS/${specFile}

# main operation
rpmbuild -ba /github/home/rpmbuild/SPECS/${specFile}

# Verify RPM is created
await gha_exec('ls /github/home/rpmbuild/RPMS');

# setOutput rpm_path to /root/rpmbuild/RPMS , to be consumed by other actions like 
# actions/upload-release-asset 

# Get source rpm name , to provide file name, path as output
myOutput=''
ls /github/home/rpmbuild/SRPMS/

# only contents of workspace can be changed by actions and used by subsequent actions 
# So copy all generated rpms into workspace , and publish output path relative to workspace (/github/workspace)
mkdir -p rpmbuild/SRPMS
mkdir -p rpmbuild/RPMS

cp /github/home/rpmbuild/SRPMS/${myOutput} rpmbuild/SRPMS
cp -R /github/home/rpmbuild/RPMS/. rpmbuild/RPMS/

ls -la rpmbuild/SRPMS
ls -la rpmbuild/RPMS

echo "::set-output source_rpm_dir_path=rpmbuild/SRPMS/"
echo "::set-output source_rpm_path=rpmbuild/SRPMS/${myOutput}"
echo "::set-output source_rpm_name=${myOutput}"
echo "::set-output rpm_dir_path=rpmbuild/RPMS/"
echo "::set-output rpm_content_type=application/octet-stream"
