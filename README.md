```markdown
# ab-fio

**ab-fio** is a containerized storage benchmarking tool designed to evaluate disk and block device performance using [fio](https://github.com/axboe/fio).

It provides predefined workloads for HDDs, SSDs, and NVMe devices, allowing users to evaluate storage performance through a simple command-line interface. The tool supports both local disks and block devices exposed by storage systems, including Ceph RBD.

Test results are printed to standard output in CSV format, making them suitable for further analysis, monitoring, and performance comparisons.

## Features

- **Multiple storage types:** Supports HDD, SSD, and NVMe devices.
- **Automatic device detection:** Determines the device type using its rotational property and device name.
- **Custom device type:** Allows explicitly specifying the device type when automatic detection is unsuitable.
- **Predefined workloads:** Includes latency, random I/O, and sequential I/O benchmarks.
- **Custom workloads:** Supports running user-defined fio workload files.
- **Configurable test duration:** Allows specifying the duration of each test.
- **Configurable test interval:** Controls the delay between consecutive workloads.
- **CSV output:** Prints test results in CSV format for further analysis.
- **Containerized execution:** Runs inside Docker or Podman without requiring fio to be installed on the host.

## Supported Devices

The tool supports the following device types:

| Device Type | Description |
|---|---|
| `hdd` | Hard Disk Drives |
| `ssd` | Solid State Drives |
| `nvme` | NVMe storage devices |

Any block device accessible through `/dev/` can be used as a test target, provided that the host and container have the necessary permissions.

Examples:

- `/dev/sda`
- `/dev/sdf`
- `/dev/nvme0n1`
- `/dev/rbd0`

### Device Type Detection

By default, `ab-fio` attempts to determine the device type automatically:

- **HDD:** Identified using the device's rotational property.
- **NVMe:** Identified using the device name.
- **SSD:** Used for non-rotational devices that are not identified as NVMe.

The detected device type determines which predefined workloads are executed.

For network-backed block devices, virtual disks, or devices whose rotational property does not accurately represent their underlying storage characteristics, explicitly specifying the device type is recommended.

For example, a Ceph RBD device may be exposed as `/dev/rbd0`. Its underlying storage could be HDDs, SSDs, or NVMe devices, so automatic detection may not reflect the desired benchmark workload.

In such cases, use the `--type` option to select the appropriate workload profile.

## Requirements

The following requirements must be met before running the tool:

- Docker or Podman installed on the host.
- A block device accessible from the host.
- Root privileges or sufficient permissions to access the target device.
- The container must be run with `--privileged` to access the specified block device.

**Important:** Running fio directly against a block device can overwrite existing data. Make sure the target device is not being used by a filesystem, application, or storage service that must remain operational. Use a dedicated test device whenever possible.

## Getting Started

### Pull the Image

```bash
docker pull docker.io/abolfazlmarj/ab-fio:v2.3.1
```

Alternatively, use Podman:

```bash
podman pull docker.io/abolfazlmarj/ab-fio:v2.3.1
```

### Display Help

```bash
podman run --rm \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  --help
```

The tool displays its available options and workload profiles.

### Basic Usage

```bash
podman run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf
```

This command runs the predefined workloads associated with the detected device type.

The default test duration is 600 seconds per workload, and the default interval between workloads is 3 seconds.

## Command-Line Options

| Option | Description | Default | Required |
|---|---|---|---|
| `-d`, `--device` | Target block device to benchmark | None | Yes |
| `-t`, `--time` | Duration of each test, in seconds | `600` | No |
| `-w`, `--workload` | Workload selection | `all` | No |
| `--type` | Device type: `hdd`, `ssd`, or `nvme` | Automatic detection | No |
| `--interval` | Delay between consecutive tests, in seconds | `3` | No |
| `-h`, `--help` | Display command-line help | None | No |

### Workload Options

The following predefined workloads are available:

| Workload | Description | Supported Device Types |
|---|---|---|
| `all` | Run all workloads associated with the device type | HDD, SSD, NVMe |
| `data` | Run custom workloads supplied through the `/data` directory | HDD, SSD, NVMe |
| `lat-r` | Random read latency | HDD, SSD, NVMe |
| `lat-w` | Random write latency | HDD, SSD, NVMe |
| `rnd-r` | Random read performance | HDD, SSD, NVMe |
| `rnd-w` | Random write performance | HDD, SSD, NVMe |
| `seq-r` | Sequential read performance | HDD, SSD, NVMe |
| `seq-w` | Sequential write performance | HDD, SSD, NVMe |
| `rnd-r2` | Additional random read workload | SSD, NVMe |
| `rnd-w2` | Additional random write workload | SSD, NVMe |
| `rnd-r3` | Additional random read workload | NVMe |
| `rnd-w3` | Additional random write workload | NVMe |

The `rnd-r2`, `rnd-w2`, `rnd-r3`, and `rnd-w3` workloads are intended for the additional performance testing profiles defined for SSD and NVMe devices.

## Examples

All examples use the image:

```text
docker.io/abolfazlmarj/ab-fio:v2.3.1
```

### 1. Run All Workloads on an HDD

```bash
docker run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf \
  --type hdd
