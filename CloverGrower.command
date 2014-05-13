#!/bin/bash
myV="6.16"
gccVers="4.8.2" 
# use this
# Reset locales (important when grepping strings from output commands)
export LC_ALL=C

# Retrieve full path of the command
declare -r CMD=$([[ $0 == /* ]] && echo "$0" || echo "${PWD}/${0#./}")

# Retrieve full path of CloverGrower
declare -r CLOVER_GROWER_SCRIPT=$(readlink "$CMD" || echo "$CMD")
declare -r CLOVER_GROWER_DIR="${CLOVER_GROWER_SCRIPT%/*}"
theShortcut=`echo ~/Desktop`
# Source librarie
source "${CLOVER_GROWER_DIR}"/CloverGrower.lib
myArch=`uname -m`
export archBit='x86_64'
theRevision=
if [[ "$1" == ""  && "$myArch" == "x86_64" ]]; then # if NO parameter build 32&64
	target="X64/IA32"
else 	
	target="X64"
fi
if [ "$myArch" == "i386" ] || [ "$1" == "32" ] ; then # for 32bit cpu
	target="IA32"
	export archBit='i686'
fi
[ "$1" == "-r" ] &&	[ "$2" != "" ] && theRevision="$2"		
# don't use -e
set -u
user=$(id -un)
theBoss=$(id -ur)
hours=$(get_hours)
theLink=/usr/local/bin/clover
if [[ -L "$theShortcut"/CloverGrower.command ]]; then
	theLink="$theShortcut"/CloverGrower.command
fi

#what system
theSystem=$(uname -r)
theSystem="${theSystem:0:2}"
case "${theSystem}" in
    [0-8]) rootSystem="unsupported" ;;
    9) export rootSystem="Leopard" ;;
    10) export rootSystem="Snow Leopard" ;;
    11) export rootSystem="Lion" ;;
    12)	export rootSystem="Mountain Lion" ;;
    13)	export rootSystem="Mavericks" ;;
    [14-20]) rootSystem="Unknown" ;;
esac

# XCode check
if [ ! -f /usr/bin/gcc ]; then
	echob "ERROR:"
	echob "      Xcode Command Line Tools from Apple"
	echob "      NOT FOUND!!!!"
	echob "      CloverGrower.command needs it";echo
	if [ "${theSystem}" != 13 ] || [ ! -f /usr/bin/xcode-select ]; then
		echob "      Going To Apple Developer Site"
		echob "      Download & Install XCode Command Line Tools"
		echob "      then re-run CloverGrower.command"
		open "http://developer.apple.com/downloads/"
	
		echob "Good $hours $user"
		tput bel
		exit 1
	else
		echob "      Running on $rootSystem, Getting Command Line Tools from Apple"
		echob "      re-run CloverGrower.command AFTER installing.."
		xcode-select --install
		echob "Good $hours $user"
		exit 1
	fi		
fi
#check for space in Volume name
CLOVER_GROWER_DIR_SPACE=`echo "$CLOVER_GROWER_DIR" | tr ' ' '_'`
if [[ "$CLOVER_GROWER_DIR_SPACE" != "$CLOVER_GROWER_DIR" ]]; then
	echob "Space in Volume Name Detected!!"
	echob "Recomend you change Volume Name"
	echob " From:" 
	echob "      ${CLOVER_GROWER_DIR}"
	echob "   To:"
	echob "      ${CLOVER_GROWER_DIR_SPACE}"
	echob "You MUST change name to continue"
	echob "Press any to exit "
	read ansr
	echob "OK, change name yourself and re-run ${CLOVER_GROWER_SCRIPT}"
	echob "Good $hours $user"
	exit		
fi	

#vars
export workDIR="${CLOVER_GROWER_DIR}"
export TOOLCHAIN=~/src/opt/local
workSpace=$(df -m "${workDIR}" | tail -n1 | awk '{ print $4 }')
workSpacePKGDIR=
workSpaceNeeded="522"
workSpaceMin="104"
filesDIR="${workDIR}"/Files
notifier="${filesDIR}"/terminal-notifier.app/Contents/MacOS/terminal-notifier
[ -f "${workDIR}"/.edk2DIR ] && edk2DIR=$(cat "${workDIR}"/.edk2DIR) && [ ! -d "${edk2DIR}"/.svn ] && rm -rf "${workDIR}"/.edk2DIR 
while [ ! -f "${workDIR}"/.edk2DIR ]; do # folder with edk2 svn
	echo "edk2 folder is NOW universal"
	echob "To use Default, press return/enter"
	echo "OR"
	echob "drag in edk2 folder and press return/enter"
	read my_edk2DIR
	if [ ! -d "$my_edk2DIR" ]; then
		my_edk2DIR="${workDIR}"/edk2
		echo "$my_edk2DIR" > "${workDIR}"/.edk2DIR
	else
		echo "$my_edk2DIR" > "${workDIR}"/.edk2DIR
		break
	fi
done
edk2DIR=$(cat "${workDIR}"/.edk2DIR)
edk2DIRName=$(basename "${edk2DIR}")
edk2DIRParent=$(dirname "${edk2DIR}")
echo "Using..."
echob "       $edk2DIR"
echo "        as edk2 source folder"
CloverDIR="${edk2DIR}"/Clover
rEFItDIR="${CloverDIR}"/rEFIt_UEFI
buildDIR="${edk2DIR}"/Build
cloverPKGDIR="${CloverDIR}"/CloverPackage
builtPKGDIR="${workDIR}"/builtPKG

if [ -d "${builtPKGDIR}" ]; then
	workSpacePKGDIR=$(du -sh "${builtPKGDIR}" | tail -n1 | awk '{ print $1 }')
fi

theBuiltVersion=""
theAuthor=""
style=release
gFWLoader=
# Shortcut and link
if [[ ! -L "$theShortcut"/CloverGrower.command || $(readlink "$theShortcut"/CloverGrower.command) != "$CLOVER_GROWER_SCRIPT" ]]; then
	if [[ ! -L /usr/local/bin/clover || $(readlink /usr/local/bin/clover) != "$CLOVER_GROWER_SCRIPT" ]]; then
		echob "Running CloverGrower.command"
		theText="link"
		echob "To make CloverGrower V$myV easier to use"
		echob "I will do one of the following:"
		echo "    Create link, in /usr/local/bin.     Select any key"
		echo "    Create Shortcut, put it on Desktop. Select 's'"
		echob "    Type 's' OR any key"
		read theSelect
		case "$theSelect" in
                s|S)
                     theLink="$theShortcut"/CloverGrower.command
                     theText="shortcut"
                     sudoit=
                     ;;
                *)
                sudoit="sudo"
        esac
		printf "Will create link %s to %s\n" $(echob "$theLink") $(echob "CloverGrower.command")
		if [ "$theLink" == /usr/local/bin/clover ]; then
			echob "You can THEN 'run' CloverGrower.command by typing 'clover' ;)"
			if [ ! -d /usr/local/bin ]; then
				command='sudo mkdir -p /usr/local/bin'; echob "$command" ; eval "$command"
			fi
		else
			echob "You can THEN run by double clicking CloverGrower.command on Desktop"
		fi		
		command='$sudoit ln -sf "${CLOVER_GROWER_SCRIPT}" "$theLink" && $sudoit chown $theBoss "$theLink"'
		echob "$command" ; eval "$command"
	fi
fi

if [[ ! -f "${workDIR}"/vers.txt ]]; then
	echo $myV >"${workDIR}"/vers.txt
fi	
flagTime="No" # flag for complete download/build time, GCC, edk2, Clover, pkg

# Check for svn
[[ -z $(type -P svn) ]] && { echob "svn command not found. Exiting..." >&2 ; exit 1; }


if [[ ! -d "$edk2DIR" && "$workSpace" -lt "$workSpaceNeeded" ]]; then
	echob "error!!! Not enough free space"
	echob "Need at least $workSpaceNeeded bytes free"
	echob "Only have $workSpace bytes"
	if [ "$workSpacePKGDIR" == "" ]; then
		echob "move CloverGrower to different Folder"
		echob "OR free some space"
		exit 1
	else
		echob "You have $workSpacePKGDIR MB in builtPKGDIR"
		exit 1
	fi			
elif [[ "$workSpace" -lt "$workSpaceMin" ]]; then
	echob "Getting low on free space"
fi
workSpaceAvail="$workSpace"


# simple spinner
function spinner()
{
    local pid=$1
    #local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        #sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
		
function notify(){
if [ -f "${notifier}" ] && [ "${theSystem}" -ge "12" ]; then
	Title="CloverGrower V$myV"
	#$1 = Message
	echob "$Title $1"
	"${notifier}" -message "$1" -title "$Title"
else
	echob "$1"
fi		
}	

function checkAuthor(){
	if [ "$1" == "Initial" ] || [ "$2" == "this" ]; then
		theFlag=""
	else 
		theFlag="-r $2"
	fi
	cloverInfo=
	while [ "$cloverInfo" == "" ]; do	
		cloverInfo=$(svn info ${theFlag} svn://svn.code.sf.net/p/cloverefiboot/code)
		theAuthor=$(echo "$cloverInfo" | grep 'Last Changed Author:')
		sleep 1
	done
}

# set up Revisions Clover
function getREVISIONSClover(){
checkAuthor "$1" "$2"
newCloverRev=
cloverstats=$(echo "$cloverInfo" | grep 'Revision')
export CloverREV="${cloverstats:10:10}"
theAuthor=$(echo "$cloverInfo" | grep 'Last Changed Author:')
[ ! -d "${CloverDIR}" ] && mkdir -p "${CloverDIR}"
if [ "$1" == "Initial" ]; then
	echo "${CloverREV}" > "${CloverDIR}"/Lvers.txt	# make initial revision txt file
else
	newCloverRev="${CloverREV}"	
fi	
#rEFIt
refitstats=`svn info svn://svn.code.sf.net/p/cloverefiboot/code/rEFIt_UEFI | grep 'Last Changed Rev:'`
export rEFItREV="${refitstats:18:10}"

}

# set up Revisions edk2
function getREVISIONSedk2(){
checksvn=$(svn info svn://svn.code.sf.net/p/edk2/code/trunk/edk2 | grep "Revision")
sleep 1
export edk2REV="${checksvn:10:5}"
if [ "$1" == "Initial" ]; then
	basestats=$(svn info svn://svn.code.sf.net/p/edk2/code/trunk/edk2/BaseTools/ | grep 'Last Changed Rev')
	sleep 1
	basetools="${basestats:18:5}" # grab basetools revision, rebuild tools IF revision has changed
	echo "${edk2REV}" > "${edk2DIR}"/Lvers.txt	# update revision
	echo "${basetools}" > "${edk2DIR}"/Lbasetools.txt	# update revision
	
fi
}

# checkout/update svn
# $1=Local folder, $2=svn Remote folder
function getSOURCEFILE() {
	[ ! -d "${edk2DIR}" ] && mkdir "${edk2DIR}"
	[ "$1" == edk2 ] && cd "${edk2DIRParent}"
	[ "$1" == Clover ] && cd "${edk2DIR}" 
	getREVISIONS${1} Initial this # flag to write initial revision
	if [ ! -d "$1"/.svn ]; then
      	echo -n "    Check out $1  "
		(svn co "$2" "$1" >/dev/null) &
	else
    	if [ "$1" == "Clover" ] && [ -d "${CloverDIR}"/.svn ]; then
			theFlag="up --revision ${versionToBuild}"
		else 
			theFlag="up"
		fi
    	cd "$1"
    	echo -n "    Auto Update $1  "
		(svn $theFlag . >/dev/null) &
    fi
	spinner $!
	checkit "  SVN $1"
}

# sets up svn sources
function getSOURCE() {
    edk2Update="Yes"
    # Don't update edk2 if no Clover updates
    if [[  "${cloverUpdate}" == "Yes" ]]; then
    	if [[ -d "${edk2DIR}"/.svn ]]; then # get svn revision
    		getREVISIONSedk2 test
    		Ledk2=`cat "${edk2DIR}"/Lvers.txt`
			if [[ "$edk2REV" == "$Ledk2" ]]; then
				echob "edk2 svn revision = edk2 local revision ( $edk2REV )" # same return
				edk2Update="No"
			else
				echob "edk2 local will be updated from $Ledk2 to $edk2REV" # updated
			fi
		fi		   	  	
        # Get edk2 source
        if [[ "$edk2Update" == "Yes" ]]; then
        	#cd "${edk2DIR}"
	    	getSOURCEFILE edk2 svn://svn.code.sf.net/p/edk2/code/trunk/edk2  # old repo "http://edk2.svn.sourceforge.net/svnroot/edk2/trunk/edk2"
	    	
	    	echo "$edk2REV" > "${edk2DIR}"/Lvers.txt # update the version
	      fi	
	fi
	cd "${edk2DIR}"
	# Get Clover source
    getSOURCEFILE Clover "svn://svn.code.sf.net/p/cloverefiboot/code/"
    
    GETTEXT_PREFIX=${GETTEXT_PREFIX:-"${HOME}"/src/opt/local}
	# Check that the gettext utilities exists
	if [[ ! -x "$GETTEXT_PREFIX/bin/msgmerge" ]]; then
		echob "Need getttext for package builder, Fixing..."
    	"${CloverDIR}"/buildgettext.sh
  		checkit "buildtext.sh"
	fi

}

# compiles X64 or IA32 versions of Clover and rEFIt_UEFI
function cleanRUN(){
	builder=gcc
	bits=$1
	theBits=$(echo "$bits" | awk '{print toupper($0)}')
	theBuilder=$(echo "$builder" | awk '{print toupper($0)}')
	theStyle=$(echo "$style" | awk '{print toupper($0)}')
	clear
	echo "	Starting Build Process: $(date -j +%T)"
	echo "	Building Clover$theBits: gcc${mygccVers} $style"
	clear
	if [[ "$myArch" == "i386" || "$archBit" == "i686" ]]; then # if 32bit processor
		archBits='IA32'
	elif [ "$bits" == "X64/IA32" ]; then
		archBits='x64 mc ia32'
	else
		archBits='x64'
	fi
	cd "${CloverDIR}"
	for az in $archBits ; do
		echob "	 running ./ebuild.sh -gcc${mygccVers} -$az -$style"
		sleep 2
		./ebuild.sh -$az -r
		checkit "Clover${az}_r${versionToBuild} $theStyle"
		#rm -rf "${buildDIR}"
	done	
}
	
# sets up 'new' sysmlinks for >=gcc47
function MakeSymLinks() {
# Function: SymLinks in CG_PREFIX location
# Need this here to fix links if Files/.CloverTools gets removed
    if [[ "$target" == "IA32" ]] || [[ "$myArch" == "i386" ]]; then
    	DoLinks "ia32" "i686-clover-linux-gnu" # only for 32bit cpu
    else	
        DoLinks "x86_64"  "x86_64-clover-linux-gnu" # for 64bit CPU
        DoLinks "i686" "i686-clover-linux-gnu" # ditto
    fi    
}

#makes 'new' syslinks
function DoLinks(){
    ARCH="$1"
    TARGETARCH="$2"
    if [[ ! -d "${TOOLCHAIN}/${ARCH}" ]]; then
        mkdir -p "${TOOLCHAIN}/${ARCH}"
    fi
    if [[ $(readlink "${TOOLCHAIN}/${ARCH}"-clover-linux-gnu/bin/gcc) != "${CG_PREFIX}"-clover-linux-gnu/bin/gcc ]]; then # need to do this
        echo "  Fixing your GCC${mygccVers} ${ARCH} Symlinks"
        for bin in gcc ar ld objcopy; do
            ln -sf "${CG_PREFIX}"/bin/$TARGETARCH-$bin  "${TOOLCHAIN}/${ARCH}"/$bin
        done
        echo "  Finished: Fixing"
        echo "  symlinks are in: ${TOOLCHAIN}/$ARCH"
    fi
}

# checks for gcc install and installs if NOT found
function checkGCC(){
    export mygccVers="${gccVers:0:1}${gccVers:2:1}" # needed for BUILD_TOOLS e.g GCC46
    echob "Checking GCC$gccVers INSTALL status"
    if [ -x "${CG_PREFIX}/${archBit}"-clover-linux-gnu/bin/gcc ]; then
    	local lVers=$("${CG_PREFIX}/${archBit}"-clover-linux-gnu/bin/gcc -dumpversion)
        export mygccVers="${lVers:0:1}${lVers:2:1}" # needed for BUILD_TOOLS e.g GCC46
        echo "  gcc $lVers detected"
        echo "  Fixing gcc…"
        MakeSymLinks
        return
    fi
	echob "$archBit GCC$gccVers NOT installed";echo
	echob "Press 'i' To install to ~/src/opt/local"
	echob "OR"
	echob "Press RETURN/ENTER' to 'EXIT' CloverGrower V$myV"
	read choose
	[[ "$choose" == "" ]] && echob "Good ${hours}" && exit 1
	[ ! -d "${CG_PREFIX}"/src ] && mkdir -p "${CG_PREFIX}"/src
	cd "${workDIR}"/Files
	echo "  Download/install GCC$gccVers Compiler Tool"
	echob "  To: ${CG_PREFIX}"
	sleep 2
	echo "  Files/buildgcc -all ${CG_PREFIX} $gccVers"
	echob "  Starting GCC$gccVers build process..." 
	STARTM=$(date -u "+%s" 1>/dev/null )
	date
	("${filesDIR}"/buildgcc.sh "-all") # "${CG_PREFIX}" "$gccVers")  # build all to CG_PREFIX with gccVers
	checkit "GCC$gccVers build process..."	
}

# main function
function Main(){
	STARTD=$(date -j "+%d-%h-%Y")
	theARCHS="$1"
	[ -f "${edk2DIR}"/Lvers.txt ] && edk2Local=$(cat "${edk2DIR}"/Lvers.txt)
	echo $(date)
	cloverLocal=${cloverLocal:=''}
	echob "*******************************************"
	echob "$buildMess"
	echob "*    Revisions:- edk2: $edk2Local              *"
	echob "*              Clover: $CloverREV            *"
	echob "*    Using Flags: gcc$mygccVers ${targetBitsMess} $style  *"
	echob "*******************************************"
	STARTT=$(date -j "+%H:%M")
	STARTM=$(date -u "+%s")
	cleanRUN "$theARCHS"
}

autoBuild(){
	
	if [ "$built" == "No " ]; then
		buildMess="*    Auto-Build Full Clover rEFIt_UEFI    *"
		cleanMode=""
		targetBits="$1"
		targetBitsMess="${targetBits}"
		Main "${targetBits}"
		built="Yes"
	fi	
}	

# makes pkg if Built OR builds THEN makes pkg
function makePKG(){
	#set -x
	versionToBuild=""
	cloverUpdate="No"
	theBuiltVersion=
	getREVISIONSClover "test" "this" # get Clover SVN revision, returns in CloverREV, "test" is dummy flag, does NOT write revision in folder
	versionToBuild="${CloverREV}" # Clover not checked out so use it.
	#echo "Revision: ${CloverREV}" && exit
	echo
	echob "********************************************"
	echob "*             Good $hours              *"
	echob "*      Welcome To CloverGrower V$myV       *"
	echob "*        This script by STLVNUB            *"
	echob "* Clover Credits: Slice, dmazar and others *"
	echob "********************************************"
	echob "Forum: http://www.projectosx.com/forum/index.php?showtopic=2562"
	echob "Wiki:  http://clover-wiki.zetam.org:8080/Home"
	if [[ "${gRefitVers}" == "0" && "${gTheLoader}" != "Apple" ]] && [ "$gFWLoader" != "Ozmosis" ]; then 
		echob "Booting with ${gTheLoader} UEFI, Clover is NOT currently Installed"
	else
			echob "${gCloverLoader}"
	fi
	if [ "$theRevision" == "" ]; then
		echo
		echob "Stats   :-Clover          Stats           :-WorkSpace"
		echob "Clover  : revision: ${CloverREV}  Work Folder     : $workDIR"
		echob "Target  : $target        Available Space : ${workSpaceAvail} MB"
		echob "Compiler: GCC $gccVers       builtPKGDIR     : ${workSpacePKGDIR}"
		echob "User: $user running '$(basename $CMD)' on OS X '$rootSystem' :)"
		[[ -d "${builtPKGDIR}" ]] && theBuiltVersion=`ls -t "${builtPKGDIR}"` && [[ $theBuiltVersion != "" ]] && theBuiltVersion="${theBuiltVersion:0:4}"
		if [[ -f "${builtPKGDIR}/${versionToBuild}/Clover_v2k_r${versionToBuild}".pkg ||  -d "${builtPKGDIR}/${versionToBuild}/CloverCD" ]] && [ -d "$	{CloverDIR}" ]; then # don't build IF pkg already here
			if [ "${theBuiltVersion}" == "${versionToBuild}" ]; then
				built="Yes"
			else
				built="No "
				cloverUpdate="Yes"
			fi
			echob "*********Clover Build STATS***********"
			echob "*      remote revision at ${CloverREV}       *" 
			echob "*      local  revision at ${versionToBuild}       *"
			if [ "$built" == "Yes" ]; then
				echob "* Clover_v2k_r${versionToBuild}.pkg ALREADY Made!  *"
				echob "**************************************"
				if [[ "${versionToBuild}" -gt "${gRefitVers}" ]]; then
					echob "Updated package (${versionToBuild}) NOT installed!!"
					echob "Opening ${versionToBuild} Folder"
					open "${builtPKGDIR}"/"${versionToBuild}"
 				fi	
				return
			fi
			echob "*      Package Built   =  $built        *"
			echob "**************************************"
		fi
	fi	
	if [[ -f "${edk2DIR}"/Basetools/Source/C/bin/VfrCompile ]]; then
		if [[ -d "${CloverDIR}" && -d "${rEFItDIR}" && "$theRevision" == "" ]]; then
			cloverLVers=$(getSvnRevision "${CloverDIR}")
			if [[ "$theAuthor" == "Last Changed Author: pootle-clover" ]]; then
           		echob "*********Clover Build STATS***********"
				echob "*      local  revision at ${cloverLVers}       *"
				echob "*      remote revision at ${CloverREV}       *"
				echob "*      Package Built   =  $built        *"
				echob "**************************************"
				if [[ "${theBuiltVersion}" != "" ]]; then
					ToBuildVersion=$CloverREV
					echob "Last successful build was ${theBuiltVersion}"
					while [ "$theAuthor" == "Last Changed Author: pootle-clover"  ]
					do
						echob "Commit was from 'pootle-clover'"
						echob "so Auto backtracking a revision"
						let ToBuildVersion--
						echob "Trying r${ToBuildVersion}"
						getREVISIONSClover "test" ${ToBuildVersion}
						echob "Found ${newCloverRev} $theAuthor"
					done 
            		echob "Continuing using r${newCloverRev}"
            		versionToBuild=${newCloverRev}
            		cloverLVers=${newCloverRev}
            		newCloverRev="" #
            		cloverUpdate="Yes"
            	fi	
            fi	
			if [[ "${cloverLVers}" != "${CloverREV}" ]]; then
            	cd "${CloverDIR}"
           		echo "$CloverREV" > Lvers.txt # update the version
           		notify "Clover Update ( $CloverREV ) Detected !"
           		cloverUpdate="Yes"
           		echob "*********Clover Build STATS***********"
				echob "*      local  revision at ${cloverLVers}       *"
				echob "*      remote revision at ${CloverREV}       *"
				echob "*      Package Built   =  $built        *"
				echob "**************************************"
				echob "svn changes for $CloverREV"
   				changesSVN=$(svn log -v -r "$CloverREV")
   				echob "$changesSVN"
       			tput bel
       			cd ..
       		elif [[ ! -f "${builtPKGDIR}/${versionToBuild}/Clover_v2k_r${versionToBuild}".pkg ]] && [[ "${versionToBuild}" != "${cloverLVers}" ]]; then
       			echob "Clover_v2k_r${versionToBuild}.pkg NOT built"
       			cloverUpdate="Yes"
    		elif [[ -f "${builtPKGDIR}/${versionToBuild}/Clover_v2k_r${versionToBuild}".pkg ]]; then
       			echob "Clover_v2k_r${versionToBuild}.pkg built"
       			return 0
       		else
            	echob "No Clover Update found."
            	echob "Current revision: ${cloverLVers}"
            fi
    	else
    		[ -d "${buildDIR}" ] && rm -rf "${buildDIR}"
    	fi		
    else 
	    cloverUpdate="Yes"
    fi
    if [[ ! -e "${edk2DIR}"/edksetup.sh ]]; then
    	getREVISIONSedk2 "test"
    	if [[ -d "${edk2DIR}"/.svn ]]; then
    		echob "svn edk2 revision: ${edk2REV}"
    		echob "error!!! RETRY!!"
	    	cd "${edk2DIR}"
	    	svn cleanup
	    	
	    	echo -n "    Auto Fixup edk2  "
	    	(svn up --non-interactive --trust-server-cert >/dev/null) &
	    	spinner $!
			checkit "edk2  "
		fi		
	fi	
	if [ "$theRevision" != "" ]; then	
		versionToBuild="${theRevision}"
		cloverUpdate="Yes"
	else
   	 	versionToBuild="${CloverREV}"
	fi
	if [[ ! -d "${edk2DIR}"/.svn || ! -d "${rEFItDIR}" || "$cloverUpdate" == "Yes" ]]; then # only get source if NOT there or UPDATED.
    	echob "Getting SVN Source Files, Hang ten, OR TWENTY"
    	getSOURCE
   	elif [ "$theRevision" == "" ]; then
   		versionToBuild="${cloverLVers}"
   	fi 
   	if [[ ! -f "${CloverDIR}"/HFSPlus/X64/HFSPlus.efi ]]; then  # only needs to be done ONCE.
        echob "    Copy Files/HFSPlus Clover/HFSPlus"
    	cp -R "${filesDIR}/HFSPlus/" "${CloverDIR}/HFSPlus/"
    fi
   	# Remove old edk2 config files
   	rm -f "${edk2DIR}"/Conf/{BuildEnv.sh,build_rule.txt,target.txt,tools_def.txt}
	# Create new default edk2 files in edk2/Conf
   	cd "${edk2DIR}"
   	./edksetup.sh >/dev/null
  	 #get configuration files from Clover
    cp -R "${CloverDIR}/Patches_for_EDK2/tools_def.txt"  "${edk2DIR}"/Conf/
    cp -R "${CloverDIR}/Patches_for_EDK2/build_rule.txt" "${edk2DIR}"/Conf/
    echob "    Ready to build Clover $versionToBuild, Using Gcc $gccVers"
    sleep 1
    autoBuild "$1"
    tput bel
    echo "$CloverREV" > "${CloverDIR}"/Lvers.txt
	if [ ! -f "${builtPKGDIR}/${versionToBuild}/Clover_v2k_r${versionToBuild}".pkg ]; then # make pkg if not there
		cd "${CloverDIR}"/CloverPackage
		if [[ "$target" != "IA32" ]]; then
			[[ -f "${builtPKGDIR}/${versionToBuild}" ]] && rm -rf "${builtPKGDIR}/${versionToBuild}" # need to delete in case of failed build
			echob "Making Clover_v2k_r${versionToBuild}.pkg..."
			[[ -d "${CloverDIR}"/CloverPackage/sym ]] && rm -rf "${CloverDIR}"/CloverPackage/sym
			echob "cd to src/edk2/Clover/CloverPackage and run ./makepkg."
			./makepkg "No"
			
			if [ ! -f "${CloverDIR}/CloverPackage/sym/Clover_v2k_r${versionToBuild}".pkg ]; then 
				echob "Package ${versionToBuild} NOT BUILT!!!, probably svn error :("
				echob "REMOVE Clover folder from src/edk2 and re-run CloverGrower V$myV :)"
				exit 1
			else
				echob "Clover_v2k_r${versionToBuild}.pkg	successfully built"
			fi
		fi	
		echob "run ./makeiso"
		./makeiso "No"
		
		if [ "$flagTime" == "Yes" ]; then
			STOPBM=$(date -u "+%s")
			RUNTIMEMB=$(expr $STOPBM - $STARTM)
			if (($RUNTIMEMB>59)); then
				TTIMEMB=$(printf "%dm%ds\n" $((RUNTIMEMB/60%60)) $((RUNTIMEMB%60)))
			else
				TTIMEMB=$(printf "%ds\n" $((RUNTIMEMB)))
			fi
			echob "CloverGrower V$myV Complete Build process took $TTIMEMB to complete..."
		else
			STOPM=$(date -u "+%s")
			RUNTIMEM=$(expr $STOPM - $STARTM)
			if (($RUNTIMEM>59)); then
				TTIMEM=$(printf "%dm%ds\n" $((RUNTIMEM/60%60)) $((RUNTIMEM%60)))
			else
				TTIMEM=$(printf "%ds\n" $((RUNTIMEM)))
			fi	
			echob "Clover revision $CloverREV Compile/MKPkg process took $TTIMEM to complete" 
		fi
		[[ ! -d "${builtPKGDIR}/${versionToBuild}" ]] && echob "mkdir -p buildPKG/${versionToBuild}." && mkdir -p "${builtPKGDIR}"/"${versionToBuild}"
		echob "cp edk2/Clover/CloverPackage/sym/ builtPKG/${versionToBuild}."
		if [[ "$target" != "IA32" ]]; then
			cp -R "${CloverDIR}"/CloverPackage/sym/Clover* "${builtPKGDIR}"/"${versionToBuild}"/
		else
			cp -R "${CloverDIR}"/CloverPackage/sym/* "${builtPKGDIR}"/"${versionToBuild}"/
		fi	
		echob "rm -rf edk2/Clover/CloverPackage/sym"
		rm -rf "${CloverDIR}"/CloverPackage/sym
		echob "rm -rf src/edk2/Build Folder"
		echob "Auto open Clover_v2k_r${versionToBuild}.pkg."
		open "${builtPKGDIR}"/"${versionToBuild}/Clover_v2k_r${versionToBuild}.pkg"
		tput bel
	fi
	
}

getInstalledLoader(){
	local efi=`ioreg -l -p IODeviceTree | grep firmware-abi | awk '{print $5}'`
    local efiBITS="${efi:5:2}"
    if [ "${efiBITS}" == "32" ]; then
    	efiBITS="IA32"
    elif [ "${efiBITS}" == "64" ]; then
       	efiBITS="X64"
    else
    	efiBITS="WhoKnows"   	
    fi
    
    # Discover current bootloader and associated version.
    gRefitVers="0"
    gTheLoader=$(ioreg -l -pIODeviceTree | grep firmware-vendor | awk '{print $5}' | sed 's/_/ /g' | tr -d "<\">" | xxd -r -p)
    gBootLog=$(ioreg -lw0 -pIODeviceTree | grep boot-log | tr -d \
            "    |       "boot-log" = <\">" | LANG=C sed -e 's/.*72454649742072657620//' -e 's/206f6e20.*//' | xxd -r -p | sed 's/:/ /g')
            
    if [[ "$gTheLoader" == "Apple" ]]; then
		 gCloverLoader="Booting with Apple EFI ${efiBITS}"
		 gRefitVers="1"
		 return 0
	fi
	if [[ "$gTheLoader" == "American Megatrends" ]]; then
		gFWLoader=$(echo $gBootLog | awk '{print $5}')
	fi
	if [ "$gFWLoader" == "Ozmosis" ]; then
		gFWVers=$(echo $gBootLog | awk '{print $6}')
		gCloverLoader="Booting with $gFWLoader r$gFWVers EFI :) on $gTheLoader"
	elif [[ "$gTheLoader" != "" ]]; then
    	gRefitVers=$(ioreg -lw0 -pIODeviceTree | grep boot-log | tr -d \
            "    |       "boot-log" = <\">" | LANG=C sed -e 's/.*72454649742072657620//' -e 's/206f6e20.*//' | xxd -r -p | sed 's/:/ /g')
        gCloverLoader="Booting via Clover r${gRefitVers} BOOT${efiBITS}.efi with ${gTheLoader} UEFI"
    elif [[ "$gTheLoader" == "" ]]; then
        gTheLoader="Unknown_${efiBITS}"
	elif [[ "$gTheLoader" == "CLOVER" ]]; then
		gTheLoader="Clover_${efiBITS}_${gRefitVers}"
	else
		local tmp=""
        tmp=`ioreg -p IODeviceTree | grep RevoEFI`
        if [ ! "$tmp" == "" ]; then 
        	gTheLoader="RevoBoot_${efiBITS}"
        else
            gTheLoader="${gTheLoader}_${efiBITS}"
        fi
    fi  
}
# setup gcc
export CG_PREFIX="${TOOLCHAIN}"/cross 
if [ ! -x "${CG_PREFIX}/${archBit}"-clover-linux-gnu/bin/gcc ]; then
		checkGCC
fi
getInstalledLoader # check what user is Booting with ;)
export mygccVers="${gccVers:0:1}${gccVers:2:1}" # needed for BUILD_TOOLS e.g >GCC47 
buildMess="*    Auto-Build Full Clover rEFIt_UEFI    *"
cleanMode=""
built="No "
makePKG "$target" # do complete build
notify "Good $hours $user, Thanks for using CloverGrower V$myV" 
