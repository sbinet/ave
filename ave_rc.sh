#!/bin/bash
## ave_rc.sh
## @date November 2009
## @purpose a set of bash functions to ease the Athena-CMT pain

alias wipeBin='find -name "i686*" -exec rm -rf {} \;'
alias atn=/afs/cern.ch/atlas/software/dist/nightlies/atn/atn
alias ave-uuidgen='uuidgen | tr "[:lower:]" "[:upper:]"'
alias wkarea='cmt bro "mkdir ../$CMTCONFIG;echo \"OK\""'
alias pmake='make -s -j3 QUIET=1 PEDANTIC=1'
alias brmake='cmt bro make -s -j3 QUIET=1 PEDANTIC=1'
alias abootstrap='(cmt bro cmt config && source ./setup.sh && brmake; source ./setup.sh)'
alias avn='~binet/public/tools/avn'

alias vo='ssh -Y voatlas51'

## new python-based atlas-login
export AtlasSetup=/afs/cern.ch/atlas/software/dist/AtlasSetup
alias alogin='source $AtlasSetup/scripts/asetup.sh $*'

## poor man's way of getting the same result than:
## os.sysconf("SC_NPROCESSORS_ONLN")
if [[ -e "/proc/cpuinfo" ]]; then
    export AVE_NCPUS=`cat /proc/cpuinfo | grep processor | wc -l`
else
    export AVE_NCPUS='1'
fi
export AVE_MAKE_DEFAULT_OPTS='-s -j${AVE_NCPUS} QUIET=1 PEDANTIC=1'

export AVE_VALGRIND=${HOME}/.local/usr/bin/valgrind
export AVE_CMT_VERSION=v1r20p20090520
export AVE_CMT_VERSION=v1r21
export AVE_CMT_ROOT=/afs/cern.ch/sw/contrib/CMT


