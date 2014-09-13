Package.describe({
  summary: "Publish with reactive dependencies on related queries",
  version: '0.1.5',
  name: 'mrt:related',
  git: 'https://github.com/peerlibrary/meteor-related.git'
});

Package.on_use(function (api) {
  api.imply('peerlibrary:related@0.1.5');
});
