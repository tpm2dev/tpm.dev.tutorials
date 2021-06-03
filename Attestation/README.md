# What Attestation is

A computer can use a TPM to demonstrate:

 - possession of a valid TPM

 - it being in a trusted state by dint of having executed trusted code
   to get to that state

 - possession of objects such as asymmetric keypairs being resident on
   the TPM (objects that might be used in the attestation protocol)

Possible outputs of succesful attestation:

 - authorize client to join its network

 - delivery of configuration metadata to the client

 - unlocking of storage / filesystems on the client

 - delivery of various secrets, such credentials for various authentication systems:

    - issuance of X.509 certificate(s) for TPM-resident attestaion
      public keys

      For servers these certificates would have `dNSName` subject
      alternative names (SANs).

      For a user device such a certificate might have a subject name
      and/or SANs identifying the user or device.

    - issuance of non-PKIX certificates (e.g., OpenSSH-style certificates)

    - issuance of Kerberos host-based service principal long-term keys
      ("keytabs")

    - service account tokens

    - etc.

 - client state tracking

 - etc.

Possible outputs of unsuccessful attestation:

 - alerting

 - diagnostics (e.g., which PCR extensions in the PCR quote and eventlog
   are not recognized, which then might be used to determine what
   firmware / OS updates a client has installed, or that it has been
   compromised)

In this tutorial we'll focus on attestion of servers in an enterprise
environment.  However, the concepts described here are applicable to
other environments, such as IoTs and personal devices, where the
attestation database could be hosted on a user's personal devices for
use in joining new devices to the user's set of devices, or for joining
new IoTs to the user's SOHO network.

# Attestation Protocols

Attestation is done by a client computer with a TPM interacting with an
attestation service over a network.  This requires a network protocol
for attestation.

## Intended Audience

Readers should have read the [TPM introduction tutorial](/Intro/README.md).

## Enrollment

[Enrollment](/Enrollment/README.md) is the process and protocol for
onboarding devices into a network / organization.  For example, adding
an IoT to a home network, a server to a data center, a smartphone or
tablet or laptop to a persons set of personal devices, etc.

Generally attestation protocols apply to enrolled devices.  Enrollment
protocols _may_ be very similar to attestation protocols, or even
actually be sub-protocols of attestation protocols.  Enrollment
protocols can also be separate from attestation altogether.

This tutorial mostly covers only attestation of/by enrolled devices.
For more about enrollment see the tutorial specifically for
[enrollment](/Enrollment/README.md).

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
 - `{"key":<value>,...}` == JSON text
 - `TPM2_MakeCredential(<args>)` == outputs of calling `TPM2_MakeCredential()` with `args` arguments
 - `TPM2_Certify(<args>)` == outputs of calling `TPM2_Certify()` with `args` arguments
 - `XK` == `<X>` key, for some `<X>` purpose (the TPM-resident object and its private key)
    - `EK` == endorsement key (the TPM-resident object and its private key)
    - `AK` == attestation key (the TPM-resident object and its private key)
    - `TK` == transport key (the TPM-resident object and its private key)
 - `XKpub` == `<X>`'s public key, for some `<X>` purpose
    - `EKpub` == endorsement public key
    - `AKpub` == attestation public key
    - `TKpub` == transport public key
 - `XKname` == `<X>`'s cryptographic name, for some `<X>` purpose
    - `EKname` == endorsement key's cryptographic name
    - `AKname` == attestation key's cryptographic name

## Threat Models

Some threats that an attestation protocol and implementation may want to
address:

 - attestation client impersonation
 - attestation server impersonation
 - unauthorized firmware and/or OS updates
 - theft or compromise of of attestation servers
 - theft of client devices or their local storage (e.g., disks, JBODs)
 - theft of client devices by adversaries capable of decapping and
   reading the client's TPM's NVRAM

The attestation protocols we discuss will provide at least partial
protection against impersonation of attestation clients: once a TPM's
EKpub/EKcert are bound to the device in the attestation server's
database, that TPM can only be used for that device and no others.

All the attestation protocols we discuss will provide protection against
unauthorized firmware and/or OS updates via attestation of root of trust
measurements (RTM).

The attestation protocols we discuss will provide protection against
impersonation of attestation servers without necessarily authenticating
the servers to the clients in traditional ways (e.g., using TLS server
certificates).  The role of the attestation server will be to deliver to
clients secrets and credentials they need that can only be correct and
legitimate if the server is authentic.  As well, an attestation server
may unlock network access for a client, something only an authentic
server could do.

We will show how an attestation server can avoid storing any cleartext
secrets.

Theft of _running_ client devices cannot be fully protected against by
an attestation protocol.  The client must detect being taken from its
normal environment and shutdown in such a way that no secrets are left
in cleartext on any of its devices.  Frequent attestations might be used
to detect theft of a client, but other keepalive signalling options are
possible.

