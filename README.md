# app-slurm

Add-on slurm server (slurmctld) for JarviceXE apps. Using this add-on will configure and start slurmctld in the background of a running JarviceXE job. Slurm is configured to use [Power Saving](https://slurm.schedmd.com/power_save.html) mode to spawn and tear down worker nodes as needed. Each Slurm job will create one (1) additional JarviceXE job which is cleaned up by slurm at completion. The node pool providing resources for the JarviceXE jobs can utilize kubernetes autoscaling.

## Warning

JarviceXE applications that use this add-on will enable users to run arbitrary scripts and launch interactive shells from remote Slurm clients. This behavior may be undesirable for noninteractive applications. 

## Getting Started

To build a sample container:

```bash
git clone https://github.com/nimbix/app-slurm
docker build -t <container-tag-for-new-app> app-slurm/
```

To add on to existing container:

```bash
git clone https://github.com/nimbix/app-slurm
docker build -t <container-tag-for-new-app> --build-arg "BASE_IMAGE=<existing-container>" app-slurm/
```

### Prerequisites

#### Supported O/S

* CentOS 7
* Ubuntu Bionic 18.04+

#### JarviceXE Vault

All slurmd nodes can use the JarviceXE vault as shared storage mounted at `/data`. 

### Docker Build Arguments (--build-arg)

* BASE_IMAGE: container to use for add on; default `centos:7.5.1804`
* SLURM_VERSION: (CentOS only) Slurm version to install; default `19.05.5`
* COREDNS_VERSION: CoreDNS version to install; default `1.8.3`
* SLURM_WORKDIR: location of ‘app-slurm’ repository; default `.` (current working directory)

### Nimbix Desktop enabled containers

Install add on to Nimbix Desktop enabled containers by building with `Dockerfile.gui`.

```bash
git clone https://github.com/nimbix/app-slurm
docker build -f Dockerfile.gui -t <container-tag-for-new-app> --build-arg "BASE_IMAGE=<existing-container>" app-slurm/
```

The above command will create a CentOS application that opens a xclock window.

#### Application customization

Update `scripts/slurm.sh` and `NAE/AppDef.json.gui` to match the requirements of the `BASE_IMAGE` container.

##### slurm.sh

Replace `/usr/bin/xclock` with your application binary or script. Arguments passed in by `AppDef.json` can be accessed with `$@` 

For example: 

```bash
# start ample application scripts w/ AppDef args
exec /usr/bin/my-app "$@"
```

#### AppDef.json.gui

Update the `xclock` command for your application.

**NOTE** The `APIKEY`, `APIURL`, `APIUSER`, and `JARVICE_VAULT_NAME` AppDef parameters are required for the slurm add-on to operate correctly

## Known Issues

* Slurm version must be the same between slurmctld and worker nodes (slurmd).
* All slurm nodes must be in the same JARVICE downstream cluster.
* Docker build may use cache layer when changing BASE_IMAGE build argument. Use `--no-cache` flag to force a rebuild.

## Authors

* **Kenneth Hill** - *Initial work* - ken.hill@nimbix.net

## License

This project is licensed under the BSD-2-Clause-Views - see the [LICENSE.md](LICENSE.md) file for details

