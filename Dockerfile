# base image to support rpmbuild (packages will be Dist el6)
FROM centos:6

# copy needed files
COPY entrypoint.sh /entrypoint.sh

# Use archived (vault) repos as the original ones are not available anymore
RUN sed -i 's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo && sed -i 's/^#baseurl.*$/baseurl=http:\/\/vault.centos.org\/6.10\/os\/x86_64/g' /etc/yum.repos.d/CentOS-Base.repo

# Installing tools needed for rpmbuild
RUN yum install -y rpm-build rpmdevtools gcc make coreutils python yum-utils diffutils

# script
ENTRYPOINT ["bash", "/entrypoint.sh"]
