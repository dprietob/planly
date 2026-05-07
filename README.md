# Planly

Aplicación para el diseño de planos a escala, escrita en **Vala** con **GTK4** y **libadwaita**.

## Estado

Work in progress.

## Características

- Dibuja líneas en un canvas a escala (200 px = 1 metro).
- Muestra en tiempo real la longitud en píxeles y metros, y el ángulo en grados.
- Mantén **Shift** mientras dibujas para fijar la línea a las 8 direcciones cardinales (0°, 45°, 90°…).
- Haz clic sobre cualquier línea existente para seleccionarla.
- Tema oscuro por defecto; cambiable a claro o del sistema desde el menú de apariencia.

## Dependencias

| Dependencia | Versión mínima | Notas                |
| ----------- | -------------- | -------------------- |
| Vala        | 0.56           |                      |
| GTK4        | 4.10           |                      |
| libadwaita  | 1.4            | `libadwaita-1`       |
| Meson       | 0.62           | Sistema de build     |
| Ninja       | —              | Backend de Meson     |
| gettext     | —              | Herramientas de i18n |

En Fedora / RHEL:

```shell
sudo dnf install vala vala-devel vala-language-server gtk4-devel libadwaita-devel meson ninja-build gettext-devel
```

En Debian / Ubuntu:

```shell
sudo apt install valac libvala-dev vala-language-server libgtk-4-dev libadwaita-1-dev meson ninja-build gettext
```

En Arch Linux:

```shell
sudo pacman -S vala vala-language-server gtk4 libadwaita meson ninja gettext base-devel
```

## Compilación y ejecución

```shell
# Clona el repositorio
git clone git@github.com:dprietob/planly.git
cd planly

# Configura el build en el directorio _build/
meson setup _build

# Compila
ninja -C _build

# Ejecuta directamente desde el directorio de build
./_build/planly
```

### Instalación en el sistema

```shell
# Instala en /usr/local (o el prefix configurado)
sudo ninja -C _build install

# Ejecuta como cualquier otra aplicación
planly
```

Para desinstalar:

```shell
sudo ninja -C _build uninstall
```

### Prefix personalizado

```shell
# Instalar en ~/.local (sin sudo)
meson setup _build --prefix ~/.local
ninja -C _build
ninja -C _build install
```

## Desarrollo

### Recompilar tras cambios

Meson detecta automáticamente los cambios en los ficheros fuente; basta con volver a ejecutar `ninja`:

```shell
ninja -C _build
```

Si modificas `meson.build` o `meson_options.txt`, Meson se regenera solo al invocar `ninja`.

### Estructura del proyecto

```
planly/
├── meson.build                  # Build principal
├── meson_options.txt            # Opciones: profile (default/development)
├── src/
│   ├── config.vapi              # Constantes generadas por Meson (APP_ID, VERSION…)
│   ├── constants.vala           # Constantes de la aplicación (dimensiones, escala)
│   ├── utils.vala               # Utilidades matemáticas (redondeo, conversión)
│   ├── planly.vala              # Punto de entrada y clase Application
│   ├── gui/
│   │   ├── draw-mode.vala       # Enum DrawMode: NORMAL / FLATTEN
│   │   ├── scene.vala           # Canvas principal (Gtk.DrawingArea + Cairo)
│   │   ├── window.vala          # Ventana principal (Adw.ApplicationWindow)
│   │   └── components/
│   │       ├── drawable.vala    # Interfaz Drawable (GObject)
│   │       └── line.vala        # Entidad Line: geometría, métricas, interacción
│   └── project/
│       └── project.vala         # Placeholder para futura gestión de proyectos
├── data/
│   ├── com.dprietob.planly.desktop.in   # Acceso directo freedesktop
│   ├── com.dprietob.planly.appdata.xml.in  # Metadatos GNOME Software / AppStream
│   └── icons/hicolor/scalable/apps/
│       └── com.dprietob.planly.svg      # Icono de la aplicación
└── po/
    ├── LINGUAS                  # Idiomas disponibles
    ├── POTFILES                 # Ficheros fuente con cadenas traducibles
    └── es.po                    # Traducción al español
```

### Añadir un nuevo idioma

1. Añade el código de idioma a `po/LINGUAS` (p. ej. `fr`).
2. Genera el fichero `.po` inicial desde el directorio `_build/`:

```shell
ninja -C _build planly-pot       # Actualiza el fichero .pot
msginit -l fr -o po/fr.po -i _build/po/planly.pot
```

3. Traduce las cadenas en `po/fr.po`.
4. Recompila con `ninja -C _build`.

### Actualizar las cadenas traducibles

Cuando se añaden o modifican cadenas en el código:

```shell
ninja -C _build planly-update-po
```

Esto actualiza todos los ficheros `.po` existentes con las nuevas cadenas.

## ID de la aplicación

`com.dprietob.planly`

Sigue la convención de nomenclatura inversa de dominios de freedesktop / GNOME.