Theft of non-running client devices can be protected against by having
the client shutdown in such a way that no secrets are left in cleartext
on any of its devices.  Such client devices may be configured to need
the help of an attestation server to recover the secrets it needs for
normal operation.

Full protection against decapping of TPM chips is not possible, but
protection against off-line use of secrets stolen from TPM chips is
possible by requiring that the client be on-line and attest in order to
obtain secrets that it needs to operate.  This allows for revocation of
stolen clients, which would result in attestation protocol failures.

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
[`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md), while
the attestation client will use
[`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md)
instead of plain asymmetric decryption.

## Trusted State Attestation

Trusted state is attested by sending a quote of Platform Configuration
Registers (PCRs) and the `eventlog` describing the evolution of the
system's state from power-up to the current state.  The attestation
service validates the digests used to extend the various PCRs,
and perhaps the sequence in which they appear in the eventlog, typically
by checking a list of known-trusted digests (these are, for example,
checksums of firmware images).

Typically the attestation protocol will have the client generate a
signing-only asymmetric public key pair known as the attestation key
(AK) with which to sign the PCR quote and eventlog.  Binding of the
EKpub and AKpub will happen via
[`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md) /
[`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md).

Note that the [`TPM2_Quote()`](/TPM-Commands/TPM2_Quote.md) function produces a signed
message -- signed with a TPM-resident AK named by the caller (and to
which they have access), which would be the AK used in the attestation
protocol.

