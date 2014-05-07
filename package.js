Package.describe({
  summary: "Publish with reactive dependencies on related queries"
});

Package.on_use(function (api) {
  api.use(['coffeescript', 'underscore'], 'server');

  api.add_files([
    'server.coffee'
  ], 'server');
});

Package.on_test(function (api) {
  api.use(['related', 'tinytest', 'test-helpers'], 'server');
  api.add_files('tests.js', 'server');
});
