/**
 * main_cli.vala
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

using GLib;

namespace PdfToCbr {
    /**
     * Command line executable for PdfToCbr.
     * 
     * @since 0.0.1
     */
    public class PdfToCbrCli {
        /**
         * Output path of the CBZ/CBR file or folder where to save the extracted images.
         * 
         * @since 0.0.1
         */
        private static string? output_path = null;
        /**
         * Format of the extracted images (png or jpg).
         * Default is png.
         * 
         * @since 0.0.1
         */
        private static string format = "png";

        private const OptionEntry[] options = {
            { "output", 'o', 0, OptionArg.STRING, ref output_path, "Output path (folder or file .cbz/.cbr)", "PATH" },
            { "format", 'f', 0, OptionArg.STRING, ref format, "Image format (png or jpg)", "IMAGE_FORMAT" },
            { null }
        };

        /**
         * Command line executable for PdfToCbr.
         * @param args Array of the command line options and values.
         * -o, --output=PATH             Output path (folder or file .cbz/.cbr)
         * -f, --format=IMAGE_FORMAT     Image format (png or jpg)
         * 
         * @since 0.0.1
         */
        public static int main(string[] args) {
            try {
                var context = new GLib.OptionContext ("<file_input.pdf>");
                context.set_summary (_("Extract all images from a PDF file."));
                context.set_help_enabled (true);
                context.add_main_entries (options, Constants.GETTEXT_PACKAGE);
                context.parse (ref args);
            } catch (GLib.OptionError e) {
                stderr.printf (_("Error during options parsing: %s\n"), e.message);
                stderr.printf (_("For more details ececute '%s --help'.\n"), args[0]);
                return 1;
            }

            if (output_path == null) {
                stderr.printf(_("Error: --output option is mandatory.\n"));
                stderr.printf(_("For more details ececute '%s --help'.\n"), args[0]);
                return 1;
            }

            if (args.length < 2) {
                stderr.printf(_("Error: give a PDF input file.\n"));
                stderr.printf(_("For more details ececute '%s --help'.\n"), args[0]);
                return 1;
            }
            string input_path = args[1];

            format = format.down();
            if (format == "jpeg") format = "jpg";

            if (format != "png" && format != "jpg") {
                stderr.printf(_("Error: not supported '%s' format.\n"), format);
                return 1;
            }

            if (!FileUtils.test(input_path, GLib.FileTest.EXISTS)) {
                stderr.printf(_("Error: '%s' file not found.\n"), input_path);
                return 1;
            }

            var extractor = new PdfImageExtractor();

            // Connect to signals for console feedback
            extractor.progress.connect((current, total, msg) => {
                stdout.printf("\r%s", msg);
            });

            extractor.finished.connect((total_images, out_path) => {
                stdout.printf(_("\nFinished! %d images saved in '%s'.\n"), total_images, out_path);
            });

            extractor.error.connect((msg) => {
                stderr.printf(_("\nError: %s\n"), msg);
            });

            // Execute extraction
            extractor.extract_images(input_path, output_path, format);

            return 0;
        }
    }
}