perl -0777 -pe 's/^#(\d+)\n(.*?)$/: \1:0;\2/gm' ~/.bash_history >> ~/.zsh_history
