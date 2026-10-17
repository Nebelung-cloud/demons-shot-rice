import QtQuick
import QtQuick.Layouts
import qs

// сцена аркана по глифу из arcana.js: "sigil" — ascii-D, "moon" — луна, иначе пиксельная иконка
Item {
    id: root

    property string glyph
    property int size: 90

    Layout.alignment: Qt.AlignHCenter
    implicitWidth: glyph === "sigil" ? d.implicitWidth : glyph === "moon" ? moon.implicitWidth : icon.implicitWidth
    implicitHeight: glyph === "sigil" ? d.implicitHeight : glyph === "moon" ? moon.implicitHeight : icon.implicitHeight

    AsciiD { id: d; visible: root.glyph === "sigil"; font.pixelSize: Math.round(root.size / 10) }
    Art.Moon { id: moon; visible: root.glyph === "moon" }
    PixelIcon { id: icon; visible: root.glyph !== "sigil" && root.glyph !== "moon"; size: root.size; text: visible ? root.glyph : "" }
}
