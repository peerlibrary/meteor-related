Package.describe({
  summary: "Publish with reactive dependencies on related queries",
  version: '0.1.6',
  name: 'peerlibrary:related',
  git: 'https://github.com/peerlibrary/meteor-related.git'
});

Package.on_use(function (api) {
  api.versionsFrom('METEOR@0.9.3');
  api.use(['coffeescript', 'underscore', 'peerlibrary:assert@0.2.5'], 'server');

  api.add_files([
    'server.coffee'
  ], 'server');
});

Package.on_test(function (api) {
  api.use(['peerlibrary:related', 'tinytest', 'test-helpers', 'coffeescript', 'insecure', 'random'], ['client', 'server']);

  api.add_files('tests.coffee', ['client', 'server']);
});
