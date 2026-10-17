.pragma library

// 22 старших аркана: цифра, имя, глиф Nerd Font, смысл
// "sigil" — вместо глифа ascii-D (Death), "moon" — нарисованная луна
const MAJOR = [
    ["0", "The Fool", "\u{F0343}", "Step off the edge."],
    ["I", "The Magician", "\u{F0068}", "Everything on the table."],
    ["II", "The Priestess", "\u{F033E}", "Whisper only."],
    ["III", "The Empress", "\u{F024A}", "Make something."],
    ["IV", "The Emperor", "\u{F01A5}", "Set the house rules."],
    ["V", "The Hierophant", "\u{F0757}", "Say it like a prayer."],
    ["VI", "The Lovers", "\u{F02D1}", "Never drink alone."],
    ["VII", "The Chariot", "\u{F0858}", "Can't slow down."],
    ["VIII", "Strength", "\u{F095B}", "Carry everything."],
    ["IX", "The Hermit", "\u{F06B5}", "Write it down by candlelight."],
    ["X", "The Wheel", "\u{F0833}", "Spin it again."],
    ["XI", "Justice", "\u{F05D1}", "Weigh every door."],
    ["XII", "The Hanged Man", "\u{F0717}", "Hang until dawn."],
    ["XIII", "Death", "sigil", "Every door closes."],
    ["XIV", "Temperance", "\u{F0176}", "Pour it even."],
    ["XV", "The Devil", "\u{F0238}", "Take what you want."],
    ["XVI", "The Tower", "\u{F085B}", "The tower falls."],
    ["XVII", "The Star", "\u{F0AE2}", "Not tonight."],
    ["XVIII", "The Moon", "moon", "Still right before your eyes."],
    ["XIX", "The Sun", "\u{F0599}", "Get loose."],
    ["XX", "Judgement", "\u{F00E6}", "Answer the call."],
    ["XXI", "The World", "sigil", "Let it slide."],
];

// у приложения свой аркан и глиф (как в концепте); ключ — кусок id/имени в нижнем регистре
const APPS = [
    ["steam", 10, "\u{F04D3}", "games"],
    ["spotify", 21, "\u{F04C7}", "music"],
    ["feishin", 21, "\u{F075A}", "music"],
    ["signal", 2, "\u{F0FCC}", "chat"],
    ["telegram", 2, "\u{F0FCC}", "chat"],
    ["obsidian", 9, "\u{F082E}", "notes"],
    ["discord", 6, "\u{F066F}", "voice"],
    ["vesktop", 6, "\u{F066F}", "voice"],
    ["equibop", 6, "\u{F066F}", "voice"],
    ["settings", 4, "\u{F0493}", "system"],
    ["pavucontrol", 14, "\u{F057E}", "audio"],
    ["easyeffects", 14, "\u{F0EA2}", "audio"],
    ["swappy", 18, "\u{F0100}", "screenshot"],
    ["thunar", 8, "\u{F0770}", "files"],
    ["nautilus", 8, "\u{F0770}", "files"],
    ["btop", 7, "\u{F0A07}", "monitor"],
    ["inkscape", 3, "\u{F0AE8}", "vector"],
    ["gimp", 3, "\u{F0AE8}", "image"],
    ["krita", 3, "\u{F0AE8}", "paint"],
    ["blender", 3, "\u{F0AE8}", "3d"],
    ["transmission", 15, "\u{F01DA}", "torrent"],
    ["qbittorrent", 15, "\u{F01DA}", "torrent"],
    ["flatseal", 11, "\u{F099D}", "permissions"],
    ["kitty", 1, "\u{F018D}", "terminal"],
    ["foot", 1, "\u{F018D}", "terminal"],
    ["zen", 0, "\u{F059F}", "web"],
    ["firefox", 0, "\u{F059F}", "web"],
    ["chrom", 0, "\u{F059F}", "web"],
    ["codium", 5, "\u{F0169}", "code"],
    ["code", 5, "\u{F0169}", "code"],
    ["zed", 5, "\u{F0169}", "code"],
    ["mpv", 19, "\u{F040A}", "video"],
    ["vlc", 19, "\u{F040A}", "video"],
    ["lutris", 10, "\u{F04D3}", "games"],
    ["prism", 10, "\u{F04D3}", "games"],
];

function hash(s) {
    let h = 13;
    for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
    return h;
}

// { num, name, glyph, q, what, key } для приложения; неизвестные — аркан по хешу имени
function forApp(id, name, category) {
    const key = `${id} ${name}`.toLowerCase();
    const hit = APPS.find(a => key.includes(a[0]));
    const k = hit ? hit[1] : hash(key) % MAJOR.length;
    const m = MAJOR[k];
    return { k, num: m[0], name: m[1], glyph: hit ? hit[2] : m[2], q: m[3], what: hit ? hit[3] : (category || "app") };
}

function major(k) {
    const m = MAJOR[(k % 22 + 22) % 22];
    return { k, num: m[0], name: m[1], glyph: m[2], q: m[3] };
}

// карта дня: по дню года
function ofTheDay(date) {
    const start = new Date(date.getFullYear(), 0, 0);
    return major(Math.floor((date - start) / 86400000));
}
