importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAvrAPkv3W1LXfpDURB_cTScBRuHEBkBT0",
  authDomain: "floodguard-web.firebaseapp.com",
  projectId: "floodguard-web",
  storageBucket: "floodguard-web.firebasestorage.app",
  messagingSenderId: "837721359628",
  appId: "1:837721359628:web:1cf73d52ba7d03bf9385b2" // Note: This is a placeholder, but it works for messaging initialization
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
