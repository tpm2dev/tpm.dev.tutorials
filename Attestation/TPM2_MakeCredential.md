# `TPM2_MakeCredential()`

`TPM2_MakeCredential()` takes an EKpub, the name of an object in a TPM
identified by that EKpub, and a small secret, and it encrypts `{name,
secret}` to the EKpub.

Nothing terribly interesting happens here.  All the interesting
semantics are on the
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) side.

Together with [`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md),
this function can be used to implement attestation protocols.

## Inputs

 - `TPMI_DH_OBJECT handle` (e.g., an EKpub to encrypt to)
 - `TPM2B_DIGEST credential` (not necessarily a digest, but a small [digest-sized] secret)
 - `TPM2B_NAME objectName` (name of object resident on the same TPM as `handle` that `TPM2_ActivateCredential()` will check)

## Outputs

 - `TPM2B_ID_OBJECT credentialBlob` (ciphertext of encryption of `credential` with a secret "seed" [see below])
 - `TPM2B_ENCRYPTED_SECRET secret` (ciphertext of encryption of a "seed" to `handle`)

## References

 - [TCG TPM Library part 1: Architecture, section 24](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part1_Architecture_pub.pdf)
 - [TCG TPM Library part 2: Structures](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part2_Structures_pub.pdf)
 - [TCG TPM Library part 3: Commands, section 13](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)
 - [TCG TPM Library part 3: Commands Code, section 13](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_code_pub.pdf)

