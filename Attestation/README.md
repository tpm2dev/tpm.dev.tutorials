# What Attestation is

A computer can use a TPM to demonstrate:

 - possession of a valid TPM

 - it being in a trusted state by dint of having executed (possibly
   only) trusted code to get to that state

 - possession of objects such as asymmetric keypairs being resident on
   the TPM (objects that might be used in the attestation protocol)

Possible results of succesful attestation:

 - encrypted filesystems getting unlocked with the help of an
   attestation server

 - issuance of X.509 certificate(s) for TPM-resident public keys

 - other secrets (e.g., credentials for various authentication systems)

# Attestation Protocols

Attestation is done by a computer with a TPM interacting with an
attestation service over a network.  This requires an attestation
protocol.

## Notation

 - `Encrypt_<name>` == encryption with the named private or secret key
   (if symmetric, then this primitive is expected to provide
   authenticated encryption).
 - `Sign_<name>` == digital signature with the named private key.
 - `MAC_<name>` == message authentication code keyed with the named
   secret key.
 - `CSn` == client-to-server message number `n`
 - `SCn` == server-to-client message number `n`
 - `{stuff, more_stuff}` == a sequence of data, a "struct"

## Proof of Possession of TPM

Proof of possession of a valid TPM is performed by the attestation
client sending its TPM's Endorsement Key (EK) certificate (if one is
available, else the attestation service must recognize the EK public
key) and then exchanging additional messages by which the client can
prove its possession of the EK.

Proof of possession of an EK is complicated by the fact that EKs are
[generally decrypt-only](Decrypt-only-EK.md) (some TPMs also support
signing EKs, but the TCG specifications only require decrypt-only EKs).
The protocol has to have the attestation service send a challenge (or
key) encrypted to the EKpub and then the attestation client demonstrate
that it was able to decrypt that with the EK.  However, this is not
_quite_ how attestation protocols work!  Instead of plain asymmetric
encryption the server will use
[`TPM2_MakeCredential()`](TPM2_MakeCredential.md), while the attestation
client will use
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) instead of
plain asymmetric decryption.

## Trusted State Attestation

Trusted state is attested by sending a quote of Platform Configuration
Registers (PCRs) and the `eventlog` describing the evolution of the
system's state from power-up to the current state.  The attestation
service vallidates the digests used to extend the various PCRs,
and perhaps the sequence in which they appear in the eventlog, typically
by checking a list of known-trusted digests (these are, for example,
checksums of firmware images).

Typically the attestation protocol will have the client generate a
signing-only asymmetric public key pair known as the attestation key
(AK) with which to sign the PCR quote and eventlog.  Binding of the
EKpub and AKpub will happen via
[`TPM2_MakeCredential()`](TPM2_MakeCredential.md) /
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md).

## Binding of Other Keys to EKpub

The semantics of [`TPM2_MakeCredential()`](TPM2_MakeCredential.md) /
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md) make it
possible to bind a TPM-resident object to the TPM's EKpub.

[`TPM2_MakeCredential()`](TPM2_MakeCredential.md) encrypts to the EKpub
a small secret datum and the name (digest of public part) of the
TPM-resident object being bound.  The counter-part to this,
[`TPM2_ActivateCredential()`](TPM2_ActivateCredential.md), will decrypt
that and return the secret to the application IFF (if and only if) the
caller has access to the named object.

Typically attestation protocols have the client send its EKpub, EKcert
(if it has one), AKpub (the public key of an "attestation key"), and
other things (e.g., PCR quote and eventlog signed with the AK), and the
server will then send the output of `TPM2_MakeCredential()` that the
client can recover a secret from using `TPM2_ActivateCredential()`.

The implication is that if the client can extract the cleartext payload
of `TPM2_MakeCredential()`, then it must possess a) the EK private key
corresponding to the EKpub, b) the AK private key corresponding to the
object named by the server.

Proof of possession can be completed immediately by demonstrating
knowledge of the secret sent by the server.  Proof of possession can
also be delayed to an eventual use of that secret, allowing for single
round trip attestation.

## Attestation Protocol Patterns

### Single Round Trip Attestation Protocols

An attestation protocol need not complete proof-of-possession
immediately if the successful outcome of the protocol has the client
demonstrate possession to other services/peers.

In the following example the client obtains a certificate (`AKcert`) for
its AK, filesystem decryption keys, and possibly other things, and
eventually it will use those items in ways that -by virtue of having
thus been used- demonstrate that it possesses the EK used in the
protocol:

