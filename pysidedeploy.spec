[app]
title = OCTAVE
project_dir = .
input_file = main.py
exec_directory = dist
# icon = path/to/icon.jpg

[python]
# Set to your Python 3.11 path (must match wheel cp311 ABI)
python_path = /path/to/python3.11
android_packages =

[qt]
modules = OpenGL,Qml,Concurrent,Core,Widgets,QuickControls2,Quick,Multimedia,Gui,Network
plugins =
qml_files = dev/DevMain.qml,dev/DevToolsPanel.qml,frontend/AlbumArtCarousel.qml,frontend/AndroidAutoView.qml,frontend/BottomBar.qml,frontend/CarMenu.qml,frontend/ClockMenu.qml,frontend/CornerBrackets.qml,frontend/CoverflowCard.qml,frontend/DownloadPage.qml,frontend/EnvironmentTheme.qml,frontend/GForceDisplay.qml,frontend/HomeOBDView.qml,frontend/LazyImage.qml,frontend/Main.qml,frontend/MainMenu.qml,frontend/MediaPlayer.qml,frontend/MediaRoom.qml,frontend/OBDDiagnostics.qml,frontend/OBDMenu.qml,frontend/OBDParameterModel.qml,frontend/PhoneMirrorView.qml,frontend/SensorCard.qml,frontend/SensorMenu.qml,frontend/SettingsCarouselLayout.qml,frontend/SettingsDashboardLayout.qml,frontend/SettingsHubLayout.qml,frontend/SettingsMenu.qml,frontend/SettingsSidebarLayout.qml,frontend/Spacing.qml,frontend/Style.qml,frontend/TerminalFeedback.qml,frontend/settings/AboutPage.qml,frontend/settings/AccessoriesSettingsPage.qml,frontend/settings/AndroidAutoSettingsPage.qml,frontend/settings/ContentSolarSystem.qml,frontend/settings/ContentSonar.qml,frontend/settings/DeviceSettingsPage.qml,frontend/settings/DisplaySettingsPage.qml,frontend/settings/GestureSensorSettingsPage.qml,frontend/settings/HomeScreenButton.qml,frontend/settings/MediaSettingsPage.qml,frontend/settings/OBDSettingsPage.qml,frontend/settings/PhoneDockSettingsPage.qml,frontend/settings/PhoneMirrorSettingsPage.qml,frontend/settings/SettingDescription.qml,frontend/settings/SettingLabel.qml,frontend/settings/SettingsButton.qml,frontend/settings/SettingsCard.qml,frontend/settings/SettingsCheckBox.qml,frontend/settings/SettingsChips.qml,frontend/settings/SettingsCollapsibleSection.qml,frontend/settings/SettingsDashboardCard.qml,frontend/settings/SettingsDivider.qml,frontend/settings/SettingsDropdown.qml,frontend/settings/SettingsHubCard.qml,frontend/settings/SettingsHubGridCard.qml,frontend/settings/SettingsRadio.qml,frontend/settings/SettingsSectionHeader.qml,frontend/settings/SettingsSegmentedControl.qml,frontend/settings/SettingsSlider.qml,frontend/settings/SettingsTextField.qml,frontend/settings/SettingsToggle.qml,frontend/settings/SidebarBubbles.qml,frontend/settings/SidebarDotGrid.qml,frontend/settings/ValueDisplay.qml,frontend/settings/VolumeKnobSettingsPage.qml,frontend/settings/widgets/AboutWidget.qml,frontend/settings/widgets/AccessoriesWidget.qml,frontend/settings/widgets/DeviceWidget.qml,frontend/settings/widgets/DisplayWidget.qml,frontend/settings/widgets/MediaWidget.qml,frontend/settings/widgets/OBDWidget.qml,frontend/settings/widgets/PhoneDockWidget.qml,frontend/settings/widgets/WidgetChip.qml,frontend/settings/widgets/WidgetPill.qml
excluded_qml_plugins = QtCharts,QtSensors,QtWebEngine

[android]
# Place wheels in deployment/wheels/ (see README for download instructions)
wheel_pyside = deployment/wheels/pyside6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl
wheel_shiboken = deployment/wheels/shiboken6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl
# Required: NDK r26b (26.1.10909125) — SET THESE TO YOUR LOCAL PATHS
ndk_path = /path/to/Android/Sdk/ndk/26.1.10909125
sdk_path = /path/to/Android/Sdk
plugins = multimedia_ffmpegmediaplugin,platforms_qtforandroid,multimedia_androidmediaplugin

[buildozer]
mode = debug
# Required: NDK r26b (26.1.10909125) — SET THESE TO YOUR LOCAL PATHS
ndk_path = /path/to/Android/Sdk/ndk/26.1.10909125
sdk_path = /path/to/Android/Sdk
arch = aarch64
local_libs = plugins_platforms_qtforandroid,plugins_multimedia_ffmpegmediaplugin,plugins_multimedia_androidmediaplugin
jars_dir = deployment/jar/PySide6/jar
recipe_dir = deployment/recipes

