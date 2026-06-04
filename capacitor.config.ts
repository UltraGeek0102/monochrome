import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
    appId: 'tf.monochrome.music',
    appName: 'Monochrome Music',
    webDir: 'dist',
    ios: {
        allowsLinkPreview: false,
        limitsNavigationsToAppBoundDomains: false,
        // NOTE: do NOT set scrollEnabled: false — it breaks in-app scrolling
    },
    server: {
        allowNavigation: [
            '*.tidal.com',
            'resources.tidal.com',   // album art images for lock screen / Dynamic Island
            '*.monochrome.tf',
            'auth.monochrome.tf',
            '*.appwrite.io',
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
