#!/bin/sh
set -e

PACKAGE_DIR="/usr/share/nginx/html/packages"
GITHUB_REPO_LIST="painteau/apt-server"
REPOS_FILE="$PACKAGE_DIR/repos.txt"
OVERRIDE_FILE="$PACKAGE_DIR/override"
SYNC_INTERVAL=300  # Sync every 5 minutes (300 seconds)
UBUNTU_VERSIONS="bionic focal jammy noble"
ARCHITECTURES="amd64 arm64"

# 🔄 **Load environment variables**
if [ -f /root/.env ]; then
    echo "Loading environment variables from /root/.env..."
    export $(grep -v '^#' /root/.env | xargs -d '\n')
else
    echo "❌ ERROR: /root/.env file not found! Exiting..."
    exit 1
fi

# 🔑 **Import GPG Key**
if [ -n "$GPG_PRIVATE_KEY" ] && [ -n "$GPG_KEY_ID" ]; then
    echo "Importing GPG key..."
    echo "$GPG_PRIVATE_KEY" | tr ' ' '\n' > /root/gpg_key.asc
    gpg --batch --import /root/gpg_key.asc

    # Vérification si l'importation a fonctionné
    if ! gpg --list-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
        echo "❌ ERROR: GPG key import failed! Exiting..."
        exit 1
    fi

    rm -f /root/gpg_key.asc  # Nettoyage du fichier temporaire
    echo "✅ GPG key successfully imported."
else
    echo "❌ ERROR: GPG_PRIVATE_KEY or GPG_KEY_ID is missing! Exiting..."
    exit 1
fi

# 🏗️ **Create repository structure**
create_repo_structure() {
    echo "📁 Creating repository structure..."
    for DIST in $UBUNTU_VERSIONS; do
        for ARCH in $ARCHITECTURES; do
            mkdir -p "$PACKAGE_DIR/dists/$DIST/main/binary-$ARCH"
        done
    done
    mkdir -p "$PACKAGE_DIR/pool/main"
    echo "✅ Repository structure created successfully."
}

# 🔄 **Fetch latest packages from GitHub**
fetch_packages() {
    echo "📥 Fetching repos.txt from $GITHUB_REPO_LIST..."
    LATEST_REPOS_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO_LIST/contents/repos.txt" | grep "download_url" | cut -d '"' -f 4)

    if [ -n "$LATEST_REPOS_URL" ]; then
        wget -q -O "$REPOS_FILE" "$LATEST_REPOS_URL"
        echo "✅ repos.txt downloaded."
    else
        echo "❌ ERROR: Failed to fetch repos.txt."
        exit 1
    fi

    while IFS= read -r GITHUB_REPO || [ -n "$GITHUB_REPO" ]; do
        echo "🔄 Processing repo: '$GITHUB_REPO'..."

        LATEST_DEB_URLS=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases" | grep "browser_download_url" | grep ".deb" | cut -d '"' -f 4)

        if [ -n "$LATEST_DEB_URLS" ]; then
            for URL in $LATEST_DEB_URLS; do
                FILE_NAME=$(basename "$URL")

                if [ ! -f "$PACKAGE_DIR/pool/main/$FILE_NAME" ]; then
                    echo "⬇️ Downloading $URL..."
                    wget --verbose -P "$PACKAGE_DIR/pool/main" "$URL"
                    echo "✅ Download complete."
                else
                    echo "⚠️ File $FILE_NAME already exists, skipping download."
                fi
            done
        else
            echo "⚠️ No .deb files found for $GITHUB_REPO."
        fi
    done < "$REPOS_FILE"

    rm -f "$REPOS_FILE"
}

# 📝 **Generate `override` file**
generate_override() {
    echo "🔄 Regenerating override file..."
    > "$OVERRIDE_FILE"

    find "$PACKAGE_DIR/pool/main" -maxdepth 1 -type f -name "*.deb" | while read DEB_FILE; do
        PACKAGE_NAME=$(dpkg-deb --show --showformat='${Package}\n' "$DEB_FILE")
        SECTION="utils"
        PRIORITY="optional"

        echo "$PACKAGE_NAME $PRIORITY $SECTION" >> "$OVERRIDE_FILE"
        echo "➕ Added override entry: $PACKAGE_NAME $PRIORITY $SECTION"
    done
}

# 📦 **Generate repository metadata**
generate_metadata() {
    echo "📝 Generating repository metadata..."

    for DIST in $UBUNTU_VERSIONS; do
        for ARCH in $ARCHITECTURES; do
            BIN_DIR="$PACKAGE_DIR/dists/$DIST/main/binary-$ARCH"

            mkdir -p "$BIN_DIR"

            echo "📦 Generating Packages.gz for $DIST $ARCH..."
            if [ "$(ls -A "$PACKAGE_DIR/pool/main"/*.deb 2>/dev/null)" ]; then
                dpkg-scanpackages --multiversion "$PACKAGE_DIR/pool/main" "$OVERRIDE_FILE" | gzip -9c > "$BIN_DIR/Packages.gz"
                dpkg-scanpackages --multiversion "$PACKAGE_DIR/pool/main" "$OVERRIDE_FILE" > "$BIN_DIR/Packages"
            else
                echo "⚠️ WARNING: No .deb files found, skipping package index."
                > "$BIN_DIR/Packages.gz"
                > "$BIN_DIR/Packages"
            fi

            echo "📝 Generating Release file for $DIST..."
            RELEASE_FILE="$PACKAGE_DIR/dists/$DIST/Release"

            cat <<EOF > "$RELEASE_FILE"
Origin: Gochu APT Server
Label: Gochu Repository
Suite: stable
Version: 1.0
Codename: $DIST
Architectures: $ARCHITECTURES
Components: main
Description: Custom APT repository for Ubuntu
Date: $(date -Ru)
EOF

            echo "✅ Release file created."

            # 🛡️ **Sign the Release file (if GPG key is available)**
            if [ -n "$GPG_PRIVATE_KEY" ] && [ -n "$GPG_KEY_ID" ]; then
                echo "🔏 Signing Release file..."
                gpg --batch --yes --local-user "$GPG_KEY_ID" --clearsign -o "$PACKAGE_DIR/dists/$DIST/InRelease" "$RELEASE_FILE"
                gpg --batch --yes --local-user "$GPG_KEY_ID" -abs -o "$PACKAGE_DIR/dists/$DIST/Release.gpg" "$RELEASE_FILE"
                echo "✅ Release file signed."
            else
                echo "⚠️ WARNING: No GPG key provided, skipping signature."
            fi
        done
    done

    echo "✅ Metadata generation complete."

    # ✅ **Cleanup**
    rm -f "$OVERRIDE_FILE"
    chown -R nginx:nginx "$PACKAGE_DIR"
}

# 🏁 **Start repository setup**
create_repo_structure
fetch_packages
generate_override
generate_metadata

# 🔄 **Start background sync**
while true; do
    echo "⏳ Waiting $SYNC_INTERVAL seconds before next sync..."
    sleep "$SYNC_INTERVAL"
    fetch_packages
    generate_override
    generate_metadata
done &

# 🚀 **Start Nginx**
exec "$@"