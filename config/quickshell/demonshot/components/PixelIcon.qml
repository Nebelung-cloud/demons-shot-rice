import QtQuick
import qs

// пиксельная иконка по глифу Nerd Font: есть рисованная в px/ (pixelarticons, сетка 24) — она, целыми пикселями;
// нет — сам глиф, огрублённый в сетку ~16 по высоте. В обоих случаях порог по альфе и тон color.
// Габариты всегда от глифа, рисунок по центру этого блока: под его высоту подогнаны раскладки карт
Item {
    id: root

    property string text
    property int size: 16
    property color color: Theme.rose

    // глиф → px/<имя>.svg
    readonly property var names: ({
        0xF0068: "wand",
        0xF009A: "bell",
        0xF00DF: "sun",
        0xF00E6: "megaphone",
        0xF0100: "camera",
        0xF0169: "braces",
        0xF0176: "coffee",
        0xF018D: "terminal",
        0xF01A5: "crown",
        0xF01DA: "download",
        0xF0214: "file",
        0xF0238: "fire",
        0xF024A: "leaf",
        0xF02CB: "headphone",
        0xF02D1: "heart",
        0xF02E9: "image",
        0xF030C: "keyboard",
        0xF0337: "link",
        0xF033E: "lock",
        0xF033F: "unlock",
        0xF0343: "logout",
        0xF036C: "mic",
        0xF036D: "mic-off",
        0xF0379: "monitor",
        0xF037D: "mouse",
        0xF03D8: "colors-swatch",
        0xF040A: "play",
        0xF0493: "gear",
        0xF04B2: "hourglass",
        0xF04C3: "radio",
        0xF04C7: "music",
        0xF04D3: "gamepad",
        0xF04E5: "sword",
        0xF0552: "upload",
        0xF057E: "volume-3",
        0xF058E: "waves",
        0xF0590: "cloud",
        0xF0591: "cloud",
        0xF0593: "zap",
        0xF0594: "moon",
        0xF0595: "cloud-sun",
        0xF0597: "cloud",
        0xF0598: "snowflake",
        0xF0599: "sun",
        0xF059D: "wind",
        0xF059F: "globe",
        0xF05D1: "scale",
        0xF061A: "cpu",
        0xF066F: "discord",
        0xF06B5: "lightbulb",
        0xF0709: "reload",
        0xF0717: "snowflake",
        0xF0757: "quote-text-inline",
        0xF075A: "music",
        0xF075F: "volume-x",
        0xF0770: "folder",
        0xF082E: "notebook",
        0xF0833: "loader",
        0xF0858: "speed-fast",
        0xF085B: "castle",
        0xF08AE: "gpu",
        0xF0928: "wifi",
        0xF095B: "audio-waveform",
        0xF099D: "shield",
        0xF09A8: "article",
        0xF0A07: "analytics",
        0xF0AE2: "sparkle",
        0xF0AE8: "brush",
        0xF0CB8: "album",
        0xF0EA2: "sliders-vertical",
        0xF0FCC: "message",
    })
    readonly property string file: names[text.codePointAt(0)] ?? ""
    readonly property int k: Math.max(1, Math.round(size / 24))

    implicitWidth: glyph.implicitWidth
    implicitHeight: glyph.implicitHeight

    Image {
        visible: root.file !== ""
        x: Math.round((glyph.width - width) / 2)
        y: Math.round((glyph.height - height) / 2)
        width: 24 * root.k
        height: width
        source: visible ? Qt.resolvedUrl(`px/${root.file}.svg`) : ""
        sourceSize: Qt.size(24, 24)
        smooth: false
        layer.enabled: visible
        layer.effect: ShaderEffect {
            property color tint: root.color
            fragmentShader: Qt.resolvedUrl("shaders/pixel.frag.qsb")
        }
    }

    Text {
        id: glyph
        readonly property int k: Math.max(1, Math.round(root.size / 16))
        visible: root.file === ""
        text: root.text
        font.family: Theme.mono
        font.pixelSize: root.size
        layer.enabled: visible
        layer.smooth: false
        layer.textureSize: Qt.size(Math.ceil(width / k), Math.ceil(height / k))
        layer.effect: ShaderEffect {
            property color tint: root.color
            fragmentShader: Qt.resolvedUrl("shaders/pixel.frag.qsb")
        }
    }
}
