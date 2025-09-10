if [[ 'code' == $(cat /proc/$PPID/comm) ]]; then
	#return
fi
integer verbose
if [[ -f $TMPDIR/debug_zshrc && $SHLVL == 1 && ! -o LOGIN ]]; then
	export DEBUG_RC=1
	zmodload zsh/zprof
	export DEBUG=2
	verbose=3
	echo "Profiling"
	#exec 3>&2 2>/tmp/zshstart.$$.log
	#setopt xtrace prompt_subst
fi
ZPM_HOME=${ZDOTDIR:-$HOME}/.zinit
typeset -A ZINIT
ZINIT[HOME_DIR]=$ZPM_HOME
ZINIT[BIN_DIR]=$ZPM_HOME/bin
ZINIT[ZCOMPDUMP_PATH]=$ZPM_HOME/.zcompdump
OPENAI_APIKEY=''
#module_path+=($ZINIT[BIN_DIR]/zmodules/Src); zmodload zdharma-continuum/zplugin
export ZPM_HOME ZINIT
include -qr file
include -q aliases
zshrc() {
	local f opt=$1
	(($#opt)) || {
		include -qr functions
		chooser -v opt --use-keys -f1 'E' 'Edit .zshrc' 'V' 'Edit .zshenv' 'P' 'Profile zsh startup' \
			|| return
	}
	case $opt in
		p*) echo 'The next zsh startup will be profiled'
			touch $TMPDIR/debug_zshrc
			return ;;
		e*) f=$ZDOTDIR/.zshrc ;;
		*) f=$ZDOTDIR/.zshrc ;;
	esac
	$f || open $f || gvim $f || $EDITOR $f || vim $f
}

bindkey -e # Use emacs keybindings even if our EDITOR is set to vi

REPORTTIME=1 # lower limit to report slow commands time (seconds)
export HISTTIMEFORMAT="%d/%m/%y %T "
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY EXTENDED_HISTORY HIST_VERIFY
setopt EXTENDED_GLOB PIPE_FAIL NO_MULTIOS AUTO_CD AUTO_PUSHD
HISTSIZE=4500; SAVEHIST=4500
HISTFILE=~/.zsh_history
tabs 4
[[ ! -f '/etc/vim/vimrc.local' && ! -f $HOME/.vimrc ]] && zsh $CFG/vimrc.sh

#vramsteg

if [[ ! -f $ZINIT[BIN_DIR]/zinit.zsh ]]; then
	print -P "%F{33}▓▒░ %F{220}Installing Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
	mkdir -p "$ZPM_HOME" && command chmod g-rwX "$ZPM_HOME"
	git clone https://github.com/zdharma-continuum/zinit $ZINIT[BIN_DIR] || \
		print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi
source $ZINIT[BIN_DIR]/zinit.zsh

# Load a few important annexes, without Turbo (this is currently required for annexes)
zinit light-mode for \
	zdharma-continuum/z-a-rust \
	zdharma-continuum/z-a-as-monitor \
	zdharma-continuum/z-a-patch-dl \
	zdharma-continuum/z-a-bin-gem-node

# Oh-my-zsh libs
for name in functions git key-bindings misc; do
	zinit snippet OMZL::$name.zsh
done

ohmyzsh_plugins=(
	#fzf vi-mode heroku lein
	#git
	wd command-not-found common-aliases ubuntu sudo colorize pip virtualenv # zsh-keybindings
)
for omzp in $ohmyzsh_plugins; do
	zinit snippet OMZP::$omzp
done
zplugin pack for pyenv
export PYENV_VIRTUALENVWRAPPER_PREFER_PYVENV="true"
#heredoc plugins <<-END

#load=(light) # load, light or snippet
#((!DEBUG_RC)) && zload_opts+=(lucid)
zinit ice wait lucid

	#pick='asdf.sh' @asdf-vm/asdf \
#	as='command' make="\!PREFIX=$ZPFX install" atclone="cp contrib/fzy-* $ZPFX/bin/" pick="$ZPFX/bin/fzy*" jhawthorn/fzy \
	#from='gh-r' as='program' junegunn/fzf-bin \
	#atload='zsh-startify' zdharma-continuum/zsh-startify \
	#molovo/crash \
	#as='command' if="[[ \! -f $ZPFX/bin/reptyr ]]" make="PREFIX=$ZPFX install" nelhage/reptyr \
