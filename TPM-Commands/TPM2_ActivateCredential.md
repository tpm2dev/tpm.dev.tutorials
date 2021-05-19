# `TPM2_ActivateCredential()`

`TPM2_ActivateCredential()` decrypts a ciphertext made by
[`TPM2_MakeCredential()`](TPM2_MakeCredential.md) and checks that the
caller has access to the object named by the caller of
[`TPM2_MakeCredential()`](TPM2_MakeCredential.md), and if so then
`TPM2_ActivateCredential()` outputs the small secret provided by the
caller of [`TPM2_MakeCredential()`](TPM2_MakeCredential.md),
otherwise `TPM2_ActivateCredential()` fails.

Together with [`TPM2_MakeCredential()`](TPM2_MakeCredential.md),
this function can be used to implement attestation protocols.

## Inputs

 - `TPMI_DH_OBJECT activateHandle` (e.g., handle for an AK)
 - `TPMI_DH_OBJECT keyHandle` (e.g., handle for an EK corresponding to the EKpub encrypted to by `TPM2_MakeCredential()`)
 - `TPM2B_ID_OBJECT credentialBlob` (output of `TPM2_MakeCredential()`)
 - `TPM2B_ENCRYPTED_SECRET secret` (output of `TPM2_MakeCredential()`)

## Outputs (success case)

 - `TPM2B_DIGEST certInfo` (not necessarily a digest, but a small [digest-sized] secret that was input to `TPM2_MakeCredential()`)

## References

 - [TCG TPM Library part 1: Architecture, section 24](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part1_Architecture_pub.pdf)
 - [TCG TPM Library part 2: Structures](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part2_Structures_pub.pdf)
 - [TCG TPM Library part 3: Commands, section 12](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)
 - [TCG TPM Library part 3: Commands Code, section 12](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_code_pub.pdf)

