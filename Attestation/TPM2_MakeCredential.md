# `TPM2_MakeCredential()`

`TPM2_MakeCredential()` takes an EKpub, the name of an object in a TPM
identified by that EKpub, and a small secret, and it encrypts `{name,
secret}` to the EKpub.

Nothing terribly interesting happens here.  All the interesting
semantics are on the
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) side.

Together with [`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md),
this function can be used to implement attestation protocols.
