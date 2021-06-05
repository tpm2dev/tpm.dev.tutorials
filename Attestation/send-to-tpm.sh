#!/bin/bash

PROG=${0##*/}

set -euo pipefail

function usage {
  ((${1:-1} > 0)) && exec 1>&2
  cat <<EOF
Usage: $PROG EK-PUB-FILE SECRET-FILE OUT-FILE
       $PROG EK-PUB-FILE SECRET-FILE OUT-FILE [POLICY-CMD [ARGS [\\; ...]]]
       $PROG -P well-known-key-name EK-PUB-FILE SECRET-FILE OUT-FILE

    Options:

     -h         This help message.
     -P WKname  Use the given cryptographic name binding a policy for
                recipient to meet.
     -f         Overwrite OUT-FILE.
     -x         Trace this script.
EOF
  exit ${1:-1}
}

force=false
wkname=
while getopts +:hfxP: opt; do
case "$opt" in
P) wkname=$OPTARG;;
h) usage 0;;
f) force=true;;
x) set -vx;;
*) usage;;
esac
done

shift $((OPTIND - 1))

(($# >= 3)) || usage
ekpub_file=$1
secret_file=$2
out_file=$3
shift 3

function err {
  echo "ERROR: $*" 1>&2
  exit 1
}

[[ -f ${ekpub_file:-} ]]   || usage
[[ -f ${secret_file:-} ]]  || usage
[[ -f ${out_file:-}    ]]  && $force && rm -f "${out_file:-}"
[[ -f ${out_file:-}    ]]  && err "output file ($out_file) exists"

# Make a temp dir and remove it when we exit:
d=
trap 'rm -rf "$d"' EXIT
d=$(mktemp -d)

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
    (cd "$d" && "${cmd[@]}")
  done
}

function make_policyDigest {
  # Start a trial session, execute the given policy commands, save the
  # policyDigest.
  tpm2 flushcontext --transient-object
  tpm2 flushcontext --loaded-session
  tpm2 startauthsession --session "${d}/session.ctx"
  exec_policy "$@"
}

function wkname {
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

  tpm2 flushcontext --saved-session

  # Load
  attrs='decrypt|sign'
  loadexternal_args=()
  if (($# > 0)); then
    make_policyDigest "$@" 1>&2
    loadexternal_args+=(-L "${d}/policy")
    attrs='adminwithpolicy|decrypt|sign'
  fi

  # Load the WK
  tpm2 flushcontext --transient-object 1>&2
  tpm2 flushcontext --loaded-session 1>&2
  tpm2 loadexternal -C n                        \
                    -Gecc                       \
                    -r "${d}/wkpriv.pem"        \
                    "${loadexternal_args[@]}"   \
                    -a "$attrs"                 \
                    -c "${d}/wk.ctx"            |
    grep ^name:                                 |
    cut -d' ' -f2
}

[[ -z $wkname ]] && wkname=$(wkname "$@")

tpm2 makecredential                     \
  --tcti "none"                         \
  --encryption-key "${ekpub_file}"      \
  --name "$wkname"                      \
  --secret "${secret_file}"             \
  --credential-blob "$out_file"
