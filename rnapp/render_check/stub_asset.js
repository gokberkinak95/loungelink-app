// Görsel/font varlıkları için taklit. Metro bunları sayısal bir kaynak
// kimliğine çevirir; Node ise .png'yi JS sanıp "Invalid or unexpected token"
// verir. Splash ekranı icon.png istediği için oturumsuz açılış testi bu
// yüzden çöküyordu (v1.84'te fark edildi).
module.exports = 1;
