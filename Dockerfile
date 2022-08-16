# Using CentOS 8 as base image to support rpmbuild (packages will be Dist el8)
FROM centos:8


# Change CentOS Linux URLs to archived Vault
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-* && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=https://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*

# copy needed files
COPY entrypoint.sh /entrypoint.sh

# Installing tools needed for rpmbuild
RUN yum install -y rpm-build rpmdevtools gcc make coreutils python3 yum-utils --allowerasing

# script
ENTRYPOINT ["bash", "/entrypoint.sh"]
