[app]
title = OCTAVE
project_dir = .
input_file = main.py
exec_directory = dist
icon = /home/rhea/Dropbox/Oasis/_OCTAVE_ANDROID_VENV/lib/python3.11/site-packages/PySide6/scripts/deploy_lib/pyside_icon.jpg

[python]
python_path = /home/rhea/Dropbox/Oasis/_OCTAVE_ANDROID_VENV/bin/python3.11
android_packages = 

[qt]
modules = OpenGL,Qml,Concurrent,Core,Widgets,QuickControls2,Quick,Multimedia,Gui,Network
plugins = 
qml_files = dev/DevMain.qml,dev/DevToolsPanel.qml,frontend/AlbumArtCarousel.qml,frontend/AndroidAutoView.qml,frontend/BottomBar.qml,frontend/CarMenu.qml,frontend/ClockMenu.qml,frontend/CornerBrackets.qml,frontend/CoverflowCard.qml,frontend/DownloadPage.qml,frontend/EnvironmentTheme.qml,frontend/GForceDisplay.qml,frontend/HomeOBDView.qml,frontend/LazyImage.qml,frontend/Main.qml,frontend/MainMenu.qml,frontend/MediaPlayer.qml,frontend/MediaRoom.qml,frontend/OBDDiagnostics.qml,frontend/OBDMenu.qml,frontend/OBDParameterModel.qml,frontend/PhoneMirrorView.qml,frontend/SensorCard.qml,frontend/SensorMenu.qml,frontend/SettingsCarouselLayout.qml,frontend/SettingsDashboardLayout.qml,frontend/SettingsHubLayout.qml,frontend/SettingsMenu.qml,frontend/SettingsSidebarLayout.qml,frontend/Spacing.qml,frontend/Style.qml,frontend/TerminalFeedback.qml,frontend/settings/AboutPage.qml,frontend/settings/AccessoriesSettingsPage.qml,frontend/settings/AndroidAutoSettingsPage.qml,frontend/settings/ContentSolarSystem.qml,frontend/settings/ContentSonar.qml,frontend/settings/DeviceSettingsPage.qml,frontend/settings/DisplaySettingsPage.qml,frontend/settings/GestureSensorSettingsPage.qml,frontend/settings/HomeScreenButton.qml,frontend/settings/MediaSettingsPage.qml,frontend/settings/OBDSettingsPage.qml,frontend/settings/PhoneDockSettingsPage.qml,frontend/settings/PhoneMirrorSettingsPage.qml,frontend/settings/SettingDescription.qml,frontend/settings/SettingLabel.qml,frontend/settings/SettingsButton.qml,frontend/settings/SettingsCard.qml,frontend/settings/SettingsCheckBox.qml,frontend/settings/SettingsChips.qml,frontend/settings/SettingsCollapsibleSection.qml,frontend/settings/SettingsDashboardCard.qml,frontend/settings/SettingsDivider.qml,frontend/settings/SettingsDropdown.qml,frontend/settings/SettingsHubCard.qml,frontend/settings/SettingsHubGridCard.qml,frontend/settings/SettingsRadio.qml,frontend/settings/SettingsSectionHeader.qml,frontend/settings/SettingsSegmentedControl.qml,frontend/settings/SettingsSlider.qml,frontend/settings/SettingsTextField.qml,frontend/settings/SettingsToggle.qml,frontend/settings/SidebarBubbles.qml,frontend/settings/SidebarDotGrid.qml,frontend/settings/ValueDisplay.qml,frontend/settings/VolumeKnobSettingsPage.qml,frontend/settings/widgets/AboutWidget.qml,frontend/settings/widgets/AccessoriesWidget.qml,frontend/settings/widgets/DeviceWidget.qml,frontend/settings/widgets/DisplayWidget.qml,frontend/settings/widgets/MediaWidget.qml,frontend/settings/widgets/OBDWidget.qml,frontend/settings/widgets/PhoneDockWidget.qml,frontend/settings/widgets/WidgetChip.qml,frontend/settings/widgets/WidgetPill.qml
excluded_qml_plugins = QtCharts,QtSensors,QtWebEngine

[android]
wheel_pyside = /home/rhea/Dropbox/Oasis/_OCTAVE_ANDROID_WHEELS/pyside6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl
wheel_shiboken = /home/rhea/Dropbox/Oasis/_OCTAVE_ANDROID_WHEELS/shiboken6-6.11.0-6.11.0-cp311-cp311-android_aarch64.whl
ndk_path = /home/rhea/Android/Sdk/ndk/26.1.10909125
sdk_path = /home/rhea/Android/Sdk
plugins = multimedia_ffmpegmediaplugin,platforms_qtforandroid,multimedia_androidmediaplugin

[buildozer]
mode = debug
ndk_path = /home/rhea/Android/Sdk/ndk/26.1.10909125
sdk_path = /home/rhea/Android/Sdk
arch = aarch64
local_libs = plugins_platforms_qtforandroid,plugins_multimedia_ffmpegmediaplugin,plugins_multimedia_androidmediaplugin
jars_dir = /home/rhea/Dropbox/Oasis/_OCTAVE/deployment/jar/PySide6/jar
recipe_dir = /home/rhea/Dropbox/Oasis/_OCTAVE/deployment/recipes