function ave-login()
{
    args=("$@")
    args=$@
    nargs=${#args[@]}
    if [ $nargs -lt 1 ]; then
        # try to get informations from a previous login...
        if [[ -e ".ave_config.rc" ]]; then
            echo "::: taking configuration from previous login..."
            echo "======="
            cat .ave_config.rc
            echo "======="
            #args=`grep 'login-args' .ave_config.rc | cut -d= -f2`
            #args=${args// /}
            args=`grep 'login-args' .ave_config.rc | sed "s/login-args = //"`
            #args=${args// /}
        fi
    #else
        #args=$1; shift
    fi

    if [ -z "${args}" ]; then
        echo "** you need to give an argument to ave-login !"
        echo "** ex: "
        echo "$ ave-login rel_2,gcc34"
        return 1
    fi

    echo "::: generating asetup.cfg..."

    /bin/cat >| ${PWD}/.asetup.cfg <<EOF
[defaults]
default32 = True
opt = True
gcc43default = True
lang = C
hastest = True           # to prepend pwd to cmtpath
pedantic = True
runtime = True
setup = True
os = slc5
#project = AtlasOffline  # offline is the default
save = True
#standalone = False       # prefer build area instead of kit-release
#standalone = True       # prefer release area instead of build-area
EOF

    export AVE_LOGIN_ARGS="$args"
    echo "::: configuring athena for [$AVE_LOGIN_ARGS]..."
    source $AtlasSetup/scripts/asetup.sh --input=${PWD}/.asetup.cfg $AVE_LOGIN_ARGS || return 1
    /bin/cat >| .ave_config.rc <<EOF
[ave]
login-time = `date`
login-args = $AVE_LOGIN_ARGS
cmtconfig  = $CMTCONFIG
hostname   = `hostname`
EOF

    echo "::: cmt-configuration: [$CMTCONFIG]"
    cmt show path || return 1
    echo "::: configuring athena for [$AVE_LOGIN_ARGS]... [done]"
    return 0
}

function ave-old-login()
{
    args=("$@")
    nargs=${#args[@]}
    if [ $nargs -lt 1 ]; then
        # try to get informations from a previous login...
        if [[ -e ".ave_config.rc" ]]; then
            echo "::: taking configuration from previous login..."
            echo "======="
            cat .ave_config.rc
            echo "======="
            args=`grep 'login-args' .ave_config.rc | cut -d= -f2`
            args=${args// /}
        fi
    else
        args=$1; shift
    fi
    if [ -z ${args} ]; then
        echo "** you need to give an argument to ave-login !"
        echo "** ex: "
        echo "$ ave-login rel_2,gcc34"
        return 1
    fi
    export AVE_CMTHOME_DIR=`mktemp -d ${TMPDIR}/ave-cmthome-${args//,/-}-XXXXXXXXXX` || exit 1
    echo "::: generating cmthome/requirements [$AVE_CMTHOME_DIR/requirements]..."

    # check if we are at cern...
    hostname | grep -qE "cern.ch$"
    rc=$?
    if [ $rc -eq 0 ]; then
        AVE_CMT_CMTSITE="CERN"
        AVE_CMT_SITEROOT="/afs/cern.ch"
        AVE_CMT_ATLAS_DIST_AREA="\${SITEROOT}/atlas/software/dist"
        AVE_CMT_ATLAS_TEST_AREA="\${HOME}"
    else
        AVE_CMT_CMTSITE="STANDALONE"
        AVE_CMT_SITEROOT=
        ###
        if [ `hostname` = "farnsworth" ]; then
            AVE_CMT_CMTSITE="CERN"
            AVE_CMT_SITEROOT="/afs/cern.ch"
            AVE_CMT_ATLAS_DIST_AREA="\${SITEROOT}/atlas/software/dist"
            AVE_CMT_ATLAS_TEST_AREA="\${HOME}"
            export CMTCONFIG=x86_64-slc5-gcc43-dbg
        fi
    fi

    /bin/cat >| ${AVE_CMTHOME_DIR}/requirements <<EOF
set   CMTSITE         $AVE_CMT_CMTSITE
set   SITEROOT        $AVE_CMT_SITEROOT
macro ATLAS_DIST_AREA $AVE_CMT_ATLAS_DIST_AREA
macro ATLAS_TEST_AREA $AVE_CMT_ATLAS_TEST_AREA

apply_tag noTest
apply_tag runtime
apply_tag AtlasOffline

apply_tag optimized

# to get the 32bits compat libs on slc4-64
apply_tag 32

# use the same version of CMT as the one used to build the selected
# release or nightly
#apply_tag setupCMT

use AtlasLogin AtlasLogin-* \$(ATLAS_DIST_AREA)

macro ATLAS_RELEASE  "\$(ATLAS_RELEASE)"

#macro cmtconfig_default i686-slc5-gcc43-opt

#set CMTCONFIG \$(cmtconfig_default)	i686-slc3-gcc323-opt i686-slc3-gcc323-opt	i686-slc3-gcc323-dbg i686-slc3-gcc323-dbg	i686-slc3-gcc344-opt i686-slc3-gcc344-opt	i686-slc3-gcc344-dbg i686-slc3-gcc344-dbg	i686-slc3-icc8-opt i686-slc3-icc8-opt	i686-slc3-gcc344-opt i686-slc3-gcc344-opt	i686-slc3-gcc344-dbg i686-slc3-gcc344-dbg	x86_64-slc3-gcc344-opt x86_64-slc3-gcc344-opt	i686-slc4-gcc345-opt i686-slc4-gcc345-opt	i686-slc4-gcc345-dbg i686-slc4-gcc345-dbg	x86_64-slc4-gcc345-opt x86_64-slc4-gcc345-opt	x86_64-slc4-gcc345-dbg x86_64-slc4-gcc345-dbg	i686-slc4-gcc34-opt i686-slc4-gcc34-opt	i686-slc4-gcc34-dbg i686-slc4-gcc34-dbg	x86_64-slc4-gcc34-opt x86_64-slc4-gcc34-opt	x86_64-slc4-gcc34-dbg x86_64-slc4-gcc34-dbg	i686-slc4-gcc41-opt i686-slc4-gcc41-opt	i686-slc4-gcc41-dbg i686-slc4-gcc41-dbg	x86_64-slc4-gcc41-opt x86_64-slc4-gcc41-opt	x86_64-slc4-gcc41-dbg x86_64-slc4-gcc41-dbg	i686-slc4-gcc43-opt i686-slc4-gcc43-opt	i686-slc4-gcc43-dbg i686-slc4-gcc43-dbg	x86_64-slc4-gcc43-opt x86_64-slc4-gcc43-opt	x86_64-slc4-gcc43-dbg x86_64-slc4-gcc43-dbg	i686-slc5-gcc34-opt i686-slc5-gcc34-opt	i686-slc5-gcc34-dbg i686-slc5-gcc34-dbg	x86_64-slc5-gcc34-opt x86_64-slc5-gcc34-opt	x86_64-slc5-gcc34-dbg x86_64-slc5-gcc34-dbg	i686-slc5-gcc43-opt i686-slc5-gcc43-opt	i686-slc5-gcc43-dbg i686-slc5-gcc43-dbg	x86_64-slc5-gcc43-opt x86_64-slc5-gcc43-opt	x86_64-slc5-gcc43-dbg x86_64-slc5-gcc43-dbg	i386-mac104-gcc40-opt i386-mac104-gcc40-opt	i386-mac104-gcc40-dbg i386-mac104-gcc40-dbg	ppc-mac104-gcc40-opt ppc-mac104-gcc40-opt	ppc-mac104-gcc40-dbg ppc-mac104-gcc40-dbg	i386-mac105-gcc40-opt i386-mac105-gcc40-opt	i386-mac105-gcc40-dbg i386-mac105-gcc40-dbg

path_remove  CMTPATH "\$(ATLAS_TEST_AREA)"
path_prepend CMTPATH "\$PWD" 
set TestArea "\$PWD"
EOF

    pushd ${AVE_CMTHOME_DIR}
    source $AVE_CMT_ROOT/$AVE_CMT_VERSION/mgr/setup.sh
    cmt config || return 1
    popd
    echo "::: generating cmthome/requirements [$AVE_CMTHOME_DIR/requirements]... [done]"
    export AVE_LOGIN_ARGS=$args
    echo "::: configuring athena for [$AVE_LOGIN_ARGS]..."
    source ${AVE_CMTHOME_DIR}/setup.sh -tag=$AVE_LOGIN_ARGS || return 1
    /bin/cat >| .ave_config.rc <<EOF
[ave]
login-time = `date`
login-args = $AVE_LOGIN_ARGS
cmtconfig  = $CMTCONFIG
hostname   = `hostname`
EOF

    echo "::: cmt-configuration: [$CMTCONFIG]"
    cmt show path
    echo "::: configuring athena for [$AVE_LOGIN_ARGS]... [done]"
    return 0
}

function ave-setup()
{
    echo "::: ave-setup..."
    pushd WorkArea/cmt
    source ./setup.sh    || return 1
    popd
    echo "::: ave-setup... [done]"
}

function ave-workarea()
{
    echo "::: building workarea..."
    /bin/rm -rf InstallArea
    abootstrap-wkarea.py "$@" || return 1
    pushd WorkArea/cmt
    ave-config           || return 1
    ave-brmake           || return 1
    source ./setup.sh    || return 1
    popd
    pushd WorkArea/run
    echo "::: building workarea... [done]"
}

function ave-config()
{
    cmt bro cmt config || return 1
    source ./setup.sh  || return 1
}

function ave-make()
{
    cmt make ${AVE_MAKE_DEFAULT_OPTS} "$@" || return 1
}

function ave-brmake()
{
    cmt bro make ${AVE_MAKE_DEFAULT_OPTS} || return 1
}

function ave-reco-tests()
{
    pid=$$
    test_dir=`pwd`/ave-reco-tests-$pid
    echo "::: running ave-reco-tests in [$test_dir]..."
    if [ -e $test_dir ]; then
	/bin/rm -rf $test_dir
    fi
    /bin/mkdir $test_dir
    pushd $test_dir

    echo "::: setup recex-common-links..."
    RecExCommon_links.sh || return 1
    echo "::: running many reco tests..."
    manyrecotests.sh || return 1
    echo "::: running pyutils tests..."
    python -c 'import PyUtils.AthFile as af; af.tests.main()' || return 1

    popd
    echo "::: all good."
    return 0
}

function ave-reco-trf-tests()
{
    pid=$$
    test_dir=`pwd`/ave-reco-trf-tests-$pid
    echo "::: running ave-reco-tests in [$test_dir]..."
    if [ -e $test_dir ]; then
	/bin/rm -rf $test_dir
    fi
    /bin/mkdir $test_dir
    pushd $test_dir

    echo "::: setup recex-common-links..."
    RecExCommon_links.sh || return 1

    function run_reco_trf()
    {
	ami_cfg=$1; shift
	echo "::: running reco-trf [$ami_cfg]..."
	if [ -e reco_trf_test_$ami_cfg ]; then
	    /bin/rm -rf reco_trf_test_$ami_cfg
	fi
	/bin/mkdir reco_trf_test_$ami_cfg
	pushd reco_trf_test_$ami_cfg
	Reco_trf.py AMI=$ami_cfg >& reco_trf_${ami_cfg}.txt
	rc=$?
	popd
	echo "::: running reco-trf [$ami_cfg]... (rc=$rc)"
	return rc
    }
    run_reco_trf q120  
    run_reco_trf q121
    run_reco_trf q122  

    popd
    echo "::: all good."
    return 0
}

function ave-follow-tail()
{
    file=$1; shift;
    /usr/bin/watch -n 1 /usr/bin/tail -n 25 $file
    return 0
}

function _ave_valgrind_setup_suppressions()
{
    get_files -data valgrindRTT.supp
    get_files -data Gaudi.supp/Gaudi.supp
    get_files -data newSuppressions.supp
    get_files -data oracleDB.supp
    get_files -data root.supp/root.supp
}

function ave-valgrind-mem()
{
    args=("$@")
    nargs=${#args[@]}
    _ave_valgrind_setup_suppressions

    ${AVE_VALGRIND} \
        --tool=memcheck \
        --suppressions=valgrindRTT.supp \
        --suppressions=Gaudi.supp \
        --suppressions=newSuppressions.supp \
        --suppressions=oracleDB.supp \
        --suppressions=root.supp \
        --suppressions=$ROOTSYS/etc/valgrind-root.supp \
        --trace-children=yes \
        --num-callers=20 \
        --track-origins=yes \
        --leak-check=yes \
        --show-reachable=yes \
        `which athena.py` --stdcmalloc $args 2>&1 | tee valgrind.mem.log 

}

function ave-valgrind-cpu()
{
    args=("$@")
    nargs=${#args[@]}
    _ave_valgrind_setup_suppressions

    ${AVE_VALGRIND} \
        --tool=callgrind \
        --suppressions=valgrindRTT.supp \
        --suppressions=Gaudi.supp \
        --suppressions=newSuppressions.supp \
        --suppressions=oracleDB.supp \
        --suppressions=root.supp \
        --suppressions=$ROOTSYS/etc/valgrind-root.supp \
        --num-callers=20 \
        --trace-children=yes \
        --collect-jumps=yes \
        --instr-atstart=yes \
        `which athena.py` --stdcmalloc $args 2>&1 | tee valgrind.cpu.log
}

function ave-valgrind-helgrind()
{
    args=("$@")
    nargs=${#args[@]}
    _ave_valgrind_setup_suppressions

    ${AVE_VALGRIND} \
	    --tool=helgrind \
        --suppressions=valgrindRTT.supp \
        --suppressions=Gaudi.supp \
        --suppressions=newSuppressions.supp \
        --suppressions=oracleDB.supp \
        --suppressions=root.supp \
        --suppressions=$ROOTSYS/etc/valgrind-root.supp \
        --trace-children=yes \
	    --track-lockorders=yes \
	    --history-level=full \
        `which athena.py` --stdcmalloc $args 2>&1 | tee valgrind.helgrind.log
}

function ave-valgrind-drd()
{
    args=("$@")
    nargs=${#args[@]}
    _ave_valgrind_setup_suppressions

    ${AVE_VALGRIND} \
	    --tool=drd \
        --suppressions=valgrindRTT.supp \
        --suppressions=Gaudi.supp \
        --suppressions=newSuppressions.supp \
        --suppressions=oracleDB.supp \
        --suppressions=root.supp \
        --suppressions=$ROOTSYS/etc/valgrind-root.supp \
        --trace-children=yes \
	    --check-stack-var=yes \
	    --trace-barrier=yes \
	    --trace-fork-join=yes \
	    --read-var-info=yes \
        `which athena.py` --stdcmalloc $args 2>&1 | tee valgrind.drd.log
}

# function ave-reload()
# {
#     . ~/public/Athena/ave_rc.sh
# }