```
  CS0:  Signed_AK({timestamp, [ID], EKpub, [EKcert],
                   AKpub, PCR_quote, eventlog})
  SC0:  {TPM2_MakeCredential(EKpub, AKpub, session_key),
         Encrypt_session_key({AKcert, filesystem_keys, etc.})}
```

(`ID` might be, e.g., a hostname.)

The server will validate that the `timestamp` is near the current time,
the EKcert (if provided, else the EKpub), the signature using the
asserted (but not yet bound to the EKpub) AKpub, then it will validate
the PCR quote and eventlog, and, if everything checks out, will issue a
certificate for the AKpub and return various secrets that the client may
need.

The client obtains those items IFF (if and only if) the AK is resident
in the same TPM as the EK, courtesy of `TPM2_ActivateCredential()`'s
semantics.

NOTE well that in this example it is *essential* that the AKcert not be
logged in any public place since otherwise an attacker can make and send
`CS0` using a non-TPM-resident AK and any TPM's EKpub/EKcert known to
the attacker, and then it may recover the AK certificate from the log in
spite of being unable to recover the AK certificate from `SC1`!

### Two Round Trip Attestation Protocols

We can add a round trip to the protocol in the previous section to make
the client prove possession of the EK and binding of the AK to the EK
before it can get the items it needs.  This avoids the security
consideration of having to not log the AKcert.

Below is a sketch of a stateless, two round trip attestation protocol.

Actual protocols tend to use a secret challenge that the client echoes
back to the server rather than a secret key possesion of which is proven
with symmetriclly-keyed cryptographic algorithms.

```
  CS0:  Signed_AK({timestamp, [ID], EKpub, [EKcert],
                   AKpub, PCR_quote, eventlog})
  SC0:  {TPM2_MakeCredential(EKpub, AKpub, session_key), ticket}
  CS1:  {ticket, MAC_session_key(CS0), CS0}
  SC1:  Encrypt_session_key({AKcert, filesystem_keys, etc.})
```

where `session_key` is an ephemeral secret symmetric authenticated
encryption key, and `ticket` is an authenticated encrypted state cookie:

```
  ticket = {vno, Encrypt_server_secret_key({session_key, timestamp, MAC_session_key(CS0)})}
```

where `server_secret_key` is a key known only to the attestation service
and `vno` identifies that key (in order to support key rotation without
having to try authenticated decryption twice near key rotation events).

The attestation server could validate that the `timestamp` is recent
upon receipt of `CS0`.  But the attestation server can delay validation
of EKcert, signatures, and PCR quote and eventlog until receipt of
`CS1`.  In order to produce `SC0` the server need only digest the AKpub
to produce the name input of `TPM2_MakeCredential()`.  Upon receipt of
`CS1` (which repeats `CS0`), the server can decrypt the ticket, validate
the MAC of `CS0`, validate `CS0`, and produce `SC1` if everything checks
out.

In this protocol the client must successfully call
`TPM2_ActivateCredential()` to obtain the `session_key` that it then
proves possession of in `CS1`, and only then does the server send the
`AKcert` and/or various secret values to the client, this time saving
the cost of asymmetric encryption by using the `session_key` to key a
symmetric authenticated cipher.

### Actual Protocols: ibmacs

(TBD)

### Actual Protocols: safeboot.dev

(TBD)

### Actual Protocols: ...

(TBD)

# Long-Term State Kept by Attestation Services

Attestation servers need to keep some long-term state:

 - binding of `EKpub` and `ID`
 - PCR validation profile for each identified client

The PCR validation profile for a client consists of a set of required
and/or acceptable digests that must appear in each PCR's extension log.
These required and/or acceptable digests may be digests of firmware
images, boot loaders, boot loader configurations (e.g., `menu.lst`, for
Grub), operating system kernels, `initrd` images, filesystem root hashes
(think ZFS), etc.

Some of these are obtained by administrators on a trust-on-first-use
(TOFU) basis.

## Long-Term State Created by Attestation Services

An attestation service might support creation of host&lt;-&gt;EKpub
bindings on a first-come-first-served basis.

An attestation service might support deletion of host PCR validation
profiles that represent past states upon validation of PCR quotes using
newer profiles.  This could be used to permit firmware and/or operating
system upgrades and then disallow downgrades after evidence of
successful upgrade.
