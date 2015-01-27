
DIRPATH=$(dirname $0)
SUBDIR=$1
ISSUE_NUM_OFFSET=$2
OLD_REPO_NAME=$3
NEW_REPO_NAME=$4

# 第1引数で指定したディレクトリにソースコードを移動
# 参考ページ: http://qiita.com/edvakf@github/items/9e7ccbaa944d26f9b69c
# filterに渡すコマンドの実行結果の改行がうまく扱えなかった（改行が無くなってしまった）ので
EXEC_CMD='git ls-files -s | '
EXEC_CMD=$EXEC_CMD"ruby $DIRPATH/move-file-to-subdir.rb "$SUBDIR' | '
EXEC_CMD=$EXEC_CMD'GIT_INDEX_FILE=$GIT_INDEX_FILE.new '
EXEC_CMD=$EXEC_CMD'git update-index --index-info && '
EXEC_CMD=$EXEC_CMD'mv $GIT_INDEX_FILE.new $GIT_INDEX_FILE || true'
git filter-branch -f --index-filter "$EXEC_CMD" -- --all

# 第2引数で指定した数字分、コミットコメント内のIssue番号をずらす
EXEC_CMD="ruby $DIRPATH/replace-issue-symbol-num.rb "
EXEC_CMD=$EXEC_CMD$ISSUE_NUM_OFFSET
git filter-branch -f --msg-filter "$EXEC_CMD"

EXEC_CMD="ruby $DIRPATH/replace-issue-link-num.rb "
EXEC_CMD=$EXEC_CMD$ISSUE_NUM_OFFSET
git filter-branch -f --msg-filter "$EXEC_CMD"

# 第3引数で指定したリポジトリのコミットリンクを、コミットコメント内から削除
EXEC_CMD="ruby $DIRPATH/delete-commit-link.rb "
EXEC_CMD=$EXEC_CMD$OLD_REPO_NAME
git filter-branch -f --msg-filter "$EXEC_CMD"

# 第3引数で指定したリポジトリへのリンクを第4引数で指定したリポジトリへのリンクに、コミットコメント内を置換
EXEC_CMD="ruby $DIRPATH/replace-repository-name-in-link.rb "
EXEC_CMD=$EXEC_CMD$OLD_REPO_NAME" "$NEW_REPO_NAME
git filter-branch -f --msg-filter "$EXEC_CMD"

