Users = new Meteor.Collection "Users_meteor_related_tests"
Posts = new Meteor.Collection "Posts_meteor_related_tests"

intersectionObjects = (array, rest...) ->
  _.filter _.uniq(array), (item) ->
    _.every rest, (other) ->
      _.any other, (element) -> _.isEqual element, item

testSetEqual = (test, a, b) ->
  a ||= []
  b ||= []

  if a.length is b.length and intersectionObjects(a, b).length is a.length
    test.ok()
  else
    test.fail
      type: 'assert_set_equal'
      actual: JSON.stringify a
      expected: JSON.stringify b

if Meteor.isServer
  # Initialize the database
  Users.remove {}
  Posts.remove {}

  Meteor.publish null, ->
    Users.find()

  Meteor.publish 'users-posts', ->
    @related (user) ->
      Posts.find
        _id:
          $in: user?.posts or []
    ,
      Users.find {},
        fields:
          posts: 1

  Meteor.publish 'users-posts-count', ->
    @related (user) ->
      count = 0
      initializing = true
      countId = Random.id()

      Posts.find(
        _id:
          $in: user?.posts or []
      ).observeChanges
        added: (id) =>
          count++
          @changed countId, count: count unless initializing
        removed: (id) =>
          count--
          @changed countId, count: count unless initializing

      initializing = false

      @added 'Counts', countId,
        count: count

      @ready()
    ,
      Users.find {},
        fields:
          posts: 1

if Meteor.isClient
  Counts = new Meteor.Collection 'Counts'

  testAsyncMulti 'related - basic', [
    (test, expect) ->
      Meteor.subscribe 'users-posts', expect()
      Meteor.subscribe 'users-posts-count', expect()
  ,
    (test, expect) ->
      test.equal Posts.find().fetch(), []
      test.equal Counts.findOne()?.count, 0

      @posts = []

      for i in [0...10]
        Posts.insert {}, expect (error, id) =>
          test.isFalse error, error?.toString?() or error
          test.isTrue id
          @posts.push id
  ,
    (test, expect) ->
      test.equal Posts.find().fetch(), []
      test.equal Counts.findOne()?.count, 0

      Users.insert
        posts: @posts
      ,
        expect (error, userId) =>
          test.isFalse error, error?.toString?() or error
          test.isTrue userId
          @userId = userId
  ,
    (test, expect) ->
      testSetEqual test, _.pluck(Posts.find().fetch(), '_id'), @posts
      test.equal Counts.findOne()?.count, @posts.length

      @shortPosts = @posts[0...5]

      Users.update @userId,
        posts: @shortPosts
      ,
        expect (error, count) =>
          test.isFalse error, error?.toString?() or error
          test.equal count, 1
  ,
    (test, expect) ->
      testSetEqual test, _.pluck(Posts.find().fetch(), '_id'), @shortPosts
      test.equal Counts.findOne()?.count, @shortPosts.length

      Users.update @userId,
        posts: []
      ,
        expect (error, count) =>
          test.isFalse error, error?.toString?() or error
          test.equal count, 1
  ,
    (test, expect) ->
      testSetEqual test, _.pluck(Posts.find().fetch(), '_id'), []
      test.equal Counts.findOne()?.count, 0

      Users.update @userId,
        posts: @posts
      ,
        expect (error, count) =>
          test.isFalse error, error?.toString?() or error
          test.equal count, 1
  ,
    (test, expect) ->
      testSetEqual test, _.pluck(Posts.find().fetch(), '_id'), @posts
      test.equal Counts.findOne()?.count, @posts.length

      Users.remove @userId,
        expect (error) =>
          test.isFalse error, error?.toString?() or error
  ,
    (test, expect) ->
      testSetEqual test, _.pluck(Posts.find().fetch(), '_id'), []
      test.equal Counts.findOne()?.count, 0
  ]
