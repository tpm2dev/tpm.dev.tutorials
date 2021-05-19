# `TPM2_Load()`

`TPM2_Load()` loads a saved key.

## Inputs

 - `TPMI_DH_OBJECT parentHandle`
 - `TPM2B_PRIVATE inPrivate`
 - `TPM2B_PUBLIC inPublic`

## Outputs (success case)

 - `TPM_HANDLE objectHandle`
 - `TPM2B_NAME name`

## References

 - [TCG TPM Library part 3: Commands, section 12.2.2](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)

