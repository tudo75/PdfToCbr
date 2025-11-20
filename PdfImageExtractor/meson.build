project('pdf-image-extractor', ['vala', 'c'], license: 'GPL-3.0-only', version: '0.0.1')

# Include the translations module
# i18n = import('i18n')
# define GETTEXT_PACKAGE
# add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')
# Set our translation domain
# add_global_arguments(['-DG_LOG_DOMAIN="@0@"'.format (meson.project_name())], language:'c')

add_global_arguments(['-DGDK_DISABLE_DEPRECATED', '-DGTK_DISABLE_DEPRECATED'], language:'c')

# Define depencies
dependencies = [
	dependency('glib-2.0'),
    dependency('gdk-pixbuf-2.0'),
	dependency('gio-2.0'),
    dependency('poppler-glib'),
    dependency('cairo'),
#   meson.get_compiler('c').find_library('m', required: false),
#   meson.get_compiler('vala').find_library('posix'),
]

conf_data = configuration_data()
conf_data.set('APP_ID', meson.project_name())
conf_data.set('PROJECT_NAME', meson.project_name())
conf_data.set('GETTEXT_PACKAGE', meson.project_name())
conf_data.set('VERSION', meson.project_version())
conf_data.set('PREFIX', get_option('prefix'))

# config_header = configure_file(
#     input: 'src/config.vala.in',
#     output: 'config.vala',
#     configuration: conf_data
# )

# Specify the source files
src = files(
    'pdf_image_extractor.vala',
    #'src/labels.vala',
)

# Define the executable
executable(
    'pdf-image-extractor', 
    src,
#    config_header,
    dependencies: dependencies,
)
