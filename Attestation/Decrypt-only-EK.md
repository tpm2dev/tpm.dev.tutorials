# Endorsement Keys are (Generally) Decrypt-Only

All TPMs (2.0) must have decrypt-only Endorsement Keys (EKs).

Some TPMs may have signing-only EKs.  E.g., Google cloud vTPMs have
signing-only EKs as well as decrypt-only EKs.

Somehow one must make do with decrypt-only EKs to authenticate a TPM.
The obvious answer is to make the TPM prove possession of an EK by
sending a challenge encrypted to the EK's public key (EKpub).

This is what [`TPM2_MakeCredential()`](TPM2_MakeCredential.md) (encrypt)
and [`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) (decrypt)
are all about, except that they add some structure to the plaintext and
semantics to the decryption function.

See [README](README.md) for details of how
[`TPM2_MakeCredential()`](TPM2_MakeCredential.md) and
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) are used in
attestation protocols.
