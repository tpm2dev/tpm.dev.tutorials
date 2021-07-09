# Device Enrollment

Device Enrollment is the act of registering a device -anything from an
IoT to a server- and creating the state that will be referenced in
future [attestations](/Attestation/README.md) from that device.

This can be as simple as sending the device's endorsement key
certificate (EKcert) to a registration server (possibly authenticating
to that server using some administrator user's credentials), to a more
complex protocol similar to [attestation](/Attestation/README.md).

## Online Enrollment

Online enrollment means that the device to be enrolled interacts with an
enrollment service over a network.

## Off-line Enrollment

Off-line enrollment means that the device to be enrolled *does not*
interact with an enrollment service.

For example, one might scan an endorsement key (EK) public key or
certificate from a QR code on a shipment manifest and then enroll the
device using only that information.

## Safeboot.dev Enrollment Protocol

[Safeboot.dev](https://safeboot.dev) has an enrollment script,
`attest-enroll` which can have a trivial HTTP API binding where an
authenticated and authorized client principal `POST`s an `EKpub` and a
device name to the server.  The server then creates enrollment state for
the device that will be used during subsequence attestation.

The [safeboot.dev enrollment process](https://github.com/osresearch/safeboot/blob/master/docs/enrollment.md)
does not require any interaction with the enrollee device except to
extract its `EKpub`.  When the `EKpub` can be determined in an off-line
manner, then the safeboot.dev enrollment process can be fully off-line.

# Server-Side State to Create during Enrollment

 - device name <-> EKpub binding
 - enrolling user/admin
 - that the device has a valid TPM (i.e., the EKcert validates to a
   trusted TPM vendor's trust anchor)
 - initial root of trust measurement (RTM)
 - backup, secret recovery keys
 - encrypted secrets to send to the device

# Client-side State to Create during Enrollment

 - encrypted filesystems?
 - device credentials?  (e.g., TLS server certificates, Kerberos keys ["keytabs"], etc.)

# Secrets Long-Term Storage and Transport

Every time an enrolled device reboots, or possibly more often, it may
have to connect to an attestation server to obtain secrets from it that
the device needs in order to proceed.  For example, filesystem
decryption keys, general network access, device authentication
credentials, etc.

See [attestation](/Attestation/README.md#Secret-Transport-Sub-Protocols)
for details of how to store and transport secrets onto an enrolled
device post-enrollment.

## Encrypt-to-TPM Sample Scripts

A pair of scripts used in [safeboot.dev](https://safeboot.dev) are
included here to demonstrate how to make long-term secrets encrypted to
TPMs for use in [attestation](/Attestation/README.md) protocols.  The
method used is the one described in the [attestation
tutorial](/Attestation/README.md#Secret-Transport-Sub-Protocols) using
either of two methods to encrypt to a TPM:

 - The "EK" method of encryption to a TPM uses
   [`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md) and
   [`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md)
   with a hard-coded, _well-known_ activation key (`WK`) to implement
   encryption-to-`EKpub` with (optional) sender-asserted authorization
   policy.

 - The "TK" method of encryption to a TPM uses a software implementation
   of [`TPM2_Duplicate()`](/TPM-Commands/TPM2_Duplicate.md) to wrap the
   private part of a "transport key" (`TK`) to the target TPM, then
   normal RSA encryption to the public part of the `TK`.  The ciphertext
   consists of the outputs of `TPM2_Duplicate()` and the ciphertext
   produced by RSA encryption to the TK.

The "EK" method is the default.  Both methods support sender-asserted
policies.

The scripts:

 - [`send-to-tpm`](send-to-tpm)
 - [`tpm-receive`](tpm-receive)

You can use these scripts like so:

 - without policy:

   ```bash
   : ; # Make a secret
   : ; dd if=/dev/urandom of=secret.bin bs=16 count=1
   : ;
   : ; # Encrypt the secret to some TPM whose EKpub is in a file named
   : ; # ek.pub:
   : ; /safeboot/sbin/send-to-tpm ek.pub secret.bin cipher.bin
   : ; 
   ```

   ```bash
   : ; # Decrypt the secret:
   : ; tpm-receive cipher.bin plaintext.bin
   837197674484b3f81a90cc8d46a5d724fd52d76e06520b64f2a1da1b331469aa
   name: 000bc76d1462d32d5e6051d0aa121edfa5ed66b8e7f3632ce3c5a172b1ebd8aabc40
   : ;
   ```

 - with policy

   > Here we use a policy that `PCR #11` has not been extended.  The
   > idea is to extend it immediately after decrypting the ciphertext,
   > which means that the ciphertext cannot again be decrypted later
   > (by, say, some other application with access to the same TPM)
   > without rebooting.

   ```bash
   : ; # Make up a policy (here that PCR11 must be unextended):
   : ; dd if=/dev/zero of=pcr.dat bs=32 count=1
   : ; policy=(tpm2 policypcr -l sha256:11 -f pcr.dat)
   : ;
   : ; send-to-tpm ek.pub secret.bin cipher.bin "${policy[@]}"
   fd32fa22c52cfc8e1a0c29eb38519f87084cab0b04b0d8f020a4d38b2f4e223e
   7fdad037a921f7eec4f97c08722692028e96888f0b970dc7b3bb6a9c97e8f988
   7fdad037a921f7eec4f97c08722692028e96888f0b970dc7b3bb6a9c97e8f988
   policyDigest:
   7fdad037a921f7eec4f97c08722692028e96888f0b970dc7b3bb6a9c97e8f988
   : ; 
   ```

   ```bash
   : ; # We have to satisfy the same policy on the receive side:
   : ; policy=(tpm2 policypcr -l sha256:11 -f pcr.dat)
   : ;
   : ; tpm-receive cipher.bin plaintext.bin "${policy[@]}"
   fd32fa22c52cfc8e1a0c29eb38519f87084cab0b04b0d8f020a4d38b2f4e223e
   7fdad037a921f7eec4f97c08722692028e96888f0b970dc7b3bb6a9c97e8f988
   7fdad037a921f7eec4f97c08722692028e96888f0b970dc7b3bb6a9c97e8f988
   837197674484b3f81a90cc8d46a5d724fd52d76e06520b64f2a1da1b331469aa
   name: 000b20a6cc44c93ad206196c65028f9a8bf2590de0b8f89bca9e968f09f4e616dba6
   fd32fa22c52cfc8e1a0c29eb38519f87084cab0b04b0d8f020a4d38b2f4e223e
   7fdad037a921f7eec4f97c08722692028e96888f0b970dc7b3bb6a9c97e8f988
   7fdad037a921f7eec4f97c08722692028e96888f0b970dc7b3bb6a9c97e8f988
   : ;
   ```

   Multiple policy commands can be separated with a quoted semi-colon:

   ```bash
   send-to-tpm ... tpm2 policyblah ... \; policyfoo ...
   ```

   Multiple policy commands can be separated with a quoted semi-colon:

   ```bash
   send-to-tpm ... tpm2 policyblah ... \; policyfoo ...
   ```

   When a policy is specified, these scripts will automatically set the
   `adminWithPolicy` attribute of the activation object, and will add
   `tpm2 policycommandcode TPM2_CC_ActivateCredential` ("EK" method) or
   `tpm2 policycommandcode TPM2_CC_RSA_Decrypt` ("TK" method) to the
   policy.

# Enrollment Semantics

 - online vs. off-line

 - client device trust semantics:
    - bind device name and EKpub on first use ("BOFU")?
    - enroll into inventory and then allow authorized users to bind a
      device name to an EKpub on a first-come-first-served basis?

 - enrollment server trust semantics:
    - trust on first use (TOFU) (i.e., trust the first enrollment server
      found)
    - pre-install a trust anchor on the client device
    - use a user/admin credential on the device to establish trust on
      the server (e.g., intrinsically to how user authentication works,
      or having the user review and approve the server's credentials)

# Threat Models

Threats:

 - enrollment server impersonation
 - enrollment of rogue devices
 - eavesdroppers
 - DoS

A typical enrollment protocol for servers in datacenters may well not
bother protecting against all of the above.

A typical enrollment protocol for IoTs in a home network also may well
not bother protecting against any of the above.

Enrollment protocols for personal devices must protect against all the
listed threats except DoS attacks.

# Enrollment Protocols

## Trivial Enrollment Protocols

The simplest enrollment protocols just have the client device send its
EKcert to the enrollment server.  The enrollment server may have a user
associate enrolled devices with device IDs (e.g., hostnames), and the
device's enrollment is complete.

## Enrollment Protocols with Proof of Possession and Attestation

A more complex enrollment protocol would have the device attest to
possession of the EK whose EKpub is certified by its EKcert, and might
as well also perform attestation of other things, such as RTM.

An enrollment protocol with proof of possession might look a lot like
the [two round trip attestation
protocol](/Attestation/README.md#two-round-trip-stateless-attestation-protocol-patterns),
with the addition of `enrollment_data` in the last message from the
client to the server (server authentication not shown):

```
  CS0:  [ID], EKpub, [EKcert], AKpub, PCRs, eventlog, timestamp,
        TPM2_Quote(AK, PCRs, extra_data)=Signed_AK({hash-of-PCRs, misc, extra_data})
  SC0:  {TPM2_MakeCredential(EKpub, AKpub, session_key), ticket}
  CS1:  {ticket, MAC_session_key(CS0), CS0, Encrypt_session_key(enrollment_data)}
                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                            (new)
  SC1:  Encrypt_session_key({AKcert, filesystem_keys, etc.})

  <extra_data includes timestamp>
```

where

```
  enrollment_data = { Encrypt_TK(secrets), [TKpub], [HK_pub] }

  secrets = any secrets generated on the client side
  TKpub = public part of transport key for encrypting secrets to the
          client
  HKpub = public part of a host key for host authentication
```

## Enrollment Protocols for Personal Devices

Enrollment of personal devices in their owners' personal device groups
can be a lot like Bluetooth device pairing.  Where such devices have
TPMs then perhaps there is a role for the TPM to play in enrollment.

# Security Considerations

TBD

The enrollment database, though it contains ciphertexts of secrets
encrypted to enrolled devices' TPMs, is nonetheless to be kept
confidential.  This is necessary to avoid attacks where an attacker
compromises an enrolled device then attempts to decrypt those
ciphertexts with the enrolled device's TPM.  These ciphertexts should
only be furnished to the device as part of an attestation protocol.

For the same reason, these ciphertexts must be super-encrypted when
delivering them to enrolled devices during attestation.

Ciphertexts in enrolled state should be made with suitable sender-
asserted policies.  For example, asserting that `PCR #11` has not been
extended so that immediately after decrypting such a ciphertext the
client can extend `PCR #11` to make decrypting that ciphertext again
impossible without an intervening reboot.

