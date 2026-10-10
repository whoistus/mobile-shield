const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

// The SDK is linked with file:, so Metro must watch the package source and resolve
// react / react-native only from this app to keep a single copy.
const packageRoot = path.resolve(__dirname, '../../packages/react-native');

const config = {
  watchFolders: [packageRoot],
  resolver: {
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
    blockList: [new RegExp(`${path.resolve(packageRoot, 'node_modules').replace(/[\\/]/g, '[\\\\/]')}[\\\\/].*`)],
    unstable_enableSymlinks: true,
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
