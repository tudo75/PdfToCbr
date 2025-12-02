project('PdfToCbr', ['vala', 'c'], license: 'GPL-3.0-only', license_files: 'LICENSE', version: '0.0.2')

# Include the translations module
i18n = import('i18n')
# define GETTEXT_PACKAGE
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')
# Set our translation domain
add_global_arguments(['-DG_LOG_DOMAIN="@0@"'.format (meson.project_name())], language:'c')

add_global_arguments(['-DGDK_DISABLE_DEPRECATED', '-DGTK_DISABLE_DEPRECATED'], language:'c')

# Define depencies
dependencies = [
	dependency('glib-2.0'),
    dependency('gdk-pixbuf-2.0'),
	dependency('gio-2.0'),
    dependency('poppler-glib'),
    dependency('cairo'),
    dependency('libarchive'),
#   meson.get_compiler('c').find_library('m', required: false),
    meson.get_compiler('vala').find_library('posix'),
]

conf_data = configuration_data()
conf_data.set('APP_ID', 'com.github.tudo75.')
conf_data.set('PROJECT_NAME', meson.project_name())
conf_data.set('GETTEXT_PACKAGE', meson.project_name())
conf_data.set('VERSION', meson.project_version())
conf_data.set('PREFIX', get_option('prefix'))

config_header = configure_file(
     input: 'src/config.vala.in',
     output: 'config.vala',
     configuration: conf_data
)

# Specify the source files
src = files(
    'src/pdf_image_extractor.vala',
)

# Define the executable
executable(
    'pdftocbr-cli',
    'src/main_cli.vala',
    src, 
    config_header,
    dependencies: dependencies,
    install: true,
)

# Eseguibile con nuova interfaccia GTK4
executable(
    'pdftocbr',
    'src/gui.vala',
    'src/batchmode.vala',
    src,
    config_header,
    dependencies: dependencies + [dependency('gtk4')],
    install: true,
)

subdir('po')
subdir('resources')



# create api documentation from code
valadoc = find_program(
    'valadoc',
    required: false,
)

docsrc1 = [
    '../build/config.vala',
    '../src/pdf_image_extractor.vala',
    '../src/main_cli.vala',
]

docsrc2 = [
    '../build/config.vala',
    '../src/pdf_image_extractor.vala',
    '../src/gui.vala',
    '../src/batchmode.vala',
]

doc1 = custom_target(
    'documentation cli',
	output: 'doc-cli',
    build_by_default: false,
	command: [
        valadoc, 
        '--verbose',
        '--force',
        '--internal',
        '--private',
        '--use-svg-images',
        '--package-name=PdfToCbr-Cli',
        '--package-version=0.0.1',
        '--pkg=glib-2.0',
        '--pkg=gio-2.0',
        '--pkg=poppler-glib',
        '--pkg=cairo',
        '--pkg=libarchive',
        '--pkg=posix',
        '--pkg=gdk-pixbuf-2.0',
        '--directory=../doc-cli',
        '--target-glib=auto',
        docsrc1
    ],
)

doc2 = custom_target(
    'documentation gui',
	output: 'doc-gui',
    build_by_default: false,
	command: [
        valadoc, 
        '--verbose',
        '--force',
        '--internal',
        '--private',
        '--use-svg-images',
        '--package-name=PdfToCbr',
        '--package-version=0.0.1',
        '--pkg=gtk4',
        '--pkg=glib-2.0',
        '--pkg=gio-2.0',
        '--pkg=poppler-glib',
        '--pkg=cairo',
        '--pkg=libarchive',
        '--pkg=posix',
        '--pkg=gdk-pixbuf-2.0',
        '--directory=../doc-gui',
        '--target-glib=auto',
        docsrc2
    ],
)