import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs

// иконка приложения, перекрашенная в палитру: ч/б по яркости, затем тон color. ok = иконка нашлась
Item {
    id: root

    property string name
    property int size: 24
    property color color: Theme.rose
    readonly property bool ok: img.source != ""

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        implicitSize: root.size
        source: Quickshell.iconPath(root.name, true)
        visible: false
    }
    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1
        colorizationColor: root.color
    }
}
