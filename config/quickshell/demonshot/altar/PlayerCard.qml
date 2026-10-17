import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// XXI · The World: круг-уроборос, внутри обложка пикселями (или Crimson ascii-D), по кругу — прогресс, кнопки
HandCard {
    id: c

    property bool full: false // Media: полоска прогресса и время
    readonly property var p: Media.player
    readonly property real len: p?.length ?? 0

    num: "XXI"
    name: "The World"
    rays: false

    Art.Orb {
        value: c.len > 0 ? Media.position / c.len : 0
        Item {
            width: 92; height: 92
            Image {
                id: cover
                anchors.fill: parent
                source: c.p?.trackArtUrl ?? ""
                sourceSize: Qt.size(30, 30)
                smooth: false
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            // круглая маска
            Rectangle { id: mask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
            MultiEffect {
                anchors.fill: parent
                visible: cover.status === Image.Ready
                source: cover
                maskEnabled: true
                maskSource: mask
            }
            AsciiD {
                visible: cover.status !== Image.Ready
                anchors.centerIn: parent
                font.pixelSize: 5
            }
        }
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 12
        Layout.maximumWidth: 180
        elide: Text.ElideRight
        text: c.p?.trackTitle || "Demon's Shot"
        font { family: Theme.frak; pixelSize: 23 }
        color: Theme.bone
    }
    Art.T2 {
        Layout.topMargin: 4
        Layout.maximumWidth: 180
        elide: Text.ElideRight
        text: c.p ? `${c.p.trackArtist || c.p.identity}${c.full ? "" : " · " + Media.time(Media.position)}` : "nothing plays"
    }
    Rectangle {
        visible: c.full
        Layout.fillWidth: true
        Layout.topMargin: 12
        implicitHeight: 2
        color: Theme.wine
        Rectangle { width: parent.width * (c.len > 0 ? Media.position / c.len : 0); height: 2; color: Theme.bone }
    }
    Art.T2 { visible: c.full; text: `${Media.time(Media.position)} · ${Media.time(c.len)}` }
    Art.Ctrl {
        playing: Media.playing
        onPrev: c.p?.previous()
        onToggle: c.p?.togglePlaying()
        onNext: c.p?.next()
    }
}
