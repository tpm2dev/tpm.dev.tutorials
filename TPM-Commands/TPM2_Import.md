# `TPM2_Import()`

`TPM2_Import()` reads a wrapped key produced by
[`TPM2_Duplicate()`](TPM2_Duplicate.md) and outputs a blob that can be
saved and later loaded with [`TPM2_Load()`](TPM2_Load.md).

## Inputs

 - `TPM2B_DATA encryptionKey` (optional; symmetric key to decrypt with)
 - `TPM2B_PUBLIC objectPublic`
 - `TPM2B_PRIVATE duplicate`
 - `TPM2B_ENCRYPTED_SECRET inSymSeed`
 - `TPMT_SYM_DEF_OBJECT+ symmetricAlg`

## Outputs (success case)

 - `TPM2B_PRIVATE outPrivate`

## References

 - [TCG TPM Library part 3: Commands, section 13.3](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)

