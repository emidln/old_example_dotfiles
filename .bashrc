# vim: set filetype=bash:
#export TERM=xterm-256color

#if [ -z "$TMUX" ] && [ "$TERM" = "xterm-kitty" ]; then
#  tmux attach || exec tmux new-session && exit;
#fi

export EDITOR=vim
export SYSTEMD_PAGER=
export TZ=/usr/share/zoneinfo/America/Chicago

# turn off software xon/xoff
[[ $- == *i* ]] && stty -ixon

# BEGIN prompt_stuff

# needed for __git_ps1
[[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"

#source /usr/share/git-core/contrib/completion/git-prompt.sh

function append_path {
    if [[ -d "$1" ]]; then
        case ":${2:-$PATH}:" in
            *":$1:"*) :;; # already there
            *) PATH="$1:${2:-$PATH}"
        esac
    fi
}

function prepend_path {
    if [[ -d "$1" ]]; then
        case ":${2:-$PATH}:" in
            *":$1:"*) :;; # already there
            *) PATH="${2:-$PATH}:$1"
        esac
    fi
}

# path-independence
MY_LOCATION="${BASH_SOURCE[0]}"
if [[ "$MY_LOCATION" == "*__dot__*" ]]; then
   MY_BASH_D="$(dirname $MY_LOCATION)/__dot__bash__dot_d"
else
   MY_BASH_D="$(dirname $MY_LOCATION)/.bash.d"
fi

# Source local bash definitions
if [[ -d "${MY_BASH_D}" ]]; then
    for f in $(ls -1 "${MY_BASH_D}"); do
        if [[ -f "${MY_BASH_D}/$f" ]]; then
            . "${MY_BASH_D}/$f"
        fi
    done
fi

export PATH="${HOME}/.fzf/bin:${PATH}"
export PATH="${HOME}/.emacs.d/bin:${PATH}"
export PATH="${HOME}/.cargo/bin:${PATH}"

export GIT_PS1_SHOWCOLORHINTS=1

function expand_ps1 {
	my_ps1=`shift`
	x="$(PS1=\"$PS1\" echo -n | bash --norc -i 2>&1 > /dev/null)"; echo "'${x%exit}'"
	#echo -e "$x"
	echo $x
}
function running_inside_docker {
    # check older fedora and centos7 systems using cgroupsv1
    if rg -q docker /proc/1/cgroup &>/dev/null; then
        return 0
    # check newer fedora systems using cgroups v2
    elif [[ -e /sys/fs/cgroup/cgroup.events ]] && [[ -e /sys/fs/cgroup/cgroup.type ]]; then
        return 0
    fi
    return 1
}

export CONTAINER_INSIDE_DOCKER="$(running_inside_docker ; echo $?)"
function hostname_purple_docker {
    if [[ ${CONTAINER_INSIDE_DOCKER} ]]; then
        echo -en "\\033[38;5;056m\h\\033[0m"
    else
        echo -en "\h"
    fi
}

function prompt() {
    local myps1="\n\u@$(hostname_purple_docker) \[\033[33m\]\w\[\033\[\033[00m\]"
    echo -en "${myps1@P}"
    __git_ps1 ""
    echo ""
    PS1="\$? \\\$ "
}
export PROMPT_COMMAND='prompt'
# track history across all instances of bash
export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"

# END prompt_stuff

# "local" man
function lman() {
    nroff -man "$@" | less -r
}


# default to vi editing
set -o vi

export FZF_DEFAULT_COMMAND="rg --hidden --files --iglob=\"!.git\""
export FZF_DEFAULT_OPTS="--color=16 --bind=ctrl-h:backward-kill-word --filepath-word"

bind -f ~/.inputrc
bind '"\C-x\C-e": shell-expand-line'
function __emidln_fzf_select {
    local __EMIDLN_FZF_CMD="$(tr -d '|'  <<<${@:0:`expr ${#1} - 1`})"
    local __EMIDLN_FZF_QUERY="$(sed -e 's/|$//' <<<${@: -1})"
    # >&2 echo ""
    # >&2 echo "__EMIDLN_FZF_CMD: ${__EMIDLN_FZF_CMD}"
    # >&2 echo "__EMIDLN_FZF_QUERY: ${__EMIDLN_FZF_QUERY}"
    local stdout=$(fzf +m -q "${__EMIDLN_FZF_QUERY}")
    if [[ $? != 0 || -z "$stdout" ]]; then
        echo -n "${__EMIDLN_FZF_CMD} ${__EMIDLN_FZF_QUERY}"
    else
        echo -n "${__EMIDLN_FZF_CMD} ${stdout}"
    fi
}

