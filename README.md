# Zotero Dark AMOLED

A minimal, high-contrast dark theme (AMOLED-friendly) for Zotero. This repository contains styles and scripts to apply a true-black, eye-friendly appearance to Zotero's interface.

## Features

- True black backgrounds to reduce power usage on OLED/AMOLED displays
- High-contrast text and UI elements for better readability
- Small, focused CSS/Style changes for easy maintenance

## Installation

1. Close Zotero.
2. Locate your Zotero profile directory. On most systems this is in:
   - macOS: ~/Library/Application Support/Zotero/
   - Linux: ~/.zotero/zotero/
   - Windows: %APPDATA%\Zotero\
3. Inside the profile folder, open the "chrome" (or create it) directory.
4. Copy the stylesheet files from this repository into the chrome directory and update your userChrome.css or userContent.css to import them, or follow any add-on-specific installation instructions if provided.
5. Restart Zotero.

## Usage

- If this repository contains a single CSS file (e.g. zotero-dark-amoled.css), add an @import or paste the contents into your existing userChrome.css/file.
- Tweak colors or selectors as needed; the CSS aims to be minimal and easy to customize.

## Customization

Modify color variables at the top of the stylesheet to change accent colors or tweak contrast. If you need support for additional UI elements, open an issue describing the item and preferred styling.

## Contributing

Contributions are welcome. Please open issues for bugs or feature requests, and submit pull requests for fixes or improvements. Keep changes focused and document any selector changes in the PR description.

## License

This repository does not include a license file. If you want to reuse these styles in other projects, please add a LICENSE file or indicate the preferred license in a new issue/PR.

---