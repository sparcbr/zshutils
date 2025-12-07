[[ "$SUDO_USER" != "" ]] && { export HOME=~$SUDO_USER; }
export ZDOTDIR="${${(%):-%x}:a:h}"
export GITHUB_API_TOKEN=''
# -F: no pager if fit the screen
# -X: no init/deinit / dont clear screen
# -e: exit on 2nd time end-of-file is reached
#export LESS=-asrRix4FXe # cant use -F without -X ?
export ZSH_LIBS=$HOME/bin/zsh_libs
export LC_CTYPE=en_US.UTF-8
export LC_NUMERIC=en_US.UTF-8
export LC_NAME=en_US.UTF-8
export LANG=en_US.UTF-8
export TMP=/tmp TMPDIR=/tmp

path+=$HOME/.local/bin
path+=$HOME/bin
path+=$HOME/.config/composer/vendor/bin

if [[ -r $HOME/.zshrc_local ]]; then
	source $HOME/.zshrc_local

	if [[ ! -d $CLOUD ]]; then
		echo Dir not found: $CLOUD
	fi
fi

[[ -z $CLOUD ]] && export CLOUD=$HOME/cfg
export CFG=$HOME/cfg
export SOUNDS=$CFG/sounds
[[ -d $CFG ]] || mkdir -p $CFG
export NOSND=0
export USE_CCACHE=1
skip_global_compinit=1
command -v sudo >/dev/null || alias sudo=''

if [[ -z "$ZSH_MAIN_INFO" && -d "$ZSH_LIBS/" ]]; then
	source $ZSH_LIBS/zsh_main || echo $'\e'"[93mFail including"$'\e[0m'" $ZSH_LIBS/zsh_main"
else
	echo "ZSH_LIBS not found: $ZSH_LIBS"
fi
