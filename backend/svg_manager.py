import os
import re
from PySide6.QtCore import QObject, Signal, Slot

class SVGManager(QObject):
    svgUpdated = Signal()

    def __init__(self):
        super().__init__()
        self.svg_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                                    "frontend", "assets")
    @Slot(str)
    def update_svg_color(self, color):
        """Update all media control SVGs to use the specified color"""
        #print(f"Updating SVG colors to: {color}")
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
            #print(f"Attempting to update: {file_path}")
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
                    #print(f"Successfully updated {svg_name}")
                except Exception as e:
                    print(f"Error updating {svg_name}: {e}")
            else:
                print(f"File not found: {svg_name}")

        self.svgUpdated.emit()

    @Slot(str, str)
    def update_specific_svg(self, svg_name, color):
        """Update a specific SVG file with the given color"""
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