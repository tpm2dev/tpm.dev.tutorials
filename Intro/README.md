# Introduction to TPMs

Trusted Platform Modules (TPMs) are a large and complex topic, made all
the more difficult to explain by the intricate relationships between the
relevant concepts.  This is an attempt at a simple explanation --
simpler than reading hundreds of pages of documents, but then too, too
light on detail to be immediately useful.

So what is a TPM?  Well, it's a cryptographic co-processor with special
features to enable "root of trust measurement" (RTM), remote attestation
of system state, unlocking of local resources that are kept encrypted
(e.g., filesystems), and more.  A TPM can do those things, and it can do
it with rich authentication and authorization policies.

Typically a TPM is a hardware module, a chip, though there are firmware,
virtual, and simulated TPMs as well, all implemented in software.

To simplify things we'll consider only TPM 2.0.  Also to simplify things
we'll ignore algorithm agility.

Other parts of this [tutorial](README.md) may cover specific concepts in
much more detail.

# Core Concepts

Some core concepts in the world of TPMs (not all of which we'll discuss
here):

 - cryptography
 - hash extension
 - cryptographic object naming
 - platform configuration registers (PCRs)
 - immutability of object public areas
 - key hierarchies
 - key wrapping
 - limited resources
    - tickets
    - resource management
 - sessions
 - authorization
    - restricted cryptographic keys
    - policies
 - other object types
    - non-volatile (NV) indexes
 - attestation

We'll assume reader familiarity with cryptography so we need not explain
it.

Authorization is the most important aspect of a TPM, since that's
ultimately what it exists for: to authorize a system or application to
perform certain duties when all the desired conditions allow for it.

