# Github Action - rpmbuild

Github action to builds RPMs from a spec file, using git repo contents as source.

See also (redwain/upload-release-asset).

## Usage
### Pre-requisites
Create a workflow `.yml` file in your repositories `.github/workflows` directory. An [example workflow](#example-workflow---build-rpm) is available below. For more information, reference the GitHub Help Documentation for [Creating a workflow file](https://help.github.com/en/articles/configuring-a-workflow#creating-a-workflow-file). 

**Note:** You need to have a spec file in order to build RPM.


### Inputs

- `spec_path`: The path to the spec file in your repo. [**required**]
- `keep_debuginfo`: Many rpmbuilds generate a debuginfo package.  Default: false.
- `preinstall_packages`: Spec file BuildRequires are installed via yum-builddep, prior to rpmbuild, but sometimes epel-release package must be installed before yum-builddep is executed.  This does that.

### Outputs

- `rpm_dir`: Path to RPMS directory
- `srpm_path`: Path to SRPM file
- `srpm_dir`: Path to SRPMS directory
- `srpm_name`: Name of generated SRPM file
- `content_type`: Content-type for RPM Upload

### Example

Basic:

```yaml
name: rpmbuild
on:
  release:
    types: [created]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: redwain/rpmbuild@el7
      id: rpm
      with:
        spec_path: "extra/redhat/this.spec"
    - uses: redwain/upload-release-assets@master
      with:
        files: 'assets/RPMS/*rpm;assets/SRPMS/*rpm'
```
This workflow triggered on every `release`, builds RPM and SRPM using `extra/redhat/this.spec` from the contents of current git ref triggering the action. Contents are retrived through [GitHub API](https://developer.github.com/v3/repos/contents/#get-archive-link) [downloaded through archive link].

#### Above workflow will create an artifact like :

![artifact_image](assets/upload_artifacts.png)

## Enterprise linux versions:

To generate distribution specific packages, e.g. el6, el7, el8:

- Use redwain/rpmbuild@el6 for CentOS 6 *[el6]*
- Use redwain/rpmbuild@el7 for CentOS 7 *[el7]*
- Use redwain/rpmbuild@el8 for CentOS 8 *[el8]*

## Contribute

Feel free to contribute to this project. Read [CONTRIBUTING Guide](CONTRIBUTING.md) for more details.

## References

* [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)
* [GitHub Learning Lab](https://lab.github.com/)
* [Container Toolkit Action](https://github.com/actions/container-toolkit-action)

## License

The scripts and documentation in this project are released under the [GNU GPLv3](LICENSE)
