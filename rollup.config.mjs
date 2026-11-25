import resolve from '@rollup/plugin-node-resolve';

export default {
  input: 'dist/esm/index.js',
  plugins: [resolve({ browser: true, preferBuiltins: false })],
  output: [
    {
      file: 'dist/plugin.js',
      format: 'iife',
      name: 'capacitorNativeNavigation',
      globals: {
        '@capacitor/core': 'capacitorExports',
      },
      sourcemap: true,
      inlineDynamicImports: true,
    },
    {
      file: 'dist/plugin.cjs.js',
      format: 'cjs',
      sourcemap: true,
      inlineDynamicImports: true,
    },
  ],
  external: ['@capacitor/core'],
};
