FROM ghcr.io/cirruslabs/flutter:stable

# 作業ディレクトリの設定
WORKDIR /app

# 必要に応じてFlutterの設定を追加（Webサポートの有効化など）
RUN flutter config --enable-web

# Gitのセーフディレクトリ設定（コンテナ内でGit操作を行う場合のエラー回避）
RUN git config --global --add safe.directory /app

# コンテナが起動し続けるようにコマンドを指定（docker-composeから上書き可能）
CMD ["tail", "-f", "/dev/null"]
