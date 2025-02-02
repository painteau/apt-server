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
    echo "📥 Loading environment variables from /root/.env..."
    set -a
    . /root/.env
    set +a
else
    echo "❌ ERROR: /root/.env file not found! Exiting..."
    exit 1
fi

# 🔑 **Check GPG Key**
if [ -z "$GPG_PRIVATE_KEY" ] || [ -z "$GPG_KEY_ID" ]; then
    echo "❌ ERROR: GPG_PRIVATE_KEY or GPG_KEY_ID is missing! Exiting..."
    exit 1
fi

# 🔑 **Import GPG Key**
echo "🔑 Importing GPG key..."
echo "$GPG_PRIVATE_KEY" | sed 's/\\n/\n/g' > /root/gpg_key.asc
gpg --batch --import /root/gpg_key.asc
rm -f /root/gpg_key.asc

if ! gpg --list-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
    echo "❌ ERROR: GPG key import failed! Exiting..."
    exit 1
fi

echo "✅ GPG key successfully imported."

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

# 📦 **Generate repository metadata**
generate_metadata() {
    echo "📝 Generating repository metadata..."

    for DIST in $UBUNTU_VERSIONS; do
        for ARCH in $ARCHITECTURES; do
            BIN_DIR="$PACKAGE_DIR/dists/$DIST/main/binary-$ARCH"

            mkdir -p "$BIN_DIR"

            echo "📦 Generating Packages.gz for $DIST $ARCH..."
            if [ "$(ls -A "$PACKAGE_DIR/pool/main"/*.deb 2>/dev/null)" ]; then
                dpkg-scanpackages --multiversion "$PACKAGE_DIR/pool/main" /dev/null | gzip -9c > "$BIN_DIR/Packages.gz"
                dpkg-scanpackages --multiversion "$PACKAGE_DIR/pool/main" /dev/null > "$BIN_DIR/Packages"
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

            # 📌 **Generate hashes**
            echo "🔢 Adding hash sums to Release file..."

            {
                echo "MD5Sum:"
                find "$PACKAGE_DIR/dists/$DIST" -type f ! -name "Release" -print0 | xargs -0 md5sum | awk '{print $1, length($2), substr($2, index($2, "dists/"))}'

                echo "SHA1:"
                find "$PACKAGE_DIR/dists/$DIST" -type f ! -name "Release" -print0 | xargs -0 sha1sum | awk '{print $1, length($2), substr($2, index($2, "dists/"))}'

                echo "SHA256:"
                find "$PACKAGE_DIR/dists/$DIST" -type f ! -name "Release" -print0 | xargs -0 sha256sum | awk '{print $1, length($2), substr($2, index($2, "dists/"))}'
            } >> "$RELEASE_FILE"

            echo "✅ Hashes added to Release file."

            # 🔏 **Sign the Release file**
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
    chown -R nginx:nginx "$PACKAGE_DIR"
}

# 🏁 **Start repository setup**
create_repo_structure
generate_metadata

# 🔄 **Start background sync**
while true; do
    echo "⏳ Waiting $SYNC_INTERVAL seconds before next sync..."
    sleep "$SYNC_INTERVAL"
    generate_metadata
done &

# 🚀 **Start Nginx*
exec "$@"