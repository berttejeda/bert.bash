if [[ "$OSTYPE" =~ .*darwin.* ]];then
  os_is_osx=true
elif [[ "$OSTYPE" =~ .*linux.* ]];then
  os_is_linux=true
elif [[ "$OSTYPE" =~ .*msys.* ]];then
  os_is_windows=true
fi

if [[ -n $os_is_windows ]];then
  if [[ -z $EDITOR_PATH ]];then
    export EDITOR_PATH="C:\Program Files\Sublime Text 3\subl.exe"
  fi
else
  export EDITOR_PATH=${EDITOR_PATH-$(which subl)}
fi  

export EDITOR_COMMAND="${EDITOR_COMMAND-'${EDITOR_PATH}' -a}"
export EDITOR_COMMAND_W_WAIT="${EDITOR_COMMAND_W_WAIT-'${EDITOR_PATH}' -w}"

# sublime text
function subl() { 
  eval "${EDITOR_COMMAND}" ${*}
}
if [[ -n $LOCALIZED_HISTORY ]];then 
    # initial shell
    export HISTFILE="${HOME}/.history/${PWD##*/}.dir_bash_history"
    [[ -d ~/.history ]] || mkdir -p ~/.history
    # timestamp all history entries                                                                            
    export HISTTIMEFORMAT="%h/%d - %H:%M:%S "
    export HISTCONTROL=ignoredups:erasedups
    export HISTSIZE=1000000
    export HISTFILESIZE=1000000
    shopt -s histappend ## append, no clearouts                                                               
    shopt -s histverify ## edit a recalled history line before executing                                      
    shopt -s histreedit ## reedit a history substitution line if it failed                                    
    ## Save the history after each command finishes                                                           
    ## (and keep any existing PROMPT_COMMAND settings)                                                        
    export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
    alias cd='if ! [ -w ${2} ];then HISTFILE=~/.history/.bash_history;fi;cd.remember.history "${HOME}/.history/${PWD##*/}.dir_bash_history"'
    history.recall() { 
        if [ ! $@ ] ; then 
           echo "Usage: ${FUNCNAME[0]} <PATTERN>" 
           echo "where PATTERN is a part of previously given command" 
        else 
             grep -h $@ <(history) ~/.history/* | grep -vi "${FUNCNAME[0]}" | more; 
        fi 
    }
    function cd.remember.history()
    {
        # Keep history on a per-directory basis
        # History file is written to according to value of $PWD
        # Default History folder is ~/.history
        curDir="${PWD}"
        curDir_Name="${curDir##*/}"
        curDir_HISTFILE="${HOME}/.history/${curDir_Name}.dir_bash_history"
        export HISTFILE=${1// /_}
        desDir="${2}"
        dir.check(){
            if ! [[ -d "${1}" ]];then
                echo "The directory ${desDir} does not exist!
                You must check yourself before you wreck yourself ..."
                return 1
            fi
        }
        ##### actions logic
        #@special
        ### destination is a special bash variable
        ### e.g. .. ... ....
        if [[ $desDir =~ ^\.*\.$ ]];then 
            #### need to evaluate path
            desDir=$(\cd $desDir && pwd)
            desDir_Name=${desDir##*/}
            dir.check "${desDir}" || return 1
            if [[ ${DEBUG} ]];then echo "${desDir} matched @special, match on ${BASH_REMATCH}";fi
        #@previous
        ### destination matches - shortcut
        ### e.g. -
        elif [[ $desDir == '-' ]];then
            desDir=$(builtin cd $desDir)
            desDir_Name=${desDir##*/}
            dir.check "${desDir}" || return 1
            if [[ ${DEBUG} ]];then echo "${desDir} matched @previous";fi            
        #@hidden
        ### destination begins with a dot followed by an alphanumeric character
        ### e.g. .git
        elif [[ $desDir =~ ^\.[[:alnum:]] ]];then 
            #### need to strip the first character
            desDir_Name=${desDir:1}
            dir.check "${desDir}" || return 1
            if [[ ${DEBUG} ]];then echo "${desDir} matched @hidden, match on ${BASH_REMATCH}";fi
        #@standard
        ### destination begins with an alphanumeric character 
        ### and ends with the same, with no non-alphanumeric characters in between
        ### e.g. git, home, root
        elif [[ $desDir =~ ^[[:alnum:]]*[[:alnum:]]$ ]];then
            #### need to leave as is
            desDir_Name=${desDir}
            dir.check "${desDir}" || return 1
            if [[ ${DEBUG} ]];then echo "${desDir} matched @standard, match on ${BASH_REMATCH}";fi
        #@root
        elif [[ $desDir == "/" ]];then
            desDir_Name=ROOT
            dir.check "${desDir}" || return 1
            if [[ ${DEBUG} ]];then echo "${desDir} matched @root";fi
        #@fqpath
        else
            desDir_Name=${desDir##*/}
            dir.check "${desDir}" || return 1
            # account for fully qualified paths directly under /
            if [[ -z $desDir_Name ]];then desDir_Name=${desDir#*/};fi
            # account for fully qualified paths matching path/
            if [[ -z $desDir_Name ]];then desDir_Name=${desDir};fi
            if [[ ${DEBUG} ]];then echo "${desDir} matched @fqpath, dir name is ${desDir_Name}";fi
            #   account for fully qualified paths directly under ROOT(/)
            if [[ -z $desDir_Name ]];then desDir_Name=${desDir#*/}
            #   account for fully qualified paths matching ${path}/
                elif [[ -z $desDir_Name ]];then desDir_Name=${desDir%/*}
            fi
            if [[ ${DEBUG} ]];then echo "${desDir} matched @fqpath, dir name is ${desDir_Name}";fi
        fi
        # additional sanitization
        # remove trailing slashes from directory specification, except for / path
        if [[ (! $desDir == "/") && ($desDir =~ \/$) ]];then
            desDir=${desDir:0: ${#desDir} - 1}
            desDir_Name=${desDir:0: ${#desDir_Name} - 1}
            if [[ $desDir =~ .*\/.* ]];then desDir_Name=${desDir##*/};fi
        fi
        if [[ ${DEBUG} ]];then
            echo "desDir is ${desDir}"
            echo "desDir_Name is $desDir_Name"
        fi
        desDir_Name=${desDir_Name// /_}
        dex_file_name=".${desDir_Name}.dex"
        dex_file_path="${desDir}/${dex_file_name}"
        if [[ ${DEBUG} ]];then 
            echo "dex filename is ${dex_file_name}, path is ${dex_file_path}"
            if ! [[ -f ${dex_file_path} ]]; then echo "dex file ${dex_file_path} does not exist";fi
        fi
        if [[ -f ${dex_file_path} ]]; then
            source "${dex_file_path}"
        fi
        builtin cd "${desDir}" # do actual cd
        if [[ -w "${desDir}" ]]; then 
            export HISTFILE="${HOME}/.history/${desDir_Name}.dir_bash_history"
            touch $HISTFILE
            if [[ ${DEBUG} ]];then echo "${desDir} is writable";fi
            echo "#"`date '+%s'` >> "${curDir_HISTFILE}"
            echo "cd ${2}" >> "${curDir_HISTFILE}"
            echo "#"`date '+%s'` >> $HISTFILE
        else
            export HISTFILE=~/.history/${desDir_Name}.dir_bash_history
            if [[ ${DEBUG} ]];then echo "${desDir} is not writable";fi
            echo "#"`date '+%s'` >> "${curDir_HISTFILE}"
            echo "cd ${2}" >> "${curDir_HISTFILE}"
            echo "#"`date '+%s'`"$@" >> $HISTFILE
        fi
        if [[ ${DEBUG} ]];then echo "HISTFILE is $HISTFILE";fi
    }
fi

# Text formatting
text.format(){

  if [[ ($# -lt 1) ]]; then 
    echo "Usage: ${FUNCNAME[0]} <bold, underline, green, blue, etc> <text>"
    return 0
  fi  
  PREFIX=""
  local color=$1 
  local string=$2
  declare -A colors=( 
    ["bold"]="bold" 
    ["underline"]="smul"
    ["none"]="sgr0"
    ["red"]="setaf 1"
    ["green"]="setaf 2"
    ["yellow"]="setaf 3"
    ["blue"]="setaf 4"
    ["magenta"]="setaf 5"
    ["cyan"]="setaf 6"
    ["white"]="setaf 7"
    ["bg_red"]="setaf 1"
    ["bg_green"]="setaf 2"
    ["bg_yellow"]="setaf 3"
    ["bg_blue"]="setaf 4"
    ["bg_magenta"]="setaf 5"
    ["bg_cyan"]="setaf 6"
    ["bg_white"]="setaf 7"
    )
  eval tput "${colors[$color]}"
}

a() { alias $1=cd\ $PWD; }

topuniq(){ sort|uniq -c|sort "${@:--rn}"; }

# red=$(text.format red)
# yellow=$(text.format yellow)
# blue=$(text.format blue)

if [ -t 1 ] ; then
  red='\033[0;31m'
  green='\033[0;32m'
  blue='\033[0;34m'
  reset='\033[0m' # reset to no color
else
  red=''
  green=''
  blue=''
  reset=''
fi

function confirm() {
  local response
  if [[ ("$*" =~ .*--graphical.*) && ("$OSTYPE" =~ .*darwin.*) ]];then  
  process='''
    on run argv
      display dialog "Proceed?" buttons {"Yes", "No"}
    end run  
  '''
  response=$(osascript - < <(echo -e "${process}"))
  if echo "${response}" | grep -qE ".*[yY][eE][sS]|[yY].*"; then
    return 0
  else
    return 1
  fi
  else
    local msg="${1:-Are you sure?} [y/N] "; shift
    read -r $* -p "$msg" response || echo
    case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
    esac
  fi
}


# Accepts a prefix, ANSI-control format string, and message. Primarily meant for
# building other output functions.
message() {
  local prefix="$1"
  local ansi_format="$2"
  local message=''
  if [[ -z "$3" ]]; then
    read -r -d '' message
  else
    message="$3"
  fi
  local padding="$(echo "$prefix" | perl -pe 's/./ /g')"
  message="$(echo "$message" | perl -pe "s/^/$padding/ unless 1")"
  printf "%b%s %s%b\n" "$ansi_format" "$prefix" "$message" "$FMT_NONE" >&2
}

# Accepts a message either via stdin or as the first argument. Does not exit.
info() {
  message '==>' "$FMT_BOLD" "$@"
}

# Accepts a message either via stdin or as the first argument. Does not exit.
warn() {
  message 'WARNING:' "$FMT_YELLOW" "$@"
}

# Accepts a message either via stdin or as the first argument. Does not exit.
fatal() {
  message 'FATAL:' "$FMT_RED" "$@"
}

# Like `fatal`, but also exits with non-zero status.
abort() {
  fatal "$1"
  exit 1
}

# Indents the given text (via stdin). Defaults to two spaces, takes optional
# argument for number of spaces to indent by.
indent() {
  local num=${1:-2}
  local str="$(printf "%${num}s" '')"
  perl -pe "s/^/$str/"
}


#@ colors
#@ common
#@ prompt
#@ confirm

#@ colors
#@ common
#@ prompt
#@ confirm


create_params(){
  echo -e '''
  while (( "$#" )); do
      for param in "${!params[@]}";do
          if [[ "$1" =~ $param ]]; then
              var=${param//-/_};
              var=${var%|*};
              var=${var//__/};
              if [[ $var ]];then
                  declare ${var%|*}+="${2}";
              else
                  eval "local ${var%|*}=${2}";
              fi;
          fi;
      done;
  shift;
  done
  '''
}

help(){
    #
    # Display Help/Usage
    #
    echo -e "Usage: ${1}"
    params="${2}"
    for param in "${!params[@]}";do
        if [[ $param != 0 ]];then
          echo "param: ${param} ${params[${param}]}"
        fi
    done
}