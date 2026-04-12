i18n.merge_file(
  input:       'com.dprietob.planly.desktop.in',
  output:      'com.dprietob.planly.desktop',
  type:        'desktop',
  po_dir:      '../po',
  install:     true,
  install_dir: get_option('datadir') / 'applications',
)

i18n.merge_file(
  input:       'com.dprietob.planly.appdata.xml.in',
  output:      'com.dprietob.planly.appdata.xml',
  po_dir:      '../po',
  install:     true,
  install_dir: get_option('datadir') / 'metainfo',
)

install_data(
  'icons/hicolor/scalable/apps/com.dprietob.planly.svg',
  install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps',
)
