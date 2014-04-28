# Raspberry Pi Linux Kernel Build and Development Tools

Repository of tools - scripts and the like - to aid in building, installing and developing for the Raspberry Pi Linux kernel.

The Raspberry Pi kernel, firmware and build tools can be found in the [Raspberry Pi Github account](https://github.com/raspberrypi).

Currently the tools include shell scripts to:
  - Cross build the kernel on a machine other than a Raspberry Pi.
  - Stage and transfer the requisite files from the cross-build machine to a Raspberry Pi.
  - On the running target Raspberry Pi install the new kernel, module and firmware files, backing up the existing files.

The first two are run on the cross-build machine, located in the **cross-build** directory, and the last on the target Raspberry Pi, located in the **rpi-target** directory.

The process sequences were obtained from the [RPi Kernel Compilation](http://elinux.org/RPi_Kernel_Compilation) article on eLinux.
