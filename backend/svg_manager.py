import os
import re
from PySide6.QtCore import QObject, Signal, Slot

from backend.logging_config import get_logger
logger = get_logger(__name__)

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
        logger.debug(f" update_svg_color called with: {color}")
        # Validate color input before processing
        if not self._is_valid_color(color):
            logger.debug(f" Invalid color value rejected: {color}")
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
                    logger.error(f"Error updating {svg_name}: {e}")
            else:
                logger.warning(f"File not found: {svg_name}")

        self.svgUpdated.emit()

    @Slot(str, str)
    def update_specific_svg(self, svg_name, color):
        """Update a specific SVG file with the given color"""
        # Validate color input before processing
        if not self._is_valid_color(color):
            logger.warning(f"Invalid color value rejected: {color}")
            return

        # Validate svg_name to prevent path traversal
        if '..' in svg_name or '/' in svg_name or '\\' in svg_name:
            logger.warning(f"Invalid SVG filename rejected: {svg_name}")
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
                logger.error(f"Error updating {svg_name}: {e}")

    @Slot(str)
    def update_svg_colors_from_theme(self, theme_json):
        """Update SVG icons with varied colors from a theme JSON"""
        import json
        try:
            theme = json.loads(theme_json)
            bottombar = theme.get("bottombar", {})
            mediaroom = theme.get("mediaroom", {})

            # Map SVG files to their theme colors
            svg_color_map = {
                "previous_button.svg": bottombar.get("previous", bottombar.get("play")),
                "play_button.svg": bottombar.get("play"),
                "pause_button.svg": bottombar.get("pause", bottombar.get("play")),
                "next_button.svg": bottombar.get("next", bottombar.get("play")),
                "mute_on.svg": bottombar.get("volume", bottombar.get("play")),
                "mute_off_low.svg": bottombar.get("volume", bottombar.get("play")),
                "mute_off_med.svg": bottombar.get("volume", bottombar.get("play")),
                "mute_off_high.svg": bottombar.get("volume", bottombar.get("play")),
                "left_arrow.svg": mediaroom.get("left", bottombar.get("play")),
                "right_arrow.svg": mediaroom.get("right", bottombar.get("play")),
                "home_button.svg": bottombar.get("homeButton", bottombar.get("play")),
                "obd_button.svg": bottombar.get("obdButton", bottombar.get("play")),
                "media_button.svg": bottombar.get("mediaButton", bottombar.get("play")),
                "settings_button.svg": bottombar.get("settingsButton", bottombar.get("play")),
            }

            logger.debug(f" Updating SVGs with varied colors from theme")

            for svg_name, color in svg_color_map.items():
                if not color or not self._is_valid_color(color):
                    continue

                file_path = os.path.join(self.svg_dir, svg_name)
                if os.path.exists(file_path):
                    try:
                        with open(file_path, 'r') as file:
                            content = file.read()

                        content = re.sub(
                            r'fill=["\'](?:currentColor|#[A-Fa-f0-9]{3,6}|white|WHITE)["\']',
                            f'fill="{color}"',
                            content,
                            flags=re.IGNORECASE
                        )

                        with open(file_path, 'w') as file:
                            file.write(content)
                    except Exception as e:
                        logger.error(f"Error updating {svg_name}: {e}")

            # Emit signal once after all updates
            self.svgUpdated.emit()

        except json.JSONDecodeError as e:
            logger.debug(f" Error parsing theme JSON: {e}")
        except Exception as e:
            logger.debug(f" Error updating SVG colors: {e}")