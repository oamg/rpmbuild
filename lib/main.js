"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
const gha_core = require('@actions/core');
const gha_github = require('@actions/github');
const gha_exec = require('@actions/exec').exec;
//const gha_io = require('@actions/io');
const node_fs = require('fs');
const node_path = require('path');
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        // catch thrown errors
        try {
            // Get github context data
            const context = gha_github.context;
            // To be used to get contents of this git ref 
            const owner = context.repo.owner;
            const repo = context.repo.repo;
            const ref = context.ref;
            // input: spec_file
            const specPath = gha_core.getInput('spec_file');
            const specFile = node_path.basename(specPath);
            // Read spec file and get values 
            var data = node_fs.readFileSync(specPath, 'utf8');
            let name = '';
            let version = '';
            for (var line of data.split('\n')) {
                var lineArray = line.split(/[ ]+/);
                if (lineArray[0].includes('Name')) {
                    name = name + lineArray[1];
                }
                if (lineArray[0].includes('Version')) {
                    version = version + lineArray[1];
                }
            }
            console.log(`name: ${name}`);
            console.log(`version: ${version}`);
            // setup rpm tree
            yield gha_exec('rpmdev-setuptree');
            // Copy spec file from path specPath to /root/rpmbuild/SPECS/
            yield gha_exec(`cp /github/workspace/${specPath} /github/home/rpmbuild/SPECS/`);
            // Dowload tar.gz file of source code,  Reference : https://developer.github.com/v3/repos/contents/#get-archive-link
            yield gha_exec(`curl -L --output tmp.tar.gz https://api.github.com/repos/${owner}/${repo}/tarball/${ref}`);
            // create directory to match source file - %{name}-{version}.tar.gz of spec file
            yield gha_exec(`mkdir ${name}-${version}`);
            // Extract source code 
            yield gha_exec(`tar xvf tmp.tar.gz -C ${name}-${version} --strip-components 1`);
            // Create Source tar.gz file 
            yield gha_exec(`tar -czvf ${name}-${version}.tar.gz ${name}-${version}`);
            // // list files in current directory /github/workspace/
            // await gha_exec('ls -la ');
            // Copy tar.gz file to source path
            yield gha_exec(`cp ${name}-${version}.tar.gz /github/home/rpmbuild/SOURCES/`);
            // install all BuildRequires: listed in specFile
            yield gha_exec(`yum-builddep /github/home/rpmbuild/SPECS/${specFile}`);
            // main operation
            yield gha_exec(`rpmbuild -ba /github/home/rpmbuild/SPECS/${specFile}`);
            // Verify RPM is created
            yield gha_exec('ls /github/home/rpmbuild/RPMS');
            // setOutput rpm_path to /root/rpmbuild/RPMS , to be consumed by other actions like 
            // actions/upload-release-asset 
            // Get source rpm name , to provide file name, path as output
            let myOutput = '';
            yield gha_exec('ls /github/home/rpmbuild/SRPMS/', (err, stdout, stderr) => {
                if (err) {
                    //some err occurred
                    console.error(err);
                }
                else {
                    // the *entire* stdout and stderr (buffered)
                    console.log(`stdout: ${stdout}`);
                    myOutput = myOutput + `${stdout}`.trim();
                    console.log(`stderr: ${stderr}`);
                }
            });
            // only contents of workspace can be changed by actions and used by subsequent actions 
            // So copy all generated rpms into workspace , and publish output path relative to workspace (/github/workspace)
            yield gha_exec(`mkdir -p rpmbuild/SRPMS`);
            yield gha_exec(`mkdir -p rpmbuild/RPMS`);
            yield gha_exec(`cp /github/home/rpmbuild/SRPMS/${myOutput} rpmbuild/SRPMS`);
            yield gha_exec(`cp -R /github/home/rpmbuild/RPMS/. rpmbuild/RPMS/`);
            yield gha_exec(`ls -la rpmbuild/SRPMS`);
            yield gha_exec(`ls -la rpmbuild/RPMS`);
            // set outputs to path relative to workspace ex ./rpmbuild/
            gha_core.setOutput("source_rpm_dir_path", `rpmbuild/SRPMS/`); // path to  SRPMS directory
            gha_core.setOutput("source_rpm_path", `rpmbuild/SRPMS/${myOutput}`); // path to Source RPM file
            gha_core.setOutput("source_rpm_name", `${myOutput}`); // name of Source RPM file
            gha_core.setOutput("rpm_dir_path", `rpmbuild/RPMS/`); // path to RPMS directory
            gha_core.setOutput("rpm_content_type", "application/octet-stream"); // Content-type for Upload
        }
        catch (error) {
            gha_core.setFailed(error.message);
        }
    });
}
run();
