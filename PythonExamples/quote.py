#
# Import the tpm2_pytss libraries and the encoders
#

from tpm2_pytss import *
from tpm2_pytss.encoding import (
    base_encdec,
    json_encdec,
)

#
# We also need this too, for convenience later
#

import json

#
# Setting up some variables here for convenience
#

tcti_to_use = None
attestation_key_handle = 0x810100AA
pcrs_to_quote = "sha256:0,1,2,3"
extradata_to_use = b"Ian12345"

#
# Make a connection to a TPM and use the ESAPI interface
# tcti=None means that the pytss libraries will search for an available TCTI
#
#
# When this is run, then as the various TCTI interfaces are searched errors are written if those interfaces are not foud
#

tpm = ESAPI(tcti=None)

# 
# Send a startup message, just in case (actually this is because I'm using the IBM SW TPM and haven't started it properly)
#

tpm.startup(TPM2_SU.CLEAR)

#
# Create the necessary parameters for making a quote
#


handle =  tpm.tr_from_tpmpublic(attestation_key_handle)
pcrsels = TPML_PCR_SELECTION.parse(pcrs_to_quote)
extradata_to_use = TPM2B_DATA(extradata_to_use)

#
# Now to make the quote and return the attested values and signature
#

quote,signature = tpm.quote(
	  handle, pcrsels, extradata_to_use
	)

#
# Now to unmarshal the attested values and we'll print them out which'll give a tpm2_pytss.types.TPMS_ATTEST object
#

att,_ = TPMS_ATTEST.unmarshal( bytes(quote) )
print("att=",att)

#
# We construct an encoder and encode that structure in a python dict
#

enc = json_encdec()
ae = enc.encode(att)
print("ae=",type(ae),"\n",ae)

#
# Now we'll use the json library to convert that to JSON and pretty print it
#

js = json.dumps(ae,indent=4)
print("\n",js)


#
# Now we'll do the same, except we'll generate the nonce using the TPM's random number generator
#

r = tpm.get_random( 8 )

extradata_to_use = TPM2B_DATA(str(r))

print("\nWith randomly generated extra data: ",str(r))

quote,signature = tpm.quote(
	  handle, pcrsels, extradata_to_use
	)

att,_ = TPMS_ATTEST.unmarshal( bytes(quote) )
enc = json_encdec()
ae = enc.encode(att)
print("ae2=",type(ae),"\n",ae)
