# TPM 2.0 PQC Status as of June 2026

Last change: 3.August.2026

## Where things stand today ("Too Long Didn't Read")

1. No discrete hardware TPM ships with PQC capabilities yet. See table with [PQC status](#pqc-status-of-known-tpm-20-solutions).

    ```TPM developers and system integrators have no PQC-capable discrete silicon to build against today.```

2. The v1.85 spec defining PQC capabilities is final. See [table with new commands](#new-tpm-commands).

    Many new TPM commands are added, some deprecated and detailed table is available below.

3. What is available today:

    Infineon's current generation SLB 9672 / SLB 9673 has PQC protection over *the TPM update channel*: XMSS signatures mean a firmware push to the chip cannot be corrupted by a quantum attacker. That is sound engineering. But the PQC boundary stops at the chip itself. Your application, your attestation flow, your key exchange still run on classical algorithms. Similar is the situation with STMicroelectronics ST33K discrete TPM 2.0 solution.

The nearest point on the horizon **based on public information** is SEALSQ, with  [engineering samples targeted for Q3 2026](https://www.sealsq.com/investors/news-releases/sealsq-announces-comprehensive-2026-certification-roadmap-for-qs7001-secure-element-and-qvault-tpm-product-lines).

wolfSSL's firmware TPM is available now for teams that need to develop and test against the v1.85 API before production silicon arrives. wolfTPM is licensed under GPLv2 so it can be used for devleopment but shipping firmware TPM into products requires a commercial license from [wolfSSL](https://www.wolfssl.com/announcing-wolftpm-firmware-tpm-ftpm-support/).

Note: TPM 2.0 alternatives that do not follow TCG standards: Microchip's MEC175xB embedded controller provides immutable hardware support with PQC algorithms including ML-DSA, ML-KEM, and LMS. It is not a TCG-compliant discrete TPM and it does not implement the TPM 2.0 commands.

## PQC status of known TPM 2.0 solutions

### New Generation PQC TPM

| Vendor / Product | TCG spec | PQC in TPM ops | PQC FW updates | Status | Notes |
|---|---|---|---|---|---|
| SEALSQ QVault TPM | v1.85 | Yes | Yes | 🚀 Samples | Supports ML-DSA-87 and ML-KEM-1024 for TPM operations.  |
| STMicro ST33KTPMXQ | v1.85 | Yes | Yes | Upcomming | Pin-to-pin compatible with previous ST33K. |
| Nuvoton NPCT8xx | v1.85 | Yes | Yes | Upcomming | Pin-to-pin compatible with NPCT76x/NPCT75x. |
| Infineon OPTIGA TPM with PQC | v1.85 | Yes | Yes | Upcomming | Pin-to-pin compatible with SLB 9672/9673. |
| wolfTPM firmware TPM | v1.85 | Yes | Not Applicable | ✅ Available | Firmware TPM, not discrete silicon. Built on wolfCrypt FIPS. |

### Current Generation TPM 2.0

`PQC protects the update channel, not TPM operations.`

| Vendor / Product | TCG spec | PQC in TPM ops | PQC FW updates | Status |
|---|---|---|---|---|
| Infineon Optiga SLB 9672 | v1.59 | No | Yes — XMSS | Available |
| Infineon Optiga SLB 9673 | v1.59 | No | Yes — XMSS | Available |
| STMicroelectronics ST33K | v1.59 | No | Yes — LMS | Available |
| Nuvoton NPCT 76x/75x | v1.59 | No | No | Available |

Note: firmware update algorithm choice: Infineon uses XMSS, ST uses LMS. Both are stateful hash-based signatures standardized under SP800-208. Different parameter choices, same security concept.

### Pin-to-pin compatiblity for PQC TPM now confirmed

| Vendor | PQC TPM | Pin-to-pin | Current gen TPM 2.0 |
|---|---|---|---|
| STMicro |ST33KTPMXQ | Yes | ST33KTPM |
| Nuvoton | NPCT8xx | Yes | NPCT76x/NPCT75x |
| Infineon | OPTIGA TPM with PQC | Yes | SLB 9672/9673 |
| SEALSQ | QVault TPM with PQC | Not applicable  | No prior versions |

## New algorithms in v1.85

v185 introduces six algorithms. Three post-quantum: ML-KEM, ML-DAS and HashML-DSA. Three classical: dDSA, HashEdDSA and DHKEM. They share command infrastructure and that is by design.

The classic TPM signing model is: hash externally, hand the digest to `TPM2_Sign`, get a signature back. ML-DSA breaks that model. It signs full messages — the algorithm requires the full message to be present during signing, not a pre-computed hash. To accommodate it, the spec introduced a sequence-based command model: open a context, stream the message through the TPM, close and get a signature. Once that infrastructure existed, EdDSA and its pre-hashed variant HashEdDSA plugged into the same commands at no additional cost. The same logic applies to key encapsulation: `TPM2_Encapsulate` and `TPM2_Decapsulate` serve ML-KEM, but DHKEM — the ECDH-based KEM from RFC 9180 — runs on the same command pair.

DHKEM has concrete near-term relevance beyond the quantum transition. v1.85 also adds Curve25519 and Curve448 support, which are the curves DHKEM operates on. ISO 15118 — the protocol governing secure communication between EVs and charging infrastructure — uses these curves. I've been watching TPM adoption in EV charging for several years. The same command surface that enables post-quantum key encapsulation also closes a long-standing compatibility gap for that market.

The framing of "PQC update" undersells what v1.85 actually is. The command model was redesigned. Post-quantum algorithms required it, and the classical world benefited.

| Algorithm | Type | Standard | Post-quantum | Parameter sets | New commands | Notes |
|---|---|---|---|---|---|---|
| ML-DSA | Digital signature | FIPS 204 | Yes | ML-DSA-44, ML-DSA-65, ML-DSA-87 | `SignVerifySequenceStart`, `SignSequenceComplete`, `VerifySequenceComplete` | Signs full messages — not digests. Sequence commands required. Attestation Key (AK) support included. |
| HashML-DSA | Digital signature | FIPS 204 | Yes | Same as ML-DSA | `SignDigest`, `VerifyDigestSignature`, `SignVerifySequenceStart`, `SignSequenceComplete`, `VerifySequenceComplete` | Pre-hashed variant. Message is hashed externally first; TPM receives the digest. Can use the digest-based path when that is appropriate. |
| ML-KEM | Key encapsulation | FIPS 203 | Yes | ML-KEM-512, ML-KEM-768, ML-KEM-1024 | `Encapsulate`, `Decapsulate` | Endorsement Key (EK) support included. Relevant for harvest-now-decrypt-later threat models — long-term confidentiality protection. |
| EdDSA | Digital signature | RFC 8032 | No | Ed25519, Ed448 | `SignVerifySequenceStart`, `SignSequenceComplete`, `VerifySequenceComplete` | Not post-quantum. New to the TPM command surface. Uses same sequence commands as ML-DSA. Signing limited to `MAX_BUFFER`. |
| HashEdDSA | Digital signature | RFC 8032 | No | Ed25519, Ed448 | `SignVerifySequenceStart`, `VerifySequenceComplete` | Pre-hashed variant of EdDSA. Verification supports arbitrary message size; signing limited to `MAX_BUFFER`. |
| DHKEM | Key encapsulation | RFC 9180 | No | P-256, P-384, X25519, X448 | `Encapsulate`, `Decapsulate` | ECDH-based KEM. Not post-quantum. Shares the KEM command surface with ML-KEM. Relevant for ISO 15118 and protocols built on Curve25519 / Curve448. |

---

## New TPM commands

Seven new commands. Two deprecated in the same version. `TPM2_Sign()` and `TPM2_VerifySignature()` are replaced — not yet removed, but the direction is clear. The replacements exist because ML-DSA cannot sign digests. The old interface assumed all signing algorithms were digest-based. That assumption no longer holds.

| Command | Algorithm scope | Standard | Purpose |
|---|---|---|---|
| `TPM2_SignDigest` | ECDSA, HashML-DSA | FIPS 204 | Signs a message digest directly |
| `TPM2_VerifyDigestSignature` | ECDSA, HashML-DSA | FIPS 204 | Verifies a signature against a digest |
| `TPM2_SignVerifySequenceStart` | ML-DSA, HashML-DSA, EdDSA, HashEdDSA | FIPS 204, RFC 8032 | Opens a context for multi-part signing or verification |
| `TPM2_SignSequenceComplete` | ML-DSA, HashML-DSA, EdDSA | FIPS 204, RFC 8032 | Closes the signing context and returns the signature |
| `TPM2_VerifySequenceComplete` | ML-DSA, HashML-DSA, EdDSA, HashEdDSA | FIPS 204, RFC 8032 | Closes the verification context and returns the result |
| `TPM2_Encapsulate` | ML-KEM, DHKEM | FIPS 203, RFC 9180 | Public-key operation — generates a shared secret and ciphertext |
| `TPM2_Decapsulate` | ML-KEM, DHKEM | FIPS 203, RFC 9180 | Private-key operation — recovers the shared secret from ciphertext |

## In Summary

TCG published TPM 2.0 Library Specification v1.85 in July 2025. It is the first version to bring post-quantum cryptography into the TPM command surface directly:

* ML-DSA for signing
* ML-KEM for key encapsulation

The specification is real, but the discrete silicon is still catching up.

That gap matters if you are designing a product today. There are products shipping now that carry PQC marketing. Some of them protect the *firmware update channel* with a post-quantum algorithm. That is not the same thing as exposing post-quantum operations to your application. The distinction is architectural, and the table below makes it explicit.

A TPM with a PQC-protected *firmware update mechanism* means the firmware pushed to the chip is signed with a post-quantum algorithm and protecting the update channel from tampering. It does not mean your application can call the new PQC commands such as `TPM2_Encapsulate` or `TPM2_SignVerifySequenceStart`.

