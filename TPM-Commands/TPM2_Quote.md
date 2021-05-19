# `TPM2_Quote()`

`TPM2_Quote()` computes a hash of the PCRs selected by the caller, and
signs that hash, some additional metadata, and any extra data provided
by the caller, with a signing key named by the caller.  The caller must
have access to that key, naturally.

The PCRs' values are NOT included in the quote produced by
`TPM2_Quote()`.  Instead, an attestation service can review an unsigned
eventlog to ensure it leads to the same values as unsigned PCR values
also provided by the attestation client, and then the attestation
service can verify that the hash of the PCR values is indeed signed by
the quote supplied by the client.

## Inputs

 - `TPMI_DH_OBJECT sigHandle` (handle for an AK)
 - `TPM2B_DATA qualifyingData` (extra data)
 - `TPMT_SIG_SCHEME inScheme` ("signing scheme to use if the schemefor signHandleis `TPM_ALG_NULL`")
 - `TPML_PCR_SELECTION PCRselect` (set of PCRs to quote)

## Outputs (success case)

 - `TPM2B_ATTEST quoted`
 - `TPMT_SIGNATURE signature`

Where `TPM2B_ATTEST` is basically a `TPMS_ATTEST`, which contains the
following fields:

 - `TPM_GENERATED magic`
 - `TPMI_ST_ATTEST type`
 - `TPM2B_NAME signer` (name of AK)
 - `TPM2B_DATA extraData` ("external information supplied by caller")
 - `TPMS_CLOCK_INFO clockInfo` ("Clock, resetCount, restartCount, and Safe")
 - `UINT64 firmwareVersion`
 - `TPMU_ATTEST attested`, a discriminated union with the
   `TPMS_QUOTE_INFO` arm (indicated by the `TPM_ST_ATTEST_QUOTE`
   discriminant value), which contains:
    - `TPML_PCR_SELECTION pcrSelect` (the set of PCRs digested by `pcrDigest`)
    - `TPM2B_DIGEST pcrDigest` (the digest of the PCRs indicated by `pcrSelect`)

## References

 - [TCG TPM Library part 3: Commands, section 18.4](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)

