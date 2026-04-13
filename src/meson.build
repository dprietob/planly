# config.h se genera en _build/src/, que el compilador C ya tiene en su -I path
conf = configuration_data()
conf.set_quoted('CONFIG_APP_ID',          'com.dprietob.planly')
conf.set_quoted('CONFIG_GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('CONFIG_LOCALEDIR',       get_option('prefix') / get_option('localedir'))
conf.set_quoted('CONFIG_VERSION',         meson.project_version())
configure_file(output: 'config.h', configuration: conf)

planly_sources = files(
  'Planly.vala',
  'Constants.vala',
  'Utils.vala',
  # ── Herramientas ──────────────────────────────────────────────────────
  'gui/ToolType.vala',
  'gui/DrawMode.vala',
  # ── Componentes dibujables ─────────────────────────────────────────────
  'gui/components/Drawable.vala',
  'gui/components/Shape.vala',
  'gui/components/Line.vala',
  'gui/components/Rect.vala',
  'gui/components/Circle.vala',
  # ── UI ────────────────────────────────────────────────────────────────
  'gui/Scene.vala',
  'gui/Window.vala',
  # ── Proyecto ──────────────────────────────────────────────────────────
  'project/Project.vala',
)

cc = meson.get_compiler('c')

planly_deps = [
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
  cc.find_library('m'),  # libm: sqrt, cos, sin, atan2, fabs…
]

executable('planly',
  planly_sources,
  files('Config.vapi'),
  dependencies:  planly_deps,
  vala_args:     ['--target-glib=2.76'],
  install:       true,
)
