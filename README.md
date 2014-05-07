Publish with reactive dependencies
==================================

Adding this package to your [Meteor](http://www.meteor.com/) application augments
[Meteor.publish](http://docs.meteor.com/#meteor_publish) handler object with method
`related` which allows you to define publish endpoints with reactive dependencies on
additional queries.

```
mrt add related
```

`this.related`
--------------

Along with existing properties and methods, `this` inside `Meteor.publish` callback now
has `related` method available. Method excepts:

 * a callback, a new publish callback which will get as arguments results of your queries
 * one or more quries which will run and their results will be passed to a callback as arguments

Example
-------

Let's say that you have a list of blog posts user is following as `follows` field in Meteor's
`users` documents. You want to create a publish endpoint which will publish only those blog posts
which current user follows. But if `follows` field changes, published blog posts should also
change (or if published blog posts themselves change, changes should be pushed to the client).

```
Meteor.publish('followed-blog-posts', function () {
  if (!this.userId) return;

  this.related(function (user) {
    return Posts.find({_id: {$in: user.follows}});
  },
    Meteor.users.find(this.userId, {fields: {follows: 1}})
  );
});
```

Every time `follows` field of currently logged-in user changes, related publish callback is
rerun with new `user` document as an argument. Callback should do anything a normal publish
callback should: or call `added`/`changed`/`removed`, or simply return a query to publish.

Documents are tracked between reruns and are not republished if they remain the same between
reruns.

Known limitations
-----------------

Currently each of related queries is expected to return at most one document at all times.
In theory returning multiple documents could be supported, but this means that related publish
callback would be rerun at any change of any of those multiple documents. This is probably not
a not very efficient approach.

Nested calls to `related` should probably work, but were not yet tested.
