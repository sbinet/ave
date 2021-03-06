#!/bin/bash
## ave_rc.sh
## @date November 2009
## @purpose a set of bash functions to ease the Athena-CMT pain

alias wipeBin='find -name "i686-*" -o -name "x86_64-*" -exec rm -rf {} \;'
alias atn=/afs/cern.ch/atlas/software/dist/nightlies/atn/atn
alias ave-uuidgen='uuidgen | tr "[:lower:]" "[:upper:]"'
alias wkarea='cmt bro "mkdir ../$CMTCONFIG;echo \"OK\""'
alias pmake='make -s -j3 QUIET=1 PEDANTIC=1'
alias brmake='cmt bro make -s -j3 QUIET=1 PEDANTIC=1'
alias abootstrap='(cmt bro cmt config && source ./setup.sh && brmake; source ./setup.sh)'
alias avn='~binet/public/tools/avn'

alias vo='ssh -Y voatlas51'

## new python-based atlas-login
export AtlasSetup=/afs/cern.ch/atlas/software/dist/beta/AtlasSetup
alias alogin='source $AtlasSetup/scripts/asetup.sh $*'

## for voms authentication's benefit
export X509_USER_PROXY=${HOME}/private/x509proxy

## poor man's way of getting the same result than:
## os.sysconf("SC_NPROCESSORS_ONLN")
if [[ -e "/proc/cpuinfo" ]]; then
    export AVE_NCPUS=`cat /proc/cpuinfo | grep processor | wc -l`
else
    export AVE_NCPUS='1'
fi

export AVE_MAKE_DEFAULT_OPTS='-s -j${AVE_NCPUS} -l${AVE_NCPUS} QUIET=1 PEDANTIC=1'

export AVE_VALGRIND=${HOME}/.local/usr/bin/valgrind
export AVE_VALGRIND=valgrind
export AVE_CMT_VERSION=v1r20p20090520
export AVE_CMT_VERSION=v1r21
export AVE_CMT_VERSION=v1r24
export AVE_CMT_ROOT=/afs/cern.ch/sw/contrib/CMT

# enable cmt-v1r24 parallel make
export AVE_CMTBCAST=1

# setup AtlasLocalRootBase
export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
alias ave-alrb='. ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh'

function ave-login()
{
    args=("$@")
    args=$@
    nargs=${#args[@]}
    if [ $nargs -lt 1 ]; then
        # try to get informations from a previous login...
        if [[ -e ".ave_store.cmt" ]]; then
            echo "::: taking configuration from previous login..."
            eval `atl-cmt-load-env -f .ave_store.cmt`
            rc=$?
            echo "::: cmt-configuration: [$CMTCONFIG]"
            cmt show path || return 1
            return $rc
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

    export AVE_LOGIN_ARGS="${args[@]}"
    echo "::: configuring athena for [$AVE_LOGIN_ARGS]..."
    atl-cmt-save-env -f .ave_store.cmt "${AVE_LOGIN_ARGS}" || return 1
    eval `atl-cmt-load-env -f .ave_store.cmt`
    echo "::: cmt-configuration: [$CMTCONFIG]"
    cmt show path || return 1
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
    find $TestArea \
        -name "genConf" \
        -o -name "$CMTCONFIG" \
        -exec /bin/rm -rf {} \;
    abootstrap-wkarea.py "$@" || return 1
    pushd WorkArea/cmt
    ave-config           || return 1
    source ./setup.sh    || return 1
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
    unset CMTBCAST
    cmt make ${AVE_MAKE_DEFAULT_OPTS} "$@" || return 1
}

function ave-brmake()
{
    if [[ "$AVE_CMTBCAST" == "1" ]]; then
        CMTBCAST=1 \
        cmt make ${AVE_MAKE_DEFAULT_OPTS} "$@" || return 1
    else
        cmt bro make ${AVE_MAKE_DEFAULT_OPTS} "$@" || return 1
    fi
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

ave-valgrind-massif () {
        args=("$@")
        nargs=${#args[@]}
        ${AVE_VALGRIND} --tool=massif --trace-children=yes `which athena.py` --stdcmalloc $args 2>& 1 | tee valgrind.massif.log
}

function ave-voms-proxy-init()
{
  export X509_USER_PROXY=${HOME}/private/x509proxy
  ( # spawn a subshell so python version used by 'gd' does not interfere
    # with the current one (most probably from athena)
    source /afs/cern.ch/project/gd/LCG-share/current/etc/profile.d/grid_env.sh
    voms-proxy-init -voms atlas -out ${X509_USER_PROXY}
  )
  if [ -f $X509_USER_PROXY ]
  then
      echo "::: fetching X509_USER_PROXY back..."
      echo "::: X509_USER_PROXY=$X509_USER_PROXY"
      echo "::: fetching X509_USER_PROXY back... [done]"
  fi  
}

# function ave-reload()
# {
#     . ~/public/Athena/ave_rc.sh
# }

function ave-gpt-cpu-profile()
{
    args=("$@")
    ave_gpt_cpuprofile=ave-gpt-$$.cpu.profile
    /bin/rm -rf ${ave_gpt_cpuprofile}* 2> /dev/null
    echo "::: running gpt-cpu-profiler (outfile=$ave_gpt_cpuprofile)..."
    TCMALLOCDIR=${ATLAS_GPERFTOOLS_DIR} \
    LD_PRELOAD=libtcmalloc_and_profiler.so \
    CPUPROFILE_FREQUENCY=1000 \
    CPUPROFILE=$ave_gpt_cpuprofile \
        `which python` `which athena.py` --stdcmalloc $args
    sc=$?
    echo "::: running gpt-cpu-profiler (outfile=$ave_gpt_cpuprofile)... [done]"
    return $sc
}

function ave-gpt-mem-profile()
{
    args=("$@")
    ave_gpt_memprofile=ave-gpt-$$.mem.profile
    /bin/rm -rf ${ave_gpt_memprofile}* 2> /dev/null
    echo "::: running gpt-mem-profiler (outfile=$ave_gpt_memprofile)..."
    TCMALLOCDIR=${ATLAS_GPERFTOOLS_DIR} \
    LD_PRELOAD=libtcmalloc_and_profiler.so \
    HEAPPROFILE=$ave_gpt_memprofile \
        `which python` `which athena.py` --stdcmalloc $args
    sc=$?
    echo "::: running gpt-mem-profiler (outfile=$ave_gpt_memprofile)... [done]"
    return $sc
}

function ave-gpt-analyze()
{
    profile=$1; shift;

    pprof --callgrind `which python` $profile >| ${profile}.callgrind
    sc=$?
    return $sc
}
