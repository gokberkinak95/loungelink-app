// v1.88: yerli tarih/saat seçicinin taklidi.
// Taklit olmadan testler HEP yedek (maskeli metin) yolunu koşuyordu —
// yani asıl yol hiç mount edilmiyordu. v1.80 dersi: test edilmeyen dal,
// üretimde ilk kırılan daldır.
const React = require("react");
function DateTimePicker(props) {
  return React.createElement("DateTimePicker", { mode: props.mode, testID: "dtp" });
}
module.exports = { __esModule: true, default: DateTimePicker };
