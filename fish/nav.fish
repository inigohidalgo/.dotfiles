# navigation shortcuts
# abbr expands the command after pressing <space>
#
# --set-cursor and adding `%` will move the cursor to that location

abbr -a ..2 "cd ../.."
abbr -a ..3 "cd ../../.."
abbr -a ..4 "cd ../../../.."
abbr -a ..5 "cd ../../../../.."

abbr -a --set-cursor cdc 'cd $HOME/.config/%'
abbr -a --set-cursor cdcf 'cd $HOME/.config/fish/%'

abbr -a --set-cursor cdr 'cd $REPOS_DIR/%'
abbr -a --set-cursor cdra 'cd $REPOS_DIR/axpo/%'
abbr -a --set-cursor cdrau 'cd $AU_REPO_DIR/%'
abbr -a --set-cursor cdrw 'cd $GWT_DIR/%'
abbr -a --set-cursor cdri 'cd $REPOS_DIR/ihr/%'

abbr -a --set-cursor cdt 'cd $TOOLS_DIR/%'
abbr -a --set-cursor cdtp 'cd $TOOLS_DIR/pythia/%'
abbr -a --set-cursor cdtb 'cd $TOOLS_DIR/bimo/%'
abbr -a --set-cursor cdtd 'cd $TOOLS_DIR/dsbuilder/%'

abbr -a --set-cursor cdu 'cd $UC_DIR/%'
