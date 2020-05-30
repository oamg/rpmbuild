# base image to support rpmbuild (packages will be Dist el6)
FROM centos:6

# copy needed files
COPY entrypoint.sh /entrypoint.sh

# Installing tools needed for rpmbuild
RUN yum install -y rpm-build rpmdevtools gcc make coreutils python yum-utils

# Install nodejs and npm from epel
#RUN yum install -y nodejs npm

# Setting up node to run our JS file
# Download Node Linux binary
#RUN curl --remote-name https://nodejs.org/dist/v12.16.1/node-v12.16.1-linux-x64.tar.xz

# Extract and install
#RUN tar --strip-components 1 -xf node-v* -C /usr/local

# Install all dependecies to execute main.js
#RUN npm install --production

# Rebuild typescript src/main.ts into lib/main.ts
# RUN npm run-script build

# script
ENTRYPOINT ["bash", "/entrypoint.sh"]