The output of [`TPM2_Quote()`](/TPM-Commands/TPM2_Quote.md) might be the only part of
a client's messages to the attestation service that include a signature
made with the AK, but integrity protection of everything else can be
implied (e.g., the eventlog and PCR values are used to reconstruct the
PCR digest signed in the quote).  `TPM2_Quote()` signs more than just a
digest of the selected PCRs.  `TPM2_Quote()` signs all of:

 - digest of selected PCRs
 - caller-provided extra data (e.g., a cookie/nonce/timestamp/...),
 - the TPM's firmware version number,
 - `clock` (the TPM's time since startup),
 - `resetCount` (an indirect indicator of reboots),
 - `restartCount` (an indirect indicator of suspend/resume events)
 - and `safe` (a boolean indicating whether the `clock` might have ever
   gone backwards).

## Binding of Other Keys to EKpub

The semantics of [`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md) /
[`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md) make it
possible to bind a TPM-resident object to the TPM's EKpub.

[`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md) encrypts to the EKpub
a small secret datum and the name (digest of public part) of the
TPM-resident object being bound.  The counter-part to this,
[`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md), will decrypt
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

## Binding hosts to TPMs

(TBD.  Talk about IDevID or similar certificates binding hosts to their
factory-installed TPMs, and how to obtain those from vendors.)

## Attestation Protocol Patterns and Actual Protocols (decrypt-only EKs)

Note: all the protocols described below are based on decrypt-only TPM
endorsement keys.

Let's start with few observations and security considerations:

 - Clients need to know which PCRs to quote.  E.g., the [Safe Boot](https://safeboot.dev/)
   project and the [IBM sample attestation client and server](https://sourceforge.net/projects/ibmtpm20acs/)
   have the client ask for a list of PCRs and then the client quotes
   just those.

   But clients could just quote all PCRs.  It's more data to send, but
   probably not a big deal, and it saves a round trip if there's no need
   to ask what PCRs to send.

 - Some replay protection or freshness indication for client requests is
   needed.  A stateful method of doing this is to use a server-generated
   nonce (as an encrypted state cookie embedding a timestamp).  A
   stateless method is to use a timestamp and reject requests with old
   timestamps.

 - Replay protection of server to client responses is mostly either not
   needed or implicitly provided by [`TPM2_MakeCredential()`](TPM2_MakeCredential.md)
   because `TPM2_MakeCredential()` generates a secret seed that
   randomizes its outputs even when all the inputs are the same across
   multiple calls to it.

 - Ultimately the protocol *must* make use of
   [`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md) and
   [`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md) in order to
   authenticate a TPM-running host via its TPM's EKpub.

 - Privacy protection of client identifiers may be needed, in which case
   TLS may be desired.

 - Even if a single round trip attestation protocol is adequate, a
   return routability check may be needed to avoid denial of service
   attacks.  I.e., do not run a single round trip attestation protocol
   over UDP without first requiring the client to echo a nonce/cookie.

 - Statelessness on the server side is highly desirable, as that should
   permit having multiple servers and each of a client's messages can go
   to different servers.  Conversely, keeping state on the server across
   multiple round trips can cause resource exhaustion / denial of
   service attack considerations.

 - Statelessness maps well onto HTTP / REST.  Indeed, attestation
   protocol messages could all be idempotent and therefore map well onto
   HTTP `GET` requests but for the fact that all the things that may be
   have to be sent may not fit on a URI local part or URI query
   parameters, therefore HTTP `POST` is the better option.

### Error Cases Not Shown

Note that error cases are not shown in the protocols described below.

Naturally, in case of error the attestation server will send a suitable
error message back to the client.

### Databases, Log Sinks, and Dashboarding / Alerting Systems Not Shown

In order to simplify the protocol diagrams below, interactions with
databases, log sinks, and alerting systems are not shown.

A typical attestation service will, however, have interactions with
those components, some or all of which might even be remote:

 - attestation database
 - log sinks
 - dashboarding / alerting

If an attestation service must be on the critical path for booting an
entire datacenter, it may be desirable for the attestation service to be
able to run with no remote dependencies, at least for some time.  This
means, for example, that the attestation database should be locally
available and replicated/synchronized only during normal operation.  It
also means that there should be a local log sink that can be sent to
upstream collectors during normal operation.

### Single Round Trip Attestation Protocol Patterns

An attestation protocol need not complete proof-of-possession
immediately if the successful outcome of the protocol has the client
subsequently demonstrate possession to other services/peers.  This is a
matter of taste and policy.  However, one may want to have
cryptographically secure "client attested successfully" state on the
server without delay, in which case two round trips are the minimum for
an attestation protocol.

In the following example the client obtains a certificate (`AKcert`) for
its AKpub, filesystem decryption keys, and possibly other things, and
eventually it will use those items in ways that -by virtue of having
thus been used- demonstrate that it possesses the EK used in the
protocol:

```
  <client knows a priori what PCRs to quote, possibly all, saving a round trip>

  CS0:  [ID], EKpub, [EKcert], AKpub, PCRs, eventlog, timestamp,
        TPM2_Quote(AK, PCRs, extra_data)=Signed_AK({hash-of-PCRs, misc, extra_data})
  SC0:  {TPM2_MakeCredential(EKpub, AKpub, session_key),
         Encrypt_session_key({AKcert, filesystem_keys, etc.})}

  <extra_data includes timestamp>

  <subsequent client use of AK w/ AKcert, or of credentials made
   available by dint of being able to access filesystems unlocked by
   SC0, demonstrate that the client has attested successfully>
```

(`ID` might be, e.g., a hostname.)

![Protocol Diagram](Protocol-Two-Messages.png)

(In this diagram we show the use of a TPM simulator on the server side
for implementing [`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md).)

The server will validate that the `timestamp` is near the current time,
the EKcert (if provided, else the EKpub), the signature using the
asserted (but not yet bound to the EKpub) AKpub, then it will validate
the PCR quote and eventlog, and, if everything checks out, will issue a
certificate for the AKpub and return various secrets that the client may
need.

The client obtains those items IFF (if and only if) the AK is resident
in the same TPM as the EK, courtesy of `TPM2_ActivateCredential()`'s
semantics.

NOTE well that in single round trip attestation protocols using only
decrypt-only EKs it is *essential* that the AKcert not be logged in any
public place since otherwise an attacker can make and send `CS0` using a
non-TPM-resident AK and any TPM's EKpub/EKcert known to the attacker,
and then it may recover the AK certificate from the log in spite of
being unable to recover the AK certificate from `SC1`!

Alternatively, a single round trip attestation protocol can be
implemented as an optimization to a two round trip protocol when the AK
is persisted both, in the client TPM and in the attestation service's
database:

```
  <having previously successfully enrolled>

  CS0:  timestamp, AKpub, PCRs, eventlog,
        TPM2_Quote(AK, PCRs, extra_data)=Signed_AK({hash-of-PCRs, misc, extra_data})
  SC0:  {TPM2_MakeCredential(EKpub, AKpub, session_key),
         Encrypt_session_key({AKcert, filesystem_keys, etc.})}
```

### Three-Message Attestation Protocol Patterns

A single round trip protocol using encrypt-only EKpub will not
demonstrate proof of possession immediately, but later on when the
certified AK is used elsewhere.  A proof-of-possession (PoP) may be
desirable anyways for monitoring and alerting purposes.

```
  CS0:  [ID], EKpub, [EKcert], AKpub, PCRs, eventlog, timestamp,
        TPM2_Quote(AK, PCRs, extra_data)=Signed_AK({hash-of-PCRs, misc, extra_data})
  SC0:  {TPM2_MakeCredential(EKpub, AKpub, session_key),
         Encrypt_session_key({AKcert, filesystem_keys, etc.})}
  CS1:  AKcert, Signed_AK(AKcert)
```

![Protocol Diagram](Protocol-Three-Messages.png)

(In this diagram we show the use of a TPM simulator on the server side
for implementing [`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md).)

NOTE well that in this protocol, like single round trip attestation
protocols using only decrypt-only EKs, it is *essential* that the AKcert
not be logged in any public place since otherwise an attacker can make
and send `CS0` using a non-TPM-resident AK and any TPM's EKpub/EKcert
known to the attacker, and then it may recover the AK certificate from
the log in spite of being unable to recover the AK certificate from
`SC1`!

If such a protocol is instantiated over HTTP or TCP, it will really be
more like a two round trip protocol:

```
  CS0:  [ID], EKpub, [EKcert], AKpub, PCRs, eventlog, timestamp,
        TPM2_Quote(AK, PCRs, extra_data)=Signed_AK({hash-of-PCRs, misc, extra_data})
  SC0:  {TPM2_MakeCredential(EKpub, AKpub, session_key),
         Encrypt_session_key({AKcert, filesystem_keys, etc.})}
  CS1:  AKcert, Signed_AK(AKcert)
  SC1:  <empty>
```

### Two Round Trip Stateless Attestation Protocol Patterns

We can add a round trip to the protocol in the previous section to make
the client prove possession of the EK and binding of the AK to the EK
before it can get the items it needs.  This avoids the security
consideration of having to not log the AKcert.

Below is a sketch of a stateless, two round trip attestation protocol.

Actual protocols tend to use a secret challenge that the client echoes
back to the server rather than a secret key possesion of which is proven
with symmetriclly-keyed cryptographic algorithms.

```
  CS0:  [ID], EKpub, [EKcert], AKpub, PCRs, eventlog, timestamp,
        TPM2_Quote(AK, PCRs, extra_data)=Signed_AK({hash-of-PCRs, misc, extra_data})
  SC0:  {TPM2_MakeCredential(EKpub, AKpub, session_key), ticket}
  CS1:  {ticket, MAC_session_key(CS0), CS0}
  SC1:  Encrypt_session_key({AKcert, filesystem_keys, etc.})

  <extra_data includes timestamp>
```

where `session_key` is an ephemeral secret symmetric authenticated
encryption key, and `ticket` is an authenticated encrypted state cookie:

```
  ticket = {vno, Encrypt_server_secret_key({session_key, timestamp,
                                            MAC_session_key(CS0)})}
```

![Protocol Diagram](Protocol-Four-Messages.png)

where `server_secret_key` is a key known only to the attestation service
and `vno` identifies that key (in order to support key rotation without
having to try authenticated decryption twice near key rotation events).

[Note: `ticket` here is not in the sense used by TPM specifications, but
in the sense of "TLS session resumption ticket" or "Kerberos ticket",
and, really, it's just an encrypted state cookie so that the server can
be stateless.]

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

(The `server_secret_key`, `ticket`, `session_key`, and proof of
possession used in `CS1` could even conform to Kerberos or encrypted JWT
and be used for authentication, possibly with an off-the-shelf HTTP
stack.)

An HTTP API binding for this protocol could look like:

```
  POST /get-attestation-ticket
      Body: CS0
      Response: SC0

  POST /attest
      Body: CS1
      Response: SC1
```

Here the attestation happens in the first round trip, but the proof of
possession is completed in the second, and the delivery of secrets and
AKcert also happens in the second round trip.

### Actual Protocols: ibmacs

The [`IBM TPM Attestation Client Server`](https://sourceforge.net/projects/ibmtpm20acs/)
(`ibmacs`) open source project has sample code for a "TCG attestation
application".

It implements a stateful (state is kept in a database) attestation and
enrollment protocol over TCP sockets that consists of JSON texts of the
following form, sent prefixed with a 32-bit message length in host byte
order:

```
  CS0: {"command":"nonce","hostname":"somehostname",
        "userid":"someusername","boottime":"2021-04-29 16:37:06"}
  SC0: {"response":"nonce","nonce":"<hex>", "pcrselect":"<hex>", ...}

  <nonce is used in production of signed PCR quote>

  CS1: {"command":"quote","hostname":"somehostname",
        "quoted":"<hex>","signature":"<hex>",
        "event1":"<hex>","imaevent0":"<hex>"}
  SC1: {"response":"quote"}

  CS2: {"command":"enrollrequest","hostname":"somehost",
        "tpmvendor":"...","ekcert":"<PEM>","akpub":"<hex(DER)>"}
  SC2: {"response":"enrollrequest",
        "credentialblob":"<hex of credentialBlob output of TPM2_MakeCredential()>",
        "secret":"<hex of secret output of TPM2_MakeCredential()>"}

  CS3: {"command":"enrollcert","hostname":"somecert","challenge":"<hex>"}
  SC3: {"response":"enrollcert","akcert":"<hex>"}
```

The server keeps state across round trips.

Note that this protocol has *up to* four (4) round trips.  Because the
`ibmacs` server keeps state in a database, it should be possible to
elide some of these round trips in attestations subsequent to
enrollment.

The messages of the second and third round trips could be combined since
there should be no need to wait for PCR quote validation before sending
the EKcert and AKpub.  The messages of the first round trip too could be
combined with the messages of the second and third round trip by using a
timestamp as a nonce -- with those changes this protocol would get down
to two round trips.

### Actual Protocols: safeboot.dev

```
  CS0:  <empty>
  SC0:  nonce, PCR_list
  CS1:  [ID], EKpub, [EKcert], AKpub, PCRs, eventlog, nonce,
        TPM2_Quote(AK, PCRs, extra_data)=Signed_AK({hash-of-PCRs, misc, extra_data})
  SC1:  {TPM2_MakeCredential(EKpub, AKpub, session_key),
         Encrypt_session_key({filesystem_keys})}
```

Nonce validation is currently not well-developed in Safeboot.
If a timestamp is used instead of a nonce, and if the client assumes all
PCRs are desired, then this becomes a one round trip protocol.

An AKcert will be added to the Safeboot protocol soon.

## Attestation Protocol Patterns and Actual Protocols (signing-only EKs)

Some TPMs come provisioned with signing-only endorsement keys in
addition to decrypt-only EKs.  For example, vTPMs in Google cloud
provides both, decrypt-only and signing-only EKs.

Signing-only EKs can be used for attestation as well.

[Ideally signing-only EKs can be restricted to force the use of
`TPM2_Certify()`?  Restricted signing keys can only sign payloads that
start with a magic value, whereas unrestricted signing keys can sign any
payload.]

Signing-only EKs make single round trip attestation protocols possible
that also provide immediate attestation status because signing provides
proof of possession non-interactively, whereas asymmetric encryption
requires interaction to prove possession:

```
  CS0:  timestamp, [ID], EKpub, [EKcert], AKpub, PCRs, eventlog,
        TPM2_Certify(EKpub, AKpub), TPM2_Quote()
  SC0:  AKcert
```

If secrets need to be sent back, then a decrypt-only EK also neds to be
used:

```
  CS0:  timestamp, [ID], EKpub_signing, EKpub_encrypt,
        [EKcert_signing], [EKcert_encrypt], AKpub, PCRs, eventlog,
        TPM2_Certify(EKpub, AKpub), TPM2_Quote()
  SC0:  {TPM2_MakeCredential(EKpub_encrypt, AKpub, session_key),
         Encrypt_session_key({AKcert, filesystem_keys, etc.})}
```

# Long-Term State Kept by Attestation Services

Attestation servers need to keep some long-term state:

 - binding of `EKpub` and `ID`
 - PCR validation profile(s) for each identified client
 - resetCount (for reboot detection)

Log-like attestation state:

 - client attestation status (last time successfully attested, last time
   unsuccessfully attested)

The PCR validation profile for a client consists of a set of required
and/or acceptable digests that must appear in each PCR's extension log.
These required and/or acceptable digests may be digests of firmware
images, boot loaders, boot loader configurations (e.g., `menu.lst`, for
Grub), operating system kernels, `initrd` images, filesystem root hashes
(think ZFS), etc.

Some of these are obtained by administrators on a trust-on-first-use
(TOFU) basis.

Things to log:

 - client attestation attempts and outcomes
 - AK certificates issued (WARNING: see note about single round trip
   attestation protocols above -- do not log AKcerts in public places
   when using single round trip attestation protocols!)

## Long-Term State Created or Updated by Attestation Services

 - An attestation service might support creation of host&lt;-&gt;EKpub
   bindings on a first-come-first-served basis.  In this mode the
   attestation server might validate an EKcert and that the desired
   hostname has not been bound to an EK, then create the binding.

 - An attestation service might support deletion of host PCR validation
   profiles that represent past states upon validation of PCR quotes
   using newer profiles.  This could be used to permit firmware and/or
   operating system upgrades and then disallow downgrades after evidence
   of successful upgrade.

 - An attestation service might keep track of client reboots so as to:
    - revoke old AKcerts when the client reboots (but note that this is
      really not necessary if we trust the client's TPM, since then the
      previous AKs will never be usable again)
    - alert if the reboot count ever goes backwards

## Schema for Attestation Server Database

A schema for the attestation server's database entries might look like:

```JSON
{
  "EKpub": "<EKpub>",
  "hostname": "<hostname>",
  "EKcert": "<EKcert in PEM, if available>",
  "previous_firmware_profile": "FWProfile0",
  "current_firmware_profiles": ["FWProfile1", "FWProfile2", "..."],
  "previous_operating_system_profiles": "OSProfile0",
  "current_operating_system_profiles": ["OSProfile1", "OSProfile2", "..."],
  "previous_PCRs": "<...>",
  "proposed_PCRs": "<...>",
  "ak_cert_template": "<AKCertTemplate>",
  "resetCount": "<resetCount value from last quote>",
  "secrets": "<see below>"
}
```

The attestation server's database should have two lookup keys:

 - EKpub
 - hostname

The attestation server's database's entry for any client should provide,
de minimis:

 - a way to validate the root of trust measurements in the client's
   quoted PCRs, for which two methods are possible:
    - save the PCRs quoted last as the ones expected next time
    - or, name profiles for validating firmware RTM PCRs and profiles
      for validating operating system RTM PCRs

A profile for validating PCRs should contain a set of expected extension
values for each of a set of PCRs.  The attestation server can then check
that the eventlog submitted by the client lists exactly those extension
values and no others.  PCR extension order in the eventlog probably
doesn't matter here.  If multiple profiles are named, then one of those
must match -- this allows for upgrades and downgrades.

```JSON
{
  "profile_name":"SomeProfile",
  "values":[
    {
      "PCR":0,
      "values":["aaaaaaa","bbbbbb","..."]
    },
    {
      "PCR":1,
      "values":["ccccccc","dddddd","..."]
    }
  ]
}
```

Using the PCR values from the previous attestation makes upgrades
tricky, probably requiring an authenticated and authorized administrator
to bless new PCR values after an upgrade.  A client that presents a PCR
quote that does not match the previous one would cause the
`proposed_PCRs` field to be updated but otherwise could not continue,
then an administrator would confirm that the client just did a
firmware/OS upgrade and if so replace the `previous_PCRs` with the
`proposed_PCRs`, then the client could attempt attestation again.

# Delivery of Secrets to Attestation Clients

An attestation server might have to return storage/filesystem decryption
key-encryption-keys (KEKs) to a client.  But one might not want to store
those keys in the clear on the attestation server.  As well, one might
want a break-glass way to recover those secrets.

Possible goals:

 - store secrets that clients need on the attestation server
 - do not store plaintext or plaintext-equivalent secrets on the
   attestation server
 - allow for adding more secrets to send to the client after enrollment
 - provide a break-glass recovery mechanism

Note that in all cases the client does get direct access to various
secrets.  Using a TPM to prevent direct software access to those secrets
would not be performant if, for example, those secrets are being used to
encrypt filesystems.  We must inherently trust the client to keep those
secrets safe when running.

## Break-Glass Recovery

For break-glass recovery, the simplest thing to do is to store
`Encrypt_backupKey({EKpub, hostname, secrets})`, where `backupKey` is an
asymmetric key whose private key is stored offline (e.g., in a safe, or
in an offline HSM).  To break the glass and recover the key, just bring
the ciphertext to the offline system where the private backup key is
kept, decrypt it, and then use the secrets manually to recover the
affected system.

## Secret Transport Sub-Protocols

Here we describe several possible sub-protocols of attestation protocols
for secret transport.  This list is almost certainly not exhaustive.

### Store a `TPM2_MakeCredential()` Payload

[`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md) and
[`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md)
are a form of limited asymmetric encryption (`TPM2_MakeCredential()`)
and asymmetric decryption (`TPM2_ActivateCredential()`) subject to the
sender's choice of authorization.  The details are explained
[here](/TPM-Commands/TPM2_MakeCredential.md) and
[here](/TPM-Commands/TPM2_ActivateCredential.md).  Basically, there are
two TPM key objects involved:

 - a transport key (typically the `EK`),
 - and an authorization key (typically an `AK`)

and the caller of `TPM2_MakeCredential()` must specify the public part
of the transport key and the
[name](/Intro/README.md#Cryptographic-Object-Naming) of the
authorization key, along with a small secret to transport.  The caller
of `TPM2_ActivateCredential()` must then provide the handles for those
two key objects and the outputs of `TPM2_MakeCredential()` in order to
extract the small secret.  Typically the small secret is an AES key for
encrypting larger secrets.

So if we can store the outputs of `TPM2_MakeCredential()` long-term so
that the client can activate over multiple reboots, then we have a way
to deliver secrets to the client.

We'll discuss two ways to do this:

 - use a `WK` -- a universally well-known key (thus WK, for well-known)

   Since the `WK`'s private area is not used for any cryptography in
   `TPM2_MakeCredential()`/`TPM2_ActivateCredential()`, it can be a key
   that everyone knows.

   Note that the `WK`'s public area can name arbitrary an auth policy,
   and `TPM2_MakeCredential()` will enforce it.

   E.g., the `WK` could be the all-zeros AES key.  Its policy could be
   whatever is appropriate for the organization.  For example, the
   policy could require that some non-resettable application PCR have
   the value zero so that extending it can disable use of
   `TPM2_MakeCredential()` post-boot.

 - use an `LTAK` -- a long-term `AK`

   I.e., an `AK` that lacks the `stClear` attribute, and _preferably_
   created deterministically with either
   [`TPM2_CreateLoaded()`](/TPM-Commands/TPM2_CreateLoaded.md) or
   [`TPM2_CreatePrimary()`](/TPM-Commands/TPM2_CreatePrimary.md).

   > Note that the `LTAK` need not be a primary.

   > If the `LTAK` were created with
   > [`TPM2_Create()`](/TPM-Commands/TPM2_Create.md) then the key's saved
   > context file would have to be stored somewhere so that it could be
   > loaded again on next boot with
   > [`TPM2_Load()`](/TPM-Commands/TPM2_Load.md).  Whereas creating it
   > deterministically means that it can be re-created every time it's
   > needed using the same hiercarchy, template, and entropy as
   > arguments to `TPM2_CreatePrimary()` or `TPM2_CreateLoaded()`

   Note that the `AK`'s public area can name arbitrary an auth policy,
   and `TPM2_MakeCredential()` will enforce it.

The best option here is to use a `WK` because using an `LTAK` would
require recording its public key in the device's enrolled attestation
state, which would complicate enrollment, whereas the `WK`, being
well-known and the same for all cases, would not need to be recorded in
server-side attestation state.

> One might like to use the `EK` as the `activateHandle`.  Sadly, this
> is not possible.
> While `TPM2_MakeCredential(EKpub, EKname, input)` works,
> `TPM2_ActivateCredential(EK, EK, credentialBlob, secret)` does not
>  and cannot.
>
> The reason for this is that `TPM2_ActivateCredential()` requires
> `ADMIN` role for the `activateHandle`, and since the `EK` has
> `adminWithPolicy` attribute set and its policy doesn't have the
> `TPM_CC_ACTIVATECREDENTIAL` command permitted, the call must fail.
>
> Credit for the `WK` idea goes to [Erik > Larsson](https://developers.tpm.dev/chats/new?user_id=4336638).

Normally during attestation we want to use an `AK` with `stClear` set so
that each boot forces the client to use a new one.  However, for sending
secrets to the client via `TPM2_MakeCredential()` /
`TPM2_ActivateCredential()` we really need need the `activateHandle`
object to not have `stClear` set.

For this approach then, the best solution is to use a `WK`.

```
  CS0:  timestamp, AKpub, PCRs, eventlog,
        TPM2_Quote(AK, PCRs, extra_data)=Signed_AK({hash-of-PCRs, misc, extra_data})
  SC0:  {TPM2_MakeCredential(EKpub, AKname, session_key),
         Encrypt_session_key(long_term_Credential)}

    where

      long_term_Credential = TPM2_MakeCredential(EKpub, WKname, secrets)
```

New secrets can be added at any time without interaction with the
client if the attestation server recalls the `LTAKname`.

The schema for storing secrets transported this way would be:

```JSON
{
  "EKpub": "<EKpub>",
  "hostname": "<hostname>",
  "EKcert": "<EKcert in PEM, if available>",
  "previous_firmware_profile": "FWProfile0",
  "current_firmware_profiles": ["FWProfile1", "FWProfile2", "..."],
  "previous_operating_system_profiles": "OSProfile0",
  "current_operating_system_profiles": ["OSProfile1", "OSProfile2", "..."],
  "previous_PCRs": "<...>",
  "proposed_PCRs": "<...>",
  "resetCount": "<resetCount value from last quote>",

  "secret store and transport fields":"vvvvvvvvvvvvvvvvvv",

  "secrets": ["<MakeCredential_0>", "<MakeCredential_1>", "..", "<MakeCredential_N>"]
  "secrets_backup": ["<RSA_Encrypt_to_backup_key(...)", "..."],
}
```

### Use an Unrestricted Decryption Transport Key (TK) for Secret Transport (client-side)

Another option is to generate an asymmetric key-pair at device
enrollment time (we shall call this the "transport key", or `TK`), and
store:

 - the `TKpub`, and

 - zero, one, or more secrets encrypted in the `EKpub`.

The client has to use
[`TPM2_CreatePrimary()`](/TPM-Commands/TPM2_CreatePrimary.md) or
[`TPM2_CreateLoaded()`](/TPM-Commands/TPM2_CreateLoaded.md) in order to
deterministically create the same `TK` (without the `stClear`)
attribute, else if it uses
[`TPM2_Create()`](/TPM-Commands/TPM2_Create.md) then it must store the
key save file somewhere (possibly in the attestation server!) or make
the key object persistent.

New secrets can be added at any time without interaction with the
client.

```JSON
{
  "EKpub": "<EKpub>",
  "hostname": "<hostname>",
  "EKcert": "<EKcert in PEM, if available>",
  "previous_firmware_profile": "FWProfile0",
  "current_firmware_profiles": ["FWProfile1", "FWProfile2", "..."],
  "previous_operating_system_profiles": "OSProfile0",
  "current_operating_system_profiles": ["OSProfile1", "OSProfile2", "..."],
  "previous_PCRs": "<...>",
  "proposed_PCRs": "<...>",
  "ak_cert_template": "<AKCertTemplate>",
  "resetCount": "<resetCount value from last quote>",

  "secret store and transport fields":"vvvvvvvvvvvvvvvvvv",

  "TKpub": "<TKpub in PEM>",
  "secrets": ["<RSA_Encrypt_0>", "<RSA_Encrypt_1>", "..", "<RSA_Encrypt_N>"]
  "secrets_backup": ["<RSA_Encrypt_to_backup_key(...)", "..."],
}
```

### Use an Unrestricted Decryption Transport Key (TK) for Secret Transport (server-side)

Another option is to generate an asymmetric key-pair at device
enrollment time (we shall call this the "transport key", or `TK`), and
store:

 - the TK exported to the client device's TPM (i.e., the output of
   `TPM2_Duplicate()` called on that private key to export it to the
   client's TPM's EKpub), and

 - the ciphertext resulting from encrypting long-term secrets to that
   TK.

At attestation time the server can send back these two values to the
client, and then the client can `TPM2_Import()` and then `TPM2_Load()`
the duplicated (exported) TK, then use it to `TPM2_RSA_Decrypt()` the
encrypted long-term secrets.

New secrets can be added at any time without interaction with the
client.

```JSON
{
  "EKpub": "<EKpub>",
  "hostname": "<hostname>",
  "EKcert": "<EKcert in PEM, if available>",
  "previous_firmware_profile": "FWProfile0",
  "current_firmware_profiles": ["FWProfile1", "FWProfile2", "..."],
  "previous_operating_system_profiles": "OSProfile0",
  "current_operating_system_profiles": ["OSProfile1", "OSProfile2", "..."],
  "previous_PCRs": "<...>",
  "proposed_PCRs": "<...>",
  "ak_cert_template": "<AKCertTemplate>",
  "resetCount": "<resetCount value from last quote>",

  "secret store and transport fields":"vvvvvvvvvvvvvvvvvv",

  "TKdup": "<output of TPM2_Duplicate(EKpub, TK)>",
  "TKpub": "<TKpub in PEM>",
  "secrets": ["<RSA_Encrypt_0>", "<RSA_Encrypt_1>", "..", "<RSA_Encrypt_N>"]
  "secrets_backup": ["<RSA_Encrypt_to_backup_key(...)", "..."],
}
```

### Store a Secret PCR Extension Value for Unsealing Data Objects

The attestation server could store in plaintext a secret that it will
returned encrypted to the client's EKpub vias `TPM2_MakeCredential()`,
and which the client must use to extend a PCR (e.g., the debug PCR) to
get that PCR into the state needed to unseal a persistent data object on
the TPM.

Because the sealed data object may itself be stored in cleartext in the
TPM's NVRAM, and because an attacker might be able to decap a stolen
client device's TPM and recover the TPM's NVRAM contents and seeds, the
client might store an encrypted value in that sealed data object that
the TPM does not have the keey to decrypt.  The decryption key would be
sent by the attestation server (possibly being the same secret as is
extended into that PCR).

```JSON
{
  "EKpub": "<EKpub>",
  "hostname": "<hostname>",
  "EKcert": "<EKcert in PEM, if available>",
  "previous_firmware_profile": "FWProfile0",
  "current_firmware_profiles": ["FWProfile1", "FWProfile2", "..."],
  "previous_operating_system_profiles": "OSProfile0",
  "current_operating_system_profiles": ["OSProfile1", "OSProfile2", "..."],
  "previous_PCRs": "<...>",
  "proposed_PCRs": "<...>",
  "ak_cert_template": "<AKCertTemplate>",
  "resetCount": "<resetCount value from last quote>",

  "secret store and transport fields":"vvvvvvvvvvvvvvvvvv",

  "unseal_key": "<key>",
  "secrets_backup": ["<RSA_Encrypt_to_backup_key(...)", "..."],
}
```

### Store Secrets in Plaintext, Encrypt to EKpub Using `TPM2_MakeCredential()`

As the title says, one option is to store the secrets in plaintext and
send them encrypted to the EKpub via
[`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md).
Because [`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md)
encrypts only a small secret, it goes without saying that that secret
would be a one-time use symmetric encryption key that would be used to
encrypt the actual secrets.

This is, naturally, the least desirable option.

```JSON
{
  "EKpub": "<EKpub>",
  "hostname": "<hostname>",
  "EKcert": "<EKcert in PEM, if available>",
  "previous_firmware_profile": "FWProfile0",
  "current_firmware_profiles": ["FWProfile1", "FWProfile2", "..."],
  "previous_operating_system_profiles": "OSProfile0",
  "current_operating_system_profiles": ["OSProfile1", "OSProfile2", "..."],
  "previous_PCRs": "<...>",
  "proposed_PCRs": "<...>",
  "ak_cert_template": "<AKCertTemplate>",
  "resetCount": "<resetCount value from last quote>",

  "secret store and transport fields":"vvvvvvvvvvvvvvvvvv",

  "secrets": ["<secret_0>", "<secret_1>", "<secret_N>"]
}
```

# Security Considerations

TBD

# References

 - [TCG TPM Library part 1: Architecture, sections 23 and 24](https://trustedcomputinggroup.org/wp-content/uploads/TCG_TPM2_r1p59_Part1_Architecture_pub.pdf)
 - https://sourceforge.net/projects/ibmtpm20acs/
 - https://safeboot.dev/
 - https://github.com/osresearch/safeboot/
