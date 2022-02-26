# Quote

This example demonstrates the use of ESAPI.quote

The code will:

   * setup the ESAPI interface
   * send a TPM_STARTUP clear command
   * request a quote using the given attestation key, pcrs and extradata
   * unmarshal the returned data structures and print these as a python dict and convert to JSON and pretty print

## Setup and Variables

The following code might need to be modified for you local setup

```python3
tcti_to_use = None
attestation_key_handle = 0x810100AA
pcrs_to_quote = "sha256:0,1,2,3"
extradata_to_use = b"Ian12345"
```

## Running

To run type `python3 quote.py`

Errors might be generated as the pytss libraries search for a suitable TPM device. If everything is successful then a pretty printed JSON structure will be shown.

## Output

The following is example output:

```bash
~/tpm.dev.tutorials/PythonExamples$ python3 quote.py
att= <tpm2_pytss.types.TPMS_ATTEST object at 0x7f5fb10419d0>
ae= <class 'dict'> 
 {'attested': {'pcrDigest': '38723a2e5e8a17aa7950dc008209944e898f69a7bd10a23c839d341e935fd5ca', 'pcrSelect': [{'hash': 'sha256', 'pcrSelect': [0, 1, 2, 3]}]}, 'clockInfo': {'clock': 308418200, 'resetCount': 22, 'restartCount': 0, 'safe': 1}, 'extraData': '49616e3132333435', 'firmwareVersion': [538513443, 1455670], 'magic': 4283712327, 'qualifiedSigner': '000bff3ea118be81e7f10ead098c900b93c885785e828bf27d824a87add847b5ec56', 'type': 'attest_quote'}

 {
    "attested": {
        "pcrDigest": "38723a2e5e8a17aa7950dc008209944e898f69a7bd10a23c839d341e935fd5ca",
        "pcrSelect": [
            {
                "hash": "sha256",
                "pcrSelect": [
                    0,
                    1,
                    2,
                    3
                ]
            }
        ]
    },
    "clockInfo": {
        "clock": 308418200,
        "resetCount": 22,
        "restartCount": 0,
        "safe": 1
    },
    "extraData": "49616e3132333435",
    "firmwareVersion": [
        538513443,
        1455670
    ],
    "magic": 4283712327,
    "qualifiedSigner": "000bff3ea118be81e7f10ead098c900b93c885785e828bf27d824a87add847b5ec56",
    "type": "attest_quote"
}

```

The *magic number* of the quote is returned as an integer `4283712327` this corresponds to the better known TPM returned byte sequence `FF544347` in hex.