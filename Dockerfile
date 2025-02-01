FROM nginx:alpine

# Installer les outils nécessaires
RUN apk add --no-cache dpkg dpkg-dev curl wget

# Créer le dossier pour les paquets
RUN mkdir -p /usr/share/nginx/html/packages

# Copier l'entrée de script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copier la configuration de Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Exposer le port HTTP
EXPOSE 80

# Définir l'entrée du conteneur
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]