Package.describe({
  summary: "Publish with reactive dependencies on related queries",
  version: '0.1.8',
  name: 'peerlibrary:related',
  git: 'https://github.com/peerlibrary/meteor-related.git'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@1.0.3.1');

  // Core dependencies.
  api.use([
    'coffeescript',
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
  // Core dependencies.
  api.use([
    'tinytest',
    'test-helpers',
    'coffeescript',
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
    'peerlibrary:classy-test@0.2.18'
  ]);

  api.addFiles([
    'tests.coffee'
  ]);
});
