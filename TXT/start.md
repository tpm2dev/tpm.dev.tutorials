# Tboot and TXT Installation

This guide gives an overview of how to install tboot for DRTM - dynamic root of trust measurement.

- [Tboot and TXT Installation](#tboot-and-txt-installation)
  * [Installation](#installation)
    + [Step 1 - Preliminaries](#step-1---preliminaries)
    + [Step 2 - Compiling tboot](#step-2---compiling-tboot)
    + [Step 3 - Grub](#step-3---grub)
    + [Step 4 - ACM](#step-4---acm)
    + [Step 5 - Reboot](#step-5---reboot)
    + [Step 6 - Testing](#step-6---testing)
  * [Getting Help](#getting-help)
  * [Tools](#tools)
    + [txt-stat](#txt-stat)
    + [txt-parse_err](#txt-parse-err)
    + [txt-acminfo](#txt-acminfo)
  * [TPM Operations](#tpm-operations)
    + [PCR Read](#pcr-read)
    + [Quoting](#quoting)
    + [Sealing](#sealing)
  * [Things Not Described](#things-not-described)
  * [Anecdotes](#anecdotes)

## Installation

WARNING this involves some changes to your boot sequence which may cause your system not to boot - or worse. Undertaking of the procedure here is at your own risk. Do not try this on a machine with valuable processes, services or data, and especially NOT on a running production machine (no names).

This guide was tested on a Lenovo X1 Carbon 5th Generation laptop running Ubuntu 20.04. It should work in many other environments with little or no modification.

### Step 1 - Preliminaries

We assume the following are available:

   * The TPM 2.0 device is enabled in the BIOS and visible as /dev/tpm0
   * TXT is supported by your CPU and has been enabled in the BIOS
   * You have root/sudo access and sufficient familiarity with Linux/Unix
   * A compilation environment is available, eg: gcc, make etc.

### Step 2 - Compiling tboot

Firstly we need to download tboot from here https://sourceforge.net/projects/tboot/ - this can be made to any directory. You should obtain a zip file for the latest release which as of writing is *1.10.2*

```bash
gunzip tboot-1.10.2.tar.zip
tar xvf tboot-1.10.2.tar
cd tboot-1.10.2
```

Please take time to read README.md and the documentation in the `docs` directory. To compile do the following, also ensuring you have all the necessary dependencies

```bash
sudo apt install build-essential mercurial libz-dev libssl-dev
make
```

After compilation you can check the following directories:

```bash
$ ls tboot
20_linux_tboot  20_linux_xen_tboot  common  Config.mk  include  Makefile  tboot  tboot.gz  tboot.strip  tboot-syms  txt
$ ls utils
Makefile  txt-acminfo  txt-acminfo.c  txt-acminfo.o  txt-parse_err  txt-parse_err.c  txt-parse_err.o  txt-stat  txt-stat.c  txt-stat.o
```

The important files are tboot.gz and txt-stat - these are the tboot executable itself and a utility for examining the logs generated. There are other files, 20_linux_tboot is a grub configuraton file, plus there are other utilities.

If all has been successful:

```bash
sudo make install
```

This will install tboot.gz into /boot and the grub files to /etc/grub.d. A symbol table tboot-syms will also be copied to boot, you don't need to worry about this.


### Step 3 - Grub
To get tboot to run it is necessary to get grub to call tboot. Fortunately the developers of tboot have made this process painless. However a word of caution: make sure you backup your grub configuration file so that you have a working version if all goes wrong:

```bash
sudo /boot/grub/grub.cfg /boot/grub/grub.cfg.working
```

Before generating the grub configuration files we should also modify the grub timeout which is found in the file `/etc/default/grub`. Edit this file (sudo required) and find the line `GRUB_TIMEOUT` and set this to something sensible like `GRUB_TIMEOUT=20`.

I also like to comment out any splash screen and quiet operation - mainly because I like seeing the boot sequence but also because the manufacturer logos hide the grub menu which we'll need to get to later. 

Please refer to the grub documentation for more information here.


Now generating the grub configuration:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg 
```

My Ubuntu distribution ships grub-mkconfig, which should be the same as grub2-mkconfig in other distributions. Both should work without issues, but if there is a problem here's a page that describes what is going on: https://linuxhint.com/grub2_mkconfig_tutorial/


### Step 4 - ACM
Tboot requires an Accredited Code Module from Intel. Not all CPUs support TXT - most i5 an i7s do and as far as I have seen Xeons have the ACM already onboard the CPU itself.

The ACMs are available from here: https://software.intel.com/content/www/us/en/develop/articles/intel-trusted-execution-technology.html

You need to find your CPU type, mine is a 7th generation i7 and from there the correct ACM to download, again in my case this is: 6th_7th_gen_i5_i7-SINIT_79.zip .   You can find your CPU type by running `cat /proc/cpuinfo`.

Unzip this and you'll get a file 6th_7th_gen_i5_i7-SINIT_79.bin  (this is what is on mine!). This file should be copied to /boot

```bash
unzip 6th_7th_gen_i5_i7-SINIT_79.zip
sudo cp 6th_7th_gen_i5_i7-SINIT_79.bin /boot
```



### Step 5 - Reboot
As stated earlier what we're looking for here is the boot sequence going to the grub menu rather than any splash screen. On my laptop hitting Escape during the splash screen shows me the grub menu. You need to search for the tboot menu entry and select this.

You should then see a lot of log information from grub and tboot, and eventually Linux will start. At this point you can log in.


### Step 6 - Testing
Remember the commands in tboot's utils directory we compiled back in step 2? We need those now.  

To check if the trusted boot has worked run:

```bash
sudo ./txt-stat
```

and you'll get a huge amount of information. The easiest way to check is to run the following:

```bash
$ sudo ./txt-stat | grep "TXT measured launch"
         TXT measured launch: TRUE
```

If the line above reads TRUE then all has worked and a DRTM has been performed successfully. There is another tool `txt-parse_err` which can be used if things have not worked out; as I've never been in this situation then I have no idea what it produces, but there is a description a bit later.

Because the ACM writes values to the TPM you can use tools to read these and we describe this a bit later.

## Getting Help
Tboot has a discussion page that you should see. Also tpm.dev has some very knowledgeable people who can help.

## Tools
A brief description of the tools

### txt-stat
This tool shows the TXT log and status. From this log you can see what values were written to the TPM PCR and detailed information about the process.

```bash
sudo ./txt-stat
```

The quick way of finding out if things have worked has been described earlier: `sudo ./txt-stat | grep "TXT measured launch"` which should report TRUE.


This tool needs access to `/dev/mem` which provides access to the physical memory hence the requirement for sudo - it is probably a bad idea to play with permissions here. Read this for more information: https://man7.org/linux/man-pages/man4/mem.4.html



### txt-parse_err
I have no idea... this is what I get

```bash
$ sudo ./txt-parse_err 
ERRORCODE: 0x00000000
no error
```

which I assume means all was successful



### txt-acminfo
If you want to expore what is inside the ACM you downloaded from Intel this command provides this information. Just give it the location of your ACM.

```bash
./txt-acminfo /boot/6th_7th_gen_i5_i7-SINIT_79.bin
```

One interesting piece of information is the signature which contains the RSA public key used to sign the ACM. I assume that you can verify this against what Intel has and if someone knows how to do this please let me know or even better, write it up here!


## TPM Operations
As noted the ACM writes to the TPM, specifically to PCRs 17 and 18 in the SHA1 and SHA256 banks. Knowing this allows all kinds of interesting things to be done:

### PCR Read

```bash
$ tpm2_pcrread  sha256:17,18
sha256:
  17: 0x025238F270168234D2D90B312C5EF0E771A76FEC48A704196E2E51D1B51A3C17
  18: 0x473698EB00F05501CF8F08C6C54BD2105D6F17036C6DA00E44A4288B17FC3282
```

If these value in 17 changes then your kernel has changed. PCR 18 is a hash of the TXT log.

IIRC there are utilities to calculate both of these values from the output of txt-stat. If you find them let me know please.

### Quoting

A better idea would be to collect a quote from the TPM for use in your attestation environment you can do this like so. NB: I assume you have a suitable attestation key loaded somewhere - mine is at 0x810100AA in this case. The final echo statement should return 0 for successful signature validation:

```bash
tpm2_quote -c 0x810100AA -l sha256:18 -m quote.msg -s quote.sig -g sha256 -q 123456 -o pcrs.out
tpm2_print -t TPMS_ATTEST quote.msg
tpm2_verifysignature -c 0x810100AA -g sha256 -s quote.sig -m quote.msg
echo $?
```

Refer to a tutorial on quoting, eg: https://github.com/nokia/TPMCourse/blob/master/docs/quoting.md

Here is a full worked example:

```bash
/tmp$ tpm2_quote -c 0x810100AA -l sha256:18 -m quote.msg -s quote.sig -g sha256 -q 123456 -o pcrs.out
quoted: ff54434780180022000be235c450700dc31d3526e4f94dcf816fe5aac91b22563ffc7bbb831d9d685f62000312345600000000556646320000001200000001010047000c44a0100400000001000b0300000400200d1ce194d7dab9ac2a9ae182f31b865123df22459b90e398ec4537388000af98
signature:
  alg: rsassa
  sig: 9788d6996cd569ba32c6cd63effedc405dc32762e12fbaf041a7df81902f88f372b1c62ef8cbd3b8840c7432e49a76d71f8e2716ddeb08147f2d4d78a1f566c83a94beb45d2bb7eb16de64c814e8c1b737dd69724e372606f83b91a3a666e4b64ca1c802d0c620cded4668ee1a765cab18422eeccf10fa001c42422c5aa251221f69f1c1b1eb19ac6bf6bd155c42d1a4a77c29a9a29eef090ff8266703f6dd1062c9d1f276ece45ca1c2f3db6662f036263441f99d1a8ddf1f70c584fa76f9ad365fa3c1ec7f627e233ee73b1ac7c99b3d5dec975c543e1995c6ae21434ea7166910edf4c9f6cf0dd0b1516a86321e6ed38dea84c56f9f3e238021533b8ff37f
pcrs:
  sha256:
    18: 0x473698EB00F05501CF8F08C6C54BD2105D6F17036C6DA00E44A4288B17FC3282
calcDigest: 0d1ce194d7dab9ac2a9ae182f31b865123df22459b90e398ec4537388000af98
/tmp$ tpm2_print -t TPMS_ATTEST quote.msg
magic: ff544347
type: 8018
qualifiedSigner: 000be235c450700dc31d3526e4f94dcf816fe5aac91b22563ffc7bbb831d9d685f62
extraData: 123456
clockInfo:
  clock: 1432766002
  resetCount: 18
  restartCount: 1
  safe: 1
firmwareVersion: 0410a0440c004700
attested:
  quote:
    pcrSelect:
      count: 1
      pcrSelections:
        0:
          hash: 11 (sha256)
          sizeofSelect: 3
          pcrSelect: 000004
    pcrDigest: 0d1ce194d7dab9ac2a9ae182f31b865123df22459b90e398ec4537388000af98
/tmp$ tpm2_verifysignature -c 0x810100AA -g sha256 -s quote.sig -m quote.msg
/tmp$ echo $?
```

### Sealing
You can use PCR17's value to seal data, eg: keys, in the TPM's NVRAM. If PCR17 changes then that area of NVRAM will no longer be accessable. Refer to https://github.com/nokia/TPMCourse/blob/master/docs/nvram.md#sealing for more information about this process.

These commands will create a policy based on the current value of PCR 17, create an NVRAM area that can only be read or written to against that policy. We write in some secrets to that NVRAM area (providing the policy) and then read the area using the current value of PCR 17 and the policy revealing the secret.

```bash
tpm2_pcrread -o drtm.pcrvalues sha256:17
tpm2_createpolicy --policy-pcr -l sha256:17 -f drtm.pcrvalues -L drtm.policy
tpm2_nvdefine 0x1500019 -C o -s 32 -L drtm.policy -a "policyread|policywrite"
echo "my password" > secretFile
tpm2_nvwrite 0x1500019 -C 0x1500019 -P pcr:sha256:17=drtm.pcrvalues -i secretFile
tpm2_nvread 0x1500019 -C 0x1500019 -P pcr:sha256:17=drtm.pcrvalues 
```

As NVRAM is persistent you can now try an upgrade of your system, eg: a new kernel, rebooting and then trying to read that NVRAM area just with the command

```bash
tpm2_nvread 0x1500019 -C 0x1500019 -P pcr:sha256:17=drtm.pcrvalues 
```

In order to reveal the secret you need to revert back to the kernel that generates the correct hash otherwise the data is sealed forever. A really good way of protecting secrets.


## Things Not Described
You can do some very clever things with keys and data stored in the TPM NVRAM. Tboot actually tries to obtain manufacturer certificates from some standard locations onboard the TPM. I have not played with this, but there are some significant security benefits to be gained.

Also a very good chance of breaking your boot sequence too....but this is what you want in this case :)


## Summary Install Sequence
The above scripts without the text - you might need to change the name of the ACM. Tboot and ACM assumed to be placed in the same directory, eg: `/tmp/tbootinstall` might be a good place.

Installation:

```bash
gunzip tboot-1.10.2.tar.zip
tar xvf tboot-1.10.2.tar
cd tboot-1.10.2
make
sudo make install
sudo /boot/grub/grub.cfg /boot/grub/grub.cfg.working
sudo grub-mkconfig -o /boot/grub/grub.cfg 
unzip 6th_7th_gen_i5_i7-SINIT_79.zip
sudo cp 6th_7th_gen_i5_i7-SINIT_79.bin /boot
```

Post-Boot Check

```bash
tpm2_pcrread  sha256:17,18
sudo ./txt-stat | grep "TXT measured launch"
sudo ./txt-parse_err 

```


## Anecdotes
A friend of mine spent a couple of days trying to figure out why a top of the range PC would not perform the DRTM correctly using tboot. Tboot returned lots of odd errors and PCRs 17 and 18 were empty. TPM and TXT *were* enabled in BIOS so that wasn't the problem.

Until we discovered that this "top of the range" PC wasn't exactly "top of the range"... it has an i3 CPU and not an i7 CPU... Why was TXT an option in the BIOS...no idea....why didn't we notice it was an i3...no idea.

The moral here is always check beforehand


The other story involved a lot of very expensive servers in a very cold machine room. After many many many many reboots and much debugging we discovered that the BIOS on those machines was broken beyond all definitions of broken. It turns out that enabling TPM disabled TXT and vice versa....don't ask. After coffee I believe we planned to hunt down the writers of that particular BIOS and perform unspeakable acts, like making then use Windows ME forever....Geneva Convention notwithstanding.