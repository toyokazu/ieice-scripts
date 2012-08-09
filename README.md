# IEICE Paper Meta Data Preprocessor

本スクリプトでは，論文誌検索システムのデータと論文誌投稿システムのデータを照合し，著者データに所属，会員番号の情報を追加します．また，論文誌検索システムのログから，論文の参照回数をカウントします．

## インストール方法

本スクリプトは git コマンド，ruby (1.9.2以上) を利用します．

### Windows 環境での RVM のセットアップ

以下，Windows での Ruby 実行環境のセットアップ手順です．

cygwin の最新版をインストールします．RVM ではユーザのホームディレクトリに ruby 関連のコマンドをインストールするので，ユーザ名にスペースが含まれる場合，個別に対応が必要になります．できればスペースを含まないユーザ名のユーザを作成してください．

http://www.cygwin.com/

1. setup.exe をダウンロードして実行します．
2. "Choose A Download Source" では，"Install from Internet" を選択します．
3. "Select Root Install Directory" では，デフォルトの C:\cygwin のままとし，All Users に対してインストールします．
4. "Select Local Package Directory" では，ダウンロードしたパッケージのキャッシュディレクトリを指定します．適当に空き容量のあるフォルダを指定してください．
5. "Select Your Internet Connection" では，Proxy 等を利用していない場合は "Direct Connection" を選択してください．
6. "Choose A Download Site" では，国内のサイトを適当に選択してください (例: http://ftp.jaist.ac.jp)．
7. "Select Packages" では，必要なパッケージを指定します．RVM では，git, curl 等のコマンドラインツールを利用するので，以下の項目が有効になっているか（Skip ではなくバージョン番号が左端に表示されているか）確認してください．

* Devel
** gcc
** gcc-core
** git
** git-completion
** libtool
** make
** readline
* Libs
** zlib
** zlib-devel
* Net
** openssl
** openssh
** curl
* Utils
** patch
** (screen)

インストール完了後，Cygwin Terminal を実行します．

ホームディレクトリが作成されたら，以下のコマンドを実行して RVM をインストールします (https://rvm.io/rvm/install/ 参照)．

    $ curl -L https://get.rvm.io | bash -s stable --ruby

以下の設定を ~/.bashrc に追加します (~/.bash_profile に追加されているものを ~/.bashrc に追加)．

    $ vi $HOME/.bashrc
    [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

あと，もし shell が /bin/bash になっていない場合は修正しておく(主にマルチユーザの場合)．

    $ env | grep SHELL
    /bin/sh -> /bin/bash なら OK
    $ mkpasswd -l > /etc/passwd
    $ vi /etc/passwd
    ->該当ユーザ名の shell を /bin/bash に修正

--ruby オプションを指定していれば ruby がインストールされるはずですが，以下のコマンドで no ruby と表示される場合は，手動でインストールしてください．

    $ which ruby
    which: no ruby in (....)

    $ rvm install 1.9.3
    $ rvm use 1.9.3

これで ruby のインストールは完了です．

### Linux (debian squeeze) での RVM のセットアップ

以下，Linux (debian squeeze) の場合の Ruby 実行環境のセットアップ手順です．

RVM が依存するパッケージをインストールします．

    % sudo aptitude install build-essential openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion

以下のコマンドを実行して RVM をインストールします (https://rvm.io/rvm/install/ 参照)．

    $ curl -L https://get.rvm.io | bash -s stable --ruby

--ruby オプションを指定していれば ruby がインストールされるはずですが，以下のコマンドで no ruby と表示される場合は，手動でインストールしてください．

    $ which ruby
    ruby not found

    $ rvm install 1.9.3
    $ rvm use 1.9.3

これで ruby のインストールは完了です．

### ieice-scripts のダウンロード

以下のコマンドでスクリプトを手元の環境にコピーします．

    % git clone https://github.com/toyokazu/ieice-scripts.git
    % cd ieice-scripts

## merge_affiliations.rb

著者の所属，会員番号を統合するためのスクリプトです．

### 利用手順

まず設定ファイルを作成します．

    % cp ./config/files_template.yml ./config/files_wabun-a.yml
    % vi ./config/files_wabun-a.yml
    submission: submission-system-data-utf8.tsv
    search:
      ja: paper-search-system-data-japanese-utf8.tsv
      en: paper-search-system-data-english-utf8.tsv
    output: output-utf8.tsv
    
    % mkdir files

設定ファイルには入力ファイル，出力ファイルのファイル名を指定します．
それぞれ下記のようなデータが記載されたファイルを指定します．

submission-system-data-utf8.tsv: 投稿システムのデータ（タブ区切り, UTF8）
paper-search-system-data-japanese-utf8.tsv: 論文誌検索システムのデータ (タブ区切り, UTF8)
paper-search-system-data-english-utf8.tsv: 論文誌検索システムのデータ（タブ区切り, UTF8）
output-utf8.tsv（出力ファイル）

入力ファイル，出力ファイルは files ディレクトリ以下で読み出し，書き込みされるため，ディレクトリを作成し，ここにファイルをコピーしてください．準備ができたら，以下のようにコマンドを実行します．

    % ./script/merge_affiliations.rb

実行が完了すると，著者の所属や会員番号が統合されたデータが指定したファイル名で出力されます．入出力フォーマットについては，次節で述べます．

### 入出力フォーマット

まず，入力ファイルのフォーマットについて述べます．

論文誌投稿システムから取得するデータのフォーマット

    # 0: id1　　　　受付番号の西暦部分
    # 1: id2　　　　受付番号4ケタ
    # 2: soccode  特集号コード
    # 3: title_j     　和文タイトル
    # 4: title_e 　　　英文タイトル
    # 5: volume1　掲載号
    # 6: inputnum 著者順番
    # 7: name_j　　著者名（日本語）
    # 8: name_e 　著者名（英語）
    # 9: membernum　会員番号
    # 10: orgcode　　機関コード
    # 11: name_j　　　機関コード名（日本語）
    # 12: name_e　　 機関コード名（英語）

論文誌検索システムから取得するデータのフォーマット

    # 0: id, 文献ID
    # 1: vol, 巻 (年, ソサイエティ) Vol
    # 2: num, 号 Num
    # 3: s_page, 開始ページ番号
    # 4: e_page, 終了ページ番号
    # 5: date, 発行年月
    # 6: title, タイトル【検索用】
    # 7: author, 著者【検索用】
    # 8: abstract, 概要【検索用】
    # 9: keyword, キーワード（全角カンマ区切り）【検索用】
    # 10: special, 特集号名
    # 11: category1, 論文種別 (論文, レター)
    # 12: category2, 専門分野分類コード（大項目）
    # 13: category3, 専門分野分類名（大項目）※目次の見出しに利用
    # 14: disp_title, タイトル【表示用】
    # 15: disp_author, 著者名【表示用】
    # 16: disp_abstract, 概要【表示用】
    # 17: disp_keyword, キーワード（全角カンマ区切り）【表示用】
    # 18: err_fname, 正誤Web PDF
    # 19: err_comm, 正誤内容
    # 20: nodisp_comm, 非表示
    # 21: delflg, 削除
    # 22: mmflg, MM情報
    # 23: l_auth_pdf, レター著者PDF
    # 24: l_auth_link, レター著者内容
    # 25: err_1, 訂正元ファイル名
    # 26: err_2, 訂正先ファイル名
    # 27: recommend, 推薦論文
    # 28: 目次脚注正誤PDF

出力ファイルフォーマット

    # 0: エントリ数 (1 or 2)
    # 1: 言語 (ja/en)
    # 2-29: 論文誌検索システムと同じ項目 (28以外)
    # 30: 言語 (en)
    # 31-58: 論文誌検索システムと同じ項目 (28以外)
    # 59: 照合結果
    # 60: 備考欄

なお，照合後の著者欄は以下の様な出力になります．

    著者氏名1（著者会員番号1）＠著者所属1；著者氏名2＠著者所属2；著者氏名3（著者会員番号3）＠著者所属3；...

論文誌検索システムからの入力ファイルとして，ja および en を両方指定した場合で，日本語に対応する英語のデータがある場合は，両方を出力します．英語データを指定した場合でも，該当する論文に対応する英語データがない場合は，日本語のみ出力します．

照合結果には，論文誌投稿システムのエントリと，論文誌検索システムのエントリを照合した結果として，以下のような情報が出力されます．関連する論文誌投稿システムのデータが表示されます．

    # 完全一致 (一つの言語のみ（英語 or 日本語の初回比較で一致）)
    FULL_MATCH
    # 完全一致 (一つの言語のみ（日本語に失敗した場合の英語のみ）)
    EN_FULL_MATCH
    # 巻号，著者リスト一致
    VOL_AUTHOR_MATCH
    # 巻号，著者リスト一致
    EN_VOL_AUTHOR_MATCH
    # 巻号，著者リスト一致（ただし，一つの巻号に複数存在）
    # タイトルの辞書順で一致候補を備考欄に提示
    MULTI_VOL_AUTHOR_MATCH
    # マッチしないもの．10年前までの範囲ではおそらくタイトル，著者名に微妙に修正が入っている
    # 巻号，タイトルの辞書順で一致候補を備考欄に提示
    NOT_MATCHED

完全一致を除くと，間違って一致と判定されている場合があるため，備考欄には照合に用いられた論文誌投稿システムのデータも併記されます．

## count_downloads.rb

論文誌検索システムのアクセスログから論文のダウンロード数をカウントします．

### 利用手順

### 入出力フォーマット

まず，入力ファイル (アクセスログ) のフォーマットです．

    # 0: 項番  id  int8    
    # 1: 閲覧日時  log_date  varchar 10  yyyymmdd hhmmss
    # 2: ログインユーザ  user_id varchar 100 "環境変数　REMOTE_USER ID or メールアドレス"
    # 3: 会員ソサイエティ  society varchar 5 
    # 4: 閲覧ファイル名  f_name  varchar 100 
    # 5: 分冊  category  varchar 100 
    # 6: 大分類  type  varchar 100 
    # 7: リモートホストアドレス  remote_addr varchar 200 環境変数　REMOTE_ADDR
    # 8: リモートホスト名  remote_host varchar 200 環境変数　REMOTE_HOST
    # 9:  ユーザエージェント  user_agent  varchar 100 環境変数　HTTP_USER_AGENT
    # 10:  リクエストURI uri varchar 500 
    # 11:  ブラウザ  browser varchar 50  
    # 12:  クライアントOS  os  varchar 500 
    # 13:  閲覧状態  err int   "ファイル閲覧時：1 ログイン成功時：2"
    # 14:  ホスト名  host  varchar 200 ホスト名
    # 15:  アクセス種別  access  varchar 1 "・通常ユーザ認証時 ： 0 ・サイトライセンス認証時 ： 1 ・サイトライセンス認証時＋ユーザ認証 ： 2"
    # 16:  あらまし（Summary)閲覧  summary_view  varchar 1 あらまし閲覧時　：　1
    # 17:  archive閲覧フラグ table_of_contents_view  varchar 1 archive閲覧時：1
    # 18:  最新号閲覧フラグ  index_view  varchar 1 最新号閲覧時：1
    # 19:  環境変数：X-Forwarded-For x_forwarded_for varchar 200 環境変数：X-Forwarded-For

次に出力ファイルのフォーマットです．

    # 0: 論文誌番号
    # 1: 論文誌参照回数

コメントアウトされた部分を使って，ログイン回数を集計することもできます．

## License (MIT License)
Copyright (C) 2012 by Toyokazu Akiyama.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
