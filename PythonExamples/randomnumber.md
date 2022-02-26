# Quote

This example demonstrates the use of ESAPI.get_random

The code will:

   * setup the ESAPI interface
   * send a TPM_STARTUP clear command
   * request 8 random numbers from the TPM
   * print out the result

## Setup and Variables

No specific setup is required. You may wish to change the number of bytes returned in the `get_random` call. 

## Running

To run type `python3 quote.py`

Errors might be generated as the pytss libraries search for a suitable TPM device. If everything is successful then a random number will be shown.

## Output

```bash
~/tpm.dev.tutorials/PythonExamples$ python3 randomnumber.py 
type is  <class 'tpm2_pytss.types.TPM2B_DIGEST'>
r    is  a10ab7558675a56c
as int   11604288967829464428

```