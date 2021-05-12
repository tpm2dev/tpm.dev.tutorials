# Boot with TPM: Secure vs Verified vs Measured

## Contributors
* Daniel Smith
* Dimi Tomov
* Ian Oliver

## Terminology

Secure Boot - From technical point of view, this is a Verified Boot.
Trusted Boot - From technical point of view, this is a 
Measured Boot.

## Verified vs Measured boot

The confusion between Secure and Trusted Boot often is caused by a blending of marketing speak with technical implementation. There are really only two types of booting a system in a manner to assert a degree of trustworthiness, i.e. Trusted Boot.

### Verified boot

The first type is a verified boot were the assertion comes in the form of a cryptographic signature verification. Often this is what is referred to when the boot integrity solutions is called "Secure Boot".

#### The advantages to these solutions is that:

1. it gives total control over the process to the signing authority that is trusted
2. requires no external validation (which often equates to easier implementations)
3. defeating decent cryptography is hard and a specialized field

#### The disadvantages are that:

1. the signing authority has total control over the boot process
2. the cryptographic validation (the Root of Trust) is often done in software so it can be defeated just like any other piece of software (thus no need to defeat the cryptography directly)
3. it is an all or nothing validation
4. there is no evidence to the success or failure of the validation (thus if 2. occurred you have no way of knowing)
5. while the validation process is simple to implement the key revocation process creates an escrow problem

### Measured boot

The second type is measured boot were the assertion comes in the form of measurement evidence that must be evaluated for correctness. Often this is called "Measured Launch" or "Measured Boot".

#### The advantages to these solutions are that:

1. control over boot is often given to the user
2. it is easier to implement the measurement in hardware
3. there is no key escrow issue allowing for limitless good/correct configurations
4. it is possible to have flexibility in determining good/correct configurations
5. there is evidence to assert externally the correctness of the system.

The disadvantages are:

1.) outside of a very limited set of solutions, the boot process is not stopped immediately when a bad configuration is loaded
2.) often local attestation is relied on as the enforcement mechanism and thus susceptible to being defeated by a local entity
3.) past attestation protocols have been overly complex with little consensus inhibiting adoption
4.) the lack of open remote attestation solutions.

## Hybrid Solutions

There are hybrid solutions like UEFI SecureBoot where both measurement and verification are applied to maximize certain advantages from each. Like UEFI SecureBoot, these often are paired as a verified measured boot in that the integrity of the measurement is rooted in the verification of an early software component.

The trustworthiness of these solutions is driven by where the verification is conducted. Solutions like Intel's BootGuard and AMD's HVB attempt to move the verification closer to hardware through CPU protected software execution environments (ACM Mode and PSP respectively).

## The TrenchBoot project (remarks by Daniel Smith)

When I started the TrenchBoot project one of the approaches I was advocating, and still am, is a measured verified boot that I called Measured-SecureBoot (MSB). Just as UEFI SecureBoot maximize certain advantages, MSB is designed to maximize freedom and integrity for a trustworthy solution in control of the user but a strong degree of integrity that can be asserted externally to outside service providers. This is achieved by the fact that a majority of measured boot solutions are implemented with the first measurement being taken by hardware. This would be leveraged to measure the software verification code along with verification key(s). This provides the ability to have verified boot without any of the key escrow issues and to attest to external service providers of verification chain in use.

## Measured boot (remarks by Ian Oliver)

As long as your write something to the TPM during boot you get a Measured boot. How relevant that is, is another topic. You can have a Static-Root-of-Trust-for-Measurement(SRTM) on a Pi. For example, [wolfBoot](https://github.com/wolfSSL/wolfBoot) + [wolfTPM](https://github.com/wolfSSL/wolfTPM) or  uBoot + TPM.  What you do not get is a Core-Root-of-Trust-for-Measurement(CRTM).

## Original article at TPM.dev

TPM.dev source - https://developers.tpm.dev/posts/boot-with-tpm-secure-vs-measured-vs-trusted

## Notes

* i.MX6 and i.MX8 "High Assurance Boot"(HAB) are a form of Secure Boot.
* Raspberry Pi does not have secure boot, because the Broadcom SoC does not offer such capability.
* Nvidia Jetson also offers Secure Boot

