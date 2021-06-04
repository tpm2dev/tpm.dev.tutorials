# `TPM2_Duplicate()`

`TPM2_Duplicate()` wraps a key, typically encrypting it to a public key
for a key on a remote TPM.

I.e., this is used to export a wrapped key for some target, typically a
remote TPM.

## Inputs

 - `TPMI_DH_OBJECT objectHandle` (handle for key to encrypt with)
 - `TPMI_DH_OBJECT newParentHandle` (optional; handle for key to wrap to -- "Only the  public  area  of newParentHandle is required to be loaded")
 - `TPM2B_DATA encryptionKeyIn` (optional; symmetric key to encrypt with)
 - `TPMT_SYM_DEF_OBJECT+ symmetricAlg` ("definition for the symmetric algorithm to be used for the inner wrapper")

## Outputs (success case)

 - `TPM2B_DATA encryptionKeyOut`
 - `TPM2B_PRIVATE duplicate`
 - `TPM2B_ENCRYPTED_SECRET outSymSeed`

## References

 - [TCG TPM Library part 3: Commands, section 18.4](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)