function __emidln_fzf_history {
    # fzf is going to return `NNN command args...`, so we need to munge it
    local __EMIDLN_FZF_QUERY="$(sed -e 's/|\(.*\) |$/\1/' <<<$*)"
    local stdout=$(\
        set -eo pipefail;
        history \
        | tr -s ' ' \
        | cut -d' ' -f3- \
        | sort -u \
        | fzf --tac --tiebreak=index --bind=ctrl-r:toggle-sort +m -q "${__EMIDLN_FZF_QUERY}" \
        | sed -Ee 's/^[[:space:]]*[0-9]*[[:space:]]*(.*)$/\1/' \
    )
    if [[ $? != 0 || -z "$stdout" ]]; then
        >&2 echo -n "${__EMIDLN_FZF_QUERY}"
        return 1
    else
        echo -n "${stdout}"
    fi
}
bind '"\C-r": " \C-x\C-a^ddi$(__emidln_fzf_history \\| \C-x\C-aP i\\| )\C-x\C-e\C-x\C-r\C-x\C-a$i"'

function fzf_apropos {
    local choice=$(/usr/bin/apropos '' | fzf -q "$1" --preview-window=down:60% --preview 'echo {} | cut -f 1 -d " " | xargs man' | cut -f 1 -d " ")
    if [[ $? == 0 ]]; then
        eval "man ${choice}"
    fi
}
alias apropos=fzf_apropos

alias ls="lsd --color=always"
alias la="lsd -A --color=always"
alias ll="lsd -lh --color=always"
alias lla="lsd -lAh --color=always"
alias lt="lsd --tree --color=always"
alias lta="lsd --tree -A --color=always"
alias temacs="emacs -nw"
alias e="emacsclient -c -n"
alias te="emacsclient -c -n -w"
export EDITOR="vim"
alias restartemacs="systemctl --user restart emacs"
alias ALTERNATE_EDITOR="vim"

function list_bash_colors {
    color=${1:-16}
    while [ $color -lt 245 ]; do
        echo -e "$color: \\033[38;5;${color}mhello\\033[48;5;${color}mworld\\033[0m"
        ((color++));
    done
}

export PATH="${HOME}/.local/bin:${PATH}"
export PATH="${HOME}/bin:${PATH}"
export GOPATH="${HOME}/.local/gopath"
[[ ! -d "${GOPATH}" ]] && mkdir -p "${GOPATH}"
export PATH="${HOME}/.local/go/bin:${GOPATH}/bin:${PATH}"

function find_bb {
    fd --color always -d 1 -t x . $(git rev-parse --show-toplevel)/bazel/bin | sk --ansi --preview "preview.sh {}" --with-nth=-1 -d /
}


bind '"\C-b": " \C-x\C-a^ddi$(find_bb \\| \C-x\C-aP i\\| )\C-x\C-e\C-x\C-r\C-x\C-a$i"'

function cdr {
    local controlling_dir=$(git rev-parse --show-toplevel)
    local parent_path_comps=$(awk -F"/" '{print NF}' <<< $controlling_dir)
    local target_dir
    target_dir=$(fd -t d . $controlling_dir | sk -d / --with-nth="${parent_paths_comps}..-1")
    if [[ $? == 0 ]]; then
        cd $target_dir
    fi
}

curl_time() {
    curl -so /dev/null -w "\
   namelookup:  %{time_namelookup}s\n\
      connect:  %{time_connect}s\n\
   appconnect:  %{time_appconnect}s\n\
  pretransfer:  %{time_pretransfer}s\n\
     redirect:  %{time_redirect}s\n\
starttransfer:  %{time_starttransfer}s\n\
-------------------------\n\
        total:  %{time_total}s\n" "$@"
}

function find_dominating_file {
    local start=$1
    local filename=$2
    local target=$(realpath $start/$filename)
    local tdir=$(dirname $target)
    if [[ -e "$target" ]]; then
        echo $tdir
        return 0
    elif [[ "$start" == "/" ]]; then
        return 1
    else
        find_dominating_file $(dirname $tdir) $filename
    fi
}

function __update_tmux_prefix
{
    echo "tmux prefix was: '$1'"
    tmux unbind "$1"
    tmux bind "$2" last-window
    tmux set -g prefix "$2"
    echo "tmux prefix now: '$2'"
}

function toggle_tmux_prefix
{
    local current_prefix=$(tmux show -g prefix | cut -d' ' -f2)
    case $current_prefix in
        M-Space) __update_tmux_prefix "$current_prefix" "C-Space";;
        C-Space) __update_tmux_prefix "$current_prefix" "M-Space";;
        *)       echo "Unsupported prefix! Fix it yourself!"; return 1;;
    esac
    return 0
}




