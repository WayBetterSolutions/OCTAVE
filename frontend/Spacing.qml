// Spacing.qml
pragma Singleton
import QtQuick 2.15

QtObject {
    // ===== Base dimensions and scaling factors =====
    property int applicationWidth: width
    property int applicationHeight: height
    
    // Global scaling properties
    property real globalScale: 1.0
    property real textScale: 1.0
    property real controlScale: 1.0
    
    // Core sizing values
    property real normalButtonSize: 0.07
    property double settingsMinPreviewWidth: 250
    
    // ===== Core percentage values =====
    // Base sizing percentages
    property real overallMarginPercent: 0.01
    property real overallTextPercent: 0.045
    property real overallSpacingPercent: .05
    property real overallSliderWidthPercent: 0.06
    property real overallSliderHeightPercent: 0.06
    property real overallSliderRadiusPercent: 0.03
    
    // ===== Section spacing values =====
    property int sectionSpacing: scaledSize(Math.min(applicationWidth, applicationHeight) * 0.05)
    property int rowSpacing: scaledSize(Math.min(applicationWidth, applicationHeight) * 0.015)
    property int columnSpacing: scaledSize(Math.min(applicationWidth, applicationHeight) * 0.02)
    
    // ===== Bottom Bar Properties =====
    property real bottomBarHeightPercent: 0.125
    property real bottomBarBetweenButtonMarginPercent: 0.01
    
    // Bottom bar buttons
    property real bottomBarPreviousButtonWidthPercent: normalButtonSize
    property real bottomBarPreviousButtonHeightPercent: normalButtonSize
    property real bottomBarPlayButtonWidthPercent: normalButtonSize + (normalButtonSize*.5)
    property real bottomBarPlayButtonHeightPercent: normalButtonSize + (normalButtonSize*.5)
    property real bottomBarNextButtonWidthPercent: normalButtonSize
    property real bottomBarNextButtonHeightPercent: normalButtonSize
    property real bottomBarMuteButtonWidthPercent: normalButtonSize
    property real bottomBarMuteButtonHeightPercent: normalButtonSize
    property real bottomBarShuffleButtonWidthPercent: normalButtonSize *1.125
    property real bottomBarShuffleButtonHeightPercent: normalButtonSize *1.125
    property real bottomBarNavButtonWidthPercent: normalButtonSize * 1.1
    property real bottomBarNavButtonHeightPercent: normalButtonSize * 2

    // Bottom bar volume controls
    property real bottomBarVolumeSliderWidthPercent: 0.05
    property real bottomBarVolumeSliderHeightPercent: 0.05
    property real bottomBarVolumeTextPercent: 0.05
    property real bottomBarVolumePopupTextBoxHeightPercent: 0.1
    property real bottomBarVolumePopupTextBoxWidthPercent: 0.1
    property real bottomBarVolumePopupTextPercent: 0.3
    property real bottomBarVolumePopupTextMarginPercent: 0.5
    property real bottomBarVolumePopupWidthPercent: 0.05
    property real bottomBarVolumePopupHeightPercent: 0.5
    
    // ===== Media Room Properties =====
    // Media room buttons and spacing
    property real mediaRoomMarginPercent: .01
    property real mediaRoomSpacingPercent: .05
    property real mediaRoomBetweenButtonPercent: .04
    
    // Media room controls container
    property real mediaRoomControlsContainerWidth: .9
    property real mediaRoomControlsContainerHeight: .6
    
    // Media room buttons
    property real mediaRoomPreviousButtonHeightPercent: .1
    property real mediaRoomPreviousButtonWidthPercent: .1
    property real mediaRoomPlayButtonHeightPercent: .3
    property real mediaRoomPlayButtonWidthPercent: .3
    property real mediaRoomNextButtonHeightPercent: .1
    property real mediaRoomNextButtonWidthPercent: .1
    property real mediaRoomShuffleButtonHeightPercent: .1
    property real mediaRoomShuffleButtonWidthPercent: .1
    
    // Media room metadata
    property real mediaRoomMetaSpacingPercent: .01
    property real mediaRoomMetaDataSongTextPercent: .06
    property real mediaRoomMetaDataBandTextPercent: .05
    property real mediaRoomMetaDataAlbumTextPercent: .05
    
    // Media room artwork
    property real mediaRoomAlbumArtHeightPercent: .6
    property real mediaRoomAlbumArtWidthPercent: .6
    
    // Media room progress and duration
    property real mediaRoomDurationBarHeightPercent: .1
    property real mediaRoomProgressSliderHeightPercent: .025
    property real mediaRoomSliderButtonHeightPercent: .05
    property real mediaRoomSliderButtonWidthPercent: .05
    property real mediaRoomSliderButtonRadiusPercent: .025
    property real mediaRoomSliderDurationTextPercent: .05

    // ===== Media Player Properties =====
    property real mediaPlayerHeaderHeightPercent: 0.08
    property real mediaPlayerRowHeightPercent: 0.15
    property real mediaPlayerIndexColumnWidthPercent: 0.05
    property real mediaPlayerTitleColumnWidthPercent: 0.60
    property real mediaPlayerAlbumColumnWidthPercent: 0.35
    property real mediaPlayerAlbumArtSizePercent: 0.075
    property real mediaPlayerTextSizePercent: 0.035
    property real mediaPlayerSecondaryTextSizePercent: 0.03
    property real mediaPlayerStatsBarHeightPercent: 0.05
    property real mediaPlayerStatsTextSizePercent: 0.03
    property real mediaPlayerContentMarginPercent: 0.01
    
    // ===== Settings Properties =====
    property real settingsNavMarginPercent: .01
    property real settingsContentMarginPercent: .05
    property real settingsDeviceNameWidthPercent: .2
    property real settingsDeviceNameHeightPercent: .05
    property real settingsNavWidthPercent: 0.25
    property real settingsButtonHeightPercent: 0.2
    property real settingsPreviewWidthPercent: 0.4
    property real formElementHeightPercent: 0.1
    property real formLabelWidthPercent: 0.2
    property real formInputWidthPercent: 0.4

    // ===== Main Menu Properties =====
    property real mainMenuOBDTextPercent: 0.075
    property real mainMenuOBDDataPercent: 0.1
    property real mainMenuSongTextPercent: 0.045
    property real mainMenuArtistTextPercent: 0.035
    property real mainMenuTimeTextPercent: 0.028
    property real mainMenuPlayButtonPercent: 0.12
    property real mainMenuNavButtonPercent: 0.085
    property real mainMenuSliderHeightPercent: 0.01
    property real mainMenuSliderHandlePercent: 0.03
    
    // ===== Core scaling functions =====
    /**
     * Applies global scaling to the provided size
     * @param {real} baseSize - The original size to scale
     * @return {int} - The scaled size as an integer
     */
    function scaledSize(baseSize) {
        return Math.round(baseSize * globalScale)
    }
    
    /**
     * Utility function to scale any value based on screen size
     * @param {real} size - The size to scale
     * @return {int} - The scaled size relative to screen dimensions
     */
    function scalePx(size) {
        return Math.round(size * globalScale * (Math.min(applicationWidth, applicationHeight) / 1000))
    }
    
    /**
     * Updates application dimensions and triggers recalculations
     * @param {int} width - New application width
     * @param {int} height - New application height
     */
    function updateDimensions(width, height) {
        applicationWidth = width
        applicationHeight = height
        dimensionsChanged()
    }
    
    // Signal handler property for notifying dimension changes
    property var dimensionsChanged: function() {}
    
    // ===== Calculated Dimensions - Core =====
    property int overallMargin: scaledSize(Math.min(applicationWidth, applicationHeight) * overallMarginPercent)
    property int overallText: scaledSize(Math.min(applicationWidth, applicationHeight) * overallTextPercent * textScale)
    property int overallSpacing: scaledSize(Math.min(applicationWidth, applicationHeight) * overallSpacingPercent)
    property int overallSliderWidth: scaledSize(Math.min(applicationWidth, applicationHeight) * overallSliderWidthPercent)
    property int overallSliderHeight: scaledSize(Math.min(applicationWidth, applicationHeight) * overallSliderHeightPercent)
    property int overallSliderRadius: scaledSize(Math.min(applicationWidth, applicationHeight) * overallSliderRadiusPercent)
    
    // ===== Calculated Dimensions - Bottom Bar =====
    property int bottomBarHeight: scaledSize(applicationHeight * bottomBarHeightPercent)
    property int bottomBarBetweenButtonMargin: scaledSize(Math.min(applicationWidth, applicationHeight) * bottomBarBetweenButtonMarginPercent)
    property int bottomBarPreviousButtonWidth: scaledSize(applicationWidth * bottomBarPreviousButtonWidthPercent)
    property int bottomBarPreviousButtonHeight: scaledSize(applicationHeight * bottomBarPreviousButtonHeightPercent)
    property int bottomBarPlayButtonWidth: scaledSize(applicationWidth * bottomBarPlayButtonWidthPercent)
    property int bottomBarPlayButtonHeight: scaledSize(applicationHeight * bottomBarPlayButtonHeightPercent)
    property int bottomBarNextButtonWidth: scaledSize(applicationWidth * bottomBarNextButtonWidthPercent)
    property int bottomBarNextButtonHeight: scaledSize(applicationHeight * bottomBarNextButtonHeightPercent)
    property int bottomBarMuteButtonWidth: scaledSize(applicationWidth * bottomBarMuteButtonWidthPercent)
    property int bottomBarMuteButtonHeight: scaledSize(applicationHeight * bottomBarMuteButtonHeightPercent)
    property int bottomBarShuffleButtonWidth: scaledSize(applicationWidth * bottomBarShuffleButtonWidthPercent)
    property int bottomBarShuffleButtonHeight: scaledSize(applicationHeight * bottomBarShuffleButtonHeightPercent)
    property int bottomBarVolumeSliderWidth: scaledSize(applicationWidth * bottomBarVolumeSliderWidthPercent)
    property int bottomBarVolumeSliderHeight: scaledSize(applicationHeight * bottomBarVolumeSliderHeightPercent)
    property int bottomBarVolumeText: scaledSize(Math.min(applicationWidth, applicationHeight) * bottomBarVolumeTextPercent)
    property int bottomBarVolumePopupTextBoxHeight: scaledSize(Math.min(applicationWidth, applicationHeight) * bottomBarVolumePopupTextBoxHeightPercent)
    property int bottomBarVolumePopupTextBoxWidth: scaledSize(Math.min(applicationWidth, applicationHeight) * bottomBarVolumePopupTextBoxWidthPercent)
    property int bottomBarVolumePopupText: scaledSize(Math.min(applicationWidth, applicationHeight) * bottomBarVolumePopupTextPercent)
    property int bottomBarVolumePopupTextMargin: scaledSize(Math.min(applicationWidth, applicationHeight) * bottomBarVolumePopupTextMarginPercent)
    property int bottomBarVolumePopupWidth: scaledSize(applicationWidth * bottomBarVolumePopupWidthPercent)
    property int bottomBarVolumePopupHeight: scaledSize(applicationHeight * bottomBarVolumePopupHeightPercent)
    property int bottomBarNavButtonWidth: scaledSize(applicationWidth * bottomBarNavButtonWidthPercent)
    property int bottomBarNavButtonHeight: scaledSize(applicationHeight * bottomBarNavButtonHeightPercent)
    
    // ===== Calculated Dimensions - Media Room =====
    property int mediaRoomMargin: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomMarginPercent)
    property int mediaRoomSpacing: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomSpacingPercent)
    property int mediaRoomBetweenButton: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomBetweenButtonPercent)
    property int mediaRoomPreviousButtonHeight: scaledSize(applicationHeight * mediaRoomPreviousButtonHeightPercent)
    property int mediaRoomPreviousButtonWidth: scaledSize(applicationWidth * mediaRoomPreviousButtonWidthPercent)
    property int mediaRoomPlayButtonHeight: scaledSize(applicationHeight * mediaRoomPlayButtonHeightPercent)
    property int mediaRoomPlayButtonWidth: scaledSize(applicationWidth * mediaRoomPlayButtonWidthPercent)
    property int mediaRoomNextButtonHeight: scaledSize(applicationHeight * mediaRoomNextButtonHeightPercent)
    property int mediaRoomNextButtonWidth: scaledSize(applicationWidth * mediaRoomNextButtonWidthPercent)
    property int mediaRoomShuffleButtonHeight: scaledSize(applicationHeight * mediaRoomShuffleButtonHeightPercent)
    property int mediaRoomShuffleButtonWidth: scaledSize(applicationWidth * mediaRoomShuffleButtonWidthPercent)
    property int mediaRoomMetaSpacing: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomMetaSpacingPercent)
    property int mediaRoomMetaDataSongText: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomMetaDataSongTextPercent)
    property int mediaRoomMetaDataBandText: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomMetaDataBandTextPercent)
    property int mediaRoomMetaDataAlbumText: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomMetaDataAlbumTextPercent)
    property int mediaRoomAlbumArtHeight: scaledSize(applicationHeight * mediaRoomAlbumArtHeightPercent)
    property int mediaRoomAlbumArtWidth: scaledSize(applicationWidth * mediaRoomAlbumArtWidthPercent)
    property int mediaRoomDurationBarHeight: scaledSize(applicationHeight * mediaRoomDurationBarHeightPercent)
    property int mediaRoomProgressSliderHeight: scaledSize(applicationHeight * mediaRoomProgressSliderHeightPercent)
    property int mediaRoomSliderButtonWidth: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomSliderButtonWidthPercent)
    property int mediaRoomSliderButtonHeight: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomSliderButtonHeightPercent)
    property int mediaRoomSliderButtonRadius: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomSliderButtonRadiusPercent)
    property int mediaRoomSliderDurationText: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaRoomSliderDurationTextPercent)

    // ===== Calculated Dimensions - Media Player =====
    property int mediaPlayerHeaderHeight: scaledSize(applicationHeight * mediaPlayerHeaderHeightPercent)
    property int mediaPlayerRowHeight: scaledSize(applicationHeight * mediaPlayerRowHeightPercent)
    property int mediaPlayerAlbumArtSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaPlayerAlbumArtSizePercent)
    property int mediaPlayerTextSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaPlayerTextSizePercent)
    property int mediaPlayerSecondaryTextSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaPlayerSecondaryTextSizePercent)
    property int mediaPlayerStatsBarHeight: scaledSize(applicationHeight * mediaPlayerStatsBarHeightPercent)
    property int mediaPlayerStatsTextSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaPlayerStatsTextSizePercent)
    property int mediaPlayerContentMargin: scaledSize(Math.min(applicationWidth, applicationHeight) * mediaPlayerContentMarginPercent)

    // ===== Calculated Dimensions - Settings =====
    property int settingsNavMargin: scaledSize(Math.min(applicationWidth, applicationHeight) * settingsNavMarginPercent)
    property int settingsContentMargin: scaledSize(Math.min(applicationWidth, applicationHeight) * settingsContentMarginPercent)
    property int settingsDeviceNameHeight: scaledSize(applicationHeight * settingsDeviceNameHeightPercent)
    property int settingsDeviceNameWidth: scaledSize(applicationWidth * settingsDeviceNameWidthPercent)
    property int settingsNavWidth: scaledSize(applicationWidth * settingsNavWidthPercent)
    property int settingsButtonHeight: scaledSize(applicationHeight * settingsButtonHeightPercent)
    property int settingsPreviewWidth: scaledSize(applicationWidth * settingsPreviewWidthPercent)
    property int formElementHeight: scaledSize(applicationHeight * formElementHeightPercent)
    property int formLabelWidth: scaledSize(applicationWidth * formLabelWidthPercent)
    property int formInputWidth: scaledSize(applicationWidth * formInputWidthPercent)

    property int mainMenuOBDTextSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuOBDTextPercent)
    property int mainMenuOBDDataSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuOBDDataPercent)
    property int mainMenuSongTextSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuSongTextPercent)
    property int mainMenuArtistTextSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuArtistTextPercent)
    property int mainMenuTimeTextSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuTimeTextPercent)
    property int mainMenuPlayButtonSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuPlayButtonPercent)
    property int mainMenuNavButtonSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuNavButtonPercent)
    property int mainMenuSliderHeight: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuSliderHeightPercent)
    property int mainMenuSliderHandleSize: scaledSize(Math.min(applicationWidth, applicationHeight) * mainMenuSliderHandlePercent)
}