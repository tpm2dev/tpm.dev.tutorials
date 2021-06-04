# `TPM2_MakeCredential()`

`TPM2_MakeCredential()` and
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) provide a
mechanism by which an application can send secrets to a TPM-using
application.  This mechanism is asymmetric encryption/decryption with
support for an authorization policy of the sender's choice.

`TPM2_MakeCredential()` takes an a public key (typically the endorsement
key's public key), the [cryptographic name of an
object](/Intro/README.md#Cryptographic-Object-Naming) in a TPM
identified by that the given public key, and a small secret called a
`credential`, and it encrypts `{name, credential}` to the given public
key.

The object name input parameter, being a name, binds an optional
authorization policy that
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) will enforce.

`TPM2_MakeCredential()` can be implemented entirely in software, as it
uses no secret, TPM-resident key material.  All the interesting
semantics are on the
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) side.

Together with [`TPM2_Quote()`](TPM2_Quote.md) and
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md), this function
can be used to implement attestation protocols.

A typical use is to encrypt an AES key to an `EKpub`, then encrypt a
large secret payload in the AES key, then sending the outputs of
`TPM2_MakeCredential()` and the encrypted large secret payload.  The
peer receives these items and calls
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) to recover the
AES key, then decrypts the large ciphertext payload to recover the large
cleartext secret.

> NOTE: The `objectName` input names a key object that must present on
> the destination TPM, and the `objectName` is included in the plaintext
> that is encrypted to the public key identified by `handle`, _but_ none
> of the key material of `objectName` is used to key any cryptographic
> operations in `TPM2_MakeCredential()`, and therefore neither is the
> private area of `objectName` on the destination TPM used in any
> cryptographic operations in
> [`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md).
>
> This means that the key named by `objectName` can even be a
> universally-well-known key.  The only part of that key that truly
> matters is the policy digest named in the public area of `objectName`.

## Authorization

[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) checks the
authorization of the caller to perform this operation by enforcing the
sender's policy named by the sender's `objectName`.  See
[here](TPM2_ActivateCredential.md) for details.

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

 - `TPMI_DH_OBJECT handle` (public key to encrypt to, typically a remote TPM's EKpub)
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

