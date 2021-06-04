# `TPM2_ActivateCredential()`

`TPM2_ActivateCredential()` is the flip side to
[`TPM2_MakeCredential()`](TPM2_MakeCredential.md), decrypting a small
ciphertext made by [`TPM2_MakeCredential()`](TPM2_MakeCredential.md).

The intersting things about `TPM2_ActivateCredential()` are that

 - the decryption key used may be a restricted key (which
   `TPM2_RSA_Decrypt()` would refuse to use)
 - and that `TPM2_ActivateCredential()` evaluates an authorization
   policy of the sender's choice.

Together with [`TPM2_MakeCredential()`](TPM2_MakeCredential.md) an
[`TPM2_Quote()`](TPM2_Quote.md) this function can be used to implement
attestation protocols.

Two of the input parameters of `TPM2_ActivateCredential()`, `keyHandle`
and `activateHandle`, correspond to the `handle` and `objectName` inputs
of [`TPM2_MakeCredential()`](TPM2_MakeCredential.md), respectively.  The
other inputs are [`TPM2_MakeCredential()`](TPM2_MakeCredential.md)'s
outputs.  The output, `certInfo` is
[`TPM2_MakeCredential()`](TPM2_MakeCredential.md)'s `credential` input.

## Authorization

`TPM2_ActivateCredential()` checks the authorization of the caller to
perform this operation by enforcing the `keyHandle`'s policy in the
`USER` role, and the `activateHandle`'s policy in the `ADMIN` role.  See
section 19.2 of [TCG TPM Library part 1:
Architecture](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part1_Architecture_pub.pdf).

What this means specifically depends on whether the `userWithAuth`
attribute is set on the `keyHandle` and whether the `adminWithPolicy`
attribute is set on the `activateHandle`.

In particular, if `adminWithPolicy` is set on the `activateHandle` then
the authorization session's `policyDigest` must match the
`activateHandle`'s policy _and_ the authorization session's
`commandCode` must be set to `TPM_CC_ActivateCredential`, which means
that the caller must have called `TPM2_PolicyCommandCode()` with
`TPM_CC_ActivateCredential` as the command code argument.

Some possible authorization policies to enforce include:

 - that some non-resettable PCR has not been extended since boot

   This allows the recipient to extend that PCR immediately after
   activating the credential to prevent the attestation protocol from
   being used again without rebooting.

 - user authentication / attended boot

   The policy could require physical presence, authentication of a user
   with biometrics and/or a smartcard and/or a password.

 - locality

## Inputs

 - `TPMI_DH_OBJECT keyHandle` (e.g., handle for an EK corresponding to the EKpub encrypted to by `TPM2_MakeCredential()`)
 - `TPMI_DH_OBJECT activateHandle` (e.g., handle for an AK)
 - `TPM2B_ID_OBJECT credentialBlob` (output of `TPM2_MakeCredential()`)
 - `TPM2B_ENCRYPTED_SECRET secret` (output of `TPM2_MakeCredential()`)

## Outputs (success case)

 - `TPM2B_DIGEST certInfo` (not necessarily a digest, but a small [digest-sized] secret that was input to `TPM2_MakeCredential()`)

## References

 - [TCG TPM Library part 1: Architecture, section 24](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part1_Architecture_pub.pdf)
 - [TCG TPM Library part 2: Structures](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part2_Structures_pub.pdf)
 - [TCG TPM Library part 3: Commands, section 12](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_pub.pdf)
 - [TCG TPM Library part 3: Commands Code, section 12](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part3_Commands_code_pub.pdf)

