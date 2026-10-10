const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const packageRoot = path.resolve(__dirname, '..');

// The SDK package is linked from the parent directory: watch it, but resolve
// react / react-native only from this app so there is a single copy.
const config = {
  watchFolders: [packageRoot],
  resolver: {
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
    blockList: [new RegExp(`${path.resolve(packageRoot, 'node_modules').replace(/[\\/]/g, '[\\\\/]')}[\\\\/].*`)],
    unstable_enableSymlinks: true,
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
