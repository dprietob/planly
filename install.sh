#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Es necesario tener permisos de superusuario."
  exit 1
fi

mvn clean package

mkdir -p "/opt/planly"

cp target/planly-*.jar "/opt/planly/planly.jar"

cat > "/opt/planly/planly.sh" <<'EOF'
#!/usr/bin/env bash
exec java -jar /opt/planly/planly.jar "$@"
EOF

chmod +x "/opt/planly/planly.sh"

ln -sf "/opt/planly/planly.sh" "/usr/local/bin/planly"

echo "Planly se ha intalado correctamente!"