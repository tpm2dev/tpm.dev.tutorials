#!/bin/bash

PROG=${0##*/}

set -euo pipefail

function usage {
  echo "Usage: $PROG [OPTIONS] CIPHERTEXT-FILE OUT-FILE [POLICY-CMD [ARGS] [\; ...]]"
  cat <<EOF
Usage: $PROG CIPHERTEXT-FILE OUT-FILE [POLICY-CMD [ARGS] [;] ...]

  "Activates" (decrypts) CIPHERTEXT-FILE made with TPM2_MakeCredential and
  writes the plaintext to OUT-FILE.  If the sender asserted some policy,
  that policy must be repeated when invoking this program to decrypt the
  secret.

  Policies should be specified as a sequence of {tpm2 policy...}
  commands, with all necessary arguments except for {--session}|{-S}
  and {--policy}|{-L} options.  Also, no need to include {tpm2
  policycommandcode}, as that will get added.  E.g.:

      $ $PROG ./ekpub ./secret ./madecredential \\
          tpm2 policypcr -l "sha256:0,1,2,3" -f pcrs

    Options:

     -h         This help message.
     -f         Overwrite OUT-FILE.
     -x         Trace this script.
EOF
  exit 1
}

force=false
verbose=false
while getopts +:hfvx opt; do
case "$opt" in
h) usage 0;;
f) force=true;;
v) verbose=true;;
x) set -vx;;
*) usage;;
esac
done

shift $((OPTIND - 1))

(($# >= 2)) || usage
ciphertext_file=$1
out_file=$2
shift 2

[[ -f ${ciphertext_file:-} ]] || usage
[[ -f ${out_file:-} ]] && $force && rm -f "$out_file"
[[ -f ${out_file:-} ]] && usage

d=
trap 'rm -rf "$d"' EXIT
d=$(mktemp -d)

function v {
  if $verbose; then
    printf 'Running:'
    printf ' %q' "$@"
    printf '\n'
  fi >/dev/tty || true
  if "$@"; then
    $verbose && printf '(SUCCESS)\n' >/dev/tty || true
  else
    stat=$?
    printf 'ERROR: Command exited with %d\n' $stat >/dev/tty || true
    return $stat
  fi
}

function exec_policy {
  local add_commandcode=true
  local has_policy=false

  while (($# > 0)); do
    has_policy=true
    cmd=()
    while (($# > 0)) && [[ $1 != ';' ]]; do
      cmd+=("$1")
      if ((${#cmd[@]} == 1)) && [[ ${cmd[0]} = tpm2_* ]]; then
        cmd+=(--session "${d}/session.ctx" --policy "${d}/policy")
      elif ((${#cmd[@]} == 2)) && [[ ${cmd[0]} = tpm2 ]]; then
        cmd+=(--session "${d}/session.ctx" --policy "${d}/policy")
      fi
      shift
    done
    (($# > 0)) && shift
    # Run the policy command in the temp dir.  It -or the last command- must
    # leave a file there named 'policy'.
    "${cmd[@]}"
    if [[ ${cmd[0]} = tpm2 ]] && ((${#cmd[@]} == 1)); then
      echo "Policy is incomplete" 1>&2
      exit 1
    fi
    [[ ${cmd[0]} = tpm2 && ${cmd[1]} = policycommandcode ]] &&
      add_commandcode=false
    [[ ${cmd[0]} = tpm2_policycommandcode ]] && add_commandcode=false
  done
  $has_policy && $add_commandcode &&
    tpm2 policycommandcode --session "${d}/session.ctx"     \
                           --policy "${d}/policy"           \
                           TPM2_CC_ActivateCredential
}

function make_policyDigest {
  tpm2 flushcontext --transient-object
  tpm2 flushcontext --loaded-session
  v tpm2 startauthsession --session "${d}/session.ctx"
  exec_policy "$@"
}

# Get the EK handle:
tpm2 flushcontext --transient-object
tpm2 flushcontext --loaded-session
tpm2 flushcontext --saved-session 1>&2
tpm2 createek --key-algorithm rsa           \
              --ek-context "${d}/ek.ctx"    \
              --public "${d}/ek.pub"

# Make policyDigest and load WK
attrs='decrypt|sign'
adminwithpolicy=
if (($# > 0)); then
  make_policyDigest "$@"
  attrs='adminwithpolicy|decrypt|sign'
  adminwithpolicy=true
fi

rm -f "${d}/session.ctx"

# This is the WK.  It was generated with:
#  openssl genpkey -genparam                               \
#                  -algorithm EC                           \
#                  -out "${d}/ecp.pem"                     \
#                  -pkeyopt ec_paramgen_curve:secp384r1    \
#                  -pkeyopt ec_param_enc:named_curve
#  openssl genpkey -paramfile "${d}/ecp.pem"
cat > "${d}/wkpriv.pem" <<EOF
-----BEGIN PRIVATE KEY-----
MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDAlMnCWue7CfXjNLibH
PTJrsOLUcoxqU3FLWYEWMI+HuPnzcwwl7SkKN6cpf4H3oQihZANiAAQ1pw6D5QVw
vymljYVDyrUriOet8zPB/9tq9XJ7A54qsVkaVufAuEJ6GIvD4xUZ27manMosJADS
aW2TLJkwxecRh2eTwPtSx2U32M2/yHeuWRV/0juiIozefPsTAlHAi3E=
-----END PRIVATE KEY-----
EOF

# Load the WK
v tpm2 flushcontext --transient-object 1>&2
v tpm2 flushcontext --loaded-session 1>&2
if v tpm2 loadexternal -C n                                 \
                     -Gecc                                  \
                     -r "${d}/wkpriv.pem"                   \
		     ${adminwithpolicy:+-L "${d}/policy"}   \
                     -a "$attrs"                            \
                     -c "${d}/wk.ctx" > "${d}/out" 2> "${d}/err"; then
  cat "${d}/out" 1>&2
else
  stat=$?
  echo "ERROR: Failed to load WK:" 1>&2
  cat "${d}/out"
  cat "${d}/err" 1>&2
  exit $stat
fi

# Create empty auth session for EK
v tpm2 flushcontext --transient-object
v tpm2 flushcontext --loaded-session
v tpm2 startauthsession --session "${d}/sessionek.ctx" --policy-session
v tpm2 policysecret --session "${d}/sessionek.ctx" --object-context endorsement

activatecredential_args=()
if (($# > 0)); then
  activatecredential_args+=(--credentialedkey-auth session:"${d}/session.ctx")
  # Create auth session for the WK, since it has adminWithPolicy
  v tpm2 flushcontext --transient-object
  v tpm2 flushcontext --loaded-session
  v tpm2 startauthsession --session "${d}/session.ctx" --policy-session
  exec_policy "$@"
  v tpm2 flushcontext --transient-object
  v tpm2 flushcontext --loaded-session
fi
# Finally, ActivateCredential
$verbose && tpm2 readpublic -c "${d}/wk.ctx" | grep name:
v tpm2 activatecredential --credentialedkey-context "${d}/wk.ctx"             \
                          "${activatecredential_args[@]}"                     \
                          --credentialkey-context "${d}/ek.ctx"               \
                          --credentialkey-auth session:"${d}/sessionek.ctx"   \
                          --credential-blob "$ciphertext_file"                \
                          -o "$out_file"
