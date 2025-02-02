FROM nginx:alpine

# Install necessary tools
RUN apk add --no-cache dpkg dpkg-dev curl wget tar zstd gnupg

# Create the package directory
RUN mkdir -p /usr/share/nginx/html/packages

# Remove default Nginx pages
RUN rm -f /usr/share/nginx/html/index.html /usr/share/nginx/html/50x.html

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy the Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Set environment variables for GPG
ARG GPG_PRIVATE_KEY
ARG GPG_KEY_ID
ENV GPG_PRIVATE_KEY=$GPG_PRIVATE_KEY
ENV GPG_KEY_ID=$GPG_KEY_ID

# Expose HTTP port
EXPOSE 80

# Set custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]