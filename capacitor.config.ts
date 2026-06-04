import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
    appId: 'tf.monochrome.music',
    appName: 'Monochrome Music',
    webDir: 'dist',
    ios: {
        // Allow the webview to make cross-origin requests to TIDAL/Appwrite servers
        allowsLinkPreview: false,
        limitsNavigationsToAppBoundDomains: false,
        // Disable scrolling bounce (feels more native)
        scrollEnabled: false,
        contentInset: 'always',
    },
    server: {
        // Allow all external URLs to load inside the webview (TIDAL streams, Appwrite auth)
        allowNavigation: [
            '*.tidal.com',
            '*.monochrome.tf',
            'auth.monochrome.tf',
            '*.appwrite.io',
            '*.qqdl.site',
            'hifi.geeked.wtf',
        ],
    },
    assets: {
        iconBackgroundColor: '#000000',
        iconBackgroundColorDark: '#000000',
        splashBackgroundColor: '#000000',
        splashBackgroundColorDark: '#000000',
    },
};

export default config;