```

This runs the predefined HDD workloads against `/dev/sdf`.

### 2. Run a Specific Workload

Run random write testing against an HDD:

```bash
docker run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf \
  --type hdd \
  -w rnd-w
```

### 3. Configure the Test Duration

Run all HDD workloads for 60 seconds each:

```bash
docker run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf \
  --type hdd \
  --time 60
```

### 4. Configure the Interval Between Workloads

Set the interval between consecutive tests to 60 seconds:

```bash
docker run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf \
  --interval 60
```

The interval is the delay between the completion of one workload and the start of the next workload.

### 5. Specify the Device Type Explicitly

Run NVMe workloads against a device that is not automatically detected as NVMe:

```bash
docker run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf \
  --type nvme
```

This executes the NVMe workload profile against `/dev/sdf`, regardless of its physical device type.

### 6. Run NVMe Workloads on an HDD

Run NVMe workloads against an HDD for 100 seconds per test:

```bash
docker run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf \
  --type nvme \
  --time 100
```

This can be useful when comparing the performance of different storage devices under the same workload profile.

### 7. Run a Workload Against a Ceph RBD Device

Run random write testing against a Ceph RBD device for 120 seconds:

```bash
docker run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/rbd0 \
  --type hdd \
  --time 120 \
  --workload rnd-w
```

In this example, the HDD workload profile is used to test the RBD device.

The specified type determines the workload profile, not the underlying physical storage type of the RBD image.

## Custom Workloads

`ab-fio` supports custom fio workload files supplied from outside the container.

This allows users to define their own fio workloads without rebuilding the container image.

### Directory Structure

The custom workload directory must be mounted inside the container at `/data`.

Example:

```text
my-workloads/
├── custom-read.fio
├── custom-write.fio
└── custom-randwrite.fio
```

### Run Custom Workloads

Mount the workload directory and select the `data` workload:

```bash
docker run --rm --privileged \
  -v /path/to/my/workloads:/data \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf \
  -w data \
  -t 60
```

This runs the custom workload files available under `/data`.

### Important: Device and Runtime Parameters

When using custom workload files, the following behavior applies:

- If a custom fio workload contains a `filename` parameter, the device specified through `-d` is ignored for that workload.
- If a custom fio workload contains a `runtime` parameter, the duration specified through `-t` is ignored for that workload.

Therefore, if you want the command-line `device` and `time` parameters to control the test, remove the corresponding `filename` and `runtime` parameters from the custom fio workload files.

The predefined workloads supplied with `ab-fio` are designed to work with the tool's device and duration parameters.

## Output Format

Test results are printed to standard output in CSV format.

The output contains performance metrics and workload information, including:

| Column | Description |
|---|---|
| `testnum` | Test sequence number |
| `rw` | fio read/write workload type |
| `numjobs` | Number of fio jobs |
| `iodepth` | I/O queue depth |
| `bs` | Block size |
| `iops` | Input/output operations per second |
| `lat` | I/O latency |
| `bw` | Bandwidth |
| `testfile` | Workload file used for the test |
| `date` | Test execution timestamp |

Example:

```csv
testnum,rw,numjobs,iodepth,bs,iops,lat,bw,testfile,date
1,randread,1,1,4K,293,3406.30u,1172Ki,lat-r.fio,Wed Oct 14 12:07:32 UTC 2026
2,randwrite,1,1,4K,83,11.98m,334Ki,lat-w.fio,Wed Oct 14 12:09:36 UTC 2026
3,randread,1,64,4K,2874,22263.93u,11.2Mi,rnd-r.fio,Wed Oct 14 12:11:40 UTC 2026
4,randwrite,1,64,4K,870,73.54m,3481Ki,rnd-w.fio,Wed Oct 14 12:13:44 UTC 2026
```

The latency values use fio's unit suffixes:

- `u`: microseconds
- `m`: milliseconds

The output can be redirected to a file for further processing:

```bash
podman run --rm --privileged \
  docker.io/abolfazlmarj/ab-fio:v2.3.1 \
  -d /dev/sdf \
  --type hdd \
  --time 60 > results.csv
```

The resulting CSV file can be imported into tools such as Excel, LibreOffice Calc, or Python for analysis and visualization.

## Version

Current documented version: **v2.3.1**

## License

See the repository's license file for licensing information.
```
