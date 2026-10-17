import QtQuick

// рука из шести HandCard
Item {
    function deal() { for (const c of children) c.deal?.(); }
    width: 220
    height: 380
}
