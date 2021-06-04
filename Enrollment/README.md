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

# Secrets Transport

Every time an enrolled device reboots, or possibly more often, it may
have to connect to an attestation server to obtain secrets from it that
the device needs in order to proceed.  For example, filesystem
decryption keys, general network access, device authentication
credentials, etc.

See [attestation](/Attestation/README.md) for details of how to
transport secrets onto an enrolled device post-enrollment.

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
