# Passing a secret to a TPM using only the public key of Endorsement Key (EK)

This is example code to pass a secret to a system by just knowing its endorsenment key's public key.
We will be using the current (commit 07a92e9fa75548ea102ce90b3b6182093b3f7a73 or later) master branch of https://github.com/tpm2-software/tpm2-pytss

The terms for the systems are `client`, the system we want to pass the secret to and `server`, the system which has the secret but doesn't need a TPM.
One assumtion that will be made is that you already have the EKpub for the remote system on the local system, and trust it.
While we will use the EK in this guide any key accepted by ActivateCredential should work.

## Background

What we want is something akin to asymmetric encryption, with the local
system encrypting to the public key of the remote system.  The local
system would send the ciphertext to the remote system, and the remote
system would decrypt it using its private key.

The TPM does support plain asymmetric decryption using
`TPM2_RSA_Decrypt()`.  However, the `EK` is a [restricted
key](/Intro/README.md#Restricted-Cryptographic-Keys), specifically a
[restricted decryption key](/Intro/README.md#Restricted-Decryption-Keys)
which means that `TPM2_RSA_Decrypt()` will not work.

The TPM supports two constrained asymmetric decryption operations with
[restricted decryption
keys](/Intro/README.md#Restricted-Decryption-Keys):

 - [`TPM2_Import()`](/TPM-Commands/TPM2_Import.md)
 - [`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md)

The sender sides of those two functions are, respectively:

 - [`TPM2_Duplicate()`](/TPM-Commands/TPM2_Duplicate.md)
 - [`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md)

`TPM2_Duplicate()`/`TPM2_Import()` are specifically about sharing
private key objects from one TPM to another.  We won't use those here.

[`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md) allows
us to encrypt a small secret (e.g., an AES key) to a remote system's
`EKpub`, and then the remote system can decrypt that with its `EK` using
[`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md).

The key background concepts here are:

 - [restricted decryption keys](/Intro/README.md#Restricted-Decryption-Keys),
 - and access controlled decryption with restricted decryption keys.

Most importantly,
[`TPM2_MakeCredential()`](/TPM-Commands/TPM2_MakeCredential.md) allows
the sender to specify an authorization policy that the caller of
[`TPM2_ActivateCredential()`](/TPM-Commands/TPM2_ActivateCredential.md)
must meet in order for it to be willing to decrypt the ciphertext.

> Note that `TPM2_MakeCredential()` can be implemented entirely in
> software.

> Note that duplicating a key that is fixed to TPMs requires using
> `TPM2_Duplicate()` on that TPM, otherwise if the key is not fixed to
> the TPM then `TPM2_Duplicate()` can be implemented in software.

## Concept

`TPM2_MakeCredential()` requires three inputs.  Besides the target's
`EKpub` and the small secret to send to it, `TPM2_MakeCredential()` also
requires the [cryptographic name](/Intro/README.md#Cryptographic-Object-Naming)
of a key object that must reside on the target system's TPM -- this is
known as the _activation object_.

The key insight is that the actual public key of the object named by the
activation object name input of `TPM2_MakeCredential()` is not used at
all.  Neither does `TPM2_ActivateCredential()` use the private key of
that object.  The only things that matter about the activation object
are that:

a) it must exist on the target system,
b) its cryptographic name must be the same as was used on the sender side,
c) and that the caller of `TPM2_ActivateCredential()` must satisfy the activation object's [_authorization policy_](/Intro/README.md#Policies) (_if_ `adminWithPolicy` is set as an attribute of the activation object).

> NOTE: The cryptographic name of an object binds the authorization
> policy set on that object.  Therefore the caller of
> `TPM2_MakeCredential()` specifies an authorization policy that the
> caller of `TPM2_ActivateCredential()` must meet if the
> `adminWithPolicy` attribute is set on the activation object.

> NOTE: Learn more about [restricted keys](/Intro/README.md#Restricted-Cryptographic-Keys),
> [authorization policies](/Intro/README.md#Policies), and
> user roles in our [introductory tutorial](/Intro/README.md).

Since the private and public key parts of the activation object are not
used and are irrelevant, they can even be fixed and published for all to
see, even the private key.

By using a well-known activation key we can avoid having to know the
cryptographic name of some unique object on the remote system's TPM!

Or we can generate a unique key but send its private part in the clear
to the remote system.

Thus we need only know the target system's TPM's `EKpub`.

## server script

```python
#!/usr/bin/python3

import sys
from tpm2_pytss import *
from tpm2_pytss.makecred import MakeCredential
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat, PrivateFormat, NoEncryption

def main(ekpath, publicpath, sensitivepath, credpath, secretpath, oursecret):
    # first read the EK and unmarshal it
    with open(ekpath, 'rb') as ef:
        ekb = ef.read()
    ekpub, _ = TPM2B_PUBLIC.Unmarshal(ekb)

    # Now we generate the temporary key pair
    # We are using ECC keys here as they are generally fast to generate, but RSA should work as well
    # We will use the curve SECP256R1 as it should work on all TPMs
	# One could use a well known/the same pre-generated key for multiple systems
    privatekey = ec.generate_private_key(ec.SECP256R1, backend=default_backend())
    publickey = privatekey.public_key()
    
    # Now it's time to TPM structures from the keys
    # First we need to encode it due to how the tpm2_pytss API currently works
    privateenc = privatekey.private_bytes(Encoding.DER, PrivateFormat.PKCS8, NoEncryption())
    publicenc = publickey.public_bytes(Encoding.DER, PublicFormat.SubjectPublicKeyInfo)
    sensitive = TPM2B_SENSITIVE.fromPEM(privateenc)
    # by objectAttributes to 0 we reduce the change that keys will be used for anything
    public = TPM2B_PUBLIC.fromPEM(publicenc, objectAttributes=0)
    # the same applices to authPolicy
    public.publicArea.authPolicy = b"\x00" * 32

    # now it's time to run the MakeCredential part, using the software implementation in tpm2_pytss
    # the API is slight different to the standard, but behaves the same
    credblob, secret = MakeCredential(ekpub, oursecret, bytes(public.getName()))

    # time to marshal the structures and save them to disk so we can send them the remote system
    pubb = public.Marshal()
    with open(publicpath, 'xb') as pubf:
        pubf.write(pubb)
    sensb = sensitive.Marshal()
    with open(sensitivepath, 'xb') as sensf:
        sensf.write(sensb)
    credb = credblob.Marshal()
    with open(credpath, 'xb') as credf:
        credf.write(credb)
    secretb = secret.Marshal()
    with open(secretpath, 'xb') as secretf:
        secretf.write(secretb)

    
if __name__ == '__main__':
    if len(sys.argv) < 6:
        sys.stderr.write(f"usage: {sys.argv[0]} ek-public temp-public temp-sensitive credblob secret\n")
        exit(1)
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], b"example secret")
```

Arguments to the script is the following:
ek-public: the path to the public part of the EK
temp-public: where to save the public part of the temporary key
temp-sensitive: where to save the sensitive part of the temporary key
credlob: where to save the encrypted credential generated by MakeCredential
secret: where to save the encrypted secret generated by MakeCredential

## client script

```python
#!/usr/bin/python3


import sys
from tpm2_pytss import *

def unmarshal_tools_context(ekb):
    ekctx = TPMS_CONTEXT()
    magic = int.from_bytes(ekb[0:4], byteorder='big')
    version = int.from_bytes(ekb[4:8], byteorder='big')
    ekctx.hierarchy = int.from_bytes(ekb[8:12], byteorder='big')
    ekctx.savedHandle = int.from_bytes(ekb[12:16], byteorder='big')
    ekctx.sequence = int.from_bytes(ekb[16:24], byteorder='big')
    ekctx.contextBlob, _ = TPM2B_CONTEXT_DATA.Unmarshal(ekb[24:])
    return ekctx

def eksession(ectx):
    session = ectx.StartAuthSession(
        ESYS_TR.NONE,
        ESYS_TR.NONE,
        None,
        TPM2_SE.POLICY,
        TPMT_SYM_DEF(algorithm=TPM2_ALG.NULL),
        TPM2_ALG.SHA256,
    )

    ectx.PolicySecret(
        ESYS_TR.RH_ENDORSEMENT,
        session,
        TPM2B_NONCE()._cdata,
        TPM2B_DIGEST()._cdata,
        TPM2B_NONCE()._cdata,
        0,
        session1=ESYS_TR.PASSWORD,
    )
    
    return session

def main(ekpath, publicpath, sensitivepath, credpath, secretpath):
    # time to setup a ESAPI context, we will use the default TCTI for the system
    ectx = ESAPI()

    # Time to load the EK context, by using tpm2_createek there is no reason the implement the whole setup in this example code
    with open(ekpath, 'rb') as ekf:
        ekb = ekf.read()
    ekctx = unmarshal_tools_context(ekb)
    ekhandle = ectx.ContextLoad(ekctx)

    # now lets setup the standard EK policy session
    session = eksession(ectx)
    
    # Now we should read, unmarshal and load the temporary key pair
    with open(publicpath, 'rb') as pubf:
        pubb = pubf.read()
    public, _ = TPM2B_PUBLIC.Unmarshal(pubb)
    with open(sensitivepath, 'rb') as sensf:
        sensb = sensf.read()
    sensitive, _ = TPM2B_SENSITIVE.Unmarshal(sensb)
    print(sensitive.sensitiveArea.authValue.size, public.publicArea.authPolicy.size)
    # We will load it under the NULL hierarchy as that is the only hierarchy allowing both the public and private part to be loaded for external keys
    handle = ectx.LoadExternal(sensitive, public, ESYS_TR.RH_NULL)
    
    
    # Time to read and unmarshal the credential and secret for ActivateCredential
    with open(credpath, 'rb') as credf:
        credb = credf.read()
    credblob, _ = TPM2B_ID_OBJECT.Unmarshal(credb)
    with open(secretpath, 'rb') as secretf:
        secretb = secretf.read()
    secret, _ = TPM2B_ENCRYPTED_SECRET.Unmarshal(secretb)
    
    # Well, now there is nothing left but calling ActivateCredential and getting our secret on the remove system!
    oursecret = ectx.ActivateCredential(handle, ekhandle, credblob, secret, session2=session)

    print(f"we got the secret: {bytes(oursecret)}")

if __name__ == '__main__':
    if len(sys.argv) < 6:
        sys.stderr.write(f"usage: {sys.argv[0]} ek-ctx temp-public temp-sensitive credblob secret\n")
        exit(1)
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
```

Generate the EK context with `tpm2_createek -c ek.ctx`
The arguments are:
ek-ctx: the context generated by tpm2_createek
temp-public: the temp-public output from the local system script
temp-sensitive: the temp-sensitive output from the local system script
credblob: the credblob output from the local system script
secret: the secret output from the local system script

## Example (bash)

This example uses two bash scripts:

 - [`send-to-tpm.sh`](send-to-tpm.sh)
 - [`tpm-receive.sh`](tpm-receive.sh)

Usage messages for those two scripts:

```
Usage: send-to-tpm.sh EK-PUB-FILE SECRET-FILE OUT-FILE [POLICY-CMD [ARGS [\; ...]]]
       send-to-tpm.sh -P well-known-key-name EK-PUB-FILE SECRET-FILE OUT-FILE

    Options:

     -h         This help message.
     -P WKname  Use the given cryptographic name binding a policy for
                recipient to meet.
     -f         Overwrite OUT-FILE.
     -x         Trace this script.
```

```
Usage: receive.sh CIPHERTEXT-FILE OUT-FILE [POLICY-CMD [ARGS] [;] ...]

  "Activates" (decrypts) CIPHERTEXT-FILE made with TPM2_MakeCredential and
  writes the plaintext to OUT-FILE.

  The POLICY-CMD and arguments are one or more commands that must
  leave a policy digest in a file named 'policy' in the current
  directory (which will be a temporary directory).

    Options:

     -h         This help message.
     -f         Overwrite OUT-FILE.
     -x         Trace this script.
```

Example (without policy, both scripts running on the same system):

```
: ; # NOTE: The shell prompt ($PS1) is set to ': ; ' to make it easy to
: ; # cut-and-paste.
: ; 
: ; # Get the EKpub:
: ; tpm2 createek --ek-context ek.ctx --public ek.pub
: ; 
: ; # Make a small secret:
: ; echo hello world > secret.txt
: ; 
: ; # Make ciphertext:
: ; /tmp/send-to-tpm.sh -f ek.pub /tmp/secret /tmp/cipher
: ; 
: ; # Decrypt ciphertext:
: ; /tmp/receive.sh -f /tmp/cipher /tmp/plain
name:
000b9f40e7a7a85bcc39bba777b7eda5764d91a28512d91d395ca114b14621ae321e
837197674484b3f81a90cc8d46a5d724fd52d76e06520b64f2a1da1b331469aa
certinfodata:68656c6c6f20776f726c640a
: ; 
: ; # Show plaintext:
: ; cat /tmp/plain
hello world
```

Example (with policy, both scripts running on the same system):

```
: ; # NOTE: The shell prompt ($PS1) is set to ': ; ' to make it easy to
: ; # cut-and-paste.
: ; 
: ; # Get the EKpub:
: ; tpm2 createek --ek-context ek.ctx --public ek.pub
: ; 
: ; # Make a small secret:
: ; echo hello world > secret.txt
: ; 
: ; /tmp/send-to-tpm.sh -f ek.pub /tmp/secret /tmp/cipher \
>     tpm2 policysecret --session session.ctx \
>                       --object-context endorsement -L policy \; \
>     tpm2 policycommandcode -S session.ctx -L policy \
>                            TPM2_CC_ActivateCredential
837197674484b3f81a90cc8d46a5d724fd52d76e06520b64f2a1da1b331469aa
cd9917cf18c3848c3a2e606986a066c68142f9bc2710a278287a650ca3bbf245
: ; 
: ; /tmp/tpm-receive.sh -f /tmp/cipher /tmp/plain \
>     tpm2 policysecret --session session.ctx \
                        --object-context endorsement \
                        -L policy \; \
      tpm2 policycommandcode -S session.ctx -L policy \
                             TPM2_CC_ActivateCredential
837197674484b3f81a90cc8d46a5d724fd52d76e06520b64f2a1da1b331469aa
cd9917cf18c3848c3a2e606986a066c68142f9bc2710a278287a650ca3bbf245
name: 000bec987554f57b9918285794542c05549aa778832be169351494066907d6d95abf
837197674484b3f81a90cc8d46a5d724fd52d76e06520b64f2a1da1b331469aa
837197674484b3f81a90cc8d46a5d724fd52d76e06520b64f2a1da1b331469aa
cd9917cf18c3848c3a2e606986a066c68142f9bc2710a278287a650ca3bbf245
certinfodata:68656c6c6f20776f726c640a
: ; cat /tmp/plain
hello world
: ;
```

You can pass policy commands to the `send-to-tpm.sh` and `tpm-receive.sh`
commands as arguments, with multiple policy commands separated by a
single semi-colon (quoted, to avoid evaluation by the shell):

```bash
send-to-tpm.sh ek.pub /tmp/secret /tmp/cipher \
          tpm2 policypcr -S session.ctx -l "sha256:0,1,2,3" -f $PWD/pcr.dat \
                         -L policy \; \
          tpm2 policycommandcode -S session.ctx -L policy TPM2_CC_ActivateCredential
```

## Issues

 - The secret sent this way has to be small: no larger than the digest
   size for the digest algorithm being used.

   If the application needs to send larger secrets, then it should
   generate an AES key and send that as the small secret, then encrypt
   the larger secret in the AES key and send that ciphertext.  (But
   don't forget to also include an HMAC or MAC of the ciphertext to make
   detection of errors / tampering possible.)

 - There is no protection against replay attacks in this example.

   Replay protection can be added by adding a timestamp to the secret
   data, and by using a replay cache on the remote system.

 - There is no authentication of the sender.  To authenticate the sender
   simply add a digital signature of the ciphertext.
