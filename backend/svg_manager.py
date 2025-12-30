import os
import re
from PySide6.QtCore import QObject, Signal, Slot

# Valid CSS named colors (subset of most common ones)
VALID_NAMED_COLORS = {
    'white', 'black', 'red', 'green', 'blue', 'yellow', 'cyan', 'magenta',
    'gray', 'grey', 'orange', 'purple', 'pink', 'brown', 'navy', 'teal',
    'silver', 'maroon', 'olive', 'lime', 'aqua', 'fuchsia', 'transparent',
    'currentcolor', 'none'
}


class SVGManager(QObject):
    svgUpdated = Signal()

    def __init__(self):
        super().__init__()
        self.svg_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                    "frontend", "assets")

    def _is_valid_color(self, color):
        """Validate that color is a valid hex color or named color"""
        if not isinstance(color, str):
            return False

        color = color.strip()

        # Check for valid hex color (#RGB, #RRGGBB, #RRGGBBAA)
        if re.match(r'^#[A-Fa-f0-9]{3}$', color):
            return True
        if re.match(r'^#[A-Fa-f0-9]{6}$', color):
            return True
        if re.match(r'^#[A-Fa-f0-9]{8}$', color):
            return True

        # Check for valid named color
        if color.lower() in VALID_NAMED_COLORS:
            return True

        # Check for rgb/rgba format
        if re.match(r'^rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*(,\s*[\d.]+\s*)?\)$', color):
            return True

        return False

    @Slot(str)
    def update_svg_color(self, color):
        """Update all media control SVGs to use the specified color"""
        # Validate color input before processing
        if not self._is_valid_color(color):
            print(f"Invalid color value rejected: {color}")
            return

        svg_files = [
            "previous_button.svg",
            "play_button.svg",
            "pause_button.svg",
            "next_button.svg",
            "mute_on.svg",
            "mute_off_low.svg",
            "mute_off_med.svg",
            "mute_off_high.svg",
            "left_arrow.svg",
            "right_arrow.svg",
            "home_button.svg",
            "obd_button.svg",
            "media_button.svg",
            "settings_button.svg"
        ]

        for svg_name in svg_files:
            file_path = os.path.join(self.svg_dir, svg_name)
            if os.path.exists(file_path):
                try:
                    with open(file_path, 'r') as file:
                        content = file.read()

                    # Handle both currentColor and specific colors
                    content = re.sub(
                        r'fill=["\'](?:currentColor|#[A-Fa-f0-9]{3,6}|white|WHITE)["\']',
                        f'fill="{color}"',
                        content,
                        flags=re.IGNORECASE
                    )

                    with open(file_path, 'w') as file:
                        file.write(content)
                except Exception as e:
                    print(f"Error updating {svg_name}: {e}")
            else:
                print(f"File not found: {svg_name}")

        self.svgUpdated.emit()

    @Slot(str, str)
    def update_specific_svg(self, svg_name, color):
        """Update a specific SVG file with the given color"""
        # Validate color input before processing
        if not self._is_valid_color(color):
            print(f"Invalid color value rejected: {color}")
            return

        # Validate svg_name to prevent path traversal
        if '..' in svg_name or '/' in svg_name or '\\' in svg_name:
            print(f"Invalid SVG filename rejected: {svg_name}")
            return

        file_path = os.path.join(self.svg_dir, svg_name)
        if os.path.exists(file_path):
            try:
                with open(file_path, 'r') as file:
                    content = file.read()

                content = re.sub(
                    r'fill=["\'](#[A-Fa-f0-9]{3,6}|[A-Za-z]+)["\']',
                    f'fill="{color}"',
                    content,
                    flags=re.IGNORECASE
                )

                with open(file_path, 'w') as file:
                    file.write(content)

                self.svgUpdated.emit()
            except Exception as e:
                print(f"Error updating {svg_name}: {e}")