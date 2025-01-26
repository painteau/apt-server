#!/bin/sh

# Generate Packages.gz if there are .deb files
if [ "$(ls -A /usr/share/nginx/html/packages/*.deb 2>/dev/null)" ]; then
  echo "Generating Packages.gz..."
  dpkg-scanpackages /usr/share/nginx/html/packages /dev/null | gzip -9c > /usr/share/nginx/html/packages/Packages.gz
  echo "Packages.gz generated."
else
  echo "No .deb files found. Skipping Packages.gz generation."
fi

# Start Nginx
exec "$@"
