
DIRPATH=$(dirname $0)

RPLCMD="ruby $DIRPATH/replace-issue-symbol-num.rb "
RPLCMD=$RPLCMD$1
git filter-branch -f --msg-filter "$RPLCMD"

RPLCMD="ruby $DIRPATH/replace-issue-link-num.rb "
RPLCMD=$RPLCMD$1
git filter-branch -f --msg-filter "$RPLCMD"