# function bt {
#     # if we're inside the git repo
#     local git_top
#     git_top=$(git rev-parse --show-toplevel 2>/dev/null ; exit $?)
#     if [[ $? == 0 ]]; then
#         cd $git_top
#         return 0
#     fi
#     # if we're in the build area
#     local workspace_pointer
#     workspace_pointer=$(find_dominating_file . DO_NOT_BUILD_HERE ; exit $?)
#     if [[ $? == 0 ]]; then
#         cd $(< $workspace_pointer/DO_NOT_BUILD_HERE)
#         return 0
#     fi
#     # else let the user pick a bazel repo
#     local new_bt
#     # FIXME: this finds WORKSPACE files, not the directory that contains them
#     new_bt=$(fd -d 1 -t d -t l '.*WORKSPACE.*' ${HOME} | sk)
#     if [[ $? == 0 ]]; then
#         cd $new_bt
#         return 0
#     fi
#     return 1
# }

function fake_firefox {
    wget --user-agent 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:89.0) Gecko/20100101 Firefox/89.0' "$@"
}

#[[ $(stat -c '%U:%G' /var/run/docker.sock ) != "bja:bja" ]] && sudo chown bja:bja /var/run/docker.sock


# Disk is cheap, knowledge is precious
HISTORY_SIZE=10000000
export HISTFILESIZE=$HISTORY_SIZE
export HISTSIZE=$HISTORY_SIZE

#export PATH="${PATH}:${HOME}/.local/aws/bin

function default_route {
    ip route|awk '/default/ { print $3 }'
}

export MANPATH="${MANPATH}:/home/user/.fzf/man"

function dnf {
    sudo yum -y "$@"
}

function WS {
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        git rev-parse --show-toplevel
        return 0
    else
        local D=$(realpath $(pwd))
        while [[ $(realpath ${D}) != / ]]; do
            if [[ -e "${D}/DO_NOT_BUILD_HERE" ]]; then
                cat ${D}/DO_NOT_BUILD_HERE
                return 0
            else
                D=$(dirname ${D})
            fi
        done
        return 1
    fi
}

function ws {
    local foo=$(WS)
    if [[ -d "$foo" ]]; then
        cd $foo
        return 0
    fi
    return 1
}

function EXT {
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        if compgen -G $(git rev-parse --show-toplevel)/WORKSPACE* > /dev/null 2>&1; then
            echo $(bazel info output_base 2>/dev/null)/external
            return 0
        fi
    fi
    return 1
}

function ext {
    local foo=$(EXT)
    if [[ -d "$foo" ]]; then
        cd $foo
        return 0
    fi
    return 1
}

#export MANPAGER="sh -c 'col -bx | bat -l man -p -f | less -RF'"
export BAT_PAGER="less -RF"
export BAT_THEME=ansi
alias info='info --vi-keys'
alias cat='bat -p'
alias tmux='tmux -2u'

# expand variables on tab complete; works around escaping $ after tab completion
shopt -s direxpand

function vi {
    if [[ $# == 1 ]]; then
        if rg -q ':\d+(:.*)?$' <<<$1; then
            vim $(sd '(.*):(\d+)(:.*)?$' '$1 +$2' <<<$1)
        else
            vim "$@"
        fi
    else
        vim "$@"
    fi
}

# Disk is cheap, knowledge is precious
HISTORY_SIZE=10000000
export HISTFILESIZE=$HISTORY_SIZE
export HISTSIZE=$HISTORY_SIZE

# setup PROMPT_COMMAND to yield a unified history
shopt -s histappend
##update_terminal_cwd() {
##    # Identify the directory using a "file:" scheme URL,
##    # including the host name to disambiguate local vs.
##    # remote connections. Percent-escape spaces.
##    local SEARCH=' '
##    local REPLACE='%20'
##    local PWD_URL="file://$HOSTNAME${PWD//$SEARCH/$REPLACE}"
##    printf '\e]7;%s\a' "$PWD_URL"
##}
export GIT_PS1_SHOWCOLORHINTS=1
# add fancy git-aware PS1
#export PROMPT_COMMAND='__git_ps1 "\u@\h \[\033[33m\]\w\[\033\[\033[00m\]" " \m $? \\\$ "'
#export PROMPT_COMMAND='__git_ps1 "\u@\h \[\033[33m\]\w\[\033\[\033[00m\]" " $? \\\$ "'

function expand_ps1() {
	my_ps1=`shift`
	x="$(PS1=\"$PS1\" echo -n | bash --norc -i 2>&1 > /dev/null)"; echo "'${x%exit}'"
	#echo -e "$x"
	echo $x
}

function prompt() {
    local myps1="\n\u@\h \[\033[33m\]\w\[\033\[\033[00m\]"
    #local gitps1="$(__git_ps1 $myps1)"
    echo -en "${myps1@P}"
    __git_ps1 ""
    echo ""
    PS1="\$? \\\$ "
}
export PROMPT_COMMAND='prompt'
# track history across all instances of bash
export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"

export PATH="/opt/homebrew/bin:${PATH}:${HOME}/go/bin"
alias bazel=bazelisk

alias python=python3

 export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
