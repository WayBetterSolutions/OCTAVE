[app]
title = OCTAVE
package.name = OCTAVE
package.domain = org.OCTAVE

# Run buildozer from the deployment/ directory; source.dir points to project root
source.dir = ..
source.include_exts = py,png,jpg,kv,atlas,qml,js,json,ttf,otf,svg,mp3,wav
source.exclude_dirs = venv,dev,build_scripts,tools,.git,.claude,backend/android_auto/proto,dist,deployment,.buildozer,venv_old_linux,backend/media
source.exclude_patterns = setup.py,pyproject.toml,requirements*.txt,BUILD.md,LICENSE,README.md,pysidedeploy.spec,*.spec
version = 0.1
requirements = python3,shiboken6,PySide6,mutagen,requests,urllib3,certifi,charset-normalizer,idna,yt-dlp,ytmusicapi,rapidfuzz,redis,six
orientation = landscape
osx.python_version = 3
osx.kivy_version = 1.9.1
fullscreen = 1
android.archs = arm64-v8a
android.allow_backup = True
ios.kivy_ios_url = https://github.com/kivy/kivy-ios
ios.kivy_ios_branch = master
ios.ios_deploy_url = https://github.com/phonegap/ios-deploy
ios.ios_deploy_branch = 1.10.0
ios.codesign.allowed = false

# ---- SET THESE TO YOUR LOCAL PATHS ----
# Required: Android NDK r26b (26.1.10909125), Python 3.11 host toolchain
# Install via Android Studio SDK Manager or `sdkmanager "ndk;26.1.10909125"`
android.ndk_path = /path/to/Android/Sdk/ndk/26.1.10909125
android.sdk_path = /path/to/Android/Sdk

p4a.bootstrap = qt
# Relative to this spec file (deployment/)
p4a.local_recipes = recipes
p4a.branch = develop
android.permissions = android.permission.INTERNET, android.permission.ACCESS_NETWORK_STATE, android.permission.CAMERA, android.permission.BLUETOOTH, android.permission.BLUETOOTH_CONNECT, android.permission.BLUETOOTH_SCAN, android.permission.BLUETOOTH_ADMIN, android.permission.ACCESS_FINE_LOCATION, android.permission.MODIFY_AUDIO_SETTINGS, android.permission.WRITE_EXTERNAL_STORAGE, android.permission.RECORD_AUDIO
# Relative to this spec file (deployment/)
android.add_jars = jar/PySide6/jar/Qt6AndroidNetwork.jar,jar/PySide6/jar/Qt6Android.jar,jar/PySide6/jar/Qt6AndroidQuick.jar,jar/PySide6/jar/Qt6AndroidNetworkInformationBackend.jar,jar/PySide6/jar/Qt6AndroidBindings.jar,jar/PySide6/jar/Qt6AndroidMultimedia.jar,jar/PySide6/jar/Qt6AndroidBluetooth.jar
p4a.extra_args = --sdk-dir=/path/to/Android/Sdk --ndk-dir=/path/to/Android/Sdk/ndk/26.1.10909125 --qt-libs=OpenGL,Qml,Concurrent,Core,Widgets,QuickControls2,Quick,Multimedia,Gui,Network --load-local-libs=plugins_platforms_qtforandroid,plugins_multimedia_ffmpegmediaplugin,plugins_multimedia_androidmediaplugin,plugins_imageformats_qsvg --init-classes=
# icon.filename = path/to/icon.jpg

[buildozer]
log_level = 2
warn_on_root = 1
bin_dir = ../dist

