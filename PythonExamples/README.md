# Python Examples with PYTSS

Now that tpm2_pytss is stable I've started collecting worked examples for some common situations, eg: reading PCRs, quotes etc.

tpm_pytss is here: https://github.com/tpm2-software/tpm2-pytss

## Running the examples

First you will need a TPM, either a real TPM or the IBM SW TPM is a good substitute.

Each example can be run just by typing `python3 example.py`

## Available Examples

Each example has an accompanying description as markdown file, plus annotated code.

<<<<<<< HEAD
   * [quote](quote.md)
=======
   * [randomnumber]
   * [quote]

## Notes on TCTI Errors

When an `ESAPI` object is created it will print out errors as it searches for a suitable TPM devices. For example:

```bash
~/tpm.dev.tutorials/PythonExamples$ python3 randomnumber.py 
ERROR:tcti:src/tss2-tcti/tcti-device.c:442:Tss2_Tcti_Device_Init() Failed to open specified TCTI device file /dev/tpmrm0: No such file or directory 
ERROR:tcti:src/tss2-tcti/tctildr-dl.c:154:tcti_from_file() Could not initialize TCTI file: libtss2-tcti-device.so.0 
ERROR:tcti:src/tss2-tcti/tcti-device.c:442:Tss2_Tcti_Device_Init() Failed to open specified TCTI device file /dev/tpm0: No such file or directory 
ERROR:tcti:src/tss2-tcti/tctildr-dl.c:154:tcti_from_file() Could not initialize TCTI file: libtss2-tcti-device.so.0 
ERROR:tcti:src/tss2-tcti/tcti-swtpm.c:222:tcti_control_command() Control command failed with error: 1 
ERROR:tcti:src/tss2-tcti/tcti-swtpm.c:330:tcti_swtpm_set_locality() Failed to set locality: 0xa000a 
WARNING:tcti:src/tss2-tcti/tcti-swtpm.c:599:Tss2_Tcti_Swtpm_Init() Could not set locality via control channel: 0xa000a 
ERROR:tcti:src/tss2-tcti/tctildr-dl.c:154:tcti_from_file() Could not initialize TCTI file: libtss2-tcti-swtpm.so.0 
type is  <class 'tpm2_pytss.types.TPM2B_DIGEST'>
r    is  a10ab7558675a56c
as hex   11604288967829464428
```
>>>>>>> a53da59 (added random numbers and updated text)
