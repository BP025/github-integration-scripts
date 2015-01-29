GitHubリポジトリ統合Script集
===
複数のGitHubリポジトリを1つのGitHubリポジトリに統合するためのScript集です。

**統合は決してオススメしません！やんごとなき理由が無い限り考えなおしてください！**

[履歴を残したまま複数のgitリポジトリを統合する](http://qiita.com/edvakf@github/items/9e7ccbaa944d26f9b69c)を参考にしています。


* 移行できるもの
    * gitリポジトリ（ソースコード）
    * Issue・Issueコメント・Milestone
* 移行できないもの
    * gitリポジトリのtag
    * PullRequest
    * Wiki

詳しくは後述します。


手順例
---
GiHubリポジトリ Hoge/A, Hoge/B を Hoge/X に統合する場合、手順は以下のようになります。

1. 統合先GitHubリポジトリ Hoge/X を作成する
1. この統合Script集を実行可能にする

        git clone "https://github.com/BP025/github-integration-scripts.git"
        cd github-integration-scripts
        bundle install --path vendor/bundle

1. Issue・Issueコメント・Milestoneを移行
    1. Hoge/A

            bundle exec ruby issue-migration.rb -u <GitHubアカウントID> -p <GitHubアカウントパスワード> -l A Hoge/A Hoge/X

        **Issue番号が何番まで作成されたかメモする**

    1. Hoge/B

            bundle exec ruby issue-migration.rb -u <GitHubアカウントID> -p <GitHubアカウントパスワード> -l B Hoge/B Hoge/X

1. gitリポジトリを移行
    1. Hoge/A

              git clone "https://github.com/Hoge/A.git"
              cd A
              . ../git-migration.sh A 0 Hoge/A Hoge/X

    1. Hoge/B

              cd ..
              git clone "https://github.com/Hoge/B.git"
              cd B
              . ../git-migration.sh B <メモしたIssue番号> Hoge/B Hoge/X

1. gitリポジトリを統合

        cd ../A
        git remote add tmpB ../B
        git fetch tmpB
        git merge tmpB/master

    master以外のbranchも統合するならmergeを繰り返します。

1. Hoge/Xへpush

        git remote add integrated "https://github.com/Hoge/X.git"
        git push -u integrated master

Hoge/Cも統合する場合も、Issue番号をメモするのを忘れずにHoge/Bの手順を繰り返せばOKです。


動作確認した環境
---
* zsh
* ruby 2.2.0


移行できるもの・できないものの詳細
---

# gitリポジトリ

* ソースコード … ◯
    * 全branchを移行できます
* コミットログ … △
    * コミットツリーは維持されますが、コミットハッシュがすべて変更されます
* コミットコメント … △
    * 全文そのまま維持することは可能ですが、それだとIssue番号や移行元リポジトリ内へのリンクが移行後のものになりません。
      よって、scriptで以下の加工を行っています
        * Issue番号を移行後のものに置換
        * 移行元リポジトリ内へのリンクを移行後のリポジトリへのリンクに置換
        * コミットハッシュを含むリンクを削除
    * 他の統合元リポジトリへのリンクは加工されません
        * A,B -> X の統合を行う場合、Aのコミットコメント内にBへのリンクがあっても無視されます
* タグ … ×

# Issue・Issueコメント・Milestone

統合先でのこれらの作成はGitHub上での操作が自動化されたようなものなのでいろいろ制限があります。

* 本文 … △
    * gitリポジトリのコミットコメントと同様にIssue番号やリンクの加工を行っています
        * 作成順までは再現しないため、Issue番号が含まれていてもリンクになっていない場合もあります。
          内容はそのまま保存し直すとリンク化されるので見つけたら再保存してください
* 作成日・作成者 … △
    * 作成日はscriptを実行した日時になります
    * 作成者はscriptを実行するときに指定したアカウントのユーザーになります
    * scriptで本文の先頭に作成者・作成日時を追加する加工を行っています


# PullRequest

× 移行できません。データは取得できますが、作成に必要な当時のコミット情報が失われています。

ただし、PullRequestはIssueの一種なので完全に無視してしまうとIssue番号が詰められてしまいます。よって、`PullRequest`というlabelを付けたIssueとして移行することでIssue番号のズレを防止します。


# Wiki

× 移行できません。gitで扱えるのでなんとかしてください。


統合後の注意点
---
統合すると以降は必ずすべてのソースコードをまとめて扱うことになります。

`git clone`する場合もそうですし、branchを切り替える場合にも注意が必要です。

