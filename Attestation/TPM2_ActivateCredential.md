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
