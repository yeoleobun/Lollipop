(function () {
  'use strict';
  try {
    Object.defineProperty(window, 'PublicKeyCredential', {
      value: undefined,
      configurable: true
    });
    if (navigator.credentials) {
      Object.defineProperty(navigator, 'credentials', {
        value: undefined,
        configurable: true
      });
    }
  } catch (_) {}
})();
