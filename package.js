Package.describe({
  summary: "Publish with reactive dependencies on related queries",
  version: '0.2.2',
  name: 'peerlibrary:related',
  git: 'https://github.com/peerlibrary/meteor-related.git'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@1.7');

  // Core dependencies.
  api.use([
    'coffeescript@2.3.2_1',
    'underscore'
  ], 'server');

  // 3rd party dependencies.
  api.use([
    'peerlibrary:assert@0.2.5'
  ], 'server');

  api.addFiles([
    'server.coffee'
  ], 'server');
});

Package.onTest(function (api) {
  api.versionsFrom('METEOR@1.7');

  // Core dependencies.
  api.use([
    'tinytest',
    'test-helpers',
    'coffeescript@2.3.2_1',
    'insecure',
    'random',
    'underscore'
  ]);

  // Internal dependencies.
  api.use([
    'peerlibrary:related'
  ]);

  // 3rd party dependencies.
  api.use([
    'peerlibrary:assert@0.2.5',
    'peerlibrary:classy-test@0.2.26'
  ]);

  api.addFiles([
    'tests.coffee'
  ]);
});
