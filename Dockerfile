FROM ghcr.io/cirruslabs/flutter:stable

# 権限昇格し、git と openssh-client をインストールしてコンテナ内で開発（Git連携）を完結させる
USER root
RUN apt-get update && apt-get install -y git openssh-client && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリの設定
WORKDIR /workspace

# 必要に応じてFlutterの設定を追加（Webサポートの有効化など）
RUN flutter config --enable-web

# Gitのセーフディレクトリ設定（コンテナ内でGit操作を行う場合のエラー回避）
RUN git config --global --add safe.directory /workspace

# コンテナが起動し続けるようにコマンドを指定（docker-composeから上書き可能）
CMD ["tail", "-f", "/dev/null"]
