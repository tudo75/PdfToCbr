/**
 * gui.vala
 *
 * Copyright 2025 Nicola tudo75 Tudino
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using GLib;

namespace PdfToCbr {
    /**
     * GUI application for PdfToCbr.
     * Extract imagews from a PDF file and save them in a CBZ/CBR  file or a folder.
     * 
     * @since 0.0.1
     */
    public class PdfToCbr : Gtk.Application {
        public const string APP_NAME = Constants.PROJECT_NAME;
        private const string VERSION = Constants.VERSION;
        private const string APP_ID = Constants.APP_ID;
        private const string APP_LANG_DOMAIN = Constants.GETTEXT_PACKAGE;
        private const string APP_INSTALL_PREFIX = Constants.PREFIX;
            
        private ExtractorWindow window;

        public PdfToCbr () {
            Object (application_id: APP_ID, flags: ApplicationFlags.FLAGS_NONE);

            // congfigure i18n localization
            Intl.setlocale (LocaleCategory.ALL, "");
            string langpack_dir = Path.build_filename (APP_INSTALL_PREFIX, "share", "locale");
            Intl.bindtextdomain (APP_LANG_DOMAIN, langpack_dir);
            Intl.bind_textdomain_codeset (APP_LANG_DOMAIN, "UTF-8");
            Intl.textdomain (APP_LANG_DOMAIN);
        }

        protected override void activate () {
            window = new ExtractorWindow (this);
            window.present ();
        }
    }
    
    public static int main (string[] args) {
        PdfToCbr app = new PdfToCbr ();
        return app.run (args);
    }
}