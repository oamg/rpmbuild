# Using CentOS 8 as base image to support rpmbuild (packages will be Dist el8)
FROM centos:8

# copy needed files
COPY entrypoint.sh /entrypoint.sh

# Installing tools needed for rpmbuild
RUN yum install -y rpm-build rpmdevtools gcc make coreutils python3 yum-utils --allowerasing

# script
ENTRYPOINT ["bash", "/entrypoint.sh"]
