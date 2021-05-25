# `TPM2_CreatePrimary()`

This command creates a primary key object.

The created object can then be loaded with [`TPM2_Load()`](TPM2_Load.md).

To decide whether to use [`TPM2_CreateLoaded()`](TPM2_CreateLoaded.md),
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
[`TPM2_CreateLoaded()`](TPM2_CreateLoaded.md).

## Inputs

 - `TPMI_RH_HIERARCHY+ primaryHandle`
 - `TPM2B_TEMPLATE inPublic`
 - `TPM2B_DATA outsideInfo`
 - `TPML_PCR_SELECTION creationPCR`

## Outputs (success case)

 - `TPM_HANDLE objectHandle`
 - `TPM2B_CREATION_DATA creationData`
 - `TPM2B_DIGEST creationHash`
 - `TPMT_TK_CREATION creationTicket`
 - `TPM2B_NAME name`

## References

 - [TCG TPM Library part 3: Commands, section 24.1](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)
