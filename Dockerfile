FROM nginx:alpine

# Install necessary tools
RUN apk add --no-cache dpkg dpkg-dev curl wget tar zstd

# Create the package directory
RUN mkdir -p /usr/share/nginx/html/packages

# Remove default index.html to enable directory listing
RUN rm -f /usr/share/nginx/html/index.html

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy the Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose HTTP port
EXPOSE 80

# Set custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]