# app-slurm

Add on slurm server (slurmctld) for JarviceXE apps. Using this add on will configure and start slurmctld in the background of a running JarviceXE job. Slurm is configured to use Power Saving mode to spawn and tear down worker nodes as needed. Each Slurm job will create one (1) additional JarviceXE job which is cleaned up at job termination. The node pool providing resources for the JarviceXE jobs can utilize kubernetes autoscaling.

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

####Supported O/S

* CentOS 7+
* Ubuntu Bionic 18.04+

####JarviceXE Vault

The same vault must be accessible to all jobs. Ephemeral vaults are not supported

### Docker Build Arguments

* BASE_IMAGE: container to use for add on; default centos:7.5.1804
* SLURM_VERSION: (CentOS only) Slurm version to install; default 19.05.5
* COREDNS_VERSION: CoreDNS version to install; default 1.8.3
* SLURM_WORKDIR: location of ‘app-slurm’ repository; default . (current working directory)

## Known Issues

* Slurm version must be the same between slurmctld and worker nodes (slurmd)
* A temporary working directory is created in a user’s vault (i.e. /data/tmp.XXXX) to store Slurm configuration files which are removed when the main JarviceXE job exits. This cleanup is a best effort and fails when a job is terminated outside of JARVICE Shutdown/Terminate requests.

## Authors

* **Kenneth Hill** - *Initial work* - ken.hill@nimbix.net

## License

This project is licensed under the BSD-2-Clause-Views - see the [LICENSE.md](LICENSE.md) file for details

