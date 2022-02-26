#
# Import the tpm2_pytss libraries 
#

from tpm2_pytss import *

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
# Now to make the quote and return the attested values and signature
#

r = tpm.get_random( 8 )

print("type is ",type(r))
print("r    is ",str(r))
print("as int  ",int(str(r),16))