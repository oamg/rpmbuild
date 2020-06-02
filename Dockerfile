# base image to support rpmbuild (packages will be Dist el6)
FROM centos:7

# copy needed files
COPY entrypoint.sh /entrypoint.sh

# Installing tools needed for rpmbuild
RUN yum install -y rpm-build rpmdevtools gcc make coreutils python yum-utils

# script
ENTRYPOINT ["bash", "/entrypoint.sh"]
