# `TPM2_CreateLoaded()`

This command creates a key object and loads it.  The object can be a
primary key, in which case `TPM2_CreateLoaded()` behaves just like
[`TPM2_CreatePrimary()`](TPM2_CreatePrimary.md).  Or the object can be
`ordinary` or `derived`.

The created object can then be loaded with [`TPM2_Load()`](TPM2_Load.md).

To decide whether to use `TPM2_CreateLoaded()`,
[`TPM2_Create()`](TPM2_Create.md), or
[`TPM2_CreatePrimary()`](TPM2_CreatePrimary.md) refer to table 28 in
section 2.7 of the [TCG TPM Library part 1:
Architecture](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part1_Architecture_pub.pdf).

If you need to `TPM2_CertifyCreation()` that a TPM created some object,
you must use [`TPM2_CreatePrimary()`](TPM2_CreatePrimary.md) or
[`TPM2_Create()`](TPM2_Create.md).

If you need to seal the object to a PCR selection, you must use
[`TPM2_CreatePrimary()`](TPM2_CreatePrimary.md) or
[`TPM2_Create()`](TPM2_Create.md).

If you need to create a derived object, you must use
`TPM2_CreateLoaded()`.

## Inputs

 - `TPMI_DH_PARENT+ parentHandle`
 - `TPM2B_SENSITIVE_CREATE inSensitive`
 - `TPM2B_TEMPLATE inPublic`

## Outputs (success case)

 - `TPM_HANDLE objectHandle`
 - `TPM2B_PRIVATE outPrivate` (optional)
 - `TPM2B_PUBLIC outPublic`
 - `TPM2B_NAME name`

## References

 - [TCG TPM Library part 3: Commands, section 12.9](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)

