# config.h se genera en _build/src/, que el compilador C ya tiene en su -I path
conf = configuration_data()
conf.set_quoted('CONFIG_APP_ID', 'com.dprietob.planly')
conf.set_quoted('CONFIG_GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('CONFIG_LOCALEDIR', get_option('prefix') / get_option('localedir'))
conf.set_quoted('CONFIG_VERSION', meson.project_version())
configure_file(output: 'config.h', configuration: conf)

planly_sources = files(
  'gui/DrawMode.vala',
  # ── UI ────────────────────────────────────────────────────────────────
  'gui/HeaderBar.vala',
  'gui/Scene.vala',
  'gui/StatusBar.vala',
  'gui/ToolBar.vala',
  # ── Herramientas ──────────────────────────────────────────────────────
  'gui/ToolType.vala',
  'gui/Window.vala',
  'gui/components/Circle.vala',
  # ── Componentes dibujables ─────────────────────────────────────────────
  'gui/components/Drawable.vala',
  'gui/components/Line.vala',
  'gui/components/Rect.vala',
  'gui/components/Shape.vala',
  # ── Proyecto ──────────────────────────────────────────────────────────
  'project/Project.vala',
  'Accels.vala',
  'AccelsManager.vala',
  'Actions.vala',
  'Constants.vala',
  'Planly.vala',
  'Utils.vala',
)

cc = meson.get_compiler('c')

planly_deps = [
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
  cc.find_library('m'),
]

# Recursos (iconos svg)
planly_resources = gnome.compile_resources(
  'planly-resources',
  '../data/resources.gresource.xml',
  source_dir: '../data',
)

executable(
  'planly',
  planly_sources + planly_resources,
  files('Config.vapi'),
  dependencies: planly_deps,
  vala_args: ['--target-glib=2.76'],
  install: true,
)