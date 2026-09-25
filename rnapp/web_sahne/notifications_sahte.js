// web_sahne/notifications_sahte.js — web sahnesinde bildirim modülü taklidi
// (cihazdaki "izin verildi, jeton var" hâli). Sahne `?izin=denied` ile
// reddedilmiş hâli de çizebilir.
const q = new URLSearchParams(typeof window !== "undefined" ? window.location.search : "");
const DURUM = q.get("izin") || "granted";
export const AndroidImportance = { MAX: 5, HIGH: 4, DEFAULT: 3, LOW: 2, MIN: 1 };
export async function getPermissionsAsync() { return { status: DURUM, granted: DURUM === "granted", canAskAgain: true }; }
export async function requestPermissionsAsync() { return getPermissionsAsync(); }
export async function getExpoPushTokenAsync() { return { data: "ExponentPushToken[sahne]" }; }
export async function getDevicePushTokenAsync() { return { data: "sahne", type: "fcm" }; }
export function setNotificationHandler() {}
export function addNotificationResponseReceivedListener() { return { remove() {} }; }
export function addNotificationReceivedListener() { return { remove() {} }; }
export async function getLastNotificationResponseAsync() { return null; }
export async function setNotificationChannelAsync() {}
export async function getBadgeCountAsync() { return 0; }
export async function setBadgeCountAsync() {}
export async function dismissAllNotificationsAsync() {}
export default {};