zinit load 	zsh-users/zsh-history-substring-search
zinit load 	zdharma-continuum/history-search-multi-word
zinit load lukechilds/zsh-better-npm-completion
zinit load RobSis/zsh-completion-generator
zinit load Vifon/deer
zinit ice as='program' pick='bin/git-dsf' zdharma-continuum/zsh-diff-so-fancy
zinit load jimeh/zsh-peco-history
zinit load wbinglee/zsh-wakatime
zinit load arzzen/calc.plugin.zsh
zinit load chrissicool/zsh-256color
zinit load hlissner/zsh-autopair
zinit load zdharma-continuum/zsh-navigation-tools
zinit load jessarcher/zsh-artisan
zinit load tom-doerr/zsh_codex
	#zdharma-continuum/zconvey \
	#zdharma-continuum/zshelldoc \
	#sharat87/zsh-vim-mode \
	#gradle/gradle-completion \
	#ranger/ranger \

#type asdf && {
#	asdf list nodejs 2>/dev/null || {
#		apt install dirmngr gpg
#		asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
#		${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring
#		asdf install nodejs lts
#	}
#}

zinit ice depth=1
zthemes=(romkatv/powerlevel10k gnzh robbyrussell agnoster)
if [[ -z "$theme" ]]; then
	for theme in $zthemes; do
		if [[ $theme == */* ]]; then
			zinit light $theme && break # ok loaded
		else
			zinit snippet OMZP::$theme && break # ok loaded
		fi
		techo -c err "Theme $theme not found"
	done
fi

zinit ice atclone"dircolors -b LS_COLORS > c.zsh" atpull'%atclone' pick"c.zsh" nocompile'!' \
    atload'zstyle ":completion:*" list-colors “${(s.:.)LS_COLORS}”'
zinit light trapd00r/LS_COLORS

if [[ -z $zcompdump(.mw+1) ]]; then
	ZINIT[COMPINIT_OPTS]='-C'
fi
#autoload -Uz _zinit
#(( ${+_comps} )) && _comps[zinit]=_zinit
zinit wait for \
	atinit"zicompinit; zicdreplay" zdharma-continuum/fast-syntax-highlighting \
	blockf zsh-users/zsh-completions \
	atload"!_zsh_autosuggest_start" zsh-users/zsh-autosuggestions

ZSH_AUTOSUGGEST_USE_ASYNC=1
#ZSH_AUTOSUGGEST_MANUAL_REBIND=1 # re-bind widgets manually: _zsh_autosuggest_bind_widgets
#bindkey "$terminfo[kcuu1]" history-substring-search-up
#bindkey "$terminfo[kcud1]" history-substring-search-down
#bindkey "$terminfo[kcud1]" #fc crward-word
#bindkey "$terminfo[kcud1]" backward-word
bindkey '^X' create_completion

for lib in debug functions device proc sql git android progtools conversion mediatool network; do include -l $lib; done
compdef $comp

#cd $old_pwd
path+=(./vendor/bin ./node_modules/.bin)
#path+=($HOME/flutter/bin)
for dir in $HOME/{.composer, .config/composer}(/N); do
	if [[ -d $dir && -f $dir/composer.json ]]; then
		path+=($dir)
		export COMPOSER_HOME=$dir
	fi
done

[[ -d /snap/bin ]] && path+=(/snap/bin)
[[ -d /usr/share/zsh/vendor-completions ]] && fpath=(/usr/share/zsh/vendor-completions $fpath)
fpath+=($HOME/bin/zfunctions)

() {
	# colorls
	#https://github.com/ogham/exa
	#https://github.com/avdv/scalals
	return
	local f
	type getpath >/dev/null || getpath() { echo "${1:h}" } || return
	techo -T -c head "Loading colorls"
	if ! f=$(gem which colorls); then
		chkCmd gem -p 'ruby ruby-dev' || return
		sudo gem install colorls || return
		f=$(gem which colorls) || return
	fi
	source $(getpath $f)/tab_complete.sh
}
[[ "$theme" == 'romkatv/powerlevel10k' ]] && {
	[[ -f $CFG/.p10k.zsh ]] && source $CFG/.p10k.zsh || techo -T -c head "Loading p10k prompt. Run 'p10k configure' to customize."
}
if ((DEBUG_RC)); then
	#set +x;
	echo "Ending"
	rm -f $TMPDIR/debug_zshrc
	unset DEBUG_RC
	export DEBUG=0
	zpmod source-study
	zprof
	#exec 2>&3 3>&-
else
	{ [[ $TERM_PROGRAM == 'vscode' ]] || box } always { catch '*'; }
fi
# fnm
export PATH=$HOME/.fnm:$PATH
eval "`fnm env --use-on-cd`"
