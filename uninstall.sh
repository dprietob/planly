#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Es necesario tener permisos de superusuario."
  exit 1
fi

rm -rf "/opt/planly"
rm "/usr/local/bin/planly"

echo "Planly se ha desintalado correctamente!"