# `TPM2_Certify()`

`TPM2_Certify()` signs an assertion that some named object is loaded in
the TPM.

## Inputs

 - `TPMI_DH_OBJECT objectHandle` (object to be certified)
 - `TPMI_DH_OBJECT signHandle` (handle for a signing key)
 - `TPM2B_DATA qualifyingData` (extra data)
 - `TPMT_SIG_SCHEME inScheme` ("signing scheme to use if the schemefor signHandleis `TPM_ALG_NULL`")

## Outputs (success case)

 - `TPM2B_ATTEST certifyInfo` (what was signed)
 - `TPMT_SIGNATURE signature` (signature)

## References

 - [TCG TPM Library part 3: Commands, section 18.2](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)

