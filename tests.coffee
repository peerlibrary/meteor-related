Users = new Meteor.Collection 'Users_meteor_related_tests'
Posts = new Meteor.Collection 'Posts_meteor_related_tests'

if Meteor.isServer
  Meteor.publish null, ->
    Users.find()

  Meteor.publish 'posts', (ids) ->
    Posts.find
      _id:
        $in: ids

  Meteor.publish 'users-posts', (userId) ->
    @copyIn = true

    @related (user) ->
      assert @copyIn, "copyIn not copied into related publish"

      Posts.find(
        _id:
          $in: user?.posts or []
      ).observeChanges
        added: (id, fields) =>
          fields.dummyField = true
          @added 'Posts_meteor_related_tests', id, fields
        changed: (id, fields) =>
          @changed 'Posts_meteor_related_tests', id, fields
        removed: (id) =>
          @removed 'Posts_meteor_related_tests', id

      @ready()
    ,
      Users.find userId,
        fields:
          posts: 1

  Meteor.publish 'users-posts-count', (userId, countId) ->
    @related (user) ->
      count = 0
      initializing = true

      Posts.find(
        _id:
          $in: user?.posts or []
      ).observeChanges
        added: (id) =>
          count++
          @changed 'Counts', countId, count: count unless initializing
        removed: (id) =>
          count--
          @changed 'Counts', countId, count: count unless initializing

      initializing = false

      @added 'Counts', countId,
        count: count

      @ready()
    ,
      Users.find userId,
        fields:
          posts: 1

class RelatedTestCase extends ClassyTestCase
  @testName: 'related'

  setUpServer: ->
    # Initialize the database.
    Users.remove {}
    Posts.remove {}

  setUpClient: ->
    @countsCollection ?= new Meteor.Collection 'Counts'

  testClientBasic: [
    ->
      @userId = Random.id()
      @countId = Random.id()

      @assertSubscribeSuccessful 'users-posts', @userId, @expect()
      @assertSubscribeSuccessful 'users-posts-count', @userId, @countId, @expect()
  ,
    ->
      @assertEqual Posts.find().fetch(), []
      @assertEqual @countsCollection.findOne(@countId)?.count, 0

      @posts = []

      for i in [0...10]
        Posts.insert {}, @expect (error, id) =>
          @assertFalse error, error?.toString?() or error
          @assertTrue id
          @posts.push id
  ,
    ->
      @assertEqual Posts.find().fetch(), []
      @assertEqual @countsCollection.findOne(@countId)?.count, 0

      Users.insert
        _id: @userId
        posts: @posts
      ,
        @expect (error, userId) =>
          @assertFalse error, error?.toString?() or error
          @assertTrue userId
          @assertEqual userId, @userId
  ,
    ->
      Posts.find().forEach (post) =>
        @assertTrue post.dummyField
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
      @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length

      @shortPosts = @posts[0...5]

      Users.update @userId,
        posts: @shortPosts
      ,
        @expect (error, count) =>
          @assertFalse error, error?.toString?() or error
          @assertEqual count, 1
  ,
    ->
      Posts.find().forEach (post) =>
        @assertTrue post.dummyField
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @shortPosts
      @assertEqual @countsCollection.findOne(@countId)?.count, @shortPosts.length

      Users.update @userId,
        posts: []
      ,
        @expect (error, count) =>
          @assertFalse error, error?.toString?() or error
          @assertEqual count, 1
  ,
    ->
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), []
      @assertEqual @countsCollection.findOne(@countId)?.count, 0

      Users.update @userId,
        posts: @posts
      ,
        @expect (error, count) =>
          @assertFalse error, error?.toString?() or error
          @assertEqual count, 1
  ,
    ->
      Posts.find().forEach (post) =>
        @assertTrue post.dummyField, true
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
      @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length

      Posts.remove @posts[0], @expect (error, count) =>
        @assertFalse error, error?.toString?() or error
        @assertEqual count, 1
  ,
    ->
      Posts.find().forEach (post) =>
        @assertTrue post.dummyField
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts[1..]
      @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length - 1

      Users.remove @userId,
        @expect (error) =>
          @assertFalse error, error?.toString?() or error
  ,
    ->
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), []
      @assertEqual @countsCollection.findOne(@countId)?.count, 0
  ]

  testClientUnsubscribing: [
    ->
      @userId = Random.id()
      @countId = Random.id()

      @assertSubscribeSuccessful 'users-posts', @userId, @expect()
      @assertSubscribeSuccessful 'users-posts-count', @userId, @countId, @expect()
  ,
    ->
      @assertEqual Posts.find().fetch(), []
      @assertEqual @countsCollection.findOne(@countId)?.count, 0

      @posts = []

      for i in [0...10]
        Posts.insert {}, @expect (error, id) =>
          @assertFalse error, error?.toString?() or error
          @assertTrue id
          @posts.push id
  ,
    ->
      @assertEqual Posts.find().fetch(), []
      @assertEqual @countsCollection.findOne(@countId)?.count, 0

      Users.insert
        _id: @userId
        posts: @posts
      ,
        @expect (error, userId) =>
          @assertFalse error, error?.toString?() or error
          @assertTrue userId
          @assertEqual userId, @userId
  ,
    ->
      Posts.find().forEach (post) =>
        @assertTrue post.dummyField
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
      @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length

      # We have to update posts to trigger at least one rerun.
      Users.update @userId,
        posts: _.shuffle @posts
      ,
        @expect (error, count) =>
          @assertFalse error, error?.toString?() or error
          @assertEqual count, 1
  ,
    ->
      Posts.find().forEach (post) =>
        @assertTrue post.dummyField
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
      @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length

      callback = @expect()
      @postsSubscribe = Meteor.subscribe 'posts', @posts,
        onReady: callback
        onError: (error) =>
          @assertFail
            type: 'subscribe'
            message: "Subscrption to endpoint failed, but should have succeeded."
          callback()
      @unsubscribeAll()

      # Let's wait a but for subscription to really stop
      Meteor.setTimeout @expect(), 1000
  ,
    ->
      # After unsubscribing from the related-based publish which added dummyField,
      # dummyField should be removed from documents available on the client side
      Posts.find().forEach (post) =>
        @assertIsUndefined post.dummyField
      @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts

      @postsSubscribe.stop()
  ]

# Register the test case.
ClassyTestCase.addTest new RelatedTestCase()
