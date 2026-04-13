# NDCTL Test Runner

NDCTL Test Runner is a GitHub Actions workflow that allows Linux kernel
developers to validate kernel changes using the ndctl test suites for
CXL, NVDIMM, and DAX.

The workflow builds a kernel, boots it in QEMU using run_qemu_ci.sh, and
executes the selected ndctl test suites.

The goal is to provide a simple automated testing environment that runs
entirely on GitHub-hosted infrastructure. No special hardware is required.


## Quick Start

1. Fork this repository.

2. Open the **Actions** tab in your fork.

3. Select **ndctl-test runner**.

4. Click **Run workflow**.

5. Provide your kernel repository and branch.

Repository inputs may be either:

- a GitHub repository in `owner/name` form
- a full git URL (for example a kernel.org maintainer tree)


## Try It Now

You can immediately test the current CXL maintainer tree.

Example inputs:

```
kernel_repo: https://git.kernel.org/pub/scm/linux/kernel/git/cxl/cxl.git
kernel_branch: fixes
ndctl_repo: pmem/ndctl
ndctl_branch: pending
test_suite: cxl
timeout_min: 35
```

This runs the ndctl CXL test suite against the current CXL maintainer
fixes branch in QEMU.


## Workflow Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `kernel_repo` | Kernel repo: `owner/name` or full git URL | `AlisonSchofield/linux-kernel` |
| `kernel_branch` | Kernel branch, tag, or SHA | `cxl-testme` |
| `ndctl_repo` | ndctl repo: `owner/name` or full git URL | `pmem/ndctl` |
| `ndctl_branch` | ndctl branch, tag, or SHA | `pending` |
| `test_suite` | Test suites to run (see below) | `all` |
| `timeout_min` | Guest timeout in minutes | `35` |

### test_suite values

| Value | Test suites run |
|-------|----------------|
| `all` | CXL, NVDIMM, and DAX tests |
| `cxl` | CXL unit tests only |
| `nvdimm` | NVDIMM (nfit) tests only |
| `dax` | DAX tests only |

Space- or comma-separated combinations are also accepted (for example `nvdimm dax`).


## Example Inputs

Example using a GitHub kernel repository (CXL testing):

```
kernel_repo: yourname/linux
kernel_branch: cxl-feature-branch
ndctl_repo: pmem/ndctl
ndctl_branch: pending
test_suite: cxl
timeout_min: 35
```

Example using a kernel.org maintainer tree (all suites):

```
kernel_repo: https://git.kernel.org/pub/scm/linux/kernel/git/cxl/cxl.git
kernel_branch: next
ndctl_repo: pmem/ndctl
ndctl_branch: pending
test_suite: all
timeout_min: 35
```


## Running From The Command Line

Tests can also be triggered from the command line using the GitHub CLI.

Install the GitHub CLI and authenticate:

```
gh auth login
```

Run the workflow:

```
gh workflow run "ndctl-test runner" \
  --repo yourname/ndctl-test-runner \
  -f kernel_repo=yourname/linux \
  -f kernel_branch=cxl-feature-branch \
  -f test_suite=cxl
```

Example using the CXL maintainer tree:

```
gh workflow run "ndctl-test runner" \
  --repo yourname/ndctl-test-runner \
  -f kernel_repo=https://git.kernel.org/pub/scm/linux/kernel/git/cxl/cxl.git \
  -f kernel_branch=fixes \
  -f test_suite=cxl
```

Watch the run:

```
gh run watch
```


## Example Test Output

The workflow summary displays the results of each test.

Example CXL output:

```
1/13 ndctl:cxl / cxl-topology.sh        OK
2/13 ndctl:cxl / cxl-region-sysfs.sh    OK
3/13 ndctl:cxl / cxl-labels.sh          OK
4/13 ndctl:cxl / cxl-create-region.sh   OK
5/13 ndctl:cxl / cxl-xor-region.sh      OK
...
13/13 ndctl:cxl / cxl-poison.sh         OK

Ok:                 13
Fail:               0
Skipped:            0
```

Detailed logs are also uploaded as workflow artifacts.


## Automatically Trigger Tests From Your Kernel Repository

Developers may configure their kernel repository to automatically trigger
the NDCTL Test Runner whenever commits are pushed.

Create the file:

```
.github/workflows/ndctl-test.yml
```

Example workflow:

```
name: run ndctl tests

on:
  push:
    branches:
      - cxl-*

jobs:
  trigger:
    runs-on: ubuntu-latest

    steps:
      - name: Trigger NDCTL Test Runner
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

        run: |
          gh workflow run "ndctl-test runner" \
            --repo yourname/ndctl-test-runner \
            -f kernel_repo=${{ github.repository }} \
            -f kernel_branch=${{ github.ref_name }} \
            -f test_suite=cxl
```


## Overview

This project packages the run_qemu_ci.sh testing environment into a
reproducible GitHub Actions workflow for automated ndctl test execution.

The runner performs the following steps:

1. Checkout the requested kernel repository and branch
2. Checkout the requested ndctl repository and branch
3. Build the kernel with configuration appropriate for the selected test suite
4. Boot the kernel in QEMU using run_qemu_ci.sh
5. Execute the selected ndctl test suites (CXL, NVDIMM, DAX, or all)
6. Publish logs and test summaries


## Test Environment

The workflow currently runs with the following configuration:

```
GitHub runner: ubuntu-24.04
Architecture:  x86_64
mkosi image:   ubuntu noble
```


## Relationship to run_qemu

https://github.com/pmem/run_qemu

This project builds on the run_qemu infrastructure originally developed
by Vishal Verma and expanded upon by Marc Herbert.

`run_qemu_ci.sh` is a CI-focused derivative of the upstream `run_qemu.sh`.
It retains the kernel build, rootfs image creation, and automated QEMU
boot and test execution, while removing all interactive features (SSH
access, networking setup, GDB integration, and developer convenience
tools) that are not needed for automated CI runs.
