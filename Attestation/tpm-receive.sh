#!/bin/bash

PROG=${0##*/}

set -euo pipefail

function usage {
  echo "Usage: $PROG [OPTIONS] CIPHERTEXT-FILE OUT-FILE [POLICY-CMD [ARGS] [\; ...]]"
  cat <<EOF
Usage: $PROG CIPHERTEXT-FILE OUT-FILE [POLICY-CMD [ARGS] [;] ...]

  "Activates" (decrypts) CIPHERTEXT-FILE made with TPM2_MakeCredential and
  writes the plaintext to OUT-FILE.

  The POLICY-CMD and arguments are one or more commands that must
  leave a policy digest in a file named 'policy' in the current
  directory (which will be a temporary directory).

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
  while (($# > 0)); do
    cmd=()
    while (($# > 0)) && [[ $1 != ';' ]]; do
      cmd+=("$1")
      shift
    done
    (($# > 0)) && shift
    # Run the policy command in the temp dir.  It -or the last command- must
    # leave a file there named 'policy'.
    if (v cd "$d" && v "${cmd[@]}" 1> "${d}/out" 2> "${d}/err"); then
      cat "${d}/out" >/dev/tty || true
    else
      stat=$?
      echo "ERROR: Failed to run \"${cmd[0]} ...\":"
      cat "${d}/out"
      cat "${d}/err" 1>&2
      exit $stat
    fi
  done
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
tpm2 createek --key-algorithm rsa           \
              --ek-context "${d}/ek.ctx"    \
              --public "${d}/ek.pub"

# Make policyDigest and load WK
attrs='decrypt|sign'
loadexternal_args=()
if (($# > 0)); then
  make_policyDigest "$@"
  loadexternal_args+=(-L "${d}/policy")
  attrs='adminwithpolicy|decrypt|sign'
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
tpm2 flushcontext --transient-object 1>&2
tpm2 flushcontext --loaded-session 1>&2
if v tpm2 loadexternal -C n                      \
                     -Gecc                       \
                     -r "${d}/wkpriv.pem"        \
                     "${loadexternal_args[@]}"   \
                     -a "$attrs"                 \
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
