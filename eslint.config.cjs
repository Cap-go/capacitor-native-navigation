const ionic = require('@ionic/eslint-config/recommended');

module.exports = [
  { ignores: ['dist/**', 'build/**'] },
  ...ionic,
];