TPMs have a very rich set of options for authorization.  It's not just
[policies](#Policies), but also cryptographic object names used with
restricted keys to allow access only to applications that also have
other access.

Where to start?  Let's start with hash extension, which may be the only
trivial concept in the world of TPMs!

## Hash Extension

Hash extension is just appending some data to a current digest-sized
value, hashing that, and then calling the output the new current value:

```
  v_0 = 0         # size-of-digest-output zero bits
  v_1 = Extend(v_0, e_0)
      = H(v_0 || e_0)
  v_2 = Extend(v_1, e_1)
      = H(v_1 || e_1)
      = H(H(v_0 || e_0) || e_1)
  v_3 = Extend(v_2, e_2)
      = H(v_2 || e_2)
      = H(H(v_1 || e_1) || e_2)
      = H(H(H(v_0 || e_0) || e_1) || e_2)
  ..
  v_n = Extend(v_n-1, e_n-1)
      = H(v_n-1 || e_n-1)
      = H(H(v_n-2 || e_n-2) || e_n-1)
      = H(H(...) || e_n-1)
```

where `H()` is a cryptographic hash function.

Each extension value can be arbitrarily large, and the TPM will use the
traditional `Init`/`Update`/`Final` approach to making digest
computation online.

Note that `H(e0 || e1 || e2) != Extend(Extend(Extend(0, e0), e1), e2)`.
Hash extension makes "message" boundaries strong.

Hash extension is most of what a PCR is, but hash extension is in other
TPM concepts besides PCRs, such as policy naming.

## Platform Configuration Registers (PCRs)

A PCR, then, is just a hash extension output.  The only operations on
PCRs are: read, extend, and reset.  All richness of semantics of PCRs
come from how they are used:

 - how they are extended and by what code
 - what purposes they are read for
    - attestation
    - authorization

Note that a PCR value by itself is devoid of meaning.  To add meaning
one must have access to the list of discrete values extended into the
PCR, as well as the order in which they were extended into the PCR.  And
one must know the meaning of each such value.

### Eventlogs

Any TPM-using platform has to provide a way to keep a log of PCR hash
extension values.  Such a log is known as the "eventlog".

The TPM itself cannot hold this log for the TPM is resource-constrained.

Indeed, hash extension is used by TPMs as a sort of a compression
function that represents a larger state that may not fit on the TPM.
PCRs are one case, and authorization policies are another.

## Root of Trust Measurements (RTM)

When a computer and its TPM start up, most PCRs are set to all-zeros,
and then the computer's boot firmware performs a core root of trust
measurement (CRTM) to "measure" (i.e., hash) the the next boot stage and
extend it into an agreed-upon PCR.  The entire boot process should,
ideally, perform RTMs.  At the end of the boot process some set of PCRs
should reflect the totality of the code path taken to complete booting.

Some PCRs are used to measure the BIOS, others to measure option ROMs,
and others to measure the operating system.  Each platform has a
specification for which PCRs are used or reserved for what purposes.  In
principle one could measure the entirety of an operating system and all
the code that is installed on the system.

RTM can be used to ensure that only known-trusted code is executed, and
that important resources are not unlocked unless the state of the system
when they are needed is "only executed trusted code".

Note that some PCRs are left to be used by "applications".

Some terms:

 - core RTM (CRTM) -- initial measurements performed upon power-on
 - static RTM (SRTM) -- subsequent-to-CRTM measurements of next boot
   stages
 - dynamic RTM (DRTM) -- measurements involved in rebooting

Resource unlocking can be done by creating objects tied to a set of PCRs
such that they must each have specific values for the TPM to be willing
to unlock (unseal) the object.

### The PCR Extension Eventlog

On the "PC platform" (which includes x64 servers) the BIOS keeps a log
of all the PCR extensions it has performed.  The OS should keep its own
log of extensions it performs of PCRs reserved to the OS.  Each
application has to keep a log of the extensions of the PCRs allocated to
it.  Again, the TPM itself cannot do this.

The eventlog documents how the PCRs evolved to their current state,
whatever it might be.  Since PCR extension values are typically digests,
the eventlog is very dry, but it can still be used to evaluate whether
the current PCR values represent a trusted state.  For example, one
might have a database of known-good and known-bad firmware/ROM digests,
then one can check that only known-good ones appear in the eventlog and
that reproducing the hash extensions described by the eventlot produces
the same PCR values as one can read, and if so it follows that the
system has only executed trusted code.

Note though that PCRs and RTM are not enough on their own to keep a
system from executing untrusted code.  A system can be configured to
allow execution of arbitrary code at some point (e.g., download and
execute) and to not extend PCRs accordingly, in which case the execution
of untrusted code will not be reflected in any RTM.

## Object Naming

TPMs support a variety of types of objects.  Objects generally have
pointer-like "handles" that they are often used in the TPM APIs.  But
more importantly, objects have cryptographically-secure names that are
used in many cases.

  The cryptographically-secure name of an object is the hash of the
  object's "public area".

The public area of, say, an asymmetric key is a data structure that
includes the public key (corresponding to the private key), and various
attributes of the key (e.g., its algorithm, but also whether it is bound
to the TPM where it resides, or to its key hierarchy), unseal policy,
and access policy.

This concept is extremely important.  Because object names are the
outputs of cryptographically strong digest (hash) functions, they are
resistant to collision attacks, first pre-image attacks, and second
pre-image attacks -- as strong as the hash algorithm used anyways.
Which means that object names cannot be forged easily, which means that
they can be used in context where a peer needs certain guarantees, or
to defeat active attacks.

### Immutability of Object Public Areas

Because the name of an object is a digest of its public area, the public
area cannot be changed after creating it.  One can delete and then
recreate an object in order to "change" its public area, but this
necessarily yields a new name (assuming no digest collisions).

### Cryptographic Object Naming as a Binding

> This section comes too soon, since it relates to attestation and
> restricted keys.  Still, it may be useful to illustrate cryptographic
> object naming with one particularly important use of it.

A pair of functions, `TPM2_MakeCredential()` and
`TPM2_ActivateCredential()`, illustrate the use of cryptographic object
naming as a binding or a sort of authorization function.

`TPM2_MakeCredential()` can be used to encrypt a datum (a "credential")
to a target TPM such that the target will _only be willing to decrypt
it_ if *and only if* the application calling `TPM2_ActivateCredential()`
to decrypt that credential has access to some key named by the sender,
and that name is a cryptographic name that the sender can and must
compute for itself.

The semantics of these two functions can be used to defeat a
cut-and-paste attack in attestation protocols.

## Key Hierarchies

TPMs have multiple key hierarchies, all rooted in a primary decrypt-only
asymmetric private key derived from a seed, with arbitrarily complex
trees of keys below the primary key:

```
                seed
                 |
                 |
                 v
     primary key (asymmetric encryption)
                 |
                 |
                 v
       secondary keys (of any kind)
                 |
                 |
                 v
                ...
```

There are three built-in hierarchies:

 - platform hierarchy
 - endorsement hierarchy
 - storage hierarchy

of which only the endorsement and storage hierarchies will be of
interest to most readers.

The endorsement hierarchy is used to authenticate (when needed) that a
TPM is a legitimate TPM.  The primary endorsement key is known as the EK
(endorsement key).  Hardware TPMs come with a certificate for the EK
issued by the TPM's manufacturer.  This EK certificate ("EKcert") can be
used to authenticate the TPM's legitimacy.  The EK's public key
("EKpub") can be used to uniquely identify a TPM, and possibly link to
the platform's, and even the platform's user(s)' identities.

## Key Wrapping and Resource Management

The primary key is always a decrypt-only asymmetric private key, and its
corresponding public key is therefore encrypt-only.  This is largely
because of key wrapping, where a symmetric key or asymmetric private key
is encrypted to a TPM's EKpub so that it can be safely sent to that TPM
so that that TPM can then decrypt and use that secret.

As well as wrapping secrets by encryption to public keys, TPMs also use
wrapping in a symmetric key known only to the TPM for the purpose of
saving keys off the TPM.  This is used for resource management: since
hardware TPMs have very limited resources, objects need to created or
loaded, used, then saved off-TPM to make room for other objects to be
loaded (unless they are not to be used again, then saving them is
pointless).  Only a TPM that saved an object can load it again, but some
objects can be exported to other TPMs by encrypting them to their
destination TPMs' EKpubs.

### Controlling Exportability of Keys

A key that is `fixedTPM` cannot leave the TPM in cleartext.  It can be
saved off the TPM it resides in, but only that TPM can load it again.

A key that is `fixedParent` cannot be re-parented, though if its parent
is neither `fixedParent` nor `fixedTPM` then the parent and its
descendants can be moved as a group to some other TPM.

## Persistence

Cryptographic keys are, by default, not stored on non-volatile memory.
Hardware TPMs have very little non-volatile (NV) memory.  They also have
very limited volatile memory as well.

PCRs always exist, but they get reset on restart.

Keys can be moved to NV storage.

## Non-Volatile (NV) Indexes

TPMs also have a special kind of non-volatile object: NV indexes.

NV indexes come in multiple flavors for various uses:

 - store public data (e.g., an NV index is used to store the EKcert)
 - emulate PCRs
 - monotonic counters
 - fields of write-once bits (for, e.g., revocation)
 - ...

NV indexes can be used standalone, and/or in connection with policies,
to enrich application TPM semantics.

## Authentication and Authorization

TPMs have multiple ways to authenticate users/entities:

 - plain passwords (legacy)
 - HMAC based on secret keys or passwords
 - public key signed attestations of identification by biometric
   authentication devices

TPMs have two ways to authorize access to various objects:

 - plain passwords (legacy)
 - HMAC proof of possession of a secret key or password
 - arbitrarily complex policies that can make reference to:
    - PCR state
    - NV index state
    - time of day
    - authentication state
    - etc.

### Policies

A policy consists of a sequence of "commands" that each asserts
something of interest.

Policies are particularly interesting because they are cryptographically
named using hash extension with the sequence of "commands" that make up
a policy.  Therefore no matter how complex and large a policy is, it is
always "compressed" to a hash digest.

It is the responsibility of the application that will attempt to use a
policy-protected resource to know what the policy's definition is and
restate it to the TPM when it goes to make use of that resource.  Thus,
and because policies are `O(1)` in storage size, they can be arbitrarily
more complex than a TPM's limited resources would otherwise allow.

All the policy commands that are to be evaluated successfully to grant
access have to be known to the entity that wants that access.  Of
course, that entity will have to satisfy -at access time- the conditions
expressed by the relevant policy.  The application has to know the
policy because the TPM knows only a digest of it.

### Policy Construction

Construction of a policy consists of computing it by hash extending an
initial all-zeroes value with the commands that make up the policy.

### Policy Evaluation

Evaluation of a policy consists of issuing those same commands to the
TPM in a session, with those commands either evaluated immediately or
deferred to the time of execution of the to-be-authorized command, but
the TPM computes the same hash extension as it goes.  Once all policy
commands being evaluated have succeeded, the resulting hash extension
value is compared to the policy that protects the resource(s) being used
by the to-be-authorized command, and if it matches, then the command is
allowed, otherwise it is not.

### Indirect Policies

Because an object's policy is part of its name, that policy cannot be
changed after creation.  An indirect policy command allows for the
inclusion of a policy stored in an NV index.

### Compound Policies

Policies consist of a conjunction (logical-AND) of assertions that must
be true at evaluation time.

However, there is a special policy command that allows for alternation
(logical-OR).  This policy command has a number of alternative policy
digests.  At evaluation time, one of the alternation digests must match
the extension value for the policy commands up to (but excluding) the
logical-OR policy command.  At evaluation time the caller must have
picked one of the alternatives and executed the commands that make it
up.

(Recall that the application has to know the definition of the policy
because the TPM knows only the policy's digest.)

### Rich Policy Semantics

With all these features, and with all the flexibility allowed by NV
indexes, policies can be used to:

 - require that N-of-M users authenticate
 - enforce bank vault-like time of day restrictions
 - require multi-factor authentication (password, biometric, smartcard)
 - check revocation
 - check system RTM state
 - distinguish user roles (admin roles get access to some resources,
   user roles get access to other resources)

## Sessions

A session is an object (meaning, among other things, that it can be
loaded and unloaded as needed) that represents the current policy
construction or evaluation hash extension digest (the `policyDigest`),
and the objects that have been granted access.

## Restricted Cryptographic Keys

Cryptographic keys can either be unrestricted or restricted.

An unrestricted signing key can be used to sign arbitrary content.

A restricted signing key can be used to sign only content that begins
with a magic byte sequence, and which the TPM allows only to be used in
certain operations.

A restricted decryption key can only be used to decrypt ciphertexts
whose plaintexts have a certain structure.  In particular these are used
for `TPM2_MakeCredential()`/`TPM2_ActivateCredential()` to allow the
TPM-using application to get the plaintext if and only if (IFF) the
plaintext cryptographically names an object that the application has
access to.  This is used to communicate secrets ("credentials") to TPMs.

## Attestation

Attestation is the process of demonstrating that a system's current
state is "trusted", or the truthfulness of some set of assertions.

As you can see in our [tutorial on attestation](Attestation/README.md),
many TPM concepts can be used to great effect:

 - using PCRs to attest to system state
 - using policies and sealed-to-PCRs objects to attest to authentication
   events on the system
 - using restricted keys and cryptographic object naming to authenticate
   a TPM and bind it to its host
 - delivering key material to authenticated systems via their TPMs
 - unlocking resources following successful attestation
 - authorization of devices onto a network
 - etc.

