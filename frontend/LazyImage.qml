import QtQuick 2.15

Item {
    id: root
    property string source
    property bool rounded: false
    property int fidelity: 60
    property bool smoothing: false     // Enable/disable smoothing
    property bool mipmap: false        // Enable/disable mipmapping
    property bool antialiasing: false  // Enable/disable antialiasing
    property real quality: 0.0         // Image quality (0.0 to 1.0)
    property int cacheLimit: 2048      // Cache size limit in KB
    
    Image {
        id: img
        anchors.fill: parent
        source: root.visible ? root.source : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        sourceSize {
            width: root.fidelity
            height: root.fidelity
        }
        visible: status === Image.Ready
        smooth: root.smoothing
        mipmap: root.mipmap
        antialiasing: root.antialiasing
        autoTransform: true
    }
}